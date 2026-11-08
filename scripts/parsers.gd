# Parsers for textures.dat, Objects.dat, modellist.dat and level .map files (port of parsers.js).
class_name Parsers
extends RefCounted


class TextureManager:
	var aliases: Dictionary = {} # alias_name (lower) -> file name within Assets/

	func load_textures_dat(rel_path: String) -> void:
		aliases.clear()
		var text := DataPaths.read_text(rel_path)
		if text == "":
			push_warning("textures.dat not found: " + rel_path)
			return
		var current_tex_path := ""
		for raw_line in text.split("\n"):
			var line := raw_line.strip_edges()
			if line == "" or line.begins_with("//"):
				continue
			var parts := Parsers._split_ws(line)
			if parts.is_empty():
				continue
			if parts[0] == "AddTexture":
				current_tex_path = parts[1] if parts.size() > 1 else ""
				current_tex_path = current_tex_path.replace("\\", "/").get_file()
			elif parts[0] == "Alias":
				if parts.size() > 2 and parts[2] != "":
					aliases[parts[2].to_lower()] = current_tex_path

	func has_alias(alias: String) -> bool:
		return aliases.has(alias)

	func get_texture_path(alias: String) -> String:
		if alias == "":
			return ""
		var clean := alias.to_lower().strip_edges()
		if aliases.has(clean):
			return aliases[clean]
		return clean + ".bmp"


# Splits on any run of whitespace, like JS `split(/\s+/)` on a trimmed line.
static func _split_ws(line: String) -> PackedStringArray:
	return line.replace("\t", " ").replace("\r", " ").split(" ", false)


# One polygon of an Objects.dat object; `verts` holds x, y, z, u, v per triangle-list vertex.
# UVs are already in Godot orientation (v grows downwards in the image).
class ObjectPoly:
	var texture: String = ""
	var verts: PackedFloat32Array = PackedFloat32Array()


class ObjectDef:
	var id: int = -1
	var name: String = ""
	var polys: Array = [] # Array[ObjectPoly]


class ObjectsDatParser:
	var objects: Dictionary = {} # id -> ObjectDef (insertion order preserved)

	# Preset UVs in three.js orientation; converted to Godot (u, 1 - v) when stored.
	const TRI_UVS := [0.0, 0.0, 0.0, 1.0, 1.0, 0.0]
	const QUAD_UVS := [0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0]
	# A quad is emitted as two triangles: corners (0,1,3) and (2,3,1)
	const QUAD_ORDER := [0, 1, 3, 2, 3, 1]
	const TRI_ORDER := [0, 1, 2]

	func parse(rel_path: String) -> Dictionary:
		objects.clear()
		var text := DataPaths.read_text(rel_path)
		if text == "":
			push_error("Objects.dat not found: " + rel_path)
			return objects
		var tokens := text.replace("\r", " ").replace("\n", " ").replace("\t", " ").split(" ", false)
		var count := tokens.size()
		var i := 0
		var current: ObjectDef = null
		var current_texture := "wall1"
		var corners := PackedFloat32Array()
		corners.resize(20)

		while i < count:
			var tok := tokens[i]
			if tok == "OBJECT" or tok == "Q2M_OBJECT":
				i += 1
				current = ObjectDef.new()
				current.id = tokens[i].to_int() if i < count else -1
				i += 1
				current.name = tokens[i] if i < count else ""
				i += 1
				objects[current.id] = current
				continue
			if current == null:
				i += 1
				continue
			match tok:
				"TEXTURE":
					i += 1
					current_texture = tokens[i] if i < count else current_texture
					i += 1
				"TYPE", "SCALE", "SHADOW", "CONNECTION":
					i += 2
				"TRI", "TRITEX", "QUAD", "QUADTEX":
					i += 1
					var n := 3 if (tok == "TRI" or tok == "TRITEX") else 4
					var textured := tok.ends_with("TEX")
					var preset: Array = TRI_UVS if n == 3 else QUAD_UVS
					for v in n:
						var o := v * 5
						corners[o] = _num(tokens, i); i += 1
						corners[o + 1] = _num(tokens, i); i += 1
						corners[o + 2] = _num(tokens, i); i += 1
						if textured:
							corners[o + 3] = _num(tokens, i); i += 1
							# three.js stores 1 - v and flips the image; Godot samples the file v directly
							corners[o + 4] = _num(tokens, i); i += 1
						else:
							corners[o + 3] = preset[v * 2]
							corners[o + 4] = 1.0 - preset[v * 2 + 1]
					var order: Array = TRI_ORDER if n == 3 else QUAD_ORDER
					var poly := ObjectPoly.new()
					poly.texture = current_texture
					var verts := PackedFloat32Array()
					verts.resize(order.size() * 5)
					for k in order.size():
						var src: int = order[k] * 5
						for c in 5:
							verts[k * 5 + c] = corners[src + c]
					poly.verts = verts
					current.polys.append(poly)
				_:
					i += 1
		return objects

	static func _num(tokens: PackedStringArray, i: int) -> float:
		if i >= tokens.size():
			return NAN
		return tokens[i].to_float()


class ModelDef:
	var id: int = -1
	var name: String = ""
	var format: String = ""
	var filepath: String = ""
	var raw_filepath: String = ""
	var scale: float = 1.0
	var texture_alias: String = ""
	var monster_weapon: String = "NONE"
	var type: String = ""

	func is_3ds() -> bool:
		return format == "3DS" or filepath.to_lower().ends_with(".3ds")

	func is_md2() -> bool:
		return format == "MD2" or filepath.to_lower().ends_with(".md2")


class ModelListParser:
	var models_by_name: Dictionary = {}
	var models_by_id: Dictionary = {}

	func parse(rel_path: String) -> void:
		models_by_name.clear()
		models_by_id.clear()
		var text := DataPaths.read_text(rel_path)
		if text == "":
			push_error("Failed to load model list: " + rel_path)
			return
		for raw_line in text.split("\n"):
			var line := raw_line.strip_edges()
			if line == "" or line.begins_with("FILENAME") or line.begins_with("END_FILE") or line.begins_with("//"):
				continue
			var tokens := Parsers._split_ws(line)
			if tokens.size() < 5:
				continue
			var type_cmd := tokens[0].to_upper()
			if type_cmd != "PLAYER" and type_cmd != "YOURGUN":
				continue
			var upper := PackedStringArray()
			for t in tokens:
				upper.append(t.to_upper())

			var format := ""
			for j in range(1, mini(5, tokens.size())):
				if upper[j] == "3DS" or upper[j] == "MD2":
					format = upper[j]
					break

			var model_id := -1
			var file_path := ""
			var model_id_idx := upper.find("MODEL_ID")
			if model_id_idx != -1 and model_id_idx + 2 < tokens.size():
				model_id = tokens[model_id_idx + 1].to_int()
				file_path = tokens[model_id_idx + 2]

			var scale := 1.0
			var scale_idx := upper.find("SCALE")
			if scale_idx != -1 and scale_idx + 1 < tokens.size():
				scale = tokens[scale_idx + 1].to_float()
				if scale == 0.0:
					scale = 1.0

			var texture_alias := ""
			var tex_idx := upper.find("TEX")
			if tex_idx != -1 and tex_idx + 1 < tokens.size():
				texture_alias = tokens[tex_idx + 1]

			var name := ""
			var monster_weapon := "NONE"
			if type_cmd == "PLAYER":
				var thaco_idx := upper.find("THACO")
				if thaco_idx != -1 and thaco_idx + 2 < tokens.size():
					name = tokens[thaco_idx + 2]
				if thaco_idx != -1 and thaco_idx + 4 < tokens.size():
					monster_weapon = tokens[thaco_idx + 4]
			else:
				var d_idx := tokens.rfind("D")
				if d_idx != -1 and d_idx + 2 < tokens.size():
					name = tokens[d_idx + 2]

			if name == "" and model_id != -1:
				name = "model_%d" % model_id

			var clean_path := file_path.replace("\\", "/")
			if clean_path.begins_with("../"):
				clean_path = clean_path.substr(3)

			var def := ModelDef.new()
			def.id = model_id
			def.name = name
			def.format = format
			def.filepath = clean_path
			def.raw_filepath = file_path
			def.scale = scale
			def.texture_alias = texture_alias
			def.monster_weapon = monster_weapon
			def.type = type_cmd
			if name != "":
				models_by_name[name.to_lower()] = def
			if model_id != -1:
				models_by_id[model_id] = def

	func get_model_by_name(name: String) -> ModelDef:
		if name == "":
			return null
		return models_by_name.get(name.to_lower().strip_edges(), null)


class LightSource:
	var type: String = "flicker"
	var pos: Vector3 = Vector3.ZERO
	var dir: Vector3 = Vector3(0, -1, 0)
	var color: Vector3 = Vector3.ONE # raw COLOUR values (may exceed 1)


class MapInstance:
	var name: String = ""
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var rot: float = 0.0
	var shadow: int = 1
	var model_name: String = ""
	var texture_alias: String = ""
	var monster_id: int = 0
	var ability: int = 0
	var is_start_pos: bool = false
	var is_light: bool = false
	var light: LightSource = null


class LevelMapParser:
	var instances: Array = [] # Array[MapInstance]
	var start_pos: Vector3 = Vector3(0, 100, 0)
	var start_rot: float = 0.0
	var lights: Array = []

	func parse_file(rel_path: String) -> bool:
		var text := DataPaths.read_text(rel_path)
		if text == "":
			push_error("Level map not found: " + rel_path)
			return false
		parse_text(text)
		return true

	func parse_text(text: String) -> void:
		instances = []
		lights = []
		var current: MapInstance = null
		for raw_line in text.split("\n"):
			var line := raw_line.strip_edges()
			if line == "" or line.begins_with("//"):
				continue
			var tokens := Parsers._split_ws(line)
			var cmd := tokens[0]
			if cmd == "OBJECT":
				var name := tokens[1] if tokens.size() > 1 else ""
				current = MapInstance.new()
				current.name = name
				instances.append(current)
				var lname := name.to_lower()
				if lname == "startpos":
					current.is_start_pos = true
				elif lname.contains("light"):
					current.is_light = true
			elif current != null and cmd == "CO_ORDINATES":
				current.x = _f(tokens, 1)
				current.y = _f(tokens, 2) + 28.0
				current.z = _f(tokens, 3)
				if current.is_start_pos:
					start_pos = Vector3(current.x, current.y + 100.0, current.z)
			elif current != null and cmd == "ROT_ANGLE":
				current.rot = _f(tokens, 1)
				if current.is_start_pos:
					start_rot = current.rot
				if tokens.size() >= 3:
					current.model_name = tokens[2]
				if tokens.size() >= 4:
					current.texture_alias = tokens[3]
				if tokens.size() >= 5:
					current.monster_id = tokens[4].to_int()
				if tokens.size() >= 6:
					current.ability = tokens[5].to_int()
			elif current != null and cmd == "LIGHT_SOURCE":
				var pos_idx := tokens.find("POS")
				var dir_idx := tokens.find("DIR")
				var col_idx := tokens.find("COLOUR")
				var l := LightSource.new()
				l.type = "spotlight" if (tokens[1] if tokens.size() > 1 else "flicker").to_lower() == "spotlight" else "flicker"
				if pos_idx >= 0:
					l.pos = Vector3(_f(tokens, pos_idx + 1), _f(tokens, pos_idx + 2) + 28.0, _f(tokens, pos_idx + 3))
				else:
					l.pos = Vector3(current.x, current.y, current.z)
				if dir_idx >= 0:
					l.dir = Vector3(_f(tokens, dir_idx + 1), _f(tokens, dir_idx + 2), _f(tokens, dir_idx + 3))
				if col_idx >= 0:
					l.color = Vector3(_f(tokens, col_idx + 1), _f(tokens, col_idx + 2), _f(tokens, col_idx + 3))
				current.light = l
				lights.append(l)
			elif current != null and cmd == "SHADOW":
				current.shadow = tokens[1].to_int() if tokens.size() > 1 else 0

	static func _f(tokens: PackedStringArray, i: int) -> float:
		if i < 0 or i >= tokens.size():
			return 0.0
		var v := tokens[i].to_float()
		return 0.0 if is_nan(v) else v
