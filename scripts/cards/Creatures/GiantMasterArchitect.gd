extends CreatureCard
class_name GiantMasterArchitect

const ART_PATH := "res://images/card_art/creatures/giant_master_architect_ai_edit.png"

func _init() -> void:
	super._init()
	card_name = "Giant Master Architect"
	card_types = ["Giant", "Smith", "Norse Creature"]
	level = 5
	mana_cost = 6
	sacrifice_cost = 0
	speed = 1
	resilience = 32
	strength = 27
	ability_text = "Master Plan ([b]Impact[/b]): Add one structure from your deck to your hand."
	flavor_text = ""
	culture = "Norse"
	artist = "Tim Nguyen"
	art_path = ART_PATH

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		var no_target_text := resolve_no_structure_targets()
		if game_manager != null:
			game_manager.note_player_feedback(no_target_text)
		return

	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(get_controller(), "giant_master_architect_impact", {
		"source_uid": uid,
		"target_uids": target_uids,
		"queue_with_priority": true,
		"event_name": "giant_master_architect_impact",
	})

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.deck_zone == null:
		return valid_targets
	for card in controller.deck_zone.cards:
		if _is_valid_structure_target(card, controller):
			valid_targets.append(card)
	return valid_targets

func resolve_master_plan_impact(game_manager: GameManager, target: Card) -> String:
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller for Master Plan."
	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		return card_name + " found no valid structure to add."

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

func resolve_master_plan_cancel(_game_manager: GameManager) -> String:
	var controller := get_controller()
	if controller != null:
		_shuffle_deck(controller)
	return "%s searched the deck but took no structure." % card_name

func resolve_no_structure_targets() -> String:
	var controller := get_controller()
	if controller != null:
		_shuffle_deck(controller)
	return "%s searched the deck but found no structures." % card_name

func _shuffle_deck(controller: Player) -> void:
	if controller == null or controller.deck_zone == null:
		return
	controller.deck_zone.cards.shuffle()

func _is_valid_structure_target(card: Card, controller: Player) -> bool:
	return card != null \
		and controller != null \
		and card.current_zone == controller.deck_zone \
		and card.card_type == Card.CardType.STRUCTURE

