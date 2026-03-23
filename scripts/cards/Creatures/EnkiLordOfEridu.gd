extends CreatureCard
class_name EnkiLordOfEridu

func _init() -> void:
	super._init()
	card_name = "Enki, Lord of Eridu"
	card_types = ["Divine Manifestation", "Mer", "Mage", "Priest", "Sage", "Ancient Creature"]
	level = 8
	mana_cost = 8
	sacrifice_cost = 0
	speed = 1
	resilience = 36
	strength = 32
	ability_text = "Class Immunity (Passive): Friendly Mages are immune to hexes."
	flavor_text = ""
	culture = "Ancient"
	art_path = "res://images/card_art/enki_lord_of_eridu.jpg"
	artist = "Ricarrdo Zoppello"

func protects_from_hex(target: Card) -> bool:
	if abilities_suppressed():
		return false
	if target == null:
		return false
	return (
		target.card_type == Card.CardType.CREATURE
		and target.get_controller() == get_controller()
		and target.has_type("Mage")
	)
