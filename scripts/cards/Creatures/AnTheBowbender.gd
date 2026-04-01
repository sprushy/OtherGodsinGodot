extends CreatureCard
class_name AnTheBowbender

func _init() -> void:
	super._init()
	card_name = "Án the Bowbender"
	card_types = ["Human", "Warrior", "Archer", "Norse Creature"]
	level = 3
	mana_cost = 0
	speed = 2
	resilience = 5
	strength = 21
	sacrifice_cost = 0
	ability_text = ""
	flavor_text = "\"Án is a dangerous reminder that not all Norse heroes lie within the bounds of law\"\n~Thórir"
	culture = "Norse"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/an_the_bowbender.jpg"
