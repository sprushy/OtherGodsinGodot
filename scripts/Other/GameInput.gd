# GameInput.gd
extends RefCounted
class_name GameInput

## Abstract base class for submitting player actions into the game.
##
## Swap LocalGameInput for NetworkedGameInput to route actions over the network.
## The command dict format mirrors MatchManager.process_command().

func submit_action(_command: Dictionary) -> bool:
	push_error("GameInput.submit_action() must be overridden by a subclass")
	return false
