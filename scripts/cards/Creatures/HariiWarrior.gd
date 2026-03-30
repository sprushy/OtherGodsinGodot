extends CreatureCard
class_name HariiWarrior

func _init() -> void:
	super._init()
	card_name = "Harii Warrior"
	card_types = ["Human", "Warrior", "Norse Creature"]
	level = 3
	mana_cost = 0
	speed = 2
	resilience = 9
	strength = 22
	sacrifice_cost = 0
	ability_text = ""
	culture = "Norse"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/HariiWarriorEdit.png"
