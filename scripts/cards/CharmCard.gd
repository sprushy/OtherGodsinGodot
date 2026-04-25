extends BaseCard
class_name CharmCard

var must_be_prepared_to_activate: bool = false

func _init() -> void:
	super._init()
	card_type = Card.CardType.CHARM
	if "Charm" not in card_types:
		card_types.append("Charm")

func can_prepare(game_manager: GameManager, player: Player = null) -> bool:
	var preparing_player := player if player != null else card_owner
	return super.can_prepare(game_manager, preparing_player)

func can_activate_from_hand(game_manager: GameManager, triggering_action: CardAction = null) -> bool:
	if must_be_prepared_to_activate:
		return false
	if game_manager == null or card_owner == null:
		return false
	if game_manager.current_player != card_owner:
		return false
	if game_manager._has_pending_stack_action_for_card(self):
		return false
	if is_activation_locked(game_manager):
		return false
	if current_zone != card_owner.hand_zone:
		return false
	var responding_player := game_manager.priority_player
	if responding_player == null and triggering_action != null:
		responding_player = triggering_action.initial_priority_player
	if responding_player == null:
		responding_player = game_manager.turn_player if game_manager.turn_player != null else game_manager.current_player
	if card_owner != responding_player:
		return false
	if not can_pay_costs(card_owner):
		return false
	if targets and get_valid_targets(game_manager).is_empty():
		return false
	return can_respond_to_action(triggering_action, game_manager)

func can_activate_prepared(game_manager: GameManager, triggering_action: CardAction = null) -> bool:
	if game_manager == null or card_owner == null:
		return false
	if game_manager._has_pending_stack_action_for_card(self):
		return false
	if not is_prepared:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_muted:
		return false
	if is_activation_locked(game_manager):
		return false
	if not game_manager.is_prepared_charm_ready(self, triggering_action):
		return false
	if not game_manager.can_pay_prepared_card_activation_cost(self, card_owner):
		return false
	if targets and get_valid_targets(game_manager).is_empty():
		return false
	return can_respond_to_action(triggering_action, game_manager)

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	return []

func is_valid_target(_target: Card) -> bool:
	return false

func can_respond_to_action(action: CardAction, _game_manager: GameManager = null) -> bool:
	if action == null:
		return true
	var action_speed := action.get_timing_speed()
	match action.type:
		CardAction.Type.ATTACK:
			return action.attacker != null and get_effective_speed() >= action_speed
		CardAction.Type.SPELL, CardAction.Type.ABILITY, CardAction.Type.CHARM:
			return action.card != null and action_speed > 0 and get_effective_speed() >= action_speed
		CardAction.Type.EVENT:
			if action.event_name == "start_turn" or action.event_name == "end_turn":
				return true
			if action_speed > 0:
				return get_effective_speed() >= action_speed
	return false

func resolve(_game_manager: GameManager, _target = null) -> void:
	push_error("CharmCard.resolve() must be overridden in " + card_name + "!")
