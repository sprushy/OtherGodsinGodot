# NetworkedGameInput.gd
extends GameInput
class_name NetworkedGameInput

## Client-side GameInput implementation.
## Sends every player action to the server via NetworkManager.request_action().
## The server validates, executes, and broadcasts the resulting state back.
##
## Returns true optimistically (the server may still reject the command,
## in which case the next full_state broadcast will correct the UI).

var network_manager: Node  # NetworkManager

func _init(nm: Node) -> void:
	network_manager = nm

func submit_action(command: Dictionary) -> bool:
	if network_manager == null:
		push_error("NetworkedGameInput: no network_manager set")
		return false
	network_manager.request_action(command)
	return true
