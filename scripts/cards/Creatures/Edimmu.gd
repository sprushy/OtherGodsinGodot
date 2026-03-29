extends CreatureCard
class_name Edimmu

func _init() -> void:
	super._init()
	card_name = "Edimmu"
	card_types = ["Spirit", "Ghost", "Ancient Creature"]
	level = 2
	mana_cost = 0
	speed = 1
	resilience = 5
	strength = 11
	sacrifice_cost = 0
	ability_text = "[b]Incorporeal[/b] ([b]Passive[/b]): Can only be Engaged by Spirits or faster Mages. Can only Engage Spirits or slower Mages."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricarrdo Zoppello"
	art_path = "res://images/card_art/creatures/edimmu_web_1.jpg"
	incorporeal = true
