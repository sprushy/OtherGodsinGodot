extends ThorPracticeBot
class_name PracticeFuzzPlayerBot

var match_client = null
var _awaiting_network_state_after_submit: bool = false

func attach(
	p_game_manager: GameManager,
	p_match_manager: MatchManager,
	p_game_input: GameInput,
	p_player_index: int
) -> void:
	super.attach(p_game_manager, p_match_manager, p_game_input, p_player_index)
	match_client = null
	_awaiting_network_state_after_submit = false
	_answered_prompt_ids.clear()
	if match_manager != null and not match_manager.move_failed.is_connected(_on_match_move_failed):
		match_manager.move_failed.connect(_on_match_move_failed)
	if game_input != null and game_input.has_signal("submission_rejected"):
		var rejection_callback := Callable(self, "_on_submission_rejected")
		if not game_input.submission_rejected.is_connected(rejection_callback):
			game_input.submission_rejected.connect(rejection_callback)

func attach_networked(
	p_game_manager: GameManager,
	p_match_manager: MatchManager,
	p_game_input: GameInput,
	p_player_index: int,
	p_match_client
) -> void:
	attach(p_game_manager, p_match_manager, p_game_input, p_player_index)
	match_client = p_match_client
	_awaiting_network_state_after_submit = false
	_answered_prompt_ids.clear()
	if match_client != null and match_client.has_signal("game_event_received"):
		if not match_client.game_event_received.is_connected(_on_network_game_event):
			match_client.game_event_received.connect(_on_network_game_event)
	_queue_retry_poll()

func detach() -> void:
	if match_client != null and is_instance_valid(match_client) \
			and match_client.has_signal("game_event_received") \
			and match_client.game_event_received.is_connected(_on_network_game_event):
		match_client.game_event_received.disconnect(_on_network_game_event)
	match_client = null
	_awaiting_network_state_after_submit = false
	_answered_prompt_ids.clear()
	if match_manager != null and match_manager.move_failed.is_connected(_on_match_move_failed):
		match_manager.move_failed.disconnect(_on_match_move_failed)
	if game_input != null and game_input.has_signal("submission_rejected"):
		var rejection_callback := Callable(self, "_on_submission_rejected")
		if game_input.submission_rejected.is_connected(rejection_callback):
			game_input.submission_rejected.disconnect(rejection_callback)
	super.detach()

func _on_network_game_event(event_type: String, data: Dictionary) -> void:
	match event_type:
		"full_state":
			_awaiting_network_state_after_submit = false
			_refresh_network_player_refs()
			poll()
		"ui_interaction":
			_awaiting_network_state_after_submit = false
			_handle_network_ui_interaction(data)
		"turn_started", "match_join_ok", "match_reconnect_ok", "series_game_started":
			_awaiting_network_state_after_submit = false
			_refresh_network_player_refs()
			poll()
		"command_rejected":
			_awaiting_network_state_after_submit = false
			_forget_rejected_prompt()
			_queue_retry_poll()
		"server_disconnected", "match_reconnect_started":
			_awaiting_network_state_after_submit = false

func _refresh_network_player_refs() -> void:
	if game_manager == null or player_index < 0 or player_index >= game_manager.players.size():
		return
	bot_player = game_manager.players[player_index]
	opponent = game_manager.get_opponent(bot_player)
	_active = bot_player != null

func _handle_network_ui_interaction(event_data: Dictionary) -> void:
	var prompt_player_index := int(event_data.get("player_index", player_index))
	if prompt_player_index != player_index:
		return
	var type := str(event_data.get("type", ""))
	var payload: Dictionary = {}
	var raw_payload = event_data.get("data", {})
	if raw_payload is Dictionary:
		payload = (raw_payload as Dictionary).duplicate(true)
	_on_match_ui_interaction(prompt_player_index, type, payload)

func _should_queue_step() -> bool:
	if _awaiting_network_state_after_submit:
		return false
	if _is_networked_bot_client() and game_manager != null and not game_manager.action_stack.is_empty():
		return false
	return super._should_queue_step()

func _should_retry_poll_later() -> bool:
	if _awaiting_network_state_after_submit:
		return false
	if _is_networked_bot_client() and game_manager != null and not game_manager.action_stack.is_empty():
		return false
	return super._should_retry_poll_later()

func _on_match_ui_interaction(prompt_player_index: int, type: String, data: Dictionary) -> void:
	if prompt_player_index != player_index:
		return
	match type:
		"priority":
			_submit_priority_response_from_prompt(data)
		_:
			super._on_match_ui_interaction(prompt_player_index, type, data)

func _try_attack() -> bool:
	if game_manager != null and game_manager.current_player == bot_player and game_manager.turn_number <= 1:
		return false
	return super._try_attack()

func _on_match_move_failed(_reason: String) -> void:
	_awaiting_network_state_after_submit = false
	_forget_rejected_prompt()
	_queue_retry_poll()

func _on_submission_rejected(_reason: String) -> void:
	_awaiting_network_state_after_submit = false
	_forget_rejected_prompt()
	_queue_retry_poll()

func _submit_action(command: Dictionary) -> bool:
	var submitted := super._submit_action(command)
	if submitted and _is_networked_bot_client():
		_awaiting_network_state_after_submit = true
	return submitted

func _is_networked_bot_client() -> bool:
	if match_client == null or not match_client.has_method("is_networked_client"):
		return false
	return bool(match_client.call("is_networked_client"))

func _submit_priority_response_from_prompt(data: Dictionary) -> void:
	if game_manager != null:
		if game_manager.action_stack.is_empty():
			return
		if bot_player != null and game_manager.priority_player != bot_player:
			return
	if not _mark_prompt_answered(data):
		return
	var previous_prompt_id := _current_card_prompt_id
	_current_card_prompt_id = int(data.get("_prompt_id", -1))
	_handle_priority()
	_current_card_prompt_id = previous_prompt_id
