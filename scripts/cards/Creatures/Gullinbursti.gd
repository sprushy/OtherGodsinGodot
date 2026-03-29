extends CreatureCard
class_name Gullinbursti

func _init() -> void:
	super._init()
	card_name = "Gullinbursti"
	card_types = ["Animal", "Porcine", "Norse Creature"]
	level = 4
	mana_cost = 3
	sacrifice_cost = 0
	speed = 4
	resilience = 25
	strength = 24
	ability_text = ""
	flavor_text = "Forged by Dwarven smiths for the God Freyr, Gullinbursti can run through air and water and moves faster than any horse."
	culture = "Norse"
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/creatures/gullinbursti.png"
