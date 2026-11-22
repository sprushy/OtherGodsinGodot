extends RefCounted
class_name GameCursor

const CURSOR_SOURCE := preload("res://images/ui/cursors/StealthFogCursor.png")
const UIArtScalerScript = preload("res://scripts/ui/UIArtScaler.gd")

const CURSOR_TARGET_HEIGHT := 53
const CURSOR_HOTSPOT_RATIO := Vector2(0.10, 0.08)
const DEFAULT_CURSOR_SHAPES := [
	Input.CURSOR_ARROW,
	Input.CURSOR_POINTING_HAND,
	Input.CURSOR_HELP,
]

static var _registered_target_height: int = 0

static func get_target_height() -> int:
	return CURSOR_TARGET_HEIGHT

static func build_texture() -> Texture2D:
	return UIArtScalerScript.build_cursor_texture(CURSOR_SOURCE, get_target_height())

static func get_hotspot(texture: Texture2D) -> Vector2:
	return UIArtScalerScript.get_cursor_hotspot(texture, CURSOR_HOTSPOT_RATIO)

static func ensure_registered(cursor_shapes: Array = DEFAULT_CURSOR_SHAPES) -> bool:
	var target_height := get_target_height()
	_registered_target_height = target_height
	var cursor_texture := build_texture()
	if cursor_texture == null:
		return false
	var hotspot := get_hotspot(cursor_texture)
	for cursor_shape in cursor_shapes:
		Input.set_custom_mouse_cursor(cursor_texture, cursor_shape, hotspot)
	return true

static func clear(cursor_shapes: Array = DEFAULT_CURSOR_SHAPES) -> void:
	for cursor_shape in cursor_shapes:
		Input.set_custom_mouse_cursor(null, cursor_shape)
