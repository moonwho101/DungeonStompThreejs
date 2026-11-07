extends SceneTree

const CollisionSystem = preload("res://scripts/collision.gd")

func _init():
    print("Testing collision system...")
    var col = CollisionSystem.new()
    # Add a floor quad as two triangles at y = 0
    col.add_triangle(Vector3(0, 0, 0), Vector3(500, 0, 0), Vector3(500, 0, 500))
    col.add_triangle(Vector3(0, 0, 0), Vector3(500, 0, 500), Vector3(0, 0, 500))
    col.build_grid()

    print("Triangles in collision:", col.triangles.size())
    assert(col.triangles.size() == 2, "Expected 2 collision triangles")

    # Capsule test where player feet penetrate below floor y=0:
    # eye_height = 100, so if pos.y = 80, feet are at -20, intersecting floor at y=0
    var pos = Vector3(250, 80, 250)
    var vel = Vector3(0, -100, 0)
    var res = col.resolve_capsule(pos, CollisionSystem.CAPSULE_RADIUS, CollisionSystem.CAPSULE_HEIGHT, vel, CollisionSystem.EYE_HEIGHT)
    print("Collision result grounded:", res.grounded, "New pos:", res.position)
    assert(res.grounded, "Capsule should be grounded on floor")
    assert(res.position.y >= 99.0, "Capsule should be lifted so eye is near 100")

    # Line of sight test in open space
    var los1 = col.has_line_of_sight(Vector3(100, 100, 100), Vector3(400, 100, 400))
    print("Line of sight open air:", los1)
    assert(los1, "Should have line of sight in open air")

    print("ALL COLLISION TESTS PASSED!")
    quit(0)
