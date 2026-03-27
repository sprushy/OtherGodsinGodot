extends PowerCard
class_name AnankesBinding

const UNLOCK_COST := 2
const ACTIVATION_COST := 3
const RETURN_DELAY_TURNS := 2
const ART_PATH := "res://images/card_art/powers/anankes_binding.jpg"

var stored_cards: Array[Card] = []
var turns_until_return: int = -1

func _init() -> void:
	super._init()
	card_name = "Ananke's Binding"
	mana_cost = UNLOCK_COST
	culture = "Olympic"
	card_types = ["Power", "Fate Manipulation"]
	ability_text = "Pay 3 mana: [b]Search[/b] a card and place it under this card. At the end of your second turn after activation, [b]Prime[/b] it."
	art_path = ART_PATH

func on_unlock(_game_manager: GameManager) -> void:
	print(card_name + " unlocked.")

func can_activate(game_manager: GameManager) -> bool:
	return not is_face_down \
		and not is_activation_locked(game_manager) \
		and card_owner == game_manager.current_player \
		and card_owner.mana >= get_activation_mana_cost(ACTIVATION_COST, game_manager) \
		and not card_owner.deck_zone.cards.is_empty()

func get_cards_in_deck() -> Array[Card]:
	return card_owner.deck_zone.cards.duplicate()

func activate(game_manager: GameManager, chosen_card: Card = null) -> void:
	if not can_activate(game_manager):
		return
	if chosen_card == null or chosen_card.current_zone != card_owner.deck_zone:
		print(card_name + ": Invalid deck choice.")
		return
	if not card_owner.deck_zone.cards.has(chosen_card):
		print(card_name + ": Chosen card is no longer in deck.")
		return

	if not spend_activation_mana(ACTIVATION_COST, game_manager):
		return
	card_owner.deck_zone.cards.erase(chosen_card)
	card_owner.deck_zone.cards.shuffle()
	stored_cards.append(chosen_card)
	turns_until_return = RETURN_DELAY_TURNS
	print(card_name + ": " + chosen_card.card_name + " was placed under this card. Deck shuffled.")

func on_turn_end(_game_manager: GameManager) -> void:
	super.on_turn_end(_game_manager)
	if stored_cards.is_empty():
		turns_until_return = -1
		return

	turns_until_return -= 1
	if turns_until_return <= 0:
		_return_stored_cards_to_top_of_deck(_game_manager)
		turns_until_return = -1

func on_deck_shuffled() -> void:
	if stored_cards.is_empty():
		return
	for stored_card in stored_cards:
		card_owner.deck_zone.cards.append(stored_card)
	stored_cards.clear()
	card_owner.deck_zone.cards.shuffle()
	turns_until_return = -1
	print(card_name + ": Stored cards were shuffled back into the deck.")

func _return_stored_cards_to_top_of_deck(game_manager: GameManager = null) -> void:
	if stored_cards.is_empty():
		return
	var primed_names: Array[String] = []
	for i in range(stored_cards.size() - 1, -1, -1):
		primed_names.append(stored_cards[i].card_name)
		card_owner.deck_zone.cards.insert(0, stored_cards[i])
	print(card_name + ": " + str(stored_cards.size()) + " stored card(s) placed on top of the deck.")
	if game_manager != null:
		var primed_label := ", ".join(primed_names)
		var card_label := "card" if primed_names.size() == 1 else "cards"
		game_manager.note_player_feedback("%s primed %s %s." % [card_name, card_label, primed_label])
	stored_cards.clear()

func get_hover_detail_lines(viewer: Player = null) -> Array[String]:
	var details := super.get_hover_detail_lines(viewer)
	if stored_cards.is_empty():
		return details

	if turns_until_return > 0:
		details.append("Priming in %d turn(s)." % turns_until_return)

	for stored_card in stored_cards:
		if stored_card == null:
			continue
		var line := "Holding: " + stored_card.card_name
		var ability_summary := stored_card.get_inline_ability_summary()
		if ability_summary != "":
			line += " - " + ability_summary
		details.append(line)
	return details

func get_activation_cost_hover_data(_game_manager: GameManager = null) -> Dictionary:
	return {
		"base_cost": ACTIVATION_COST,
		"cost_kind": Card.COST_KIND_POWER_ACTIVATION,
		"label": "Activation Cost",
	}
