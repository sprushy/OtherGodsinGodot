extends EquipmentCard
class_name BeardedAxe

func _init() -> void:
	super._init()
	card_name = "Bearded Axe"
	culture = "Norse"
	card_types = ["Weapon", "Axe"]
	mana_cost = 0
	strength_modifier = 5
	ability_text = "The equipped creature gains +5 STR. It gains another +8 STR when attacking a creature in Defensive stance."
	flavor_text = ""
	art_path = "res://images/card_art/equipment/Bearded Axe(web).jpg"
	artist = "Ricarrdo Zoppello"

func get_bonus_strength_vs_defense(_attacker: Card) -> int:
	return 8
