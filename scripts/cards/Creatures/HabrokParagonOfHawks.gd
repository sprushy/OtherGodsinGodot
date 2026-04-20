extends CreatureCard
class_name HabrokParagonOfHawks

const ART_PATH := "res://images/card_art/creatures/habrok_paragon_of_hawks.png"

var _breakout_choice_consumed_turn: int = -1

func _init() -> void:
	super._init()
	card_name = "Habrok, Paragon of Hawks"
	card_types = ["Animal", "Avian", "Aerial", "Norse Creature"]
	level = 4
	mana_cost = 2
	sacrifice_cost = 0
	speed = 2
	resilience = 13
	strength = 21
	culture = "Norse"
	artist = "Lorinda Tomko"
	art_path = ART_PATH
	ability_text = "[b]Breakout[/b]: If at the end of your opponent's turn this creature is the only one you control, you may return it to your hand and destroy your opponent's weakest creature."

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

func get_breakout_prompt_text(game_manager: GameManager) -> String:
	var target: Card = _get_weakest_enemy_creature(game_manager)
	if target == null:
		return "Return %s to your hand?" % card_name
	return "Return %s to your hand and destroy %s?" % [card_name, target.card_name]

func resolve_breakout_choice(game_manager: GameManager, do_breakout: bool) -> void:
	if game_manager == null:
		return
	_consume_breakout_choice(game_manager)
	if not do_breakout:
		game_manager.note_player_feedback("%s stays on the field." % card_name)
		return
	if current_zone == null or not current_zone.is_board_zone():
		game_manager.note_player_feedback("%s can no longer break out." % card_name)
		return

	var weakest_enemy: Card = _get_weakest_enemy_creature(game_manager)
	_return_to_hand()

	if weakest_enemy == null:
		game_manager.note_player_feedback("%s breaks out and returns to hand." % card_name)
		return

	if game_manager.is_immune_to_source(weakest_enemy, self):
		game_manager.note_player_feedback(
			"%s breaks out and returns to hand, but %s is immune to creature abilities." % [
				card_name,
				weakest_enemy.card_name
			]
		)
		return

	var target_name: String = weakest_enemy.get_target_log_display_name(game_manager.get_feedback_viewer())
	game_manager.request_send_to_graveyard(weakest_enemy, func() -> void:
		var destroyed: bool = weakest_enemy.current_zone == null or not weakest_enemy.current_zone.is_board_zone()
		if destroyed:
			game_manager.note_player_feedback(
				"%s breaks out, returns to hand, and destroys %s." % [card_name, target_name]
			)
		else:
			game_manager.note_player_feedback(
				"%s breaks out and returns to hand, but %s survives." % [card_name, target_name]
			)
	, false, true)

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

func _get_weakest_enemy_creature(game_manager: GameManager) -> Card:
	var candidates: Array[Card] = _get_enemy_board_creatures(game_manager)
	if candidates.is_empty():
		return null

	var lowest_strength: int = candidates[0].get_effective_strength()
	for candidate in candidates:
		lowest_strength = mini(lowest_strength, candidate.get_effective_strength())
	candidates = candidates.filter(func(card: Card) -> bool:
		return card.get_effective_strength() == lowest_strength
	)

	var lowest_resilience: int = candidates[0].get_effective_resilience()
	for candidate in candidates:
		lowest_resilience = mini(lowest_resilience, candidate.get_effective_resilience())
	candidates = candidates.filter(func(card: Card) -> bool:
		return card.get_effective_resilience() == lowest_resilience
	)

	var destroyable_candidates: Array[Card] = candidates.filter(func(card: Card) -> bool:
		return game_manager != null and not game_manager.is_immune_to_source(card, self)
	)
	if not destroyable_candidates.is_empty():
		candidates = destroyable_candidates

	return candidates[0]

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

