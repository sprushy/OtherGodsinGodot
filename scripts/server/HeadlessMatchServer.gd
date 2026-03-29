extends Node
class_name HeadlessMatchServer

const PromptRouterScript = preload("res://scripts/server/PromptRouter.gd")
const HeadlessMatchHostScript = preload("res://scripts/server/HeadlessMatchHost.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const DefaultMatchSetupScript = preload("res://scripts/server/DefaultMatchSetup.gd")

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
	game_manager.set_interaction_host(self)
	match_manager = MatchManager.new(game_manager)
	prompt_router = PromptRouterScript.new(game_manager)
	headless_match_host = HeadlessMatchHostScript.new()
	headless_match_host.attach(game_manager, match_manager, prompt_router)
	headless_match_host.configure_match_session(match_session)
	headless_match_host.match_player_authenticated.connect(_on_match_player_authenticated)

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

	var match_players: Dictionary = _default_match_setup.build_default_match(game_manager)
	headless_match_host.enable_authoritative_broadcasts()
	game_event_broadcaster = headless_match_host.game_event_broadcaster
	if not game_manager.game_ended.is_connected(_on_game_ended):
		game_manager.game_ended.connect(_on_game_ended)

	var player1: Player = match_players.get("player1", null)
	var player2: Player = match_players.get("player2", null)
	if player1 == null or player2 == null:
		startup_failed.emit("Dedicated match bootstrap did not create both players.")
		return ERR_INVALID_DATA

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
	var tree := get_tree()
	if tree == null:
		return
	var shutdown_timer := tree.create_timer(1.0)
	shutdown_timer.timeout.connect(func() -> void:
		if get_tree() != null:
			get_tree().quit()
	)
