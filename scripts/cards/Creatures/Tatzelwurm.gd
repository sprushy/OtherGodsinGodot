extends CreatureCard
class_name Tatzelwurm

const ART_PATH := "res://images/card_art/creatures/TatzelwyrmEdit.png"

func _init() -> void:
	super._init()
	card_name = "Tatzelwurm"
	card_types = ["Animal", "Cryptid", "Norse Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 9
	strength = 16
	ability_text = "[b]Dragon Heart[/b]: [b]Slay[/b]: [b]Acquire[/b] a Dragon."
	flavor_text = ""
	culture = "Norse"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func on_kill(game_manager: GameManager, _victim: Card) -> void:
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback(resolve_no_dragon_heart_targets())
		return
	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(get_controller(), "tatzelwurm_dragon_heart", {
		"source_uid": uid,
		"target_uids": target_uids,
	})

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.deck_zone == null:
		return valid_targets
	for card in controller.deck_zone.cards:
		if _is_valid_dragon_target(card, controller):
			valid_targets.append(card)
	return valid_targets

func resolve_dragon_heart(game_manager: GameManager, target: Card) -> String:
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller for Dragon Heart."
	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		return card_name + " found no valid Dragon to add."

	controller.move_card(target, controller.hand_zone)
	if target.current_zone != controller.hand_zone:
		return "%s could not move %s to hand." % [card_name, target.card_name]
	target.card_owner = controller
	_shuffle_deck(controller)
	return "%s adds %s from the deck to %s's hand." % [
		card_name,
		target.card_name,
		controller.player_name
	]

func resolve_dragon_heart_decline(_game_manager: GameManager) -> String:
	var controller := get_controller()
	if controller != null:
		_shuffle_deck(controller)
	return "%s took no Dragon." % card_name

func resolve_no_dragon_heart_targets() -> String:
	var controller := get_controller()
	if controller != null:
		_shuffle_deck(controller)
	return "%s searched the deck but found no Dragons." % card_name

func _shuffle_deck(controller: Player) -> void:
	if controller == null or controller.deck_zone == null:
		return
	controller.deck_zone.cards.shuffle()

func _is_valid_dragon_target(card: Card, controller: Player) -> bool:
	return card != null \
		and controller != null \
		and card.current_zone == controller.deck_zone \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.has_type("Dragon")

