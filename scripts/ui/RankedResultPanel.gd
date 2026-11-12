extends PanelContainer

const TITLE_FONT = preload("res://fonts/custom_ui/Norsebold.otf")
const GOLD := Color("f3cb7a")
const CORAL := Color("f18b83")
const SILVER := Color("b9cbe0")
const ANIMATION_DURATION := 1.25
const RANK_REVEAL_TIME := 0.52

var _result: Dictionary
var _delta: int
var _rank_changed: bool
var _accent: Color
var _time := ANIMATION_DURATION
var _rank_label: Label
var _progress_label: Label
var _star_row: Control

func build(result: Dictionary, animate: bool) -> void:
	_result = result
	_delta = int(result["star_delta"])
	_rank_changed = result["previous_rank_name"] != result["rank_name"]
	_accent = GOLD if _delta > 0 else (CORAL if _delta < 0 else SILVER)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171b28").lerp(_accent, 0.065)
	style.border_color = Color(_accent, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	var best_of := int(result.get("best_of", 0))
	var heading := "Bo%d Ranked Progress" % best_of if best_of > 0 else "Ranked Progress"
	_label(column, heading, 14, SILVER)
	_rank_label = _label(column, "", 34, _accent)
	_rank_label.add_theme_font_override("font", TITLE_FONT)
	_star_row = Control.new()
	_star_row.custom_minimum_size.y = 52
	_star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star_row.draw.connect(_draw_stars)
	column.add_child(_star_row)
	_progress_label = _label(column, "", 14, SILVER)
	_label(column, _result_text(), 19, _accent)

	_set_animation_time(0.0 if animate else ANIMATION_DURATION)
	if animate:
		create_tween().tween_method(_set_animation_time, 0.0, ANIMATION_DURATION, ANIMATION_DURATION).set_delay(0.22)

func _label(parent: Node, text: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _result_text() -> String:
	if _delta == 0:
		return "0 stars · Rank protected" if bool(_result["loss_protected"]) else "0 stars · Draw"
	var change := "+%d" % _delta if _delta > 0 else "−%d" % absi(_delta)
	change += " star" if absi(_delta) == 1 else " stars"
	if _rank_changed:
		change += " · Promoted" if _delta > 0 else " · Demoted"
	elif _delta > 1:
		change += " · Win streak"
	return change

func _set_animation_time(time: float) -> void:
	_time = time
	var show_previous := _rank_changed and time < RANK_REVEAL_TIME
	var rank_name := str(_result["previous_rank_name"] if show_previous else _result["rank_name"])
	if _rank_label.text != rank_name:
		_rank_label.text = rank_name
	var count := int(_result["stars"])
	var required := int(_result["stars_required"])
	if time < RANK_REVEAL_TIME:
		count = int(_result["previous_stars"])
		required = int(_result["previous_stars_required"])
	var progress_text := "%d / %d stars" % [count, required] if required > 0 else "%d Mythic stars" % count
	if _progress_label.text != progress_text:
		_progress_label.text = progress_text
	var reveal := clampf((time - RANK_REVEAL_TIME) / 0.42, 0.0, 1.0)
	_rank_label.pivot_offset = _rank_label.size * 0.5
	_rank_label.scale = Vector2.ONE * (1.0 + (0.13 * sin(PI * reveal) if _rank_changed else 0.0))
	_star_row.queue_redraw()

func _draw_stars() -> void:
	var center := _star_row.size * 0.5
	var required := int(_result["stars_required"])
	var start_stars := int(_result["previous_stars"])
	var target_stars := int(_result["stars"])
	var elapsed := _time
	if _rank_changed:
		if _time < RANK_REVEAL_TIME:
			required = int(_result["previous_stars_required"])
			target_stars = required if _delta > 0 else start_stars
		else:
			elapsed -= RANK_REVEAL_TIME
			# On demotion, show the lost star in the lower division as it burns away.
			start_stars = 0 if _delta > 0 else target_stars + absi(_delta)
	if required == 0:
		var pulse := sin(PI * clampf(elapsed / 0.62, 0.0, 1.0)) if _delta != 0 else 0.0
		_draw_star(center, 22.0 * (1.0 + 0.28 * pulse), _accent)
		_draw_sparks(center, elapsed / 0.66, _delta < 0)
	else:
		var spacing := minf(50.0, _star_row.size.x / float(required + 1))
		for i in range(required):
			var point := center + Vector2((i - (required - 1) * 0.5) * spacing, 0.0)
			_draw_star(point, 18.0, Color("4a5365"), true)
			if i < mini(start_stars, target_stars):
				_draw_star(point, 18.0, GOLD)
			elif i < target_stars:
				var arrival := clampf((elapsed - 0.06 - 0.08 * (i - start_stars)) / 0.32, 0.0, 1.0)
				if arrival > 0.0:
					var bounce := lerpf(0.65, 1.0, arrival) + 0.38 * sin(PI * arrival)
					_draw_star(point - Vector2(0, 14.0 * (1.0 - arrival)), 18.0 * bounce, Color(GOLD, minf(1.0, arrival * 3.0)))
					_draw_sparks(point, arrival, false)
			elif i < start_stars:
				var fall := clampf((elapsed - 0.09) / 0.44, 0.0, 1.0)
				if fall < 1.0:
					_draw_star(point + Vector2(0, 12.0 * fall), 18.0 * (1.0 - 0.4 * fall), Color(GOLD.lerp(CORAL, fall), 1.0 - fall))
					_draw_sparks(point, fall, true)
	if _rank_changed and _delta > 0:
		var shockwave := (_time - RANK_REVEAL_TIME) / 0.47
		if shockwave > 0.0 and shockwave < 1.0:
			_star_row.draw_arc(center, lerpf(18.0, 78.0, shockwave), 0, TAU, 40, Color(GOLD, 0.65 * (1.0 - shockwave)), 1.5, true)
			_draw_sparks(center, shockwave, false)
	elif bool(_result["loss_protected"]):
		var glint := (_time - 0.1) / 0.64
		if glint > 0.0 and glint < 1.0:
			_star_row.draw_arc(center, lerpf(16.0, 64.0, glint), 0, TAU, 36, Color(SILVER, 0.42 * sin(PI * glint)), 1.5, true)

func _draw_star(center: Vector2, radius: float, tint: Color, hollow: bool = false) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var angle := -PI / 2.0 + i * TAU / 10.0
		points.append(center + Vector2.from_angle(angle) * radius * (1.0 if i % 2 == 0 else 0.45))
	if not hollow:
		_star_row.draw_circle(center, radius * 1.25, Color(tint, tint.a * 0.1), true, -1.0, true)
		_star_row.draw_colored_polygon(points, tint)
		_star_row.draw_colored_polygon(PackedVector2Array([center, points[0], points[1], points[2]]), tint.lightened(0.28))
	points.append(points[0])
	_star_row.draw_polyline(points, tint.lightened(0.25), 1.25, true)

func _draw_sparks(center: Vector2, phase: float, falling: bool) -> void:
	if phase <= 0.0 or phase >= 1.0:
		return
	var tint := CORAL if falling else GOLD
	for i in range(8):
		var direction := Vector2.from_angle(i * TAU / 8.0)
		var point := center + direction * (9.0 + phase * (22.0 + 3.0 * (i % 3)))
		if falling:
			point.y += 22.0 * phase
		var spark_color := Color(tint, (1.0 - phase) * 0.8)
		_star_row.draw_line(point, point + direction * (5.0 - phase * 3.0), spark_color, 1.5, true)
