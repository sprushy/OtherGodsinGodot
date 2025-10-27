extends CreatureCard
class_name Allu

func _init() -> void:
	super._init()
	card_name = "Allu"
	card_types = ["Demon", "Ancient Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 16
	strength = 19
	flavor_text = "Stupefy: Instead of attacking, this card may put one creature of equal or lower level to sleep for as long as this card remains on the field."
	culture = "Ancient"
