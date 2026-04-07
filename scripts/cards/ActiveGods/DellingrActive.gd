extends ActiveGodCard
class_name DellingrActive

const LINKED_GOD_NAME := "Dellingr, the Dayspring"
const ART_PATH := "res://images/card_art/gods/Dellingr(web).jpg"
const REVEAL_SOURCE := "Dellingr Active - Radiate"

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Dellingr, Active God"
	card_types = ["Active God", "Divine Manifestation", "God"]
	level = 11
	mana_cost = 11
	speed = 3
	resilience = 32
	strength = 30
	culture = "Norse"
	flavor_text = "Dellingr's radiance strips away every shadow and leaves hostile magic dormant."
	ability_text = "[b]Radiate[/b] ([b]Impact[/b]): Reveal all your opponent's face-down and in-hand cards until the end of the turn; if they are magical, they cannot be activated this turn; if they have a [b]Reveal[/b] ability, you may choose not to activate them."
	art_path = ART_PATH
	name_at_bottom = true
	artist = "Ricardo Zoppello"

func on_impact(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	var opponent := _get_opponent(game_manager)
	if opponent == null:
		return
	var hidden_cards := _get_hidden_opponent_cards(opponent)
	if hidden_cards.is_empty():
		game_manager.note_player_feedback("%s radiates, but your opponent has no hidden cards to reveal." % card_name)
		return

	var revealed_count := 0
	var locked_count := 0
	for target in hidden_cards:
		if target == null:
			continue
		_reveal_without_triggering_reveal_ability(target, game_manager)
		revealed_count += 1
		if target.is_magical_card():
			target.lock_activation_until_end_of_turn(game_manager.turn_number, REVEAL_SOURCE, self, card_owner)
			locked_count += 1

	var feedback := "%s reveals %d hidden opposing card(s) until end of turn." % [card_name, revealed_count]
	if locked_count > 0:
		feedback += " %d magical card(s) cannot be activated this turn." % locked_count
	game_manager.note_player_feedback(feedback)

func _get_opponent(game_manager: GameManager) -> Player:
	if game_manager == null or card_owner == null:
		return null
	return game_manager.get_opponent(card_owner)

func _get_hidden_opponent_cards(opponent: Player) -> Array[Card]:
	var hidden_cards: Array[Card] = []
	if opponent == null:
		return hidden_cards

	for card in opponent.hand_zone.cards:
		if card != null:
			hidden_cards.append(card)

	for zone in [opponent.god_zone] + opponent.power_zones + opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if _is_hidden_board_card(card):
				hidden_cards.append(card)

	return hidden_cards

func _is_hidden_board_card(card: Card) -> bool:
	if card == null or card.current_zone == null:
		return false
	if card.is_temporarily_revealed():
		return false
	var publicly_revealed_power := card is PowerCard and (card as PowerCard).is_publicly_revealed
	var hidden_face_down := (card.is_face_down or card.is_prepared) and not publicly_revealed_power
	return card.is_stealth or hidden_face_down

func _reveal_without_triggering_reveal_ability(target: Card, game_manager: GameManager) -> void:
	if target == null:
		return
	target.remove_status_effects_by_name("temporarily_revealed")
	target.add_status_effect(
		"temporarily_revealed",
		REVEAL_SOURCE,
		self,
		card_owner,
		{"expires_turn": game_manager.turn_number}
	)
	if game_manager.has_method("notify_card_revealed_by_effect"):
		game_manager.notify_card_revealed_by_effect(target, self)
