extends Control

const Catalog = preload("res://scripts/core/RankBadgeCatalog.gd")
const TextureCache = preload("res://scripts/ui/UITextureCache.gd")
const COLORS := [
	Color("aeb8c4"), Color("cb8d64"), Color("d1e5f3"), Color("f1c467"),
	Color("7fe3f7"), Color("b69cf5"), Color("ffe7a3"),
]
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

func get_crop_center_after_drag(relative: Vector2) -> Vector2:
	if _texture == null:
		return Vector2(0.5, 0.5)
	var crop_size := _get_crop_size()
	var travel := _texture.get_size() - Vector2.ONE * crop_size
	var center := Vector2(_crop["x"], _crop["y"])
	var image_delta := relative * crop_size / (minf(size.x, size.y) * 0.88)
	if travel.x > 0.0:
		center.x = clampf(center.x - image_delta.x / travel.x, 0.0, 1.0)
	if travel.y > 0.0:
		center.y = clampf(center.y - image_delta.y / travel.y, 0.0, 1.0)
	return center

func _get_crop_size() -> float:
	return minf(_texture.get_width(), _texture.get_height()) / float(_crop["zoom"])

func _draw() -> void:
	if _league < 0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var extent := minf(size.x, size.y)
	var offset := (size - Vector2.ONE * extent) * 0.5
	var center := offset + Vector2.ONE * extent * 0.5
	var rim: Color = COLORS[_league]
	var outline := PackedVector2Array()
	var portrait := PackedVector2Array()
	var uv := PackedVector2Array()
	var crop_size := _get_crop_size() if _texture != null else 0.0
	var image_size := _texture.get_size() if _texture != null else Vector2.ONE
	var origin := (image_size - Vector2.ONE * crop_size) * Vector2(_crop.get("x", 0.5), _crop.get("y", 0.5))
	for point: Vector2 in SHIELD:
		var border_point := offset + point * extent
		outline.append(border_point)
		portrait.append(center.lerp(border_point, 0.88))
		uv.append((origin + point * crop_size) / image_size)
	draw_colored_polygon(outline, rim.darkened(0.54))
	if _texture != null:
		draw_polygon(portrait, PackedColorArray([Color.WHITE]), uv, _texture)
	else:
		draw_colored_polygon(portrait, Color("202735"))
	outline.append(outline[0])
	draw_polyline(outline, rim, maxf(1.0, extent * 0.037), true)
	var division := _rank_name.get_slice(" ", 1)
	if division.is_empty():
		division = "✦"
	var font := ThemeDB.fallback_font
	var font_size := maxi(8, roundi(extent * 0.21))
	var text_width := font.get_string_size(division, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var plaque_size := Vector2(text_width + extent * 0.16, extent * 0.23)
	var plaque := Rect2(Vector2(center.x - plaque_size.x * 0.5, offset.y + extent * 0.75), plaque_size)
	draw_rect(plaque, Color("181722"))
	draw_rect(plaque, rim, false, 1.0)
	var baseline := plaque.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(center.x - text_width * 0.5, baseline), division, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, rim)
