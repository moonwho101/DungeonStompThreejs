# Circular minimap (port of minimap.js). The static level is baked once per level into a 2D mesh of
# floors and wall strokes, then drawn with a moving transform; doors, items, monsters and portals
# are drawn on top every refresh.
class_name Minimap
extends Control

const VIEW_RADIUS := 1600.0
const VIEW_RADIUS_SQ := (VIEW_RADIUS * 1.2) * (VIEW_RADIUS * 1.2)
const REDRAW_INTERVAL := 1.0 / 30.0
const FLOOR_COLOR := Color("#1f3050")
const WALL_COLOR := Color("#9fb3cf")
const WALL_WIDTH := 7.5 # 1.5 px on the browser's 200 px / 1000 unit tiles

var game # Game
var _level_mesh: ArrayMesh = null
var _baked_revision := -1
var _timer := 0.0
var _player_pos := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _font: SystemFont


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Segoe UI", "Arial", "sans-serif"])
	_font.font_weight = 700


func level_changed() -> void:
	_baked_revision = -1


func _bake() -> void:
	var cw: CollisionWorld = game.collision
	_baked_revision = cw.revision
	var verts := PackedVector2Array()
	var colors := PackedColorArray()
	for i in cw.static_count:
		if cw.tplanar[i] == 0:
			continue
		var ny: float = cw.tn[i].y
		var is_floor := ny > 0.6
		if not is_floor and absf(ny) > 0.35:
			continue # ceilings and slanted decor would only add clutter
		var a: Vector3 = cw.ta[i]
		var b: Vector3 = cw.tb[i]
		var c: Vector3 = cw.tc[i]
		if is_floor:
			verts.append(Vector2(a.x, a.z))
			verts.append(Vector2(b.x, b.z))
			verts.append(Vector2(c.x, c.z))
			colors.append(FLOOR_COLOR)
			colors.append(FLOOR_COLOR)
			colors.append(FLOOR_COLOR)
	# Walls go after floors so they are drawn on top.
	for i in cw.static_count:
		if cw.tplanar[i] == 0:
			continue
		var ny: float = cw.tn[i].y
		if ny > 0.6 or absf(ny) > 0.35:
			continue
		# A vertical wall triangle collapses to a line in plan view: keep its longest edge.
		var a := Vector2(cw.ta[i].x, cw.ta[i].z)
		var b := Vector2(cw.tb[i].x, cw.tb[i].z)
		var c := Vector2(cw.tc[i].x, cw.tc[i].z)
		var ab := a.distance_squared_to(b)
		var bc := b.distance_squared_to(c)
		var ca := c.distance_squared_to(a)
		var p := a
		var q := b
		if bc >= ab and bc >= ca:
			p = b
			q = c
		elif ca >= ab and ca >= bc:
			p = c
			q = a
		var d := q - p
		if d.length_squared() < 1e-6:
			continue
		var n := Vector2(-d.y, d.x).normalized() * (WALL_WIDTH * 0.5)
		var ext := d.normalized() * (WALL_WIDTH * 0.5)
		var p0 := p - ext + n
		var p1 := q + ext + n
		var p2 := q + ext - n
		var p3 := p - ext - n
		verts.append_array([p0, p1, p2, p0, p2, p3])
		for k in 6:
			colors.append(WALL_COLOR)
	_level_mesh = ArrayMesh.new()
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	_level_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func update_minimap(player_pos: Vector3, camera: Camera3D, delta: float) -> void:
	_timer += delta
	if _timer < REDRAW_INTERVAL:
		return
	_timer = 0.0
	_player_pos = player_pos
	_yaw = camera.rotation.y
	_pitch = camera.rotation.x
	queue_redraw()


func _dots(list: Array, radius: float, sc: float, center: Vector2, color: Color, filter: Callable) -> void:
	for item in list:
		if not filter.call(item):
			continue
		var p: Vector3 = item.position
		var dx := p.x - _player_pos.x
		var dz := p.z - _player_pos.z
		if dx * dx + dz * dz > VIEW_RADIUS_SQ:
			continue
		draw_circle(center + Vector2(dx, dz) * sc, radius, color)


func _draw() -> void:
	if game == null:
		return
	var size_px := minf(size.x, size.y)
	var c := size_px / 2.0
	var center := Vector2(c, c)
	var sc := c / VIEW_RADIUS
	var px := _player_pos.x
	var pz := _player_pos.z
	draw_rect(Rect2(Vector2.ZERO, Vector2(size_px, size_px)), Color("#0a0e17"))

	if _baked_revision != game.collision.revision:
		_bake()
	if _level_mesh != null and _level_mesh.get_surface_count() > 0:
		draw_set_transform(center - Vector2(px, pz) * sc, 0.0, Vector2(sc, sc))
		draw_mesh(_level_mesh, null)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var dot := size_px / 160.0

	# Closed doors
	var lines := PackedVector2Array()
	var cw: CollisionWorld = game.collision
	for door: Dictionary in game.doors:
		if door.is_open:
			continue
		var dp: Vector3 = door.position
		if (dp.x - px) * (dp.x - px) + (dp.z - pz) * (dp.z - pz) > VIEW_RADIUS_SQ:
			continue
		for t in range(door.tri_start, door.tri_start + door.tri_count):
			var a := center + Vector2(cw.ta[t].x - px, cw.ta[t].z - pz) * sc
			var b := center + Vector2(cw.tb[t].x - px, cw.tb[t].z - pz) * sc
			var cc := center + Vector2(cw.tc[t].x - px, cw.tc[t].z - pz) * sc
			lines.append_array([a, b, b, cc])
	if not lines.is_empty():
		draw_multiline(lines, Color("#f59e0b"), 3.0 * dot)

	_dots(game.chests, 3.5 * dot, sc, center, Color("#facc15"), func(ch): return not ch.is_open)
	_dots(game.active_pickups, 2.5 * dot, sc, center, Color("#4ade80"),
		func(p): return p.state == "ACTIVE" and p.def.get("type", "") == "health")
	_dots(game.active_pickups, 2.5 * dot, sc, center, Color("#38bdf8"),
		func(p): return p.state == "ACTIVE" and p.def.get("type", "") != "health")
	_dots(game.monsters, 3.5 * dot, sc, center, Color("#f87171"),
		func(m): return not m.dead and m.state != Monster.State.CHASE and m.state != Monster.State.ATTACK)
	_dots(game.monsters, 4.0 * dot, sc, center, Color("#ef4444"),
		func(m): return m.state == Monster.State.CHASE or m.state == Monster.State.ATTACK)

	# Exit portals: pulse on the map, or point toward them from the rim when out of view.
	var now := Time.get_ticks_msec()
	var pulse := 0.5 + 0.5 * sin(now / 250.0)
	var rim := c - 10.0 * dot
	for tp: Dictionary in game.active_teleporters:
		var tpos: Vector3 = tp.position
		var dx := tpos.x - px
		var dz := tpos.z - pz
		var dist := sqrt(dx * dx + dz * dz)
		if dist * sc < rim:
			var p := center + Vector2(dx, dz) * sc
			draw_arc(p, (4.0 + 3.0 * pulse) * dot, 0.0, TAU, 24, Color("#e0f2fe"), 1.5 * dot, true)
			draw_circle(p, 3.0 * dot, Color("#38bdf8"))
		else:
			var ang := atan2(dz, dx)
			var e := center + Vector2(cos(ang), sin(ang)) * rim
			var tri := PackedVector2Array([
				e + Vector2(cos(ang), sin(ang)) * 6.0 * dot,
				e + Vector2(cos(ang + 2.4), sin(ang + 2.4)) * 5.0 * dot,
				e + Vector2(cos(ang - 2.4), sin(ang - 2.4)) * 5.0 * dot])
			var col := Color("#38bdf8")
			col.a = 0.6 + 0.4 * pulse
			draw_colored_polygon(tri, col)

	# Player marker and view cone. Canvas angle: +X right (0 rad), +Z down (PI/2 rad).
	var cos_pitch := cos(_pitch)
	var angle := atan2(-cos(_yaw) * cos_pitch, -sin(_yaw) * cos_pitch)
	var cone := PackedVector2Array([center])
	for k in 13:
		var a := angle - 0.4 + 0.8 * k / 12.0
		cone.append(center + Vector2(cos(a), sin(a)) * 28.0 * dot)
	draw_colored_polygon(cone, Color(251 / 255.0, 191 / 255.0, 36 / 255.0, 0.22))
	var arrow_len := 8.0 * dot
	var arrow := PackedVector2Array([
		center + Vector2(cos(angle), sin(angle)) * arrow_len,
		center + Vector2(cos(angle + 2.5), sin(angle + 2.5)) * arrow_len * 0.7,
		center + Vector2(cos(angle - 2.5), sin(angle - 2.5)) * arrow_len * 0.7])
	draw_colored_polygon(arrow, Color("#f59e0b"))
	var outline := arrow.duplicate()
	outline.append(arrow[0])
	draw_polyline(outline, Color.WHITE, dot, true)
	var fs := roundi(9.0 * dot)
	var tw := _font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, Vector2(c - tw / 2.0, 14.0 * dot), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#ef4444"))
