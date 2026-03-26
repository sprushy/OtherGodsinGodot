extends CreatureCard
class_name CombatMech

const TOKEN_ART_PATH := "res://images/card_art/creatures/AIMechToken.png"

func _init() -> void:
	super._init()
	card_name = "Combat Mech"
	card_types = ["Token", "Machine", "Mech", "Atlanitan Creature"]
	is_token = true
	can_be_used_for_creature_sacrifice = false
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	speed = 1
	resilience = 18
	strength = 18
	ability_text = ""
	flavor_text = ""
	culture = "Atlanitan"
	artist = ""
	art_path = TOKEN_ART_PATH
