extends RefCounted

const SWORD_TEXTURE_PATH := "res://images/AggressiveSwordOverlay.png"
const OVERLAY_NAME := "AggressiveSwordOverlay"
const LAYOUT_CORNER := 0
const LAYOUT_STAT_UNDER := 1
const LAYOUT_CENTER := 2
const CORNER_WIDTH_RATIO := 0.46
const CORNER_MAX_HEIGHT_RATIO := 0.70
const CORNER_MARGIN_RATIO := 0.025
const STAT_WIDTH_RATIO := 0.46
const STAT_MAX_HEIGHT_RATIO := 0.72
const STAT_BADGE_LEFT := 6.0
const STAT_BADGE_WIDTH := 60.0
const STAT_BOTTOM_EXTENSION_RATIO := 0.34
const STAT_MIN_EXTENSION := 18.0

static var _sword_texture: Texture2D = null
static var _sword_texture_loaded := false

class SwordOverlayContainer:
	extends Control

	var layout_kind: int = LAYOUT_CORNER
	var size_multiplier: float = 1.0

	func _ready() -> void:
		var resize_callback := Callable(self, "_layout_container")
		if not resized.is_connected(resize_callback):
			resized.connect(resize_callback)
		_layout_container()
		call_deferred("_layout_container")

	func configure(p_layout_kind: int, p_size_multiplier: float) -> void:
		layout_kind = p_layout_kind
		size_multiplier = maxf(0.01, p_size_multiplier)
		_layout_container()
		call_deferred("_layout_container")

	func _compute_sword_size(parent_size: Vector2, width_ratio: float, max_height_ratio: float) -> Vector2:
		var sword := get_node_or_null("SwordImage") as TextureRect
		if sword == null or sword.texture == null:
			return Vector2.ZERO
		var texture_size: Vector2 = sword.texture.get_size()
		if texture_size.x <= 0.0 or texture_size.y <= 0.0:
			return Vector2.ZERO
		var aspect: float = texture_size.x / texture_size.y
		var scaled_width_ratio := width_ratio * size_multiplier
		var scaled_max_height_ratio := max_height_ratio * size_multiplier
		var sword_size := Vector2(parent_size.x * scaled_width_ratio, parent_size.x * scaled_width_ratio / aspect)
		var max_height := parent_size.y * scaled_max_height_ratio
		if sword_size.y > max_height:
			sword_size.y = max_height
			sword_size.x = sword_size.y * aspect
		return sword_size

	func _layout_container() -> void:
		var sword := get_node_or_null("SwordImage") as TextureRect
		if sword == null:
			return

		var parent_size := size
		if parent_size.x <= 0.0 or parent_size.y <= 0.0:
			return

		var sword_size := Vector2.ZERO
		match layout_kind:
			LAYOUT_STAT_UNDER:
				sword_size = _compute_sword_size(parent_size, STAT_WIDTH_RATIO, STAT_MAX_HEIGHT_RATIO)
			LAYOUT_CENTER:
				sword_size = _compute_sword_size(parent_size, CORNER_WIDTH_RATIO, CORNER_MAX_HEIGHT_RATIO)
			_:
				sword_size = _compute_sword_size(parent_size, CORNER_WIDTH_RATIO, CORNER_MAX_HEIGHT_RATIO)
		if sword_size == Vector2.ZERO:
			return

		sword.size = sword_size
		match layout_kind:
			LAYOUT_STAT_UNDER:
				var badge_left := STAT_BADGE_LEFT + (STAT_BADGE_WIDTH - sword_size.x) * 0.5
				var bottom_extension := maxf(STAT_MIN_EXTENSION, sword_size.y * STAT_BOTTOM_EXTENSION_RATIO)
				sword.position = Vector2(
					badge_left,
					parent_size.y - sword_size.y + bottom_extension
				)
			LAYOUT_CENTER:
				sword.position = (parent_size - sword_size) * 0.5
			_:
				var margin := maxf(2.0, minf(parent_size.x, parent_size.y) * CORNER_MARGIN_RATIO)
				sword.position = Vector2(
					parent_size.x - sword_size.x - margin,
					parent_size.y - sword_size.y - margin
				)

static func _get_sword_texture() -> Texture2D:
	if not _sword_texture_loaded:
		_sword_texture_loaded = true
		_sword_texture = load(SWORD_TEXTURE_PATH) as Texture2D
	return _sword_texture

static func ensure_on(parent: Control, p_layout_kind: int = LAYOUT_CORNER, p_size_multiplier: float = 1.0) -> Control:
	if parent == null or not is_instance_valid(parent):
		return null
	var texture := _get_sword_texture()
	if texture == null:
		return null
	var existing := parent.get_node_or_null(OVERLAY_NAME) as Control
	if existing != null:
		if existing is SwordOverlayContainer:
			_configure_container(existing, p_layout_kind, p_size_multiplier)
			return existing
		parent.remove_child(existing)
		existing.queue_free()

	var container := SwordOverlayContainer.new()
	container.name = OVERLAY_NAME
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.clip_contents = false
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(container)

	var sword := TextureRect.new()
	sword.name = "SwordImage"
	sword.texture = texture
	sword.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sword.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sword)

	_configure_container(container, p_layout_kind, p_size_multiplier)
	return container

static func remove_from(parent: Control) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var existing := parent.get_node_or_null(OVERLAY_NAME)
	if existing != null:
		existing.queue_free()

static func _configure_container(container: Control, p_layout_kind: int, p_size_multiplier: float) -> void:
	if container == null or not is_instance_valid(container):
		return
	var sword_container := container as SwordOverlayContainer
	if sword_container == null:
		return
	sword_container.configure(p_layout_kind, p_size_multiplier)
