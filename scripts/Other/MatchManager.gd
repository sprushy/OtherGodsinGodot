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

# Spell-specific targeting states
var pending_blot_sacrifice_target: Card = null
var pending_blot_selected_creatures: Array[Card] = []
var pending_blot_costs_paid: bool = false

var pending_divine_caprice_power: Card = null
var pending_divine_caprice_selected_zone: Zone = null

var pending_retreat_action: CardAction = null
var pending_retreat_target: Card = null

func _init(p_game_manager: GameManager) -> void:
	game_manager = p_game_manager

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
signal request_ui_interaction(type: String, data: Dictionary)

var last_resolution_text: String = ""

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
		# Check for retreat prompts (e.g. Askelladen)
		# This currently requires UI interaction.
		request_ui_interaction.emit("combat_retreat", {"action": action, "target": actual_target})
		# For now, we assume the UI will call a continuation.
		# In a full headless mode, we'd need a MoveGenerator to decide for the AI.
		return
	elif actual_target is Player:
		var active_attackers := _get_active_attackers(action)
		if active_attackers.is_empty():
			return
			
		var follower_damage := 0
		for combatant in active_attackers:
			follower_damage += combatant.get_effective_strength()
			combatant.spend_major_creature_action()
			combatant.mark_attacked_this_turn()
			
		if active_attackers.size() >= 2:
			game_manager._notify_after_united_front_combat(active_attackers[0], active_attackers[1], null)
		else:
			game_manager._notify_after_combat(active_attackers[0], null)
			
		actual_target.lose_followers(follower_damage)

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
