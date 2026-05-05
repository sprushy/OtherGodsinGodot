extends SceneTree

const GameManagerScript = preload("res://scripts/Other/game_manager.gd")
const MatchManagerScript = preload("res://scripts/Other/MatchManager.gd")
const GameStateScript = preload("res://scripts/Other/GameState.gd")
const PlayerScript = preload("res://scripts/Other/player.gd")
const CardActionScript = preload("res://scripts/Other/CardAction.gd")
const ThorActiveScript = preload("res://scripts/cards/ActiveGods/ThorActive.gd")
const ThorScript = preload("res://scripts/cards/Gods/Thor.gd")
const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")
const RunicShortswordScript = preload("res://scripts/cards/Equipment/RunicShortsword.gd")
const BrownBearScript = preload("res://scripts/cards/Creatures/BrownBear.gd")
const LOG_PATH := "res://thor_followers_attack_probe.log"

func _init() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	_reset_log()
	_log("probe start")
	var game_manager = GameManagerScript.new()
	_log("game manager created")
	var match_manager = MatchManagerScript.new(game_manager)
	_log("match manager created")

	var player1 = PlayerScript.new()
	player1.player_name = "Attacker"
	game_manager.players.append(player1)
	_log("player1 ready")

	var player2 = PlayerScript.new()
	player2.player_name = "Defender"
	game_manager.players.append(player2)
	_log("player2 ready")

	var thor_god = ThorScript.new()
	thor_god.card_owner = player1
	player1.god_zone.add_card(thor_god)
	_log("thor god placed")

	var defender_god = TiamatScript.new()
	defender_god.card_owner = player2
	player2.god_zone.add_card(defender_god)
	_log("defender god placed")

	game_manager.setup_game()
	_log("setup_game complete")
	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.turn_player = player1
	player1.is_turn_player = true
	player2.is_turn_player = false

	var thor_active = ThorActiveScript.new()
	thor_active.card_owner = player1
	player1.frontline_zones[0].add_card(thor_active)
	thor_active.set_stored_normal_god(thor_god)
	_log("thor active placed")
	thor_active.apply_passive_to_board()
	_log("thor passive applied")

	var sword = RunicShortswordScript.new()
	sword.card_owner = player1
	player1.frontline_zones[0].add_card(sword)
	_log("sword placed")
	sword.equip_to(thor_active)
	_log("sword equipped")

	var filler = BrownBearScript.new()
	filler.card_owner = player1
	player1.frontline_zones[1].add_card(filler)
	_log("filler placed")

	var action = CardActionScript.new()
	action.type = CardActionScript.Type.ATTACK
	action.source_player = player1
	action.attacker = thor_active
	action.target = player2
	action.halve_follower_damage = thor_active.halves_follower_damage_inflicted()
	_log("action prepared")

	print("--- Before attack ---")
	print("Thor STR: %d" % thor_active.get_effective_strength())
	print("Thor equipment count: %d" % thor_active.equipment.size())
	print("Defender followers: %d" % player2.followers)

	match_manager._finish_followers_attack(action, player2)
	_log("followers attack finished")

	print("--- After attack ---")
	print("Resolution text: %s" % match_manager.last_resolution_text)
	print("Defender followers: %d" % player2.followers)
	print("Serialize P1 view...")
	var p1_state = GameStateScript.serialize(game_manager, 0)
	_log("serialize p1 complete")
	print("P1 state ok: %s" % str(p1_state.get("is_game_over", false)))
	print("Serialize P2 view...")
	var p2_state = GameStateScript.serialize(game_manager, 1)
	_log("serialize p2 complete")
	print("P2 state ok: %s" % str(p2_state.get("is_game_over", false)))
	print("Serialize spectator view...")
	var spectator_state = GameStateScript.serialize(game_manager, GameStateScript.SPECTATOR_VIEWER_INDEX)
	_log("serialize spectator complete")
	print("Spectator state ok: %s" % str(spectator_state.get("is_game_over", false)))

	_log("probe success")
	quit(0)

func _reset_log() -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(LOG_PATH), FileAccess.WRITE)
	if file == null:
		return
	file.store_line("reset")
	file.close()

func _log(message: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(LOG_PATH)
	var file := FileAccess.open(absolute_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(message)
	file.flush()
	file.close()
