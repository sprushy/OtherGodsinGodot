extends PowerCard
class_name AspectShift

const SHIFT_COST := 4
const ART_PATH := "res://images/card_art/powers/aspect_shift.png"

var _normal_god: GodCard = null
var _hades_aspect_uid := ""

func _init() -> void:
	super._init()
	card_name = "Aspect Shift"
	culture = "Olympic"
	mana_cost = SHIFT_COST
	card_types = ["Power", "Aspect"]
	ability_text = "[b]Unlock[/b] (%d mana): Shift your God to their Hades aspect.\n[b]Return to Form[/b] ([b]Activate[/b], %d mana): Shift your God back to their normal aspect and [b]Relock[/b] this.\nAphrodite Areia shifts into Aphrodite Skotia. Hermes shifts into Hermes Psychopompus." % [SHIFT_COST, SHIFT_COST]
	art_path = ART_PATH

func can_unlock(game_manager: GameManager) -> bool:
	return game_manager != null and not game_manager.is_game_over and _is_in_power_slot() \
		and _normal_god == null and has_hades_aspect(_get_current_god()) and super.can_unlock(game_manager)

func get_unlock_failure_reason(game_manager: GameManager) -> String:
	if not has_hades_aspect(_get_current_god()):
		return card_name + " needs a God with a Hades aspect."
	return super.get_unlock_failure_reason(game_manager)

func on_unlock(game_manager: GameManager) -> void:
	var god := _get_current_god()
	var hades_aspect := make_hades_aspect()
	if hades_aspect == null:
		relock()
		return
	_normal_god = god
	_hades_aspect_uid = hades_aspect.uid
	_shift_god(god, hades_aspect, game_manager)

func can_activate(game_manager: GameManager) -> bool:
	return game_manager != null and not game_manager.is_game_over and _is_in_power_slot() \
		and _has_shifted_god() and super.can_activate(game_manager) \
		and can_pay_activation_costs(SHIFT_COST, game_manager)

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if not _has_shifted_god():
		return card_name + " needs the Hades aspect it brought into play."
	if not can_pay_activation_costs(SHIFT_COST, game_manager):
		return "%s needs %d mana to shift back." % [card_name, get_activation_mana_cost(SHIFT_COST, game_manager)]
	return super.get_activation_failure_reason(game_manager)

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if not can_activate(game_manager):
		game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	if not spend_activation_mana(SHIFT_COST, game_manager):
		return
	var restored_god := _normal_god
	_normal_god = null
	_hades_aspect_uid = ""
	relock()
	_shift_god(_get_current_god(), restored_god, game_manager)

static func has_hades_aspect(god: GodCard) -> bool:
	return god is AphroditeAreia or god is Hermes

func make_hades_aspect() -> GodCard:
	var aspect: GodCard
	var god := _get_current_god()
	if god is AphroditeAreia:
		aspect = AphroditeSkotia.new()
	elif god is Hermes:
		aspect = HermesPsychopompus.new()
	else:
		return null
	aspect.card_owner = card_owner
	return aspect

func get_normal_aspect() -> GodCard:
	return _normal_god

func get_activation_cost_hover_data(game_manager: GameManager = null) -> Dictionary:
	return {
		"base_cost": SHIFT_COST,
		"current_cost": get_activation_mana_cost(SHIFT_COST, game_manager),
		"cost_kind": Card.COST_KIND_POWER_ACTIVATION,
	}

func get_serialized_state() -> Dictionary:
	var state := super.get_serialized_state()
	if _normal_god != null:
		state["normal_god"] = GameState.serialize_embedded_card(_normal_god)
		state["hades_aspect_uid"] = _hades_aspect_uid
	return state

func apply_serialized_state(state: Dictionary) -> void:
	super.apply_serialized_state(state)
	_normal_god = GameState.deserialize_embedded_card(state.get("normal_god", {})) as GodCard
	_hades_aspect_uid = str(state.get("hades_aspect_uid", ""))

func _get_current_god() -> GodCard:
	if card_owner == null or card_owner.god_zone.cards.is_empty():
		return null
	return card_owner.god_zone.cards[0] as GodCard

func _is_in_power_slot() -> bool:
	return card_owner != null and current_zone in card_owner.power_zones

func _has_shifted_god() -> bool:
	var god := _get_current_god()
	return _normal_god != null and god != null and god.uid == _hades_aspect_uid

func _shift_god(outgoing: GodCard, incoming: GodCard, game_manager: GameManager) -> void:
	var god_slot := card_owner.god_zone
	# A shift preserves effects on the God and the original aspect's usage state.
	incoming.card_owner = card_owner
	incoming.is_muted = outgoing.is_muted
	incoming.mute_turns_remaining = outgoing.mute_turns_remaining
	incoming._mute_applied_owner_turn_number = outgoing._mute_applied_owner_turn_number
	incoming.active_statuses = outgoing.active_statuses
	incoming.active_buffs = outgoing.active_buffs
	outgoing.active_statuses = []
	outgoing.active_buffs = []
	incoming._sync_status_flags()
	god_slot.remove_card(outgoing)
	outgoing.field_subtypes.clear()
	card_owner.move_card(incoming, god_slot)
	card_owner.card_moved.emit(outgoing, god_slot, null)
	game_manager.note_player_feedback("%s shifts %s into %s." % [card_name, outgoing.card_name, incoming.card_name])
