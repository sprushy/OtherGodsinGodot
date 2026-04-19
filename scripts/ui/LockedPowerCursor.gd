extends RefCounted
class_name LockedPowerCursor

const CURSOR_SOURCE := preload("res://images/NorseLockedPowerCursor.png")
const CURSOR_SHAPE := Input.CURSOR_VSPLIT
const CONTROL_CURSOR_SHAPE := Control.CURSOR_VSPLIT
const CURSOR_TARGET_HEIGHT := 96
const CURSOR_HOTSPOT_RATIO := Vector2(0.50, 0.28)

static var _registered: bool = false

static func ensure_registered() -> bool:
	if _registered:
		return true
	if CURSOR_SOURCE == null:
		return false
	var cursor_texture := _build_cursor_texture(CURSOR_SOURCE, CURSOR_TARGET_HEIGHT)
	if cursor_texture == null:
		return false
	var hotspot := _get_cursor_hotspot(cursor_texture, CURSOR_HOTSPOT_RATIO)
	Input.set_custom_mouse_cursor(cursor_texture, CURSOR_SHAPE, hotspot)
	_registered = true
	return true

static func get_control_cursor_shape(fallback_shape: int) -> int:
	return CONTROL_CURSOR_SHAPE if ensure_registered() else fallback_shape

static func _build_cursor_texture(source_texture: Texture2D, target_height_limit: int) -> Texture2D:
	if source_texture == null:
		return null
	var source_image := source_texture.get_image()
	if source_image == null or source_image.is_empty():
		return null
	var used_rect := source_image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		used_rect = Rect2i(Vector2i.ZERO, source_image.get_size())
	var cursor_image := source_image.get_region(used_rect)
	if cursor_image == null or cursor_image.is_empty():
		return null
	var target_height := mini(target_height_limit, cursor_image.get_height())
	if target_height <= 0:
		return null
	var cursor_scale := float(target_height) / float(cursor_image.get_height())
	var target_width := maxi(1, int(round(cursor_image.get_width() * cursor_scale)))
	cursor_image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(cursor_image)

static func _get_cursor_hotspot(texture: Texture2D, hotspot_ratio: Vector2) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var size := texture.get_size()
	return Vector2(
		clampf(size.x * hotspot_ratio.x, 0.0, maxf(0.0, size.x - 1.0)),
		clampf(size.y * hotspot_ratio.y, 0.0, maxf(0.0, size.y - 1.0))
	)
