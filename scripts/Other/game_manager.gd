# GameManager.gd - Complete Version with Robust Player Identification
extends Node
class_name GameManager

signal game_ended(winner: Player, loser: Player)

enum GamePhase { MULLIGAN, MAIN, COMBAT, END }

var players: Array[Player] = []
var current_player: Player
var other_player: Player
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

# Priority system
var priority_player: Player = null
var consecutive_passes: int = 0

func push_to_stack(action: CardAction) -> void:
	if is_game_over:
		return
	action_stack.push_back(action)
	consecutive_passes = 0
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

func consume_player_feedback() -> String:
	var text := last_player_feedback_text
	last_player_feedback_text = ""
	return text

# Returns eligible speed-2+ responses the given player can play against the top stack action.
func get_priority_responses(player: Player) -> Array:
	var responses: Array = []
	if action_stack.is_empty():
		return responses
	var top: CardAction = action_stack.back()
	var top_speed := top.get_timing_speed()
	# Prepared hexes that can trigger against the pending stack action
	for hex in prepared_hexes.keys().duplicate():
		if hex.card_owner != player:
			continue
		if prepared_hexes[hex] >= turn_number:
			continue
		if hex.is_activation_locked(self):
			continue
		if _has_pending_stack_action_for_card(hex):
			continue
		if not (hex is HexCard):
			continue
		var typed_hex := hex as HexCard
		if typed_hex.has_method("can_respond_to_action") and typed_hex.can_respond_to_action(top):
			responses.append(typed_hex)
			continue
		if top.type == CardAction.Type.ATTACK and top.attacker != null:
			var def_card: Card = top.interceptor if top.interceptor != null else (top.target if top.target is Card else null)
			if def_card != null and typed_hex.can_activate(top.attacker, def_card):
				responses.append(typed_hex)
	for charm in prepared_charms.keys().duplicate():
		if charm == null:
			continue
		if charm.card_owner != player:
			continue
		if _has_pending_stack_action_for_card(charm):
			continue
		if not (charm is CharmCard):
			continue
		var typed_charm := charm as CharmCard
		if typed_charm.can_activate_prepared(self, top):
			responses.append(typed_charm)
	for c in player.hand_zone.cards:
		if c is CharmCard:
			var hand_charm := c as CharmCard
			if hand_charm.can_activate_from_hand(self, top):
				responses.append(hand_charm)
			continue
	# Speed 2+ spells in hand
	for c in player.hand_zone.cards:
		if c is CharmCard:
			continue
		if c.card_type != Card.CardType.SPELL:
			continue
		if c.get_effective_speed() < 2:
			continue
		if top_speed > 0 and c.get_effective_speed() < top_speed:
			continue
		responses.append(c)
	return responses

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
	current_phase = GamePhase.MULLIGAN
	offer_mulligan(current_player, 5, 0)
	offer_mulligan(other_player, 5, 2)

func offer_mulligan(player: Player, card_count: int, bonus_mana: int) -> void:
	# UI driven - draw card_count cards
	# For each card not kept, give player 4 mana
	# Add bonus_mana
	pass

func start_turn() -> void:
	if is_game_over:
		return
	turn_number += 1
	current_phase = GamePhase.MAIN
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
	
	# Trigger board permanents' on_turn_start
	for zone in current_player.frontline_zones + current_player.reserve_zones:
		for card in zone.cards:
			if card.has_method("on_turn_start"):
				card.on_turn_start(self)
	for zone in current_player.power_zones:
		for card in zone.cards:
			if card.has_method("on_turn_start"):
				card.on_turn_start(self)

func activate_prepared_hexes(defending_player: Player) -> void:
	for hex in prepared_hexes.keys():
		if hex.card_owner == defending_player and prepared_hexes[hex] < turn_number:
			hex.is_prepared = false

func _resolve_turn_upkeep() -> void:
	if _upkeep_resolved_turn == turn_number:
		return
	_upkeep_resolved_turn = turn_number
	for card in current_player.god_zone.cards:
		if card.has_method("on_turn_start"):
			card.on_turn_start(self)

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
	
	attacker.spend_major_creature_action()
	attacker.mark_attacked_this_turn()
	
	if target is Card:
		resolve_combat(attacker, target)
	elif target is Player:
		target.lose_followers(attacker.get_effective_strength())
		_notify_after_combat(attacker, null)

func _can_intercept_followers(defender: Card, attacker: Card) -> bool:
	if defender == null or attacker == null:
		return false
	if defender.card_type != Card.CardType.CREATURE:
		return false
	if defender.is_sleeping:
		return false
	if defender.get_effective_speed() < attacker.get_effective_speed():
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

func check_for_intercept(attacker: Card, defending_player: Player) -> Card:
	print("	Checking for intercepts...")
	for zone in defending_player.frontline_zones + defending_player.reserve_zones:
		for card in zone.cards:
			if _can_intercept_followers(card, attacker):
				print("	-> " + card.card_name + " intercepts!")
				return card
	print("	-> No intercepts, attacking followers directly")
	return null

func resolve_combat(attacker: Card, defender: Card) -> void:
	attacker.reveal_from_stealth(self)
	defender.reveal_from_stealth(self)
	var attacker_controller := attacker.get_controller()
	var defender_controller := defender.get_controller()
	if defender.is_god:
		# Gods cannot be targeted in combat — redirect to follower damage
		defender_controller.lose_followers(attacker.get_effective_strength())
		print(attacker.card_name + " attacks " + defender_controller.player_name + "'s followers for " + str(attacker.get_effective_strength()) + " (via god)!")
		_notify_after_combat(attacker, defender)
		return
	var attacker_str = attacker.get_effective_strength()

	print("=== COMBAT: " + attacker.card_name + " (STR:" + str(attacker_str) + ") vs " + defender.card_name + " ===")
	
	if defender.is_petrified() or defender.card_type == Card.CardType.STRUCTURE:
		var defender_res := defender.get_effective_resilience()
		print("	STR vs Structure RES: " + str(attacker_str) + " vs " + str(defender_res))
		if attacker_str > defender_res:
			print("	Structure destroyed!")
			_combat_kill(attacker, defender)
		_notify_after_combat(attacker, defender)
		return

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
			var defender_res = defender.get_effective_resilience()
			print("	STR vs RES: " + str(attacker_str_vs_res) + " vs " + str(defender_res))

			if attacker_str_vs_res > defender_res:
				print("	" + defender.card_name + " destroyed!")
				_combat_kill(attacker, defender)
			elif attacker_str_vs_res < defender_res:
				# Followers convert to defender's side
				var diff = defender_res - attacker_str_vs_res
				print("	" + str(diff) + " followers convert to " + defender_controller.player_name)
				attacker_controller.lose_followers(diff)
				defender_controller.gain_followers(diff)
			else:
				print("	Exact match - no effect")
	elif defender.card_type == Card.CardType.EQUIPMENT and defender.equipped_on == null:
		print("	Equipment destroyed!")
		_combat_kill(attacker, defender)
	_notify_after_combat(attacker, defender)

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

func end_turn() -> void:
	if is_game_over:
		return
	# Trigger structures' on_turn_end
	for zone in current_player.frontline_zones + current_player.reserve_zones:
		for card in zone.cards:
			if card.has_method("on_turn_end"):
				card.on_turn_end(self)
	for card in current_player.god_zone.cards:
		if card.has_method("on_turn_end"):
			card.on_turn_end(self)
	for zone in current_player.power_zones:
		for card in zone.cards:
			if card.has_method("on_turn_end"):
				card.on_turn_end(self)
	for player in players:
		for zone in [player.god_zone] + player.power_zones + player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				card.remove_expired_statuses(turn_number)
	
	# Swap players for the next turn
	var temp = current_player
	current_player = other_player
	other_player = temp
	current_player.is_turn_player = true
	other_player.is_turn_player = false
	start_turn()


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
	else:
		if not _send_to_graveyard_with_hook(victim, true, true):
			return
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
	if destruction and (card.has_status_effect("berserker_rage_guard") or card.has_status_effect("berserker_mead_guard")):
		print(card.card_name + " resists destruction this turn.")
		return false
	# Record board position before the zone changes so Circle of Rebirth can
	# auto-resurrect to the same spot.
	if card.current_zone and card.current_zone.is_board_zone():
		card.last_board_zone_type  = card.current_zone.zone_type
		card.last_board_zone_index = card.current_zone.zone_index

	if card.has_method("on_removed") and not card.abilities_suppressed():
		card.on_removed(self)
	if combat_death and card.has_method("on_death") and not card.abilities_suppressed():
		card.on_death(self)

	died_this_turn.append(card)
	card.card_owner.move_card(card, card.card_owner.graveyard_zone)
	return true
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
	current_phase = GamePhase.END
	if winning_player != null:
		print(winning_player.player_name + " wins the game! " + defeated_player.player_name + " reached 0 followers.")
	else:
		print("Game over! " + defeated_player.player_name + " reached 0 followers.")
	game_ended.emit(winning_player, losing_player)
