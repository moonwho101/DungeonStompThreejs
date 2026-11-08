# 3DS model loader (port of three.js TDSLoader plus the game's FallbackTDSLoader rules:
# textures resolve to .jpg/.png in Assets/, missing ones render black, textured materials ignore
# their diffuse colour). The result is a template Node3D that is duplicated per placement.
class_name TDSModel
extends RefCounted

const M3DMAGIC := 0x4D4D
const MLIBMAGIC := 0x3DAA
const CMAGIC := 0xC23D
const MDATA := 0x3D3D
const MASTER_SCALE := 0x0100
const NAMED_OBJECT := 0x4000
const N_TRI_OBJECT := 0x4100
const POINT_ARRAY := 0x4110
const FACE_ARRAY := 0x4120
const MSH_MAT_GROUP := 0x4130
const TEX_VERTS := 0x4140
const MAT_ENTRY := 0xAFFF
const MAT_NAME := 0xA000
const MAT_AMBIENT := 0xA010
const MAT_DIFFUSE := 0xA020
const MAT_SPECULAR := 0xA030
const MAT_SHININESS := 0xA040
const MAT_TRANSPARENCY := 0xA050
const MAT_ADDITIVE := 0xA083
const MAT_TEXMAP := 0xA200
const MAT_MAPNAME := 0xA300
const MAT_MAP_USCALE := 0xA354
const MAT_MAP_VSCALE := 0xA356
const MAT_MAP_UOFFSET := 0xA358
const MAT_MAP_VOFFSET := 0xA35A
const COLOR_F := 0x0010
const COLOR_24 := 0x0011
const LIN_COLOR_24 := 0x0012
const LIN_COLOR_F := 0x0013
const INT_PERCENTAGE := 0x0030
const FLOAT_PERCENTAGE := 0x0031

var template: Node3D = null
var local_aabb := AABB() # in template space (after the 3DS -> Y-up rotation)
var has_geometry := false
var mesh_names: PackedStringArray = PackedStringArray()

static var _cache: Dictionary = {}


class Chunk:
	var data: PackedByteArray
	var offset := 0
	var position := 0
	var id := 0
	var size := 0
	var end := 0
	var valid := true

	func _init(d: PackedByteArray, pos: int) -> void:
		data = d
		offset = pos
		position = pos
		if pos + 6 > d.size():
			valid = false
			return
		id = read_word()
		size = read_dword()
		end = offset + size

	func end_of_chunk() -> bool:
		return position >= end

	func read_chunk() -> Chunk:
		if end_of_chunk():
			return null
		var next := Chunk.new(data, position)
		if not next.valid:
			return null
		position += next.size
		return next

	func read_byte() -> int:
		if position >= data.size():
			position += 1
			return 0
		var v := data[position]
		position += 1
		return v

	func read_word() -> int:
		if position + 2 > data.size():
			position += 2
			return 0
		var v := data.decode_u16(position)
		position += 2
		return v

	func read_short() -> int:
		if position + 2 > data.size():
			position += 2
			return 0
		var v := data.decode_s16(position)
		position += 2
		return v

	func read_dword() -> int:
		if position + 4 > data.size():
			position += 4
			return 0
		var v := data.decode_u32(position)
		position += 4
		return v

	func read_float() -> float:
		if position + 4 > data.size():
			return 0.0
		var v := data.decode_float(position)
		position += 4
		return v

	func read_string() -> String:
		var bytes := PackedByteArray()
		var c := read_byte()
		while c != 0 and position <= data.size():
			bytes.append(c)
			c = read_byte()
		return bytes.get_string_from_ascii()


class MatInfo:
	var name := ""
	var color := Color(1, 1, 1)
	var has_map := false
	var map_name := ""
	var repeat := Vector2(1, 1)
	var map_offset := Vector2(0, 0)
	var opacity := 1.0
	var additive := false
	var specular := Color(0x11 / 255.0, 0x11 / 255.0, 0x11 / 255.0).srgb_to_linear()
	var shininess := 30.0
	var material: ShaderMaterial = null

	func get_material() -> ShaderMaterial:
		if material == null:
			material = Materials.make_3ds_material(color, map_name, has_map, opacity, additive, specular, shininess)
		return material


class MeshData:
	var name := ""
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var groups: Array = [] # [start_index, count, material_index]
	var materials: Array = [] # Array[MatInfo] in the order three.js pushes them
	var has_groups := false


var _materials: Dictionary = {}
var _meshes: Array = []
var _master_scale := 1.0


static func load_for_def(def: Parsers.ModelDef) -> TDSModel:
	if def == null or def.filepath == "":
		return null
	var key := def.filepath.to_lower()
	if _cache.has(key):
		return _cache[key]
	var model: TDSModel = null
	var abs_path := DataPaths.resolve_asset(def.filepath.get_file())
	if abs_path != "":
		model = TDSModel.new()
		if not model._parse(DataPaths.read_bytes_abs(abs_path)):
			model = null
	if model == null:
		push_warning("Could not load 3DS model at " + def.filepath)
	_cache[key] = model
	return model


static func clear_cache() -> void:
	for k in _cache:
		var m: TDSModel = _cache[k]
		if m != null and m.template != null:
			m.template.free()
	_cache.clear()


func instantiate() -> Node3D:
	return template.duplicate() as Node3D


func _parse(data: PackedByteArray) -> bool:
	if data.size() < 6:
		return false
	var chunk := Chunk.new(data, 0)
	if chunk.id == MLIBMAGIC or chunk.id == CMAGIC or chunk.id == M3DMAGIC:
		var next := chunk.read_chunk()
		while next:
			if next.id == MDATA:
				_read_mesh_data(next)
			next = chunk.read_chunk()
	_build()
	return true


func _read_mesh_data(chunk: Chunk) -> void:
	var next := chunk.read_chunk()
	while next:
		if next.id == MASTER_SCALE:
			_master_scale = next.read_float()
		elif next.id == NAMED_OBJECT:
			_read_named_object(next)
		elif next.id == MAT_ENTRY:
			_read_material_entry(next)
		next = chunk.read_chunk()


func _read_named_object(chunk: Chunk) -> void:
	var name := chunk.read_string()
	var next := chunk.read_chunk()
	while next:
		if next.id == N_TRI_OBJECT:
			var md := _read_mesh(next)
			md.name = name
			_meshes.append(md)
		next = chunk.read_chunk()


func _read_color(chunk: Chunk) -> Color:
	var sub := chunk.read_chunk()
	var c := Color(1, 1, 1)
	if sub == null:
		return c
	if sub.id == COLOR_24 or sub.id == LIN_COLOR_24:
		var r := sub.read_byte()
		var g := sub.read_byte()
		var b := sub.read_byte()
		c = Color(r / 255.0, g / 255.0, b / 255.0)
	elif sub.id == COLOR_F or sub.id == LIN_COLOR_F:
		c = Color(sub.read_float(), sub.read_float(), sub.read_float())
	return c


func _read_percentage(chunk: Chunk) -> float:
	var sub := chunk.read_chunk()
	if sub == null:
		return 0.0
	if sub.id == INT_PERCENTAGE:
		return sub.read_short() / 100.0
	if sub.id == FLOAT_PERCENTAGE:
		return sub.read_float()
	return 0.0


func _read_material_entry(chunk: Chunk) -> void:
	var mat := MatInfo.new()
	var next := chunk.read_chunk()
	while next:
		match next.id:
			MAT_NAME:
				mat.name = next.read_string()
			MAT_ADDITIVE:
				mat.additive = true
			MAT_DIFFUSE, MAT_AMBIENT:
				mat.color = _read_color(next)
			MAT_SPECULAR:
				mat.specular = _read_color(next)
			MAT_SHININESS:
				mat.shininess = _read_percentage(next) * 100.0
			MAT_TRANSPARENCY:
				mat.opacity = 1.0 - _read_percentage(next)
			MAT_TEXMAP:
				_read_map(next, mat)
		next = chunk.read_chunk()
	_materials[mat.name] = mat


func _read_map(chunk: Chunk, mat: MatInfo) -> void:
	mat.has_map = true
	var next := chunk.read_chunk()
	while next:
		match next.id:
			MAT_MAPNAME:
				mat.map_name = next.read_string()
				mat.repeat = Vector2(1, 1)
				mat.map_offset = Vector2(0, 0)
			MAT_MAP_UOFFSET:
				mat.map_offset.x = next.read_float()
			MAT_MAP_VOFFSET:
				mat.map_offset.y = next.read_float()
			MAT_MAP_USCALE:
				mat.repeat.x = next.read_float()
			MAT_MAP_VSCALE:
				mat.repeat.y = next.read_float()
		next = chunk.read_chunk()


func _read_mesh(chunk: Chunk) -> MeshData:
	var md := MeshData.new()
	var next := chunk.read_chunk()
	while next:
		if next.id == POINT_ARRAY:
			var n := next.read_word()
			var pts := PackedVector3Array()
			pts.resize(n)
			for i in n:
				pts[i] = Vector3(next.read_float(), next.read_float(), next.read_float())
			md.points = pts
		elif next.id == FACE_ARRAY:
			_read_face_array(next, md)
		elif next.id == TEX_VERTS:
			var n := next.read_word()
			var uvs := PackedVector2Array()
			uvs.resize(n)
			for i in n:
				uvs[i] = Vector2(next.read_float(), next.read_float())
			md.uvs = uvs
		next = chunk.read_chunk()
	return md


func _read_face_array(chunk: Chunk, md: MeshData) -> void:
	var faces := chunk.read_word()
	var idx := PackedInt32Array()
	idx.resize(faces * 3)
	for i in faces:
		idx[i * 3] = chunk.read_word()
		idx[i * 3 + 1] = chunk.read_word()
		idx[i * 3 + 2] = chunk.read_word()
		chunk.read_word() # visibility flags
	md.indices = idx
	var material_index := 0
	var start := 0
	while not chunk.end_of_chunk():
		var sub := chunk.read_chunk()
		if sub == null:
			break
		if sub.id == MSH_MAT_GROUP:
			var gname := sub.read_string()
			var num := sub.read_word()
			# three.js assumes each group's faces are consecutive and in file order
			var count := num * 3
			md.groups.append([start, count, material_index])
			start += count
			material_index += 1
			md.has_groups = true
			if _materials.has(gname):
				md.materials.append(_materials[gname])


# 3DS (Z-up) to Y-up, as the game applies rotation (-PI/2, 0, PI/2) to every 3DS model.
func _to_y_up(v: Vector3) -> Vector3:
	return Vector3(-v.y, v.z, -v.x)


func _build() -> void:
	template = Node3D.new()
	template.name = "Model3DS"
	var first := true
	for md: MeshData in _meshes:
		var n_points := md.points.size()
		if n_points == 0 or md.indices.is_empty():
			continue
		mesh_names.append(md.name)
		# smooth vertex normals from indexed faces (computeVertexNormals)
		var vn := PackedVector3Array()
		vn.resize(n_points)
		for f in range(0, md.indices.size() - 2, 3):
			var ia := md.indices[f]
			var ib := md.indices[f + 1]
			var ic := md.indices[f + 2]
			if ia >= n_points or ib >= n_points or ic >= n_points:
				continue
			var a := md.points[ia]
			var b := md.points[ib]
			var c := md.points[ic]
			var fn := (c - b).cross(a - b)
			vn[ia] += fn
			vn[ib] += fn
			vn[ic] += fn
		var pos := PackedVector3Array()
		var nrm := PackedVector3Array()
		pos.resize(n_points)
		nrm.resize(n_points)
		for i in n_points:
			var p := _to_y_up(md.points[i] * _master_scale)
			pos[i] = p
			nrm[i] = _to_y_up(vn[i].normalized())
			if first:
				local_aabb = AABB(p, Vector3.ZERO)
				first = false
			else:
				local_aabb = local_aabb.expand(p)

		# Surfaces: [index_start, index_count, MatInfo or null for the default white material]
		var surfaces: Array = []
		if not md.has_groups:
			surfaces.append([0, md.indices.size(), null])
		elif md.materials.size() == 1:
			surfaces.append([0, md.indices.size(), md.materials[0]])
		else:
			for g: Array in md.groups:
				var mi: int = g[2]
				if mi < md.materials.size():
					surfaces.append([g[0], g[1], md.materials[mi]])

		var mesh := ArrayMesh.new()
		for s: Array in surfaces:
			var start: int = s[0]
			var count: int = mini(s[1], md.indices.size() - start)
			if count < 3:
				continue
			var mat: MatInfo = s[2]
			var uvs := PackedVector2Array()
			uvs.resize(n_points)
			for i in n_points:
				var uv := md.uvs[i] if i < md.uvs.size() else Vector2.ZERO
				if mat != null and mat.has_map:
					uv = uv * mat.repeat + mat.map_offset
				uvs[i] = Vector2(uv.x, 1.0 - uv.y)
			var idx := PackedInt32Array()
			for f in range(start, start + count - 2, 3):
				var ia := md.indices[f]
				var ib := md.indices[f + 1]
				var ic := md.indices[f + 2]
				if ia >= n_points or ib >= n_points or ic >= n_points:
					continue
				# reversed so three.js front faces stay front faces in Godot
				idx.append(ia)
				idx.append(ic)
				idx.append(ib)
			if idx.is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = pos
			arrays[Mesh.ARRAY_NORMAL] = nrm
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_INDEX] = idx
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var surf_mat: ShaderMaterial
			if mat == null:
				surf_mat = Materials.make_3ds_material(Color(1, 1, 1), "", false, 1.0, false)
			else:
				surf_mat = mat.get_material()
			mesh.surface_set_material(mesh.get_surface_count() - 1, surf_mat)
		if mesh.get_surface_count() == 0:
			continue
		var mi_node := MeshInstance3D.new()
		mi_node.name = md.name if md.name != "" else "mesh"
		mi_node.mesh = mesh
		template.add_child(mi_node)
		has_geometry = true


# World-space AABB of an instance placed with the given transform (like Box3.setFromObject).
func world_box(xf: Transform3D) -> CollisionWorld.Box:
	var box := CollisionWorld.Box.new()
	if not has_geometry:
		return box
	for i in 8:
		box.expand(xf * local_aabb.get_endpoint(i))
	return box
