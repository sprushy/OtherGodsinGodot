extends PowerCard
class_name AnankesBinding

const UNLOCK_COST := 2
const ACTIVATION_COST := 3
const RETURN_DELAY_TURNS := 2

var stored_cards: Array[Card] = []
var turns_until_return: int = -1
var is_active_binding: bool = false

func _init() -> void:
	super._init()
	card_name = "Ananke's Binding"
	mana_cost = UNLOCK_COST
	culture = "Olympic"
	card_types = ["Power", "Fate Manipulation"]

	ability_text = "Pay 3 mana: Search a card from your deck and put it under this card; at the end of your second turn after activation, place it on top of your deck. If your deck is shuffled you must shuffle cards under this card back into the deck."
	art_path = "res://images/card_art/anankes_binding.png"


func on_unlock(game_manager: GameManager) -> void:
	print(card_name + " unlocked.")


func can_activate(player, game_manager: GameManager) -> bool:
	if player == null:
		return false
	if not player.has_method("get_deck"):
		return false
	if player.mana < ACTIVATION_COST:
		return false

	var deck = player.get_deck()
	return deck != null and deck.size() > 0


func activate(player, chosen_card: Card, game_manager: GameManager) -> bool:
	if not can_activate(player, game_manager):
		return false
	if chosen_card == null:
		return false

	var deck = player.get_deck()
	if deck == null or not deck.has(chosen_card):
		return false

	player.spend_mana(ACTIVATION_COST)
	deck.erase(chosen_card)
	stored_cards.append(chosen_card)

	# Reset timer each time the card is activated.
	turns_until_return = RETURN_DELAY_TURNS
	is_active_binding = true

	print(card_name + ": " + chosen_card.card_name + " was placed under this card.")
	return true


func on_turn_end(player, game_manager: GameManager) -> void:
	if not is_active_binding:
		return
	if stored_cards.is_empty():
		is_active_binding = false
		turns_until_return = -1
		return

	# Assumes this is called only for this card's controller at the end of their turn.
	turns_until_return -= 1

	if turns_until_return <= 0:
		_return_stored_cards_to_top_of_deck(player)
		is_active_binding = false
		turns_until_return = -1


func on_deck_shuffled(player, game_manager: GameManager) -> void:
	if stored_cards.is_empty():
		return

	var deck = player.get_deck()
	if deck == null:
		return

	for stored_card in stored_cards:
		deck.append(stored_card)

	stored_cards.clear()

	if player.has_method("shuffle_deck"):
		player.shuffle_deck()
	elif deck.has_method("shuffle"):
		deck.shuffle()

	is_active_binding = false
	turns_until_return = -1

	print(card_name + ": Stored cards were shuffled back into the deck.")


func _return_stored_cards_to_top_of_deck(player) -> void:
	if stored_cards.is_empty():
		return

	var deck = player.get_deck()
	if deck == null:
		return

	# Last stored ends up deepest; first stored ends up on top.
	for i in range(stored_cards.size() - 1, -1, -1):
		deck.push_front(stored_cards[i])

	print(card_name + ": " + str(stored_cards.size()) + " stored card(s) placed on top of the deck.")
	stored_cards.clear()
