class_name UITextureCache
extends RefCounted

static var _textures_by_path: Dictionary = {}

static func get_texture(path: String) -> Texture2D:
	var normalized_path := str(path).strip_edges()
	if normalized_path == "":
		return null
	if _textures_by_path.has(normalized_path):
		var cached = _textures_by_path[normalized_path]
		if cached is Texture2D:
			return cached
		_textures_by_path.erase(normalized_path)

	var texture := ResourceLoader.load(normalized_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	if texture != null:
		_textures_by_path[normalized_path] = texture
	return texture

static func clear() -> void:
	_textures_by_path.clear()
