extends "res://scripts/ui/CardDrawAnimation.gd"

var _from_deck: bool = false
var _held: bool = false
var _flight_ready: bool = false
var _immediate_departure: bool = false
var _tumble_turns: float = 0.0

func set_held_pose(center: Vector2, art_size: Vector2, angle: float) -> void:
	if not _held or _flight == null:
		return
	_source_center = center
	_source_size = art_size
	_source_rotation = angle
	_flight.position = center - _face_size * 0.5
	_flight.scale = art_size / _face_size
	_flight.rotation = angle
	queue_redraw()

func set_tumble(turns: float) -> void:
	_tumble_turns = turns

func _create_card_face(card: Card, _display_mana_cost: int, _cost_lines: Array[String]) -> Control:
	var art := TextureRect.new()
	art.texture = UITextureCache.get_texture(card.art_path)
	if art.texture == null:
		art.texture = CARD_BACK
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	art.custom_minimum_size = _source_size
	return art

func play_grave(card: Card, source: Dictionary, target_geometry: Callable, delay: float = 0.0, hold: bool = false) -> void:
	_from_deck = bool(source.get("from_deck", false))
	_held = hold
	super.play(card, source["center"], source["size"], float(source["rotation"]), target_geometry, -1, [], false, delay)
	_flight.visible = _held or delay <= 0.0

func release(begin_travel_immediately: bool = false) -> void:
	_held = false
	_immediate_departure = begin_travel_immediately
	if _flight_ready:
		_start_flight()

func _begin_flight() -> void:
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_sync_flight_size()
	_set_progress(0.0)
	if is_queued_for_deletion():
		return
	_flight_ready = true
	if not _held:
		_start_flight()

func _start_flight() -> void:
	if _tween != null or is_queued_for_deletion():
		return
	_tween = create_tween()
	if _delay > 0.0:
		_tween.tween_interval(_delay)
		_tween.tween_callback(_flight.show)
	_tween.tween_method(_set_progress, 0.0, 1.0, 0.95)
	_tween.tween_callback(queue_free)

func _set_progress(value: float) -> void:
	_progress = value
	var target: Dictionary = _target_geometry.call()
	if target.is_empty():
		cancel()
		return
	# Milled cards move immediately so successive launches stay distinct.
	# Other grave transitions darken in place before leaving the field.
	var darkness := smoothstep(0.0, 0.28, value)
	_face.modulate = Color.WHITE.lerp(Color(0.18, 0.18, 0.21), darkness)
	_back.visible = false
	var travel := value if _immediate_departure else _ease_in_out_cubic(value if _from_deck else clampf((value - 0.24) / 0.76, 0.0, 1.0))
	var destination: Vector2 = target["center"]
	var destination_size: Vector2 = target["size"]
	var bend := Vector2((_source_center.x + destination.x) * 0.5, minf(_source_center.y, destination.y) - 55.0)
	var center := _source_center.lerp(bend, travel).lerp(bend.lerp(destination, travel), travel)
	_flight.position = center - _face_size * 0.5
	var arrival_scale := minf(destination_size.x / _face_size.x, destination_size.y / _face_size.y)
	var launch_scale := minf(_source_size.x / _face_size.x, _source_size.y / _face_size.y)
	_flight.scale = Vector2.ONE * lerpf(launch_scale, arrival_scale, travel)
	_flight.rotation = lerpf(_source_rotation, float(target["rotation"]), travel)
	if not is_zero_approx(_tumble_turns):
		_flight.rotation += _tumble_turns * TAU * travel
		_flight.position.y -= sin(travel * PI) * _source_size.y * 0.22
	_flight.modulate.a = 1.0 - smoothstep(0.78, 1.0, value)
	if _trail.is_empty() or _trail.back().distance_to(center) > 3.0:
		_trail.append(center)
		if _trail.size() > 18:
			_trail.pop_front()
	queue_redraw()

func _draw() -> void:
	if _flight == null or not _flight.visible:
		return
	for i in range(1, _trail.size()):
		var alpha := float(i) / float(_trail.size()) * 0.28 * (1.0 - smoothstep(0.78, 1.0, _progress))
		draw_line(_trail[i - 1], _trail[i], Color(0.12, 0.13, 0.17, alpha), 1.0 + float(i) * 0.25, true)
