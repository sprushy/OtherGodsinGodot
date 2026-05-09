extends HexCard
class_name TheDeluge

const ART_PATH := "res://images/card_art/hexes/TheDelugeEdit.png"

func _init() -> void:
	super._init()
	card_name = "The Deluge"
	level = 4
	mana_cost = 1
	speed = 3
	is_legendary = true
	culture = "Neutral"
	card_types = ["Legendary Destruction", "Physical"]
	ability_text = "When a creature or structure is summoned, destroy all physical cards."
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = ART_PATH
	targets = false

func can_respond_to_action(action: CardAction) -> bool:
	return action != null \
		and action.type == CardAction.Type.EVENT \
		and action.event_name == "summon" \
		and _is_valid_summon_trigger(action.card)

func get_priority_targets(_game_manager: GameManager, action: CardAction) -> Array[Card]:
	if not can_respond_to_action(action):
		return []
	return [action.card]

func on_activate_action(game_manager: GameManager, action: CardAction) -> void:
	if game_manager == null:
		if card_owner != null:
			card_owner.move_card(self, card_owner.graveyard_zone)
		return

	var triggering_card := _get_triggering_card(action)
	var triggering_name := "a summoned card"
	if triggering_card != null:
		triggering_name = triggering_card.get_target_log_display_name(game_manager.get_feedback_viewer())

	var doomed_cards := _get_doomed_cards(game_manager)
	var immune_count := 0
	var destroyable_cards: Array[Card] = []
	for doomed_card in doomed_cards:
		if doomed_card == null or doomed_card.current_zone == null or not doomed_card.current_zone.is_board_zone():
			continue
		if game_manager.is_immune_to_source(doomed_card, self):
			immune_count += 1
			continue
		destroyable_cards.append(doomed_card)
	var on_destroy_complete := func(destroyed_count) -> void:
		var feedback := ""
		if destroyed_count > 0:
			feedback = "%s triggered when %s was summoned and destroyed %d physical card(s)." % [
				card_name,
				triggering_name,
				destroyed_count,
			]
		else:
			feedback = "%s triggered when %s was summoned, but no physical cards were destroyed." % [
				card_name,
				triggering_name,
			]
		if immune_count > 0:
			feedback += " %d card(s) were immune." % immune_count
		game_manager.note_player_feedback(feedback)
		if card_owner != null:
			card_owner.move_card(self, card_owner.graveyard_zone)
	game_manager.request_send_cards_to_graveyard(
		destroyable_cards,
		on_destroy_complete,
		false,
		true
	)

func _get_triggering_card(action: CardAction) -> Card:
	if action == null:
		return null
	if action.target is Card:
		return action.target as Card
	if action.response_to != null:
		return action.response_to.card
	return null

func _get_doomed_cards(game_manager: GameManager) -> Array[Card]:
	var doomed_cards: Array[Card] = []
	if game_manager == null:
		return doomed_cards
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			if zone == null:
				continue
			for card in zone.cards:
				if card != null and card.is_physical_card():
					doomed_cards.append(card)
	return doomed_cards

func _is_valid_summon_trigger(card: Card) -> bool:
	if card == null:
		return false
	return card.card_type in [Card.CardType.CREATURE, Card.CardType.STRUCTURE]
