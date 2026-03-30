extends SceneTree

const GarmScript := preload("res://scripts/cards/Creatures/Garm.gd")

const OUTPUT_PATH := "user://direct_followers_attack_probe.txt"

func _initialize() -> void:
	call_deferred("_run_probe")

func _write_line(file: FileAccess, text: String) -> void:
	if file != null:
		file.store_line(text)

func _run_probe() -> void:
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("direct_followers_attack_probe: could not open output file")
		quit(1)
		return

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

	var garm := GarmScript.new()
	garm.card_owner = player1
	garm.creature_mode = Card.CreatureMode.AGGRESSIVE
	player1.frontline_zones[0].add_card(garm)

	player1.followers = 100
	player2.followers = 100

	_write_line(file, "before_resolve_followers_attack_p2=%d" % player2.followers)
	var helper_damage := game_manager.resolve_followers_attack([garm], player2)
	_write_line(file, "helper_damage=%d" % helper_damage)
	_write_line(file, "after_resolve_followers_attack_p2=%d" % player2.followers)

	player2.followers = 100
	var match_manager := MatchManager.new(game_manager)
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.source_player = player1
	action.attacker = garm
	action.target = player2
	match_manager.resolve_action(action)

	_write_line(file, "after_match_manager_resolve_p2=%d" % player2.followers)
	_write_line(file, "match_manager_text=%s" % match_manager.last_resolution_text)

	file.flush()
	file.close()
	print("direct_followers_attack_probe: PASS")
	quit()
