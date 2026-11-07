extends SceneTree

const Player = preload("res://scripts/player.gd")
const Monster = preload("res://scripts/monster.gd")
const CollisionSystem = preload("res://scripts/collision.gd")

func _init():
    print("Testing player and monster systems...")
    var col = CollisionSystem.new()
    col.add_triangle(Vector3(-1000, 0, -1000), Vector3(1000, 0, -1000), Vector3(1000, 0, 1000))
    col.add_triangle(Vector3(-1000, 0, -1000), Vector3(1000, 0, 1000), Vector3(-1000, 0, 1000))
    col.build_grid()

    # Test Player
    var player = Player.new()
    player.collision_system = col
    player.position = Vector3(0, 100, 0)
    print("Player initial weapon:", player.get_current_weapon_name())
    assert(player.get_current_weapon_name() == "Axe", "Expected default weapon Axe")

    player.cycle_weapon(1)
    print("Player cycled weapon:", player.get_current_weapon_name())
    assert(player.get_current_weapon_name() == "Flamesword", "Expected cycled weapon Flamesword")

    player.take_damage(20)
    assert(player.hp == 80, "Expected 80 HP after 20 damage")

    # Test Monster
    var monster = Monster.new()
    monster.collision_system = col
    monster.position = Vector3(0, 50, 100)
    assert(monster.state == Monster.State.IDLE, "Expected initial state IDLE")

    # Update AI within aggro range
    monster.update_ai(0.1, player.position)
    print("Monster state after aggro:", monster.state)
    assert(monster.state == Monster.State.ALERT or monster.state == Monster.State.CHASE, "Monster should alert/chase")

    monster.take_damage(100)
    assert(monster.state == Monster.State.DEATH, "Monster should be in DEATH state")

    print("ALL PLAYER AND MONSTER TESTS PASSED!")
    quit(0)
