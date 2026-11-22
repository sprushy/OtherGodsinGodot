extends GodCard
class_name HermesPsychopompus

const CALL_OF_THE_CROSSING := "Call of the Crossing"
const WINGS_OF_THE_DEPARTED := "Wings of the Departed"
const ART_PATH := "res://images/card_art/gods/hermes_psychopompus_alt_art.png"
const ALT_ART_PATH := "res://images/card_art/gods/hermes_psychopompus.png"

var _call_last_used_turn: int = -1
var _wings_last_used_turn: int = -1

func _init() -> void:
	super._init()
	card_name = "Hermes Psychopompus"
	card_types = ["Emissary", "Death", "Targeting"]
	mana_cost = 0
	speed = 7
	culture = "Olympic"
	targets = true
	ability_text = "[b]%s[/b] ([b]Once per turn[/b], 2 mana per Level): Summon a Ghost from your deck to an empty friendly lane in aggressive stance.\n[b]%s[/b] ([b]Once per turn[/b], X mana): Pay up to 1 mana for each Ghost in your Graveyard. Target creature gains +1 SPD per mana paid until end of turn." % [CALL_OF_THE_CROSSING, WINGS_OF_THE_DEPARTED]
	art_path = ART_PATH
	art_variants = [ART_PATH, ALT_ART_PATH]
	name_at_bottom = true

func is_own_active_god_card(active_god: ActiveGodCard) -> bool:
	return active_god is HermesActive

func can_use_god_power(game_manager: GameManager) -> bool:
	if not super.can_use_god_power(game_manager):
		return false
	return not _was_ability_used_this_turn(game_manager, CALL_OF_THE_CROSSING) \
		or not _was_ability_used_this_turn(game_manager, WINGS_OF_THE_DEPARTED)

func can_activate(game_manager: GameManager) -> bool:
	return can_summon_ghost(game_manager) or can_boost_speed(game_manager)

func can_summon_ghost(game_manager: GameManager) -> bool:
	return can_use_god_power(game_manager) \
		and not _was_ability_used_this_turn(game_manager, CALL_OF_THE_CROSSING) \
		and not get_summonable_ghosts().is_empty()

func can_boost_speed(game_manager: GameManager) -> bool:
	return can_use_god_power(game_manager) \
		and not _was_ability_used_this_turn(game_manager, WINGS_OF_THE_DEPARTED) \
		and get_max_speed_payment() > 0 \
		and not get_speed_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if not super.can_use_god_power(game_manager):
		return card_name + " cannot activate right now."
	if _was_ability_used_this_turn(game_manager, CALL_OF_THE_CROSSING) \
			and _was_ability_used_this_turn(game_manager, WINGS_OF_THE_DEPARTED):
		return card_name + " has already used both abilities this turn."
	return "Call of the Crossing needs an affordable Ghost in your deck and an open lane. Wings of the Departed needs mana, a Ghost in your Graveyard, and a valid creature target."

func get_summonable_ghosts(mana_budget: int = -1) -> Array[Card]:
	var ghosts: Array[Card] = []
	if get_open_ghost_lanes().is_empty():
		return ghosts
	var available_mana := card_owner.mana if mana_budget < 0 else mana_budget
	for card in card_owner.deck_zone.get_unordered_deck_cards():
		if _is_payable_deck_ghost(card, available_mana):
			ghosts.append(card)
	return ghosts

func get_open_ghost_lanes() -> Array[Zone]:
	var lanes: Array[Zone] = []
	if card_owner == null:
		return lanes
	for lane in card_owner.frontline_zones + card_owner.reserve_zones:
		if lane.cards.is_empty():
			lanes.append(lane)
	return lanes

func get_max_speed_payment(mana_budget: int = -1) -> int:
	if card_owner == null:
		return 0
	var ghost_count := 0
	for card in card_owner.graveyard_zone.cards:
		if card.has_type("Ghost"):
			ghost_count += 1
	return mini(card_owner.mana if mana_budget < 0 else mana_budget, ghost_count)

func get_speed_targets(game_manager: GameManager) -> Array[Card]:
	return game_manager.get_field_cards(null, false).filter(
		func(card: Card) -> bool: return _is_valid_speed_target(game_manager, card)
	)

func get_ability_command_failure_reason(game_manager: GameManager, command: Dictionary, target: Card) -> String:
	if game_manager.is_game_over or not super.can_use_god_power(game_manager):
		return card_name + " cannot activate right now."
	match command.get("ability", ""):
		CALL_OF_THE_CROSSING:
			if _was_ability_used_this_turn(game_manager, CALL_OF_THE_CROSSING):
				return CALL_OF_THE_CROSSING + " has already been used this turn."
			var ghost := game_manager.get_card_by_uid(str(command.get("ghost_uid", "")))
			if target != null or not _is_payable_deck_ghost(ghost, card_owner.mana):
				return CALL_OF_THE_CROSSING + " needs an affordable Ghost in your deck."
			if _get_ghost_summon_lane(command) == null:
				return CALL_OF_THE_CROSSING + " needs an empty friendly lane."
		WINGS_OF_THE_DEPARTED:
			if _was_ability_used_this_turn(game_manager, WINGS_OF_THE_DEPARTED):
				return WINGS_OF_THE_DEPARTED + " has already been used this turn."
			var payment: Variant = command.get("mana_amount", 0)
			if not (payment is int) or payment < 1 or payment > get_max_speed_payment():
				return WINGS_OF_THE_DEPARTED + " needs a valid mana payment."
			if not _is_valid_speed_target(game_manager, target):
				return WINGS_OF_THE_DEPARTED + " needs a valid creature target."
		_:
			return "Choose Call of the Crossing or Wings of the Departed."
	return ""

func activate(game_manager: GameManager, _target: Card = null) -> void:
	game_manager.note_player_feedback("Choose Call of the Crossing or Wings of the Departed.")

func activate_from_command(game_manager: GameManager, command: Dictionary) -> void:
	var target := game_manager.get_card_by_uid(str(command.get("target_uid", "")))
	var failure_reason := get_ability_command_failure_reason(game_manager, command, target)
	if not failure_reason.is_empty():
		game_manager.note_player_feedback(failure_reason)
		return
	if command["ability"] == CALL_OF_THE_CROSSING:
		var ghost := game_manager.get_card_by_uid(str(command["ghost_uid"]))
		var mana_cost_for_ghost := get_ghost_mana_cost(ghost)
		if not game_manager.summon_creature_by_effect(
			card_owner, ghost, _get_ghost_summon_lane(command), Card.CreatureMode.AGGRESSIVE,
			false, false, self, false, false, true, false, mana_cost_for_ghost
		):
			game_manager.note_player_feedback(CALL_OF_THE_CROSSING + " could not summon the chosen Ghost.")
			return
		_mark_ability_used(game_manager, CALL_OF_THE_CROSSING)
		game_manager.note_player_feedback("%s summons %s for %d mana." % [
			CALL_OF_THE_CROSSING, ghost.card_name, mana_cost_for_ghost
		])
		notify_power_activated(game_manager, ghost)
		return
	var payment: int = command["mana_amount"]
	if not card_owner.spend_mana(payment):
		game_manager.note_player_feedback(WINGS_OF_THE_DEPARTED + " needs a valid mana payment.")
		return
	target.add_buff(WINGS_OF_THE_DEPARTED, 0, 0, payment, self, card_owner,
		"hermes_wings_of_the_departed", {"expires_turn": game_manager.turn_number})
	_mark_ability_used(game_manager, WINGS_OF_THE_DEPARTED)
	game_manager.note_player_feedback("%s gives %s +%d SPD until end of turn." % [
		WINGS_OF_THE_DEPARTED, target.get_target_log_display_name(game_manager.get_feedback_viewer()), payment
	])
	notify_power_activated(game_manager, target)

func get_ghost_mana_cost(ghost: Card) -> int:
	return 2 * maxi(0, ghost.get_effective_level())

func _is_payable_deck_ghost(ghost: Card, mana_budget: int) -> bool:
	return ghost != null and ghost.current_zone == card_owner.deck_zone \
		and ghost.is_creature_card() and ghost.has_type("Ghost") \
		and get_ghost_mana_cost(ghost) <= mana_budget

func _get_ghost_summon_lane(command: Dictionary) -> Zone:
	if not (command.get("zone_type") is int) or not (command.get("zone_index") is int):
		return null
	var lane := get_champions_call_zone_from_command(command)
	return lane if lane != null and lane.cards.is_empty() else null

func _is_valid_speed_target(game_manager: GameManager, target: Card) -> bool:
	return target != null and target.is_creature_card() \
		and target.current_zone != null and target.current_zone.is_board_zone() \
		and not target.is_face_down and not target.is_stealth \
		and not game_manager.is_immune_to_source(target, self)

func on_removed(_game_manager: GameManager) -> void:
	_call_last_used_turn = -1
	_wings_last_used_turn = -1

func get_serialized_state() -> Dictionary:
	var state := super.get_serialized_state()
	state["call_last_used_turn"] = _call_last_used_turn
	state["wings_last_used_turn"] = _wings_last_used_turn
	return state

func apply_serialized_state(state: Dictionary) -> void:
	super.apply_serialized_state(state)
	_call_last_used_turn = int(state.get("call_last_used_turn", -1))
	_wings_last_used_turn = int(state.get("wings_last_used_turn", -1))

func _was_ability_used_this_turn(game_manager: GameManager, ability: String) -> bool:
	if game_manager == null:
		return false
	match ability:
		CALL_OF_THE_CROSSING:
			return _call_last_used_turn == game_manager.turn_number
		WINGS_OF_THE_DEPARTED:
			return _wings_last_used_turn == game_manager.turn_number
		_:
			return false

func _mark_ability_used(game_manager: GameManager, ability: String) -> void:
	if game_manager == null:
		return
	match ability:
		CALL_OF_THE_CROSSING:
			_call_last_used_turn = game_manager.turn_number
		WINGS_OF_THE_DEPARTED:
			_wings_last_used_turn = game_manager.turn_number
