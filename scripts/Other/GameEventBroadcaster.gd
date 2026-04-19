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
	if move.get("type", "") in ["end_turn", "intercept_decision", "priority_pass"]:
		return
	_broadcast_full_state_for_move(move)

func _on_action_resolved(action: CardAction) -> void:
	_broadcast_full_state_for_action(action)

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

func _on_game_ended(winner: Player, loser: Player) -> void:
	var winner_idx := game_manager.players.find(winner)
	var result_message := game_manager.get_game_result_message(winner, loser)
	_broadcast_full_state(result_message)
	network_manager.broadcast_event_to_all("game_ended", {
		winner_index = winner_idx,
		winner_name  = winner.player_name if winner != null else "",
		result_message = result_message,
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
	# Send personalized state to each player (hand privacy + hidden board privacy)
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

func _broadcast_full_state_for_move(move: Dictionary) -> void:
	if network_manager == null:
		return
	for player_index in network_manager.player_peer_ids:
		var peer_id: int = network_manager.player_peer_ids[player_index]
		var state_data := GameState.serialize(game_manager, player_index)
		var event_data := {
			state = state_data,
			action_message = _label_for_move(move, _viewer_for_player_index(player_index)),
		}
		if peer_id == 1:
			network_manager.game_event_received.emit("full_state", event_data)
		else:
			network_manager.broadcast_event_to_peer(peer_id, "full_state", event_data)

func _broadcast_full_state_for_action(action: CardAction) -> void:
	if network_manager == null:
		return
	for player_index in network_manager.player_peer_ids:
		var peer_id: int = network_manager.player_peer_ids[player_index]
		var viewer := _viewer_for_player_index(player_index)
		var state_data := GameState.serialize(game_manager, player_index)
		var event_data := {
			state = state_data,
			action_message = _label_for_resolved_action(action, viewer),
		}
		if peer_id == 1:
			network_manager.game_event_received.emit("full_state", event_data)
		else:
			network_manager.broadcast_event_to_peer(peer_id, "full_state", event_data)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _label_for_move(move: Dictionary, viewer: Player = null) -> String:
	match move.get("type", ""):
		"attack":
			var attacker := move.get("attacker", null) as Card
			var target = move.get("target", null)
			if attacker == null:
				return "An attack was declared."
			if target is Player:
				return "%s attacks %s's followers." % [_card_label_for_viewer(attacker, viewer), (target as Player).player_name]
			if target is Card:
				return "%s attacks %s." % [_card_label_for_viewer(attacker, viewer), _target_label_for_viewer(target, viewer)]
			return _card_label_for_viewer(attacker, viewer) + " attacks."
		"intercept_decision":
			return ""
		"play_card":
			var card := game_manager.get_card_by_uid(move.get("card_uid", ""))
			return ("Played %s." % _card_label_for_viewer(card, viewer)) if card else "Card played."
		"cast_spell":
			return _label_for_stack_move(
				game_manager.get_card_by_uid(move.get("spell_uid", "")),
				game_manager.get_card_by_uid(move.get("target_uid", "")),
				viewer
			)
		"cast_charm":
			return _label_for_stack_move(
				game_manager.get_card_by_uid(move.get("charm_uid", "")),
				game_manager.get_card_by_uid(move.get("target_uid", "")),
				viewer
			)
		"god_ability":
			return _label_for_stack_move(
				game_manager.get_card_by_uid(move.get("god_uid", "")),
				game_manager.get_card_by_uid(move.get("target_uid", "")),
				viewer
			)
		"activate_power":
			return _label_for_stack_move(
				game_manager.get_card_by_uid(move.get("power_uid", "")),
				game_manager.get_card_by_uid(move.get("target_uid", "")),
				viewer
			)
		"activate_card_ability":
			return _label_for_stack_move(
				game_manager.get_card_by_uid(move.get("source_uid", "")),
				game_manager.get_card_by_uid(move.get("target_uid", "")),
				viewer
			)
		"wolf_adolescent_maturation_choice":
			var wolf := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var lupine := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if lupine != null:
				return "%s matures into %s." % [_card_label_for_viewer(wolf, viewer), _card_label_for_viewer(lupine, viewer)]
			return ("%s skips Maturation." % _card_label_for_viewer(wolf, viewer)) if wolf != null else "Wolf Adolescent skips Maturation."
		"prepare_card":
			return "A card was prepared face-down."
		"creature_move":
			var card := game_manager.get_card_by_uid(move.get("card_uid", ""))
			return ("%s moved." % _card_label_for_viewer(card, viewer)) if card else "Creature moved."
		"change_mode":
			var card := game_manager.get_card_by_uid(move.get("card_uid", ""))
			return ("%s changed stance." % _card_label_for_viewer(card, viewer)) if card else "Stance changed."
		"tiamat_upkeep_choice":
			var tiamat_card := game_manager.get_card_by_uid(str(move.get("card_uid", "")))
			return ("Matriarch Rule returned %s to hand." % _card_label_for_viewer(tiamat_card, viewer)) if tiamat_card else "Matriarch Rule returned a slotted creature to hand."
		"end_turn":
			return "Turn ended."
	return ""

func _label_for_resolved_action(action: CardAction, viewer: Player = null) -> String:
	if action == null:
		return match_manager.last_resolution_text
	if not _action_involves_hidden_card(action, viewer):
		return match_manager.last_resolution_text
	match action.type:
		CardAction.Type.ATTACK:
			if action.target is Player:
				return "%s attacks %s's followers." % [_card_label_for_viewer(action.attacker, viewer), (action.target as Player).player_name]
			if action.target is Card:
				return "%s fought %s." % [_card_label_for_viewer(action.attacker, viewer), _target_label_for_viewer(action.target, viewer)]
			return _card_label_for_viewer(action.attacker, viewer) + " attacks."
		CardAction.Type.EVENT:
			return action.event_name.replace("_", " ").capitalize() + "."
		_:
			return _label_for_stack_move(action.card, action.target, viewer)

func _label_for_stack_move(card: Card, target = null, viewer: Player = null) -> String:
	if card == null:
		return ""
	if target != null:
		return "%s is targeting %s." % [_card_label_for_viewer(card, viewer), _target_label_for_viewer(target, viewer)]
	return _card_label_for_viewer(card, viewer) + " goes on the stack."

func _viewer_for_player_index(player_index: int) -> Player:
	if game_manager == null:
		return null
	if player_index < 0 or player_index >= game_manager.players.size():
		return null
	return game_manager.players[player_index]

func _card_label_for_viewer(card: Card, viewer: Player = null) -> String:
	if card == null:
		return "Card"
	return card.get_log_display_name(viewer)

func _target_label_for_viewer(target, viewer: Player = null) -> String:
	if target is Card:
		return (target as Card).get_target_log_display_name(viewer)
	if target is Player:
		return (target as Player).player_name + "'s followers"
	return "target"

func _action_involves_hidden_card(action: CardAction, viewer: Player = null) -> bool:
	if viewer == null or action == null:
		return false
	for maybe_card in [action.card, action.attacker, action.united_front_partner, action.interceptor]:
		if maybe_card != null and (maybe_card as Card).is_hidden_from_viewer(viewer):
			return true
	if action.target is Card and (action.target as Card).is_hidden_from_viewer(viewer):
		return true
	return false
