extends PowerCard
class_name SavingGrace

const UNLOCK_COST := 4
const BASE_RESPONSE_SPEED := 5
const FAST_RESPONSE_SPEED := 7
const FAST_RESPONSE_EXTRA_COST := 2
const ART_PATH := "res://images/card_art/powers/SavingGrace.jpg"

func _init() -> void:
	super._init()
	card_name = "Saving Grace"
	culture = "Neutral"
	level = 0
	mana_cost = UNLOCK_COST
	speed = BASE_RESPONSE_SPEED
	card_types = ["Power", "Ward", "Followers"]
	ability_text = "[b]Ward[/b]: If you control no creatures or magical cards, when your opponent attacks your followers, you may flip this face-up. You lose no followers this turn. ([b]Spd[/b] 5, or pay 2 additional mana for [b]Spd[/b] 7.)"
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

func get_priority_response_speed() -> int:
	var game_manager := card_owner.game_manager if card_owner != null else null
	var attack_action := _get_relevant_attack_action(game_manager)
	if attack_action != null and _requires_fast_response(attack_action) and _can_pay_response_cost_for_action(attack_action, game_manager):
		return FAST_RESPONSE_SPEED
	return BASE_RESPONSE_SPEED

func can_unlock(_game_manager: GameManager) -> bool:
	return false

func get_unlock_failure_reason(_game_manager: GameManager) -> String:
	return card_name + " can only flip face-up in response to an attack on your followers."

func can_activate(_game_manager: GameManager) -> bool:
	return false

func get_activation_failure_reason(_game_manager: GameManager) -> String:
	return card_name + " only responds while face-down to attacks on your followers."

func can_respond_to_priority_action(action: CardAction, game_manager: GameManager) -> bool:
	return _can_respond_to_attack_action(action, game_manager, true)

func activate(game_manager: GameManager, _activation_data = null) -> void:
	var attack_action := _get_relevant_attack_action(game_manager)
	if not _can_respond_to_attack_action(attack_action, game_manager, false):
		if game_manager != null:
			game_manager.note_player_feedback(card_name + " cannot respond right now.")
		return

	var unlock_cost := get_unlock_mana_cost(game_manager)
	var total_cost := _get_response_cost_for_action(attack_action, game_manager)
	if not pay_costs_with_mana_cost(card_owner, total_cost, game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("%s needs %d mana to answer this attack." % [card_name, total_cost])
		return
	if game_manager != null and unlock_cost < mana_cost:
		game_manager.claim_cost_adjustments(self, mana_cost, Card.COST_KIND_POWER_UNLOCK)

	is_face_down = false
	is_publicly_revealed = false
	is_muted = false
	mute_turns_remaining = 0
	_mute_applied_owner_turn_number = -1
	on_unlock(game_manager)
	game_manager.grant_turn_follower_loss_prevention(card_owner, self)

	var feedback := "%s flips face-up. %s cannot lose followers this turn." % [
		card_name,
		card_owner.player_name
	]
	if _requires_fast_response(attack_action):
		feedback += " %s paid %d additional mana to answer at Spd %d." % [
			card_owner.player_name,
			FAST_RESPONSE_EXTRA_COST,
			FAST_RESPONSE_SPEED
		]
	game_manager.note_player_feedback(feedback)

func _can_respond_to_attack_action(action: CardAction, game_manager: GameManager, require_priority_holder: bool) -> bool:
	if game_manager == null or action == null:
		return false
	if not is_face_down or is_muted:
		return false
	if is_activation_locked(game_manager):
		return false
	if card_owner == null:
		return false
	if require_priority_holder and card_owner != game_manager.priority_player:
		return false
	if current_zone == null or current_zone.zone_owner != card_owner or current_zone.zone_type != Zone.ZoneType.POWER_SLOT:
		return false
	if action.type != CardAction.Type.ATTACK or action.attacker == null:
		return false
	if action.target != card_owner:
		return false
	if action.attacker.get_controller() == card_owner:
		return false
	if not _has_empty_field_condition():
		return false
	return _can_pay_response_cost_for_action(action, game_manager)

func _has_empty_field_condition() -> bool:
	if card_owner == null:
		return false
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if card == null:
				continue
			if card.is_creature_card() or card.is_magical_card():
				return false
	return true

func _get_relevant_attack_action(game_manager: GameManager) -> CardAction:
	if game_manager == null or game_manager.action_stack.is_empty():
		return null
	var top_action := game_manager.action_stack.back() as CardAction
	if top_action == null:
		return null
	if top_action.type == CardAction.Type.ATTACK:
		return top_action
	if top_action.response_to != null and top_action.response_to.type == CardAction.Type.ATTACK:
		return top_action.response_to
	return null

func _requires_fast_response(action: CardAction) -> bool:
	return action != null and action.get_timing_speed() > BASE_RESPONSE_SPEED

func _get_response_cost_for_action(action: CardAction, game_manager: GameManager) -> int:
	var total_cost := get_unlock_mana_cost(game_manager)
	if _requires_fast_response(action):
		total_cost += FAST_RESPONSE_EXTRA_COST
	return total_cost

func _can_pay_response_cost_for_action(action: CardAction, game_manager: GameManager) -> bool:
	if card_owner == null:
		return false
	return can_pay_costs_with_mana_cost(card_owner, _get_response_cost_for_action(action, game_manager))
