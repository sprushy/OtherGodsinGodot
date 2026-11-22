# GameInput.gd
extends RefCounted
class_name GameInput

## Abstract base class for submitting player actions into the game.
##
## InProcessGameInput and NetworkedGameInput both submit to MatchManager.process_command().
## The command dict format mirrors MatchManager.process_command().

@warning_ignore("unused_signal")
signal submission_rejected(reason: String)

func submit_action(_command: Dictionary) -> bool:
	push_error("GameInput.submit_action() must be overridden by a subclass")
	return false
