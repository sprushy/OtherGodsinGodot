extends CreatureCard
class_name Gallu

const ART_PATH := "res://images/card_art/creatures/gallu.jpg"

func _init() -> void:
	super._init()
	card_name = "Gallu"
	card_types = ["Demon", "Ancient Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 7
	strength = 22
	ability_text = ""
	flavor_text = "Dangerous and implacable, Gallu demons haul their victims to the underworld."
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
