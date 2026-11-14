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

enum DeckPlacement { UNKNOWN, SHELVED, PRIMED, REVEALED }

@export var zone_type: ZoneType
@export var zone_index: int = -1
var cards: Array[Card] = []
var zone_owner: Player
var _public_deck_placements: Dictionary[Card, DeckPlacement] = {}
var known_top_card: Card:
	get:
		return get_known_deck_card(0)

func get_deck_placement(card: Card) -> DeckPlacement:
	return _public_deck_placements.get(card, DeckPlacement.UNKNOWN)

func get_known_deck_card(index: int) -> Card:
	if index < 0 or index >= cards.size():
		return null
	var card := cards[index]
	return card if _public_deck_placements.has(card) else null

func get_primed_top_card() -> Card:
	var card := known_top_card
	return card if get_deck_placement(card) == DeckPlacement.PRIMED else null

func set_deck_placement(card: Card, placement: DeckPlacement) -> void:
	if placement == DeckPlacement.UNKNOWN:
		_public_deck_placements.erase(card)
	else:
		_public_deck_placements[card] = placement

func reveal_deck_card(card: Card) -> void:
	if card.current_zone == self and get_deck_placement(card) == DeckPlacement.UNKNOWN:
		set_deck_placement(card, DeckPlacement.REVEALED)

func clear_deck_knowledge() -> void:
	_public_deck_placements.clear()

func get_unordered_deck_cards() -> Array[Card]:
	var unordered := cards.duplicate()
	# A stable order independent of deck position also makes tie breaks safe.
	unordered.sort_custom(func(a: Card, b: Card) -> bool: return a.uid < b.uid)
	return unordered

func shuffle_deck() -> void:
	clear_deck_knowledge()
	cards.shuffle()

func prime_card(card: Card) -> void:
	cards.erase(card)
	add_card(card, DeckPlacement.PRIMED)

func shelve_deck_card(card: Card) -> void:
	cards.erase(card)
	add_card(card, DeckPlacement.SHELVED)

func add_card(card: Card, deck_placement: DeckPlacement = DeckPlacement.UNKNOWN) -> void:
	if zone_type == ZoneType.DECK and deck_placement == DeckPlacement.PRIMED:
		cards.push_front(card)
	else:
		cards.append(card)
	if zone_type == ZoneType.DECK:
		set_deck_placement(card, deck_placement)
	card.current_zone = self
	if zone_owner != null and is_in_play_zone() \
			and (card.is_god or card.has_type("Active God")):
		zone_owner.has_had_god_in_play = true

func remove_card(card: Card) -> void:
	_public_deck_placements.erase(card)
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
