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
var _action_log_event_id: int = 0

func _init(gm: GameManager, mm: MatchManager, nm: Node, p_prompt_router = null) -> void:
	game_manager = gm
	match_manager = mm
	network_manager = nm
	prompt_router = p_prompt_router if p_prompt_router != null else PromptRouterScript.new(game_manager)
	_connect_signals()

func _connect_signals() -> void:
	match_manager.move_validated.connect(_on_move_validated)
	match_manager.action_resolved.connect(_on_action_resolved)
	match_manager.ui_refresh_requested.connect(_on_ui_refresh_requested)
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

func _on_ui_refresh_requested() -> void:
	if network_manager == null or game_manager == null:
		return
	for player_index in network_manager.player_peer_ids:
		var peer_id: int = network_manager.player_peer_ids[player_index]
		var viewer := _viewer_for_player_index(player_index)
		var action_message := ""
		if not game_manager.action_stack.is_empty():
			action_message = _label_for_pending_stack_action(game_manager.action_stack.back(), viewer)
		elif match_manager != null:
			action_message = str(match_manager.last_resolution_text).strip_edges()
		var event_data := _build_full_state_event_data(
			player_index,
			action_message
		)
		if peer_id == 1:
			network_manager.game_event_received.emit("full_state", event_data)
		else:
			network_manager.broadcast_event_to_peer(peer_id, "full_state", event_data)
	for peer_id in network_manager.spectator_peer_ids:
		network_manager.broadcast_event_to_peer(
			int(peer_id),
			"full_state",
			_build_full_state_event_data(
				GameState.SPECTATOR_VIEWER_INDEX,
				"Watching live match.",
				network_manager.get_spectator_visible_player_indices(int(peer_id))
			)
		)

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
	_action_log_event_id += 1
	# Send personalized state to each player (hand privacy + hidden board privacy)
	for player_index in network_manager.player_peer_ids:
		var peer_id: int = network_manager.player_peer_ids[player_index]
		var event_data := _build_full_state_event_data(player_index, action_message)
		if peer_id == 1:
			# Server's own "peer" — emit locally so the host UI updates too
			network_manager.game_event_received.emit("full_state", event_data)
		else:
			network_manager.broadcast_event_to_peer(peer_id, "full_state", event_data)
	for peer_id in network_manager.spectator_peer_ids:
		network_manager.broadcast_event_to_peer(
			int(peer_id),
			"full_state",
			_build_full_state_event_data(
				GameState.SPECTATOR_VIEWER_INDEX,
				action_message,
				network_manager.get_spectator_visible_player_indices(int(peer_id))
			)
		)

func _broadcast_full_state_for_move(move: Dictionary) -> void:
	if network_manager == null:
		return
	_action_log_event_id += 1
	for player_index in network_manager.player_peer_ids:
		var peer_id: int = network_manager.player_peer_ids[player_index]
		var event_data := _build_full_state_event_data(
			player_index,
			_label_for_move(move, _viewer_for_player_index(player_index))
		)
		if peer_id == 1:
			network_manager.game_event_received.emit("full_state", event_data)
		else:
			network_manager.broadcast_event_to_peer(peer_id, "full_state", event_data)
	for peer_id in network_manager.spectator_peer_ids:
		network_manager.broadcast_event_to_peer(
			int(peer_id),
			"full_state",
			_build_full_state_event_data(
				GameState.SPECTATOR_VIEWER_INDEX,
				_label_for_move(move, _viewer_for_player_index(GameState.SPECTATOR_VIEWER_INDEX)),
				network_manager.get_spectator_visible_player_indices(int(peer_id))
			)
		)

func _broadcast_full_state_for_action(action: CardAction) -> void:
	if network_manager == null:
		return
	_action_log_event_id += 1
	for player_index in network_manager.player_peer_ids:
		var peer_id: int = network_manager.player_peer_ids[player_index]
		var viewer := _viewer_for_player_index(player_index)
		var event_data := _build_full_state_event_data(
			player_index,
			_label_for_resolved_action(action, viewer)
		)
		if peer_id == 1:
			network_manager.game_event_received.emit("full_state", event_data)
		else:
			network_manager.broadcast_event_to_peer(peer_id, "full_state", event_data)
	for peer_id in network_manager.spectator_peer_ids:
		network_manager.broadcast_event_to_peer(
			int(peer_id),
			"full_state",
			_build_full_state_event_data(
				GameState.SPECTATOR_VIEWER_INDEX,
				_label_for_resolved_action(action, _viewer_for_player_index(GameState.SPECTATOR_VIEWER_INDEX)),
				network_manager.get_spectator_visible_player_indices(int(peer_id))
			)
		)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _build_full_state_event_data(player_index: int, action_message: String, visible_player_indices: Array = []) -> Dictionary:
	var event_data := {
		state = GameState.serialize(game_manager, player_index, visible_player_indices),
		action_message = action_message,
		action_log_event_id = _action_log_event_id,
	}
	var attack_preview := _serialize_pending_attack_preview()
	if player_index >= 0 and not attack_preview.is_empty():
		event_data["pending_attack_preview"] = attack_preview
	return event_data

func _serialize_pending_attack_preview() -> Dictionary:
	if match_manager == null or match_manager.selected_attacker == null or match_manager.pending_attack_target == null:
		return {}
	var preview := {
		"attacker_uid": match_manager.selected_attacker.uid,
	}
	if match_manager.pending_attack_target is Card:
		preview["target_uid"] = (match_manager.pending_attack_target as Card).uid
	elif match_manager.pending_attack_target is Player:
		preview["target_player_index"] = game_manager.players.find(match_manager.pending_attack_target)
	return preview

func _label_for_pending_stack_action(action: CardAction, viewer: Player = null) -> String:
	if action == null:
		return ""
	if match_manager != null:
		var prompt_message := str(match_manager._get_priority_action_message(action, viewer)).strip_edges()
		if not prompt_message.is_empty():
			return prompt_message
	return _label_for_resolved_action(action, viewer)

func _label_for_move(move: Dictionary, viewer: Player = null) -> String:
	var public_log_message := str(move.get("public_log_message", "")).strip_edges()
	if public_log_message != "":
		return public_log_message
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
		"play_creature":
			var creature := game_manager.get_card_by_uid(move.get("card_uid", ""))
			if creature == null:
				return "Creature summoned."
			var mode: int = int(move.get("mode", Card.CreatureMode.DEFENSIVE))
			var stance := "aggressive" if mode == int(Card.CreatureMode.AGGRESSIVE) else "defensive"
			return "Summoned %s in %s stance." % [_card_label_for_viewer(creature, viewer), stance]
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
		"activate_divine_caprice":
			return _label_for_stack_move(
				game_manager.get_card_by_uid(move.get("power_uid", "")),
				null,
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
		"humbaba_augury_choice":
			var humbaba := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if humbaba != null and chosen != null:
				return "%s primes %s with Augury Reading." % [_card_label_for_viewer(humbaba, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Augury Reading." % _card_label_for_viewer(humbaba, viewer)) if humbaba != null else "Humbaba resolves Augury Reading."
		"first_sage_adapa_choice":
			var adapa := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if adapa != null and chosen != null:
				return "%s silences %s." % [_card_label_for_viewer(adapa, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Silence Divine." % _card_label_for_viewer(adapa, viewer)) if adapa != null else "Silence Divine resolves."
		"third_sage_enmedugga_choice":
			var enmedugga := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if enmedugga != null and chosen != null:
				return "%s grants Good Fortune to %s." % [_card_label_for_viewer(enmedugga, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Good Fortune." % _card_label_for_viewer(enmedugga, viewer)) if enmedugga != null else "Good Fortune resolves."
		"fourth_sage_enmegalamma_choice":
			var enmegalamma := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if enmegalamma != null and chosen != null:
				return "%s adds %s from the deck." % [_card_label_for_viewer(enmegalamma, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Search Sage." % _card_label_for_viewer(enmegalamma, viewer)) if enmegalamma != null else "Search Sage resolves."
		"sixth_sage_an_enlilda_choice":
			var enlilda := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if enlilda != null and chosen != null:
				return "%s conjures %s home." % [_card_label_for_viewer(enlilda, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Conjure Home." % _card_label_for_viewer(enlilda, viewer)) if enlilda != null else "Conjure Home resolves."
		"lailoken_reveal_choice":
			var lailoken := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if lailoken != null and chosen != null:
				return "%s drains %s." % [_card_label_for_viewer(lailoken, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Magic Drain." % _card_label_for_viewer(lailoken, viewer)) if lailoken != null else "Magic Drain resolves."
		"masmassu_priest_reveal_choice":
			var priest := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if priest != null and chosen != null:
				if priest is Grindylow:
					return "%s drowns %s." % [_card_label_for_viewer(priest, viewer), _card_label_for_viewer(chosen, viewer)]
				return "%s breaks %s." % [_card_label_for_viewer(priest, viewer), _card_label_for_viewer(chosen, viewer)]
			if priest is Grindylow:
				return "%s resolves Drown Below." % _card_label_for_viewer(priest, viewer)
			return ("%s resolves Dalkhu Break." % _card_label_for_viewer(priest, viewer)) if priest != null else "Dalkhu Break resolves."
		"rally_the_troops_choice":
			var rally := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if rally != null and chosen != null:
				return "%s recruits %s." % [_card_label_for_viewer(rally, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Rally." % _card_label_for_viewer(rally, viewer)) if rally != null else "Rally resolves."
		"terror_impact_choice":
			var terror := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if terror != null and chosen != null:
				return "%s returns %s to hand." % [_card_label_for_viewer(terror, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Terror." % _card_label_for_viewer(terror, viewer)) if terror != null else "Terror resolves."
		"huginn_perish_prime_choice":
			var huginn := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if huginn != null and chosen != null:
				return "%s primes %s." % [_card_label_for_viewer(huginn, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Hex Search." % _card_label_for_viewer(huginn, viewer)) if huginn != null else "Hex Search resolves."
		"muninn_perish_prime_choice":
			var muninn := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if muninn != null and chosen != null:
				return "%s primes %s." % [_card_label_for_viewer(muninn, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Charm Search." % _card_label_for_viewer(muninn, viewer)) if muninn != null else "Charm Search resolves."
		"fenrir_devour_choice":
			var fenrir := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if fenrir != null and chosen != null:
				return "%s devours %s." % [_card_label_for_viewer(fenrir, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Devour." % _card_label_for_viewer(fenrir, viewer)) if fenrir != null else "Devour resolves."
		"harii_jarl_impact_choice":
			var jarl := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen_names: Array[String] = []
			for chosen_uid in move.get("chosen_uids", []):
				var chosen := game_manager.get_card_by_uid(str(chosen_uid))
				if chosen != null:
					chosen_names.append(_card_label_for_viewer(chosen, viewer))
			if jarl != null and not chosen_names.is_empty():
				return "%s summons %s." % [_card_label_for_viewer(jarl, viewer), ", ".join(chosen_names)]
			return ("%s resolves Warband." % _card_label_for_viewer(jarl, viewer)) if jarl != null else "Warband resolves."
		"durinn_secondborn_choice":
			var durinn := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if durinn != null and chosen != null:
				return "%s reforges %s." % [_card_label_for_viewer(durinn, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Reforge." % _card_label_for_viewer(durinn, viewer)) if durinn != null else "Reforge resolves."
		"kur_jara_tree_of_life_choice":
			var kur_jara := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen_names: Array[String] = []
			for chosen_uid in move.get("chosen_uids", []):
				var chosen := game_manager.get_card_by_uid(str(chosen_uid))
				if chosen != null:
					chosen_names.append(_card_label_for_viewer(chosen, viewer))
			if kur_jara != null and not chosen_names.is_empty():
				return "%s completes Tree of Life using %s." % [_card_label_for_viewer(kur_jara, viewer), ", ".join(chosen_names)]
			return ("%s resolves Tree of Life." % _card_label_for_viewer(kur_jara, viewer)) if kur_jara != null else "Tree of Life resolves."
		"hunting_tactics_choice":
			var power := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var attacker := game_manager.get_card_by_uid(move.get("attacker_uid", ""))
			var chosen_names: Array[String] = []
			for chosen_uid in move.get("chosen_uids", []):
				var chosen := game_manager.get_card_by_uid(str(chosen_uid))
				if chosen != null:
					chosen_names.append(_card_label_for_viewer(chosen, viewer))
			if power != null and attacker != null and not chosen_names.is_empty():
				return "%s supports %s with %s." % [_card_label_for_viewer(power, viewer), _card_label_for_viewer(attacker, viewer), ", ".join(chosen_names)]
			if power != null and attacker != null:
				return "%s declines to support %s." % [_card_label_for_viewer(power, viewer), _card_label_for_viewer(attacker, viewer)]
			return "Hunting Tactics resolves."
		"gugalanna_celestial_charge_choice":
			var gugalanna := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if gugalanna != null and chosen != null:
				return "%s charges down %s." % [_card_label_for_viewer(gugalanna, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Celestial Charge." % _card_label_for_viewer(gugalanna, viewer)) if gugalanna != null else "Celestial Charge resolves."
		"giant_master_architect_choice":
			var architect := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if architect != null and chosen != null:
				return "%s takes %s from the deck." % [_card_label_for_viewer(architect, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Master Plan." % _card_label_for_viewer(architect, viewer)) if architect != null else "Master Plan resolves."
		"pai_long_autumn_king_choice":
			var pai_long := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if pai_long != null and chosen != null:
				return "%s takes %s from the deck." % [_card_label_for_viewer(pai_long, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Stormcloud." % _card_label_for_viewer(pai_long, viewer)) if pai_long != null else "Stormcloud resolves."
		"nergal_lion_choice":
			var lion := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if lion != null and chosen != null:
				return "%s immolates %s." % [_card_label_for_viewer(lion, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Immolate." % _card_label_for_viewer(lion, viewer)) if lion != null else "Immolate resolves."
		"gala_tura_destroyed_choice":
			var gala_tura := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen_names: Array[String] = []
			for chosen_uid in move.get("chosen_uids", []):
				var chosen := game_manager.get_card_by_uid(str(chosen_uid))
				if chosen != null:
					chosen_names.append(_card_label_for_viewer(chosen, viewer))
			if gala_tura != null and not chosen_names.is_empty():
				return "%s returns %s to the deck." % [_card_label_for_viewer(gala_tura, viewer), ", ".join(chosen_names)]
			return ("%s resolves Water of Life." % _card_label_for_viewer(gala_tura, viewer)) if gala_tura != null else "Water of Life resolves."
		"gawain_healing_hands_choice":
			var gawain := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var target := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if gawain != null and target != null:
				return "%s heals %s." % [_card_label_for_viewer(gawain, viewer), _card_label_for_viewer(target, viewer)]
			return ("%s resolves Healing Hands." % _card_label_for_viewer(gawain, viewer)) if gawain != null else "Healing Hands resolves."
		"tatzelwurm_dragon_heart_choice":
			var tatzelwurm := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if tatzelwurm != null and chosen != null:
				return "%s takes %s from the deck." % [_card_label_for_viewer(tatzelwurm, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Dragon Heart." % _card_label_for_viewer(tatzelwurm, viewer)) if tatzelwurm != null else "Dragon Heart resolves."
		"byggvir_reveal_choice":
			var byggvir := game_manager.get_card_by_uid(move.get("source_uid", ""))
			return ("%s resolves Brewing." % _card_label_for_viewer(byggvir, viewer)) if byggvir != null else "Brewing resolves."
		"nusku_well_of_fire_choice":
			var nusku := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if nusku != null and chosen != null:
				return "%s chooses %s for Well of Fire." % [_card_label_for_viewer(nusku, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Well of Fire." % _card_label_for_viewer(nusku, viewer)) if nusku != null else "Well of Fire resolves."
		"apollyons_demiurge_choice":
			var spell := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("target_uid", ""))
			if spell != null and chosen != null:
				return "%s chooses %s." % [_card_label_for_viewer(spell, viewer), _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves." % _card_label_for_viewer(spell, viewer)) if spell != null else "Apollyon's Demiurge resolves."
		"ragnarok_discard_choice":
			var ragnarok := game_manager.get_card_by_uid(move.get("source_uid", ""))
			return ("%s forces a discard." % _card_label_for_viewer(ragnarok, viewer)) if ragnarok != null else "Ragnarok forces a discard."
		"foolish_optimism_choice":
			var spell := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var attacker := game_manager.get_card_by_uid(move.get("attacker_uid", ""))
			var defender := game_manager.get_card_by_uid(move.get("defender_uid", ""))
			if spell != null and attacker != null and defender != null:
				return "%s compels %s to attack %s." % [_card_label_for_viewer(spell, viewer), _card_label_for_viewer(attacker, viewer), _card_label_for_viewer(defender, viewer)]
			return ("%s fizzles." % _card_label_for_viewer(spell, viewer)) if spell != null else "Foolish Optimism fizzles."
		"blessed_knights_choice":
			var knights := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var ward_kind := str(move.get("ward_kind", "")).replace("_", " ")
			return ("%s grants Blessed Ward against %s." % [_card_label_for_viewer(knights, viewer), ward_kind]) if knights != null else "Blessed Ward was chosen."
		"tezcatlipoca_active_titlacauan_choice":
			var tez := game_manager.get_card_by_uid(move.get("source_uid", ""))
			return ("%s resolves Titlacauan." % _card_label_for_viewer(tez, viewer)) if tez != null else "Titlacauan resolves."
		"nusku_active_core_flame_choice":
			var nusku := game_manager.get_card_by_uid(move.get("source_uid", ""))
			if bool(move.get("decline", false)):
				return ("%s declines Core Flame." % _card_label_for_viewer(nusku, viewer)) if nusku != null else "Core Flame was declined."
			return ("%s resolves Core Flame." % _card_label_for_viewer(nusku, viewer)) if nusku != null else "Core Flame resolves."
		"mummu_entropy_choice":
			var mummu := game_manager.get_card_by_uid(move.get("source_uid", ""))
			var chosen := game_manager.get_card_by_uid(move.get("chosen_uid", ""))
			var placement := str(move.get("placement", "prime")).capitalize()
			if mummu != null and chosen != null:
				return "%s chooses %s for %s." % [_card_label_for_viewer(mummu, viewer), placement, _card_label_for_viewer(chosen, viewer)]
			return ("%s resolves Entropy." % _card_label_for_viewer(mummu, viewer)) if mummu != null else "Entropy resolves."
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
		"return_to_hand_choice":
			var return_card := game_manager.get_card_by_uid(str(move.get("card_uid", "")))
			return ("Resolved %s's escape choice." % _card_label_for_viewer(return_card, viewer)) if return_card else "Resolved a return-to-hand choice."
		"habrok_breakout_choice":
			var habrok := game_manager.get_card_by_uid(str(move.get("source_uid", "")))
			return ("%s resolved Breakout." % _card_label_for_viewer(habrok, viewer)) if habrok else "Breakout resolved."
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
	if player_index == GameState.SPECTATOR_VIEWER_INDEX:
		return Player.new()
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
