# GameManager.gd - Complete Version with Robust Player Identification
extends RefCounted
class_name GameManager

signal game_ended(winner: Player, loser: Player)
signal doorway_choice_requested(structure: StructureCard, card: Card, combat_death: bool, destruction: bool)
signal decision_requested(player: Player, type: String, data: Dictionary)
signal turn_started(turn_number: int, player: Player)
signal turn_ended(turn_number: int, player: Player)
signal controller_turn_started(turn_number: int, player: Player)
signal controller_turn_ended(turn_number: int, player: Player)
signal global_turn_started(turn_number: int, player: Player)
signal global_turn_ended(turn_number: int, player: Player)
signal turn_upkeep_started(turn_number: int, player: Player)
signal turn_upkeep_resolved(turn_number: int, player: Player)
signal phase_changed(old_phase: int, new_phase: int, turn_number: int, player: Player)
signal god_power_activated(turn_number: int, player: Player, god: Card, target: Card)
signal card_summoned(player: Player, card: Card, from_zone: Zone, to_zone: Zone, summon_source: Card, face_down: bool, stealth: bool)
signal followers_converted(from_player: Player, to_player: Player, amount: int)

enum GamePhase { MULLIGAN, MAIN, COMBAT, END }
const GAME_END_REASON_DEFEAT := "defeat"
const GAME_END_REASON_FORFEIT := "forfeit"
const GAME_END_REASON_MATCH_FORFEIT := "match_forfeit"
const GOD_DEATH_FOLLOWER_LOSS := 7
const GOD_DEATH_UPKEEP_MANA_PENALTY := 1
const UPKEEP_DRAW_MANA_GAIN := 1
const UPKEEP_MANA_GAIN := 5
const FIRST_TURN_UPKEEP_DRAW_MANA_GAIN := 0
const FIRST_TURN_UPKEEP_MANA_GAIN := 4

static func round_down_divide(amount: int, divisor: int) -> int:
	if divisor == 0:
		return 0
	return int(floor(float(amount) / float(divisor)))

var players: Array[Player] = []
var current_player: Player
var other_player: Player
var turn_player: Player
var feedback_viewer: Player
var current_phase: GamePhase = GamePhase.MULLIGAN
var is_game_over: bool = false
var winning_player: Player = null
var losing_player: Player = null
var game_end_reason: String = ""
var turn_number: int = 0
var action_stack: Array[CardAction] = []
var prepared_hexes: Dictionary = {}
var prepared_charms: Dictionary = {}
var attack_restrictions: Dictionary = {}# player -> turns remaining
var has_resolved_attack_this_turn: bool = false
var turn_destruction_wards: Dictionary = {} # player -> {expires_turn, source_card}
var turn_follower_loss_preventions: Dictionary = {} # player -> {expires_turn, source_card}
var turn_opponent_targeting_immunities: Dictionary = {} # player -> {expires_turn, source_card}
var died_this_turn: Array[Card] = []
var destroyed_this_turn: Array[Card] = []
var pending_resurrections: Array[Card] = []
var combat_destroy_events_this_turn: Array[Dictionary] = []
var last_hex_resolution_text: String = ""
var last_player_feedback_text: String = ""
var _pending_player_feedback_texts: Array[String] = []
var _pending_ui_sound_cues: Array[String] = []
var _upkeep_resolved_turn: int = -1
var _upkeep_started_turn: int = -1
var _temporary_summon_cost_modifiers: Array[Dictionary] = []
var _temporary_control_effects: Array[Dictionary] = []
var _next_board_entry_order: int = 0
var _pending_doorway_structure: StructureCard = null
var _pending_doorway_structures: Array[StructureCard] = []
var _pending_doorway_card: Card = null
var _pending_doorway_combat_death: bool = false
var _pending_doorway_destruction: bool = false
var _pending_doorway_ignore_self_combat_replacement: bool = false
var _pending_doorway_continue: Callable = Callable()
var _pending_return_to_hand_card: Card = null
var _pending_return_to_hand_reason: String = ""
var _pending_return_to_hand_send_to_abyss: bool = false
var _pending_return_to_hand_continue: Callable = Callable()
var _pending_return_to_hand_steal_actor: Card = null
var _temporary_combat_follower_damage_halved: bool = false
var _combat_resolution_deferred: bool = false
var _deferred_combat_resume: Callable = Callable()
var _committed_combat_snapshots: Dictionary = {}

const INTERCEPT_COUNT_TURN_META := "intercept_count_turn"
const INTERCEPT_COUNT_VALUE_META := "intercept_count_value"

# Priority system
var priority_player: Player = null
var consecutive_passes: int = 0
var _effect_source_card_stack: Array[Card] = []
var resolving_stack_actions: Array[CardAction] = []

func get_phase_name(phase: int = -1) -> String:
	var resolved_phase: GamePhase = current_phase
	if phase >= 0:
		resolved_phase = phase as GamePhase
	var phase_names := GamePhase.keys()
	if resolved_phase < 0 or resolved_phase >= phase_names.size():
		return "UNKNOWN"
	return phase_names[resolved_phase]

func has_resolved_turn_upkeep(turn: int = -1) -> bool:
	var resolved_turn := turn_number if turn < 0 else turn
	return _upkeep_resolved_turn == resolved_turn

func _set_phase(new_phase: GamePhase) -> void:
	if current_phase == new_phase:
		return
	var old_phase := current_phase
	current_phase = new_phase
	phase_changed.emit(old_phase, new_phase, turn_number, current_player)

func push_to_stack(action: CardAction) -> void:
	if is_game_over:
		return
	if action != null and action.response_to != null:
		action.response_to.event_data.erase("priority_window_offered_player_indexes")
	action_stack.push_back(action)
	consecutive_passes = 0
	if action.initial_priority_player != null:
		priority_player = action.initial_priority_player
	else:
		priority_player = get_opponent(action.source_player)

func pass_priority() -> void:
	if is_game_over:
		return
	consecutive_passes += 1
	if consecutive_passes < 2:
		priority_player = get_opponent(priority_player)

func both_passed() -> bool:
	return consecutive_passes >= 2

func begin_stack_action_resolution(action: CardAction) -> void:
	if action == null or action in resolving_stack_actions:
		return
	resolving_stack_actions.append(action)

func end_stack_action_resolution(action: CardAction) -> void:
	if action == null:
		return
	resolving_stack_actions.erase(action)

func get_resolving_action_display_zone(source_card: Card = null) -> Zone:
	for i in range(resolving_stack_actions.size() - 1, -1, -1):
		var action := resolving_stack_actions[i]
		if action == null:
			continue
		if source_card != null and action.card != source_card:
			continue
		if action.display_zone != null:
			return action.display_zone
	return null

func _is_zone_in_play(zone: Zone) -> bool:
	if zone == null:
		return false
	return zone.is_board_zone() or zone.zone_type == Zone.ZoneType.GOD_SLOT or zone.zone_type == Zone.ZoneType.POWER_SLOT

func _is_hidden_board_card(card: Card) -> bool:
	return card != null \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and (card.is_face_down or card.is_stealth or card.is_prepared)

func _action_is_stale(action: CardAction) -> bool:
	if action == null:
		return true
	match action.type:
		CardAction.Type.EVENT:
			if action.event_name == "summon":
				return action.card == null \
					or action.card.current_zone == null \
					or not action.card.current_zone.is_board_zone() \
					or action.card.is_face_down \
					or action.card.is_stealth \
					or action.card.is_prepared
			if action.event_name == "hand_play":
				return action.card == null \
					or action.card.current_zone == null \
					or not _is_zone_in_play(action.card.current_zone) \
					or action.card.is_face_down \
					or action.card.is_stealth \
					or action.card.is_prepared
			if action.event_name == "frontline_entry":
				return action.card == null \
					or action.card.current_zone == null \
					or action.card.current_zone.zone_type != Zone.ZoneType.FRONTLINE
			if action.event_name not in ["start_turn", "end_turn"] and _is_hidden_board_card(action.card):
				return true
		CardAction.Type.ATTACK:
			var attacker_active := _can_continue_declared_attack(action.attacker)
			var partner_active := _can_continue_declared_attack(action.united_front_partner)
			return not attacker_active and not partner_active
		CardAction.Type.SPELL, CardAction.Type.ABILITY, CardAction.Type.CHARM:
			if action.card == null or action.card.current_zone == null:
				return true
			if action.card.card_owner == null:
				return false
			return action.card.current_zone == action.card.card_owner.graveyard_zone \
				or action.card.current_zone == action.card.card_owner.abyss_zone
	return false

func prune_stale_stack_actions() -> void:
	_prune_stale_stack_actions()

func _prune_stale_stack_actions() -> void:
	if action_stack.is_empty() and resolving_stack_actions.is_empty():
		return
	var kept_actions: Array[CardAction] = []
	for action in action_stack:
		if action in resolving_stack_actions:
			kept_actions.append(action)
			continue
		if _action_is_stale(action):
			_cleanup_stale_stack_action(action)
			continue
		kept_actions.append(action)
	action_stack = kept_actions
	var kept_resolving: Array[CardAction] = []
	for action in resolving_stack_actions:
		if action != null and action in action_stack:
			kept_resolving.append(action)
	resolving_stack_actions = kept_resolving
	if action_stack.is_empty():
		priority_player = null
		consecutive_passes = 0

func _cleanup_stale_stack_action(action: CardAction) -> void:
	if action == null:
		return
	if action.type != CardAction.Type.ATTACK:
		return
	var declared_target: Card = action.interceptor
	if declared_target == null and action.target is Card:
		declared_target = action.target as Card
	if declared_target != null:
		_clear_combat_engagement_state(declared_target)

func note_player_feedback(text: String) -> void:
	var trimmed_text := text.strip_edges()
	if trimmed_text == "":
		return
	last_player_feedback_text = trimmed_text
	_pending_player_feedback_texts.append(trimmed_text)
	print(trimmed_text)

func get_activation_mana_unavailable_text(card: Card = null) -> String:
	if card != null and str(card.card_name).strip_edges() != "":
		return "You do not have enough mana to activate " + card.card_name + "."
	return "You do not have enough mana to activate this card."

func has_insufficient_activation_mana(card: Card, prepared: bool = false, player: Player = null) -> bool:
	if card == null:
		return false
	var paying_player := player if player != null else card.card_owner
	if paying_player == null:
		return false
	var mana_required := get_prepared_card_activation_mana_cost(paying_player, card) if prepared else get_card_play_mana_cost(paying_player, card, false)
	return paying_player.mana < mana_required

func get_feedback_viewer() -> Player:
	if feedback_viewer != null:
		return feedback_viewer
	if turn_player != null:
		return turn_player
	return current_player

func _notify_player_god_visual_state_changed(player: Player) -> void:
	if player == null or player.god_zone == null or player.god_zone.cards.is_empty():
		return
	var god := player.god_zone.cards[0]
	if god != null and god.has_method("_emit_visual_state_changed"):
		god._emit_visual_state_changed()

func push_effect_source_card(source_card: Card) -> void:
	_effect_source_card_stack.append(source_card)

func pop_effect_source_card() -> void:
	if _effect_source_card_stack.is_empty():
		return
	_effect_source_card_stack.pop_back()

func get_effect_source_card() -> Card:
	if _effect_source_card_stack.is_empty():
		return null
	return _effect_source_card_stack.back()

func run_with_effect_source(source_card: Card, callback: Callable) -> void:
	var pushed := false
	if source_card != null:
		push_effect_source_card(source_card)
		pushed = true
	if callback.is_valid():
		callback.call()
	if pushed:
		pop_effect_source_card()

func grant_turn_destruction_ward(player: Player, source_card: Card = null, expires_turn: int = -1) -> void:
	if player == null:
		return
	var resolved_expires_turn := turn_number if expires_turn < 0 else expires_turn
	turn_destruction_wards[player] = {
		"expires_turn": resolved_expires_turn,
		"source_card": source_card,
	}

func has_turn_destruction_ward(player: Player) -> bool:
	if player == null:
		return false
	var ward_data: Variant = turn_destruction_wards.get(player, null)
	if not (ward_data is Dictionary):
		return false
	var expires_turn := int((ward_data as Dictionary).get("expires_turn", -1))
	return expires_turn >= turn_number

func get_turn_destruction_ward_activation_block_reason(source_card: Card, chosen_target = null) -> String:
	if source_card == null:
		return ""
	for protected_key in turn_destruction_wards.keys():
		var protected_player := protected_key as Player
		if protected_player == null or not has_turn_destruction_ward(protected_player):
			continue
		if _would_activation_break_turn_destruction_ward(source_card, protected_player, chosen_target):
			return "%s cannot be activated: %s's creatures are warded from opposing destruction effects this turn." % [
				source_card.card_name,
				protected_player.player_name
			]
	return ""

func _clear_expired_turn_destruction_wards(current_turn: int) -> void:
	for player in turn_destruction_wards.keys().duplicate():
		var ward_data: Variant = turn_destruction_wards.get(player, null)
		if not (ward_data is Dictionary):
			turn_destruction_wards.erase(player)
			continue
		var expires_turn := int((ward_data as Dictionary).get("expires_turn", -1))
		if expires_turn <= current_turn:
			turn_destruction_wards.erase(player)

func grant_turn_follower_loss_prevention(player: Player, source_card: Card = null, expires_turn: int = -1) -> void:
	if player == null:
		return
	var resolved_expires_turn := turn_number if expires_turn < 0 else expires_turn
	turn_follower_loss_preventions[player] = {
		"expires_turn": resolved_expires_turn,
		"source_card": source_card,
	}

func has_turn_follower_loss_prevention(player: Player) -> bool:
	if player == null:
		return false
	var prevention_data: Variant = turn_follower_loss_preventions.get(player, null)
	if not (prevention_data is Dictionary):
		return false
	var expires_turn := int((prevention_data as Dictionary).get("expires_turn", -1))
	return expires_turn >= turn_number

func can_player_lose_followers_now(player: Player) -> bool:
	if player == null:
		return false
	return not has_turn_follower_loss_prevention(player)

func grant_turn_opponent_targeting_immunity(player: Player, source_card: Card = null, expires_turn: int = -1) -> void:
	if player == null:
		return
	var resolved_expires_turn := turn_number if expires_turn < 0 else expires_turn
	turn_opponent_targeting_immunities[player] = {
		"expires_turn": resolved_expires_turn,
		"source_card": source_card,
	}

func has_turn_opponent_targeting_immunity(player: Player) -> bool:
	if player == null:
		return false
	var immunity_data: Variant = turn_opponent_targeting_immunities.get(player, null)
	if not (immunity_data is Dictionary):
		return false
	var expires_turn := int((immunity_data as Dictionary).get("expires_turn", -1))
	return expires_turn >= turn_number

func _clear_expired_turn_follower_loss_preventions(current_turn: int) -> void:
	for player in turn_follower_loss_preventions.keys().duplicate():
		var prevention_data: Variant = turn_follower_loss_preventions.get(player, null)
		if not (prevention_data is Dictionary):
			turn_follower_loss_preventions.erase(player)
			continue
		var expires_turn := int((prevention_data as Dictionary).get("expires_turn", -1))
		if expires_turn <= current_turn:
			turn_follower_loss_preventions.erase(player)

func _clear_expired_turn_opponent_targeting_immunities(current_turn: int) -> void:
	for player in turn_opponent_targeting_immunities.keys().duplicate():
		var immunity_data: Variant = turn_opponent_targeting_immunities.get(player, null)
		if not (immunity_data is Dictionary):
			turn_opponent_targeting_immunities.erase(player)
			continue
		var expires_turn := int((immunity_data as Dictionary).get("expires_turn", -1))
		if expires_turn <= current_turn:
			turn_opponent_targeting_immunities.erase(player)

func _would_activation_break_turn_destruction_ward(source_card: Card, protected_player: Player, chosen_target = null) -> bool:
	if source_card == null or protected_player == null:
		return false
	var source_controller := source_card.get_controller()
	if source_controller == null:
		source_controller = source_card.card_owner
	if source_controller == null or source_controller == protected_player:
		return false
	if source_card.has_method("would_destroy_creature_of_player"):
		return source_card.would_destroy_creature_of_player(self, protected_player, chosen_target)
	var targeted_card := chosen_target as Card
	return targeted_card != null \
		and targeted_card.card_type == Card.CardType.CREATURE \
		and targeted_card.get_controller() == protected_player \
		and _card_has_destruction_theme(source_card)

func _card_has_destruction_theme(source_card: Card) -> bool:
	if source_card == null:
		return false
	for raw_type in source_card.card_types:
		if str(raw_type).findn("destruction") >= 0:
			return true
	return false

func record_interception(interceptor: Card) -> void:
	if interceptor == null:
		return
	var recorded_turn := int(interceptor.get_meta(INTERCEPT_COUNT_TURN_META, -1))
	var count := int(interceptor.get_meta(INTERCEPT_COUNT_VALUE_META, 0))
	if recorded_turn != turn_number:
		recorded_turn = turn_number
		count = 0
	count += 1
	interceptor.set_meta(INTERCEPT_COUNT_TURN_META, recorded_turn)
	interceptor.set_meta(INTERCEPT_COUNT_VALUE_META, count)

func get_interception_count_this_turn(card: Card) -> int:
	if card == null:
		return 0
	if int(card.get_meta(INTERCEPT_COUNT_TURN_META, -1)) != turn_number:
		return 0
	return int(card.get_meta(INTERCEPT_COUNT_VALUE_META, 0))

func get_creatures_with_intercepts_this_turn(player: Player, minimum_count: int = 1) -> Array[Card]:
	var matching_creatures: Array[Card] = []
	if player == null:
		return matching_creatures
	for zone in player.frontline_zones + player.reserve_zones:
		for card in zone.cards:
			if card == null or card.card_type != Card.CardType.CREATURE:
				continue
			if get_interception_count_this_turn(card) >= minimum_count:
				matching_creatures.append(card)
	return matching_creatures

func consume_player_feedback() -> String:
	var text := " ".join(_pending_player_feedback_texts)
	if text.strip_edges() == "":
		text = last_player_feedback_text
	last_player_feedback_text = ""
	_pending_player_feedback_texts.clear()
	return text

func note_ui_sound_cue(cue_name: String) -> void:
	var normalized_cue := cue_name.strip_edges()
	if normalized_cue == "":
		return
	_pending_ui_sound_cues.append(normalized_cue)

func consume_ui_sound_cues() -> Array[String]:
	var cues := _pending_ui_sound_cues.duplicate()
	_pending_ui_sound_cues.clear()
	return cues

func get_game_result_message(winner: Player = winning_player, loser: Player = losing_player, reason: String = "") -> String:
	var resolved_reason := reason.strip_edges()
	if resolved_reason == "":
		resolved_reason = game_end_reason
	if resolved_reason == GAME_END_REASON_FORFEIT:
		if winner != null and loser != null:
			return "%s wins the game! %s forfeited." % [winner.player_name, loser.player_name]
		if loser != null:
			return "Game over! %s forfeited." % [loser.player_name]
		if winner != null:
			return winner.player_name + " wins by forfeit!"
	if resolved_reason == GAME_END_REASON_MATCH_FORFEIT:
		if winner != null and loser != null:
			return "%s wins the match! %s forfeited the match." % [winner.player_name, loser.player_name]
		if loser != null:
			return "Match over! %s forfeited the match." % [loser.player_name]
		if winner != null:
			return winner.player_name + " wins the match by forfeit!"
	if winner != null and loser != null:
		return "%s wins the game! %s reached 0 followers." % [winner.player_name, loser.player_name]
	if loser != null:
		return "Game over! %s reached 0 followers." % [loser.player_name]
	if winner != null:
		return winner.player_name + " wins the game!"
	return "Game over!"

func set_temporary_combat_follower_damage_halved(halved: bool) -> void:
	_temporary_combat_follower_damage_halved = halved

func _adjust_combat_follower_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	if _temporary_combat_follower_damage_halved:
		return GameManager.round_down_divide(amount, 2)
	return amount

func get_card_by_uid(uid: String) -> Card:
	if uid == "":
		return null
		
	for p in players:
		# Check hand
		for c in p.hand_zone.cards:
			if c.get("uid") == uid: return c
		# Check deck
		for c in p.deck_zone.cards:
			if c.get("uid") == uid: return c
		# Check graveyard
		for c in p.graveyard_zone.cards:
			if c.get("uid") == uid: return c
		# Check abyss
		for c in p.abyss_zone.cards:
			if c.get("uid") == uid: return c
		# Check god zone
		for c in p.god_zone.cards:
			if c.get("uid") == uid: return c
		# Check board zones (frontline, reserve, power)
		for zones in [p.frontline_zones, p.reserve_zones, p.power_zones]:
			for zone in zones:
				for c in zone.cards:
					var found_card := _find_card_by_uid_recursive(c, uid)
					if found_card != null:
						return found_card
					
	return null

func _find_card_by_uid_recursive(card: Card, uid: String) -> Card:
	if card == null:
		return null
	if card.get("uid") == uid:
		return card
	for nested_value in card.get_hover_stored_cards():
		var nested_card := nested_value as Card
		if nested_card == null:
			continue
		var found_card := _find_card_by_uid_recursive(nested_card, uid)
		if found_card != null:
			return found_card
	return null

func can_cards_engage_each_other(attacker: Card, defender: Card) -> bool:
	if attacker == null or defender == null:
		return false
	if is_attack_blocked_by_active_structure(attacker, defender):
		return false
	var ignore_targeting_limits := attacker.can_ignore_attack_targeting_restrictions(defender)
	if not ignore_targeting_limits and attacker.has_method("can_engage") and not attacker.can_engage(defender):
		return false
	if not ignore_targeting_limits and defender.has_method("can_be_engaged_by") and not defender.can_be_engaged_by(attacker):
		return false
	return true

func can_interceptor_engage_attacker(interceptor: Card, attacker: Card) -> bool:
	if interceptor == null or attacker == null:
		return false
	if interceptor.has_method("can_engage") and not interceptor.can_engage(attacker):
		return false
	if attacker.has_method("can_be_engaged_by") and not attacker.can_be_engaged_by(interceptor):
		return false
	return true

# Returns eligible speed-2+ responses the given player can play against the top stack action.
func get_priority_responses(player: Player) -> Array:
	var responses: Array = []
	var seen_response_ids: Dictionary = {}
	_prune_stale_stack_actions()
	if action_stack.is_empty():
		return responses
	for card in player.god_zone.cards:
		_append_unique_priority_response(responses, seen_response_ids, card, player)
	for zone in player.power_zones + player.frontline_zones + player.reserve_zones:
		for card in zone.cards:
			_append_unique_priority_response(responses, seen_response_ids, card, player)
	for hex in prepared_hexes.keys().duplicate():
		_append_unique_priority_response(responses, seen_response_ids, hex, player)
	for charm in prepared_charms.keys().duplicate():
		_append_unique_priority_response(responses, seen_response_ids, charm, player)
	for c in player.hand_zone.cards:
		_append_unique_priority_response(responses, seen_response_ids, c, player)
	return responses

func _append_unique_priority_response(responses: Array, seen_response_ids: Dictionary, card: Card, player: Player) -> void:
	if card == null or not is_instance_valid(card) or not can_card_respond_to_priority(card, player):
		return
	var card_id := card.get_instance_id()
	if seen_response_ids.has(card_id):
		return
	seen_response_ids[card_id] = true
	responses.append(card)

func _get_priority_response_targets(card: Card, action: CardAction) -> Array:
	if card == null or not is_instance_valid(card):
		return []
	if card is HexCard:
		return get_priority_hex_targets(card as HexCard, action)
	if card.has_method("get_priority_targets"):
		return card.get_priority_targets(self, action)
	if card.has_method("get_priority_field_targets"):
		return card.get_priority_field_targets(self, action)
	if card.has_method("get_valid_targets"):
		return card.get_valid_targets(self)
	return []

func _priority_response_has_required_targets(card: Card, action: CardAction) -> bool:
	if card == null or action == null:
		return false
	if not is_targeting_source(card):
		return true
	return not _get_priority_response_targets(card, action).is_empty()

func is_targeting_source(card: Card) -> bool:
	return card != null and (card.targets or card.has_type("Targeting"))

func can_card_respond_to_priority(card: Card, player: Player = null) -> bool:
	if card == null or not is_instance_valid(card) or action_stack.is_empty():
		return false
	var responding_player := player if player != null else priority_player
	if responding_player == null or card.card_owner != responding_player:
		return false
	var top: CardAction = action_stack.back()
	if not _can_hand_card_respond_to_priority(card, top):
		return false
	if (card.is_power or card.is_god) and not can_player_use_powers(card.card_owner):
		return false
	if card.card_type == Card.CardType.SPELL and card.current_zone == card.card_owner.hand_zone and spells_must_be_prepared():
		return false
	if top.type == CardAction.Type.EVENT and top.event_name == "frontline_entry":
		if not card.has_method("can_respond_to_frontline_entry"):
			return false
		if not card.can_respond_to_frontline_entry(top):
			return false
	if top.type == CardAction.Type.EVENT and top.event_name == "destroyed":
		if not card.has_method("can_respond_to_destroyed_event"):
			return false
		if not card.can_respond_to_destroyed_event(top, self):
			return false
	var top_speed := top.get_timing_speed()
	if card is HexCard:
		if not prepared_hexes.has(card):
			return false
		if not card.is_prepared:
			return false
		if card.current_zone == null or not card.current_zone.is_board_zone():
			return false
		if prepared_hexes.get(card, turn_number) >= turn_number:
			return false
		if card.is_activation_locked(self):
			return false
		if _has_pending_stack_action_for_card(card):
			return false
		if not can_pay_prepared_card_activation_cost(card, responding_player):
			return false
		var hex_speed := card.get_effective_speed()
		if hex_speed < 2:
			return false
		if top_speed > 0 and hex_speed < top_speed:
			return false
		var typed_hex := card as HexCard
		if typed_hex.has_method("can_respond_after_upkeep") and not typed_hex.can_respond_after_upkeep(self):
			return false
		if typed_hex.has_method("can_respond_to_action") and typed_hex.can_respond_to_action(top):
			if typed_hex.has_method("get_priority_targets"):
				return not get_priority_hex_targets(typed_hex, top).is_empty()
			return true
		return top.type == CardAction.Type.ATTACK and top.attacker != null and not get_attack_hex_targets(top, typed_hex).is_empty()
	if card is CharmCard:
		var typed_charm := card as CharmCard
		if card.current_zone == card.card_owner.hand_zone:
			if not typed_charm.can_activate_from_hand(self, top):
				return false
		elif not typed_charm.can_activate_prepared(self, top):
			return false
		return _priority_response_has_required_targets(card, top)
	if card.has_method("can_respond_to_priority_action"):
		if _has_pending_stack_action_for_card(card):
			return false
		var response_speed := card.get_effective_speed()
		if card.has_method("get_priority_response_speed"):
			response_speed = int(card.get_priority_response_speed())
		if response_speed < 2:
			return false
		if top_speed > 0 and response_speed < top_speed:
			return false
		if not card.can_respond_to_priority_action(top, self):
			return false
		return _priority_response_has_required_targets(card, top)
	if card.current_zone != responding_player.hand_zone:
		return false
	if _has_pending_stack_action_for_card(card):
		return false
	if card.card_type != Card.CardType.SPELL:
		return false
	if card.get_effective_speed() < 2:
		return false
	if top_speed > 0 and card.get_effective_speed() < top_speed:
		return false
	if not can_play_card(responding_player, card, null):
		return false
	return _priority_response_has_required_targets(card, top)

func _can_hand_card_respond_to_priority(card: Card, action: CardAction) -> bool:
	if card == null or card.card_owner == null:
		return false
	if card.current_zone != card.card_owner.hand_zone:
		return true
	if card.card_owner == current_player:
		return true
	if card.has_method("can_respond_from_hand_on_opponent_turn"):
		return bool(card.can_respond_from_hand_on_opponent_turn(action, self))
	return false

func get_priority_hex_targets(hex: HexCard, action: CardAction) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if hex == null or action == null:
		return valid_targets
	if hex.has_method("get_priority_targets"):
		return hex.get_priority_targets(self, action)
	if action.type == CardAction.Type.ATTACK:
		return get_attack_hex_targets(action, hex)
	return valid_targets

func get_attack_hex_targets(action: CardAction, hex: HexCard) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if action == null or hex == null or action.type != CardAction.Type.ATTACK:
		return valid_targets
	var defender: Card = action.interceptor if action.interceptor != null else (action.target if action.target is Card else null)
	var candidates: Array[Card] = [action.attacker]
	if action.united_front_partner != null:
		candidates.append(action.united_front_partner)
	for candidate in candidates:
		if candidate == null or candidate in valid_targets:
			continue
		if candidate.current_zone == null or not candidate.current_zone.is_board_zone():
			continue
		if candidate.get_controller() != action.source_player:
			continue
		if hex.can_activate(candidate, defender):
			valid_targets.append(candidate)
	return valid_targets

func _has_pending_stack_action_for_card(card: Card) -> bool:
	for action in action_stack:
		if action.card == card:
			return true
	return false

func is_prepared_charm_ready(charm: CharmCard, _triggering_action: CardAction = null) -> bool:
	if charm == null:
		return false
	if not prepared_charms.has(charm):
		return false
	var prepared_turn: int = int(prepared_charms.get(charm, turn_number))
	return prepared_turn < turn_number

func setup_game() -> void:
	is_game_over = false
	winning_player = null
	losing_player = null
	game_end_reason = ""
	for player in players:
		player.game_manager = self
		if not player.card_moved.is_connected(_on_player_card_moved):
			player.card_moved.connect(_on_player_card_moved)
		var defeat_callback := Callable(self, "_on_player_defeated")
		if not player.defeated.is_connected(defeat_callback):
			player.defeated.connect(defeat_callback)
	
	if players.size() == 2:
		current_player = players[0]
		other_player = players[1]
		turn_player = current_player
		current_player.is_turn_player = true

# --- NEW ROBUST HELPER FUNCTION ---
# This is the state-independent way to find a player's opponent,
# essential for reliable card effects like Warding Stone.
func get_opponent(player: Player) -> Player:
	for p in players:
		if p != player:
			return p
	# Should not happen in a 2-player game
	return null

# Turn lifecycle order is intentionally explicit:
# 1. Officially begin the new turn and increment turn_number.
# 2. Reset once-per-turn state for the active player.
# 3. Open the upkeep window and resolve upkeep hooks with no priority window.
# 4. Later, when the player chooses a mana/card upkeep option or another upkeep option,
#    mark upkeep complete and then fire turn-start hooks/effects.
func start_turn() -> void:
	if is_game_over:
		return
	_prune_stale_stack_actions()
	turn_player = current_player
	turn_number += 1
	_set_phase(GamePhase.MAIN)
	has_resolved_attack_this_turn = false
	died_this_turn.clear()
	destroyed_this_turn.clear()
	pending_resurrections.clear()
	combat_destroy_events_this_turn.clear()
	for player in players:
		_notify_player_god_visual_state_changed(player)
	_temporary_summon_cost_modifiers.clear()

	current_player.reset_creature_actions()
	
	for zone in current_player.frontline_zones + current_player.reserve_zones:
		for card in zone.cards:
			if card.card_type == Card.CardType.CREATURE:
				card.summoned_this_turn = false

	_begin_turn_upkeep()

func _begin_turn_upkeep() -> void:
	if _upkeep_started_turn == turn_number:
		return
	_upkeep_started_turn = turn_number
	if is_player_under_god_death(current_player):
		current_player.lose_followers(GOD_DEATH_FOLLOWER_LOSS)
		note_player_feedback(
			"[b]God Death[/b]: %s loses %d followers and gains 1 less upkeep mana." % [
				current_player.player_name,
				GOD_DEATH_FOLLOWER_LOSS
			]
		)
		if is_game_over:
			return
	for card in _get_sorted_upkeep_cards_for_player(current_player, "on_turn_upkeep"):
		card.on_turn_upkeep(self)
		if is_game_over:
			return
	var opponent := get_opponent(current_player)
	if opponent != null:
		for card in _get_sorted_upkeep_cards_for_player(opponent, "on_opponent_turn_upkeep"):
			card.on_opponent_turn_upkeep(self, current_player)
			if is_game_over:
				return
	turn_upkeep_started.emit(turn_number, current_player)

func _resolve_turn_upkeep() -> void:
	if _upkeep_resolved_turn == turn_number:
		return
	_begin_turn_upkeep()
	_upkeep_resolved_turn = turn_number
	turn_upkeep_resolved.emit(turn_number, current_player)
	_notify_controller_turn_start(current_player)
	_notify_global_turn_start(current_player)
	turn_started.emit(turn_number, current_player)

func has_target_immunity(target: Card, source: Card, immunity_kind: String) -> bool:
	if target == null or source == null:
		return false
	for status in target.active_statuses:
		var status_name := str(status.get("name", ""))
		if status_name == "blessed_ward":
			if status.get("ward_kind", "") != immunity_kind:
				continue
			return true
		if status_name == "third_sage_good_fortune":
			if status.get("ward_kind", "") != immunity_kind:
				continue
			if _is_third_sage_good_fortune_active(target, status):
				return true
	if immunity_kind == "hexes":
		var controller := target.get_controller()
		if controller == null:
			return false
		for passive_card in target.get_controller_passive_cards():
			if passive_card is EnkiLordOfEridu and (passive_card as EnkiLordOfEridu).protects_from_hex(target):
				return true
	return false

func _is_third_sage_good_fortune_active(target: Card, status: Dictionary) -> bool:
	if target == null:
		return false
	var source_card := status.get("source_card", null) as Card
	if source_card == null:
		return false
	if source_card.abilities_suppressed():
		return false
	if source_card.is_face_down or source_card.is_stealth:
		return false
	if source_card.current_zone == null or not source_card.current_zone.is_board_zone():
		return false
	var expected_board_entry_order := int(status.get("source_board_entry_order", source_card.board_entry_order))
	if expected_board_entry_order >= 0 and source_card.board_entry_order != expected_board_entry_order:
		return false
	return true

func _is_watchbeast_active() -> bool:
	for player in players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card != null and not card.abilities_suppressed() \
						and card.has_method("is_watchbeast") and card.is_watchbeast():
					return true
	return false

func _has_gala_tura_graveward(target: Card, source: Card) -> bool:
	if target == null or source == null:
		return false
	if target.current_zone == null or target.current_zone.zone_type != Zone.ZoneType.GRAVEYARD:
		return false
	if target.card_owner == null:
		return false
	var source_controller := source.get_controller()
	if source_controller == null:
		source_controller = source.card_owner
	if source_controller == null or source_controller == target.card_owner:
		return false
	for status in target.active_statuses:
		if status.get("name", "") != "gala_tura_graveward":
			continue
		var source_card := status.get("source_card", null) as Card
		if source_card == null:
			continue
		if source_card.abilities_suppressed():
			continue
		if source_card.current_zone == null or not source_card.current_zone.is_board_zone():
			continue
		if source_card.get_controller() != target.card_owner:
			continue
		return true
	return false

func is_immune_to_source(target: Card, source: Card) -> bool:
	if target == null or source == null:
		return false
	if _has_gala_tura_graveward(target, source):
		return true
	var target_controller := target.get_controller()
	if target_controller == null:
		target_controller = target.card_owner
	var source_controller := source.get_controller()
	if source_controller == null:
		source_controller = source.card_owner
	if target_controller != null \
			and source_controller != null \
			and target_controller != source_controller \
			and is_targeting_source(source) \
			and has_turn_opponent_targeting_immunity(target_controller):
		return true
	if target.current_zone != null \
			and target.current_zone.zone_type == Zone.ZoneType.GRAVEYARD \
			and _is_watchbeast_active():
		return true
	var immunity_kind := source.get_ability_immunity_tag() if source.has_method("get_ability_immunity_tag") else ""
	if immunity_kind == "":
		return false
	return has_target_immunity(target, source, immunity_kind)

func _is_hex_immune(target: Card, source: Card = null) -> bool:
	if target == null:
		return false
	if source != null and is_immune_to_source(target, source):
		return true
	var controller := target.get_controller()
	if controller == null:
		return false
	for passive_card in target.get_controller_passive_cards():
		if passive_card is EnkiLordOfEridu and (passive_card as EnkiLordOfEridu).protects_from_hex(target):
			return true
	return false

func activate_hex(hex: HexCard, attacker: Card, defender: Card) -> bool:
	print(hex.card_name + " triggers!")
	last_hex_resolution_text = ""
	if hex != null and hex.is_prepared and not activate_prepared_card(hex, hex.card_owner):
		last_hex_resolution_text = get_activation_mana_unavailable_text(hex) if has_insufficient_activation_mana(hex, true, hex.card_owner) else "Cannot afford %s!" % hex.card_name
		return false
	prepared_hexes.erase(hex)
	for affected_card in hex.get_affected_cards(attacker, defender):
		if _is_hex_immune(affected_card, hex):
			print(hex.card_name + " fizzles against " + affected_card.card_name + " due to hex immunity.")
			last_hex_resolution_text = "%s triggered, but %s was immune to hexes." % [hex.card_name, affected_card.card_name]
			hex.on_immune_activate(self, attacker, defender)
			return true
	hex.on_activate(self, attacker, defender)
	return true

func player_chooses_draw() -> void:
	if is_game_over:
		return
	if not is_player_in_upkeep_window(current_player):
		return
	_begin_turn_upkeep()
	_gain_upkeep_choice_mana(get_base_upkeep_draw_mana_gain())
	current_player.draw_card()
	_resolve_turn_upkeep()

func player_chooses_mana() -> void:
	if is_game_over:
		return
	if not is_player_in_upkeep_window(current_player):
		return
	_begin_turn_upkeep()
	_gain_upkeep_choice_mana(get_base_upkeep_mana_gain())
	_resolve_turn_upkeep()

func _gain_upkeep_choice_mana(amount: int) -> void:
	if amount <= 0 or current_player == null:
		return
	var effective_amount := get_effective_upkeep_mana_gain(amount, current_player)
	if effective_amount <= 0:
		return
	current_player.gain_mana(effective_amount)

func get_upkeep_choice_feedback(choice: String) -> String:
	match choice:
		"draw":
			var draw_mana := get_effective_upkeep_mana_gain(get_base_upkeep_draw_mana_gain(), current_player)
			return "Drew a card." if draw_mana <= 0 else "Gained %d mana and drew a card." % draw_mana
		"mana":
			var mana_gain := get_effective_upkeep_mana_gain(get_base_upkeep_mana_gain(), current_player)
			return "No upkeep mana gained." if mana_gain <= 0 else "Gained %d mana." % mana_gain
		"skip":
			return "Skipped upkeep choice."
	return ""

func is_first_game_turn() -> bool:
	return turn_number == 1

func get_base_upkeep_draw_mana_gain() -> int:
	return FIRST_TURN_UPKEEP_DRAW_MANA_GAIN if is_first_game_turn() else UPKEEP_DRAW_MANA_GAIN

func get_base_upkeep_mana_gain() -> int:
	return FIRST_TURN_UPKEEP_MANA_GAIN if is_first_game_turn() else UPKEEP_MANA_GAIN

func get_effective_upkeep_mana_gain(base_amount: int, player: Player = null) -> int:
	var target_player := player if player != null else current_player
	var effective_amount := maxi(base_amount, 0)
	if is_player_under_god_death(target_player):
		effective_amount = maxi(0, effective_amount - GOD_DEATH_UPKEEP_MANA_PENALTY)
	return effective_amount

func player_chooses_upkeep_only() -> void:
	if is_game_over:
		return
	if not is_player_in_upkeep_window(current_player):
		return
	_resolve_turn_upkeep()

func add_temporary_summon_cost_modifier(
	player: Player,
	amount: int,
	source: Card = null,
	excluded_card: Card = null
) -> void:
	if player == null or amount == 0:
		return
	var excluded_cards: Array[Card] = []
	if excluded_card != null:
		excluded_cards.append(excluded_card)
	_temporary_summon_cost_modifiers.append({
		"player": player,
		"amount": amount,
		"source": source,
		"excluded_cards": excluded_cards,
		"turn_number": turn_number,
	})

func card_uses_summon_cost_rules(card: Card) -> bool:
	if card == null:
		return false
	if card.card_type == Card.CardType.CREATURE:
		return not card.is_god
	return card.card_type == Card.CardType.STRUCTURE

func get_card_summon_mana_cost(
	player: Player,
	card: Card,
	summon_source: Card = null,
	ignore_base_cost: bool = false
) -> int:
	if card == null:
		return 0
	var total_cost := 0 if ignore_base_cost else card.mana_cost
	return card.get_adjusted_mana_cost(
		total_cost,
		Card.COST_KIND_CREATURE_SUMMON,
		self,
		{"player": player, "summon_source": summon_source}
	)

func get_card_play_mana_cost(
	player: Player,
	card: Card,
	prepared: bool = false
) -> int:
	if card == null:
		return 0
	if card_uses_summon_cost_rules(card):
		return get_card_summon_mana_cost(player, card)
	return card.get_adjusted_mana_cost(
		card.mana_cost,
		Card.COST_KIND_HAND_PLAY,
		self,
		{"player": player, "prepared": prepared}
	)

func get_prepared_card_activation_mana_cost(player: Player, card: Card) -> int:
	if player == null or card == null:
		return 0
	return get_card_play_mana_cost(player, card, true)

func can_pay_prepared_card_activation_cost(card: Card, player: Player = null) -> bool:
	if card == null:
		return false
	if not card.is_prepared:
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	var paying_player := player if player != null else card.card_owner
	if paying_player == null:
		return false
	var mana_required := get_prepared_card_activation_mana_cost(paying_player, card)
	return card.can_pay_costs_with_mana_cost(paying_player, mana_required)

func activate_prepared_card(card: Card, player: Player = null) -> bool:
	if card == null:
		return false
	if not card.is_prepared:
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	var paying_player := player if player != null else card.card_owner
	if paying_player == null:
		return false
	var mana_required := get_prepared_card_activation_mana_cost(paying_player, card)
	if not card.pay_costs_with_mana_cost(paying_player, mana_required, self):
		return false
	if not card_uses_summon_cost_rules(card) and mana_required < card.mana_cost:
		claim_cost_adjustments(
			card,
			card.mana_cost,
			Card.COST_KIND_HAND_PLAY,
			{"player": paying_player, "prepared": true}
		)
	prepared_hexes.erase(card)
	prepared_charms.erase(card)
	card.is_prepared = false
	card.reveal(self)
	return true

func get_additional_summon_mana_cost(player: Player, creature: Card, summon_source: Card = null) -> int:
	if player == null or creature == null:
		return 0
	return maxi(0, get_total_cost_adjustment(
		creature,
		creature.mana_cost,
		Card.COST_KIND_CREATURE_SUMMON,
		{"player": player, "summon_source": summon_source}
	))

func get_creature_summon_mana_cost(
	player: Player,
	creature: Card,
	summon_source: Card = null,
	ignore_base_cost: bool = false
) -> int:
	if creature == null:
		return 0
	return get_card_summon_mana_cost(player, creature, summon_source, ignore_base_cost)

func can_pay_creature_summon_cost(
	player: Player,
	creature: Card,
	summon_source: Card = null,
	pay_normal_summon_costs: bool = true
) -> bool:
	if player == null or creature == null:
		return false
	var mana_required := get_creature_summon_mana_cost(
		player,
		creature,
		summon_source,
		not pay_normal_summon_costs
	)
	if pay_normal_summon_costs:
		return creature.can_pay_costs_with_mana_cost(player, mana_required)
	return player.mana >= mana_required

func can_play_card(player: Player, card: Card, target_zone: Zone) -> bool:
	return get_play_card_failure_reason(player, card, target_zone).is_empty()

func get_play_card_failure_reason(player: Player, card: Card, target_zone: Zone) -> String:
	_prune_stale_stack_actions()
	if is_game_over:
		return "The game is already over."
	if player == null:
		return "No acting player was provided."
	if card == null:
		return "The selected card was not found."
	if player == current_player and not has_resolved_turn_upkeep():
		return "Resolve upkeep before taking other actions."
	if card.card_type == Card.CardType.SPELL and card.current_zone == player.hand_zone and spells_must_be_prepared():
		return "Heavy Snow prevents spells from being cast from hand."
	var card_failure_reason := ""
	if card.has_method("get_play_failure_reason"):
		card_failure_reason = str(card.call("get_play_failure_reason", self, player))
	if not card_failure_reason.is_empty():
		return card_failure_reason
	if not card.can_be_played(self, player):
		return card.card_name + " cannot be played right now."
	# Check if player can pay costs
	var mana_required := get_card_play_mana_cost(player, card, false)
	if not card.can_pay_costs_with_mana_cost(player, mana_required):
		print("Cannot afford card costs")
		return card.get_cost_payment_failure_reason(player, mana_required)

	# Speed 1 cards can only be played on your turn
	if card.get_effective_speed() == 1 and player != current_player:
		return "Speed 1 cards can only be played on your turn."

	# God and power cards go to special zones
	if card.is_god and target_zone != player.god_zone:
		return "Choose your God zone."
	if card.is_power and not card.is_god and target_zone not in player.power_zones:
		return "Choose one of your power zones."

	# Regular cards go to frontline or reserve
	if not card.is_god and not card.is_power:
		if target_zone != null:
			if target_zone not in player.frontline_zones and target_zone not in player.reserve_zones:
				return "Choose a frontline or reserve zone."

	# One creature summon per turn
	if card.card_type == Card.CardType.CREATURE and player == current_player:
		if player.has_summoned_this_turn and not _can_use_extra_normal_summon(player, card, target_zone):
			return "You have already used your normal summon for this turn."

	# One structure summon per turn
	if card.card_type == Card.CardType.STRUCTURE and player == current_player:
		if player.has_summoned_structure_this_turn:
			return "You have already summoned a structure this turn."

	# Equipment zone rules: unequipped equipment cannot share a zone with anything else.
	if target_zone != null and target_zone.is_board_zone():
		var unequipped_in_zone := target_zone.get_equipment()
		if card.card_type == Card.CardType.EQUIPMENT:
			# Equipment can only be played to an empty zone or a zone with exactly one creature (auto-equip)
			var has_unequipped := unequipped_in_zone.size() > 0
			var creature_in_zone := target_zone.get_creature()
			if has_unequipped:
				print("Cannot play equipment: zone already has unequipped equipment")
				return "Cannot play equipment: zone already has unequipped equipment"
			if target_zone.cards.size() > 0 and creature_in_zone == null:
				print("Cannot play equipment: zone occupied by a non-creature card")
				return "Cannot play equipment: zone occupied by a non-creature card"
			if creature_in_zone != null and not card.can_equip_to(creature_in_zone):
				print("Cannot play equipment: target creature is not a valid bearer")
				return "Cannot play equipment: target creature is not a valid bearer"
		else:
			# Non-equipment cards cannot enter a zone containing unequipped equipment
			if unequipped_in_zone.size() > 0:
				print("Cannot play card: zone contains unequipped equipment")
				return "Cannot play card: zone contains unequipped equipment"

	return ""

func get_prepare_card_failure_reason(player: Player, card: Card, target_zone: Zone, ignore_stack_window: bool = false) -> String:
	_prune_stale_stack_actions()
	if is_game_over:
		return "The game is already over."
	if player == null:
		return "No acting player was provided."
	if card == null:
		return "The selected card was not found."
	if not ignore_stack_window and not action_stack.is_empty():
		return "Cannot prepare cards while another action is resolving."
	if player == current_player and not has_resolved_turn_upkeep():
		return "Resolve upkeep before taking other actions."
	if card.card_type not in [Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM]:
		return "%s cannot be prepared." % card.card_name
	var card_reason := card.get_prepare_failure_reason(self, player)
	if not card_reason.is_empty():
		return card_reason
	if target_zone == null or not target_zone.is_board_zone():
		return "Choose a friendly board zone."
	if target_zone.zone_owner != player:
		return "You can only prepare cards into your own zones."
	if target_zone not in player.frontline_zones and target_zone not in player.reserve_zones:
		return "Choose a frontline or reserve zone."
	if target_zone.cards.size() > 0:
		return "That zone is occupied."
	if target_zone.get_equipment().size() > 0:
		return "Cannot prepare card: zone contains unequipped equipment"
	return ""

func can_prepare_card(player: Player, card: Card, target_zone: Zone) -> bool:
	var failure_reason := get_prepare_card_failure_reason(player, card, target_zone)
	if not failure_reason.is_empty():
		if failure_reason == "Cannot prepare card: zone contains unequipped equipment":
			print(failure_reason)
		return false
	return true

func play_card(player: Player, card: Card, target_zone: Zone, prepared: bool = false) -> void:
	if is_game_over:
		return
	var can_place := can_prepare_card(player, card, target_zone) if prepared else can_play_card(player, card, target_zone)
	if can_place:
		var from_zone := card.current_zone
		var used_extra_normal_summon := (
			not prepared
			and card.card_type == Card.CardType.CREATURE
			and player == current_player
			and player.has_summoned_this_turn
			and _can_use_extra_normal_summon(player, card, target_zone)
		)
		var entered_field_face_up_from_hand := (
			from_zone == player.hand_zone
			and target_zone != null
			and target_zone.is_board_zone()
			and not prepared
		)

		if not prepared:
			# Prepared cards now pay when they activate, not when they are set.
			var mana_required := get_card_play_mana_cost(player, card, prepared)
			if not card.pay_costs_with_mana_cost(player, mana_required, self):
				print("Failed to pay costs")
				return
			if not card_uses_summon_cost_rules(card) and mana_required < card.mana_cost:
				claim_cost_adjustments(
					card,
					card.mana_cost,
					Card.COST_KIND_HAND_PLAY,
					{"player": player, "prepared": prepared}
				)
		
		card.is_prepared = prepared
		card.is_face_down = prepared
		player.move_card(card, target_zone)

		# Auto-equip: if equipment is played to a zone with a creature, equip it
		if card.card_type == Card.CardType.EQUIPMENT:
			var creature_there := target_zone.get_creature()
			if creature_there != null:
				card.equip_to(creature_there)
				_maybe_apply_telchine_hand_weapon_imbue(player, from_zone, card, creature_there)
				print(card.card_name + " equipped to " + creature_there.card_name)

		# Mark summoned
		if card.card_type == Card.CardType.CREATURE:
			card.reset_creature_action_state()
			card.spend_creature_summon_actions()
			player.has_summoned_this_turn = true
			if used_extra_normal_summon:
				_consume_extra_normal_summon(player, card, target_zone)
			card.summoned_this_turn = true
			card.summoned_after_first_attack_this_turn = has_resolved_attack_this_turn
			# Apply any active god passives to the newly placed creature
			_apply_god_passives_to_card(player, card)
		elif card.card_type == Card.CardType.STRUCTURE and player == current_player and not prepared:
			player.has_summoned_structure_this_turn = true

		if target_zone != null and target_zone.is_board_zone() and card.card_type in [Card.CardType.CREATURE, Card.CardType.STRUCTURE]:
			_trigger_board_summon(card, player, from_zone, target_zone, null, card.is_face_down, card.is_stealth, entered_field_face_up_from_hand)
		
		# Hexes must be prepared
		if card.card_type == Card.CardType.HEX:
			if not prepared:
				print("Hexes must be prepared before use")
				return
			prepared_hexes[card] = turn_number
		elif card is CharmCard and prepared:
			prepared_charms[card] = turn_number
		
		# Handle spells - cast them after they're in the zone
		if card.card_type == Card.CardType.SPELL and not prepared:
			print("	Casting spell from zone...")
			if card is SpellCard:
				_notify_spell_played(player, card)
				card.on_play(self, null)
		
		if card.goes_to_graveyard_after_use() and not prepared:
			# Add to action stack or resolve immediately
			resolve_card_effect(card)

func play_creature_stealth(player: Player, card: Card, target_zone: Zone) -> void:
	if card.card_type == Card.CardType.CREATURE:
		summon_creature_by_effect(
			player,
			card,
			target_zone,
			Card.CreatureMode.DEFENSIVE,
			true,
			true,
			null,
			true,
			true,
			true
		)

func summon_structure_without_cost(
	player: Player,
	card: Card,
	target_zone: Zone
) -> bool:
	return summon_structure_by_effect(
		player,
		card,
		target_zone,
		null,
		false,
		true
	)

func summon_structure_by_effect(
	player: Player,
	card: Card,
	target_zone: Zone,
	summon_source: Card = null,
	pay_normal_summon_costs: bool = false,
	trigger_impact: bool = true
) -> bool:
	if is_game_over or player == null or card == null:
		return false
	if card.card_type != Card.CardType.STRUCTURE:
		return false
	if target_zone == null:
		return false
	if target_zone not in player.frontline_zones and target_zone not in player.reserve_zones:
		return false
	if not target_zone.cards.is_empty():
		return false

	var mana_required := get_card_summon_mana_cost(
		player,
		card,
		summon_source,
		not pay_normal_summon_costs
	)
	if pay_normal_summon_costs:
		if not card.pay_costs_with_mana_cost(player, mana_required, self):
			return false
	elif mana_required > 0 and not player.spend_mana(mana_required):
		return false

	var from_zone := card.current_zone
	player.move_card(card, target_zone)
	card.is_prepared = false
	card.is_face_down = false
	card.is_stealth = false
	_trigger_board_summon(card, player, from_zone, target_zone, summon_source, false, false, trigger_impact)
	return true

func summon_creature_without_cost(
	player: Player,
	card: Card,
	target_zone: Zone,
	mode: Card.CreatureMode = Card.CreatureMode.AGGRESSIVE,
	face_down: bool = false,
	stealth: bool = false
) -> bool:
	return summon_creature_by_effect(
		player,
		card,
		target_zone,
		mode,
		face_down,
		stealth,
		null,
		false,
		false,
		true
	)

func summon_creature_by_effect(
	player: Player,
	card: Card,
	target_zone: Zone,
	mode: Card.CreatureMode = Card.CreatureMode.AGGRESSIVE,
	face_down: bool = false,
	stealth: bool = false,
	summon_source: Card = null,
	pay_normal_summon_costs: bool = false,
	consume_turn_summon: bool = false,
	trigger_impact: bool = true,
	skip_mana_payment: bool = false
) -> bool:
	if is_game_over or player == null or card == null:
		return false
	if card.card_type != Card.CardType.CREATURE:
		return false
	if target_zone == null:
		return false
	if target_zone not in player.frontline_zones and target_zone not in player.reserve_zones:
		return false
	if not target_zone.cards.is_empty():
		return false
	var using_extra_normal_summon := false
	if player == current_player and consume_turn_summon and player.has_summoned_this_turn:
		if _can_use_extra_normal_summon(player, card, target_zone):
			using_extra_normal_summon = true
		else:
			return false
	if not can_pay_creature_summon_cost(player, card, summon_source, pay_normal_summon_costs):
		return false

	var mana_required := get_creature_summon_mana_cost(
		player,
		card,
		summon_source,
		not pay_normal_summon_costs
	)
	if pay_normal_summon_costs:
		if not card.pay_costs_with_mana_cost(player, mana_required, self):
			return false
	elif not skip_mana_payment and mana_required > 0 and not player.spend_mana(mana_required):
		return false

	var from_zone := card.current_zone
	player.move_card(card, target_zone)
	card.is_prepared = false
	card.is_face_down = face_down
	card.is_stealth = stealth
	var resolved_mode: Card.CreatureMode = mode
	if face_down:
		resolved_mode = Card.CreatureMode.DEFENSIVE
	if resolved_mode == Card.CreatureMode.AGGRESSIVE and _any_active_structure_forces_defensive_summon():
		resolved_mode = Card.CreatureMode.DEFENSIVE
	card.creature_mode = resolved_mode
	card.reset_creature_action_state()
	if consume_turn_summon:
		card.spend_creature_summon_actions(stealth)
	card.summoned_this_turn = true
	card.summoned_after_first_attack_this_turn = has_resolved_attack_this_turn
	if consume_turn_summon:
		player.has_summoned_this_turn = true
		if using_extra_normal_summon:
			_consume_extra_normal_summon(player, card, target_zone)

	if not face_down:
		card.wake_up()

	_apply_god_passives_to_card(player, card)

	_trigger_board_summon(card, player, from_zone, target_zone, summon_source, face_down, stealth, trigger_impact)
	return true

func _trigger_board_summon(
	card: Card,
	player: Player,
	from_zone: Zone,
	target_zone: Zone,
	summon_source: Card = null,
	face_down: bool = false,
	stealth: bool = false,
	trigger_impact: bool = true
) -> void:
	if card == null or player == null or target_zone == null:
		return
	if card.has_method("on_summon"):
		card.on_summon(self)
	var should_trigger_impact := not face_down \
		and trigger_impact \
		and _should_trigger_summon_impact(card, from_zone, summon_source) \
		and not card.abilities_suppressed()
	if should_trigger_impact and card.has_method("on_impact"):
		card.on_impact(self)
	card_summoned.emit(player, card, from_zone, target_zone, summon_source, face_down, stealth)
	_notify_powers_of_creature_summon(player, card, from_zone, target_zone, summon_source, face_down, stealth)

func _should_trigger_summon_impact(card: Card, from_zone: Zone, summon_source: Card) -> bool:
	if card == null:
		return false
	if card.has_method("should_trigger_impact_from_zone"):
		if card.should_trigger_impact_from_zone(from_zone):
			return true
	elif from_zone != null and from_zone.zone_type == Zone.ZoneType.HAND:
		return true
	return _is_active_god_manifestation_summon(card, summon_source)

func _is_active_god_manifestation_summon(card: Card, summon_source: Card) -> bool:
	var active_god := card as ActiveGodCard
	if active_god == null or summon_source == null:
		return false
	if summon_source.card_name == "Take the Field":
		return true
	var normal_god := summon_source as GodCard
	return normal_god != null and normal_god.is_own_active_god_card(active_god)

func prepare_card(player: Player, card: Card, target_zone: Zone) -> void:
	play_card(player, card, target_zone, true)

func reveal_prepared_card(card: Card) -> void:
	if card.is_prepared:
		card.reveal(self)
		if card.card_type == Card.CardType.HEX and card in prepared_hexes:
			card.is_prepared = false

func resolve_card_effect(card: Card) -> void:
	# Card-specific effects would be implemented here
	if card.goes_to_graveyard_after_use():
		# *** CHANGE: Use hook helper for destruction ***
		_send_to_graveyard_with_hook(card)

func spells_must_be_prepared() -> bool:
	for player in players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card == null:
					continue
				if not (card is CharmCard):
					continue
				if card.card_name != "Heavy Snow":
					continue
				if card.is_face_down or card.abilities_suppressed():
					continue
				return true
	return false

func get_creature_action_mana_cost(creature: Card, _action_name: String = "") -> int:
	if creature == null:
		return 0
	var total_cost := 0
	for player in players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones + player.power_zones:
			if zone == null:
				continue
			for zone_card in zone.cards:
				if not (zone_card is PermanentHexCard):
					continue
				var binding_hex := zone_card as PermanentHexCard
				if binding_hex == null or binding_hex.attached_target != creature:
					continue
				if zone_card.has_method("get_creature_action_tax_amount"):
					total_cost += int(zone_card.get_creature_action_tax_amount(creature, self))
	return maxi(0, total_cost)

func can_pay_creature_action_mana_cost(creature: Card, action_name: String = "") -> bool:
	var cost := get_creature_action_mana_cost(creature, action_name)
	if cost <= 0:
		return true
	var controller := creature.get_controller()
	return controller != null and controller.mana >= cost

func pay_creature_action_mana_cost(creature: Card, action_name: String = "") -> bool:
	var cost := get_creature_action_mana_cost(creature, action_name)
	if cost <= 0:
		return true
	var controller := creature.get_controller()
	if controller == null or not controller.spend_mana(cost):
		return false
	var viewer := get_feedback_viewer()
	var action_label := action_name if action_name != "" else "act"
	note_player_feedback("%s pays %d mana for %s to %s." % [
		controller.player_name,
		cost,
		creature.get_target_log_display_name(viewer),
		action_label
	])
	return true

func creature_move(creature: Card, target_zone: Zone) -> bool:
	if is_game_over:
		return false
	if creature.card_type != Card.CardType.CREATURE:
		return false
	
	if not creature.get_status_effect("cannot_move").is_empty():
		return false
	
	if not creature.can_take_minor_creature_action():
		return false

	var current_zone = creature.current_zone
	var controller := creature.get_controller()
	if controller == null:
		return false
	var adjacent_zones = controller.get_adjacent_zones(current_zone)

	if target_zone in adjacent_zones:
		if target_zone.get_equipment().size() > 0:
			print("Cannot move: zone contains unequipped equipment")
			return false
		if not can_pay_creature_action_mana_cost(creature, "move"):
			return false
		if not pay_creature_action_mana_cost(creature, "move"):
			return false
		creature.reveal_from_stealth(self)
		creature.card_owner.move_card(creature, target_zone)
		creature.spend_minor_creature_action(true)
		return true
	
	return false

func creature_change_mode(creature: Card, target_mode = -1) -> bool:
	if is_game_over:
		return false
	if creature.card_type != Card.CardType.CREATURE:
		return false
	
	if not creature.can_take_minor_creature_action():
		return false
	if not can_pay_creature_action_mana_cost(creature, "change stance"):
		return false
	if not pay_creature_action_mana_cost(creature, "change stance"):
		return false
	
	var requested_mode := int(target_mode)
	var old_mode: Card.CreatureMode = creature.creature_mode
	creature.reveal_from_stealth(self)
	if requested_mode == Card.CreatureMode.AGGRESSIVE or requested_mode == Card.CreatureMode.DEFENSIVE:
		creature.creature_mode = int(requested_mode) as Card.CreatureMode
	elif creature.creature_mode == Card.CreatureMode.AGGRESSIVE:
		creature.creature_mode = Card.CreatureMode.DEFENSIVE
	else:
		creature.creature_mode = Card.CreatureMode.AGGRESSIVE

	creature.spend_minor_creature_action()
	if old_mode != creature.creature_mode:
		if creature.has_method("on_mode_change") and not creature.abilities_suppressed():
			creature.on_mode_change(self, old_mode)
		_notify_cards_of_creature_mode_change(creature, old_mode)
	return true

func equip_card(equipment: Card, creature: Card) -> bool:
	if is_game_over:
		return false
	if equipment.card_type != Card.CardType.EQUIPMENT:
		return false
	
	if creature == null or not equipment.can_equip_to(creature):
		return false
	
	if not creature.can_take_major_creature_action():
		return false
	if not can_pay_creature_action_mana_cost(creature, "equip"):
		return false
	
	if equipment.current_zone != creature.current_zone:
		return false
	
	if not pay_creature_action_mana_cost(creature, "equip"):
		return false
	equipment.equip_to(creature)
	creature.spend_major_creature_action()
	return true

func _maybe_apply_telchine_hand_weapon_imbue(player: Player, from_zone: Zone, equipment: Card, _creature: Card) -> void:
	if player == null or equipment == null or from_zone != player.hand_zone:
		return
	if equipment.card_type != Card.CardType.EQUIPMENT or not equipment.has_type("Weapon"):
		return
	var source := _get_active_telchine_apprentice(player)
	if source == null:
		return
	if equipment.has_method("apply_telchine_apprentice_imbue"):
		equipment.apply_telchine_apprentice_imbue(source, player)

func _get_active_telchine_apprentice(player: Player) -> Card:
	if player == null:
		return null
	for zone in player.frontline_zones + player.reserve_zones:
		for card in zone.cards:
			if card == null:
				continue
			if card.card_type != Card.CardType.CREATURE:
				continue
			if card.card_name != "Telchine Apprentice":
				continue
			if card.abilities_suppressed() or card.is_face_down or card.is_stealth or card.is_prepared:
				continue
			return card
	return null

# Returns all board zones reachable by a creature:
# - own adjacent/diagonal zones (same player's board)
# - opposing frontline zones at same or ±1 column index (if creature is in frontline)
func get_reachable_board_zones(creature: Card) -> Array[Zone]:
	var creature_zone := creature.current_zone
	if creature_zone == null or not creature_zone.is_board_zone():
		return []
	var controller := creature.get_controller()
	if controller == null:
		return []
	var reachable: Array[Zone] = controller.get_adjacent_zones(creature_zone)
	# Cross-board reach: frontline creature can reach opposing frontline at ±1 column
	if creature_zone.zone_type == Zone.ZoneType.FRONTLINE:
		var opponent := get_opponent(controller)
		if opponent != null:
			var ci := creature_zone.zone_index
			for di in [-1, 0, 1]:
				var ti: int = ci + di
				if ti >= 0 and ti < opponent.frontline_zones.size():
					reachable.append(opponent.frontline_zones[ti])
	return reachable

# Creature picks up (equips) an unequipped equipment card from an adjacent/diagonal zone.
# Own equipment: no intercept. Enemy equipment: subject to intercept.
# Returns false if the action is blocked or invalid.
func creature_pick_up_equipment(creature: Card, equipment: Card) -> bool:
	if is_game_over:
		return false
	if creature == null or not creature.can_receive_equipment():
		return false
	if equipment.card_type != Card.CardType.EQUIPMENT or equipment.equipped_on != null:
		return false
	if not equipment.can_equip_to(creature):
		return false
	var equip_zone := equipment.current_zone
	if equip_zone == null or not equip_zone.is_board_zone():
		return false
	var reachable := get_reachable_board_zones(creature)
	var controller := creature.get_controller()
	if controller == null:
		return false
	var is_enemy := equip_zone.zone_owner != controller
	var in_range := equip_zone in reachable
	if is_enemy:
		if not creature.can_take_major_creature_action():
			return false
	elif not creature.can_take_minor_creature_action():
		return false
	if not can_pay_creature_action_mana_cost(creature, "pick up equipment"):
		return false
	# Must be in frontline to act on out-of-range enemy equipment
	if is_enemy and not in_range and creature.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		return false
	if not pay_creature_action_mana_cost(creature, "pick up equipment"):
		return false
	if is_enemy:
		creature.spend_major_creature_action()
	else:
		creature.spend_minor_creature_action()
	if is_enemy and equipment.has_method("request_self_steal_replacement_choice") and not equipment.abilities_suppressed():
		if equipment.request_self_steal_replacement_choice(self, creature):
			return true
	return _complete_creature_pick_up_equipment(creature, equipment)

func creature_use_steed(creature: Card, steed: Card) -> bool:
	if is_game_over:
		return false
	if creature == null or steed == null:
		return false
	if creature.card_type != Card.CardType.CREATURE:
		return false
	if not creature.can_take_minor_creature_action():
		return false
	if not can_pay_creature_action_mana_cost(creature, "mount"):
		return false
	if not steed.has_method("can_be_used_as_steed_by") or not steed.can_be_used_as_steed_by(creature, self):
		return false

	var steed_zone := steed.current_zone
	if steed_zone == null or not steed_zone.is_board_zone():
		return false

	if not pay_creature_action_mana_cost(creature, "mount"):
		return false
	steed_zone.remove_card(steed)
	creature.current_zone.add_card(steed)
	if not steed.has_method("mount_to_creature") or not steed.mount_to_creature(creature):
		creature.current_zone.remove_card(steed)
		steed_zone.add_card(steed)
		return false

	creature.spend_minor_creature_action()
	print(creature.card_name + " mounts " + steed.card_name)
	return true

# Creature destroys an unequipped equipment card.
# Own or in-range enemy equipment: interceptable only if enemy.
# Out-of-range enemy equipment: interceptable.
func creature_destroy_equipment(creature: Card, equipment: Card) -> bool:
	if is_game_over:
		return false
	if creature.card_type != Card.CardType.CREATURE:
		return false
	if not creature.can_take_major_creature_action():
		return false
	if not can_pay_creature_action_mana_cost(creature, "destroy equipment"):
		return false
	if equipment.card_type != Card.CardType.EQUIPMENT or equipment.equipped_on != null:
		return false
	var equip_zone := equipment.current_zone
	if equip_zone == null or not equip_zone.is_board_zone():
		return false
	var reachable := get_reachable_board_zones(creature)
	var controller := creature.get_controller()
	if controller == null:
		return false
	var is_enemy := equip_zone.zone_owner != controller
	var in_range := equip_zone in reachable
	if is_enemy and not in_range and creature.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		return false
	if not pay_creature_action_mana_cost(creature, "destroy equipment"):
		return false
	creature.spend_major_creature_action()
	print(creature.card_name + " destroys " + equipment.card_name)
	_send_to_graveyard_with_hook(equipment, false, true)
	return true

func get_equipment_action_failure_text(creature: Card, equipment: Card, action: String) -> String:
	if is_game_over:
		return "The game is already over."
	if creature == null or equipment == null:
		return "That equipment action is no longer valid."
	if creature.card_type != Card.CardType.CREATURE:
		return creature.card_name + " cannot use equipment."
	if equipment.card_type != Card.CardType.EQUIPMENT:
		return equipment.card_name + " is not equipment."

	match action:
		"pick_up", "steal":
			if not creature.can_receive_equipment():
				if creature.is_face_down or creature.is_stealth:
					return creature.card_name + " is hidden and cannot carry equipment."
				return creature.card_name + " cannot carry equipment right now."
			if equipment.equipped_on != null:
				return equipment.card_name + " is already equipped."
			var equip_zone := equipment.current_zone
			if equip_zone == null or not equip_zone.is_board_zone():
				return equipment.card_name + " is no longer on the field."
			if not equipment.can_equip_to(creature):
				if equipment.has_method("get_cannot_equip_reason"):
					var reason = str(equipment.get_cannot_equip_reason(creature)).strip_edges()
					if reason != "":
						return reason
				return equipment.card_name + " can't be equipped to " + creature.card_name + "."
			var reachable := get_reachable_board_zones(creature)
			var controller := creature.get_controller()
			if controller == null:
				return creature.card_name + " has no controller."
			var is_enemy := equip_zone.zone_owner != controller
			var in_range := equip_zone in reachable
			if is_enemy:
				if not creature.can_take_major_creature_action():
					return creature.card_name + " cannot spend a major action to steal equipment."
				if not in_range and creature.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
					return creature.card_name + " must be on the frontline to steal that equipment from range."
			elif not creature.can_take_minor_creature_action():
				return creature.card_name + " cannot spend a minor action to pick up equipment."
			return creature.card_name + " failed to " + ("steal " if action == "steal" else "pick up ") + equipment.card_name + "."
		"destroy":
			if not creature.can_take_major_creature_action():
				return creature.card_name + " cannot spend a major action to destroy equipment."
			if equipment.equipped_on != null:
				return equipment.card_name + " is already equipped."
			var equip_zone := equipment.current_zone
			if equip_zone == null or not equip_zone.is_board_zone():
				return equipment.card_name + " is no longer on the field."
			var reachable := get_reachable_board_zones(creature)
			var controller := creature.get_controller()
			if controller == null:
				return creature.card_name + " has no controller."
			var is_enemy := equip_zone.zone_owner != controller
			var in_range := equip_zone in reachable
			if is_enemy and not in_range and creature.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
				return creature.card_name + " must be on the frontline to destroy that equipment from range."
			return creature.card_name + " failed to destroy " + equipment.card_name + "."
	return creature.card_name + " failed to act on " + equipment.card_name + "."

func resolve_creature_equipment_action(actor: Card, target: Card, action: String) -> bool:
	if actor == null or target == null:
		return false
	if actor.has_method("resolve_equipment_action"):
		return actor.resolve_equipment_action(self, target, action)
	if target.has_method("can_be_used_as_steed_by"):
		return creature_use_steed(actor, target) if action == "pick_up" else false
	match action:
		"pick_up", "steal":
			return creature_pick_up_equipment(actor, target)
		"destroy":
			return creature_destroy_equipment(actor, target)
	return false

func _complete_creature_pick_up_equipment(creature: Card, equipment: Card) -> bool:
	if creature == null or equipment == null:
		return false
	if not creature.can_receive_equipment():
		return false
	if creature.current_zone == null or not creature.current_zone.is_board_zone():
		return false
	if equipment.card_type != Card.CardType.EQUIPMENT or equipment.equipped_on != null:
		return false
	var equip_zone := equipment.current_zone
	if equip_zone == null or not equip_zone.is_board_zone():
		return false
	if not equipment.can_equip_to(creature):
		return false
	equip_zone.remove_card(equipment)
	creature.current_zone.add_card(equipment)
	equipment.equip_to(creature)
	print(creature.card_name + " picks up " + equipment.card_name)
	return true

func creature_attack(attacker: Card, target) -> void:
	if is_game_over:
		return
	# This function is now mostly for AI use or direct attacks
	# Player attacks go through the UI intercept system
	if attacker.card_type != Card.CardType.CREATURE:
		return
	var attacker_controller := attacker.get_controller()
	if attacker_controller == null:
		return
	if attacker.summoned_after_first_attack_this_turn:
		print(attacker.card_name + " cannot attack because it was summoned after the first attack resolved this turn.")
		return
	if attack_restrictions.has(attacker_controller):
		print(attacker_controller.player_name + " cannot attack! Restricted for " + str(attack_restrictions[attacker_controller].turns) + " more turns")
		return
	var cannot_attack_status := attacker.get_status_effect("cannot_attack")
	if not cannot_attack_status.is_empty():
		var source_name := str(cannot_attack_status.get("source", "an effect"))
		print(attacker.card_name + " cannot attack because of " + source_name + ".")
		return
	
	if not attacker.can_take_major_creature_action():
		print("Creature has already acted this turn")
		return
	
	if attacker.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		print("Only frontline creatures can attack")
		return

	if attacker.creature_mode == Card.CreatureMode.DEFENSIVE:
		print(attacker.card_name + " is in defensive stance and cannot attack")
		return
	if not can_pay_creature_action_mana_cost(attacker, "attack"):
		print(attacker.card_name + " cannot attack because its controller cannot pay the action tax.")
		return
	if not pay_creature_action_mana_cost(attacker, "attack"):
		return

	if attacker.is_stealth:
		attacker.reveal_from_stealth(self)
	var united_front_partner: Card = null
	if attacker.has_method("get_united_front_partner_for_attack"):
		united_front_partner = attacker.get_united_front_partner_for_attack(self)
	
	attacker.spend_attack_creature_action()
	attacker.mark_attacked_this_turn()
	if united_front_partner != null:
		united_front_partner.reveal_from_stealth(self)
		united_front_partner.spend_attack_creature_action()
		united_front_partner.mark_attacked_this_turn()
	
	var attack_resolved := false
	if target is Card:
		if united_front_partner != null:
			resolve_united_front_combat(attacker, united_front_partner, target)
		else:
			resolve_combat(attacker, target)
		attack_resolved = true
	elif target is Player:
		resolve_followers_attack(_get_active_united_front_attackers(attacker, united_front_partner), target)
		attack_resolved = true
	if attack_resolved:
		note_attack_resolved()

func note_attack_resolved() -> void:
	# Finalized attacks count even when their combat or target fizzles.
	has_resolved_attack_this_turn = true

func resolve_followers_attack(attackers: Array[Card], defending_player: Player) -> int:
	if defending_player == null:
		return 0
	var active_attackers: Array[Card] = []
	for combatant in attackers:
		if _can_continue_declared_attack(combatant):
			active_attackers.append(combatant)
	if active_attackers.is_empty():
		return 0
	if is_followers_attack_blocked_by_active_structure(active_attackers[0], defending_player, active_attackers.slice(1)):
		return 0

	for combatant in active_attackers:
		combatant.reveal_from_stealth(self)
	for combatant in active_attackers:
		_notify_attack_declared(combatant)

	var follower_damage := 0
	for combatant in active_attackers:
		if _source_converts_combat_follower_damage(combatant):
			follower_damage += _apply_combat_follower_damage(combatant, defending_player, combatant.get_effective_strength())
		else:
			follower_damage += _apply_combat_follower_damage(null, defending_player, combatant.get_effective_strength())
		if is_game_over:
			break

	if is_game_over:
		return follower_damage
	if active_attackers.size() >= 2:
		_notify_after_united_front_combat(active_attackers[0], active_attackers[1], null)
	else:
		_notify_after_combat(active_attackers[0], null)

	for combatant in active_attackers:
		_notify_opponent_attacks_followers(combatant, defending_player)

	return follower_damage

func _notify_attack_declared(attacker: Card, target: Card = null) -> void:
	if attacker == null:
		return
	if attacker.has_method("on_attack") and not attacker.abilities_suppressed():
		attacker.on_attack(self, target)

func _notify_opponent_attacks_followers(attacker: Card, defending_player: Player) -> void:
	if attacker == null or defending_player == null:
		return
	for zone in defending_player.frontline_zones + defending_player.reserve_zones:
		for card in zone.cards:
			if card != null and card.has_method("on_opponent_attacks_followers") \
					and not card.abilities_suppressed():
				card.on_opponent_attacks_followers(self, attacker)

func _can_intercept_followers(defender: Card, attacker: Card) -> bool:
	if defender == null or attacker == null:
		return false
	if defender.card_type != Card.CardType.CREATURE:
		return false
	if defender.is_sleeping:
		return false
	if not defender.get_status_effect("cannot_intercept").is_empty():
		return false
	if defender.can_special_intercept(self, attacker, defender.get_controller()):
		return _can_interceptor_engage_attacker(defender, attacker)
	var interceptor_speed := get_interceptor_speed_against_attacker(defender, attacker)
	if interceptor_speed < attacker.get_effective_speed():
		return false
	if not _can_interceptor_engage_attacker(defender, attacker):
		return false
	if defender.current_zone == null:
		return false
	var row_distance := -1
	match defender.current_zone.zone_type:
		Zone.ZoneType.FRONTLINE:
			row_distance = 2
		Zone.ZoneType.RESERVE:
			row_distance = 1
		_:
			return false
	var minimum_distance := 1
	if defender.creature_mode == Card.CreatureMode.AGGRESSIVE:
		minimum_distance = 2
	minimum_distance = max(0, minimum_distance - defender.get_intercept_reach_bonus(self, attacker, defender.get_controller()))
	return row_distance >= minimum_distance

func _can_interceptor_engage_attacker(interceptor: Card, attacker: Card) -> bool:
	if interceptor == null or attacker == null:
		return false
	if interceptor.has_method("can_engage") and not interceptor.can_engage(attacker):
		return false
	if attacker.has_method("can_be_engaged_by") and not attacker.can_be_engaged_by(interceptor):
		return false
	return true

func get_interceptor_speed_against_attacker(
	interceptor: Card,
	attacker: Card,
	protected_target = null
) -> int:
	if interceptor == null:
		return 0
	var interceptor_speed := interceptor.get_effective_speed()
	interceptor_speed += interceptor.get_intercept_speed_bonus_against_attacker(self, attacker, protected_target)
	if attacker != null \
			and interceptor.has_type("Giant") \
			and not attacker.has_type("Giant") \
			and _has_giants_disdain(interceptor.get_controller()):
		interceptor_speed += 1
	return interceptor_speed

func check_for_intercept(attacker: Card, defending_player: Player) -> Card:
	print("	Checking for intercepts...")
	for zone in defending_player.frontline_zones + defending_player.reserve_zones:
		for card in zone.cards:
			if _can_intercept_followers(card, attacker):
				print("	-> " + card.card_name + " intercepts!")
				return card
	print("	-> No intercepts, attacking followers directly")
	return null

func resolve_combat(attacker: Card, defender: Card, continue_callback: Callable = Callable()) -> bool:
	if attacker == null or defender == null:
		return false
	var ignore_targeting_limits := attacker.can_ignore_attack_targeting_restrictions(defender)
	if is_attack_blocked_by_active_structure(attacker, defender):
		print(attacker.card_name + " cannot engage " + defender.card_name + ".")
		if continue_callback.is_valid():
			continue_callback.call()
		return false
	if not ignore_targeting_limits and attacker.has_method("can_engage") and not attacker.can_engage(defender):
		print(attacker.card_name + " cannot engage " + defender.card_name + ".")
		if continue_callback.is_valid():
			continue_callback.call()
		return false
	if not ignore_targeting_limits and defender.has_method("can_be_engaged_by") and not defender.can_be_engaged_by(attacker):
		print(defender.card_name + " cannot be engaged by " + attacker.card_name + ".")
		if continue_callback.is_valid():
			continue_callback.call()
		return false
	_begin_declared_combat(attacker, defender)
	var attacker_controller := attacker.get_controller()
	var defender_controller := defender.get_controller()
	var finish := func() -> void:
		_notify_after_combat(attacker, defender)
		_clear_combat_engagement_state(defender)
		if continue_callback.is_valid():
			continue_callback.call()
	attacker.reveal_from_stealth(self)
	defender.reveal_from_stealth(self)
	_notify_attack_declared(attacker, defender)
	if defender.is_god:
		# Gods cannot be targeted in combat — redirect to follower damage
		var god_damage := _apply_combat_follower_damage(attacker, defender_controller, attacker.get_effective_strength())
		print(attacker.card_name + " attacks " + defender_controller.player_name + "'s followers for " + str(god_damage) + " (via god)!")
		finish.call()
		return true
	if defender.has_method("on_defend") and not defender.abilities_suppressed():
		defender.on_defend(self, attacker)
	var attacker_str = attacker.get_effective_strength()

	print("=== COMBAT: " + attacker.card_name + " (STR:" + str(attacker_str) + ") vs " + defender.card_name + " ===")
	
	if defender.is_petrified() or defender.card_type == Card.CardType.STRUCTURE:
		var defender_res := defender.get_effective_resilience()
		print("	STR vs Structure RES: " + str(attacker_str) + " vs " + str(defender_res))
		if attacker_str > defender_res:
			print("	Structure destroyed!")
			_combat_kill(attacker, defender)
		finish.call()
		return true

	if defender.card_type == Card.CardType.CREATURE:
		if defender.creature_mode == Card.CreatureMode.AGGRESSIVE:
			# Strength vs Strength — real stats determine who wins; disdain halves for damage only
			var defender_str_real: int = defender.get_effective_strength()
			var defender_str_for_damage: int = _get_giants_disdain_damage_stat(defender, [attacker], defender_str_real)
			var attacker_str_for_damage: int = _get_giants_disdain_damage_stat(attacker, [defender], attacker_str)
			print("	STR vs STR: " + str(attacker_str) + " vs " + str(defender_str_real) + ((" (disdain→damage as %d)" % defender_str_for_damage) if defender_str_for_damage != defender_str_real else ""))

			if attacker_str > defender_str_real:
				var diff = _apply_combat_follower_damage(attacker, defender_controller, attacker_str - defender_str_for_damage)
				print("	" + defender.card_name + " destroyed! " + defender_controller.player_name + " loses " + str(diff) + " followers")
				_combat_kill(attacker, defender)
			elif defender_str_real > attacker_str:
				var diff = _apply_combat_follower_damage(defender, attacker_controller, defender_str_real - attacker_str_for_damage)
				print("	" + attacker.card_name + " destroyed! " + attacker_controller.player_name + " loses " + str(diff) + " followers")
				_combat_kill(defender, attacker)
			else:	# Tie — pre-compute routing before either card moves zones
				print("	Tie! Both creatures destroyed")
				var void_attacker := _should_class_rend(defender, attacker)
				var void_defender := _should_class_rend(attacker, defender)
				var simultaneous_casualties: Array[Card] = [attacker, defender]
				_combat_kill_routed(defender, attacker, void_attacker, simultaneous_casualties)
				_combat_kill_routed(attacker, defender, void_defender, simultaneous_casualties)
		else:	# Defensive stance - real RES determines kill; Giant's Disdain only reduces the opposing attack stat.
			var vs_defense_bonus := 0
			for equip in attacker.equipment:
				if equip is EquipmentCard:
					vs_defense_bonus += equip.get_bonus_strength_vs_defense(attacker)
			var attacker_str_vs_res: int = attacker_str + vs_defense_bonus
			var attacker_str_for_conversion: int = _get_giants_disdain_damage_stat(attacker, [defender], attacker_str) + vs_defense_bonus
			var defender_res_real: int = defender.get_effective_resilience()
			print("\tSTR vs RES: " + str(attacker_str_vs_res) + " vs " + str(defender_res_real))

			if attacker_str_vs_res > defender_res_real:
				print("	" + defender.card_name + " destroyed!")
				_combat_kill(attacker, defender)
			elif attacker_str_vs_res < defender_res_real:
				# Followers convert using the defender's full resilience, with Giant's Disdain reducing only the opposing attack stat.
				var diff_damage: int = _convert_combat_follower_damage(
					attacker_controller,
					defender_controller,
					maxi(0, defender_res_real - attacker_str_for_conversion)
				)
				var diff_gain: int = defender_res_real - attacker_str_vs_res
				print("	" + str(diff_damage) + " followers convert to " + defender_controller.player_name)
				if diff_gain != diff_damage:
					print("\t(disdain adjusted conversion from %d to %d)" % [diff_gain, diff_damage])
				if _ferocious_defence_triggers(defender, attacker_str_vs_res):
					print("	Ferocious Defence! " + attacker.card_name + " destroyed!")
					_combat_kill(defender, attacker)
			else:
				if _ferocious_defence_triggers(defender, attacker_str_vs_res):
					print("	Exact match - no follower conversion")
					print("	Ferocious Defence! " + attacker.card_name + " destroyed!")
					_combat_kill(defender, attacker)
				else:
					print("	Exact match - no effect")
	elif defender.card_type == Card.CardType.EQUIPMENT and defender.equipped_on == null:
		print("	Equipment destroyed!")
		_combat_kill(attacker, defender)
	finish.call()
	return true

func resolve_united_front_combat(attacker: Card, partner: Card, defender: Card) -> void:
	var active_attackers: Array[Card] = _get_active_united_front_attackers(attacker, partner)
	if active_attackers.is_empty():
		return
	if active_attackers.size() == 1:
		resolve_combat(active_attackers[0], defender)
		return
	var primary: Card = active_attackers[0]
	var support: Card = active_attackers[1]
	if is_attack_blocked_by_active_structure(primary, defender, [support]):
		print(primary.card_name + " and " + support.card_name + " cannot engage " + defender.card_name + ".")
		return
	_begin_declared_combat(primary, defender)
	_begin_declared_combat(support, defender)
	var attacker_controller := primary.get_controller()
	var defender_controller := defender.get_controller()
	var finish := func() -> void:
		_notify_after_united_front_combat(attacker, partner, defender)
		_clear_combat_engagement_state(defender)
	for combatant in active_attackers:
		combatant.reveal_from_stealth(self)
	defender.reveal_from_stealth(self)
	for combatant in active_attackers:
		_notify_attack_declared(combatant, defender)
	if defender.has_method("on_defend") and not defender.abilities_suppressed():
		defender.on_defend(self, primary)
	var combined_strength := primary.get_effective_strength() + support.get_effective_strength()

	if defender.is_god:
		var converting_attacker: Card = null
		for combatant in active_attackers:
			if _source_converts_combat_follower_damage(combatant):
				converting_attacker = combatant
				break
		var god_damage := _apply_combat_follower_damage(converting_attacker, defender_controller, combined_strength)
		print("%s and %s attack %s's followers for %d!" % [primary.card_name, support.card_name, defender_controller.player_name, god_damage])
		finish.call()
		return

	print("=== UNITED FRONT COMBAT: %s + %s (STR:%d) vs %s ===" % [primary.card_name, support.card_name, combined_strength, defender.card_name])

	if defender.is_petrified() or defender.card_type == Card.CardType.STRUCTURE:
		var defender_res := defender.get_effective_resilience()
		print("	STR vs Structure RES: %d vs %d" % [combined_strength, defender_res])
		if combined_strength > defender_res:
			print("	Structure destroyed!")
			_combat_kill(primary, defender)
		finish.call()
		return

	if defender.card_type == Card.CardType.CREATURE:
		if defender.creature_mode == Card.CreatureMode.AGGRESSIVE:
			var defender_str_real: int = defender.get_effective_strength()
			var defender_str_for_damage: int = _get_giants_disdain_damage_stat(defender, active_attackers, defender_str_real)
			var combined_strength_for_damage: int = _get_giants_disdain_combined_strength_for_damage(active_attackers, defender)
			print("	Combined STR vs STR: %d vs %d" % [combined_strength, defender_str_real])
			if combined_strength > defender_str_real:
				var converting_attacker: Card = null
				for combatant in active_attackers:
					if _source_converts_combat_follower_damage(combatant):
						converting_attacker = combatant
						break
				var diff := _apply_combat_follower_damage(converting_attacker, defender_controller, combined_strength - defender_str_for_damage)
				print("	%s destroyed! %s loses %d followers" % [defender.card_name, defender_controller.player_name, diff])
				_combat_kill(primary, defender)
			elif defender_str_real > combined_strength:
				var diff := _apply_combat_follower_damage(defender, attacker_controller, defender_str_real - combined_strength_for_damage)
				print("	United Front loses! %s loses %d followers" % [attacker_controller.player_name, diff])
				note_player_feedback("United Front loses! Both attackers are destroyed.")
				_combat_kill(defender, primary)
				_combat_kill(defender, support)
			else:
				print("	Tie! Both united attackers and the defender are destroyed")
				var void_primary := _should_class_rend(defender, primary)
				var void_support := _should_class_rend(defender, support)
				var void_defender := _should_class_rend(primary, defender)
				var simultaneous_casualties: Array[Card] = [primary, support, defender]
				_combat_kill_routed(defender, primary, void_primary, simultaneous_casualties)
				_combat_kill_routed(defender, support, void_support, simultaneous_casualties)
				_combat_kill_routed(primary, defender, void_defender, simultaneous_casualties)
		else:
			var vs_defense_bonus := 0
			for combatant in active_attackers:
				for equip in combatant.equipment:
					if equip is EquipmentCard:
						vs_defense_bonus += equip.get_bonus_strength_vs_defense(combatant)
			var attacker_str_vs_res: int = combined_strength + vs_defense_bonus
			var attacker_str_for_conversion: int = _get_giants_disdain_combined_strength_for_damage(active_attackers, defender) + vs_defense_bonus
			var defender_res_real: int = defender.get_effective_resilience()
			print("\tCombined STR vs RES: %d vs %d" % [attacker_str_vs_res, defender_res_real])
			if attacker_str_vs_res > defender_res_real:
				print("	%s destroyed!" % defender.card_name)
				_combat_kill(primary, defender)
			elif attacker_str_vs_res < defender_res_real:
				var diff_damage: int = _convert_combat_follower_damage(
					attacker_controller,
					defender_controller,
					maxi(0, defender_res_real - attacker_str_for_conversion)
				)
				print("	%d followers convert to %s" % [diff_damage, defender_controller.player_name])
				if _ferocious_defence_triggers(defender, attacker_str_vs_res):
					print("	Ferocious Defence! United Front attackers destroyed!")
					_combat_kill(defender, primary)
					_combat_kill(defender, support)
			else:
				if _ferocious_defence_triggers(defender, attacker_str_vs_res):
					print("	Exact match - no follower conversion")
					print("	Ferocious Defence! United Front attackers destroyed!")
					_combat_kill(defender, primary)
					_combat_kill(defender, support)
				else:
					print("	Exact match - no effect")
	elif defender.card_type == Card.CardType.EQUIPMENT and defender.equipped_on == null:
		print("	Equipment destroyed!")
		_combat_kill(primary, defender)
	finish.call()

func resolve_combat_with_continuation(
	attacker: Card,
	defender: Card,
	continue_callback: Callable = Callable(),
	interceptor_initiates: bool = false
) -> bool:
	if attacker == null or defender == null:
		return false
	if has_committed_combat_snapshot(attacker, defender):
		return _resolve_committed_combat_snapshot(attacker, defender, continue_callback)
	if interceptor_initiates:
		if defender.has_method("can_engage") and not defender.can_engage(attacker):
			print(defender.card_name + " cannot intercept " + attacker.card_name + ".")
			if continue_callback.is_valid():
				continue_callback.call()
			return false
		if attacker.has_method("can_be_engaged_by") and not attacker.can_be_engaged_by(defender):
			print(attacker.card_name + " cannot be intercepted by " + defender.card_name + ".")
			if continue_callback.is_valid():
				continue_callback.call()
			return false
	else:
		var ignore_targeting_limits := attacker.can_ignore_attack_targeting_restrictions(defender)
		if is_attack_blocked_by_active_structure(attacker, defender):
			print(attacker.card_name + " cannot engage " + defender.card_name + ".")
			if continue_callback.is_valid():
				continue_callback.call()
			return false
		if not ignore_targeting_limits and attacker.has_method("can_engage") and not attacker.can_engage(defender):
			print(attacker.card_name + " cannot engage " + defender.card_name + ".")
			if continue_callback.is_valid():
				continue_callback.call()
			return false
		if not ignore_targeting_limits and defender.has_method("can_be_engaged_by") and not defender.can_be_engaged_by(attacker):
			print(defender.card_name + " cannot be engaged by " + attacker.card_name + ".")
			if continue_callback.is_valid():
				continue_callback.call()
			return false
	_begin_declared_combat(attacker, defender)
	var attacker_controller := attacker.get_controller()
	var defender_controller := defender.get_controller()
	var finish := func() -> void:
		_notify_after_combat(attacker, defender)
		_clear_combat_engagement_state(defender)
		if continue_callback.is_valid():
			continue_callback.call()
	attacker.reveal_from_stealth(self)
	defender.reveal_from_stealth(self)
	_notify_attack_declared(attacker, defender)
	if defender.is_god:
		var god_damage := _apply_combat_follower_damage(attacker, defender_controller, attacker.get_effective_strength())
		print(attacker.card_name + " attacks " + defender_controller.player_name + "'s followers for " + str(god_damage) + " (via god)!")
		_notify_opponent_attacks_followers(attacker, defender_controller)
		finish.call()
		return true
	var continue_resolution := func() -> bool:
		if defender.has_method("on_defend") and not defender.abilities_suppressed():
			defender.on_defend(self, attacker)
		var attacker_str := attacker.get_effective_strength()
		print("=== COMBAT: " + attacker.card_name + " (STR:" + str(attacker_str) + ") vs " + defender.card_name + " ===")
		if defender.is_petrified() or defender.card_type == Card.CardType.STRUCTURE:
			var defender_res := defender.get_effective_resilience()
			print("	STR vs Structure RES: " + str(attacker_str) + " vs " + str(defender_res))
			if attacker_str > defender_res:
				print("	Structure destroyed!")
				return _combat_kill_deferred(attacker, defender, finish)
			finish.call()
			return true
		if defender.card_type == Card.CardType.CREATURE:
			if defender.creature_mode == Card.CreatureMode.AGGRESSIVE:
				var defender_str_real: int = defender.get_effective_strength()
				var defender_str_for_damage: int = _get_giants_disdain_damage_stat(defender, [attacker], defender_str_real)
				var attacker_str_for_damage: int = _get_giants_disdain_damage_stat(attacker, [defender], attacker_str)
				print("	STR vs STR: " + str(attacker_str) + " vs " + str(defender_str_real))
				if attacker_str > defender_str_real:
					var diff := _apply_combat_follower_damage(attacker, defender_controller, attacker_str - defender_str_for_damage)
					print("	" + defender.card_name + " destroyed! " + defender_controller.player_name + " loses " + str(diff) + " followers")
					return _combat_kill_deferred(attacker, defender, finish)
				if defender_str_real > attacker_str:
					var diff := _apply_combat_follower_damage(defender, attacker_controller, defender_str_real - attacker_str_for_damage)
					print("	" + attacker.card_name + " destroyed! " + attacker_controller.player_name + " loses " + str(diff) + " followers")
					return _combat_kill_deferred(defender, attacker, finish)
				print("	Tie! Both creatures destroyed")
				var simultaneous_casualties: Array[Card] = [attacker, defender]
				return _combat_kill_sequence_deferred([
					{"killer": defender, "victim": attacker, "do_void": _should_class_rend(defender, attacker), "suppress_ally_kill_sources": simultaneous_casualties},
					{"killer": attacker, "victim": defender, "do_void": _should_class_rend(attacker, defender), "suppress_ally_kill_sources": simultaneous_casualties},
				], finish)
			var vs_defense_bonus := 0
			for equip in attacker.equipment:
				if equip is EquipmentCard:
					vs_defense_bonus += equip.get_bonus_strength_vs_defense(attacker)
			var attacker_str_vs_res: int = attacker_str + vs_defense_bonus
			var attacker_str_for_conversion: int = _get_giants_disdain_damage_stat(attacker, [defender], attacker_str) + vs_defense_bonus
			var defender_res_real: int = defender.get_effective_resilience()
			print("\tSTR vs RES: " + str(attacker_str_vs_res) + " vs " + str(defender_res_real))
			if attacker_str_vs_res > defender_res_real:
				print("	" + defender.card_name + " destroyed!")
				return _combat_kill_deferred(attacker, defender, finish)
			if attacker_str_vs_res < defender_res_real:
				var diff_damage: int = _convert_combat_follower_damage(
					attacker_controller,
					defender_controller,
					maxi(0, defender_res_real - attacker_str_for_conversion)
				)
				print("	" + str(diff_damage) + " followers convert to " + defender_controller.player_name)
				if _ferocious_defence_triggers(defender, attacker_str_vs_res):
					print("	Ferocious Defence! " + attacker.card_name + " destroyed!")
					return _combat_kill_deferred(defender, attacker, finish)
			elif _ferocious_defence_triggers(defender, attacker_str_vs_res):
				print("	Exact match - no follower conversion")
				print("	Ferocious Defence! " + attacker.card_name + " destroyed!")
				return _combat_kill_deferred(defender, attacker, finish)
		elif defender.card_type == Card.CardType.EQUIPMENT and defender.equipped_on == null:
			print("	Equipment destroyed!")
			return _combat_kill_deferred(attacker, defender, finish)
		finish.call()
		return true
	_combat_resolution_deferred = false
	_deferred_combat_resume = Callable()
	return continue_resolution.call()

func capture_committed_combat_snapshot(attacker: Card, defender: Card) -> void:
	if attacker == null or defender == null:
		return
	var snapshot_key := _get_committed_combat_snapshot_key(attacker, defender)
	if _committed_combat_snapshots.has(snapshot_key):
		return
	_begin_declared_combat(attacker, defender)
	_notify_attack_declared(attacker, defender)
	if defender.has_method("on_defend") and not defender.abilities_suppressed():
		defender.on_defend(self, attacker)
	var attacker_str: int = attacker.get_effective_strength()
	var defender_str: int = defender.get_effective_strength()
	var defender_res: int = defender.get_effective_resilience()
	var vs_defense_bonus := 0
	for equip in attacker.equipment:
		if equip is EquipmentCard:
			vs_defense_bonus += equip.get_bonus_strength_vs_defense(attacker)
	_committed_combat_snapshots[snapshot_key] = {
		"attacker": attacker,
		"defender": defender,
		"attacker_controller": attacker.get_controller(),
		"defender_controller": defender.get_controller(),
		"attacker_str": attacker_str,
		"attacker_str_for_damage": _get_giants_disdain_damage_stat(attacker, [defender], attacker_str),
		"attacker_str_vs_res": attacker_str + vs_defense_bonus,
		"attacker_str_for_conversion": _get_giants_disdain_damage_stat(attacker, [defender], attacker_str) + vs_defense_bonus,
		"defender_str": defender_str,
		"defender_str_for_damage": _get_giants_disdain_damage_stat(defender, [attacker], defender_str),
		"defender_res": defender_res,
		"defender_mode": defender.creature_mode,
		"defender_type": defender.card_type,
		"defender_is_god": defender.is_god,
		"defender_is_petrified": defender.is_petrified(),
		"ferocious_defence": _ferocious_defence_triggers(defender, attacker_str + vs_defense_bonus),
	}

func has_committed_combat_snapshot(attacker: Card, defender: Card) -> bool:
	if attacker == null or defender == null:
		return false
	return _committed_combat_snapshots.has(_get_committed_combat_snapshot_key(attacker, defender))

func _get_committed_combat_snapshot_key(attacker: Card, defender: Card) -> String:
	return "%d:%d" % [attacker.get_instance_id(), defender.get_instance_id()]

func _resolve_committed_combat_snapshot(
	attacker: Card,
	defender: Card,
	continue_callback: Callable = Callable()
) -> bool:
	var snapshot_key := _get_committed_combat_snapshot_key(attacker, defender)
	var snapshot: Dictionary = _committed_combat_snapshots.get(snapshot_key, {})
	_committed_combat_snapshots.erase(snapshot_key)
	if snapshot.is_empty():
		return false
	var attacker_controller: Player = snapshot.get("attacker_controller", null)
	var defender_controller: Player = snapshot.get("defender_controller", null)
	var finish := func() -> void:
		_notify_after_combat(attacker, defender)
		_clear_combat_engagement_state(defender)
		if continue_callback.is_valid():
			continue_callback.call()
	var kill_if_present := func(killer: Card, victim: Card, next: Callable) -> void:
		if victim == null or victim.current_zone == null or not victim.current_zone.is_board_zone():
			next.call()
			return
		_combat_kill_deferred(killer, victim, next)
	var attacker_str := int(snapshot.get("attacker_str", 0))
	if bool(snapshot.get("defender_is_god", false)):
		_apply_combat_follower_damage(attacker, defender_controller, attacker_str)
		_notify_opponent_attacks_followers(attacker, defender_controller)
		finish.call()
		return true
	var defender_type := int(snapshot.get("defender_type", Card.CardType.CREATURE))
	if bool(snapshot.get("defender_is_petrified", false)) or defender_type == Card.CardType.STRUCTURE:
		if attacker_str > int(snapshot.get("defender_res", 0)):
			kill_if_present.call(attacker, defender, finish)
		else:
			finish.call()
		return true
	if defender_type == Card.CardType.CREATURE:
		if int(snapshot.get("defender_mode", Card.CreatureMode.AGGRESSIVE)) == Card.CreatureMode.AGGRESSIVE:
			var defender_str := int(snapshot.get("defender_str", 0))
			if attacker_str > defender_str:
				_apply_combat_follower_damage(
					attacker,
					defender_controller,
					attacker_str - int(snapshot.get("defender_str_for_damage", defender_str))
				)
				kill_if_present.call(attacker, defender, finish)
				return true
			if defender_str > attacker_str:
				_apply_combat_follower_damage(
					defender,
					attacker_controller,
					defender_str - int(snapshot.get("attacker_str_for_damage", attacker_str))
				)
				kill_if_present.call(defender, attacker, finish)
				return true
			var kills: Array[Dictionary] = []
			if attacker.current_zone != null and attacker.current_zone.is_board_zone():
				kills.append({"killer": defender, "victim": attacker})
			if defender.current_zone != null and defender.current_zone.is_board_zone():
				kills.append({"killer": attacker, "victim": defender})
			_combat_kill_sequence_deferred(kills, finish)
			return true
		var attacker_str_vs_res := int(snapshot.get("attacker_str_vs_res", attacker_str))
		var defender_res := int(snapshot.get("defender_res", 0))
		if attacker_str_vs_res > defender_res:
			kill_if_present.call(attacker, defender, finish)
			return true
		if attacker_str_vs_res < defender_res:
			_convert_combat_follower_damage(
				attacker_controller,
				defender_controller,
				maxi(0, defender_res - int(snapshot.get("attacker_str_for_conversion", attacker_str_vs_res)))
			)
		if bool(snapshot.get("ferocious_defence", false)):
			kill_if_present.call(defender, attacker, finish)
		else:
			finish.call()
		return true
	if defender_type == Card.CardType.EQUIPMENT and defender.equipped_on == null:
		kill_if_present.call(attacker, defender, finish)
		return true
	finish.call()
	return true

func _combat_kill_deferred(killer: Card, victim: Card, continue_callback: Callable = Callable()) -> bool:
	return _combat_kill_routed_deferred(killer, victim, _should_class_rend(killer, victim), continue_callback)

func _combat_kill_routed_deferred(
	killer: Card,
	victim: Card,
	do_void: bool,
	continue_callback: Callable = Callable(),
	suppress_ally_kill_sources: Array = []
) -> bool:
	var killer_controller := killer.get_controller() if killer != null else null
	var victim_controller := victim.get_controller()
	var bypass_combat_survival := killer != null and killer.can_destroy_combat_protected_creatures(victim)
	var finish := func() -> void:
		var victim_counts_as_creature_kill := victim != null and victim.card_type == Card.CardType.CREATURE and not victim.is_petrified()
		var victim_counts_as_attack_target_destroy := victim != null \
			and killer_controller != null \
			and victim_controller != null \
			and victim_controller != killer_controller
		if killer != null and killer.has_method("on_kill") and not killer.abilities_suppressed() and victim_counts_as_creature_kill:
			killer.on_kill(self, victim)
		if killer != null and killer.has_method("on_attack_target_destroyed") and not killer.abilities_suppressed() and victim_counts_as_attack_target_destroy:
			killer.on_attack_target_destroyed(self, victim)
		if victim_counts_as_attack_target_destroy:
			combat_destroy_events_this_turn.append({
				"killer_owner": killer_controller,
				"victim_owner": victim_controller,
				"killer": killer,
				"victim": victim,
			})
			_notify_player_god_visual_state_changed(killer_controller)
		if killer != null and killer_controller != null and victim_controller != killer_controller and victim_counts_as_creature_kill:
			for zone in killer_controller.frontline_zones + killer_controller.reserve_zones:
				for card in zone.cards:
					if card in suppress_ally_kill_sources:
						continue
					if card.has_method("on_ally_kill") and not card.abilities_suppressed():
						card.on_ally_kill(self, killer, victim)
		if continue_callback.is_valid():
			continue_callback.call()
	if do_void:
		print("Class Rend! " + killer.card_name + " voids " + victim.card_name + "!")
		if victim.current_zone and victim.current_zone.is_board_zone():
			victim.last_board_zone_type  = victim.current_zone.zone_type
			victim.last_board_zone_index = victim.current_zone.zone_index
		victim.process_board_leave_hooks(self)
		if victim.has_method("on_death") and not victim.post_field_abilities_suppressed():
			victim.on_death(self)
		died_this_turn.append(victim)
		destroyed_this_turn.append(victim)
		for equip in victim.equipment.duplicate():
			_send_to_abyss_with_hook(equip)
		victim.card_owner.move_card(victim, victim.card_owner.abyss_zone)
		finish.call()
		return true
	return request_send_to_graveyard(victim, finish, true, true, bypass_combat_survival)

func _combat_kill_sequence_deferred(kills: Array[Dictionary], continue_callback: Callable = Callable()) -> bool:
	if kills.is_empty():
		if continue_callback.is_valid():
			continue_callback.call()
		return true
	var next_kills: Array[Dictionary] = kills.duplicate()
	var kill: Dictionary = next_kills.pop_front()
	var continue_sequence := func() -> void:
		_combat_kill_sequence_deferred(next_kills, continue_callback)
	return _combat_kill_routed_deferred(
		kill.get("killer", null),
		kill.get("victim", null),
		kill.get("do_void", false) == true,
		continue_sequence,
		kill.get("suppress_ally_kill_sources", [])
	)

func _notify_after_combat(attacker: Card, defender: Card) -> void:
	if attacker != null and attacker.has_method("on_after_combat"):
		attacker.on_after_combat(self, defender)
	if defender != null and defender.has_method("on_after_combat"):
		defender.on_after_combat(self, attacker)
	_notify_friendly_creature_after_combat(attacker, defender)
	_notify_friendly_creature_after_combat(defender, attacker)
	for player in players:
		for zone in player.power_zones:
			for card in zone.cards:
				if card.has_method("on_creature_after_combat"):
					card.on_creature_after_combat(self, attacker, defender)
	_expire_after_combat_effects(attacker)
	_expire_after_combat_effects(defender)

func _begin_declared_combat(attacker: Card, defender: Card) -> void:
	if attacker == null or defender == null:
		return
	if not defender.has_meta("combat_declared_attackers"):
		_mark_combat_engagement_state(defender)
	var declared_attackers: Array = defender.get_meta("combat_declared_attackers", [])
	var attacker_key := _get_combat_declaration_key(attacker)
	if attacker_key in declared_attackers:
		return
	declared_attackers = declared_attackers.duplicate()
	declared_attackers.append(attacker_key)
	defender.set_meta("combat_declared_attackers", declared_attackers)
	_notify_creature_enters_combat(attacker, defender)

func _notify_creature_enters_combat(attacker: Card, defender: Card) -> void:
	for power in _get_active_powers():
		if power != null and power.has_method("on_creature_enters_combat"):
			power.on_creature_enters_combat(self, attacker, defender)
	for player in players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card != null and card.has_method("on_creature_enters_combat") and not card.abilities_suppressed():
					card.on_creature_enters_combat(self, attacker, defender)

func _notify_after_united_front_combat(attacker: Card, partner: Card, defender: Card) -> void:
	_notify_after_combat(attacker, defender)
	if partner != null and partner != attacker and partner.has_method("on_after_combat"):
		partner.on_after_combat(self, defender)
	_notify_friendly_creature_after_combat(partner, defender)
	_expire_after_combat_effects(partner)

func _notify_friendly_creature_after_combat(friendly_creature: Card, opposing_card: Card) -> void:
	if friendly_creature == null or opposing_card == null:
		return
	if friendly_creature.card_type != Card.CardType.CREATURE:
		return
	var controller := friendly_creature.get_controller()
	if controller == null:
		return
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if card != null and card.has_method("on_friendly_creature_after_combat") and not card.abilities_suppressed():
				card.on_friendly_creature_after_combat(self, friendly_creature, opposing_card)

func defer_combat_resolution() -> void:
	_combat_resolution_deferred = true

func has_deferred_combat_resolution() -> bool:
	return _deferred_combat_resume.is_valid()

func resume_deferred_combat() -> void:
	if not _deferred_combat_resume.is_valid():
		_combat_resolution_deferred = false
		return
	var resume_callback := _deferred_combat_resume
	_deferred_combat_resume = Callable()
	_combat_resolution_deferred = false
	resume_callback.call()

func _expire_after_combat_effects(card: Card) -> void:
	if card == null:
		return
	card.remove_effects_expiring_after_combat()

func _get_combat_declaration_key(card: Card) -> String:
	if card == null:
		return ""
	if str(card.uid) != "":
		return str(card.uid)
	return str(card.get_instance_id())

func _mark_combat_engagement_state(defender: Card) -> void:
	if defender == null:
		return
	defender.set_meta("combat_was_stealth_when_engaged", defender.is_stealth)
	defender.set_meta("combat_was_sleeping_when_engaged", defender.is_sleeping)

func _clear_combat_engagement_state(defender: Card) -> void:
	if defender == null:
		return
	defender.remove_meta("combat_was_stealth_when_engaged")
	defender.remove_meta("combat_was_sleeping_when_engaged")
	defender.remove_meta("combat_declared_attackers")

func _get_active_united_front_attackers(attacker: Card, partner: Card) -> Array[Card]:
	var active_attackers: Array[Card] = []
	var controller := attacker.get_controller() if attacker != null else null
	for candidate in [attacker, partner]:
		if candidate == null:
			continue
		if not _can_continue_declared_attack(candidate):
			continue
		if controller != null and candidate.get_controller() != controller:
			continue
		if candidate.card_type != Card.CardType.CREATURE:
			continue
		active_attackers.append(candidate)
	return active_attackers

func _can_continue_declared_attack(attacker: Card) -> bool:
	return attacker != null \
		and attacker.card_type == Card.CardType.CREATURE \
		and attacker.current_zone != null \
		and attacker.current_zone.zone_type == Zone.ZoneType.FRONTLINE \
		and attacker.creature_mode == Card.CreatureMode.AGGRESSIVE

func add_to_stack(action: CardAction) -> void:
	action_stack.append(action)

func resolve_stack() -> void:
	while action_stack.size() > 0:
		var action = action_stack.pop_back()
		action.resolve()
		
func convert_followers(from_player: Player, to_player: Player, amount: int) -> int:
	if from_player == null or to_player == null or amount <= 0:
		return 0
	if not can_player_lose_followers_now(from_player):
		return 0
	var actual: int = mini(amount, from_player.followers)
	if actual <= 0:
		return 0
	followers_converted.emit(from_player, to_player, actual)
	from_player.lose_followers(actual)
	to_player.gain_followers(actual)
	print("Convert! " + str(actual) + " followers move from " + from_player.player_name + " to " + to_player.player_name)
	return actual

func _convert_combat_follower_damage(from_player: Player, to_player: Player, amount: int) -> int:
	if from_player == null or to_player == null or amount <= 0:
		return 0
	var adjusted_amount := _adjust_combat_follower_damage(amount)
	if adjusted_amount <= 0:
		return 0
	var remaining_amount := from_player.absorb_guard_damage(adjusted_amount)
	if remaining_amount <= 0:
		return 0
	if not can_player_lose_followers_now(from_player):
		return 0
	var actual := mini(remaining_amount, from_player.followers)
	if actual <= 0:
		return 0
	followers_converted.emit(from_player, to_player, actual)
	from_player.lose_followers(actual)
	to_player.gain_followers(actual)
	return actual

func _source_converts_combat_follower_damage(source_card: Card) -> bool:
	if source_card == null or not source_card.has_method("converts_follower_damage_to_conversion"):
		return false
	return source_card.converts_follower_damage_to_conversion(self)

func _get_combat_follower_conversion_amount(source_card: Card, amount: int) -> int:
	if amount <= 0:
		return 0
	if source_card != null and source_card.has_method("get_follower_damage_conversion_amount"):
		return clampi(int(source_card.get_follower_damage_conversion_amount(amount, self)), 0, amount)
	return amount

func _apply_combat_follower_damage(source_card: Card, damaged_player: Player, amount: int) -> int:
	if damaged_player == null or amount <= 0:
		return 0
	var adjusted_amount := _adjust_combat_follower_damage(amount)
	if adjusted_amount <= 0:
		return 0
	adjusted_amount = damaged_player.absorb_guard_damage(adjusted_amount)
	if adjusted_amount <= 0:
		return 0
	var source_controller := source_card.get_controller() if source_card != null else null
	if _source_converts_combat_follower_damage(source_card) \
			and source_controller != null \
			and source_controller != damaged_player:
		var conversion_amount := _get_combat_follower_conversion_amount(source_card, adjusted_amount)
		if conversion_amount <= 0:
			return 0
		return convert_followers(damaged_player, source_controller, conversion_amount)
	damaged_player.lose_followers(adjusted_amount)
	return adjusted_amount

func apply_attack_restriction(player: Player, turns: int, source: Card = null) -> void:
	attack_restrictions[player] = {turns = turns, source = source}
	if source != null and source.has_method("refresh_attack_restriction_art"):
		source.call("refresh_attack_restriction_art", self)
	print(player.player_name + " cannot attack for " + str(turns) + " turns!")

func remove_attack_restriction(player: Player) -> void:
	if attack_restrictions.has(player):
		attack_restrictions.erase(player)
		print(player.player_name + " attack restriction removed!")

func _advance_attack_restriction_turn(player: Player) -> void:
	if player == null or not attack_restrictions.has(player):
		return
	attack_restrictions[player].turns -= 1
	if attack_restrictions[player].turns <= 0:
		var source_card: Card = attack_restrictions[player].source
		attack_restrictions.erase(player)
		print(player.player_name + " can now attack again!")
		if source_card != null:
			source_card.switch_to_exhausted_art()
	else:
		var source_card: Card = attack_restrictions[player].source
		if source_card != null and source_card.has_method("refresh_attack_restriction_art"):
			source_card.call("refresh_attack_restriction_art", self)
		print(player.player_name + " still cannot attack (" + str(attack_restrictions[player].turns) + " turns left)")

# Turn lifecycle order is intentionally explicit:
# 1. Fire controller turn-end hooks for the ending player's permanents.
# 2. Fire global turn-end hooks for all permanents.
# 3. Emit turn_ended and clear end-of-turn expiring statuses.
# 4. Reset creature action points for every board creature.
# 5. Swap active/other players.
# 6. Begin the next turn immediately.
func end_turn() -> void:
	if is_game_over:
		return
	var ending_player := current_player
	_notify_controller_turn_end(ending_player)
	_notify_global_turn_end(ending_player)
	turn_ended.emit(turn_number, ending_player)
	for card in _get_all_turn_event_cards():
		card.remove_expired_buffs(turn_number)
		card.remove_expired_statuses(turn_number)
	_clear_expired_turn_destruction_wards(turn_number)
	_clear_expired_turn_follower_loss_preventions(turn_number)
	_clear_expired_turn_opponent_targeting_immunities(turn_number)
	_advance_attack_restriction_turn(ending_player)
	_reset_all_board_creature_action_states()
	
	# Swap players for the next turn
	var temp = current_player
	current_player = other_player
	other_player = temp
	turn_player = current_player
	current_player.is_turn_player = true
	other_player.is_turn_player = false
	start_turn()

func _reset_all_board_creature_action_states() -> void:
	for player in players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card != null and card.is_creature_card():
					card.reset_creature_action_state()
					card.summoned_after_first_attack_this_turn = false

func _get_player_turn_event_cards(player: Player, include_god: bool = true) -> Array[Card]:
	var cards: Array[Card] = []
	if player == null:
		return cards
	var zones: Array[Zone] = []
	var powers_enabled := can_player_use_powers(player)
	if include_god and powers_enabled:
		zones.append(player.god_zone)
	if powers_enabled:
		zones.append_array(player.power_zones)
	zones.append_array(player.frontline_zones)
	zones.append_array(player.reserve_zones)
	for zone in zones:
		for card in zone.cards.duplicate():
			if card != null:
				cards.append(card)
	return cards

func _get_all_turn_event_cards() -> Array[Card]:
	var cards: Array[Card] = []
	for player in players:
		for card in _get_player_turn_event_cards(player):
			if card not in cards:
				cards.append(card)
	return cards

func _notify_controller_turn_start(player: Player) -> void:
	controller_turn_started.emit(turn_number, player)
	for card in _get_player_turn_event_cards(player):
		if card.has_method("on_turn_start"):
			card.on_turn_start(self)

func _get_sorted_upkeep_cards_for_player(player: Player, method_name: String) -> Array[Card]:
	var cards: Array[Card] = []
	if player == null:
		return cards
	for card in _get_player_turn_event_cards(player):
		if card != null and card.has_method(method_name):
			_ensure_board_entry_order(card)
			cards.append(card)
	cards.sort_custom(_compare_upkeep_cards)
	return cards

func _compare_upkeep_cards(a: Card, b: Card) -> bool:
	var a_speed := a.get_effective_speed()
	var b_speed := b.get_effective_speed()
	if a_speed == b_speed:
		return a.board_entry_order < b.board_entry_order
	return a_speed > b_speed

func _ensure_board_entry_order(card: Card) -> void:
	if card == null or card.current_zone == null or not card.current_zone.is_board_zone():
		return
	if card.board_entry_order >= 0:
		return
	card.board_entry_order = _next_board_entry_order
	_next_board_entry_order += 1

func _notify_global_turn_start(starting_player: Player) -> void:
	global_turn_started.emit(turn_number, starting_player)
	for card in _get_all_turn_event_cards():
		if card.has_method("on_global_turn_start"):
			card.on_global_turn_start(self, starting_player)
	MalinalxochitlAcolyte.process_persistent_poison_turn_start(self, starting_player)

func _notify_controller_turn_end(player: Player) -> void:
	controller_turn_ended.emit(turn_number, player)
	for card in _get_player_turn_event_cards(player):
		if card.has_method("on_turn_end"):
			card.on_turn_end(self)

func _notify_global_turn_end(ending_player: Player) -> void:
	global_turn_ended.emit(turn_number, ending_player)
	for card in _get_all_turn_event_cards():
		if card.has_method("on_global_turn_end"):
			card.on_global_turn_end(self, ending_player)
	_resolve_temporary_control_effects(ending_player)
	_resolve_destroy_at_turn_end_statuses()

func _resolve_temporary_control_effects(ending_player: Player) -> void:
	if _temporary_control_effects.is_empty():
		return
	var remaining_entries: Array[Dictionary] = []
	for entry in _temporary_control_effects:
		if int(entry.get("return_turn_number", -1)) != turn_number:
			remaining_entries.append(entry)
			continue
		if entry.get("ending_player") != ending_player:
			remaining_entries.append(entry)
			continue
		var creature := entry.get("creature") as Card
		var previous_controller := entry.get("previous_controller") as Player
		if creature == null or not is_instance_valid(creature):
			continue
		if previous_controller == null or not is_instance_valid(previous_controller):
			continue
		if creature.current_zone == null or not creature.current_zone.is_board_zone():
			continue
		var return_zone := _find_enslave_destination(
			previous_controller,
			int(entry.get("previous_zone_type", Zone.ZoneType.FRONTLINE)),
			int(entry.get("previous_zone_index", 0))
		)
		if return_zone == null:
			creature.card_owner.move_card(creature, creature.card_owner.hand_zone)
			continue
		previous_controller.move_card(creature, return_zone)
		creature.reveal_from_stealth(self)
	_temporary_control_effects = remaining_entries

func notify_god_power_activated(player: Player, god: Card, target: Card = null) -> void:
	if player == null or god == null:
		return
	for zone in player.frontline_zones + player.reserve_zones:
		for card in zone.cards.duplicate():
			if card != null and card.has_method("on_friendly_god_power_activated"):
				card.on_friendly_god_power_activated(self, god, target)
	god_power_activated.emit(turn_number, player, god, target)

func notify_creature_shapeshifted(creature: Card, source_card: Card = null) -> void:
	if creature == null:
		return
	for card in _get_all_turn_event_cards():
		if card != null and card.has_method("on_creature_shapeshifted"):
			card.on_creature_shapeshifted(self, creature, source_card)


# --- New Helper Function for Card Removal ---
# Returns true if the given player has Asag on the board (Class Rend active).
func _class_rend_active(player: Player) -> bool:
	for zone in player.frontline_zones + player.reserve_zones:
		for card in zone.cards:
			if card is AsagTheDestroyer and not card.abilities_suppressed():
				return true
	return false

# Returns true if target is shielded by Guardian (Asaruludu's passive).
# Applies during the controller's turn or during the combat phase.
func is_guardian_protected(target: Card, source: Card = null) -> bool:
	if source != null and not is_targeting_source(source):
		return false
	if target != null and target.has_status_effect("en_hedu_anna_exaltation_guard"):
		return true
	var target_controller := target.get_controller()
	if target_controller == null:
		return false
	if not (current_phase == GamePhase.COMBAT or current_player == target_controller):
		return false
	if target.culture != "Ancient":
		return false
	for zone in target_controller.frontline_zones + target_controller.reserve_zones:
		for card in zone.cards:
			if card is Asaruludu and not card.abilities_suppressed():
				return true
	return false

# Returns whether Class Rend would trigger for this kill (evaluated before any zone changes).
func _should_class_rend(killer: Card, victim: Card) -> bool:
	var killer_controller := killer.get_controller() if killer != null else null
	var victim_controller := victim.get_controller() if victim != null else null
	return killer != null \
		and killer.card_type == Card.CardType.CREATURE \
		and killer.has_type("Demon") \
		and killer_controller != null \
		and victim_controller != null \
		and killer_controller != victim_controller \
		and _class_rend_active(killer_controller)

# Executes a combat kill with a pre-determined void flag (avoids mid-sequence zone-state drift).
func _combat_kill_routed(killer: Card, victim: Card, do_void: bool, suppress_ally_kill_sources: Array = []) -> void:
	var killer_controller := killer.get_controller() if killer != null else null
	var victim_controller := victim.get_controller()
	var bypass_combat_survival := killer != null and killer.can_destroy_combat_protected_creatures(victim)
	var finish := func() -> void:
		var victim_counts_as_creature_kill := victim != null and victim.card_type == Card.CardType.CREATURE and not victim.is_petrified()
		var victim_counts_as_attack_target_destroy := victim != null \
			and killer_controller != null \
			and victim_controller != null \
			and victim_controller != killer_controller
		if killer != null and killer.has_method("on_kill") and not killer.abilities_suppressed() and victim_counts_as_creature_kill:
			killer.on_kill(self, victim)
		if killer != null and killer.has_method("on_attack_target_destroyed") and not killer.abilities_suppressed() and victim_counts_as_attack_target_destroy:
			killer.on_attack_target_destroyed(self, victim)
		if victim_counts_as_attack_target_destroy:
			combat_destroy_events_this_turn.append({
				"killer_owner": killer_controller,
				"victim_owner": victim_controller,
				"killer": killer,
				"victim": victim,
			})
			_notify_player_god_visual_state_changed(killer_controller)
		if killer != null and killer_controller != null and victim_controller != killer_controller and victim_counts_as_creature_kill:
			for zone in killer_controller.frontline_zones + killer_controller.reserve_zones:
				for card in zone.cards:
					if card in suppress_ally_kill_sources:
						continue
					if card.has_method("on_ally_kill") and not card.abilities_suppressed():
						card.on_ally_kill(self, killer, victim)
	if do_void:
		print("Class Rend! " + killer.card_name + " voids " + victim.card_name + "!")
		if victim.current_zone and victim.current_zone.is_board_zone():
			victim.last_board_zone_type  = victim.current_zone.zone_type
			victim.last_board_zone_index = victim.current_zone.zone_index
		victim.process_board_leave_hooks(self)
		if victim.has_method("on_death") and not victim.post_field_abilities_suppressed():
			victim.on_death(self)
		died_this_turn.append(victim)
		for equip in victim.equipment.duplicate():
			_send_to_abyss_with_hook(equip)
		victim.card_owner.move_card(victim, victim.card_owner.abyss_zone)
		finish.call()
		return
	request_send_to_graveyard(victim, finish, true, true, bypass_combat_survival)

func player_destroyed_creature_by_combat_this_turn(player: Player) -> bool:
	for event in combat_destroy_events_this_turn:
		var victim := event.get("victim", null) as Card
		if event.get("killer_owner", null) == player \
			and event.get("victim_owner", null) != player \
			and victim != null \
			and victim.card_type == Card.CardType.CREATURE \
			and not victim.is_petrified():
			return true
	return false

func card_destroyed_attack_target_this_turn(card: Card) -> bool:
	if card == null:
		return false
	for event: Dictionary in combat_destroy_events_this_turn:
		if event.get("killer", null) != card:
			continue
		var killer_owner: Player = event.get("killer_owner", null)
		var victim_owner: Player = event.get("victim_owner", null)
		if killer_owner != null and victim_owner != killer_owner:
			return true
	return false

func card_destroyed_attack_target_since(card: Card, from_event_index: int = 0) -> bool:
	if card == null:
		return false
	var start_index := maxi(0, from_event_index)
	for i in range(start_index, combat_destroy_events_this_turn.size()):
		var event: Dictionary = combat_destroy_events_this_turn[i]
		if event.get("killer", null) != card:
			continue
		var killer_owner: Player = event.get("killer_owner", null)
		var victim_owner: Player = event.get("victim_owner", null)
		if killer_owner != null and victim_owner != killer_owner:
			return true
	return false

func _is_protected_from_enslavement(creature: Card) -> bool:
	if creature == null:
		return false
	for player in players:
		for god in player.god_zone.cards:
			if god != null and god.has_method("prevents_enslave") and god.prevents_enslave(creature):
				return true
	return false

func get_enslave_failure_reason(creature: Card, new_controller: Player) -> String:
	if creature == null or new_controller == null:
		return "No creature was selected."
	if creature.card_type != Card.CardType.CREATURE or creature.is_god:
		return creature.card_name + " cannot be enslaved."
	if creature.current_zone == null or not creature.current_zone.is_board_zone():
		return creature.card_name + " is not on the field."
	if _is_protected_from_enslavement(creature):
		return creature.card_name + " is protected from enslavement."
	var destination := _find_enslave_destination(new_controller, creature.current_zone.zone_type, creature.current_zone.zone_index)
	if destination == null:
		return "There is no open zone to place " + creature.card_name + "."
	return ""

func can_enslave_creature(creature: Card, new_controller: Player) -> bool:
	return get_enslave_failure_reason(creature, new_controller) == ""

func enslave_creature(creature: Card, new_controller: Player) -> bool:
	if not can_enslave_creature(creature, new_controller):
		var reason := get_enslave_failure_reason(creature, new_controller)
		if reason != "":
			print(reason)
		return false
	var destination := _find_enslave_destination(new_controller, creature.current_zone.zone_type, creature.current_zone.zone_index)
	if destination == null:
		return false
	new_controller.move_card(creature, destination)
	creature.reveal_from_stealth(self)
	return true

func grant_temporary_control_of_creature(
	creature: Card,
	new_controller: Player,
	source_card: Card = null,
	return_turn_number: int = -1,
	ending_player: Player = null
) -> bool:
	if creature == null or new_controller == null:
		return false
	var previous_controller := creature.get_controller()
	if previous_controller == null or previous_controller == new_controller:
		return false
	if not can_enslave_creature(creature, new_controller):
		return false
	var destination := _find_enslave_destination(new_controller, creature.current_zone.zone_type, creature.current_zone.zone_index)
	if destination == null:
		return false
	_temporary_control_effects = _temporary_control_effects.filter(func(entry: Dictionary) -> bool:
		return entry.get("creature") != creature
	)
	_temporary_control_effects.append({
		"creature": creature,
		"previous_controller": previous_controller,
		"previous_zone_type": creature.current_zone.zone_type,
		"previous_zone_index": creature.current_zone.zone_index,
		"return_turn_number": turn_number if return_turn_number < 0 else return_turn_number,
		"ending_player": current_player if ending_player == null else ending_player,
		"source_card": source_card,
	})
	new_controller.move_card(creature, destination)
	creature.reveal_from_stealth(self)
	return true

func _find_enslave_destination(player: Player, zone_type: int, zone_index: int) -> Zone:
	var preferred_rows: Array[Array] = []
	if zone_type == Zone.ZoneType.FRONTLINE:
		preferred_rows = [player.frontline_zones, player.reserve_zones]
	else:
		preferred_rows = [player.reserve_zones, player.frontline_zones]
	for row in preferred_rows:
		if zone_index >= 0 and zone_index < row.size():
			var preferred_zone := row[zone_index] as Zone
			if preferred_zone.cards.is_empty():
				return preferred_zone
		for zone in row:
			if zone.cards.is_empty():
				return zone
	return null

# Routes a combat kill, auto-detecting Class Rend. Use _combat_kill_routed for ties.
func _combat_kill(killer: Card, victim: Card) -> void:
	_combat_kill_routed(killer, victim, _should_class_rend(killer, victim))

func _send_to_graveyard_with_hook(card: Card, combat_death: bool = false, destruction: bool = false) -> bool:
	return _send_to_graveyard_with_hook_resolved(card, false, combat_death, destruction)

func request_send_to_graveyard(
	card: Card,
	continue_callback: Callable = Callable(),
	combat_death: bool = false,
	destruction: bool = false,
	ignore_self_combat_replacement: bool = false
) -> bool:
	if card == null:
		if continue_callback.is_valid():
			continue_callback.call()
		return true
	var graveyard_replacements := _get_graveyard_replacement_sources(card)
	if not graveyard_replacements.is_empty():
		_pending_doorway_structures = graveyard_replacements
		_pending_doorway_structure = _pending_doorway_structures.pop_front()
		_pending_doorway_card = card
		_pending_doorway_combat_death = combat_death
		_pending_doorway_destruction = destruction
		_pending_doorway_ignore_self_combat_replacement = ignore_self_combat_replacement
		_pending_doorway_continue = continue_callback
		doorway_choice_requested.emit(_pending_doorway_structure, card, combat_death, destruction)
		return false
	return _send_to_graveyard_with_hook_resolved(
		card,
		false,
		combat_death,
		destruction,
		continue_callback,
		ignore_self_combat_replacement
	)

func request_send_cards_to_graveyard(
	cards: Array[Card],
	completion_callback: Callable = Callable(),
	combat_death: bool = false,
	destruction: bool = false,
	ignore_self_combat_replacement: bool = false,
	card_index: int = 0,
	destroyed_count: int = 0
) -> void:
	var working_queue: Array[Card] = []
	if card_index == 0 and not cards.is_empty():
		var seen_card_ids: Dictionary = {}
		for queued_card in cards:
			if queued_card == null or not is_instance_valid(queued_card):
				continue
			var queued_card_id := queued_card.get_instance_id()
			if seen_card_ids.has(queued_card_id):
				continue
			seen_card_ids[queued_card_id] = true
			working_queue.append(queued_card)
	else:
		working_queue = cards.duplicate()
	if working_queue.is_empty():
		if completion_callback.is_valid():
			completion_callback.call(destroyed_count)
		return
	var card = working_queue.pop_front()
	if card == null or not is_instance_valid(card):
		request_send_cards_to_graveyard(
			working_queue,
			completion_callback,
			combat_death,
			destruction,
			ignore_self_combat_replacement,
			1,
			destroyed_count
		)
		return
	if card.current_zone == null and not is_card_on_field(card):
		request_send_cards_to_graveyard(
			working_queue,
			completion_callback,
			combat_death,
			destruction,
			ignore_self_combat_replacement,
			1,
			destroyed_count
		)
		return
	var on_continue := func() -> void:
		var next_destroyed_count := destroyed_count
		if _counts_as_destroyed_destination(card):
			next_destroyed_count += 1
		request_send_cards_to_graveyard(
			working_queue,
			completion_callback,
			combat_death,
			destruction,
			ignore_self_combat_replacement,
			1,
			next_destroyed_count
		)
	request_send_to_graveyard(
		card,
		on_continue,
		combat_death,
		destruction,
		ignore_self_combat_replacement
	)

func _counts_as_destroyed_destination(card: Card) -> bool:
	if card == null or not is_instance_valid(card) or card.card_owner == null or card.current_zone == null:
		return false
	return card.current_zone == card.card_owner.graveyard_zone \
		or card.current_zone == card.card_owner.abyss_zone

func reached_public_destroyed_destination(card: Card) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	if _counts_as_destroyed_destination(card):
		return true
	return card.is_token and card.current_zone == null

func get_resolved_destruction_log_name(
	card: Card,
	viewer: Player = null,
	unresolved_fallback: String = "a card"
) -> String:
	if card == null or not is_instance_valid(card):
		return unresolved_fallback
	if reached_public_destroyed_destination(card):
		return card.get_display_name()
	return unresolved_fallback if not unresolved_fallback.is_empty() else card.get_target_log_display_name(viewer)

func _send_to_graveyard_with_hook_resolved(
	card: Card,
	send_to_abyss: bool,
	combat_death: bool = false,
	destruction: bool = false,
	continue_callback: Callable = Callable(),
	ignore_self_combat_replacement: bool = false
) -> bool:
	if destruction and not combat_death and _is_turn_destruction_ward_protected(card):
		print(card.card_name + " resists destruction from " + get_effect_source_card().card_name + " this turn.")
		if continue_callback.is_valid():
			continue_callback.call()
		return false
	if destruction and (
		card.has_status_effect("berserker_rage_guard")
		or card.has_status_effect("berserker_mead_guard")
		or card.has_status_effect("en_hedu_anna_exaltation_guard")
	):
		print(card.card_name + " resists destruction this turn.")
		if continue_callback.is_valid():
			continue_callback.call()
		return false
	# Record board position before the zone changes so Circle of Rebirth can
	# auto-resurrect to the same spot.
	if card.current_zone and card.current_zone.is_board_zone():
		card.last_board_zone_type  = card.current_zone.zone_type
		card.last_board_zone_index = card.current_zone.zone_index

	var replacement_zone: Zone = null
	if not (ignore_self_combat_replacement and combat_death) \
			and card.has_method("get_self_graveyard_replacement_zone") and not card.abilities_suppressed() \
			and not _is_watchbeast_active():
		replacement_zone = card.get_self_graveyard_replacement_zone(self, combat_death, destruction, send_to_abyss)

	card.process_board_leave_hooks(self)
	if combat_death and card.has_method("on_death") and not card.post_field_abilities_suppressed():
		card.on_death(self)

	died_this_turn.append(card)
	if destruction or combat_death:
		destroyed_this_turn.append(card)
	if replacement_zone != null:
		card.card_owner.move_card(card, replacement_zone)
		if replacement_zone == card.card_owner.hand_zone:
			print("%s returns to %s's hand instead." % [card.card_name, card.card_owner.player_name])
		if continue_callback.is_valid():
			continue_callback.call()
		return true
	if not (ignore_self_combat_replacement and combat_death) \
			and card.has_method("request_self_graveyard_replacement_choice") and not card.abilities_suppressed() \
			and not _is_watchbeast_active():
		if card.request_self_graveyard_replacement_choice(
			self,
			combat_death,
			destruction,
			send_to_abyss,
			continue_callback
		):
			return false
	if send_to_abyss:
		card.card_owner.move_card(card, card.card_owner.abyss_zone)
	else:
		card.card_owner.move_card(card, card.card_owner.graveyard_zone)
	if continue_callback.is_valid():
		continue_callback.call()
	return true

func has_pending_return_to_hand_choice() -> bool:
	return _pending_return_to_hand_card != null

func get_pending_return_to_hand_card() -> Card:
	return _pending_return_to_hand_card

func get_pending_doorway_card() -> Card:
	return _pending_doorway_card

func get_pending_doorway_structure() -> StructureCard:
	return _pending_doorway_structure

func begin_pending_return_to_hand_choice(
	card: Card,
	reason: String,
	continue_callback: Callable = Callable(),
	send_to_abyss: bool = false,
	steal_actor: Card = null
) -> bool:
	if card == null or _pending_return_to_hand_card != null:
		return false
	var prompt_player := card.card_owner if card.card_owner != null else current_player
	if prompt_player == null:
		return false
	_pending_return_to_hand_card = card
	_pending_return_to_hand_reason = reason
	_pending_return_to_hand_send_to_abyss = send_to_abyss
	_pending_return_to_hand_continue = continue_callback
	_pending_return_to_hand_steal_actor = steal_actor
	decision_requested.emit(prompt_player, "return_to_hand_choice", {
		"card": card,
		"card_uid": card.uid,
		"reason": reason,
	})
	return true

func resolve_pending_return_to_hand_choice(pay_cost: bool) -> bool:
	if not has_pending_return_to_hand_choice():
		return false
	var card := _pending_return_to_hand_card
	var reason := _pending_return_to_hand_reason
	var send_to_abyss := _pending_return_to_hand_send_to_abyss
	var continue_callback := _pending_return_to_hand_continue
	var steal_actor := _pending_return_to_hand_steal_actor
	_clear_pending_return_to_hand_choice()

	var resolved := false
	var feedback := ""
	if pay_cost and card != null and is_instance_valid(card) \
			and card.has_method("resolve_return_to_hand_replacement_choice"):
		feedback = card.resolve_return_to_hand_replacement_choice(self, true, reason)
		resolved = card.card_owner != null and card.current_zone == card.card_owner.hand_zone

	if not resolved and reason == "stolen":
		resolved = _complete_creature_pick_up_equipment(steal_actor, card)
		if feedback == "":
			if resolved and steal_actor != null and card != null:
				feedback = "%s steals %s." % [steal_actor.card_name, card.card_name]
			elif card != null:
				feedback = "%s could not be stolen." % card.card_name
	elif not resolved and card != null and card.card_owner != null:
		if send_to_abyss:
			card.card_owner.move_card(card, card.card_owner.abyss_zone)
			if feedback == "":
				feedback = "%s is sent to the abyss." % card.card_name
		else:
			card.card_owner.move_card(card, card.card_owner.graveyard_zone)
			if feedback == "":
				feedback = "%s is destroyed." % card.card_name
		resolved = true

	if feedback.strip_edges() != "":
		note_player_feedback(feedback)
	if continue_callback.is_valid():
		continue_callback.call()
	return resolved

func _clear_pending_return_to_hand_choice() -> void:
	_pending_return_to_hand_card = null
	_pending_return_to_hand_reason = ""
	_pending_return_to_hand_send_to_abyss = false
	_pending_return_to_hand_continue = Callable()
	_pending_return_to_hand_steal_actor = null

func _is_turn_destruction_ward_protected(card: Card) -> bool:
	if card == null or card.card_type != Card.CardType.CREATURE:
		return false
	var protected_player := card.get_controller()
	if protected_player == null or not has_turn_destruction_ward(protected_player):
		return false
	var source_card := get_effect_source_card()
	if source_card == null:
		return false
	var source_controller := source_card.get_controller()
	if source_controller == null:
		source_controller = source_card.card_owner
	return source_controller != null and source_controller != protected_player

func has_pending_doorway_choice() -> bool:
	return _pending_doorway_structure != null and _pending_doorway_card != null

func resolve_pending_doorway_choice(send_to_abyss: bool) -> bool:
	if not has_pending_doorway_choice():
		return false
	var card := _pending_doorway_card
	var combat_death := _pending_doorway_combat_death
	var destruction := _pending_doorway_destruction
	var ignore_self_combat_replacement := _pending_doorway_ignore_self_combat_replacement
	var continue_callback := _pending_doorway_continue
	if send_to_abyss:
		_clear_pending_doorway_choice()
		var abyss_success := _send_to_graveyard_with_hook_resolved(
			card,
			true,
			combat_death,
			destruction,
			continue_callback,
			ignore_self_combat_replacement
		)
		return abyss_success
	if _advance_pending_doorway_choice():
		return false
	_clear_pending_doorway_choice()
	var graveyard_success := _send_to_graveyard_with_hook_resolved(
		card,
		false,
		combat_death,
		destruction,
		continue_callback,
		ignore_self_combat_replacement
	)
	return graveyard_success

func _advance_pending_doorway_choice() -> bool:
	if _pending_doorway_card == null:
		return false
	while not _pending_doorway_structures.is_empty():
		var next_structure = _pending_doorway_structures.pop_front()
		if next_structure == null:
			continue
		if not is_instance_valid(next_structure):
			continue
		if not next_structure.replaces_graveyard_send(_pending_doorway_card, self):
			continue
		_pending_doorway_structure = next_structure
		doorway_choice_requested.emit(
			next_structure,
			_pending_doorway_card,
			_pending_doorway_combat_death,
			_pending_doorway_destruction
		)
		return true
	return false

func _clear_pending_doorway_choice() -> void:
	_pending_doorway_structure = null
	_pending_doorway_structures.clear()
	_pending_doorway_card = null
	_pending_doorway_combat_death = false
	_pending_doorway_destruction = false
	_pending_doorway_ignore_self_combat_replacement = false
	_pending_doorway_continue = Callable()
func banish_card_with_hook(card: Card) -> void:
	_send_to_abyss_with_hook(card)

func remove_card_from_game_with_hook(card: Card) -> void:
	if card == null:
		return
	var from_zone := card.current_zone
	if from_zone == null:
		return
	if card.current_zone.is_board_zone():
		card.last_board_zone_type = card.current_zone.zone_type
		card.last_board_zone_index = card.current_zone.zone_index
	if card.is_creature_card() and from_zone.is_board_zone():
		for equip in card.equipment.duplicate():
			if equip == null:
				continue
			equip.unequip()
	if card.card_type == Card.CardType.EQUIPMENT and card.equipped_on != null:
		card.unequip()
	if from_zone.is_in_play_zone():
		if card.has_method("reset_activation_counter"):
			card.reset_activation_counter()
		card.remove_effects_expiring_after_combat()
	card.process_board_leave_hooks(self)
	from_zone.remove_card(card)
	card.board_entry_order = -1
	if card.card_owner != null:
		card.card_owner.card_moved.emit(card, from_zone, null)
	if from_zone.is_in_play_zone():
		card.clear_board_leave_state()

func _send_to_abyss_with_hook(card: Card) -> void:
	card.process_board_leave_hooks(self)
	card.card_owner.move_card(card, card.card_owner.abyss_zone)

func send_to_deck_bottom_with_hook(card: Card) -> void:
	if card.current_zone != null and card.current_zone.is_board_zone():
		card.process_board_leave_hooks(self)
	card.card_owner.move_card(card, card.card_owner.deck_zone)

func _on_player_card_moved(card: Card, from_zone: Zone, to_zone: Zone) -> void:
	if card == null:
		return
	card.remove_status_effects_with_flag("clear_on_card_move")
	if from_zone != null and from_zone.is_board_zone() and (to_zone == null or not to_zone.is_board_zone()):
		card.board_entry_order = -1
	elif to_zone != null and (from_zone == null or not from_zone.is_board_zone()) and to_zone.is_board_zone():
		_ensure_board_entry_order(card)
	if prepared_hexes.has(card) and (to_zone == null or not to_zone.is_board_zone() or not card.is_prepared):
		prepared_hexes.erase(card)
	if prepared_charms.has(card) and (to_zone == null or not to_zone.is_board_zone() or not card.is_prepared):
		prepared_charms.erase(card)
	if card.card_type == Card.CardType.CREATURE and to_zone != null:
		if from_zone != null and from_zone.zone_type == Zone.ZoneType.ABYSS and to_zone.is_board_zone():
			_notify_creature_returned_from_void(card)
		elif to_zone.zone_type == Zone.ZoneType.ABYSS:
			_notify_creature_sent_to_void(card)
	_notify_board_cards_of_movement(card, from_zone, to_zone)
	if to_zone != null and to_zone.zone_type == Zone.ZoneType.FRONTLINE:
		_push_frontline_entry_event(card)

func _push_frontline_entry_event(card: Card) -> void:
	if card == null or card.card_owner == null:
		return
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.event_name = "frontline_entry"
	action.card = card
	action.source_player = card.card_owner
	if not _has_priority_responses_for_action(action):
		return
	push_to_stack(action)

func get_field_cards(player: Player = null, include_sheltered: bool = true) -> Array[Card]:
	var field_cards: Array[Card] = []
	var seen_cards: Dictionary = {}
	if player != null:
		_append_player_field_cards(player, field_cards, seen_cards, include_sheltered)
		return field_cards
	for field_player in players:
		_append_player_field_cards(field_player, field_cards, seen_cards, include_sheltered)
	return field_cards

func is_card_on_field(card: Card, include_sheltered: bool = true) -> bool:
	if card == null:
		return false
	if card.current_zone != null and card.current_zone.is_board_zone():
		return true
	if not include_sheltered or card.card_owner == null:
		return false
	for field_card in get_field_cards(card.card_owner, true):
		if field_card == card:
			return true
	return false

func _append_player_field_cards(player: Player, field_cards: Array[Card], seen_cards: Dictionary, include_sheltered: bool) -> void:
	if player == null:
		return
	for zone in player.frontline_zones + player.reserve_zones:
		if zone == null:
			continue
		for card in zone.cards:
			_append_unique_field_card(field_cards, seen_cards, card)
	if not include_sheltered:
		return
	for zone in player.power_zones:
		if zone == null:
			continue
		for source_card in zone.cards:
			if source_card == null or not source_card.has_method("get_sheltered_cards_for_field_effects"):
				continue
			for sheltered_card in source_card.get_sheltered_cards_for_field_effects():
				_append_unique_field_card(field_cards, seen_cards, sheltered_card)

func _append_unique_field_card(field_cards: Array[Card], seen_cards: Dictionary, card: Card) -> void:
	if card == null:
		return
	var card_id := card.get_instance_id()
	if seen_cards.has(card_id):
		return
	seen_cards[card_id] = true
	field_cards.append(card)

func _has_priority_responses_for_action(action: CardAction) -> bool:
	if action == null:
		return false
	var original_priority_player := priority_player
	var original_consecutive_passes := consecutive_passes
	var temporarily_added := false
	if not action_stack.has(action):
		action_stack.push_back(action)
		temporarily_added = true

	var first_player := action.initial_priority_player
	if first_player == null:
		first_player = get_opponent(action.source_player)
	var second_player := get_opponent(first_player) if first_player != null else null
	var has_responses := false
	if first_player != null:
		priority_player = first_player
		has_responses = not get_priority_responses(first_player).is_empty()
	if not has_responses and second_player != null:
		priority_player = second_player
		has_responses = not get_priority_responses(second_player).is_empty()

	if temporarily_added:
		action_stack.erase(action)
	priority_player = original_priority_player
	consecutive_passes = original_consecutive_passes
	return has_responses

func _notify_board_cards_of_movement(moved_card: Card, from_zone: Zone, to_zone: Zone) -> void:
	for player in players:
		for zone in [player.god_zone] + player.power_zones + player.frontline_zones + player.reserve_zones:
			for board_card in zone.cards.duplicate():
				if board_card != null and board_card.has_method("on_any_card_moved"):
					board_card.on_any_card_moved(self, moved_card, from_zone, to_zone)

func _notify_cards_of_creature_mode_change(creature: Card, old_mode: Card.CreatureMode) -> void:
	for player in players:
		for zone in [player.god_zone] + player.power_zones + player.frontline_zones + player.reserve_zones:
			for board_card in zone.cards.duplicate():
				if board_card != null and board_card.has_method("on_any_creature_mode_changed") and not board_card.abilities_suppressed():
					board_card.on_any_creature_mode_changed(self, creature, old_mode)

func _resolve_destroy_at_turn_end_statuses() -> void:
	var due_cards: Array[Card] = []
	for player in players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards.duplicate():
				if card == null or not card.has_status_effect("destroy_at_turn_end"):
					continue
				var status = card.get_status_effect("destroy_at_turn_end")
				if int(status.get("expires_turn", -1)) > turn_number:
					continue
				due_cards.append(card)

	for card in due_cards:
		if card == null or card.current_zone == null or not card.current_zone.is_board_zone():
			continue
		var viewer := get_feedback_viewer()
		var card_name_for_feedback := card.get_target_log_display_name(viewer)
		card.remove_status_effects_by_name("destroy_at_turn_end")
		var on_destroy_complete := func() -> void:
			if reached_public_destroyed_destination(card):
				var destroyed_name := get_resolved_destruction_log_name(card, viewer, card_name_for_feedback)
				note_player_feedback("%s is destroyed at turn's end." % destroyed_name)
		request_send_to_graveyard(card, on_destroy_complete, false, true)

func notify_card_revealed_by_effect(revealed_card: Card, source_card: Card) -> void:
	if revealed_card == null or source_card == null:
		return
	if not _is_reveal_effect_source(source_card):
		return
	for player in players:
		for zone in [player.god_zone] + player.power_zones + player.frontline_zones + player.reserve_zones:
			for board_card in zone.cards.duplicate():
				if board_card != null and board_card.has_method("on_card_revealed_by_effect"):
					board_card.on_card_revealed_by_effect(self, revealed_card, source_card)

func _is_reveal_effect_source(source_card: Card) -> bool:
	if source_card == null:
		return false
	if source_card.is_god:
		return true
	if source_card.card_type == Card.CardType.POWER:
		return true
	return source_card.is_magical_card()

func _notify_creature_sent_to_void(creature: Card) -> void:
	for power in _get_active_powers():
		if power.has_method("on_creature_sent_to_void"):
			power.on_creature_sent_to_void(creature, self)

func _notify_creature_returned_from_void(creature: Card) -> void:
	for power in _get_active_powers():
		if power.has_method("on_creature_returned_from_void"):
			power.on_creature_returned_from_void(creature, self)

func _notify_powers_of_creature_summon(
	player: Player,
	card: Card,
	from_zone: Zone,
	to_zone: Zone,
	summon_source: Card,
	face_down: bool,
	stealth: bool
) -> void:
	if card == null or card.card_type != Card.CardType.CREATURE:
		return
	for power in _get_active_powers():
		if power != null and power.has_method("on_creature_summoned"):
			power.on_creature_summoned(player, card, from_zone, to_zone, summon_source, face_down, stealth, self)
	for event_card in _get_all_turn_event_cards():
		if event_card == null or event_card is PowerCard:
			continue
		if not event_card.has_method("on_creature_summoned"):
			continue
		if event_card.abilities_suppressed():
			continue
		event_card.on_creature_summoned(player, card, from_zone, to_zone, summon_source, face_down, stealth, self)

func _can_use_extra_normal_summon(player: Player, card: Card, target_zone: Zone) -> bool:
	if player == null or card == null:
		return false
	for power in _get_active_powers():
		if power != null and power.has_method("can_grant_extra_normal_summon"):
			if power.can_grant_extra_normal_summon(player, card, target_zone, self):
				return true
	return false

func _consume_extra_normal_summon(player: Player, card: Card, target_zone: Zone) -> void:
	if player == null or card == null:
		return
	for power in _get_active_powers():
		if power == null or not power.has_method("can_grant_extra_normal_summon"):
			continue
		if not power.can_grant_extra_normal_summon(player, card, target_zone, self):
			continue
		if power.has_method("consume_extra_normal_summon"):
			power.consume_extra_normal_summon(player, card, target_zone, self)
		return

func notify_spell_played(player: Player, spell_card: Card) -> void:
	_notify_spell_played(player, spell_card)

func _notify_spell_played(player: Player, spell_card: Card) -> void:
	for power in _get_active_powers():
		if power.has_method("on_spell_played"):
			power.on_spell_played(player, spell_card, self)

func get_total_cost_adjustment(
	target_card: Card,
	base_cost: int,
	cost_kind: String,
	metadata: Dictionary = {}
) -> int:
	var total_adjustment := 0
	for entry in get_cost_adjustment_entries(target_card, base_cost, cost_kind, metadata):
		total_adjustment += int(entry.get("delta", 0))
	return total_adjustment

func get_cost_adjustment_entries(
	target_card: Card,
	base_cost: int,
	cost_kind: String,
	metadata: Dictionary = {}
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if target_card == null or base_cost < 0:
		return entries
	entries.append_array(_get_state_cost_adjustment_entries(target_card, base_cost, cost_kind, metadata))
	for source_card in _get_cost_adjustment_source_cards():
		if source_card == null:
			continue
		for raw_entry in source_card.get_cost_adjustment_entries(target_card, base_cost, cost_kind, self, metadata):
			var entry := _normalize_cost_adjustment_entry(raw_entry, source_card)
			if entry.is_empty():
				continue
			entries.append(entry)
	return entries

func claim_cost_adjustments(
	target_card: Card,
	base_cost: int,
	cost_kind: String,
	metadata: Dictionary = {}
) -> bool:
	if target_card == null or base_cost <= 0:
		return false
	var claimed := _claim_state_cost_adjustments(target_card, base_cost, cost_kind, metadata)
	for source_card in _get_cost_adjustment_source_cards():
		if source_card != null and source_card.claim_cost_adjustment(target_card, base_cost, cost_kind, self, metadata):
			claimed = true
	return claimed

func get_power_cost_reduction_amount(target_power: PowerCard, base_cost: int, is_unlock: bool) -> int:
	if target_power == null or base_cost <= 0:
		return 0
	var cost_kind := Card.COST_KIND_POWER_UNLOCK if is_unlock else Card.COST_KIND_POWER_ACTIVATION
	return mini(base_cost, -mini(0, get_total_cost_adjustment(target_power, base_cost, cost_kind)))

func get_power_cost_adjustment_entries(target_power: PowerCard, base_cost: int, is_unlock: bool) -> Array[Dictionary]:
	if target_power == null:
		return []
	var cost_kind := Card.COST_KIND_POWER_UNLOCK if is_unlock else Card.COST_KIND_POWER_ACTIVATION
	return get_cost_adjustment_entries(target_power, base_cost, cost_kind)

func claim_power_cost_reduction(target_power: PowerCard, base_cost: int, is_unlock: bool) -> bool:
	if target_power == null:
		return false
	var cost_kind := Card.COST_KIND_POWER_UNLOCK if is_unlock else Card.COST_KIND_POWER_ACTIVATION
	return claim_cost_adjustments(target_power, base_cost, cost_kind)

func _get_state_cost_adjustment_entries(
	target_card: Card,
	_base_cost: int,
	cost_kind: String,
	metadata: Dictionary = {}
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if cost_kind == Card.COST_KIND_CREATURE_SUMMON:
		var player: Player = metadata.get("player", null)
		var _summon_source: Card = metadata.get("summon_source", null)
		if player == null:
			player = target_card.card_owner
		for modifier in _temporary_summon_cost_modifiers:
			if modifier.get("player", null) != player:
				continue
			if int(modifier.get("turn_number", -1)) != turn_number:
				continue
			var excluded_cards: Array = modifier.get("excluded_cards", [])
			if target_card in excluded_cards:
				continue
			var amount := int(modifier.get("amount", 0))
			if amount == 0:
				continue
			var source_card = modifier.get("source", null)
			var source_name = source_card.card_name if source_card is Card else "Summon cost modifier"
			entries.append({
				"source": source_name,
				"source_card": source_card,
				"delta": amount,
			})
	if _has_prepared_activation_cost_waiver(target_card, cost_kind, metadata):
		entries.append({
			"source": str(target_card.get_meta("prepared_activation_cost_waiver_source", "Prepared cost waiver")),
			"source_card": target_card.get_meta("prepared_activation_cost_waiver_source_card", null),
			"delta": -_base_cost,
		})
	return entries

func _claim_state_cost_adjustments(
	target_card: Card,
	_base_cost: int,
	cost_kind: String,
	metadata: Dictionary = {}
) -> bool:
	var claimed := false
	if _has_prepared_activation_cost_waiver(target_card, cost_kind, metadata):
		_clear_prepared_activation_cost_waiver(target_card)
		claimed = true
	return claimed

func _has_prepared_activation_cost_waiver(target_card: Card, cost_kind: String, metadata: Dictionary = {}) -> bool:
	if target_card == null:
		return false
	if cost_kind != Card.COST_KIND_HAND_PLAY:
		return false
	if not bool(metadata.get("prepared", false)):
		return false
	if not target_card.is_prepared:
		return false
	return bool(target_card.get_meta("prepared_activation_cost_waived", false))

func _clear_prepared_activation_cost_waiver(target_card: Card) -> void:
	if target_card == null:
		return
	for key in [
		"prepared_activation_cost_waived",
		"prepared_activation_cost_waiver_source",
		"prepared_activation_cost_waiver_source_card"
	]:
		if target_card.has_meta(key):
			target_card.remove_meta(key)

func _get_cost_adjustment_source_cards() -> Array[Card]:
	var sources: Array[Card] = []
	for player in players:
		for card in player.god_zone.cards:
			if _can_source_adjust_costs(card):
				sources.append(card)
		for zone in player.power_zones:
			for card in zone.cards:
				if _can_source_adjust_costs(card):
					sources.append(card)
		for card in get_field_cards(player):
			if _can_source_adjust_costs(card):
				sources.append(card)
	return sources

func _can_source_adjust_costs(card: Card) -> bool:
	if card == null or card.card_owner == null:
		return false
	if card.current_zone == null:
		return is_card_on_field(card) and not card.is_face_down and not card.abilities_suppressed()
	if (card.is_power or card.is_god) and not can_player_use_powers(card.card_owner):
		return false
	if card is PowerCard:
		return (card as PowerCard).is_effectively_active()
	if card.current_zone == card.card_owner.god_zone:
		return not card.is_face_down and not card.abilities_suppressed()
	if not card.current_zone.is_board_zone():
		return false
	return not card.is_face_down and not card.abilities_suppressed()

func _normalize_cost_adjustment_entry(raw_entry, source_card: Card) -> Dictionary:
	if raw_entry == null:
		return {}
	if raw_entry is Dictionary:
		var entry := (raw_entry as Dictionary).duplicate()
		if not entry.has("delta"):
			return {}
		if not entry.has("source"):
			entry["source"] = source_card.card_name if source_card != null else "Cost modifier"
		if not entry.has("source_card"):
			entry["source_card"] = source_card
		return entry
	if raw_entry is int:
		var delta := int(raw_entry)
		if delta == 0:
			return {}
		return {
			"source": source_card.card_name if source_card != null else "Cost modifier",
			"source_card": source_card,
			"delta": delta,
		}
	return {}


func _get_active_powers() -> Array[PowerCard]:
	var active_powers: Array[PowerCard] = []
	for player in players:
		if not can_player_use_powers(player):
			continue
		for zone in player.power_zones:
			if zone.cards.is_empty():
				continue
			var power := zone.cards[0] as PowerCard
			if power != null and power.is_effectively_active():
				active_powers.append(power)
	return active_powers

func _is_face_up_awake_god_for_player(card: Card, player: Player) -> bool:
	return card != null \
		and player != null \
		and card.get_controller() == player \
		and (card.is_god or card.has_type("Active God")) \
		and not card.is_face_down \
		and not card.is_stealth \
		and not card.is_sleeping

func player_has_normal_god(player: Player) -> bool:
	if player == null or player.god_zone == null:
		return false
	for card in player.god_zone.cards:
		if _is_face_up_awake_god_for_player(card, player):
			return true
	return false

func player_has_face_up_awake_active_god(player: Player) -> bool:
	if player == null:
		return false
	for zone in player.frontline_zones + player.reserve_zones:
		for card in zone.cards:
			if _is_face_up_awake_god_for_player(card, player):
				return true
	return false

func can_player_use_powers(player: Player) -> bool:
	if player == null:
		return false
	return player_has_normal_god(player) or player_has_face_up_awake_active_god(player)

func is_player_under_god_death(player: Player) -> bool:
	if player == null:
		return false
	return not can_player_use_powers(player)

func has_active_laws_of_civilization() -> bool:
	for power in _get_active_powers():
		if power is LawsOfCivilization:
			return true
	return false

func is_player_in_upkeep_window(player: Player) -> bool:
	return player != null \
		and player == current_player \
		and _upkeep_started_turn == turn_number \
		and _upkeep_resolved_turn != turn_number

func can_player_gain_mana_now(player: Player) -> bool:
	if player == null:
		return false
	if not has_active_laws_of_civilization():
		return true
	return is_player_in_upkeep_window(player)

func can_player_add_to_hand_now(player: Player) -> bool:
	if player == null:
		return false
	if not has_active_laws_of_civilization():
		return true
	return is_player_in_upkeep_window(player)

func _player_has_active_power_of_type(player: Player, script_type) -> bool:
	if player == null:
		return false
	for power in _get_active_powers():
		if power.card_owner == player and is_instance_of(power, script_type):
			return true
	return false

func _has_ferocious_defence(player: Player) -> bool:
	return _player_has_active_power_of_type(player, FerociousDefence)

func _has_giants_disdain(player: Player) -> bool:
	return _player_has_active_power_of_type(player, GiantsDisdain)

# Returns true when Giant's Disdain should halve `stat_owner`'s stat for
# follower-damage calculation because an opposing Giant with the power is in combat.
func _giants_disdain_applies(stat_owner: Card, opposing_cards: Array[Card]) -> bool:
	if stat_owner == null:
		return false
	if stat_owner.has_type("Giant"):
		return false
	for opposing_card in opposing_cards:
		if opposing_card == null:
			continue
		if not opposing_card.has_type("Giant"):
			continue
		if _has_giants_disdain(opposing_card.get_controller()):
			return true
	return false

func _get_giants_disdain_damage_stat(stat_owner: Card, opposing_cards: Array[Card], base_stat: int) -> int:
	if not _giants_disdain_applies(stat_owner, opposing_cards):
		return base_stat
	return maxi(0, GameManager.round_down_divide(base_stat, 2))

func _get_giants_disdain_combined_strength_for_damage(attackers: Array[Card], opposing_card: Card) -> int:
	var total := 0
	for attacker in attackers:
		if attacker == null:
			continue
		total += _get_giants_disdain_damage_stat(attacker, [opposing_card], attacker.get_effective_strength())
	return total

func _ferocious_defence_triggers(defender: Card, opposing_strength: int) -> bool:
	if defender == null:
		return false
	if defender.card_type != Card.CardType.CREATURE:
		return false
	if defender.creature_mode != Card.CreatureMode.DEFENSIVE:
		return false
	return _has_ferocious_defence(defender.get_controller()) and defender.get_effective_resilience() >= opposing_strength

func _get_active_structures() -> Array[StructureCard]:
	var active_structures: Array[StructureCard] = []
	for player in players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				var structure := card as StructureCard
				if structure != null and not structure.abilities_suppressed():
					active_structures.append(structure)
	return active_structures

func is_attack_blocked_by_active_structure(attacker: Card, defender: Card, allied_attackers: Array = []) -> bool:
	if attacker == null or defender == null:
		return false
	for structure in _get_active_structures():
		if structure.has_method("blocks_attack_on_target") and structure.blocks_attack_on_target(self, attacker, defender, allied_attackers):
			return true
	return false

func is_followers_attack_blocked_by_active_structure(
	attacker: Card,
	defending_player: Player,
	allied_attackers: Array = []
) -> bool:
	if attacker == null or defending_player == null:
		return false
	for structure in _get_active_structures():
		if structure.has_method("blocks_attack_on_followers") \
				and structure.blocks_attack_on_followers(self, attacker, defending_player, allied_attackers):
			return true
	return false

func _any_active_structure_forces_defensive_summon() -> bool:
	for structure in _get_active_structures():
		if structure.has_method("forces_defensive_summon") and structure.forces_defensive_summon():
			return true
	return false

func _get_graveyard_replacement_sources(card: Card) -> Array[StructureCard]:
	var structures: Array[StructureCard] = []
	if card == null or card.card_type != Card.CardType.CREATURE:
		return structures
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return structures
	if _is_watchbeast_active():
		return structures
	for structure in _get_active_structures():
		if structure.replaces_graveyard_send(card, self):
			structures.append(structure)
	return structures

func _apply_god_passives_to_card(_player: Player, _card: Card) -> void:
	# God aura cards now refresh themselves through their own summon/move/turn hooks.
	# Keep this helper as a no-op for existing call sites and local probes.
	return

func forfeit_game(forfeiting_player: Player) -> void:
	_finish_game(forfeiting_player, GAME_END_REASON_FORFEIT)

func forfeit_match(forfeiting_player: Player) -> void:
	_finish_game(forfeiting_player, GAME_END_REASON_MATCH_FORFEIT)

func _finish_game(losing_player_ref: Player, reason: String = GAME_END_REASON_DEFEAT) -> void:
	if is_game_over or losing_player_ref == null:
		return
	losing_player = losing_player_ref
	winning_player = get_opponent(losing_player_ref)
	game_end_reason = reason
	is_game_over = true
	_set_phase(GamePhase.END)
	print(get_game_result_message(winning_player, losing_player, reason))
	game_ended.emit(winning_player, losing_player)

func _on_player_defeated(defeated_player: Player) -> void:
	_finish_game(defeated_player, GAME_END_REASON_DEFEAT)
