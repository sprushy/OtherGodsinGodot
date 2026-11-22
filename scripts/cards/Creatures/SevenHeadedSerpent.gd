extends CreatureCard
class_name SevenHeadedSerpent

const ART_PATH := "res://images/card_art/creatures/seven_headed_serpent.jpg"

func _init() -> void:
	super._init()
	card_name = "Seven-Headed Serpent"
	card_types = ["Animal", "Anguine"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 11
	strength = 16
	ability_text = "[b]Unavoidable Strikes[/b] ([b]Passive[/b]): Cannot be intercepted. Can intercept regardless of speed."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func prevents_interception() -> bool:
	return _unavoidable_strikes_is_active()

func can_intercept_regardless_of_speed(_protected_target) -> bool:
	return _unavoidable_strikes_is_active()

func _unavoidable_strikes_is_active() -> bool:
	return not (abilities_suppressed() or is_face_down or is_prepared)
