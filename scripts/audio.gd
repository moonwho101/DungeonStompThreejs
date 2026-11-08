# Sound effects, music and the synthesized pickup chime (port of the audio code in logic.js).
class_name AudioManager
extends Node

const MAX_CONCURRENT_SOUNDS := 24
const MUSIC_TRACKS := ["Midi/d1.wav", "Midi/d2.wav", "Midi/d3.wav", "Midi/d4.wav"]

var _streams: Dictionary = {} # rel path -> AudioStream or null
var _players: Array = []
var music_enabled := true
var _music_player: AudioStreamPlayer
var _music_playing := false
var _music_delay := 0.0
var _last_song := -1
var _pickup_streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in MAX_CONCURRENT_SOUNDS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)


func _load_stream(rel: String) -> AudioStream:
	if _streams.has(rel):
		return _streams[rel]
	var stream: AudioStream = null
	var abs_path := DataPaths.path(rel)
	if FileAccess.file_exists(abs_path):
		stream = load_wav(FileAccess.get_file_as_bytes(abs_path))
	_streams[rel] = stream
	return stream


const IMA_STEPS := [7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73,
	80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658,
	724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026,
	4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350,
	22385, 24623, 27086, 29794, 32767]
const IMA_INDEX := [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]


# Browsers decode these WAVs even though many have odd-sized chunks without padding and trailing
# garbage, and two are IMA-ADPCM. The chunks are parsed tolerantly here and re-wrapped in a clean
# PCM header so Godot's native loader can convert them.
static func load_wav(bytes: PackedByteArray) -> AudioStreamWAV:
	if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var p := 12
	var fmt_tag := -1
	var channels := 1
	var rate := 22050
	var bits := 8
	var block_align := 0
	var samples_per_block := 0
	var data_off := -1
	var data_size := 0
	while p + 8 <= bytes.size():
		var cid := bytes.slice(p, p + 4).get_string_from_ascii()
		var sz := bytes.decode_u32(p + 4)
		if cid == "fmt " and p + 24 <= bytes.size():
			fmt_tag = bytes.decode_u16(p + 8)
			channels = bytes.decode_u16(p + 10)
			rate = bytes.decode_u32(p + 12)
			block_align = bytes.decode_u16(p + 20)
			bits = bytes.decode_u16(p + 22)
			if fmt_tag == 17 and sz >= 20 and p + 28 <= bytes.size():
				samples_per_block = bytes.decode_u16(p + 26)
		elif cid == "data":
			data_off = p + 8
			data_size = mini(sz, bytes.size() - data_off)
			break
		p += 8 + sz + (sz & 1)
	if data_off < 0 or fmt_tag == -1 or channels < 1:
		return null
	var data := bytes.slice(data_off, data_off + data_size)
	if fmt_tag == 17:
		data = _decode_ima_adpcm(data, channels, block_align, samples_per_block)
		bits = 16
	elif fmt_tag != 1:
		return null
	var pad := data.size() & 1
	var out := PackedByteArray()
	out.resize(44)
	out.encode_u32(0, 0x46464952) # RIFF
	out.encode_u32(4, 36 + data.size() + pad)
	out.encode_u32(8, 0x45564157) # WAVE
	out.encode_u32(12, 0x20746d66) # "fmt "
	out.encode_u32(16, 16)
	out.encode_u16(20, 1)
	out.encode_u16(22, channels)
	out.encode_u32(24, rate)
	out.encode_u32(28, rate * channels * (bits / 8))
	out.encode_u16(32, channels * (bits / 8))
	out.encode_u16(34, bits)
	out.encode_u32(36, 0x61746164) # data
	out.encode_u32(40, data.size())
	out.append_array(data)
	if pad:
		out.append(0)
	return AudioStreamWAV.load_from_buffer(out)


static func _decode_ima_adpcm(data: PackedByteArray, channels: int, block_align: int, samples_per_block: int) -> PackedByteArray:
	var out := PackedByteArray()
	if block_align <= 4 * channels:
		return out
	if samples_per_block <= 0:
		samples_per_block = (block_align - 4 * channels) * 8 / (4 * channels) + 1
	var pcm := PackedInt32Array()
	var pos := 0
	while pos + 4 * channels <= data.size():
		var block_end := mini(pos + block_align, data.size())
		var pred := PackedInt32Array()
		var idx := PackedInt32Array()
		pred.resize(channels)
		idx.resize(channels)
		for ch in channels:
			pred[ch] = data.decode_s16(pos)
			idx[ch] = clampi(data[pos + 2], 0, 88)
			pos += 4
		var block_samples := PackedInt32Array()
		block_samples.resize(samples_per_block * channels)
		for ch in channels:
			block_samples[ch] = pred[ch]
		var written := PackedInt32Array()
		written.resize(channels)
		for ch in channels:
			written[ch] = 1
		var chunk_i := 0
		while pos < block_end:
			# Mono: every byte holds two samples. Stereo: 4 bytes (8 samples) per channel, interleaved.
			var ch := 0
			var count := 1
			if channels > 1:
				ch = chunk_i % channels
				count = 4
			chunk_i += 1
			for b in count:
				if pos >= block_end:
					break
				var byte := data[pos]
				pos += 1
				for nib in [byte & 0x0F, byte >> 4]:
					var step: int = IMA_STEPS[idx[ch]]
					var diff := step >> 3
					if nib & 1: diff += step >> 2
					if nib & 2: diff += step >> 1
					if nib & 4: diff += step
					pred[ch] = clampi(pred[ch] - diff if nib & 8 else pred[ch] + diff, -32768, 32767)
					idx[ch] = clampi(idx[ch] + IMA_INDEX[nib], 0, 88)
					if written[ch] < samples_per_block:
						block_samples[written[ch] * channels + ch] = pred[ch]
						written[ch] += 1
		var frames := samples_per_block
		for ch in channels:
			frames = mini(frames, written[ch])
		for i in frames * channels:
			pcm.append(block_samples[i])
		pos = block_end
	out.resize(pcm.size() * 2)
	for i in pcm.size():
		out.encode_s16(i * 2, pcm[i])
	return out


static func _rel(filename: String) -> String:
	if filename.begins_with("Sounds/") or filename.begins_with("Midi/"):
		return filename
	return "Sounds/" + filename


func preload_sounds(names: Array) -> void:
	for n in names:
		if n != null and str(n) != "":
			_load_stream(_rel(str(n)))


func play_sound(filename: String, volume: float = 1.0) -> void:
	if filename == "":
		return
	var stream := _load_stream(_rel(filename))
	if stream == null:
		return
	_play_stream(stream, volume)


func _play_stream(stream: AudioStream, volume: float) -> void:
	for p: AudioStreamPlayer in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(clampf(volume, 0.0001, 1.0)) if volume > 0.0 else -80.0
			p.play()
			return


static func random_sound(list: Array) -> String:
	if list.is_empty():
		return ""
	return list[randi() % list.size()]


# ---------------------------------------------------------------- Music

func is_music_on() -> bool:
	return music_enabled


func stop_music() -> void:
	_music_player.stop()
	_music_playing = false


func toggle_music() -> bool:
	music_enabled = not music_enabled
	if not music_enabled:
		stop_music()
	else:
		_music_delay = 0.0
	return music_enabled


func start_next_music_track() -> void:
	stop_music()
	if not music_enabled:
		return
	var available: Array = range(MUSIC_TRACKS.size())
	if _last_song != -1 and MUSIC_TRACKS.size() > 1:
		available.erase(_last_song)
	var next_index: int = available[randi() % available.size()]
	_last_song = next_index
	var stream := _load_stream(MUSIC_TRACKS[next_index])
	if stream == null:
		_music_delay = 10.0
		return
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(0.4)
	_music_player.play()
	_music_playing = true


func _on_music_finished() -> void:
	_music_playing = false
	_music_delay = 10.0 + randf() * 20.0


func update_music(delta: float) -> void:
	if not music_enabled:
		return
	if not _music_playing:
		if _music_delay > 0.0:
			_music_delay -= delta
		else:
			start_next_music_track()


func set_paused(paused: bool) -> void:
	_music_player.stream_paused = paused


# ---------------------------------------------------------------- Pickup chime

# Two-oscillator arpeggio with an exponential fade, like playPickupSound's WebAudio graph.
func _make_pickup_stream(is_health: bool) -> AudioStreamWAV:
	var rate := 44100
	var dur := 0.45
	var n := int(rate * dur)
	var f := [523.25, 659.25, 783.99] if is_health else [659.25, 880.0, 1046.5]
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph1 := 0.0
	var ph2 := 0.0
	for i in n:
		var t := float(i) / rate
		var step := 0 if t < 0.08 else (1 if t < 0.16 else 2)
		var f1: float = f[step]
		var f2: float = f1 * 1.5
		ph1 = fmod(ph1 + f1 / rate, 1.0)
		ph2 = fmod(ph2 + f2 / rate, 1.0)
		var o1 := sin(ph1 * TAU) if is_health else (1.0 - 4.0 * absf(ph1 - 0.5))
		var o2 := sin(ph2 * TAU)
		var gain := 0.3 * pow(0.001 / 0.3, t / dur)
		var s := clampf((o1 + o2) * gain, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func play_pickup_sound(is_health: bool = true) -> void:
	if not _pickup_streams.has(is_health):
		_pickup_streams[is_health] = _make_pickup_stream(is_health)
	_play_stream(_pickup_streams[is_health], 1.0)
