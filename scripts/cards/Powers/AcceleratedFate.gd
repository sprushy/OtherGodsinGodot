extends PowerCard
class_name AcceleratedFate

const DRAW_COST := 5

func _init() -> void:
	super._init()
	card_name = "Accelerated Fate"
	culture = "Neutral"
	mana_cost = 1
	ability_text = "Unlock (1): Active — Pay 5 mana to draw 1 card."
	art_path = "res://images/card_art/accelerated_fate.png"

func can_activate(game_manager: GameManager) -> bool:
	return not is_face_down \
		and card_owner == game_manager.current_player \
		and card_owner.mana >= DRAW_COST

func activate(game_manager: GameManager, _target: Card = null) -> void:
	card_owner.spend_mana(DRAW_COST)
	card_owner.draw_card()
	print("Accelerated Fate: Drew 1 card for " + str(DRAW_COST) + " mana.")
