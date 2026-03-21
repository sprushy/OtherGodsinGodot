extends CreatureCard
class_name AsagTheDestroyer

func _init() -> void:
	super._init()
	card_name = "Asag the Destroyer"
	card_types = ["Demon", "Ancient Creature"]
	level = 5
	mana_cost = 0
	sacrifice_cost = 1
	speed = 1
	resilience = 21
	strength = 33
	flavor_text = "Class Rend (passive): Void a creature and everything equipped to it when it is destroyed by a friendly Demon."
	culture = "Ancient"
