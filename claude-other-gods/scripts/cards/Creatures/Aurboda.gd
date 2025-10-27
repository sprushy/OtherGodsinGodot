extends CreatureCard
class_name Aurboda

func _init() -> void:
	super._init()
	card_name = "Aurboda"
	card_types = ["Giant", "Warrior", "Norse Creature"]
	level = 3
	mana_cost = 1
	sacrifice_cost = 0
	speed = 1
	resilience = 3
	strength = 21
	flavor_text = "Pierce: Every time this card destroys a creature in battle, convert 7 of your opponent's followers."
	culture = "Norse"
