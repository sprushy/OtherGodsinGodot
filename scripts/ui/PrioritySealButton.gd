extends BaseButton

## A compact, engraved seal docked beside the turn controls.
const SEAL_SIZE := Vector2(96.0, 90.0)
const GOLD := Color(0.86, 0.67, 0.34)
const PALE_GOLD := Color(1.0, 0.89, 0.62)
const TITLE_FONT = preload("res://fonts/custom_ui/Norsebold.otf")

var has_responses := true
var _pulse_time := 0.0

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	accessibility_name = "Pass Priority"
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	visibility_changed.connect(_sync_animation)
	resized.connect(queue_redraw)
	_sync_animation()

func _get_minimum_size() -> Vector2:
	return SEAL_SIZE

func _sync_animation() -> void:
	set_process(is_visible_in_tree())
	if is_visible_in_tree():
		_pulse_time = 0.0
		queue_redraw()

func _process(delta: float) -> void:
	_pulse_time = fmod(_pulse_time + delta * 1.6, TAU)
	queue_redraw()

func _outline(inset: float = 0.0) -> PackedVector2Array:
	var rect := Rect2(Vector2.ZERO, size).grow(-inset)
	var cut := 12.0
	return PackedVector2Array([
		rect.position + Vector2(cut, 0.0), Vector2(rect.end.x - cut, rect.position.y),
		Vector2(rect.end.x, rect.position.y + cut), rect.end - Vector2(0.0, cut),
		rect.end - Vector2(cut, 0.0), Vector2(rect.position.x + cut, rect.end.y),
		Vector2(rect.position.x, rect.end.y - cut), rect.position + Vector2(0.0, cut),
	])

func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _outline())

func _draw() -> void:
	var hovered := is_hovered() or has_focus()
	var pressed := is_pressed()
	var pulse := 0.5 + 0.5 * sin(_pulse_time)
	var accent := PALE_GOLD if hovered else GOLD
	var center := Vector2(size.x * 0.5, 28.0)
	var polygon := _outline(3.0)
	var edge := polygon.duplicate()
	edge.append(edge[0])
	# A shadow and layered rim keep the lettering legible over any board art.
	var shadow := _outline()
	for i in shadow.size():
		shadow[i] += Vector2(0.0, 3.0)
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.45))
	draw_colored_polygon(polygon, Color(0.075, 0.058, 0.040, 0.98) if pressed else Color(0.13, 0.105, 0.075, 0.98))
	draw_polyline(edge, Color(accent, 0.12 + pulse * 0.10), 7.0, true)
	draw_polyline(edge, accent, 1.4 if not hovered else 2.0, true)
	var inner := _outline(7.0)
	inner.append(inner[0])
	draw_polyline(inner, Color(GOLD, 0.30), 1.0, true)

	# The hourglass is surrounded by an illuminated ritual ring and tally marks.
	draw_circle(center, 21.0, Color(GOLD, 0.045 + pulse * 0.055))
	draw_arc(center, 20.0, 0.0, TAU, 64, Color(accent, 0.75), 1.0, true)
	draw_arc(center, 23.0, PI * 0.12, PI * 0.88, 24, Color(accent, 0.35 + pulse * 0.35), 1.0, true)
	draw_arc(center, 23.0, PI * 1.12, PI * 1.88, 24, Color(accent, 0.35 + pulse * 0.35), 1.0, true)
	for i in 12:
		var direction := Vector2.from_angle(float(i) * TAU / 12.0)
		draw_line(center + direction * 17.0, center + direction * 18.5, Color(GOLD, 0.7), 1.0, true)
	var glass := PackedVector2Array([
		center + Vector2(-7.0, -10.0), center + Vector2(7.0, -10.0),
		center + Vector2(6.0, -5.0), center, center + Vector2(6.0, 5.0),
		center + Vector2(7.0, 10.0), center + Vector2(-7.0, 10.0),
		center + Vector2(-6.0, 5.0), center, center + Vector2(-6.0, -5.0),
		center + Vector2(-7.0, -10.0),
	])
	draw_polyline(glass, accent, 1.5, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, 3.0), center + Vector2(4.0, 7.0), center + Vector2(-4.0, 7.0),
	]), PALE_GOLD)
	_draw_caption("PASS", 64.0, TITLE_FONT, 17, PALE_GOLD)
	_draw_caption("PRIORITY", 80.0, TITLE_FONT, 17, PALE_GOLD)

func _draw_caption(value: String, baseline: float, font: Font, font_size: int, color: Color) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
