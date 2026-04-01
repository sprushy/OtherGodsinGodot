extends CreatureCard
class_name Lailoken

const MAGIC_DRAIN_BUFF_SOURCE := "Lailoken Magic Drain"
const MAGIC_DRAIN_STR_BONUS := 5

func _init() -> void:
	super._init()
	card_name = "Lailoken"
	card_types = ["Human", "Mage", "Triskelion Creature", "Targeting"]
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 12
	strength = 14
	targets = true
	ability_text = "[b]Magic Drain[/b] ([b]Reveal[/b]): Destroy a prepared magical card; if this effect is successful, gain 5 Str."
	flavor_text = ""
	culture = "Triskelion"
	artist = "Riccardo Zoppello"
	art_path = "res://images/card_art/creatures/LailokenEdit.png"

func on_reveal(game_manager: GameManager) -> void:
	if game_manager == null or abilities_suppressed():
		return
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		game_manager.note_player_feedback("%s found no prepared magical cards to drain." % card_name)
		return

	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_queue_lailoken_reveal_prompt"):
		prompt_host.call("_queue_lailoken_reveal_prompt", self)
		return

	begin_magic_drain_reveal(
		game_manager,
		valid_targets[0],
		func(result_text: String) -> void:
			if game_manager != null and result_text.strip_edges() != "":
				game_manager.note_player_feedback(result_text)
	)

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _is_valid_magic_drain_target(card):
					valid_targets.append(card)
	return valid_targets

func begin_magic_drain_reveal(
	game_manager: GameManager,
	target: Card,
	completion: Callable = Callable()
) -> void:
	var finish := func(result_text: String) -> void:
		if completion.is_valid():
			completion.call(result_text)
		elif game_manager != null and result_text.strip_edges() != "":
			game_manager.note_player_feedback(result_text)

	if game_manager == null:
		finish.call(card_name + " cannot resolve Magic Drain right now.")
		return

	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		finish.call(card_name + " found no valid prepared magical card to drain.")
		return
	if game_manager.is_immune_to_source(target, self):
		finish.call(
			"%s is immune to %s's creature abilities this turn." % [
				target.get_target_log_display_name(game_manager.get_feedback_viewer()),
				card_name
			]
		)
		return

	var viewer := game_manager.get_feedback_viewer()
	var target_name := target.get_target_log_display_name(viewer)
	var on_destroy_complete := func() -> void:
		var destroyed := target.current_zone == null or not target.current_zone.is_board_zone()
		if not destroyed:
			finish.call("%s failed to destroy %s with Magic Drain." % [card_name, target_name])
			return
		add_buff(
			MAGIC_DRAIN_BUFF_SOURCE,
			MAGIC_DRAIN_STR_BONUS,
			0,
			0,
			self,
			card_owner,
			"magic_drain"
		)
		finish.call("%s destroyed %s with Magic Drain and gained %d Str." % [
			card_name,
			target_name,
			MAGIC_DRAIN_STR_BONUS
		])
	game_manager.request_send_to_graveyard(
		target,
		on_destroy_complete,
		false,
		true
	)

func _is_valid_magic_drain_target(target: Card) -> bool:
	return target != null \
		and target != self \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.is_prepared \
		and target.is_magical_card()

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
