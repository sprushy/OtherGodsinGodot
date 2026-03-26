extends StructureCard
class_name DoorwayToTheVoid

func _init() -> void:
	super._init()
	card_name = "Doorway to the Void"
	card_types = ["Gateway"]
	level = 1
	mana_cost = 0
	resilience = 30
	speed = 0
	strength = 0
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	name_at_bottom = true
	art_path = "res://images/card_art/structures/Doorway to the Void(web).jpg"
	ability_text = "Gateway ([b]Passive[/b]): If a creature from either side of the field would be sent to the graveyard, you may send it to the void instead."

func replaces_graveyard_send(card: Card, _game_manager: GameManager) -> bool:
	if abilities_suppressed():
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if card == null or card.card_type != Card.CardType.CREATURE:
		return false
	return card.current_zone != null and card.current_zone.is_board_zone()
