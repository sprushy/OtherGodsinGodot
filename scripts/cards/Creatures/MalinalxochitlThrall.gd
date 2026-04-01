extends CreatureCard
class_name MalinalxochitlThrall

const ART_PATH := "res://images/card_art/creatures/MalinalxochitlThrall.png"

func _init() -> void:
	super._init()
	card_name = "Malinalxochitl Thrall"
	card_types = ["Thrall", "Human", "Monster", "Animal", "Insect", "Warrior", "Nahuatl Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 17
	strength = 22
	ability_text = ""
	flavor_text = "Imbued with the tail of a scorpion and equipped with conjured moonstone axe and bindings; Malinalxochitl's thralls are barely recognizable as men."
	culture = "Nahuatl"
	artist = ""
	art_path = ART_PATH
