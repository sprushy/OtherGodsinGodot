class_name AbyssGatewayIcon
extends Control

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

var _void_art: TextureRect = null
var _void_frames: Array[Texture2D] = []
var _void_frame_index := 0
var _void_frame_time := 0.0
var _void_hovered := false
var _void_activity_seconds_remaining := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(50, 48)
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


func set_void_hover(active: bool) -> void:
	_void_hovered = active


func pulse_void_activity(linger_seconds: float = VOID_ACTIVITY_LINGER_SECONDS) -> void:
	_void_activity_seconds_remaining = maxf(_void_activity_seconds_remaining, linger_seconds)


func _void_wants_visible() -> bool:
	return _void_hovered or _void_activity_seconds_remaining > 0.0


func _process(delta: float) -> void:
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
	_void_frames.clear()
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
		_void_frames.append(frame)
