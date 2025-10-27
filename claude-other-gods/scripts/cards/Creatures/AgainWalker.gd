extends CreatureCard
class_name AgainWalker

func _init() -> void:
	super._init()
	card_name = "Again-Walker"
	card_types = ["Undead", "Draug", "Warrior", "Norse Creature"]
	level = 2
	mana_cost = 1
	sacrifice_cost = 0
	speed = 1
	resilience = 10
	strength = 15
	flavor_text = "Return: If this card is destroyed by combat you may return it to your field at the end of the same turn."
	culture = "Norse"
