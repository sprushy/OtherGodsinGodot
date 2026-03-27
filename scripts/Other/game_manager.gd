# GameManager.gd - Complete Version with Robust Player Identification
extends Node
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

enum GamePhase { MULLIGAN, MAIN, COMBAT, END }

var players: Array[Player] = []
var current_player: Player
var other_player: Player
var turn_player: Player
var feedback_viewer: Player
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
	var resolved_phase := current_phase if phase < 0 else phase
	var phase_names := GamePhase.keys()
	if resolved_phase < 0 or resolved_phase >= phase_names.size():
		return "UNKNOWN"
	return phase_names[resolved_phase]

func _set_phase(new_phase: int) -> void:
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

# Returns eligible speed-2+ responses the given player can play against the top stack action.
func get_priority_responses(player: Player) -> Array:
	var responses: Array = []
	if action_stack.is_empty():
		return responses
	for card in player.god_zone.cards:
		if can_card_respond_to_priority(card, player):
			responses.append(card)
	for zone in player.power_zones + player.frontline_zones + player.reserve_zones:
		for card in zone.cards:
			if can_card_respond_to_priority(card, player):
				responses.append(card)
	for hex in prepared_hexes.keys().duplicate():
		if can_card_respond_to_priority(hex, player):
			responses.append(hex)
	for charm in prepared_charms.keys().duplicate():
		if can_card_respond_to_priority(charm, player):
			responses.append(charm)
	for c in player.hand_zone.cards:
		if can_card_respond_to_priority(c, player):
			responses.append(c)
	return responses

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

func is_prepared_charm_ready(charm: CharmCard, triggering_action: CardAction = null) -> bool:
	if charm == null:
		return false
	if not prepared_charms.has(charm):
		return false
	var prepared_turn: int = int(prepared_charms.get(charm, turn_number))
	return prepared_turn < turn_number

func setup_game() -> void:
	players = []
	is_game_over = false
	winning_player = null
	losing_player = null
	for child in get_children():
		if child is Player:
			players.append(child)
			var player := child as Player
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

# -----------------------------------

func start_mulligan() -> void:
	_set_phase(GamePhase.MULLIGAN)
	offer_mulligan(current_player, 5, 0)
	offer_mulligan(other_player, 5, 2)

func offer_mulligan(player: Player, card_count: int, bonus_mana: int) -> void:
	# UI driven - draw card_count cards
	# For each card not kept, give player 4 mana
	# Add bonus_mana
	pass

# Turn lifecycle order is intentionally explicit:
# 1. Officially begin the new turn and increment turn_number.
# 2. Reset once-per-turn state for the active player.
# 3. Fire controller turn-start hooks for the active player's non-god permanents.
# 4. Fire global turn-start hooks for all permanents.
# 5. Emit turn_started.
# 6. Later, when the player chooses draw/mana, resolve upkeep exactly once.
func start_turn() -> void:
	if is_game_over:
		return
	turn_player = current_player
	turn_number += 1
	_set_phase(GamePhase.MAIN)
	died_this_turn.clear()
	pending_resurrections.clear()
	combat_destroy_events_this_turn.clear()

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
	
	_notify_controller_turn_start(current_player)
	_notify_global_turn_start(current_player)
	turn_started.emit(turn_number, current_player)

func activate_prepared_hexes(defending_player: Player) -> void:
	for hex in prepared_hexes.keys():
		if hex.card_owner == defending_player and prepared_hexes[hex] < turn_number:
			hex.is_prepared = false

func _resolve_turn_upkeep() -> void:
	if _upkeep_resolved_turn == turn_number:
		return
	_upkeep_resolved_turn = turn_number
	turn_upkeep_started.emit(turn_number, current_player)
	for card in current_player.god_zone.cards:
		if card.has_method("on_turn_upkeep"):
			card.on_turn_upkeep(self)
		elif card.has_method("on_turn_start"):
			card.on_turn_start(self)
	turn_upkeep_resolved.emit(turn_number, current_player)

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
	return false

func is_immune_to_source(target: Card, source: Card) -> bool:
	if target == null or source == null:
		return false
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
	_resolve_turn_upkeep()
	current_player.draw_card()
	current_player.gain_mana(1)

func player_chooses_mana() -> void:
	if is_game_over:
		return
	_resolve_turn_upkeep()
	current_player.gain_mana(5)

func can_play_card(player: Player, card: Card, target_zone: Zone) -> bool:
	if is_game_over:
		return false
	# Check if player can pay costs
	if not card.can_pay_costs(player):
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
		else:
			# Non-equipment cards cannot enter a zone containing unequipped equipment
			if unequipped_in_zone.size() > 0:
				print("Cannot play card: zone contains unequipped equipment")
				return false

	return true

func play_card(player: Player, card: Card, target_zone: Zone, prepared: bool = false) -> void:
	if is_game_over:
		return
	if can_play_card(player, card, target_zone):
		var from_zone := card.current_zone
		var entered_field_face_up_from_hand := (
			from_zone == player.hand_zone
			and target_zone != null
			and target_zone.is_board_zone()
			and not prepared
		)

		# Pay costs before playing
		if not card.pay_costs(player, self):
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

		if entered_field_face_up_from_hand and card.has_method("on_impact"):
			card.on_impact(self)
		
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
		card.is_stealth = true
		card.is_face_down = true
		card.creature_mode = Card.CreatureMode.DEFENSIVE
		play_card(player, card, target_zone)

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
		creature.creature_mode = requested_mode
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
	
	if creature.card_type != Card.CardType.CREATURE:
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
	if creature.card_type != Card.CardType.CREATURE:
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
		var attackers: Array[Card] = _get_active_united_front_attackers(attacker, united_front_partner)
		var total_strength := 0
		for combatant in attackers:
			total_strength += combatant.get_effective_strength()
		if total_strength <= 0:
			total_strength = attacker.get_effective_strength()
		target.lose_followers(total_strength)
		_notify_after_united_front_combat(attacker, united_front_partner, null)

func _can_intercept_followers(defender: Card, attacker: Card) -> bool:
	if defender == null or attacker == null:
		return false
	if defender.card_type != Card.CardType.CREATURE:
		return false
	if defender.is_sleeping:
		return false
	if defender.get_effective_speed() < attacker.get_effective_speed():
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
		if not defender.can_take_major_creature_action():
			return false
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
			# Strength vs Strength
			var defender_str = defender.get_effective_strength()
			print("	STR vs STR: " + str(attacker_str) + " vs " + str(defender_str))
			
			if attacker_str > defender_str:
				var diff = attacker_str - defender_str
				print("	" + defender.card_name + " destroyed! " + defender_controller.player_name + " loses " + str(diff) + " followers")
				defender_controller.lose_followers(diff)
				_combat_kill(attacker, defender)
			elif defender_str > attacker_str:
				var diff = defender_str - attacker_str
				print("	" + attacker.card_name + " destroyed! " + attacker_controller.player_name + " loses " + str(diff) + " followers")
				attacker_controller.lose_followers(diff)
				_combat_kill(defender, attacker)
			else:	# Tie — pre-compute routing before either card moves zones
				print("	Tie! Both creatures destroyed")
				var void_attacker := _should_class_rend(defender, attacker)
				var void_defender := _should_class_rend(attacker, defender)
				_combat_kill_routed(defender, attacker, void_attacker)
				_combat_kill_routed(attacker, defender, void_defender)
		else:	# Defensive stance
			var vs_defense_bonus := 0
			for equip in attacker.equipment:
				if equip is EquipmentCard:
					vs_defense_bonus += equip.get_bonus_strength_vs_defense(attacker)
			var attacker_str_vs_res: int = attacker_str + vs_defense_bonus
			var defender_res: int = defender.get_effective_resilience()
			print("	STR vs RES: " + str(attacker_str_vs_res) + " vs " + str(defender_res))

			if attacker_str_vs_res > defender_res:
				print("	" + defender.card_name + " destroyed!")
				_combat_kill(attacker, defender)
			elif attacker_str_vs_res < defender_res:
				# Followers convert to defender's side
				var diff: int = defender_res - attacker_str_vs_res
				print("	" + str(diff) + " followers convert to " + defender_controller.player_name)
				attacker_controller.lose_followers(diff)
				defender_controller.gain_followers(diff)
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
			var defender_str := defender.get_effective_strength()
			print("	Combined STR vs STR: %d vs %d" % [combined_strength, defender_str])
			if combined_strength > defender_str:
				var diff := combined_strength - defender_str
				print("	%s destroyed! %s loses %d followers" % [defender.card_name, defender_controller.player_name, diff])
				defender_controller.lose_followers(diff)
				_combat_kill(primary, defender)
			elif defender_str > combined_strength:
				var diff := defender_str - combined_strength
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
			var defender_res := defender.get_effective_resilience()
			print("	Combined STR vs RES: %d vs %d" % [attacker_str_vs_res, defender_res])
			if attacker_str_vs_res > defender_res:
				print("	%s destroyed!" % defender.card_name)
				_combat_kill(primary, defender)
			elif attacker_str_vs_res < defender_res:
				var diff := defender_res - attacker_str_vs_res
				print("	%d followers convert to %s" % [diff, defender_controller.player_name])
				attacker_controller.lose_followers(diff)
				defender_controller.gain_followers(diff)
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
		finish.call()
		return true
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
			var defender_str := defender.get_effective_strength()
			print("	STR vs STR: " + str(attacker_str) + " vs " + str(defender_str))
			if attacker_str > defender_str:
				var diff := attacker_str - defender_str
				print("	" + defender.card_name + " destroyed! " + defender_controller.player_name + " loses " + str(diff) + " followers")
				defender_controller.lose_followers(diff)
				return _combat_kill_deferred(attacker, defender, finish)
			if defender_str > attacker_str:
				var diff := defender_str - attacker_str
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
		var defender_res: int = defender.get_effective_resilience()
		print("	STR vs RES: " + str(attacker_str_vs_res) + " vs " + str(defender_res))
		if attacker_str_vs_res > defender_res:
			print("	" + defender.card_name + " destroyed!")
			return _combat_kill_deferred(attacker, defender, finish)
		if attacker_str_vs_res < defender_res:
			var diff: int = defender_res - attacker_str_vs_res
			print("	" + str(diff) + " followers convert to " + defender_controller.player_name)
			attacker_controller.lose_followers(diff)
			defender_controller.gain_followers(diff)
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
		if killer != null and killer.has_method("on_kill") and not killer.abilities_suppressed() and victim_counts_as_creature_kill:
			killer.on_kill(self, victim)
		if killer_controller != null and victim_counts_as_creature_kill:
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

func _notify_after_united_front_combat(attacker: Card, partner: Card, defender: Card) -> void:
	_notify_after_combat(attacker, defender)
	if partner != null and partner != attacker and partner.has_method("on_after_combat"):
		partner.on_after_combat(self, defender)

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
	for card in _get_player_turn_event_cards(player, false):
		if card.has_method("on_turn_start"):
			card.on_turn_start(self)

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
		if killer != null and killer.has_method("on_kill") and not killer.abilities_suppressed() and victim_counts_as_creature_kill:
			killer.on_kill(self, victim)
		if killer_controller != null and victim_counts_as_creature_kill:
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
		if event.get("killer_owner", null) == player and event.get("victim_owner", null) != player:
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
	if card.has_method("get_self_graveyard_replacement_zone") and not card.abilities_suppressed():
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

func _get_active_structures() -> Array[StructureCard]:
	var active_structures: Array[StructureCard] = []
	for player in players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				var structure := card as StructureCard
				if structure != null and not structure.abilities_suppressed():
					active_structures.append(structure)
	return active_structures

func _get_graveyard_replacement_sources(card: Card) -> Array[StructureCard]:
	var structures: Array[StructureCard] = []
	if card == null or card.card_type != Card.CardType.CREATURE:
		return structures
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return structures
	for structure in _get_active_structures():
		if structure.replaces_graveyard_send(card, self):
			structures.append(structure)
	return structures

func _apply_god_passives_to_card(player: Player, card: Card) -> void:
	if player.god_zone.cards.size() == 0:
		return
	var god := player.god_zone.cards[0]
	if god is Thor and (god as Thor).applies_to(card):
		card.clear_buffs_from(Thor.PASSIVE_SOURCE)
		card.add_buff(Thor.PASSIVE_SOURCE, 3, 3, 0, god, player, "passive")

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
