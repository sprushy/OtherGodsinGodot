extends RefCounted

const SWORD_TEXTURE := preload("res://images/AggressiveSwordOverlay.png")
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

static func ensure_on(parent: Control, p_layout_kind: int = LAYOUT_CORNER, p_size_multiplier: float = 1.0) -> Control:
	if parent == null or not is_instance_valid(parent):
		return null
	var existing := parent.get_node_or_null(OVERLAY_NAME) as Control
	if existing != null:
		_configure_container(existing, p_layout_kind, p_size_multiplier)
		return existing

	var container := Control.new()
	container.name = OVERLAY_NAME
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.clip_contents = false
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(container)

	var sword := TextureRect.new()
	sword.name = "SwordImage"
	sword.texture = SWORD_TEXTURE
	sword.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sword.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sword)

	container.resized.connect(func() -> void:
		_layout_container(container)
	)
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
	container.set_meta("sword_layout_kind", p_layout_kind)
	container.set_meta("sword_size_multiplier", maxf(0.01, p_size_multiplier))
	_layout_container(container)
	var callable := func() -> void:
		_layout_container(container)
	callable.call_deferred()

static func _compute_sword_size(parent_size: Vector2, width_ratio: float, max_height_ratio: float, size_multiplier: float) -> Vector2:
	var texture_size := SWORD_TEXTURE.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ZERO
	var aspect := texture_size.x / texture_size.y
	var scaled_width_ratio := width_ratio * size_multiplier
	var scaled_max_height_ratio := max_height_ratio * size_multiplier
	var sword_size := Vector2(parent_size.x * scaled_width_ratio, parent_size.x * scaled_width_ratio / aspect)
	var max_height := parent_size.y * scaled_max_height_ratio
	if sword_size.y > max_height:
		sword_size.y = max_height
		sword_size.x = sword_size.y * aspect
	return sword_size

static func _layout_container(container: Control) -> void:
	if container == null or not is_instance_valid(container):
		return
	var sword := container.get_node_or_null("SwordImage") as TextureRect
	if sword == null:
		return

	var parent_size := container.size
	if parent_size.x <= 0.0 or parent_size.y <= 0.0:
		return

	var layout_kind := int(container.get_meta("sword_layout_kind", LAYOUT_CORNER))
	var size_multiplier := float(container.get_meta("sword_size_multiplier", 1.0))
	var sword_size := Vector2.ZERO
	match layout_kind:
		LAYOUT_STAT_UNDER:
			sword_size = _compute_sword_size(parent_size, STAT_WIDTH_RATIO, STAT_MAX_HEIGHT_RATIO, size_multiplier)
		LAYOUT_CENTER:
			sword_size = _compute_sword_size(parent_size, CORNER_WIDTH_RATIO, CORNER_MAX_HEIGHT_RATIO, size_multiplier)
		_:
			sword_size = _compute_sword_size(parent_size, CORNER_WIDTH_RATIO, CORNER_MAX_HEIGHT_RATIO, size_multiplier)
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
