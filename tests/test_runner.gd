extends SceneTree

const Parsers = preload("res://scripts/parsers.gd")
const DungeonGenerator = preload("res://scripts/generator.gd")
const CollisionSystem = preload("res://scripts/collision.gd")
const PlayerClass = preload("res://scripts/player.gd")
const MonsterClass = preload("res://scripts/monster.gd")

func _init():
    print("========================================")
    print("RUNNING DUNGEON STOMP GODOT 4.7.2 TEST SUITE")
    print("========================================")

    # 1. Parsers Test
    print("[1/4] Testing Parsers...")
    var tex_mgr = Parsers.TextureManager.new()
    tex_mgr.load_textures_dat("bin/textures.dat")
    assert(tex_mgr.aliases.size() > 0, "Textures dat aliases empty!")
    print("  -> Textures aliases loaded:", tex_mgr.aliases.size())

    var obj_parser = Parsers.ObjectsDatParser.new()
    var objs = obj_parser.parse("bin/ObjectsAll.dat")
    assert(objs.size() > 0, "Objects dat parsed 0 definitions!")
    print("  -> Objects definitions parsed:", objs.size())

    # 2. Generator Test
    print("[2/4] Testing Dungeon Generator...")
    var level_text = DungeonGenerator.generate_dungeon(20, 20, 6, 12345)
    var map_parser = Parsers.LevelMapParser.new()
    var parsed = map_parser.parse_text(level_text)
    assert(parsed and map_parser.instances.size() > 0, "Level map parsing failed!")
    print("  -> Dungeon instances generated:", map_parser.instances.size())

    # 3. Collision Test
    print("[3/4] Testing Collision System...")
    var col = CollisionSystem.new()
    col.add_triangle(Vector3(0, 0, 0), Vector3(400, 0, 0), Vector3(400, 0, 400))
    col.add_triangle(Vector3(0, 0, 0), Vector3(400, 0, 400), Vector3(0, 0, 400))
    col.build_grid()

    var falling_pos = Vector3(200, 80, 200)
    var vel = Vector3(0, -200, 0)
    var res = col.resolve_capsule(falling_pos, CollisionSystem.CAPSULE_RADIUS, CollisionSystem.CAPSULE_HEIGHT, vel, CollisionSystem.EYE_HEIGHT)
    assert(res.grounded, "Capsule collision should ground on floor!")
    print("  -> Grounded collision resolved at pos:", res.position)

    # 4. Entities & Combat Test
    print("[4/4] Testing Entities & Combat...")
    var player = PlayerClass.new()
    player.position = Vector3(0, 100, 0)
    assert(player.get_current_weapon_name() == "Axe", "Default weapon mismatch")
    player.cycle_weapon(1)
    assert(player.get_current_weapon_name() == "Flamesword", "Cycled weapon mismatch")
    player.take_damage(25)
    assert(player.hp == 75, "Player HP calculation mismatch")

    var monster = MonsterClass.new()
    monster.position = Vector3(0, 50, 80)
    monster.update_ai(0.1, player.position)
    assert(monster.state != MonsterClass.State.IDLE, "Monster should alert or chase player")
    monster.take_damage(100)
    assert(monster.state == MonsterClass.State.DEATH, "Monster should be dead")
    print("  -> Player & Monster combat cycle verified successfully.")

    print("========================================")
    print("ALL TESTS PASSED SUCCESSFULLY! (4/4)")
    print("========================================")
    quit(0)
