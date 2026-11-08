# Headless test suite: godot --headless --path . -s res://tests/test_runner.gd
extends SceneTree

var _failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_failures += 1
		printerr("  FAIL ", msg)


func _init() -> void:
	print("Dungeon Stomp Godot tests")

	var tm := Parsers.TextureManager.new()
	tm.load_textures_dat("bin/textures.dat")
	check(tm.aliases.size() > 100, "textures.dat aliases loaded (%d)" % tm.aliases.size())

	var objs := Parsers.ObjectsDatParser.new()
	objs.parse("bin/Objects.dat")
	check(objs.objects.size() > 100, "Objects.dat definitions parsed (%d)" % objs.objects.size())
	var corridor: Parsers.ObjectDef = null
	for id in objs.objects:
		if objs.objects[id].name.to_lower() == "corridor01":
			corridor = objs.objects[id]
			break
	var tri_count := 0
	if corridor != null:
		for p: Parsers.ObjectPoly in corridor.polys:
			tri_count += p.verts.size() / 15
	check(tri_count == 96, "CORRIDOR01 has 96 triangles (%d)" % tri_count)

	var models := Parsers.ModelListParser.new()
	models.parse("bin/modellist.dat")
	var goblin := models.get_model_by_name("GOBLIN")
	check(goblin != null and goblin.is_md2() and goblin.monster_weapon == "GOBLINAXE", "modellist GOBLIN entry")

	var level := Parsers.LevelMapParser.new()
	level.parse_file("bin/level1.map")
	check(level.instances.size() == 1991, "level1.map instances (%d)" % level.instances.size())
	check(level.start_pos == Vector3(5200, 128, 2600), "level1.map start position")

	var a := DungeonGenerator.generate({"numObjectsToPlace": 150, "seed": "test-seed"})
	var b := DungeonGenerator.generate({"numObjectsToPlace": 150, "seed": "test-seed"})
	check(a != "" and a == b, "seeded generator is deterministic")
	check(a.contains("spiral") and a.begins_with("OBJECT startpos"), "generated map has start and exit portal")
	check(DungeonGenerator.imul(0xFFFFFFFF, 5) == 0xFFFFFFFB, "imul matches Math.imul")

	var cw := CollisionWorld.new()
	cw.add_triangle(Vector3(0, 0, 0), Vector3(0, 0, 500), Vector3(500, 0, 500))
	cw.add_triangle(Vector3(0, 0, 0), Vector3(500, 0, 500), Vector3(500, 0, 0))
	cw.build_grid()
	var grounded := cw.resolve_capsule_world(Vector3(250, 80, 250), CollisionWorld.EYE_HEIGHT, CollisionWorld.CAPSULE_RADIUS,
		CollisionWorld.CAPSULE_HEIGHT, Vector3(0, -100, 0), true, null, [], false, Vector3.ZERO)
	check(grounded and absf(cw.out_pos.y - 100.0) < 1.0, "capsule lands on floor (y=%.2f)" % cw.out_pos.y)
	check(cw.out_vel.y >= 0.0, "downward velocity removed on landing")
	check(cw.has_line_of_sight(Vector3(100, 100, 100), Vector3(400, 100, 400)), "line of sight in open air")
	check(not cw.has_line_of_sight(Vector3(250, 50, 250), Vector3(250, -50, 250)), "floor blocks line of sight")

	var md2 := MD2Model.load_for_def(goblin)
	check(md2 != null and md2.frame_count >= 198, "goblin.md2 loads with all frames")
	var chest := TDSModel.load_for_def(models.get_model_by_name("cdoorclosedchest"))
	check(chest != null and chest.has_geometry, "chest .3ds loads")

	var wav := AudioManager.load_wav(FileAccess.get_file_as_bytes(DataPaths.path("Sounds/swish8.wav")))
	check(wav != null and wav.data.size() > 0, "IMA-ADPCM wav decodes")
	TDSModel.clear_cache()
	MD2Model.clear_cache()
	Materials.clear_caches()

	print("FAILED: %d" % _failures if _failures > 0 else "ALL TESTS PASSED")
	quit(1 if _failures > 0 else 0)
