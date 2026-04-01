extends CreatureCard
class_name KurJara

var _tree_of_life_target: Card = null
var _tree_of_life_gm: GameManager = null
var _tree_of_life_activation_turn: int = -1
var _tree_of_life_turns_remaining: int = -1
var _tree_of_life_activated: bool = false
var _tree_of_life_pending_destroy_count: int = 0

func _init() -> void:
	super._init()
	card_name = "Kur-Jara"
	card_types = ["Divine Accolyte", "Golem", "Aerial", "Ancient Creature"]
	level = 4
	mana_cost = 2
	sacrifice_cost = 0
	speed = 3
	resilience = 26
	strength = 21
	ability_text = "[b]Tree of Life[/b] ([b]Activate[/b]): Choose a Divine or Priest in your grave, and send this card to the grave. At the end of your second turn after activation, [b]Resurrect[/b] both cards to the reserve line and destroy a friendly creature for each level higher the chosen creature is than this card."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/Kur-jara(print).jpg"
	targets = true

func get_activation_label() -> String:
	return "Tree of Life"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null or _tree_of_life_activated:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if abilities_suppressed() or is_sleeping:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or card_owner == null or card_owner.graveyard_zone == null:
		return valid_targets
	for card in card_owner.graveyard_zone.cards:
		if card != null and card.card_type == Card.CardType.CREATURE:
			if card.has_type("Divine") or card.has_type("Priest"):
				valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	var valid := get_valid_targets(game_manager)
	if target == null or target not in valid:
		if valid.is_empty():
			game_manager.note_player_feedback("%s fizzles: no Divine or Priest in your grave." % card_name)
			return
		target = valid[0]
	_tree_of_life_activated = true
	_tree_of_life_target = target
	_tree_of_life_gm = game_manager
	_tree_of_life_activation_turn = game_manager.turn_number
	_tree_of_life_turns_remaining = 2
	if not game_manager.controller_turn_ended.is_connected(_on_controller_turn_ended):
		game_manager.controller_turn_ended.connect(_on_controller_turn_ended)
	game_manager.note_player_feedback(
		"%s activates Tree of Life, choosing %s, and enters the grave." % [card_name, target.card_name]
	)
	game_manager._send_to_graveyard_with_hook(self, false, false)

func _on_controller_turn_ended(turn_number: int, player: Player) -> void:
	if _tree_of_life_gm == null or card_owner == null:
		_cleanup_tree_of_life_signal()
		return
	if player != card_owner:
		return
	# Don't count the turn on which the ability was activated.
	if turn_number == _tree_of_life_activation_turn:
		return
	_tree_of_life_turns_remaining -= 1
	if _tree_of_life_turns_remaining > 0:
		return
	_cleanup_tree_of_life_signal()
	_resolve_tree_of_life()

func _cleanup_tree_of_life_signal() -> void:
	if _tree_of_life_gm != null \
			and _tree_of_life_gm.controller_turn_ended.is_connected(_on_controller_turn_ended):
		_tree_of_life_gm.controller_turn_ended.disconnect(_on_controller_turn_ended)

func _resolve_tree_of_life() -> void:
	var gm: GameManager = _tree_of_life_gm
	var chosen: Card = _tree_of_life_target
	_tree_of_life_gm = null

	if gm == null or card_owner == null:
		_clear_tree_of_life_state()
		return

	# Resurrect Kur-Jara from the grave.
	if current_zone == card_owner.graveyard_zone:
		var self_zone := _find_open_board_zone(gm, null)
		if self_zone != null:
			card_owner.move_card(self, self_zone)
			has_acted_this_turn = false
			is_stealth = false
			is_face_down = false
			gm.note_player_feedback("%s rises from the grave via Tree of Life." % card_name)
		else:
			gm.note_player_feedback("%s has no open zone to resurrect into." % card_name)

	# Resurrect the chosen Divine/Priest from the grave.
	if chosen != null and chosen.current_zone == card_owner.graveyard_zone:
		var chosen_zone := _find_open_board_zone(gm, current_zone)
		if chosen_zone != null:
			card_owner.move_card(chosen, chosen_zone)
			chosen.has_acted_this_turn = false
			chosen.is_stealth = false
			chosen.is_face_down = false
			gm.note_player_feedback("%s resurrects %s via Tree of Life." % [card_name, chosen.card_name])
		else:
			gm.note_player_feedback("Tree of Life: no open zone for %s." % chosen.card_name)

	# Destroy 1 friendly creature per level above Kur-Jara's level.
	if chosen != null:
		var level_diff := chosen.get_effective_level() - get_effective_level()
		if level_diff > 0:
			_tree_of_life_pending_destroy_count = level_diff
			var prompt_host := _get_prompt_host(gm)
			if prompt_host != null and prompt_host.has_method("_queue_kur_jara_tree_of_life_destroy_prompt"):
				prompt_host.call("_queue_kur_jara_tree_of_life_destroy_prompt", self)
				return
			var fallback_targets: Array[Card] = []
			for candidate in get_tree_of_life_destroy_candidates(gm):
				fallback_targets.append(candidate)
				if fallback_targets.size() >= level_diff:
					break
			resolve_tree_of_life_destroy_selection(gm, fallback_targets)
			return

	_clear_tree_of_life_state()

func _find_open_board_zone(_gm: GameManager, exclude: Zone) -> Zone:
	if card_owner == null:
		return null
	for zone in card_owner.reserve_zones:
		if zone != exclude and zone.cards.is_empty():
			return zone
	for zone in card_owner.frontline_zones:
		if zone != exclude and zone.cards.is_empty():
			return zone
	return null

func get_tree_of_life_pending_destroy_count() -> int:
	return maxi(0, _tree_of_life_pending_destroy_count)

func get_tree_of_life_target() -> Card:
	return _tree_of_life_target

func get_tree_of_life_target_name(viewer: Player = null) -> String:
	if _tree_of_life_target == null:
		return "Unknown"
	if viewer != null:
		return _tree_of_life_target.get_target_log_display_name(viewer)
	return _tree_of_life_target.card_name

func get_tree_of_life_destroy_candidates(gm: GameManager) -> Array[Card]:
	var friendly: Array[Card] = []
	if gm == null or card_owner == null:
		return friendly
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card: Card in zone.cards:
			if card != null and card.card_type == Card.CardType.CREATURE:
				friendly.append(card)
	return friendly

func resolve_tree_of_life_destroy_selection(gm: GameManager, selected_cards: Array[Card]) -> String:
	var required := get_tree_of_life_pending_destroy_count()
	var valid_candidates := get_tree_of_life_destroy_candidates(gm)
	var chosen_cards: Array[Card] = []
	for card in selected_cards:
		if card == null or card not in valid_candidates or card in chosen_cards:
			continue
		chosen_cards.append(card)
	var destroyed_names: Array[String] = []
	for card: Card in chosen_cards:
		if destroyed_names.size() >= required:
			break
		if gm != null and gm._send_to_graveyard_with_hook(card, false, true):
			destroyed_names.append(card.card_name)
	var remaining := maxi(0, required - destroyed_names.size())
	var feedback_parts: Array[String] = []
	if not destroyed_names.is_empty():
		feedback_parts.append("Tree of Life destroys %s." % ", ".join(destroyed_names))
	if remaining > 0:
		feedback_parts.append(
			"Tree of Life: not enough friendly creatures to fully pay the level cost (%d remaining)." % remaining
		)
	var feedback := " ".join(feedback_parts).strip_edges()
	if feedback == "":
		feedback = "Tree of Life had no creatures to destroy."
	if gm != null:
		gm.note_player_feedback(feedback)
	_clear_tree_of_life_state()
	return feedback

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	if _tree_of_life_activated:
		lines.append("Tree of Life target: %s" % get_tree_of_life_target_name())
		lines.append("Tree of Life own turns remaining: %d" % maxi(0, _tree_of_life_turns_remaining))
	if _tree_of_life_pending_destroy_count > 0:
		lines.append("Tree of Life destroy choices pending: %d" % _tree_of_life_pending_destroy_count)
	return lines

func get_hover_detail_lines(viewer: Player = null) -> Array[String]:
	var lines := super.get_hover_detail_lines(viewer)
	if _tree_of_life_activated:
		lines.append("[b]Tree of Life target:[/b] %s" % get_tree_of_life_target_name(viewer))
		lines.append("[b]Own turns remaining:[/b] %d" % maxi(0, _tree_of_life_turns_remaining))
	if _tree_of_life_pending_destroy_count > 0:
		lines.append("[b]Destroy choices pending:[/b] %d" % _tree_of_life_pending_destroy_count)
	return lines

func _clear_tree_of_life_state() -> void:
	_tree_of_life_activated = false
	_tree_of_life_target = null
	_tree_of_life_gm = null
	_tree_of_life_activation_turn = -1
	_tree_of_life_turns_remaining = -1
	_tree_of_life_pending_destroy_count = 0

func _apply_destruction_cost(gm: GameManager, count: int) -> void:
	var remaining := count
	for card: Card in get_tree_of_life_destroy_candidates(gm):
		if remaining <= 0:
			break
		gm.note_player_feedback(
			"Tree of Life costs %s — %s is destroyed." % [card_name, card.card_name]
		)
		gm._send_to_graveyard_with_hook(card, false, true)
		remaining -= 1
	if remaining > 0:
		gm.note_player_feedback(
			"Tree of Life: not enough friendly creatures to fully pay the level cost (%d remaining)." % remaining
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
			if node != null and node.is_inside_tree() \
					and (node == tree.current_scene or tree.current_scene.is_ancestor_of(node)):
				return node
	for host in hosts:
		var node: Node = host as Node
		if node != null and node.is_inside_tree() and node.get("game_manager") != null:
			return node
	if tree.current_scene != null:
		return tree.current_scene
	return null
