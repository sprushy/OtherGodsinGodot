class_name SnowV2CardMeltOverlay
extends Control

const WEATHER_GROUP := "snow_v2_card_weather"
const MAX_PATCHES := 6
const MAX_FALLING_FLAKES := 8
const MAX_LANDED_FLAKES := 4
const POWDER_LANDING_THRESHOLD := 6
const EDGE_ACCUMULATION_THRESHOLD := 0.22
const CORNER_ACCUMULATION_THRESHOLD := 0.56
const FLAKE_ATLAS_COLUMNS := 11
const FLAKE_ATLAS_ROWS := 10
const EDGE_STRIP_ROWS := 10
const CORNER_ATLAS_COLUMNS := 4
const CORNER_ATLAS_ROWS := 7

var snowflake_texture: Texture2D = null
var paintbrush_texture: Texture2D = null
var flake_atlas_texture: Texture2D = null
var powder_texture: Texture2D = null
var edge_strip_texture: Texture2D = null
var corner_border_texture: Texture2D = null
var body_inset: Vector4 = Vector4(10.0, 14.0, 10.0, 28.0)
var allow_melt_on_land: bool = true
var show_falling_flakes: bool = true
var show_body_powder: bool = true
var show_edge_snow: bool = true

var _active: bool = false
var _strength: float = 0.0
var _wind_direction: Vector2 = Vector2(-1.0, 0.18)
var _wind_force: float = 1.0
var _patches: Array[Dictionary] = []
var _falling_flakes: Array[Dictionary] = []
var _landed_flakes: Array[Dictionary] = []
var _landing_count: int = 0
var _surface_accumulation: float = 0.0
var _last_shake_time: float = -1000.0
var _rng := RandomNumberGenerator.new()
var _tick: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(WEATHER_GROUP)
	_rng.seed = int(get_instance_id()) ^ 91037
	visible = false
	set_process(false)

func set_snow_v2_weather(active: bool, strength: float, wind_direction: Vector2, wind_force: float) -> void:
	_active = active
	_strength = clampf(strength, 0.0, 1.0)
	if wind_direction.length_squared() > 0.001:
		_wind_direction = wind_direction.normalized()
	_wind_force = clampf(wind_force, 0.0, 4.0)
	visible = _active and _strength > 0.05
	set_process(visible)
	if visible and show_falling_flakes and _falling_flakes.is_empty():
		_seed_falling_flakes()
	elif not show_falling_flakes:
		_falling_flakes.clear()
	if not visible:
		_patches.clear()
		_falling_flakes.clear()
		_landed_flakes.clear()
		_landing_count = 0
		_surface_accumulation = 0.0
	queue_redraw()

func set_weather(strength: float, wind_direction: Vector2) -> void:
	set_snow_v2_weather(strength > 0.05, strength, wind_direction, _wind_force)

func _process(delta: float) -> void:
	if not visible:
		return
	var body := _body_rect()
	if body.size.x <= 8.0 or body.size.y <= 8.0:
		return
	if show_falling_flakes:
		_update_falling_flakes(delta)
	_update_landed_flakes(delta)
	_surface_accumulation = clampf(_surface_accumulation + delta * (0.018 + _strength * 0.024), 0.0, 1.0)
	_tick += delta
	if _tick < 0.10:
		if show_falling_flakes:
			queue_redraw()
		return
	_tick = 0.0
	for i in range(_patches.size()):
		var patch := _patches[i]
		var melts := allow_melt_on_land and bool(patch.get("melts", allow_melt_on_land))
		if melts:
			patch["wet"] = clampf(float(patch.get("wet", 0.0)) + 0.014 + _strength * 0.018, 0.0, 1.0)
			patch["snow"] = clampf(float(patch.get("snow", 1.0)) - 0.032 - _strength * 0.025, 0.0, 1.0)
		else:
			patch["melts"] = false
			patch["wet"] = 0.0
			patch["snow"] = clampf(float(patch.get("snow", 1.0)) - 0.003, 0.42, 1.0)
		patch["age"] = float(patch.get("age", 0.0)) + 0.10
		_patches[i] = patch
	_prune_old_patches()
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var body := _body_rect()
	if body.size.x <= 8.0 or body.size.y <= 8.0:
		return
	var powder_amount := _body_powder_amount()
	if show_body_powder and powder_amount > 0.001:
		_draw_powder_accumulation(body, powder_amount)
	for patch in _patches:
		var uv_pos: Vector2 = patch.get("pos", Vector2(0.5, 0.5))
		var patch_size: Vector2 = patch.get("size", Vector2(0.12, 0.07))
		var center := body.position + body.size * uv_pos
		var size_px := Vector2(body.size.x * patch_size.x, body.size.y * patch_size.y)
		var rect := Rect2(center - size_px * 0.5, size_px)
		var melts := allow_melt_on_land and bool(patch.get("melts", allow_melt_on_land))
		var wet := float(patch.get("wet", 0.0)) if melts else 0.0
		var snow := float(patch.get("snow", 1.0))
		var age := float(patch.get("age", 0.0))
		var fade := clampf(1.0 - maxf(0.0, age - 5.5) / 4.0, 0.0, 1.0)
		if paintbrush_texture != null:
			if wet > 0.001:
				draw_texture_rect(paintbrush_texture, rect, false, Color(0.07, 0.11, 0.13, 0.055 * wet * fade))
			if snow > 0.0:
				var snow_rect := rect.grow_individual(-size_px.x * 0.20, -size_px.y * 0.18, -size_px.x * 0.24, -size_px.y * 0.22)
				var snow_alpha := 0.24 if melts else 0.16
				draw_texture_rect(paintbrush_texture, snow_rect, false, Color(0.92, 0.97, 1.0, snow_alpha * snow * _strength * fade))
		else:
			if wet > 0.001:
				draw_rect(rect, Color(0.07, 0.11, 0.13, 0.045 * wet * fade), true)
	_draw_landed_flakes(body)
	if show_falling_flakes:
		_draw_falling_flakes(body)
	if show_edge_snow:
		_draw_edge_snow(Rect2(Vector2.ZERO, size))

func _draw_powder_accumulation(body: Rect2, powder_amount: float) -> void:
	if powder_texture == null:
		return
	var alpha := clampf(powder_amount * (0.08 + _strength * 0.08), 0.0, 0.14)
	draw_texture_rect(powder_texture, body, false, Color(0.92, 0.97, 1.0, alpha))

func _body_powder_amount() -> float:
	var landing_powder := 0.0
	if _landing_count >= POWDER_LANDING_THRESHOLD:
		landing_powder = clampf(float(_landing_count - POWDER_LANDING_THRESHOLD + 1) / 10.0, 0.0, 1.0)
	if show_falling_flakes:
		return landing_powder
	return clampf((_surface_accumulation - 0.32) / 0.68, 0.0, 1.0)

func _draw_landed_flakes(body: Rect2) -> void:
	if snowflake_texture == null and flake_atlas_texture == null:
		return
	for flake in _landed_flakes:
		var uv_pos: Vector2 = flake.get("pos", Vector2.ZERO)
		var x := body.position.x + body.size.x * uv_pos.x
		var y := body.position.y + body.size.y * uv_pos.y
		var s := minf(body.size.x, body.size.y) * float(flake.get("size", 0.05))
		var lifetime := float(flake.get("lifetime", 0.9))
		var age := float(flake.get("age", 0.0))
		var alpha := clampf(1.0 - age / lifetime, 0.0, 1.0) * float(flake.get("alpha", 0.78))
		_draw_flake_texture(Rect2(Vector2(x, y) - Vector2(s, s) * 0.5, Vector2(s, s)), flake, Color(0.96, 0.99, 1.0, alpha))

func _draw_falling_flakes(body: Rect2) -> void:
	if snowflake_texture == null and flake_atlas_texture == null:
		return
	for flake in _falling_flakes:
		var uv_pos: Vector2 = flake.get("pos", Vector2.ZERO)
		var x := body.position.x + body.size.x * uv_pos.x
		var y := body.position.y + body.size.y * uv_pos.y
		var s := minf(body.size.x, body.size.y) * float(flake.get("size", 0.035))
		var alpha := float(flake.get("alpha", 0.0))
		_draw_flake_texture(Rect2(Vector2(x, y) - Vector2(s, s) * 0.5, Vector2(s, s)), flake, Color(0.92, 0.97, 1.0, alpha))

func _draw_flake_texture(rect: Rect2, flake: Dictionary, tint: Color) -> void:
	if flake_atlas_texture != null:
		draw_texture_rect_region(flake_atlas_texture, rect, _get_flake_atlas_region(flake), tint)
	elif snowflake_texture != null:
		draw_texture_rect(snowflake_texture, rect, false, tint)

func _get_flake_atlas_region(flake: Dictionary) -> Rect2:
	var atlas_size := flake_atlas_texture.get_size()
	var cell := Vector2(atlas_size.x / float(FLAKE_ATLAS_COLUMNS), atlas_size.y / float(FLAKE_ATLAS_ROWS))
	var col := int(flake.get("atlas_col", 0)) % FLAKE_ATLAS_COLUMNS
	var row := int(flake.get("atlas_row", 3)) % FLAKE_ATLAS_ROWS
	return Rect2(Vector2(float(col) * cell.x, float(row) * cell.y), cell)

func _draw_edge_snow(surface: Rect2) -> void:
	var accumulation := _edge_accumulation_amount()
	if accumulation < EDGE_ACCUMULATION_THRESHOLD:
		return
	var visible_accumulation := clampf((accumulation - EDGE_ACCUMULATION_THRESHOLD) / (1.0 - EDGE_ACCUMULATION_THRESHOLD), 0.0, 1.0)
	if edge_strip_texture != null:
		var atlas_size := edge_strip_texture.get_size()
		var row_height := atlas_size.y / float(EDGE_STRIP_ROWS)
		var top_row := posmod(int(get_instance_id()), EDGE_STRIP_ROWS)
		var bottom_row := posmod(top_row + 3, EDGE_STRIP_ROWS)
		var top_src := Rect2(Vector2(0.0, float(top_row) * row_height), Vector2(atlas_size.x, row_height))
		var bottom_src := Rect2(Vector2(0.0, float(bottom_row) * row_height), Vector2(atlas_size.x, row_height))
		var thickness := clampf(surface.size.y * (0.035 + visible_accumulation * 0.035), 4.0, 13.0)
		var alpha := (0.12 + _strength * 0.12) * visible_accumulation
		draw_texture_rect_region(edge_strip_texture, Rect2(surface.position + Vector2(0.0, 0.0), Vector2(surface.size.x, thickness)), top_src, Color(0.92, 0.97, 1.0, alpha))
		draw_texture_rect_region(edge_strip_texture, Rect2(surface.position + Vector2(0.0, surface.size.y - thickness * 0.62), Vector2(surface.size.x, thickness)), bottom_src, Color(0.92, 0.97, 1.0, alpha * 0.62))
	if corner_border_texture != null and accumulation >= CORNER_ACCUMULATION_THRESHOLD:
		var atlas_size := corner_border_texture.get_size()
		var cell := Vector2(atlas_size.x / float(CORNER_ATLAS_COLUMNS), atlas_size.y / float(CORNER_ATLAS_ROWS))
		var corner_accumulation := clampf((accumulation - CORNER_ACCUMULATION_THRESHOLD) / (1.0 - CORNER_ACCUMULATION_THRESHOLD), 0.0, 1.0)
		var row := posmod(int(get_instance_id()), 2)
		var corner_size := minf(surface.size.x, surface.size.y) * (0.12 + corner_accumulation * 0.10)
		var alpha := (0.12 + _strength * 0.10) * corner_accumulation
		var left_src := Rect2(Vector2(0.0, float(row) * cell.y), cell)
		var right_src := Rect2(Vector2(cell.x, float(row) * cell.y), cell)
		draw_texture_rect_region(corner_border_texture, Rect2(surface.position + Vector2(0.0, 0.0), Vector2(corner_size, corner_size)), left_src, Color(0.92, 0.97, 1.0, alpha))
		draw_texture_rect_region(corner_border_texture, Rect2(surface.position + Vector2(surface.size.x - corner_size, 0.0), Vector2(corner_size, corner_size)), right_src, Color(0.92, 0.97, 1.0, alpha))

func _edge_accumulation_amount() -> float:
	var landing_accumulation := clampf(float(maxi(0, _landing_count - 5)) / 16.0, 0.0, 1.0)
	return maxf(landing_accumulation, _surface_accumulation)

func _body_rect() -> Rect2:
	var rect := Rect2(Vector2.ZERO, size)
	rect.position.x += body_inset.x
	rect.position.y += body_inset.y
	rect.size.x -= body_inset.x + body_inset.z
	rect.size.y -= body_inset.y + body_inset.w
	return rect

func _seed_falling_flakes() -> void:
	_falling_flakes.clear()
	var count := _target_falling_flake_count()
	for i in range(count):
		_falling_flakes.append(_make_falling_flake(false))

func _update_falling_flakes(delta: float) -> void:
	var target_count := _target_falling_flake_count()
	while _falling_flakes.size() < target_count:
		_falling_flakes.append(_make_falling_flake(true))
	while _falling_flakes.size() > target_count:
		_falling_flakes.pop_back()

	for i in range(_falling_flakes.size()):
		var flake := _falling_flakes[i]
		var pos: Vector2 = flake.get("pos", Vector2.ZERO)
		var velocity: Vector2 = flake.get("velocity", Vector2(0.0, 0.22))
		pos += velocity * delta
		pos.x += _wind_direction.x * _wind_force * delta * 0.045
		flake["pos"] = pos
		var landing_y := float(flake.get("landing_y", 0.72))
		if pos.y >= landing_y:
			_add_landed_flake(Vector2(clampf(pos.x, 0.10, 0.90), clampf(landing_y, 0.12, 0.88)), flake)
			flake = _make_falling_flake(true)
		elif pos.x < -0.16 or pos.x > 1.16:
			flake = _make_falling_flake(true)
		_falling_flakes[i] = flake

func _target_falling_flake_count() -> int:
	if not show_falling_flakes:
		return 0
	return clampi(3 + int(round(_strength * 5.0)), 3, MAX_FALLING_FLAKES)

func _make_falling_flake(start_above: bool) -> Dictionary:
	var start_y := _rng.randf_range(-0.20, 0.45)
	if start_above:
		start_y = _rng.randf_range(-0.18, -0.02)
	return {
		"pos": Vector2(_rng.randf_range(0.12, 0.88), start_y),
		"velocity": Vector2(_rng.randf_range(-0.012, 0.014), _rng.randf_range(0.42, 0.72 + _strength * 0.22)),
		"landing_y": _rng.randf_range(0.24, 0.82),
		"size": _rng.randf_range(0.040, 0.070 + _strength * 0.018),
		"alpha": _rng.randf_range(0.58, 0.86),
		"atlas_col": _rng.randi_range(0, FLAKE_ATLAS_COLUMNS - 1),
		"atlas_row": _rng.randi_range(2, FLAKE_ATLAS_ROWS - 3),
	}

func _add_landed_flake(uv_pos: Vector2, source_flake: Dictionary) -> void:
	_landing_count += 1
	_landed_flakes.append({
		"pos": uv_pos,
		"size": float(source_flake.get("size", 0.055)) * 1.15,
		"alpha": 0.76 + _strength * 0.16,
		"age": 0.0,
		"lifetime": _rng.randf_range(0.55, 0.95),
		"atlas_col": int(source_flake.get("atlas_col", 0)),
		"atlas_row": int(source_flake.get("atlas_row", 3)),
	})
	while _landed_flakes.size() > MAX_LANDED_FLAKES:
		_landed_flakes.pop_front()
	if allow_melt_on_land:
		_add_melt_patch(uv_pos)
	else:
		_add_snow_patch(uv_pos)

func shake_off_snow(retain_ratio: float = 0.22) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_shake_time < 0.22:
		return
	_last_shake_time = now
	var keep_ratio := clampf(retain_ratio, 0.08, 0.55)
	_landing_count = maxi(1, int(round(float(_landing_count) * keep_ratio))) if _landing_count > 0 else 0
	_surface_accumulation = clampf(_surface_accumulation * keep_ratio, 0.0, 1.0)
	_trim_visual_snow_after_shake(keep_ratio)
	queue_redraw()

func _trim_visual_snow_after_shake(keep_ratio: float) -> void:
	var patch_keep_count := clampi(int(ceil(float(_patches.size()) * keep_ratio)), 0, _patches.size())
	while _patches.size() > patch_keep_count:
		_patches.pop_front()
	for i in range(_patches.size()):
		var patch := _patches[i]
		patch["melts"] = false
		patch["wet"] = 0.0
		patch["snow"] = clampf(float(patch.get("snow", 1.0)) * 0.72, 0.22, 0.68)
		patch["age"] = maxf(float(patch.get("age", 0.0)), 2.0)
		_patches[i] = patch
	var flake_keep_count := clampi(int(ceil(float(_landed_flakes.size()) * keep_ratio)), 0, _landed_flakes.size())
	while _landed_flakes.size() > flake_keep_count:
		_landed_flakes.pop_front()

func _update_landed_flakes(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for flake in _landed_flakes:
		flake["age"] = float(flake.get("age", 0.0)) + delta
		if float(flake.get("age", 0.0)) < float(flake.get("lifetime", 0.9)):
			kept.append(flake)
	_landed_flakes = kept

func _add_melt_patch(uv_pos: Vector2) -> void:
	_patches.append({
		"pos": uv_pos,
		"size": Vector2(_rng.randf_range(0.075, 0.145), _rng.randf_range(0.038, 0.085)),
		"wet": _rng.randf_range(0.10, 0.22),
		"snow": _rng.randf_range(0.72, 1.0),
		"age": 0.0,
		"melts": true,
	})
	while _patches.size() > MAX_PATCHES:
		_patches.pop_front()

func _add_snow_patch(uv_pos: Vector2) -> void:
	_patches.append({
		"pos": uv_pos,
		"size": Vector2(_rng.randf_range(0.090, 0.165), _rng.randf_range(0.045, 0.095)),
		"wet": 0.0,
		"snow": _rng.randf_range(0.78, 1.0),
		"age": 0.0,
		"melts": false,
	})
	while _patches.size() > MAX_PATCHES:
		_patches.pop_front()

func _prune_old_patches() -> void:
	var kept: Array[Dictionary] = []
	for patch in _patches:
		var age := float(patch.get("age", 0.0))
		var wet := float(patch.get("wet", 0.0))
		var melts := bool(patch.get("melts", true))
		var snow := float(patch.get("snow", 1.0))
		if (melts and (age < 9.5 or wet < 0.98)) or (not melts and (age < 13.0 or snow > 0.42)):
			kept.append(patch)
	_patches = kept
