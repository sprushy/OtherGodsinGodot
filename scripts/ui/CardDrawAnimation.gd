extends Control

signal landed

const CARD_BACK := preload("res://images/cardbackAI.png")
const GOLD := Color(0.97, 0.79, 0.43)

var _flight: Control
var _face: Control
var _face_size: Vector2
var _back: TextureRect
var _flight_halo: StyleBoxFlat
var _arrival_rim: StyleBoxFlat
var _target_geometry: Callable
var _source_center: Vector2
var _source_size: Vector2
var _source_rotation: float
var _progress: float = 0.0
var _burst: float = 0.0
var _has_landed: bool = false
var _trail: Array[Vector2] = []
var _tween: Tween
var _reveal_from_back: bool = true
var _delay: float = 0.0

func play(card: Card, source_center: Vector2, source_size: Vector2, source_rotation: float, target_geometry: Callable, display_mana_cost: int = -1, cost_lines: Array[String] = [], reveal_from_back: bool = true, delay: float = 0.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_source_center = source_center
	_source_size = source_size
	_source_rotation = source_rotation
	_target_geometry = target_geometry
	_reveal_from_back = reveal_from_back
	_delay = delay
	_flight = Control.new()
	_flight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flight)
	_face = _create_card_face(card, display_mana_cost, cost_lines)
	_flight.add_child(_face)
	# The opaque back covers the face while it lays out and renders once,
	# so revealing it does not trigger its first text/art draw mid-flight.
	_back = TextureRect.new()
	_back.texture = CARD_BACK
	_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back.stretch_mode = TextureRect.STRETCH_SCALE
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flight.add_child(_back)
	_ignore_child_input(_flight)
	_flight_halo = StyleBoxFlat.new()
	_flight_halo.bg_color = Color(0.0, 0.0, 0.0, 0.08)
	_flight_halo.set_border_width_all(2)
	_flight_halo.set_corner_radius_all(7)
	_flight_halo.shadow_color = Color(GOLD, 0.23)
	_flight_halo.shadow_size = 20
	_flight_halo.shadow_offset = Vector2(0.0, 6.0)
	_arrival_rim = StyleBoxFlat.new()
	_arrival_rim.bg_color = Color.TRANSPARENT
	_arrival_rim.set_border_width_all(2)
	_arrival_rim.set_corner_radius_all(6)
	_arrival_rim.shadow_size = 12
	_sync_flight_size()
	_set_progress(0.0)
	_begin_flight()

func _create_card_face(card: Card, display_mana_cost: int, cost_lines: Array[String]) -> Control:
	var face := VisualCard.new()
	face.set_hand_mode(true)
	# Animation faces retain art, name, cost and stats without the effect
	# paragraph. Normal cards and their hover details remain complete.
	face.set_show_rules_text(false)
	face.setup(card, 180, 0, display_mana_cost, cost_lines)
	face.set_disabled(true, false)
	return face

func _sync_flight_size() -> void:
	_face_size = _face.get_combined_minimum_size()
	_face.size = _face_size
	_flight.size = _face_size
	_flight.pivot_offset = _face_size * 0.5
	_back.size = _face_size

func _begin_flight() -> void:
	# Hand and board rebuilding still run after play() in the UI refresh.
	# Finish that work and the deferred container layout before moving.
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_sync_flight_size()
	_set_progress(0.0)
	if is_queued_for_deletion():
		return
	_tween = create_tween()
	if _delay > 0.0:
		_flight.visible = false
		_tween.tween_interval(_delay)
		_tween.tween_callback(_flight.show)
	_tween.tween_method(_set_progress, 0.0, 1.0, 1.32)
	_tween.tween_callback(_land)
	_tween.tween_method(_set_burst, 0.0, 1.0, 0.48)
	_tween.tween_callback(queue_free)

func cancel() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	queue_free()

func _ignore_child_input(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_child_input(child)

func _set_progress(value: float) -> void:
	_progress = value
	var target: Dictionary = _target_geometry.call()
	if target.is_empty():
		_land()
		cancel()
		return
	# Fit the reveal above the hand, even in a short window or for a tall card.
	var face_size := _face_size
	var preview_scale := minf(1.18, (size.y * 0.58) / maxf(1.0, face_size.y))
	var half_reveal := face_size * preview_scale * 0.5
	var reveal_center := Vector2(
		clampf(_source_center.x + 225.0, half_reveal.x + 24.0, size.x - half_reveal.x - 24.0),
		clampf(_source_center.y - 85.0, half_reveal.y + 24.0, size.y - half_reveal.y - 145.0)
	)
	var destination: Vector2 = target["center"]
	var destination_size: Vector2 = target["size"]
	var destination_rotation: float = target["rotation"]
	var center := reveal_center
	var card_scale := Vector2.ONE * preview_scale
	var angle := 0.0
	# Reveal the compact face as the card flips past its edge.
	_back.visible = _reveal_from_back and value < 0.365
	_back.modulate.a = 1.0
	if value < 0.25:
		var lift := _ease_out_cubic(value / 0.25)
		center = _source_center.lerp(reveal_center, lift)
		center.y -= sin(lift * PI) * 38.0
		card_scale = (_source_size / face_size).lerp(Vector2.ONE * preview_scale, lift)
		angle = lerpf(_source_rotation, deg_to_rad(7.0), lift)
	elif value < 0.48:
		var flip := (value - 0.25) / 0.23
		if _reveal_from_back:
			card_scale.x *= maxf(0.025, absf(cos(flip * PI)))
		angle = lerpf(deg_to_rad(7.0), 0.0, flip)
	elif value >= 0.65:
		var travel := _ease_in_out_cubic((value - 0.65) / 0.35)
		var bend := Vector2(reveal_center.x + 100.0, minf(reveal_center.y, destination.y) - 65.0)
		center = reveal_center.lerp(bend, travel).lerp(bend.lerp(destination, travel), travel)
		card_scale = (Vector2.ONE * preview_scale).lerp(destination_size / face_size, travel)
		angle = lerpf(0.0, destination_rotation, travel)
	_flight.position = center - face_size * 0.5
	_flight.scale = card_scale
	_flight.rotation = angle
	if _trail.is_empty() or _trail.back().distance_to(center) > 3.0:
		_trail.append(center)
		if _trail.size() > 18:
			_trail.pop_front()
	queue_redraw()

func _land() -> void:
	if _has_landed:
		return
	_has_landed = true
	_flight.visible = false
	landed.emit()
	queue_redraw()

func _set_burst(value: float) -> void:
	_burst = value
	queue_redraw()

func _draw() -> void:
	if _flight == null:
		return
	if not _has_landed and not _flight.visible:
		return
	if not _has_landed:
		for i in range(1, _trail.size()):
			var alpha := float(i) / float(_trail.size()) * 0.24
			draw_line(_trail[i - 1], _trail[i], Color(GOLD, alpha), 1.0 + float(i) * 0.22, true)
		var center := _flight.position + _flight.pivot_offset
		draw_set_transform(center, _flight.rotation, _flight.scale)
		_flight_halo.border_color = Color(GOLD, 0.45 + sin(_progress * PI) * 0.4)
		draw_style_box(_flight_halo, Rect2(-_flight.size * 0.5, _flight.size).grow(3.0))
		draw_set_transform(Vector2.ZERO)
	else:
		var target: Dictionary = _target_geometry.call()
		if target.is_empty():
			return
		var card_size: Vector2 = target["size"]
		var center: Vector2 = target["center"]
		var top := center - Vector2(0.0, card_size.y * 0.5)
		var fade := 1.0 - _burst
		# Keep the arrival effect at the exposed top edge of the hand card.
		for i in range(12):
			var angle := PI + float(i) * PI / 11.0
			var direction := Vector2(cos(angle), sin(angle))
			var point := top + direction * (16.0 + _burst * 58.0)
			draw_line(point - direction * (3.0 + fade * 5.0), point + direction * 3.0, Color(GOLD, fade), 1.6, true)
		draw_set_transform(center, float(target["rotation"]))
		_arrival_rim.border_color = Color(GOLD, fade)
		_arrival_rim.shadow_color = Color(GOLD, fade * 0.35)
		draw_style_box(_arrival_rim, Rect2(-card_size * 0.5, card_size).grow(2.0 + _burst * 5.0))
		draw_set_transform(Vector2.ZERO)
		var font := get_theme_default_font()
		var caption := "+1 to hand"
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string_outline(font, top + Vector2(-width * 0.5, -18.0 - _burst * 18.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 5, Color(0.03, 0.035, 0.04, fade))
		draw_string(font, top + Vector2(-width * 0.5, -18.0 - _burst * 18.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1.0, 0.91, 0.67, fade))

func _ease_out_cubic(value: float) -> float:
	return 1.0 - pow(1.0 - value, 3.0)

func _ease_in_out_cubic(value: float) -> float:
	return 4.0 * value * value * value if value < 0.5 else 1.0 - pow(-2.0 * value + 2.0, 3.0) * 0.5
