extends HexCard
class_name TheInferno

const ART_PATH := "res://images/card_art/hexes/inferno(web).jpg"

func _init() -> void:
	super._init()
	card_name = "The Inferno"
	level = 4
	mana_cost = 1
	speed = 3
	is_legendary = true
	culture = "Neutral"
	card_types = ["Legendary Destruction", "Front Line"]
	ability_text = "When your opponent declares an attack, destroy all cards on their frontline."
	flavor_text = ""
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	targets = false

func can_respond_to_action(action: CardAction) -> bool:
	if action == null or action.type != CardAction.Type.ATTACK:
		return false
	var attacker := action.attacker
	if attacker == null or attacker.card_type != Card.CardType.CREATURE:
		return false
	if attacker.current_zone == null or not attacker.current_zone.is_board_zone():
		return false
	if attacker.get_controller() == card_owner:
		return false
	return attacker.get_effective_speed() <= get_effective_speed()

func get_priority_targets(game_manager: GameManager, action: CardAction) -> Array[Card]:
	if not can_respond_to_action(action):
		return []
	var attacking_player := _get_attacking_player(action)
	if attacking_player == null:
		return []
	if _get_frontline_cards(game_manager, attacking_player).is_empty():
		return []
	return [action.attacker]

func on_activate_action(game_manager: GameManager, action: CardAction) -> void:
	if game_manager == null:
		if card_owner != null:
			card_owner.move_card(self, card_owner.graveyard_zone)
		return

	var attacking_player := _get_attacking_player(action)
	if attacking_player == null:
		game_manager.note_player_feedback("%s fizzles: the attacking player could not be determined." % card_name)
		if card_owner != null:
			card_owner.move_card(self, card_owner.graveyard_zone)
		return

	var doomed_cards := _get_frontline_cards(game_manager, attacking_player)
	var destroyed_count := 0
	var immune_count := 0
	for doomed_card in doomed_cards:
		if doomed_card == null or doomed_card.current_zone == null or not doomed_card.current_zone.is_board_zone():
			continue
		if game_manager.is_immune_to_source(doomed_card, self):
			immune_count += 1
			continue
		if game_manager.request_send_to_graveyard(doomed_card, Callable(), false, true):
			destroyed_count += 1

	var attacking_name := attacking_player.player_name if attacking_player.player_name != "" else "the attacking player"
	var feedback := ""
	if destroyed_count > 0:
		feedback = "%s triggered and destroyed %d card(s) on %s's frontline." % [
			card_name,
			destroyed_count,
			attacking_name,
		]
	else:
		feedback = "%s triggered, but no cards on %s's frontline were destroyed." % [
			card_name,
			attacking_name,
		]
	if immune_count > 0:
		feedback += " %d card(s) were immune." % immune_count
	game_manager.note_player_feedback(feedback)

	if card_owner != null:
		card_owner.move_card(self, card_owner.graveyard_zone)

func _get_attacking_player(action: CardAction) -> Player:
	if action == null:
		return null
	var source_action := action.response_to if action.response_to != null else action
	if source_action == null:
		return null
	var attacker := source_action.attacker
	if attacker != null:
		return attacker.get_controller()
	return source_action.source_player

func _get_frontline_cards(game_manager: GameManager, player: Player) -> Array[Card]:
	var doomed_cards: Array[Card] = []
	if game_manager == null or player == null:
		return doomed_cards
	for zone in player.frontline_zones:
		if zone == null:
			continue
		for card in zone.cards:
			if card != null:
				doomed_cards.append(card)
	return doomed_cards
