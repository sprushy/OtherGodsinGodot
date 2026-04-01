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

func add_card(card: Card) -> void:
	cards.append(card)
	card.current_zone = self

func remove_card(card: Card) -> void:
	cards.erase(card)
	if card.current_zone == self:
		card.current_zone = null

func get_card_count() -> int:
	return cards.size()

func is_board_zone() -> bool:
	return zone_type in [ZoneType.FRONTLINE, ZoneType.RESERVE, ZoneType.GOD_SLOT, ZoneType.POWER_SLOT]

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
