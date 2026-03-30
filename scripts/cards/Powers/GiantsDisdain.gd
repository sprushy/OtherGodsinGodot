extends PowerCard
class_name GiantsDisdain

const ART_PATH := "res://images/card_art/powers/giants_disdain.png"

func _init() -> void:
	super._init()
	card_name = "Giant's Disdain"
	mana_cost = 4
	culture = "Neutral"
	card_types = ["Power", "Class Buff", "Giant"]
	ability_text = "Giants you control treat non-Giant opponents' stats as half (rounded down) when calculating follower damage, and gain +5 Speed when intercepting non-Giant creatures."
	art_path = ART_PATH

func on_unlock(_game_manager: GameManager) -> void:
	print(card_name + " unlocked.")
