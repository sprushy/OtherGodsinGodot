class_name UIFont
extends RefCounted

const CUSTOM_FONT_DIR := "res://fonts/custom_ui"
const DEFAULT_UI_FONT_PATHS := [
	CUSTOM_FONT_DIR + "/Norsebold.otf",
	CUSTOM_FONT_DIR + "/Norse.otf",
	CUSTOM_FONT_DIR + "/OtherGodsUI.otf",
	CUSTOM_FONT_DIR + "/OtherGodsUI.ttf",
	CUSTOM_FONT_DIR + "/OtherGodsUI.woff2",
	CUSTOM_FONT_DIR + "/OtherGodsUI.woff",
	CUSTOM_FONT_DIR + "/OtherGodsUI.fnt",
]
const NORSE_CARD_NAME_FONT_PATHS := [
	CUSTOM_FONT_DIR + "/Norsebold.otf",
	CUSTOM_FONT_DIR + "/Norse.otf",
	CUSTOM_FONT_DIR + "/NorseCardNames.otf",
	CUSTOM_FONT_DIR + "/NorseCardNames.ttf",
	CUSTOM_FONT_DIR + "/NorseCardNames.woff2",
	CUSTOM_FONT_DIR + "/NorseCardNames.woff",
	CUSTOM_FONT_DIR + "/NorseCardNames.fnt",
	CUSTOM_FONT_DIR + "/OtherGodsUI.otf",
	CUSTOM_FONT_DIR + "/OtherGodsUI.ttf",
	CUSTOM_FONT_DIR + "/OtherGodsUI.woff2",
	CUSTOM_FONT_DIR + "/OtherGodsUI.woff",
	CUSTOM_FONT_DIR + "/OtherGodsUI.fnt",
]

static var _default_font: Font = null
static var _norse_card_name_font: Font = null
static var _did_try_default_font := false
static var _did_try_norse_card_name_font := false

static func get_default_font() -> Font:
	if not _did_try_default_font:
		_default_font = _load_first_font(DEFAULT_UI_FONT_PATHS)
		_did_try_default_font = true
	return _default_font

static func get_norse_card_name_font() -> Font:
	if not _did_try_norse_card_name_font:
		_norse_card_name_font = _load_first_font(NORSE_CARD_NAME_FONT_PATHS)
		_did_try_norse_card_name_font = true
	return _norse_card_name_font

static func apply_default_font(root: Control) -> bool:
	var font := get_default_font()
	if root == null or font == null:
		return false
	if root.theme == null:
		root.theme = Theme.new()
	root.theme.default_font = font
	return true

static func apply_norse_card_name_font(label: Label, card: Card) -> bool:
	if label == null or not is_norse_card(card):
		return false
	var font := get_norse_card_name_font()
	if font == null:
		return false
	label.add_theme_font_override("font", font)
	return true

static func clear_card_name_font(label: Label) -> void:
	if label == null:
		return
	label.remove_theme_font_override("font")

static func refresh_card_name_font(label: Label, card: Card) -> void:
	clear_card_name_font(label)
	apply_norse_card_name_font(label, card)

static func is_norse_card(card: Card) -> bool:
	if card == null:
		return false
	if str(card.culture).strip_edges().to_lower() == "norse":
		return true
	for card_type in card.card_types:
		if str(card_type).strip_edges().to_lower().contains("norse"):
			return true
	return false

static func _load_first_font(paths: Array) -> Font:
	for path in paths:
		var font_path := str(path)
		if not ResourceLoader.exists(font_path) and not FileAccess.file_exists(font_path):
			continue
		var font := _load_font_file(font_path)
		if font != null:
			_apply_engine_fallback(font)
			return font
	return null

static func _load_font_file(font_path: String) -> Font:
	var extension := font_path.get_extension().to_lower()
	if extension == "fnt" or extension == "font":
		var bitmap_font := FontFile.new()
		var error := bitmap_font.load_bitmap_font(font_path)
		return bitmap_font if error == OK else null
	if extension == "otf" or extension == "ttf" or extension == "woff2" or extension == "woff":
		var dynamic_font := FontFile.new()
		var error := dynamic_font.load_dynamic_font(font_path)
		return dynamic_font if error == OK else null
	var loaded := ResourceLoader.load(font_path)
	return loaded as Font

static func _apply_engine_fallback(font: Font) -> void:
	var fallback := ThemeDB.fallback_font
	if fallback == null or fallback == font:
		return
	font.fallbacks = [fallback]
