# Audio manager for Dungeon Stomp Godot 4.7.2
class_name AudioManager
extends Node

var sound_cache: Dictionary = {}

func play_sound(sound_name: String) -> void:
	var path = "res://Sounds/" + sound_name
	if not path.ends_with(".wav") and not path.ends_with(".WAV"):
		path += ".wav"

	if not FileAccess.file_exists(path):
		var upper_path = path.replace(".wav", ".WAV")
		if FileAccess.file_exists(upper_path):
			path = upper_path
		else:
			return

	var stream: AudioStreamWAV = null
	if sound_cache.has(path):
		stream = sound_cache[path]
	elif ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStreamWAV:
			stream = res
			sound_cache[path] = stream
	else:
		# Direct WAV loading fallback
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var bytes = file.get_buffer(file.get_length())
			stream = AudioStreamWAV.new()
			stream.data = bytes
			sound_cache[path] = stream

	if stream:
		var player = AudioStreamPlayer.new()
		player.stream = stream
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
