extends PowerCard
class_name FerociousDefence

const UNLOCK_COST := 6
const ART_PATH := "res://images/card_art/powers/ferocious_defence.jpg"

func _init() -> void:
	super._init()
	card_name = "Ferocious Defence"
	mana_cost = UNLOCK_COST
	culture = "Neutral"
	card_types = ["Power", "Creature Buff"]
	ability_text = "Friendly creatures in defensive stance destroy creatures they are in combat with if their RES is higher than or equal to the opposing creature's STR."
	art_path = ART_PATH

func on_unlock(_game_manager: GameManager) -> void:
	print(card_name + " unlocked.")
