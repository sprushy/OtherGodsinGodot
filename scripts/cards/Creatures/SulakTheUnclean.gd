extends CreatureCard
class_name SulakTheUnclean

const ART_PATH := "res://images/card_art/creatures/Sulak the Unclean(web).jpg"

func _init() -> void:
	super._init()
	card_name = "Sulak the Unclean"
	card_types = ["Demon", "Ancient Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 15
	strength = 19
	ability_text = ""
	flavor_text = "\"Sulak likes to strike when his victims are most vulnerable...\""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
