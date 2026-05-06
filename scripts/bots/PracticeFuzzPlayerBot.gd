extends ThorPracticeBot
class_name PracticeFuzzPlayerBot

func attach(
	p_game_manager: GameManager,
	p_match_manager: MatchManager,
	p_game_input: GameInput,
	p_player_index: int
) -> void:
	super.attach(p_game_manager, p_match_manager, p_game_input, p_player_index)
	if match_manager != null and not match_manager.move_failed.is_connected(_on_match_move_failed):
		match_manager.move_failed.connect(_on_match_move_failed)
	if game_input != null and game_input.has_signal("submission_rejected"):
		var rejection_callback := Callable(self, "_on_submission_rejected")
		if not game_input.submission_rejected.is_connected(rejection_callback):
			game_input.submission_rejected.connect(rejection_callback)

func detach() -> void:
	if match_manager != null and match_manager.move_failed.is_connected(_on_match_move_failed):
		match_manager.move_failed.disconnect(_on_match_move_failed)
	if game_input != null and game_input.has_signal("submission_rejected"):
		var rejection_callback := Callable(self, "_on_submission_rejected")
		if game_input.submission_rejected.is_connected(rejection_callback):
			game_input.submission_rejected.disconnect(rejection_callback)
	super.detach()

func _on_match_ui_interaction(prompt_player_index: int, type: String, data: Dictionary) -> void:
	if prompt_player_index != player_index:
		return
	match type:
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
	_queue_retry_poll()

func _on_submission_rejected(_reason: String) -> void:
	_queue_retry_poll()

func _submit_first_target_choice(command_type: String, data: Dictionary) -> void:
	_submit_action({
		"type": command_type,
		"source_uid": str(data.get("source_uid", "")),
		"target_uid": _first_uid_from_prompt(data, "target_uids"),
	})

func _first_uid_from_prompt(data: Dictionary, key: String) -> String:
	for raw_uid in data.get(key, []):
		var uid := str(raw_uid).strip_edges()
		if not uid.is_empty():
			return uid
	return ""
