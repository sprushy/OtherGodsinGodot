extends ThorPracticeBot
class_name PracticeFuzzPlayerBot

var match_client = null
var _awaiting_network_state_after_submit: bool = false
var _answered_prompt_ids: Dictionary = {}

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
	_on_match_ui_interaction(prompt_player_index, type, _normalize_network_prompt_payload(type, payload))

func _normalize_network_prompt_payload(type: String, payload: Dictionary) -> Dictionary:
	var normalized := payload.duplicate(true)
	match type:
		"combat_retreat":
			var action_data = normalized.get("action", {})
			if action_data is Dictionary:
				var action_dictionary := action_data as Dictionary
				normalized["action"] = CardAction.from_dict(action_dictionary, game_manager)
			var target = null
			var target_uid := str(normalized.get("target_uid", "")).strip_edges()
			if not target_uid.is_empty() and game_manager != null:
				target = game_manager.get_card_by_uid(target_uid)
			if target == null and game_manager != null:
				var target_player_index := int(normalized.get("target_player_index", -1))
				if target_player_index >= 0 and target_player_index < game_manager.players.size():
					target = game_manager.players[target_player_index]
			if target != null:
				normalized["target"] = target
	return normalized

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
			_submit_priority_pass_from_prompt(data)
		"wheel_of_fire_turn_start":
			_submit_action({
				"type": "wheel_of_fire_turn_start_choice",
				"source_uid": str(data.get("source_uid", "")),
				"pay_cost": false,
			})
		"first_sage_adapa_impact":
			_submit_first_target_choice("first_sage_adapa_choice", data)
		"third_sage_enmedugga_impact":
			_submit_first_target_choice("third_sage_enmedugga_choice", data)
		"fourth_sage_enmegalamma_impact":
			_submit_first_target_choice("fourth_sage_enmegalamma_choice", data)
		"sixth_sage_an_enlilda_impact":
			_submit_first_target_choice("sixth_sage_an_enlilda_choice", data)
		"hunting_tactics":
			_submit_hunting_tactics_choice(data)
		"huginn_perish_prime":
			_submit_first_target_choice("huginn_perish_prime_choice", data)
		"muninn_perish_prime":
			_submit_first_target_choice("muninn_perish_prime_choice", data)
		"return_to_hand_choice":
			_submit_action({
				"type": "return_to_hand_choice",
				"source_uid": str(data.get("source_uid", "")),
				"target_uid": _first_uid_from_prompt(data, "target_uids"),
			})
		_:
			super._on_match_ui_interaction(prompt_player_index, type, data)

func _try_attack() -> bool:
	if game_manager != null and game_manager.current_player == bot_player and game_manager.turn_number <= 1:
		return false
	return super._try_attack()

func _on_match_move_failed(_reason: String) -> void:
	_awaiting_network_state_after_submit = false
	_queue_retry_poll()

func _on_submission_rejected(_reason: String) -> void:
	_awaiting_network_state_after_submit = false
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

func _mark_prompt_answered(data: Dictionary) -> bool:
	var prompt_id := int(data.get("_prompt_id", -1))
	if prompt_id < 0:
		return true
	var key := str(prompt_id)
	if _answered_prompt_ids.has(key):
		return false
	_answered_prompt_ids[key] = true
	return true

func _submit_priority_pass_from_prompt(data: Dictionary) -> void:
	if game_manager != null:
		if game_manager.action_stack.is_empty():
			return
		if bot_player != null and game_manager.priority_player != bot_player:
			return
	if not _mark_prompt_answered(data):
		return
	_submit_action({"type": "priority_pass"})

func _submit_first_target_choice(command_type: String, data: Dictionary) -> void:
	if not _mark_prompt_answered(data):
		return
	_submit_action({
		"type": command_type,
		"source_uid": str(data.get("source_uid", "")),
		"target_uid": _first_uid_from_prompt(data, "target_uids"),
	})

func _submit_hunting_tactics_choice(data: Dictionary) -> void:
	if not _mark_prompt_answered(data):
		return
	var source_uid := str(data.get("source_uid", "")).strip_edges()
	var attacker_uid := str(data.get("attacker_uid", "")).strip_edges()
	var chosen_uids: Array[String] = []
	for raw_uid in data.get("target_uids", []):
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

func _first_uid_from_prompt(data: Dictionary, key: String) -> String:
	for raw_uid in data.get(key, []):
		var uid := str(raw_uid).strip_edges()
		if not uid.is_empty():
			return uid
	return ""
