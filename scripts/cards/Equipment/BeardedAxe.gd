extends EquipmentCard
class_name BeardedAxe

func _init() -> void:
	super._init()
	card_name = "Bearded Axe"
	culture = "Norse"
	card_types = ["Weapon", "Axe"]
	mana_cost = 0
	strength_modifier = 5
	ability_text = "Gain 5 Str. Norse Warriors gain an additional 8 Str when attacking defensive stance creatures."
	flavor_text = ""
	art_path = "res://images/card_art/equipment/Bearded Axe(web).jpg"
	artist = "Ricarrdo Zoppello"

func get_bonus_strength_vs_defense(attacker: Card) -> int:
	if attacker.culture == "Norse" and attacker.has_type("Warrior"):
		return 8
	return 0
