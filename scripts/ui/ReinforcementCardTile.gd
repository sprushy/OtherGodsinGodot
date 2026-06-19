extends PanelContainer
class_name ReinforcementCardTile

signal card_dropped(card_name: String, from_zone: String, to_zone: String)
signal card_adjust_requested(card_name: String, source_zone: String, direction: int)
signal card_drag_started(card_name: String, source_zone: String, global_position: Vector2)
signal card_hover_started(card_name: String, source_zone: String, tile: Control)
signal card_hover_ended(card_name: String, source_zone: String, tile: Control)

const ZONE_MAIN := "main"
const ZONE_SIDE := "side"

var card_name: String = ""
var source_zone: String = ZONE_MAIN
var drag_enabled: bool = true
var adjust_enabled: bool = true
var custom_drag_signal_enabled: bool = false
var adjust_moves_between_zones: bool = true

func setup(card: Card, count: int, p_source_zone: String, compact: bool = false, other_count: int = 0) -> void:
	card_name = str(card.card_name) if card != null else ""
	source_zone = p_source_zone
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(172, 246) if not compact else Vector2(250, 62)
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
		_build_compact(card, count, other_count)
	else:
		_build_full(card, count, other_count)

func _build_full(card: Card, count: int, other_count: int) -> void:
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
	footer.add_theme_constant_override("separation", 8)
	box.add_child(footer)

	footer.add_child(_make_adjust_button("−", -1, count > 0))

	var count_label := Label.new()
	count_label.text = "×%d" % count
	count_label.add_theme_font_size_override("font_size", 18)
	footer.add_child(count_label)

	footer.add_child(_make_adjust_button("+", 1, other_count > 0))

func _build_compact(card: Card, count: int, other_count: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	row.add_child(_make_adjust_button("−", -1, count > 0))

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

	row.add_child(_make_adjust_button("+", 1, other_count > 0))

func _make_adjust_button(label: String, direction: int, has_source_copy: bool) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(30, 28)
	btn.disabled = not adjust_enabled or not has_source_copy
	btn.tooltip_text = _get_adjust_tooltip(direction)
	btn.pressed.connect(func() -> void:
		card_adjust_requested.emit(card_name, source_zone, direction)
	)
	return btn

func _get_adjust_tooltip(direction: int) -> String:
	if not adjust_moves_between_zones:
		var zone_label := "Main Deck" if source_zone == ZONE_MAIN else "Reinforcements"
		if direction < 0:
			return "Remove one copy from %s." % zone_label
		return "Add one copy to %s." % zone_label
	var this_label := "Main Deck" if source_zone == ZONE_MAIN else "Reinforcements"
	var other_label := "Reinforcements" if source_zone == ZONE_MAIN else "Main Deck"
	if direction < 0:
		return "Move one from %s to %s." % [this_label, other_label]
	return "Move one from %s to %s." % [other_label, this_label]

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

func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if not custom_drag_signal_enabled or not drag_enabled or card_name.strip_edges().is_empty():
		return
	card_drag_started.emit(card_name, source_zone, mouse_event.global_position)
	accept_event()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			if not card_name.strip_edges().is_empty():
				card_hover_started.emit(card_name, source_zone, self)
		NOTIFICATION_MOUSE_EXIT:
			card_hover_ended.emit(card_name, source_zone, self)

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
