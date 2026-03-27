extends HexCard
class_name FoolishOptimism

func _init() -> void:
	super._init()
	card_name = "Foolish Optimism"
	culture = "Neutral"
	card_types = ["Compulsion", "Attack"]
	level = 1
	mana_cost = 1
	speed = 2
	is_legendary = false
	sacrifice_cost = 0
	flavor_text = ""
	artist = "David Revoy"
	art_path = "res://images/card_art/hexes/foolish_optimism_crop.jpg"
	ability_text = "After upkeep, force your opponent's lowest lvl creature to attack your highest lvl creature."

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	if game_manager == null:
		return false
	if not game_manager.has_resolved_turn_upkeep():
		print(card_name + " can only be used after upkeep.")
		return false
	return true

func can_respond_to_action(_action: CardAction) -> bool:
	return true

func on_activate_action(game_manager: GameManager, action: CardAction) -> void:
	var resolution_text := _begin_resolution(game_manager)
	if resolution_text == "":
		return
	action.resolution_text = resolution_text
	send_to_graveyard_if_needed()

func resolve(game_manager: GameManager, target = null) -> void:
	if game_manager == null:
		return
	var resolution_text := _begin_resolution(game_manager)
	if resolution_text == "":
		return
	print(resolution_text)

func resolve_with_choices(game_manager: GameManager, attacker: Card, defender: Card) -> String:
	if game_manager == null:
		return card_name + " fizzles."
	if attacker == null:
		return "%s fizzles: no opposing creature to compel when it resolves." % card_name
	if defender == null:
		return "%s fizzles: no friendly creature to attack when it resolves." % card_name
	if attacker.current_zone == null or not attacker.current_zone.is_board_zone():
		return "%s fizzles: the chosen attacker is no longer on the field." % card_name
	if defender.current_zone == null or not defender.current_zone.is_board_zone():
		return "%s fizzles: the chosen defender is no longer on the field." % card_name
	if not _can_force_attack(game_manager, attacker, defender):
		return "%s fizzles: %s cannot legally attack %s." % [card_name, attacker.card_name, defender.card_name]

	var feedback := "%s compels %s to attack %s." % [card_name, attacker.card_name, defender.card_name]
	print(feedback)
	game_manager.creature_attack(attacker, defender)
	return feedback

func finish_prompt_resolution(game_manager: GameManager, attacker: Card, defender: Card) -> String:
	var feedback := resolve_with_choices(game_manager, attacker, defender)
	send_to_graveyard_if_needed()
	return feedback

func send_to_graveyard_if_needed() -> void:
	if card_owner == null or current_zone == null:
		return
	if current_zone == card_owner.graveyard_zone:
		return
	card_owner.move_card(self, card_owner.graveyard_zone)

func get_forced_attacker_candidates(game_manager: GameManager) -> Array[Card]:
	var controller := _get_spell_controller(game_manager)
	var opponent := game_manager.get_opponent(controller) if game_manager != null and controller != null else null
	return _get_board_creatures(opponent)

func get_forced_defender_candidates(game_manager: GameManager) -> Array[Card]:
	var controller := _get_spell_controller(game_manager)
	return _get_board_creatures(controller)

func get_lowest_level_attacker_choices(game_manager: GameManager) -> Array[Card]:
	var candidates := get_forced_attacker_candidates(game_manager)
	if candidates.is_empty():
		return []
	var lowest_level := candidates[0].level
	for creature in candidates:
		lowest_level = mini(lowest_level, creature.level)
	var ties: Array[Card] = []
	for creature in candidates:
		if creature.level == lowest_level:
			ties.append(creature)
	return ties

func get_highest_level_defender_choices(game_manager: GameManager) -> Array[Card]:
	var candidates := get_forced_defender_candidates(game_manager)
	if candidates.is_empty():
		return []
	var highest_level := candidates[0].level
	for creature in candidates:
		highest_level = maxi(highest_level, creature.level)
	var ties: Array[Card] = []
	for creature in candidates:
		if creature.level == highest_level:
			ties.append(creature)
	return ties

func get_forced_attacker(game_manager: GameManager) -> Card:
	var choices := get_lowest_level_attacker_choices(game_manager)
	return choices[0] if not choices.is_empty() else null

func get_forced_defender(game_manager: GameManager) -> Card:
	var choices := get_highest_level_defender_choices(game_manager)
	return choices[0] if not choices.is_empty() else null

func _get_spell_controller(game_manager: GameManager) -> Player:
	if card_owner != null:
		return card_owner
	if game_manager != null:
		return game_manager.current_player
	return null

func _get_board_creatures(player: Player) -> Array[Card]:
	var creatures: Array[Card] = []
	if player == null:
		return creatures
	for zone in player.frontline_zones + player.reserve_zones:
		for card in zone.cards:
			if card != null and card.card_type == Card.CardType.CREATURE and not card.is_god:
				creatures.append(card)
	return creatures

func _pick_lowest_level_creature(candidates: Array[Card]) -> Card:
	var chosen: Card = null
	for creature in candidates:
		if chosen == null or creature.level < chosen.level:
			chosen = creature
	return chosen

func _pick_highest_level_creature(candidates: Array[Card]) -> Card:
	var chosen: Card = null
	for creature in candidates:
		if chosen == null or creature.level > chosen.level:
			chosen = creature
	return chosen

func _begin_resolution(game_manager: GameManager) -> String:
	var attacker_choices := get_lowest_level_attacker_choices(game_manager)
	if attacker_choices.is_empty():
		return "%s fizzles: no opposing creature to compel when it resolves." % card_name
	var defender_choices := get_highest_level_defender_choices(game_manager)
	if defender_choices.is_empty():
		return "%s fizzles: no friendly creature to attack when it resolves." % card_name

	var prompt_host := _get_prompt_host(game_manager)
	if (attacker_choices.size() > 1 or defender_choices.size() > 1) \
			and prompt_host != null \
			and prompt_host.has_method("_resolve_foolish_optimism_prompt"):
		prompt_host.call("_resolve_foolish_optimism_prompt", self, attacker_choices, defender_choices)
		return ""

	return resolve_with_choices(game_manager, attacker_choices[0], defender_choices[0])

func _can_force_attack(game_manager: GameManager, attacker: Card, defender: Card) -> bool:
	if game_manager == null or attacker == null or defender == null:
		return false
	var attacker_controller := attacker.get_controller()
	if attacker_controller == null:
		return false
	if game_manager.attack_restrictions.has(attacker_controller):
		return false
	if attacker.is_sleeping:
		return false
	if not attacker.get_status_effect("cannot_attack").is_empty():
		return false
	if not attacker.can_take_major_creature_action():
		return false
	if attacker.current_zone == null or attacker.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		return false
	if attacker.creature_mode == Card.CreatureMode.DEFENSIVE:
		return false
	if attacker.has_method("can_engage") and not attacker.can_engage(defender):
		return false
	if defender.has_method("can_be_engaged_by") and not defender.can_be_engaged_by(attacker):
		return false
	return true

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
