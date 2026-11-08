# Gamepad / controller support (port of gamepad.js using Godot's standard joypad layout).
class_name GamepadInput
extends Node

const DEFAULT_SENSITIVITY := 2.8
const DEADZONE := 0.15
const LOOK_EXPONENT := 1.8
const MAX_PITCH := PI * 0.47
const MENU_REPEAT_DELAY := 0.32
const MENU_REPEAT_INTERVAL := 0.14

var game # Game
var sensitivity := DEFAULT_SENSITIVITY
var invert_y := false
var vibration_enabled := true

var _device := -1
var _prev: Dictionary = {}
var _l3_sprint := false
var _rt_was_down := false
var _nav_dir := 0
var _nav_timer := 0.0
var _horiz_dir := 0
var _horiz_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_changed)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		_device = pads[0]
	call_deferred("_update_display")


func set_sensitivity(v: float) -> void:
	if is_finite(v) and v > 0.1 and v <= 10.0:
		sensitivity = v


static func format_name(raw: String) -> String:
	if raw == "":
		return "Controller"
	var lower := raw.to_lower()
	if lower.contains("xbox") or lower.contains("xinput"):
		return "Xbox Controller"
	if lower.contains("dualsense") or lower.contains("ps5"):
		return "PlayStation DualSense"
	if lower.contains("dualshock") or lower.contains("ps4") or lower.contains("playstation") or lower.contains("wireless controller"):
		return "PlayStation Controller"
	if lower.contains("pro controller") or lower.contains("switch") or lower.contains("joy-con"):
		return "Nintendo Switch Controller"
	var clean := raw.split("(")[0].strip_edges()
	return clean if clean != "" else "Gamepad"


func _on_joy_changed(device: int, connected: bool) -> void:
	if connected:
		_device = device
		game.ui.toast("🎮 %s Connected" % format_name(Input.get_joy_name(device)))
		vibrate(80, 0.4, 0.2)
	else:
		if device == _device:
			var pads := Input.get_connected_joypads()
			_device = pads[0] if not pads.is_empty() else -1
		game.ui.toast("🎮 Controller Disconnected")
		_prev.clear()
	_update_display()


func _update_display() -> void:
	if game == null or game.ui == null:
		return
	if _device >= 0:
		game.ui.set_gamepad_display(format_name(Input.get_joy_name(_device)), true)
	else:
		game.ui.set_gamepad_display("None", false)


func vibrate(duration_ms: float, weak: float, strong: float) -> void:
	if not vibration_enabled:
		return
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), clampf(duration_ms, 10.0, 2000.0) / 1000.0)


static func deadzone_curve(x: float, y: float, deadzone: float, exponent: float) -> Vector3:
	var mag := Vector2(x, y).length()
	if mag <= deadzone:
		return Vector3.ZERO
	var n := minf(1.0, (mag - deadzone) / (1.0 - deadzone))
	var curved := pow(n, exponent)
	var sc := curved / mag
	return Vector3(x * sc, y * sc, curved)


func _down(button: int) -> bool:
	return _device >= 0 and Input.is_joy_button_pressed(_device, button)


func _just(button: int) -> bool:
	var d := _down(button)
	return d and not _prev.get(button, false)


func _record() -> void:
	for b in range(0, 21):
		_prev[b] = _down(b)


func _detect_active_device() -> void:
	for d in Input.get_connected_joypads():
		if d == _device:
			continue
		var active := false
		for b in range(0, 15):
			if Input.is_joy_button_pressed(d, b):
				active = true
				break
		if not active:
			for a in range(0, 4):
				if absf(Input.get_joy_axis(d, a)) > 0.35:
					active = true
					break
		if active:
			_device = d
			_prev.clear()
			game.ui.toast("🎮 %s Active" % format_name(Input.get_joy_name(d)))
			_update_display()
			return


func poll(delta: float, paused: bool) -> Dictionary:
	_detect_active_device()
	if _device < 0 or not (_device in Input.get_connected_joypads()):
		_prev.clear()
		return {}
	if paused:
		_menu_navigation(delta)
		_record()
		return {"in_menu": true}

	var left := deadzone_curve(Input.get_joy_axis(_device, JOY_AXIS_LEFT_X), Input.get_joy_axis(_device, JOY_AXIS_LEFT_Y), DEADZONE, 1.1)
	var right := deadzone_curve(Input.get_joy_axis(_device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(_device, JOY_AXIS_RIGHT_Y), 0.12, LOOK_EXPONENT)
	var lt := Input.get_joy_axis(_device, JOY_AXIS_TRIGGER_LEFT)
	var rt := Input.get_joy_axis(_device, JOY_AXIS_TRIGGER_RIGHT)

	if _just(JOY_BUTTON_LEFT_STICK):
		_l3_sprint = not _l3_sprint
		vibrate(40, 0.2, 0.05)
	if _l3_sprint and left.z < 0.05:
		_l3_sprint = false
	var jump := _just(JOY_BUTTON_A)
	if jump and not game.fly_mode:
		vibrate(40, 0.2, 0.05)
	var fly: bool = game.fly_mode
	var rt_down := rt > 0.4
	var attack := rt_down and not _rt_was_down
	_rt_was_down = rt_down
	var cycle := 0
	if _just(JOY_BUTTON_RIGHT_SHOULDER) or _just(JOY_BUTTON_DPAD_RIGHT) or _just(JOY_BUTTON_Y):
		cycle = 1
		vibrate(45, 0.25, 0.05)
	elif _just(JOY_BUTTON_LEFT_SHOULDER) or _just(JOY_BUTTON_DPAD_LEFT):
		cycle = -1
		vibrate(45, 0.25, 0.05)
	var result := {
		"move_x": left.x, "move_y": left.y, "look_x": right.x, "look_y": right.y, "has_look": right.z > 0.0,
		"sprint": lt > 0.25 or _l3_sprint, "jump": jump,
		"fly_up": fly and (_down(JOY_BUTTON_A) or _down(JOY_BUTTON_RIGHT_SHOULDER)),
		"fly_down": fly and (_down(JOY_BUTTON_B) or _down(JOY_BUTTON_LEFT_SHOULDER) or lt > 0.25),
		"attack": attack, "interact": _just(JOY_BUTTON_X), "cycle_weapon": cycle,
		"recenter_pitch": _just(JOY_BUTTON_RIGHT_STICK), "toggle_god_mode": _just(JOY_BUTTON_BACK),
		"toggle_music": _just(JOY_BUTTON_DPAD_UP), "toggle_normal_maps": _just(JOY_BUTTON_DPAD_DOWN),
		"pause_toggle": _just(JOY_BUTTON_START),
	}
	_record()
	return result


func apply_look(camera: Camera3D, delta: float, look_x: float, look_y: float) -> void:
	if absf(look_x) < 1e-4 and absf(look_y) < 1e-4:
		return
	var rot := camera.rotation
	rot.y -= look_x * sensitivity * delta
	rot.x = clampf(rot.x + (look_y if invert_y else -look_y) * sensitivity * delta, -MAX_PITCH, MAX_PITCH)
	camera.rotation = rot


func _menu_navigation(delta: float) -> void:
	var ui = game.ui
	if not ui.is_menu_visible():
		return
	var stick_x := Input.get_joy_axis(_device, JOY_AXIS_LEFT_X)
	var stick_y := Input.get_joy_axis(_device, JOY_AXIS_LEFT_Y)
	var vert := 0
	if _down(JOY_BUTTON_DPAD_UP) or stick_y < -0.45:
		vert = -1
	elif _down(JOY_BUTTON_DPAD_DOWN) or stick_y > 0.45:
		vert = 1
	if vert != 0:
		if vert != _nav_dir:
			_nav_dir = vert
			_nav_timer = MENU_REPEAT_DELAY
			ui.gamepad_move_focus(vert)
		else:
			_nav_timer -= delta
			if _nav_timer <= 0.0:
				_nav_timer = MENU_REPEAT_INTERVAL
				ui.gamepad_move_focus(vert)
	else:
		_nav_dir = 0
		_nav_timer = 0.0
	var horiz := 0
	if _down(JOY_BUTTON_DPAD_LEFT) or stick_x < -0.45:
		horiz = -1
	elif _down(JOY_BUTTON_DPAD_RIGHT) or stick_x > 0.45:
		horiz = 1
	if horiz != 0:
		if horiz != _horiz_dir:
			_horiz_dir = horiz
			_horiz_timer = MENU_REPEAT_DELAY
			ui.gamepad_adjust(horiz)
		else:
			_horiz_timer -= delta
			if _horiz_timer <= 0.0:
				_horiz_timer = MENU_REPEAT_INTERVAL
				ui.gamepad_adjust(horiz)
	else:
		_horiz_dir = 0
		_horiz_timer = 0.0
	if _just(JOY_BUTTON_A):
		vibrate(60, 0.3, 0.1)
		ui.gamepad_accept()
	if _just(JOY_BUTTON_B):
		vibrate(50, 0.2, 0.1)
		ui.on_back_or_resume()
	if _just(JOY_BUTTON_START) and ui.resume_enabled():
		vibrate(50, 0.2, 0.1)
		ui.click_resume()
