# MD2 model loader (port of three.js MD2Loader). All animation frames are packed into a
# vertex-animation texture and blended in the vertex shader, replacing three.js morph targets.
class_name MD2Model
extends RefCounted

const IDENT := 844121161
const VERSION := 8
const MAX_VAT_WIDTH := 4096

var mesh: ArrayMesh = null
var vat_pos: ImageTexture = null
var vat_nrm: ImageTexture = null
var vat_width := 1
var vat_rows := 1
var frame_count := 0
var frame_aabbs: Array[AABB] = []
var full_aabb := AABB()

static var _cache: Dictionary = {}

const NORMALS := [
	-0.525731, 0.000000, 0.850651, -0.442863, 0.238856, 0.864188, -0.295242, 0.000000, 0.955423,
	-0.309017, 0.500000, 0.809017, -0.162460, 0.262866, 0.951056, 0.000000, 0.000000, 1.000000,
	0.000000, 0.850651, 0.525731, -0.147621, 0.716567, 0.681718, 0.147621, 0.716567, 0.681718,
	0.000000, 0.525731, 0.850651, 0.309017, 0.500000, 0.809017, 0.525731, 0.000000, 0.850651,
	0.295242, 0.000000, 0.955423, 0.442863, 0.238856, 0.864188, 0.162460, 0.262866, 0.951056,
	-0.681718, 0.147621, 0.716567, -0.809017, 0.309017, 0.500000, -0.587785, 0.425325, 0.688191,
	-0.850651, 0.525731, 0.000000, -0.864188, 0.442863, 0.238856, -0.716567, 0.681718, 0.147621,
	-0.688191, 0.587785, 0.425325, -0.500000, 0.809017, 0.309017, -0.238856, 0.864188, 0.442863,
	-0.425325, 0.688191, 0.587785, -0.716567, 0.681718, -0.147621, -0.500000, 0.809017, -0.309017,
	-0.525731, 0.850651, 0.000000, 0.000000, 0.850651, -0.525731, -0.238856, 0.864188, -0.442863,
	0.000000, 0.955423, -0.295242, -0.262866, 0.951056, -0.162460, 0.000000, 1.000000, 0.000000,
	0.000000, 0.955423, 0.295242, -0.262866, 0.951056, 0.162460, 0.238856, 0.864188, 0.442863,
	0.262866, 0.951056, 0.162460, 0.500000, 0.809017, 0.309017, 0.238856, 0.864188, -0.442863,
	0.262866, 0.951056, -0.162460, 0.500000, 0.809017, -0.309017, 0.850651, 0.525731, 0.000000,
	0.716567, 0.681718, 0.147621, 0.716567, 0.681718, -0.147621, 0.525731, 0.850651, 0.000000,
	0.425325, 0.688191, 0.587785, 0.864188, 0.442863, 0.238856, 0.688191, 0.587785, 0.425325,
	0.809017, 0.309017, 0.500000, 0.681718, 0.147621, 0.716567, 0.587785, 0.425325, 0.688191,
	0.955423, 0.295242, 0.000000, 1.000000, 0.000000, 0.000000, 0.951056, 0.162460, 0.262866,
	0.850651, -0.525731, 0.000000, 0.955423, -0.295242, 0.000000, 0.864188, -0.442863, 0.238856,
	0.951056, -0.162460, 0.262866, 0.809017, -0.309017, 0.500000, 0.681718, -0.147621, 0.716567,
	0.850651, 0.000000, 0.525731, 0.864188, 0.442863, -0.238856, 0.809017, 0.309017, -0.500000,
	0.951056, 0.162460, -0.262866, 0.525731, 0.000000, -0.850651, 0.681718, 0.147621, -0.716567,
	0.681718, -0.147621, -0.716567, 0.850651, 0.000000, -0.525731, 0.809017, -0.309017, -0.500000,
	0.864188, -0.442863, -0.238856, 0.951056, -0.162460, -0.262866, 0.147621, 0.716567, -0.681718,
	0.309017, 0.500000, -0.809017, 0.425325, 0.688191, -0.587785, 0.442863, 0.238856, -0.864188,
	0.587785, 0.425325, -0.688191, 0.688191, 0.587785, -0.425325, -0.147621, 0.716567, -0.681718,
	-0.309017, 0.500000, -0.809017, 0.000000, 0.525731, -0.850651, -0.525731, 0.000000, -0.850651,
	-0.442863, 0.238856, -0.864188, -0.295242, 0.000000, -0.955423, -0.162460, 0.262866, -0.951056,
	0.000000, 0.000000, -1.000000, 0.295242, 0.000000, -0.955423, 0.162460, 0.262866, -0.951056,
	-0.442863, -0.238856, -0.864188, -0.309017, -0.500000, -0.809017, -0.162460, -0.262866, -0.951056,
	0.000000, -0.850651, -0.525731, -0.147621, -0.716567, -0.681718, 0.147621, -0.716567, -0.681718,
	0.000000, -0.525731, -0.850651, 0.309017, -0.500000, -0.809017, 0.442863, -0.238856, -0.864188,
	0.162460, -0.262866, -0.951056, 0.238856, -0.864188, -0.442863, 0.500000, -0.809017, -0.309017,
	0.425325, -0.688191, -0.587785, 0.716567, -0.681718, -0.147621, 0.688191, -0.587785, -0.425325,
	0.587785, -0.425325, -0.688191, 0.000000, -0.955423, -0.295242, 0.000000, -1.000000, 0.000000,
	0.262866, -0.951056, -0.162460, 0.000000, -0.850651, 0.525731, 0.000000, -0.955423, 0.295242,
	0.238856, -0.864188, 0.442863, 0.262866, -0.951056, 0.162460, 0.500000, -0.809017, 0.309017,
	0.716567, -0.681718, 0.147621, 0.525731, -0.850651, 0.000000, -0.238856, -0.864188, -0.442863,
	-0.500000, -0.809017, -0.309017, -0.262866, -0.951056, -0.162460, -0.850651, -0.525731, 0.000000,
	-0.716567, -0.681718, -0.147621, -0.716567, -0.681718, 0.147621, -0.525731, -0.850651, 0.000000,
	-0.500000, -0.809017, 0.309017, -0.238856, -0.864188, 0.442863, -0.262866, -0.951056, 0.162460,
	-0.864188, -0.442863, 0.238856, -0.809017, -0.309017, 0.500000, -0.688191, -0.587785, 0.425325,
	-0.681718, -0.147621, 0.716567, -0.442863, -0.238856, 0.864188, -0.587785, -0.425325, 0.688191,
	-0.309017, -0.500000, 0.809017, -0.147621, -0.716567, 0.681718, -0.425325, -0.688191, 0.587785,
	-0.162460, -0.262866, 0.951056, 0.442863, -0.238856, 0.864188, 0.162460, -0.262866, 0.951056,
	0.309017, -0.500000, 0.809017, 0.147621, -0.716567, 0.681718, 0.000000, -0.525731, 0.850651,
	0.425325, -0.688191, 0.587785, 0.587785, -0.425325, 0.688191, 0.688191, -0.587785, 0.425325,
	-0.955423, 0.295242, 0.000000, -0.951056, 0.162460, 0.262866, -1.000000, 0.000000, 0.000000,
	-0.850651, 0.000000, 0.525731, -0.955423, -0.295242, 0.000000, -0.951056, -0.162460, 0.262866,
	-0.864188, 0.442863, -0.238856, -0.951056, 0.162460, -0.262866, -0.809017, 0.309017, -0.500000,
	-0.864188, -0.442863, -0.238856, -0.951056, -0.162460, -0.262866, -0.809017, -0.309017, -0.500000,
	-0.681718, 0.147621, -0.716567, -0.681718, -0.147621, -0.716567, -0.850651, 0.000000, -0.525731,
	-0.688191, 0.587785, -0.425325, -0.587785, 0.425325, -0.688191, -0.425325, 0.688191, -0.587785,
	-0.425325, -0.688191, -0.587785, -0.587785, -0.425325, -0.688191, -0.688191, -0.587785, -0.425325,
]


static func clear_cache() -> void:
	_cache.clear()


# Loads (and caches) the model for a modellist entry. Like the browser version, a missing or
# corrupt file falls back to WEAPONsorcerer.MD2.
static func load_for_def(def: Parsers.ModelDef) -> MD2Model:
	if def == null or def.filepath == "":
		return null
	var key := def.filepath.to_lower()
	if _cache.has(key):
		return _cache[key]
	var model: MD2Model = null
	for file_name in [def.filepath.get_file(), "WEAPONsorcerer.MD2"]:
		var abs_path := DataPaths.resolve_asset(file_name)
		if abs_path == "":
			continue
		model = parse(DataPaths.read_bytes_abs(abs_path))
		if model != null:
			break
	if model == null:
		push_warning("Could not load MD2 model at " + def.filepath)
	_cache[key] = model
	return model


static func parse(data: PackedByteArray) -> MD2Model:
	if data.size() < 68:
		return null
	var h := PackedInt32Array()
	for i in 17:
		h.append(data.decode_s32(i * 4))
	var skinwidth := h[2]
	var skinheight := h[3]
	var num_vertices := h[6]
	var num_st := h[7]
	var num_tris := h[8]
	var num_frames := h[10]
	var offset_st := h[12]
	var offset_tris := h[13]
	var offset_frames := h[14]
	if h[0] != IDENT or h[1] != VERSION:
		push_error("Not a valid MD2 file")
		return null
	if h[16] != data.size():
		push_error("Corrupted MD2 file")
		return null

	# texture coordinates (Godot v grows downwards, so t / skinheight directly)
	var st := PackedVector2Array()
	st.resize(num_st)
	for i in num_st:
		var o := offset_st + i * 4
		st[i] = Vector2(float(data.decode_s16(o)) / skinwidth, float(data.decode_s16(o + 2)) / skinheight)

	# triangles: corners emitted as (0, 2, 1) so three.js front faces stay front faces in Godot
	var v_idx := PackedInt32Array()
	var uv_idx := PackedInt32Array()
	var corner_order := [0, 2, 1]
	var referenced := PackedByteArray()
	referenced.resize(num_vertices)
	for i in num_tris:
		var o := offset_tris + i * 12
		for c: int in corner_order:
			var vi := data.decode_u16(o + c * 2)
			v_idx.append(vi)
			uv_idx.append(data.decode_u16(o + 6 + c * 2))
			if vi < num_vertices:
				referenced[vi] = 1

	var m := MD2Model.new()
	m.frame_count = num_frames
	m.vat_width = clampi(num_vertices, 1, MAX_VAT_WIDTH)
	m.vat_rows = int(ceil(float(num_vertices) / m.vat_width))
	var tex_h := m.vat_rows * num_frames
	var pos_data := PackedFloat32Array()
	pos_data.resize(m.vat_width * tex_h * 3)
	var nrm_data := PackedFloat32Array()
	nrm_data.resize(m.vat_width * tex_h * 3)

	var frame0_pos := PackedVector3Array()
	var frame0_nrm := PackedVector3Array()
	frame0_pos.resize(num_vertices)
	frame0_nrm.resize(num_vertices)

	var offset := offset_frames
	for f in num_frames:
		var sx := data.decode_float(offset)
		var sy := data.decode_float(offset + 4)
		var sz := data.decode_float(offset + 8)
		var tx := data.decode_float(offset + 12)
		var ty := data.decode_float(offset + 16)
		var tz := data.decode_float(offset + 20)
		offset += 40
		var mn := Vector3(INF, INF, INF)
		var mx := Vector3(-INF, -INF, -INF)
		var row_base := f * m.vat_rows * m.vat_width
		for j in num_vertices:
			var x := data[offset] * sx + tx
			var y := data[offset + 1] * sy + ty
			var z := data[offset + 2] * sz + tz
			var ni := data[offset + 3] * 3
			offset += 4
			# convert to Y-up exactly like three.js: (x, z, y)
			var p := Vector3(x, z, y)
			var n := Vector3(NORMALS[ni], NORMALS[ni + 2], NORMALS[ni + 1]) if ni + 2 < NORMALS.size() else Vector3.UP
			var t := (row_base + j) * 3
			pos_data[t] = p.x
			pos_data[t + 1] = p.y
			pos_data[t + 2] = p.z
			nrm_data[t] = n.x
			nrm_data[t + 1] = n.y
			nrm_data[t + 2] = n.z
			if referenced[j] == 1:
				mn = mn.min(p)
				mx = mx.max(p)
			if f == 0:
				frame0_pos[j] = p
				frame0_nrm[j] = n
		var box := AABB(mn, mx - mn) if mx.x >= mn.x else AABB()
		m.frame_aabbs.append(box)
		m.full_aabb = box if f == 0 else m.full_aabb.merge(box)

	var pos_img := Image.create_from_data(m.vat_width, tex_h, false, Image.FORMAT_RGBF, pos_data.to_byte_array())
	var nrm_img := Image.create_from_data(m.vat_width, tex_h, false, Image.FORMAT_RGBF, nrm_data.to_byte_array())
	m.vat_pos = ImageTexture.create_from_image(pos_img)
	m.vat_nrm = ImageTexture.create_from_image(nrm_img)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var count := v_idx.size()
	verts.resize(count)
	normals.resize(count)
	uvs.resize(count)
	uv2s.resize(count)
	for i in count:
		var vi := v_idx[i]
		if vi < num_vertices:
			verts[i] = frame0_pos[vi]
			normals[i] = frame0_nrm[vi]
		var ui := uv_idx[i]
		if ui < num_st:
			uvs[i] = st[ui]
		uv2s[i] = Vector2(vi, 0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	m.mesh = ArrayMesh.new()
	if count > 0:
		m.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# Creates a mesh instance using the given shared MD2 material (which carries the VAT textures).
func create_instance(tex_alias: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = get_material(tex_alias)
	mi.custom_aabb = full_aabb
	set_pose(mi, [0], [1.0])
	return mi


var _materials: Dictionary = {}

func get_material(tex_alias: String) -> ShaderMaterial:
	var key := tex_alias.to_lower().strip_edges()
	if _materials.has(key):
		return _materials[key]
	var base := Materials.get_shared_material(tex_alias, true)
	var mat := base.duplicate() as ShaderMaterial
	mat.set_shader_parameter("vat_pos", vat_pos)
	mat.set_shader_parameter("vat_nrm", vat_nrm)
	mat.set_shader_parameter("vat_width", vat_width)
	mat.set_shader_parameter("vat_rows", vat_rows)
	_materials[key] = mat
	return mat


# Applies morph-style weights. Frames outside the model are ignored and the remaining weight goes
# to frame 0, matching three.js morphTargetBaseInfluence.
func set_pose(mi: GeometryInstance3D, frames: Array, weights: Array) -> void:
	var f := Vector4.ZERO
	var w := Vector4.ZERO
	var n := 0
	var total := 0.0
	for k in frames.size():
		var fr: int = frames[k]
		var wt: float = weights[k]
		if fr < 0 or fr >= frame_count or wt <= 0.0 or n >= 4:
			continue
		f[n] = fr
		w[n] = wt
		total += wt
		n += 1
	var base := 1.0 - total
	if base > 1e-4:
		var merged := false
		for k in n:
			if int(f[k]) == 0:
				w[k] += base
				merged = true
				break
		if not merged and n < 4:
			f[n] = 0
			w[n] = base
	mi.set_instance_shader_parameter("frames", f)
	mi.set_instance_shader_parameter("weights", w)


func frame_aabb(frame: int) -> AABB:
	if frame >= 0 and frame < frame_aabbs.size():
		return frame_aabbs[frame]
	return frame_aabbs[0] if not frame_aabbs.is_empty() else AABB()
