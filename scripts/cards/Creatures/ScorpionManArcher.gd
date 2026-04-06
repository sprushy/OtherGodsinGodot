extends CreatureCard
class_name ScorpionManArcher

const ART_PATH := "res://images/card_art/creatures/scorpion_man_archer.jpg"

func _init() -> void:
	super._init()
	card_name = "Scorpion-Man Archer"
	card_types = ["Monster", "Animal", "Insect", "Warrior", "Archer", "Ancient Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 13
	strength = 21
	ability_text = ""
	flavor_text = "Guardian of the end of the world"
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
