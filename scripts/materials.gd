# Texture loading and the shared Lambert materials (port of the material code in render.js).
# Textures are sampled raw (no sRGB decode) because three.js loads them with NoColorSpace.
class_name Materials
extends RefCounted

const LAMBERT_COMMON := """
uniform sampler2D albedo_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_color = vec4(1.0);
uniform float opacity = 1.0;
uniform bool has_texture = false;
uniform bool has_normal = false;
global uniform bool ds_normal_maps;
"""

const LAMBERT_FRAGMENT := """
void fragment() {
	vec4 c = albedo_color;
	if (has_texture) {
		c *= texture(albedo_tex, UV);
	}
	ALBEDO = c.rgb;
	#ALPHA#
	if (has_normal && ds_normal_maps) {
		// Tangent frame from screen-space derivatives, as three.js does for meshes without tangents.
		vec3 N = normalize(NORMAL);
		vec3 q0 = dFdx(VERTEX);
		vec3 q1 = dFdy(VERTEX);
		vec2 st0 = dFdx(UV);
		vec2 st1 = dFdy(UV);
		vec3 q1perp = cross(q1, N);
		vec3 q0perp = cross(N, q0);
		vec3 T = q1perp * st0.x + q0perp * st1.x;
		vec3 B = q1perp * st0.y + q0perp * st1.y;
		float det = max(dot(T, T), dot(B, B));
		float sc = det == 0.0 ? 0.0 : inversesqrt(det);
		float orient = dot(cross(q0, q1), N) < 0.0 ? -1.0 : 1.0;
		float face = FRONT_FACING ? 1.0 : -1.0;
		T *= sc * orient * face;
		B *= sc * orient * face;
		vec3 m = texture(normal_tex, UV).xyz * 2.0 - 1.0;
		NORMAL = normalize(T * m.x + B * m.y + N * m.z);
	}
}
"""

const MD2_VERTEX := """
uniform sampler2D vat_pos : filter_nearest, repeat_disable;
uniform sampler2D vat_nrm : filter_nearest, repeat_disable;
uniform int vat_width = 1;
uniform int vat_rows = 1;
instance uniform vec4 frames = vec4(0.0);
instance uniform vec4 weights = vec4(1.0, 0.0, 0.0, 0.0);

void vertex() {
	int id = int(UV2.x + 0.5);
	ivec2 base = ivec2(id % vat_width, id / vat_width);
	vec3 p = vec3(0.0);
	vec3 n = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		float w = weights[k];
		if (w > 0.0) {
			ivec2 c = base + ivec2(0, int(frames[k] + 0.5) * vat_rows);
			p += texelFetch(vat_pos, c, 0).xyz * w;
			n += texelFetch(vat_nrm, c, 0).xyz * w;
		}
	}
	VERTEX = p;
	NORMAL = n;
}
"""

const PHONG_LIGHT := """
uniform vec4 specular_color = vec4(0.0056, 0.0056, 0.0056, 1.0);
uniform float shininess = 30.0;
// three.js MeshPhongMaterial: Lambert diffuse + BRDF_BlinnPhong specular.
// LIGHT_COLOR already carries the PI factor, so it equals the three.js light intensity.
void light() {
	float NdotL = max(dot(NORMAL, LIGHT), 0.0);
	vec3 irr = ATTENUATION * LIGHT_COLOR * NdotL;
	DIFFUSE_LIGHT += irr / PI;
	vec3 H = normalize(LIGHT + VIEW);
	float dotNH = max(dot(NORMAL, H), 0.0);
	float dotVH = max(dot(VIEW, H), 0.0);
	float fresnel = exp2((-5.55473 * dotVH - 6.98316) * dotVH);
	vec3 F = specular_color.rgb * (1.0 - fresnel) + vec3(fresnel);
	float D = (1.0 / PI) * (shininess * 0.5 + 1.0) * pow(dotNH, shininess);
	SPECULAR_LIGHT += irr * F * (0.25 * D);
}
"""

static var texture_manager: Parsers.TextureManager = null
static var _shaders: Dictionary = {}
static var _texture_cache: Dictionary = {} # alias -> Texture2D (fallback if missing)
static var _file_texture_cache: Dictionary = {} # abs path -> Texture2D
static var _normal_cache: Dictionary = {} # nm alias -> Texture2D or null
static var _shared: Dictionary = {} # key -> ShaderMaterial
static var _fallback: Texture2D = null
static var _black: Texture2D = null


static func get_shader(kind: String) -> Shader:
	if _shaders.has(kind):
		return _shaders[kind]
	var mode := "render_mode cull_disabled, diffuse_lambert, specular_disabled"
	var alpha := ""
	if kind.contains("alpha"):
		mode += ", depth_draw_opaque"
		alpha = "ALPHA = c.a * opacity;"
	if kind.contains("add"):
		mode += ", blend_add, depth_draw_never"
		alpha = "ALPHA = c.a * opacity;"
	var code := "shader_type spatial;\n" + mode + ";\n" + LAMBERT_COMMON
	if kind.begins_with("md2"):
		code += MD2_VERTEX
	code += LAMBERT_FRAGMENT.replace("#ALPHA#", alpha)
	if kind.begins_with("phong"):
		code += PHONG_LIGHT
	var sh := Shader.new()
	sh.code = code
	_shaders[kind] = sh
	return sh


static func fallback_texture() -> Texture2D:
	if _fallback == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
		img.fill(Color8(0x66, 0x66, 0x77))
		img.fill_rect(Rect2i(0, 0, 64, 64), Color8(0x44, 0x44, 0x55))
		img.fill_rect(Rect2i(64, 64, 64, 64), Color8(0x44, 0x44, 0x55))
		img.generate_mipmaps()
		_fallback = ImageTexture.create_from_image(img)
	return _fallback


static func black_texture() -> Texture2D:
	if _black == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
		img.fill(Color(0, 0, 0))
		_black = ImageTexture.create_from_image(img)
	return _black


static func load_texture_file(abs_path: String) -> Texture2D:
	if _file_texture_cache.has(abs_path):
		return _file_texture_cache[abs_path]
	var img := DataPaths.load_image(abs_path)
	var tex: Texture2D = null
	if img != null:
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	_file_texture_cache[abs_path] = tex
	return tex


static func load_first(paths: PackedStringArray) -> Texture2D:
	for p in paths:
		var t := load_texture_file(p)
		if t != null:
			return t
	return null


# Texture for an alias from textures.dat (falls back to the alias itself as a file stem).
static func get_texture(alias: String) -> Texture2D:
	if alias == "":
		return null
	if _texture_cache.has(alias):
		return _texture_cache[alias]
	var paths := PackedStringArray()
	var tex_path := texture_manager.get_texture_path(alias) if texture_manager else ""
	if tex_path != "":
		paths.append_array(DataPaths.texture_candidates(tex_path))
	for p in DataPaths.texture_candidates(alias):
		if not paths.has(p):
			paths.append(p)
	var tex := load_first(paths)
	if tex == null:
		tex = fallback_texture()
	_texture_cache[alias] = tex
	return tex


static func get_normal_map(alias: String) -> Texture2D:
	if alias == "" or texture_manager == null:
		return null
	var nm_alias := alias.to_lower().strip_edges() + "_nm"
	if not texture_manager.has_alias(nm_alias):
		return null
	if _normal_cache.has(nm_alias):
		return _normal_cache[nm_alias]
	var tex := load_first(DataPaths.texture_candidates(texture_manager.get_texture_path(nm_alias)))
	_normal_cache[nm_alias] = tex
	return tex


static func _configure(mat: ShaderMaterial, albedo: Texture2D, normal: Texture2D) -> void:
	mat.set_shader_parameter("has_texture", albedo != null)
	if albedo != null:
		mat.set_shader_parameter("albedo_tex", albedo)
	mat.set_shader_parameter("has_normal", normal != null)
	if normal != null:
		mat.set_shader_parameter("normal_tex", normal)


# Shared Lambert material for a texture alias (static geometry and MD2 models).
static func get_shared_material(tex_alias: String, md2: bool = false) -> ShaderMaterial:
	var key := ("md2|" if md2 else "") + tex_alias.to_lower().strip_edges()
	if _shared.has(key):
		return _shared[key]
	var mat := ShaderMaterial.new()
	mat.shader = get_shader("md2" if md2 else "world")
	if tex_alias != "":
		_configure(mat, get_texture(tex_alias), get_normal_map(tex_alias))
	else:
		_configure(mat, null, null)
	_shared[key] = mat
	return mat


# Phong material for a 3DS material entry. `tex_name` is the map file name stored in the .3ds file.
static func make_3ds_material(color: Color, tex_name: String, has_map: bool, opacity: float, additive: bool,
		specular: Color = Color(0x11 / 255.0, 0x11 / 255.0, 0x11 / 255.0).srgb_to_linear(), shininess: float = 30.0) -> ShaderMaterial:
	var kind := "phong"
	if additive:
		kind = "phong_add"
	elif opacity < 1.0:
		kind = "phong_alpha"
	var mat := ShaderMaterial.new()
	mat.shader = get_shader(kind)
	mat.set_shader_parameter("opacity", opacity)
	mat.set_shader_parameter("specular_color", Color(specular.r, specular.g, specular.b, 1.0))
	mat.set_shader_parameter("shininess", maxf(shininess, 0.0001))
	if has_map:
		mat.set_shader_parameter("albedo_color", Color(1, 1, 1, 1))
		var tex := load_first(DataPaths.texture_candidates(tex_name)) if tex_name != "" else null
		if tex == null:
			if tex_name != "":
				push_warning("3DS texture not found: %s (.jpg/.png in Assets/)" % tex_name)
			tex = black_texture()
		var stem := tex_name.replace("\\", "/").get_file()
		if stem.rfind(".") != -1:
			stem = stem.substr(0, stem.rfind("."))
		_configure(mat, tex, get_normal_map(stem))
	else:
		mat.set_shader_parameter("albedo_color", Color(color.r, color.g, color.b, 1.0))
		_configure(mat, null, null)
	return mat


static func clear_caches() -> void:
	_shaders.clear()
	_texture_cache.clear()
	_file_texture_cache.clear()
	_normal_cache.clear()
	_shared.clear()
	_fallback = null
	_black = null


static func set_normal_maps_enabled(enabled: bool) -> void:
	RenderingServer.global_shader_parameter_set("ds_normal_maps", enabled)
