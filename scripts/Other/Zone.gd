# Zone.gd
extends RefCounted
class_name Zone

enum ZoneType {
	HAND,
	DECK,
	GRAVEYARD,
	ABYSS,
	FRONTLINE,
	RESERVE,
	GOD_SLOT,
	POWER_SLOT
}

@export var zone_type: ZoneType
@export var zone_index: int = -1
var cards: Array[Card] = []
var zone_owner: Player
# Authoritative knowledge for the deck owner. Never serialized to opponents.
var known_top_card: Card

func get_unordered_deck_cards() -> Array[Card]:
	var unordered := cards.duplicate()
	# A stable order independent of deck position also makes tie breaks safe.
	unordered.sort_custom(func(a: Card, b: Card) -> bool: return a.uid < b.uid)
	return unordered

func shuffle_deck() -> void:
	known_top_card = null
	cards.shuffle()

func prime_card(card: Card, known_to_owner: bool = true) -> void:
	cards.erase(card)
	cards.push_front(card)
	known_top_card = card if known_to_owner else null

func shelve_deck_card(card: Card) -> void:
	if card == known_top_card:
		known_top_card = null
	cards.erase(card)
	cards.append(card)

func add_card(card: Card) -> void:
	cards.append(card)
	card.current_zone = self
	if zone_owner != null and is_in_play_zone() \
			and (card.is_god or card.has_type("Active God")):
		zone_owner.has_had_god_in_play = true

func remove_card(card: Card) -> void:
	if card == known_top_card:
		known_top_card = null
	cards.erase(card)
	if card.current_zone == self:
		card.current_zone = null

func get_card_count() -> int:
	return cards.size()

func is_board_zone() -> bool:
	return zone_type in [ZoneType.FRONTLINE, ZoneType.RESERVE]

func is_in_play_zone() -> bool:
	return is_board_zone() or zone_type in [ZoneType.GOD_SLOT, ZoneType.POWER_SLOT]

func get_creature() -> Card:
	for card in cards:
		if card.is_creature_card():
			return card
	return null

func get_equipment() -> Array[Card]:
	var equip_list: Array[Card] = []
	for card in cards:
		if card.card_type == Card.CardType.EQUIPMENT and card.equipped_on == null:
			equip_list.append(card)
	return equip_list
