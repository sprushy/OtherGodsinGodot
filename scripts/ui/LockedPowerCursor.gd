extends RefCounted
class_name LockedPowerCursor

const CURSOR_SOURCE := preload("res://images/NorseLockedPowerCursor.png")
const UIArtScalerScript = preload("res://scripts/ui/UIArtScaler.gd")
const CURSOR_SHAPE := Input.CURSOR_CROSS
const CONTROL_CURSOR_SHAPE := Control.CURSOR_CROSS
const CURSOR_TARGET_HEIGHT := 72
const CURSOR_HOTSPOT_RATIO := Vector2(0.50, 0.28)

static var _registered: bool = false
static var _registered_target_height: int = 0

static func ensure_registered() -> bool:
	var target_height := UIArtScalerScript.get_board_cursor_target_height(CURSOR_TARGET_HEIGHT)
	if _registered and _registered_target_height == target_height:
		return true
	if CURSOR_SOURCE == null:
		return false
	var cursor_texture := UIArtScalerScript.build_cursor_texture(CURSOR_SOURCE, target_height)
	if cursor_texture == null:
		return false
	var hotspot := UIArtScalerScript.get_cursor_hotspot(cursor_texture, CURSOR_HOTSPOT_RATIO)
	Input.set_custom_mouse_cursor(cursor_texture, CURSOR_SHAPE, hotspot)
	_registered = true
	_registered_target_height = target_height
	return true

static func get_control_cursor_shape(fallback_shape: Control.CursorShape) -> Control.CursorShape:
	if ensure_registered():
		return CONTROL_CURSOR_SHAPE as Control.CursorShape
	return fallback_shape
