extends CreatureCard
class_name TitanicMech

func _init() -> void:
	super._init()
	card_name = "Titanic Mech"
	card_types = ["Machine", "Mech", "Atlanitan Creature"]
	level = 5
	mana_cost = 7
	sacrifice_cost = 0
	speed = 1
	resilience = 35
	strength = 37
	ability_text = ""
	flavor_text = "Titan class mechs are heavily armoured moving fortresses, capable of sustaining a garrison for years at a time if necessary."
	culture = "Atlanitan"
	artist = "Stanley Vay"
	art_path = "res://images/card_art/creatures/Titanic_Mech.jpg"
