class_name BoardZoneUI
extends PanelContainer

signal zone_clicked(zone: Zone)
signal card_clicked(card: Card)

var zone: Zone
var game_manager: GameManager
var owning_player: Player
var zone_index: int
var _drop_callback: Callable
var _is_enemy: bool = false

const ZONE_WIDTH  := 150
const ZONE_HEIGHT := 100

var _row_label: String = ""

func setup(p_zone: Zone, p_gm: GameManager, p_player: Player, idx: int,
		drop_cb: Callable, is_enemy: bool = false, row_label: String = "") -> void:
	zone         = p_zone
	game_manager = p_gm
	owning_player = p_player
	zone_index   = idx
	_drop_callback = drop_cb
	_is_enemy    = is_enemy
	_row_label   = row_label
	custom_minimum_size = Vector2(ZONE_WIDTH, ZONE_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_display()

func _refresh_display() -> void:
	for child in get_children():
		child.queue_free()

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left    = 4
	style.corner_radius_top_right   = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)

	if zone.cards.size() > 0:
		var card := zone.cards[0]
		match card.card_type:
			Card.CardType.CREATURE:
				style.bg_color    = Color(0.13, 0.22, 0.42)
				style.border_color = Color(0.4, 0.65, 1.0)
			Card.CardType.STRUCTURE:
				style.bg_color    = Color(0.28, 0.18, 0.08)
				style.border_color = Color(0.75, 0.55, 0.3)
			_:
				style.bg_color    = Color(0.18, 0.18, 0.18)
				style.border_color = Color(0.5, 0.5, 0.5)
		add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		add_child(vbox)

		var name_lbl := Label.new()
		name_lbl.text = card.card_name if not card.is_stealth else "???"
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(name_lbl)

		if card.card_type == Card.CardType.CREATURE:
			var mode_lbl := Label.new()
			mode_lbl.text = "???" if card.is_stealth else \
				("DEF" if card.creature_mode == Card.CreatureMode.DEFENSE else "ATK")
			mode_lbl.add_theme_font_size_override("font_size", 13)
			vbox.add_child(mode_lbl)

			var stats_lbl := Label.new()
			stats_lbl.text = "STR:%d RES:%d SPD:%d" % [
				card.get_effective_strength(), card.get_effective_resilience(), card.get_effective_speed()
			]
			stats_lbl.add_theme_font_size_override("font_size", 13)
			vbox.add_child(stats_lbl)

			if card.has_acted_this_turn:
				var acted_lbl := Label.new()
				acted_lbl.text = "✓ acted"
				acted_lbl.add_theme_font_size_override("font_size", 9)
				acted_lbl.modulate = Color(0.8, 0.8, 0.4)
				vbox.add_child(acted_lbl)

		elif card.card_type == Card.CardType.STRUCTURE:
			var res_lbl := Label.new()
			res_lbl.text = "RES:%d" % card.resilience
			res_lbl.add_theme_font_size_override("font_size", 13)
			vbox.add_child(res_lbl)

	else:
		# Empty zone styling
		style.bg_color    = Color(0.07, 0.12, 0.07, 0.55)
		style.border_color = Color(0.22, 0.35, 0.22, 0.7)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			style.set_border_width(side, 1)
		add_theme_stylebox_override("panel", style)

		var lbl := Label.new()
		lbl.text = _row_label if _row_label != "" else str(zone_index + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		lbl.modulate.a = 0.4
		add_child(lbl)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if zone.cards.size() > 0:
			card_clicked.emit(zone.cards[0])
		else:
			zone_clicked.emit(zone)

func _extract_card(data: Variant) -> Card:
	if data is Dictionary:
		return data.get("card") as Card
	if data is Card:
		return data as Card
	return null

func can_accept_card(card: Card) -> bool:
	if card is BitMeseri:
		if zone.cards.size() == 0:
			return false
		var target := zone.cards[0]
		if target.card_type != Card.CardType.CREATURE and target.card_type != Card.CardType.STRUCTURE and target.card_type != Card.CardType.EQUIPMENT:
			return false
		return game_manager.can_play_card(game_manager.current_player, card, null)
	if _is_enemy:
		return false
	if zone.cards.size() > 0:
		return false
	if owning_player != game_manager.current_player:
		return false
	return game_manager.can_play_card(owning_player, card, zone)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var card := _extract_card(data)
	if card == null:
		return false
	# BitMeseri can be dragged onto any zone that has a valid creature/structure target
	if card is BitMeseri:
		if zone.cards.size() == 0:
			return false
		var target := zone.cards[0]
		if target.card_type != Card.CardType.CREATURE and target.card_type != Card.CardType.STRUCTURE and target.card_type != Card.CardType.EQUIPMENT:
			return false
		return game_manager.can_play_card(game_manager.current_player, card, null)
	# Normal placement: own empty zones only
	if _is_enemy:
		return false
	if zone.cards.size() > 0:
		return false
	if owning_player != game_manager.current_player:
		return false
	return game_manager.can_play_card(owning_player, card, zone)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var card := _extract_card(data)
	var rotated: bool = data.get("rotated", false) if data is Dictionary else false
	_drop_callback.call(card, zone, rotated)
