extends SpellCard
class_name LightOfMorningsDoors

func _init() -> void:
	super._init()
	card_name = "Light of Morning's Doors"
	culture = "Norse"
	card_types = ["Revelation"]
	level = 1
	mana_cost = 1
	speed = 1
	is_legendary = false
	sacrifice_cost = 0
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/spells/MorningDoorsEdit.png"
	ability_text = "Reveal all of your opponent's face-down cards."
	targets = false

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null or card_owner == null:
		return

	var hidden_cards := _get_hidden_opponent_cards(game_manager)
	if hidden_cards.is_empty():
		var no_targets_feedback := card_name + " found no face-down enemy cards to reveal."
		game_manager.note_player_feedback(no_targets_feedback)
		print(no_targets_feedback)
		return

	var revealed_count := 0
	for card in hidden_cards:
		if _reveal_hidden_card(card, game_manager):
			revealed_count += 1

	var feedback := "%s revealed %d face-down opponent card(s)." % [card_name, revealed_count]
	game_manager.note_player_feedback(feedback)
	print(feedback)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	if game_manager == null or player == null:
		return false
	if _get_hidden_opponent_cards(game_manager).is_empty():
		print(card_name + " has no valid targets.")
		return false
	return true

func _get_hidden_opponent_cards(game_manager: GameManager) -> Array[Card]:
	var hidden_cards: Array[Card] = []
	if game_manager == null or card_owner == null:
		return hidden_cards

	var opponent := game_manager.get_opponent(card_owner)
	if opponent == null:
		return hidden_cards

	for card in opponent.god_zone.cards:
		if _is_revealable_face_down_card(card):
			hidden_cards.append(card)
	for zone in opponent.power_zones + opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if _is_revealable_face_down_card(card):
				hidden_cards.append(card)

	return hidden_cards

func _is_revealable_face_down_card(card: Card) -> bool:
	if card == null:
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	if not card.is_face_down:
		return false
	if card.is_temporarily_revealed():
		return false
	var power := card as PowerCard
	if power != null and power.is_publicly_revealed:
		return false
	return true

func _reveal_hidden_card(card: Card, game_manager: GameManager) -> bool:
	if not _is_revealable_face_down_card(card):
		return false

	var power := card as PowerCard
	if power != null:
		power.reveal_while_face_down()
		if not card.abilities_suppressed():
			card.on_reveal(game_manager)
		if game_manager != null and game_manager.has_method("notify_card_revealed_by_effect"):
			game_manager.notify_card_revealed_by_effect(card, self)
		return true

	card.reveal(game_manager)
	if game_manager != null and game_manager.has_method("notify_card_revealed_by_effect"):
		game_manager.notify_card_revealed_by_effect(card, self)
	return true
