extends Control

signal impact_landed

## A separate, immediate targeted strike with a brief return stroke and afterimage.
const DURATION := 0.72
const STROKE_TIMES := [0.015, 0.075, 0.135]

var _geometry: Callable
var _target: Dictionary = {}
var _elapsed := 0.0
var _strokes: Array[Dictionary] = []
var _sparks: Array[Vector2] = []
var _glow: GradientTexture2D
var _landed := false


func play(target_geometry: Callable) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_geometry = target_geometry
	_target = _geometry.call()
	if _target.is_empty():
		queue_free()
		return
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.40, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.75), Color(1.0, 1.0, 1.0, 0.14), Color.TRANSPARENT])
	_glow = GradientTexture2D.new()
	_glow.gradient = gradient
	_glow.width = 128
	_glow.height = 128
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for stroke_index in range(STROKE_TIMES.size()):
		# Normalized, subdivided paths preserve exact contact through resizes.
		var trunk := _branch(Vector2(rng.randf_range(-0.08, 0.08), -1.0), Vector2.ZERO, 5, 0.065, rng)
		var forks: Array[PackedVector2Array] = []
		for fork_index in range(6):
			var origin: Vector2 = trunk[rng.randi_range(5, trunk.size() - 5)]
			var side := -1.0 if fork_index % 2 == 0 else 1.0
			var end := origin + Vector2(side * rng.randf_range(0.04, 0.12), rng.randf_range(0.06, 0.16))
			forks.append(_branch(origin, end, 3, 0.02, rng))
		_strokes.append({"trunk": trunk, "forks": forks})
	for spark_index in range(28):
		var angle := rng.randf_range(-PI, PI)
		_sparks.append(Vector2(cos(angle), sin(angle) * 0.65 - 0.8) * rng.randf_range(0.4, 1.2))
	queue_redraw()


func _branch(start: Vector2, end: Vector2, depth: int, jitter: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array([start, end])
	for level in range(depth):
		var divided := PackedVector2Array()
		for point_index in range(points.size() - 1):
			var a := points[point_index]
			var b := points[point_index + 1]
			divided.append(a)
			divided.append((a + b) * 0.5 + Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter) * 0.18))
		divided.append(end)
		points = divided
		jitter *= 0.48
	return points


func _process(delta: float) -> void:
	_elapsed += delta
	if not _landed and _elapsed >= float(STROKE_TIMES[0]):
		_landed = true
		set_meta("grave_departures_allowed", true)
		impact_landed.emit()
	if _elapsed >= DURATION or not _geometry.is_valid():
		queue_free()
		return
	var live_target: Dictionary = _geometry.call()
	if not live_target.is_empty():
		_target = live_target
	queue_redraw()


func _draw() -> void:
	if _target.is_empty() or _glow == null:
		return
	var center: Vector2 = _target["center"]
	var card_size: Vector2 = _target["size"]
	var unit := minf(card_size.x, card_size.y)
	var span := maxf(card_size.y * 2.8, absf(center.y) * 0.8)
	var strongest := 0.0
	for stroke_index in range(_strokes.size()):
		var age := _elapsed - float(STROKE_TIMES[stroke_index])
		if age < 0.0:
			continue
		var strength := exp(-age * 24.0)
		strongest = maxf(strongest, strength)
		if strength < 0.006:
			continue
		var stroke: Dictionary = _strokes[stroke_index]
		var points := _to_board(stroke["trunk"], center, span)
		_draw_bolt(points, unit * 0.014, strength)
		var forks: Array = stroke["forks"]
		for fork_index in range(forks.size()):
			_draw_bolt(_to_board(forks[fork_index], center, span), unit * 0.0045, strength * 0.65)
	if _elapsed >= float(STROKE_TIMES[0]):
		var impact_age := _elapsed - float(STROKE_TIMES[0])
		_draw_glow(center, Vector2(unit * 0.8, unit * 0.6), Color(0.2, 0.46, 1.0, strongest * 0.8))
		_draw_glow(center, Vector2.ONE * unit * 0.38, Color(1.0, 0.96, 0.82, strongest))
		_draw_glow(center, Vector2(unit * 0.75, unit * 0.04), Color(0.65, 0.8, 1.0, strongest * 0.75))
		for spark_index in range(_sparks.size()):
			var velocity := _sparks[spark_index] * unit
			var point := center + velocity * impact_age + Vector2(0.0, unit * impact_age * impact_age * 0.6)
			var trail := (velocity + Vector2(0.0, unit * impact_age * 1.2)) * 0.035
			var alpha := (1.0 - smoothstep(0.10, 0.48, impact_age)) * (0.55 + 0.45 * sin(float(spark_index) * 9.0 + impact_age * 11.0))
			var color := Color(1.0, 0.68, 0.25, alpha) if spark_index % 3 == 0 else Color(0.65, 0.83, 1.0, alpha)
			draw_line(point - trail, point, color, maxf(0.8, unit * 0.003), true)
			if spark_index % 4 == 0:
				_draw_glow(point, Vector2.ONE * unit * 0.035, color)


func _to_board(path: PackedVector2Array, center: Vector2, span: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in path:
		points.append(center + point * span)
	return points


func _draw_bolt(points: PackedVector2Array, width: float, strength: float) -> void:
	draw_polyline(points, Color(0.20, 0.36, 1.0, strength * 0.08), maxf(2.0, width * 12.0), true)
	draw_polyline(points, Color(0.35, 0.60, 1.0, strength * 0.23), maxf(1.5, width * 5.0), true)
	draw_polyline(points, Color(0.65, 0.85, 1.0, strength * 0.8), maxf(1.0, width * 2.0), true)
	draw_polyline(points, Color(1.0, 0.99, 0.94, strength), maxf(0.65, width), true)


func _draw_glow(center: Vector2, extent: Vector2, color: Color) -> void:
	draw_texture_rect(_glow, Rect2(center - extent, extent * 2.0), false, color)
