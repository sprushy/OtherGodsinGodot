class_name AbyssGatewayIcon
extends Control

signal portal_clicked

const GATEWAY_TEXTURE := preload("res://images/ui/zones/abyss_gateway.png")
const GATEWAY_FOREGROUND_TEXTURE := preload("res://images/ui/zones/abyss_gateway_foreground_overlay.png")
const VOID_SHEET_TEXTURE := preload("res://images/ui/zones/abyss_gateway_void_sheet.png")
const ART_OVERSCAN := Rect2(-42.5, -99.0, 200.0, 196.0)
const VOID_OVERSCAN := Rect2(-12.0, -78.25, 136.0, 144.5)
const VOID_TILT_DEGREES := 2.0
const VOID_PIVOT := Vector2(80.0, 84.0)
const VOID_FRAME_COLUMNS := 6
const VOID_FRAME_ROWS := 6
const VOID_FRAME_COUNT := 36
const VOID_FRAME_RATE := 12.0
const VOID_ACTIVE_ALPHA := 0.82
const VOID_FADE_DURATION := 0.25
const VOID_ACTIVITY_LINGER_SECONDS := 2.5
# Include the doorway opening even where the gateway texture is transparent.
# The surrounding artwork uses its alpha mask for hover and click detection.
const PORTAL_HIT_RECT := Rect2(0.0, -55.0, 140.0, 115.0)
const VISUAL_SCALE := 0.67

class GatewayHitArea extends Control:
	var click_mask: BitMap
	var opening_rect: Rect2

	func contains_point(point: Vector2) -> bool:
		if opening_rect.has_point(point):
			return true
		if click_mask == null or size.x <= 0.0 or size.y <= 0.0:
			return false
		# Match the artwork's KEEP_ASPECT_CENTERED texture placement.
		var texture_size := Vector2(click_mask.get_size())
		var texture_scale := minf(size.x / texture_size.x, size.y / texture_size.y)
		var drawn_size := texture_size * texture_scale
		var drawn_origin := (size - drawn_size) * 0.5
		if not Rect2(drawn_origin, drawn_size).has_point(point):
			return false
		return click_mask.get_bitv(Vector2i((point - drawn_origin) / texture_scale))

	func _has_point(point: Vector2) -> bool:
		return contains_point(point)

static var _gateway_click_mask: BitMap = null

var count_label: Label = null
var _void_art: TextureRect = null
var _void_frames: Array[Texture2D] = []
var _void_frame_index := 0
var _void_frame_time := 0.0
var _void_hovered := false
var _void_activity_seconds_remaining := 0.0
var _click_catcher: GatewayHitArea = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(50, 48)
	# Scale every layer and its hit box together around the existing art centre.
	pivot_offset = ART_OVERSCAN.get_center() + size * 0.5
	scale = Vector2.ONE * VISUAL_SCALE
	_build_void_frames()

	add_child(_make_gateway_texture("AbyssGatewayBack", GATEWAY_TEXTURE))

	_void_art = TextureRect.new()
	_void_art.name = "AbyssGatewayVoid"
	_void_art.texture = _void_frames[0] if not _void_frames.is_empty() else VOID_SHEET_TEXTURE
	_void_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_void_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_void_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_void_art.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_void_art.visible = false
	_void_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_void_art.offset_left = VOID_OVERSCAN.position.x
	_void_art.offset_top = VOID_OVERSCAN.position.y
	_void_art.offset_right = VOID_OVERSCAN.position.x + VOID_OVERSCAN.size.x
	_void_art.offset_bottom = VOID_OVERSCAN.position.y + VOID_OVERSCAN.size.y
	_void_art.rotation_degrees = VOID_TILT_DEGREES
	_void_art.pivot_offset = VOID_PIVOT
	add_child(_void_art)

	add_child(_make_gateway_texture("AbyssGatewayForeground", GATEWAY_FOREGROUND_TEXTURE))

	if _gateway_click_mask == null:
		_gateway_click_mask = BitMap.new()
		_gateway_click_mask.create_from_image_alpha(GATEWAY_TEXTURE.get_image(), 0.05)
	_click_catcher = GatewayHitArea.new()
	_click_catcher.click_mask = _gateway_click_mask
	_click_catcher.opening_rect = Rect2(PORTAL_HIT_RECT.position - ART_OVERSCAN.position, PORTAL_HIT_RECT.size)
	_click_catcher.name = "AbyssGatewayClickCatcher"
	_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_click_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_click_catcher.offset_left = ART_OVERSCAN.position.x
	_click_catcher.offset_top = ART_OVERSCAN.position.y
	_click_catcher.offset_right = ART_OVERSCAN.position.x + ART_OVERSCAN.size.x
	_click_catcher.offset_bottom = ART_OVERSCAN.position.y + ART_OVERSCAN.size.y
	_click_catcher.gui_input.connect(_on_click_catcher_gui_input)
	add_child(_click_catcher)


func _on_click_catcher_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		portal_clicked.emit()


func _make_gateway_texture(node_name: String, texture: Texture2D) -> TextureRect:
	var art := TextureRect.new()
	art.name = node_name
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = ART_OVERSCAN.position.x
	art.offset_top = ART_OVERSCAN.position.y
	art.offset_right = ART_OVERSCAN.position.x + ART_OVERSCAN.size.x
	art.offset_bottom = ART_OVERSCAN.position.y + ART_OVERSCAN.size.y
	return art


func pulse_void_activity(linger_seconds: float = VOID_ACTIVITY_LINGER_SECONDS) -> void:
	_void_activity_seconds_remaining = maxf(_void_activity_seconds_remaining, linger_seconds)


func _void_wants_visible() -> bool:
	return _void_hovered or _void_activity_seconds_remaining > 0.0


func _update_hover_from_mouse() -> void:
	if not is_visible_in_tree():
		_void_hovered = false
		return
	var viewport := get_viewport()
	if viewport == null:
		_void_hovered = false
		return
	if _click_catcher == null:
		_void_hovered = false
		return
	var local_mouse := _click_catcher.get_global_transform().affine_inverse() * viewport.get_mouse_position()
	_void_hovered = _click_catcher.contains_point(local_mouse)


func _process(delta: float) -> void:
	_update_hover_from_mouse()
	if is_instance_valid(count_label):
		count_label.visible = _void_hovered
	if _void_art == null or _void_frames.is_empty():
		return
	_void_activity_seconds_remaining = maxf(0.0, _void_activity_seconds_remaining - delta)
	var target_alpha := VOID_ACTIVE_ALPHA if _void_wants_visible() else 0.0
	var alpha := _void_art.modulate.a
	if not is_equal_approx(alpha, target_alpha):
		alpha = move_toward(alpha, target_alpha, delta * VOID_ACTIVE_ALPHA / VOID_FADE_DURATION)
		_void_art.modulate.a = alpha
	_void_art.visible = alpha > 0.0 or target_alpha > 0.0
	if not _void_art.visible:
		return
	_void_frame_time += delta
	var frame_duration := 1.0 / VOID_FRAME_RATE
	while _void_frame_time >= frame_duration:
		_void_frame_time -= frame_duration
		_void_frame_index = (_void_frame_index + 1) % _void_frames.size()
		_void_art.texture = _void_frames[_void_frame_index]


func _build_void_frames() -> void:
	_void_frames = create_void_frames()


static func create_void_frames() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var frame_size := Vector2(
		float(VOID_SHEET_TEXTURE.get_width()) / float(VOID_FRAME_COLUMNS),
		float(VOID_SHEET_TEXTURE.get_height()) / float(VOID_FRAME_ROWS)
	)
	for frame_index in range(VOID_FRAME_COUNT):
		var column := frame_index % VOID_FRAME_COLUMNS
		var row := frame_index / VOID_FRAME_COLUMNS
		var frame := AtlasTexture.new()
		frame.atlas = VOID_SHEET_TEXTURE
		frame.region = Rect2(Vector2(float(column), float(row)) * frame_size, frame_size)
		frames.append(frame)
	return frames
