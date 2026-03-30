extends SceneTree

const GiantsDisdainScript := preload("res://scripts/cards/Powers/GiantsDisdain.gd")
const GiantMasterArchitectScript := preload("res://scripts/cards/Creatures/GiantMasterArchitect.gd")
const AurbodaScript := preload("res://scripts/cards/Creatures/Aurboda.gd")
const BerserkerScript := preload("res://scripts/cards/Creatures/Berserker.gd")

func _assert_state(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _initialize() -> void:
	call_deferred("_run_probe")

func _make_game_manager() -> Dictionary:
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
	game_manager.turn_number = 1
	game_manager.feedback_viewer = player1

	var power := GiantsDisdainScript.new()
	power.card_owner = player1
	power.is_face_down = false
	player1.power_zones[0].add_card(power)

	return {
		"game_manager": game_manager,
		"player1": player1,
		"player2": player2,
	}

func _run_probe() -> void:
	var continuation_state := _make_game_manager()
	var continuation_manager: GameManager = continuation_state.game_manager
	var continuation_p1: Player = continuation_state.player1
	var continuation_p2: Player = continuation_state.player2

	var architect := GiantMasterArchitectScript.new()
	architect.card_owner = continuation_p1
	architect.creature_mode = Card.CreatureMode.AGGRESSIVE
	continuation_p1.frontline_zones[0].add_card(architect)

	var berserker := BerserkerScript.new()
	berserker.card_owner = continuation_p2
	berserker.creature_mode = Card.CreatureMode.AGGRESSIVE
	continuation_p2.frontline_zones[0].add_card(berserker)

	continuation_manager.resolve_combat_with_continuation(architect, berserker)
	await process_frame

	_assert_state(
		continuation_p2.followers == 81,
		"Deferred combat should deal 19 follower damage with Giant's Disdain; got %d." % continuation_p2.followers
	)

	var united_state := _make_game_manager()
	var united_manager: GameManager = united_state.game_manager
	var united_p1: Player = united_state.player1
	var united_p2: Player = united_state.player2

	var united_architect := GiantMasterArchitectScript.new()
	united_architect.card_owner = united_p1
	united_architect.creature_mode = Card.CreatureMode.AGGRESSIVE
	united_p1.frontline_zones[0].add_card(united_architect)

	var aurboda := AurbodaScript.new()
	aurboda.card_owner = united_p1
	aurboda.creature_mode = Card.CreatureMode.AGGRESSIVE
	united_p1.frontline_zones[1].add_card(aurboda)

	var united_berserker := BerserkerScript.new()
	united_berserker.card_owner = united_p2
	united_berserker.creature_mode = Card.CreatureMode.AGGRESSIVE
	united_p2.frontline_zones[0].add_card(united_berserker)

	united_manager.resolve_united_front_combat(united_architect, aurboda, united_berserker)
	await process_frame

	_assert_state(
		united_p2.followers == 60,
		"United Front combat should deal 40 follower damage with Giant's Disdain; got %d." % united_p2.followers
	)

	print("giants_disdain_combat_probe: PASS")
	quit()
