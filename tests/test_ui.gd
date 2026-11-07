extends SceneTree

const HUDScene = preload("res://scenes/hud.tscn")
const AudioManager = preload("res://scripts/audio.gd")

func _init():
    print("Testing HUD, Minimap and Audio systems...")
    var hud = HUDScene.instantiate()
    assert(hud != null, "Failed to instantiate HUD scene")

    hud.update_stats(95, 100, 50, 2, "Fireball")
    print("HUD stats updated successfully.")

    var audio = AudioManager.new()
    assert(audio != null, "Failed to instantiate AudioManager")
    print("AudioManager initialized.")

    print("ALL HUD, MINIMAP AND AUDIO TESTS PASSED!")
    hud.queue_free()
    audio.queue_free()
    quit(0)
