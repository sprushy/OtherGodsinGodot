extends CreatureCard
class_name HumbabaTheTerrible

const QUEUED_AUGURY_SUPPRESSION_META := "queued_humbaba_augury_suppression"

func _init() -> void:
	super._init()
	card_name = "Humbaba the Terrible"
	card_types = ["Giant", "Forest", "Ancient Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 20
	strength = 28
	ability_text = "[b]Augury Reading[/b] ([b]Passive[/b]): Every time this card enters combat, your opponent looks at the top three cards of their deck, [b]Primes[/b] one, and [b]Shelves[/b] the others."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/Humbaba(print)Art.jpg"

func on_attack(game_manager: GameManager, _target) -> void:
	if _consume_queued_augury_suppression():
		return
	_trigger_augury_reading(game_manager)

func on_defend(game_manager: GameManager, _attacker: Card) -> void:
	if _consume_queued_augury_suppression():
		return
	_trigger_augury_reading(game_manager)

func queue_augury_trigger_suppression() -> void:
	var remaining := int(get_meta(QUEUED_AUGURY_SUPPRESSION_META, 0))
	set_meta(QUEUED_AUGURY_SUPPRESSION_META, remaining + 1)

func _consume_queued_augury_suppression() -> bool:
	var remaining := int(get_meta(QUEUED_AUGURY_SUPPRESSION_META, 0))
	if remaining <= 0:
		return false
	if remaining <= 1:
		remove_meta(QUEUED_AUGURY_SUPPRESSION_META)
	else:
		set_meta(QUEUED_AUGURY_SUPPRESSION_META, remaining - 1)
	return true

func _trigger_augury_reading(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	var top_cards := get_augury_cards(game_manager)
	if top_cards.is_empty():
		game_manager.note_player_feedback("%s found no cards to read." % card_name)
		return

	var prompt_player := _get_opponent(game_manager)
	if prompt_player == null:
		game_manager.note_player_feedback(resolve_augury_reading(game_manager, top_cards[0]))
		return

	var target_uids: Array[String] = []
	for card in top_cards:
		if card != null:
			target_uids.append(card.uid)
	game_manager.decision_requested.emit(prompt_player, "humbaba_augury", {
		"source_uid": uid,
		"target_uids": target_uids,
	})

func get_augury_cards(game_manager: GameManager) -> Array[Card]:
	var cards: Array[Card] = []
	var opponent := _get_opponent(game_manager)
	if opponent == null or opponent.deck_zone == null:
		return cards
	var limit := mini(3, opponent.deck_zone.cards.size())
	for i in range(limit):
		var card := opponent.deck_zone.cards[i] as Card
		if card != null:
			cards.append(card)
	return cards

func resolve_augury_reading(game_manager: GameManager, chosen_card: Card = null) -> String:
	var opponent := _get_opponent(game_manager)
	if opponent == null or opponent.deck_zone == null:
		return card_name + " found no opposing deck to read."

	var top_cards := get_augury_cards(game_manager)
	if top_cards.is_empty():
		return card_name + " found no cards to read."

	var primed_card := chosen_card if chosen_card != null and chosen_card in top_cards else top_cards[0]
	var shelved_cards: Array[Card] = []
	for card in top_cards:
		opponent.deck_zone.cards.erase(card)
		if card == primed_card:
			continue
		shelved_cards.append(card)

	opponent.deck_zone.cards.insert(0, primed_card)
	for card in shelved_cards:
		opponent.deck_zone.cards.append(card)

	var primed_name := primed_card.get_target_log_display_name(game_manager.get_feedback_viewer())
	if shelved_cards.is_empty():
		return "%s used Augury Reading and primed %s." % [card_name, primed_name]

	var shelved_names: Array[String] = []
	for card in shelved_cards:
		shelved_names.append(card.get_target_log_display_name(game_manager.get_feedback_viewer()))
	return "%s used Augury Reading and primed %s while shelving %s." % [
		card_name,
		primed_name,
		", ".join(shelved_names)
	]

func _get_opponent(game_manager: GameManager) -> Player:
	var controller := get_controller()
	if game_manager == null or controller == null:
		return null
	return game_manager.get_opponent(controller)

