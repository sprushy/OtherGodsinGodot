extends CreatureCard
class_name Enkidu

func _init() -> void:
	super._init()
	card_name = "Enkidu"
	card_types = ["Human", "Warrior", "Ancient Creature"]
	level = 4
	mana_cost = 2
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	speed = 2
	resilience = 18
	strength = 27
	ability_text = ""
	flavor_text = "Gilgamesh's companion; he had to be lured into civilization incrementally."
	culture = "Ancient"
	artist = "Ricarrdo Zoppello"
	art_path = "res://images/card_art/creatures/Enkidu(print).jpg"
