extends CreatureCard
class_name JiangZiyaFisherOfKings

const ART_PATH := "res://images/card_art/creatures/jiang_ziya_fisher_of_kings.png"
const ALT_ART_PATH := "res://images/card_art/creatures/jiang_ziya_fisher_of_kings_alt.png"
const TACTIC_COUNTER_COST := 2
const SUMMON_TACTIC_COUNTERS := 2
const COUNTER_RESPONSE_SPEED := 99

var tactic_counters: int = 0

func _init() -> void:
	super._init()
	card_name = "Jiang Ziya, Fisher of Kings"
	card_types = ["Human", "General", "Tian Creature"]
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 9
	strength = 9
	is_legendary = true
	targets = false
	ability_text = "[b]Patient Strategist[/b] ([b]Summon[/b]): Put 2 tactic counters on this.\n[b]Counterstroke[/b]: When this is targeted by an effect or attack, you may remove 2 tactic counters to negate it and destroy its source or attacker.\n[b]Fisher of Kings[/b] ([b]Activate[/b]): Remove 2 tactic counters to [b]Acquire[/b] a King or Legendary card."
	flavor_text = ""
	culture = "Tian"
	artist = "User provided art"
	art_path = ART_PATH
	art_variants = [ART_PATH, ALT_ART_PATH]

func get_activation_label() -> String:
	return "Fisher of Kings"

func on_summon(game_manager: GameManager) -> void:
	tactic_counters += SUMMON_TACTIC_COUNTERS
	_emit_visual_state_changed()
	if game_manager != null:
		game_manager.note_player_feedback(
			"%s enters with %d tactic counters." % [card_name, tactic_counters]
		)

func can_activate(game_manager: GameManager) -> bool:
	if not _can_use_counter_abilities(game_manager):
		return false
	if get_controller() != game_manager.current_player:
		return false
	if tactic_counters < TACTIC_COUNTER_COST:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if not _is_face_up_on_field():
		return card_name + " must be face-up on the field."
	if abilities_suppressed():
		return card_name + " has no active abilities right now."
	if is_activation_locked(game_manager):
		return card_name + " cannot activate this turn."
	if is_sleeping:
		return card_name + " is asleep."
	if get_controller() != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if tactic_counters < TACTIC_COUNTER_COST:
		return "%s needs %d tactic counters." % [card_name, TACTIC_COUNTER_COST]
	if get_valid_targets(game_manager).is_empty():
		return card_name + " found no King or Legendary card in your deck."
	return card_name + " cannot activate right now."

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.deck_zone == null:
		return valid_targets
	for card in controller.deck_zone.cards:
		if _is_valid_fisher_target(card, controller):
			valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	var threat := _find_response_threat(game_manager)
	if threat != null and _can_counter_threat(threat, game_manager, false):
		_resolve_counterstroke(game_manager, threat)
		return

	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	if target == null or target not in get_valid_targets(game_manager):
		game_manager.note_player_feedback("%s fizzles: choose a King or Legendary card from your deck." % card_name)
		return

	var controller := get_controller()
	if controller == null:
		return
	tactic_counters -= TACTIC_COUNTER_COST
	controller.move_card(target, controller.hand_zone)
	if target.current_zone != controller.hand_zone:
		tactic_counters += TACTIC_COUNTER_COST
		_emit_visual_state_changed()
		game_manager.note_player_feedback("%s could not add %s to hand." % [card_name, target.card_name])
		return

	target.card_owner = controller
	controller.deck_zone.cards.shuffle()
	_emit_visual_state_changed()
	game_manager.note_player_feedback(
		"%s removes %d tactic counters and adds %s to %s's hand." % [
			card_name,
			TACTIC_COUNTER_COST,
			target.card_name,
			controller.player_name
		]
	)

func get_priority_response_speed() -> int:
	return COUNTER_RESPONSE_SPEED

func can_respond_to_priority_action(action: CardAction, game_manager: GameManager) -> bool:
	return _can_counter_threat(action, game_manager, true)

func get_priority_targets(_game_manager: GameManager, _action: CardAction = null) -> Array[Card]:
	return []

func on_removed(_game_manager: GameManager) -> void:
	tactic_counters = 0
	_emit_visual_state_changed()

func get_serialized_state() -> Dictionary:
	var state := super.get_serialized_state()
	state["tactic_counters"] = tactic_counters
	return state

func apply_serialized_state(state: Dictionary) -> void:
	super.apply_serialized_state(state)
	tactic_counters = int(state.get("tactic_counters", 0))
	_emit_visual_state_changed()

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	lines.append("Tactic counters: %d" % tactic_counters)
	return lines

func _can_counter_threat(action: CardAction, game_manager: GameManager, require_priority: bool) -> bool:
	if action == null or game_manager == null:
		return false
	if not _can_use_counter_abilities(game_manager):
		return false
	if tactic_counters < TACTIC_COUNTER_COST:
		return false
	var controller := get_controller()
	if controller == null:
		return false
	if require_priority and controller != game_manager.priority_player:
		return false

	if action.type == CardAction.Type.ATTACK:
		return action.attacker != null \
			and (action.target == self or action.interceptor == self) \
			and action.attacker.get_controller() != controller

	if action.card == null or action.card == self:
		return false
	if action.card.get_controller() == controller:
		return false
	if action.card.has_method("can_be_negated") and not action.card.can_be_negated(action):
		return false
	return _action_targets_self(action)

func _resolve_counterstroke(game_manager: GameManager, threat: CardAction) -> void:
	if not _can_counter_threat(threat, game_manager, false):
		game_manager.note_player_feedback("%s can no longer use Counterstroke." % card_name)
		return

	tactic_counters -= TACTIC_COUNTER_COST
	if threat in game_manager.action_stack:
		game_manager.action_stack.erase(threat)

	var source_card := threat.attacker if threat.type == CardAction.Type.ATTACK else threat.card
	var source_name := "the effect"
	if source_card != null:
		source_name = source_card.get_target_log_display_name(game_manager.get_feedback_viewer())
	var destroyed := false
	if source_card != null \
			and source_card.current_zone != null \
			and source_card.current_zone.zone_type not in [Zone.ZoneType.GRAVEYARD, Zone.ZoneType.ABYSS]:
		destroyed = game_manager.request_send_to_graveyard(source_card, Callable(), false, true)

	_emit_visual_state_changed()
	var result := "%s removes %d tactic counters and negates %s." % [
		card_name,
		TACTIC_COUNTER_COST,
		source_name
	]
	if destroyed:
		result += " %s is destroyed." % source_name
	elif source_card != null:
		result += " %s could not be destroyed." % source_name
	game_manager.note_player_feedback(result)

func _find_response_threat(game_manager: GameManager) -> CardAction:
	if game_manager == null:
		return null
	for index in range(game_manager.action_stack.size() - 1, -1, -1):
		var action := game_manager.action_stack[index] as CardAction
		if action == null:
			continue
		if action.card == self and action.response_to != null:
			if _can_counter_threat(action.response_to, game_manager, false):
				return action.response_to
			continue
		if _can_counter_threat(action, game_manager, false):
			return action
	return null

func _action_targets_self(action: CardAction) -> bool:
	if action == null:
		return false
	if _target_value_contains_self(action.target):
		return true
	return _target_value_contains_self(action.event_data)

func _target_value_contains_self(value) -> bool:
	if value == self:
		return true
	if value is Array:
		for entry in value:
			if _target_value_contains_self(entry):
				return true
	elif value is Dictionary:
		for entry in (value as Dictionary).values():
			if _target_value_contains_self(entry):
				return true
	return false

func _can_use_counter_abilities(game_manager: GameManager) -> bool:
	return game_manager != null \
		and _is_face_up_on_field() \
		and not abilities_suppressed() \
		and not is_activation_locked(game_manager) \
		and not is_sleeping

func _is_face_up_on_field() -> bool:
	return current_zone != null \
		and current_zone.is_board_zone() \
		and not is_face_down \
		and not is_stealth \
		and not is_prepared

func _is_valid_fisher_target(card: Card, controller: Player) -> bool:
	return card != null \
		and controller != null \
		and card.current_zone == controller.deck_zone \
		and (card.has_type("King") or card.is_legendary)
