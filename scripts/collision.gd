# Capsule collision and spatial grid calculations for Dungeon Stomp Godot 4.7.2
class_name CollisionSystem
extends RefCounted

const CAPSULE_RADIUS = 28.0
const CAPSULE_HEIGHT = 105.0
const EYE_HEIGHT = 100.0
const GRAVITY = 1600.0
const JUMP_SPEED = 520.0
const MONSTER_CAPSULE_RADIUS = 24.0
const MONSTER_CAPSULE_HEIGHT = 80.0
const MONSTER_FOOT_OFFSET = 50.0
const GRID_CELL_SIZE = 256.0

class CollisionTriangle:
	var a: Vector3
	var b: Vector3
	var c: Vector3
	var normal: Vector3
	var planar: bool
	var min_pos: Vector3
	var max_pos: Vector3

	func _init(pa: Vector3, pb: Vector3, pc: Vector3):
		a = pa
		b = pb
		c = pc
		var edge1 = pb - pa
		var edge2 = pc - pa
		normal = edge1.cross(edge2)
		planar = normal.length_squared() > 1e-10
		normal = normal.normalized()
		min_pos = Vector3(
			min(pa.x, min(pb.x, pc.x)),
			min(pa.y, min(pb.y, pc.y)),
			min(pa.z, min(pb.z, pc.z))
		)
		max_pos = Vector3(
			max(pa.x, max(pb.x, pc.x)),
			max(pa.y, max(pb.y, pc.y)),
			max(pa.z, max(pb.z, pc.z))
		)

var triangles: Array[CollisionTriangle] = []
var spatial_grid: Dictionary = {}

func add_triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	var tri = CollisionTriangle.new(a, b, c)
	triangles.append(tri)

func build_grid() -> void:
	spatial_grid.clear()
	for tri in triangles:
		var min_cx = int(floor(tri.min_pos.x / GRID_CELL_SIZE))
		var max_cx = int(floor(tri.max_pos.x / GRID_CELL_SIZE))
		var min_cy = int(floor(tri.min_pos.y / GRID_CELL_SIZE))
		var max_cy = int(floor(tri.max_pos.y / GRID_CELL_SIZE))
		var min_cz = int(floor(tri.min_pos.z / GRID_CELL_SIZE))
		var max_cz = int(floor(tri.max_pos.z / GRID_CELL_SIZE))

		for cx in range(min_cx, max_cx + 1):
			for cy in range(min_cy, max_cy + 1):
				for cz in range(min_cz, max_cz + 1):
					var key = Vector3i(cx, cy, cz)
					if not spatial_grid.has(key):
						spatial_grid[key] = []
					spatial_grid[key].append(tri)

func get_nearby_triangles(box_min: Vector3, box_max: Vector3) -> Array[CollisionTriangle]:
	var result: Array[CollisionTriangle] = []
	var seen: Dictionary = {}

	var min_cx = int(floor(box_min.x / GRID_CELL_SIZE))
	var max_cx = int(floor(box_max.x / GRID_CELL_SIZE))
	var min_cy = int(floor(box_min.y / GRID_CELL_SIZE))
	var max_cy = int(floor(box_max.y / GRID_CELL_SIZE))
	var min_cz = int(floor(box_min.z / GRID_CELL_SIZE))
	var max_cz = int(floor(box_max.z / GRID_CELL_SIZE))

	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			for cz in range(min_cz, max_cz + 1):
				var key = Vector3i(cx, cy, cz)
				if spatial_grid.has(key):
					for tri in spatial_grid[key]:
						var tri_id = tri.get_instance_id()
						if not seen.has(tri_id):
							seen[tri_id] = true
							if not (tri.max_pos.x < box_min.x or tri.min_pos.x > box_max.x or \
									tri.max_pos.y < box_min.y or tri.min_pos.y > box_max.y or \
									tri.max_pos.z < box_min.z or tri.min_pos.z > box_max.z):
								result.append(tri)
	return result

static func closest_point_triangle_point(v0: Vector3, v1: Vector3, v2: Vector3, p: Vector3) -> Vector3:
	var v10 = v1 - v0
	var v20 = v2 - v0
	var vp0 = p - v0

	var d1 = v10.dot(vp0)
	var d2 = v20.dot(vp0)
	if d1 <= 0.0 and d2 <= 0.0:
		return v0

	var vp1 = p - v1
	var d3 = v10.dot(vp1)
	var d4 = v20.dot(vp1)
	if d3 >= 0.0 and d4 <= d3:
		return v1

	var vc = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var v = d1 / (d1 - d3)
		return v0 + v10 * v

	var vp2 = p - v2
	var d5 = v10.dot(vp2)
	var d6 = v20.dot(vp2)
	if d6 >= 0.0 and d5 <= d6:
		return v2

	var vb = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var w = d2 / (d2 - d6)
		return v0 + v20 * w

	var va = d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return v1 + (v2 - v1) * w

	var denom = 1.0 / (va + vb + vc)
	var v = vb * denom
	var w = vc * denom
	return v0 + v10 * v + v20 * w

static func closest_point_segment_point(a: Vector3, b: Vector3, p: Vector3) -> Vector3:
	var ab = b - a
	var ab_len_sq = ab.length_squared()
	if ab_len_sq < 1e-8:
		return a
	var t = clamp((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return a + ab * t

# Resolves player or entity capsule against static level triangles
func resolve_capsule(pos: Vector3, radius: float, height: float, vel: Vector3, foot_offset: float) -> Dictionary:
	var grounded = false
	var cur_pos = pos

	for _iter in range(4):
		var base_y = cur_pos.y - foot_offset
		var cap_a = Vector3(cur_pos.x, base_y + radius, cur_pos.z)
		var cap_b = Vector3(cur_pos.x, base_y + height - radius, cur_pos.z)

		var box_min = Vector3(cur_pos.x - radius - 30, base_y - 30, cur_pos.z - radius - 30)
		var box_max = Vector3(cur_pos.x + radius + 30, base_y + height + 30, cur_pos.z + radius + 30)
		var nearby = get_nearby_triangles(box_min, box_max)

		var max_pen = 0.0
		var best_normal = Vector3.ZERO

		for tri in nearby:
			# Check planar pierce
			if tri.planar:
				var plane_n = tri.normal
				var da = plane_n.dot(cap_a - tri.a)
				var db = plane_n.dot(cap_b - tri.a)
				if da * db < 0.0:
					var t = da / (da - db)
					var pierce = cap_a.lerp(cap_b, t)
					var near_p = closest_point_triangle_point(tri.a, tri.b, tri.c, pierce)
					if near_p.distance_squared_to(pierce) < 1.0:
						var pen = radius + min(abs(da), abs(db))
						if pen > max_pen:
							max_pen = pen
							best_normal = plane_n if da > 0.0 else -plane_n
						continue

			var tri_pt = closest_point_triangle_point(tri.a, tri.b, tri.c, cap_a)
			var cap_pt = closest_point_segment_point(cap_a, cap_b, tri_pt)
			var diff = cap_pt - tri_pt
			var dist = diff.length()
			if dist < radius:
				var pen = radius - dist
				if pen > max_pen:
					max_pen = pen
					best_normal = diff.normalized() if dist > 1e-6 else tri.normal

		if max_pen <= 0.0:
			break

		cur_pos += best_normal * (max_pen + 0.01)
		if best_normal.y > 0.5:
			grounded = true
		if vel != Vector3.ZERO and vel.dot(best_normal) < 0:
			vel -= best_normal * vel.dot(best_normal)

	return { "position": cur_pos, "velocity": vel, "grounded": grounded }

func has_line_of_sight(from_pos: Vector3, to_pos: Vector3) -> bool:
	var dist = from_pos.distance_to(to_pos)
	if dist <= 1.0:
		return true

	var step_size = 40.0
	var steps = max(1, int(floor(dist / step_size)))

	var b_min = Vector3(min(from_pos.x, to_pos.x) - 20, min(from_pos.y, to_pos.y) - 20, min(from_pos.z, to_pos.z) - 20)
	var b_max = Vector3(max(from_pos.x, to_pos.x) + 20, max(from_pos.y, to_pos.y) + 20, max(from_pos.z, to_pos.z) + 20)
	var tris = get_nearby_triangles(b_min, b_max)

	for i in range(1, steps):
		var sample = from_pos.lerp(to_pos, float(i) / float(steps))
		for tri in tris:
			var pt = closest_point_triangle_point(tri.a, tri.b, tri.c, sample)
			if sample.distance_squared_to(pt) <= 15.0 * 15.0:
				return false

	return true
