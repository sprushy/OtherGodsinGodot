extends CreatureCard
class_name AnTheBowbender

func _init() -> void:
	super._init()
	card_name = "Ãn the Bow-bender"
	card_type = Card.CardType.CREATURE
	card_types = ["Animal", "Ursine"]
	level = 3
	mana_cost = 0
	speed = 2
	resilience = 23
	strength = 18
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	flavor_text = "\"Growl\""
	culture = "Norse"
	art_path = "res://images/card_art/creatures/an_the_bowbender.jpg"
