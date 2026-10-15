extends Control
## Input and presentation only. The match controller owns all turn commands.

signal end_turn_requested

const MechanismScript := preload("res://quarantine/mechanical_turn_tower/scripts/TurnBellMechanism.gd")
const UIFontScript := preload("res://scripts/ui/UIFont.gd")
const DISPLAY_SIZE := Vector2(188.0, 248.0)
const PULL_PIXELS := 38.0
const PULL_THRESHOLD := 0.42

@export var ring_sound: AudioStream
@export var audio_bus: StringName = &"SFX"
@export_range(-40.0, 6.0, 0.5) var volume_db := -6.0
@export_range(0.2, 2.0, 0.05) var rotation_duration := 0.9

var _viewport: SubViewport
var _image: TextureRect
var _camera: Camera3D
var _mechanism
var _caption: Label
var _audio: AudioStreamPlayer
var _rotation_tween: Tween
var _owner_index := -1
var _viewer_index := -1
var _turn_number := -1
var _target_angle := 0.0
var _allowed := false
var _request_latched := false
var _request_saw_lock := false
var _dragging := false
var _touch_index := -1
var _drag_start := Vector2.ZERO
var _peak_pull := 0.0
var _pull := 0.0


func _ready() -> void:
	custom_minimum_size = DISPLAY_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_viewport()
	_audio = AudioStreamPlayer.new()
	_audio.name = "BellAudio"
	_audio.max_polyphony = 4
	add_child(_audio)
	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var caption_font: Font = UIFontScript.get_default_font()
	if caption_font != null:
		_caption.add_theme_font_override("font", caption_font)
	_caption.add_theme_font_size_override("font_size", 17)
	_caption.add_theme_color_override("font_color", Color("dec496"))
	_caption.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.95))
	_caption.add_theme_constant_override("outline_size", 3)
	add_child(_caption)
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	_layout()
	_refresh_interaction()


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "TowerViewport"
	_viewport.size = Vector2i(376, 452)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	_image = TextureRect.new()
	_image.name = "TowerImage"
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.texture = _viewport.get_texture()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_image)
	_mechanism = MechanismScript.new()
	_viewport.add_child(_mechanism)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 4.0
	_viewport.add_child(_camera)
	_camera.current = true
	_position_camera(0)
	var environment := WorldEnvironment.new()
	var lighting := Environment.new()
	lighting.background_mode = Environment.BG_COLOR
	lighting.background_color = Color(0.0, 0.0, 0.0, 0.0)
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = Color(0.76, 0.72, 0.62)
	lighting.ambient_light_energy = 0.70
	lighting.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = lighting
	_viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	key.light_color = Color(1.0, 0.85, 0.64)
	key.light_energy = 1.65
	key.shadow_enabled = true
	_viewport.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.0, 3.0, -3.0)
	fill.light_color = Color(0.66, 0.72, 0.65)
	fill.light_energy = 1.1
	fill.omni_range = 9.0
	_viewport.add_child(fill)


func _layout() -> void:
	if _image == null:
		return
	_image.position = Vector2.ZERO
	_image.size = Vector2(size.x, maxf(1.0, size.y - 22.0))
	_caption.position = Vector2(0.0, size.y - 22.0)
	_caption.size = Vector2(size.x, 22.0)
	# Match the viewport's projection to the displayed rectangle, at 2x resolution.
	_viewport.size = Vector2i(maxi(2, int(_image.size.x * 2.0)), maxi(2, int(_image.size.y * 2.0)))


func _position_camera(viewer: int) -> void:
	var side := -1.0 if viewer == 1 else 1.0
	_camera.position = Vector3(0.0, 8.7, side * 4.6)
	_camera.look_at(Vector3(0.0, 1.28, 0.0))


## Call with replicated turn state. Never rotate merely because a pull was attempted.
func set_turn_state(owner: int, viewer: int, turn: int, allowed: bool) -> void:
	if not is_node_ready():
		return
	if _viewer_index != viewer:
		_viewer_index = viewer
		_position_camera(viewer)
	if _owner_index < 0 or turn < _turn_number:
		if _rotation_tween != null:
			_rotation_tween.kill()
		_target_angle = PI * float(owner)
		_mechanism.casing.rotation.y = _target_angle
		clear_request()
	elif owner != _owner_index or turn != _turn_number:
		if _rotation_tween != null:
			_rotation_tween.kill()
		_target_angle += PI * float(maxi(1, turn - _turn_number))
		_rotation_tween = create_tween()
		_rotation_tween.tween_property(_mechanism.casing, "rotation:y", _target_angle, rotation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_rotation_tween.finished.connect(_refresh_interaction)
		clear_request()
	_owner_index = owner
	_turn_number = turn
	# A dismissed choice prompt may return control without advancing the turn.
	if _request_latched and not allowed:
		_request_saw_lock = true
	elif _request_latched and _request_saw_lock and allowed:
		clear_request()
	_allowed = allowed
	if not is_available() and _dragging:
		_cancel_pull()
	_refresh_interaction()


func is_rotating() -> bool:
	return _rotation_tween != null and _rotation_tween.is_running()


func get_casing_angle() -> float:
	return _mechanism.casing.rotation.y


func is_open_to_viewer() -> bool:
	return _owner_index >= 0 and _owner_index == _viewer_index and not is_rotating()


func is_available() -> bool:
	return is_visible_in_tree() and _allowed and is_open_to_viewer() and not _request_latched


func clear_request() -> void:
	_request_latched = false
	_request_saw_lock = false


func is_pulling() -> bool:
	return _dragging


func get_grip_position() -> Vector2:
	var projected := _camera.unproject_position(_mechanism.grip.global_position)
	return projected / Vector2(_viewport.size) * _image.size


func _pull_rect() -> Rect2:
	var grip := get_grip_position()
	return Rect2(grip - Vector2(31.0, 66.0), Vector2(62.0, 96.0))


func _has_point(point: Vector2) -> bool:
	return is_node_ready() and is_available() and _pull_rect().has_point(point)


func _gui_input(event: InputEvent) -> void:
	if not is_available():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_pull(event.position, -1)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_begin_pull(event.position, event.index)
		accept_event()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		_request_end_turn(1.0)
		accept_event()


func _input(event: InputEvent) -> void:
	if capture_pull_input(event):
		get_viewport().set_input_as_handled()


## The board also calls this before its own drag handlers, keeping releases reliable.
func capture_pull_input(event: InputEvent) -> bool:
	if not _dragging:
		return false
	if _touch_index < 0:
		if event is InputEventMouseMotion:
			_update_pull(_event_local(event.position))
			return true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_update_pull(_event_local(event.position))
			_finish_pull()
			return true
	else:
		if event is InputEventScreenDrag and event.index == _touch_index:
			_update_pull(_event_local(event.position))
			return true
		if event is InputEventScreenTouch and event.index == _touch_index and not event.pressed:
			_update_pull(_event_local(event.position))
			if event.canceled:
				_cancel_pull()
			else:
				_finish_pull()
			return true
	return false


func _event_local(position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * position


func _begin_pull(position: Vector2, touch: int) -> void:
	if _dragging:
		return
	grab_focus()
	_dragging = true
	_touch_index = touch
	_drag_start = position
	_peak_pull = 0.0
	_pull = 0.0


func _update_pull(position: Vector2) -> void:
	_pull = clampf((position.y - _drag_start.y) / PULL_PIXELS, 0.0, 1.0)
	_peak_pull = maxf(_peak_pull, _pull)
	_mechanism.set_pull(_pull)


func _finish_pull() -> void:
	var strength := _peak_pull
	_dragging = false
	_touch_index = -1
	if strength >= PULL_THRESHOLD:
		_request_end_turn(strength)


func _request_end_turn(strength: float) -> void:
	if not is_available():
		return
	_request_latched = true
	_mechanism.strike(strength)
	if ring_sound != null:
		if _audio.stream != ring_sound:
			_audio.stream = ring_sound
		_audio.bus = audio_bus if AudioServer.get_bus_index(audio_bus) >= 0 else &"Master"
		_audio.volume_db = volume_db
		_audio.play()
	_refresh_interaction()
	end_turn_requested.emit()


func _cancel_pull() -> void:
	_dragging = false
	_touch_index = -1
	_peak_pull = 0.0
	_pull = 0.0
	if is_node_ready():
		_mechanism.set_pull(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_pull()


func _on_visibility_changed() -> void:
	if not is_node_ready():
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if not is_visible_in_tree():
		_cancel_pull()
		clear_request()
		_owner_index = -1
		_turn_number = -1
		if _rotation_tween != null:
			_rotation_tween.kill()


func _process(delta: float) -> void:
	if not _dragging and _pull > 0.0:
		_pull = move_toward(_pull, 0.0, delta * 3.5)
		_mechanism.set_pull(_pull)
	_refresh_interaction()


func _refresh_interaction() -> void:
	var available := is_available()
	focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_DRAG if available else Control.CURSOR_ARROW
	if not available and has_focus():
		release_focus()
	if is_rotating():
		_caption.text = "Turning..."
	elif _owner_index != _viewer_index:
		_caption.text = "Opponent's Turn"
	elif available:
		_caption.text = "Pull to End Turn"
	else:
		_caption.text = "Turn Bell"
	tooltip_text = "Pull the rope down and release to end your turn.\nSpace or Enter also pulls the rope." if available else "The casing opens toward the active player. Resolve upkeep and pending choices before pulling."
