extends Control

const SHOVEL_TEXTURE := preload("res://images/ui/zones/grave_tumulus_shovel.png")
const SHOVEL_RECT := Rect2(0.106, 0.235, 0.205, 0.284)
const SHOVEL_PIVOT := Vector2(0.265, 0.505)
const SHIFT_ANGLE := 0.105
const MOVE_SECONDS := 0.24
const DIRT_SECONDS := 0.6
const VISUAL_SCALE := 1.75
const COUNT_CHANGE_DISPLAY_MSEC := 2500

var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
var count_label: Label
var _count_visible_until_msec := 0
var shifted := false
var _angle := 0.0
var _from_angle := 0.0
var _target_angle := 0.0
var _move_time := MOVE_SECONDS
var _dirt: Array[Dictionary] = []
var _shovel_region := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_shovel_region = Rect2(SHOVEL_TEXTURE.get_image().get_used_rect())
	resized.connect(queue_redraw)

func _has_point(point: Vector2) -> bool:
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return false
	var centered := (point - size * 0.5) / (Vector2(0.46, 0.42) * side)
	return centered.length_squared() <= 1.0

func set_grave_count(count: int) -> void:
	if not is_instance_valid(count_label):
		return
	var next_text := str(count)
	if count_label.text == next_text:
		return
	count_label.text = next_text
	_count_visible_until_msec = Time.get_ticks_msec() + COUNT_CHANGE_DISPLAY_MSEC
	_update_count_visibility()

func _update_count_visibility() -> void:
	if not is_instance_valid(count_label):
		return
	var hovered := is_visible_in_tree() and _has_point(get_local_mouse_position())
	var remaining_msec := _count_visible_until_msec - Time.get_ticks_msec()
	count_label.visible = hovered or remaining_msec > 0
	count_label.modulate.a = 1.0 if hovered else clampf(float(remaining_msec) / 300.0, 0.0, 1.0)

func set_shifted(value: bool, animate: bool = false) -> void:
	shifted = value
	_target_angle = SHIFT_ANGLE if shifted else 0.0
	if not animate:
		_angle = _target_angle
		_move_time = MOVE_SECONDS
		queue_redraw()
		return
	_from_angle = _angle
	_move_time = 0.0
	# Each click sheds a fresh burst, including the return to the resting pose.
	for _i in range(9):
		_dirt.append({
			"age": 0.0,
			"offset": Vector2(randf_range(-0.016, 0.016), randf_range(-0.014, 0.006)),
			"velocity": Vector2(randf_range(-0.13, 0.13), randf_range(-0.17, -0.06)),
			"radius": randf_range(0.007, 0.013),
			"color": Color(0.25, 0.16, 0.08).lightened(randf_range(0.0, 0.2)),
		})
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_update_count_visibility()
	if _move_time >= MOVE_SECONDS and _dirt.is_empty():
		return
	_move_time = minf(_move_time + delta, MOVE_SECONDS)
	var progress := _move_time / MOVE_SECONDS
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	_angle = lerpf(_from_angle, _target_angle, eased)
	_angle += sin(progress * TAU * 2.0) * 0.025 * (1.0 - progress)
	for i in range(_dirt.size() - 1, -1, -1):
		_dirt[i]["age"] += delta
		if float(_dirt[i]["age"]) >= DIRT_SECONDS:
			_dirt.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if texture == null:
		return
	var side := minf(size.x, size.y)
	var origin := (size - Vector2.ONE * side) * 0.5
	draw_texture_rect(texture, Rect2(origin, Vector2.ONE * side), false)
	var pivot := origin + SHOVEL_PIVOT * side
	draw_set_transform(pivot, _angle)
	if _shovel_region.has_area():
		draw_texture_rect_region(SHOVEL_TEXTURE, Rect2((SHOVEL_RECT.position - SHOVEL_PIVOT) * side, SHOVEL_RECT.size * side), _shovel_region)
	draw_set_transform(Vector2.ZERO)
	for speck in _dirt:
		var age: float = speck["age"]
		var offset: Vector2 = speck["offset"]
		var velocity: Vector2 = speck["velocity"]
		var speck_position := pivot + (offset + velocity * age + Vector2(0.0, 0.38 * age * age)) * side
		var color: Color = speck["color"]
		color.a *= 1.0 - age / DIRT_SECONDS
		draw_circle(speck_position, maxf(0.5, float(speck["radius"]) * side), color)
