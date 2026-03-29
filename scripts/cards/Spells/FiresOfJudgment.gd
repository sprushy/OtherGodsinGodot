extends SpellCard
class_name FiresOfJudgment

func _init() -> void:
	super._init()
	card_name = "Fires of Judgment"
	culture = "Neutral"
	card_types = ["Destruction", "Physical"]
	level = 3
	mana_cost = 4
	speed = 1
	is_legendary = false
	sacrifice_cost = 0
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/InfernoAIEdit.png"
	ability_text = "Destroy all of your opponent's face up creatures, structures, and equipment."

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null or card_owner == null:
		return

	var doomed_cards := _get_doomed_cards(game_manager)
	if doomed_cards.is_empty():
		print(card_name + " found no face-up enemy permanents to destroy.")
		return

	var destroyed_count := 0
	for doomed_card in doomed_cards:
		if game_manager.request_send_to_graveyard(doomed_card, Callable(), false, true):
			destroyed_count += 1

	var feedback := "%s destroyed %d face-up enemy permanent(s)." % [card_name, destroyed_count]
	game_manager.note_player_feedback(feedback)
	print(feedback)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	if game_manager == null or player == null:
		return false
	if _get_doomed_cards(game_manager).is_empty():
		print(card_name + " has no valid targets.")
		return false
	return true

func _get_doomed_cards(game_manager: GameManager) -> Array[Card]:
	var doomed_cards: Array[Card] = []
	if game_manager == null or card_owner == null:
		return doomed_cards

	var opponent := game_manager.get_opponent(card_owner)
	if opponent == null:
		return doomed_cards

	for zone: Zone in opponent.frontline_zones + opponent.reserve_zones:
		for card: Card in zone.cards:
			if _is_doomed_card(card, opponent):
				doomed_cards.append(card)

	return doomed_cards

func _is_doomed_card(card: Card, opponent: Player) -> bool:
	if card == null or opponent == null:
		return false
	if card.get_controller() != opponent:
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	if card.is_face_down or card.is_stealth:
		return false
	return card.card_type in [
		Card.CardType.CREATURE,
		Card.CardType.STRUCTURE,
		Card.CardType.EQUIPMENT,
	]
