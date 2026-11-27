extends Control

const Catalog = preload("res://scripts/core/RankBadgeCatalog.gd")
const TextureCache = preload("res://scripts/ui/UITextureCache.gd")
const BloodStreaksScript = preload("res://scripts/ui/BloodStreaks.gd")
const RankedProgression = preload("res://scripts/server/RankedProgression.gd")
const PORTRAIT_SCALE := 0.88
const DIVINE_SHIELD_SCALE := 0.84
const DIVINE_HIGHLIGHT := Color("fff5cd")
const DIVINE_SHADOW := Color("2b1531")
const SHIELD := [
	Vector2(0.50, 0.03), Vector2(0.90, 0.19), Vector2(0.95, 0.36),
	Vector2(0.89, 0.74), Vector2(0.50, 0.98), Vector2(0.11, 0.74),
	Vector2(0.05, 0.36), Vector2(0.10, 0.19),
]

var _rank_name := ""
var _league := -1
var _selection := {}
var _crop := {}
var _texture: Texture2D
var _series_wins := -1
var _series_win_streaks: Array[TextureRect] = []

func _ready() -> void:
	resized.connect(queue_redraw)

func set_badge(rank_name: String, portrait: Dictionary) -> void:
	if _rank_name == rank_name and _selection == portrait:
		return
	_rank_name = rank_name
	_selection = portrait.duplicate()
	_league = Catalog.league_for_rank(rank_name)
	_crop = Catalog.resolve_portrait(_league, portrait)
	_texture = null
	if not _crop.is_empty():
		var card: Card = Catalog.get_cards(_league)[_crop["card"]]
		var art_path: String = Catalog.art_paths(card)[_crop["art"]]
		if ResourceLoader.exists(art_path, "Texture2D"):
			_texture = TextureCache.get_texture(art_path)
	tooltip_text = "%s · %s" % [_rank_name, _crop["card"]] if not _crop.is_empty() else _rank_name
	queue_redraw()

## Necoc Yaotl-style blood streaks marking this player's wins in a Bo3 series.
## Call every frame if convenient; the no-change case is a plain early-out.
func set_series_wins(wins: int) -> void:
	var resolved := maxi(0, wins)
	if _series_wins == resolved:
		return
	_series_wins = resolved
	for streak in _series_win_streaks:
		if is_instance_valid(streak):
			streak.queue_free()
	_series_win_streaks.clear()
	if resolved > 0:
		_series_win_streaks = BloodStreaksScript.attach(self, resolved)

func get_crop_center_after_drag(relative: Vector2) -> Vector2:
	if _texture == null:
		return Vector2(0.5, 0.5)
	var crop_size := _get_crop_size()
	var travel := _texture.get_size() - Vector2.ONE * crop_size
	var center := Vector2(_crop["x"], _crop["y"])
	var portrait_extent := minf(size.x, size.y) * _get_shield_scale() * PORTRAIT_SCALE
	if portrait_extent <= 0.0:
		return center
	var image_delta := relative * crop_size / portrait_extent
	if travel.x > 0.0:
		center.x = clampf(center.x - image_delta.x / travel.x, 0.0, 1.0)
	if travel.y > 0.0:
		center.y = clampf(center.y - image_delta.y / travel.y, 0.0, 1.0)
	return center

func _get_crop_size() -> float:
	return minf(_texture.get_width(), _texture.get_height()) / float(_crop["zoom"])

func _get_shield_scale() -> float:
	return DIVINE_SHIELD_SCALE if _league == RankedProgression.DIVINE else 1.0

func _draw() -> void:
	if _league < 0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var extent := minf(size.x, size.y)
	var center := size * 0.5
	var rim: Color = Catalog.LEAGUE_COLORS[_league]
	var divine := _league == RankedProgression.DIVINE
	if divine:
		_draw_divine_halo(center, extent, rim)
	_draw_shield(center, extent, rim, divine)
	_draw_plaque(center, extent, rim, divine)

func _draw_shield(center: Vector2, extent: float, rim: Color, divine: bool) -> void:
	var shield_extent := extent * _get_shield_scale()
	var shadow := DIVINE_SHADOW if divine else rim.darkened(0.82)
	var highlight := DIVINE_HIGHLIGHT if divine else rim.lightened(0.48)
	var bevel_shadow := rim.darkened(0.34)
	var outline := PackedVector2Array()
	var bevel_colors := PackedColorArray()
	var liner := PackedVector2Array()
	var portrait := PackedVector2Array()
	var uv := PackedVector2Array()
	var crop_size := _get_crop_size() if _texture != null else 0.0
	var image_size := _texture.get_size() if _texture != null else Vector2.ONE
	var origin := (image_size - Vector2.ONE * crop_size) * Vector2(_crop.get("x", 0.5), _crop.get("y", 0.5))
	for point: Vector2 in SHIELD:
		var local := (point - Vector2(0.5, 0.5)) * shield_extent
		outline.append(center + local)
		bevel_colors.append(highlight.lerp(bevel_shadow, point.y))
		liner.append(center + local * 0.93)
		portrait.append(center + local * PORTRAIT_SCALE)
		uv.append((origin + point * crop_size) / image_size)
	draw_polygon(outline, bevel_colors)
	draw_colored_polygon(liner, shadow)
	if _texture != null:
		draw_polygon(portrait, PackedColorArray([Color.WHITE]), uv, _texture)
	else:
		draw_colored_polygon(portrait, shadow.lightened(0.09))
	_stroke_polygon(outline, shadow, maxf(0.8, extent * 0.018))
	draw_polyline(PackedVector2Array([outline[7], outline[0], outline[1]]),
		highlight, maxf(0.8, extent * 0.018), true)

func _draw_divine_halo(center: Vector2, extent: float, rim: Color) -> void:
	var radius := extent * 0.425
	draw_circle(center, radius, DIVINE_SHADOW, true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, 48, rim.darkened(0.45), maxf(1.0, extent * 0.034), true)
	draw_arc(center, radius, PI, TAU, 24, rim, maxf(0.8, extent * 0.015), true)
	for i in range(8):
		var direction := Vector2.UP.rotated(i * TAU / 8.0)
		var tangent := direction.orthogonal() * extent * 0.054
		var base := center + direction * extent * 0.398
		var tip := center + direction * extent * (0.487 if i % 2 == 0 else 0.47)
		var root := center + direction * extent * 0.34
		var ray := PackedVector2Array([tip, base + tangent, root, base - tangent])
		draw_polygon(ray, PackedColorArray([DIVINE_HIGHLIGHT, rim, rim.darkened(0.36), rim]))

func _draw_plaque(badge_center: Vector2, extent: float, rim: Color, divine: bool) -> void:
	var division := _rank_name.get_slice(" ", 1)
	var font := ThemeDB.fallback_font
	var font_size := maxi(8, roundi(extent * 0.22))
	var text_width := font.get_string_size(division, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var half_width := maxf(extent * 0.19, text_width * 0.5 + extent * 0.09)
	var half_height := maxf(extent * 0.115, font.get_height(font_size) * 0.5)
	var center := badge_center + Vector2.DOWN * minf(extent * 0.34, extent * 0.48 - half_height)
	var cut := extent * 0.06
	var plaque := PackedVector2Array([
		center + Vector2(-half_width + cut, -half_height), center + Vector2(half_width - cut, -half_height),
		center + Vector2(half_width, 0.0), center + Vector2(half_width - cut, half_height),
		center + Vector2(-half_width + cut, half_height), center + Vector2(-half_width, 0.0),
	])
	var ink := DIVINE_HIGHLIGHT if divine else rim.lightened(0.34)
	draw_colored_polygon(plaque, DIVINE_SHADOW if divine else Color("15141d"))
	_stroke_polygon(plaque, rim, maxf(0.8, extent * 0.015))
	if division.is_empty():
		_draw_star(center, extent * 0.095, ink)
		return
	var baseline := center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(center.x - text_width * 0.5, baseline), division,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var star := PackedVector2Array()
	for i in range(8):
		var length := radius if i % 2 == 0 else radius * 0.38
		star.append(center + Vector2.UP.rotated(i * TAU / 8.0) * length)
	draw_colored_polygon(star, color)
	_stroke_polygon(star, color, 0.8)

func _stroke_polygon(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)
