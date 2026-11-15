extends SceneTree

const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const HeadlessMatchHostScript = preload("res://scripts/server/HeadlessMatchHost.gd")
const MatchClientScript = preload("res://scripts/client/MatchClient.gd")

const MATCH_COUNT := 2
const TEST_TIMEOUT_MSEC := 45_000

var _lobby = null
var _match_ids: Array[String] = []

class VolunteerMenu extends "res://scripts/Other/MainMenu.gd":
	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _get_local_bot_match_capacity() -> int:
		return MATCH_COUNT

class VolunteerLobbyClient extends LobbyClient:
	var started: Array[String] = []
	var submitted: Array[Dictionary] = []
	var cancelled: Array[String] = []

	func _ready() -> void:
		pass

	func is_authenticated() -> bool:
		return true

	func request_bot_work(_bot_id: String = "", _excluded_list_ids: Array = []) -> void:
		pass

	func report_bot_work_started(job_id: String) -> void:
		started.append(job_id)

	func submit_bot_work_result(job_id: String, winner_index: int, turns: int) -> void:
		submitted.append({"job_id": job_id, "winner_index": winner_index, "turns": turns})

	func cancel_bot_work(job_id: String) -> void:
		cancelled.append(job_id)

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

	var volunteer_decks: Array[Dictionary] = []
	if failures.is_empty():
		var session = supervisor.get_match(_match_ids[0])
		for player_id in session.player_session_ids:
			volunteer_decks.append(session.player_decks_by_session[player_id])
	await _cleanup(supervisor)
	if failures.is_empty():
		await _check_volunteer_matches(volunteer_decks, failures)
	if failures.is_empty():
		print("shared_match_worker_smoke: PASS (lobby and volunteer matches share a process, and a volunteer match advanced after another finished)")
	else:
		for failure in failures:
			push_error("shared_match_worker_smoke: %s" % failure)
	quit(0 if failures.is_empty() else 1)

func _check_volunteer_matches(decks: Array[Dictionary], failures: PackedStringArray) -> void:
	var scene := preload("res://scenes/mainfork.tscn").instantiate()
	var menu := scene.get_node("Control")
	menu.set_script(VolunteerMenu)
	for game in menu.get_node("GameContainer").get_children():
		game.free()
	var lobby_client := VolunteerLobbyClient.new()
	menu.add_child(lobby_client)
	menu.lobby_client = lobby_client
	get_root().add_child(scene)
	_match_ids.assign(["volunteer_smoke_%d_a" % OS.get_process_id(), "volunteer_smoke_%d_b" % OS.get_process_id()])
	for match_id in _match_ids:
		menu._request_local_bot_match(false)
		lobby_client.bot_work_assignment_received.emit({"job_id": match_id, "decks": decks})
	var supervisor = menu._local_bot_match_supervisor
	var deadline := Time.get_ticks_msec() + TEST_TIMEOUT_MSEC
	if lobby_client.started != _match_ids or supervisor == null or supervisor.active_matches.size() != MATCH_COUNT:
		failures.append("Volunteer assignments did not start both matches under one supervisor.")
	else:
		while not _all_matches_started(supervisor) and Time.get_ticks_msec() < deadline:
			await create_timer(0.1).timeout
		if _all_matches_started(supervisor):
			await _check_volunteer_completion(menu, lobby_client, failures)
		else:
			failures.append("Both volunteer matches did not become active before timeout.")
	menu._stop_local_bot_match_worker()
	if not lobby_client.cancelled.has(_match_ids[1]) or menu._get_local_bot_match_count() != 0:
		failures.append("Stopping volunteer hosting did not cancel the remaining match.")
	scene.queue_free()
	await process_frame
	_remove_bot_reviews()

func _check_volunteer_completion(menu, lobby_client: VolunteerLobbyClient, failures: PackedStringArray) -> void:
	var supervisor = menu._local_bot_match_supervisor
	var finished_id := _match_ids[0]
	var survivor_id := _match_ids[1]
	var finishing = supervisor._shared_bot_match_servers[finished_id]
	var survivor = supervisor._shared_bot_match_servers[survivor_id]
	var heartbeat_path: String = survivor.match_session.supervisor_heartbeat_path
	if heartbeat_path.is_empty() or finishing.match_session.supervisor_heartbeat_path != heartbeat_path:
		failures.append("Volunteer matches did not use their shared supervisor heartbeat.")
	var session: MatchSession = supervisor.get_match(finished_id)
	var match_info := session.to_spectator_match_info("local_volunteer_host")
	var host := HeadlessMatchHostScript.new()
	var transport := host.setup_transport(menu, false, true, session.server_ip, session.match_port, true, match_info)
	var spectator := MatchClientScript.new(null, transport, true, true, match_info, session.server_ip, session.match_port)
	var events: Array[String] = []
	spectator.game_event_received.connect(func(event: String, _data: Dictionary) -> void: events.append(event))
	var join_deadline := Time.get_ticks_msec() + 5_000
	while not events.has("full_state") and Time.get_ticks_msec() < join_deadline:
		await create_timer(0.1).timeout
	if not events.has("match_join_ok") or not events.has("full_state"):
		failures.append("A local spectator did not receive the shared match state.")
	finishing.game_manager.forfeit_game(finishing.game_manager.players[1])
	var deadline := Time.get_ticks_msec() + TEST_TIMEOUT_MSEC
	while lobby_client.submitted.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not events.has("series_ended"):
		failures.append("The shared match closed before delivering the spectator recap.")
	spectator.shutdown()
	if is_instance_valid(transport):
		transport.queue_free()
	if lobby_client.submitted.size() != 1 or lobby_client.submitted[0].get("job_id") != finished_id \
			or lobby_client.submitted[0].get("winner_index") != 0:
		failures.append("Volunteer hosting did not report the finished match's result exactly once.")
		return
	if is_instance_valid(finishing) or supervisor.get_match(finished_id) != null or menu._get_local_bot_match_count() != 1:
		failures.append("Volunteer hosting did not clean up just the finished match.")
	if not is_instance_valid(survivor) or not FileAccess.file_exists(heartbeat_path):
		failures.append("Finishing one volunteer match stopped the other or removed its heartbeat.")
		return
	var turn_after_completion: int = survivor.game_manager.turn_number
	while is_instance_valid(survivor) and survivor.game_manager.turn_number <= turn_after_completion \
			and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not is_instance_valid(survivor) or survivor.game_manager.turn_number <= turn_after_completion:
		failures.append("The surviving volunteer match did not advance after the first finished.")

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
	_remove_bot_reviews()
	if _lobby != null and is_instance_valid(_lobby):
		_lobby.queue_free()
	await process_frame

func _remove_bot_reviews() -> void:
	for match_id in _match_ids:
		var review_path := ServerPathsScript.get_bot_review_path(match_id)
		for path in [review_path, "%s.tmp" % review_path, "%s.bak" % review_path]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
