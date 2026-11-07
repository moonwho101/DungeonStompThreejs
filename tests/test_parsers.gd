extends SceneTree

const Parsers = preload("res://scripts/parsers.gd")
const DungeonGenerator = preload("res://scripts/generator.gd")

func _init():
    print("Testing parsers...")
    var tex_mgr = Parsers.TextureManager.new()
    tex_mgr.load_textures_dat("bin/textures.dat")
    print("Loaded aliases:", tex_mgr.aliases.size())
    assert(tex_mgr.aliases.size() > 0, "No texture aliases loaded!")

    var obj_parser = Parsers.ObjectsDatParser.new()
    var objs = obj_parser.parse("bin/ObjectsAll.dat")
    print("Loaded 3D object definitions:", objs.size())
    assert(objs.size() > 0, "No objects parsed!")

    var map_text = DungeonGenerator.generate_dungeon(20, 20, 6, 42)
    var map_parser = Parsers.LevelMapParser.new()
    var ok = map_parser.parse_text(map_text)
    print("Map parse success:", ok, "Instances:", map_parser.instances.size(), "StartPos:", map_parser.start_pos)
    assert(ok and map_parser.instances.size() > 0, "Failed to parse generated dungeon!")

    print("ALL PARSER AND GENERATOR TESTS PASSED!")
    quit(0)
