extends RefCounted
class_name GameCursor

const CURSOR_SOURCE := preload("res://images/ui/cursors/StealthFogCursor.png")
const UIArtScalerScript = preload("res://scripts/ui/UIArtScaler.gd")

const CURSOR_TARGET_HEIGHT := 67
const CURSOR_HOTSPOT_RATIO := Vector2(0.10, 0.08)
const DEFAULT_CURSOR_SHAPES := [
	Input.CURSOR_ARROW,
	Input.CURSOR_POINTING_HAND,
	Input.CURSOR_HELP,
]

static var _registered_target_height: int = 0

static func ensure_registered(cursor_shapes: Array = DEFAULT_CURSOR_SHAPES) -> bool:
	var target_height := UIArtScalerScript.get_window_cursor_target_height(CURSOR_TARGET_HEIGHT)
	_registered_target_height = target_height
	var cursor_texture := UIArtScalerScript.build_cursor_texture(CURSOR_SOURCE, target_height)
	if cursor_texture == null:
		return false
	var hotspot := UIArtScalerScript.get_cursor_hotspot(cursor_texture, CURSOR_HOTSPOT_RATIO)
	for cursor_shape in cursor_shapes:
		Input.set_custom_mouse_cursor(cursor_texture, cursor_shape, hotspot)
	return true

static func clear(cursor_shapes: Array = DEFAULT_CURSOR_SHAPES) -> void:
	for cursor_shape in cursor_shapes:
		Input.set_custom_mouse_cursor(null, cursor_shape)
