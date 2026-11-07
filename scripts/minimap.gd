# Minimap display rendering player position, level geometry, and monsters
class_name Minimap
extends Control

var player_pos: Vector3 = Vector3.ZERO
var player_yaw: float = 0.0
var monster_positions: Array[Vector3] = []
var wall_points: Array[Vector2] = []

@export var map_radius: float = 80.0
@export var scale_factor: float = 0.08

func update_minimap(pos: Vector3, yaw: float, monsters: Array, walls: Array[Vector2]) -> void:
	player_pos = pos
	player_yaw = yaw
	monster_positions.clear()
	for m in monsters:
		if is_instance_valid(m) and m.get("state") != 5: # 5 is State.DEATH
			if m.has_method("get_pos"):
				monster_positions.append(m.get_pos())
			elif "position" in m:
				monster_positions.append(m.position)
	wall_points = walls
	queue_redraw()

func _draw() -> void:
	var center = size * 0.5

	# Draw circular background
	draw_circle(center, map_radius, Color(0.05, 0.08, 0.1, 0.75))
	draw_arc(center, map_radius, 0, TAU, 32, Color(0.2, 0.6, 0.8, 0.9), 2.0)

	# Draw nearby walls
	for pt in wall_points:
		var dx = (pt.x - player_pos.x) * scale_factor
		var dz = (pt.y - player_pos.z) * scale_factor
		var local_pt = Vector2(dx, dz)
		if local_pt.length() <= map_radius - 2.0:
			draw_circle(center + local_pt, 1.5, Color(0.4, 0.7, 0.9, 0.6))

	# Draw monsters as red dots
	for m_pos in monster_positions:
		var dx = (m_pos.x - player_pos.x) * scale_factor
		var dz = (m_pos.z - player_pos.z) * scale_factor
		var local_pt = Vector2(dx, dz)
		if local_pt.length() <= map_radius - 2.0:
			draw_circle(center + local_pt, 3.0, Color.RED)

	# Draw player as green arrow/dot at center
	draw_circle(center, 4.0, Color.GREEN)
	var dir = Vector2(sin(-player_yaw), cos(-player_yaw)) * 8.0
	draw_line(center, center + dir, Color.GREEN, 2.0)
