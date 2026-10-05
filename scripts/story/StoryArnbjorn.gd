extends CreatureCard
class_name StoryArnbjorn

const ART_PATH := "res://images/story/Arnbjorn.png"

func _init() -> void:
	super._init()
	card_name = "Arnbjørn"
	card_types = ["Human", "Warrior", "Norse Creature"]
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	strength = 16
	resilience = 16
	speed = 1
	culture = "Norse"
	art_path = ART_PATH
	art_variants = [ART_PATH]
	is_single_player_card = true
