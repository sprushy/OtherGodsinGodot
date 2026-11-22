extends Control

## Owns this effect's presentation order, while authoritative rules and state
## continue normally. Every flying card is the existing art-only grave actor.
signal departure_requested(card_uid: String, tumble_turns: float)

const AURA_SHADER := preload("res://shaders/occult_singularity_aura.gdshader")
const SOURCE_ART := preload("res://images/card_art/spells/OccultSingularityEdit.png")
const LIFT_END := 1.45
const SPIN_END := 3.65
const VICTIM_SPACING := 0.11

var source_uid := ""
var _geometry: Callable
var _board: Dictionary = {}
var _source_start: Dictionary = {}
var _source_actor: Dictionary = {}
var _victims: Array[Dictionary] = []
var _fallback: TextureRect
var _aura: ColorRect
var _glow: GradientTexture2D
var _phase_time := 0.0
var _wall_time := 0.0
var _angle := 0.0
var _resolution_finished := false
var _source_departed := false
var _victim_clock := -1.0
var _hover_center := Vector2.ZERO


func play(card_uid: String, source_geometry: Dictionary, board_geometry: Callable) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	source_uid = card_uid
	_source_start = source_geometry
	_geometry = board_geometry
	_board = _geometry.call()
	_aura = ColorRect.new()
	_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var aura_material := ShaderMaterial.new()
	aura_material.shader = AURA_SHADER
	_aura.material = aura_material
	add_child(_aura)
	_fallback = TextureRect.new()
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fallback.texture = SOURCE_ART
	_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fallback.clip_contents = true
	add_child(_fallback)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.45), Color(1.0, 1.0, 1.0, 0.08), Color.TRANSPARENT])
	_glow = GradientTexture2D.new()
	_glow.gradient = gradient
	_glow.width = 64
	_glow.height = 64
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_update_poses(0.0)


func adopt_grave_card(card_uid: String, animation: Control, source: Dictionary, is_source: bool) -> void:
	animation.set_meta("grave_sequence_controller", self)
	var actor := {
		"uid": card_uid, "animation": animation,
		"start": Vector2(source["center"]), "size": Vector2(source["size"]),
		"rotation": float(source["rotation"]), "departed": false,
		"phase": float(_victims.size()) * 2.399963,
	}
	if is_source:
		_source_actor = actor
		_fallback.hide()
	else:
		_victims.append(actor)
	_update_poses(0.0)


func finish_resolution() -> void:
	_resolution_finished = true


func _process(delta: float) -> void:
	_wall_time += delta
	if not _geometry.is_valid():
		queue_free()
		return
	var live_board: Dictionary = _geometry.call()
	if not live_board.is_empty():
		_board = live_board
	# Pending replacement/protection prompts can still change the outcome.
	# Start the gentle levitation, then wait until authoritative resolution settles.
	if _resolution_finished:
		_phase_time += delta
	else:
		_phase_time = minf(0.55, _phase_time + delta)
	_update_poses(delta)
	if _phase_time >= SPIN_END and not _source_departed:
		_source_departed = true
		if not _source_actor.is_empty():
			_source_actor["departed"] = true
			departure_requested.emit(source_uid, 0.0)
		else:
			_fallback.hide()
	if _source_departed and _victim_clock < 0.0:
		var source_animation := _get_live_animation(_source_actor)
		if source_animation == null:
			_victim_clock = 0.0
	if _victim_clock >= 0.0:
		_victim_clock += delta
		for index in _victims.size():
			var actor := _victims[index]
			if not bool(actor["departed"]) and _victim_clock >= float(index) * VICTIM_SPACING:
				actor["departed"] = true
				var turns := (1.15 + float(index % 3) * 0.22) * (-1.0 if index % 2 == 0 else 1.0)
				departure_requested.emit(str(actor["uid"]), turns)
		if _victim_clock > maxf(0.45, float(_victims.size()) * VICTIM_SPACING + 0.35):
			queue_free()
	queue_redraw()


func _get_live_animation(actor: Dictionary) -> Control:
	# Grave actors free themselves on arrival. Validate the stored Variant before
	# casting it: casting an already-freed object raises a script error in Godot.
	var animation = actor.get("animation")
	if not is_instance_valid(animation):
		return null
	if animation.is_queued_for_deletion():
		return null
	return animation as Control


func _update_poses(delta: float) -> void:
	if _board.is_empty():
		return
	var unit := float(_board["unit"])
	var board_center: Vector2 = _board["center"]
	_hover_center = board_center - Vector2(0.0, unit * 0.15)
	var lift := smoothstep(0.0, 0.7, _phase_time)
	var energy := smoothstep(LIFT_END, SPIN_END, _phase_time)
	_angle += delta * lerpf(0.24, 8.5, energy * energy)
	var source_center: Vector2 = Vector2(_source_start["center"]).lerp(_hover_center, lift)
	source_center.y -= sin(_wall_time * 2.3) * unit * 0.018 * lift
	var original_size: Vector2 = _source_start["size"]
	var hover_scale := clampf(unit * 0.76 / maxf(original_size.x, original_size.y), 0.4, 1.8)
	var source_size := original_size * lerpf(1.0, hover_scale, lift)
	if not _source_departed:
		if not _source_actor.is_empty():
			var animation := _get_live_animation(_source_actor)
			if animation != null:
				animation.set_held_pose(source_center, source_size, float(_source_start["rotation"]) * (1.0 - lift) + sin(_wall_time * 1.6) * 0.035 * lift)
		else:
			_fallback.size = source_size
			_fallback.position = source_center - source_size * 0.5
	_aura.size = Vector2.ONE * unit * 2.3
	_aura.position = source_center - _aura.size * 0.5
	var aura_material := _aura.material as ShaderMaterial
	aura_material.set_shader_parameter("phase", _angle)
	aura_material.set_shader_parameter("energy", energy)
	var aura_fade := 1.0 - smoothstep(0.0, maxf(0.4, float(_victims.size()) * VICTIM_SPACING + 0.25), _victim_clock) if _victim_clock >= 0.0 else 1.0
	aura_material.set_shader_parameter("opacity", lift * aura_fade)
	var board_size: Vector2 = _board["size"]
	var orbit_radius := minf(board_size.x * 0.26, unit * 1.6)
	for index in _victims.size():
		var actor := _victims[index]
		if bool(actor["departed"]):
			continue
		var animation := _get_live_animation(actor)
		if animation == null:
			continue
		var delay := minf(0.3, float(index) * 0.045)
		var tug := smoothstep(0.3 + delay, LIFT_END + delay, _phase_time)
		var start: Vector2 = actor["start"]
		var phase := _angle + float(actor["phase"])
		var lift_height := unit * 0.32 * tug
		var tension := sin(_wall_time * 12.0 + float(actor["phase"])) * unit * 0.018 * (1.0 - energy) * tug
		var lifted := start + Vector2(sin(phase) * unit * 0.045 * tug, -lift_height + tension)
		var ride_radius := orbit_radius * (0.85 + float(index % 3) * 0.08)
		var orbit := _hover_center + Vector2(cos(phase) * ride_radius, sin(phase) * ride_radius * 0.32 - unit * 0.25)
		var center := lifted.lerp(orbit, energy)
		var depth_scale := 0.70 + sin(phase) * 0.10
		var card_scale := lerpf(1.0, depth_scale, energy)
		var bank := lerpf(sin(_wall_time * 7.0 + float(actor["phase"])) * 0.12 * tug, sin(phase + 0.7) * 0.38, energy)
		animation.set_held_pose(center, Vector2(actor["size"]) * card_scale, float(actor["rotation"]) + bank)
		animation.z_index = z_index + 2 + int((sin(phase) + 1.0) * 3.0)
		actor["center"] = center
	if not _source_actor.is_empty():
		var source_animation := _get_live_animation(_source_actor)
		if source_animation != null:
			source_animation.z_index = z_index + 10


func _draw() -> void:
	if _board.is_empty() or _glow == null:
		return
	var unit := float(_board["unit"])
	var energy := smoothstep(LIFT_END, SPIN_END, _phase_time)
	for actor in _victims:
		if bool(actor["departed"]) or not actor.has("center"):
			continue
		var center: Vector2 = actor["center"]
		var start: Vector2 = actor["start"]
		var shadow_size := Vector2(unit * 0.42, unit * 0.16)
		draw_texture_rect(_glow, Rect2(start - shadow_size, shadow_size * 2.0), false, Color(0.08, 0.005, 0.07, 0.25))
		var bend := center.lerp(_hover_center, 0.5) - Vector2(0.0, unit * (0.15 + energy * 0.25))
		var strand := PackedVector2Array()
		for segment in range(17):
			var t := float(segment) / 16.0
			var point := center.lerp(bend, t).lerp(bend.lerp(_hover_center, t), t)
			point.y += sin(t * TAU * 2.0 + _angle + float(actor["phase"])) * unit * 0.012 * sin(t * PI)
			strand.append(point)
		var alpha := smoothstep(0.25, 0.8, _phase_time) * (0.25 + energy * 0.3)
		draw_polyline(strand, Color(1.0, 0.025, 0.53, alpha * 0.18), maxf(2.0, unit * 0.022), true)
		draw_polyline(strand, Color(1.0, 0.3, 0.78, alpha), maxf(0.8, unit * 0.004), true)
		var mote_index := int(fposmod(_wall_time * (2.0 + energy * 8.0) + float(actor["phase"]), 16.0))
		var mote_size := Vector2.ONE * unit * 0.05
		draw_texture_rect(_glow, Rect2(strand[mote_index] - mote_size, mote_size * 2.0), false, Color(1.0, 0.30, 0.75, alpha))
