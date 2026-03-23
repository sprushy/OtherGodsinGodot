extends PowerCard
class_name AcceleratedFate

const DRAW_COST := 5
const DEFAULT_ART := "res://images/card_art/accelerated_fate.png"
const USED_ART := "res://images/card_art/accelerated_fate_used.png"

func _init() -> void:
	super._init()
	card_name = "Accelerated Fate"
	culture = "Neutral"
	mana_cost = 1
	ability_text = "Unlock (1): Active - Pay 5 mana to draw 1 card."
	art_path = DEFAULT_ART
	exhausted_art_path = USED_ART

func can_activate(game_manager: GameManager) -> bool:
	return not is_face_down \
		and card_owner == game_manager.current_player \
		and card_owner.mana >= DRAW_COST \
		and not is_used

func activate(game_manager: GameManager, _target: Card = null) -> void:
	card_owner.spend_mana(DRAW_COST)
	card_owner.draw_card()
	is_used = true
	switch_to_exhausted_art()
	print("Accelerated Fate: Drew 1 card for " + str(DRAW_COST) + " mana.")

func on_turn_end(_game_manager: GameManager) -> void:
	if not is_used:
		return
	is_used = false
	art_path = DEFAULT_ART
	art_updated.emit(art_path)
