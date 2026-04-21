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

func _is_transport_connected() -> bool:
	if network_manager == null:
		return false
	var multiplayer_api = network_manager.multiplayer
	if multiplayer_api == null:
		return false
	var multiplayer_peer = multiplayer_api.multiplayer_peer
	if multiplayer_peer == null:
		return false
	return multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func submit_action(command: Dictionary) -> bool:
	if network_manager == null:
		push_error("NetworkedGameInput: no network_manager set")
		return false
	if not _is_transport_connected():
		push_warning("NetworkedGameInput: cannot send %s while disconnected" % str(command.get("type", command)))
		return false
	network_manager.request_action(command)
	return true
