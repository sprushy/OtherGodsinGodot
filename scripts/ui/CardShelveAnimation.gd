extends "res://scripts/ui/CardDrawAnimation.gd"

var _insert_card: Callable

func play_shelve(card: Card, source: Dictionary, target_geometry: Callable, insert_card: Callable) -> void:
	_insert_card = insert_card
	super.play(card, source["center"], source["size"], float(source["rotation"]), target_geometry)

func _sync_flight_size() -> void:
	super._sync_flight_size()
	# The back changes proportions independently of the face. Scale it about
	# the flight's center so reshaping cannot displace it along the path.
	_back.pivot_offset = _face_size * 0.5

func _begin_flight() -> void:
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_sync_flight_size()
	_set_progress(0.0)
	if is_queued_for_deletion():
		return
	_tween = create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0, 0.90)
	_tween.tween_callback(_finish_shelve)

func _set_progress(value: float) -> void:
	_progress = value
	var target: Dictionary = _target_geometry.call()
	if target.is_empty():
		cancel()
		return
	var destination: Vector2 = target["center"]
	var destination_size: Vector2 = target["size"]
	var travel := _ease_in_out_cubic(value)
	var bend := Vector2((_source_center.x + destination.x) * 0.5, minf(_source_center.y, destination.y) - 65.0)
	var center := _source_center.lerp(bend, travel).lerp(bend.lerp(destination, travel), travel)
	var card_scale := (_source_size / _face_size).lerp(destination_size / _face_size, travel)
	var turn := smoothstep(0.18, 0.34, value)
	_face.visible = turn < 1.0
	_face.modulate.a = 1.0 - turn
	_back.visible = turn > 0.0
	_back.modulate.a = turn
	# The field representation can be square while the deck back is tall.
	# Shape the back independently during the flip so it reaches the deck's
	# rectangular proportions as the face disappears, rather than waiting for
	# the later travel scaling to do it.
	if _back.visible:
		var current_back_size := _face_size * card_scale
		var target_back_size := current_back_size.lerp(destination_size, turn)
		_back.scale = target_back_size / current_back_size
	else:
		_back.scale = Vector2.ONE
	_flight.position = center - _face_size * 0.5
	_flight.scale = card_scale
	_flight.rotation = lerpf(_source_rotation, float(target["rotation"]), travel)
	if _trail.is_empty() or _trail.back().distance_to(center) > 3.0:
		_trail.append(center)
		if _trail.size() > 18:
			_trail.pop_front()
	queue_redraw()

func _finish_shelve() -> void:
	_has_landed = true
	_flight.visible = false
	if _insert_card.is_valid():
		_insert_card.call()
	queue_free()

func _draw() -> void:
	if _has_landed:
		return
	# Keep the motion trail, without the draw animation's enclosing halo.
	for i in range(1, _trail.size()):
		var alpha := float(i) / float(_trail.size()) * 0.24
		draw_line(_trail[i - 1], _trail[i], Color(GOLD, alpha), 1.0 + float(i) * 0.22, true)
