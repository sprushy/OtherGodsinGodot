extends CreatureCard
class_name ScorpionManWarrior

const ART_PATH := "res://images/card_art/creatures/scorpion_man_warrior.jpg"

func _init() -> void:
	super._init()
	card_name = "Scorpion-Man Warrior"
	card_types = ["Monster", "Animal", "Insect", "Warrior", "Ancient Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 22
	strength = 20
	ability_text = ""
	flavor_text = "Guardian of the end of the world"
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
