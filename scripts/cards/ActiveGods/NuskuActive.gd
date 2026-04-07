extends ActiveGodCard
class_name NuskuActive

const LINKED_GOD_NAME := "Nusku, Firebearer"
const MILL_COUNT := 7
const ART_PATH := "res://scripts/cards/Charms/NuskuEdit2.png"

var _declined_core_flame: bool = false

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Nusku, Active God"
	card_types = ["Active God", "Divine Manifestation", "God"]
	level = 12
	mana_cost = 12
	speed = 2
	resilience = 30
	strength = 33
	culture = "Ancient"
	flavor_text = "Nusku's fire offers revelation now or judgment later."
	ability_text = "[b]Core Flame[/b] ([b]Impact[/b]): You may [b]Mill[/b] 7 of your cards; choose a magical card from them and add it to your hand.\n[b]Celestial Light[/b] ([b]Fatality[/b]): If you declined Core Flame, convert your opponent's followers equal to the number of cards in your grave."
	art_path = ART_PATH
	name_at_bottom = true
	artist = "Ricardo Zoppello"

func on_summon(_game_manager: GameManager) -> void:
	_declined_core_flame = false

func on_impact(game_manager: GameManager) -> void:
	if game_manager == null or card_owner == null or card_owner.deck_zone == null:
		return
	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_queue_nusku_active_core_flame_prompt"):
		prompt_host.call("_queue_nusku_active_core_flame_prompt", self)
		return
	game_manager.note_player_feedback(resolve_core_flame(game_manager))

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var decline := bool(command.get("decline", false))
	var chosen_uid := str(command.get("chosen_uid", command.get("target_uid", "")))
	var chosen_card: Card = game_manager.get_card_by_uid(chosen_uid) if chosen_uid != "" else null
	game_manager.note_player_feedback(resolve_core_flame(game_manager, chosen_card, decline))

func resolve_core_flame(game_manager: GameManager, chosen_card: Card = null, decline: bool = false) -> String:
	if game_manager == null or card_owner == null or card_owner.deck_zone == null or card_owner.graveyard_zone == null:
		return card_name + " cannot resolve Core Flame right now."
	if decline:
		_declined_core_flame = true
		return "%s declines Core Flame." % card_name
	if card_owner.deck_zone.cards.is_empty():
		_declined_core_flame = false
		return "%s cannot mill because the deck is empty." % card_name

	var milled_cards := _mill_cards()
	var eligible_cards := _get_eligible_milled_magical_cards(milled_cards)
	var resolved_choice := chosen_card if chosen_card != null and chosen_card in eligible_cards else null
	if resolved_choice == null and not eligible_cards.is_empty():
		resolved_choice = eligible_cards[0]

	_declined_core_flame = false

	var feedback := "%s milled %d card(s)." % [card_name, milled_cards.size()]
	if resolved_choice != null:
		card_owner.move_card(resolved_choice, card_owner.hand_zone)
		feedback += " %s was added to %s's hand." % [
			resolved_choice.get_target_log_display_name(game_manager.get_feedback_viewer()),
			card_owner.player_name
		]
	else:
		feedback += " No magical card was milled."
	return feedback

func on_death(game_manager: GameManager) -> void:
	if game_manager == null or not _declined_core_flame:
		return
	var controller := get_controller()
	if controller == null:
		controller = card_owner
	var opponent := game_manager.get_opponent(controller)
	if opponent == null:
		return
	var grave_count := 0
	if controller != null and controller.graveyard_zone != null:
		grave_count = controller.graveyard_zone.cards.size()
	_declined_core_flame = false
	if grave_count <= 0:
		return
	var converted := game_manager.convert_followers(opponent, controller, grave_count)
	if converted <= 0:
		return
	game_manager.note_player_feedback("%s's Celestial Light converts %d followers." % [card_name, converted])

func _mill_cards() -> Array[Card]:
	var milled: Array[Card] = []
	for _i in range(MILL_COUNT):
		if card_owner.deck_zone.cards.is_empty():
			break
		var milled_card := card_owner.deck_zone.cards[0] as Card
		card_owner.move_card(milled_card, card_owner.graveyard_zone)
		milled.append(milled_card)
	return milled

func _get_eligible_milled_magical_cards(milled_cards: Array[Card]) -> Array[Card]:
	var eligible: Array[Card] = []
	for card in milled_cards:
		if card != null and card.current_zone == card_owner.graveyard_zone and card.is_magical_card():
			eligible.append(card)
	return eligible

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
