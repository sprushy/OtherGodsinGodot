extends PowerCard
class_name OraclesSight

const UNLOCK_COST := 2
const LOOK_COUNT := 5
const ART_PATH := "res://images/card_art/powers/OraclesSightEdit.png"

var _pending_unlock_resolution: bool = false

func _init() -> void:
	super._init()
	card_name = "Oracle's Sight"
	culture = "Neutral"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Foresight"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	targets = true
	ability_text = "[b]Unlock[/b] (2): [b]Foresight[/b] - Look at the next 5 cards in your deck; choose one to [b]Prime[/b] and [b]Shelve[/b] the rest."
	artist = "Eliot Chan"
	art_path = ART_PATH

func on_unlock(game_manager: GameManager) -> void:
	_pending_unlock_resolution = true
	if game_manager == null or card_owner == null:
		return
	var top_cards := get_foresight_cards()
	if top_cards.is_empty():
		is_used = true
		_pending_unlock_resolution = false
		game_manager.note_player_feedback("%s unlocked, but your deck has no cards to read." % card_name)
		return

	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_queue_oracles_sight_prompt"):
		prompt_host.call("_queue_oracles_sight_prompt", self)
		return

	activate(game_manager, top_cards[0])

func can_activate(game_manager: GameManager) -> bool:
	return game_manager != null \
		and not is_face_down \
		and not is_muted \
		and not is_activation_locked(game_manager) \
		and not is_used \
		and _pending_unlock_resolution \
		and card_owner == game_manager.current_player \
		and not get_foresight_cards().is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot resolve right now."
	if is_face_down:
		return card_name + " must be unlocked first."
	if is_muted:
		return card_name + " is muted."
	if is_activation_locked(game_manager):
		return card_name + " cannot resolve this turn."
	if is_used:
		return card_name + " has already resolved."
	if not _pending_unlock_resolution:
		return card_name + " has no foresight choice pending."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if get_foresight_cards().is_empty():
		return card_name + " found no cards to read."
	return card_name + " cannot resolve right now."

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	game_manager.note_player_feedback(resolve_foresight_choice(game_manager, target))

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var chosen_uid := str(command.get("chosen_uid", command.get("target_uid", "")))
	var chosen_card: Card = game_manager.get_card_by_uid(chosen_uid) if chosen_uid != "" else null
	activate(game_manager, chosen_card)

func get_foresight_cards() -> Array[Card]:
	var cards: Array[Card] = []
	if card_owner == null or card_owner.deck_zone == null:
		return cards
	var limit := mini(LOOK_COUNT, card_owner.deck_zone.cards.size())
	for i in range(limit):
		var card := card_owner.deck_zone.cards[i] as Card
		if card != null:
			cards.append(card)
	return cards

func resolve_foresight_choice(game_manager: GameManager, chosen_card: Card = null) -> String:
	var top_cards := get_foresight_cards()
	if game_manager == null or card_owner == null or top_cards.is_empty():
		_pending_unlock_resolution = false
		is_used = true
		return "%s found no cards to read." % card_name

	var primed_card := chosen_card if chosen_card != null and chosen_card in top_cards else top_cards[0]
	var shelved_cards: Array[Card] = []
	for card in top_cards:
		card_owner.deck_zone.cards.erase(card)
		if card == primed_card:
			continue
		shelved_cards.append(card)

	card_owner.deck_zone.cards.insert(0, primed_card)
	for card in shelved_cards:
		card_owner.deck_zone.cards.append(card)

	is_used = true
	_pending_unlock_resolution = false

	var primed_name := primed_card.get_target_log_display_name(game_manager.get_feedback_viewer())
	if shelved_cards.is_empty():
		return "%s used Foresight and primed %s." % [card_name, primed_name]

	var shelved_names: Array[String] = []
	for card in shelved_cards:
		shelved_names.append(card.get_target_log_display_name(game_manager.get_feedback_viewer()))
	return "%s used Foresight and primed %s while shelving %s." % [
		card_name,
		primed_name,
		", ".join(shelved_names)
	]

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
