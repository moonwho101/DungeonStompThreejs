# Lights, glare sprites, particles, blood, floating text and explosion flashes (port of render.js).
class_name Effects
extends Node3D

const LIGHT_RANGE := 1000.0
const MAX_POINT_LIGHTS := 8
const MAX_SPOT_LIGHTS := 4
const MAX_DYNAMIC_LIGHTS := 4
const POINT_LIGHT_INTENSITY := 8500.0
const SPOT_LIGHT_INTENSITY := 12000.0
const LIGHT_DECAY := 1.5
const LIGHT_FADE_SPEED := 4.0
const LIGHT_REFRESH_INTERVAL := 0.1
const FLICKER_COLOUR_REF := 14.0
const SPOT_COLOUR_REF := 0.9
const EXPLOSION_FLASH_INTENSITY := 15000.0
const EXPLOSION_FLASH_DURATION := 0.3

const MAX_PARTICLES := 3072
const PARTICLE_GRAVITY := 180.0
# A three.js point of `size` covers size * tan(fov / 2) world units at any distance (fov 75).
const POINT_TO_WORLD := 0.7673269879789604

const MAX_BLOOD := 1792
const BLOOD_GRAVITY := 620.0
const MAX_BLOOD_DECALS := 56
const BLOOD_DECAL_HOLD := 20.0
const BLOOD_DECAL_FADE := 5.0

const BILLBOARD := """
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	#EXTRA#
}
"""

# Procedural versions of the canvas "halo" and "core" glare textures.
const GLARE_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled#FOG#;
uniform int kind = 0;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float opacity = 1.0;
#BILLBOARD#
float ramp(float r, float o0, float a0, float o1, float a1, float o2, float a2, float o3, float a3, float o4, float a4) {
	if (r <= o0) return a0;
	if (r <= o1) return mix(a0, a1, (r - o0) / (o1 - o0));
	if (r <= o2) return mix(a1, a2, (r - o1) / (o2 - o1));
	if (r <= o3) return mix(a2, a3, (r - o2) / (o3 - o2));
	if (r <= o4) return mix(a3, a4, (r - o3) / (o4 - o3));
	return a4;
}
float ramp3(float r, float a0, float o1, float a1) {
	if (r <= o1) return mix(a0, a1, r / o1);
	if (r <= 1.0) return mix(a1, 0.0, (r - o1) / (1.0 - o1));
	return 0.0;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a;
	if (kind == 0) {
		a = ramp(length(p), 0.0, 0.55, 0.2, 0.32, 0.45, 0.12, 0.75, 0.03, 1.0, 0.0);
	} else {
		float h = abs(p.y) <= 0.05 ? ramp3(length(vec2(p.x, p.y / 0.05)), 0.9, 0.3, 0.35) : 0.0;
		float v = abs(p.x) <= 0.05 ? ramp3(length(vec2(p.x / 0.05, p.y)), 0.7, 0.3, 0.25) : 0.0;
		float c = ramp(length(p), 0.0, 1.0, 0.12, 0.9, 0.3, 0.3, 0.6, 0.05, 1.0, 0.0);
		a = h;
		a = a + v * (1.0 - a);
		a = a + c * (1.0 - a);
	}
	ALBEDO = tint.rgb;
	ALPHA = a * opacity;
}
"""

const PARTICLE_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, fog_disabled;
#BILLBOARD#
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = 1.0;
}
"""

const BLOOD_SHADER := """
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, fog_disabled;
varying float soft;
#BILLBOARD#
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	if (d > 1.0) discard;
	float crisp = smoothstep(1.0, 0.8, d);
	float puff = pow(1.0 - d, 1.6);
	float shape = mix(crisp, puff, soft);
	vec3 rgb = COLOR.rgb * mix(mix(0.55, 1.0, smoothstep(1.0, 0.45, d)), 1.0, soft);
	float highlight = smoothstep(0.4, 0.0, length(p - vec2(-0.32, -0.32)));
	rgb += vec3(0.75, 0.35, 0.3) * highlight * (1.0 - soft) * COLOR.a;
	ALBEDO = rgb;
	ALPHA = COLOR.a * shape;
}
"""

const BLOOD_PALETTE := [0x8b0000, 0xa80a0a, 0xc41212, 0x6a0808, 0x7d0d0d]


class Lamp:
	var type := "flicker"
	var pos := Vector3.ZERO
	var dir := Vector3.DOWN
	var color := Color.WHITE # sRGB
	var brightness := 1.0
	var phase := 0.0
	var halo_size := 340.0
	var core_size := 120.0
	var halo: MeshInstance3D
	var core: MeshInstance3D
	var slot: LightSlot = null
	var dist := INF
	var flicker := 1.0


class LightSlot:
	var light: Light3D
	var lamp: Lamp = null
	var fade := 0.0
	var releasing := false
	var busy := false


var lamps: Array = []
var flicker_slots: Array = []
var spot_slots: Array = []
var dynamic_slots: Array = []
var _light_refresh_timer := LIGHT_REFRESH_INTERVAL
var explosion_flashes: Array = []

var _glare_materials: Dictionary = {}
var _quad: QuadMesh

# Particle pool (additive squares)
var _p_pos := PackedVector3Array()
var _p_vel := PackedVector3Array()
var _p_base := PackedColorArray()
var _p_size := PackedFloat32Array()
var _p_age := PackedFloat32Array()
var _p_life := PackedFloat32Array()
var _p_next := 0
var _p_high := 0
var _p_alive := 0
var _p_mm: MultiMesh
var _p_buf := PackedFloat32Array()

# Blood pool
var _b_pos := PackedVector3Array()
var _b_vel := PackedVector3Array()
var _b_col := PackedColorArray()
var _b_size := PackedFloat32Array()
var _b_base := PackedFloat32Array()
var _b_soft := PackedFloat32Array()
var _b_age := PackedFloat32Array()
var _b_life := PackedFloat32Array()
var _b_grav := PackedFloat32Array()
var _b_drag := PackedFloat32Array()
var _b_growth := PackedFloat32Array()
var _b_floor := PackedFloat32Array()
var _b_trail := PackedByteArray()
var _b_next := 0
var _b_high := 0
var _b_alive := 0
var _b_mm: MultiMesh
var _b_buf := PackedFloat32Array()

var _decals: Array = []
var _decal_next := 0
var _decal_textures: Array = []

var floating_texts: Array = []
var _text_font: SystemFont


func _ready() -> void:
	_quad = QuadMesh.new()
	_quad.size = Vector2(1, 1)
	for i in MAX_POINT_LIGHTS:
		var l := OmniLight3D.new()
		l.omni_range = LIGHT_RANGE
		l.omni_attenuation = LIGHT_DECAY
		l.light_energy = 0.0
		l.light_specular = 0.0
		l.visible = false
		add_child(l)
		var s := LightSlot.new()
		s.light = l
		flicker_slots.append(s)
	for i in MAX_SPOT_LIGHTS:
		var l := SpotLight3D.new()
		l.spot_range = LIGHT_RANGE
		l.spot_attenuation = LIGHT_DECAY
		l.spot_angle = rad_to_deg(PI / 3.2)
		l.spot_angle_attenuation = 1.0
		l.light_energy = 0.0
		l.light_specular = 0.0
		l.visible = false
		add_child(l)
		var s := LightSlot.new()
		s.light = l
		spot_slots.append(s)
	for i in MAX_DYNAMIC_LIGHTS:
		var l := OmniLight3D.new()
		l.omni_range = 400.0
		l.omni_attenuation = LIGHT_DECAY
		l.light_energy = 0.0
		l.light_specular = 0.0
		l.visible = false
		add_child(l)
		var s := LightSlot.new()
		s.light = l
		dynamic_slots.append(s)
	_text_font = SystemFont.new()
	_text_font.font_names = PackedStringArray(["Arial", "Segoe UI", "sans-serif"])
	_text_font.font_weight = 900
	_init_particles()
	_init_blood()


static func hex_color(hex: int) -> Color:
	return Color8((hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF)


func _billboard_shader(code: String, extra: String = "") -> Shader:
	var sh := Shader.new()
	sh.code = code.replace("#BILLBOARD#", BILLBOARD.replace("#EXTRA#", extra))
	return sh


func glare_material(kind: int, fog: bool, priority: int = 0) -> ShaderMaterial:
	var key := "%d|%s|%d" % [kind, fog, priority]
	if _glare_materials.has(key):
		return _glare_materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = _billboard_shader(GLARE_SHADER.replace("#FOG#", "" if fog else ", fog_disabled"))
	mat.set_shader_parameter("kind", kind)
	mat.render_priority = priority
	_glare_materials[key] = mat
	return mat


# Billboard glare sprite (kind 0 = halo, 1 = core).
func make_glare(kind: int, fog: bool, tint: Color, opacity: float, size: float, priority: int = 0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = glare_material(kind, fog, priority)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(size, size, size)
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("opacity", opacity)
	return mi


# ---------------------------------------------------------------- Lamps

func clear_lamps() -> void:
	for lamp: Lamp in lamps:
		lamp.halo.queue_free()
		lamp.core.queue_free()
	lamps.clear()
	for slots in [flicker_slots, spot_slots]:
		for s: LightSlot in slots:
			s.lamp = null
			s.fade = 0.0
			s.releasing = false
			s.light.light_energy = 0.0
			s.light.visible = false


func register_lamp(src: Parsers.LightSource) -> void:
	var is_spot := src.type == "spotlight"
	var ref := SPOT_COLOUR_REF if is_spot else FLICKER_COLOUR_REF
	var c := src.color
	var max_comp := maxf(c.x, maxf(c.y, c.z))
	var color := Color(1.0, 0.7, 0.4)
	if max_comp > 1e-4:
		color = Color(c.x / max_comp, c.y / max_comp, c.z / max_comp)
	var lamp := Lamp.new()
	lamp.type = "spotlight" if is_spot else "flicker"
	lamp.pos = src.pos + Vector3(0, 40, 0)
	lamp.dir = src.dir.normalized() if src.dir.length_squared() >= 1e-6 else Vector3.DOWN
	lamp.color = color
	lamp.brightness = clampf(max_comp / ref, 0.6, 1.15)
	lamp.phase = randf() * TAU
	lamp.halo_size = 170.0 if is_spot else 340.0
	lamp.core_size = 55.0 if is_spot else 120.0
	var core_color := color.srgb_to_linear().lerp(Color.WHITE, 0.55).linear_to_srgb()
	lamp.halo = make_glare(0, false, color, 0.0, 1.0, 10)
	lamp.core = make_glare(1, false, core_color, 0.0, 1.0, 11)
	lamp.halo.position = lamp.pos
	lamp.core.position = lamp.pos
	lamp.halo.visible = false
	lamp.core.visible = false
	add_child(lamp.halo)
	add_child(lamp.core)
	lamps.append(lamp)


func _flicker_value(lamp: Lamp, t: float) -> float:
	var p := lamp.phase
	if lamp.type == "spotlight":
		return 0.97 + 0.03 * sin(t * 2.0 + p)
	return 0.86 + 0.07 * sin(t * 9.0 + p) + 0.045 * sin(t * 23.0 + p * 1.7) \
		+ 0.03 * sin(t * 47.0 + p * 0.6) + 0.06 * sin(t * 3.1 + p) * sin(t * 5.3 + p * 2.0)


static func _smoothstep01(e0: float, e1: float, x: float) -> float:
	var k := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


func _refresh_light_slots(type: String, slots: Array) -> void:
	var nearest: Array = []
	for lamp: Lamp in lamps:
		if lamp.type == type and lamp.dist <= LIGHT_RANGE:
			nearest.append(lamp)
	nearest.sort_custom(func(a: Lamp, b: Lamp): return a.dist < b.dist)
	var wanted := nearest.slice(0, slots.size())
	for s: LightSlot in slots:
		if s.lamp != null and not wanted.has(s.lamp):
			s.releasing = true
	for lamp: Lamp in wanted:
		if lamp.slot != null:
			lamp.slot.releasing = false
			continue
		for s: LightSlot in slots:
			if s.lamp == null:
				s.lamp = lamp
				s.fade = 0.0
				s.releasing = false
				lamp.slot = s
				s.light.light_color = lamp.color
				s.light.visible = true
				if lamp.type == "spotlight":
					s.light.position = lamp.pos
					var target := lamp.pos + lamp.dir * 100.0
					var up := Vector3.UP if absf(lamp.dir.dot(Vector3.UP)) < 0.999 else Vector3.RIGHT
					s.light.look_at(target, up)
				break


func update_lighting(t: float, delta: float, player_pos: Vector3) -> void:
	var range_sq := LIGHT_RANGE * LIGHT_RANGE
	for lamp: Lamp in lamps:
		var dist_sq := lamp.pos.distance_squared_to(player_pos)
		if dist_sq > range_sq:
			lamp.dist = INF
			if lamp.halo.visible:
				lamp.halo.visible = false
				lamp.core.visible = false
			continue
		lamp.dist = sqrt(dist_sq)
		lamp.flicker = _flicker_value(lamp, t)
		var fade := (1.0 - _smoothstep01(LIGHT_RANGE * 0.6, LIGHT_RANGE, lamp.dist)) * _smoothstep01(40.0, 160.0, lamp.dist)
		var f := lamp.flicker
		var vis := fade > 0.01
		lamp.halo.visible = vis
		lamp.core.visible = vis
		if vis:
			var hs := lamp.halo_size * (0.9 + 0.2 * f)
			var cs := lamp.core_size * (0.85 + 0.3 * f)
			lamp.halo.scale = Vector3(hs, hs, 1)
			lamp.core.scale = Vector3(cs, cs, 1)
			lamp.halo.set_instance_shader_parameter("opacity", fade * minf(1.0, 0.45 + 0.5 * f) * lamp.brightness)
			lamp.core.set_instance_shader_parameter("opacity", fade * minf(1.0, 0.5 + 0.5 * f))

	_light_refresh_timer += delta
	if _light_refresh_timer >= LIGHT_REFRESH_INTERVAL:
		_light_refresh_timer = 0.0
		_refresh_light_slots("flicker", flicker_slots)
		_refresh_light_slots("spotlight", spot_slots)

	for pair in [[flicker_slots, POINT_LIGHT_INTENSITY], [spot_slots, SPOT_LIGHT_INTENSITY]]:
		var base: float = pair[1]
		for s: LightSlot in pair[0]:
			var lamp := s.lamp
			if lamp == null:
				continue
			s.fade = clampf(s.fade + (-1.0 if s.releasing else 1.0) * LIGHT_FADE_SPEED * delta, 0.0, 1.0)
			if s.releasing and s.fade <= 0.0:
				s.light.light_energy = 0.0
				s.light.visible = false
				lamp.slot = null
				s.lamp = null
				s.releasing = false
				continue
			if lamp.type == "flicker":
				var p := lamp.phase
				s.light.position = Vector3(lamp.pos.x + sin(t * 11.0 + p) * 3.0,
					lamp.pos.y + sin(t * 17.0 + p * 1.3) * 4.0,
					lamp.pos.z + cos(t * 13.0 + p * 0.7) * 3.0)
			s.light.light_energy = base * lamp.brightness * lamp.flicker * s.fade / PI


func acquire_dynamic_light(color_hex: int, intensity: float, distance: float) -> LightSlot:
	for s: LightSlot in dynamic_slots:
		if s.busy:
			continue
		s.busy = true
		s.light.light_color = hex_color(color_hex)
		s.light.light_energy = intensity / PI
		(s.light as OmniLight3D).omni_range = distance
		s.light.visible = true
		return s
	return null


func release_dynamic_light(s: LightSlot) -> void:
	if s == null:
		return
	s.busy = false
	s.light.light_energy = 0.0
	s.light.visible = false


func set_dynamic_intensity(s: LightSlot, intensity: float) -> void:
	if s != null:
		s.light.light_energy = intensity / PI


func add_explosion_flash(pos: Vector3, color_hex: int, aoe_radius: float) -> void:
	var s := acquire_dynamic_light(color_hex, EXPLOSION_FLASH_INTENSITY, aoe_radius * 2.0)
	if s != null:
		s.light.position = pos
		explosion_flashes.append({"slot": s, "timer": 0.0})


func update_explosion_flashes(delta: float) -> void:
	for i in range(explosion_flashes.size() - 1, -1, -1):
		var fl: Dictionary = explosion_flashes[i]
		fl.timer += delta
		if fl.timer >= EXPLOSION_FLASH_DURATION:
			release_dynamic_light(fl.slot)
			explosion_flashes.remove_at(i)
		else:
			set_dynamic_intensity(fl.slot, EXPLOSION_FLASH_INTENSITY * (1.0 - fl.timer / EXPLOSION_FLASH_DURATION))


# ---------------------------------------------------------------- Particles

func _make_multimesh(shader_code: String, max_count: int, custom: bool, extra: String = "") -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = custom
	mm.mesh = _quad
	mm.instance_count = max_count
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = _billboard_shader(shader_code, extra)
	mmi.material_override = mat
	mmi.custom_aabb = AABB(Vector3(-1e6, -1e6, -1e6), Vector3(2e6, 2e6, 2e6))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


func _init_particles() -> void:
	_p_pos.resize(MAX_PARTICLES)
	_p_vel.resize(MAX_PARTICLES)
	_p_base.resize(MAX_PARTICLES)
	_p_size.resize(MAX_PARTICLES)
	_p_age.resize(MAX_PARTICLES)
	_p_life.resize(MAX_PARTICLES)
	_p_buf.resize(MAX_PARTICLES * 16)
	_p_mm = _make_multimesh(PARTICLE_SHADER, MAX_PARTICLES, false)


func emit_particle(x: float, y: float, z: float, vx: float, vy: float, vz: float, color_hex: int, size: float, life: float) -> void:
	var slot := -1
	for n in MAX_PARTICLES:
		var c := (_p_next + n) % MAX_PARTICLES
		if _p_life[c] <= 0.0:
			slot = c
			break
	if slot == -1:
		slot = _p_next
		_p_alive -= 1
	_p_next = (slot + 1) % MAX_PARTICLES
	_p_pos[slot] = Vector3(x, y, z)
	_p_vel[slot] = Vector3(vx, vy, vz)
	_p_base[slot] = hex_color(color_hex).srgb_to_linear()
	_p_size[slot] = size
	_p_age[slot] = 0.0
	_p_life[slot] = life
	_p_alive += 1
	if slot >= _p_high:
		_p_high = slot + 1


func _update_particles(delta: float) -> void:
	if _p_alive <= 0:
		if _p_high != 0:
			_p_high = 0
			_p_mm.visible_instance_count = 0
		return
	var buf := _p_buf
	for i in _p_high:
		var o := i * 16
		var life := _p_life[i]
		if life <= 0.0:
			buf[o] = 0.0
			buf[o + 5] = 0.0
			buf[o + 10] = 0.0
			continue
		var age := _p_age[i] + delta
		if age >= life:
			_p_life[i] = 0.0
			_p_alive -= 1
			buf[o] = 0.0
			buf[o + 5] = 0.0
			buf[o + 10] = 0.0
			continue
		_p_age[i] = age
		var v := _p_vel[i]
		var p := _p_pos[i] + v * delta
		_p_pos[i] = p
		v.y -= PARTICLE_GRAVITY * delta
		_p_vel[i] = v
		var fade := 1.0 - age / life
		var c := _p_base[i]
		var s := _p_size[i] * POINT_TO_WORLD
		buf[o] = s; buf[o + 1] = 0.0; buf[o + 2] = 0.0; buf[o + 3] = p.x
		buf[o + 4] = 0.0; buf[o + 5] = s; buf[o + 6] = 0.0; buf[o + 7] = p.y
		buf[o + 8] = 0.0; buf[o + 9] = 0.0; buf[o + 10] = s; buf[o + 11] = p.z
		buf[o + 12] = c.r * fade; buf[o + 13] = c.g * fade; buf[o + 14] = c.b * fade; buf[o + 15] = 1.0
	_p_buf = buf
	RenderingServer.multimesh_set_buffer(_p_mm.get_rid(), _p_buf)
	_p_mm.visible_instance_count = _p_high


func create_treasure_drop_effect(pos: Vector3) -> void:
	for i in 30:
		var theta := randf() * TAU
		var phi := randf() * PI - PI / 2.0
		var speed := 60.0 + randf() * 140.0
		emit_particle(pos.x, pos.y + 10.0, pos.z, cos(phi) * cos(theta) * speed, sin(phi) * speed + 40.0,
			cos(phi) * sin(theta) * speed, 0xfacc15, 10.0, 0.9)


func create_pickup_particle_burst(pos: Vector3, color_hex: int = 0x38bdf8) -> void:
	for i in 24:
		var theta := randf() * TAU
		var phi := randf() * PI - PI / 2.0
		var speed := 80.0 + randf() * 120.0
		emit_particle(pos.x, pos.y + 10.0, pos.z, cos(phi) * cos(theta) * speed, sin(phi) * speed + 50.0,
			cos(phi) * sin(theta) * speed, color_hex, 8.0, 0.8)


# ---------------------------------------------------------------- Blood

func _init_blood() -> void:
	_b_col.resize(MAX_BLOOD)
	_b_pos.resize(MAX_BLOOD)
	_b_vel.resize(MAX_BLOOD)
	_b_size.resize(MAX_BLOOD)
	_b_base.resize(MAX_BLOOD)
	_b_soft.resize(MAX_BLOOD)
	_b_age.resize(MAX_BLOOD)
	_b_life.resize(MAX_BLOOD)
	_b_grav.resize(MAX_BLOOD)
	_b_drag.resize(MAX_BLOOD)
	_b_growth.resize(MAX_BLOOD)
	_b_floor.resize(MAX_BLOOD)
	_b_trail.resize(MAX_BLOOD)
	_b_buf.resize(MAX_BLOOD * 20)
	_b_mm = _make_multimesh(BLOOD_SHADER, MAX_BLOOD, true, "soft = INSTANCE_CUSTOM.x;")


func _emit_blood(x: float, y: float, z: float, vx: float, vy: float, vz: float, r: float, g: float, b: float, a: float,
		size: float, life: float, gravity: float, drag: float, growth: float, soft: float, floor_y: float, trail: bool) -> void:
	var slot := -1
	for n in MAX_BLOOD:
		var c := (_b_next + n) % MAX_BLOOD
		if _b_life[c] <= 0.0:
			slot = c
			break
	if slot == -1:
		slot = _b_next
		_b_alive -= 1
	_b_next = (slot + 1) % MAX_BLOOD
	_b_pos[slot] = Vector3(x, y, z)
	_b_vel[slot] = Vector3(vx, vy, vz)
	_b_col[slot] = Color(r, g, b, a)
	_b_size[slot] = size
	_b_base[slot] = size
	_b_soft[slot] = soft
	_b_age[slot] = 0.0
	_b_life[slot] = life
	_b_grav[slot] = gravity
	_b_drag[slot] = drag
	_b_growth[slot] = growth
	_b_floor[slot] = floor_y
	_b_trail[slot] = 1 if trail else 0
	_b_alive += 1
	if slot >= _b_high:
		_b_high = slot + 1


func _blood_decal_texture(seed: int) -> ImageTexture:
	var size := 128
	var half := size / 2.0
	var buf := PackedFloat32Array()
	buf.resize(size * size * 4)
	var s := seed * 9301 + 49297
	var rand := func() -> float:
		s = (s * 9301 + 49297) % 233280
		return s / 233280.0
	var blob := func(bx: float, by: float, rx: float, ry: float, rot: float, alpha: float) -> void:
		var ext := ceili(maxf(rx, ry)) + 1
		var cs := cos(-rot)
		var sn := sin(-rot)
		var yscale := ry / rx
		for py in range(maxi(0, floori(by) - ext), mini(size, ceili(by) + ext)):
			for px in range(maxi(0, floori(bx) - ext), mini(size, ceili(bx) + ext)):
				var dx := px + 0.5 - bx
				var dy := py + 0.5 - by
				var lx := dx * cs - dy * sn
				var ly := (dx * sn + dy * cs) / yscale
				var t := sqrt(lx * lx + ly * ly) / rx
				if t > 1.0:
					continue
				var cr: float
				var cg: float
				var ca: float
				if t <= 0.7:
					var k := t / 0.7
					cr = lerpf(96.0, 74.0, k)
					cg = lerpf(6.0, 4.0, k)
					ca = lerpf(alpha, alpha * 0.9, k)
				else:
					var k := (t - 0.7) / 0.3
					cr = lerpf(74.0, 60.0, k)
					cg = lerpf(4.0, 2.0, k)
					ca = lerpf(alpha * 0.9, 0.0, k)
				var o := (py * size + px) * 4
				var da := buf[o + 3]
				var oa := ca + da * (1.0 - ca)
				if oa <= 0.0:
					continue
				buf[o] = (cr / 255.0 * ca + buf[o] * da * (1.0 - ca)) / oa
				buf[o + 1] = (cg / 255.0 * ca + buf[o + 1] * da * (1.0 - ca)) / oa
				buf[o + 2] = (cg / 255.0 * ca + buf[o + 2] * da * (1.0 - ca)) / oa
				buf[o + 3] = oa
	blob.call(half, half, 20.0 + rand.call() * 8.0, 16.0 + rand.call() * 8.0, rand.call() * PI, 0.95)
	for i in 5:
		var a: float = rand.call() * TAU
		var r: float = 10.0 + rand.call() * 12.0
		blob.call(half + cos(a) * r, half + sin(a) * r, 8.0 + rand.call() * 8.0, 6.0 + rand.call() * 6.0, a, 0.9)
	for i in 16:
		var a: float = rand.call() * TAU
		var r: float = 26.0 + rand.call() * 32.0
		var rad: float = 2.0 + rand.call() * (2.5 if r > 48.0 else 5.0)
		blob.call(half + cos(a) * r, half + sin(a) * r, rad * 2.2, rad, a, 0.95)
	for i in 5:
		var a: float = rand.call() * TAU
		var length: float = 18.0 + rand.call() * 20.0
		for k in 4:
			var r := 14.0 + k * (length / 4.0)
			var rad := 5.0 - k
			blob.call(half + cos(a) * r, half + sin(a) * r, rad * 2.0, rad, a, 0.9)
	var bytes := PackedByteArray()
	bytes.resize(size * size * 4)
	for i in size * size * 4:
		bytes[i] = clampi(int(round(buf[i] * 255.0)), 0, 255)
	var img := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _ensure_decals() -> void:
	if not _decals.is_empty():
		return
	for i in 5:
		_decal_textures.append(_blood_decal_texture(i + 1))
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	for i in MAX_BLOOD_DECALS:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = _decal_textures[i % _decal_textures.size()]
		mat.render_priority = 1
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = mat
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_decals.append({"mesh": mi, "mat": mat, "active": false, "age": 0.0, "target": 1.0, "grow": 0.15})


func _spawn_blood_decal(x: float, floor_y: float, z: float, size: float, grow_time: float = 0.15, shade: float = 1.0) -> void:
	_ensure_decals()
	var d: Dictionary = _decals[_decal_next]
	_decal_next = (_decal_next + 1) % _decals.size()
	d.active = true
	d.age = 0.0
	d.target = size
	d.grow = grow_time
	var mi: MeshInstance3D = d.mesh
	mi.visible = true
	mi.position = Vector3(x, floor_y + 0.8, z)
	mi.rotation = Vector3(0, randf() * TAU, 0)
	mi.scale = Vector3.ONE * (size * 0.3)
	var mat: StandardMaterial3D = d.mat
	mat.albedo_texture = _decal_textures[randi() % _decal_textures.size()]
	mat.albedo_color = Color(shade, shade, shade, 1.0)


# Sprays blood from a point. `dir` is the direction the blow travels (attacker -> victim).
func create_blood_splatter(pos: Vector3, dir: Vector3, severity: float, floor_y: float, base_color_hex: int = 0x9a0a0a, killed: bool = false) -> void:
	var sev := minf(1.0, maxf(0.15, severity))
	var boost := 2.0 if killed else 1.0
	var bc := hex_color(base_color_hex).srgb_to_linear()
	var br := bc.r
	var bg := bc.g
	var bb := bc.b
	var flat := Vector2(dir.x, dir.z).length()
	if flat == 0.0:
		flat = 1.0
	var fx := dir.x / flat
	var fz := dir.z / flat

	var droplet_count := roundi((18.0 + 46.0 * sev) * boost)
	for i in droplet_count:
		var back := randf() < 0.22
		var spread := 0.35 + randf() * 0.75
		var speed := (110.0 + randf() * 260.0) * (0.7 + sev * 0.5) * (0.6 if back else 1.0)
		var sign := -1.0 if back else 1.0
		var vx := (fx * sign + (randf() - 0.5) * 2.0 * spread) * speed
		var vz := (fz * sign + (randf() - 0.5) * 2.0 * spread) * speed
		var vy := (randf() * 0.9 - 0.15) * speed * 0.9 + 40.0
		var shade := 0.45 + randf() * 0.8
		var big := randf() < 0.18
		var size := (2.6 + randf() * 2.4) if big else (1.1 + randf() * 2.0)
		_emit_blood(pos.x + (randf() - 0.5) * 6.0, pos.y + (randf() - 0.5) * 8.0, pos.z + (randf() - 0.5) * 6.0,
			vx, vy, vz, minf(1.0, br * shade), minf(1.0, bg * shade), minf(1.0, bb * shade), 1.0,
			size, 1.6 + randf() * 0.8, BLOOD_GRAVITY, 0.25, 0.0, 0.0, floor_y, big and randf() < 0.6)

	var mist_count := roundi((7.0 + 9.0 * sev) * boost)
	for i in mist_count:
		var speed := 40.0 + randf() * 150.0
		var shade := 0.5 + randf() * 0.5
		_emit_blood(pos.x + (randf() - 0.5) * 8.0, pos.y + (randf() - 0.5) * 10.0, pos.z + (randf() - 0.5) * 8.0,
			(fx * 0.8 + (randf() - 0.5) * 1.4) * speed, (randf() - 0.1) * speed * 0.6, (fz * 0.8 + (randf() - 0.5) * 1.4) * speed,
			br * shade, bg * shade, bb * shade, 0.55 + randf() * 0.25,
			9.0 + randf() * 12.0 + sev * 6.0, 0.45 + randf() * 0.35, 40.0, 3.2, 1.4, 1.0, floor_y, false)

	if sev > 0.45 or killed:
		var jets := 7 if killed else 3
		for j in jets:
			var ang := atan2(fz, fx) + (randf() - 0.5) * 2.2
			var jx := cos(ang)
			var jz := sin(ang)
			var jet_speed := 260.0 + randf() * 220.0
			var jet_up := 120.0 + randf() * 200.0
			for k in 7:
				var sp := jet_speed * (0.8 + randf() * 0.4)
				_emit_blood(pos.x, pos.y, pos.z, jx * sp, jet_up * (0.8 + randf() * 0.4), jz * sp,
					minf(1.0, br * 1.25), bg * 0.9, bb * 0.9, 1.0,
					2.2 + randf() * 1.8, 1.4 + randf() * 0.5, BLOOD_GRAVITY, 0.1, 0.0, 0.0, floor_y, true)

	_spawn_blood_decal(pos.x + fx * 14.0, floor_y, pos.z + fz * 14.0, 26.0 + 34.0 * sev * boost, 0.2)
	if killed:
		_spawn_blood_decal(pos.x, floor_y, pos.z, 85.0 + randf() * 30.0, 5.0, 0.9)
		_spawn_blood_decal(pos.x + fx * 30.0, floor_y, pos.z + fz * 30.0, 55.0, 3.5, 0.95)


func _update_blood_decals(delta: float) -> void:
	for d: Dictionary in _decals:
		if not d.active:
			continue
		d.age += delta
		var grow := minf(1.0, d.age / d.grow)
		var eased := 1.0 - pow(1.0 - grow, 3.0)
		var mi: MeshInstance3D = d.mesh
		mi.scale = Vector3.ONE * (d.target * (0.3 + 0.7 * eased))
		if d.age > BLOOD_DECAL_HOLD:
			var f: float = (d.age - BLOOD_DECAL_HOLD) / BLOOD_DECAL_FADE
			if f >= 1.0:
				d.active = false
				mi.visible = false
				continue
			var mat: StandardMaterial3D = d.mat
			mat.albedo_color.a = 1.0 - f


func _update_blood(delta: float) -> void:
	_update_blood_decals(delta)
	if _b_alive <= 0:
		if _b_high != 0:
			_b_high = 0
			_b_mm.visible_instance_count = 0
		return
	var high := _b_high
	for i in high:
		var life := _b_life[i]
		if life <= 0.0:
			_b_size[i] = 0.0
			continue
		var age := _b_age[i] + delta
		if age >= life:
			_b_life[i] = 0.0
			_b_size[i] = 0.0
			_b_alive -= 1
			continue
		_b_age[i] = age
		var t := age / life
		var is_mist := _b_soft[i] > 0.5
		var damping := maxf(0.0, 1.0 - _b_drag[i] * delta)
		var v := _b_vel[i]
		v.x *= damping
		v.z *= damping
		v.y = v.y * damping - _b_grav[i] * delta
		_b_vel[i] = v
		var p := _b_pos[i] + v * delta
		_b_pos[i] = p
		var c := _b_col[i]
		if is_mist:
			_b_size[i] = _b_base[i] * (1.0 + _b_growth[i] * t)
			c.a *= 1.0 - minf(1.0, delta * 1.6 / (1.0 - t + 0.2))
		else:
			if p.y <= _b_floor[i]:
				var base_size := _b_base[i]
				if base_size > 2.0 or randf() < 0.25:
					_spawn_blood_decal(p.x, _b_floor[i], p.z, 7.0 + base_size * 5.0 + randf() * 8.0, 0.1)
				_b_life[i] = 0.0
				_b_size[i] = 0.0
				_b_alive -= 1
				continue
			if _b_trail[i] == 1 and t < 0.4 and randf() < 0.55:
				_emit_blood(p.x, p.y, p.z, v.x * 0.15, v.y * 0.15, v.z * 0.15, c.r, c.g, c.b, 0.9,
					_b_base[i] * 0.45, 0.35, BLOOD_GRAVITY * 0.4, 1.5, 0.0, 0.0, _b_floor[i], false)
			if t > 0.85:
				c.a = (1.0 - t) / 0.15
		_b_col[i] = c
	high = _b_high
	var buf := _b_buf
	for i in high:
		var o := i * 20
		var s := 0.0
		if _b_life[i] > 0.0:
			s = _b_size[i] * POINT_TO_WORLD
		var p := _b_pos[i]
		var c := _b_col[i]
		buf[o] = s; buf[o + 1] = 0.0; buf[o + 2] = 0.0; buf[o + 3] = p.x
		buf[o + 4] = 0.0; buf[o + 5] = s; buf[o + 6] = 0.0; buf[o + 7] = p.y
		buf[o + 8] = 0.0; buf[o + 9] = 0.0; buf[o + 10] = s; buf[o + 11] = p.z
		buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = c.a if s > 0.0 else 0.0
		buf[o + 16] = _b_soft[i]; buf[o + 17] = 0.0; buf[o + 18] = 0.0; buf[o + 19] = 0.0
	_b_buf = buf
	RenderingServer.multimesh_set_buffer(_b_mm.get_rid(), _b_buf)
	_b_mm.visible_instance_count = high


func clear_blood() -> void:
	for i in MAX_BLOOD:
		_b_life[i] = 0.0
		_b_size[i] = 0.0
	_b_alive = 0
	_b_high = 0
	_b_mm.visible_instance_count = 0
	for d: Dictionary in _decals:
		d.active = false
		(d.mesh as MeshInstance3D).visible = false


# ---------------------------------------------------------------- Floating text

# three.js canvas textures are not colour managed: their sRGB values are treated as linear,
# so they appear brighter on screen. This returns the sRGB colour that reproduces that look.
static func canvas_color(css: String) -> Color:
	var c := Color.html(css)
	var out := c.linear_to_srgb()
	out.a = c.a
	return out


func create_floating_text(text: String, pos: Vector3, css: String = "#38bdf8") -> void:
	var label := Label3D.new()
	label.text = text
	label.font = _text_font
	label.font_size = 14
	label.pixel_size = 120.0 / 256.0
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 1)
	label.modulate = canvas_color(css)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	label.position = pos + Vector3(0, 30, 0)
	label.render_priority = 5
	label.outline_render_priority = 4
	add_child(label)
	floating_texts.append({"label": label, "timer": 0.0, "duration": 1.2})


func update_pickup_effects(delta: float) -> void:
	for i in range(floating_texts.size() - 1, -1, -1):
		var item: Dictionary = floating_texts[i]
		item.timer += delta
		var progress: float = item.timer / item.duration
		var label: Label3D = item.label
		label.position.y += 30.0 * delta
		var a := maxf(0.0, 1.0 - progress)
		label.modulate.a = a
		label.outline_modulate.a = a
		if progress >= 1.0:
			label.queue_free()
			floating_texts.remove_at(i)
	_update_particles(delta)
	_update_blood(delta)


func clear_floating_texts() -> void:
	for item: Dictionary in floating_texts:
		(item.label as Label3D).queue_free()
	floating_texts.clear()
