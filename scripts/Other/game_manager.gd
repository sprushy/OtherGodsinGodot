# GameManager.gd - Complete Version with Robust Player Identification
extends Node
class_name GameManager

enum GamePhase { MULLIGAN, MAIN, COMBAT, END }

var players: Array[Player] = []
var current_player: Player
var other_player: Player
var current_phase: GamePhase = GamePhase.MULLIGAN
var turn_number: int = 0
var action_stack: Array[CardAction] = []
var prepared_hexes: Dictionary = {}
var attack_restrictions: Dictionary = {}# player -> turns remaining

# Priority system
var priority_player: Player = null
var consecutive_passes: int = 0

func push_to_stack(action: CardAction) -> void:
	action_stack.push_back(action)
	consecutive_passes = 0
	priority_player = get_opponent(action.source_player)

func pass_priority() -> void:
	consecutive_passes += 1
	if consecutive_passes < 2:
		priority_player = get_opponent(priority_player)

func both_passed() -> bool:
	return consecutive_passes >= 2

# Returns eligible speed-2+ responses the given player can play against the top stack action.
func get_priority_responses(player: Player) -> Array:
	var responses: Array = []
	if action_stack.is_empty():
		return responses
	var top: CardAction = action_stack.back()
	# Prepared hexes that can trigger against the pending attack
	if top.type == CardAction.Type.ATTACK and top.attacker != null:
		var def_card: Card = top.interceptor if top.interceptor != null else (top.target if top.target is Card else null)
		if def_card != null:
			var hex := find_triggerable_hex(top.attacker, def_card)
			if hex != null and hex.card_owner == player:
				responses.append(hex)
	# Speed 2+ spells in hand
	for c in player.hand_zone.cards:
		if c.get_effective_speed() >= 2 and c.card_type == Card.CardType.SPELL:
			responses.append(c)
	return responses

func setup_game() -> void:
	players = []
	for child in get_children():
		if child is Player:
			players.append(child)
	
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
	turn_number += 1
	current_phase = GamePhase.MAIN
	
	current_player.reset_creature_actions()
	
	# Reduce attack restrictions (for the player whose turn is starting)
	if attack_restrictions.has(current_player):
		attack_restrictions[current_player] -= 1
		if attack_restrictions[current_player] <= 0:
			attack_restrictions.erase(current_player)
			print(current_player.player_name + " can now attack again!")
		else:
			print(current_player.player_name + " still cannot attack (" + str(attack_restrictions[current_player]) + " turns left)")
	
	# Clear summoning sickness
	for zone in current_player.frontline_zones + current_player.reserve_zones:
		for card in zone.cards:
			if card.card_type == Card.CardType.CREATURE:
				card.summoned_this_turn = false
	
	# Trigger structures' on_turn_start
	for zone in current_player.frontline_zones + current_player.reserve_zones:
		for card in zone.cards:
			if card is StructureCard:
				card.on_turn_start(self)
	


func activate_prepared_hexes(defending_player: Player) -> void:
	for hex in prepared_hexes.keys():
		if hex.card_owner == defending_player and prepared_hexes[hex] < turn_number:
			hex.is_prepared = false

# Checks all prepared hexes belonging to the defender's owner.
# If one can activate, it fires and returns true (combat should be cancelled).
func find_triggerable_hex(attacker: Card, defender: Card) -> HexCard:
	var defending_player := defender.card_owner
	for hex in prepared_hexes.keys().duplicate():
		if hex.card_owner != defending_player:
			continue
		if prepared_hexes[hex] >= turn_number:
			continue
		if not (hex is HexCard):
			continue
		if (hex as HexCard).can_activate(attacker, defender):
			return hex as HexCard
	return null

func activate_hex(hex: HexCard, attacker: Card, defender: Card) -> void:
	print(hex.card_name + " triggers!")
	prepared_hexes.erase(hex)
	hex.on_activate(self, attacker, defender)

func check_and_trigger_hexes(attacker: Card, defender: Card) -> bool:
	var hex := find_triggerable_hex(attacker, defender)
	if hex:
		activate_hex(hex, attacker, defender)
		return true
	return false

func player_chooses_draw() -> void:
	current_player.draw_card()
	current_player.gain_mana(1)

func player_chooses_mana() -> void:
	current_player.gain_mana(5)

func can_play_card(player: Player, card: Card, target_zone: Zone) -> bool:
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
	if card.is_power and target_zone not in player.power_zones:
		return false
	
	# Regular cards go to frontline or reserve
	if not card.is_god and not card.is_power:
		if target_zone != null:
			if target_zone not in player.frontline_zones and target_zone not in player.reserve_zones:
				return false
	
	# Check summon limit for creatures
	if card.card_type == Card.CardType.CREATURE and player == current_player:
		if player.has_summoned_this_turn:
			return false
	
	return true

func play_card(player: Player, card: Card, target_zone: Zone, prepared: bool = false) -> void:
	if can_play_card(player, card, target_zone):
		# Pay costs before playing
		if not card.pay_costs(player):
			print("Failed to pay costs")
			return
		
		player.move_card(card, target_zone)
		card.is_prepared = prepared
		card.is_face_down = prepared
		
		# Mark summoned
		if card.card_type == Card.CardType.CREATURE:
			player.has_summoned_this_turn = true
			card.summoned_this_turn = true	# Track summoning sickness for movement/mode change
			
		if card is StructureCard:
			card.on_summon(self)
		
		# Hexes must be prepared
		if card.card_type == Card.CardType.HEX:
			if not prepared:
				print("Hexes must be prepared before use")
				return
			prepared_hexes[card] = turn_number
		
		# Handle spells - cast them after they're in the zone
		if card.card_type == Card.CardType.SPELL:
			print("	Casting spell from zone...")
			if card is SpellCard:
				card.on_play(self, null)
		
		if card.goes_to_graveyard_after_use() and not prepared:
			# Add to action stack or resolve immediately
			resolve_card_effect(card)

func play_creature_stealth(player: Player, card: Card, target_zone: Zone) -> void:
	if card.card_type == Card.CardType.CREATURE:
		card.is_stealth = true
		card.is_face_down = true
		card.creature_mode = Card.CreatureMode.DEFENSE
		play_card(player, card, target_zone)

func prepare_card(player: Player, card: Card, target_zone: Zone) -> void:
	play_card(player, card, target_zone, true)

func reveal_prepared_card(card: Card) -> void:
	if card.is_prepared:
		card.is_face_down = false
		if card.card_type == Card.CardType.HEX and card in prepared_hexes:
			card.is_prepared = false

func resolve_card_effect(card: Card) -> void:
	# Card-specific effects would be implemented here
	if card.goes_to_graveyard_after_use():
		# *** CHANGE: Use hook helper for destruction ***
		_send_to_graveyard_with_hook(card)

func creature_move(creature: Card, target_zone: Zone) -> bool:
	if creature.card_type != Card.CardType.CREATURE:
		return false
	
	if creature.summoned_this_turn:
		return false
	
	if creature.has_acted_this_turn:
		return false
	
	var current_zone = creature.current_zone
	var adjacent_zones = creature.card_owner.get_adjacent_zones(current_zone)
	
	if target_zone in adjacent_zones:
		creature.card_owner.move_card(creature, target_zone)
		creature.has_acted_this_turn = true
		return true
	
	return false

func creature_change_mode(creature: Card) -> bool:
	if creature.card_type != Card.CardType.CREATURE:
		return false
	
	if creature.summoned_this_turn:
		return false
	
	if creature.has_acted_this_turn:
		return false
	
	if creature.creature_mode == Card.CreatureMode.ATTACK:
		creature.creature_mode = Card.CreatureMode.DEFENSE
	else:
		creature.creature_mode = Card.CreatureMode.ATTACK
	
	creature.has_acted_this_turn = true
	return true

func equip_card(equipment: Card, creature: Card) -> bool:
	if equipment.card_type != Card.CardType.EQUIPMENT:
		return false
	
	if creature.card_type != Card.CardType.CREATURE:
		return false
	
	if creature.has_acted_this_turn:
		return false
	
	if equipment.current_zone != creature.current_zone:
		return false
	
	equipment.equip_to(creature)
	creature.has_acted_this_turn = true
	return true

func creature_attack(attacker: Card, target) -> void:
	# This function is now mostly for AI use or direct attacks
	# Player attacks go through the UI intercept system
	if attacker.card_type != Card.CardType.CREATURE:
		return
	if attack_restrictions.has(attacker.card_owner):
		print(attacker.card_owner.player_name + " cannot attack! Restricted for " + str(attack_restrictions[attacker.card_owner]) + " more turns")
		return
	
	if attacker.has_acted_this_turn:
		print("Creature has already acted this turn")
		return
	
	if attacker.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		print("Only frontline creatures can attack")
		return

	if attacker.creature_mode == Card.CreatureMode.DEFENSE:
		print(attacker.card_name + " is in defense mode and cannot attack")
		return

	if attacker.is_stealth:
		attacker.reveal_from_stealth()
	
	attacker.has_acted_this_turn = true
	
	if target is Card:
		resolve_combat(attacker, target)
	elif target is Player:
		# For AI attacks, still auto-check intercepts
		var interceptor = check_for_intercept(attacker, target)
		if interceptor:
			print("	AUTO-INTERCEPT by " + interceptor.card_name)
			resolve_combat(attacker, interceptor)
		else:
			target.lose_followers(attacker.get_effective_strength())

func check_for_intercept(attacker: Card, defending_player: Player) -> Card:
	print("	Checking for intercepts...")
	
	# Check frontline for interceptors
	for zone in defending_player.frontline_zones:
		for card in zone.cards:
			if card.card_type == Card.CardType.CREATURE:
				if card.creature_mode == Card.CreatureMode.DEFENSE:
					print("	-> " + card.card_name + " (DEF) intercepts!")
					return card
				elif card.creature_mode == Card.CreatureMode.ATTACK and card.get_effective_speed() > attacker.get_effective_speed():
					print("	-> " + card.card_name + " (ATK, faster) intercepts!")
					return card
	
	# Check reserves for defensive interceptors
	for zone in defending_player.reserve_zones:
		for card in zone.cards:
			if card.card_type == Card.CardType.CREATURE and card.creature_mode == Card.CreatureMode.DEFENSE:
				print("	-> " + card.card_name + " (DEF, reserve) intercepts!")
				return card
	
	print("	-> No intercepts, attacking followers directly")
	return null

func resolve_combat(attacker: Card, defender: Card) -> void:
	var attacker_str = attacker.get_effective_strength()
	
	print("=== COMBAT: " + attacker.card_name + " (STR:" + str(attacker_str) + ") vs " + defender.card_name + " ===")
	
	if defender.card_type == Card.CardType.CREATURE:
		if defender.creature_mode == Card.CreatureMode.ATTACK:
			# Strength vs Strength
			var defender_str = defender.get_effective_strength()
			print("	STR vs STR: " + str(attacker_str) + " vs " + str(defender_str))
			
			if attacker_str > defender_str:
				# Defender dies, defender's owner loses followers equal to difference
				var diff = attacker_str - defender_str
				print("	" + defender.card_name + " destroyed! " + defender.card_owner.player_name + " loses " + str(diff) + " followers")
				defender.card_owner.lose_followers(diff)
				_send_to_graveyard_with_hook(defender)
			elif defender_str > attacker_str:
				# Attacker dies, attacker's owner loses followers equal to difference
				var diff = defender_str - attacker_str
				print("	" + attacker.card_name + " destroyed! " + attacker.card_owner.player_name + " loses " + str(diff) + " followers")
				attacker.card_owner.lose_followers(diff)
				_send_to_graveyard_with_hook(attacker)
			else:	# Tie
				# Both die
				print("	Tie! Both creatures destroyed")
				# *** CHANGE: Use hook helper for destruction (Defender) ***
				_send_to_graveyard_with_hook(defender)
				# *** CHANGE: Use hook helper for destruction (Attacker) ***
				_send_to_graveyard_with_hook(attacker)
		else:	# DEFENSE mode
			# Strength vs Resilience
			var defender_res = defender.get_effective_resilience()
			print("	STR vs RES: " + str(attacker_str) + " vs " + str(defender_res))
			
			if attacker_str > defender_res:
				# Defender destroyed
				print("	" + defender.card_name + " destroyed!")
				# *** CHANGE: Use hook helper for destruction ***
				_send_to_graveyard_with_hook(defender)
			elif attacker_str < defender_res:
				# Followers convert to defender's side
				var diff = defender_res - attacker_str
				print("	" + str(diff) + " followers convert to " + defender.card_owner.player_name)
				attacker.card_owner.lose_followers(diff)
				defender.card_owner.gain_followers(diff)
			else:
				print("	Exact match - no effect")
	elif defender.card_type == Card.CardType.STRUCTURE:
		# Strength vs Resilience
		var defender_res = defender.resilience
		if attacker_str > defender_res:
			print("	Structure destroyed!")
			# *** CHANGE: Use hook helper for destruction ***
			_send_to_graveyard_with_hook(defender)
	elif defender.card_type == Card.CardType.EQUIPMENT and defender.equipped_on == null:
		# Unequipped equipment can be broken
		print("	Equipment destroyed!")
		# *** CHANGE: Use hook helper for destruction ***
		_send_to_graveyard_with_hook(defender)

func add_to_stack(action: CardAction) -> void:
	action_stack.append(action)

func resolve_stack() -> void:
	while action_stack.size() > 0:
		var action = action_stack.pop_back()
		action.resolve()
		
func apply_attack_restriction(player: Player, turns: int) -> void:
	attack_restrictions[player] = turns
	print(player.player_name + " cannot attack for " + str(turns) + " turns!")

func remove_attack_restriction(player: Player) -> void:
	if attack_restrictions.has(player):
		attack_restrictions.erase(player)
		print(player.player_name + " attack restriction removed!")

func end_turn() -> void:
	# Trigger structures' on_turn_end
	for zone in current_player.frontline_zones + current_player.reserve_zones:
		for card in zone.cards:
			if card is StructureCard:
				card.on_turn_end(self)
	
	# Swap players for the next turn
	var temp = current_player
	current_player = other_player
	other_player = temp
	current_player.is_turn_player = true
	other_player.is_turn_player = false
	start_turn()


# --- New Helper Function for Card Removal ---
func _send_to_graveyard_with_hook(card: Card) -> void:
	# This function handles the removal logic and ensures the on_removed hook is called
	
	# 1. Call the custom hook before the card's current_zone reference is changed.
	# The 'on_removed' hook is designed to run when leaving a board zone.
	if card.has_method("on_removed"):
		card.on_removed(self)
	
		
	# 2. Perform the actual move to the graveyard.
	card.card_owner.move_card(card, card.card_owner.graveyard_zone)
# Add this public function to your GameManager.gd
func banish_card_with_hook(card: Card) -> void:
	_send_to_abyss_with_hook(card)
func _send_to_abyss_with_hook(card: Card) -> void:
	if card.has_method("on_removed"):
		card.on_removed(self)
	card.card_owner.move_card(card, card.card_owner.abyss_zone)
