extends StructureCard
class_name Colosseum

const ART_PATH := "res://images/card_art/structures/colosseum.png"

func _init() -> void:
	super._init()
	card_name = "Colosseum"
	card_types = ["Arena"]
	level = 3
	mana_cost = 2
	sacrifice_cost = 0
	resilience = 30
	strength = 0
	speed = 0
	ability_text = "All creatures must be summoned in face-up aggressive stance."
	flavor_text = ""
	culture = "Olympic"
	artist = "User provided art"
	art_path = ART_PATH

func forces_aggressive_summon() -> bool:
	return true
