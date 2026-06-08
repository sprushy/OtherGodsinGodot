extends CreatureCard
class_name PaiLongAutumnKing

const ART_PATH := "res://images/card_art/creatures/TheDragonKingEdit.png"

func _init() -> void:
	super._init()
	card_name = "Pai Long, Autumn King"
	card_types = ["Dragon", "Long", "Mage", "King", "Aerial", "Tian Creature"]
	level = 6
	mana_cost = 9
	sacrifice_cost = 0
	speed = 3
	resilience = 25
	strength = 36
	ability_text = "[b]Stormcloud[/b] ([b]Impact[/b]): Add a [b]Weather[/b] charm from your deck to your hand.\n[b]Weather King[/b] ([b]Passive[/b]): This card is immune to weather effects that do not increase its stats."
	flavor_text = ""
	culture = "Tian"
	artist = "David Revoy"
	art_path = ART_PATH

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		var no_target_text := resolve_no_weather_targets()
		if game_manager != null:
			game_manager.note_player_feedback(no_target_text)
		return

	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(get_controller(), "pai_long_autumn_king_impact", {
		"source_uid": uid,
		"target_uids": target_uids,
		"queue_with_priority": true,
		"event_name": "pai_long_autumn_king_impact",
	})

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.deck_zone == null:
		return valid_targets
	for card in controller.deck_zone.cards:
		if _is_valid_weather_target(card, controller):
			valid_targets.append(card)
	return valid_targets

func resolve_stormcloud_impact(game_manager: GameManager, target: Card) -> String:
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller for Stormcloud."
	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		return card_name + " found no valid Weather charm to add."

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

func resolve_stormcloud_cancel(_game_manager: GameManager) -> String:
	var controller := get_controller()
	if controller != null:
		_shuffle_deck(controller)
	return "%s searched the deck but took no Weather charm." % card_name

func resolve_no_weather_targets() -> String:
	var controller := get_controller()
	if controller != null:
		_shuffle_deck(controller)
	return "%s searched the deck but found no Weather charms." % card_name

func blocks_weather_effect(source_card: Card, str_bonus: int = 0, res_bonus: int = 0, spd_bonus: int = 0) -> bool:
	if not _weather_king_is_active():
		return false
	if source_card == null or not source_card.has_type("Weather"):
		return false
	return str_bonus <= 0 and res_bonus <= 0 and spd_bonus <= 0

func _weather_king_is_active() -> bool:
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_enslaved() or is_muted or is_petrified():
		return false
	for status in active_statuses:
		if status.get("name", "") != Card.ABILITY_NEGATED_STATUS:
			continue
		var source_card := status.get("source_card", null) as Card
		if source_card != null and source_card.has_type("Weather"):
			continue
		return false
	return true

func _shuffle_deck(controller: Player) -> void:
	if controller == null or controller.deck_zone == null:
		return
	controller.deck_zone.cards.shuffle()

func _is_valid_weather_target(card: Card, controller: Player) -> bool:
	return card != null \
		and controller != null \
		and card.current_zone == controller.deck_zone \
		and card.card_type == Card.CardType.CHARM \
		and card.has_type("Weather")

