class_name DefenseShieldOverlay
extends TextureRect

const SHIELD_TEXTURE := preload("res://images/DefenseShieldOverlay.png")
const OVERLAY_NAME := "DefenseShieldOverlay"
const LAYOUT_CORNER := 0
const LAYOUT_STAT_UNDER := 1
const LAYOUT_CENTER := 2
const STEALTH_VIEW_SIZE_MULTIPLIER := 1.30
const CORNER_WIDTH_RATIO := 0.46
const CORNER_MAX_HEIGHT_RATIO := 0.70
const CORNER_MARGIN_RATIO := 0.025
const STAT_WIDTH_RATIO := 0.46
const STAT_MAX_HEIGHT_RATIO := 0.72
const STAT_BADGE_LEFT := 6.0
const STAT_BADGE_WIDTH := 60.0
const STAT_BOTTOM_EXTENSION_RATIO := 0.34
const STAT_MIN_EXTENSION := 18.0

var _layout_mode: int = LAYOUT_CORNER
var _size_multiplier: float = 1.0

static func ensure_on(parent: Control, shield_layout_mode: int = LAYOUT_CORNER, size_multiplier: float = 1.0) -> Control:
	if parent == null or not is_instance_valid(parent):
		return null
	var existing := parent.get_node_or_null(OVERLAY_NAME) as Control
	if existing != null:
		_configure_container(existing, shield_layout_mode, size_multiplier)
		return existing

	var container := Control.new()
	container.name = OVERLAY_NAME
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.clip_contents = false
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(container)

	var shield := DefenseShieldOverlay.new()
	shield.name = "ShieldImage"
	container.add_child(shield)
	_configure_container(container, shield_layout_mode, size_multiplier)
	return container

static func remove_from(parent: Control) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var existing := parent.get_node_or_null(OVERLAY_NAME)
	if existing != null:
		existing.queue_free()

static func _configure_container(container: Control, shield_layout_mode: int, size_multiplier: float) -> void:
	if container == null or not is_instance_valid(container):
		return
	var shield := container.get_node_or_null("ShieldImage") as DefenseShieldOverlay
	if shield != null:
		shield.set_layout_mode(shield_layout_mode, size_multiplier)

func _init() -> void:
	texture = SHIELD_TEXTURE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_layout_mode(shield_layout_mode: int, size_multiplier: float = 1.0) -> void:
	_layout_mode = shield_layout_mode
	_size_multiplier = maxf(0.01, size_multiplier)
	_layout_to_parent()
	call_deferred("_layout_to_parent")

func _ready() -> void:
	_connect_parent_resize()
	_layout_to_parent()
	call_deferred("_layout_to_parent")

func _exit_tree() -> void:
	var parent_control := get_parent() as Control
	var resize_callback := Callable(self, "_layout_to_parent")
	if parent_control != null and parent_control.resized.is_connected(resize_callback):
		parent_control.resized.disconnect(resize_callback)

func _connect_parent_resize() -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var resize_callback := Callable(self, "_layout_to_parent")
	if not parent_control.resized.is_connected(resize_callback):
		parent_control.resized.connect(resize_callback)

func _compute_shield_size(parent_size: Vector2, width_ratio: float, max_height_ratio: float) -> Vector2:
	var texture_size := SHIELD_TEXTURE.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ZERO
	var aspect := texture_size.x / texture_size.y
	var scaled_width_ratio := width_ratio * _size_multiplier
	var scaled_max_height_ratio := max_height_ratio * _size_multiplier
	var shield_size := Vector2(parent_size.x * scaled_width_ratio, parent_size.x * scaled_width_ratio / aspect)
	var max_height := parent_size.y * scaled_max_height_ratio
	if shield_size.y > max_height:
		shield_size.y = max_height
		shield_size.x = shield_size.y * aspect
	return shield_size

func _layout_to_parent() -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return

	var parent_size := parent_control.size
	if parent_size.x <= 0.0 or parent_size.y <= 0.0:
		return

	var shield_size := Vector2.ZERO
	match _layout_mode:
		LAYOUT_STAT_UNDER:
			shield_size = _compute_shield_size(parent_size, STAT_WIDTH_RATIO, STAT_MAX_HEIGHT_RATIO)
		LAYOUT_CENTER:
			shield_size = _compute_shield_size(parent_size, CORNER_WIDTH_RATIO, CORNER_MAX_HEIGHT_RATIO)
		_:
			shield_size = _compute_shield_size(parent_size, CORNER_WIDTH_RATIO, CORNER_MAX_HEIGHT_RATIO)
	if shield_size == Vector2.ZERO:
		return

	size = shield_size
	match _layout_mode:
		LAYOUT_STAT_UNDER:
			var badge_left := STAT_BADGE_LEFT + (STAT_BADGE_WIDTH - shield_size.x) * 0.5
			var bottom_extension := maxf(STAT_MIN_EXTENSION, shield_size.y * STAT_BOTTOM_EXTENSION_RATIO)
			position = Vector2(
				badge_left,
				parent_size.y - shield_size.y + bottom_extension
			)
		LAYOUT_CENTER:
			position = (parent_size - shield_size) * 0.5
		_:
			var margin := maxf(2.0, minf(parent_size.x, parent_size.y) * CORNER_MARGIN_RATIO)
			position = Vector2(
				parent_size.x - shield_size.x - margin,
				parent_size.y - shield_size.y - margin
			)
