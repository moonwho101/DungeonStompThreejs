# Locates the game data (Assets/, bin/, Sounds/, Midi/) on disk.
# These folders are excluded from Godot's importer (.gdignore), so every file is read at runtime,
# exactly like the browser version fetches them. In the editor they live in the project folder;
# an exported build looks next to the executable.
class_name DataPaths
extends RefCounted

static var _root: String = ""
static var _asset_index: Dictionary = {}
static var _asset_index_built: bool = false


static func root() -> String:
	if _root != "":
		return _root
	var candidates: Array[String] = []
	var res_root := ProjectSettings.globalize_path("res://")
	if res_root != "":
		candidates.append(res_root)
	candidates.append(OS.get_executable_path().get_base_dir())
	for c in candidates:
		if DirAccess.dir_exists_absolute(c.path_join("bin")) and DirAccess.dir_exists_absolute(c.path_join("Assets")):
			_root = c
			return _root
	_root = candidates[0]
	return _root


static func path(rel: String) -> String:
	return root().path_join(rel.replace("\\", "/"))


static func read_text(rel: String) -> String:
	var f := FileAccess.open(path(rel), FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


static func read_bytes_abs(abs_path: String) -> PackedByteArray:
	if abs_path == "":
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(abs_path)


static func _build_asset_index() -> void:
	_asset_index_built = true
	_asset_index.clear()
	var dir := path("Assets")
	for f in DirAccess.get_files_at(dir):
		_asset_index[f.to_lower()] = f


# Returns the absolute path of `file_name` inside Assets/ with its real casing, or "" when missing.
static func resolve_asset(file_name: String) -> String:
	if not _asset_index_built:
		_build_asset_index()
	var real: String = _asset_index.get(file_name.to_lower(), "")
	if real == "":
		return ""
	return path("Assets").path_join(real)


# Texture lookup order: .jpg, then .png (only the file stem of `path_or_stem` is used).
static func texture_candidates(path_or_stem: String) -> PackedStringArray:
	var stem := path_or_stem.replace("\\", "/").get_file()
	var dot := stem.rfind(".")
	if dot != -1:
		stem = stem.substr(0, dot)
	var out := PackedStringArray()
	for ext in ["jpg", "png"]:
		var p := resolve_asset(stem + "." + ext)
		if p != "":
			out.append(p)
	return out


static func load_image(abs_path: String) -> Image:
	if abs_path == "" or not FileAccess.file_exists(abs_path):
		return null
	var img := Image.load_from_file(abs_path)
	if img == null or img.is_empty():
		return null
	return img
