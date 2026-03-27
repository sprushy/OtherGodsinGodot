extends PowerCard
class_name AcceleratedFate

const DRAW_COST := 5
const DEFAULT_ART := "res://images/card_art/powers/accelerated_fate.png"
const USED_ART := "res://images/card_art/powers/accelerated_fate_used.png"

func _init() -> void:
	super._init()
	card_name = "Accelerated Fate"
	culture = "Neutral"
	mana_cost = 1
	ability_text = "[b]Unlock[/b] (1): [b]Activate[/b] - Pay 5 mana to draw a card."
	art_path = DEFAULT_ART
	exhausted_art_path = USED_ART

func can_activate(game_manager: GameManager) -> bool:
	return not is_face_down \
		and not is_muted \
		and not is_activation_locked(game_manager) \
		and card_owner == game_manager.current_player \
		and card_owner.mana >= get_activation_mana_cost(DRAW_COST, game_manager) \
		and not is_used

func activate(game_manager: GameManager, _target: Card = null) -> void:
	var spent_cost := get_activation_mana_cost(DRAW_COST, game_manager)
	if not spend_activation_mana(DRAW_COST, game_manager):
		return
	card_owner.draw_card()
	is_used = true
	switch_to_exhausted_art()
	print("Accelerated Fate: Drew 1 card for " + str(spent_cost) + " mana.")

func on_turn_end(_game_manager: GameManager) -> void:
	super.on_turn_end(_game_manager)
	if not is_used:
		return
	is_used = false
	art_path = DEFAULT_ART
	art_updated.emit(art_path)
