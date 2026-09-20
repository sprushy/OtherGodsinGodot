extends GameInput
class_name InProcessGameInput

## Same-process command transport for an authoritative MatchManager.

var match_manager: MatchManager

func _init(p_match_manager: MatchManager) -> void:
	match_manager = p_match_manager

func submit_action(command: Dictionary) -> bool:
	return match_manager.process_command(command)
