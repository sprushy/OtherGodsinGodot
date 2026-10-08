class_name SnowV2ScreenOverlay
extends Control

const MAX_FLAKES := 640
const MIN_FLAKES := 90
const FLAKE_ATLAS_COLUMNS := 11
const FLAKE_ATLAS_ROWS := 10

var snowflake_texture: Texture2D = null
var paintbrush_texture: Texture2D = null
var flake_atlas_texture: Texture2D = null
var wind_wisp_texture: Texture2D = null
var melt_over_entire_screen: bool = false

var _active: bool = false
var _strength: float = 0.0
var _wind_direction: Vector2 = Vector2(-1.0, 0.18)
var _wind_force: float = 1.0
var _flakes: Array[Dictionary] = []
var _landed_flakes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_sync_viewport_bounds()
	get_viewport().size_changed.connect(_sync_viewport_bounds)
	_rng.seed = 47027
	set_process(false)
	visible = false

func set_weather(active: bool, strength: float, wind_direction: Vector2, wind_force: float) -> void:
	_sync_viewport_bounds()
	_active = active
	_strength = clampf(strength, 0.0, 1.0)
	if wind_direction.length_squared() > 0.001:
		_wind_direction = wind_direction.normalized()
	_wind_force = clampf(wind_force, 0.0, 4.0)
	visible = _active and _strength > 0.01
	set_process(visible)
	if visible and _flakes.is_empty():
		_seed_flakes()
	if not visible:
		_flakes.clear()
		_landed_flakes.clear()
	queue_redraw()

func _sync_viewport_bounds() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	clip_contents = false
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var rect_size := size
	if rect_size.x <= 4.0 or rect_size.y <= 4.0:
		rect_size = get_viewport_rect().size
	if rect_size.x <= 4.0 or rect_size.y <= 4.0:
		return

	var target_count := int(round(lerpf(float(MIN_FLAKES), float(MAX_FLAKES), _strength)))
	while _flakes.size() < target_count:
		_flakes.append(_make_flake(rect_size, false))
	while _flakes.size() > target_count:
		_flakes.pop_back()
	if melt_over_entire_screen:
		_advance_surface_flakes(delta, rect_size)
		queue_redraw()
		return

	var wind_sign := 1.0
	if _wind_direction.x < 0.0:
		wind_sign = -1.0
	for i in range(_flakes.size()):
		var flake := _flakes[i]
		var pos: Vector2 = flake.get("pos", Vector2.ZERO)
		var drift := absf(float(flake.get("drift", 0.0))) * wind_sign
		var fall_speed := float(flake.get("fall", 60.0))
		var wind_velocity := Vector2(
			_wind_direction.x * _wind_force * 195.0 + drift,
			maxf(0.15, 1.0 + _wind_direction.y * 0.25) * fall_speed
		)
		pos += wind_velocity * delta
		pos.x += sin(_time * float(flake.get("sway_rate", 1.0)) + float(flake.get("phase", 0.0))) * 4.0 * delta
		flake["pos"] = pos
		if pos.y > rect_size.y + 32.0 or pos.x < -72.0 or pos.x > rect_size.x + 72.0:
			flake = _make_flake(rect_size, true)
		_flakes[i] = flake
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var rect_size := size
	if rect_size.x <= 4.0 or rect_size.y <= 4.0:
		return

	var veil_alpha := 0.025 + _strength * 0.075
	draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.82, 0.90, 1.0, veil_alpha), true)
	_draw_wind_wisps(rect_size)
	_draw_soft_accumulation(rect_size)
	_draw_surface_melt()
	_draw_flakes()

func _advance_surface_flakes(delta: float, rect_size: Vector2) -> void:
	for i in range(_landed_flakes.size() - 1, -1, -1):
		var landed := _landed_flakes[i]
		landed["age"] = float(landed.get("age", 0.0)) + delta
		if float(landed["age"]) >= float(landed["lifetime"]):
			_landed_flakes.remove_at(i)
	for i in range(_flakes.size()):
		var flake := _flakes[i]
		var remaining := maxf(0.0, float(flake["remaining"]) - delta)
		var duration := float(flake["flight_time"])
		var landing: Vector2 = flake["landing"]
		var velocity: Vector2 = flake["velocity"]
		flake["remaining"] = remaining
		flake["pos"] = landing - velocity * remaining
		flake["alpha"] = float(flake["surface_alpha"]) * minf(1.0, (duration - remaining) / 0.2)
		if remaining <= 0.0:
			var landed := flake.duplicate()
			landed["age"] = 0.0
			landed["lifetime"] = _rng.randf_range(1.4, 3.4)
			_landed_flakes.append(landed)
			while _landed_flakes.size() > MAX_FLAKES:
				_landed_flakes.pop_front()
			flake = _make_flake(rect_size, true)
		_flakes[i] = flake

func _draw_surface_melt() -> void:
	for flake in _landed_flakes:
		var progress := clampf(float(flake["age"]) / float(flake["lifetime"]), 0.0, 1.0)
		var pos: Vector2 = flake["landing"]
		var flake_size := float(flake["size"]) * 0.85 * lerpf(1.0, 0.35, progress)
		var alpha := float(flake["surface_alpha"]) * (1.0 - progress)
		var rect := Rect2(pos - Vector2.ONE * flake_size * 0.5, Vector2.ONE * flake_size)
		var tint := Color(0.96, 0.99, 1.0, alpha)
		if flake_atlas_texture != null:
			draw_texture_rect_region(flake_atlas_texture, rect, _get_flake_atlas_region(flake), tint)
		elif snowflake_texture != null:
			draw_texture_rect(snowflake_texture, rect, false, tint)
		if paintbrush_texture != null:
			var patch_size := Vector2(flake_size * 1.8, flake_size * 0.7)
			draw_texture_rect(paintbrush_texture, Rect2(pos - patch_size * 0.5, patch_size), false, Color(0.88, 0.95, 1.0, alpha * 0.24))

func _draw_flakes() -> void:
	for flake in _flakes:
		var pos: Vector2 = flake.get("pos", Vector2.ZERO)
		var flake_size := float(flake.get("size", 4.0)) * 1.15
		var alpha := float(flake.get("alpha", 0.55)) * (0.45 + _strength * 0.65)
		var rect := Rect2(pos - Vector2(flake_size, flake_size) * 0.5, Vector2(flake_size, flake_size))
		var tint := Color(0.90, 0.96, 1.0, clampf(alpha, 0.0, 0.95))
		if flake_atlas_texture != null:
			draw_texture_rect_region(flake_atlas_texture, rect, _get_flake_atlas_region(flake), tint)
		elif snowflake_texture != null:
			draw_texture_rect(snowflake_texture, rect, false, tint)
		else:
			draw_circle(pos, flake_size * 0.22, tint)

func _draw_wind_wisps(rect_size: Vector2) -> void:
	if wind_wisp_texture == null:
		return
	var texture_size := wind_wisp_texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return
	if rect_size.x <= 1.0 or rect_size.y <= 1.0:
		return
	var alpha := 0.05 + _strength * 0.08
	var patch_size := Vector2(rect_size.x * 0.92, rect_size.y * 0.42)
	var horizontal_step := rect_size.x * 0.64
	var wind_sign := -1.0 if _wind_direction.x < 0.0 else 1.0
	# Overlap the transparent edges and wrap by patch spacing, so scrolling
	# never exposes an empty strip or resets the entire wind layer at once.
	for row in range(4):
		var speed := (18.0 + 38.0 * _wind_force) * (0.55 + float(row) * 0.22)
		var offset := fposmod(_time * speed * wind_sign + float(row) * horizontal_step * 0.37, horizontal_step)
		var y := rect_size.y * (-0.15 + float(row) * 0.30)
		for column in range(-2, 2):
			var x := float(column) * horizontal_step + offset
			draw_texture_rect(
				wind_wisp_texture,
				Rect2(Vector2(x, y), patch_size),
				false,
				Color(0.78, 0.90, 1.0, alpha)
			)

func _get_flake_atlas_region(flake: Dictionary) -> Rect2:
	var atlas_size := flake_atlas_texture.get_size()
	var cell := Vector2(atlas_size.x / float(FLAKE_ATLAS_COLUMNS), atlas_size.y / float(FLAKE_ATLAS_ROWS))
	var col := int(flake.get("atlas_col", 0)) % FLAKE_ATLAS_COLUMNS
	var row := int(flake.get("atlas_row", 3)) % FLAKE_ATLAS_ROWS
	return Rect2(Vector2(float(col) * cell.x, float(row) * cell.y), cell)

func _draw_soft_accumulation(rect_size: Vector2) -> void:
	if paintbrush_texture == null:
		return
	var patch_count := 4 + int(round(_strength * 4.0))
	for i in range(patch_count):
		var fraction := (float(i) + 0.35) / float(patch_count)
		var width := lerpf(70.0, 145.0, fmod(float(i) * 0.37, 1.0))
		var height := lerpf(8.0, 22.0, fmod(float(i) * 0.61, 1.0))
		var x := rect_size.x * fraction - width * 0.5
		var y := rect_size.y - height * (0.58 + fmod(float(i) * 0.19, 0.55))
		var alpha := (0.018 + _strength * 0.045) * (0.75 + fmod(float(i) * 0.23, 0.35))
		draw_texture_rect(
			paintbrush_texture,
			Rect2(Vector2(x, y), Vector2(width, height)),
			false,
			Color(0.92, 0.97, 1.0, alpha)
		)

func _seed_flakes() -> void:
	_flakes.clear()
	var rect_size := size
	if rect_size.x <= 4.0 or rect_size.y <= 4.0:
		rect_size = get_viewport_rect().size
	var count := int(round(lerpf(float(MIN_FLAKES), float(MAX_FLAKES), _strength)))
	for i in range(count):
		_flakes.append(_make_flake(rect_size, false))

func _make_flake(rect_size: Vector2, start_above: bool) -> Dictionary:
	var y := _rng.randf_range(-rect_size.y, rect_size.y)
	if start_above:
		y = _rng.randf_range(-40.0, -6.0)
	var flake: Dictionary = {
		"pos": Vector2(_rng.randf_range(-32.0, rect_size.x + 32.0), y),
		"size": _rng.randf_range(2.2, 8.5 + _strength * 7.0),
		"alpha": _rng.randf_range(0.30, 0.78),
		"fall": _rng.randf_range(42.0, 175.0 + _strength * 120.0),
		"drift": _rng.randf_range(4.0, 32.0),
		"sway_rate": _rng.randf_range(0.7, 1.8),
		"phase": _rng.randf_range(0.0, TAU),
		"atlas_col": _rng.randi_range(0, FLAKE_ATLAS_COLUMNS - 1),
		"atlas_row": _rng.randi_range(2, FLAKE_ATLAS_ROWS - 3),
	}
	if melt_over_entire_screen:
		var duration := _rng.randf_range(0.7, 2.1)
		var landing := Vector2(_rng.randf_range(0.0, rect_size.x), _rng.randf_range(0.0, rect_size.y))
		var velocity := Vector2(_wind_direction.x * _wind_force * 105.0, float(flake["fall"]))
		var remaining := duration if start_above else _rng.randf_range(0.0, duration)
		flake["landing"] = landing
		flake["velocity"] = velocity
		flake["flight_time"] = duration
		flake["remaining"] = remaining
		flake["surface_alpha"] = float(flake["alpha"])
		flake["pos"] = landing - velocity * remaining
	return flake
