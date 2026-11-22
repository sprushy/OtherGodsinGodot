extends BotGameInput
class_name ServerBotGameInput

var match_session = null

func _init(p_match_manager: MatchManager, p_player_index: int, p_match_session = null) -> void:
	super._init(p_match_manager, p_player_index)
	match_session = p_match_session

func submit_action(command: Dictionary) -> bool:
	if match_session != null \
			and match_session.has_method("is_waiting_for_reconnect") \
			and match_session.is_waiting_for_reconnect():
		return false
	return super.submit_action(command)
