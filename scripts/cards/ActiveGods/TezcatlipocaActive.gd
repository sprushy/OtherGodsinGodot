extends ActiveGodCard
class_name TezcatlipocaActive

const LINKED_GOD_NAME := "Tezcatlipoca, the Smoking Mirror"
const ART_PATH := "res://images/card_art/gods/TezArt.png"
const MAX_TITLACAUAN_TARGETS := 2

var necoc_yaotl_sacrifices: Array[Card] = []

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Tezcatlipoca, Active God"
	card_types = ["Active God", "Divine Manifestation", "God", "Targeting"]
	level = 10
	mana_cost = 0
	speed = 3
	resilience = 31
	strength = 31
	culture = "Nahuatl"
	flavor_text = "Smoke and sacrifice crown the god of night when he walks the field."
	ability_text = "[b]Titlacauan[/b] ([b]Impact[/b]): Enslave up to 2 creatures whose total levels are less than or equal to the total levels sacrificed for Necoc Yaotl."
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	name_at_bottom = true

func receive_necoc_yaotl_sacrifices(cards: Array[Card]) -> void:
	necoc_yaotl_sacrifices.clear()
	for card in cards:
		if card != null:
			necoc_yaotl_sacrifices.append(card)

func get_titlacauan_level_budget() -> int:
	var total := 0
	for card in necoc_yaotl_sacrifices:
		if card != null:
			total += card.get_effective_level()
	return total

func get_valid_titlacauan_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if game_manager == null or controller == null:
		return valid_targets
	var opponent := game_manager.get_opponent(controller)
	if opponent == null:
		return valid_targets
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if _is_valid_titlacauan_target(game_manager, card):
				valid_targets.append(card)
	return valid_targets

func get_selected_titlacauan_targets(game_manager: GameManager, target_data) -> Array[Card]:
	var selected: Array[Card] = []
	var raw_choices: Array = []
	if target_data is Array:
		raw_choices = target_data
	elif target_data is Dictionary:
		raw_choices = target_data.get("target_uids", [])
	var valid_targets := get_valid_titlacauan_targets(game_manager)
	for entry in raw_choices:
		var card: Card = null
		if entry is Card:
			card = entry as Card
		elif game_manager != null:
			card = game_manager.get_card_by_uid(str(entry))
		if card == null or card in selected or card not in valid_targets:
			continue
		selected.append(card)
	return selected

func is_valid_titlacauan_selection(game_manager: GameManager, chosen_targets: Array[Card]) -> bool:
	if chosen_targets.size() > MAX_TITLACAUAN_TARGETS:
		return false
	var total_levels := 0
	var valid_targets := get_valid_titlacauan_targets(game_manager)
	for target in chosen_targets:
		if target == null or target not in valid_targets:
			return false
		total_levels += target.get_effective_level()
	return total_levels <= get_titlacauan_level_budget()

func on_impact(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_queue_tezcatlipoca_active_titlacauan_prompt"):
		prompt_host.call("_queue_tezcatlipoca_active_titlacauan_prompt", self)
		return
	game_manager.note_player_feedback(resolve_titlacauan_choice(game_manager))

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var option: Dictionary = command.get("option", {})
	var skip_choice := bool(option.get("skip", command.get("skip", false)))
	var chosen_targets := get_selected_titlacauan_targets(game_manager, option if not option.is_empty() else command)
	game_manager.note_player_feedback(resolve_titlacauan_choice(game_manager, chosen_targets, not skip_choice))

func resolve_titlacauan_choice(game_manager: GameManager, chosen_targets: Array[Card] = [], auto_select_if_empty: bool = true) -> String:
	if game_manager == null:
		return card_name + " cannot resolve Titlacauan right now."
	var budget := get_titlacauan_level_budget()
	if budget <= 0:
		return "%s has no Necoc Yaotl sacrifices powering Titlacauan." % card_name
	var valid_targets := get_valid_titlacauan_targets(game_manager)
	if valid_targets.is_empty():
		return "%s found no creatures it could enslave with Titlacauan." % card_name

	var resolved_targets := chosen_targets
	if resolved_targets.is_empty():
		if auto_select_if_empty:
			resolved_targets = _auto_select_titlacauan_targets(valid_targets, budget)
	elif not is_valid_titlacauan_selection(game_manager, resolved_targets):
		return "%s needs a valid Titlacauan selection." % card_name

	if resolved_targets.is_empty():
		return "%s chooses no targets for Titlacauan." % card_name

	var enslaved_names: Array[String] = []
	for target in resolved_targets:
		if target == null:
			continue
		if not game_manager.enslave_creature(target, get_controller()):
			return "%s failed to enslave %s." % [card_name, target.card_name]
		enslaved_names.append(target.get_target_log_display_name(game_manager.get_feedback_viewer()))

	return "%s uses Titlacauan to enslave %s." % [card_name, ", ".join(enslaved_names)]

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	lines.append("Titlacauan budget: %d" % get_titlacauan_level_budget())
	lines.append("Necoc Yaotl sacrifices: %d" % necoc_yaotl_sacrifices.size())
	return lines

func _is_valid_titlacauan_target(game_manager: GameManager, target: Card) -> bool:
	return target != null \
		and target.card_type == Card.CardType.CREATURE \
		and not target.is_god \
		and not target.is_face_down \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.get_controller() != get_controller() \
		and game_manager.can_enslave_creature(target, get_controller()) \
		and not game_manager.is_immune_to_source(target, self)

func _auto_select_titlacauan_targets(valid_targets: Array[Card], budget: int) -> Array[Card]:
	var sorted_targets := valid_targets.duplicate()
	sorted_targets.sort_custom(func(a: Card, b: Card) -> bool:
		return a.get_effective_level() < b.get_effective_level()
	)
	var chosen: Array[Card] = []
	var remaining_budget := budget
	for target in sorted_targets:
		if target == null or chosen.size() >= MAX_TITLACAUAN_TARGETS:
			break
		var target_level = target.get_effective_level()
		if target_level > remaining_budget:
			continue
		chosen.append(target)
		remaining_budget -= target_level
	return chosen

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
