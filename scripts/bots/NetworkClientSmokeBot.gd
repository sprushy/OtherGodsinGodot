extends RefCounted
class_name NetworkClientSmokeBot

# Drives the non-authoritative client side of a two-process smoke match.
#
# Unlike ThorPracticeBot (which assumes an authoritative MatchManager that emits
# request_ui_interaction), this bot runs on a remote client where prompts arrive
# ONLY via match_client.game_event_received. It:
#   - submits commands through the client's real game_input (a NetworkedGameInput,
#     so commands travel over ENet to the authoritative host), and
#   - answers hunting_tactics / intercept / priority prompts from incoming events.
#
# Main-phase behaviour is intentionally minimal: as player 2 it mostly draws on
# upkeep and ends its turn so the host (player 1) can mount the Hunting Tactics
# attack. It never needs to assemble its own attack.

var game_manager: GameManager = null
var match_manager: MatchManager = null
var match_client = null
var game_input: GameInput = null
var network_manager: Node = null
var player_index: int = -1
var bot_player: Player = null

const STEP_DELAY_SECONDS := 0.4
const RETRY_DELAY_SECONDS := 0.2

var _active: bool = false
var _step_queued: bool = false
var _retry_queued: bool = false

func attach(
	p_game_manager: GameManager,
	p_match_manager: MatchManager,
	p_match_client,
	p_player_index: int
) -> void:
	detach()
	game_manager = p_game_manager
	match_manager = p_match_manager
	match_client = p_match_client
	player_index = p_player_index
	if game_manager != null and player_index >= 0 and player_index < game_manager.players.size():
		bot_player = game_manager.players[player_index]
	if match_client != null:
		game_input = match_client.get_game_input()
		network_manager = match_client.network_manager
		if network_manager == null and match_manager != null:
			network_manager = match_manager.network_manager
	_active = bot_player != null and game_input != null
	_connect_signals()
	_queue_step()

func detach() -> void:
	_disconnect_signals()
	game_manager = null
	match_manager = null
	match_client = null
	game_input = null
	network_manager = null
	player_index = -1
	bot_player = null
	_active = false
	_step_queued = false
	_retry_queued = false

func _connect_signals() -> void:
	if match_manager != null:
		_connect_if_needed(match_manager.move_validated, _on_match_progressed)
		_connect_if_needed(match_manager.action_resolved, _on_match_progressed)
		_connect_if_needed(match_manager.move_failed, _on_match_failed)
		_connect_if_needed(match_manager.ui_refresh_requested, _on_match_progressed)
	if game_manager != null:
		_connect_if_needed(game_manager.turn_started, _on_turn_started)
		_connect_if_needed(game_manager.game_ended, _on_game_ended)
	if match_client != null and match_client.has_signal("game_event_received"):
		_connect_if_needed(match_client.game_event_received, _on_game_event)

func _disconnect_signals() -> void:
	if match_manager != null:
		_disconnect_if_needed(match_manager.move_validated, _on_match_progressed)
		_disconnect_if_needed(match_manager.action_resolved, _on_match_progressed)
		_disconnect_if_needed(match_manager.move_failed, _on_match_failed)
		_disconnect_if_needed(match_manager.ui_refresh_requested, _on_match_progressed)
	if game_manager != null:
		_disconnect_if_needed(game_manager.turn_started, _on_turn_started)
		_disconnect_if_needed(game_manager.game_ended, _on_game_ended)
	if match_client != null and match_client.has_signal("game_event_received"):
		_disconnect_if_needed(match_client.game_event_received, _on_game_event)

func _connect_if_needed(signal_ref: Signal, method: Callable) -> void:
	if not signal_ref.is_connected(method):
		signal_ref.connect(method)

func _disconnect_if_needed(signal_ref: Signal, method: Callable) -> void:
	if signal_ref.is_connected(method):
		signal_ref.disconnect(method)

func _on_turn_started(_turn_number: int, player: Player) -> void:
	if player == bot_player:
		_queue_step()

func _on_match_progressed(_value = null) -> void:
	_queue_step()

func _on_match_failed(_reason: String) -> void:
	_queue_retry()

func _on_game_ended(_winner: Player, _loser: Player) -> void:
	_active = false
	_step_queued = false

func _on_game_event(event_type: String, data: Dictionary) -> void:
	if not _active:
		return
	if event_type != "ui_interaction":
		return
	var type: String = data.get("type", "")
	var payload: Dictionary = data.get("data", {})
	var prompt_player_index := int(data.get("player_index", player_index))
	if prompt_player_index != player_index:
		return
	match type:
		"hunting_tactics":
			_answer_hunting_tactics(payload)
		"intercept":
			_submit_action({"type": "intercept_decision", "interceptor_uid": ""})
		"priority":
			_queue_retry()
		_:
			_queue_step()

func _answer_hunting_tactics(payload: Dictionary) -> void:
	var source_uid := str(payload.get("source_uid", "")).strip_edges()
	var attacker_uid := str(payload.get("attacker_uid", "")).strip_edges()
	var chosen_uids: Array[String] = []
	for raw_uid in payload.get("target_uids", []):
		var uid := str(raw_uid).strip_edges()
		if not uid.is_empty():
			chosen_uids.append(uid)
			break
	_submit_action({
		"type": "hunting_tactics_choice",
		"source_uid": source_uid,
		"attacker_uid": attacker_uid,
		"chosen_uids": chosen_uids,
	})

func _queue_step() -> void:
	if _step_queued or not _should_act():
		return
	_step_queued = true
	var tree := _get_tree()
	if tree == null:
		call_deferred("_run_step")
		return
	tree.create_timer(STEP_DELAY_SECONDS).timeout.connect(_run_step, CONNECT_ONE_SHOT)

func _queue_retry() -> void:
	if _retry_queued:
		return
	_retry_queued = true
	var tree := _get_tree()
	if tree == null:
		call_deferred("_run_retry")
		return
	tree.create_timer(RETRY_DELAY_SECONDS).timeout.connect(_run_retry, CONNECT_ONE_SHOT)

func _run_retry() -> void:
	_retry_queued = false
	_queue_step()

func _run_step() -> void:
	_step_queued = false
	if not _should_act():
		return
	if game_manager.action_stack != null and not game_manager.action_stack.is_empty():
		# Priority is answered via the priority ui_interaction event; nothing to do here.
		return
	if game_manager.current_player != bot_player:
		return
	if not game_manager.has_resolved_turn_upkeep():
		_submit_action({"type": "upkeep_choice", "choice": "draw"})
		return
	# Minimal main phase: end the turn so the host can act. (Player 2 cooperates.)
	_submit_action({"type": "end_turn", "discard_uids": []})

func _should_act() -> bool:
	if not _active or game_manager == null or game_input == null or bot_player == null:
		return false
	if game_manager.is_game_over:
		return false
	if match_manager != null and match_manager.selected_attacker != null:
		return false
	return true

func _get_tree() -> SceneTree:
	if network_manager != null:
		return network_manager.get_tree()
	return Engine.get_main_loop() as SceneTree

func _submit_action(command: Dictionary) -> bool:
	if game_input == null:
		return false
	return game_input.submit_action(command)
