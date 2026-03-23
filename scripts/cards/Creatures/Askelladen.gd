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
	ability_text = "Tactful Retreat: When this face-up card attacks or is attacked by a card of equal or lesser speed, you may [b]Shelve[/b] both cards."
	flavor_text = ""
	culture = "Norse"
	art_path = "res://images/card_art/askelladen.jpg"
	targets = true
