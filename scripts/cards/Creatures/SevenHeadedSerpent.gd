extends CreatureCard
class_name SevenHeadedSerpent

const ART_PATH := "res://images/card_art/creatures/seven_headed_serpent.jpg"

func _init() -> void:
	super._init()
	card_name = "Seven-Headed Serpent"
	card_types = ["Animal", "Anguine", "Ancient Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 11
	strength = 16
	ability_text = "[b]Unavoidable Strikes[/b] ([b]Passive[/b]): [b]Reach[/b] 2"
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func get_intercept_reach_bonus(
	_game_manager: GameManager = null,
	_attacker: Card = null,
	_protected_target = null
) -> int:
	if abilities_suppressed() or is_face_down or is_stealth or is_prepared:
		return 0
	return 2
