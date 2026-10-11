extends RefCounted
class_name NetworkClientSmokeBot

# Drives the network client side of a two-process smoke match.
#
# Unlike ThorPracticeBot (which assumes an authoritative MatchManager that emits
# request_ui_interaction), this bot runs on a remote client where prompts arrive
# ONLY via match_client.game_event_received. It:
#   - submits commands through the client's real game_input (a NetworkedGameInput,
#     so commands travel over ENet to the authoritative host), and
#   - answers card decisions / intercept / priority prompts from incoming events.
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
var _answered_prompt_ids: Dictionary = {}
var _last_answered_prompt_id: int = -1

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
	_answered_prompt_ids.clear()
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
	_answered_prompt_ids.clear()
	_last_answered_prompt_id = -1
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
	_answered_prompt_ids.erase(str(_last_answered_prompt_id))
	_queue_retry()

func _on_game_ended(_winner: Player, _loser: Player) -> void:
	_active = false
	_step_queued = false

func _on_game_event(event_type: String, data: Dictionary) -> void:
	if not _active:
		return
	if event_type == "command_rejected":
		_answered_prompt_ids.erase(str(_last_answered_prompt_id))
		_queue_retry()
		return
	if event_type == "full_state":
		if game_manager != null and player_index >= 0 and player_index < game_manager.players.size():
			bot_player = game_manager.players[player_index]
		_queue_step()
		return
	if event_type != "ui_interaction":
		return
	var type: String = data.get("type", "")
	var payload: Dictionary = data.get("data", {})
	var prompt_player_index := int(data.get("player_index", player_index))
	if prompt_player_index != player_index:
		return
	match type:
		"intercept":
			if _mark_prompt_answered(payload):
				_submit_action({"type": "intercept_decision", "interceptor_uid": "", "_prompt_id": int(payload.get("_prompt_id", -1))})
		"priority":
			_answer_priority(payload)
		_:
			_answer_card_prompt(type, payload)

func _answer_card_prompt(type: String, payload: Dictionary) -> void:
	if game_manager == null or bot_player == null or not _mark_prompt_answered(payload):
		return
	# Share card decisions while keeping this smoke bot's minimal turn loop.
	var decision_bot := ThorPracticeBot.new()
	decision_bot.game_manager = game_manager
	decision_bot.match_manager = match_manager
	decision_bot.player_index = player_index
	decision_bot.bot_player = bot_player
	decision_bot.opponent = game_manager.get_opponent(bot_player)
	decision_bot.game_input = game_input
	decision_bot._on_match_ui_interaction(player_index, type, payload)
	var prompt_key := str(payload.get("_prompt_id", -1))
	if not decision_bot._answered_prompt_ids.has(prompt_key):
		_answered_prompt_ids.erase(prompt_key)

func _answer_priority(payload: Dictionary) -> void:
	if game_manager != null:
		if game_manager.action_stack.is_empty():
			return
		if bot_player != null and game_manager.priority_player != bot_player:
			return
	if not _mark_prompt_answered(payload):
		return
	_submit_action({"type": "priority_pass", "_prompt_id": int(payload.get("_prompt_id", -1))})

func _mark_prompt_answered(payload: Dictionary) -> bool:
	var prompt_id := int(payload.get("_prompt_id", -1))
	if prompt_id < 0:
		return true
	var key := str(prompt_id)
	if _answered_prompt_ids.has(key):
		return false
	_answered_prompt_ids[key] = true
	_last_answered_prompt_id = prompt_id
	return true

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
	var submitted := game_input.submit_action(command)
	if not submitted:
		_answered_prompt_ids.erase(str(command.get("_prompt_id", -1)))
	return submitted
