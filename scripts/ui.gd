# HUD, screen overlays and the main/generator/options menus (port of index.html + the HUD code).
class_name GameUI
extends CanvasLayer

const AMBER := Color("#f59e0b")

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 edge_color : source_color = vec4(1.0, 0.0, 0.0, 0.8);
uniform float inner = 0.4;
uniform float opacity = 0.0;
uniform vec2 rect_size = vec2(1280.0, 720.0);
void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	float t = length(p) / length(rect_size * 0.5);
	float k = clamp((t - inner) / (1.0 - inner), 0.0, 1.0);
	COLOR = vec4(edge_color.rgb, edge_color.a * k * opacity);
}
"""

const BAR_SHADER := """
shader_type canvas_item;
uniform vec4 c0 : source_color;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec2 rect_size = vec2(180.0, 16.0);
uniform float radius = 6.0;
void fragment() {
	vec2 p = UV * rect_size;
	float r = min(radius, min(rect_size.x, rect_size.y) * 0.5);
	vec2 q = abs(p - rect_size * 0.5) - rect_size * 0.5 + r;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	vec4 col = UV.x < 0.5 ? mix(c0, c1, UV.x * 2.0) : mix(c1, c2, (UV.x - 0.5) * 2.0);
	COLOR = vec4(col.rgb, col.a * clamp(0.5 - d, 0.0, 1.0));
}
"""

var game # Game
var minimap: Minimap

var _font: SystemFont
var _font_bold: SystemFont
var _font_black: SystemFont
var _mono: SystemFont

var _flash: ColorRect
var _flash_mat: ShaderMaterial
var _flash_opacity := 0.0
var _flash_target := 0.0
var _flash_hold := 0.0
var _low_health: ColorRect
var _low_health_mat: ShaderMaterial
var _low_health_active := false
var _low_health_time := 0.0
var _death: Control
var _info: RichTextLabel
var _info_values := {"mode": "FPS (WALK)", "mode_color": "#10b981", "pos": "0, 0, 0", "depth": "1", "obj": "0",
	"light": "0", "normalmap": true, "music": true, "gamepad": "None", "gamepad_on": false}
var _hp_fill: ColorRect
var _xp_fill: ColorRect
var _hp_target := 1.0
var _xp_target := 0.0
var _hp_cur := 1.0
var _xp_cur := 0.0
var _hp_text: Label
var _level_text: Label
var _kills_text: Label
var _gun_text: Label
var _loading: ColorRect
var _toast: PanelContainer
var _toast_label: Label
var _toast_timer := 0.0

# Menu
var _menu: PanelContainer
var _views: Dictionary = {}
var _current_view := "main"
var _prompt: Label
var _status: Label
var _btn_new: Button
var _btn_resume: Button
var _btn_generator: Button
var _btn_options: Button
var _btn_generate: Button
var _btn_gen_back: Button
var _gen_size: HSlider
var _gen_size_val: Label
var _gen_seed: LineEdit
var _opt_normal: CheckBox
var _opt_music: CheckBox
var _opt_vibration: CheckBox
var _opt_invert: CheckBox
var _opt_sens: HSlider
var _opt_sens_val: Label
var _btn_fullscreen: Button
var _btn_opt_back: Button
var _syncing := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = _sys_font(["Segoe UI", "Tahoma", "Geneva", "Verdana", "sans-serif"], 400)
	_font_bold = _sys_font(["Segoe UI", "Tahoma", "Geneva", "Verdana", "sans-serif"], 700)
	_font_black = _sys_font(["Segoe UI", "Tahoma", "Geneva", "Verdana", "sans-serif"], 800)
	_mono = _sys_font(["Consolas", "Courier New", "monospace"], 400)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_overlays(root)
	_build_minimap(root)
	_build_info(root)
	_build_hud(root)
	_build_loading(root)
	_build_menu(root)
	_build_toast(root)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


func _sys_font(names: Array, weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	var emoji := SystemFont.new()
	emoji.font_names = PackedStringArray(["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji"])
	f.fallbacks = [emoji]
	return f


static func _style(bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0, radius: int = 8,
		pad_h: float = 0.0, pad_v: float = 0.0, shadow: Color = Color(0, 0, 0, 0), shadow_size: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	s.shadow_color = shadow
	s.shadow_size = shadow_size
	s.anti_aliasing = true
	return s


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _on_resize() -> void:
	var vs := get_viewport().get_visible_rect().size
	_flash_mat.set_shader_parameter("rect_size", vs)
	_low_health_mat.set_shader_parameter("rect_size", vs)


# ---------------------------------------------------------------- Overlays

func _vignette(root: Control, color: Color, inner: float) -> ShaderMaterial:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	mat.shader = sh
	mat.set_shader_parameter("edge_color", color)
	mat.set_shader_parameter("inner", inner)
	rect.material = mat
	root.add_child(rect)
	if _low_health == null and inner > 0.5:
		_low_health = rect
	else:
		_flash = rect
	return mat


func _build_overlays(root: Control) -> void:
	_low_health_mat = _vignette(root, Color(160 / 255.0, 0, 0, 0.55), 0.55)
	_flash_mat = _vignette(root, Color(1, 0, 0, 0.8), 0.4)

	_death = ColorRect.new()
	(_death as ColorRect).color = Color(60 / 255.0, 0, 0, 0.7)
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.visible = false
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := _label("YOU DIED", _font_black, 56, Color("#fecaca"))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var small := _label("Respawning at the dungeon entrance...", _font_bold, 16, Color("#fca5a5"))
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)
	box.add_child(small)
	_death.add_child(box)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_death)

	var cross := Crosshair.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)


class Crosshair:
	extends Control

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.5))
		draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.7))


func flash_screen(kind: String, opacity: float, hold_ms: float) -> void:
	var color := Color(1, 0, 0, 0.8)
	var inner := 0.4
	match kind:
		"green":
			color = Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.5)
			inner = 0.3
		"health":
			color = Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.4)
		"xp":
			color = Color(234 / 255.0, 179 / 255.0, 8 / 255.0, 0.4)
	_flash_mat.set_shader_parameter("edge_color", color)
	_flash_mat.set_shader_parameter("inner", inner)
	_flash_target = opacity
	_flash_hold = hold_ms / 1000.0


func show_death_screen(show: bool) -> void:
	_death.visible = show


# ---------------------------------------------------------------- Minimap and info panel

func _build_minimap(root: Control) -> void:
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _style(Color(10 / 255.0, 14 / 255.0, 23 / 255.0, 0.88), Color(0, 0, 0, 0), 0, 130,
		0, 0, Color(0, 0, 0, 0.8), 16))
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.anchor_left = 1.0
	frame.anchor_right = 1.0
	frame.offset_left = -15 - 260
	frame.offset_right = -15
	frame.offset_top = 15
	frame.offset_bottom = 15 + 260
	root.add_child(frame)
	minimap = Minimap.new()
	minimap.game = game
	minimap.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(minimap)
	var border := Panel.new()
	border.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0), Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.4), 2, 130))
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.anchor_left = 1.0
	border.anchor_right = 1.0
	border.offset_left = -15 - 260
	border.offset_right = -15
	border.offset_top = 15
	border.offset_bottom = 15 + 260
	root.add_child(border)


func update_minimap(pos: Vector3, camera: Camera3D) -> void:
	minimap.update_minimap(pos, camera, get_process_delta_time())


func _build_info(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(15 / 255.0, 23 / 255.0, 42 / 255.0, 0.85),
		Color(1, 1, 1, 0.1), 1, 8, 14, 10, Color(0, 0, 0, 0.5), 12))
	panel.position = Vector2(15, 15)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info.scroll_active = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_font_override("normal_font", _mono)
	_info.add_theme_font_override("bold_font", _sys_font(["Consolas", "Courier New", "monospace"], 700))
	_info.add_theme_font_size_override("normal_font_size", 13)
	_info.add_theme_font_size_override("bold_font_size", 13)
	_info.add_theme_color_override("default_color", Color("#d1d5db"))
	_info.add_theme_constant_override("line_separation", 4)
	panel.add_child(_info)
	root.add_child(panel)
	_refresh_info()


func _refresh_info() -> void:
	var v := _info_values
	var nm_on: bool = v.normalmap
	var mu_on: bool = v.music
	var t := "[b][color=#f59e0b]Dungeon Stomp Godot - by Mark Longo Copyright 2026[/color][/b]\n"
	t += "Mode: [color=%s]%s[/color]\n" % [v.mode_color, v.mode]
	t += "Position: %s\n" % v.pos
	t += "Depth: [color=#38bdf8]%s[/color] | Objects: %s | Lights: %s\n" % [v.depth, v.obj, v.light]
	t += "Normal Maps: [color=%s]%s[/color] (N) | Music: [color=%s]%s[/color] (P)\n" % [
		"#00ff88" if nm_on else "#ef4444", "ON" if nm_on else "OFF", "#00ff88" if mu_on else "#ef4444", "ON" if mu_on else "OFF"]
	t += "Gamepad: [color=%s]%s[/color]\n" % ["#00ff88" if v.gamepad_on else "#64748b", v.gamepad]
	t += "Controls: WASD / L-Stick (Move) | Space / A (Jump) | E / X (Open Door) | RT (Attack) | LB/RB (Weapon)"
	_info.text = t


func set_info(key: String, text: String) -> void:
	if _info_values.get(key) == text:
		return
	_info_values[key] = text
	if _info != null:
		_refresh_info()


func set_toggle_info(key: String, enabled: bool) -> void:
	_info_values[key] = enabled
	if _info != null:
		_refresh_info()


func set_mode_display(fly: bool) -> void:
	_info_values.mode = "FLY MODE" if fly else "FPS (WALK)"
	_info_values.mode_color = "#00ffff" if fly else "#00ff88"
	_refresh_info()


func set_gamepad_display(name: String, connected: bool) -> void:
	_info_values.gamepad = name
	_info_values.gamepad_on = connected
	_refresh_info()

# ---------------------------------------------------------------- Bottom HUD

func _badge(title: String, value: String, value_color: Color, value_size: int = 15, min_w: float = 60.0) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(30 / 255.0, 41 / 255.0, 59 / 255.0, 0.6), Color(1, 1, 1, 0.12), 1, 8, 14, 6))
	panel.custom_minimum_size = Vector2(min_w, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _label(title.to_upper(), _font_bold, 10, Color("#64748b"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var v := _label(value, _font_black, value_size, value_color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	box.add_child(v)
	panel.add_child(box)
	_hud_row.add_child(panel)
	return v


var _hud_row: HBoxContainer

func _bar(title: String, right_text: String, right_color: Color, c0: Color, c1: Color, c2: Color) -> Array:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(title, _font_bold, 11, Color("#94a3b8"))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r := _label(right_text, _font_bold, 11, right_color)
	row.add_child(l)
	row.add_child(r)
	box.add_child(row)
	var track := Panel.new()
	track.custom_minimum_size = Vector2(180, 16)
	track.add_theme_stylebox_override("panel", _style(Color(15 / 255.0, 23 / 255.0, 42 / 255.0, 0.8), Color(1, 1, 1, 0.15), 1, 8))
	track.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BAR_SHADER
	mat.shader = sh
	mat.set_shader_parameter("c0", c0)
	mat.set_shader_parameter("c1", c1)
	mat.set_shader_parameter("c2", c2)
	fill.material = mat
	fill.position = Vector2(0, 0)
	fill.size = Vector2(180, 16)
	track.add_child(fill)
	box.add_child(track)
	_hud_row.add_child(box)
	return [fill, r]


func _build_hud(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(15 / 255.0, 18 / 255.0, 26 / 255.0, 0.93),
		Color(1, 170 / 255.0, 0, 0.25), 1, 12, 24, 12, Color(0, 0, 0, 0.8), 24))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -20
	_hud_row = HBoxContainer.new()
	_hud_row.add_theme_constant_override("separation", 16)
	_hud_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_hud_row)
	root.add_child(panel)
	_level_text = _badge("Hero", "LVL 1", Color("#38bdf8"))
	var hp := _bar("HEALTH", "100 / 100", Color("#f87171"), Color("#dc2626"), Color("#ef4444"), Color("#f87171"))
	_hp_fill = hp[0]
	_hp_text = hp[1]
	var xp := _bar("EXP", "PROGRESS", Color("#94a3b8"), Color("#0284c7"), Color("#38bdf8"), Color("#7dd3fc"))
	_xp_fill = xp[0]
	_kills_text = _badge("KILLS", "0", Color("#f43f5e"))
	_gun_text = _badge("WEAPON", "AXE", AMBER, 13, 120)


func update_hud(stats: Dictionary, gun_text: String) -> void:
	var max_hp := maxf(1.0, float(stats.maxHealth))
	_hp_target = clampf(float(stats.health) / max_hp, 0.0, 1.0)
	_xp_target = clampf(float(stats.xp) / maxf(1.0, float(stats.nextXp)), 0.0, 1.0)
	_low_health_active = float(stats.health) > 0.0 and _hp_target < 0.3
	_hp_text.text = "%d / %d" % [int(ceil(float(stats.health))), int(stats.maxHealth)]
	_level_text.text = "LVL %d" % int(stats.level)
	_kills_text.text = str(int(stats.kills))
	_gun_text.text = gun_text


func _build_loading(root: Control) -> void:
	_loading = ColorRect.new()
	_loading.color = Color(5 / 255.0, 7 / 255.0, 12 / 255.0, 0.92)
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading.visible = false
	var l := _label("LOADING DUNGEON...", _font_bold, 20, AMBER)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading.add_child(l)
	root.add_child(_loading)


func show_loading(show: bool) -> void:
	_loading.visible = show


func _build_toast(root: Control) -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _style(Color(15 / 255.0, 20 / 255.0, 30 / 255.0, 0.96),
		Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.6), 1, 8, 20, 10, Color(0, 0, 0, 0.8), 24))
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 24
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_toast_label = _label("", _font_bold, 14, AMBER)
	_toast.add_child(_toast_label)
	root.add_child(_toast)


func toast(message: String) -> void:
	_toast_label.text = message
	_toast_timer = 3.2


func _process(delta: float) -> void:
	# Damage / pickup flash (opacity transition 0.15 s ease-out)
	if _flash_hold > 0.0:
		_flash_hold -= delta
		if _flash_hold <= 0.0:
			_flash_target = 0.0
	_flash_opacity = move_toward(_flash_opacity, _flash_target, delta / 0.15)
	_flash_mat.set_shader_parameter("opacity", _flash_opacity)
	# Low health pulse (1.1 s ease-in-out between 0.25 and 1)
	if _low_health_active:
		_low_health_time += delta
		var k := 0.5 - 0.5 * cos(_low_health_time / 1.1 * TAU)
		_low_health_mat.set_shader_parameter("opacity", lerpf(0.25, 1.0, k))
	else:
		_low_health_time = 0.0
		_low_health_mat.set_shader_parameter("opacity", 0.0)
	# Bars ease towards their targets (CSS width transition 0.2 s)
	_hp_cur = lerpf(_hp_cur, _hp_target, minf(1.0, delta * 12.0))
	_xp_cur = lerpf(_xp_cur, _xp_target, minf(1.0, delta * 12.0))
	_set_fill(_hp_fill, _hp_cur)
	_set_fill(_xp_fill, _xp_cur)
	# Toast slide in/out
	if _toast_timer > 0.0:
		_toast_timer -= delta
		_toast.modulate.a = move_toward(_toast.modulate.a, 1.0, delta / 0.3)
	else:
		_toast.modulate.a = move_toward(_toast.modulate.a, 0.0, delta / 0.3)
	_toast.offset_top = lerpf(-36.0, 24.0, _toast.modulate.a)


func _set_fill(fill: ColorRect, pct: float) -> void:
	var w := 180.0 * pct
	fill.size = Vector2(w, 16)
	fill.visible = w > 0.5
	(fill.material as ShaderMaterial).set_shader_parameter("rect_size", Vector2(maxf(w, 1.0), 16.0))


# ---------------------------------------------------------------- Menu

func _menu_button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.add_theme_font_override("font", _font_bold)
	b.add_theme_font_size_override("font_size", 14)
	b.focus_mode = Control.FOCUS_ALL
	var normal: StyleBoxFlat
	var hover: StyleBoxFlat
	if primary:
		normal = _style(Color("#e8920a"), Color("#fbbf24"), 1, 8, 16, 11, Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.35), 8)
		hover = _style(Color("#f0a020"), Color("#fbbf24"), 1, 8, 16, 11, Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.5), 10)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			b.add_theme_color_override(k, Color("#0f172a"))
	else:
		normal = _style(Color(30 / 255.0, 41 / 255.0, 59 / 255.0, 0.7), Color(1, 170 / 255.0, 0, 0.25), 1, 8, 16, 11)
		hover = _style(Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.22), AMBER, 1, 8, 16, 11, Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.25), 7)
		b.add_theme_color_override("font_color", Color("#e2e8f0"))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_focus_color", Color("#fbbf24"))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(226 / 255.0, 232 / 255.0, 240 / 255.0, 0.4))
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color.a *= 0.4
	disabled.border_color = Color(1, 1, 1, 0.1)
	disabled.shadow_size = 0
	var focus := _style(Color(0, 0, 0, 0), AMBER, 2, 8)
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	focus.shadow_color = Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.8)
	focus.shadow_size = 8
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", focus)
	return b


func _help(text: String) -> Label:
	var l := _label(text, _font, 11, Color("#64748b"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _field_label(text: String, value: String) -> Array:
	var row := HBoxContainer.new()
	var l := _label(text, _font_bold, 13, Color("#cbd5e1"))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _label(value, _font_bold, 13, AMBER)
	row.add_child(l)
	row.add_child(v)
	return [row, v]


func _checkbox(text: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.add_theme_font_override("font", _font)
	c.add_theme_font_size_override("font_size", 14)
	c.add_theme_color_override("font_color", Color("#e2e8f0"))
	c.add_theme_color_override("font_hover_color", Color.WHITE)
	c.add_theme_color_override("font_focus_color", Color("#fbbf24"))
	c.add_theme_color_override("font_pressed_color", Color("#e2e8f0"))
	var focus := _style(Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.15), AMBER, 2, 6)
	c.add_theme_stylebox_override("focus", focus)
	return c


func _slider(min_v: float, max_v: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.custom_minimum_size = Vector2(0, 20)
	s.add_theme_stylebox_override("grabber_area", _style(AMBER, Color(0, 0, 0, 0), 0, 3, 0, 3))
	s.add_theme_stylebox_override("grabber_area_highlight", _style(Color("#fbbf24"), Color(0, 0, 0, 0), 0, 3, 0, 3))
	s.add_theme_stylebox_override("slider", _style(Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 0, 3, 0, 3))
	s.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), AMBER, 2, 6))
	return s


func _h3(text: String) -> Label:
	var l := _label(text.to_upper(), _font_bold, 18, Color("#fbbf24"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _build_menu(root: Control) -> void:
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", _style(Color(12 / 255.0, 15 / 255.0, 23 / 255.0, 0.97),
		Color(1, 170 / 255.0, 0, 0.35), 1, 14, 32, 24, Color(0, 0, 0, 0.85), 48))
	_menu.custom_minimum_size = Vector2(440, 0)
	_menu.anchor_left = 0.5
	_menu.anchor_right = 0.5
	_menu.anchor_top = 0.5
	_menu.anchor_bottom = 0.5
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.gui_input.connect(_on_menu_gui_input)
	root.add_child(_menu)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_menu.add_child(outer)
	var title := _label("⚔️ DUNGEON STOMP ⚔️", _font_bold, 24, AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	# Main view
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	_prompt = _label("Loading dungeon...", _font, 13, Color("#94a3b8"))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(_prompt)
	_btn_new = _menu_button("New Game", true)
	_btn_resume = _menu_button("Resume")
	_btn_resume.disabled = true
	_btn_generator = _menu_button("Dungeon Generator")
	_btn_options = _menu_button("Options")
	for b in [_btn_new, _btn_resume, _btn_generator, _btn_options]:
		main.add_child(b)
	_status = _label("", _font, 13, Color("#38bdf8"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(_status)
	main.add_child(_help("WASD = Move   ·   Space = Jump   ·   E = Open Door   ·   G = Regen Dungeon   ·   Q/Z = Weapon   ·   Esc = Menu"))
	main.add_child(_help("🎮 L-Stick = Move (L3 Sprint)   ·   R-Stick = Look (R3 Level)   ·   RT = Attack / Cast   ·   X = Open Door/Chest   ·   A = Jump / Confirm   ·   LB/RB = Weapon   ·   LT = Sprint   ·   Start = Menu"))
	main.add_child(_help("Find the glowing exit portal to descend — every level is tougher."))
	outer.add_child(main)
	_views["main"] = main

	# Generator view
	var gen := VBoxContainer.new()
	gen.add_theme_constant_override("separation", 10)
	gen.add_child(_h3("Dungeon Generator"))
	var size_row := _field_label("Rooms / Objects:", "225")
	gen.add_child(size_row[0])
	_gen_size_val = size_row[1]
	_gen_size = _slider(150, 600, 25)
	_gen_size.value = 225
	_gen_size.value_changed.connect(func(v: float): _gen_size_val.text = str(int(v)))
	gen.add_child(_gen_size)
	gen.add_child(_field_label("Seed (optional):", "")[0])
	_gen_seed = LineEdit.new()
	_gen_seed.placeholder_text = "Leave empty for random"
	_gen_seed.max_length = 32
	_gen_seed.add_theme_font_override("font", _font)
	_gen_seed.add_theme_font_size_override("font_size", 14)
	_gen_seed.add_theme_stylebox_override("normal", _style(Color(15 / 255.0, 23 / 255.0, 42 / 255.0, 0.85), Color(1, 1, 1, 0.2), 1, 6, 12, 9))
	_gen_seed.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), AMBER, 1, 6))
	gen.add_child(_gen_seed)
	_btn_generate = _menu_button("Generate Dungeon", true)
	_btn_gen_back = _menu_button("Back")
	gen.add_child(_btn_generate)
	gen.add_child(_btn_gen_back)
	outer.add_child(gen)
	_views["generator"] = gen

	# Options view
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 12)
	opts.add_child(_h3("Options"))
	_opt_normal = _checkbox("Normal Maps (N)")
	_opt_music = _checkbox("Music (P / M)")
	_opt_vibration = _checkbox("Controller Vibration (Rumble)")
	_opt_invert = _checkbox("Invert Look Y")
	for c in [_opt_normal, _opt_music, _opt_vibration, _opt_invert]:
		opts.add_child(c)
	var sens_row := _field_label("Controller Sensitivity:", "2.8")
	opts.add_child(sens_row[0])
	_opt_sens_val = sens_row[1]
	_opt_sens = _slider(1.0, 5.0, 0.2)
	_opt_sens.value = 2.8
	opts.add_child(_opt_sens)
	_btn_fullscreen = _menu_button("Toggle Fullscreen")
	_btn_opt_back = _menu_button("Back")
	opts.add_child(_btn_fullscreen)
	opts.add_child(_btn_opt_back)
	outer.add_child(opts)
	_views["options"] = opts

	_btn_new.pressed.connect(_on_new_game)
	_btn_resume.pressed.connect(click_resume)
	_btn_generator.pressed.connect(_on_open_generator)
	_btn_options.pressed.connect(_on_open_options)
	_btn_generate.pressed.connect(_on_generate)
	_btn_gen_back.pressed.connect(_on_back)
	_btn_opt_back.pressed.connect(_on_back)
	_btn_fullscreen.pressed.connect(_on_fullscreen)
	_opt_normal.toggled.connect(func(on: bool):
		if not _syncing:
			game.set_normal_maps_enabled(on)
			game.save_game_options())
	_opt_music.toggled.connect(func(on: bool):
		if _syncing or on == game.audio.is_music_on():
			return
		var enabled: bool = game.audio.toggle_music()
		set_toggle_info("music", enabled)
		if enabled:
			game.audio.start_next_music_track()
		game.save_game_options())
	_opt_vibration.toggled.connect(func(on: bool):
		if not _syncing:
			game.gamepad.vibration_enabled = on
			game.save_game_options())
	_opt_invert.toggled.connect(func(on: bool):
		if not _syncing:
			game.gamepad.invert_y = on
			game.save_game_options())
	_opt_sens.value_changed.connect(func(v: float):
		_opt_sens_val.text = "%.1f" % v
		if not _syncing:
			game.gamepad.set_sensitivity(v)
			game.save_game_options())
	show_menu_view("main")


func _click_sound() -> void:
	game.audio.play_sound("buttonselect111.wav", 0.5)


func _on_menu_gui_input(event: InputEvent) -> void:
	# Clicking the menu panel (not a button) enters the dungeon, like the browser version.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _current_view == "main" and (game.world_ready or resume_enabled()):
			game.start_game_session()


func _on_new_game() -> void:
	_click_sound()
	if not game.world_ready:
		return
	_btn_new.disabled = true
	await game.new_game()
	_btn_new.disabled = false


func click_resume() -> void:
	if _btn_resume.disabled or not game.world_ready:
		return
	game.start_game_session()
	_click_sound()


func _on_open_generator() -> void:
	_click_sound()
	show_menu_view("generator")
	_gen_size.value = int(game.gen_options.get("numObjectsToPlace", 225))
	var s = game.gen_options.get("seed")
	_gen_seed.text = "" if s == null else str(s)


func _on_open_options() -> void:
	_click_sound()
	show_menu_view("options")
	sync_options()


func _on_generate() -> void:
	_click_sound()
	if not game.world_ready:
		return
	_btn_generate.disabled = true
	await game.generate_from_menu(int(_gen_size.value), _gen_seed.text.strip_edges())
	_btn_generate.disabled = false


func _on_back() -> void:
	_click_sound()
	show_menu_view("main")


func _on_fullscreen() -> void:
	_click_sound()
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_update_fullscreen_button()


func _update_fullscreen_button() -> void:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_btn_fullscreen.text = "EXIT FULLSCREEN" if fs else "TOGGLE FULLSCREEN"


func sync_options() -> void:
	_syncing = true
	_opt_normal.button_pressed = game.normal_maps_enabled
	_opt_music.button_pressed = game.audio.is_music_on()
	_opt_vibration.button_pressed = game.gamepad.vibration_enabled
	_opt_invert.button_pressed = game.gamepad.invert_y
	_opt_sens.value = game.gamepad.sensitivity
	_opt_sens_val.text = "%.1f" % game.gamepad.sensitivity
	_syncing = false
	set_toggle_info("music", game.audio.is_music_on())
	set_toggle_info("normalmap", game.normal_maps_enabled)
	_update_fullscreen_button()


func show_menu_view(view: String) -> void:
	_current_view = view
	for k in _views:
		(_views[k] as Control).visible = k == view
	if _status != null:
		_status.text = ""
	if view == "options":
		_update_fullscreen_button()


func show_menu(show: bool) -> void:
	_menu.visible = show
	if not show:
		var f := get_viewport().gui_get_focus_owner()
		if f != null:
			f.release_focus()


func is_menu_visible() -> bool:
	return _menu != null and _menu.visible


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_status(text: String) -> void:
	_status.text = text


func set_resume_enabled(enabled: bool) -> void:
	_btn_resume.disabled = not enabled


func resume_enabled() -> bool:
	return not _btn_resume.disabled


# Escape / gamepad B: go back from a sub-menu, or resume from the main menu.
func on_back_or_resume() -> void:
	if _current_view != "main":
		_on_back()
	elif resume_enabled():
		click_resume()


func _focusables() -> Array:
	var view: Control = _views[_current_view]
	var out: Array = []
	var stack: Array = [view]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		for c in n.get_children():
			if c is BaseButton or c is Slider or c is LineEdit:
				if (c as Control).visible and not (c is BaseButton and (c as BaseButton).disabled):
					out.append(c)
			elif c is Container:
				stack.append(c)
	return out


func gamepad_move_focus(dir: int) -> void:
	var items := _focusables()
	if items.is_empty():
		return
	var cur := get_viewport().gui_get_focus_owner()
	var idx := items.find(cur)
	idx = 0 if idx == -1 else posmod(idx + dir, items.size())
	(items[idx] as Control).grab_focus()
	game.audio.play_sound("buttonselect111.wav", 0.25)


func gamepad_adjust(dir: int) -> void:
	var cur := get_viewport().gui_get_focus_owner()
	if cur is Slider:
		var s := cur as Slider
		s.value = clampf(s.value + dir * s.step, s.min_value, s.max_value)
		game.audio.play_sound("buttonselect111.wav", 0.25)
	elif cur is CheckBox:
		(cur as CheckBox).button_pressed = not (cur as CheckBox).button_pressed
		game.audio.play_sound("buttonselect111.wav", 0.35)


func gamepad_accept() -> void:
	var cur := get_viewport().gui_get_focus_owner()
	if cur == null:
		gamepad_move_focus(0)
		return
	if cur is CheckBox:
		(cur as CheckBox).button_pressed = not (cur as CheckBox).button_pressed
		game.audio.play_sound("buttonselect111.wav", 0.4)
	elif cur is BaseButton:
		(cur as BaseButton).pressed.emit()
