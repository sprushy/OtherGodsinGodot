extends CreatureCard
class_name Fenrir

const ART_PATH := "res://images/card_art/creatures/fenrir.jpg"
const DEVOUR_BUFF_SOURCE := "Fenrir Devour"

func _init() -> void:
	super._init()
	card_name = "Fenrir"
	card_types = ["Animal", "Lupine", "Norse Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 6
	is_legendary = true
	mana_cost = 0
	sacrifice_cost = 2
	speed = 2
	resilience = 20
	strength = 20
	targets = true
	ability_text = "[b]Wolf Master[/b]: [b]Shuffle[/b] this card from your hand. For your turn summon, you may summon a Lupine from your deck, paying its summon cost.\n[b]Devour[/b] ([b]Impact[/b]): Destroy a creature at least 2 levels weaker than this card and gain its Str and Res."
	culture = "Norse"
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

func get_hand_ability_label() -> String:
	return "Wolf Master"

func can_use_hand_ability(game_manager: GameManager) -> bool:
	if game_manager == null or card_owner == null:
		return false
	if current_zone != card_owner.hand_zone:
		return false
	if card_owner != game_manager.current_player:
		return false
	if card_owner.has_summoned_this_turn:
		return false
	if _get_open_summon_zones().is_empty():
		return false
	return not get_valid_wolf_master_summons_after_shuffle(game_manager).is_empty()

func perform_wolf_master_shuffle() -> bool:
	if card_owner == null:
		return false
	return card_owner.shuffle_card_into_deck(self)

func get_valid_wolf_master_summons(game_manager: GameManager = null) -> Array[Card]:
	var valid_cards: Array[Card] = []
	if card_owner == null:
		return valid_cards
	for card in card_owner.deck_zone.cards:
		if _is_valid_lupine(card) and _can_pay_wolf_master_cost_for(card, game_manager):
			valid_cards.append(card)
	return valid_cards

func get_valid_wolf_master_summons_after_shuffle(game_manager: GameManager = null) -> Array[Card]:
	if card_owner == null:
		return []
	if current_zone == card_owner.deck_zone:
		return get_valid_wolf_master_summons(game_manager)
	var valid_cards := get_valid_wolf_master_summons(game_manager)
	if _is_valid_lupine(self) and current_zone == card_owner.hand_zone and self not in valid_cards and _can_pay_wolf_master_cost_for(self, game_manager):
		valid_cards.append(self)
	return valid_cards

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_devour_targets(game_manager)
	if valid_targets.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("%s found no creature weak enough to devour." % card_name)
		return

	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_queue_fenrir_devour_prompt"):
		prompt_host.call("_queue_fenrir_devour_prompt", self)
		return

	resolve_devour_impact(game_manager, valid_targets[0], func(feedback: String) -> void:
		if game_manager != null:
			game_manager.note_player_feedback(feedback)
	)

func get_valid_devour_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _is_valid_devour_target(card):
					valid_targets.append(card)
	return valid_targets

func resolve_devour_impact(game_manager: GameManager, target: Card, continue_callback: Callable = Callable()) -> void:
	if game_manager == null:
		_emit_devour_result(continue_callback, card_name + " cannot devour right now.")
		return
	var valid_targets := get_valid_devour_targets(game_manager)
	if target == null or target not in valid_targets:
		_emit_devour_result(continue_callback, card_name + " found no creature weak enough to devour.")
		return
	if game_manager.is_guardian_protected(target, self):
		_emit_devour_result(continue_callback, target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is protected by Guardian!")
		return
	if game_manager.is_immune_to_source(target, self):
		_emit_devour_result(continue_callback, target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is immune to " + card_name + "'s creature abilities this turn.")
		return

	var devoured_name := target.get_target_log_display_name(game_manager.get_feedback_viewer())
	var gained_strength := target.get_effective_strength()
	var gained_resilience := target.get_effective_resilience()
	game_manager.request_send_to_graveyard(target, func() -> void:
		var left_board := target.current_zone == null or not target.current_zone.is_board_zone()
		if left_board:
			add_buff(DEVOUR_BUFF_SOURCE, gained_strength, gained_resilience, 0, self, card_owner, "fenrir_devour")
			_emit_devour_result(
				continue_callback,
				"%s devoured %s and gained %d Str and %d Res." % [
					card_name,
					devoured_name,
					gained_strength,
					gained_resilience
				]
			)
		else:
			_emit_devour_result(continue_callback, "%s could not devour %s." % [card_name, devoured_name])
	, false, true)

func _is_valid_lupine(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.has_type("Lupine")

func _is_valid_devour_target(card: Card) -> bool:
	return card != null \
		and card != self \
		and card.card_type == Card.CardType.CREATURE \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and card.level <= level - 2

func _get_open_summon_zones() -> Array[Zone]:
	var open_zones: Array[Zone] = []
	if card_owner == null:
		return open_zones
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		if zone.cards.is_empty():
			open_zones.append(zone)
	return open_zones

func _can_pay_wolf_master_cost_for(card: Card, game_manager: GameManager) -> bool:
	if card_owner == null or card == null:
		return false
	if game_manager == null:
		return true
	return game_manager.can_pay_creature_summon_cost(card_owner, card, self, true)

func _emit_devour_result(callback: Callable, feedback: String) -> void:
	if callback.is_valid():
		callback.call(feedback)

func _get_prompt_host(game_manager: GameManager = null) -> Node:
	if game_manager != null:
		var direct_host := game_manager.get_interaction_host()
		var direct_node := direct_host as Node
		if direct_node != null and is_instance_valid(direct_node):
			return direct_node
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var hosts: Array = tree.get_nodes_in_group("combat_mock_game")
	if tree.current_scene != null:
		for host in hosts:
			var node: Node = host as Node
			if node != null and node.is_inside_tree() and (node == tree.current_scene or tree.current_scene.is_ancestor_of(node)):
				return node
	for host in hosts:
		var node: Node = host as Node
		if node != null and node.is_inside_tree() and node.get("game_manager") != null:
			return node
	if tree.current_scene != null:
		return tree.current_scene
	return null
