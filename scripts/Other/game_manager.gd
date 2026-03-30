# GameManager.gd - Complete Version with Robust Player Identification
extends RefCounted
class_name GameManager

signal game_ended(winner: Player, loser: Player)
signal doorway_choice_requested(structure: StructureCard, card: Card, combat_death: bool, destruction: bool)
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

enum GamePhase { MULLIGAN, MAIN, COMBAT, END }

var players: Array[Player] = []
var current_player: Player
var other_player: Player
var turn_player: Player
var feedback_viewer: Player
var interaction_host: Object = null
var current_phase: GamePhase = GamePhase.MULLIGAN
var is_game_over: bool = false
var winning_player: Player = null
var losing_player: Player = null
var turn_number: int = 0
var action_stack: Array[CardAction] = []
var prepared_hexes: Dictionary = {}
var prepared_charms: Dictionary = {}
var attack_restrictions: Dictionary = {}# player -> turns remaining
var died_this_turn: Array[Card] = []
var pending_resurrections: Array[Card] = []
var combat_destroy_events_this_turn: Array[Dictionary] = []
var last_hex_resolution_text: String = ""
var last_player_feedback_text: String = ""
var _upkeep_resolved_turn: int = -1
var _upkeep_started_turn: int = -1
var _temporary_summon_cost_modifiers: Array[Dictionary] = []
var _next_board_entry_order: int = 0
var _pending_doorway_structure: StructureCard = null
var _pending_doorway_structures: Array[StructureCard] = []
var _pending_doorway_card: Card = null
var _pending_doorway_combat_death: bool = false
var _pending_doorway_destruction: bool = false
var _pending_doorway_continue: Callable = Callable()

# Priority system
var priority_player: Player = null
var consecutive_passes: int = 0

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

func note_player_feedback(text: String) -> void:
	if text.strip_edges() == "":
		return
	last_player_feedback_text = text
	print(text)

func get_feedback_viewer() -> Player:
	if feedback_viewer != null:
		return feedback_viewer
	if turn_player != null:
		return turn_player
	return current_player

func consume_player_feedback() -> String:
	var text := last_player_feedback_text
	last_player_feedback_text = ""
	return text

func set_interaction_host(host: Object) -> void:
	interaction_host = host

func get_interaction_host() -> Object:
	return interaction_host

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
		# Check god zone
		for c in p.god_zone.cards:
			if c.get("uid") == uid: return c
		# Check board zones (frontline, reserve, power)
		for zones in [p.frontline_zones, p.reserve_zones, p.power_zones]:
			for zone in zones:
				for c in zone.cards:
					if c.get("uid") == uid: return c
					
	return null

func can_cards_engage_each_other(attacker: Card, defender: Card) -> bool:
	if attacker == null or defender == null:
		return false
	if attacker.has_method("can_engage") and not attacker.can_engage(defender):
		return false
	if defender.has_method("can_be_engaged_by") and not defender.can_be_engaged_by(attacker):
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
	if card == null or not can_card_respond_to_priority(card, player):
		return
	var card_id := card.get_instance_id()
	if seen_response_ids.has(card_id):
		return
	seen_response_ids[card_id] = true
	responses.append(card)

func can_card_respond_to_priority(card: Card, player: Player = null) -> bool:
	if card == null or action_stack.is_empty():
		return false
	var responding_player := player if player != null else priority_player
	if responding_player == null or card.card_owner != responding_player:
		return false
	var top: CardAction = action_stack.back()
	var top_speed := top.get_timing_speed()
	if card is HexCard:
		if prepared_hexes.get(card, turn_number) >= turn_number:
			return false
		if card.is_activation_locked(self):
			return false
		if _has_pending_stack_action_for_card(card):
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
			return typed_charm.can_activate_from_hand(self, top)
		return typed_charm.can_activate_prepared(self, top)
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
		return card.can_respond_to_priority_action(top, self)
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
	return true

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
	if defender == null:
		return valid_targets
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
	for player in players:
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
# 3. Resolve automatic upkeep with no priority window.
# 4. Later, when the player chooses Draw Card, Gain 4 Mana, or another upkeep option,
#    mark upkeep complete and then fire turn-start hooks/effects.
func start_turn() -> void:
	if is_game_over:
		return
	turn_player = current_player
	turn_number += 1
	_set_phase(GamePhase.MAIN)
	died_this_turn.clear()
	pending_resurrections.clear()
	combat_destroy_events_this_turn.clear()
	_temporary_summon_cost_modifiers.clear()

	current_player.reset_creature_actions()
	
	# Reduce attack restrictions (for the player whose turn is starting)
	if attack_restrictions.has(current_player):
		attack_restrictions[current_player].turns -= 1
		if attack_restrictions[current_player].turns <= 0:
			var source_card: Card = attack_restrictions[current_player].source
			attack_restrictions.erase(current_player)
			print(current_player.player_name + " can now attack again!")
			if source_card != null:
				source_card.switch_to_exhausted_art()
		else:
			print(current_player.player_name + " still cannot attack (" + str(attack_restrictions[current_player].turns) + " turns left)")
	
	# Clear summoning sickness
	for zone in current_player.frontline_zones + current_player.reserve_zones:
		for card in zone.cards:
			if card.card_type == Card.CardType.CREATURE:
				card.summoned_this_turn = false

	_begin_turn_upkeep()

func activate_prepared_hexes(defending_player: Player) -> void:
	for hex in prepared_hexes.keys():
		if hex.card_owner == defending_player and prepared_hexes[hex] < turn_number:
			hex.is_prepared = false

func _begin_turn_upkeep() -> void:
	if _upkeep_started_turn == turn_number:
		return
	_upkeep_started_turn = turn_number
	turn_upkeep_started.emit(turn_number, current_player)
	current_player.gain_mana(1)
	for card in _get_sorted_upkeep_cards_for_player(current_player, "on_turn_upkeep"):
		card.on_turn_upkeep(self)
	var opponent := get_opponent(current_player)
	if opponent != null:
		for card in _get_sorted_upkeep_cards_for_player(opponent, "on_opponent_turn_upkeep"):
			card.on_opponent_turn_upkeep(self, current_player)

func _resolve_turn_upkeep() -> void:
	if _upkeep_resolved_turn == turn_number:
		return
	_begin_turn_upkeep()
	_upkeep_resolved_turn = turn_number
	turn_upkeep_resolved.emit(turn_number, current_player)
	_notify_controller_turn_start(current_player)
	_notify_global_turn_start(current_player)
	turn_started.emit(turn_number, current_player)

# Checks all prepared hexes belonging to the defender's owner.
# If one can activate, it fires and returns true (combat should be cancelled).
func find_triggerable_hex(attacker: Card, defender: Card) -> HexCard:
	var defending_player := defender.get_controller()
	for hex in prepared_hexes.keys().duplicate():
		if hex.card_owner != defending_player:
			continue
		if prepared_hexes[hex] >= turn_number:
			continue
		if hex.is_activation_locked(self):
			continue
		if not (hex is HexCard):
			continue
		var typed_hex := hex as HexCard
		if not typed_hex.can_activate(attacker, defender):
			continue
		if is_guardian_protected(attacker, hex):
			return null
		return typed_hex
	return null

func has_target_immunity(target: Card, source: Card, immunity_kind: String) -> bool:
	if target == null or source == null:
		return false
	for status in target.active_statuses:
		if status.get("name", "") != "blessed_ward":
			continue
		if status.get("ward_kind", "") != immunity_kind:
			continue
		return true
	if immunity_kind == "hexes":
		var controller := target.get_controller()
		if controller == null:
			return false
		for zone in controller.frontline_zones + controller.reserve_zones:
			for card in zone.cards:
				if card is EnkiLordOfEridu and (card as EnkiLordOfEridu).protects_from_hex(target):
					return true
	return false

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
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if card is EnkiLordOfEridu and (card as EnkiLordOfEridu).protects_from_hex(target):
				return true
	return false

func activate_hex(hex: HexCard, attacker: Card, defender: Card) -> void:
	print(hex.card_name + " triggers!")
	last_hex_resolution_text = ""
	prepared_hexes.erase(hex)
	for affected_card in hex.get_affected_cards(attacker, defender):
		if _is_hex_immune(affected_card, hex):
			print(hex.card_name + " fizzles against " + affected_card.card_name + " due to hex immunity.")
			last_hex_resolution_text = "%s triggered, but %s was immune to hexes." % [hex.card_name, affected_card.card_name]
			hex.on_immune_activate(self, attacker, defender)
			return
	hex.on_activate(self, attacker, defender)

func check_and_trigger_hexes(attacker: Card, defender: Card) -> bool:
	var hex := find_triggerable_hex(attacker, defender)
	if hex:
		activate_hex(hex, attacker, defender)
		return true
	return false

func player_chooses_draw() -> void:
	if is_game_over:
		return
	_begin_turn_upkeep()
	current_player.draw_card()
	_resolve_turn_upkeep()

func player_chooses_mana() -> void:
	if is_game_over:
		return
	_begin_turn_upkeep()
	current_player.gain_mana(4)
	_resolve_turn_upkeep()

func player_chooses_upkeep_only() -> void:
	if is_game_over:
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
	if is_game_over:
		return false
	if card == null or not card.can_be_played(self, player):
		return false
	# Check if player can pay costs
	var mana_required := card.mana_cost
	if card_uses_summon_cost_rules(card):
		mana_required = get_card_summon_mana_cost(player, card)
	if not card.can_pay_costs_with_mana_cost(player, mana_required):
		print("Cannot afford card costs")
		return false

	# Speed 1 cards can only be played on your turn
	if card.get_effective_speed() == 1 and player != current_player:
		return false

	# God and power cards go to special zones
	if card.is_god and target_zone != player.god_zone:
		return false
	if card.is_power and not card.is_god and target_zone not in player.power_zones:
		return false

	# Regular cards go to frontline or reserve
	if not card.is_god and not card.is_power:
		if target_zone != null:
			if target_zone not in player.frontline_zones and target_zone not in player.reserve_zones:
				return false

	# One creature summon per turn
	if card.card_type == Card.CardType.CREATURE and player == current_player:
		if player.has_summoned_this_turn:
			return false

	# Equipment zone rules: unequipped equipment cannot share a zone with anything else.
	if target_zone != null and target_zone.is_board_zone():
		var unequipped_in_zone := target_zone.get_equipment()
		if card.card_type == Card.CardType.EQUIPMENT:
			# Equipment can only be played to an empty zone or a zone with exactly one creature (auto-equip)
			var has_unequipped := unequipped_in_zone.size() > 0
			var creature_in_zone := target_zone.get_creature()
			if has_unequipped:
				print("Cannot play equipment: zone already has unequipped equipment")
				return false
			if target_zone.cards.size() > 0 and creature_in_zone == null:
				print("Cannot play equipment: zone occupied by a non-creature card")
				return false
			if creature_in_zone != null and not card.can_equip_to(creature_in_zone):
				print("Cannot play equipment: target creature is not a valid bearer")
				return false
		else:
			# Non-equipment cards cannot enter a zone containing unequipped equipment
			if unequipped_in_zone.size() > 0:
				print("Cannot play card: zone contains unequipped equipment")
				return false

	return true

func can_prepare_card(player: Player, card: Card, target_zone: Zone) -> bool:
	if is_game_over:
		return false
	if player == null or card == null:
		return false
	if card.card_type not in [Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM]:
		return false
	if not card.can_prepare(self, player):
		return false
	if target_zone == null or not target_zone.is_board_zone():
		return false
	if target_zone.zone_owner != player:
		return false
	if target_zone not in player.frontline_zones and target_zone not in player.reserve_zones:
		return false
	if target_zone.cards.size() > 0:
		return false
	if target_zone.get_equipment().size() > 0:
		print("Cannot prepare card: zone contains unequipped equipment")
		return false
	return true

func play_card(player: Player, card: Card, target_zone: Zone, prepared: bool = false) -> void:
	if is_game_over:
		return
	var can_place := can_prepare_card(player, card, target_zone) if prepared else can_play_card(player, card, target_zone)
	if can_place:
		var from_zone := card.current_zone
		var entered_field_face_up_from_hand := (
			from_zone == player.hand_zone
			and target_zone != null
			and target_zone.is_board_zone()
			and not prepared
		)

		# Pay costs before playing
		var mana_required := card.mana_cost
		if card_uses_summon_cost_rules(card):
			mana_required = get_card_summon_mana_cost(player, card)
		if not card.pay_costs_with_mana_cost(player, mana_required, self):
			print("Failed to pay costs")
			return
		
		player.move_card(card, target_zone)
		card.is_prepared = prepared
		card.is_face_down = prepared

		# Auto-equip: if equipment is played to a zone with a creature, equip it
		if card.card_type == Card.CardType.EQUIPMENT:
			var creature_there := target_zone.get_creature()
			if creature_there != null:
				card.equip_to(creature_there)
				print(card.card_name + " equipped to " + creature_there.card_name)

		# Mark summoned
		if card.card_type == Card.CardType.CREATURE:
			player.has_summoned_this_turn = true
			card.summoned_this_turn = true	# Track summoning sickness for movement/mode change
			# Apply any active god passives to the newly placed creature
			_apply_god_passives_to_card(player, card)

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
		true,
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
	trigger_impact: bool = true
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
	if player == current_player and consume_turn_summon and player.has_summoned_this_turn:
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
	elif mana_required > 0 and not player.spend_mana(mana_required):
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
	card.summoned_this_turn = true
	if consume_turn_summon:
		player.has_summoned_this_turn = true

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
	if not face_down and trigger_impact and card.has_method("on_impact"):
		card.on_impact(self)
	card_summoned.emit(player, card, from_zone, target_zone, summon_source, face_down, stealth)

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

func creature_move(creature: Card, target_zone: Zone) -> bool:
	if is_game_over:
		return false
	if creature.card_type != Card.CardType.CREATURE:
		return false
	
	if creature.summoned_this_turn:
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
		creature.reveal_from_stealth(self)
		creature.card_owner.move_card(creature, target_zone)
		creature.spend_minor_creature_action(true)
		return true
	
	return false

func creature_change_mode(creature: Card, target_mode: int = -1) -> bool:
	if is_game_over:
		return false
	if creature.card_type != Card.CardType.CREATURE:
		return false
	
	if creature.summoned_this_turn:
		return false
	
	if not creature.can_take_minor_creature_action():
		return false
	
	var requested_mode: int = target_mode
	creature.reveal_from_stealth(self)
	if requested_mode == Card.CreatureMode.AGGRESSIVE or requested_mode == Card.CreatureMode.DEFENSIVE:
		creature.creature_mode = requested_mode as Card.CreatureMode
	elif creature.creature_mode == Card.CreatureMode.AGGRESSIVE:
		creature.creature_mode = Card.CreatureMode.DEFENSIVE
	else:
		creature.creature_mode = Card.CreatureMode.AGGRESSIVE

	creature.spend_minor_creature_action()
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
	
	if equipment.current_zone != creature.current_zone:
		return false
	
	equipment.equip_to(creature)
	creature.spend_major_creature_action()
	return true

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
	# Must be in frontline to act on out-of-range enemy equipment
	if is_enemy and not in_range and creature.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		return false
	if is_enemy:
		creature.spend_major_creature_action()
	else:
		creature.spend_minor_creature_action()
	# Move equipment to creature's zone and equip it
	equip_zone.remove_card(equipment)
	creature.current_zone.add_card(equipment)
	equipment.equip_to(creature)
	print(creature.card_name + " picks up " + equipment.card_name)
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
	creature.spend_major_creature_action()
	print(creature.card_name + " destroys " + equipment.card_name)
	_send_to_graveyard_with_hook(equipment, false, true)
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

	if attacker.is_stealth:
		attacker.reveal_from_stealth(self)
	var united_front_partner: Card = null
	if attacker.has_method("get_united_front_partner_for_attack"):
		united_front_partner = attacker.get_united_front_partner_for_attack(self)
	
	attacker.spend_major_creature_action()
	attacker.mark_attacked_this_turn()
	if united_front_partner != null:
		united_front_partner.reveal_from_stealth(self)
		united_front_partner.spend_major_creature_action()
		united_front_partner.mark_attacked_this_turn()
	
	if target is Card:
		if united_front_partner != null:
			resolve_united_front_combat(attacker, united_front_partner, target)
		else:
			resolve_combat(attacker, target)
	elif target is Player:
		resolve_followers_attack(_get_active_united_front_attackers(attacker, united_front_partner), target)

func resolve_followers_attack(attackers: Array[Card], defending_player: Player) -> int:
	if defending_player == null:
		return 0
	var active_attackers: Array[Card] = []
	for combatant in attackers:
		if combatant != null and combatant.current_zone != null and combatant.current_zone.is_board_zone():
			active_attackers.append(combatant)
	if active_attackers.is_empty():
		return 0

	var follower_damage := 0
	for combatant in active_attackers:
		follower_damage += combatant.get_effective_strength()
	if follower_damage > 0:
		defending_player.lose_followers(follower_damage)

	if active_attackers.size() >= 2:
		_notify_after_united_front_combat(active_attackers[0], active_attackers[1], null)
	else:
		_notify_after_combat(active_attackers[0], null)

	for combatant in active_attackers:
		_notify_opponent_attacks_followers(combatant, defending_player)

	return follower_damage

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
	minimum_distance = max(0, minimum_distance - defender.get_intercept_reach_bonus())
	return row_distance >= minimum_distance

func _can_interceptor_engage_attacker(interceptor: Card, attacker: Card) -> bool:
	if interceptor == null or attacker == null:
		return false
	if interceptor.has_method("can_engage") and not interceptor.can_engage(attacker):
		return false
	if attacker.has_method("can_be_engaged_by") and not attacker.can_be_engaged_by(interceptor):
		return false
	return true

func get_interceptor_speed_against_attacker(interceptor: Card, attacker: Card) -> int:
	if interceptor == null:
		return 0
	var interceptor_speed := interceptor.get_effective_speed()
	if attacker != null \
			and interceptor.has_type("Giant") \
			and not attacker.has_type("Giant") \
			and _has_giants_disdain(interceptor.get_controller()):
		interceptor_speed += 5
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
	if attacker.has_method("can_engage") and not attacker.can_engage(defender):
		print(attacker.card_name + " cannot engage " + defender.card_name + ".")
		if continue_callback.is_valid():
			continue_callback.call()
		return false
	if defender.has_method("can_be_engaged_by") and not defender.can_be_engaged_by(attacker):
		print(defender.card_name + " cannot be engaged by " + attacker.card_name + ".")
		if continue_callback.is_valid():
			continue_callback.call()
		return false
	attacker.reveal_from_stealth(self)
	defender.reveal_from_stealth(self)
	var attacker_controller := attacker.get_controller()
	var defender_controller := defender.get_controller()
	var finish := func() -> void:
		_notify_after_combat(attacker, defender)
		if continue_callback.is_valid():
			continue_callback.call()
	if defender.is_god:
		# Gods cannot be targeted in combat — redirect to follower damage
		defender_controller.lose_followers(attacker.get_effective_strength())
		print(attacker.card_name + " attacks " + defender_controller.player_name + "'s followers for " + str(attacker.get_effective_strength()) + " (via god)!")
		finish.call()
		return true
	if attacker.has_method("on_attack") and not attacker.abilities_suppressed():
		attacker.on_attack(self, defender)
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
				var diff = attacker_str - defender_str_for_damage
				print("	" + defender.card_name + " destroyed! " + defender_controller.player_name + " loses " + str(diff) + " followers")
				defender_controller.lose_followers(diff)
				_combat_kill(attacker, defender)
			elif defender_str_real > attacker_str:
				var diff = defender_str_real - attacker_str_for_damage
				print("	" + attacker.card_name + " destroyed! " + attacker_controller.player_name + " loses " + str(diff) + " followers")
				attacker_controller.lose_followers(diff)
				_combat_kill(defender, attacker)
			else:	# Tie — pre-compute routing before either card moves zones
				print("	Tie! Both creatures destroyed")
				var void_attacker := _should_class_rend(defender, attacker)
				var void_defender := _should_class_rend(attacker, defender)
				_combat_kill_routed(defender, attacker, void_attacker)
				_combat_kill_routed(attacker, defender, void_defender)
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
				if _ferocious_defence_triggers(defender, attacker_str_vs_res):
					print("	Ferocious Defence! " + attacker.card_name + " destroyed!")
					_combat_kill(defender, attacker)
				else:
					# Followers convert using the defender's full resilience, with Giant's Disdain reducing only the opposing attack stat.
					var diff_damage: int = maxi(0, defender_res_real - attacker_str_for_conversion)
					var diff_gain: int = defender_res_real - attacker_str_vs_res
					print("	" + str(diff_damage) + " followers convert to " + defender_controller.player_name)
					attacker_controller.lose_followers(diff_damage)
					defender_controller.gain_followers(diff_damage)
					if diff_gain != diff_damage:
						print("\t(disdain adjusted conversion from %d to %d)" % [diff_gain, diff_damage])
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
	primary.reveal_from_stealth(self)
	support.reveal_from_stealth(self)
	defender.reveal_from_stealth(self)
	var attacker_controller := primary.get_controller()
	var defender_controller := defender.get_controller()
	for combatant in active_attackers:
		if combatant.has_method("on_attack") and not combatant.abilities_suppressed():
			combatant.on_attack(self, defender)
	if defender.has_method("on_defend") and not defender.abilities_suppressed():
		defender.on_defend(self, primary)
	var combined_strength := primary.get_effective_strength() + support.get_effective_strength()

	if defender.is_god:
		defender_controller.lose_followers(combined_strength)
		print("%s and %s attack %s's followers for %d!" % [primary.card_name, support.card_name, defender_controller.player_name, combined_strength])
		_notify_after_united_front_combat(attacker, partner, defender)
		return

	print("=== UNITED FRONT COMBAT: %s + %s (STR:%d) vs %s ===" % [primary.card_name, support.card_name, combined_strength, defender.card_name])

	if defender.is_petrified() or defender.card_type == Card.CardType.STRUCTURE:
		var defender_res := defender.get_effective_resilience()
		print("	STR vs Structure RES: %d vs %d" % [combined_strength, defender_res])
		if combined_strength > defender_res:
			print("	Structure destroyed!")
			_combat_kill(primary, defender)
		_notify_after_united_front_combat(attacker, partner, defender)
		return

	if defender.card_type == Card.CardType.CREATURE:
		if defender.creature_mode == Card.CreatureMode.AGGRESSIVE:
			var defender_str_real: int = defender.get_effective_strength()
			var defender_str_for_damage: int = _get_giants_disdain_damage_stat(defender, active_attackers, defender_str_real)
			var combined_strength_for_damage: int = _get_giants_disdain_combined_strength_for_damage(active_attackers, defender)
			print("	Combined STR vs STR: %d vs %d" % [combined_strength, defender_str_real])
			if combined_strength > defender_str_real:
				var diff := combined_strength - defender_str_for_damage
				print("	%s destroyed! %s loses %d followers" % [defender.card_name, defender_controller.player_name, diff])
				defender_controller.lose_followers(diff)
				_combat_kill(primary, defender)
			elif defender_str_real > combined_strength:
				var diff := defender_str_real - combined_strength_for_damage
				print("	United Front loses! %s loses %d followers" % [attacker_controller.player_name, diff])
				note_player_feedback("United Front loses! Both attackers are destroyed.")
				attacker_controller.lose_followers(diff)
				_combat_kill(defender, primary)
				_combat_kill(defender, support)
			else:
				print("	Tie! Both united attackers and the defender are destroyed")
				var void_primary := _should_class_rend(defender, primary)
				var void_support := _should_class_rend(defender, support)
				var void_defender := _should_class_rend(primary, defender)
				_combat_kill_routed(defender, primary, void_primary)
				_combat_kill_routed(defender, support, void_support)
				_combat_kill_routed(primary, defender, void_defender)
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
				if _ferocious_defence_triggers(defender, attacker_str_vs_res):
					print("	Ferocious Defence! United Front attackers destroyed!")
					_combat_kill(defender, primary)
					_combat_kill(defender, support)
				else:
					var diff_damage: int = maxi(0, defender_res_real - attacker_str_for_conversion)
					print("	%d followers convert to %s" % [diff_damage, defender_controller.player_name])
					attacker_controller.lose_followers(diff_damage)
					defender_controller.gain_followers(diff_damage)
			else:
				print("	Exact match - no effect")
	elif defender.card_type == Card.CardType.EQUIPMENT and defender.equipped_on == null:
		print("	Equipment destroyed!")
		_combat_kill(primary, defender)
	_notify_after_united_front_combat(attacker, partner, defender)

func resolve_combat_with_continuation(
	attacker: Card,
	defender: Card,
	continue_callback: Callable = Callable(),
	interceptor_initiates: bool = false
) -> bool:
	if attacker == null or defender == null:
		return false
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
		if attacker.has_method("can_engage") and not attacker.can_engage(defender):
			print(attacker.card_name + " cannot engage " + defender.card_name + ".")
			if continue_callback.is_valid():
				continue_callback.call()
			return false
		if defender.has_method("can_be_engaged_by") and not defender.can_be_engaged_by(attacker):
			print(defender.card_name + " cannot be engaged by " + attacker.card_name + ".")
			if continue_callback.is_valid():
				continue_callback.call()
			return false
	attacker.reveal_from_stealth(self)
	defender.reveal_from_stealth(self)
	var attacker_controller := attacker.get_controller()
	var defender_controller := defender.get_controller()
	var finish := func() -> void:
		_notify_after_combat(attacker, defender)
		if continue_callback.is_valid():
			continue_callback.call()
	if defender.is_god:
		defender_controller.lose_followers(attacker.get_effective_strength())
		print(attacker.card_name + " attacks " + defender_controller.player_name + "'s followers for " + str(attacker.get_effective_strength()) + " (via god)!")
		_notify_opponent_attacks_followers(attacker, defender_controller)
		finish.call()
		return true
	if attacker.has_method("on_attack") and not attacker.abilities_suppressed():
		attacker.on_attack(self, defender)
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
				var diff := attacker_str - defender_str_for_damage
				print("	" + defender.card_name + " destroyed! " + defender_controller.player_name + " loses " + str(diff) + " followers")
				defender_controller.lose_followers(diff)
				return _combat_kill_deferred(attacker, defender, finish)
			if defender_str_real > attacker_str:
				var diff := defender_str_real - attacker_str_for_damage
				print("	" + attacker.card_name + " destroyed! " + attacker_controller.player_name + " loses " + str(diff) + " followers")
				attacker_controller.lose_followers(diff)
				return _combat_kill_deferred(defender, attacker, finish)
			print("	Tie! Both creatures destroyed")
			return _combat_kill_sequence_deferred([
				{"killer": defender, "victim": attacker, "do_void": _should_class_rend(defender, attacker)},
				{"killer": attacker, "victim": defender, "do_void": _should_class_rend(attacker, defender)},
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
			if _ferocious_defence_triggers(defender, attacker_str_vs_res):
				print("	Ferocious Defence! " + attacker.card_name + " destroyed!")
				return _combat_kill_deferred(defender, attacker, finish)
			var diff_damage: int = maxi(0, defender_res_real - attacker_str_for_conversion)
			print("	" + str(diff_damage) + " followers convert to " + defender_controller.player_name)
			attacker_controller.lose_followers(diff_damage)
			defender_controller.gain_followers(diff_damage)
	elif defender.card_type == Card.CardType.EQUIPMENT and defender.equipped_on == null:
		print("	Equipment destroyed!")
		return _combat_kill_deferred(attacker, defender, finish)
	finish.call()
	return true

func _combat_kill_deferred(killer: Card, victim: Card, continue_callback: Callable = Callable()) -> bool:
	return _combat_kill_routed_deferred(killer, victim, _should_class_rend(killer, victim), continue_callback)

func _combat_kill_routed_deferred(killer: Card, victim: Card, do_void: bool, continue_callback: Callable = Callable()) -> bool:
	var killer_controller := killer.get_controller() if killer != null else null
	var victim_controller := victim.get_controller()
	var finish := func() -> void:
		var victim_counts_as_creature_kill := victim != null and victim.card_type == Card.CardType.CREATURE and not victim.is_petrified()
		var victim_counts_as_attack_target_destroy := victim != null \
			and killer_controller != null \
			and victim_controller != null \
			and victim_controller != killer_controller
		if killer != null and killer.has_method("on_kill") and not killer.abilities_suppressed() and victim_counts_as_creature_kill:
			killer.on_kill(self, victim)
		if victim_counts_as_attack_target_destroy:
			combat_destroy_events_this_turn.append({
				"killer_owner": killer_controller,
				"victim_owner": victim_controller,
				"killer": killer,
				"victim": victim,
			})
		if killer != null and killer_controller != null and victim_controller != killer_controller and victim_counts_as_creature_kill:
			for zone in killer_controller.frontline_zones + killer_controller.reserve_zones:
				for card in zone.cards:
					if card.has_method("on_ally_kill") and not card.abilities_suppressed():
						card.on_ally_kill(self, killer, victim)
		if continue_callback.is_valid():
			continue_callback.call()
	if do_void:
		print("Class Rend! " + killer.card_name + " voids " + victim.card_name + "!")
		if victim.current_zone and victim.current_zone.is_board_zone():
			victim.last_board_zone_type  = victim.current_zone.zone_type
			victim.last_board_zone_index = victim.current_zone.zone_index
		if victim.has_method("on_removed") and not victim.abilities_suppressed():
			victim.on_removed(self)
		if victim.has_method("on_death") and not victim.abilities_suppressed():
			victim.on_death(self)
		died_this_turn.append(victim)
		for equip in victim.equipment.duplicate():
			_send_to_abyss_with_hook(equip)
		victim.card_owner.move_card(victim, victim.card_owner.abyss_zone)
		finish.call()
		return true
	return request_send_to_graveyard(victim, finish, true, true)

func _combat_kill_sequence_deferred(kills: Array[Dictionary], continue_callback: Callable = Callable()) -> bool:
	if kills.is_empty():
		if continue_callback.is_valid():
			continue_callback.call()
		return true
	var next_kills: Array[Dictionary] = kills.duplicate()
	var kill: Dictionary = next_kills.pop_front()
	return _combat_kill_routed_deferred(
		kill.get("killer", null),
		kill.get("victim", null),
		kill.get("do_void", false) == true,
		func() -> void:
			_combat_kill_sequence_deferred(next_kills, continue_callback)
	)

func _notify_after_combat(attacker: Card, defender: Card) -> void:
	if attacker != null and attacker.has_method("on_after_combat"):
		attacker.on_after_combat(self, defender)
	if defender != null and defender.has_method("on_after_combat"):
		defender.on_after_combat(self, attacker)
	for player in players:
		for zone in player.power_zones:
			for card in zone.cards:
				if card.has_method("on_creature_after_combat"):
					card.on_creature_after_combat(self, attacker, defender)
	_expire_after_combat_effects(attacker)
	_expire_after_combat_effects(defender)

func _notify_after_united_front_combat(attacker: Card, partner: Card, defender: Card) -> void:
	_notify_after_combat(attacker, defender)
	if partner != null and partner != attacker and partner.has_method("on_after_combat"):
		partner.on_after_combat(self, defender)
	_expire_after_combat_effects(partner)

func _expire_after_combat_effects(card: Card) -> void:
	if card == null:
		return
	card.remove_effects_expiring_after_combat()

func _get_active_united_front_attackers(attacker: Card, partner: Card) -> Array[Card]:
	var active_attackers: Array[Card] = []
	var controller := attacker.get_controller() if attacker != null else null
	for candidate in [attacker, partner]:
		if candidate == null:
			continue
		if candidate.current_zone == null or not candidate.current_zone.is_board_zone():
			continue
		if controller != null and candidate.get_controller() != controller:
			continue
		if candidate.card_type != Card.CardType.CREATURE:
			continue
		active_attackers.append(candidate)
	return active_attackers

func add_to_stack(action: CardAction) -> void:
	action_stack.append(action)

func resolve_stack() -> void:
	while action_stack.size() > 0:
		var action = action_stack.pop_back()
		action.resolve()
		
func convert_followers(from_player: Player, to_player: Player, amount: int) -> void:
	var actual: int = mini(amount, from_player.followers)
	from_player.lose_followers(actual)
	to_player.gain_followers(actual)
	print("Convert! " + str(actual) + " followers move from " + from_player.player_name + " to " + to_player.player_name)

func apply_attack_restriction(player: Player, turns: int, source: Card = null) -> void:
	attack_restrictions[player] = {turns = turns, source = source}
	print(player.player_name + " cannot attack for " + str(turns) + " turns!")

func remove_attack_restriction(player: Player) -> void:
	if attack_restrictions.has(player):
		attack_restrictions.erase(player)
		print(player.player_name + " attack restriction removed!")

# Turn lifecycle order is intentionally explicit:
# 1. Fire controller turn-end hooks for the ending player's permanents.
# 2. Fire global turn-end hooks for all permanents.
# 3. Emit turn_ended and clear end-of-turn expiring statuses.
# 4. Swap active/other players.
# 5. Begin the next turn immediately.
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
	
	# Swap players for the next turn
	var temp = current_player
	current_player = other_player
	other_player = temp
	turn_player = current_player
	current_player.is_turn_player = true
	other_player.is_turn_player = false
	start_turn()

func _get_player_turn_event_cards(player: Player, include_god: bool = true) -> Array[Card]:
	var cards: Array[Card] = []
	if player == null:
		return cards
	var zones: Array[Zone] = []
	if include_god:
		zones.append(player.god_zone)
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

func notify_god_power_activated(player: Player, god: Card, target: Card = null) -> void:
	if player == null or god == null:
		return
	for zone in player.frontline_zones + player.reserve_zones:
		for card in zone.cards.duplicate():
			if card != null and card.has_method("on_friendly_god_power_activated"):
				card.on_friendly_god_power_activated(self, god, target)
	god_power_activated.emit(turn_number, player, god, target)


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
	if source != null and not source.targets:
		return false
	if target != null and target.has_status_effect("en_hedu_anna_exaltation_guard"):
		return true
	var target_controller := target.get_controller()
	if target_controller == null:
		return false
	if not (current_phase == GamePhase.COMBAT or current_player == target_controller):
		return false
	if not target.has_type("Ancient Creature"):
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
func _combat_kill_routed(killer: Card, victim: Card, do_void: bool) -> void:
	var killer_controller := killer.get_controller() if killer != null else null
	var victim_controller := victim.get_controller()
	var finish := func() -> void:
		var victim_counts_as_creature_kill := victim != null and victim.card_type == Card.CardType.CREATURE and not victim.is_petrified()
		var victim_counts_as_attack_target_destroy := victim != null \
			and killer_controller != null \
			and victim_controller != null \
			and victim_controller != killer_controller
		if killer != null and killer.has_method("on_kill") and not killer.abilities_suppressed() and victim_counts_as_creature_kill:
			killer.on_kill(self, victim)
		if victim_counts_as_attack_target_destroy:
			combat_destroy_events_this_turn.append({
				"killer_owner": killer_controller,
				"victim_owner": victim_controller,
				"killer": killer,
				"victim": victim,
			})
		if killer != null and killer_controller != null and victim_controller != killer_controller and victim_counts_as_creature_kill:
			for zone in killer_controller.frontline_zones + killer_controller.reserve_zones:
				for card in zone.cards:
					if card.has_method("on_ally_kill") and not card.abilities_suppressed():
						card.on_ally_kill(self, killer, victim)
	if do_void:
		print("Class Rend! " + killer.card_name + " voids " + victim.card_name + "!")
		if victim.current_zone and victim.current_zone.is_board_zone():
			victim.last_board_zone_type  = victim.current_zone.zone_type
			victim.last_board_zone_index = victim.current_zone.zone_index
		if victim.has_method("on_removed") and not victim.abilities_suppressed():
			victim.on_removed(self)
		if victim.has_method("on_death") and not victim.abilities_suppressed():
			victim.on_death(self)
		died_this_turn.append(victim)
		for equip in victim.equipment.duplicate():
			_send_to_abyss_with_hook(equip)
		victim.card_owner.move_card(victim, victim.card_owner.abyss_zone)
		finish.call()
		return
	request_send_to_graveyard(victim, finish, true, true)

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

func request_send_to_graveyard(card: Card, continue_callback: Callable = Callable(), combat_death: bool = false, destruction: bool = false) -> bool:
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
		_pending_doorway_continue = continue_callback
		doorway_choice_requested.emit(_pending_doorway_structure, card, combat_death, destruction)
		return false
	var success := _send_to_graveyard_with_hook_resolved(card, false, combat_death, destruction)
	if continue_callback.is_valid():
		continue_callback.call()
	return success

func _send_to_graveyard_with_hook_resolved(card: Card, send_to_abyss: bool, combat_death: bool = false, destruction: bool = false) -> bool:
	if destruction and (
		card.has_status_effect("berserker_rage_guard")
		or card.has_status_effect("berserker_mead_guard")
		or card.has_status_effect("en_hedu_anna_exaltation_guard")
	):
		print(card.card_name + " resists destruction this turn.")
		return false
	# Record board position before the zone changes so Circle of Rebirth can
	# auto-resurrect to the same spot.
	if card.current_zone and card.current_zone.is_board_zone():
		card.last_board_zone_type  = card.current_zone.zone_type
		card.last_board_zone_index = card.current_zone.zone_index

	var replacement_zone: Zone = null
	if card.has_method("get_self_graveyard_replacement_zone") and not card.abilities_suppressed() \
			and not _is_watchbeast_active():
		replacement_zone = card.get_self_graveyard_replacement_zone(self, combat_death, destruction, send_to_abyss)

	if card.has_method("on_removed") and not card.abilities_suppressed():
		card.on_removed(self)
	if combat_death and card.has_method("on_death") and not card.abilities_suppressed():
		card.on_death(self)

	died_this_turn.append(card)
	if replacement_zone != null:
		card.card_owner.move_card(card, replacement_zone)
		if replacement_zone == card.card_owner.hand_zone:
			print("%s returns to %s's hand instead." % [card.card_name, card.card_owner.player_name])
		return true
	if send_to_abyss:
		card.card_owner.move_card(card, card.card_owner.abyss_zone)
	else:
		card.card_owner.move_card(card, card.card_owner.graveyard_zone)
	return true

func has_pending_doorway_choice() -> bool:
	return _pending_doorway_structure != null and _pending_doorway_card != null

func resolve_pending_doorway_choice(send_to_abyss: bool) -> bool:
	if not has_pending_doorway_choice():
		return false
	var card := _pending_doorway_card
	var combat_death := _pending_doorway_combat_death
	var destruction := _pending_doorway_destruction
	var continue_callback := _pending_doorway_continue
	if send_to_abyss:
		_clear_pending_doorway_choice()
		var abyss_success := _send_to_graveyard_with_hook_resolved(card, true, combat_death, destruction)
		if continue_callback.is_valid():
			continue_callback.call()
		return abyss_success
	if _advance_pending_doorway_choice():
		return false
	_clear_pending_doorway_choice()
	var graveyard_success := _send_to_graveyard_with_hook_resolved(card, false, combat_death, destruction)
	if continue_callback.is_valid():
		continue_callback.call()
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
	_pending_doorway_continue = Callable()
func banish_card_with_hook(card: Card) -> void:
	_send_to_abyss_with_hook(card)

func _send_to_abyss_with_hook(card: Card) -> void:
	if card.has_method("on_removed") and not card.abilities_suppressed():
		card.on_removed(self)
	card.card_owner.move_card(card, card.card_owner.abyss_zone)

func send_to_deck_bottom_with_hook(card: Card) -> void:
	if card.current_zone != null and card.current_zone.is_board_zone():
		if card.has_method("on_removed") and not card.abilities_suppressed():
			card.on_removed(self)
	card.card_owner.move_card(card, card.card_owner.deck_zone)

func _on_player_card_moved(card: Card, from_zone: Zone, to_zone: Zone) -> void:
	if card == null or from_zone == null or to_zone == null:
		return
	if from_zone.is_board_zone() and not to_zone.is_board_zone():
		card.board_entry_order = -1
	elif not from_zone.is_board_zone() and to_zone.is_board_zone():
		_ensure_board_entry_order(card)
	if prepared_hexes.has(card) and (to_zone == null or not to_zone.is_board_zone() or not card.is_prepared):
		prepared_hexes.erase(card)
	if prepared_charms.has(card) and (to_zone == null or not to_zone.is_board_zone() or not card.is_prepared):
		prepared_charms.erase(card)
	if card.card_type == Card.CardType.CREATURE:
		if from_zone.zone_type == Zone.ZoneType.ABYSS and to_zone.is_board_zone():
			_notify_creature_returned_from_void(card)
		elif to_zone.zone_type == Zone.ZoneType.ABYSS:
			_notify_creature_sent_to_void(card)
	_notify_board_cards_of_movement(card, from_zone, to_zone)

func _notify_board_cards_of_movement(moved_card: Card, from_zone: Zone, to_zone: Zone) -> void:
	for player in players:
		for zone in [player.god_zone] + player.power_zones + player.frontline_zones + player.reserve_zones:
			for board_card in zone.cards.duplicate():
				if board_card != null and board_card.has_method("on_any_card_moved"):
					board_card.on_any_card_moved(self, moved_card, from_zone, to_zone)

func _notify_creature_sent_to_void(creature: Card) -> void:
	for power in _get_active_powers():
		if power.has_method("on_creature_sent_to_void"):
			power.on_creature_sent_to_void(creature, self)

func _notify_creature_returned_from_void(creature: Card) -> void:
	for power in _get_active_powers():
		if power.has_method("on_creature_returned_from_void"):
			power.on_creature_returned_from_void(creature, self)

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
	var claimed := false
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
	return entries

func _get_cost_adjustment_source_cards() -> Array[Card]:
	var sources: Array[Card] = []
	for player in players:
		for card in player.god_zone.cards:
			if _can_source_adjust_costs(card):
				sources.append(card)
		for zone in player.power_zones + player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _can_source_adjust_costs(card):
					sources.append(card)
	return sources

func _can_source_adjust_costs(card: Card) -> bool:
	if card == null or card.current_zone == null or card.card_owner == null:
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
		for zone in player.power_zones:
			if zone.cards.is_empty():
				continue
			var power := zone.cards[0] as PowerCard
			if power != null and power.is_effectively_active():
				active_powers.append(power)
	return active_powers

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
	return maxi(0, int(floor(float(base_stat) / 2.0)))

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
	return _has_ferocious_defence(defender.get_controller()) and defender.get_effective_resilience() > opposing_strength

func _get_active_structures() -> Array[StructureCard]:
	var active_structures: Array[StructureCard] = []
	for player in players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				var structure := card as StructureCard
				if structure != null and not structure.abilities_suppressed():
					active_structures.append(structure)
	return active_structures

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

func _on_player_defeated(defeated_player: Player) -> void:
	if is_game_over or defeated_player == null:
		return
	losing_player = defeated_player
	winning_player = get_opponent(defeated_player)
	is_game_over = true
	_set_phase(GamePhase.END)
	if winning_player != null:
		print(winning_player.player_name + " wins the game! " + defeated_player.player_name + " reached 0 followers.")
	else:
		print("Game over! " + defeated_player.player_name + " reached 0 followers.")
	game_ended.emit(winning_player, losing_player)
