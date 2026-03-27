extends CreatureCard
class_name DevastatorMech

func _init() -> void:
	super._init()
	card_name = "Devastator Mech"
	card_types = ["Machine", "Mech", "Atlanitan Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 2
	strength = 23
	ability_text = ""
	flavor_text = "Devastators can punch holes in even the thickest armour."
	culture = "Atlanitan"
	artist = "Stanley Vay"
	art_path = "res://images/card_art/creatures/Glasscannon_Mech.jpg"
