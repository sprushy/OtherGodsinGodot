extends CreatureCard
class_name SixthSageAnEnlilda

const ART_PATH := "res://images/card_art/creatures/SixthSageEdit.png"

func _init() -> void:
	super._init()
	card_name = "Sixth Sage An-Enlilda"
	card_types = ["Mer", "Mage", "Priest", "Sage", "Ancient Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 15
	strength = 8
	ability_text = "[b]Conjure Home[/b] ([b]Impact[/b]): You may [b]Void[/b] this card. If you do, add an Ancient Dwelling from your deck to your hand."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		var no_target_text := resolve_no_conjure_home_targets()
		if game_manager != null:
			game_manager.note_player_feedback(no_target_text)
		return

	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_queue_sixth_sage_an_enlilda_impact_prompt"):
		prompt_host.call("_queue_sixth_sage_an_enlilda_impact_prompt", self)
		return

	var fallback_text := resolve_conjure_home_impact(game_manager, valid_targets[0])
	if game_manager != null:
		game_manager.note_player_feedback(fallback_text)

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.deck_zone == null:
		return valid_targets
	for card in controller.deck_zone.cards:
		if _is_valid_ancient_dwelling_target(card, controller):
			valid_targets.append(card)
	return valid_targets

func resolve_conjure_home_impact(game_manager: GameManager, target: Card) -> String:
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller for Conjure Home."
	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		return card_name + " found no valid Ancient Dwelling to add."
	if current_zone == null or not current_zone.is_board_zone():
		return "%s is no longer on the field to void for Conjure Home." % card_name

	if game_manager != null:
		game_manager.banish_card_with_hook(self)
	elif controller.abyss_zone != null:
		controller.move_card(self, controller.abyss_zone)

	if current_zone != controller.abyss_zone:
		return "%s could not be voided for Conjure Home." % card_name

	controller.move_card(target, controller.hand_zone)
	_shuffle_deck(controller)
	if target.current_zone != controller.hand_zone:
		return "%s voided itself, but could not move %s to hand." % [card_name, target.card_name]
	target.card_owner = controller
	return "%s voids itself and adds %s from the deck to %s's hand." % [
		card_name,
		target.card_name,
		controller.player_name
	]

func resolve_conjure_home_decline(_game_manager: GameManager) -> String:
	var controller := get_controller()
	if controller != null:
		_shuffle_deck(controller)
	return "%s stayed on the field and conjured no Dwelling." % card_name

func resolve_no_conjure_home_targets() -> String:
	var controller := get_controller()
	if controller != null:
		_shuffle_deck(controller)
	return "%s searched the deck but found no Ancient Dwellings." % card_name

func _shuffle_deck(controller: Player) -> void:
	if controller == null or controller.deck_zone == null:
		return
	controller.deck_zone.cards.shuffle()

func _is_valid_ancient_dwelling_target(card: Card, controller: Player) -> bool:
	return card != null \
		and controller != null \
		and card.current_zone == controller.deck_zone \
		and card.card_type == Card.CardType.STRUCTURE \
		and card.has_type("Dwelling") \
		and _is_ancient_dwelling(card)

func _is_ancient_dwelling(card: Card) -> bool:
	return card != null and (
		card.has_type("Ancient Structure")
		or card.has_type("Ancient")
		or str(card.culture).strip_edges() == "Ancient"
	)

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
