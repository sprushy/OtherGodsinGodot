extends PowerCard
class_name AnankesBinding

const UNLOCK_COST := 2
const ACTIVATION_COST := 3
const RETURN_DELAY_TURNS := 2
const ART_PATH := "res://images/card_art/anankes_binding.jpg"

var stored_cards: Array[Card] = []
var turns_until_return: int = -1

func _init() -> void:
	super._init()
	card_name = "Ananke's Binding"
	mana_cost = UNLOCK_COST
	culture = "Olympic"
	card_types = ["Power", "Fate Manipulation"]
	ability_text = "Pay 3 mana: Search a card from your deck and put it under this card; at the end of your second turn after activation, place it on top of your deck."
	art_path = ART_PATH

func on_unlock(_game_manager: GameManager) -> void:
	print(card_name + " unlocked.")

func can_activate(game_manager: GameManager) -> bool:
	return not is_face_down \
		and card_owner == game_manager.current_player \
		and card_owner.mana >= ACTIVATION_COST \
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

	card_owner.spend_mana(ACTIVATION_COST)
	card_owner.deck_zone.cards.erase(chosen_card)
	stored_cards.append(chosen_card)
	turns_until_return = RETURN_DELAY_TURNS
	print(card_name + ": " + chosen_card.card_name + " was placed under this card.")

func on_turn_end(_game_manager: GameManager) -> void:
	if stored_cards.is_empty():
		turns_until_return = -1
		return

	turns_until_return -= 1
	if turns_until_return <= 0:
		_return_stored_cards_to_top_of_deck()
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

func _return_stored_cards_to_top_of_deck() -> void:
	if stored_cards.is_empty():
		return
	for i in range(stored_cards.size() - 1, -1, -1):
		card_owner.deck_zone.cards.insert(0, stored_cards[i])
	print(card_name + ": " + str(stored_cards.size()) + " stored card(s) placed on top of the deck.")
	stored_cards.clear()
