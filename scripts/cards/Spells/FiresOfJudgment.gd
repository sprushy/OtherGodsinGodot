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
	art_path = "res://images/card_art/spells/InfernoAIEdit.png"
	ability_text = "Destroy all of your opponent's face up creatures, structures, and equipment."

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null or card_owner == null:
		return

	var doomed_cards := _get_doomed_cards(game_manager)
	if doomed_cards.is_empty():
		print(card_name + " found no face-up enemy permanents to destroy.")
		return
	var on_destroy_complete := func(destroyed_count) -> void:
		var feedback := "%s destroyed %d face-up enemy permanent(s)." % [card_name, destroyed_count]
		game_manager.note_player_feedback(feedback)
		print(feedback)
	game_manager.request_send_cards_to_graveyard(
		doomed_cards,
		on_destroy_complete,
		false,
		true
	)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	if game_manager == null or player == null:
		return false
	if _get_doomed_cards(game_manager).is_empty():
		print(card_name + " has no valid targets.")
		return false
	return true

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	var base_reason := super.get_play_failure_reason(game_manager, player)
	if not base_reason.is_empty():
		return base_reason
	if game_manager == null or player == null:
		return card_name + " cannot be cast right now."
	if _get_doomed_cards(game_manager).is_empty():
		return card_name + " has no valid targets."
	return ""

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

func would_destroy_creature_of_player(game_manager: GameManager, protected_player: Player, _chosen_target = null) -> bool:
	if game_manager == null or protected_player == null:
		return false
	for doomed_card in _get_doomed_cards(game_manager):
		if doomed_card != null and doomed_card.card_type == Card.CardType.CREATURE and doomed_card.get_controller() == protected_player:
			return true
	return false
