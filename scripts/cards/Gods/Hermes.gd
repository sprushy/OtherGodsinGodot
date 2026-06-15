extends GodCard
class_name Hermes

const ACTIVATION_COST := 2
const ACTIVATION_SPEED := 7
const SPEED_BONUS := 3
const BUFF_SOURCE := "Hermes's Deceptive Speed"
const BUFF_EFFECT_TYPE := "hermes_deceptive_speed"

var _last_used_turn: int = -1

func _init() -> void:
	super._init()
	card_name = "Hermes"
	card_types = ["Emissary", "Trickster"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	mana_cost = 0
	speed = 7
	culture = "Olympic"
	targets = true
	flavor_text = ""
	ability_text = "Deceptive Speed (%d mana, Spd %d): Once per turn increase a creature's Spd by %d until the end of the turn." % [ACTIVATION_COST, ACTIVATION_SPEED, SPEED_BONUS]
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/gods/HermesEdit.png"
	name_at_bottom = true

func can_activate(game_manager: GameManager) -> bool:
	if not _can_use_deceptive_speed(game_manager, false):
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	return _get_deceptive_speed_failure_reason(game_manager, false)

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if is_valid_activation_target(card):
					valid_targets.append(card)
	return valid_targets

func is_valid_activation_target(target: Card) -> bool:
	return target != null \
		and target.is_creature_card() \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and not target.is_face_down \
		and not target.is_stealth

func get_priority_response_speed() -> int:
	return ACTIVATION_SPEED

func can_respond_to_priority_action(_action: CardAction, game_manager: GameManager) -> bool:
	if not _can_use_deceptive_speed(game_manager, true):
		return false
	return not get_valid_targets(game_manager).is_empty()

func activate(game_manager: GameManager, target: Card = null) -> void:
	var priority_response := _is_deceptive_speed_priority_response_resolving(game_manager)
	if not _can_use_deceptive_speed(game_manager, priority_response):
		if game_manager != null:
			game_manager.note_player_feedback(_get_deceptive_speed_failure_reason(game_manager, priority_response))
		return
	if get_valid_targets(game_manager).is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("Deceptive Speed has no valid targets right now.")
		return
	if not is_valid_activation_target(target):
		game_manager.note_player_feedback("Deceptive Speed fizzles: invalid target.")
		return
	if game_manager != null and game_manager.is_immune_to_source(target, self):
		game_manager.note_player_feedback("Deceptive Speed fizzles: " + target.card_name + " is immune to powers.")
		return
	if not card_owner.spend_mana(ACTIVATION_COST):
		game_manager.note_player_feedback(card_name + " needs " + str(ACTIVATION_COST) + " mana.")
		return

	target.remove_buffs_from_source_card(self, BUFF_EFFECT_TYPE)
	target.add_buff(
		BUFF_SOURCE,
		0,
		0,
		SPEED_BONUS,
		self,
		card_owner,
		BUFF_EFFECT_TYPE,
		{"expires_turn": game_manager.turn_number}
	)
	_last_used_turn = game_manager.turn_number
	game_manager.note_player_feedback(
		"Deceptive Speed gives %s +%d Spd until end of turn." % [
			target.get_target_log_display_name(game_manager.get_feedback_viewer()),
			SPEED_BONUS
		]
	)
	notify_power_activated(game_manager, target)

func on_removed(_game_manager: GameManager) -> void:
	_last_used_turn = -1

func _can_use_deceptive_speed(game_manager: GameManager, as_priority_response: bool) -> bool:
	if game_manager == null:
		return false
	if card_owner == null:
		return false
	if is_muted:
		return false
	if current_zone != card_owner.god_zone:
		return false
	if _was_used_this_turn(game_manager):
		return false
	if card_owner.mana < ACTIVATION_COST:
		return false
	if game_manager.has_method("has_resolved_turn_upkeep") and not game_manager.has_resolved_turn_upkeep():
		return false
	if game_manager.has_method("can_player_use_powers") and not game_manager.can_player_use_powers(card_owner):
		return false
	if as_priority_response:
		return not game_manager.action_stack.is_empty()
	return can_use_god_power(game_manager)

func _get_deceptive_speed_failure_reason(game_manager: GameManager, as_priority_response: bool) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if card_owner == null:
		return card_name + " has no controller."
	if is_muted:
		return card_name + " is muted."
	if current_zone != card_owner.god_zone:
		return card_name + " must be in your god slot."
	if _was_used_this_turn(game_manager):
		return "Deceptive Speed has already been used this turn."
	if card_owner.mana < ACTIVATION_COST:
		return card_name + " needs " + str(ACTIVATION_COST) + " mana."
	if game_manager.has_method("has_resolved_turn_upkeep") and not game_manager.has_resolved_turn_upkeep():
		return card_name + " cannot act before upkeep resolves."
	if game_manager.has_method("can_player_use_powers") and not game_manager.can_player_use_powers(card_owner):
		return card_name + "'s powers are unavailable."
	if as_priority_response:
		if game_manager.action_stack.is_empty():
			return card_name + " has nothing to respond to."
	else:
		if card_owner != game_manager.current_player:
			return "It is not " + card_name + "'s turn to act."
		if game_manager.priority_player != null or not game_manager.action_stack.is_empty():
			return card_name + " cannot activate while another action is waiting."
	if get_valid_targets(game_manager).is_empty():
		return "Deceptive Speed has no valid targets right now."
	return ""

func _is_deceptive_speed_priority_response_resolving(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if not game_manager.action_stack.is_empty():
		var top_action := game_manager.action_stack.back() as CardAction
		if _is_own_priority_response_action(top_action):
			return true
	for action in game_manager.resolving_stack_actions:
		var resolving_action := action as CardAction
		if _is_own_priority_response_action(resolving_action):
			return true
	return false

func _is_own_priority_response_action(action: CardAction) -> bool:
	return action != null \
		and action.type == CardAction.Type.ABILITY \
		and action.card == self \
		and action.response_to != null

func _was_used_this_turn(game_manager: GameManager) -> bool:
	return game_manager != null and _last_used_turn == game_manager.turn_number
