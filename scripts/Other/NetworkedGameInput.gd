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

func _has_player_assignment() -> bool:
	if network_manager == null:
		return false
	return int(network_manager.local_player_index) >= 0

func _reject_submission(reason: String) -> bool:
	push_warning("NetworkedGameInput: %s" % reason)
	submission_rejected.emit(reason)
	return false

func submit_action(command: Dictionary) -> bool:
	if network_manager == null:
		return _reject_submission("No match connection is available.")
	if not _is_transport_connected():
		return _reject_submission("Disconnected from match server. Reconnect may still be available.")
	if not _has_player_assignment():
		return _reject_submission("Reconnecting to match server. Please wait for match authentication.")
	if network_manager.has_method("get_command_payload_rejection_reason"):
		var rejection_reason := str(network_manager.get_command_payload_rejection_reason(command))
		if not rejection_reason.is_empty():
			return _reject_submission(rejection_reason)
	network_manager.request_action(command)
	return true
