extends GodCard
class_name GuanYu

const TACTIC_COUNTER_COST := 4
const GUAN_YU_ACTIVE_SCRIPT := preload("res://scripts/cards/ActiveGods/GuanYuActive.gd")

var tactic_counters: int = 0
var _last_counter_turn: int = -1

func _init() -> void:
	super._init()
	card_name = "Guan Yu"
	card_types = ["War", "Champion", "Hero", "Targeting"]
	mana_cost = 0
	culture = "Tian"
	targets = true
	flavor_text = ""
	ability_text = "Tactical Break ([b]Upkeep[/b]/[b]Activate[/b]): If you control more frontline creatures than your opponent, gain 1 tactic counter. Remove 4 tactic counters: destroy a card.\n[b]Champion's Call[/b] ([b]Activate[/b]): Summon Guan Yu, Active God. You may [b]Shelve[/b] cards from your hand to pay 4 mana each."
	art_path = "res://images/card_art/gods/guan_yu.png"
	artist = "Ricarrdo Zoppello"
	name_at_bottom = true

func on_turn_upkeep(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	if card_owner != game_manager.current_player:
		return
	if is_muted:
		return
	if _last_counter_turn == game_manager.turn_number:
		return
	_last_counter_turn = game_manager.turn_number

	var my_count := _count_frontline_creatures(card_owner)
	var opponent := game_manager.get_opponent(card_owner)
	var opp_count := _count_frontline_creatures(opponent) if opponent != null else 0

	if my_count > opp_count:
		tactic_counters += 1
		_emit_visual_state_changed()
		game_manager.note_player_feedback(
			"%s gains a tactic counter from Tactical Break (now %d). Frontline: %d vs %d." % [
				card_name, tactic_counters, my_count, opp_count
			]
		)

func can_activate(game_manager: GameManager) -> bool:
	if _can_use_tactical_break(game_manager):
		return true
	return can_use_champions_call(game_manager)

func should_show_activation_aura(game_manager: GameManager) -> bool:
	return _can_use_tactical_break(game_manager)

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if _can_use_tactical_break(game_manager):
		return ""
	if can_use_champions_call(game_manager):
		return ""
	var tactical_reason := _get_tactical_break_failure_reason(game_manager)
	var champion_reason := get_champions_call_failure_reason(game_manager)
	return tactical_reason + " " + champion_reason

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid: Array[Card] = []
	if game_manager == null:
		return valid
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if is_valid_activation_target(card):
					valid.append(card)
	return valid

func is_valid_activation_target(target: Card) -> bool:
	return target != null \
		and not target.is_god \
		and target.current_zone != null \
		and target.current_zone.is_board_zone()

func activate(game_manager: GameManager, target: Card = null) -> void:
	if target != null:
		_activate_tactical_break(game_manager, target)
		return
	if can_use_champions_call(game_manager):
		game_manager.note_player_feedback(resolve_champions_call(game_manager))
		if current_zone != card_owner.god_zone:
			notify_power_activated(game_manager, null)
		return
	if game_manager != null:
		game_manager.note_player_feedback(get_activation_failure_reason(game_manager))

func activate_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var target_uid := str(command.get("target_uid", ""))
	var target: Card = game_manager.get_card_by_uid(target_uid) if not target_uid.is_empty() else null
	if not target_uid.is_empty() and target == null:
		game_manager.note_player_feedback("Tactical Break fizzles: target not found.")
		return
	if target != null:
		_activate_tactical_break(game_manager, target)
		return
	if is_champions_call_command(command):
		game_manager.note_player_feedback(resolve_champions_call_from_command(game_manager, command))
		if current_zone != card_owner.god_zone:
			notify_power_activated(game_manager, null)
		return
	if can_use_champions_call(game_manager):
		game_manager.note_player_feedback(
			resolve_champions_call(
				game_manager,
				get_champions_call_selected_cards_from_command(game_manager, command),
				get_champions_call_zone_from_command(command),
				get_champions_call_mode_from_command(command)
			)
		)
		if current_zone != card_owner.god_zone:
			notify_power_activated(game_manager, null)
		return
	game_manager.note_player_feedback(get_activation_failure_reason(game_manager))

func on_removed(_game_manager: GameManager) -> void:
	tactic_counters = 0
	_last_counter_turn = -1
	_emit_visual_state_changed()

func get_serialized_state() -> Dictionary:
	return {
		"tactic_counters": tactic_counters,
		"last_counter_turn": _last_counter_turn,
	}

func apply_serialized_state(state: Dictionary) -> void:
	tactic_counters = int(state.get("tactic_counters", 0))
	_last_counter_turn = int(state.get("last_counter_turn", -1))
	_emit_visual_state_changed()

func get_effect_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("Tactic counters: %d / %d" % [tactic_counters, TACTIC_COUNTER_COST])
	return lines

func _count_frontline_creatures(player: Player) -> int:
	if player == null:
		return 0
	var count := 0
	for zone in player.frontline_zones:
		for card in zone.cards:
			if card.card_type == Card.CardType.CREATURE:
				count += 1
	return count

func get_champions_call_candidate(_allow_fallback: bool = true) -> Card:
	if card_owner == null:
		return null
	var reserved_manifestation := get_reserved_active_god_candidate()
	if reserved_manifestation != null:
		return reserved_manifestation
	for zone in [
		card_owner.hand_zone,
		card_owner.deck_zone,
		card_owner.graveyard_zone,
	] + card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			var active_god := card as ActiveGodCard
			if active_god == null or active_god.get_linked_god_name() != "Guan Yu":
				continue
			if card.current_zone != null and card.current_zone.is_board_zone():
				return null
			return card
	var manifestation := GUAN_YU_ACTIVE_SCRIPT.new()
	manifestation.card_owner = card_owner
	return manifestation

func _can_use_tactical_break(game_manager: GameManager) -> bool:
	if not can_use_god_power(game_manager):
		return false
	if tactic_counters < TACTIC_COUNTER_COST:
		return false
	return not get_valid_targets(game_manager).is_empty()

func _get_tactical_break_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if is_muted:
		return card_name + " is muted."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if tactic_counters < TACTIC_COUNTER_COST:
		return "Tactical Break needs %d tactic counters (have %d)." % [TACTIC_COUNTER_COST, tactic_counters]
	if get_valid_targets(game_manager).is_empty():
		return "Tactical Break has no valid targets."
	return ""

func _activate_tactical_break(game_manager: GameManager, target: Card) -> void:
	if not _can_use_tactical_break(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(_get_tactical_break_failure_reason(game_manager))
		return
	if not is_valid_activation_target(target):
		if game_manager != null:
			game_manager.note_player_feedback("Tactical Break fizzles: invalid target.")
		return
	if game_manager.is_immune_to_source(target, self):
		game_manager.note_player_feedback(
			"Tactical Break fizzles: %s is immune." % target.card_name
		)
		return

	tactic_counters -= TACTIC_COUNTER_COST
	_emit_visual_state_changed()
	game_manager.note_player_feedback(
		"Tactical Break: %s spends %d tactic counters (now %d) to destroy %s." % [
			card_name, TACTIC_COUNTER_COST, tactic_counters, target.card_name
		]
	)
	game_manager.request_send_to_graveyard(target, Callable(), false, true)
	notify_power_activated(game_manager, target)
