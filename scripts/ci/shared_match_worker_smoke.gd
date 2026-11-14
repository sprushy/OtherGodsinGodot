extends SceneTree

const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")

const MATCH_COUNT := 2
const TEST_TIMEOUT_MSEC := 45_000

var _lobby = null
var _match_ids: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var first_port := 20_000 + rng.randi_range(0, 20_000)
	_lobby = LobbyServerScript.new()
	_lobby.name = "SharedWorkerSmokeLobby"
	_lobby.match_port = first_port
	_lobby.use_dedicated_match_processes = true
	_lobby.allow_in_process_match_fallback = false
	get_root().add_child(_lobby)
	await process_frame
	_lobby._ensure_match_supervisor()
	var supervisor = _lobby.match_supervisor
	supervisor.default_match_port = first_port
	supervisor.public_websocket_url = "wss://shared-worker-smoke.example"

	var failures: PackedStringArray = []
	for _index in MATCH_COUNT:
		var previous_ids: Dictionary = {}
		for match_id in supervisor.active_matches:
			previous_ids[str(match_id)] = true
		_lobby._launch_bot_self_play()
		var created_id := ""
		for match_id in supervisor.active_matches:
			if not previous_ids.has(str(match_id)):
				created_id = str(match_id)
				break
		if created_id.is_empty():
			failures.append("Lobby failed to create bot self-play match %d." % (_index + 1))
		else:
			_match_ids.append(created_id)

	var deadline := Time.get_ticks_msec() + TEST_TIMEOUT_MSEC
	while failures.is_empty() and Time.get_ticks_msec() < deadline:
		if _all_matches_started(supervisor):
			break
		await create_timer(0.1).timeout
	if failures.is_empty() and not _all_matches_started(supervisor):
		failures.append("Both shared matches did not become active before timeout.")

	if failures.is_empty():
		var ports := {}
		var api_ids := {}
		var websocket_api_ids := {}
		var game_manager_ids := {}
		for match_id in _match_ids:
			var session = supervisor.get_match(match_id)
			var runtime = supervisor._shared_bot_match_servers.get(match_id, null)
			if session == null or runtime == null or not is_instance_valid(runtime):
				failures.append("Shared runtime is missing for %s." % match_id)
				continue
			if not runtime.has_started_match() or runtime.game_manager == null:
				failures.append("Bot game did not start for %s." % match_id)
			if runtime.network_manager == null or not runtime.network_manager.is_server:
				failures.append("Match transport did not start for %s." % match_id)
			else:
				var port := int(session.match_port)
				var api_id := int(runtime.network_manager._ensure_multiplayer_api().get_instance_id())
				if ports.has(port):
					failures.append("Concurrent matches reused port %d." % port)
				if api_ids.has(api_id):
					failures.append("Concurrent matches share one MultiplayerAPI instance.")
				ports[port] = true
				api_ids[api_id] = true
				var websocket_transport = runtime.network_manager.websocket_transport
				if websocket_transport == null or not websocket_transport.is_server:
					failures.append("WebSocket transport did not start for %s." % match_id)
				else:
					var websocket_api_id := int(websocket_transport._ensure_multiplayer_api().get_instance_id())
					if websocket_api_ids.has(websocket_api_id):
						failures.append("Concurrent matches share one WebSocket MultiplayerAPI instance.")
					websocket_api_ids[websocket_api_id] = true
			if runtime.game_manager != null:
				var game_manager_id := int(runtime.game_manager.get_instance_id())
				if game_manager_ids.has(game_manager_id):
					failures.append("Concurrent matches share one GameManager instance.")
				game_manager_ids[game_manager_id] = true

	if failures.is_empty():
		print("shared_match_worker_smoke: PASS (2 bot matches active in one process)")
	else:
		for failure in failures:
			push_error("shared_match_worker_smoke: %s" % failure)

	await _cleanup(supervisor)
	quit(0 if failures.is_empty() else 1)

func _all_matches_started(supervisor) -> bool:
	if _match_ids.size() != MATCH_COUNT:
		return false
	for match_id in _match_ids:
		var runtime = supervisor._shared_bot_match_servers.get(match_id, null)
		if runtime == null or not is_instance_valid(runtime) or not runtime.has_started_match():
			return false
		var status := JsonStoreScript.load_dictionary(runtime.match_session.status_file_path, {}, "SharedMatchWorkerSmoke")
		if str(status.get("status", "")) != MatchSessionScript.STATUS_ACTIVE:
			return false
	return true

func _cleanup(supervisor) -> void:
	if supervisor != null:
		for match_id in _match_ids:
			supervisor.close_match(match_id, MatchSessionScript.STATUS_ABANDONED, true, "Shared worker smoke cleanup.")
		for match_id in _match_ids:
			var review_path := ServerPathsScript.get_bot_review_path(match_id)
			if FileAccess.file_exists(review_path):
				DirAccess.remove_absolute(review_path)
			if FileAccess.file_exists("%s.tmp" % review_path):
				DirAccess.remove_absolute("%s.tmp" % review_path)
	if _lobby != null and is_instance_valid(_lobby):
		_lobby.queue_free()
	await process_frame
