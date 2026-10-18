extends Control

signal impact_landed(board_uv: Vector2, radius_ratio: float, seed_value: float)

## White-hot fire columns and molten impacts, following the Fires of Judgment art.
const FIRE_SHADER := preload("res://shaders/meteor_fire.gdshader")
const BUILDUP := 0.55
const IMPACT_LIFETIME := 1.25
const EMBERS_PER_IMPACT := 18

var _geometry: Callable
var _zones: Array[Rect2] = []
var _meteors: Array[Dictionary] = []
var _elapsed := 0.0
var _duration := 0.0
var _glow: GradientTexture2D
var _landed_count := 0


func play(board_geometry: Callable) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_geometry = board_geometry
	_zones = _geometry.call()
	if _zones.is_empty():
		queue_free()
		return
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.65), Color(1.0, 1.0, 1.0, 0.18), Color.TRANSPARENT])
	_glow = GradientTexture2D.new()
	_glow.gradient = gradient
	_glow.width = 128
	_glow.height = 128
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var delay := BUILDUP
	var cluster := Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.2, 0.8))
	var hero_index := rng.randi_range(15, 23)
	for meteor_index in range(26):
		# Sample the whole battlefield, including gaps. Bursts cluster loosely;
		# no lane is guaranteed a hit and there is no left-to-right sweep.
		if meteor_index % 6 == 0:
			cluster = Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.2, 0.8))
		var impact_uv := Vector2(rng.randf_range(0.025, 0.975), rng.randf_range(0.035, 0.965))
		if rng.randf() < 0.55:
			impact_uv = (cluster + Vector2(rng.randfn(0.0, 0.13), rng.randfn(0.0, 0.20))).clamp(Vector2(0.025, 0.035), Vector2(0.975, 0.965))
		delay += rng.randf_range(0.025, 0.14)
		var hero := meteor_index == hero_index
		var flight := rng.randf_range(0.5, 0.95) if not hero else 1.05
		var sparks: Array[Vector2] = []
		for ember in range(EMBERS_PER_IMPACT):
			var angle := rng.randf_range(-PI, PI)
			sparks.append(Vector2(cos(angle), sin(angle) * 0.6 - 1.0) * rng.randf_range(3.0, 7.0))
		var flame := ColorRect.new()
		flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fire_material := ShaderMaterial.new()
		fire_material.shader = FIRE_SHADER
		fire_material.set_shader_parameter("seed", rng.randf_range(0.0, 100.0))
		flame.material = fire_material
		flame.visible = false
		add_child(flame)
		_meteors.append({
			"offset": impact_uv, "delay": delay, "flight": flight,
			"radius": rng.randf_range(0.09, 0.21) if not hero else 0.34,
			"slant": rng.randf_range(-0.12, 0.32),
			"spin": rng.randf_range(-PI, PI),
			"sparks": sparks, "flame": flame, "landed": false,
		})
		_duration = maxf(_duration, delay + flight + IMPACT_LIFETIME)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration or not _geometry.is_valid():
		queue_free()
		return
	_zones = _geometry.call()
	if _zones.is_empty():
		queue_free()
		return
	var bounds := _get_board_bounds()
	for meteor in _meteors:
		var flame: ColorRect = meteor["flame"]
		var age := _elapsed - float(meteor["delay"])
		var flight := float(meteor["flight"])
		flame.visible = age >= 0.0 and age < flight
		if age >= flight and not bool(meteor["landed"]):
			meteor["landed"] = true
			_landed_count += 1
			if _landed_count >= 2:
				set_meta("grave_departures_allowed", true)
			impact_landed.emit(meteor["offset"], float(meteor["radius"]), float(meteor["spin"]))
		if not flame.visible:
			continue
		var zone_rect := _zones[0]
		var radius := minf(zone_rect.size.x, zone_rect.size.y) * float(meteor["radius"])
		var impact: Vector2 = bounds.position + bounds.size * Vector2(meteor["offset"])
		var fall := Vector2(float(meteor["slant"]), 1.0).normalized()
		var head := _get_flight_head(impact, fall, bounds, zone_rect, age / flight)
		flame.size = Vector2(radius * 6.0, radius * 18.0)
		flame.pivot_offset = flame.size * Vector2(0.5, 0.80)
		flame.position = head - flame.pivot_offset
		flame.rotation = fall.angle() - PI * 0.5
		var fire_material := flame.material as ShaderMaterial
		fire_material.set_shader_parameter("effect_time", age)
		fire_material.set_shader_parameter("intensity", smoothstep(0.0, 0.14, age) * 1.25)
	queue_redraw()


func _get_board_bounds() -> Rect2:
	var bounds := _zones[0]
	for zone_rect in _zones:
		bounds = bounds.merge(zone_rect)
	return bounds


func _get_flight_head(impact: Vector2, fall: Vector2, bounds: Rect2, zone_rect: Rect2, progress: float) -> Vector2:
	var distance := maxf(bounds.size.y * 1.9, zone_rect.size.y * 3.5)
	# Long approach, accelerating into a heavy impact.
	return impact - fall * distance * (1.0 - pow(progress, 1.8))


func _draw() -> void:
	if _zones.is_empty() or _glow == null:
		return
	var bounds := _get_board_bounds()
	var envelope := minf(smoothstep(0.0, BUILDUP, _elapsed), clampf((_duration - _elapsed) / 0.7, 0.0, 1.0))
	_draw_glow(bounds.get_center(), bounds.size * Vector2(0.85, 1.1), Color(0.09, 0.015, 0.008, envelope * 0.7))
	_draw_glow(bounds.get_center(), bounds.size * Vector2(0.7, 0.8), Color(0.8, 0.09, 0.005, envelope * 0.16))
	for meteor in _meteors:
		var age := _elapsed - float(meteor["delay"])
		if age < 0.0:
			continue
		var zone_rect := _zones[0]
		var impact: Vector2 = bounds.position + bounds.size * Vector2(meteor["offset"])
		var radius := minf(zone_rect.size.x, zone_rect.size.y) * float(meteor["radius"])
		var flight := float(meteor["flight"])
		if age < flight:
			var progress := age / flight
			var fall := Vector2(float(meteor["slant"]), 1.0).normalized()
			var head := _get_flight_head(impact, fall, bounds, zone_rect, progress)
			_draw_glow(head, Vector2.ONE * radius * 5.5, Color(1.0, 0.22, 0.01, progress * 0.5))
			_draw_glow(impact, Vector2(radius * 7.0, radius * 3.0), Color(1.0, 0.24, 0.01, pow(progress, 3.0) * 0.65))
			_draw_falling_embers(head, fall, radius, age, float(meteor["spin"]))
		else:
			_draw_impact(impact, radius, age - flight, meteor)


func _draw_falling_embers(head: Vector2, fall: Vector2, radius: float, age: float, seed_value: float) -> void:
	for ember in range(8):
		var phase := fposmod(age * 1.7 + float(ember) * 0.137, 1.0)
		var across := sin(seed_value + float(ember) * 7.3) * radius * phase * 2.5
		var point := head - fall * radius * (2.0 + phase * 13.0) + fall.orthogonal() * across
		draw_line(point, point - fall * radius * (0.3 + phase), Color(1.0, 0.45, 0.045, (1.0 - phase) * 0.8), maxf(1.0, radius * 0.065), true)


func _draw_impact(center: Vector2, radius: float, age: float, meteor: Dictionary) -> void:
	if age >= IMPACT_LIFETIME:
		return
	var progress := age / IMPACT_LIFETIME
	var fade := 1.0 - smoothstep(0.45, 1.0, progress)
	var blast := 1.0 - smoothstep(0.0, 0.28, age)
	_draw_glow(center, Vector2(radius * 6.0, radius * 2.6), Color(0.025, 0.008, 0.004, fade * 0.85))
	_draw_glow(center, Vector2(radius * 13.0, radius * 7.0), Color(1.0, 0.20, 0.008, blast * 0.75))
	_draw_glow(center, Vector2.ONE * radius * (2.0 + progress * 3.0), Color(1.0, 0.94, 0.65, blast))
	# Uneven pools of heat and ash replace the geometric rings and straight cracks.
	for pool in range(8):
		var angle := float(pool) * 2.399 + float(meteor["spin"])
		var offset := Vector2(cos(angle), sin(angle) * 0.45) * radius * (0.4 + float(pool % 3))
		_draw_glow(center + offset, Vector2(radius * 1.4, radius * 0.6), Color(0.9, 0.12 + float(pool % 2) * 0.14, 0.008, fade * blast * 0.35))
	var sparks: Array = meteor["sparks"]
	for spark_index in range(sparks.size()):
		var velocity: Vector2 = sparks[spark_index] * radius
		var point := center + velocity * age + Vector2(0.0, radius * 5.0 * age * age)
		var trail := (velocity + Vector2(0.0, radius * 10.0 * age)) * 0.045
		if spark_index % 3 == 0:
			draw_circle(point, radius * 0.09 * fade, Color(0.11, 0.045, 0.017, fade))
		draw_line(point - trail, point, Color(1.0, 0.4, 0.025, fade * (1.0 - progress)), maxf(0.8, radius * 0.06), true)
		if spark_index % 4 == 0:
			_draw_glow(point, Vector2.ONE * radius * 0.6, Color(1.0, 0.28, 0.01, fade * 0.5))
	for puff in range(5):
		var drift := Vector2(sin(float(meteor["spin"]) + float(puff) * 2.0) * radius * age * 1.7, -radius * age * (1.6 + float(puff) * 0.65))
		_draw_glow(center + drift, Vector2.ONE * radius * (1.3 + progress * 3.0), Color(0.08, 0.065, 0.055, sin(progress * PI) * 0.27))


func _draw_glow(center: Vector2, extent: Vector2, color: Color) -> void:
	draw_texture_rect(_glow, Rect2(center - extent, extent * 2.0), false, color)
