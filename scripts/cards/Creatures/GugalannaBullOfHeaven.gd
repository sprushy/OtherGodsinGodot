extends CreatureCard
class_name GugalannaBullOfHeaven

const MIN_RES_TARGET := 30

func _init() -> void:
	super._init()
	card_name = "Gugalanna, Bull of Heaven"
	card_types = ["Divine Manifestation", "Animal", "Taurine", "Ancient Creature"]
	level = 4
	mana_cost = 3
	sacrifice_cost = 0
	speed = 3
	resilience = 25
	strength = 25
	ability_text = "Celestial Charge ([b]Impact[/b]): You may destroy a creature or structure with Res 30 or higher and slower Spd, but your opponent may activate hexes in response which can normally only activate on an attack. If you do, return this card from the field to your hand."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricarrdo Zoppello"
	art_path = "res://images/card_art/creatures/gugalanna_bull_of_heaven.png"

func on_impact(game_manager: GameManager) -> void:
	var prompt_host := _get_prompt_host(game_manager)
	if prompt_host != null and prompt_host.has_method("_begin_gugalanna_impact_targeting"):
		prompt_host.call("_begin_gugalanna_impact_targeting", self)
		return
	# Fallback: stay on field, no prompt available.

# Called by the prompt host after the player makes their choice.
# Pass null as target if the player declines to destroy anything.
func apply_celestial_charge(game_manager: GameManager, target: Card) -> void:
	if game_manager == null:
		return

	if target != null and _is_valid_target(target):
		# Allow attack hexes to trigger with Gugalanna as the "attacker".
		game_manager.check_and_trigger_hexes(self, target)

		# Destroy target if still on the board.
		if target.current_zone != null and target.current_zone.is_board_zone():
			game_manager.request_send_to_graveyard(target, Callable(), false, true)
			game_manager.note_player_feedback(
				"Celestial Charge: %s destroys %s." % [card_name, target.card_name]
			)
	else:
		game_manager.note_player_feedback("%s: Celestial Charge skipped." % card_name)
		return

	# Return to hand after destroying a target.
	_return_to_hand(game_manager)

func get_valid_impact_targets(game_manager: GameManager) -> Array[Card]:
	var valid: Array[Card] = []
	if game_manager == null:
		return valid
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _is_valid_target(card):
					valid.append(card)
	return valid

func _is_valid_target(target: Card) -> bool:
	return target != null \
		and (target.card_type == Card.CardType.CREATURE or target.card_type == Card.CardType.STRUCTURE) \
		and target.get_effective_resilience() >= MIN_RES_TARGET \
		and target.get_effective_speed() < get_effective_speed() \
		and target.current_zone != null \
		and target.current_zone.is_board_zone()

func _return_to_hand(game_manager: GameManager) -> void:
	if current_zone == null or not current_zone.is_board_zone():
		return
	var owner := card_owner
	if owner == null:
		return
	if game_manager != null:
		game_manager.note_player_feedback("%s returns to hand." % card_name)
	owner.move_card(self, owner.hand_zone)

func _get_prompt_host(game_manager: GameManager = null) -> Node:
	if game_manager != null:
		var host := game_manager.get_interaction_host()
		var node := host as Node
		if node != null and is_instance_valid(node):
			return node
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
