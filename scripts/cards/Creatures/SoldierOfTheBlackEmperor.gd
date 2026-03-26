extends CreatureCard
class_name SoldierOfTheBlackEmperor

func _init() -> void:
	super._init()
	card_name = "Soldier of the Black Emperor"
	card_types = ["Dragon", "Long", "Aerial", "Tian Creature"]
	level = 6
	mana_cost = 6
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	speed = 2
	resilience = 32
	strength = 35
	ability_text = ""
	flavor_text = "In the falling days of Shang, the Black Emperor and his kin were called upon to lead the twelve heavenly legions into battle against the demon king."
	culture = "Tian"
	artist = "Riccardo Zoppello"
	art_path = "res://images/card_art/creatures/Heidi, the black dragon(print).jpg"
