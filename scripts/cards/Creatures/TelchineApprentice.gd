extends CreatureCard
class_name TelchineApprentice

const ART_PATH := "res://images/card_art/creatures/TelchineApprenticeEdit.png"

func _init() -> void:
	super._init()
	card_name = "Telchine Apprentice"
	card_types = ["Human", "Mage", "Smith", "Olympic Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 21
	strength = 21
	ability_text = "[b]Imbue[/b] ([b]Passive[/b]): Weapons equipped from your hand gain: \"This can target creatures and structures that cannot normally be attacked, and can destroy creatures that cannot normally be destroyed in combat.\""
	flavor_text = ""
	culture = "Olympic"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
