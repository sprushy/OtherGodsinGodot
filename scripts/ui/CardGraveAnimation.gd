extends "res://scripts/ui/CardDrawAnimation.gd"

var _from_deck: bool = false

func play_grave(card: Card, source: Dictionary, target_geometry: Callable, delay: float = 0.0) -> void:
	_from_deck = bool(source.get("from_deck", false))
	super.play(card, source["center"], source["size"], float(source["rotation"]), target_geometry, -1, [], false, delay)
	_flight.visible = delay <= 0.0

func _begin_flight() -> void:
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_sync_flight_size()
	_set_progress(0.0)
	if is_queued_for_deletion():
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
	var travel := _ease_in_out_cubic(value if _from_deck else clampf((value - 0.24) / 0.76, 0.0, 1.0))
	var destination: Vector2 = target["center"]
	var destination_size: Vector2 = target["size"]
	var bend := Vector2((_source_center.x + destination.x) * 0.5, minf(_source_center.y, destination.y) - 55.0)
	var center := _source_center.lerp(bend, travel).lerp(bend.lerp(destination, travel), travel)
	_flight.position = center - _face_size * 0.5
	_flight.scale = (_source_size / _face_size).lerp(destination_size / _face_size, travel)
	_flight.rotation = lerpf(_source_rotation, float(target["rotation"]), travel)
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
