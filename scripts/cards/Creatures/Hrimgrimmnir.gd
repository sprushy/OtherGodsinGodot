extends CreatureCard
class_name Hrimgrimmnir

func _init() -> void:
	super._init()
	card_name = "Hrimgrimmnir"
	card_types = ["Giant", "Ice", "Norse Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 20
	strength = 20
	flavor_text = "His three heads all think up their own torments for interlopers."
	ability_text = ""
	culture = "Norse"
	artist = "Azedar Raptahalion"
	art_path = "res://images/card_art/creatures/HrimgrimmnirEdit.png"
