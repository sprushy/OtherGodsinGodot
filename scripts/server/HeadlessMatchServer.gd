extends Node
class_name HeadlessMatchServer

const PromptRouterScript = preload("res://scripts/server/PromptRouter.gd")
const HeadlessMatchHostScript = preload("res://scripts/server/HeadlessMatchHost.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const DefaultMatchSetupScript = preload("res://scripts/server/DefaultMatchSetup.gd")
const MatchHistoryStoreScript = preload("res://scripts/server/MatchHistoryStore.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const PracticeFuzzPlayerBotScript = preload("res://scripts/bots/PracticeFuzzPlayerBot.gd")
const ServerBotGameInputScript = preload("res://scripts/bots/ServerBotGameInput.gd")
const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const INITIAL_JOIN_TIMEOUT_SECONDS := 120
const ABANDONED_MATCH_SHUTDOWN_DELAY_SECONDS := 0.25
const GAME_END_SHUTDOWN_DELAY_SECONDS := 3.0
const STATUS_HEARTBEAT_INTERVAL_SECONDS := 1.0
const RANKED_TURN_TIMEOUT_MSEC := 180_000
const RANKED_TIMEOUT_RESOLUTION_GRACE_MSEC := 8_000
const BOT_SELF_PLAY_STALL_MSEC := 45_000
const BOT_SELF_PLAY_LIMIT_MSEC := 20 * 60 * 1000

signal startup_succeeded(match_id: String, port: int)
signal startup_failed(message: String)

var game_manager: GameManager = null
var match_manager: MatchManager = null
var prompt_router = null
var headless_match_host = null
var network_manager: Node = null
var game_event_broadcaster: GameEventBroadcaster = null
var match_session = null
var exit_tree_on_shutdown: bool = true

var _default_match_setup = DefaultMatchSetupScript.new()
var _match_history_store = MatchHistoryStoreScript.new(MatchHistoryStoreScript.DEFAULT_STORAGE_FILE_NAME, true)
var _deck_validator = DeckValidatorScript.new()
var _match_started: bool = false
var _initial_join_deadline_unix: int = 0
var _abandoned_shutdown_started: bool = false
var _finished_shutdown_pending: bool = false
var _series_end_payload: Dictionary = {}
var _ranked_results_by_player: Dictionary = {}
var _status_heartbeat_elapsed: float = 0.0
var _reinforcement_phase_active: bool = false
var _server_bot_entries: Array[Dictionary] = []
var _bot_review_started_msec := 0
var _bot_review_progress_msec := 0
var _bot_review_turn := 0
var _bot_review_drawn := [{}, {}]
var _bot_review_played := [{}, {}]
var _bot_review_activated := [{}, {}]
var _bot_review_issues := {}
var _ranked_clock_turn_number := -1
var _ranked_clock_context: Dictionary = {}
var _ranked_clock_remaining_by_player: Dictionary = {}
var _ranked_clock_started_msec := 0
var _ranked_timeout_turn_number := -1
var _ranked_timeout_deadline_msec := 0

func _process(delta: float) -> void:
	if not _abandoned_shutdown_started:
		_status_heartbeat_elapsed += delta
		if _status_heartbeat_elapsed >= STATUS_HEARTBEAT_INTERVAL_SECONDS:
			_status_heartbeat_elapsed = 0.0
			if not _finished_shutdown_pending and _has_lost_bot_supervisor():
				_shutdown_abandoned_match("Lobby supervisor exited.")
				return
			_write_status_file()
	_shutdown_if_match_was_abandoned()
	_check_ranked_turn_clock()
	if _bot_review_started_msec > 0 and not _abandoned_shutdown_started and not _finished_shutdown_pending:
		var now := Time.get_ticks_msec()
		if now - _bot_review_progress_msec >= BOT_SELF_PLAY_STALL_MSEC:
			_shutdown_abandoned_match("Bot self-play stopped advancing turns.")
		elif now - _bot_review_started_msec >= BOT_SELF_PLAY_LIMIT_MSEC:
			_shutdown_abandoned_match("Bot self-play reached its match time limit.")

func _has_lost_bot_supervisor() -> bool:
	if match_session == null or not match_session.is_ranked:
		return false
	var heartbeat_path: String = match_session.supervisor_heartbeat_path
	if heartbeat_path.is_empty():
		return false
	var last_heartbeat := FileAccess.get_modified_time(heartbeat_path)
	return last_heartbeat <= 0 or Time.get_unix_time_from_system() - last_heartbeat >= MatchSessionScript.SUPERVISOR_HEARTBEAT_TIMEOUT_SECONDS

func _check_ranked_turn_clock() -> void:
	if not _match_started or _finished_shutdown_pending or match_session == null \
			or not match_session.is_ranked or match_manager == null or game_manager == null:
		return
	if game_manager.turn_number != _ranked_clock_turn_number:
		_ranked_clock_turn_number = game_manager.turn_number
		_ranked_clock_context.clear()
		_ranked_clock_remaining_by_player.clear()
		_ranked_clock_started_msec = 0
		_ranked_timeout_turn_number = -1
		_ranked_timeout_deadline_msec = 0
	if match_session.is_waiting_for_reconnect():
		_save_ranked_clock_budget(Time.get_ticks_msec())
		_ranked_clock_context.clear()
		return
	var context := match_manager.get_action_clock_context()
	var now_msec := Time.get_ticks_msec()
	if context.is_empty():
		_save_ranked_clock_budget(now_msec)
		_ranked_clock_context.clear()
		return
	var player_index := int(context.get("player_index", -1))
	if player_index < 0 or player_index >= game_manager.players.size():
		return
	if context != _ranked_clock_context:
		_save_ranked_clock_budget(now_msec)
		if _ranked_timeout_turn_number == game_manager.turn_number:
			return
		_ranked_clock_context = context.duplicate()
		var budget: int = int(_ranked_clock_remaining_by_player.get(player_index, RANKED_TURN_TIMEOUT_MSEC))
		_ranked_clock_remaining_by_player[player_index] = int(budget)
		_ranked_clock_started_msec = now_msec
	var remaining := int(_ranked_clock_remaining_by_player.get(player_index, RANKED_TURN_TIMEOUT_MSEC)) \
		- maxi(0, now_msec - _ranked_clock_started_msec)
	if remaining > 0:
		return
	if _ranked_timeout_turn_number != game_manager.turn_number:
		_ranked_timeout_turn_number = game_manager.turn_number
		_ranked_timeout_deadline_msec = now_msec + RANKED_TIMEOUT_RESOLUTION_GRACE_MSEC
	elif now_msec >= _ranked_timeout_deadline_msec:
		_shutdown_abandoned_match("Ranked match stopped advancing after the turn timer expired.")

func _save_ranked_clock_budget(now_msec: int) -> void:
	if _ranked_clock_context.is_empty() or _ranked_clock_started_msec <= 0:
		return
	var player_index := int(_ranked_clock_context.get("player_index", -1))
	var remaining := int(_ranked_clock_remaining_by_player.get(player_index, RANKED_TURN_TIMEOUT_MSEC)) \
		- maxi(0, now_msec - _ranked_clock_started_msec)
	_ranked_clock_remaining_by_player[player_index] = maxi(0, remaining)
	_ranked_clock_started_msec = now_msec

func _on_ranked_clock_move_validated(move: Dictionary) -> void:
	if match_session == null or not match_session.is_ranked or game_manager == null:
		return
	if str(move.get("type", "")) not in ["play_card", "play_creature", "cast_spell", "cast_charm", "play_charm_response", "play_hex_response", "prepare_card"]:
		return
	var player_index := int(_ranked_clock_context.get("player_index", -1))
	if player_index < 0:
		return
	var now_msec := Time.get_ticks_msec()
	_save_ranked_clock_budget(now_msec)
	var remaining := int(_ranked_clock_remaining_by_player.get(player_index, RANKED_TURN_TIMEOUT_MSEC))
	_ranked_clock_remaining_by_player[player_index] = mini(RANKED_TURN_TIMEOUT_MSEC, remaining + 2_000)
	_ranked_clock_started_msec = now_msec

func start_from_config(config: Dictionary) -> Error:
	exit_tree_on_shutdown = not bool(config.get("_shared_worker", false))
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
		false,
		{},
		bool(config.get("_shared_worker", false))
	)
	if network_manager == null:
		startup_failed.emit("Failed to create the dedicated match transport.")
		return ERR_CANT_CREATE

	var transport_err: Error = network_manager.get("last_server_error") as Error
	if transport_err != OK:
		startup_failed.emit("Dedicated match transport failed to bind UDP/WebSocket port %d." % match_session.match_port)
		return transport_err

	if not game_manager.game_ended.is_connected(_on_game_ended):
		game_manager.game_ended.connect(_on_game_ended)
	if not match_manager.move_validated.is_connected(_on_ranked_clock_move_validated):
		match_manager.move_validated.connect(_on_ranked_clock_move_validated)
	headless_match_host.enable_authoritative_broadcasts()
	game_event_broadcaster = headless_match_host.game_event_broadcaster

	_write_status_file(MatchSessionScript.STATUS_ACTIVE)
	startup_succeeded.emit(match_session.match_id, match_session.match_port)
	if match_session.all_players_connected():
		call_deferred("maybe_start_match_if_ready")
	return OK

func has_started_match() -> bool:
	return _match_started

func maybe_start_match_if_ready() -> bool:
	if _match_started or match_session == null or game_manager == null:
		return _match_started
	if not match_session.all_players_connected():
		return false
	if network_manager == null:
		return false
	var required_human_count := _get_required_human_player_count()
	if _get_connected_human_player_count() < required_human_count:
		return false
	_match_started = true
	_initial_join_deadline_unix = 0
	if match_session.is_bot_self_play():
		_start_bot_review()
	_attach_server_bots_for_match()
	game_manager.start_turn()
	_poll_server_bots()
	return true

func _on_match_player_authenticated(_player_index: int, _session_id: String, was_reconnect: bool) -> void:
	if _reinforcement_phase_active:
		var winner_index := game_manager.players.find(game_manager.winning_player) if game_manager != null else -1
		_send_reinforcement_phase_to_player(_player_index, {}, winner_index)
		return
	if _finished_shutdown_pending:
		_send_series_end_to_player(_player_index)
		_write_status_file(MatchSessionScript.STATUS_FINISHED)
		if match_session == null or not match_session.is_waiting_for_reconnect():
			_schedule_finished_match_shutdown(GAME_END_SHUTDOWN_DELAY_SECONDS)
		return
	if was_reconnect:
		_poll_server_bots()
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

func _attach_server_bots_for_match() -> void:
	_detach_server_bots()
	if match_session == null or game_manager == null or match_manager == null:
		return
	for player_index in range(match_session.player_session_ids.size()):
		var session_id := str(match_session.player_session_ids[player_index]).strip_edges()
		if session_id.is_empty() or not match_session.is_bot_session(session_id):
			continue
		if player_index < 0 or player_index >= game_manager.players.size():
			continue
		var bot_input = ServerBotGameInputScript.new(match_manager, player_index, match_session)
		var bot = PracticeFuzzPlayerBotScript.new()
		bot.attach(game_manager, match_manager, bot_input, player_index)
		_server_bot_entries.append({
			"session_id": session_id,
			"player_index": player_index,
			"bot": bot,
			"game_input": bot_input,
		})

func _detach_server_bots() -> void:
	for entry in _server_bot_entries:
		var bot = entry.get("bot", null)
		if bot != null and bot.has_method("detach"):
			bot.detach()
	_server_bot_entries.clear()

func _poll_server_bots() -> void:
	for entry in _server_bot_entries:
		var bot = entry.get("bot", null)
		if bot != null and bot.has_method("poll"):
			bot.poll()

func _mark_bot_reinforcements_ready() -> void:
	if match_session == null:
		return
	for session_id in match_session.player_session_ids:
		var resolved_session_id := str(session_id).strip_edges()
		if not resolved_session_id.is_empty() and match_session.is_bot_session(resolved_session_id):
			match_session.set_reinforcement_ready(resolved_session_id, true)

func _get_required_human_player_count() -> int:
	if match_session == null:
		return 0
	if match_session.has_method("get_human_player_count"):
		return int(match_session.get_human_player_count())
	var count := 0
	for session_id in match_session.player_session_ids:
		var resolved_session_id := str(session_id).strip_edges()
		if resolved_session_id.is_empty() or (match_session.has_method("is_bot_session") and match_session.is_bot_session(resolved_session_id)):
			continue
		count += 1
	return count

func _get_connected_human_player_count() -> int:
	if match_session == null:
		return 0
	if match_session.has_method("get_connected_human_player_count"):
		return int(match_session.get_connected_human_player_count())
	if network_manager == null:
		return 0
	var count := 0
	for player_index in network_manager.player_peer_ids.keys():
		var resolved_index := int(player_index)
		if resolved_index < 0 or resolved_index >= match_session.player_session_ids.size():
			continue
		var session_id := str(match_session.player_session_ids[resolved_index]).strip_edges()
		if session_id.is_empty() or (match_session.has_method("is_bot_session") and match_session.is_bot_session(session_id)):
			continue
		count += 1
	return count

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
	if _finished_shutdown_pending:
		return
	var winner_index := game_manager.players.find(_winner) if game_manager != null else -1
	var result_message := _get_current_game_result_message()
	var series_snapshot: Dictionary = {}
	if match_session != null:
		series_snapshot = match_session.record_series_game_win(winner_index) if winner_index >= 0 else match_session.get_series_snapshot()
	if match_session != null \
			and game_manager != null \
			and game_manager.game_end_reason == GameManager.GAME_END_REASON_MATCH_FORFEIT \
			and winner_index >= 0:
		var winner_session_id := str(match_session.player_session_ids[winner_index]).strip_edges()
		match_session.series_wins_by_session[winner_session_id] = match_session.games_to_win
		series_snapshot = match_session.get_series_snapshot()
	if match_session != null and match_session.series_best_of > 1 and not match_session.is_series_complete():
		_mark_bot_reinforcements_ready()
		if game_event_broadcaster != null:
			game_event_broadcaster.suppress_next_game_end = true
		_reinforcement_phase_active = true
		headless_match_host.series_between_games = true
		_broadcast_reinforcement_phase(series_snapshot, winner_index, result_message)
		_write_status_file(MatchSessionScript.STATUS_ACTIVE)
		return

	_finished_shutdown_pending = true
	if match_session != null:
		match_session.mark_finished()
		series_snapshot = match_session.get_series_snapshot()
	_detach_server_bots()
	_ranked_results_by_player = _record_match_result(_winner, _loser)
	if match_session.is_bot_self_play():
		_write_bot_review(winner_index)
	_series_end_payload = {
		"winner_index": winner_index,
		"series": series_snapshot,
		"result_message": result_message,
	}
	_write_status_file(MatchSessionScript.STATUS_FINISHED)
	# Send each player's recap before the terminal state triggers their result screen.
	if network_manager != null:
		for player_index in network_manager.player_peer_ids:
			_send_series_end_to_player(int(player_index))
		for peer_id in network_manager.spectator_peer_ids:
			network_manager.broadcast_event_to_peer(int(peer_id), "series_ended", _series_end_payload)
	var tree := get_tree()
	if tree == null:
		return
	_schedule_finished_match_shutdown(_get_finished_match_shutdown_delay_seconds())

func _send_series_end_to_player(player_index: int) -> void:
	if network_manager == null:
		return
	var peer_id := int(network_manager.player_peer_ids.get(player_index, -1))
	if peer_id <= 0:
		return
	var payload := _series_end_payload.duplicate()
	if _ranked_results_by_player.has(player_index):
		payload["ranked_result"] = _ranked_results_by_player[player_index]
	network_manager.broadcast_event_to_peer(peer_id, "series_ended", payload)

func _get_finished_match_shutdown_delay_seconds() -> float:
	var shutdown_delay := GAME_END_SHUTDOWN_DELAY_SECONDS
	if match_session != null and match_session.is_waiting_for_reconnect():
		var now_unix := int(Time.get_unix_time_from_system())
		var reconnect_deadline := int(match_session.reconnect_deadline_unix)
		if reconnect_deadline > now_unix:
			shutdown_delay = max(shutdown_delay, float(reconnect_deadline - now_unix) + GAME_END_SHUTDOWN_DELAY_SECONDS)
	return shutdown_delay

func _schedule_finished_match_shutdown(delay_seconds: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var shutdown_timer := tree.create_timer(max(0.05, delay_seconds))
	shutdown_timer.timeout.connect(Callable(self, "_on_finished_match_shutdown_timer_timeout"))

func _on_finished_match_shutdown_timer_timeout() -> void:
	if not _finished_shutdown_pending:
		return
	_abandoned_shutdown_started = true
	_write_status_file(MatchSessionScript.STATUS_FINISHED)
	_finish_runtime_shutdown()

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

func _get_current_game_result_message() -> String:
	if game_manager != null and game_manager.is_game_over:
		return game_manager.get_game_result_message()
	return ""

func _broadcast_reinforcement_phase(
	series_snapshot: Dictionary,
	winner_index: int,
	result_message: String = ""
) -> void:
	if network_manager == null or match_session == null:
		return
	for player_index in network_manager.player_peer_ids.keys():
		_send_reinforcement_phase_to_player(int(player_index), series_snapshot, winner_index, result_message)
	for peer_id in network_manager.spectator_peer_ids:
		network_manager.broadcast_event_to_peer(int(peer_id), "series_game_ended", {
			"winner_index": winner_index,
			"series": series_snapshot,
			"result_message": result_message,
		})

func _send_reinforcement_phase_to_player(
	player_index: int,
	series_snapshot: Dictionary = {},
	winner_index: int = -1,
	result_message: String = ""
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
	var resolved_result_message := result_message.strip_edges()
	if resolved_result_message.is_empty():
		resolved_result_message = _get_current_game_result_message()
	network_manager.broadcast_event_to_peer(peer_id, "reinforcement_phase", {
		"winner_index": winner_index,
		"series": resolved_series,
		"result_message": resolved_result_message,
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
	_detach_server_bots()
	if game_event_broadcaster != null:
		game_event_broadcaster.shutdown()

	game_manager = GameManager.new()
	match_manager = MatchManager.new(game_manager)
	match_manager.network_manager = network_manager
	prompt_router = PromptRouterScript.new(game_manager)
	headless_match_host.attach(game_manager, match_manager, prompt_router)
	headless_match_host.configure_match_session(match_session)

	var match_players: Dictionary = _default_match_setup.build_match_from_session_decks(game_manager, match_session)
	if match_players.is_empty():
		_shutdown_abandoned_match("Could not build the next game in the series.")
		return
	if not game_manager.game_ended.is_connected(_on_game_ended):
		game_manager.game_ended.connect(_on_game_ended)
	if not match_manager.move_validated.is_connected(_on_ranked_clock_move_validated):
		match_manager.move_validated.connect(_on_ranked_clock_move_validated)
	headless_match_host.enable_authoritative_broadcasts()
	game_event_broadcaster = headless_match_host.game_event_broadcaster
	_attach_server_bots_for_match()
	network_manager.broadcast_event_to_all("series_game_started", {
		"series": match_session.get_series_snapshot(),
	})
	game_manager.start_turn()
	_poll_server_bots()
	_write_status_file(MatchSessionScript.STATUS_ACTIVE)

func _shutdown_if_match_was_abandoned() -> void:
	if _abandoned_shutdown_started or match_session == null:
		return
	if _finished_shutdown_pending:
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
	_detach_server_bots()
	if match_session != null and match_session.is_bot_self_play():
		_write_bot_review(-1)
	_write_status_file(MatchSessionScript.STATUS_ABANDONED, reason)
	if network_manager != null:
		network_manager.broadcast_event_to_all("match_abandoned", {"reason": reason})
	var tree := get_tree()
	if tree == null:
		return
	var shutdown_timer := tree.create_timer(ABANDONED_MATCH_SHUTDOWN_DELAY_SECONDS)
	shutdown_timer.timeout.connect(_finish_runtime_shutdown)

func _finish_runtime_shutdown() -> void:
	if exit_tree_on_shutdown:
		var tree := get_tree()
		if tree != null:
			tree.quit()
		return
	queue_free()

func _record_match_result(winner: Player, loser: Player) -> Dictionary:
	if match_session == null or game_manager == null or not match_session.is_ranked:
		return {}
	var winner_index: int = game_manager.players.find(winner)
	var loser_index: int = game_manager.players.find(loser)
	var record_result: Dictionary = _match_history_store.record_completed_match(
		match_session,
		winner_index,
		loser_index,
		_get_player_god_name(winner),
		_get_player_god_name(loser),
		_bot_battle_summary() if match_session.is_bot_self_play() else {}
	)
	if not bool(record_result.get("success", false)):
		push_warning("HeadlessMatchServer: failed to record match result: %s" % str(record_result.get("message", "Unknown error.")))
		if match_session.is_bot_self_play():
			_on_bot_review_move_failed("Failed to save the rated match result.")
		return {}
	return _match_history_store.get_ranked_match_results(record_result["entry"])

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
	if match_session.is_bot_self_play() and _bot_review_started_msec > 0:
		payload["bot_turn"] = _bot_review_turn
		payload["bot_issues"] = _bot_review_issues
	JsonStoreScript.save_json(status_path, payload, "HeadlessMatchServer")

func _start_bot_review() -> void:
	_bot_review_started_msec = maxi(1, Time.get_ticks_msec())
	_bot_review_progress_msec = _bot_review_started_msec
	game_manager.turn_started.connect(_on_bot_review_turn_started)
	game_manager.card_summoned.connect(_on_bot_review_summon)
	game_manager.hand_card_entered_play.connect(_on_bot_review_hand_play)
	match_manager.action_resolved.connect(_on_bot_review_action)
	match_manager.move_validated.connect(_on_bot_review_command)
	match_manager.move_failed.connect(_on_bot_review_move_failed)
	for i in game_manager.players.size():
		var player := game_manager.players[i]
		player.card_moved.connect(_on_bot_review_card_moved.bind(i))
		for card in player.hand_zone.cards:
			_increment_bot_review_count(_bot_review_drawn[i], card.card_name)

func _on_bot_review_turn_started(turn: int, _player: Player) -> void:
	if turn > _bot_review_turn:
		_bot_review_turn = turn
		_bot_review_progress_msec = Time.get_ticks_msec()

func _on_bot_review_card_moved(card: Card, from_zone: Zone, to_zone: Zone, index: int) -> void:
	if card != null and to_zone == game_manager.players[index].hand_zone and from_zone != to_zone:
		_increment_bot_review_count(_bot_review_drawn[index], card.card_name)

func _on_bot_review_summon(player: Player, card: Card, from_zone: Zone, _to_zone: Zone, _source: Card, _face_down: bool, _stealth: bool) -> void:
	if from_zone == null or from_zone.zone_type != Zone.ZoneType.HAND:
		_on_bot_review_hand_play(player, card)

func _on_bot_review_hand_play(player: Player, card: Card) -> void:
	var index := game_manager.players.find(player)
	if index >= 0 and card != null and not card.is_token:
		_increment_bot_review_count(_bot_review_played[index], card.card_name)

func _on_bot_review_action(action: CardAction) -> void:
	if action != null and action.card != null and action.type != CardAction.Type.EVENT and (action.card is SpellCard or action.card is CharmCard or action.card is HexCard):
		var index := game_manager.players.find(action.source_player)
		if index >= 0:
			_increment_bot_review_count(_bot_review_activated[index], action.card.card_name)

func _on_bot_review_command(command: Dictionary) -> void:
	if str(command.get("type", "")) != "unlock_power":
		return
	var card := game_manager.get_card_by_uid(str(command.get("power_uid", "")))
	if card != null and not card.is_face_down:
		_on_bot_review_hand_play(card.get_controller(), card)

func _on_bot_review_move_failed(reason: String) -> void:
	if _bot_review_issues.has(reason) or _bot_review_issues.size() < 32:
		_increment_bot_review_count(_bot_review_issues, reason)

func _increment_bot_review_count(counts: Dictionary, name: String) -> void:
	counts[name] = int(counts.get(name, 0)) + 1

func _bot_battle_summary() -> Dictionary:
	var followers: Array[int] = []
	for player in game_manager.players:
		followers.append(player.followers)
	return {"turns": game_manager.turn_number, "duration_seconds": int(game_manager.match_result_stats.get("duration_seconds", 0)), "followers": followers}

func _write_bot_review(winner_index: int) -> void:
	var seats: Array[Dictionary] = []
	for i in match_session.player_session_ids.size():
		var id: String = match_session.player_session_ids[i]
		var deck: Dictionary = match_session.registered_player_decks_by_session.get(id, {})
		var never_played: Array[String] = []
		var unplayed_main_deck: Array[String] = []
		for name in _bot_review_drawn[i]:
			if not _bot_review_played[i].has(name) and not _bot_review_activated[i].has(name):
				never_played.append(name)
		never_played.sort()
		for name in deck.get("cards", {}):
			if name != deck.get("bot_god_name", "") and not _bot_review_played[i].has(name) and not _bot_review_activated[i].has(name):
				unplayed_main_deck.append(name)
		unplayed_main_deck.sort()
		seats.append({"name": match_session.get_player_display_name(id, i), "list_id": deck.get("bot_list_id", ""),
			"cards": deck.get("cards", {}), "seen_in_hand": _bot_review_drawn[i], "played": _bot_review_played[i],
			"magic_resolutions": _bot_review_activated[i], "seen_but_never_played": never_played, "unplayed_deck_cards": unplayed_main_deck})
	JsonStoreScript.save_json(ServerPathsScript.get_bot_review_path(match_session.match_id), {
		"match_id": match_session.match_id, "turns": _bot_review_turn, "winner_index": winner_index,
		"status": match_session.status, "seats": seats, "command_failures": _bot_review_issues,
	}, "BotSelfPlay")

func _get_player_god_name(player: Player) -> String:
	if player == null or player.god_zone == null or player.god_zone.cards.is_empty():
		return ""
	var god_card = player.god_zone.cards[0]
	if god_card == null:
		return ""
	return str(god_card.card_name).strip_edges()
