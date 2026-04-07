extends ActiveGodCard
class_name MummuActive

const LINKED_GOD_NAME := "Mummu, The One Who Has Awoken"
const ART_PATH := "res://images/card_art/gods/Mummu.png"
const ENTROPY_PRIME := "prime"
const ENTROPY_SHELVE := "shelve"
const RESTORE_DEFERRED_META := "mummu_active_restore_pending"

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Mummu, Active God"
	card_types = ["Active God", "Divine Manifestation", "God"]
	level = 11
	mana_cost = 11
	speed = 1
	resilience = 30
	strength = 35
	culture = "Ancient"
	flavor_text = "Awakened entropy devours the field, then sinks back beneath creation."
	ability_text = "[b]Entropy[/b] ([b]Passive[/b]): Choose to [b]Prime[/b] or [b]Shelve[/b] any card destroyed by Mummu. When this card leaves the field, reactivate your god card."
	art_path = ART_PATH
	name_at_bottom = true
	artist = "Ricarrdo Zoppello"

func on_attack_target_destroyed(game_manager: GameManager, victim: Card) -> void:
	if game_manager == null or victim == null:
		return
	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_queue_mummu_entropy_prompt"):
		prompt_host.call("_queue_mummu_entropy_prompt", self, victim)
		return
	game_manager.note_player_feedback(resolve_entropy_choice(game_manager, victim, ENTROPY_PRIME))

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var chosen_uid := str(command.get("chosen_uid", command.get("target_uid", "")))
	var target_card: Card = game_manager.get_card_by_uid(chosen_uid) if chosen_uid != "" else null
	var placement := str(command.get("placement", command.get("keyword", ENTROPY_PRIME))).to_lower()
	game_manager.note_player_feedback(resolve_entropy_choice(game_manager, target_card, placement))

func resolve_entropy_choice(game_manager: GameManager, destroyed_card: Card, placement: String = ENTROPY_PRIME) -> String:
	if game_manager == null:
		return card_name + " cannot resolve Entropy right now."
	if destroyed_card == null or destroyed_card.card_owner == null or destroyed_card.card_owner.deck_zone == null:
		return "%s found no card to return." % card_name
	if destroyed_card.current_zone == null:
		return "%s could not return %s." % [card_name, destroyed_card.card_name]
	if destroyed_card.current_zone.zone_type not in [Zone.ZoneType.GRAVEYARD, Zone.ZoneType.ABYSS, Zone.ZoneType.DECK]:
		return "%s could not return %s." % [card_name, destroyed_card.card_name]

	var resolved_placement := ENTROPY_SHELVE if placement == ENTROPY_SHELVE else ENTROPY_PRIME
	var owner := destroyed_card.card_owner
	owner.move_card(destroyed_card, owner.deck_zone)
	owner.deck_zone.cards.erase(destroyed_card)
	if resolved_placement == ENTROPY_SHELVE:
		owner.deck_zone.cards.append(destroyed_card)
		return "%s shelved %s." % [card_name, destroyed_card.get_target_log_display_name(game_manager.get_feedback_viewer())]

	owner.deck_zone.cards.insert(0, destroyed_card)
	return "%s primed %s." % [card_name, destroyed_card.get_target_log_display_name(game_manager.get_feedback_viewer())]

func on_removed(game_manager: GameManager) -> void:
	if current_zone == null or not current_zone.is_board_zone():
		return
	if bool(get_meta(RESTORE_DEFERRED_META, false)):
		return
	set_meta(RESTORE_DEFERRED_META, true)
	call_deferred("_restore_normal_god_after_leaving_field", game_manager)

func _restore_normal_god_after_leaving_field(game_manager: GameManager) -> void:
	if has_meta(RESTORE_DEFERRED_META):
		remove_meta(RESTORE_DEFERRED_META)
	if card_owner == null:
		return
	if current_zone != null and current_zone.is_board_zone():
		return

	if game_manager != null:
		game_manager.remove_card_from_game_with_hook(self)

	var restored_god := restore_stored_normal_god()
	if restored_god != null and game_manager != null:
		game_manager.note_player_feedback("%s was reactivated." % [
			restored_god.card_name
		])

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
