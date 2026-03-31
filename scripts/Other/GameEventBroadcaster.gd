# GameEventBroadcaster.gd
extends RefCounted
class_name GameEventBroadcaster

## Server-side only. Connects to GameManager and MatchManager signals
## and pushes serialized game state to all connected clients after each action.
##
## Strategy: full-state sync after every move_validated + turn_started + game_ended.
## This is bandwidth-heavy but simple and correct. Event-by-event deltas can
## replace this later without touching the client or GameInput abstraction.

const PromptRouterScript = preload("res://scripts/server/PromptRouter.gd")

var game_manager: GameManager
var match_manager: MatchManager
var network_manager: Node  # NetworkManager
var prompt_router = null

func _init(gm: GameManager, mm: MatchManager, nm: Node, p_prompt_router = null) -> void:
	game_manager = gm
	match_manager = mm
	network_manager = nm
	prompt_router = p_prompt_router if p_prompt_router != null else PromptRouterScript.new(game_manager)
	_connect_signals()

func _connect_signals() -> void:
	match_manager.move_validated.connect(_on_move_validated)
	match_manager.action_resolved.connect(_on_action_resolved)
	game_manager.turn_upkeep_started.connect(_on_turn_upkeep_started)
	game_manager.turn_started.connect(_on_turn_started)
	game_manager.game_ended.connect(_on_game_ended)
	match_manager.request_ui_interaction.connect(_on_ui_interaction_requested)
	game_manager.doorway_choice_requested.connect(_on_doorway_choice_requested)

# ---------------------------------------------------------------------------
# Signal handlers — each triggers a full broadcast
# ---------------------------------------------------------------------------

func _on_move_validated(move: Dictionary) -> void:
	# "end_turn" already triggers _on_turn_started which broadcasts full_state;
	# broadcasting again here would send it twice per turn change.
	if move.get("type", "") == "end_turn":
		return
	var label := _label_for_move(move)
	_broadcast_full_state(label)

func _on_action_resolved(_action: CardAction) -> void:
	_broadcast_full_state("")

func _on_turn_upkeep_started(_turn_number: int, player: Player) -> void:
	if network_manager == null:
		return
	var player_idx := game_manager.players.find(player)
	_broadcast_full_state("Turn %d — %s's turn." % [game_manager.turn_number, player.player_name])
	var peer_id: int = network_manager.player_peer_ids.get(player_idx, -1)
	if peer_id != 1 and peer_id != -1:
		network_manager.broadcast_event_to_peer(peer_id, "upkeep_needed", {
			current_player_index = player_idx,
		})

func _on_turn_started(turn_number: int, player: Player) -> void:
	var player_idx := game_manager.players.find(player)
	_broadcast_full_state("Turn %d — %s's turn." % [turn_number, player.player_name])
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

func _on_ui_interaction_requested(player_index: int, type: String, data: Dictionary) -> void:
	var serialized_data: Dictionary = prompt_router.serialize_prompt_data(data)
	_broadcast_ui_interaction(player_index, type, serialized_data)

func _on_doorway_choice_requested(structure: Card, card: Card, combat_death: bool, destruction: bool) -> void:
	var player := structure.card_owner if structure != null else game_manager.current_player
	var player_idx := game_manager.players.find(player)
	var data := {
		"structure_uid": structure.uid if structure != null else "",
		"card_uid": card.uid if card != null else "",
		"combat_death": combat_death,
		"destruction": destruction
	}
	_broadcast_ui_interaction(player_idx, "doorway_choice", data)

func _broadcast_ui_interaction(player_index: int, type: String, data: Dictionary) -> void:
	if network_manager == null:
		return
	var peer_id: int = network_manager.player_peer_ids.get(player_index, -1)
	var envelope: Dictionary = prompt_router.build_prompt_envelope(player_index, type, data)
	if peer_id == 1:
		# Server's own "peer" — emit locally so the host UI updates too
		network_manager.game_event_received.emit("ui_interaction", envelope)
	elif peer_id != -1:
		network_manager.broadcast_event_to_peer(peer_id, "ui_interaction", envelope)

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
			return "A card was prepared face-down."
		"creature_move":
			var card := game_manager.get_card_by_uid(move.get("card_uid", ""))
			return ("%s moved." % card.card_name) if card else "Creature moved."
		"change_mode":
			var card := game_manager.get_card_by_uid(move.get("card_uid", ""))
			return ("%s changed stance." % card.card_name) if card else "Stance changed."
		"end_turn":
			return "Turn ended."
	return ""
