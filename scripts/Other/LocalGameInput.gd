# LocalGameInput.gd
extends GameInput
class_name LocalGameInput

## Local (same-machine) implementation of GameInput.
## Routes actions directly to MatchManager.process_command().
## Replace with NetworkedGameInput to send actions to a remote server instead.

var match_manager: MatchManager

func _init(p_match_manager: MatchManager) -> void:
	match_manager = p_match_manager

func submit_action(command: Dictionary) -> bool:
	return match_manager.process_command(command)
