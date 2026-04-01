extends CreatureCard
class_name Huginn

func _init() -> void:
	super._init()
	card_name = "Huginn"
	card_types = ["Animal", "Avian", "Raven", "Aerial", "Norse Creature"]
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 4
	resilience = 3
	strength = 7
	ability_text = "[b]Hex Search[/b] ([b]Prime[/b], [b]Perish[/b]): Prime one Hex."
	flavor_text = ""
	culture = "Norse"
	artist = "Daniel Decena"
	art_path = "res://images/card_art/creatures/Huginn.png"

func on_removed(game_manager: GameManager) -> void:
	call_deferred("_resolve_perish_prime", game_manager)

func _resolve_perish_prime(game_manager: GameManager) -> void:
	if game_manager == null or card_owner == null or card_owner.deck_zone == null:
		return
	if current_zone != card_owner.graveyard_zone:
		return
	var valid_hexes := get_valid_hex_targets()
	if valid_hexes.is_empty():
		game_manager.note_player_feedback("%s perished, but found no hex to prime." % card_name)
		return
	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_queue_huginn_perish_prime_prompt"):
		prompt_host.call("_queue_huginn_perish_prime_prompt", self)
		return
	game_manager.note_player_feedback(resolve_perish_prime_choice(game_manager, valid_hexes[0]))

func resolve_perish_prime_choice(game_manager: GameManager, chosen_hex: Card = null) -> String:
	if game_manager == null or card_owner == null or card_owner.deck_zone == null:
		return card_name + " found no deck to prime."
	var valid_hexes := get_valid_hex_targets()
	if valid_hexes.is_empty():
		return "%s perished, but found no hex to prime." % card_name
	var resolved_hex := chosen_hex if chosen_hex != null and chosen_hex in valid_hexes else valid_hexes[0]
	card_owner.deck_zone.cards.erase(resolved_hex)
	card_owner.deck_zone.cards.insert(0, resolved_hex)
	return "%s perished and primed %s." % [card_name, resolved_hex.card_name]

func get_valid_hex_targets() -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null or card_owner.deck_zone == null:
		return valid_targets
	for card in card_owner.deck_zone.cards:
		if card != null and card.current_zone == card_owner.deck_zone and card.card_type == Card.CardType.HEX:
			valid_targets.append(card)
	return valid_targets

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
