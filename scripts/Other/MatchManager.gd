# MatchManager.gd
extends RefCounted
class_name MatchManager

# This class manages high-level match flow and targeting state,
# decoupling game rules from the UI.

signal targeting_started(source: Card, target_type: String)
signal targeting_ended()
signal move_validated(move: Dictionary)
signal move_failed(reason: String)

var game_manager: GameManager
var game_state: GameState
var network_manager: Node = null # Set this if in multiplayer mode

# Targeting State (moved from CombatMockGame)
var pending_click_selection_name: String = ""
var pending_click_selection_source: Card = null
var pending_click_selection_validator: Callable = Callable()
var pending_click_selection_confirm: Callable = Callable()
var pending_click_selection_cancel: Callable = Callable()

# Hand card play state
var pending_paid_hand_card: Card = null
var pending_paid_hand_display_zone: Zone = null
var pending_paid_hand_display_zone_auto: bool = false
var pending_spell_display_zone: Zone = null

# Spell/Ability waiting state
var awaiting_spell_target: bool = false
var spell_waiting_for_target: Card = null
var spell_waiting_for_action: CardAction = null
var spell_waiting_for_display_zone: Zone = null

# Other specific targeting states
var awaiting_god_ability_target: bool = false
var god_ability_source: Card = null

var awaiting_stupefy_target: bool = false
var stupefy_source: Card = null

var awaiting_pyre_target: bool = false
var pyre_source: Card = null # AncientPyre

var awaiting_anointing_target: bool = false
var anointing_source: Card = null # AnointingStatue

# Attack state
var selected_attacker: Card = null
var pending_attack_target = null # Card or Player
var selected_interceptor: Card = null

# Spell-specific targeting states
var pending_blot_sacrifice_target: Card = null
var pending_blot_selected_creatures: Array[Card] = []
var pending_blot_costs_paid: bool = false

var pending_divine_caprice_power: Card = null
var pending_divine_caprice_selected_zone: Zone = null

var pending_retreat_action: CardAction = null
var pending_retreat_target: Card = null
var _active_command_sender_info: Dictionary = {}

func _init(p_game_manager: GameManager) -> void:
	game_manager = p_game_manager
	move_failed.connect(_on_move_failed)

# --- Targeting Control ---

func start_click_selection(
	selection_name: String,
	source: Card,
	validator: Callable,
	confirm: Callable,
	cancel: Callable
) -> void:
	pending_click_selection_name = selection_name
	pending_click_selection_source = source
	pending_click_selection_validator = validator
	pending_click_selection_confirm = confirm
	pending_click_selection_cancel = cancel
	targeting_started.emit(source, selection_name)

func _clear_targeting_state() -> void:
	pending_click_selection_name = ""
	pending_click_selection_source = null
	pending_click_selection_validator = Callable()
	pending_click_selection_confirm = Callable()
	pending_click_selection_cancel = Callable()
	targeting_ended.emit()

func cancel_targeting() -> void:
	var click_cancel_callback := pending_click_selection_cancel
	_clear_targeting_state()
	
	awaiting_spell_target = false
	spell_waiting_for_target = null
	spell_waiting_for_action = null
	spell_waiting_for_display_zone = null
	
	awaiting_god_ability_target = false
	god_ability_source = null
	
	awaiting_stupefy_target = false
	stupefy_source = null
	
	awaiting_pyre_target = false
	pyre_source = null
	
	awaiting_anointing_target = false
	anointing_source = null
	
	if click_cancel_callback.is_valid():
		click_cancel_callback.call()

func confirm_click_selection(target) -> void:
	if not pending_click_selection_validator.call(target):
		move_failed.emit("Invalid target for " + pending_click_selection_name)
		return
		
	var confirm_callback = pending_click_selection_confirm
	_clear_targeting_state()
	if confirm_callback.is_valid():
		confirm_callback.call(target)

func get_targeting_name() -> String:
	if pending_click_selection_confirm.is_valid():
		return pending_click_selection_name
	if awaiting_pyre_target and pyre_source != null:
		return pyre_source.card_name + ": Ritual Flame"
	if awaiting_anointing_target and anointing_source != null:
		return anointing_source.card_name
	if awaiting_god_ability_target and god_ability_source != null:
		return god_ability_source.card_name
	if awaiting_stupefy_target and stupefy_source != null:
		return stupefy_source.card_name + ": Stupefy"
	if awaiting_spell_target and spell_waiting_for_target != null:
		return spell_waiting_for_target.card_name
	return "Target selection"

signal action_resolved(action: CardAction)
signal request_ui_interaction(player_index: int, type: String, data: Dictionary)

var last_resolution_text: String = ""
var last_move_failed_reason: String = ""

func resolve_action(action: CardAction) -> void:
	last_resolution_text = ""
	match action.type:
		CardAction.Type.ABILITY:
			_resolve_ability(action)
		CardAction.Type.SPELL:
			_resolve_spell(action)
		CardAction.Type.EVENT:
			_resolve_event(action)
		CardAction.Type.ATTACK:
			_resolve_attack(action)
	
	action_resolved.emit(action)

func _resolve_ability(action: CardAction) -> void:
	if action.card is HexCard:
		var hex := action.card as HexCard
		if hex.has_method("on_activate_action"):
			hex.on_activate_action(game_manager, action)
			last_resolution_text = action.resolution_text if action.resolution_text != "" else hex.card_name + " resolved!"
		else:
			var def_card: Card = action.interceptor if action.interceptor != null else (action.target if action.target is Card else null)
			game_manager.activate_hex(hex, action.attacker, def_card)
			if game_manager.last_hex_resolution_text != "":
				last_resolution_text = game_manager.last_hex_resolution_text
			else:
				last_resolution_text = hex.card_name + " triggered!"
	elif action.resolve_callback.is_valid():
		action.resolve_callback.call()
		last_resolution_text = action.resolution_text if action.resolution_text != "" else action.card.card_name + " resolved!"

func _resolve_spell(action: CardAction) -> void:
	if action.resolve_callback.is_valid():
		action.resolve_callback.call()
		last_resolution_text = action.resolution_text if action.resolution_text != "" else action.card.card_name + " resolved!"

func _resolve_event(action: CardAction) -> void:
	if action.resolve_callback.is_valid():
		action.resolve_callback.call()
		last_resolution_text = action.resolution_text if action.resolution_text != "" else action.event_name.replace("_", " ").capitalize() + " passed."

func _resolve_attack(action: CardAction) -> void:
	if action.attacker == null:
		return

	game_manager.current_phase = GameManager.GamePhase.COMBAT
	var actual_target = action.interceptor if action.interceptor != null else action.target

	action.attacker.reveal(game_manager)
	if action.united_front_partner != null:
		action.united_front_partner.reveal(game_manager)
	if actual_target is Card:
		actual_target.reveal(game_manager)

	action.attacker.mark_attacked_this_turn()

	if actual_target is Card:
		# If the target left the board before the attack resolved (e.g. Gungnir destroyed it),
		# the attack fizzles — attacker still spends their action.
		if actual_target.current_zone == null or not actual_target.current_zone.is_board_zone():
			action.attacker.spend_major_creature_action()
			last_resolution_text = action.attacker.card_name + "'s attack fizzles — target is no longer on the board."
			return
		# Check for Askelladen Tactful Retreat prompts.
		# If any combatant can retreat, delegate to the UI for the interactive prompt.
		# Otherwise, resolve headlessly so the server can handle networked combat.
		var retreat_prompts := _get_retreat_candidates(action.attacker, actual_target, action.source_player)
		if not retreat_prompts.is_empty():
			var target_player: Player = retreat_prompts[0].card_owner
			var player_idx := game_manager.players.find(target_player)
			request_ui_interaction.emit(player_idx, "combat_retreat", {"action": action, "target": actual_target})
			return
		# No retreat possible - resolve directly.
		_finish_creature_combat(action, actual_target)
		return
	elif actual_target is Player:
		var active_attackers := _get_active_attackers(action)
		if active_attackers.is_empty():
			return
		for combatant in active_attackers:
			combatant.spend_major_creature_action()
			combatant.mark_attacked_this_turn()
		var follower_damage := game_manager.resolve_followers_attack(active_attackers, actual_target)
		last_resolution_text = "%s attacks %s's followers for %d!" % [
			action.attacker.card_name,
			actual_target.player_name,
			follower_damage
		]

## Headless combat resolution (no retreat dialog needed).
## Called by _resolve_attack when no Askelladen can retreat.
func _finish_creature_combat(action: CardAction, target: Card) -> void:
	var attacker := action.attacker
	var partner := action.united_front_partner

	var finish := func() -> void:
		var active: Array[Card] = []
		if partner != null:
			active = game_manager._get_active_united_front_attackers(attacker, partner)
		elif attacker.current_zone != null and attacker.current_zone.is_board_zone():
			active = [attacker]
		for combatant in active:
			combatant.spend_major_creature_action()
			combatant.mark_attacked_this_turn()
		if active.size() >= 2:
			last_resolution_text = active[0].card_name + " and " + active[1].card_name + " fought " + target.card_name + "!"
		elif not active.is_empty():
			last_resolution_text = active[0].card_name + " fought " + target.card_name + "!"
		
	if partner != null:
		game_manager.resolve_united_front_combat(attacker, partner, target)
		finish.call()
	else:
		game_manager.resolve_combat_with_continuation(attacker, target, finish, action.interceptor != null)

## Returns any Askelladen cards in the combat that qualify for Tactful Retreat.
func _get_retreat_candidates(attacker: Card, defender: Card, _turn_player: Player) -> Array:
	var candidates: Array = []
	for card in [attacker, defender]:
		if not (card is Askelladen):
			continue
		var other: Card = defender if card == attacker else attacker
		var ask := card as Askelladen
		if ask.is_face_down or ask.abilities_suppressed():
			continue
		if game_manager.is_immune_to_source(other, ask):
			continue
		if other.get_effective_speed() > ask.get_effective_speed():
			continue
		if not game_manager.is_guardian_protected(other, ask):
			candidates.append(ask)
	return candidates

func is_targeting_active() -> bool:
	return pending_click_selection_confirm.is_valid() or \
		awaiting_spell_target or \
		awaiting_god_ability_target or \
		awaiting_stupefy_target or \
		awaiting_pyre_target or \
		awaiting_anointing_target

func _get_active_attackers(action: CardAction) -> Array[Card]:
	var active: Array[Card] = []
	for c in [action.attacker, action.united_front_partner]:
		if c != null and c.current_zone != null and c.current_zone.is_board_zone():
			active.append(c)
	return active

# --- Attack Management ---

func can_attack(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
		
	return (
		card.card_type == Card.CardType.CREATURE
		and card.can_take_major_creature_action()
		and not card.is_sleeping
		and not card.has_status_effect("cannot_attack")
		and game_manager.turn_number > 0
		and card.creature_mode == Card.CreatureMode.AGGRESSIVE
		and card.current_zone != null
		and card.current_zone.zone_type == Zone.ZoneType.FRONTLINE
		and not game_manager.attack_restrictions.has(card.get_controller())
	)

func get_attack_invalid_reason(card: Card) -> String:
	if card == null:
		return "No card selected."
	if card.card_type != Card.CardType.CREATURE:
		return "Only creatures can attack."
	if not card.can_take_major_creature_action():
		return card.card_name + " has already used its major action this turn."
	if card.is_sleeping:
		return card.card_name + " is Sleeping and cannot act."
	if card.has_status_effect("cannot_attack"):
		var status = card.get_status_effect("cannot_attack")
		var source = status.get("source", "an effect")
		return card.card_name + " cannot attack because of " + source + "."
	if game_manager.turn_number == 0:
		return "Cannot attack on the first turn!"
	if card.creature_mode != Card.CreatureMode.AGGRESSIVE:
		return card.card_name + " is in defensive stance and cannot attack."
	if card.current_zone == null or card.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		return card.card_name + " cannot attack from the back row."
	if game_manager.attack_restrictions.has(card.get_controller()):
		var turns = game_manager.attack_restrictions[card.get_controller()]
		return "Attacks restricted for " + str(turns) + " more turns."
	
	return ""

func select_attacker(card: Card) -> void:
	if card == null:
		selected_attacker = null
		return
		
	if can_attack(card):
		if selected_attacker == card:
			selected_attacker = null
		else:
			selected_attacker = card
			pending_attack_target = null
	else:
		move_failed.emit(get_attack_invalid_reason(card))

func request_attack(attacker, target) -> void:
	var attacker_card: Card = attacker if attacker is Card else game_manager.get_card_by_uid(str(attacker))
	var target_obj = target
	
	if target is String:
		target_obj = null
		# Check if target is a card
		target_obj = game_manager.get_card_by_uid(target)
		if target_obj == null:
			var target_index := int(target)
			if str(target_index) == target and target_index >= 0 and target_index < game_manager.players.size():
				target_obj = game_manager.players[target_index]
		if target_obj == null:
			# Check if target is a player (by index or name)
			for p in game_manager.players:
				if p.player_name == target:
					target_obj = p
					break
	
	if attacker_card == null or target_obj == null:
		move_failed.emit("Invalid attack request: missing attacker or target.")
		return
		
	if not can_attack(attacker_card):
		move_failed.emit(get_attack_invalid_reason(attacker_card))
		return
		
	# Check if target is valid for engagement
	if target_obj is Card:
		if not game_manager.can_cards_engage_each_other(attacker_card, target_obj):
			move_failed.emit(attacker_card.card_name + " cannot engage " + target_obj.card_name + ".")
			return
	
	selected_attacker = attacker_card
	pending_attack_target = target_obj
	
	# In a real game, this might trigger an "intercept" phase
	# For now, we signal that an attack is requested/pending
	move_validated.emit({"type": "attack", "attacker": attacker_card, "target": target_obj})

func broadcast_event(event_type: String, data: Dictionary) -> void:
	if network_manager != null and network_manager.is_server:
		network_manager.rpc("broadcast_event", event_type, data)

# --- Zone Serialization Helpers ---

## Convert a Zone to a serializable dict for use in commands.
static func zone_to_dict(zone: Zone, gm: GameManager) -> Dictionary:
	if zone == null or zone.zone_owner == null:
		return {}
	return {
		"player_index": gm.players.find(zone.zone_owner),
		"zone_type": zone.zone_type,
		"zone_index": zone.zone_index,
	}

## Resolve a zone dict back to a Zone object.
func resolve_zone(zone_dict: Dictionary) -> Zone:
	var player_idx: int = zone_dict.get("player_index", -1)
	if player_idx < 0 or player_idx >= game_manager.players.size():
		return null
	var player := game_manager.players[player_idx]
	var zone_idx: int = zone_dict.get("zone_index", 0)
	match zone_dict.get("zone_type", -1):
		Zone.ZoneType.HAND:     return player.hand_zone
		Zone.ZoneType.DECK:     return player.deck_zone
		Zone.ZoneType.GRAVEYARD: return player.graveyard_zone
		Zone.ZoneType.ABYSS:    return player.abyss_zone
		Zone.ZoneType.GOD_SLOT: return player.god_zone
		Zone.ZoneType.POWER_SLOT:
			if zone_idx >= 0 and zone_idx < player.power_zones.size():
				return player.power_zones[zone_idx]
		Zone.ZoneType.FRONTLINE:
			if zone_idx >= 0 and zone_idx < player.frontline_zones.size():
				return player.frontline_zones[zone_idx]
		Zone.ZoneType.RESERVE:
			if zone_idx >= 0 and zone_idx < player.reserve_zones.size():
				return player.reserve_zones[zone_idx]
	return null

func _resolve_sender_player(sender_info: Dictionary) -> Player:
	if sender_info.is_empty():
		return null
	var player_idx := int(sender_info.get("player_index", -1))
	if player_idx < 0 or player_idx >= game_manager.players.size():
		return null
	return game_manager.players[player_idx]

func _get_card_controller(card: Card) -> Player:
	if card == null:
		return null
	return card.get_controller() if card.has_method("get_controller") else card.card_owner

func _get_current_targeting_player() -> Player:
	if pending_click_selection_source != null:
		return _get_card_controller(pending_click_selection_source)
	if awaiting_spell_target and spell_waiting_for_target != null:
		return _get_card_controller(spell_waiting_for_target)
	if awaiting_god_ability_target and god_ability_source != null:
		return _get_card_controller(god_ability_source)
	if awaiting_stupefy_target and stupefy_source != null:
		return _get_card_controller(stupefy_source)
	if awaiting_pyre_target and pyre_source != null:
		return _get_card_controller(pyre_source)
	if awaiting_anointing_target and anointing_source != null:
		return _get_card_controller(anointing_source)
	return null

func _get_required_player_for_command(command: Dictionary) -> Player:
	match str(command.get("type", "")):
		"select_attacker":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("card_uid", ""))))
		"request_attack":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("attacker_uid", ""))))
		"cancel_targeting", "confirm_click_selection":
			return _get_current_targeting_player()
		"play_card", "prepare_card", "play_creature", "creature_move", "change_mode":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("card_uid", ""))))
		"cast_spell":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("spell_uid", ""))))
		"god_ability":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("god_uid", ""))))
		"activate_power", "unlock_power", "activate_divine_caprice":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("power_uid", ""))))
		"cast_charm", "play_charm_response":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("charm_uid", ""))))
		"play_hex_response":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("hex_uid", ""))))
		"skoll_upkeep_summon":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("skoll_uid", ""))))
		"activate_card_ability", "en_hedu_anna_exaltation", "aphrodite_enslave_choice", "blessed_knights_choice":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("source_uid", ""))))
		"wolf_master_summon":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("fenrir_uid", ""))))
		"intercept_decision":
			var interceptor_uid := str(command.get("interceptor_uid", ""))
			if not interceptor_uid.is_empty():
				return _get_card_controller(game_manager.get_card_by_uid(interceptor_uid))
			if pending_attack_target is Card:
				return _get_card_controller(pending_attack_target)
			if pending_attack_target is Player:
				return pending_attack_target
			return game_manager.other_player
		"resurrection_choice":
			var resurrect_card := game_manager.get_card_by_uid(str(command.get("card_uid", "")))
			return resurrect_card.card_owner if resurrect_card != null else null
		"priority_pass":
			return game_manager.priority_player if game_manager.priority_player != null else game_manager.current_player
		"upkeep_choice", "end_turn":
			return game_manager.current_player
	return null

func _send_rejection_to_sender(sender_info: Dictionary, reason: String) -> void:
	if sender_info.is_empty() or network_manager == null or not network_manager.is_server:
		return
	var peer_id := int(sender_info.get("peer_id", -1))
	if peer_id <= 1:
		return
	network_manager.broadcast_event_to_peer(peer_id, "command_rejected", {"reason": reason})

func _validate_sender_authority(command: Dictionary, sender_info: Dictionary) -> String:
	if sender_info.is_empty():
		return ""
	var sender_player := _resolve_sender_player(sender_info)
	if sender_player == null:
		return "Unauthorized command: unknown player."
	var required_player := _get_required_player_for_command(command)
	if required_player == null:
		return ""
	if sender_player != required_player:
		return "Unauthorized command: that action belongs to %s." % required_player.player_name
	return ""

func _on_move_failed(reason: String) -> void:
	last_move_failed_reason = reason
	_send_rejection_to_sender(_active_command_sender_info, reason)

# --- Network Command Support ---

## Entry point for commands from the network.
## Commands are Dictionaries containing "type" and relevant IDs.
## Returns true on success, false on failure (failure also emits move_failed).
func process_command(command: Dictionary, sender_info: Dictionary = {}) -> bool:
	_active_command_sender_info = sender_info.duplicate(true)
	var authority_error := _validate_sender_authority(command, sender_info)
	if not authority_error.is_empty():
		move_failed.emit(authority_error)
		_active_command_sender_info.clear()
		return false
	var result := _process_command_impl(command)
	_active_command_sender_info.clear()
	return result

func _process_command_impl(command: Dictionary) -> bool:
	match command.get("type", ""):
		"select_attacker":
			var uid = command.get("card_uid", "")
			var card = game_manager.get_card_by_uid(uid)
			select_attacker(card)
			return true
		"request_attack":
			var attacker_uid = command.get("attacker_uid", "")
			var target_id = command.get("target_id", "") # Can be card UID or player name/index
			request_attack(attacker_uid, target_id)
			return true
		"cancel_targeting":
			cancel_targeting()
			return true
		"confirm_click_selection":
			var target_uid = command.get("target_uid", "")
			var target = game_manager.get_card_by_uid(target_uid)
			# Fallback to player search if not a card
			if target == null:
				var player_idx = command.get("player_index", -1)
				if player_idx >= 0 and player_idx < game_manager.players.size():
					target = game_manager.players[player_idx]
			confirm_click_selection(target)
			return true
		"play_card":
			var card := game_manager.get_card_by_uid(command.get("card_uid", ""))
			var zone := resolve_zone(command)
			if card == null:
				move_failed.emit("play_card: card not found")
				return false
			if not game_manager.can_play_card(game_manager.current_player, card, zone):
				move_failed.emit("Cannot play " + card.card_name + "! Not enough resources.")
				return false
			game_manager.play_card(game_manager.current_player, card, zone)
			move_validated.emit(command)
			return true
		"prepare_card":
			var card := game_manager.get_card_by_uid(command.get("card_uid", ""))
			var zone := resolve_zone(command)
			if card == null:
				move_failed.emit("prepare_card: card not found")
				return false
			if not game_manager.can_prepare_card(game_manager.current_player, card, zone):
				move_failed.emit("Cannot prepare " + card.card_name + "!")
				return false
			game_manager.prepare_card(game_manager.current_player, card, zone)
			move_validated.emit(command)
			return true
		"creature_move":
			var card := game_manager.get_card_by_uid(command.get("card_uid", ""))
			var zone := resolve_zone(command)
			if card == null or zone == null:
				move_failed.emit("creature_move: invalid card or zone")
				return false
			if not game_manager.creature_move(card, zone):
				move_failed.emit("Invalid move - must be an adjacent empty zone.")
				return false
			move_validated.emit(command)
			return true
		"change_mode":
			var card := game_manager.get_card_by_uid(command.get("card_uid", ""))
			if card == null:
				move_failed.emit("change_mode: card not found")
				return false
			var mode := int(command.get("mode", -1))
			if not game_manager.creature_change_mode(card, mode):
				move_failed.emit("Cannot change mode for " + card.card_name)
				return false
			move_validated.emit(command)
			return true
		"end_turn":
			var et_discard_uids: Array = command.get("discard_uids", [])
			for et_uid in et_discard_uids:
				var et_card := game_manager.get_card_by_uid(et_uid as String)
				if et_card != null and et_card.current_zone == game_manager.current_player.hand_zone:
					game_manager.current_player.discard_card(et_card)
			game_manager.end_turn()
			move_validated.emit(command)
			return true
		"upkeep_choice":
			match command.get("choice", ""):
				"draw":
					game_manager.player_chooses_draw()
				"mana":
					game_manager.player_chooses_mana()
				_:
					move_failed.emit("upkeep_choice: unknown choice '" + str(command.get("choice")) + "'")
					return false
			move_validated.emit(command)
			return true
		"play_creature":
			var card := game_manager.get_card_by_uid(command.get("card_uid", ""))
			var zone := resolve_zone(command)
			var mode: Card.CreatureMode = int(command.get("mode", Card.CreatureMode.DEFENSIVE)) as Card.CreatureMode
			var stealth: bool = command.get("stealth", false)
			if card == null or zone == null:
				move_failed.emit("play_creature: invalid card or zone")
				return false
			if not game_manager.can_play_card(game_manager.current_player, card, zone):
				move_failed.emit("Cannot play " + card.card_name + "!")
				return false
			var success := game_manager.summon_creature_by_effect(
				game_manager.current_player, card, zone,
				mode, stealth, stealth,
				null, true, true, true
			)
			if not success:
				move_failed.emit("Summon failed for " + card.card_name)
				return false
			move_validated.emit(command)
			return true
		"cast_spell":
			var spell_uid: String = command.get("spell_uid", "")
			var spell := game_manager.get_card_by_uid(spell_uid)
			if spell == null or not (spell is SpellCard):
				move_failed.emit("cast_spell: spell not found or not a SpellCard")
				return false
			var player := game_manager.current_player
			if not game_manager.can_play_card(player, spell, null):
				move_failed.emit("Cannot cast " + spell.card_name + "!")
				return false
			
			# Set chosen discards
			var discard_uids: Array = command.get("discard_uids", [])
			if discard_uids.size() > 0:
				var discard_cards: Array[Card] = []
				for discard_uid in discard_uids:
					var c := game_manager.get_card_by_uid(discard_uid as String)
					if c != null:
						discard_cards.append(c)
				spell.set_pending_chosen_discards(discard_cards)
			
			# Set chosen sacrifices
			var sacrifice_uid: String = command.get("sacrifice_uid", "")
			if sacrifice_uid != "":
				var sac_card := game_manager.get_card_by_uid(sacrifice_uid)
				if sac_card != null:
					spell.set_meta("pending_sacrifice_choice", sac_card)
			
			if not spell.pay_costs_with_mana_cost(player, spell.mana_cost, game_manager):
				move_failed.emit("Cannot afford " + spell.card_name + "!")
				return false
			game_manager.notify_spell_played(player, spell)
			(spell as SpellCard).resolve_from_command(game_manager, command)
			if (spell as SpellCard).should_go_to_graveyard() and spell.current_zone != player.graveyard_zone:
				player.move_card(spell, player.graveyard_zone)
			move_validated.emit(command)
			return true
		"god_ability":
			var god_uid: String = command.get("god_uid", "")
			var god_card := game_manager.get_card_by_uid(god_uid)
			if god_card == null or not god_card.is_god:
				move_failed.emit("god_ability: god card not found")
				return false
			if not god_card.has_method("can_activate") or not god_card.can_activate(game_manager):
				move_failed.emit(god_card.card_name + "'s ability cannot be activated right now.")
				return false
			var target: Card = null
			var target_uid: String = command.get("target_uid", "")
			if target_uid != "":
				target = game_manager.get_card_by_uid(target_uid)
			if god_card.has_method("activate"):
				god_card.activate(game_manager, target)
			move_validated.emit(command)
			return true
		"activate_power":
			var power_uid: String = command.get("power_uid", "")
			var power_card := game_manager.get_card_by_uid(power_uid)
			if power_card == null or not (power_card is PowerCard):
				move_failed.emit("activate_power: power card not found")
				return false
			var act_target: Card = null
			var act_target_uid: String = command.get("target_uid", "")
			if act_target_uid != "":
				act_target = game_manager.get_card_by_uid(act_target_uid)
			var act_mode: String = command.get("mode", "")
			if act_mode == "return_priest":
				if not (power_card is Breidablik):
					move_failed.emit("activate_power: return_priest requires Breidablik")
					return false
				var breidablik := power_card as Breidablik
				if not breidablik.can_return_priest(game_manager):
					move_failed.emit(power_card.card_name + " cannot return a priest right now.")
					return false
				breidablik.return_priest(game_manager, act_target)
			else:
				if not power_card.can_activate(game_manager):
					move_failed.emit(power_card.card_name + " cannot activate right now.")
					return false
				power_card.activate(game_manager, act_target)
			move_validated.emit(command)
			return true
		"cast_charm":
			var charm_uid: String = command.get("charm_uid", "")
			var charm := game_manager.get_card_by_uid(charm_uid)
			if charm == null or not (charm is CharmCard):
				move_failed.emit("cast_charm: charm not found")
				return false
			var charm_card := charm as CharmCard
			var charm_target: Card = null
			var charm_target_uid: String = command.get("target_uid", "")
			if charm_target_uid != "":
				charm_target = game_manager.get_card_by_uid(charm_target_uid)
			var charm_prepared: bool = command.get("prepared", false) or charm_card.is_prepared
			var charm_source_action: CardAction = game_manager.action_stack.back() if not game_manager.action_stack.is_empty() else null
			if charm_prepared:
				if not charm_card.can_activate_prepared(game_manager, charm_source_action):
					move_failed.emit(charm_card.card_name + " cannot activate right now.")
					return false
				game_manager.prepared_charms.erase(charm_card)
				charm_card.is_prepared = false
				charm_card.reveal(game_manager)
			else:
				if not charm_card.can_activate_from_hand(game_manager, charm_source_action):
					move_failed.emit(charm_card.card_name + " cannot be played right now.")
					return false
				if not charm_card.pay_costs(charm_card.card_owner, game_manager):
					move_failed.emit("Cannot afford " + charm_card.card_name + "!")
					return false
			charm_card.resolve(game_manager, charm_target)
			if charm_card.current_zone != null and charm_card.current_zone != charm_card.card_owner.graveyard_zone:
				charm_card.card_owner.move_card(charm_card, charm_card.card_owner.graveyard_zone)
			move_validated.emit(command)
			return true
		"skoll_upkeep_summon":
			var skoll_uid: String = command.get("skoll_uid", "")
			var skoll_card := game_manager.get_card_by_uid(skoll_uid)
			if skoll_card == null or not (skoll_card is Skoll):
				move_failed.emit("skoll_upkeep_summon: Skoll card not found")
				return false
			var skoll := skoll_card as Skoll
			if not skoll.can_use_upkeep_summon(game_manager):
				move_failed.emit("Skoll cannot use upkeep summon right now.")
				return false
			var skoll_zone := resolve_zone(command)
			if skoll_zone == null or skoll_zone.zone_owner != game_manager.current_player \
					or skoll_zone.zone_type not in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE] \
					or not skoll_zone.cards.is_empty():
				move_failed.emit("Skoll upkeep summon: invalid zone.")
				return false
			var skoll_mode_str: String = command.get("mode", "aggressive")
			var skoll_mode: Card.CreatureMode = Card.CreatureMode.DEFENSIVE
			if skoll_mode_str == "aggressive":
				skoll_mode = Card.CreatureMode.AGGRESSIVE
			var skoll_stealth := skoll_mode_str == "stealth"
			game_manager.player_chooses_upkeep_only()
			if not game_manager.summon_creature_by_effect(
				game_manager.current_player, skoll, skoll_zone,
				skoll_mode, skoll_stealth, skoll_stealth,
				skoll, false, false
			):
				move_failed.emit("Skoll could not be summoned.")
				return false
			skoll.apply_upkeep_summon_tax(game_manager)
			move_validated.emit(command)
			return true
		"unlock_power":
			var up_uid: String = command.get("power_uid", "")
			var up_card := game_manager.get_card_by_uid(up_uid)
			if up_card == null or not (up_card is PowerCard):
				move_failed.emit("unlock_power: power card not found")
				return false
			if not up_card.can_unlock(game_manager):
				move_failed.emit(up_card.card_name + " cannot be unlocked right now.")
				return false
			up_card.unlock(game_manager)
			move_validated.emit(command)
			return true
		"activate_card_ability":
			var aca_source_uid: String = command.get("source_uid", "")
			var aca_source := game_manager.get_card_by_uid(aca_source_uid)
			if aca_source == null:
				move_failed.emit("activate_card_ability: source card not found")
				return false
			if not aca_source.has_method("activate"):
				move_failed.emit("activate_card_ability: card has no activate method")
				return false
			var aca_target: Card = null
			var aca_target_uid: String = command.get("target_uid", "")
			if aca_target_uid != "":
				aca_target = game_manager.get_card_by_uid(aca_target_uid)
			if command.has("return_to_hand"):
				aca_source.activate(game_manager, {"return_to_hand": bool(command.get("return_to_hand", false))})
			elif aca_target != null:
				aca_source.activate(game_manager, aca_target)
			else:
				aca_source.activate(game_manager)
			move_validated.emit(command)
			return true
		"en_hedu_anna_exaltation":
			var eha_uid: String = command.get("source_uid", "")
			var eha_card := game_manager.get_card_by_uid(eha_uid)
			if eha_card == null or not (eha_card is EnHeduAnna):
				move_failed.emit("en_hedu_anna_exaltation: card not found")
				return false
			var eha_option: Dictionary = command.get("option", {})
			(eha_card as EnHeduAnna).resolve_exaltation_choice(game_manager, eha_option)
			move_validated.emit(command)
			return true
		"aphrodite_enslave_choice":
			var source_uid: String = command.get("source_uid", "")
			var god := game_manager.get_card_by_uid(source_uid) as AphroditeAreia
			if god == null:
				move_failed.emit("aphrodite_enslave_choice: god not found")
				return false
			var confirmed: bool = command.get("confirm", false)
			if not confirmed:
				move_validated.emit(command)
				return true
			# "Choose Target" part is handled by a subsequent god_ability command from the client
			move_validated.emit(command)
			return true
		"blessed_knights_choice":
			var source_uid: String = command.get("source_uid", "")
			var ward_kind: String = command.get("ward_kind", "")
			var card := game_manager.get_card_by_uid(source_uid) as BlessedKnights
			if card == null:
				move_failed.emit("blessed_knights_choice: card not found")
				return false
			card.apply_blessed_ward(game_manager, ward_kind)
			move_validated.emit(command)
			return true
		"wolf_master_summon":
			var wm_fenrir_uid: String = command.get("fenrir_uid", "")
			var wm_fenrir_card := game_manager.get_card_by_uid(wm_fenrir_uid)
			if wm_fenrir_card == null or not (wm_fenrir_card is Fenrir):
				move_failed.emit("wolf_master_summon: Fenrir not found")
				return false
			var wm_fenrir := wm_fenrir_card as Fenrir
			if not wm_fenrir.can_use_hand_ability(game_manager):
				move_failed.emit("Wolf Master cannot be used right now.")
				return false
			if not wm_fenrir.perform_wolf_master_shuffle():
				move_failed.emit("Wolf Master shuffle failed.")
				return false
			var wm_lupine_uid: String = command.get("lupine_uid", "")
			var wm_lupine := game_manager.get_card_by_uid(wm_lupine_uid)
			if wm_lupine == null:
				move_failed.emit("wolf_master_summon: lupine not found")
				return false
			var wm_zone := resolve_zone(command)
			if wm_zone == null or wm_zone.zone_owner != game_manager.current_player \
					or wm_zone.zone_type not in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE] \
					or not wm_zone.cards.is_empty():
				move_failed.emit("wolf_master_summon: invalid zone")
				return false
			var wm_mode_str: String = command.get("mode", "aggressive")
			var wm_mode: Card.CreatureMode = Card.CreatureMode.DEFENSIVE
			if wm_mode_str == "aggressive":
				wm_mode = Card.CreatureMode.AGGRESSIVE
			var wm_stealth := wm_mode_str == "stealth"
			if not game_manager.summon_creature_by_effect(
				game_manager.current_player, wm_lupine, wm_zone,
				wm_mode, wm_stealth, wm_stealth,
				wm_fenrir_card, true, true
			):
				move_failed.emit("Wolf Master: summon failed for " + wm_lupine.card_name)
				return false
			move_validated.emit(command)
			return true
		"activate_divine_caprice":
			var dc_uid: String = command.get("power_uid", "")
			var dc_card := game_manager.get_card_by_uid(dc_uid)
			if dc_card == null or not (dc_card is DivineCaprice):
				move_failed.emit("activate_divine_caprice: DivineCaprice not found")
				return false
			var dc := dc_card as DivineCaprice
			if not dc.can_activate(game_manager):
				move_failed.emit(dc.card_name + " cannot activate right now.")
				return false
			var raw_plan: Array = command.get("plan", [])
			var dc_plan: Array = []
			for step in raw_plan:
				var src_zone := resolve_zone(step.get("source_zone", {}))
				var tgt_zone := resolve_zone(step.get("target_zone", {}))
				if src_zone != null and tgt_zone != null:
					dc_plan.append({"source_zone": src_zone, "target_zone": tgt_zone})
			if dc_plan.is_empty():
				move_failed.emit("activate_divine_caprice: plan is empty or all zones invalid")
				return false
			dc.activate(game_manager, dc_plan)
			move_validated.emit(command)
			return true
		"intercept_decision":
			var int_uid: String = command.get("interceptor_uid", "")
			var interceptor: Card = game_manager.get_card_by_uid(int_uid) if int_uid != "" else null
			selected_interceptor = interceptor
			move_validated.emit(command)
			return true
		"play_charm_response":
			var pcr_charm_uid: String = command.get("charm_uid", "")
			var pcr_charm := game_manager.get_card_by_uid(pcr_charm_uid)
			if pcr_charm == null or not (pcr_charm is CharmCard):
				move_failed.emit("play_charm_response: charm card not found")
				return false
			if game_manager.action_stack.is_empty():
				move_failed.emit("play_charm_response: no action on stack")
				return false
			var pcr_source: CardAction = game_manager.action_stack.back()
			if not game_manager.can_card_respond_to_priority(pcr_charm, pcr_charm.card_owner):
				move_failed.emit("play_charm_response: charm cannot respond right now")
				return false
			var pcr_from_hand: bool = command.get("from_hand", false)
			var pcr_charm_card := pcr_charm as CharmCard
			var pcr_target_uid: String = command.get("target_uid", "")
			var pcr_target: Card = game_manager.get_card_by_uid(pcr_target_uid) if pcr_target_uid != "" else null
			if pcr_from_hand:
				if not pcr_charm_card.pay_costs(pcr_charm_card.card_owner, game_manager):
					move_failed.emit("Cannot afford " + pcr_charm_card.card_name + "!")
					return false
			else:
				game_manager.prepared_charms.erase(pcr_charm)
				pcr_charm.is_prepared = false
				pcr_charm.reveal(game_manager)
			var pcr_action := CardAction.new()
			pcr_action.type = CardAction.Type.SPELL
			pcr_action.source_player = pcr_charm_card.card_owner
			pcr_action.card = pcr_charm
			pcr_action.target = pcr_target
			pcr_action.response_to = pcr_source
			pcr_action.resolve_callback = func() -> void:
				pcr_charm_card.resolve(game_manager, pcr_target)
				if pcr_charm_card.current_zone != null \
						and pcr_charm_card.current_zone != pcr_charm_card.card_owner.graveyard_zone:
					pcr_charm_card.card_owner.move_card(pcr_charm_card, pcr_charm_card.card_owner.graveyard_zone)
			game_manager.push_to_stack(pcr_action)
			move_validated.emit(command)
			return true
		"priority_pass":
			# Remote player explicitly passes priority; CombatMockGame continues the loop.
			move_validated.emit(command)
			return true
		"resurrection_choice":
			var card_uid: String = command.get("card_uid", "")
			var confirmed: bool = command.get("confirm", false)
			var card := game_manager.get_card_by_uid(card_uid)
			if card == null:
				move_failed.emit("resurrection_choice: card not found")
				return false
			
			if confirmed:
				var player := card.card_owner
				if player.mana < 1:
					move_failed.emit("resurrection_choice: not enough mana")
					return false
				
				player.spend_mana(1)
				# Find an empty reserve zone, preferring the same column the card died in
				var preferred_idx: int = card.last_board_zone_index
				var zones_to_try: Array[Zone] = []
				if preferred_idx >= 0 and preferred_idx < player.reserve_zones.size():
					zones_to_try.append(player.reserve_zones[preferred_idx])
				for zone in player.reserve_zones:
					if zone not in zones_to_try:
						zones_to_try.append(zone)
				
				var placed := false
				for zone in zones_to_try:
					if zone.cards.is_empty():
						placed = game_manager.summon_creature_by_effect(
							player, card, zone,
							Card.CreatureMode.AGGRESSIVE,
							false, false, null,
							false, false, false
						)
						if placed: break
				
				if not placed:
					move_failed.emit("resurrection_choice: no empty reserve zone")
					return false
			
			# Remove from pending list regardless of choice (or if failed)
			game_manager.pending_resurrections.erase(card)
			move_validated.emit(command)
			# CombatMockGame's _on_match_move_validated("resurrection_choice") drives
			# the next step via _continue_end_turn_sequence(); no need to call it here.
			return true
		"play_hex_response":
			var phr_hex_uid: String = command.get("hex_uid", "")
			var phr_hex_card := game_manager.get_card_by_uid(phr_hex_uid)
			if phr_hex_card == null or not (phr_hex_card is HexCard):
				move_failed.emit("play_hex_response: hex card not found")
				return false
			if game_manager.action_stack.is_empty():
				move_failed.emit("play_hex_response: no action on stack")
				return false
			var phr_source: CardAction = game_manager.action_stack.back()
			if not game_manager.can_card_respond_to_priority(phr_hex_card, phr_hex_card.card_owner):
				move_failed.emit("play_hex_response: hex cannot respond right now")
				return false
			var phr_target_uid: String = command.get("target_uid", "")
			var phr_target: Card = game_manager.get_card_by_uid(phr_target_uid) if phr_target_uid != "" else null
			var phr_target_is_attacker: bool = command.get("target_is_attacker", false)
			var phr_hex := phr_hex_card as HexCard
			var phr_ability := CardAction.new()
			phr_ability.type = CardAction.Type.ABILITY
			phr_ability.source_player = phr_hex.card_owner
			phr_ability.card = phr_hex
			phr_ability.response_to = phr_source
			phr_ability.attacker = phr_target if phr_target_is_attacker and phr_target != null else phr_source.attacker
			phr_ability.interceptor = phr_source.interceptor
			phr_ability.target = phr_target if not phr_target_is_attacker and phr_target != null else phr_source.target
			game_manager.push_to_stack(phr_ability)
			game_manager.prepared_hexes.erase(phr_hex_card)
			phr_hex_card.is_prepared = false
			phr_hex_card.reveal(game_manager)
			move_validated.emit(command)
			return true
	move_failed.emit("Unknown command type: " + str(command.get("type")))
	return false

func _check_for_next_resurrection() -> void:
	# Only relevant if we have pending resurrections
	if game_manager.pending_resurrections.is_empty():
		return
		
	var candidates: Array[Card] = []
	for card in game_manager.pending_resurrections:
		if card.card_owner.mana >= 1 \
				and card.current_zone == card.card_owner.graveyard_zone:
			candidates.append(card)
			
	if not candidates.is_empty():
		var next_card := candidates[0]
		var player_idx := game_manager.players.find(next_card.card_owner)
		request_ui_interaction.emit(player_idx, "resurrection", {"card_uid": next_card.uid})
