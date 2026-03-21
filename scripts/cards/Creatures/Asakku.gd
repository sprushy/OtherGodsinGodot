extends CreatureCard
class_name Asakku

func _init() -> void:
	super._init()
	card_name = "Asakku"
	card_types = ["Demon", "Ancient Creature"]
	level = 2
	mana_cost = 1
	sacrifice_cost = 0
	speed = 1
	resilience = 13
	strength = 15
	flavor_text = "Offering (passive): When you destroy an enemy creature in combat, gain 2 mana."
	culture = "Ancient"
