class_name CardDetailContentBuilder
extends RefCounted

const LevelSymbolRowScript = preload("res://scripts/ui/LevelSymbolRow.gd")
const DebuffBadgeScript = preload("res://scripts/ui/DebuffBadge.gd")
const PUBLICLY_IDENTIFIED_BADGE_TEXTURE := preload("res://images/ability_badges/MopsusBadge.png")
const _BULLET_SEPARATOR := " | "
const _BOARD_POPUP_WIDTH := 210.0
const _KEYWORD_PANEL_WIDTH := 210.0
const _DECKBUILDER_SCROLLBAR_CONTENT_CLEARANCE := 32.0
const _DROMI_BINDING_NAME := "Dromi"
const _DROMI_BINDING_HOVER_TEXT := "Cannot attack. Losing 7 followers on opponent's turn start - Dromi"

static func build_visual_hover_body(card: Card, viewer: Player, config: Dictionary = {}) -> Control:
	var content_width := float(config.get("content_width", 300.0))
	var display_mana_cost := int(config.get("display_mana_cost", card.mana_cost))
	var display_cost_adjustment_lines: Array[String] = _to_string_array(config.get("display_cost_adjustment_lines", []))
	var game_manager = config.get("game_manager", card.card_owner.game_manager if card.card_owner != null else null)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.custom_minimum_size = Vector2(content_width, 0.0)
	apply_deckbuilder_scrollbar_style(scroll, true)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_right", int(_DECKBUILDER_SCROLLBAR_CONTENT_CLEARANCE))
	scroll.add_child(content_margin)

	var vbox := _make_vbox(content_width - _DECKBUILDER_SCROLLBAR_CONTENT_CLEARANCE, 4)
	content_margin.add_child(vbox)

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
	var show_meta_mana_cost := display_mana_cost > 0
	if card is PowerCard and card.is_face_down:
		show_meta_mana_cost = false
	if not card.is_god and card.get_effective_level() > 0:
		vbox.add_child(_make_level_symbol_row(card, 13.0))
	if show_meta_mana_cost:
		meta_parts.append("Mana: " + str(display_mana_cost))
	if card.culture != "":
		meta_parts.append(card.culture)
	if not meta_parts.is_empty():
		var meta_lbl := _make_rich_text(BaseCard.apply_mana_cost_symbols("  |  ".join(meta_parts), 14), 14, Color(0.65, 0.65, 0.65))
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
		vbox.add_child(_make_rich_text(
			BaseCard.apply_mana_cost_symbols("Extra Costs: " + " ".join(card.get_cost_shorthand_parts(0)), 14),
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

	if card.ability_text != "" or card.should_show_flavor_text_in_hover():
		vbox.add_child(_make_separator(Color(0.3, 0.3, 0.5)))

	if card.ability_text != "":
		var ability_lbl := _make_rich_text(
			BaseCard.apply_keyword_hints(BaseCard.apply_action_cost_symbols(card.get_display_ability_bbcode_text(game_manager), card)),
			17,
			Color(0.9, 0.85, 1.0),
			210.0
		)
		vbox.add_child(ability_lbl)

	if card.should_show_flavor_text_in_hover():
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
	_add_hover_summoned_active_god_section(vbox, card, viewer, content_width, game_manager)

	return scroll

static func apply_deckbuilder_scrollbar_style(scroll: ScrollContainer, force_visible: bool = false) -> void:
	if scroll == null:
		return
	if force_visible:
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS

	var bar := scroll.get_v_scroll_bar()
	if not is_instance_valid(bar):
		return

	bar.custom_minimum_size.x = 18.0
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_theme_constant_override("scroll_width", 18)
	bar.add_theme_constant_override("scroll_border", 2)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.035, 0.040, 0.060, 0.94)
	track.border_color = Color(0.18, 0.20, 0.30, 0.95)
	track.set_border_width(SIDE_LEFT, 1)
	track.set_border_width(SIDE_RIGHT, 1)
	track.set_border_width(SIDE_TOP, 1)
	track.set_border_width(SIDE_BOTTOM, 1)
	track.corner_radius_top_left = 8
	track.corner_radius_top_right = 8
	track.corner_radius_bottom_left = 8
	track.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.72, 0.66, 0.40, 0.98)
	grabber.border_color = Color(0.98, 0.88, 0.52, 1.0)
	grabber.set_border_width(SIDE_LEFT, 1)
	grabber.set_border_width(SIDE_RIGHT, 1)
	grabber.set_border_width(SIDE_TOP, 1)
	grabber.set_border_width(SIDE_BOTTOM, 1)
	grabber.corner_radius_top_left = 8
	grabber.corner_radius_top_right = 8
	grabber.corner_radius_bottom_left = 8
	grabber.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("grabber", grabber)

	var grabber_highlight := StyleBoxFlat.new()
	grabber_highlight.bg_color = grabber.bg_color
	grabber_highlight.border_color = grabber.border_color
	grabber_highlight.set_border_width(SIDE_LEFT, 1)
	grabber_highlight.set_border_width(SIDE_RIGHT, 1)
	grabber_highlight.set_border_width(SIDE_TOP, 1)
	grabber_highlight.set_border_width(SIDE_BOTTOM, 1)
	grabber_highlight.corner_radius_top_left = 8
	grabber_highlight.corner_radius_top_right = 8
	grabber_highlight.corner_radius_bottom_left = 8
	grabber_highlight.corner_radius_bottom_right = 8
	grabber_highlight.bg_color = Color(0.88, 0.78, 0.45, 1.0)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_highlight)

	var grabber_pressed := StyleBoxFlat.new()
	grabber_pressed.bg_color = grabber.bg_color
	grabber_pressed.border_color = grabber.border_color
	grabber_pressed.set_border_width(SIDE_LEFT, 1)
	grabber_pressed.set_border_width(SIDE_RIGHT, 1)
	grabber_pressed.set_border_width(SIDE_TOP, 1)
	grabber_pressed.set_border_width(SIDE_BOTTOM, 1)
	grabber_pressed.corner_radius_top_left = 8
	grabber_pressed.corner_radius_top_right = 8
	grabber_pressed.corner_radius_bottom_left = 8
	grabber_pressed.corner_radius_bottom_right = 8
	grabber_pressed.bg_color = Color(1.0, 0.84, 0.44, 1.0)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_pressed)

static func build_board_popup_body_from_game_state(
	card: Card,
	viewer: Player,
	game_manager,
	config: Dictionary = {}
) -> Control:
	var merged_config := config.duplicate(true)
	var is_hidden_card := (card.is_stealth or (card.is_face_down and not _is_public_power(card))) \
		and card.get_controller() != viewer \
		and not card.is_revealed_to_all()
	merged_config["is_hidden_card"] = is_hidden_card
	merged_config["type_label"] = _get_card_type_label(card)
	merged_config["game_manager"] = game_manager
	merged_config["effect_lines"] = []
	merged_config["equipment_lines"] = []
	merged_config["binding_lines"] = []
	merged_config["cost_lines"] = []
	merged_config["power_cost_lines"] = []

	if not is_hidden_card:
		if card.card_type == Card.CardType.CREATURE:
			merged_config["effect_lines"] = card.get_effect_summary_lines()
			merged_config["equipment_lines"] = card.get_equipment_summary_lines()
			var binding_lines: Array[String] = []
			for binding in _get_attached_permanent_hexes(card, game_manager):
				var line := binding.card_name
				var binding_effect_lines := _get_binding_hover_lines(binding)
				if binding_effect_lines.is_empty():
					binding_lines.append(line)
				else:
					binding_lines.append(line + ": " + " | ".join(binding_effect_lines))
			var has_dromi_line := false
			for line in binding_lines:
				if line.begins_with(_DROMI_BINDING_NAME):
					has_dromi_line = true
					break
			if not has_dromi_line and _has_dromi_binding(card, game_manager):
				var dromi_source := _get_dromi_binding_source(card, game_manager)
				if dromi_source != null and dromi_source != card:
					var dromi_effect_lines := _get_binding_hover_lines(dromi_source)
					if dromi_effect_lines.is_empty():
						binding_lines.append(_DROMI_BINDING_NAME + ": " + _DROMI_BINDING_HOVER_TEXT)
					else:
						binding_lines.append(_DROMI_BINDING_NAME + ": " + " | ".join(dromi_effect_lines))
				else:
					binding_lines.append(_DROMI_BINDING_NAME + ": " + _DROMI_BINDING_HOVER_TEXT)
			merged_config["binding_lines"] = binding_lines
		elif card.card_type == Card.CardType.STRUCTURE or card.card_type == Card.CardType.EQUIPMENT:
			merged_config["effect_lines"] = card.get_effect_summary_lines()

		if card is PowerCard:
			merged_config["power_cost_lines"] = _get_power_hover_cost_lines(card as PowerCard, game_manager)
		elif _can_show_prepared_magical_cost(card, viewer):
			merged_config["cost_lines"] = _get_prepared_magical_hover_cost_lines(card, viewer, game_manager)

	return build_board_popup_body(card, viewer, merged_config)

static func _is_public_power(card: Card) -> bool:
	var power := card as PowerCard
	return power != null and power.is_publicly_revealed

static func _get_card_type_label(card: Card) -> String:
	if card == null:
		return "Card"
	if card.is_god:
		return "God"
	if card.is_power:
		return "Power"
	if card.has_type("Charm"):
		return "Charm"
	match card.card_type:
		Card.CardType.CREATURE:
			return "Creature"
		Card.CardType.CHARM:
			return "Charm"
		Card.CardType.SPELL:
			return "Spell"
		Card.CardType.STRUCTURE:
			return "Structure"
		Card.CardType.HEX:
			return "Hex"
		Card.CardType.EQUIPMENT:
			return "Equipment"
	return "Card"

static func _get_power_hover_cost_lines(power: PowerCard, game_manager) -> Array[String]:
	var lines: Array[String] = []
	if power == null or game_manager == null:
		return lines
	if power.is_face_down:
		return power.get_unlock_display_cost_lines(game_manager)
	var hover_data: Dictionary = power.get_activation_cost_hover_data(game_manager)
	if hover_data.is_empty():
		return lines
	var base_cost: int = int(hover_data.get("base_cost", 0))
	var cost_kind: String = str(hover_data.get("cost_kind", Card.COST_KIND_POWER_ACTIVATION))
	var metadata: Dictionary = hover_data.get("metadata", {})
	var label: String = str(hover_data.get("label", "Activation Cost"))
	var current_cost := power.get_adjusted_mana_cost(base_cost, cost_kind, game_manager, metadata)
	if power.should_include_activation_cost_summary_line(game_manager):
		lines.append("%s: %d" % [label, current_cost])
	for breakdown_line in power.get_cost_adjustment_lines(base_cost, cost_kind, game_manager, metadata):
		lines.append(breakdown_line)
	for extra_line in hover_data.get("extra_lines", []):
		var text := str(extra_line).strip_edges()
		if text != "":
			lines.append(text)
	return lines

static func _can_show_prepared_magical_cost(card: Card, viewer: Player) -> bool:
	if card == null:
		return false
	if not card.is_prepared or not card.is_magical_card():
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	return card.get_controller() == viewer

static func _get_prepared_magical_cost_player(card: Card) -> Player:
	if card == null:
		return null
	var controller := card.get_controller()
	if controller != null:
		return controller
	return card.card_owner

static func _get_prepared_magical_hover_cost_lines(card: Card, viewer: Player, game_manager) -> Array[String]:
	var lines: Array[String] = []
	if not _can_show_prepared_magical_cost(card, viewer) or game_manager == null:
		return lines
	var current_cost := card.mana_cost
	var paying_player := _get_prepared_magical_cost_player(card)
	if paying_player != null:
		current_cost = game_manager.get_prepared_card_activation_mana_cost(paying_player, card)
	var cost_parts := card.get_cost_shorthand_parts(current_cost)
	if not cost_parts.is_empty():
		lines.append("Activation Cost: " + " ".join(cost_parts))
	if paying_player != null:
		for breakdown_line in card.get_cost_adjustment_lines(
			card.mana_cost,
			Card.COST_KIND_HAND_PLAY,
			game_manager,
			{"player": paying_player, "prepared": true}
		):
			lines.append(breakdown_line)
	return lines

static func _get_attached_permanent_hexes(card: Card, game_manager) -> Array[Card]:
	var bindings: Array[Card] = []
	if card == null:
		return bindings
	var scanned_zones: Array[Zone] = []
	if game_manager != null:
		for player in game_manager.players:
			scanned_zones.append_array(player.frontline_zones)
			scanned_zones.append_array(player.reserve_zones)
			scanned_zones.append_array(player.power_zones)
	elif card.current_zone != null:
		scanned_zones.append(card.current_zone)
	for scanned_zone in scanned_zones:
		if scanned_zone == null:
			continue
		for zone_card in scanned_zone.cards:
			if zone_card == null or zone_card == card or zone_card in bindings:
				continue
			if zone_card is PermanentHexCard and (zone_card as PermanentHexCard).attached_target == card:
				bindings.append(zone_card)
	return bindings

static func _get_dromi_binding_source(card: Card, game_manager) -> Card:
	if card == null:
		return null
	for binding in _get_attached_permanent_hexes(card, game_manager):
		if binding != null and binding.card_name == _DROMI_BINDING_NAME:
			return binding
	var cannot_attack_status := card.get_status_effect("cannot_attack")
	if cannot_attack_status.is_empty():
		return null
	var source_name := str(cannot_attack_status.get("source", ""))
	var source_card = cannot_attack_status.get("source_card", null)
	if source_card is Card and (source_card as Card).card_name == _DROMI_BINDING_NAME:
		return source_card as Card
	if source_name == _DROMI_BINDING_NAME:
		if source_card is Card:
			return source_card as Card
		return card
	return null

static func _has_dromi_binding(card: Card, game_manager) -> bool:
	return _get_dromi_binding_source(card, game_manager) != null

static func _get_binding_hover_lines(binding: Card) -> Array[String]:
	var details: Array[String] = []
	if binding == null:
		return details
	if binding.card_name == _DROMI_BINDING_NAME:
		details.append(_DROMI_BINDING_HOVER_TEXT)
		return details
	var ability_summary := binding.get_inline_ability_summary()
	if ability_summary != "":
		details.append(ability_summary)
	for effect_line in binding.get_effect_summary_lines():
		if effect_line == "" or effect_line in details:
			continue
		details.append(effect_line)
	return details

static func build_board_popup_body(card: Card, viewer: Player, config: Dictionary = {}) -> Control:
	var is_hidden_card := bool(config.get("is_hidden_card", false))
	var type_label := str(config.get("type_label", ""))
	var effect_lines: Array[String] = _to_string_array(config.get("effect_lines", []))
	var equipment_lines: Array[String] = _to_string_array(config.get("equipment_lines", []))
	var binding_lines: Array[String] = _to_string_array(config.get("binding_lines", []))
	var cost_lines: Array[String] = _to_string_array(config.get("cost_lines", []))
	var power_cost_lines: Array[String] = _to_string_array(config.get("power_cost_lines", []))
	var game_manager = config.get("game_manager", null)
	var show_listed_costs := bool(config.get("show_listed_costs", false))

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
		vbox.add_child(_make_level_symbol_row(card, 13.0))

	if not is_hidden_card and show_listed_costs and card.has_listed_play_costs():
		vbox.add_child(_make_rich_text(
			BaseCard.apply_mana_cost_symbols("Summon Cost: " + card.get_cost_shorthand(), 13),
			13,
			Color(1.0, 0.78, 0.58)
		))

	if card.card_type == Card.CardType.CREATURE and not card.is_god:
		if not is_hidden_card:
			if card.is_sleeping:
				vbox.add_child(_make_label("Sleeping", 13, Color(0.7, 0.86, 1.0)))

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
		var display_ability_text := card.get_display_ability_bbcode_text(game_manager)
		vbox.add_child(_make_rich_text(
			BaseCard.apply_keyword_hints(BaseCard.apply_action_cost_symbols(display_ability_text, card)),
			13,
			Color(0.9, 0.85, 1.0)
		))

	if cost_lines.size() > 0 and not is_hidden_card:
		vbox.add_child(_make_rich_text(BaseCard.apply_mana_cost_symbols("\n".join(cost_lines), 12), 12, Color(0.78, 0.9, 1.0)))

	if power_cost_lines.size() > 0 and not is_hidden_card:
		vbox.add_child(_make_rich_text(BaseCard.apply_mana_cost_symbols("\n".join(power_cost_lines), 12), 12, Color(1.0, 0.84, 0.62)))

	var hover_detail_lines := card.get_hover_detail_lines(viewer)
	if hover_detail_lines.size() > 0 and not is_hidden_card:
		vbox.add_child(_make_rich_text("\n".join(hover_detail_lines), 13, Color(0.66, 0.97, 0.93)))

	if not is_hidden_card:
		_add_hover_stored_card_section(vbox, card, viewer, _BOARD_POPUP_WIDTH)
		_add_hover_summoned_active_god_section(vbox, card, viewer, _BOARD_POPUP_WIDTH, game_manager)

	if card.should_show_flavor_text_in_hover() and not is_hidden_card:
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

static func _add_hover_summoned_active_god_section(
	vbox: VBoxContainer,
	card: Card,
	viewer: Player,
	width: float,
	game_manager = null
) -> void:
	if vbox == null or card == null:
		return
	var active_gods := card.get_hover_summoned_active_gods(viewer)
	if active_gods.is_empty():
		return
	vbox.add_child(_make_separator(Color(0.64, 0.48, 0.16)))
	vbox.add_child(_make_label(
		card.get_hover_summoned_active_gods_title(viewer),
		13,
		Color(1.0, 0.88, 0.48),
		true
	))
	for active_god in active_gods:
		if active_god != null:
			vbox.add_child(make_full_card_preview(active_god, viewer, width, game_manager))

static func make_full_card_preview(card: Card, viewer: Player, width: float, game_manager = null) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(width, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.92)
	style.border_color = Color(0.72, 0.54, 0.18, 0.9)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(build_board_popup_body(card, viewer, {
		"game_manager": game_manager,
		"show_listed_costs": true,
	}))
	return panel

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

	if viewer != null and card.card_owner == viewer:
		var preview := TextureRect.new()
		preview.texture = PUBLICLY_IDENTIFIED_BADGE_TEXTURE
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview.offset_left = 2.0
		preview.offset_top = 2.0
		preview.offset_right = -2.0
		preview.offset_bottom = -2.0

		var badge := DebuffBadgeScript.create(preview)
		badge.z_index = 5
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -6.0 - DebuffBadgeScript.SIZE
		badge.offset_top = 6.0
		badge.offset_right = -6.0
		badge.offset_bottom = 6.0 + DebuffBadgeScript.SIZE
		panel.add_child(badge)

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
	if card.card_type == Card.CardType.CREATURE:
		meta_parts.append("STR %d" % card.get_effective_strength())
		meta_parts.append("RES %d" % card.get_effective_resilience())
		meta_parts.append("SPD %d" % card.get_effective_speed())
	elif card.card_type == Card.CardType.STRUCTURE:
		meta_parts.append("RES %d" % card.get_effective_resilience())
	elif card.get_effective_speed() > 0:
		meta_parts.append("SPD %d" % card.get_effective_speed())
	if not meta_parts.is_empty() or (not card.is_god and card.get_effective_level() > 0):
		var meta_row := HBoxContainer.new()
		meta_row.add_theme_constant_override("separation", 5)
		meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not card.is_god and card.get_effective_level() > 0:
			meta_row.add_child(_make_level_symbol_row(card, 10.0))
		if not meta_parts.is_empty():
			meta_row.add_child(_make_label("  |  ".join(meta_parts), 11, Color(0.72, 0.84, 0.95), true))
		info.add_child(meta_row)

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

static func _get_level_symbol_color(card: Card) -> Color:
	var effective_level := card.get_effective_level()
	if effective_level > card.level:
		return Color(0.4, 1.0, 0.4)
	if effective_level < card.level:
		return Color(1.0, 0.35, 0.35)
	return Color(1.0, 0.96, 0.78)

static func _make_level_symbol_row(card: Card, symbol_size: float) -> Control:
	var row: Control = LevelSymbolRowScript.new()
	row.setup(
		card.get_effective_level(),
		symbol_size,
		_get_level_symbol_color(card),
		LevelSymbolRowScript.get_symbol_texture_for_card(card)
	)
	var tooltip_lines := PackedStringArray(["Level: %d" % card.get_effective_level()])
	var level_breakdown := card.get_buff_tooltip("lvl")
	if level_breakdown != "":
		tooltip_lines.append("LVL:\n" + level_breakdown)
	row.tooltip_text = "\n".join(tooltip_lines)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	return row

static func _make_label(
	text: String,
	font_size: int,
	font_color: Color = Color.WHITE,
	enable_wrap: bool = false
) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if enable_wrap else TextServer.AUTOWRAP_OFF
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
