extends CreatureCard

func _init() -> void:
	super._init()
	card_name = "Fourth Sage Enmegalamma"
	card_types = ["Mer", "Mage", "Priest", "Sage", "Ancient Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 15
	strength = 14
	ability_text = "[b]Search[/b] Sage ([b]Impact[/b]): You may add a Mer Sage from your deck to your hand except for another copy of this card."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/FourthSageAiEdit2.png"

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		var no_target_text := resolve_no_search_targets()
		if game_manager != null:
			game_manager.note_player_feedback(no_target_text)
		return
	var controller := get_controller()
	if game_manager == null or controller == null:
		return
	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(controller, "fourth_sage_enmegalamma_impact", {
		"source_uid": uid,
		"target_uids": target_uids,
		"queue_with_priority": true,
		"event_name": "fourth_sage_enmegalamma_impact",
	})

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.deck_zone == null:
		return valid_targets
	for card in controller.deck_zone.cards:
		if _is_valid_search_target(card, controller):
			valid_targets.append(card)
	return valid_targets

func resolve_search_sage_impact(game_manager: GameManager, target: Card) -> String:
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller for Search Sage."
	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		return card_name + " found no valid Mer Sage to add."

	controller.move_card(target, controller.hand_zone)
	if target.current_zone != controller.hand_zone:
		return "%s could not move %s to hand." % [card_name, target.card_name]
	target.card_owner = controller
	_shuffle_deck(controller)
	return "%s added %s from the deck to %s's hand." % [
		card_name,
		target.card_name,
		controller.player_name
	]

func resolve_search_sage_decline(_game_manager: GameManager) -> String:
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller for Search Sage."
	_shuffle_deck(controller)
	return "%s searched the deck but took no Sage." % card_name

func resolve_no_search_targets() -> String:
	var controller := get_controller()
	if controller != null:
		_shuffle_deck(controller)
	return "%s searched the deck but found no other Mer Sages." % card_name

func _shuffle_deck(controller: Player) -> void:
	if controller == null or controller.deck_zone == null:
		return
	controller.deck_zone.cards.shuffle()

func _is_valid_search_target(card: Card, controller: Player) -> bool:
	return card != null \
		and controller != null \
		and card.current_zone == controller.deck_zone \
		and card.card_type == Card.CardType.CREATURE \
		and card.has_type("Mer") \
		and card.has_type("Sage") \
		and card.card_name != card_name
