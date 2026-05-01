class_name CardDetailContentBuilder
extends RefCounted

const _BULLET_SEPARATOR := " | "
const _BOARD_POPUP_WIDTH := 210.0
const _KEYWORD_PANEL_WIDTH := 210.0

static func build_visual_hover_body(card: Card, viewer: Player, config: Dictionary = {}) -> Control:
	var content_width := float(config.get("content_width", 300.0))
	var display_mana_cost := int(config.get("display_mana_cost", card.mana_cost))
	var display_cost_adjustment_lines: Array[String] = _to_string_array(config.get("display_cost_adjustment_lines", []))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.custom_minimum_size = Vector2(content_width, 0.0)

	var vbox := _make_vbox(content_width, 4)
	scroll.add_child(vbox)

	var name_lbl := _make_label(
		card.get_display_name_for_control(),
		15,
		Color(1.0, 0.95, 0.7),
		true
	)
	vbox.add_child(name_lbl)

	if card.card_types.size() > 0:
		var type_lbl := _make_label(
			_BULLET_SEPARATOR.join(card.card_types),
			14,
			Color(0.7, 0.85, 1.0),
			true
		)
		vbox.add_child(type_lbl)

	var meta_parts: Array[String] = []
	if not card.is_god and card.get_effective_level() > 0:
		meta_parts.append("Level " + str(card.get_effective_level()))
	meta_parts.append("Mana: " + str(display_mana_cost))
	if card.culture != "":
		meta_parts.append(card.culture)
	if not meta_parts.is_empty():
		var meta_lbl := _make_label("  |  ".join(meta_parts), 14, Color(0.65, 0.65, 0.65), false)
		vbox.add_child(meta_lbl)

	match card.card_type:
		Card.CardType.GOD:
			pass
		Card.CardType.CREATURE:
			var stats_lbl := _make_label(
				"STR: %d   RES: %d   SPD: %d" % [
					card.get_effective_strength(),
					card.get_effective_resilience(),
					card.get_effective_speed()
				],
				16
			)
			var tip_parts: Array[String] = []
			for entry in [["STR", "str"], ["RES", "res"], ["SPD", "spd"]]:
				var breakdown := card.get_full_stat_breakdown(entry[1])
				if breakdown != "":
					tip_parts.append(entry[0] + ": " + breakdown)
			if tip_parts.size() > 0:
				stats_lbl.tooltip_text = "\n".join(tip_parts)
				stats_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
			vbox.add_child(stats_lbl)
		Card.CardType.STRUCTURE:
			vbox.add_child(_make_label("RES: %d" % card.resilience, 16))
		Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM:
			vbox.add_child(_make_label("Speed: %d" % card.speed, 16))

	if card.has_additional_costs():
		vbox.add_child(_make_label(
			"Extra Costs: " + " ".join(card.get_cost_shorthand_parts(0)),
			14,
			Color(1.0, 0.6, 0.4)
		))

	if not display_cost_adjustment_lines.is_empty():
		var summon_cost_lbl := _make_label(
			"\n".join(display_cost_adjustment_lines),
			14,
			Color(1.0, 0.72, 0.72),
			true
		)
		summon_cost_lbl.custom_minimum_size = Vector2(210.0, 0.0)
		vbox.add_child(summon_cost_lbl)

	if card.ability_text != "" or card.flavor_text != "":
		vbox.add_child(_make_separator(Color(0.3, 0.3, 0.5)))

	if card.ability_text != "":
		var ability_lbl := _make_rich_text(
			BaseCard.apply_keyword_hints(card.ability_text),
			17,
			Color(0.9, 0.85, 1.0),
			210.0
		)
		vbox.add_child(ability_lbl)

	if card.flavor_text != "":
		vbox.add_child(_make_label(card.flavor_text, 14, Color(0.6, 0.6, 0.6), true))

	var hover_details := card.get_hover_detail_lines(viewer)
	if hover_details.size() > 0:
		vbox.add_child(_make_separator(Color(0.22, 0.45, 0.4)))
		var detail_lbl := _make_rich_text(
			"\n".join(hover_details),
			14,
			Color(0.72, 0.96, 0.86),
			210.0
		)
		vbox.add_child(detail_lbl)

	_add_hover_stored_card_section(vbox, card, viewer, content_width)

	return scroll

static func build_board_popup_body(card: Card, viewer: Player, config: Dictionary = {}) -> Control:
	var is_hidden_card := bool(config.get("is_hidden_card", false))
	var type_label := str(config.get("type_label", ""))
	var effect_lines: Array[String] = _to_string_array(config.get("effect_lines", []))
	var equipment_lines: Array[String] = _to_string_array(config.get("equipment_lines", []))
	var binding_lines: Array[String] = _to_string_array(config.get("binding_lines", []))
	var cost_lines: Array[String] = _to_string_array(config.get("cost_lines", []))
	var power_cost_lines: Array[String] = _to_string_array(config.get("power_cost_lines", []))
	var game_manager = config.get("game_manager", null)

	var vbox := _make_vbox(_BOARD_POPUP_WIDTH, 4)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header_row)

	var name_lbl := _make_label(
		card.get_display_name_for_control() if not is_hidden_card else "???",
		15
	)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(name_lbl)

	if not is_hidden_card and card.culture != "":
		var culture_lbl := _make_label(card.culture, 13, Color(0.96, 0.88, 0.62))
		culture_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header_row.add_child(culture_lbl)

	if not is_hidden_card:
		var type_parts: Array[String] = []
		if type_label != "":
			type_parts.append(type_label)
		for card_type_name in card.card_types:
			if card_type_name not in type_parts:
				type_parts.append(card_type_name)
		if type_parts.size() > 0:
			vbox.add_child(_make_label(
				_BULLET_SEPARATOR.join(type_parts),
				13,
				Color(1.0, 0.55, 0.55) if card.is_petrified() else Color(0.7, 0.85, 1.0),
				true
			))

		if card.is_petrified():
			vbox.add_child(_make_label(
				"Status: Petrified Creature",
				13,
				Color(1.0, 0.35, 0.35)
			))
		if card.is_muted and card.mute_turns_remaining > 0:
			vbox.add_child(_make_label(
				"Status: Muted (%d turn%s)" % [
					card.mute_turns_remaining,
					"" if card.mute_turns_remaining == 1 else "s"
				],
				13,
				Color(1.0, 0.78, 0.86)
			))

	if not is_hidden_card and not card.is_god:
		var level_lbl := _make_label("Level %d" % card.get_effective_level(), 13, Color(0.7, 0.7, 0.7))
		var level_breakdown := card.get_buff_tooltip("lvl")
		if card.get_effective_level() > card.level:
			level_lbl.modulate = Color(0.4, 1.0, 0.4)
			if level_breakdown != "":
				level_lbl.tooltip_text = "LVL:\n" + level_breakdown
				level_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		elif card.get_effective_level() < card.level:
			level_lbl.modulate = Color(1.0, 0.35, 0.35)
			if level_breakdown != "":
				level_lbl.tooltip_text = "LVL:\n" + level_breakdown
				level_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(level_lbl)

	if card.card_type == Card.CardType.CREATURE and not card.is_god:
		if not is_hidden_card:
			if card.is_sleeping:
				vbox.add_child(_make_label("Sleeping", 13, Color(0.7, 0.86, 1.0)))

			vbox.add_child(_make_label(
				"DEF" if card.creature_mode == Card.CreatureMode.DEFENSIVE else "AGG",
				13,
				Color(0.7, 0.7, 0.7)
			))

			var stats_rtl := _make_rich_text(_build_board_creature_stats_text(card), 14, Color.WHITE, 0.0)
			var tooltip_lines := _build_board_creature_tooltips(card)
			if tooltip_lines.size() > 0:
				stats_rtl.tooltip_text = "\n\n".join(tooltip_lines)
				stats_rtl.mouse_filter = Control.MOUSE_FILTER_STOP
			vbox.add_child(stats_rtl)

			if effect_lines.size() > 0:
				vbox.add_child(_make_label("\n".join(effect_lines), 12, Color(0.78, 0.9, 1.0), true))
			if equipment_lines.size() > 0:
				vbox.add_child(_make_label(
					"Equipment:\n" + "\n".join(equipment_lines),
					12,
					Color(1.0, 0.87, 0.62),
					true
				))
			if binding_lines.size() > 0:
				vbox.add_child(_make_label(
					"Bindings:\n" + "\n".join(binding_lines),
					12,
					Color(0.66, 0.97, 0.93),
					true
				))

		if card.creature_major_action_used:
			vbox.add_child(_make_label("Major action used", 11, Color(0.8, 0.8, 0.4)))
		if card.creature_minor_actions_used > 0:
			vbox.add_child(_make_label(
				"Minor actions: %d/%d" % [
					card.creature_minor_actions_used,
					card.get_max_minor_creature_actions_per_turn()
				],
				11,
				Color(0.6, 0.9, 0.6)
			))
	elif card.card_type == Card.CardType.STRUCTURE:
		var res_lbl := _make_label(
			"RES:%d" % card.get_effective_resilience(),
			14
		)
		var res_breakdown := card.get_buff_tooltip("res")
		if card.get_effective_resilience() < card.resilience:
			res_lbl.modulate = Color(1.0, 0.35, 0.35)
			if res_breakdown != "":
				res_lbl.tooltip_text = "RES:\n" + res_breakdown
				res_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		elif card.get_effective_resilience() > card.resilience:
			res_lbl.modulate = Color(0.4, 1.0, 0.4)
			if res_breakdown != "":
				res_lbl.tooltip_text = "RES:\n" + res_breakdown
				res_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(res_lbl)
		if effect_lines.size() > 0:
			vbox.add_child(_make_label(
				"\n".join(effect_lines),
				12,
				Color(1.0, 0.45, 0.45) if card.is_petrified() else Color(0.78, 0.9, 1.0),
				true
			))
	elif not is_hidden_card and card.speed > 0:
		var spd_lbl := _make_label("SPD:%d" % card.get_effective_speed(), 14)
		var spd_breakdown := card.get_full_stat_breakdown("spd")
		if card.get_effective_speed() < card.speed:
			spd_lbl.modulate = Color(1.0, 0.35, 0.35)
			if spd_breakdown != "":
				spd_lbl.tooltip_text = "SPD:\n" + spd_breakdown
				spd_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		elif card.get_effective_speed() > card.speed:
			spd_lbl.modulate = Color(0.4, 1.0, 0.4)
			if spd_breakdown != "":
				spd_lbl.tooltip_text = "SPD:\n" + spd_breakdown
				spd_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(spd_lbl)

	if card.ability_text != "" and not is_hidden_card:
		var display_ability_text := (card as PowerCard).get_display_ability_bbcode_text(game_manager) if card is PowerCard else card.ability_text
		vbox.add_child(_make_rich_text(
			BaseCard.apply_keyword_hints(display_ability_text),
			13,
			Color(0.9, 0.85, 1.0)
		))

	if cost_lines.size() > 0 and not is_hidden_card:
		vbox.add_child(_make_label("\n".join(cost_lines), 12, Color(0.78, 0.9, 1.0), true))

	if power_cost_lines.size() > 0 and not is_hidden_card:
		vbox.add_child(_make_label("\n".join(power_cost_lines), 12, Color(1.0, 0.84, 0.62), true))

	var hover_detail_lines := card.get_hover_detail_lines(viewer)
	if hover_detail_lines.size() > 0 and not is_hidden_card:
		vbox.add_child(_make_rich_text("\n".join(hover_detail_lines), 13, Color(0.66, 0.97, 0.93)))

	if not is_hidden_card:
		_add_hover_stored_card_section(vbox, card, viewer, _BOARD_POPUP_WIDTH)

	if card.flavor_text != "" and not is_hidden_card:
		vbox.add_child(_make_label(card.flavor_text, 13, Color(0.55, 0.55, 0.55), true))

	return vbox

static func extract_card_keywords(card: Card) -> Array[String]:
	var found: Array[String] = []
	if card == null or card.ability_text == "":
		return found
	var regex := RegEx.new()
	regex.compile("\\[b\\](.*?)\\[/b\\]")
	for match in regex.search_all(card.ability_text):
		var keyword := match.get_string(1)
		if keyword in BaseCard.KEYWORD_HINTS and keyword not in found:
			found.append(keyword)
	return found

static func build_keywords_panel(keywords: Array[String]) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(_KEYWORD_PANEL_WIDTH, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.10, 0.96)
	style.border_color = Color(0.42, 0.58, 0.88)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	for i in keywords.size():
		var keyword := keywords[i]
		var keyword_box := VBoxContainer.new()
		keyword_box.add_theme_constant_override("separation", 3)
		keyword_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(keyword_box)

		var name_lbl := Label.new()
		name_lbl.text = keyword
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.5))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keyword_box.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = BaseCard.KEYWORD_HINTS[keyword]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
		desc_lbl.custom_minimum_size = Vector2(_KEYWORD_PANEL_WIDTH - 24.0, 0.0)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keyword_box.add_child(desc_lbl)

		if i < keywords.size() - 1:
			var sep := HSeparator.new()
			sep.add_theme_color_override("color", Color(0.2, 0.25, 0.35))
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(sep)

	return panel

static func _build_board_creature_stats_text(card: Card) -> String:
	var stat_parts: Array[String] = []
	for stat_info in [
		["STR", card.get_effective_strength(), card.strength],
		["RES", card.get_effective_resilience(), card.resilience],
		["SPD", card.get_effective_speed(), card.speed]
	]:
		var label_text = stat_info[0] + ":" + str(stat_info[1])
		if stat_info[1] > stat_info[2]:
			stat_parts.append("[color=#66ff66]" + label_text + "[/color]")
		elif stat_info[1] < stat_info[2]:
			stat_parts.append("[color=#ff5555]" + label_text + "[/color]")
		else:
			stat_parts.append(label_text)
	return " ".join(stat_parts)

static func _build_board_creature_tooltips(card: Card) -> Array[String]:
	var tooltip_lines: Array[String] = []
	for stat_info in [["STR", "str"], ["RES", "res"], ["SPD", "spd"]]:
		var breakdown := card.get_buff_tooltip(stat_info[1])
		if breakdown != "":
			tooltip_lines.append(stat_info[0] + ":\n" + breakdown)
	return tooltip_lines

static func _add_hover_stored_card_section(vbox: VBoxContainer, card: Card, viewer: Player, width: float) -> void:
	if vbox == null or card == null:
		return
	var stored_cards := card.get_hover_stored_cards(viewer)
	if stored_cards.is_empty():
		return
	var title := card.get_hover_stored_cards_title(viewer)
	var total_level := card.get_hover_stored_cards_total_level(viewer)
	vbox.add_child(_make_separator(Color(0.3, 0.28, 0.5)))
	var title_text := title
	if total_level > 0:
		title_text += " - Levels: %d" % total_level
	vbox.add_child(_make_label(title_text, 13, Color(1.0, 0.88, 0.48), true))
	for stored_card in stored_cards:
		if stored_card != null:
			vbox.add_child(_make_stored_card_preview(stored_card, viewer, width))

static func _make_stored_card_preview(card: Card, viewer: Player, width: float) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(width, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.92)
	style.border_color = Color(0.36, 0.48, 0.72, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	if card.art_path != "":
		var tex := load(card.art_path) as Texture2D
		if tex != null:
			var art := TextureRect.new()
			art.texture = tex
			art.custom_minimum_size = Vector2(40, 54)
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(art)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	info.add_child(_make_label(card.get_display_name_for_control(), 12, Color(1.0, 0.95, 0.76), true))
	var meta_parts: Array[String] = []
	if not card.is_god and card.get_effective_level() > 0:
		meta_parts.append("Lv %d" % card.get_effective_level())
	if card.card_type == Card.CardType.CREATURE:
		meta_parts.append("STR %d" % card.get_effective_strength())
		meta_parts.append("RES %d" % card.get_effective_resilience())
		meta_parts.append("SPD %d" % card.get_effective_speed())
	elif card.card_type == Card.CardType.STRUCTURE:
		meta_parts.append("RES %d" % card.get_effective_resilience())
	elif card.get_effective_speed() > 0:
		meta_parts.append("SPD %d" % card.get_effective_speed())
	if not meta_parts.is_empty():
		info.add_child(_make_label("  |  ".join(meta_parts), 11, Color(0.72, 0.84, 0.95), true))

	var summary := card.get_inline_ability_summary()
	if summary == "":
		var effect_lines := card.get_effect_summary_lines()
		if not effect_lines.is_empty():
			summary = " | ".join(effect_lines)
	if summary != "":
		info.add_child(_make_label(summary, 11, Color(0.82, 0.86, 0.94), true))
	return panel

static func _make_vbox(width: float, separation: int) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(width, 0.0)
	vbox.add_theme_constant_override("separation", separation)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return vbox

static func _make_label(
	text: String,
	font_size: int,
	font_color: Color = Color.WHITE,
	wrap: bool = false
) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func _make_rich_text(
	text: String,
	font_size: int,
	font_color: Color,
	min_width: float = 0.0
) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.text = text
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.scroll_active = false
	rtl.fit_content = true
	rtl.add_theme_font_size_override("normal_font_size", font_size)
	rtl.add_theme_font_size_override("bold_font_size", font_size)
	rtl.add_theme_color_override("default_color", font_color)
	# Keyword hints in BBCode need mouse interaction so hover tooltips can appear.
	rtl.mouse_filter = Control.MOUSE_FILTER_STOP if text.contains("[hint=") else Control.MOUSE_FILTER_IGNORE
	if min_width > 0.0:
		rtl.custom_minimum_size = Vector2(min_width, 0.0)
	return rtl

static func _make_separator(color: Color) -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", color)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep

static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(str(entry))
	return result
