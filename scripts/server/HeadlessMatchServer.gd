extends Node
class_name HeadlessMatchServer

const PromptRouterScript = preload("res://scripts/server/PromptRouter.gd")
const HeadlessMatchHostScript = preload("res://scripts/server/HeadlessMatchHost.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const DefaultMatchSetupScript = preload("res://scripts/server/DefaultMatchSetup.gd")
const MatchHistoryStoreScript = preload("res://scripts/server/MatchHistoryStore.gd")

signal startup_succeeded(match_id: String, port: int)
signal startup_failed(message: String)

var game_manager: GameManager = null
var match_manager: MatchManager = null
var prompt_router = null
var headless_match_host = null
var network_manager: Node = null
var game_event_broadcaster: GameEventBroadcaster = null
var match_session = null

var _default_match_setup = DefaultMatchSetupScript.new()
var _match_history_store = MatchHistoryStoreScript.new()
var _match_started: bool = false

func start_from_config(config: Dictionary) -> Error:
	var config_error: String = _validate_config(config)
	if not config_error.is_empty():
		startup_failed.emit(config_error)
		return ERR_INVALID_PARAMETER

	match_session = MatchSessionScript.from_launch_config(config)
	if match_session == null:
		startup_failed.emit("Failed to rebuild match session from launch config.")
		return ERR_INVALID_DATA

	game_manager = GameManager.new()
	match_manager = MatchManager.new(game_manager)
	prompt_router = PromptRouterScript.new(game_manager)
	headless_match_host = HeadlessMatchHostScript.new()
	headless_match_host.attach(game_manager, match_manager, prompt_router)
	headless_match_host.configure_match_session(match_session)
	headless_match_host.match_player_authenticated.connect(_on_match_player_authenticated)

	if match_session == null or match_session.player_decks_by_session.is_empty():
		startup_failed.emit("Dedicated match launch was missing submitted deck data.")
		return ERR_INVALID_DATA

	var match_players: Dictionary = _default_match_setup.build_match_from_session_decks(game_manager, match_session)
	if match_players.is_empty():
		startup_failed.emit("Dedicated match bootstrap failed to build the submitted player decks.")
		return ERR_INVALID_DATA

	var player1: Player = match_players.get("player1", null)
	var player2: Player = match_players.get("player2", null)
	if player1 == null or player2 == null:
		startup_failed.emit("Dedicated match bootstrap did not create both players.")
		return ERR_INVALID_DATA

	# Open the match port only after the authoritative game state is fully bootstrapped.
	network_manager = headless_match_host.setup_transport(
		self,
		true,
		false,
		match_session.server_ip,
		match_session.match_port,
		false
	)
	if network_manager == null:
		startup_failed.emit("Failed to create the dedicated match transport.")
		return ERR_CANT_CREATE

	var transport_err: int = int(network_manager.get("last_server_error"))
	if transport_err != OK:
		startup_failed.emit("Dedicated match transport failed to bind port %d." % match_session.match_port)
		return transport_err

	headless_match_host.enable_authoritative_broadcasts()
	game_event_broadcaster = headless_match_host.game_event_broadcaster
	if not game_manager.game_ended.is_connected(_on_game_ended):
		game_manager.game_ended.connect(_on_game_ended)

	startup_succeeded.emit(match_session.match_id, match_session.match_port)
	return OK

func has_started_match() -> bool:
	return _match_started

func maybe_start_match_if_ready() -> bool:
	if _match_started or match_session == null or game_manager == null:
		return _match_started
	if not match_session.all_players_connected():
		return false
	if network_manager == null or network_manager.player_peer_ids.size() < match_session.player_session_ids.size():
		return false
	_match_started = true
	game_manager.start_turn()
	return true

func _on_match_player_authenticated(_player_index: int, _session_id: String, was_reconnect: bool) -> void:
	if was_reconnect:
		return
	maybe_start_match_if_ready()

func _queue_wolf_adolescent_maturation_prompt(card: WolfAdolescent) -> void:
	if card == null or game_manager == null or match_manager == null:
		return
	var player_idx := game_manager.players.find(card.card_owner)
	if player_idx < 0:
		return
	var target_uids: Array[String] = []
	for target in card.get_valid_maturation_targets():
		if target != null:
			target_uids.append(target.uid)
	match_manager.request_ui_interaction.emit(player_idx, "wolf_adolescent_maturation", {
		"source_uid": card.uid,
		"target_uids": target_uids,
	})

func _queue_humbaba_augury_reading_prompt(card: HumbabaTheTerrible) -> void:
	if card == null or game_manager == null or match_manager == null:
		return
	var prompt_player := game_manager.get_opponent(card.get_controller())
	var player_idx := game_manager.players.find(prompt_player)
	if player_idx < 0:
		return
	var target_uids: Array[String] = []
	for target in card.get_augury_cards(game_manager):
		if target != null:
			target_uids.append(target.uid)
	if target_uids.is_empty():
		return
	match_manager.request_ui_interaction.emit(player_idx, "humbaba_augury", {
		"source_uid": card.uid,
		"target_uids": target_uids,
	})

func _validate_config(config: Dictionary) -> String:
	if config.is_empty():
		return "Dedicated headless match config was empty."
	if str(config.get("match_id", "")).strip_edges().is_empty():
		return "Dedicated headless match config is missing match_id."
	if int(config.get("match_port", 0)) <= 0:
		return "Dedicated headless match config is missing a valid match_port."
	var player_ids = config.get("player_session_ids", [])
	if not (player_ids is Array) or (player_ids as Array).size() < 2:
		return "Dedicated headless match config must list both player session IDs."
	return ""

func _on_game_ended(_winner: Player, _loser: Player) -> void:
	_record_match_result(_winner, _loser)
	var tree := get_tree()
	if tree == null:
		return
	var shutdown_timer := tree.create_timer(1.0)
	shutdown_timer.timeout.connect(func() -> void:
		if get_tree() != null:
			get_tree().quit()
	)

func _record_match_result(winner: Player, loser: Player) -> void:
	if match_session == null or game_manager == null or winner == null or loser == null:
		return
	if not match_session.is_ranked:
		return
	var winner_index: int = game_manager.players.find(winner)
	var loser_index: int = game_manager.players.find(loser)
	if winner_index < 0 or loser_index < 0:
		return
	_match_history_store.record_completed_match(
		match_session,
		winner_index,
		loser_index,
		_get_player_god_name(winner),
		_get_player_god_name(loser)
	)

func _get_player_god_name(player: Player) -> String:
	if player == null or player.god_zone == null or player.god_zone.cards.is_empty():
		return ""
	var god_card = player.god_zone.cards[0]
	if god_card == null:
		return ""
	return str(god_card.card_name).strip_edges()
