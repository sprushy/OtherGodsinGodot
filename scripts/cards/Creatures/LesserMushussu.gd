extends CreatureCard
class_name LesserMushussu

func _init() -> void:
	super._init()
	card_name = "Lesser Mushussu"
	card_types = ["Dragon", "Animal", "Ancient Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 15
	strength = 19
	flavor_text = "Some kings of old thought to keep Mushussu as pets, but these inclinations always vanished when they saw the size and ferocity of the matured beast."
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/Lesser Mushussu(print).jpg"
