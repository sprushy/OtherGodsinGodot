extends RefCounted

const MAX_RESOLUTION_STEPS := 24
const CardStrategy = preload("res://scripts/bots/BotCardStrategy.gd")

var game: GameManager
var match_rules: MatchManager
var bots: Array = []
var _unknown_cards: Dictionary[Card, Zone] = {}

static func capture(bot) -> Dictionary:
	var seat: int = bot.player_index
	var snapshot := GameState.serialize(bot.game_manager, seat)
	# A player knows their deck list and posted placements, not the order of
	# unplaced cards. An unknown draw in a branch cannot unlock a known play.
	var own_deck: Array = snapshot["players"][seat]["deck"]
	for index in own_deck.size():
		if int(own_deck[index].get("deck_placement", Zone.DeckPlacement.UNKNOWN)) == Zone.DeckPlacement.UNKNOWN:
			own_deck[index] = {"hidden": true, "deck_index": index}
	# Preserve cards already known to this planner, including prepared cards
	# whose identities have been revealed.
	var opponent_data: Dictionary = snapshot["players"][1 - seat]
	for key in ["frontline_zones", "reserve_zones"]:
		for lane: Array in opponent_data[key]:
			for index in lane.size():
				var entry: Dictionary = lane[index]
				if not entry.get("hidden", false):
					continue
				var card: Card = bot.game_manager.get_card_by_uid(str(entry.get("uid", "")))
				if CardStrategy.visible(bot, card):
					lane[index] = GameState.serialize_embedded_card(card)
	snapshot.erase("priority_response_uids")
	return snapshot


func _init(origin, snapshot: Dictionary) -> void:
	var live: GameManager = origin.game_manager
	game = GameManager.new()
	game.sfx_enabled = false
	game.log_player_feedback = false
	var rng := RandomNumberGenerator.new()
	rng.seed = live.turn_number
	for source in live.players:
		var player := Player.new()
		player.game_manager = game
		player.followers_enabled = source.followers_enabled
		player.deck_zone.shuffle_rng = rng
		game.players.append(player)
	GameState.apply_to_manager(snapshot, game)
	game.upkeep_mana_enabled = live.upkeep_mana_enabled
	game._next_board_entry_order = live._next_board_entry_order
	for field in ["died_this_turn", "destroyed_this_turn", "pending_resurrections"]:
		var cards: Array[Card] = game.get(field)
		for source: Card in live.get(field):
			var copy := game.get_card_by_uid(source.uid)
			if copy != null:
				cards.append(copy)
	for index in game.players.size():
		var player := game.players[index]
		player.is_turn_player = player == game.current_player
		if index == origin.player_index:
			var reserved: Card = live.players[index].reserved_active_god
			if reserved != null:
				player.reserved_active_god = GameState.deserialize_embedded_card(GameState.serialize_embedded_card(reserved)) as ActiveGodCard
				if player.reserved_active_god != null:
					player.reserved_active_god.card_owner = player
		for zone in GameState._get_player_card_zones(player):
			for card in zone.cards:
				if card.uid.is_empty() or card.card_name == "Hidden card":
					_unknown_cards[card] = zone
					continue
				var source := live.get_card_by_uid(card.uid)
				if source == null:
					continue
				var owner_index := live.players.find(source.card_owner)
				if owner_index >= 0:
					card.card_owner = game.players[owner_index]
				card.creature_shift_used_this_turn = source.creature_shift_used_this_turn
				card.has_moved_this_turn = source.has_moved_this_turn
				card.has_attacked_this_turn = source.has_attacked_this_turn
				card.has_acted_this_turn = source.has_acted_this_turn
				if card is RedCap and source is RedCap:
					card._resolved_attack_this_turn = source._resolved_attack_this_turn
				card.last_board_zone_type = source.last_board_zone_type
				card.last_board_zone_index = source.last_board_zone_index
	match_rules = MatchManager.new(game)
	for index in game.players.size():
		bots.append(origin._new_turn_projection_bot(game, match_rules, index))

func _outcome_is_known(seat: int) -> bool:
	for card in _unknown_cards:
		if card.current_zone != _unknown_cards[card] or CardStrategy.visible(bots[seat], card):
			return false
	return true


func play(seat: int, command: Dictionary) -> bool:
	if not bots[seat].game_input.submit_action(command.duplicate(true)):
		return false
	for step in MAX_RESOLUTION_STEPS:
		if game.is_game_over:
			return _outcome_is_known(seat)
		var prompts := match_rules.get_pending_ui_interaction_entries()
		if not prompts.is_empty():
			var prompt: Dictionary = prompts[0]
			var index := game.players.find(prompt.get("player"))
			if index < 0:
				return false
			var data: Dictionary = prompt["data"].duplicate(true)
			data["_prompt_id"] = prompt["prompt_id"]
			if prompt["type"] == "priority":
				bots[index]._handle_priority()
			else:
				bots[index]._handle_ui_interaction(index, prompt["type"], data)
			var remaining := match_rules.get_pending_ui_interaction_entries()
			if not remaining.is_empty() and remaining[0]["prompt_id"] == prompt["prompt_id"]:
				return false
			continue
		if match_rules.is_targeting_active():
			var handled := false
			for bot in bots:
				if bot._owns_pending_click_selection():
					bot._resolve_own_click_selection(false)
					handled = true
					break
			if not handled:
				return false
			continue
		if game.action_stack.is_empty():
			return game.resolving_stack_actions.is_empty() and match_rules.selected_attacker == null and _outcome_is_known(seat)
		match_rules.advance_priority()
	return false


func release() -> void:
	for bot in bots:
		bot.detach()
	bots.clear()
	_unknown_cards.clear()
	match_rules.reset_runtime_state()
	for action in game.action_stack + game.resolving_stack_actions:
		action.resolve_callback = Callable()
	game.action_stack.clear()
	game.resolving_stack_actions.clear()
	game._pending_doorway_continue = Callable()
	game._queued_doorway_requests.clear()
	game._pending_return_to_hand_continue = Callable()
	game._deferred_combat_resume = Callable()
	for player in game.players:
		player.game_manager = null
		player.reserved_active_god = null
		for zone in GameState._get_player_card_zones(player):
			for card in zone.cards:
				card.active_buffs.clear()
				card.active_statuses.clear()
				card.sleeping_from = null
				for equipment in card.equipment:
					equipment.equipped_on = null
				card.equipment.clear()
				card.current_zone = null
			zone.cards.clear()
			zone.clear_deck_knowledge()
			zone.zone_owner = null
	game.players.clear()
	match_rules = null
	game = null
