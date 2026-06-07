class_name LevelSymbolRow
extends Control

const NEUTRAL_LEVEL_SYMBOL_TEXTURE_PATH := "res://images/ui/NeutralLevelSymbol.png"
const ANCIENT_LEVEL_SYMBOL_TEXTURE_PATH := "res://images/ui/AncientLevelSymbol.jpg"
const NORSE_LEVEL_SYMBOL_TEXTURE_PATH := "res://images/ui/NorseLevelSymbol.png"
const TIAN_LEVEL_SYMBOL_TEXTURE_PATH := "res://images/ui/TianLevelSymbol.png"
const OLYMPIC_LEVEL_SYMBOL_TEXTURE_PATH := "res://images/ui/OlympicLevelSymbol.png"
const NAHUATL_LEVEL_SYMBOL_TEXTURE_PATH := "res://images/ui/NahuatlLevelSymbol.png"
const TRISKELION_LEVEL_SYMBOL_TEXTURE_PATH := "res://images/ui/TriskelionLevelSymbol.png"
const ATLANITAN_LEVEL_SYMBOL_TEXTURE_PATH := "res://images/ui/AtlanitanLevelSymbol.png"

static var _neutral_level_symbol_texture: Texture2D = null
static var _ancient_level_symbol_texture: Texture2D = null
static var _norse_level_symbol_texture: Texture2D = null
static var _tian_level_symbol_texture: Texture2D = null
static var _olympic_level_symbol_texture: Texture2D = null
static var _nahuatl_level_symbol_texture: Texture2D = null
static var _triskelion_level_symbol_texture: Texture2D = null
static var _atlanitan_level_symbol_texture: Texture2D = null

var level_count: int = 0
var symbol_size: float = 12.0
var symbol_color: Color = Color.WHITE
var symbol_texture: Texture2D = null

static func _load_symbol_texture(path: String) -> Texture2D:
	var byte_loaded_texture := _load_symbol_texture_from_bytes(path)
	if byte_loaded_texture != null:
		return byte_loaded_texture
	var direct_texture := load(path) as Texture2D
	if direct_texture != null:
		return direct_texture
	var imported_path := _get_imported_texture_path(path)
	if imported_path != "":
		var imported_texture := load(imported_path) as Texture2D
		if imported_texture != null:
			return imported_texture
	return null

static func _load_symbol_texture_from_bytes(path: String) -> Texture2D:
	# Allow freshly added source textures before Godot regenerates a valid .import remap.
	var global_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path):
		return null
	var bytes := FileAccess.get_file_as_bytes(global_path)
	if bytes.size() < 4:
		return null
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes.size() >= 8 \
			and bytes[0] == 0x89 \
			and bytes[1] == 0x50 \
			and bytes[2] == 0x4E \
			and bytes[3] == 0x47:
		err = image.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = image.load_jpg_from_buffer(bytes)
	if err != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

static func _get_imported_texture_path(path: String) -> String:
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return ""
	var import_file := FileAccess.open(import_path, FileAccess.READ)
	if import_file == null:
		return ""
	while not import_file.eof_reached():
		var line := import_file.get_line().strip_edges()
		if not line.begins_with("path=\""):
			continue
		var imported_path := line.trim_prefix("path=\"").trim_suffix("\"")
		return imported_path if FileAccess.file_exists(imported_path) else ""
	return ""

static func _get_ancient_level_symbol_texture() -> Texture2D:
	if _ancient_level_symbol_texture == null:
		_ancient_level_symbol_texture = _load_symbol_texture(ANCIENT_LEVEL_SYMBOL_TEXTURE_PATH)
	return _ancient_level_symbol_texture

static func _get_neutral_level_symbol_texture() -> Texture2D:
	if _neutral_level_symbol_texture == null:
		_neutral_level_symbol_texture = _load_symbol_texture(NEUTRAL_LEVEL_SYMBOL_TEXTURE_PATH)
	return _neutral_level_symbol_texture

static func _get_norse_level_symbol_texture() -> Texture2D:
	if _norse_level_symbol_texture == null:
		_norse_level_symbol_texture = _load_symbol_texture(NORSE_LEVEL_SYMBOL_TEXTURE_PATH)
		if _norse_level_symbol_texture == null:
			_norse_level_symbol_texture = _get_neutral_level_symbol_texture()
	return _norse_level_symbol_texture

static func _get_tian_level_symbol_texture() -> Texture2D:
	if _tian_level_symbol_texture == null:
		_tian_level_symbol_texture = _load_symbol_texture(TIAN_LEVEL_SYMBOL_TEXTURE_PATH)
		if _tian_level_symbol_texture == null:
			_tian_level_symbol_texture = _get_neutral_level_symbol_texture()
	return _tian_level_symbol_texture

static func _get_olympic_level_symbol_texture() -> Texture2D:
	if _olympic_level_symbol_texture == null:
		_olympic_level_symbol_texture = _load_symbol_texture(OLYMPIC_LEVEL_SYMBOL_TEXTURE_PATH)
		if _olympic_level_symbol_texture == null:
			_olympic_level_symbol_texture = _get_neutral_level_symbol_texture()
	return _olympic_level_symbol_texture

static func _get_nahuatl_level_symbol_texture() -> Texture2D:
	if _nahuatl_level_symbol_texture == null:
		_nahuatl_level_symbol_texture = _load_symbol_texture(NAHUATL_LEVEL_SYMBOL_TEXTURE_PATH)
		if _nahuatl_level_symbol_texture == null:
			_nahuatl_level_symbol_texture = _get_neutral_level_symbol_texture()
	return _nahuatl_level_symbol_texture

static func _get_triskelion_level_symbol_texture() -> Texture2D:
	if _triskelion_level_symbol_texture == null:
		_triskelion_level_symbol_texture = _load_symbol_texture(TRISKELION_LEVEL_SYMBOL_TEXTURE_PATH)
		if _triskelion_level_symbol_texture == null:
			_triskelion_level_symbol_texture = _get_neutral_level_symbol_texture()
	return _triskelion_level_symbol_texture

static func _get_atlanitan_level_symbol_texture() -> Texture2D:
	if _atlanitan_level_symbol_texture == null:
		_atlanitan_level_symbol_texture = _load_symbol_texture(ATLANITAN_LEVEL_SYMBOL_TEXTURE_PATH)
		if _atlanitan_level_symbol_texture == null:
			_atlanitan_level_symbol_texture = _get_neutral_level_symbol_texture()
	return _atlanitan_level_symbol_texture

static func get_symbol_texture_for_card(card: Card) -> Texture2D:
	if card == null:
		return _get_neutral_level_symbol_texture()
	if str(card.culture).strip_edges() == "Norse":
		return _get_norse_level_symbol_texture()
	if str(card.culture).strip_edges() == "Tian":
		return _get_tian_level_symbol_texture()
	if str(card.culture).strip_edges() == "Olympic":
		return _get_olympic_level_symbol_texture()
	if str(card.culture).strip_edges() == "Nahuatl" or str(card.culture).strip_edges() == "Nahutl":
		return _get_nahuatl_level_symbol_texture()
	if str(card.culture).strip_edges() == "Triskelion":
		return _get_triskelion_level_symbol_texture()
	if str(card.culture).strip_edges() == "Atlanitan" or str(card.culture).strip_edges() == "Atlantian":
		return _get_atlanitan_level_symbol_texture()
	if str(card.culture).strip_edges() == "Ancient":
		return _get_ancient_level_symbol_texture()
	if card.has_type("Ancient") or card.has_type("Ancient Creature") or card.has_type("Ancient Power") or card.has_type("Ancient Structure"):
		return _get_ancient_level_symbol_texture()
	return _get_neutral_level_symbol_texture()

func setup(count: int, size_px: float, color: Color = Color.WHITE, texture: Texture2D = null) -> void:
	level_count = maxi(0, count)
	symbol_size = maxf(1.0, size_px)
	symbol_color = color
	symbol_texture = texture if texture != null else _get_neutral_level_symbol_texture()
	custom_minimum_size = Vector2(symbol_size * float(level_count), symbol_size)
	size = custom_minimum_size
	queue_redraw()

func _draw() -> void:
	if symbol_texture == null:
		return
	var draw_y := maxf(0.0, (size.y - symbol_size) * 0.5)
	for i in range(level_count):
		draw_texture_rect(
			symbol_texture,
			Rect2(Vector2(symbol_size * float(i), draw_y), Vector2(symbol_size, symbol_size)),
			false,
			symbol_color
		)
