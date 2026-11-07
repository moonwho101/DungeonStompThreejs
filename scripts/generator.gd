# Procedural Dungeon Generator for Dungeon Stomp Godot 4.7.2
class_name DungeonGenerator
extends RefCounted

const TILE_SIZE = 160.0 # Standard Dungeon Stomp grid unit
const ROOM_TILES = [
	"ROOM01", "ROOM02", "ROOM03", "ROOM04", "ROOM05", "ROOM06",
	"CORRIDOR01", "CORRIDOR02", "CORRIDOR03",
	"CROSSING01", "CROSSING02", "CROSSING03"
]

class DungeonRoom:
	var x: int = 0
	var z: int = 0
	var w: int = 0
	var h: int = 0
	var center_x: int = 0
	var center_z: int = 0

static func generate_dungeon(grid_w: int = 24, grid_h: int = 24, num_rooms: int = 8, rng_seed: int = 1337) -> String:
	var rng = RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	# Grid: 0 = empty, 1 = floor, 2 = wall, 3 = door, 4 = exit
	var grid: Array = []
	for z in range(grid_h):
		var row: Array = []
		for x in range(grid_w):
			row.append(0)
		grid.append(row)

	var rooms: Array[DungeonRoom] = []

	# Generate rooms
	for _attempt in range(num_rooms * 4):
		if rooms.size() >= num_rooms:
			break
		var rw = rng.randi_range(3, 5)
		var rh = rng.randi_range(3, 5)
		var rx = rng.randi_range(1, grid_w - rw - 1)
		var rz = rng.randi_range(1, grid_h - rh - 1)

		var overlaps = false
		for existing in rooms:
			if rx <= existing.x + existing.w and rx + rw >= existing.x and \
			   rz <= existing.z + existing.h and rz + rh >= existing.z:
				overlaps = true
				break

		if not overlaps:
			var room = DungeonRoom.new()
			room.x = rx
			room.z = rz
			room.w = rw
			room.h = rh
			room.center_x = rx + int(rw / 2)
			room.center_z = rz + int(rh / 2)
			rooms.append(room)

			for z in range(rz, rz + rh):
				for x in range(rx, rx + rw):
					grid[z][x] = 1

	# Connect rooms with corridors
	for i in range(1, rooms.size()):
		var prev = rooms[i - 1]
		var curr = rooms[i]

		var cx = prev.center_x
		var cz = prev.center_z
		var tx = curr.center_x
		var tz = curr.center_z

		# Horizontal corridor
		var step_x = 1 if tx >= cx else -1
		for x in range(cx, tx + step_x, step_x):
			grid[cz][x] = 1

		# Vertical corridor
		var step_z = 1 if tz >= cz else -1
		for z in range(cz, tz + step_z, step_z):
			grid[z][tx] = 1

	# Build map text representation compatible with Dungeon Stomp level loader
	var out: PackedStringArray = []

	# Player start position in first room
	var start_x = 5200.0
	var start_z = 2600.0
	if not rooms.is_empty():
		start_x = float(rooms[0].center_x) * TILE_SIZE
		start_z = float(rooms[0].center_z) * TILE_SIZE

	out.append("OBJECT startpos")
	out.append("CO_ORDINATES %f 0.000000 %f" % [start_x, start_z])
	out.append("ROT_ANGLE 90")

	# Place tiles based on grid
	for z in range(grid_h):
		for x in range(grid_w):
			var cell = grid[z][x]
			if cell == 1:
				var world_x = float(x) * TILE_SIZE
				var world_z = float(z) * TILE_SIZE
				out.append("OBJECT CORRIDOR01")
				out.append("CO_ORDINATES %f 0.000000 %f" % [world_x, world_z])
				out.append("ROT_ANGLE 0")

				# Occasional wall torches / lights
				if (x + z) % 7 == 0:
					out.append("OBJECT LIGHT_TORCH")
					out.append("CO_ORDINATES %f 120.000000 %f" % [world_x, world_z])
					out.append("ROT_ANGLE 0")
					out.append("LIGHT_SOURCE flicker POS %f 120.0 %f COLOUR 1.0 0.85 0.5" % [world_x, world_z])

	# Place monsters in secondary rooms
	for i in range(1, rooms.size()):
		var room = rooms[i]
		var mx = float(room.center_x) * TILE_SIZE
		var mz = float(room.center_z) * TILE_SIZE
		var monster_id = (i % 6) + 1
		out.append("OBJECT MONSTER")
		out.append("CO_ORDINATES %f 0.000000 %f" % [mx, mz])
		out.append("ROT_ANGLE %d monster_%d none %d 1" % [rng.randi_range(0, 3) * 90, monster_id, monster_id])

	# Exit portal in final room
	if rooms.size() > 1:
		var exit_room = rooms[rooms.size() - 1]
		var ex = float(exit_room.center_x) * TILE_SIZE
		var ez = float(exit_room.center_z) * TILE_SIZE
		out.append("OBJECT EXIT_PORTAL")
		out.append("CO_ORDINATES %f 0.000000 %f" % [ex, ez])
		out.append("ROT_ANGLE 0")
		out.append("LIGHT_SOURCE flicker POS %f 100.0 %f COLOUR 0.2 0.8 1.0" % [ex, ez])

	return "\n".join(out)
