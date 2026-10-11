extends TextureRect

const AbyssGatewayIconScript = preload("res://scripts/ui/AbyssGatewayIcon.gd")
const SIZE_SCALE := 0.67
const DURATION_SCALE := 1.0 / 3.0

var _frames: Array[Texture2D] = []
var _elapsed := 0.0


func play(source_center: Vector2, source_size: Vector2) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_frames = AbyssGatewayIconScript.create_void_frames()
	texture = _frames[0]
	# Keep the smaller whorl round and centred on the departing card.
	var diameter := maxf(source_size.x, source_size.y) * 1.25 * SIZE_SCALE
	size = Vector2.ONE * diameter
	position = source_center - size * 0.5
	modulate.a = 0.0


func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_elapsed += delta
	var duration := AbyssGatewayIconScript.VOID_ACTIVITY_LINGER_SECONDS * DURATION_SCALE
	var fade_duration := AbyssGatewayIconScript.VOID_FADE_DURATION * DURATION_SCALE
	if _elapsed >= duration + fade_duration:
		queue_free()
		return
	var fade_in := clampf(_elapsed / fade_duration, 0.0, 1.0)
	var fade_out := clampf((duration + fade_duration - _elapsed) / fade_duration, 0.0, 1.0)
	modulate.a = minf(fade_in, fade_out) * AbyssGatewayIconScript.VOID_ACTIVE_ALPHA
	var frame_index := int(_elapsed * AbyssGatewayIconScript.VOID_FRAME_RATE) % _frames.size()
	texture = _frames[frame_index]
