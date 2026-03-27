extends StructureCard
class_name EriduCityOfSages

const MANA_PER_MAGE := 2

func _init() -> void:
	super._init()
	card_name = "Eridu, City of Sages"
	card_types = ["Dwelling", "City", "Ancient Structure"]
	level = 4
	mana_cost = 0
	discard_cost = 1
	resilience = 30
	speed = 0
	strength = 0
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	ability_text = "As an additional cost to play this card, choose and discard a card from your hand.\n[b]Upkeep[/b]: Gain 2 mana for each Mage you have on the field."
	culture = "Ancient"
	artist = "Ricarrdo Zoppello"
	art_path = "res://images/card_art/structures/City of Sages(print).jpg"

func on_turn_start(game_manager: GameManager) -> void:
	if game_manager == null or card_owner == null:
		return
	var controller := get_controller()
	if controller != card_owner:
		return
	var mage_count := _count_friendly_mages()
	if mage_count <= 0:
		return
	card_owner.gain_mana(mage_count * MANA_PER_MAGE)

func _count_friendly_mages() -> int:
	if card_owner == null:
		return 0
	var total := 0
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if card != null and card.card_type == Card.CardType.CREATURE and card.has_type("Mage"):
				total += 1
	return total
