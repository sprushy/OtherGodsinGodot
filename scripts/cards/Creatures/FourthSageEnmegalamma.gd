extends CreatureCard

func _init() -> void:
	super._init()
	card_name = "Fourth Sage Enmegalamma"
	card_types = ["Mer", "Mage", "Priest", "Sage", "Ancient Creature"]
	level = 3
	mana_cost = 3
	sacrifice_cost = 0
	speed = 1
	resilience = 15
	strength = 15
	ability_text = "[b]Search[/b] Sage ([b]Impact[/b]): You may add a Mer Sage from your deck to your hand except for another copy of this card."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/FourthSageAiEdit2.png"

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		var no_target_text := _resolve_no_search_targets()
		if game_manager != null:
			game_manager.note_player_feedback(no_target_text)
		return

	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_queue_fourth_sage_enmegalamma_impact_prompt"):
		prompt_host.call("_queue_fourth_sage_enmegalamma_impact_prompt", self)
		return

	var fallback_text := resolve_search_sage_impact(game_manager, valid_targets[0])
	if game_manager != null:
		game_manager.note_player_feedback(fallback_text)

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.deck_zone == null:
		return valid_targets
	for card in controller.deck_zone.cards:
		if _is_valid_search_target(card, controller):
			valid_targets.append(card)
	return valid_targets

func resolve_search_sage_impact(game_manager: GameManager, target: Card) -> String:
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller for Search Sage."
	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		return card_name + " found no valid Mer Sage to add."

	controller.move_card(target, controller.hand_zone)
	if target.current_zone != controller.hand_zone:
		return "%s could not move %s to hand." % [card_name, target.card_name]
	target.card_owner = controller
	_shuffle_deck(controller)
	return "%s added %s from the deck to %s's hand." % [
		card_name,
		target.card_name,
		controller.player_name
	]

func resolve_search_sage_decline(_game_manager: GameManager) -> String:
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller for Search Sage."
	_shuffle_deck(controller)
	return "%s searched the deck but took no Sage." % card_name

func _resolve_no_search_targets() -> String:
	var controller := get_controller()
	if controller != null:
		_shuffle_deck(controller)
	return "%s searched the deck but found no other Mer Sages." % card_name

func _shuffle_deck(controller: Player) -> void:
	if controller == null or controller.deck_zone == null:
		return
	controller.deck_zone.cards.shuffle()

func _is_valid_search_target(card: Card, controller: Player) -> bool:
	return card != null \
		and controller != null \
		and card.current_zone == controller.deck_zone \
		and card.card_type == Card.CardType.CREATURE \
		and card.has_type("Mer") \
		and card.has_type("Sage") \
		and card.card_name != card_name

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
