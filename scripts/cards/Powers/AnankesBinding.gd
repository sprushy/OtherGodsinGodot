extends PowerCard
class_name AnankesBinding

const UNLOCK_COST := 2
const ACTIVATION_COST := 3
# Count the end of the activation turn and the end of the owner's next turn.
const RETURN_DELAY_TURNS := 2
const ART_PATH := "res://images/card_art/powers/anankes_binding.jpg"

var stored_cards: Array[Card] = []
var _turns_until_return: Dictionary[Card, int] = {}

func _init() -> void:
	super._init()
	card_name = "Ananke's Binding"
	mana_cost = UNLOCK_COST
	culture = "Olympic"
	card_types = ["Power", "Fate Manipulation"]
	ability_text = "Pay %d mana: [b]Search[/b] a card and place it under Ananke's Binding. At the end of your next turn, [b]Prime[/b] it." % ACTIVATION_COST
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
	card_owner.deck_zone.shuffle_deck()
	stored_cards.append(chosen_card)
	_turns_until_return[chosen_card] = RETURN_DELAY_TURNS
	_emit_visual_state_changed()
	print(card_name + ": " + chosen_card.card_name + " was placed under this card. Deck shuffled.")

func on_turn_end(game_manager: GameManager) -> void:
	super.on_turn_end(game_manager)
	if game_manager == null or game_manager.current_player != card_owner:
		return
	if stored_cards.is_empty():
		return

	var due_cards: Array[Card] = []
	for card in stored_cards:
		_turns_until_return[card] -= 1
		if _turns_until_return[card] <= 0:
			due_cards.append(card)
	_prime_due_cards(due_cards, game_manager)
	_emit_visual_state_changed()

func on_deck_shuffled() -> void:
	if stored_cards.is_empty():
		return
	for stored_card in stored_cards:
		card_owner.deck_zone.cards.append(stored_card)
	stored_cards.clear()
	_turns_until_return.clear()
	card_owner.deck_zone.shuffle_deck()
	_emit_visual_state_changed()
	print(card_name + ": Stored cards were shuffled back into the deck.")

func _prime_due_cards(due_cards: Array[Card], game_manager: GameManager) -> void:
	if due_cards.is_empty():
		return
	var primed_names: Array[String] = []
	for card in due_cards:
		stored_cards.erase(card)
		_turns_until_return.erase(card)
	for i in range(due_cards.size() - 1, -1, -1):
		var card := due_cards[i]
		primed_names.append(card.card_name)
		card_owner.deck_zone.prime_card(card)
	print(card_name + ": " + str(due_cards.size()) + " stored card(s) placed on top of the deck.")
	if game_manager != null:
		var primed_label := ", ".join(primed_names)
		var card_label := "card" if primed_names.size() == 1 else "cards"
		game_manager.note_player_feedback("%s primed %s %s." % [card_name, card_label, primed_label])

func get_hover_stored_cards(_viewer: Player = null) -> Array[Card]:
	var cards: Array[Card] = []
	for stored_card in stored_cards:
		if stored_card != null:
			cards.append(stored_card)
	return cards

func get_hover_stored_cards_title(_viewer: Player = null) -> String:
	return "Bound Cards"

func get_serialized_state() -> Dictionary:
	var state := super.get_serialized_state()
	var stored_entries: Array[Dictionary] = []
	for stored_card in stored_cards:
		if stored_card == null:
			continue
		stored_entries.append({
			"card": GameState.serialize_embedded_card(stored_card),
			"turns_until_return": _turns_until_return[stored_card],
		})
	state["stored_cards"] = stored_entries
	return state

func apply_serialized_state(state: Dictionary) -> void:
	super.apply_serialized_state(state)
	stored_cards.clear()
	_turns_until_return.clear()
	var legacy_countdown := int(state.get("turns_until_return", RETURN_DELAY_TURNS))
	for entry_value in state.get("stored_cards", []):
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		var card_data = entry.get("card", {})
		if not (card_data is Dictionary):
			continue
		var stored_card := GameState.deserialize_embedded_card(card_data as Dictionary)
		if stored_card == null:
			continue
		stored_card.card_owner = card_owner
		stored_card.current_zone = null
		stored_cards.append(stored_card)
		_turns_until_return[stored_card] = maxi(1, int(entry.get("turns_until_return", legacy_countdown)))

func get_hover_detail_lines(viewer: Player = null) -> Array[String]:
	var details := super.get_hover_detail_lines(viewer)
	if stored_cards.is_empty():
		return details

	for stored_card in stored_cards:
		if stored_card == null:
			continue
		var remaining := _turns_until_return[stored_card]
		var line := "Holding %s (Primes in %d of your turn ends)" % [stored_card.card_name, remaining]
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
