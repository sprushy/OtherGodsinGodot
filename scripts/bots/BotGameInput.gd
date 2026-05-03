extends GameInput
class_name BotGameInput

var match_manager: MatchManager = null
var player_index: int = -1

func _init(p_match_manager: MatchManager, p_player_index: int) -> void:
	match_manager = p_match_manager
	player_index = p_player_index

func submit_action(command: Dictionary) -> bool:
	if match_manager == null:
		return _reject_submission("No match manager is available for the bot.")
	if player_index < 0:
		return _reject_submission("The bot does not have a player seat.")
	return match_manager.process_command(command, {
		"player_index": player_index,
		"peer_id": 0,
		"is_bot": true,
	})

func _reject_submission(reason: String) -> bool:
	push_warning("BotGameInput: %s" % reason)
	submission_rejected.emit(reason)
	return false
