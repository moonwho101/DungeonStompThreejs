# Procedural dungeon level generator (port of generator.js).
# Uses the same mulberry32 RNG and FNV seed hash, so a given seed builds the same dungeon as the browser version.
class_name DungeonGenerator
extends RefCounted

const DIR_N := [0, 1]
const DIR_S := [0, -1]
const DIR_W := [-1, 0]
const DIR_E := [1, 0]

const OBJECT_ORDER := ["CORRIDOR01", "CORRIDOR02", "CORRIDOR03", "CROSSING01", "CROSSING02", "CROSSING03", "ROOM02", "ROOM05", "ROOM06"]

const OBJECTS := {
	"CORRIDOR01": [
		{"pos": [-368, 0], "out": DIR_W},
		{"pos": [355, 0], "out": DIR_E},
	],
	"CORRIDOR02": [
		{"pos": [-284, 0], "out": DIR_W, "y": 72 - 74.5},
		{"pos": [295, 0], "out": DIR_E, "y": 414 - 74.5},
	],
	"CORRIDOR03": [
		{"pos": [-180, 0], "out": DIR_W, "y": 0},
		{"pos": [180, 0], "out": DIR_E, "y": 0},
	],
	"CROSSING01": [
		{"pos": [-60, -340], "out": DIR_S, "y": 0},
		{"pos": [365, 80], "out": DIR_E, "y": 0},
	],
	"CROSSING02": [
		{"pos": [0, 384], "out": DIR_N, "y": 0},
		{"pos": [0, -369], "out": DIR_S, "y": 0},
		{"pos": [-406, 0], "out": DIR_W, "y": 0},
		{"pos": [405, 0], "out": DIR_E, "y": 0},
	],
	"CROSSING03": [
		{"pos": [0, -334], "out": DIR_S, "y": 0},
		{"pos": [-412, 20], "out": DIR_W, "y": 0},
		{"pos": [399, 20], "out": DIR_E, "y": 0},
	],
	"ROOM02": [
		{"pos": [0, -173], "out": DIR_S, "y": 0},
	],
	"ROOM05": [
		{"pos": [455, -305 - 145], "out": DIR_E, "y": 0},
	],
	"ROOM06": [
		{"pos": [0, -311], "out": DIR_S, "y": 0},
	],
}

const BOUNDING_BOXES_FULL := {
	"CORRIDOR01": [-372, -297, 358, 303],
	"CORRIDOR02": [-288, -298, 298, 302],
	"CORRIDOR03": [-185, -299, 182, 301],
	"CROSSING01": [-447, -453, 482, 413],
	"CROSSING02": [-486, -458, 491, 475],
	"CROSSING03": [-492, -422, 485, 420],
	"ROOM02": [-255, -173, 249, 165],
	"ROOM06": [-297, -338, 294, 339],
	"ROOM05": [-505, -831, 517, 839],
}

const FLOOR_SLOTS := {
	"CORRIDOR01": [[0.0, -100.0], [0.0, 0.0], [0.0, 100.0]],
	"CORRIDOR02": [[-20.0, -200.0], [-20.0, -100.0], [-20.0, 0.0], [-20.0, 100.0], [-20.0, 200.0]],
	"CORRIDOR03": [[0.0, -100.0], [0.0, 0.0], [0.0, 100.0]],
	"CROSSING01": [[0.0, 0.0], [0.0, -100.0], [100.0, 0.0]],
	"CROSSING02": [[0.0, 0.0], [0.0, -100.0], [100.0, 0.0]],
	"CROSSING03": [[0.0, 0.0], [0.0, -100.0], [100.0, 0.0]],
	"ROOM02": [[0.0, 0.0], [-120.0, -60.0], [120.0, -60.0], [-120.0, 60.0], [120.0, 60.0]],
	"ROOM06": [[0.0, 0.0], [-140.0, -120.0], [140.0, -120.0], [-140.0, 120.0], [140.0, 120.0], [0.0, -200.0], [0.0, 200.0]],
	"ROOM05": [[0.0, 0.0], [-150.0, -200.0], [150.0, -200.0], [-150.0, 200.0], [150.0, 200.0], [0.0, -300.0], [0.0, 300.0]],
}

const MIN_SPIRAL_START_DISTANCE := 500.0
const MAX_GENERATION_ATTEMPTS := 50
const MASK32 := 0xFFFFFFFF


static func rotate(x: float, z: float, angle: int) -> Array:
	match angle:
		0: return [x, z]
		90: return [-z, x]
		180: return [-x, -z]
		270: return [z, -x]
	return [x, z]


static func get_world_bounds_full(name: String, ox: float, oz: float, rot: int) -> Array:
	var b: Array = BOUNDING_BOXES_FULL[name]
	var corners := [[b[0], b[1]], [b[2], b[1]], [b[0], b[3]], [b[2], b[3]]]
	var min_x := INF
	var min_z := INF
	var max_x := -INF
	var max_z := -INF
	for c in corners:
		var r := rotate(c[0], c[1], rot)
		min_x = minf(min_x, r[0] + ox)
		max_x = maxf(max_x, r[0] + ox)
		min_z = minf(min_z, r[1] + oz)
		max_z = maxf(max_z, r[1] + oz)
	return [min_x, min_z, max_x, max_z]


# JavaScript Math.imul on unsigned 32-bit patterns.
static func imul(a: int, b: int) -> int:
	a &= MASK32
	b &= MASK32
	var lo := (a & 0xFFFF) * b
	var hi := (((a >> 16) & 0xFFFF) * b) & 0xFFFF
	return (lo + (hi << 16)) & MASK32


# JavaScript Math.round (halves round towards +infinity).
static func js_round(v: float) -> int:
	return int(floor(v + 0.5))


class Rng:
	var seeded := false
	var s := 0

	func _init(seed_value: Variant) -> void:
		if seed_value == null or str(seed_value) == "":
			seeded = false
			return
		seeded = true
		var text := str(seed_value)
		var hash := 2166136261
		for i in text.length():
			hash = DungeonGenerator.imul(hash ^ text.unicode_at(i), 16777619)
		s = (hash ^ 0xDEADBEEF) & DungeonGenerator.MASK32

	func next() -> float:
		if not seeded:
			return randf()
		s = (s + 0x6D2B79F5) & DungeonGenerator.MASK32
		var t := DungeonGenerator.imul(s ^ (s >> 15), 1 | s)
		t = ((t + DungeonGenerator.imul(t ^ (t >> 7), 61 | t)) & DungeonGenerator.MASK32) ^ t
		return float((t ^ (t >> 14)) & DungeonGenerator.MASK32) / 4294967296.0

	func randint(a: int, b: int) -> int:
		return int(floor(next() * (b - a + 1))) + a

	func choice(arr: Array) -> Variant:
		return arr[int(floor(next() * arr.size()))]

	func uniform(a: float, b: float) -> float:
		return a + next() * (b - a)

	func shuffle(arr: Array) -> Array:
		for i in range(arr.size() - 1, 0, -1):
			var j := int(floor(next() * (i + 1)))
			var tmp = arr[i]
			arr[i] = arr[j]
			arr[j] = tmp
		return arr

	func sample(arr: Array, k: int) -> Array:
		var copy := arr.duplicate()
		shuffle(copy)
		return copy.slice(0, mini(k, copy.size()))


static func _prefer_exit_index(open_exits: Array, placed: Array, prefer_loop_chance: float, rng: Rng) -> int:
	if placed.is_empty():
		return -1
	if rng.next() >= prefer_loop_chance:
		return -1
	var best_idx := -1
	var best_score := -1e9
	for i in open_exits.size():
		var ex: Dictionary = open_exits[i]
		var score := 0.0
		for p in placed:
			var dist := Vector2(ex.wx - p.x, ex.wz - p.z).length()
			score += maxf(0.0, 2000.0 - dist)
		if score > best_score:
			best_score = score
			best_idx = i
	return best_idx


static func _hsv_to_rgb(h: float, s: float, v: float) -> Array:
	var i := int(floor(h * 6.0))
	var f := h * 6.0 - i
	var p := v * (1.0 - s)
	var q := v * (1.0 - f * s)
	var t := v * (1.0 - (1.0 - f) * s)
	match posmod(i, 6):
		0: return [v, t, p]
		1: return [q, v, p]
		2: return [p, v, t]
		3: return [p, q, v]
		4: return [t, p, v]
	return [v, p, q]


static func _round1(v: float) -> float:
	return js_round(v * 10.0) / 10.0


static func _slot_key(x: float, z: float) -> String:
	return "%d,%d" % [js_round(x), js_round(z)]


# Regenerates until the dungeon is "good": at least half the requested tiles
# placed and the exit spiral not within 500 units of the start position.
static func generate(options: Dictionary = {}) -> String:
	var start_x: float = options.get("startX", 5200.0)
	var start_z: float = options.get("startZ", 2600.0)
	var num_objects: int = int(options.get("numObjectsToPlace", 225))
	var rng := Rng.new(options.get("seed", null))
	for attempt in range(1, MAX_GENERATION_ATTEMPTS + 1):
		var is_last := attempt == MAX_GENERATION_ATTEMPTS
		var result := _generate_attempt(start_x, start_z, num_objects, rng, not is_last)
		if result != "":
			return result
		print("Dungeon quality check failed (attempt %d/%d); regenerating..." % [attempt, MAX_GENERATION_ATTEMPTS])
	return ""


static func _generate_attempt(start_x: float, start_z: float, num_objects: int, rng: Rng, strict: bool) -> String:
	var placed: Array = []
	var entities: Array = []
	var failed_exits: Array = []
	var entity_id_idx := 100

	var start_piece := {
		"name": "CORRIDOR01", "x": start_x, "y": 0.0, "z": start_z, "rot": 0,
		"bounds": get_world_bounds_full("CORRIDOR01", start_x, start_z, 0),
		"used_slots": {"0,0": true},
	}
	placed.append(start_piece)

	entities.append({"type": "circle", "x": start_x, "y": -41.0 + 40.0, "z": start_z, "rot": 0, "name": "0", "id": entity_id_idx, "state": 2})
	entity_id_idx += 1

	var open_exits: Array = []
	for ext in OBJECTS["CORRIDOR01"]:
		var rp := rotate(ext.pos[0], ext.pos[1], 0)
		var rd := rotate(ext.out[0], ext.out[1], 0)
		open_exits.append({
			"wx": start_x + rp[0], "wy": 0.0 + float(ext.get("y", 0)), "wz": start_z + rp[1],
			"wdx": int(rd[0]), "wdz": int(rd[1]), "source_name": "CORRIDOR01", "source_piece": start_piece,
		})

	for step in num_objects:
		if open_exits.is_empty():
			break
		var preferred_idx := _prefer_exit_index(open_exits, placed, 0.18, rng)
		var exit_idx := preferred_idx if preferred_idx != -1 else int(floor(rng.next() * open_exits.size()))

		var O: Dictionary = open_exits[exit_idx]
		open_exits.remove_at(exit_idx)
		var wx: float = O.wx
		var wy: float = O.wy
		var wz: float = O.wz
		var wdx: int = O.wdx
		var wdz: int = O.wdz
		var source_name: String = O.get("source_name", placed[0].name)

		var placed_new := false
		var types := OBJECT_ORDER.duplicate()
		rng.shuffle(types)

		for cand_name: String in types:
			if cand_name == "ROOM05" or cand_name == "ROOM06" or cand_name == "ROOM02":
				if rng.next() > 0.20:
					continue
			if cand_name == "ROOM05":
				if not source_name.begins_with("CORRIDOR"):
					continue
			if cand_name.begins_with("CROSSING"):
				if source_name == "ROOM05":
					continue
				if not source_name.begins_with("CORRIDOR"):
					continue
			if placed_new:
				break
			var cand_exits: Array = OBJECTS[cand_name]
			var indices: Array = range(cand_exits.size())
			rng.shuffle(indices)

			for ext_idx: int in indices:
				if placed_new:
					break
				var loc_ext: Dictionary = cand_exits[ext_idx]
				var lx: float = loc_ext.pos[0]
				var lz: float = loc_ext.pos[1]
				var ldx: int = loc_ext.out[0]
				var ldz: int = loc_ext.out[1]
				var rots := [0, 90, 180, 270]
				rng.shuffle(rots)

				for ang: int in rots:
					var rdv := rotate(ldx, ldz, ang)
					if int(rdv[0]) == -wdx and int(rdv[1]) == -wdz:
						var rp := rotate(lx, lz, ang)
						var Ox: float = wx - rp[0]
						var Oy: float = wy - float(loc_ext.get("y", 0))
						var Oz: float = wz - rp[1]

						if not _check_collision(placed, Ox, Oz, cand_name, ang, O):
							var new_piece := {"name": cand_name, "x": Ox, "y": Oy, "z": Oz, "rot": ang,
								"bounds": get_world_bounds_full(cand_name, Ox, Oz, ang)}
							placed.append(new_piece)
							placed_new = true

							if cand_name.begins_with("CROSSING"):
								for c_ext: Dictionary in cand_exits:
									if rng.next() < 0.40:
										var out_dir: Array = c_ext.out
										var base_door_rot := 0
										if out_dir == DIR_S: base_door_rot = 0
										elif out_dir == DIR_E: base_door_rot = 90
										elif out_dir == DIR_N: base_door_rot = 180
										elif out_dir == DIR_W: base_door_rot = 270
										var door_rot := (base_door_rot + ang) % 360
										var r := rotate(c_ext.pos[0], c_ext.pos[1], ang)
										entities.append({"type": "door55", "name": "0", "x": Ox + r[0],
											"y": Oy + float(c_ext.get("y", 0)) + 75.0, "z": Oz + r[1],
											"rot": door_rot, "id": entity_id_idx, "state": -1})
										entity_id_idx += 1

							if cand_name == "ROOM05" or cand_name == "CORRIDOR01" or cand_name == "ROOM06":
								var num_torches := rng.randint(2, 4)
								var all_torch_positions: Array = []
								if cand_name == "CORRIDOR01":
									all_torch_positions = [[-200, -155, 270], [0, -155, 270], [200, -155, 270],
										[-200, 155, 90], [0, 155, 90], [200, 155, 90]]
								elif cand_name == "ROOM05":
									num_torches = rng.randint(4, 8)
									all_torch_positions = [
										[-334 - 25, -431, 180], [-334 - 25, -231, 180], [-334 - 25, -31, 180],
										[-334 - 25, 169, 180], [-334 - 25, 369, 180],
										[415, -631, 0], [415, -231, 0], [415, -31, 0], [415, 169, 0], [415, 369, 0],
										[-174, -791 + 180, 270], [26, -791 + 180, 270], [226, -791 + 180, 270], [426, -791 + 180, 270],
										[-174, 655 + 40, 90], [26, 655 + 40, 90], [226, 655 + 40, 90], [426, 655 + 40, 90]]
								elif cand_name == "ROOM06":
									all_torch_positions = [[-254 + 125, -311 + 200, 180], [-254 + 60, -311 + 390, 270],
										[251 - 125, -311 + 200, 0], [251 - 60, -311 + 390, 270],
										[-254 + 200, 296 - 20, 90], [-254 + 400, 296 - 20, 90]]

								var torch_positions: Array = rng.sample(all_torch_positions, num_torches) if num_torches > 0 else []
								var base_colors := [[1.0, 1.0, 1.0], [1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0],
									[1.0, 1.0, 0.0], [0.0, 1.0, 1.0], [1.0, 0.0, 1.0], [1.0, 0.5, 0.0],
									[0.5, 0.0, 1.0], [1.0, 0.75, 0.8]]
								var base_color: Array = rng.choice(base_colors)
								var torch_r := _round1(base_color[0] * rng.uniform(9.0, 13.0))
								var torch_g := _round1(base_color[1] * rng.uniform(9.0, 13.0))
								var torch_b := _round1(base_color[2] * rng.uniform(9.0, 13.0))

								for tp: Array in torch_positions:
									var rotated_pos := rotate(tp[0], tp[1], ang)
									var world_x: float = Ox + rotated_pos[0]
									var world_z: float = Oz + rotated_pos[1]
									var torch_rot := (int(tp[2]) + ang) % 360
									entities.append({"type": "!monster1", "name": "0", "x": world_x, "y": Oy + 100.0, "z": world_z,
										"rot": torch_rot, "id": entity_id_idx, "state": 2})
									entity_id_idx += 1
									var lamp_y := Oy + 120.0
									entities.append({"type": "lamp_post", "x": world_x, "y": lamp_y, "z": world_z, "rot": 0,
										"id": entity_id_idx, "state": 0, "name": ""})
									entity_id_idx += 1
									entities.append({"type": "LIGHT_SOURCE", "name": "flicker", "x": world_x, "y": lamp_y, "z": world_z,
										"rot": 0, "id": entity_id_idx, "state": 0, "color": [torch_r, torch_g, torch_b], "dir": [0.0, -1.0, 0.0]})
									entity_id_idx += 1

							if cand_name != "CORRIDOR02":
								var light_y := Oy + 170.0
								entities.append({"type": "lamp_post", "x": Ox, "y": light_y, "z": Oz, "rot": 0, "id": entity_id_idx, "state": 0, "name": ""})
								entity_id_idx += 1
								var center_r := _round1(rng.uniform(9.0, 14.0))
								var center_g := _round1(rng.uniform(9.0, 14.0))
								var center_b := _round1(rng.uniform(9.0, 14.0))
								entities.append({"type": "LIGHT_SOURCE", "name": "flicker", "x": Ox, "y": light_y, "z": Oz, "rot": 0,
									"id": entity_id_idx, "state": 0, "color": [center_r, center_g, center_b], "dir": [0.0, -1.0, 0.0]})
								entities.append({"type": "torch1", "name": "0", "x": Ox + 0.0, "y": Oy + 140.0, "z": Oz + 0.0, "rot": 0,
									"id": entity_id_idx, "state": 0})
								entity_id_idx += 1

								if rng.next() < 0.55:
									var s_y: float = Oy + float(rng.choice([200.0, 300.0, 400.0]))
									var hue := rng.next()
									var sat := rng.uniform(0.4, 1.0)
									var val := rng.uniform(0.3, 0.9)
									var color := _hsv_to_rgb(hue, sat, val)
									entities.append({"type": "lamp_post", "x": Ox, "y": s_y, "z": Oz, "rot": 0, "id": entity_id_idx, "state": 0, "name": ""})
									entity_id_idx += 1
									var dx := rng.uniform(-0.4, 0.4)
									var dz := rng.uniform(-0.4, 0.4)
									var dy := -1.0
									var length := sqrt(dx * dx + dy * dy + dz * dz)
									entities.append({"type": "LIGHT_SOURCE", "name": "Spotlight", "x": Ox, "y": s_y, "z": Oz, "rot": 0,
										"id": entity_id_idx, "state": 0, "color": color, "dir": [dx / length, dy / length, dz / length]})
									entity_id_idx += 1

								var depth := maxf(0.0, -Oy)
								var level := mini(3, int(floor(depth / 280.0)))
								var d_rot: int = rng.choice([0, 45, 90, 135, 180, 225, 270, 315])

								var num_items := 0
								if cand_name.begins_with("ROOM05"):
									num_items = rng.randint(4, 6)
								elif cand_name.begins_with("CROSSING"):
									num_items = rng.randint(2, 3)
								else:
									num_items = rng.randint(1, 3)

								var last_placed: Dictionary = placed[placed.size() - 1]
								for _it in num_items:
									var r := rng.next()
									var ent_type := ""
									var local_x := 0.0
									var local_z := 0.0
									if FLOOR_SLOTS.has(cand_name):
										if not last_placed.has("used_slots"):
											last_placed["used_slots"] = {}
										var used: Dictionary = last_placed["used_slots"]
										var available: Array = []
										for slot: Array in FLOOR_SLOTS[cand_name]:
											if not used.has(_slot_key(slot[0], slot[1])):
												available.append(slot)
										if not available.is_empty():
											var picked: Array = rng.choice(available)
											local_x = picked[0]
											local_z = picked[1]
											used[_slot_key(local_x, local_z)] = true

									var sw := rotate(local_x, local_z, ang)
									var wx_item: float = Ox + sw[0]
									var wz_item: float = Oz + sw[1]
									if cand_name == "CORRIDOR02":
										continue

									if r < 0.10:
										ent_type = rng.choice(["POTION", "cheese1", "GOBLET", "pot1", "pot2", "pot3", "mushroom"])
										entities.append({"type": ent_type, "name": "-1", "x": wx_item, "y": Oy + 40.0, "z": wz_item, "rot": d_rot, "id": entity_id_idx, "state": 0})
									elif r < 0.25:
										ent_type = rng.choice(["rock1", "rock2", "skull", "QUARTZ", "cdoorclosedchest", "block01", "block02", "cdoorclosedbarrel"])
										var st := 0
										var item_rot := d_rot
										if ent_type == "cdoorclosedchest" or ent_type == "cdoorclosedbarrel":
											st = rng.choice([0, 1]) if level < 2 else rng.choice([0, 1, 2])
											item_rot = rng.choice([0, 90, 180, 270])
										var adjust := 10.0
										if ent_type == "block01" or ent_type == "block02":
											adjust = -11.0
										entities.append({"type": ent_type, "name": "0", "x": wx_item, "y": Oy + adjust, "z": wz_item, "rot": item_rot, "id": entity_id_idx, "state": st})
									elif r < 0.28:
										ent_type = "armour"
										entities.append({"type": ent_type, "name": "-1", "x": wx_item, "y": Oy + 60.0, "z": wz_item, "rot": d_rot, "id": entity_id_idx, "state": 0})
									elif r < 0.30:
										ent_type = "COIN"
										entities.append({"type": "COIN", "name": "-1", "x": wx_item, "y": Oy + 60.0, "z": wz_item, "rot": d_rot, "id": entity_id_idx, "state": 0})
									elif r < 0.35:
										ent_type = "SPELLBOOK"
										entities.append({"type": "spellbook", "name": "-1", "x": wx_item, "y": Oy + 40.0, "z": wz_item, "rot": d_rot, "id": entity_id_idx, "state": 0})
									elif r < 0.40:
										var scroll_type: String = rng.choice(["SCROLL-HEALING-", "SCROLL-MAGICMISSLE-", "SCROLL-FIREBALL-", "SCROLL-LIGHTNING-"])
										ent_type = scroll_type
										entities.append({"type": scroll_type, "name": "-1", "x": wx_item, "y": Oy + 40.0, "z": wz_item, "rot": d_rot, "id": entity_id_idx, "state": 0})
									elif r < 0.45:
										var weapon_types: Array
										if level == 0: weapon_types = ["BASTARDSWORD", "FLAMESWORD", "BATTLEAXE"]
										elif level == 1: weapon_types = ["ICESWORD", "LIGHTNINGSWORD", "MORNINGSTAR"]
										else: weapon_types = ["SPLITSWORD", "SPIKEDFLAIL", "SUPERFLAMESWORD"]
										ent_type = rng.choice(weapon_types)
										entities.append({"type": ent_type, "name": "-1", "x": wx_item, "y": Oy + 80.0, "z": wz_item, "rot": d_rot, "id": entity_id_idx, "state": 0})
									else:
										var possible_mobs: Array
										if level == 0: possible_mobs = ["GOBLIN", "TENTACLE", "SKELETON2", "INSECT"]
										elif level == 1: possible_mobs = ["OGRE", "CORPSE", "MUMMY", "WOLF", "COBRA", "OGRO", "CENTAUR", "CRAZ", "HYDRA", "OLUVE"]
										elif level == 2: possible_mobs = ["NECROMANCER", "SORCERER", "WRAITH", "PHANTOM", "KNIGHT", "SLAVE", "SORB", "RIDER", "FULIMO"]
										else: possible_mobs = ["FAERIE", "BAUUL", "DEMONESS", "DRAGON", "IMP", "OKTA", "DEMON", "OKTA"]
										ent_type = rng.choice(possible_mobs)
										entities.append({"type": ent_type, "name": ent_type.to_lower(), "x": wx_item,
											"y": Oy + 50.0 + (depth / 140.0) * 2.0, "z": wz_item, "rot": d_rot, "id": entity_id_idx, "state": 0})
									if ent_type != "":
										entity_id_idx += 1

							for i in cand_exits.size():
								if i == ext_idx:
									continue
								var other_ext: Dictionary = cand_exits[i]
								var op := rotate(other_ext.pos[0], other_ext.pos[1], ang)
								var od := rotate(other_ext.out[0], other_ext.out[1], ang)
								open_exits.append({"wx": Ox + op[0], "wy": Oy + float(other_ext.get("y", 0)), "wz": Oz + op[1],
									"wdx": int(od[0]), "wdz": int(od[1]), "source_name": cand_name, "source_piece": new_piece})
						break

		if not placed_new:
			failed_exits.append(O)

	open_exits.append_array(failed_exits)

	var all_piece_exits: Array = []
	for p: Dictionary in placed:
		for ext: Dictionary in OBJECTS[p.name]:
			var rp := rotate(ext.pos[0], ext.pos[1], p.rot)
			var rd := rotate(ext.out[0], ext.out[1], p.rot)
			var ey := js_round(float(p.get("y", 0.0)) + float(ext.get("y", 0)))
			all_piece_exits.append([js_round(p.x + rp[0]), ey, js_round(p.z + rp[1]), int(rd[0]), int(rd[1])])

	var connected_positions := {}
	for a: Array in all_piece_exits:
		for b: Array in all_piece_exits:
			if a[0] == b[0] and a[1] == b[1] and a[2] == b[2] and a[3] == -b[3] and a[4] == -b[4]:
				connected_positions["%d,%d,%d" % [a[0], a[1], a[2]]] = true

	for open_ex: Dictionary in open_exits:
		var key := "%d,%d,%d" % [js_round(open_ex.wx), js_round(open_ex.wy), js_round(open_ex.wz)]
		if connected_positions.has(key):
			continue
		var ex: float = open_ex.wx
		var ey2: float = open_ex.wy
		var ez: float = open_ex.wz
		var ndx: int = -int(open_ex.wdx)
		var ndz: int = -int(open_ex.wdz)
		var wall_rot := 0
		if ndx == 0 and ndz == -1: wall_rot = 270
		elif ndx == 1 and ndz == 0: wall_rot = 0
		elif ndx == 0 and ndz == 1: wall_rot = 90
		elif ndx == -1 and ndz == 0: wall_rot = 180
		ex += ndz * 160
		ez += -ndx * 160
		entities.append({"type": "wall", "name": "corridor10", "x": ex, "y": ey2, "z": ez, "rot": wall_rot, "id": entity_id_idx, "state": 0})
		entity_id_idx += 1

	if not placed.is_empty():
		# CORRIDOR02 (a slope) is never chosen for the exit circle/spiral portal
		var candidate_pieces: Array = placed.filter(func(p): return p.name != "CORRIDOR02")
		var deepest: Dictionary = candidate_pieces[0] if not candidate_pieces.is_empty() else placed[0]
		for i in range(1, candidate_pieces.size()):
			if float(candidate_pieces[i].get("y", 0.0)) < float(deepest.get("y", 0.0)):
				deepest = candidate_pieces[i]
		var tx: float = deepest.x
		var ty: float = float(deepest.get("y", 0.0))
		var tz: float = deepest.z
		var deepest_name: String = deepest.name
		var deepest_rot: int = deepest.rot

		if FLOOR_SLOTS.has(deepest_name):
			var used_local := {}
			for e: Dictionary in entities:
				var l := rotate(e.x - tx, e.z - tz, (360 - deepest_rot) % 360)
				used_local[_slot_key(l[0], l[1])] = true
			var free_slots: Array = []
			for slot: Array in FLOOR_SLOTS[deepest_name]:
				if not (slot[0] == 0.0 and slot[1] == 0.0) and not used_local.has(_slot_key(slot[0], slot[1])):
					free_slots.append(slot)
			if not free_slots.is_empty():
				var target: Array = rng.choice(free_slots)
				var r := rotate(target[0], target[1], deepest_rot)
				var new_wx: float = tx + r[0]
				var new_wz: float = tz + r[1]
				for e: Dictionary in entities:
					if absf(e.x - tx) < 1.0 and absf(e.z - tz) < 1.0 and not (e.type in ["circle", "spiral", "!flarenohit", "lamp_post", "LIGHT_SOURCE"]):
						e.x = new_wx
						e.z = new_wz

		entities.append({"type": "circle", "x": tx, "y": ty - 41.0 + 40.0, "z": tz, "rot": 0, "name": "0", "id": entity_id_idx, "state": 2})
		entity_id_idx += 1
		entities.append({"type": "spiral", "x": tx, "y": ty + 40.0, "z": tz, "rot": 0, "name": "-1", "id": entity_id_idx, "state": 2})
		entity_id_idx += 1

	if strict:
		if placed.size() < num_objects / 2.0:
			print("  Rejected: only %d tiles placed (expected at least %s)." % [placed.size(), str(num_objects / 2.0)])
			return ""
		for e: Dictionary in entities:
			if e.type == "spiral":
				if Vector2(e.x - start_x, e.z - start_z).length() < MIN_SPIRAL_START_DISTANCE:
					print("  Rejected: spiral is within %d units of startpos." % int(MIN_SPIRAL_START_DISTANCE))
					return ""
				break

	var lines := PackedStringArray()
	var links: Array = []
	var obj_id := 0
	lines.append("OBJECT startpos")
	lines.append("CO_ORDINATES %s 0.000000 %s" % [_f6(start_x), _f6(start_z)])
	lines.append("ROT_ANGLE 90")
	links.append([start_x, start_z, 90, obj_id])
	obj_id += 1

	for p: Dictionary in placed:
		lines.append("OBJECT %s" % p.name)
		lines.append("CO_ORDINATES %s %s %s" % [_f6(p.x), _f6(float(p.get("y", 0.0))), _f6(p.z)])
		lines.append("ROT_ANGLE %d" % p.rot)
		links.append([p.x, p.z, p.rot, obj_id])
		obj_id += 1

	for e: Dictionary in entities:
		var t: String = e.type
		var coords := "CO_ORDINATES %s %s %s" % [_f6(e.x), _f6(e.y), _f6(e.z)]
		if t == "wall":
			lines.append("OBJECT !wall0-240-320")
			lines.append(coords)
			lines.append("ROT_ANGLE %s 0 %s %s 0" % [str(e.rot), str(e.name), str(e.id)])
		elif t == "lamp_post":
			lines.append("OBJECT lamp_post")
			lines.append(coords)
			lines.append("ROT_ANGLE %s" % str(e.rot))
		elif t == "LIGHT_SOURCE":
			var d: Array = e.get("dir", [0.0, -1.0, 0.0])
			var c: Array = e.get("color", [1.0, 1.0, 1.0])
			lines.append("LIGHT_SOURCE %s POS %s %s %s DIR %s %s %s COLOUR %s %s %s" % [e.name, _f6(e.x), _f6(e.y), _f6(e.z),
				_f6(d[0]), _f6(d[1]), _f6(d[2]), _f6(c[0]), _f6(c[1]), _f6(c[2])])
			continue
		elif t.begins_with("door"):
			lines.append("OBJECT %s" % t)
			lines.append(coords)
			lines.append("ROT_ANGLE %s %s" % [str(e.rot), str(e.state)])
		elif t == "!monster1":
			lines.append("OBJECT !monster1")
			lines.append(coords)
			lines.append("ROT_ANGLE %s torch2 %s %s 0" % [str(e.rot), str(e.get("name", "0")), str(e.get("id", 0))])
		else:
			lines.append("OBJECT !monster1")
			lines.append(coords)
			lines.append("ROT_ANGLE %s %s %s %s %s" % [str(e.rot), t, str(e.get("name", "")), str(e.get("id", 0)), str(e.get("state", 0))])
		links.append([e.x, e.z, e.rot, obj_id])
		obj_id += 1

	lines.append("OBJECT text")
	lines.append("CO_ORDINATES 2020.000000 0.000000 1020.000000")
	lines.append("ROT_ANGLE 0 largedungeon")
	links.append([2020.0, 1020.0, 0, obj_id])
	obj_id += 1

	for link: Array in links:
		lines.append("LINK %s %s %d %d" % [_f6(link[0]), _f6(link[1]), int(floor(float(link[2]))), link[3]])
	lines.append("END_FILE")
	return "\n".join(lines) + "\n"


static func _f6(v: float) -> String:
	var s := "%.6f" % v
	if s == "-0.000000":
		return "0.000000"
	return s


static func _check_collision(placed: Array, nx: float, nz: float, n_name: String, n_rot: int, attach_ex: Dictionary) -> bool:
	var nb := get_world_bounds_full(n_name, nx, nz, n_rot)
	var source_piece = attach_ex.source_piece
	for p: Dictionary in placed:
		if is_same(p, source_piece):
			continue
		var pb: Array = p.bounds
		if nb[0] < pb[2] and nb[2] > pb[0] and nb[1] < pb[3] and nb[3] > pb[1]:
			return true
	return false
