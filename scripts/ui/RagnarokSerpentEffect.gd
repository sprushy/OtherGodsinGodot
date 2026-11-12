extends Control

## Cosmetic only: row membership comes from personalized departure geometry.
## Neither the model nor the effect reads live hands or chooses rules targets.
const SerpentModel := preload("res://scripts/ui/RagnarokSerpentModel.gd")
const SEGMENTS := 108
const EMERGE_TIME := 1.65
const RETURN_TIME := 1.9
const VENOM := Color(0.24, 1.0, 0.23)
const GOLD := Color(0.86, 0.77, 0.43)

var source_uid := ""
var _geometry: Callable
var _board: Dictionary = {}
var _home := Vector2.ZERO
var _unit := 100.0
var _age := 0.0
var _spine := PackedVector2Array()
var _head := Vector2.ZERO
var _heading := Vector2.RIGHT
var _jaw := 0.0
var _opacity := 1.0
var _actors: Array[Dictionary] = []
var _prey: Array[Dictionary] = []
var _row_bounds := Rect2()
var _strike_from := Vector2.ZERO
var _strike_direction := Vector2.DOWN
var _strike_time := 0.0
var _strike_duration := 1.0
var _row_eaten := false
var _finished := false
var _idle_time := 0.0
var _return_time := -1.0
var _return_spine := PackedVector2Array()
var _bursts: Array[Dictionary] = []
var _last_swallow_time := -100.0
var _glow: GradientTexture2D
var _view: SubViewport
var _camera: Camera3D
var _model: Node3D
var _composite: TextureRect


func play(card_uid: String, source: Dictionary, board_geometry: Callable) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	source_uid = card_uid
	_geometry = board_geometry
	_board = _geometry.call()
	if _board.is_empty():
		queue_free()
		return
	_home = source["center"]
	_unit = maxf(24.0, float(_board["unit"]))
	for index in SEGMENTS:
		_spine.append(_coil_point(index, _home, 0.08))
	_head = _spine[0]
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.TRANSPARENT])
	_glow = GradientTexture2D.new()
	_glow.gradient = gradient
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 64
	_glow.height = 64
	_create_3d_view()
	visibility_changed.connect(_sync_render_visibility)
	_sync_model()


func _create_3d_view() -> void:
	_view = SubViewport.new()
	_view.name = "SerpentWorld"
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.gui_disable_input = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_model = SerpentModel.new()
	_view.add_child(_model)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 1.0
	_camera.far = 6000.0
	_view.add_child(_camera)
	_camera.current = true
	_composite = TextureRect.new()
	_composite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_composite.texture = _view.get_texture()
	_composite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_composite.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_composite)
	_composite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _sync_render_visibility() -> void:
	if is_instance_valid(_view):
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED


func adopt_grave_card(card_uid: String, animation: Control, source: Dictionary) -> void:
	animation.set_meta("grave_sequence_controller", self)
	animation.z_index = z_index + 1
	var start: Vector2 = source["center"]
	var fallback_row := "row:%d" % int(round(start.y / maxf(1.0, _unit * 0.75)))
	_actors.append({
		"uid": card_uid, "animation": animation, "start": start,
		"size": Vector2(source["size"]), "rotation": float(source["rotation"]),
		"row": str(source.get("ragnarok_row", fallback_row)),
		"hand": bool(source.get("from_hand", false)),
	})
	_idle_time = 0.0
	# The return event precedes the last personalized state snapshot.
	if _return_time >= 0.0:
		_return_time = -1.0
		_opacity = 1.0


func finish_resolution() -> void:
	_finished = true


func _process(delta: float) -> void:
	if not _geometry.is_valid():
		queue_free()
		return
	var geometry: Dictionary = _geometry.call()
	if not geometry.is_empty():
		_board = geometry
		_unit = maxf(24.0, float(_board["unit"]))
	_age += delta
	for index in range(_bursts.size() - 1, -1, -1):
		_bursts[index]["age"] = float(_bursts[index]["age"]) + delta
		if float(_bursts[index]["age"]) > 0.8:
			_bursts.remove_at(index)
	if _return_time >= 0.0:
		_update_return(delta)
	elif _age < EMERGE_TIME:
		var rise := smoothstep(0.0, EMERGE_TIME, _age)
		var center := _home.lerp(Vector2(_board["center"]), rise)
		for index in SEGMENTS:
			_spine[index] = _coil_point(index, center, lerpf(0.08, 1.0, rise))
		_head = _spine[0]
		_heading = (_spine[0] - _spine[1]).normalized()
		_opacity = smoothstep(0.0, 0.4, _age)
	else:
		_update_hunt(delta)
		_follow_head(delta)
	_sync_model()
	queue_redraw()


func _coil_point(index: int, center: Vector2, coil_scale: float) -> Vector2:
	var t := float(index) / float(SEGMENTS - 1)
	var angle := -0.7 + t * TAU * 1.65
	var radius := _unit * lerpf(2.05, 0.45, t) * coil_scale
	return center + Vector2(cos(angle), sin(angle) * 0.70) * radius


func _live_actor(actor: Dictionary) -> Control:
	var animation = actor.get("animation")
	if not is_instance_valid(animation) or animation.is_queued_for_deletion():
		return null
	return animation as Control


func _select_row() -> void:
	var nearest := -1
	var distance := INF
	for index in range(_actors.size() - 1, -1, -1):
		if _live_actor(_actors[index]) == null:
			_actors.remove_at(index)
	var field_waiting := false
	for actor in _actors:
		if not bool(actor["hand"]):
			field_waiting = true
			break
	for index in _actors.size():
		# Human choices can take time. Collect the hand discards into full batches.
		if bool(_actors[index]["hand"]) and (not _finished or field_waiting):
			continue
		var candidate := _head.distance_squared_to(Vector2(_actors[index]["start"]))
		if candidate < distance:
			distance = candidate
			nearest = index
	if nearest < 0:
		return
	var row := str(_actors[nearest]["row"])
	for index in range(_actors.size() - 1, -1, -1):
		if str(_actors[index]["row"]) == row:
			_prey.append(_actors[index])
			_actors.remove_at(index)
	var first: Vector2 = _prey[0]["start"]
	_row_bounds = Rect2(first, Vector2.ZERO)
	for actor in _prey:
		var card_size: Vector2 = actor["size"]
		_row_bounds = _row_bounds.merge(Rect2(Vector2(actor["start"]) - card_size * 0.5, card_size))
	_strike_from = _head
	# Face the row broadside; all cards converge into the proportionate mouth.
	_strike_direction = Vector2.DOWN if _row_bounds.get_center().y >= Vector2(_board["center"]).y else Vector2.UP
	_strike_time = 0.0
	_strike_duration = clampf(1.0 + sqrt(distance) / (_unit * 12.0), 1.1, 1.6)
	_row_eaten = false
	_idle_time = 0.0


func _update_hunt(delta: float) -> void:
	if _prey.is_empty():
		_select_row()
	if _prey.is_empty():
		_idle_time += delta
		_jaw = lerpf(_jaw, 0.0, 1.0 - exp(-delta * 5.0))
		var center: Vector2 = _board["center"]
		var patrol := center + Vector2(cos(_age * 0.42) * _unit * 1.4, sin(_age * 0.56) * _unit * 0.8)
		_move_head(_head.lerp(patrol, minf(1.0, delta * 0.8)), delta)
		if _finished and _actors.is_empty() and _idle_time > 0.45:
			_return_time = 0.0
			_return_spine = _spine.duplicate()
		return
	_strike_time += delta
	var t := clampf(_strike_time / _strike_duration, 0.0, 1.0)
	var row_center := _row_bounds.get_center()
	var mouth_reach := _unit * SerpentModel.BODY_RADIUS_RATIO * SerpentModel.MOUTH_FORWARD_RATIO
	var destination := row_center - _strike_direction * mouth_reach
	var windup := _strike_from - _strike_direction * _unit * 0.5 * sin(smoothstep(0.0, 0.3, t) * PI)
	var travel := smoothstep(0.26, 0.64, t)
	var bend := windup.lerp(destination, 0.5) - _strike_direction * _unit * 0.45
	_move_head(windup.lerp(bend, travel).lerp(bend.lerp(destination, travel), travel), delta, false)
	_heading = Vector2.from_angle(lerp_angle(_heading.angle(), _strike_direction.angle(), 1.0 - exp(-delta * 8.0)))
	_jaw = smoothstep(0.08, 0.44, t) * (1.0 - smoothstep(0.80, 0.94, t))
	var swallow := smoothstep(0.38, 0.88, t)
	var mouth := _head + _heading * mouth_reach
	for actor in _prey:
		var animation := _live_actor(actor)
		if animation == null:
			continue
		var start: Vector2 = actor["start"]
		var spread := Vector2(start.x - row_center.x, 0.0) * (1.0 - swallow) * 0.65
		var center := start.lerp(mouth + spread, swallow)
		center.y -= sin(swallow * PI) * _unit * 0.40
		var bank := (start.x - row_center.x) / maxf(_unit, _row_bounds.size.x) * 0.75 * swallow
		animation.set_held_pose(center, Vector2(actor["size"]) * lerpf(1.0, 0.045, swallow * swallow), float(actor["rotation"]) + bank)
		animation.modulate = Color(1.0, 1.0 - swallow * 0.2, 1.0 - swallow * 0.35, 1.0 - smoothstep(0.7, 0.98, swallow))
		# Cards cross in front of the body, then disappear behind the closing lips.
		animation.z_index = z_index + 1 if swallow < 0.72 else z_index - 1
	if t >= 0.91 and not _row_eaten:
		_row_eaten = true
		_last_swallow_time = _age
		_bursts.append({"center": mouth, "age": 0.0, "width": _row_bounds.size.x})
		for actor in _prey:
			var animation := _live_actor(actor)
			if animation != null:
				animation.cancel()
	if t >= 1.0:
		_prey.clear()


func _move_head(destination: Vector2, delta: float, face_movement: bool = true) -> void:
	var movement := destination - _head
	if face_movement and movement.length_squared() > 0.01:
		_heading = Vector2.from_angle(lerp_angle(_heading.angle(), movement.angle(), 1.0 - exp(-delta * 5.0)))
	_head = destination


func _follow_head(delta: float) -> void:
	_spine[0] = _head
	var spacing := _unit * 0.115
	for index in range(1, SEGMENTS):
		var direction := (_spine[index] - _spine[index - 1]).normalized()
		if direction.is_zero_approx():
			direction = -_heading
		# Align the short neck with the skull instead of swivelling at a seam.
		if index < 6:
			direction = Vector2.from_angle(lerp_angle(direction.angle(), (-_heading).angle(), pow(1.0 - float(index) / 6.0, 2.0)))
		var target := _spine[index - 1] + direction * spacing
		_spine[index] = _spine[index].lerp(target, 1.0 - exp(-delta * 24.0))
		_spine[index] += direction.orthogonal() * sin(_age * 5.0 - float(index) * 0.22) * _unit * 0.06 * delta


func _update_return(delta: float) -> void:
	_return_time += delta
	var coil := smoothstep(0.0, 1.0, _return_time)
	var retreat := smoothstep(0.85, RETURN_TIME, _return_time)
	var center := Vector2(_board["center"]).lerp(_home, retreat)
	for index in SEGMENTS:
		_spine[index] = _return_spine[index].lerp(_coil_point(index, center, lerpf(1.0, 0.045, retreat)), coil)
	_head = _spine[0]
	_heading = (_spine[0] - _spine[1]).normalized()
	_jaw *= maxf(0.0, 1.0 - delta * 8.0)
	_opacity = 1.0 - smoothstep(1.4, RETURN_TIME, _return_time)
	if _return_time >= RETURN_TIME:
		queue_free()


func _radius(index: int) -> float:
	var t := float(index) / float(SEGMENTS - 1)
	var taper := pow(1.0 - t, 0.42)
	var gulp := 1.0 + 0.24 * sin(clampf((_age - _last_swallow_time) * 9.0 - float(index) * 0.16, 0.0, PI))
	var growth := lerpf(0.08, 1.0, smoothstep(0.0, EMERGE_TIME, _age))
	var retreat := 1.0 - smoothstep(0.85, RETURN_TIME, _return_time) * 0.96 if _return_time >= 0.0 else 1.0
	return _unit * SerpentModel.BODY_RADIUS_RATIO * taper * growth * retreat * gulp + 0.25


func _sync_model() -> void:
	var display_size := Vector2(maxf(2.0, size.x), maxf(2.0, size.y))
	# Bound the extra render target on large displays; gameplay stays at native size.
	var render_scale := minf(1.0, 2560.0 / display_size.x)
	var render_size := Vector2i((display_size * render_scale).round())
	if _view.size != render_size:
		_view.size = render_size
	_camera.size = display_size.y
	_camera.position = Vector3(display_size.x * 0.5, -display_size.y * 0.5, 2400.0)
	var radii := PackedFloat32Array()
	for index in SEGMENTS:
		radii.append(_radius(index))
	_model.set_pose(_spine, radii, _heading, _jaw, _unit, _age)
	_composite.modulate.a = _opacity
	var impact := maxf(0.0, 1.0 - (_age - _last_swallow_time) / 0.22)
	_composite.position = Vector2(sin(_age * 44.0), cos(_age * 51.0)) * _unit * 0.010 * impact


func _draw() -> void:
	if _spine.is_empty() or _glow == null:
		return
	var presence := smoothstep(0.0, EMERGE_TIME, _age) * _opacity
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.022, 0.028, presence * 0.24))
	var opening := sin(smoothstep(0.0, EMERGE_TIME, _age) * PI)
	if _return_time >= 0.0:
		opening = sin(clampf(_return_time / RETURN_TIME, 0.0, 1.0) * PI)
	var portal_size := Vector2(_unit * 2.5, _unit * 1.2)
	draw_texture_rect(_glow, Rect2(_home - portal_size, portal_size * 2.0), false, Color(0.16, 0.78, 0.85, opening * 0.55))
	# Soft projected shadows anchor the huge body to the card table.
	for index in range(SEGMENTS - 2, -1, -2):
		var offset := Vector2(_unit * 0.05, _unit * 0.15)
		var radius := _radius(index)
		draw_line(_spine[index + 1] + offset, _spine[index] + offset, Color(0.0, 0.005, 0.005, 0.16 * _opacity), radius * 2.5, true)
		draw_line(_spine[index + 1] + offset, _spine[index] + offset, Color(0.0, 0.005, 0.005, 0.22 * _opacity), radius * 1.7, true)
	for burst in _bursts:
		var t := float(burst["age"]) / 0.8
		var center: Vector2 = burst["center"]
		var extent := Vector2(maxf(_unit, float(burst["width"]) * 0.6), _unit * 0.8) * (0.7 + t)
		draw_texture_rect(_glow, Rect2(center - extent, extent * 2.0), false, Color(VENOM, (1.0 - t) * 0.5))
		for mote in range(28):
			var angle := float(mote) * 2.399963
			var point := center + Vector2(cos(angle) * 2.3, sin(angle)) * _unit * t * (0.5 + float(mote % 3) * 0.2)
			draw_circle(point, maxf(0.5, _unit * 0.025 * (1.0 - t)), Color(GOLD if mote % 3 == 0 else VENOM, (1.0 - t) * _opacity))
