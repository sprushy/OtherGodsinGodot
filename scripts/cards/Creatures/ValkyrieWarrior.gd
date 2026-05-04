extends CreatureCard
class_name ValkyrieWarrior

const ART_PATH := "res://images/card_art/creatures/ValkyrieWarrior.png"

func _init() -> void:
	super._init()
	card_name = "Valkyrie Warrior"
	card_types = ["Aerial", "Warrior", "Valkyrie", "Norse Creature"]
	level = 4
	mana_cost = 2
	sacrifice_cost = 0
	speed = 3
	resilience = 21
	strength = 26
	ability_text = ""
	culture = "Norse"
	artist = "Unknown"
	art_path = ART_PATH
