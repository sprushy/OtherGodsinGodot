extends CreatureCard
class_name GalaTura

const PASSIVE_SOURCE := "Gala-Tura Water of Life"
const GRAVEWARD_STATUS := "gala_tura_graveward"
const MAX_RETURN_COUNT := 3

var _destroy_trigger_queued: bool = false

func _init() -> void:
	super._init()
	card_name = "Gala-Tura"
	card_types = ["Divine Acolyte", "Golem", "Aerial", "Ancient Creature"]
	level = 2
	mana_cost = 2
	sacrifice_cost = 0
	speed = 3
	resilience = 27
	strength = 23
	flavor_text = ""
	ability_text = "Water of Life ([b]Passive[/b]): Creatures in your graveyard are immune to your opponent's effects. [b]Destroyed[/b]: You may return up to 3 of your other creatures from your graveyard to the bottom of your deck."
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/gala_tura_print.jpg"

func on_summon(game_manager: GameManager) -> void:
	_apply_graveward(game_manager)

func on_reveal(game_manager: GameManager) -> void:
	_apply_graveward(game_manager)

func on_turn_start(game_manager: GameManager) -> void:
	_apply_graveward(game_manager)

func on_removed(game_manager: GameManager) -> void:
	_remove_graveward(game_manager)

func on_muted(game_manager: GameManager) -> void:
	_remove_graveward(game_manager)

func on_unmuted(game_manager: GameManager) -> void:
	_apply_graveward(game_manager)

func on_any_card_moved(game_manager: GameManager, _moved_card: Card, _from_zone: Zone, _to_zone: Zone) -> void:
	_apply_graveward(game_manager)

func get_self_graveyard_replacement_zone(
	game_manager: GameManager,
	combat_death: bool,
	destruction: bool,
	_send_to_abyss: bool
) -> Zone:
	if not destruction:
		return null
	if current_zone == null or not current_zone.is_board_zone():
		return null
	if _destroy_trigger_queued:
		return null
	_destroy_trigger_queued = true
	call_deferred("_begin_destroy_trigger", game_manager, combat_death)
	return null

func get_destroyed_trigger_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null or card_owner.graveyard_zone == null:
		return valid_targets
	for card in card_owner.graveyard_zone.cards:
		if _is_valid_destroyed_trigger_target(card):
			valid_targets.append(card)
	return valid_targets

func resolve_destroyed_trigger(game_manager: GameManager, chosen_targets: Array[Card]) -> String:
	if game_manager == null:
		return card_name + " cannot return creatures right now."
	var valid_targets := get_destroyed_trigger_targets(game_manager)
	var sanitized_targets: Array[Card] = []
	for card in chosen_targets:
		if card == null or card not in valid_targets or card in sanitized_targets:
			continue
		sanitized_targets.append(card)
		if sanitized_targets.size() >= MAX_RETURN_COUNT:
			break

	if sanitized_targets.is_empty():
		return card_name + " returns no creatures to the deck."

	for card in sanitized_targets:
		game_manager.send_to_deck_bottom_with_hook(card)

	var returned_names: Array[String] = []
	for card in sanitized_targets:
		returned_names.append(card.card_name)

	return "%s returned %d creature(s) to the bottom of %s's deck: %s." % [
		card_name,
		sanitized_targets.size(),
		card_owner.player_name,
		", ".join(returned_names)
	]

func _begin_destroy_trigger(game_manager: GameManager, _combat_death: bool = false) -> void:
	_destroy_trigger_queued = false
	if game_manager == null:
		return
	var valid_targets := get_destroyed_trigger_targets(game_manager)
	if valid_targets.is_empty():
		game_manager.note_player_feedback("%s found no creatures to return." % card_name)
		return

	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_queue_gala_tura_destroyed_prompt"):
		prompt_host.call("_queue_gala_tura_destroyed_prompt", self)
		return

	var fallback_targets: Array[Card] = []
	for card in valid_targets:
		fallback_targets.append(card)
		if fallback_targets.size() >= MAX_RETURN_COUNT:
			break
	game_manager.note_player_feedback(resolve_destroyed_trigger(game_manager, fallback_targets))

func _apply_graveward(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	_remove_graveward(game_manager)
	if abilities_suppressed():
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	if card_owner == null or card_owner.graveyard_zone == null:
		return
	for card in card_owner.graveyard_zone.cards:
		if not _is_valid_destroyed_trigger_target(card):
			continue
		card.add_status_effect(
			GRAVEWARD_STATUS,
			PASSIVE_SOURCE,
			self,
			card_owner
		)

func _remove_graveward(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	for player in game_manager.players:
		if player == null:
			continue
		for zone in _get_all_zones_for_player(player):
			for card in zone.cards:
				card.remove_status_effects_from_source_card(self, GRAVEWARD_STATUS)

func _get_all_zones_for_player(player: Player) -> Array[Zone]:
	var zones: Array[Zone] = []
	if player == null:
		return zones
	zones.append(player.hand_zone)
	zones.append(player.deck_zone)
	zones.append(player.graveyard_zone)
	zones.append(player.abyss_zone)
	zones.append(player.god_zone)
	zones.append_array(player.power_zones)
	zones.append_array(player.frontline_zones)
	zones.append_array(player.reserve_zones)
	return zones

func _is_valid_destroyed_trigger_target(card: Card) -> bool:
	return card != null \
		and card != self \
		and card.current_zone != null \
		and card.current_zone.zone_type == Zone.ZoneType.GRAVEYARD \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god

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
