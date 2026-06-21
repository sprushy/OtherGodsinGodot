extends Node
class_name HeadlessMatchServer

const PromptRouterScript = preload("res://scripts/server/PromptRouter.gd")
const HeadlessMatchHostScript = preload("res://scripts/server/HeadlessMatchHost.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const DefaultMatchSetupScript = preload("res://scripts/server/DefaultMatchSetup.gd")
const MatchHistoryStoreScript = preload("res://scripts/server/MatchHistoryStore.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const INITIAL_JOIN_TIMEOUT_SECONDS := 120
const ABANDONED_MATCH_SHUTDOWN_DELAY_SECONDS := 0.25
const GAME_END_SHUTDOWN_DELAY_SECONDS := 3.0
const STATUS_HEARTBEAT_INTERVAL_SECONDS := 1.0

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
var _deck_validator = DeckValidatorScript.new()
var _match_started: bool = false
var _initial_join_deadline_unix: int = 0
var _abandoned_shutdown_started: bool = false
var _status_heartbeat_elapsed: float = 0.0
var _reinforcement_phase_active: bool = false

func _process(delta: float) -> void:
	if not _abandoned_shutdown_started:
		_status_heartbeat_elapsed += delta
		if _status_heartbeat_elapsed >= STATUS_HEARTBEAT_INTERVAL_SECONDS:
			_status_heartbeat_elapsed = 0.0
			_write_status_file()
	_shutdown_if_match_was_abandoned()

func start_from_config(config: Dictionary) -> Error:
	var config_error: String = _validate_config(config)
	if not config_error.is_empty():
		startup_failed.emit(config_error)
		return ERR_INVALID_PARAMETER

	match_session = MatchSessionScript.from_launch_config(config)
	if match_session == null:
		startup_failed.emit("Failed to rebuild match session from launch config.")
		return ERR_INVALID_DATA
	_write_status_file(MatchSessionScript.STATUS_STARTING)
	_initial_join_deadline_unix = int(Time.get_unix_time_from_system()) + INITIAL_JOIN_TIMEOUT_SECONDS

	game_manager = GameManager.new()
	match_manager = MatchManager.new(game_manager)
	prompt_router = PromptRouterScript.new(game_manager)
	headless_match_host = HeadlessMatchHostScript.new()
	headless_match_host.attach(game_manager, match_manager, prompt_router)
	headless_match_host.configure_match_session(match_session)
	headless_match_host.match_player_authenticated.connect(_on_match_player_authenticated)
	headless_match_host.series_command_received.connect(_on_series_command_received)

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

	var transport_err: Error = network_manager.get("last_server_error") as Error
	if transport_err != OK:
		startup_failed.emit("Dedicated match transport failed to bind port %d." % match_session.match_port)
		return transport_err

	if not game_manager.game_ended.is_connected(_on_game_ended):
		game_manager.game_ended.connect(_on_game_ended)
	headless_match_host.enable_authoritative_broadcasts()
	game_event_broadcaster = headless_match_host.game_event_broadcaster

	_write_status_file(MatchSessionScript.STATUS_ACTIVE)
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
	_initial_join_deadline_unix = 0
	game_manager.start_turn()
	return true

func _on_match_player_authenticated(_player_index: int, _session_id: String, was_reconnect: bool) -> void:
	if _reinforcement_phase_active:
		_send_reinforcement_phase_to_player(_player_index)
		return
	if was_reconnect:
		return
	maybe_start_match_if_ready()

func _queue_wolf_adolescent_maturation_prompt(card: Card) -> void:
	if card == null or game_manager == null or match_manager == null:
		return
	var target_uids: Array[String] = []
	for target in card.get_valid_maturation_targets():
		if target != null:
			target_uids.append(target.uid)
	match_manager.emit_ui_interaction_for_player(card.card_owner, "wolf_adolescent_maturation", {
		"source_uid": card.uid,
		"target_uids": target_uids,
	})

func _queue_humbaba_augury_reading_prompt(card: HumbabaTheTerrible) -> void:
	if card == null or game_manager == null or match_manager == null:
		return
	var prompt_player := game_manager.get_opponent(card.get_controller())
	var target_uids: Array[String] = []
	for target in card.get_augury_cards(game_manager):
		if target != null:
			target_uids.append(target.uid)
	if target_uids.is_empty():
		return
	match_manager.emit_ui_interaction_for_player(prompt_player, "humbaba_augury", {
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
	var winner_index := game_manager.players.find(_winner) if game_manager != null else -1
	var series_snapshot: Dictionary = match_session.record_series_game_win(winner_index) if match_session != null else {}
	if match_session != null \
			and game_manager != null \
			and game_manager.game_end_reason == GameManager.GAME_END_REASON_MATCH_FORFEIT \
			and winner_index >= 0:
		var winner_session_id := str(match_session.player_session_ids[winner_index]).strip_edges()
		match_session.series_wins_by_session[winner_session_id] = match_session.games_to_win
		series_snapshot = match_session.get_series_snapshot()
	if match_session != null and not match_session.is_series_complete():
		if game_event_broadcaster != null:
			game_event_broadcaster.suppress_next_game_end = true
		_reinforcement_phase_active = true
		headless_match_host.series_between_games = true
		_broadcast_reinforcement_phase(series_snapshot, winner_index)
		_write_status_file(MatchSessionScript.STATUS_ACTIVE)
		return

	_abandoned_shutdown_started = true
	if match_session != null:
		match_session.mark_finished()
	_write_status_file(MatchSessionScript.STATUS_FINISHED)
	_record_match_result(_winner, _loser)
	if network_manager != null:
		network_manager.broadcast_event_to_all("series_ended", {
			"winner_index": winner_index,
			"series": series_snapshot,
		})
	var tree := get_tree()
	if tree == null:
		return
	var shutdown_timer := tree.create_timer(GAME_END_SHUTDOWN_DELAY_SECONDS)
	shutdown_timer.timeout.connect(Callable(tree, "quit"))

func _on_series_command_received(command: Dictionary, sender_info: Dictionary) -> void:
	var peer_id := int(sender_info.get("peer_id", -1))
	var player_index := int(sender_info.get("player_index", -1))
	if not _reinforcement_phase_active or match_session == null:
		_reject_series_command(peer_id, "Reinforcements can only be changed between games.")
		return
	if player_index < 0 or player_index >= match_session.player_session_ids.size():
		_reject_series_command(peer_id, "Could not identify the series player.")
		return
	var proposed_cards = command.get("cards", {})
	var proposed_reinforcements = command.get("reinforcements", {})
	if not (proposed_cards is Dictionary) or not (proposed_reinforcements is Dictionary):
		_reject_series_command(peer_id, "Submit both the main deck and Reinforcements.")
		return
	var session_id := str(match_session.player_session_ids[player_index]).strip_edges()
	var registered_submission = match_session.registered_player_decks_by_session.get(session_id, {})
	if not (registered_submission is Dictionary):
		_reject_series_command(peer_id, "The registered deck could not be found.")
		return
	var special_setup = (registered_submission as Dictionary).get("special_setup", {})
	var validation := _deck_validator.validate_reinforcement_swap(
		(registered_submission as Dictionary).get("cards", {}),
		(registered_submission as Dictionary).get("reinforcements", {}),
		proposed_cards as Dictionary,
		proposed_reinforcements as Dictionary,
		special_setup if special_setup is Dictionary else {}
	)
	if not bool(validation.get("is_valid", false)):
		_reject_series_command(peer_id, str(validation.get("error", "That Reinforcement swap is not legal.")))
		return
	var current_submission = match_session.player_decks_by_session.get(session_id, {})
	if not (current_submission is Dictionary):
		current_submission = {}
	var updated_submission := (current_submission as Dictionary).duplicate(true)
	updated_submission["cards"] = validation.get("cards", {})
	updated_submission["reinforcements"] = validation.get("reinforcements", {})
	updated_submission["validation"] = validation.duplicate(true)
	match_session.player_decks_by_session[session_id] = updated_submission
	match_session.set_reinforcement_ready(session_id, true)
	network_manager.broadcast_event_to_peer(peer_id, "reinforcement_submission_accepted", {
		"series": match_session.get_series_snapshot(),
	})
	_broadcast_reinforcement_readiness()
	if match_session.all_reinforcement_submissions_ready():
		call_deferred("_start_next_series_game")

func _reject_series_command(peer_id: int, reason: String) -> void:
	if network_manager == null:
		return
	network_manager.broadcast_event_to_peer(peer_id, "command_rejected", {"reason": reason})

func _broadcast_reinforcement_phase(series_snapshot: Dictionary, winner_index: int) -> void:
	if network_manager == null or match_session == null:
		return
	for player_index in network_manager.player_peer_ids.keys():
		_send_reinforcement_phase_to_player(int(player_index), series_snapshot, winner_index)
	for peer_id in network_manager.spectator_peer_ids:
		network_manager.broadcast_event_to_peer(int(peer_id), "series_game_ended", {
			"winner_index": winner_index,
			"series": series_snapshot,
		})

func _send_reinforcement_phase_to_player(
	player_index: int,
	series_snapshot: Dictionary = {},
	winner_index: int = -1
) -> void:
	if network_manager == null or match_session == null:
		return
	if player_index < 0 or player_index >= match_session.player_session_ids.size():
		return
	var peer_id := int(network_manager.player_peer_ids.get(player_index, -1))
	if peer_id <= 0:
		return
	var session_id := str(match_session.player_session_ids[player_index]).strip_edges()
	var submission = match_session.player_decks_by_session.get(session_id, {})
	if not (submission is Dictionary):
		return
	var resolved_series: Dictionary = series_snapshot if not series_snapshot.is_empty() else match_session.get_series_snapshot()
	network_manager.broadcast_event_to_peer(peer_id, "reinforcement_phase", {
		"winner_index": winner_index,
		"series": resolved_series,
		"cards": (submission as Dictionary).get("cards", {}),
		"reinforcements": (submission as Dictionary).get("reinforcements", {}),
		"is_ready": bool(match_session.reinforcement_ready_by_session.get(session_id, false)),
	})

func _broadcast_reinforcement_readiness() -> void:
	if network_manager == null or match_session == null:
		return
	var ready_count := 0
	for session_id in match_session.player_session_ids:
		if bool(match_session.reinforcement_ready_by_session.get(session_id, false)):
			ready_count += 1
	network_manager.broadcast_event_to_all("reinforcement_readiness", {
		"ready_count": ready_count,
		"player_count": match_session.player_session_ids.size(),
		"series": match_session.get_series_snapshot(),
	})

func _start_next_series_game() -> void:
	if not _reinforcement_phase_active or match_session == null:
		return
	_reinforcement_phase_active = false
	headless_match_host.series_between_games = false
	match_session.begin_next_series_game()
	if game_event_broadcaster != null:
		game_event_broadcaster.shutdown()

	game_manager = GameManager.new()
	match_manager = MatchManager.new(game_manager)
	match_manager.network_manager = network_manager
	match_manager.authoritative_match_flow_enabled = true
	prompt_router = PromptRouterScript.new(game_manager)
	headless_match_host.attach(game_manager, match_manager, prompt_router)
	headless_match_host.configure_match_session(match_session)

	var match_players: Dictionary = _default_match_setup.build_match_from_session_decks(game_manager, match_session)
	if match_players.is_empty():
		_shutdown_abandoned_match("Could not build the next game in the series.")
		return
	if not game_manager.game_ended.is_connected(_on_game_ended):
		game_manager.game_ended.connect(_on_game_ended)
	headless_match_host.enable_authoritative_broadcasts()
	game_event_broadcaster = headless_match_host.game_event_broadcaster
	network_manager.broadcast_event_to_all("series_game_started", {
		"series": match_session.get_series_snapshot(),
	})
	game_manager.start_turn()
	_write_status_file(MatchSessionScript.STATUS_ACTIVE)

func _shutdown_if_match_was_abandoned() -> void:
	if _abandoned_shutdown_started or match_session == null:
		return
	var now_unix := int(Time.get_unix_time_from_system())
	if match_session.has_reconnect_timed_out(now_unix):
		_shutdown_abandoned_match("Reconnect window expired.")
		return
	if not _match_started \
			and _initial_join_deadline_unix > 0 \
			and now_unix >= _initial_join_deadline_unix \
			and not match_session.all_players_connected():
		_shutdown_abandoned_match("Players did not join the match server in time.")

func _shutdown_abandoned_match(reason: String) -> void:
	if _abandoned_shutdown_started:
		return
	_abandoned_shutdown_started = true
	if match_session != null:
		match_session.mark_abandoned()
	_write_status_file(MatchSessionScript.STATUS_ABANDONED, reason)
	if network_manager != null:
		network_manager.broadcast_event_to_all("match_abandoned", {"reason": reason})
	var tree := get_tree()
	if tree == null:
		return
	var shutdown_timer := tree.create_timer(ABANDONED_MATCH_SHUTDOWN_DELAY_SECONDS)
	shutdown_timer.timeout.connect(Callable(tree, "quit"))

func _record_match_result(winner: Player, loser: Player) -> void:
	if match_session == null or game_manager == null or winner == null or loser == null:
		return
	if not match_session.is_ranked:
		return
	var winner_index: int = game_manager.players.find(winner)
	var loser_index: int = game_manager.players.find(loser)
	if winner_index < 0 or loser_index < 0:
		return
	var record_result: Dictionary = _match_history_store.record_completed_match(
		match_session,
		winner_index,
		loser_index,
		_get_player_god_name(winner),
		_get_player_god_name(loser)
	)
	if not bool(record_result.get("success", false)):
		push_warning("HeadlessMatchServer: failed to record match result: %s" % str(record_result.get("message", "Unknown error.")))

func _write_status_file(status_override: String = "", reason: String = "") -> void:
	if match_session == null:
		return
	var status_path := str(match_session.status_file_path).strip_edges()
	if status_path.is_empty():
		return
	var status := status_override.strip_edges()
	if status.is_empty():
		status = str(match_session.status).strip_edges()
	var status_dir := status_path.get_base_dir()
	if not status_dir.is_empty():
		var mkdir_err := DirAccess.make_dir_recursive_absolute(status_dir)
		if mkdir_err != OK and mkdir_err != ERR_ALREADY_EXISTS:
			return
	var payload := {
		"match_id": str(match_session.match_id),
		"room_id": str(match_session.room_id),
		"status": status,
		"heartbeat_unix": int(Time.get_unix_time_from_system()),
		"match_started": _match_started,
		"all_players_connected": match_session.all_players_connected(),
		"waiting_for_reconnect": match_session.is_waiting_for_reconnect(),
		"reconnect_deadline_unix": int(match_session.reconnect_deadline_unix),
		"reinforcement_phase": _reinforcement_phase_active,
		"series": match_session.get_series_snapshot(),
	}
	var clean_reason := reason.strip_edges()
	if not clean_reason.is_empty():
		payload["reason"] = clean_reason
	JsonStoreScript.save_json(status_path, payload, "HeadlessMatchServer")

func _get_player_god_name(player: Player) -> String:
	if player == null or player.god_zone == null or player.god_zone.cards.is_empty():
		return ""
	var god_card = player.god_zone.cards[0]
	if god_card == null:
		return ""
	return str(god_card.card_name).strip_edges()
