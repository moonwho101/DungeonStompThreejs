extends Node3D

const Parsers = preload("res://scripts/parsers.gd")
const DungeonGenerator = preload("res://scripts/generator.gd")
const CollisionSystem = preload("res://scripts/collision.gd")
const PlayerClass = preload("res://scripts/player.gd")
const MonsterClass = preload("res://scripts/monster.gd")
const AudioManager = preload("res://scripts/audio.gd")
const HUDScene = preload("res://scenes/hud.tscn")

var collision_system: CollisionSystem = null
var tex_manager: Parsers.TextureManager = null
var obj_parser: Parsers.ObjectsDatParser = null
var audio_manager: AudioManager = null

var player: PlayerClass = null
var hud: Node = null
var monsters: Array = []
var wall_points: Array[Vector2] = []

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var dungeon_root: Node3D = $DungeonRoot

func _ready():
	print("Starting Dungeon Stomp Godot 4.7.2 World...")
	audio_manager = AudioManager.new()
	add_child(audio_manager)

	tex_manager = Parsers.TextureManager.new()
	tex_manager.load_textures_dat("bin/textures.dat")

	obj_parser = Parsers.ObjectsDatParser.new()
	obj_parser.parse("bin/ObjectsAll.dat")

	collision_system = CollisionSystem.new()

	# Create HUD
	hud = HUDScene.instantiate()
	add_child(hud)

	generate_new_level()

func generate_new_level(rng_seed: int = 0):
	# Clear previous dungeon instances
	for child in dungeon_root.get_children():
		child.queue_free()
	monsters.clear()
	wall_points.clear()
	collision_system.triangles.clear()
	collision_system.spatial_grid.clear()

	var dungeon_text = DungeonGenerator.generate_dungeon(24, 24, 8, rng_seed)
	var map_parser = Parsers.LevelMapParser.new()
	map_parser.parse_text(dungeon_text)

	build_dungeon_geometry(map_parser)

	collision_system.build_grid()

	# Spawn or reposition player
	if player == null:
		player = PlayerClass.new()
		var cam = Camera3D.new()
		cam.name = "Camera3D"
		cam.current = true
		player.add_child(cam)
		add_child(player)
		player.collision_system = collision_system
		player.stats_changed.connect(Callable(hud, "update_stats"))

	player.global_position = map_parser.start_pos
	player.rotation.y = deg_to_rad(map_parser.start_rot)
	player.yaw = deg_to_rad(map_parser.start_rot)
	player.velocity = Vector3.ZERO
	player.is_grounded = false

	# Play ambient level sound
	audio_manager.play_sound("teleport")

func build_dungeon_geometry(map_parser: Parsers.LevelMapParser):
	# Build mesh instances and populate collision system
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for inst in map_parser.instances:
		if inst.is_start_pos:
			continue

		if inst.is_light:
			var light = OmniLight3D.new()
			light.position = inst.position
			light.light_color = inst.light_color
			light.light_energy = 2.0
			light.omni_range = 350.0
			dungeon_root.add_child(light)
			continue

		if inst.name == "MONSTER":
			var monster = MonsterClass.new()
			monster.position = inst.position
			monster.rotation.y = deg_to_rad(inst.rotation_deg)
			monster.collision_system = collision_system
			monster.monster_id = inst.monster_id
			dungeon_root.add_child(monster)
			monsters.append(monster)
			continue

		# Map tile geometry from parsed objects
		var obj_def = obj_parser.objects_by_name.get(inst.name.to_lower())
		if obj_def:
			wall_points.append(Vector2(inst.position.x, inst.position.z))
			var rot_rad = deg_to_rad(inst.rotation_deg)
			var cos_r = cos(rot_rad)
			var sin_r = sin(rot_rad)

			for poly in obj_def.polys:
				var v_count = poly.vertices.size()
				for i in range(0, v_count, 3):
					if i + 2 < v_count:
						var p0 = transform_vertex(poly.vertices[i], inst.position, cos_r, sin_r)
						var p1 = transform_vertex(poly.vertices[i+1], inst.position, cos_r, sin_r)
						var p2 = transform_vertex(poly.vertices[i+2], inst.position, cos_r, sin_r)

						collision_system.add_triangle(p0, p1, p2)

						surface_tool.set_uv(poly.uvs[i])
						surface_tool.add_vertex(p0)
						surface_tool.set_uv(poly.uvs[i+1])
						surface_tool.add_vertex(p1)
						surface_tool.set_uv(poly.uvs[i+2])
						surface_tool.add_vertex(p2)

	surface_tool.generate_normals()
	var mesh = surface_tool.commit()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh

	# Create standard material with dungeon texture
	var mat = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat

	dungeon_root.add_child(mesh_instance)

func transform_vertex(v: Vector3, offset: Vector3, cos_r: float, sin_r: float) -> Vector3:
	var rx = v.x * cos_r - v.z * sin_r
	var rz = v.x * sin_r + v.z * cos_r
	return Vector3(rx + offset.x, v.y + offset.y, rz + offset.z)

func _process(delta: float):
	if Input.is_action_just_pressed("generate_level"):
		generate_new_level()

	if player:
		player.update_physics(delta)
		var player_pos = player.global_position
		for m in monsters:
			if is_instance_valid(m):
				m.update_ai(delta, player_pos)

		if hud:
			hud.update_minimap(player_pos, player.yaw, monsters, wall_points)
