extends Control
## Reusable 2.5D prop. Pull the rope down and release to ring; no gameplay commands.

signal rang(strength: float)
signal pull_started
signal pull_released(strength: float)

const BELL_TEXTURE := preload("res://quarantine/town_bell/art/town_bell.png")
const DESIGN_SIZE := Vector2(320.0, 360.0)
const BELL_RECT := Rect2(24.0, 12.0, 256.0, 256.0)
const PIVOT := Vector2(152.0, 35.0)
const ROPE_REST := Vector2(274.0, 264.0)
const PULL_DISTANCE := 62.0

@export var ring_sound: AudioStream
@export var audio_bus: StringName = &"SFX"
@export_range(-40.0, 6.0, 0.5) var volume_db: float = -6.0
@export_range(0.1, 1.0, 0.05) var ring_threshold: float = 0.3
@export_range(0.1, 3.0, 0.05) var ring_cooldown: float = 0.65
@export_range(1.0, 18.0, 0.5) var swing_degrees: float = 9.0
@export var disabled: bool = false:
	set(value):
		disabled = value
		if disabled:
			if _dragging:
				_cancel_pull()
			if has_focus():
				release_focus()
		focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
		self_modulate = Color(0.6, 0.6, 0.6) if disabled else Color.WHITE
		mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
		queue_redraw()

var _audio: AudioStreamPlayer
var _dragging := false
var _touch_index := -1
var _drag_origin := Vector2.ZERO
var _drag_initial_pull := 0.0
var _peak_pull := 0.0
var _pull := 0.0
var _swing_time := 10.0
var _swing_strength := 0.0
var _cooldown := 0.0
var _hovered := false


func _init() -> void:
	custom_minimum_size = DESIGN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Pull the rope down and release to ring.\nKeyboard: focus, then press Space or Enter."
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	_audio.name = "BellAudio"
	_audio.max_polyphony = 4
	add_child(_audio)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)
	visibility_changed.connect(_on_visibility_changed)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if not _dragging and _pull > 0.0:
		_pull = move_toward(_pull, 0.0, delta * 3.0)
		queue_redraw()
	if _swing_time < 3.0:
		_swing_time += delta
		queue_redraw()


## Public audio/animation hook. Returns false while disabled, hidden, or cooling down.
func ring(strength: float = 1.0) -> bool:
	if disabled or not is_visible_in_tree() or not is_node_ready() or _cooldown > 0.0:
		return false
	var amount := clampf(strength, 0.1, 1.0)
	_swing_time = 0.0
	_swing_strength = amount
	_cooldown = ring_cooldown
	if ring_sound != null:
		if _audio.stream != ring_sound:
			_audio.stream = ring_sound
		_audio.bus = audio_bus if AudioServer.get_bus_index(audio_bus) >= 0 else &"Master"
		_audio.volume_db = volume_db + linear_to_db(lerpf(0.55, 1.0, amount))
		_audio.play()
	rang.emit(amount)
	queue_redraw()
	return true


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_pull(_local_to_design(event.position), -1)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_begin_pull(_local_to_design(event.position), event.index)
		accept_event()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		if ring():
			_pull = 0.8
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	# Capture release even when the pointer has moved outside the control.
	if _touch_index < 0:
		if event is InputEventMouseMotion:
			_update_pull(_screen_to_design(event.position))
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_update_pull(_screen_to_design(event.position))
			_release_pull()
			get_viewport().set_input_as_handled()
	else:
		if event is InputEventScreenDrag and event.index == _touch_index:
			_update_pull(_screen_to_design(event.position))
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenTouch and event.index == _touch_index and not event.pressed:
			_update_pull(_screen_to_design(event.position))
			if event.canceled:
				_cancel_pull()
			else:
				_release_pull()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_pull()


func _has_point(point: Vector2) -> bool:
	if disabled:
		return false
	var local := _local_to_design(point)
	var end := _rope_end()
	# Transparent art margins and the bell body let board input pass through.
	return local.distance_to(end) <= 25.0 or Rect2(end.x - 15.0, end.y - 70.0, 30.0, 70.0).has_point(local)


func _begin_pull(point: Vector2, touch_index: int) -> void:
	if _dragging:
		return
	grab_focus()
	_dragging = true
	_touch_index = touch_index
	_drag_origin = point
	_drag_initial_pull = _pull
	_peak_pull = 0.0
	pull_started.emit()
	queue_redraw()


func _update_pull(point: Vector2) -> void:
	_pull = clampf(_drag_initial_pull + (point.y - _drag_origin.y) / PULL_DISTANCE, 0.0, 1.0)
	_peak_pull = maxf(_peak_pull, _pull)
	queue_redraw()


func _release_pull() -> void:
	var strength := _peak_pull
	_dragging = false
	_touch_index = -1
	if strength >= ring_threshold:
		ring(strength)
	pull_released.emit(strength)
	queue_redraw()


func _cancel_pull() -> void:
	_dragging = false
	_touch_index = -1
	_peak_pull = 0.0
	_pull = 0.0
	queue_redraw()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_cancel_pull()


func _set_hovered(value: bool) -> void:
	_hovered = value
	queue_redraw()


func _design_scale() -> float:
	return maxf(0.001, minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y))


func _design_origin() -> Vector2:
	return (size - DESIGN_SIZE * _design_scale()) * 0.5


func _local_to_design(point: Vector2) -> Vector2:
	return (point - _design_origin()) / _design_scale()


func _screen_to_design(point: Vector2) -> Vector2:
	return _local_to_design(get_global_transform_with_canvas().affine_inverse() * point)


func _swing_angle() -> float:
	return deg_to_rad(swing_degrees) * _swing_strength * sin(_swing_time * 11.0) * exp(-_swing_time * 2.4)


func _rope_end() -> Vector2:
	var sway := sin(_swing_time * 11.0) * exp(-_swing_time * 2.4) * _swing_strength * 7.0
	return ROPE_REST + Vector2(sway, _pull * PULL_DISTANCE)


func _draw() -> void:
	var zoom := _design_scale()
	var origin := _design_origin()
	var angle := _swing_angle() - deg_to_rad(3.0) * _pull
	draw_set_transform(origin, 0.0, Vector2.ONE * zoom)
	_draw_mount()
	# Draw from the crown pivot, with a soft offset shadow under the bronze.
	draw_set_transform(origin + (PIVOT + Vector2(4.0, 7.0)) * zoom, angle, Vector2.ONE * zoom)
	draw_texture_rect(BELL_TEXTURE, Rect2(BELL_RECT.position - PIVOT, BELL_RECT.size), false, Color(0.02, 0.015, 0.01, 0.25))
	draw_set_transform(origin + PIVOT * zoom, angle, Vector2.ONE * zoom)
	draw_texture_rect(BELL_TEXTURE, Rect2(BELL_RECT.position - PIVOT, BELL_RECT.size), false)
	draw_set_transform(origin, 0.0, Vector2.ONE * zoom)
	_draw_rope()
	draw_set_transform(Vector2.ZERO)


func _draw_mount() -> void:
	# The crown hangs on a pinned oak yoke; a side pulley guides the pull rope.
	for x in [47.0, 268.0]:
		draw_style_box(_mount_style(Color("251c16"), Color("49382a")), Rect2(x - 10.0, 22.0, 20.0, 112.0))
		draw_line(Vector2(x - 4.0, 33.0), Vector2(x - 4.0, 126.0), Color("68503a"), 2.0, true)
	var beam := Rect2(32.0, 19.0, 253.0, 24.0)
	draw_style_box(_mount_style(Color("463323"), Color("876344")), beam)
	draw_line(Vector2(37.0, 24.0), Vector2(281.0, 24.0), Color("a27b4e"), 2.0, true)
	for x in [47.0, 152.0, 268.0]:
		draw_style_box(_mount_style(Color("302f2a"), Color("74664a")), Rect2(x - 7.0, 18.0, 14.0, 28.0))
		draw_circle(Vector2(x, 25.0), 2.5, Color("b29a66"))
		draw_circle(Vector2(x, 39.0), 2.5, Color("b29a66"))
	# An iron arm holds the pulley beside the bell, clear of its swinging lip.
	draw_line(Vector2(268.0, 38.0), Vector2(274.0, 66.0), Color("383630"), 7.0, true)
	draw_circle(Vector2(265.0, 66.0), 11.0, Color("292721"))
	draw_arc(Vector2(265.0, 66.0), 9.0, 0.0, TAU, 32, Color("b69a61"), 3.0, true)
	draw_circle(Vector2(265.0, 66.0), 3.0, Color("c8af76"))


func _mount_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


func _draw_rope() -> void:
	var end := _rope_end()
	var curve := Curve2D.new()
	curve.bake_interval = 3.0
	curve.add_point(PIVOT + Vector2(0.0, 4.0), Vector2.ZERO, Vector2(50.0, -8.0))
	curve.add_point(Vector2(265.0, 56.0), Vector2(-24.0, 0.0), Vector2(6.0, 0.0))
	curve.add_point(Vector2(275.0, 68.0), Vector2(0.0, -6.0), Vector2(0.0, 45.0))
	curve.add_point(end, Vector2(0.0, -45.0))
	var points := curve.get_baked_points()
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(2.0, 3.0))
	draw_polyline(shadow, Color(0.02, 0.012, 0.006, 0.4), 7.0, true)
	draw_polyline(points, Color("342319"), 6.0, true)
	draw_polyline(points, Color("977348"), 4.0, true)
	# Diagonal fibers follow the curved rope instead of stretching a flat image.
	var length := curve.get_baked_length()
	for step in range(2, int(length / 5.0)):
		var distance := float(step) * 5.0
		var point := curve.sample_baked(distance)
		var tangent := (curve.sample_baked(minf(distance + 1.0, length)) - point).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		draw_line(point - normal * 1.8 - tangent, point + normal * 1.8 + tangent, Color("cfad74"), 1.0, true)
	# Small bronze collar, binding knots, and a dark wooden hand grip.
	draw_circle(PIVOT + Vector2(0.0, 4.0), 5.0, Color("55402a"))
	draw_arc(PIVOT + Vector2(0.0, 4.0), 4.0, 0.0, TAU, 20, Color("cfaa69"), 1.5, true)
	var grip_color := Color("9b7046") if _hovered or _dragging else Color("715034")
	draw_line(end + Vector2(-14.0, 3.0), end + Vector2(16.0, 3.0), Color(0.02, 0.01, 0.0, 0.5), 11.0, true)
	draw_line(end - Vector2(15.0, 0.0), end + Vector2(15.0, 0.0), Color("302119"), 12.0, true)
	draw_line(end - Vector2(14.0, 1.0), end + Vector2(14.0, -1.0), grip_color, 8.0, true)
	draw_line(end - Vector2(12.0, 3.0), end + Vector2(12.0, -3.0), Color("c49960"), 1.0, true)
	for offset in [-10.0, 0.0, 10.0]:
		draw_line(end + Vector2(offset, -5.0), end + Vector2(offset, 4.0), Color("c1a06a"), 2.0, true)
	if has_focus() and not disabled:
		draw_arc(end, 23.0, 0.0, TAU, 48, Color(0.83, 0.69, 0.43, 0.8), 1.5, true)
