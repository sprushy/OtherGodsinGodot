extends CreatureCard
class_name Askelladen

func _init() -> void:
	super._init()
	card_name = "Askelladen"
	card_types = ["Human", "Warrior", "Norse Creature"]
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 10
	strength = 12
	flavor_text = "Tactful Retreat: When this face-up card attacks or is attacked by a card of equal, lesser, or no speed, you may return both cards to the bottom of their decks."
	culture = "Norse"
