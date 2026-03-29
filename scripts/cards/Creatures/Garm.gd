extends CreatureCard
class_name GarmWatchdogOfHel

const ART_PATH := "res://images/card_art/creatures/garm_watchdog_of_hel.png"

func _init() -> void:
	super._init()
	card_name = "Garm, Watchdog of Hel"
	card_types = ["Animal", "Canine", "Norse Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 18
	strength = 20
	ability_text = "[b]Watchbeast[/b] ([b]Passive[/b]): While this Creature is in play, no effects which affect cards in the grave or activate in the grave may be activated."
	flavor_text = ""
	culture = "Norse"
	artist = "Ricarrdo Zoppello"
	art_path = ART_PATH

# Used by GameManager._is_watchbeast_active() to identify this passive.
func is_watchbeast() -> bool:
	return true
