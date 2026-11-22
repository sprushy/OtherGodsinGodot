extends CreatureCard
class_name HabrokParagonOfHawks

const ART_PATH := "res://images/card_art/creatures/habrok_paragon_of_hawks.png"

var _breakout_choice_consumed_turn: int = -1

func _init() -> void:
	super._init()
	card_name = "Habrok, Paragon of Hawks"
	card_types = ["Animal", "Avian", "Aerial", "Targeting"]
	level = 4
	mana_cost = 2
	sacrifice_cost = 0
	speed = 2
	resilience = 13
	strength = 21
	culture = "Norse"
	artist = "Lorinda Tomko"
	art_path = ART_PATH
	ability_text = "[b]Breakout[/b]: At the end of your opponent's turn, if Habrok is your only creature, you may return it to your hand. If you do, destroy your opponent's creature with the lowest STR. If tied, choose one."

func on_global_turn_end(game_manager: GameManager, ending_player: Player) -> void:
	if game_manager != null and _breakout_choice_consumed_turn == game_manager.turn_number:
		_breakout_choice_consumed_turn = -1
		return
	if not can_trigger_breakout(game_manager, ending_player):
		return
	# Breakout is optional. If the controller was not prompted before turn end,
	# the trigger simply goes unused instead of resolving automatically.

func can_trigger_breakout(game_manager: GameManager, ending_player: Player) -> bool:
	if game_manager == null or ending_player == null:
		return false
	if _breakout_choice_consumed_turn == game_manager.turn_number:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if abilities_suppressed():
		return false
	if is_face_down or is_stealth or is_prepared:
		return false

	var controller: Player = get_controller()
	if controller == null or ending_player == controller:
		return false

	return _is_only_friendly_board_creature(controller)

func get_breakout_prompt_text(game_manager: GameManager, viewer: Player) -> String:
	var targets := get_breakout_targets(game_manager)
	if targets.is_empty():
		return "Return %s to your hand?" % card_name
	if targets.size() > 1:
		return "Return %s to your hand and choose a creature tied for lowest STR to destroy?" % card_name
	return "Return %s to your hand and destroy %s?" % [card_name, targets[0].get_target_log_display_name(viewer)]

func resolve_breakout_choice(game_manager: GameManager, do_breakout: bool, target: Card = null) -> void:
	if game_manager == null:
		return
	_consume_breakout_choice(game_manager)
	if not do_breakout:
		game_manager.note_player_feedback("%s stays on the field." % card_name)
		return
	if current_zone == null or not current_zone.is_board_zone():
		game_manager.note_player_feedback("%s can no longer break out." % card_name)
		return

	var valid_targets := get_breakout_targets(game_manager)
	_return_to_hand()

	if target == null:
		game_manager.note_player_feedback("%s breaks out and returns to hand." % card_name)
		return

	if target not in valid_targets:
		game_manager.note_player_feedback("%s returns to hand, but its Breakout target is no longer valid." % card_name)
		return

	var viewer := game_manager.get_feedback_viewer()
	var target_name: String = target.get_target_log_display_name(viewer)
	game_manager.request_send_to_graveyard(target, func() -> void:
		var destroyed := game_manager.reached_public_destroyed_destination(target)
		if destroyed:
			var destroyed_name := game_manager.get_resolved_destruction_log_name(target, viewer, target_name)
			game_manager.note_player_feedback(
				"%s breaks out, returns to hand, and destroys %s." % [card_name, destroyed_name]
			)
		else:
			game_manager.note_player_feedback(
				"%s breaks out and returns to hand, but %s survives." % [card_name, target_name]
			)
	, false, true, false, self)

func _is_only_friendly_board_creature(controller: Player) -> bool:
	var friendly_creatures := 0
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if card == null:
				continue
			if card.card_type != Card.CardType.CREATURE or card.is_god:
				continue
			friendly_creatures += 1
			if friendly_creatures > 1:
				return false
	return friendly_creatures == 1

func _get_enemy_board_creatures(game_manager: GameManager) -> Array[Card]:
	var creatures: Array[Card] = []
	if game_manager == null:
		return creatures

	var controller: Player = get_controller()
	var opponent: Player = game_manager.get_opponent(controller) if controller != null else null
	if opponent == null:
		return creatures

	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if _is_valid_enemy_creature(card):
				creatures.append(card)
	return creatures

func get_breakout_targets(game_manager: GameManager) -> Array[Card]:
	var candidates: Array[Card] = _get_enemy_board_creatures(game_manager)
	if candidates.is_empty():
		return candidates

	var lowest_strength: int = candidates[0].get_effective_strength()
	for candidate in candidates:
		lowest_strength = mini(lowest_strength, candidate.get_effective_strength())
	return candidates.filter(func(card: Card) -> bool:
		return card.get_effective_strength() == lowest_strength and not game_manager.is_immune_to_source(card, self)
	)

func _is_valid_enemy_creature(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.current_zone != null \
		and card.current_zone.is_board_zone()

func _return_to_hand() -> void:
	if card_owner == null:
		return
	card_owner.move_card(self, card_owner.hand_zone)

func _consume_breakout_choice(game_manager: GameManager) -> void:
	_breakout_choice_consumed_turn = game_manager.turn_number if game_manager != null else -1

