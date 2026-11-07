# Core parsers for textures.dat, ObjectsAll.dat / Objects.dat, and level maps (.map)
class_name Parsers
extends RefCounted

class TextureManager:
	var aliases: Dictionary = {} # alias_name -> filename in Assets/

	func load_textures_dat(path: String) -> void:
		aliases.clear()
		if not FileAccess.file_exists(path):
			push_warning("Textures dat not found: " + path)
			return
		var file = FileAccess.open(path, FileAccess.READ)
		var current_tex_path: String = ""
		while not file.eof_reached():
			var line = file.get_line().strip_edges()
			if line == "" or line.begins_with("//"):
				continue
			var parts = line.split(" ", false)
			if parts.is_empty():
				continue
			if parts[0] == "AddTexture" and parts.size() > 1:
				var p = parts[1].replace("\\", "/")
				current_tex_path = p.get_file()
			elif parts[0] == "Alias" and parts.size() > 2:
				var alias_name = parts[2].to_lower()
				aliases[alias_name] = current_tex_path

	func get_texture_filename(alias: String) -> String:
		if alias == "":
			return ""
		var clean = alias.to_lower().strip_edges()
		if aliases.has(clean):
			return aliases[clean]
		return clean + ".bmp"

class PolygonData:
	var texture: String = ""
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()

class ObjectDefinition:
	var id: int = -1
	var name: String = ""
	var polys: Array[PolygonData] = []

class ObjectsDatParser:
	var objects: Dictionary = {} # id (int) -> ObjectDefinition
	var objects_by_name: Dictionary = {} # name.to_lower() -> ObjectDefinition

	const TRI_UVS = [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0)]
	const QUAD_UVS = [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
	const QUAD_ORDER = [0, 1, 3, 2, 3, 1]

	func parse(path: String) -> Dictionary:
		objects.clear()
		objects_by_name.clear()
		if not FileAccess.file_exists(path):
			push_error("Objects dat file does not exist: " + path)
			return objects

		var file = FileAccess.open(path, FileAccess.READ)
		var text = file.get_as_text()
		var tokens = text.split(" ", false)
		# Flatten any whitespace splitting
		var clean_tokens: PackedStringArray = []
		for line in text.split("\n"):
			line = line.strip_edges()
			if line.begins_with("//") or line == "":
				continue
			var line_toks = line.split(" ", false)
			for t in line_toks:
				var sub_toks = t.split("\t", false)
				for st in sub_toks:
					st = st.strip_edges()
					if st != "":
						clean_tokens.append(st)

		var count = clean_tokens.size()
		var i: int = 0
		var current_obj: ObjectDefinition = null
		var current_texture: String = "wall1"

		while i < count:
			var tok = clean_tokens[i]

			if tok == "OBJECT" or tok == "Q2M_OBJECT":
				i += 1
				var obj_id = int(clean_tokens[i])
				i += 1
				var obj_name = clean_tokens[i]
				i += 1
				current_obj = ObjectDefinition.new()
				current_obj.id = obj_id
				current_obj.name = obj_name
				objects[obj_id] = current_obj
				objects_by_name[obj_name.to_lower()] = current_obj
				continue

			if current_obj == null:
				i += 1
				continue

			match tok:
				"TEXTURE":
					i += 1
					if i < count:
						current_texture = clean_tokens[i]
					i += 1
				"TYPE", "SCALE", "SHADOW", "CONNECTION":
					i += 2
				"TRI":
					i += 1
					var poly = PolygonData.new()
					poly.texture = current_texture
					for c in range(3):
						var vx = float(clean_tokens[i]); i += 1
						var vy = float(clean_tokens[i]); i += 1
						var vz = float(clean_tokens[i]); i += 1
						poly.vertices.append(Vector3(vx, vy, vz))
						poly.uvs.append(TRI_UVS[c])
					current_obj.polys.append(poly)
				"QUAD":
					i += 1
					var corners: Array[Vector3] = []
					for c in range(4):
						var vx = float(clean_tokens[i]); i += 1
						var vy = float(clean_tokens[i]); i += 1
						var vz = float(clean_tokens[i]); i += 1
						corners.append(Vector3(vx, vy, vz))
					var poly = PolygonData.new()
					poly.texture = current_texture
					for idx in QUAD_ORDER:
						poly.vertices.append(corners[idx])
						poly.uvs.append(QUAD_UVS[idx])
					current_obj.polys.append(poly)
				"TRITEX":
					i += 1
					var poly = PolygonData.new()
					poly.texture = current_texture
					for c in range(3):
						var vx = float(clean_tokens[i]); i += 1
						var vy = float(clean_tokens[i]); i += 1
						var vz = float(clean_tokens[i]); i += 1
						var u = float(clean_tokens[i]); i += 1
						var v = 1.0 - float(clean_tokens[i]); i += 1
						poly.vertices.append(Vector3(vx, vy, vz))
						poly.uvs.append(Vector2(u, v))
					current_obj.polys.append(poly)
				"QUADTEX":
					i += 1
					var corners: Array[Vector3] = []
					var uvs: Array[Vector2] = []
					for c in range(4):
						var vx = float(clean_tokens[i]); i += 1
						var vy = float(clean_tokens[i]); i += 1
						var vz = float(clean_tokens[i]); i += 1
						var u = float(clean_tokens[i]); i += 1
						var v = 1.0 - float(clean_tokens[i]); i += 1
						corners.append(Vector3(vx, vy, vz))
						uvs.append(Vector2(u, v))
					var poly = PolygonData.new()
					poly.texture = current_texture
					for idx in QUAD_ORDER:
						poly.vertices.append(corners[idx])
						poly.uvs.append(uvs[idx])
					current_obj.polys.append(poly)
				_:
					i += 1

		return objects

class MapInstance:
	var name: String = ""
	var position: Vector3 = Vector3.ZERO
	var rotation_deg: float = 0.0
	var model_name: String = ""
	var texture_alias: String = ""
	var monster_id: int = 0
	var ability: int = 0
	var is_start_pos: bool = false
	var is_light: bool = false
	var light_type: String = "flicker"
	var light_color: Color = Color.WHITE

class LevelMapParser:
	var instances: Array[MapInstance] = []
	var start_pos: Vector3 = Vector3(0, 100, 0)
	var start_rot: float = 0.0

	func parse_file(path: String) -> bool:
		if not FileAccess.file_exists(path):
			push_error("Map file not found: " + path)
			return false
		var file = FileAccess.open(path, FileAccess.READ)
		return parse_text(file.get_as_text())

	func parse_text(text: String) -> bool:
		instances.clear()
		start_pos = Vector3(0, 100, 0)
		start_rot = 0.0

		var lines = text.split("\n")
		var current_obj: MapInstance = null

		for raw_line in lines:
			var line = raw_line.strip_edges()
			if line == "" or line.begins_with("//"):
				continue
			var tokens = line.split(" ", false)
			if tokens.is_empty():
				continue
			var cmd = tokens[0]

			if cmd == "OBJECT":
				current_obj = MapInstance.new()
				if tokens.size() > 1:
					current_obj.name = tokens[1]
				instances.append(current_obj)
				if current_obj.name.to_lower() == "startpos":
					current_obj.is_start_pos = true
				elif current_obj.name.to_lower().contains("light"):
					current_obj.is_light = true
			elif current_obj != null and cmd == "CO_ORDINATES":
				var x = float(tokens[1]) if tokens.size() > 1 else 0.0
				var y = (float(tokens[2]) if tokens.size() > 2 else 0.0) + 28.0
				var z = float(tokens[3]) if tokens.size() > 3 else 0.0
				current_obj.position = Vector3(x, y, z)
				if current_obj.is_start_pos:
					start_pos = Vector3(x, y + 100.0, z)
			elif current_obj != null and cmd == "ROT_ANGLE":
				current_obj.rotation_deg = float(tokens[1]) if tokens.size() > 1 else 0.0
				if current_obj.is_start_pos:
					start_rot = current_obj.rotation_deg
				if tokens.size() >= 3:
					current_obj.model_name = tokens[2]
				if tokens.size() >= 4:
					current_obj.texture_alias = tokens[3]
				if tokens.size() >= 5:
					current_obj.monster_id = int(tokens[4])
				if tokens.size() >= 6:
					current_obj.ability = int(tokens[5])
			elif current_obj != null and cmd == "LIGHT_SOURCE":
				current_obj.is_light = true
				if tokens.size() > 1 and tokens[1].to_lower() == "spotlight":
					current_obj.light_type = "spotlight"
				else:
					current_obj.light_type = "flicker"
				var col_idx = -1
				for ti in range(tokens.size()):
					if tokens[ti] == "COLOUR":
						col_idx = ti
						break
				if col_idx >= 0 and col_idx + 3 < tokens.size():
					current_obj.light_color = Color(float(tokens[col_idx+1]), float(tokens[col_idx+2]), float(tokens[col_idx+3]))
				else:
					current_obj.light_color = Color(1.0, 0.85, 0.6)

		return true
