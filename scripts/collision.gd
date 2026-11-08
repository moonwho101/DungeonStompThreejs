# Capsule collision against the static level triangles, door triangles, model boxes and other
# actors (port of collision.js). Triangles are stored as packed arrays for speed.
class_name CollisionWorld
extends RefCounted

const CAPSULE_RADIUS := 28.0
const CAPSULE_HEIGHT := 105.0
const EYE_HEIGHT := 100.0
const GRAVITY := 1600.0
const JUMP_SPEED := 520.0
const MONSTER_CAPSULE_RADIUS := 24.0
const MONSTER_CAPSULE_HEIGHT := 80.0
const MONSTER_FOOT_OFFSET := 50.0
const STAND_ON_MAX_LIFT := 20.0
const GRID_CELL_SIZE := 256.0


class Box:
	var min: Vector3 = Vector3(INF, INF, INF)
	var max: Vector3 = Vector3(-INF, -INF, -INF)

	func is_empty() -> bool:
		return max.x < min.x or max.y < min.y or max.z < min.z

	func make_empty() -> void:
		min = Vector3(INF, INF, INF)
		max = Vector3(-INF, -INF, -INF)

	func expand(p: Vector3) -> void:
		min = min.min(p)
		max = max.max(p)

	func contains_point(p: Vector3) -> bool:
		return not (p.x < min.x or p.x > max.x or p.y < min.y or p.y > max.y or p.z < min.z or p.z > max.z)

	func distance_to_point(p: Vector3) -> float:
		return p.clamp(min, max).distance_to(p)


# Triangle storage
var ta := PackedVector3Array()
var tb := PackedVector3Array()
var tc := PackedVector3Array()
var tn := PackedVector3Array()
var tplanar := PackedByteArray()
var tmin := PackedVector3Array()
var tmax := PackedVector3Array()
var tstamp := PackedInt32Array()
var static_count := 0

var grid: Dictionary = {}
var boxes: Array = [] # Array[Box] (model boxes)
var doors: Array = [] # objects with tri_start, tri_count, bounds_min, bounds_max
var revision := 0
var _query_stamp := 0

# Output of the last resolve call
var out_pos := Vector3.ZERO
var out_vel := Vector3.ZERO


func clear() -> void:
	ta.clear(); tb.clear(); tc.clear(); tn.clear(); tplanar.clear()
	tmin.clear(); tmax.clear(); tstamp.clear()
	static_count = 0
	grid.clear()
	boxes.clear()
	doors.clear()


func add_triangle(a: Vector3, b: Vector3, c: Vector3) -> int:
	var n := (b - a).cross(c - a)
	var planar := n.length_squared() > 1e-10
	ta.append(a)
	tb.append(b)
	tc.append(c)
	tn.append(n.normalized() if planar else (n / n.length() if n.length() > 0.0 else Vector3.ZERO))
	tplanar.append(1 if planar else 0)
	tmin.append(a.min(b).min(c))
	tmax.append(a.max(b).max(c))
	tstamp.append(0)
	return ta.size() - 1


func triangle_count() -> int:
	return ta.size()


# Moves door triangles vertically (doors slide up when opened).
func offset_triangles_y(start: int, count: int, dy: float) -> void:
	var d := Vector3(0, dy, 0)
	for i in range(start, start + count):
		ta[i] += d
		tb[i] += d
		tc[i] += d
		tmin[i] += d
		tmax[i] += d


static func grid_key(cx: int, cy: int, cz: int) -> int:
	return ((cx + 512) * 1024 + (cy + 512)) * 1024 + (cz + 512)


# Static triangles are everything added before this call; later ones (doors) are queried separately.
func build_grid() -> void:
	revision += 1
	grid.clear()
	static_count = ta.size()
	var tmp := {}
	for i in static_count:
		var mn := tmin[i]
		var mx := tmax[i]
		var min_cx := floori(mn.x / GRID_CELL_SIZE)
		var max_cx := floori(mx.x / GRID_CELL_SIZE)
		var min_cy := floori(mn.y / GRID_CELL_SIZE)
		var max_cy := floori(mx.y / GRID_CELL_SIZE)
		var min_cz := floori(mn.z / GRID_CELL_SIZE)
		var max_cz := floori(mx.z / GRID_CELL_SIZE)
		for cx in range(min_cx, max_cx + 1):
			for cy in range(min_cy, max_cy + 1):
				for cz in range(min_cz, max_cz + 1):
					var key := grid_key(cx, cy, cz)
					var cell = tmp.get(key)
					if cell == null:
						cell = []
						tmp[key] = cell
					cell.append(i)
	for key in tmp:
		grid[key] = PackedInt32Array(tmp[key])


func gather_nearby_triangles(mn: Vector3, mx: Vector3) -> PackedInt32Array:
	var out := PackedInt32Array()
	_query_stamp += 1
	var stamp := _query_stamp
	var min_cx := floori(mn.x / GRID_CELL_SIZE)
	var max_cx := floori(mx.x / GRID_CELL_SIZE)
	var min_cy := floori(mn.y / GRID_CELL_SIZE)
	var max_cy := floori(mx.y / GRID_CELL_SIZE)
	var min_cz := floori(mn.z / GRID_CELL_SIZE)
	var max_cz := floori(mx.z / GRID_CELL_SIZE)
	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			for cz in range(min_cz, max_cz + 1):
				var cell = grid.get(grid_key(cx, cy, cz))
				if cell == null:
					continue
				for i: int in cell:
					if tstamp[i] == stamp:
						continue
					tstamp[i] = stamp
					var a := tmax[i]
					var b := tmin[i]
					if a.x < mn.x or b.x > mx.x or a.y < mn.y or b.y > mx.y or a.z < mn.z or b.z > mx.z:
						continue
					out.append(i)
	for door in doors:
		var bmin: Vector3 = door.bounds_min
		var bmax: Vector3 = door.bounds_max
		if bmax.x < mn.x or bmin.x > mx.x or bmax.y < mn.y or bmin.y > mx.y or bmax.z < mn.z or bmin.z > mx.z:
			continue
		for i in range(door.tri_start, door.tri_start + door.tri_count):
			var a := tmax[i]
			var b := tmin[i]
			if a.x < mn.x or b.x > mx.x or a.y < mn.y or b.y > mx.y or a.z < mn.z or b.z > mx.z:
				continue
			out.append(i)
	return out


func gather_nearby_boxes(mn: Vector3, mx: Vector3) -> Array:
	var out: Array = []
	for box: Box in boxes:
		if box.is_empty():
			continue
		if box.max.x < mn.x or box.min.x > mx.x or box.max.y < mn.y or box.min.y > mx.y or box.max.z < mn.z or box.min.z > mx.z:
			continue
		out.append(box)
	return out


func has_line_of_sight(from_pos: Vector3, to_pos: Vector3) -> bool:
	var dist := from_pos.distance_to(to_pos)
	if dist <= 1.0:
		return true
	var step_size := 35.0
	var steps := maxi(1, floori(dist / step_size))
	var near_boxes := gather_nearby_boxes(from_pos.min(to_pos) - Vector3(25, 25, 25), from_pos.max(to_pos) + Vector3(25, 25, 25))
	var pad := Vector3(25, 25, 25)
	for i in range(1, steps):
		var sample := from_pos.lerp(to_pos, float(i) / steps)
		var tris := gather_nearby_triangles(sample - pad, sample + pad)
		for t in tris:
			var cp := closest_point_triangle_point(ta[t], tb[t], tc[t], sample)
			if sample.distance_squared_to(cp) <= 400.0:
				return false
		for box: Box in near_boxes:
			if box.contains_point(sample):
				return false
	return true


static func closest_point_segment_point(a: Vector3, b: Vector3, p: Vector3) -> Vector3:
	var ab := b - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq < 1e-8:
		return a
	var t := clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return a + ab * t


static func closest_point_triangle_point(v0: Vector3, v1: Vector3, v2: Vector3, p: Vector3) -> Vector3:
	var v10 := v1 - v0
	var v20 := v2 - v0
	var vp0 := p - v0
	var d1 := v10.dot(vp0)
	var d2 := v20.dot(vp0)
	if d1 <= 0.0 and d2 <= 0.0:
		return v0
	var vp1 := p - v1
	var d3 := v10.dot(vp1)
	var d4 := v20.dot(vp1)
	if d3 >= 0.0 and d4 <= d3:
		return v1
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return v0 + v10 * (d1 / (d1 - d3))
	var vp2 := p - v2
	var d5 := v10.dot(vp2)
	var d6 := v20.dot(vp2)
	if d6 >= 0.0 and d5 <= d6:
		return v2
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return v0 + v20 * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return v1 + (v2 - v1) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return v0 + v10 * (vb * denom) + v20 * (vc * denom)


var _seg_p1 := Vector3.ZERO
var _seg_p2 := Vector3.ZERO

func _closest_points_segment_segment(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var u := b - a
	var v := d - c
	var w := a - c
	var a_dot := u.dot(u)
	var b_dot := u.dot(v)
	var c_dot := v.dot(v)
	var d_dot := u.dot(w)
	var e_dot := v.dot(w)
	var D := a_dot * c_dot - b_dot * b_dot
	var sN: float
	var sD := D
	var tN: float
	var tD := D
	if D < 1e-8:
		sN = 0.0
		sD = 1.0
		tN = e_dot
		tD = c_dot
	else:
		sN = b_dot * e_dot - c_dot * d_dot
		tN = a_dot * e_dot - b_dot * d_dot
		if sN < 0.0:
			sN = 0.0
			tN = e_dot
			tD = c_dot
		elif sN > sD:
			sN = sD
			tN = e_dot + b_dot
			tD = c_dot
	if tN < 0.0:
		tN = 0.0
		if -d_dot < 0.0:
			sN = 0.0
		elif -d_dot > a_dot:
			sN = sD
		else:
			sN = -d_dot
			sD = a_dot
	elif tN > tD:
		tN = tD
		if (-d_dot + b_dot) < 0.0:
			sN = 0.0
		elif (-d_dot + b_dot) > a_dot:
			sN = sD
		else:
			sN = -d_dot + b_dot
			sD = a_dot
	var sc := 0.0 if absf(sN) < 1e-8 else sN / sD
	var tc2 := 0.0 if absf(tN) < 1e-8 else tN / tD
	_seg_p1 = a + u * sc
	_seg_p2 = c + v * tc2


# Results of _capsule_triangle
var _res_cap := Vector3.ZERO
var _res_tri := Vector3.ZERO
var _res_dist := 0.0
var _res_pierced := false
var _res_normal := Vector3.ZERO

func _capsule_triangle(cap_a: Vector3, cap_b: Vector3, i: int) -> void:
	var v0 := ta[i]
	var v1 := tb[i]
	var v2 := tc[i]
	_res_pierced = false
	if tplanar[i] == 1:
		var n := tn[i]
		var dA := n.dot(cap_a - v0)
		var dB := n.dot(cap_b - v0)
		if dA * dB < 0.0:
			var t := dA / (dA - dB)
			var pierce := cap_a.lerp(cap_b, t)
			var cp := closest_point_triangle_point(v0, v1, v2, pierce)
			if cp.distance_squared_to(pierce) < 1e-6:
				var a_near := absf(dA) <= absf(dB)
				_res_normal = -n if (dA if a_near else dB) > 0.0 else n
				_res_cap = pierce
				_res_tri = pierce
				_res_dist = -minf(absf(dA), absf(dB))
				_res_pierced = true
				return

	var min_dist_sq := INF
	var pt := closest_point_triangle_point(v0, v1, v2, cap_a)
	var pc := closest_point_segment_point(cap_a, cap_b, pt)
	var d_sq := pc.distance_squared_to(pt)
	if d_sq < min_dist_sq:
		min_dist_sq = d_sq
		_res_cap = pc
		_res_tri = pt
	pt = closest_point_triangle_point(v0, v1, v2, cap_b)
	pc = closest_point_segment_point(cap_a, cap_b, pt)
	d_sq = pc.distance_squared_to(pt)
	if d_sq < min_dist_sq:
		min_dist_sq = d_sq
		_res_cap = pc
		_res_tri = pt
	_closest_points_segment_segment(cap_a, cap_b, v0, v1)
	d_sq = _seg_p1.distance_squared_to(_seg_p2)
	if d_sq < min_dist_sq:
		min_dist_sq = d_sq
		_res_cap = _seg_p1
		_res_tri = _seg_p2
	_closest_points_segment_segment(cap_a, cap_b, v1, v2)
	d_sq = _seg_p1.distance_squared_to(_seg_p2)
	if d_sq < min_dist_sq:
		min_dist_sq = d_sq
		_res_cap = _seg_p1
		_res_tri = _seg_p2
	_closest_points_segment_segment(cap_a, cap_b, v2, v0)
	d_sq = _seg_p1.distance_squared_to(_seg_p2)
	if d_sq < min_dist_sq:
		min_dist_sq = d_sq
		_res_cap = _seg_p1
		_res_tri = _seg_p2
	_res_dist = sqrt(min_dist_sq)


var _contact_normal := Vector3.ZERO

func _cylinder_contact(px: float, pz: float, base_y: float, top_y: float, ox: float, oz: float,
		o_base_y: float, o_top_y: float, sum_radius: float, stand_on: bool) -> float:
	if base_y >= o_top_y or o_base_y >= top_y:
		return 0.0
	var dx := px - ox
	var dz := pz - oz
	var dist_sq := dx * dx + dz * dz
	if dist_sq >= sum_radius * sum_radius:
		return 0.0
	if stand_on:
		var lift := o_top_y - base_y
		if lift <= STAND_ON_MAX_LIFT:
			_contact_normal = Vector3(0, 1, 0)
			return lift
	if dist_sq > 1e-8:
		var dist := sqrt(dist_sq)
		_contact_normal = Vector3(dx / dist, 0, dz / dist)
		return sum_radius - dist
	_contact_normal = Vector3(1, 0, 0)
	return sum_radius


# Pushes a capsule out of the world. Result position/velocity are left in out_pos/out_vel.
# monster_list entries need `position`, `state` (Monster.DEATH == dead).
func resolve_capsule_world(pos: Vector3, foot_offset: float, radius: float, height: float, vel: Vector3,
		has_vel: bool, self_monster: Object, monster_list: Array, has_player: bool, player_pos: Vector3) -> bool:
	var base_y := pos.y - foot_offset
	var vel_y_padding := absf(vel.y * 0.2) if has_vel else 0.0
	var qmin := Vector3(pos.x - radius - 30.0, base_y - 50.0 - vel_y_padding, pos.z - radius - 30.0)
	var qmax := Vector3(pos.x + radius + 30.0, base_y + height + 50.0 + vel_y_padding, pos.z + radius + 30.0)
	var tris := gather_nearby_triangles(qmin, qmax)
	var near_boxes := gather_nearby_boxes(qmin, qmax)

	var grounded := false
	var best_normal := Vector3.ZERO
	for _iter in 6:
		var cur_base_y := pos.y - foot_offset
		var cap_a := Vector3(pos.x, cur_base_y + radius, pos.z)
		var cap_b := Vector3(pos.x, cur_base_y + height - radius, pos.z)
		var max_pen := 0.0

		for i in tris:
			# Exact early-out: a segment farther than `radius` from the triangle's plane cannot touch it.
			if tplanar[i] == 1:
				var n := tn[i]
				var v0 := ta[i]
				var dA := n.dot(cap_a - v0)
				var dB := n.dot(cap_b - v0)
				if dA * dB >= 0.0 and minf(absf(dA), absf(dB)) >= radius:
					continue
			_capsule_triangle(cap_a, cap_b, i)
			if _res_dist >= radius:
				continue
			var pen := radius - _res_dist
			if pen <= max_pen:
				continue
			var cn: Vector3
			if _res_pierced:
				cn = _res_normal
			else:
				cn = _res_cap - _res_tri
				var face_n := tn[i]
				if cn.length_squared() > 1e-8:
					cn = cn.normalized()
				else:
					cn = face_n
					var mid_y := (cap_a.y + cap_b.y) * 0.5
					if cn.x * (pos.x - _res_tri.x) + cn.y * (mid_y - _res_tri.y) + cn.z * (pos.z - _res_tri.z) < 0.0:
						cn = -cn
				if absf(face_n.y) > 0.7 and absf(cn.y) > 0.5:
					cn = Vector3(0, 1.0 if cn.y > 0.0 else -1.0, 0)
			max_pen = pen
			best_normal = cn

		for box: Box in near_boxes:
			var bx := clampf(cap_a.x, box.min.x, box.max.x)
			var bz := clampf(cap_a.z, box.min.z, box.max.z)
			var lo := maxf(cap_a.y, box.min.y)
			var hi := minf(cap_b.y, box.max.y)
			var cap_y: float
			var box_y: float
			if lo <= hi:
				cap_y = (lo + hi) * 0.5
				box_y = cap_y
			elif cap_b.y < box.min.y:
				cap_y = cap_b.y
				box_y = box.min.y
			else:
				cap_y = cap_a.y
				box_y = box.max.y
			var cap_p := Vector3(cap_a.x, cap_y, cap_a.z)
			var box_p := Vector3(bx, box_y, bz)
			var dist := cap_p.distance_to(box_p)
			if dist >= radius:
				continue
			var pen: float
			var cn: Vector3
			if dist > 1e-4:
				pen = radius - dist
				cn = (cap_p - box_p).normalized()
			else:
				var cx := cap_p.x
				var cz := cap_p.z
				var out_min_x := cx + radius - box.min.x
				var out_max_x := box.max.x - (cx - radius)
				var out_min_z := cz + radius - box.min.z
				var out_max_z := box.max.z - (cz - radius)
				var out_up := box.max.y - cur_base_y
				pen = out_up
				cn = Vector3(0, 1, 0)
				if out_min_x < pen:
					pen = out_min_x
					cn = Vector3(-1, 0, 0)
				if out_max_x < pen:
					pen = out_max_x
					cn = Vector3(1, 0, 0)
				if out_min_z < pen:
					pen = out_min_z
					cn = Vector3(0, 0, -1)
				if out_max_z < pen:
					pen = out_max_z
					cn = Vector3(0, 0, 1)
			if pen > max_pen:
				max_pen = pen
				best_normal = cn

		var top_y := cur_base_y + height
		if not monster_list.is_empty():
			var sum_radius := radius + MONSTER_CAPSULE_RADIUS
			for other in monster_list:
				if other == self_monster or other.dead:
					continue
				var op: Vector3 = other.position
				var o_base_y := op.y - MONSTER_FOOT_OFFSET
				var pen := _cylinder_contact(pos.x, pos.z, cur_base_y, top_y, op.x, op.z, o_base_y,
					o_base_y + MONSTER_CAPSULE_HEIGHT, sum_radius, self_monster == null)
				if pen > max_pen:
					max_pen = pen
					best_normal = _contact_normal
		if has_player:
			var o_base_y := player_pos.y - EYE_HEIGHT
			var pen := _cylinder_contact(pos.x, pos.z, cur_base_y, top_y, player_pos.x, player_pos.z, o_base_y,
				o_base_y + CAPSULE_HEIGHT, radius + CAPSULE_RADIUS, false)
			if pen > max_pen:
				max_pen = pen
				best_normal = _contact_normal

		if max_pen <= 0.0:
			break
		pos += best_normal * (max_pen + 0.01)
		if best_normal.y > 0.5:
			grounded = true
		if has_vel:
			var dot_vel := vel.dot(best_normal)
			if dot_vel < 0.0:
				vel -= best_normal * dot_vel

	out_pos = pos
	out_vel = vel
	return grounded


# Sphere-vs-environment test used by projectiles.
func hits_environment_at(p: Vector3, radius: float) -> bool:
	var r := Vector3(radius, radius, radius)
	var radius_sq := radius * radius
	for t in gather_nearby_triangles(p - r, p + r):
		if p.distance_squared_to(closest_point_triangle_point(ta[t], tb[t], tc[t], p)) <= radius_sq:
			return true
	for box: Box in gather_nearby_boxes(p - r, p + r):
		if box.distance_to_point(p) <= radius:
			return true
	return false
