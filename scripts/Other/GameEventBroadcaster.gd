# GameEventBroadcaster.gd
extends RefCounted
class_name GameEventBroadcaster

## Server-side only. Connects to GameManager and MatchManager signals
## and pushes serialized game state to all connected clients after each action.
##
## Strategy: full-state sync after every move_validated + turn_started + game_ended.
## This is bandwidth-heavy but simple and correct. Event-by-event deltas can
## replace this later without touching the client or GameInput abstraction.

var game_manager: GameManager
var match_manager: MatchManager
var network_manager: Node  # NetworkManager

func _init(gm: GameManager, mm: MatchManager, nm: Node) -> void:
	game_manager = gm
	match_manager = mm
	network_manager = nm
	_connect_signals()

func _connect_signals() -> void:
	match_manager.move_validated.connect(_on_move_validated)
	match_manager.action_resolved.connect(_on_action_resolved)
	game_manager.turn_started.connect(_on_turn_started)
	game_manager.game_ended.connect(_on_game_ended)

# ---------------------------------------------------------------------------
# Signal handlers — each triggers a full broadcast
# ---------------------------------------------------------------------------

func _on_move_validated(move: Dictionary) -> void:
	var label := _label_for_move(move)
	_broadcast_full_state(label)

func _on_action_resolved(_action: CardAction) -> void:
	_broadcast_full_state("")

func _on_turn_started(turn_number: int, player: Player) -> void:
	var player_idx := game_manager.players.find(player)
	_broadcast_full_state("Turn %d — %s's turn." % [turn_number, player.player_name])
	# Also fire a dedicated turn_started event so clients can open upkeep window
	network_manager.broadcast_event_to_all("turn_started", {
		turn_number = turn_number,
		current_player_index = player_idx,
	})

func _on_game_ended(winner: Player, _loser: Player) -> void:
	var winner_idx := game_manager.players.find(winner)
	_broadcast_full_state(winner.player_name + " wins!")
	network_manager.broadcast_event_to_all("game_ended", {
		winner_index = winner_idx,
		winner_name  = winner.player_name,
	})

# ---------------------------------------------------------------------------
# Core broadcast logic
# ---------------------------------------------------------------------------

func _broadcast_full_state(action_message: String) -> void:
	if network_manager == null:
		return
	# Send personalized state to each player (hand privacy)
	for player_index in network_manager.player_peer_ids:
		var peer_id: int = network_manager.player_peer_ids[player_index]
		var state_data := GameState.serialize(game_manager, player_index)
		var event_data := {
			state = state_data,
			action_message = action_message,
		}
		if peer_id == 1:
			# Server's own "peer" — emit locally so the host UI updates too
			network_manager.game_event_received.emit("full_state", event_data)
		else:
			network_manager.broadcast_event_to_peer(peer_id, "full_state", event_data)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _label_for_move(move: Dictionary) -> String:
	match move.get("type", ""):
		"attack":
			return "Combat resolved."
		"play_card":
			var card := game_manager.get_card_by_uid(move.get("card_uid", ""))
			return ("Played %s." % card.card_name) if card else "Card played."
		"prepare_card":
			var card := game_manager.get_card_by_uid(move.get("card_uid", ""))
			return ("Prepared %s." % card.card_name) if card else "Card prepared."
		"creature_move":
			var card := game_manager.get_card_by_uid(move.get("card_uid", ""))
			return ("%s moved." % card.card_name) if card else "Creature moved."
		"change_mode":
			var card := game_manager.get_card_by_uid(move.get("card_uid", ""))
			return ("%s changed stance." % card.card_name) if card else "Stance changed."
		"end_turn":
			return "Turn ended."
	return ""
