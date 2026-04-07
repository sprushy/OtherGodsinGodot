extends CreatureCard
class_name WarriorDragon

const ART_PATH := "res://images/card_art/creatures/WarriorDragonEdit.png"

func _init() -> void:
	super._init()
	card_name = "Warrior Dragon"
	card_types = ["Dragon", "Warrior", "Aerial", "Ancient Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 22
	strength = 21
	ability_text = ""
	flavor_text = "Cunning and wary, this dragon is among the last of its kind in its Sumerian homeland."
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
