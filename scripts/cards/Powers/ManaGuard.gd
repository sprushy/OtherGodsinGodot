extends PowerCard
class_name ManaGuard

const UNLOCK_COST := 4
const GUARD_PER_MANA := 5
const ART_PATH := "res://images/card_art/powers/ManaGuardArt.png"

func _init() -> void:
	super._init()
	card_name = "Mana Guard"
	mana_cost = UNLOCK_COST
	culture = "Neutral"
	level = 0
	card_types = ["Power", "Defense", "Followers"]
	targets = false
	ability_text = "[b]Unlock[/b] (%d): [b]Activate[/b] - During your turn, pay any amount of mana. Gain %d Guard for each mana paid. When you would take follower damage, Guard is lost first; any excess damage is dealt to your followers." % [UNLOCK_COST, GUARD_PER_MANA]
	art_path = ART_PATH

func can_activate(game_manager: GameManager) -> bool:
	if not super.can_activate(game_manager):
		return false
	return card_owner != null and card_owner.mana > 0

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if is_face_down:
		return card_name + " must be unlocked first."
	if is_muted:
		return card_name + " is muted."
	if game_manager != null and is_activation_locked(game_manager):
		return card_name + " cannot be activated this turn."
	if game_manager != null and card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if card_owner == null or card_owner.mana <= 0:
		return card_name + " needs mana to build Guard."
	return card_name + " cannot activate right now."

func activate_from_command(game_manager: GameManager, command: Dictionary) -> void:
	activate_with_mana(game_manager, int(command.get("mana_amount", 0)))

func activate(game_manager: GameManager, _target: Card = null) -> void:
	var mana_to_spend := card_owner.mana if card_owner != null else 0
	activate_with_mana(game_manager, mana_to_spend)

func activate_with_mana(game_manager: GameManager, mana_to_spend: int) -> int:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return 0
	mana_to_spend = clampi(mana_to_spend, 1, card_owner.mana)
	if not card_owner.spend_mana(mana_to_spend):
		if game_manager != null:
			game_manager.note_player_feedback(card_name + " needs mana to build Guard.")
		return 0
	var guard_gained := mana_to_spend * GUARD_PER_MANA
	card_owner.gain_guard(guard_gained)
	if game_manager != null:
		game_manager.note_player_feedback("%s spent %d mana and gained %d Guard." % [
			card_name,
			mana_to_spend,
			guard_gained,
		])
	return guard_gained
