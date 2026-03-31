extends GodCard
class_name GuanYu

const TACTIC_COUNTER_COST := 4

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
	ability_text = "Tactical Break ([b]Passive[/b]/[b]Activate[/b]): At the start of each of your turns, if you have more creatures on the frontline than your opponent, gain 1 tactic counter. Remove 4 tactic counters to destroy a card.\n[b]Champion's Call[/b]"
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
		game_manager.note_player_feedback(
			"%s gains a tactic counter from Tactical Break (now %d). Frontline: %d vs %d." % [
				card_name, tactic_counters, my_count, opp_count
			]
		)

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if is_muted:
		return false
	if card_owner != game_manager.current_player:
		return false
	if tactic_counters < TACTIC_COUNTER_COST:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
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
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
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
	game_manager.note_player_feedback(
		"Tactical Break: %s spends %d tactic counters (now %d) to destroy %s." % [
			card_name, TACTIC_COUNTER_COST, tactic_counters, target.card_name
		]
	)
	game_manager.request_send_to_graveyard(target, Callable(), false, true)
	notify_power_activated(game_manager, target)

func on_removed(_game_manager: GameManager) -> void:
	tactic_counters = 0
	_last_counter_turn = -1

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
