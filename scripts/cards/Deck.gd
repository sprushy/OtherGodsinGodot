extends Resource
class_name Deck

@export var deck_id: String = ""
@export var name: String = "New Deck"
@export var cards: Dictionary = {} # card_name (String) -> count (int)
@export var created_unix: int = 0
@export var updated_unix: int = 0

func _init(p_deck_id: String = "", p_name: String = "New Deck", p_cards: Dictionary = {}) -> void:
	deck_id = p_deck_id
	name = p_name
	cards = p_cards.duplicate(true)
	if created_unix == 0:
		created_unix = int(Time.get_unix_time_from_system())
	if updated_unix == 0:
		updated_unix = created_unix

func get_total_card_count() -> int:
	var total := 0
	for count in cards.values():
		total += int(count)
	return total

func add_card(card_name: String, count: int = 1) -> void:
	var current = cards.get(card_name, 0)
	cards[card_name] = current + count
	updated_unix = int(Time.get_unix_time_from_system())

func remove_card(card_name: String, count: int = 1) -> void:
	if not cards.has(card_name):
		return
	var current = cards[card_name]
	if current <= count:
		cards.erase(card_name)
	else:
		cards[card_name] = current - count
	updated_unix = int(Time.get_unix_time_from_system())

func to_dictionary() -> Dictionary:
	return {
		"deck_id": deck_id,
		"name": name,
		"cards": cards.duplicate(true),
		"created_unix": created_unix,
		"updated_unix": updated_unix
	}

static func from_dictionary(dict: Dictionary) -> Deck:
	var deck = Deck.new(
		str(dict.get("deck_id", "")),
		str(dict.get("name", "New Deck")),
		dict.get("cards", {})
	)
	deck.created_unix = int(dict.get("created_unix", deck.created_unix))
	deck.updated_unix = int(dict.get("updated_unix", deck.updated_unix))
	return deck
