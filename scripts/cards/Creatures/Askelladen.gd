extends CreatureCard
class_name Askelladen

const ART_PATH := "res://images/card_art/creatures/AskelledanAI1.png"
const ALT_ART_PATH := "res://images/card_art/creatures/askelledan_alt.png"

func _init() -> void:
	super._init()
	card_name = "Askelladen"
	card_types = ["Human", "Warrior", "Norse Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 10
	strength = 12
	ability_text = "Tactical Retreat: When this face-up card attacks or is attacked by a card with equal or lower speed, you may [b]Shelve[/b] both."
	flavor_text = ""
	culture = "Norse"
	art_path = ART_PATH
	art_variants = [ART_PATH, ALT_ART_PATH]
	targets = true
