extends CreatureCard
class_name NergalLion

const ART_PATH := "res://images/card_art/creatures/NergalLionEdit.png"

func _init() -> void:
	super._init()
	card_name = "Nergal Lion"
	card_types = ["Divine Acolyte", "Demon", "Pyro", "Aerial", "Ancient Creature", "Targeting"]
	level = 5
	mana_cost = 7
	speed = 2
	strength = 33
	resilience = 27
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	targets = true
	ability_text = "[b]Immolate[/b] ([b]Impact[/b]): Place a [b]Destruction[/b] card that can destroy a physical card from your graveyard face-down on your field. When it is activated, you do not have to pay its cost."

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_immolate_targets(game_manager)
	if valid_targets.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("%s found no physical destruction card to immolate." % card_name)
		return

	var valid_zones := get_valid_immolate_zones()
	if valid_zones.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("%s has no open field zone for Immolate." % card_name)
		return

	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_queue_nergal_lion_impact_prompt"):
		prompt_host.call("_queue_nergal_lion_impact_prompt", self)
		return

	var feedback := resolve_immolate_impact(game_manager, valid_targets[0], valid_zones[0])
	if game_manager != null:
		game_manager.note_player_feedback(feedback)

func get_valid_immolate_targets(_game_manager: GameManager = null) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.graveyard_zone == null:
		return valid_targets

	for card in controller.graveyard_zone.cards:
		if _is_valid_immolate_target(card, controller):
			valid_targets.append(card)
	return valid_targets

func get_valid_immolate_zones() -> Array[Zone]:
	var valid_zones: Array[Zone] = []
	var controller := get_controller()
	if controller == null:
		return valid_zones

	for zone in controller.frontline_zones + controller.reserve_zones:
		if zone == null:
			continue
		if not zone.cards.is_empty():
			continue
		if not zone.get_equipment().is_empty():
			continue
		valid_zones.append(zone)
	return valid_zones

func resolve_immolate_impact(game_manager: GameManager, target: Card, target_zone: Zone) -> String:
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller for Immolate."

	var valid_targets := get_valid_immolate_targets(game_manager)
	if target == null or target not in valid_targets:
		return card_name + " found no valid destruction card to immolate."

	var valid_zones := get_valid_immolate_zones()
	if target_zone == null or target_zone not in valid_zones:
		return card_name + " has no valid field zone for Immolate."

	controller.move_card(target, target_zone)
	if target.current_zone != target_zone:
		return "%s could not place %s face-down on the field." % [card_name, target.card_name]

	target.card_owner = controller
	target.is_prepared = true
	target.is_face_down = true
	target.is_stealth = false
	target.set_meta("prepared_activation_cost_waived", true)
	target.set_meta("prepared_activation_cost_waiver_source", card_name)
	target.set_meta("prepared_activation_cost_waiver_source_card", self)

	if game_manager != null:
		if target.card_type == Card.CardType.HEX:
			game_manager.prepared_hexes[target] = game_manager.turn_number
		elif target is CharmCard:
			game_manager.prepared_charms[target] = game_manager.turn_number

	return "%s immolated %s from %s's graveyard into %s." % [
		card_name,
		target.card_name,
		controller.player_name,
		_target_zone_label(target_zone, controller)
	]

func _is_valid_immolate_target(card: Card, controller: Player) -> bool:
	if card == null or controller == null:
		return false
	if card.current_zone != controller.graveyard_zone:
		return false
	if card.card_type not in [Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM]:
		return false
	if not _is_destruction_card(card):
		return false
	return _can_destroy_physical_card(card)

func _is_destruction_card(card: Card) -> bool:
	if card == null:
		return false
	for type_name in card.card_types:
		if str(type_name).to_lower().contains("destruction"):
			return true
	return false

func _can_destroy_physical_card(card: Card) -> bool:
	if card == null:
		return false
	for type_name in ["Physical", "Creature", "Structures", "Structure", "Equipment"]:
		if card.has_type(type_name):
			return true

	var text := str(card.ability_text).to_lower()
	if not text.contains("destroy"):
		return false
	if text.contains("magical card") and not _text_mentions_physical_target(text):
		return false
	return _text_mentions_physical_target(text)

func _text_mentions_physical_target(text: String) -> bool:
	for token in [
		" physical ",
		" attack target",
		" combat target",
		" creature",
		" creatures",
		" structure",
		" structures",
		" equipment",
		" golem",
		" golems",
		" machine",
		" machines"
	]:
		if text.contains(token):
			return true
	return false

func _target_zone_label(zone: Zone, controller: Player) -> String:
	if zone == null:
		return "the field"
	if controller == null:
		return "the field"
	var lane_number := zone.zone_index + 1
	if zone in controller.frontline_zones:
		return "%s's Front Line %d" % [controller.player_name, lane_number]
	if zone in controller.reserve_zones:
		return "%s's Reserve %d" % [controller.player_name, lane_number]
	return "the field"

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
