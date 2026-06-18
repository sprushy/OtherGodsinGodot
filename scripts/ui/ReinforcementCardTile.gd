extends PanelContainer
class_name ReinforcementCardTile

signal card_dropped(card_name: String, from_zone: String, to_zone: String)

const ZONE_MAIN := "main"
const ZONE_SIDE := "side"

var card_name: String = ""
var source_zone: String = ZONE_MAIN
var drag_enabled: bool = true

func setup(card: Card, count: int, p_source_zone: String, compact: bool = false) -> void:
	card_name = str(card.card_name) if card != null else ""
	source_zone = p_source_zone
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(172, 236) if not compact else Vector2(250, 58)
	tooltip_text = "Drag to %s" % ["Reinforcements" if source_zone == ZONE_MAIN else "Main Deck"]

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.08, 0.96)
	style.border_color = Color(0.38, 0.58, 0.82, 0.9) if source_zone == ZONE_MAIN else Color(0.78, 0.62, 0.30, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side as Side, 2)
	add_theme_stylebox_override("panel", style)

	if compact:
		_build_compact(card, count)
	else:
		_build_full(card, count)

func _build_full(card: Card, count: int) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var title := Label.new()
	title.text = card_name
	title.clip_text = true
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	box.add_child(title)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(154, 172)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if card != null and not str(card.art_path).strip_edges().is_empty():
		art.texture = load(str(card.art_path))
	box.add_child(art)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(footer)

	var count_label := Label.new()
	count_label.text = "×%d" % count
	count_label.add_theme_font_size_override("font_size", 18)
	footer.add_child(count_label)

func _build_compact(card: Card, count: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	var count_label := Label.new()
	count_label.text = "%dx" % count
	count_label.custom_minimum_size = Vector2(34, 0)
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 18)
	row.add_child(count_label)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(48, 44)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if card != null and not str(card.art_path).strip_edges().is_empty():
		art.texture = load(str(card.art_path))
	row.add_child(art)

	var title := Label.new()
	title.text = card_name
	title.clip_text = true
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	row.add_child(title)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled or card_name.strip_edges().is_empty():
		return null
	var preview := Label.new()
	preview.text = card_name
	preview.add_theme_font_size_override("font_size", 18)
	preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
	set_drag_preview(preview)
	return {
		"type": "reinforcement_card",
		"card_name": card_name,
		"source_zone": source_zone,
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not drag_enabled:
		return false
	if not (data is Dictionary):
		return false
	var payload := data as Dictionary
	if str(payload.get("type", "")) != "reinforcement_card":
		return false
	return str(payload.get("source_zone", "")) != source_zone

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var payload := data as Dictionary
	card_dropped.emit(
		str(payload.get("card_name", "")),
		str(payload.get("source_zone", "")),
		source_zone
	)
