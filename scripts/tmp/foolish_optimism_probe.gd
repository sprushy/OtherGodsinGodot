extends SceneTree

const FoolishOptimismScript := preload("res://scripts/cards/Spells/FoolishOptimism.gd")
const BrownBearScript := preload("res://scripts/cards/Creatures/BrownBear.gd")
const CombatMechScript := preload("res://scripts/cards/Creatures/CombatMech.gd")
const EnkiduScript := preload("res://scripts/cards/Creatures/Enkidu.gd")
const StoneInfantScript := preload("res://scripts/cards/Creatures/StoneInfant.gd")

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

	print("foolish_optimism_probe: PASS")
	quit()
