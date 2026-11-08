# Monster AI, animation and health bar (port of the Monster class in logic.js).
class_name Monster
extends RefCounted

enum State { IDLE, ALERT, CHASE, ATTACK, HURT, DEATH }

const ANIMS := {
	"STAND": {"name": "STAND", "start": 0, "end": 39, "fps": 9.0, "loop": true},
	"RUN": {"name": "RUN", "start": 40, "end": 45, "fps": 10.0, "loop": true},
	"ATTACK": {"name": "ATTACK", "start": 46, "end": 53, "fps": 10.0, "loop": false},
	"PAIN1": {"name": "PAIN1", "start": 54, "end": 57, "fps": 8.0, "loop": false},
	"PAIN2": {"name": "PAIN2", "start": 58, "end": 61, "fps": 8.0, "loop": false},
	"PAIN3": {"name": "PAIN3", "start": 62, "end": 65, "fps": 8.0, "loop": false},
	"JUMP": {"name": "JUMP", "start": 66, "end": 71, "fps": 10.0, "loop": false},
	"FLIP": {"name": "FLIP", "start": 72, "end": 83, "fps": 10.0, "loop": false},
	"SALUTE": {"name": "SALUTE", "start": 84, "end": 94, "fps": 9.0, "loop": false},
	"TAUNT": {"name": "TAUNT", "start": 95, "end": 111, "fps": 9.0, "loop": false},
	"WAVE": {"name": "WAVE", "start": 112, "end": 122, "fps": 9.0, "loop": false},
	"POINT": {"name": "POINT", "start": 123, "end": 134, "fps": 9.0, "loop": false},
	"DEATH1": {"name": "DEATH1", "start": 178, "end": 183, "fps": 7.0, "loop": false},
	"DEATH2": {"name": "DEATH2", "start": 184, "end": 189, "fps": 7.0, "loop": false},
	"DEATH3": {"name": "DEATH3", "start": 190, "end": 197, "fps": 7.0, "loop": false},
}

const DEFAULT_CONFIG := {
	"moveSpeed": 165.0, "turnRate": 6.0, "aggroRadius": 800.0, "deaggroRadius": 1200.0,
	"attackRange": 85.0, "stopDistance": 85.0, "alertDuration": 0.6, "damage": 10, "maxHealth": 100,
	"painSound": "impact.wav", "deathSound": "die.wav", "weaponSound": "swish4.wav",
	"yellSound": "goblin.wav", "sound": "goblin.wav",
	"canCastSpells": false, "spells": [], "spellCooldown": 0.0, "bloodColor": 0x9a0a0a,
}

const SPEED_MULT := 1.5
const SPELLS := ["MAGIC MISSILE", "FIREBALL", "LIGHTNING"]

static var CONFIGS := {
	"KNIGHT": {"painSound": "impact5.wav", "deathSound": "Skeleton.wav", "weaponSound": "swish9.wav", "yellSound": "mouther.wav", "sound": "mouther.wav", "moveSpeed": 150.0 * SPEED_MULT, "aggroRadius": 850.0, "damage": 15, "maxHealth": 20},
	"GOBLIN": {"painSound": "impact.wav", "deathSound": "death3.wav", "weaponSound": "swish4.wav", "yellSound": "goblin.wav", "sound": "goblin.wav", "moveSpeed": 190.0 * SPEED_MULT, "aggroRadius": 750.0, "damage": 6, "maxHealth": 18},
	"BAUUL": {"painSound": "baullpain.wav", "deathSound": "baull.wav", "weaponSound": "swish1.wav", "yellSound": "baullspeak.wav", "sound": "baullspeak.wav", "moveSpeed": 140.0 * SPEED_MULT, "aggroRadius": 900.0, "damage": 20, "maxHealth": 25, "canCastSpells": true, "spells": SPELLS, "attackRange": 620.0, "stopDistance": 270.0, "spellCooldown": 2.0},
	"CORPSE": {"painSound": "impact.wav", "deathSound": "goblindeath.wav", "weaponSound": "swish9.wav", "yellSound": "ghoul.wav", "sound": "ghoul.wav", "moveSpeed": 110.0 * SPEED_MULT, "aggroRadius": 650.0, "damage": 8, "maxHealth": 15},
	"SORCERER": {"painSound": "sorcererpain.wav", "deathSound": "sorcererdie.wav", "weaponSound": "swish7.wav", "yellSound": "sorcererspeak.wav", "sound": "sorcererspeak.wav", "moveSpeed": 160.0 * SPEED_MULT, "aggroRadius": 950.0, "damage": 18, "maxHealth": 20, "canCastSpells": true, "spells": SPELLS, "attackRange": 650.0, "stopDistance": 260.0, "spellCooldown": 1.6},
	"TENTACLE": {"painSound": "impact5.wav", "deathSound": "Skeleton.wav", "weaponSound": "swish9.wav", "yellSound": "mouther.wav", "sound": "mouther.wav", "moveSpeed": 120.0 * SPEED_MULT, "aggroRadius": 700.0, "damage": 5, "maxHealth": 17},
	"WRAITH": {"painSound": "wraithpain.wav", "deathSound": "wraithdie.wav", "weaponSound": "swish4.wav", "yellSound": "wraithspeak.wav", "sound": "wraithspeak.wav", "moveSpeed": 180.0 * SPEED_MULT, "aggroRadius": 950.0, "damage": 12, "maxHealth": 28, "canCastSpells": true, "spells": SPELLS, "attackRange": 600.0, "stopDistance": 250.0, "spellCooldown": 1.8},
	"OGRE": {"painSound": "impact3.wav", "deathSound": "death1.wav", "weaponSound": "swish7.wav", "yellSound": "ogre.wav", "sound": "ogre.wav", "moveSpeed": 130.0 * SPEED_MULT, "aggroRadius": 800.0, "damage": 25, "maxHealth": 25, "canCastSpells": true, "spells": SPELLS, "attackRange": 550.0, "stopDistance": 220.0, "spellCooldown": 2.2},
	"PHANTOM": {"painSound": "impact4.wav", "deathSound": "death2.wav", "weaponSound": "swish7.wav", "yellSound": "baull.wav", "sound": "baull.wav", "moveSpeed": 170.0 * SPEED_MULT, "aggroRadius": 900.0, "damage": 16, "maxHealth": 20, "canCastSpells": true, "spells": SPELLS, "attackRange": 600.0, "stopDistance": 250.0, "spellCooldown": 2.0},
	"OGRO": {"painSound": "impact3.wav", "deathSound": "death1.wav", "weaponSound": "swish7.wav", "yellSound": "ogre.wav", "sound": "ogre.wav", "moveSpeed": 135.0 * SPEED_MULT, "aggroRadius": 800.0, "damage": 14, "maxHealth": 20},
	"SKELETON2": {"painSound": "impact5.wav", "deathSound": "Skeleton.wav", "weaponSound": "swish9.wav", "yellSound": "mouther.wav", "sound": "mouther.wav", "moveSpeed": 165.0 * SPEED_MULT, "aggroRadius": 800.0, "damage": 10, "maxHealth": 15},
	"DEMONESS": {"painSound": "impact3.wav", "deathSound": "death4.wav", "weaponSound": "swish7.wav", "yellSound": "ogre.wav", "sound": "ogre.wav", "moveSpeed": 175.0 * SPEED_MULT, "aggroRadius": 950.0, "damage": 22, "maxHealth": 35, "canCastSpells": true, "spells": SPELLS, "attackRange": 680.0, "stopDistance": 280.0, "spellCooldown": 1.6},
	"FAERIE": {"painSound": "faeriepain.wav", "deathSound": "faeriedie.wav", "weaponSound": "swish7.wav", "yellSound": "faeriespeak.wav", "sound": "faeriespeak.wav", "moveSpeed": 185.0 * SPEED_MULT, "aggroRadius": 900.0, "damage": 15, "maxHealth": 30, "canCastSpells": true, "spells": SPELLS, "attackRange": 700.0, "stopDistance": 300.0, "spellCooldown": 1.4},
	"SLAVE": {"painSound": "impact5.wav", "deathSound": "Skeleton.wav", "weaponSound": "swish9.wav", "yellSound": "mouther.wav", "sound": "mouther.wav", "moveSpeed": 140.0 * SPEED_MULT, "aggroRadius": 600.0, "damage": 5, "maxHealth": 5},
	"WOLF": {"painSound": "wolfpain.wav", "deathSound": "wolfdie.wav", "weaponSound": "swish4.wav", "yellSound": "wolfhowl.wav", "sound": "wolfhowl.wav", "moveSpeed": 210.0 * SPEED_MULT, "aggroRadius": 850.0, "damage": 12, "maxHealth": 20},
	"INSECT": {"painSound": "impact5.wav", "deathSound": "Skeleton.wav", "weaponSound": "swish9.wav", "yellSound": "mouther.wav", "sound": "mouther.wav", "moveSpeed": 195.0 * SPEED_MULT, "aggroRadius": 800.0, "damage": 10, "maxHealth": 20},
	"OLUVE": {"painSound": "impact5.wav", "deathSound": "Skeleton.wav", "weaponSound": "swish9.wav", "yellSound": "mouther.wav", "sound": "mouther.wav", "moveSpeed": 150.0 * SPEED_MULT, "aggroRadius": 700.0, "damage": 6, "maxHealth": 17},
	"MUMMY": {"painSound": "mummypain.wav", "deathSound": "mummydie.wav", "weaponSound": "swish7.wav", "yellSound": "mummyspeak.wav", "sound": "mummyspeak.wav", "moveSpeed": 125.0 * SPEED_MULT, "aggroRadius": 750.0, "damage": 12, "maxHealth": 18},
	"HYDRA": {"painSound": "hydrapain.wav", "deathSound": "hydradie.wav", "weaponSound": "swish1.wav", "yellSound": "hydraspeak.wav", "sound": "hydraspeak.wav", "moveSpeed": 145.0 * SPEED_MULT, "aggroRadius": 850.0, "damage": 16, "maxHealth": 20},
	"NECROMANCER": {"painSound": "necropain.wav", "deathSound": "necrodie.wav", "weaponSound": "swish5.wav", "yellSound": "necrospeak.wav", "sound": "necrospeak.wav", "moveSpeed": 160.0 * SPEED_MULT, "aggroRadius": 1000.0, "damage": 24, "maxHealth": 35, "canCastSpells": true, "spells": SPELLS, "attackRange": 650.0, "stopDistance": 280.0, "spellCooldown": 1.8},
	"IMP": {"painSound": "imppain.wav", "deathSound": "impdie.wav", "weaponSound": "swish1.wav", "yellSound": "impspeak.wav", "sound": "impspeak.wav", "moveSpeed": 180.0 * SPEED_MULT, "aggroRadius": 800.0, "damage": 10, "maxHealth": 20},
	"DEMON": {"painSound": "demonpain.wav", "deathSound": "demondie.wav", "weaponSound": "swish7.wav", "yellSound": "demonspeak.wav", "sound": "demonspeak.wav", "moveSpeed": 165.0 * SPEED_MULT, "aggroRadius": 950.0, "damage": 20, "maxHealth": 25},
	"FULIMO": {"painSound": "fulimopain.wav", "deathSound": "fulimodie.wav", "weaponSound": "swish7.wav", "yellSound": "fulimospeak.wav", "sound": "fulimospeak.wav", "moveSpeed": 170.0 * SPEED_MULT, "aggroRadius": 900.0, "damage": 18, "maxHealth": 25},
	"COBRA": {"painSound": "impact.wav", "deathSound": "snakedie.wav", "weaponSound": "swish7.wav", "yellSound": "snakehiss.wav", "sound": "snakehiss.wav", "moveSpeed": 190.0 * SPEED_MULT, "aggroRadius": 800.0, "damage": 14, "maxHealth": 30},
	"DRAGON": {"painSound": "fulimopain.wav", "deathSound": "fulimodie.wav", "weaponSound": "swish7.wav", "yellSound": "fulimospeak.wav", "sound": "fulimospeak.wav", "moveSpeed": 160.0 * SPEED_MULT, "aggroRadius": 1000.0, "damage": 28, "maxHealth": 30},
	"CENTAUR": {"painSound": "fulimopain.wav", "deathSound": "fulimodie.wav", "weaponSound": "swish7.wav", "yellSound": "fulimospeak.wav", "sound": "fulimospeak.wav", "moveSpeed": 190.0 * SPEED_MULT, "aggroRadius": 850.0, "damage": 12, "maxHealth": 16},
	"CRAZ": {"painSound": "impact.wav", "deathSound": "death3.wav", "weaponSound": "swish7.wav", "yellSound": "orc.wav", "sound": "orc.wav", "moveSpeed": 175.0 * SPEED_MULT, "aggroRadius": 800.0, "damage": 14, "maxHealth": 20},
	"RIDER": {"painSound": "fulimopain.wav", "deathSound": "fulimodie.wav", "weaponSound": "swish7.wav", "yellSound": "fulimospeak.wav", "sound": "fulimospeak.wav", "moveSpeed": 180.0 * SPEED_MULT, "aggroRadius": 900.0, "damage": 20, "maxHealth": 26},
	"OKTA": {"painSound": "fulimopain.wav", "deathSound": "fulimodie.wav", "weaponSound": "swish7.wav", "yellSound": "fulimospeak.wav", "sound": "fulimospeak.wav", "moveSpeed": 165.0 * SPEED_MULT, "aggroRadius": 850.0, "damage": 16, "maxHealth": 25},
	"SORB": {"painSound": "impact.wav", "deathSound": "sorbdie.wav", "weaponSound": "swish7.wav", "yellSound": "sorb.wav", "sound": "sorb.wav", "moveSpeed": 170.0 * SPEED_MULT, "aggroRadius": 950.0, "damage": 22, "maxHealth": 29},
}

# Order matters for substring matching, so keep the browser's key order.
const CONFIG_ORDER := ["KNIGHT", "GOBLIN", "BAUUL", "CORPSE", "SORCERER", "TENTACLE", "WRAITH", "OGRE", "PHANTOM",
	"OGRO", "SKELETON2", "DEMONESS", "FAERIE", "SLAVE", "WOLF", "INSECT", "OLUVE", "MUMMY", "HYDRA", "NECROMANCER",
	"IMP", "DEMON", "FULIMO", "COBRA", "DRAGON", "CENTAUR", "CRAZ", "RIDER", "OKTA", "SORB"]

const HEALTH_BAR_SHADER := """
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled;
instance uniform float pct = 1.0;
instance uniform vec4 fill_color = vec4(0.13, 0.77, 0.37, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}
float rrect(vec2 p, vec2 pos, vec2 size, float r) {
	r = min(r, min(size.x, size.y) * 0.5);
	vec2 c = pos + size * 0.5;
	vec2 q = abs(p - c) - size * 0.5 + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec4 over(vec4 dst, vec3 rgb, float a) {
	float oa = a + dst.a * (1.0 - a);
	if (oa <= 0.0) return vec4(0.0);
	return vec4((rgb * a + dst.rgb * dst.a * (1.0 - a)) / oa, oa);
}
void fragment() {
	vec2 px = UV * vec2(256.0, 64.0);
	vec4 col = vec4(0.0);
	float d = rrect(px, vec2(8.0, 4.0), vec2(240.0, 56.0), 8.0);
	col = over(col, vec3(15.0, 23.0, 42.0) / 255.0, 0.85 * clamp(0.5 - d, 0.0, 1.0));
	col = over(col, vec3(1.0), 0.35 * clamp(1.5 - abs(d), 0.0, 1.0));
	float bar = rrect(px, vec2(18.0, 34.0), vec2(220.0, 16.0), 4.0);
	col = over(col, vec3(30.0, 41.0, 59.0) / 255.0, 0.9 * clamp(0.5 - bar, 0.0, 1.0));
	if (pct > 0.0) {
		float fill = rrect(px, vec2(18.0, 34.0), vec2(220.0 * pct, 16.0), 4.0);
		col = over(col, fill_color.rgb, clamp(0.5 - fill, 0.0, 1.0));
	}
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
"""

static var _bar_material: ShaderMaterial = null
static var _bar_quad: QuadMesh = null
static var _bar_font: SystemFont = null

var game # Game (untyped to avoid a class cycle)
var model: MD2Model
var mesh: MeshInstance3D
var weapon_model: MD2Model = null
var weapon_mesh: Node3D = null
var config: Dictionary
var name := "MONSTER"
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var is_grounded := false
var rotation_y := 0.0
var state: int = State.IDLE
var dead := false
var health := 100.0
var state_timer := 0.0
var attack_cooldown := 0.0
var has_dealt_damage := false
var current_anim: Dictionary
var anim_timer := 0.0
var anim_complete := false
var prev_pose: Array = []
var fade_timer := 0.0
var fade_duration := 0.15
var bbox := CollisionWorld.Box.new()
var health_bar_height := 75.0
var noise_timer := 0.0
var los_timer := 0.0
var has_los := false
var pending_spell := ""
var is_melee_attack := true
var strafe_dir := 1.0
var strafe_timer := 0.0
var hp_bar: Node3D = null
var _hp_quad: MeshInstance3D
var _hp_name: Label3D
var _hp_text: Label3D
var scale := 1.0


static func clear_shared() -> void:
	_bar_material = null
	_bar_quad = null
	_bar_font = null


static func get_config(model_name: String) -> Dictionary:
	var cfg := DEFAULT_CONFIG.duplicate(true)
	if model_name == "":
		return cfg
	var clean := model_name.to_upper().strip_edges()
	var key := ""
	if CONFIGS.has(clean):
		key = clean
	else:
		for k: String in CONFIG_ORDER:
			if clean.contains(k):
				key = k
				break
	if key != "":
		cfg.merge(CONFIGS[key], true)
	return cfg


func _init(p_game, p_model: MD2Model, p_mesh: MeshInstance3D, p_weapon_model: MD2Model, p_weapon_mesh: Node3D,
		p_config: Dictionary, initial_position: Vector3, initial_rotation_y: float, p_scale: float) -> void:
	game = p_game
	model = p_model
	mesh = p_mesh
	weapon_model = p_weapon_model
	weapon_mesh = p_weapon_mesh
	scale = p_scale
	config = p_config
	var depth_power: float = 1.0 + (game.dungeon_depth - 1) * 0.15
	if depth_power > 1.0:
		config.maxHealth = roundi(config.maxHealth * depth_power)
		config.damage = roundi(config.damage * depth_power)
	name = str(config.get("name", "MONSTER")).to_upper()
	position = initial_position
	rotation_y = initial_rotation_y
	_sync_transforms()
	health = config.maxHealth
	current_anim = ANIMS.STAND
	_update_bounding_box()
	if not bbox.is_empty():
		health_bar_height = bbox.max.y - position.y + 12.0
	noise_timer = 3.0 + randf() * 8.0
	los_timer = randf() * 0.2
	strafe_dir = 1.0 if randf() < 0.5 else -1.0
	set_animation(ANIMS.STAND, true)
	_update_morph_targets(0.0)
	_create_health_bar()


func _sync_transforms() -> void:
	mesh.position = position
	mesh.rotation = Vector3(0, rotation_y - PI / 2.0, 0)
	if weapon_mesh != null:
		weapon_mesh.position = position
		weapon_mesh.rotation = Vector3(0, rotation_y - PI / 2.0, 0)


# ---------------------------------------------------------------- Health bar

func _create_health_bar() -> void:
	if _bar_material == null:
		_bar_material = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = HEALTH_BAR_SHADER
		_bar_material.shader = sh
		_bar_quad = QuadMesh.new()
		_bar_quad.size = Vector2(1, 1)
		_bar_font = SystemFont.new()
		_bar_font.font_names = PackedStringArray(["Arial", "Segoe UI", "sans-serif"])
		_bar_font.font_weight = 700
	hp_bar = Node3D.new()
	_hp_quad = MeshInstance3D.new()
	_hp_quad.mesh = _bar_quad
	_hp_quad.material_override = _bar_material
	_hp_quad.scale = Vector3(80, 20, 1)
	_hp_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hp_bar.add_child(_hp_quad)
	_hp_name = _make_label(18, HORIZONTAL_ALIGNMENT_LEFT, Vector2(18 - 128, 32 - 20), Color(1, 1, 1))
	_hp_text = _make_label(16, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(238 - 128, 32 - 20), Effects.canvas_color("#cbd5e1"))
	hp_bar.add_child(_hp_name)
	hp_bar.add_child(_hp_text)
	_hp_name.text = name if name != "" else "MONSTER"
	game.world_root.add_child(hp_bar)
	update_health_bar()


func _make_label(size: int, align: int, offset: Vector2, color: Color) -> Label3D:
	var l := Label3D.new()
	l.font = _bar_font
	l.font_size = size
	l.pixel_size = 80.0 / 256.0
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.offset = offset
	l.modulate = color
	l.outline_size = 0
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.render_priority = 2
	return l


func update_health_bar() -> void:
	if hp_bar == null:
		return
	var max_hp: float = config.maxHealth
	var hp := maxf(0.0, ceilf(health))
	var pct := clampf(health / max_hp, 0.0, 1.0)
	var fill := Color(0x22 / 255.0, 0xc5 / 255.0, 0x5e / 255.0)
	if pct < 0.25:
		fill = Color(0xef / 255.0, 0x44 / 255.0, 0x44 / 255.0)
	elif pct < 0.55:
		fill = Color(0xea / 255.0, 0xb3 / 255.0, 0x08 / 255.0)
	_hp_quad.set_instance_shader_parameter("pct", pct)
	_hp_quad.set_instance_shader_parameter("fill_color", fill)
	_hp_text.text = "%d / %d" % [int(hp), int(max_hp)]


func free_nodes() -> void:
	if is_instance_valid(mesh):
		mesh.queue_free()
	if weapon_mesh != null and is_instance_valid(weapon_mesh):
		weapon_mesh.queue_free()
	if hp_bar != null and is_instance_valid(hp_bar):
		hp_bar.queue_free()


# ---------------------------------------------------------------- Animation

func set_animation(anim: Dictionary, force_reset: bool = false) -> void:
	if anim.is_empty():
		return
	if current_anim.name == anim.name and not force_reset:
		return
	if not force_reset and not current_anim.is_empty():
		prev_pose = get_current_pose()
		fade_timer = 0.0
	else:
		prev_pose = []
	current_anim = anim
	anim_timer = 0.0
	anim_complete = false


# [frameA, frameB, alpha]
func get_current_pose() -> Array:
	var anim := current_anim
	var total: int = anim.end - anim.start + 1
	var progress: float = anim_timer * anim.fps
	var frame_offset: int
	var next_offset: int
	var alpha: float
	if anim.loop:
		var idx := fmod(progress, total)
		frame_offset = floori(idx)
		next_offset = (frame_offset + 1) % total
		alpha = idx - frame_offset
	else:
		var idx := minf(progress, total - 1)
		frame_offset = floori(idx)
		next_offset = mini(frame_offset + 1, total - 1)
		alpha = idx - frame_offset
	return [anim.start + frame_offset, anim.start + next_offset, alpha]


func _update_morph_targets(delta: float) -> void:
	anim_timer += delta
	var anim := current_anim
	var total: int = anim.end - anim.start + 1
	if not anim.loop and anim_timer >= total / anim.fps:
		anim_complete = true
	var cur := get_current_pose()
	var frames: Array = []
	var weights: Array = []
	var add := func(frame: int, w: float) -> void:
		var k := frames.find(frame)
		if k != -1:
			weights[k] += w
		else:
			frames.append(frame)
			weights.append(w)
	if not prev_pose.is_empty() and fade_timer < fade_duration:
		fade_timer += delta
		var blend := minf(1.0, fade_timer / fade_duration)
		var inv := 1.0 - blend
		add.call(prev_pose[0], (1.0 - prev_pose[2]) * inv)
		add.call(prev_pose[1], prev_pose[2] * inv)
		add.call(cur[0], (1.0 - cur[2]) * blend)
		add.call(cur[1], cur[2] * blend)
	else:
		prev_pose = []
		add.call(cur[0], 1.0 - cur[2])
		if cur[2] > 1e-4:
			add.call(cur[1], cur[2])
	var kept_f: Array = []
	var kept_w: Array = []
	for k in frames.size():
		if frames[k] < 0 or weights[k] <= 0.001:
			continue
		kept_f.append(frames[k])
		kept_w.append(weights[k])
	model.set_pose(mesh, kept_f, kept_w)
	if weapon_model != null and weapon_mesh is GeometryInstance3D:
		weapon_model.set_pose(weapon_mesh, kept_f, kept_w)


func _update_bounding_box() -> void:
	if state == State.DEATH:
		bbox.make_empty()
		return
	var frame: int = get_current_pose()[0]
	var local := model.frame_aabb(frame)
	var xf := Transform3D(Basis(Vector3.UP, rotation_y - PI / 2.0).scaled(Vector3(scale, scale, scale)), position)
	bbox.make_empty()
	for i in 8:
		bbox.expand(xf * local.get_endpoint(i))


# ---------------------------------------------------------------- AI

func _play_noise(dist: float) -> void:
	if dist > 1200.0:
		return
	var f: String = config.get("yellSound", "")
	if f == "":
		f = config.get("sound", "goblin.wav")
	game.audio.play_sound(f, maxf(0.05, (1.0 - dist / 1200.0) * 0.7))


func _tick_ambient_noise(dt: float, dist: float) -> void:
	noise_timer -= dt
	if noise_timer <= 0.0:
		noise_timer = 5.0 + randf() * 10.0
		_play_noise(dist)


func _resolve(with_others: bool, player_pos: Vector3) -> void:
	var cw: CollisionWorld = game.collision
	is_grounded = cw.resolve_capsule_world(position, CollisionWorld.MONSTER_FOOT_OFFSET, CollisionWorld.MONSTER_CAPSULE_RADIUS,
		CollisionWorld.MONSTER_CAPSULE_HEIGHT, velocity, true, self, game.monsters if with_others else [], with_others, player_pos)
	position = cw.out_pos
	velocity = cw.out_vel


func update(delta: float, player_pos: Vector3) -> void:
	var dt := minf(delta, 0.1)
	var dx := player_pos.x - position.x
	var dz := player_pos.z - position.z
	var dist_sq := dx * dx + dz * dz
	var dist := sqrt(dist_sq)

	if hp_bar != null:
		if state == State.DEATH or dist > 2200.0:
			hp_bar.visible = false
		else:
			hp_bar.visible = true
			hp_bar.position = Vector3(position.x, position.y + health_bar_height, position.z)

	if is_grounded:
		if state == State.DEATH and anim_complete and weapon_mesh == null:
			return
		if state == State.IDLE and dist_sq > config.aggroRadius * config.aggroRadius:
			_tick_ambient_noise(dt, dist)
			if dist_sq <= 3000.0 * 3000.0:
				_update_morph_targets(dt)
				_update_bounding_box()
			return

	var est_dy := absf(velocity.y * dt)
	var sub_steps := maxi(1, ceili(est_dy / 12.0))
	var sub_dt := dt / sub_steps
	for s in sub_steps:
		velocity.y -= 1600.0 * sub_dt
		position.y += velocity.y * sub_dt
		_resolve(false, player_pos)
		if is_grounded:
			break

	if state == State.DEATH:
		mesh.position = position
		if weapon_mesh != null:
			game.remove_level_object(weapon_mesh)
			weapon_mesh.queue_free()
			weapon_mesh = null
		_update_morph_targets(dt)
		_update_bounding_box()
		return

	state_timer += dt
	if attack_cooldown > 0.0:
		attack_cooldown = maxf(0.0, attack_cooldown - dt)
	var target_angle := atan2(dx, dz)
	_tick_ambient_noise(dt, dist)

	var los: bool = not config.canCastSpells
	if config.canCastSpells and state != State.IDLE and dist <= config.attackRange:
		los_timer -= dt
		if los_timer <= 0.0:
			los_timer = 0.12 + randf() * 0.06
			has_los = game.collision.has_line_of_sight(position + Vector3(0, 40, 0), player_pos + Vector3(0, 20, 0))
		los = has_los

	match state:
		State.IDLE:
			set_animation(ANIMS.STAND)
			if dist <= config.aggroRadius:
				set_state(State.ALERT)
		State.ALERT:
			set_animation(ANIMS.STAND)
			_smooth_turn(target_angle, dt)
			if dist > config.deaggroRadius:
				set_state(State.IDLE)
			elif dist <= config.attackRange and los:
				set_state(State.ATTACK)
			elif state_timer >= config.alertDuration:
				set_state(State.CHASE)
		State.CHASE:
			_smooth_turn(target_angle, dt)
			if dist <= config.attackRange and los:
				if attack_cooldown <= 0.0:
					set_state(State.ATTACK)
				elif config.canCastSpells:
					set_animation(ANIMS.RUN)
					_tactical_movement(dt, dist, player_pos)
				else:
					set_animation(ANIMS.STAND)
			elif dist > config.deaggroRadius:
				set_state(State.IDLE)
			else:
				set_animation(ANIMS.RUN)
				if dist > config.stopDistance:
					_move_forward(dt, player_pos)
				elif config.canCastSpells:
					_tactical_movement(dt, dist, player_pos)
		State.ATTACK:
			set_animation(ANIMS.ATTACK)
			_smooth_turn(target_angle, dt)
			if not has_dealt_damage:
				var anim := current_anim
				var total_duration: float = (anim.end - anim.start + 1) / anim.fps
				if config.canCastSpells and not is_melee_attack:
					var spell_color := 0xff5500 if pending_spell == "FIREBALL" else (0x00ffff if pending_spell == "LIGHTNING" else 0x38bdf8)
					for p in 3:
						var off := randf() * TAU
						var rad := 15.0 + randf() * 20.0
						game.fx.emit_particle(position.x + cos(off) * rad, position.y + 40.0 + (randf() - 0.5) * 20.0,
							position.z + sin(off) * rad, (randf() - 0.5) * 40.0, 40.0 + randf() * 60.0, (randf() - 0.5) * 40.0,
							spell_color, 10.0, 0.4)
					if anim_timer >= total_duration * 0.5:
						has_dealt_damage = true
						game.launch_monster_projectile(self, pending_spell if pending_spell != "" else "MAGIC MISSILE", player_pos)
				else:
					if anim_timer >= total_duration * 0.5:
						has_dealt_damage = true
						var ws: String = config.get("weaponSound", "swish4.wav")
						if dist <= 1200.0:
							game.audio.play_sound(ws, maxf(0.05, (1.0 - dist / 1200.0) * 0.7))
						if dist <= 115.0 + 20.0:
							game.damage_player(config.damage)
			if anim_complete:
				attack_cooldown = config.spellCooldown if config.spellCooldown > 0.0 else 0.5
				has_dealt_damage = false
				pending_spell = ""
				set_state(State.CHASE if dist <= config.deaggroRadius else State.IDLE)
		State.HURT:
			if anim_complete:
				set_state(State.CHASE)

	_sync_transforms()
	_update_morph_targets(dt)
	_update_bounding_box()


func _tactical_movement(dt: float, dist: float, player_pos: Vector3) -> void:
	strafe_timer -= dt
	if strafe_timer <= 0.0:
		strafe_dir = 1.0 if randf() < 0.5 else -1.0
		strafe_timer = 1.0 + randf() * 1.5
	var dx := player_pos.x - position.x
	var dz := player_pos.z - position.z
	var length := sqrt(dx * dx + dz * dz)
	if length < 0.001:
		return
	var move_x := (-dz / length) * strafe_dir
	var move_z := (dx / length) * strafe_dir
	var stop_dist: float = config.stopDistance if config.stopDistance > 0.0 else 250.0
	if dist < stop_dist * 0.8:
		move_x -= (dx / length) * 0.7
		move_z -= (dz / length) * 0.7
	var speed: float = config.moveSpeed * 0.65
	position.x += move_x * speed * dt
	position.z += move_z * speed * dt
	_resolve(true, player_pos)


func _smooth_turn(target_angle: float, dt: float) -> void:
	var diff := target_angle - rotation_y
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	var max_turn: float = config.turnRate * dt
	rotation_y += clampf(diff, -max_turn, max_turn)


func _move_forward(dt: float, player_pos: Vector3) -> void:
	var move_dist: float = config.moveSpeed * dt
	position.x += sin(rotation_y) * move_dist
	position.z += cos(rotation_y) * move_dist
	_resolve(true, player_pos)


func set_state(new_state: int) -> void:
	if state == new_state or state == State.DEATH:
		return
	var old_state := state
	state = new_state
	dead = new_state == State.DEATH
	state_timer = 0.0
	var player_pos: Vector3 = game.player_position()
	if new_state == State.ATTACK:
		has_dealt_damage = false
		var d := position.distance_to(player_pos)
		if config.canCastSpells and d <= 115.0:
			is_melee_attack = true
			pending_spell = ""
		elif config.canCastSpells and not config.spells.is_empty():
			is_melee_attack = false
			pending_spell = config.spells[randi() % config.spells.size()]
			if pending_spell == "MAGIC MISSILE":
				game.audio.play_sound("spell1.wav", 0.8)
			elif pending_spell == "FIREBALL":
				game.audio.play_sound("fireball.wav", 0.8)
			elif pending_spell == "LIGHTNING":
				game.audio.play_sound("spell3.wav", 0.8)
		else:
			is_melee_attack = true
			pending_spell = ""
	if old_state == State.IDLE and (new_state == State.ALERT or new_state == State.CHASE):
		_play_noise(position.distance_to(player_pos))


func take_damage(damage: float) -> void:
	if state == State.DEATH:
		return
	health -= damage
	update_health_bar()
	var dist := position.distance_to(game.player_position())
	var volume := maxf(0.05, (1.0 - dist / 1200.0) * 0.7) if dist <= 1200.0 else 0.0
	if health <= 0.0:
		health = 0.0
		update_health_bar()
		set_state(State.DEATH)
		bbox.make_empty()
		var deaths := [ANIMS.DEATH1, ANIMS.DEATH2, ANIMS.DEATH3]
		set_animation(deaths[randi() % 3], true)
		if dist <= 1200.0:
			game.audio.play_sound(config.get("deathSound", "die.wav"), volume)
		game.drop_treasure(position)
		game.award_player_xp(config.maxHealth * 2)
		if dist <= 600.0:
			game.vibrate(150, 0.7, 0.5)
	else:
		set_state(State.HURT)
		var pains := [ANIMS.PAIN1, ANIMS.PAIN2, ANIMS.PAIN3]
		set_animation(pains[randi() % 3], true)
		if dist <= 1200.0:
			game.audio.play_sound(config.get("painSound", "impact.wav"), volume)
		if dist <= 600.0:
			game.vibrate(110, 0.6, 0.35)


# Restores a saved monster (dead ones stay on the floor in their final death pose).
func restore_snapshot(s: Dictionary) -> void:
	position = Vector3(s.x, s.y, s.z)
	rotation_y = s.r
	_sync_transforms()
	health = clampf(s.hp, 0.0, config.maxHealth)
	if int(s.get("d", 0)) == 0 and health > 0.0:
		update_health_bar()
		return
	health = 0.0
	state = State.DEATH
	dead = true
	set_animation(ANIMS.DEATH1, true)
	anim_timer = 1e6
	if weapon_mesh != null:
		game.remove_level_object(weapon_mesh)
		weapon_mesh.queue_free()
		weapon_mesh = null
	_update_morph_targets(0.0)
	bbox.make_empty()
	update_health_bar()
	if hp_bar != null:
		hp_bar.visible = false
