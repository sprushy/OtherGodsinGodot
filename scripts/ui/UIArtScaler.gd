extends RefCounted
class_name UIArtScaler

const BoardZoneUI = preload("res://scripts/ui/BoardZoneUI.gd")

const DEFAULT_BOARD_ART_REFERENCE_EXTENT := 196.0
const DEFAULT_CURSOR_MAX_HEIGHT := 192
const FALLBACK_VIEWPORT_WIDTH := 1920
const FALLBACK_VIEWPORT_HEIGHT := 1080

# Cursor and other UI art should scale from the gameplay layout baseline,
# not stay at a fixed pixel size once the board or window grows.
static func get_window_scale_factor() -> float:
	var base_width := int(ProjectSettings.get_setting("display/window/size/viewport_width", FALLBACK_VIEWPORT_WIDTH))
	var base_height := int(ProjectSettings.get_setting("display/window/size/viewport_height", FALLBACK_VIEWPORT_HEIGHT))
	var window_size := DisplayServer.window_get_size()
	var width_ratio := float(window_size.x) / maxf(1.0, float(base_width))
	var height_ratio := float(window_size.y) / maxf(1.0, float(base_height))
	return maxf(1.0, minf(width_ratio, height_ratio))

static func get_board_art_scale(reference_extent: float = DEFAULT_BOARD_ART_REFERENCE_EXTENT) -> float:
	var zone_extent := BoardZoneUI.get_zone_extent()
	if zone_extent <= reference_extent:
		return 1.0
	return zone_extent / reference_extent

static func get_cursor_target_height(
	base_height: int,
	scale_factor: float,
	max_height: int = DEFAULT_CURSOR_MAX_HEIGHT
) -> int:
	return clampi(
		int(round(float(base_height) * maxf(1.0, scale_factor))),
		base_height,
		max_height
	)

static func get_board_cursor_target_height(
	base_height: int,
	reference_extent: float = DEFAULT_BOARD_ART_REFERENCE_EXTENT,
	max_height: int = DEFAULT_CURSOR_MAX_HEIGHT
) -> int:
	return get_cursor_target_height(base_height, get_board_art_scale(reference_extent), max_height)

static func get_window_cursor_target_height(
	base_height: int,
	max_height: int = DEFAULT_CURSOR_MAX_HEIGHT
) -> int:
	return get_cursor_target_height(base_height, get_window_scale_factor(), max_height)

static func build_cursor_texture(source_texture: Texture2D, target_height_limit: int) -> Texture2D:
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

static func get_cursor_hotspot(texture: Texture2D, hotspot_ratio: Vector2) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var size := texture.get_size()
	return Vector2(
		clampf(size.x * hotspot_ratio.x, 0.0, maxf(0.0, size.x - 1.0)),
		clampf(size.y * hotspot_ratio.y, 0.0, maxf(0.0, size.y - 1.0))
	)
