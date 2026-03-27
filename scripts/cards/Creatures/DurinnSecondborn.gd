extends CreatureCard
class_name DurinnSecondborn

func _init() -> void:
	super._init()
	card_name = "Durinn Secondborn"
	card_types = ["Dwarf", "Smith", "Norse Creature", "Targeting"]
	level = 2
	mana_cost = 2
	sacrifice_cost = 0
	speed = 1
	resilience = 5
	strength = 14
	ability_text = "Reforge ([b]Impact[/b]): Add a Weapon from either graveyard to your hand."
	flavor_text = ""
	culture = "Norse"
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/DurinnAIEdit.png"
	targets = true

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("%s found no weapons to reforge." % card_name)
		return

	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_queue_durinn_secondborn_impact_prompt"):
		prompt_host.call("_queue_durinn_secondborn_impact_prompt", self)
		return

	var fallback_text := resolve_reforge_impact(game_manager, valid_targets[0])
	if game_manager != null:
		game_manager.note_player_feedback(fallback_text)

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for card in player.graveyard_zone.cards:
			if _is_valid_reforge_target(card):
				valid_targets.append(card)
	return valid_targets

func resolve_reforge_impact(game_manager: GameManager, target: Card) -> String:
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller for Reforge."
	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		return card_name + " found no valid weapon to reforge."

	var previous_owner := target.card_owner
	if previous_owner == null:
		previous_owner = controller
	previous_owner.move_card(target, controller.hand_zone)
	if target.current_zone != controller.hand_zone:
		return "%s could not move %s to hand." % [card_name, target.card_name]
	target.card_owner = controller

	var graveyard_label := "your graveyard" if previous_owner == controller else "%s's graveyard" % previous_owner.player_name
	return "%s reforged %s from %s into %s's hand." % [
		card_name,
		target.card_name,
		graveyard_label,
		controller.player_name
	]

func _is_valid_reforge_target(card: Card) -> bool:
	return card != null \
		and card.current_zone != null \
		and card.current_zone.zone_type == Zone.ZoneType.GRAVEYARD \
		and card.card_type == Card.CardType.EQUIPMENT \
		and card.has_type("Weapon")

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
