extends SceneTree

const FoolishOptimismScript := preload("res://scripts/cards/Spells/FoolishOptimism.gd")
const BrownBearScript := preload("res://scripts/cards/Creatures/BrownBear.gd")
const CombatMechScript := preload("res://scripts/cards/Creatures/CombatMech.gd")
const EnkiduScript := preload("res://scripts/cards/Creatures/Enkidu.gd")
const StoneInfantScript := preload("res://scripts/cards/Creatures/StoneInfant.gd")
const MAIN_SCENE := preload("res://scenes/mainfork.tscn")

func _assert_state(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var game_manager := GameManager.new()
	var player1 := Player.new()
	player1.player_name = "Player 1"
	var player2 := Player.new()
	player2.player_name = "Player 2"

	game_manager.players = [player1, player2]
	game_manager.setup_game()
	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.turn_player = player1

	player1.followers = 100
	player2.followers = 100
	player1.mana = 10

	var spell := FoolishOptimismScript.new()
	spell.card_owner = player1
	player1.hand_zone.add_card(spell)

	var prepare_zone := player1.reserve_zones[1]
	_assert_state(not game_manager.has_resolved_turn_upkeep(), "The turn should begin before upkeep resolves.")
	_assert_state(game_manager.can_prepare_card(player1, spell, prepare_zone), "Foolish Optimism should be preparable before upkeep resolves.")
	_assert_state(not game_manager.can_play_card(player1, spell, prepare_zone), "Foolish Optimism should not count as directly playable before upkeep resolves.")
	game_manager.prepare_card(player1, spell, prepare_zone)
	_assert_state(spell.current_zone == prepare_zone, "Preparing Foolish Optimism should move it onto the board.")
	_assert_state(spell.is_prepared and spell.is_face_down, "Prepared Foolish Optimism should stay face-down on the board.")
	_assert_state(game_manager.prepared_hexes.has(spell), "Prepared Foolish Optimism should be tracked as a prepared hex.")

	player1.hand_zone.remove_card(spell)
	prepare_zone.remove_card(spell)
	game_manager.prepared_hexes.erase(spell)
	spell.is_prepared = false
	spell.is_face_down = false

	var strongest_friendly := BrownBearScript.new()
	strongest_friendly.card_owner = player1
	player1.frontline_zones[0].add_card(strongest_friendly)

	var weaker_friendly := CombatMechScript.new()
	weaker_friendly.card_owner = player1
	player1.reserve_zones[0].add_card(weaker_friendly)

	var compelled_attacker := StoneInfantScript.new()
	compelled_attacker.card_owner = player2
	compelled_attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	player2.frontline_zones[0].add_card(compelled_attacker)

	var stronger_enemy := EnkiduScript.new()
	stronger_enemy.card_owner = player2
	stronger_enemy.creature_mode = Card.CreatureMode.AGGRESSIVE
	player2.frontline_zones[1].add_card(stronger_enemy)

	_assert_state(spell.get_forced_attacker(game_manager) == compelled_attacker, "Foolish Optimism should choose the opponent's lowest-level creature.")
	_assert_state(spell.get_forced_defender(game_manager) == strongest_friendly, "Foolish Optimism should choose your highest-level creature.")

	prepare_zone.add_card(spell)
	spell.is_prepared = true
	spell.is_face_down = true
	game_manager.prepared_hexes[spell] = game_manager.turn_number - 1

	var response_action := CardAction.new()
	response_action.type = CardAction.Type.ATTACK
	response_action.source_player = player2
	response_action.attacker = compelled_attacker
	response_action.target = strongest_friendly
	game_manager.push_to_stack(response_action)

	_assert_state(not game_manager.can_card_respond_to_priority(spell, player1), "Prepared Foolish Optimism should not be a legal priority response before upkeep resolves.")

	game_manager._resolve_turn_upkeep()
	_assert_state(game_manager.has_resolved_turn_upkeep(), "The probe should mark upkeep as resolved for the current turn.")
	_assert_state(game_manager.can_card_respond_to_priority(spell, player1), "Prepared Foolish Optimism should become a legal priority response after upkeep resolves.")

	game_manager.action_stack.clear()
	prepare_zone.remove_card(spell)
	game_manager.prepared_hexes.erase(spell)
	spell.is_prepared = false
	spell.is_face_down = false

	spell.resolve(game_manager)

	_assert_state(compelled_attacker.creature_major_action_used, "The compelled attacker should spend its major action.")
	_assert_state(compelled_attacker.has_attacked_this_turn, "The compelled attacker should count as having attacked.")
	_assert_state(player2.followers == 94, "The forced attack should resolve against the highest-level friendly creature.")
	_assert_state(player1.followers == 106, "Follower conversion from the forced attack should be applied.")

	var moved_callback := Callable(game_manager, "_on_player_card_moved")
	var defeated_callback := Callable(game_manager, "_on_player_defeated")
	for player in game_manager.players:
		if player.card_moved.is_connected(moved_callback):
			player.card_moved.disconnect(moved_callback)
		if player.defeated.is_connected(defeated_callback):
			player.defeated.disconnect(defeated_callback)
	game_manager.players.clear()
	game_manager.current_player = null
	game_manager.other_player = null
	game_manager.turn_player = null
	player1 = null
	player2 = null
	game_manager = null

	var scene: Node = MAIN_SCENE.instantiate()
	root.add_child(scene)

	var card_test: CardTestGame = scene.get_node("Control/GameContainer/CardTest")
	await card_test.start_game()
	await process_frame
	await process_frame

	var ui_player: Player = card_test.player1
	_assert_state(ui_player != null, "Expected CardTestGame player 1.")

	var ui_spell: FoolishOptimism = null
	for card in ui_player.hand_zone.cards:
		if card is FoolishOptimism:
			ui_spell = card
			break
	_assert_state(ui_spell != null, "Expected Foolish Optimism in the CardTestGame hand.")

	var expected_zone := card_test._find_empty_player_zone()
	_assert_state(expected_zone != null, "Expected an empty friendly zone for drag-to-prepare.")

	var occupied_zone_ui: BoardZoneUI = null
	for zone_ui in card_test._board_zone_uis:
		if zone_ui != null and zone_ui.zone == ui_player.frontline_zones[0]:
			occupied_zone_ui = zone_ui
			break
	_assert_state(occupied_zone_ui != null, "Expected an occupied friendly zone UI to drag onto.")

	var drop_pos := occupied_zone_ui.get_global_rect().get_center()
	card_test._on_card_drag_released(ui_spell, drop_pos, false, false)
	await process_frame
	await process_frame

	_assert_state(ui_spell.current_zone == expected_zone, "Dragging Foolish Optimism onto your side of the board should prepare it in the next empty friendly zone.")
	_assert_state(ui_spell.is_prepared and ui_spell.is_face_down, "Dragged Foolish Optimism should enter play prepared and face-down.")
	_assert_state(card_test.game_manager.prepared_hexes.has(ui_spell), "Dragged Foolish Optimism should be tracked as a prepared hex.")
	await process_frame
	await process_frame

	print("foolish_optimism_probe: PASS")
	quit()
