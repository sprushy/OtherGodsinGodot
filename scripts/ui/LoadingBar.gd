class_name LoadingBar
extends Control

const FRAME_TEXTURE_PATH := "res://images/ui/loading/mythic_loading_frame.png"
const FILL_TEXTURE_PATH := "res://images/ui/loading/mythic_loading_fill.png"
const TRACK_TEXTURE_PATH := "res://images/ui/loading/mythic_loading_track.png"
const DEFAULT_SIZE := Vector2(620.0, 86.0)
const FILL_RECT := Rect2(0.045, 0.29, 0.91, 0.45)

@export_range(0.0, 1.0) var progress: float = 0.0:
	set(value):
		_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
	get:
		return _progress

var _progress: float = 0.0
var _frame_texture: Texture2D = null
var _fill_texture: Texture2D = null
var _track_texture: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = DEFAULT_SIZE
	_frame_texture = _load_texture(FRAME_TEXTURE_PATH)
	_fill_texture = _load_texture(FILL_TEXTURE_PATH)
	_track_texture = _load_texture(TRACK_TEXTURE_PATH)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var bar_size := size
	if bar_size.x <= 1.0 or bar_size.y <= 1.0:
		return

	var fill_rect := Rect2(
		Vector2(bar_size.x * FILL_RECT.position.x, bar_size.y * FILL_RECT.position.y),
		Vector2(bar_size.x * FILL_RECT.size.x, bar_size.y * FILL_RECT.size.y)
	)
	if _track_texture != null:
		draw_texture_rect(_track_texture, fill_rect, false, Color(1.0, 1.0, 1.0, 0.26))
	else:
		draw_rect(fill_rect, Color(0.02, 0.08, 0.13, 0.72))

	var filled_width := fill_rect.size.x * _progress
	if _fill_texture != null and filled_width > 0.5:
		var source_width := _fill_texture.get_width() * _progress
		draw_texture_rect_region(
			_fill_texture,
			Rect2(fill_rect.position, Vector2(filled_width, fill_rect.size.y)),
			Rect2(Vector2.ZERO, Vector2(source_width, _fill_texture.get_height()))
		)

	if _frame_texture != null:
		draw_texture_rect(_frame_texture, Rect2(Vector2.ZERO, bar_size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, bar_size), Color(0.57, 0.43, 0.28), false, 2.0)

func _load_texture(path: String) -> Texture2D:
	var loaded := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	if loaded != null:
		return loaded
	var bytes := PackedByteArray()
	if FileAccess.file_exists(path):
		bytes = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		var global_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_path):
			bytes = FileAccess.get_file_as_bytes(global_path)
	if bytes.size() < 8:
		return null
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 \
			and bytes[1] == 0x50 \
			and bytes[2] == 0x4E \
			and bytes[3] == 0x47:
		err = image.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = image.load_jpg_from_buffer(bytes)
	if err != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
