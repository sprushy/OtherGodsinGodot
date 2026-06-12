extends CreatureCard
class_name Mopsus

const ART_PATH := "res://images/card_art/creatures/Mopsus.png"

func _init() -> void:
	super._init()
	card_name = "Mopsus"
	card_types = ["Human", "Mage", "Warrior", "Olympic Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 11
	strength = 21
	targets = true
	ability_text = "[b]Seer[/b] ([b]Activate[/b], [b]Minor Action[/b]): Reveal one of your opponent's hand cards, plus one more for each friendly Avian on the board. They remain revealed while in hand."
	flavor_text = ""
	culture = "Olympic"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func get_activation_label() -> String:
	return "Seer"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_face_down or is_stealth or is_prepared:
		return false
	if abilities_suppressed() or is_activation_locked(game_manager):
		return false
	if is_sleeping:
		return false
	if not can_take_minor_creature_action():
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	var opponent := game_manager.get_opponent(get_controller())
	if opponent == null or opponent.hand_zone == null:
		return valid_targets
	for card in opponent.hand_zone.cards:
		if card != null and card.current_zone == opponent.hand_zone:
			valid_targets.append(card)
	return valid_targets

func get_seer_reveal_count(game_manager: GameManager) -> int:
	if game_manager == null:
		return 1
	return 1 + _count_friendly_board_avians()

func get_required_seer_target_count(game_manager: GameManager) -> int:
	return mini(get_seer_reveal_count(game_manager), get_valid_targets(game_manager).size())

func get_selected_seer_targets(game_manager: GameManager, selection = null) -> Array[Card]:
	var selected_targets: Array[Card] = []
	var valid_targets: Array[Card] = get_valid_targets(game_manager)
	var raw_targets: Array = []
	if selection is Card:
		raw_targets.append(selection)
	elif selection is Array:
		raw_targets = (selection as Array).duplicate()
	elif selection is Dictionary:
		var option := selection as Dictionary
		var target_uids: Array = option.get("target_uids", [])
		for raw_uid in target_uids:
			var target_card: Card = null
			if game_manager != null:
				target_card = game_manager.get_card_by_uid(str(raw_uid))
			if target_card != null:
				raw_targets.append(target_card)
		if raw_targets.is_empty() and option.has("target_uid") and game_manager != null:
			var single_target := game_manager.get_card_by_uid(str(option.get("target_uid", "")))
			if single_target != null:
				raw_targets.append(single_target)
	for raw_target in raw_targets:
		var target_card: Card = raw_target as Card
		if target_card != null and target_card in valid_targets and target_card not in selected_targets:
			selected_targets.append(target_card)
	return selected_targets

func is_valid_seer_selection(game_manager: GameManager, selection = null) -> bool:
	return get_selected_seer_targets(game_manager, selection).size() == get_required_seer_target_count(game_manager)

func reveal_hand_card(game_manager: GameManager, selected_card: Card) -> bool:
	if selected_card == null or selected_card not in get_valid_targets(game_manager):
		return false
	if selected_card.is_revealed_in_hand():
		return true
	selected_card.add_status_effect(
		"revealed_in_hand",
		card_name,
		self,
		get_controller(),
		{"clear_on_card_move": true}
	)
	return true

func activate(game_manager: GameManager, target = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("%s cannot use Seer right now." % card_name)
		return
	var selected_targets: Array[Card] = get_selected_seer_targets(game_manager, target)
	var required_count := get_required_seer_target_count(game_manager)
	if selected_targets.size() != required_count:
		if game_manager != null:
			game_manager.note_player_feedback("%s fizzles: choose %d card(s) in your opponent's hand." % [card_name, required_count])
		return
	spend_minor_creature_action()
	for selected_card in selected_targets:
		reveal_hand_card(game_manager, selected_card)
	if game_manager != null:
		var revealed_names: Array[String] = []
		for selected_card in selected_targets:
			if selected_card != null:
				revealed_names.append(selected_card.get_display_name())
		game_manager.note_player_feedback("%s reveals %s in the opponent's hand." % [card_name, ", ".join(revealed_names)])

func _count_friendly_board_avians() -> int:
	var controller := get_controller()
	if controller == null:
		return 0
	var avian_count := 0
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if card == null:
				continue
			if card.card_type != Card.CardType.CREATURE or card.is_god:
				continue
			if card.get_controller() != controller:
				continue
			if card.has_type("Avian"):
				avian_count += 1
	return avian_count
