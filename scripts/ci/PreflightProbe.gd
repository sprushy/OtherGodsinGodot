extends Node
class_name PreflightProbe

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const DefaultMatchSetupScript = preload("res://scripts/server/DefaultMatchSetup.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")
const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const MatchCommandRegistryScript = preload("res://scripts/Other/MatchCommandRegistry.gd")
const MatchHistoryStoreScript = preload("res://scripts/server/MatchHistoryStore.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const MatchSupervisorScript = preload("res://scripts/server/MatchSupervisor.gd")
const NetworkManagerScript = preload("res://scripts/Other/NetworkManager.gd")
const RankedBotDeckPoolScript = preload("res://scripts/server/RankedBotDeckPool.gd")
const RankedProgressionScript = preload("res://scripts/server/RankedProgression.gd")
const RankBadgeCatalog = preload("res://scripts/core/RankBadgeCatalog.gd")
const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")

const MIN_CATALOG_CARDS := 200
const RESULT_ARG_PREFIX := "preflight_result_file="

var _ran := false

class RequestNextLobby extends LobbyServerScript:
	var events: Array[Dictionary] = []

	func _send_to_peer(peer_id: int, message_type: String, payload: Dictionary) -> void:
		events.append({"peer": peer_id, "type": message_type, "payload": payload})

class BadgeTestAccountStore extends AccountStore:
	var storage_path: String

	func _get_storage_path() -> String:
		return storage_path

func _ready() -> void:
	var success := run()
	get_tree().quit(0 if success else 1)

func run() -> bool:
	if _ran:
		return true
	_ran = true
	var failures: PackedStringArray = []
	_check_card_catalog(failures)
	_check_deck_validator(failures)
	_check_match_command_registry_coverage(failures)
	_check_command_authority(failures)
	_check_network_payload_guards(failures)
	_check_full_state_event_payload_budget(failures)
	_check_game_state_privacy(failures)
	_check_json_store_round_trip(failures)
	_check_match_supervisor_launch_config(failures)
	_check_ranked_progression(failures)
	_check_rank_badges(failures)
	_check_dedicated_ranked_history(failures)
	_check_ranked_bot_pool(failures)
	_check_ranked_bot_deck_generation(failures)
	_check_ranked_bot_manifestations(failures)
	_check_bot_power_followthrough(failures)
	_check_bot_summon_and_intercept(failures)
	_check_bot_main_phase_combat_order(failures)
	_check_bot_hermes_speed(failures)
	_check_bot_combat_buff_value(failures)
	_check_bot_reveal_defense(failures)
	_check_bot_next_turn_lethal(failures)
	_check_standing_bot_seeks(failures)
	_check_ladder_pages(failures)
	_check_request_next(failures)

	if not failures.is_empty():
		for failure in failures:
			push_error("preflight_probe: %s" % failure)
		_write_result_file(false, failures)
		return false

	print("preflight_probe: PASS")
	_write_result_file(true, failures)
	return true

func _check_card_catalog(failures: PackedStringArray) -> void:
	for path in CardCatalogScript.CARD_SCRIPT_PATHS:
		if not ResourceLoader.exists(path):
			failures.append("registered card script is missing: %s" % path)
			continue
		var script = load(path)
		if script == null:
			failures.append("registered card script failed to load: %s" % path)

	var cards: Array[Card] = CardCatalogScript.make_all_cards()
	if cards.size() < MIN_CATALOG_CARDS:
		failures.append("card catalog only produced %d cards" % cards.size())
	var thor_one := CardCatalogScript.instantiate_card_by_name("Thor")
	var thor_two := CardCatalogScript.instantiate_card_by_name("Thor")
	if thor_one == null or thor_two == null:
		failures.append("card catalog failed to instantiate Thor by exact name")
	elif thor_one == thor_two:
		failures.append("card catalog returned a shared cached card instance")
	var compact_fall := CardCatalogScript.instantiate_card_by_name("fallofthemighty")
	if compact_fall == null:
		failures.append("card catalog failed to instantiate Fall of the Mighty by lookup key")
	elif CardCatalogScript.to_lookup_key(str(compact_fall.card_name)) != "fallofthemighty":
		failures.append("card catalog lookup key resolved the wrong card: %s" % str(compact_fall.card_name))

	var seen_names: Dictionary = {}
	for card in cards:
		if card == null:
			failures.append("card catalog returned a null card")
			continue
		var card_name := str(card.card_name).strip_edges()
		if card_name.is_empty() or card_name == "Unnamed" or card_name == "Card":
			failures.append("card catalog returned an unnamed card from %s" % _script_path(card))
			continue
		if seen_names.has(card_name):
			failures.append("card catalog returned duplicate card name: %s" % card_name)
		seen_names[card_name] = true
		if bool(card.is_token) or card.card_types.has("Token"):
			failures.append("card catalog exposed token card: %s" % card_name)

func _check_deck_validator(failures: PackedStringArray) -> void:
	var validator = DeckValidatorScript.new()
	var valid_deck := _known_good_deck_counts()
	var result: Dictionary = validator.validate_deck(valid_deck)
	if not bool(result.get("is_valid", false)):
		failures.append("known-good deck failed validation: %s" % str(result.get("error", "")))
	var invalid_result: Dictionary = validator.validate_deck({"Thor": 2})
	if bool(invalid_result.get("is_valid", false)):
		failures.append("invalid duplicate-god deck passed validation")
	if DeckValidatorScript.get_reinforcement_limit(40, 3) != 14:
		failures.append("40 regular cards plus 3 Powers should allow 14 Reinforcements")
	var oversized_reinforcements := {
		"Tablet of Life": 3,
		"Pictish Beast": 3,
		"Hyena Pack": 3,
		"Ancient Pyre": 3,
		"Harii Shaman": 2,
	}
	var reinforcement_result: Dictionary = validator.validate_deck(valid_deck, {}, oversized_reinforcements)
	if bool(reinforcement_result.get("is_valid", false)):
		failures.append("deck validator accepted Reinforcements above the rounded-down limit")
	var registered_reinforcements := {"Tablet of Life": 3}
	var proposed_main := valid_deck.duplicate(true)
	proposed_main["Tablet of Life"] = 2
	var proposed_reinforcements := {
		"Tablet of Life": 1,
	}
	var swap_result: Dictionary = validator.validate_reinforcement_swap(
		valid_deck,
		registered_reinforcements,
		proposed_main,
		proposed_reinforcements
	)
	if not bool(swap_result.get("is_valid", false)):
		failures.append("legal Reinforcement resubmission with changed main-deck size failed validation: %s" % str(swap_result.get("error", "")))
	var player := Player.new()
	if not player.validate_deck(_cards_from_counts(valid_deck)):
		failures.append("Player.validate_deck rejected a DeckValidator-valid deck")
	if player.validate_deck(_cards_from_counts({"Thor": 2})):
		failures.append("Player.validate_deck accepted an invalid duplicate-god deck")

func _check_match_command_registry_coverage(failures: PackedStringArray) -> void:
	var implemented_commands := _extract_match_manager_command_types(failures)
	if implemented_commands.is_empty():
		return
	var registered_commands := MatchCommandRegistryScript.get_known_command_types()
	var implemented_lookup := _string_lookup(implemented_commands)
	var registered_lookup := _string_lookup(registered_commands)
	for command_type in implemented_commands:
		if not registered_lookup.has(command_type):
			failures.append("MatchCommandRegistry is missing implemented command: %s" % command_type)
	for command_type in registered_commands:
		if not implemented_lookup.has(command_type):
			failures.append("MatchCommandRegistry lists unimplemented command: %s" % command_type)

func _extract_match_manager_command_types(failures: PackedStringArray) -> Array[String]:
	var source_path := "res://scripts/Other/MatchManager.gd"
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		failures.append("preflight could not read %s" % source_path)
		return []
	var source := file.get_as_text()
	file.close()
	var start_idx := source.find("func _process_command_impl")
	var end_idx := source.find("move_failed.emit(\"Unknown command type", start_idx)
	if start_idx < 0 or end_idx <= start_idx:
		failures.append("preflight could not find MatchManager command dispatch block")
		return []
	var dispatch_source := source.substr(start_idx, end_idx - start_idx)
	var regex := RegEx.new()
	if regex.compile("(?m)^\\t\\t\"([a-z0-9_]+)\":") != OK:
		failures.append("preflight could not compile command dispatch regex")
		return []
	var commands: Array[String] = []
	for match_result in regex.search_all(dispatch_source):
		var command_type := match_result.get_string(1)
		if command_type not in commands:
			commands.append(command_type)
	# Cosmetic commands can return from process_command before rules dispatch.
	var entry_idx := source.find("func process_command(")
	var early_dispatch := RegEx.new()
	if entry_idx >= 0 and early_dispatch.compile("(?m)^\\tif str\\(command\\.get\\(\"type\", \"\"\\)\\) == \"([a-z0-9_]+)\":\\r?\\n\\t\\treturn _process_[a-z0-9_]+\\(command, sender_info\\)") == OK:
		for match_result in early_dispatch.search_all(source.substr(entry_idx, start_idx - entry_idx)):
			var command_type := match_result.get_string(1)
			if command_type not in commands:
				commands.append(command_type)
	commands.sort()
	return commands

func _string_lookup(values: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for value in values:
		var text := str(value)
		if not text.is_empty():
			lookup[text] = true
	return lookup

func _check_command_authority(failures: PackedStringArray) -> void:
	var game_manager := GameManager.new()
	var player_one := Player.new()
	player_one.player_name = "Player 1"
	game_manager.players.append(player_one)
	var player_two := Player.new()
	player_two.player_name = "Player 2"
	game_manager.players.append(player_two)
	game_manager.current_player = player_one
	game_manager.other_player = player_two
	game_manager.turn_player = player_one
	game_manager.turn_number = 2
	game_manager._upkeep_started_turn = game_manager.turn_number
	game_manager._upkeep_resolved_turn = game_manager.turn_number

	var match_manager := MatchManager.new(game_manager)
	var attacker := BaseCard.new()
	attacker.card_name = "Probe Attacker"
	attacker.card_type = Card.CardType.CREATURE
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.card_owner = player_one
	player_one.frontline_zones[0].add_card(attacker)
	var required_player := MatchCommandRegistryScript.get_required_player(
		{
			"type": "select_attacker",
			"card_uid": attacker.uid,
		},
		game_manager,
		match_manager
	)
	if required_player != player_one:
		failures.append("command registry resolved the wrong player for select_attacker")
	if MatchCommandRegistryScript.get_ui_interaction_type("intercept_decision") != "intercept":
		failures.append("command registry lost the intercept prompt mapping")
	if not MatchCommandRegistryScript.requires_clear_stack_window("play_card"):
		failures.append("command registry should block play_card during unresolved stack windows")
	if MatchCommandRegistryScript.requires_resolved_upkeep({"type": "priority_pass"}):
		failures.append("command registry should allow priority_pass during upkeep prompts")
	if not MatchCommandRegistryScript.is_known_command_type("select_attacker"):
		failures.append("command registry lost known command coverage for select_attacker")
	if MatchCommandRegistryScript.is_known_command_type("draw"):
		failures.append("command registry treated an upkeep choice value as a command type")
	if MatchCommandRegistryScript.is_known_command_type("probe_unknown_command"):
		failures.append("command registry accepted an unknown command type")
	var unknown_command := match_manager.process_command(
		{
			"type": "probe_unknown_command",
		},
		{
			"peer_id": 1,
			"player_index": 0,
		}
	)
	if unknown_command:
		failures.append("unknown command was processed successfully")
	if match_manager.last_move_failed_reason.find("Unknown command type") == -1:
		failures.append("unknown command did not fail with a clear reason: %s" % match_manager.last_move_failed_reason)

	match_manager.last_move_failed_reason = ""
	var unauthorized := match_manager.process_command(
		{
			"type": "select_attacker",
			"card_uid": attacker.uid,
		},
		{
			"peer_id": 2,
			"player_index": 1,
		}
	)
	if unauthorized:
		failures.append("unauthorized player was allowed to select attacker")
	if match_manager.last_move_failed_reason.find("belongs to Player 1") == -1:
		failures.append("unexpected unauthorized command failure reason: %s" % match_manager.last_move_failed_reason)

	match_manager.last_move_failed_reason = ""
	var authorized := match_manager.process_command(
		{
			"type": "select_attacker",
			"card_uid": attacker.uid,
		},
		{
			"peer_id": 1,
			"player_index": 0,
		}
	)
	if not authorized:
		failures.append("authorized player could not select attacker: %s" % match_manager.last_move_failed_reason)
	elif match_manager.selected_attacker != attacker:
		failures.append("authorized attacker selection did not stick")

func _check_network_payload_guards(failures: PackedStringArray) -> void:
	var network_manager = NetworkManagerScript.new()
	var valid_reason: String = network_manager.get_command_payload_rejection_reason({"type": "priority_pass"})
	if not valid_reason.is_empty():
		failures.append("network guard rejected a simple valid command: %s" % valid_reason)
	var shorthand_key_reason: String = network_manager.get_command_payload_rejection_reason({type = "priority_pass"})
	if not shorthand_key_reason.is_empty():
		failures.append("network guard rejected a command with StringName shorthand keys: %s" % shorthand_key_reason)
	var missing_type_reason: String = network_manager.get_command_payload_rejection_reason({"player_index": 0})
	if missing_type_reason.is_empty():
		failures.append("network guard accepted a command without a type")
	var unknown_type_reason: String = network_manager.get_command_payload_rejection_reason({"type": "probe_unknown_command"})
	if unknown_type_reason.find("Unknown command type") == -1:
		failures.append("network guard accepted an unknown command type: %s" % unknown_type_reason)
	var oversized_value := ""
	for _index in range(NetworkManagerScript.MAX_NETWORK_PAYLOAD_STRING_LENGTH + 1):
		oversized_value += "x"
	var oversized_reason: String = network_manager.get_command_payload_rejection_reason(
		{
			"type": "priority_pass",
			"payload": oversized_value,
		}
	)
	if oversized_reason.is_empty():
		failures.append("network guard accepted an oversized command string")
	var unsupported_node := Node.new()
	var unsupported_reason: String = network_manager.get_command_payload_rejection_reason(
		{
			"type": "priority_pass",
			"payload": unsupported_node,
		}
	)
	unsupported_node.free()
	if unsupported_reason.is_empty():
		failures.append("network guard accepted an unsupported object payload")
	var join_reason: String = network_manager.get_join_request_payload_rejection_reason(
		{
			"match_id": "probe",
			"session_id": "probe-session",
		}
	)
	if not join_reason.is_empty():
		failures.append("network guard rejected a simple join request: %s" % join_reason)
	var valid_event_reason: String = network_manager.get_game_event_payload_rejection_reason("full_state", {"turn": 1})
	if not valid_event_reason.is_empty():
		failures.append("network guard rejected a simple game event: %s" % valid_event_reason)
	var missing_event_type_reason: String = network_manager.get_game_event_payload_rejection_reason("", {})
	if missing_event_type_reason.is_empty():
		failures.append("network guard accepted a game event without a type")
	var oversized_event_value := ""
	for _index in range(NetworkManagerScript.MAX_NETWORK_PAYLOAD_STRING_LENGTH + 1):
		oversized_event_value += "x"
	var oversized_event_reason: String = network_manager.get_game_event_payload_rejection_reason(
		"full_state",
		{
			"payload": oversized_event_value,
		}
	)
	if oversized_event_reason.is_empty():
		failures.append("network guard accepted an oversized game event string")
	network_manager.free()

func _check_full_state_event_payload_budget(failures: PackedStringArray) -> void:
	var game_manager := GameManager.new()
	var deck_counts := _known_good_deck_counts()
	var session := MatchSessionScript.new(
		"preflight_payload_budget",
		"preflight_room",
		"127.0.0.1",
		12345,
		["session_one", "session_two"],
		{
			"session_one": {"deck_name": "Preflight One", "cards": deck_counts},
			"session_two": {"deck_name": "Preflight Two", "cards": deck_counts},
		},
		{
			"session_one": {"player_name": "Player 1"},
			"session_two": {"player_name": "Player 2"},
		}
	)
	var setup = DefaultMatchSetupScript.new()
	if setup.build_match_from_session_decks(game_manager, session).is_empty():
		failures.append("preflight could not build submitted-deck match for full_state payload budget")
		return
	game_manager.start_turn()
	var network_manager = NetworkManagerScript.new()
	for view in [[0, []], [1, []], [GameState.SPECTATOR_VIEWER_INDEX, []], [GameState.SPECTATOR_VIEWER_INDEX, [0, 1]]]:
		var viewer_index: int = view[0]
		var visible_indices: Array = view[1]
		var event_payload := {
			"state": GameState.serialize(game_manager, viewer_index, visible_indices),
			"action_message": "preflight payload budget",
		}
		var rejection_reason: String = network_manager.get_game_event_payload_rejection_reason("full_state", event_payload)
		if not rejection_reason.is_empty():
			var payload_bytes := JSON.stringify(event_payload).to_utf8_buffer().size()
			failures.append("full_state payload for viewer %d exceeded network guard: %s (%d bytes)" % [
				viewer_index,
				rejection_reason,
				payload_bytes,
			])
	network_manager.free()

func _check_game_state_privacy(failures: PackedStringArray) -> void:
	var game_manager := GameManager.new()
	var player_one := Player.new()
	player_one.player_name = "Player 1"
	game_manager.players.append(player_one)
	var player_two := Player.new()
	player_two.player_name = "Player 2"
	game_manager.players.append(player_two)
	game_manager.current_player = player_one
	game_manager.other_player = player_two
	game_manager.turn_player = player_one

	var own_card := BaseCard.new()
	own_card.card_name = "Probe Own Hand"
	own_card.card_owner = player_one
	player_one.hand_zone.add_card(own_card)
	var opponent_card := BaseCard.new()
	opponent_card.card_name = "Probe Opponent Secret"
	opponent_card.card_owner = player_two
	player_two.hand_zone.add_card(opponent_card)

	var state := GameState.serialize(game_manager, 0)
	var players = state.get("players", [])
	if not (players is Array) or (players as Array).size() != 2:
		failures.append("serialized state did not contain two players")
		return
	var own_hand = ((players as Array)[0] as Dictionary).get("hand", [])
	var opponent_hand = ((players as Array)[1] as Dictionary).get("hand", [])
	if not (own_hand is Array) or (own_hand as Array).is_empty():
		failures.append("viewer hand was missing from serialized state")
	elif bool(((own_hand as Array)[0] as Dictionary).get("hidden", false)):
		failures.append("viewer hand was hidden from itself")
	if not (opponent_hand is Array) or (opponent_hand as Array).is_empty():
		failures.append("opponent hand placeholder was missing from serialized state")
	else:
		var hidden_card := (opponent_hand as Array)[0] as Dictionary
		if not bool(hidden_card.get("hidden", false)):
			failures.append("opponent hand card was not hidden from viewer")
		if hidden_card.has("card_name"):
			failures.append("opponent hand leaked card name: %s" % str(hidden_card.get("card_name", "")))

func _check_json_store_round_trip(failures: PackedStringArray) -> void:
	var storage_path := "user://ci_preflight_json_store.json"
	var global_path := ProjectSettings.globalize_path(storage_path)
	DirAccess.remove_absolute(global_path)
	DirAccess.remove_absolute("%s.tmp" % global_path)
	DirAccess.remove_absolute("%s.bak" % global_path)
	var payload := {
		"version": 1,
		"nested": {
			"ok": true,
		},
	}
	if not JsonStoreScript.save_json(global_path, payload, "preflight_probe"):
		failures.append("JsonStore failed to save a probe payload")
		return
	var loaded := JsonStoreScript.load_dictionary(global_path, {}, "preflight_probe")
	if int(loaded.get("version", 0)) != 1:
		failures.append("JsonStore failed to load saved probe payload")
	if not JsonStoreScript.save_json(global_path, {"version": 2}, "preflight_probe"):
		failures.append("JsonStore failed to replace an existing payload")
		return
	var backup := JsonStoreScript.load_dictionary("%s.bak" % global_path, {}, "preflight_probe")
	if int(backup.get("version", 0)) != 1:
		failures.append("JsonStore did not preserve a previous payload backup")
	DirAccess.remove_absolute(global_path)
	DirAccess.remove_absolute("%s.tmp" % global_path)
	DirAccess.remove_absolute("%s.bak" % global_path)

func _check_match_supervisor_launch_config(failures: PackedStringArray) -> void:
	var supervisor = MatchSupervisorScript.new()
	var session = MatchSessionScript.new(
		"preflight_match_config",
		"preflight_room",
		"127.0.0.1",
		12345,
		["session_one", "session_two"]
	)
	if session.to_match_info("session_one").get("has_bot") != false:
		failures.append("Human-only match assignment did not disable the bot loading hint")
	var config_path: String = supervisor._write_launch_config(session)
	if config_path.is_empty():
		failures.append("MatchSupervisor failed to write a launch config")
		supervisor.free()
		return
	var loaded := JsonStoreScript.load_dictionary(config_path, {}, "preflight_probe")
	if str(loaded.get("match_id", "")) != "preflight_match_config":
		failures.append("MatchSupervisor launch config did not round-trip through JsonStore")
	session.launch_config_path = config_path
	supervisor._cleanup_launch_config(session)
	if FileAccess.file_exists(config_path) \
			or FileAccess.file_exists("%s.tmp" % config_path) \
			or FileAccess.file_exists("%s.bak" % config_path):
		failures.append("MatchSupervisor did not clean launch config artifacts")
	supervisor.free()

func _check_ranked_progression(failures: PackedStringArray) -> void:
	var progress := {}
	var season := RankedProgressionScript.season_for_time(1767225600.0)
	RankedProgressionScript.apply_result(progress, "loss", season)
	var summary := RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Iron V" or summary["last_delta"] != 0:
		failures.append("Ranked progression did not protect the entry rank")
	for _win in range(3):
		RankedProgressionScript.apply_result(progress, "win", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Iron IV" or summary["stars"] != 1 or summary["last_delta"] != 2:
		failures.append("Ranked progression did not apply the third-win bonus and promotion")
	RankedProgressionScript.apply_result(progress, "loss", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["stars"] != 1 or summary["last_delta"] != 0 or summary["win_streak"] != 0 or not summary["at_floor"]:
		failures.append("Ranked progression did not protect earned Iron stars and clear the win streak")
	for _win in range(2):
		RankedProgressionScript.apply_result(progress, "win", season)
	RankedProgressionScript.apply_result(progress, "draw", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Iron III" or summary["last_delta"] != 0 or summary["win_streak"] != 0:
		failures.append("Ranked progression did not preserve stars and clear the streak on a draw")
	for _win in range(8):
		RankedProgressionScript.apply_result(progress, "win", season)
	RankedProgressionScript.apply_result(progress, "loss", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Bronze IV" or summary["stars"] != 2 or summary["last_delta"] != 0 or not summary["at_floor"]:
		failures.append("Ranked progression did not protect earned Bronze stars")
	for _win in range(6):
		RankedProgressionScript.apply_result(progress, "win", season)
	RankedProgressionScript.apply_result(progress, "loss", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Silver V" or summary["last_delta"] != 0 or not summary["at_floor"]:
		failures.append("Ranked progression did not protect the Silver entry floor")
	RankedProgressionScript.apply_result(progress, "win", season)
	RankedProgressionScript.apply_result(progress, "loss", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Silver V" or summary["stars"] != 0 or summary["last_delta"] != -1:
		failures.append("Ranked progression did not deduct a star above the Silver floor")

	while summary["rank_name"] != "Divine" and int(progress["matches"]) < 130:
		if summary["stars_required"] != 3:
			failures.append("Ranked progression did not require three stars per division")
			break
		var rank_before: String = summary["rank_name"]
		RankedProgressionScript.apply_result(progress, "win", season)
		summary = RankedProgressionScript.summarize(progress, season)
		if summary["points"] == 60 and (rank_before != "Gold I" or summary["rank_name"] != "Diamond V" or summary["last_delta"] != 2):
			failures.append("Ranked progression did not promote Gold I directly to Diamond V with the streak bonus")
		if rank_before.begins_with("Diamond") and int(progress["last_delta"]) != 1:
			failures.append("Ranked progression applied a streak bonus in Diamond")
			break
	RankedProgressionScript.apply_result(progress, "loss", season)
	RankedProgressionScript.apply_result(progress, "draw", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Divine" or summary["points"] != 90 or summary["stars"] != 0 or summary["last_delta"] != 0:
		failures.append("Ranked progression did not reach or protect Divine at 90 stars")
	summary = RankedProgressionScript.summarize(progress, season + 2)
	if summary["rank_name"] != "Diamond V" or summary["season"] != "2026-03" or summary["matches"] != 0:
		failures.append("Ranked progression did not reset using the peak and elapsed seasons")

func _check_rank_badges(failures: PackedStringArray) -> void:
	var ranks := ["Iron V", "Bronze V", "Silver V", "Gold V", "Diamond V", "Ascendant V", "Divine"]
	var defaults := ["Wolf Cub", "Minotaur Footsoldier", "Berserker", "En-hedu-anna", "Nergal Lion", "Enki, Lord of Eridu", "Freyja"]
	for league in range(ranks.size()):
		var default_portrait := RankBadgeCatalog.resolve_portrait(league, {})
		var card: Card = RankBadgeCatalog.get_cards(league).get(defaults[league])
		if RankBadgeCatalog.league_for_rank(ranks[league]) != league or default_portrait.get("card") != defaults[league] \
				or card == null or not ResourceLoader.exists(card.art_path, "Texture2D"):
			failures.append("Rank badge default portrait or art missing for %s" % ranks[league])
	var portrait := {"card": "Wolf Cub", "art": 0, "x": 0.15, "y": 0.85, "zoom": 2.25}
	var saved := RankBadgeCatalog.validate_portrait(0, portrait)
	if saved != portrait or not RankBadgeCatalog.validate_portrait(1, portrait).is_empty() \
			or not RankBadgeCatalog.validate_portrait(0, {"card": "Wolf Cub", "x": 1.5}).is_empty() \
			or not RankBadgeCatalog.validate_portrait(0, {"card": "Wolf Cub", "art": 99}).is_empty() \
			or not RankBadgeCatalog.validate_portrait(0, {"card": "Freyja"}).is_empty() \
			or RankBadgeCatalog.validate_portrait(6, {"card": "Freyja, Active God"}).is_empty():
		failures.append("Rank badge eligibility or crop validation failed")
	var session := MatchSessionScript.new("badge_match", "badge_room", "127.0.0.1", 12345, ["seat_a", "seat_b"], {}, {
		"seat_a": {"rank_badge": {"rank_name": "Iron V", "portrait": saved}},
		"seat_b": {"rank_badge": {"rank_name": "Bronze IV"}},
	})
	var badges: Array = session.to_spectator_match_info()["rank_badges"]
	if badges.size() != 2 or badges[0].get("portrait") != portrait or badges[1].get("rank_name") != "Bronze IV" \
			or session.to_match_info("seat_b")["rank_badges"] != badges:
		failures.append("Match assignment did not preserve public rank badges in seat order")

	var account_path := ProjectSettings.globalize_path("user://preflight_badges_%d.json" % OS.get_process_id())
	var legacy_account := {"account_id": "badge_account", "username": "Badge Player", "password_salt": "test_salt", "password_hash": "test_hash"}
	if not JsonStoreScript.save_json(account_path, {"accounts_by_id": {"badge_account": legacy_account}}, "preflight_probe"):
		failures.append("Could not prepare a preflight account for rank badge persistence")
		return
	var store := BadgeTestAccountStore.new()
	store.storage_path = account_path
	var bronze := RankBadgeCatalog.validate_portrait(1, {"card": "Minotaur Footsoldier"})
	if not store.get_rank_badge("badge_account", 0).is_empty() \
			or not store.set_rank_badge("badge_account", 0, saved) or not store.set_rank_badge("badge_account", 1, bronze):
		failures.append("Could not save badge preferences for an existing account")
	var reopened := BadgeTestAccountStore.new()
	reopened.storage_path = account_path
	if RankBadgeCatalog.validate_portrait(0, reopened.get_rank_badge("badge_account", 0)) != saved \
			or RankBadgeCatalog.validate_portrait(1, reopened.get_rank_badge("badge_account", 1)) != bronze:
		failures.append("Rank badge choices or crop did not round-trip through account storage")
	if not reopened.set_rank_badge("badge_account", 0, {}):
		failures.append("Could not restore the default rank badge")
	var reset_store := BadgeTestAccountStore.new()
	reset_store.storage_path = account_path
	if not reset_store.get_rank_badge("badge_account", 0).is_empty() \
			or RankBadgeCatalog.validate_portrait(1, reset_store.get_rank_badge("badge_account", 1)) != bronze:
		failures.append("Resetting a rank badge changed preferences for another league")
	DirAccess.remove_absolute(account_path)
	DirAccess.remove_absolute(account_path + ".bak")

func _check_dedicated_ranked_history(failures: PackedStringArray) -> void:
	var storage_file := "preflight_ranked_%d.json" % OS.get_process_id()
	var storage_path := ServerPathsScript.get_server_data_file_path(storage_file)
	var result_dir := storage_path.get_basename() + "_results"
	var legacy_store := MatchHistoryStoreScript.new(storage_file)
	var writer_a := MatchHistoryStoreScript.new(storage_file, true)
	var writer_b := MatchHistoryStoreScript.new(storage_file, true)
	var reader := MatchHistoryStoreScript.new(storage_file, true)
	var session := MatchSessionScript.new("legacy", "preflight_room", "127.0.0.1", 12345, ["session_a", "session_b"], {}, {
		"session_a": {"profile_id": "profile_a", "account_id": "account_a"},
		"session_b": {"profile_id": "profile_b", "account_id": "account_b"},
	})
	legacy_store.record_completed_match(session, 0, 1, "Thor", "Odin")
	var initial_summary := reader.get_profile_summary("profile_a", 5, "account_a")
	if initial_summary["total_wins"] != 1 or initial_summary["ranked_progress"]["matches"] != 0 \
			or initial_summary["ranked_bo3_progress"]["matches"] != 0:
		failures.append("Ranked progression did not preserve legacy records without awarding stars")

	session.match_id = "ranked_a"
	var first_match := writer_a.record_completed_match(session, 0, 1, "Thor", "Odin")
	var old_entry: Dictionary = first_match["entry"]
	old_entry.erase("best_of")
	var old_result_path := result_dir.path_join("%s.json" % session.match_id.sha256_text())
	if not JsonStoreScript.save_json(old_result_path, old_entry, "preflight_probe"):
		failures.append("Could not prepare a ranked result without a stored format")
	session.match_id = "ranked_b"
	session.configure_series_format(3)
	var bo3_match := writer_b.record_completed_match(session, 0, 1, "Thor", "Odin")
	writer_a.record_completed_match(session, 1, 0, "Odin", "Thor")
	session.configure_series_format(1)
	session.match_id = "ranked_c"
	writer_a.record_completed_match(session, 0, 1, "Thor", "Odin")
	session.match_id = "ranked_d"
	var promotion_match := writer_b.record_completed_match(session, 0, 1, "Thor", "Odin")
	session.match_id = "guest"
	session.configure_series_format(3)
	session.player_identity_by_session["session_b"]["account_id"] = ""
	var guest_match := writer_b.record_completed_match(session, 0, 1, "Thor", "Odin")
	var winner_summary := reader.get_profile_summary("profile_a", 5, "account_a")
	var loser_summary := reader.get_profile_summary("profile_b", 5, "account_b")
	if winner_summary["total_wins"] != 6 or winner_summary["ranked_progress"]["matches"] != 3 \
			or winner_summary["ranked_progress"]["rank_name"] != "Iron IV" or winner_summary["ranked_progress"]["stars"] != 1 \
			or loser_summary["ranked_progress"]["matches"] != 3 or loser_summary["ranked_progress"]["stars"] != 0:
		failures.append("Dedicated ranked history lost, duplicated, or miscounted match results")
	var bo3_progress: Dictionary = winner_summary["ranked_bo3_progress"]
	if bo3_progress["matches"] != 1 or bo3_progress["win_streak"] != 1 \
			or bo3_progress["rank_name"] != "Iron V" or bo3_progress["stars"] != 1:
		failures.append("Bo3 ranked progression did not stay independent of Bo1")
	var usernames := {"account_a": "Winner", "account_b": "Opponent"}
	var bo1_ladder := reader.get_human_ladder(usernames, 1)
	var bo3_ladder := reader.get_human_ladder(usernames, 3)
	if bo1_ladder[0]["points"] != 4 or bo3_ladder[0]["points"] != 1:
		failures.append("Ladder standings did not use the requested ranked format")
	var first_results := reader.get_ranked_match_results(first_match["entry"])
	var first_win: Dictionary = first_results.get(0, {})
	var first_loss: Dictionary = first_results.get(1, {})
	if first_win.get("best_of") != 1 or first_win.get("star_delta") != 1 or first_win.get("stars") != 1 or first_win.get("rank_name") != "Iron V" \
			or first_loss.get("star_delta") != 0 or first_loss.get("stars") != 0 or first_loss.get("loss_protected") != true:
		failures.append("Ranked recap did not return each player's exact result after later matches")
	var bo3_result: Dictionary = reader.get_ranked_match_results(bo3_match["entry"]).get(0, {})
	if bo3_result.get("best_of") != 3 or bo3_result.get("previous_stars") != 0 or bo3_result.get("stars") != 1:
		failures.append("Bo3 ranked recap used progress from a different format")
	var promotion: Dictionary = reader.get_ranked_match_results(promotion_match["entry"]).get(0, {})
	if promotion.get("previous_rank_name") != "Iron V" or promotion.get("previous_stars") != 2 \
			or promotion.get("rank_name") != "Iron IV" or promotion.get("stars") != 1 or promotion.get("star_delta") != 2:
		failures.append("Ranked recap did not report both sides of a promotion with carryover stars")
	if not reader.get_ranked_match_results(guest_match["entry"]).is_empty():
		failures.append("Ranked recap awarded stars for an ineligible match")
	var reopened := MatchHistoryStoreScript.new(storage_file, true)
	var reopened_summary := reopened.get_profile_summary("profile_a", 5, "account_a")
	if reopened_summary["ranked_progress"] != winner_summary["ranked_progress"] \
			or reopened_summary["ranked_bo3_progress"] != bo3_progress:
		failures.append("Dedicated ranked history did not restore progress after reopening the store")
	DirAccess.remove_absolute(old_result_path + ".bak")
	for match_id in ["ranked_a", "ranked_b", "ranked_c", "ranked_d", "guest"]:
		DirAccess.remove_absolute(result_dir.path_join("%s.json" % match_id.sha256_text()))
	DirAccess.remove_absolute(result_dir)
	DirAccess.remove_absolute(storage_path)

func _check_ranked_bot_deck_generation(failures: PackedStringArray) -> void:
	var factory := PracticeAutofillDeckFactory.new()
	var thor := Thor.new()
	for legendary in [false, true]:
		var candidates := factory._get_regular_candidates(thor, {}, legendary, true)
		var expected := "Circle of Rebirth" if legendary else "Fall of the Mighty"
		if not candidates.any(func(card: Card) -> bool: return card.card_name == expected):
			failures.append("Ranked bot decks cannot generate %s" % expected)

	var deck := factory.build_random_deck(1337, TiamatThePrimordial.TIAMAT_CARD_NAME, true)
	var player := Player.new()
	if deck.is_empty() or not DeckBuilder.new().build_deck(player, _cards_from_counts(deck["cards"]), deck["special_setup"]):
		failures.append("Ranked bot generator did not produce a legal Tiamat deck")
		return
	for zone in player.power_zones:
		if zone.cards.is_empty() or not zone.cards.all(TiamatThePrimordial.is_valid_slot_creature):
			failures.append("Ranked Tiamat did not fill all three Brood slots")
			return

	var game_manager := GameManager.new()
	var opponent := Player.new()
	game_manager.players.assign([player, opponent])
	game_manager.current_player = player
	game_manager.other_player = opponent
	game_manager.start_turn()
	var match_manager := MatchManager.new(game_manager)
	var bot := PracticeFuzzPlayerBot.new()
	bot.attach(game_manager, match_manager, ServerBotGameInput.new(match_manager, 0), 0)
	var deck_size := player.deck_zone.cards.size()
	bot._handle_upkeep()
	bot.detach()
	if player.hand_zone.cards.size() != 1 or player.deck_zone.cards.size() != deck_size \
			or player.mana != 0 or not game_manager.has_resolved_turn_upkeep():
		failures.append("Ranked Tiamat did not use Matriarch Rule to take a Brood creature on turn one")

func _check_ranked_bot_manifestations(failures: PackedStringArray) -> void:
	var factory := PracticeAutofillDeckFactory.new()
	for god in factory._gods:
		for legendary in [false, true]:
			var candidates := factory._get_regular_candidates(god, {}, legendary, true)
			for card in CardCatalogScript.get_cached_card_templates():
				if card is ActiveGodCard and card.is_legendary == legendary:
					var allowed: bool = (god is Odin or god is TiamatThePrimordial) \
						and card.culture == god.culture and not god.is_own_active_god_card(card)
					if candidates.any(func(candidate: Card) -> bool: return candidate.card_name == card.card_name) != allowed:
						failures.append("Unexpected ranked deck eligibility for %s under %s" % [card.card_name, god.card_name])
	var freyja_powers := factory._get_power_candidates(Freyja.new(), {}, true)
	if not freyja_powers.any(func(card: Card) -> bool: return card is TakeTheField):
		failures.append("Take the Field was unavailable to a ranked god with a matching Active God")
	for god in [Thor.new(), GuanYu.new(), TezcatlipocaTheSmokingMirror.new(), Odin.new()]:
		var powers := factory._get_power_candidates(god, {}, true)
		if powers.any(func(card: Card) -> bool: return card is TakeTheField):
			failures.append("Take the Field was offered in the ranked power pool for %s" % god.card_name)
	var mixed_tiamat_deck := false
	for seed_value in range(12):
		var deck := factory.build_random_deck(seed_value, TiamatThePrimordial.TIAMAT_CARD_NAME, true)
		if deck.get("cards", {}).get("Take the Field", 0) == 1:
			var slots := TiamatThePrimordial.get_slot_card_names_from_setup(deck["special_setup"])
			mixed_tiamat_deck = not slots[0].is_empty() and not slots[1].is_empty() and slots[2].is_empty()
			break
	if not mixed_tiamat_deck:
		failures.append("Ranked Tiamat did not generate a legal deck with two Brood slots and Take the Field")

	var gods: Array[GodCard] = [Thor.new(), GuanYu.new(), TiamatThePrimordial.new(), TezcatlipocaTheSmokingMirror.new()]
	for god in gods:
		var game_manager := GameManager.new()
		var player := Player.new()
		var opponent := Player.new()
		game_manager.players.assign([player, opponent])
		game_manager.current_player = player
		game_manager.other_player = opponent
		game_manager.start_turn()
		game_manager.player_chooses_upkeep_only()
		# Ranked bots now reserve Active God manifestations for a turn where
		# the resulting creature can take a meaningful attack.
		game_manager.turn_number = 2
		game_manager._upkeep_started_turn = game_manager.turn_number
		game_manager._upkeep_resolved_turn = game_manager.turn_number
		var match_manager := MatchManager.new(game_manager)
		var bot := PracticeFuzzPlayerBot.new()
		bot.attach(game_manager, match_manager, ServerBotGameInput.new(match_manager, 0), 0)
		god.card_owner = player
		player.god_zone.add_card(god)
		if god is Thor or god is GuanYu:
			player.mana = god.get_champions_call_candidate().mana_cost - GodCard.CHAMPIONS_CALL_SHELVE_MANA_VALUE
			var valuable := EnkiLordOfEridu.new()
			var shelve := BrownBear.new()
			for card in [valuable, shelve]:
				card.card_owner = player
				player.hand_zone.add_card(card)
			bot._submit_strategy_plan(bot._plan_god_manifestation())
			for _step in range(8):
				match_manager.advance_priority()
			if shelve.current_zone != player.deck_zone or valuable.current_zone != player.hand_zone or player.mana != 0:
				failures.append("Champion's Call did not shelve the lower-value card and pay the rest in mana")
		elif god is TiamatThePrimordial:
			player.mana = TiamatActive.new().mana_cost
			var birth_target := Asakku.new()
			birth_target.card_owner = player
			player.hand_zone.add_card(birth_target)
			var power := TakeTheField.new()
			power.card_owner = player
			player.power_zones[2].add_card(power)
			bot._submit_strategy_plan(bot._plan_power_unlock())
			if power.is_face_down or player.mana != 0:
				failures.append("Take the Field did not pay for and unlock Tiamat's manifestation")
			for _step in range(8):
				match_manager.advance_priority()
			if not bot._get_board_creatures(player).has(birth_target):
				failures.append("Ranked Tiamat did not use Birth after Take the Field")
		elif god is TezcatlipocaTheSmokingMirror:
			var offerings: Array[Card] = []
			for i in range(TezcatlipocaTheSmokingMirror.REQUIRED_NECOC_YAOTL_SACRIFICES + 1):
				var offering := Asakku.new()
				offering.card_owner = player
				player.reserve_zones[i].add_card(offering)
				offering.spend_major_creature_action()
				offerings.append(offering)
			var victim := BrownBear.new()
			victim.card_owner = opponent
			opponent.frontline_zones[0].add_card(victim)
			for offering in offerings.slice(2):
				offering.current_zone.remove_card(offering)
			if not bot._plan_god_manifestation().is_empty():
				failures.append("Necoc Yaotl sacrificed an ordinary creature without spare board presence")
			for i in range(2, offerings.size()):
				player.reserve_zones[i].add_card(offerings[i])
			for _action in range(TezcatlipocaTheSmokingMirror.REQUIRED_NECOC_YAOTL_SACRIFICES + 1):
				bot._submit_strategy_plan(bot._plan_god_manifestation())
				for _step in range(8):
					match_manager.advance_priority()
			if victim.get_controller() != player:
				failures.append("Necoc Yaotl did not complete Titlacauan with the stored sacrifices")
		if god.current_zone == player.god_zone or not bot._get_board_creatures(player).any(func(card: Card) -> bool:
			return card is ActiveGodCard and god.is_own_active_god_card(card)
		):
			failures.append("Ranked bot failed to summon the matching Active God for %s" % god.card_name)
		bot.detach()
		match_manager.reset_runtime_state()
		game_manager.action_stack.clear()
		for seat in game_manager.players:
			for zone in [seat.god_zone, seat.hand_zone, seat.deck_zone, seat.graveyard_zone, seat.abyss_zone] + seat.power_zones + seat.frontline_zones + seat.reserve_zones:
				for card in zone.cards.duplicate():
					zone.remove_card(card)
				zone.zone_owner = null

func _check_bot_power_followthrough(failures: PackedStringArray) -> void:
	var game := GameManager.new()
	var player := Player.new()
	var opponent := Player.new()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.start_turn()
	game.player_chooses_upkeep_only()
	var manager := MatchManager.new(game)
	var bot := PracticeFuzzPlayerBot.new()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var factory := MechFactory.new()
	factory.card_owner = player
	player.power_zones[0].add_card(factory)

	player.mana = MechFactory.UNLOCK_COST + MechFactory.ACTIVATION_COST - 1
	if not bot._plan_power_unlock().is_empty():
		failures.append("Bot planned to unlock Mech Factory without enough mana to build a Mech")

	player.mana += 1
	var plan := bot._plan_power_unlock()
	if plan.get("activate_after_unlock_uid") != factory.uid or not bot._submit_strategy_plan(plan):
		failures.append("Bot did not plan a funded Mech Factory unlock and activation")
	elif not bot._take_main_phase_action():
		failures.append("Bot did not follow through after unlocking Mech Factory")
	else:
		for _step in range(8):
			manager.advance_priority()
		if factory.activations_this_turn != 1 or player.mana != 0:
			failures.append("Bot's Mech Factory follow-up did not resolve through the match command path")

	var palisade := PalisadePower.new()
	palisade.card_owner = player
	player.power_zones[1].add_card(palisade)
	player.mana = PalisadePower.UNLOCK_COST + PalisadePower.ACTIVATION_COST
	if not bot._plan_power_unlock().is_empty():
		failures.append("Bot unlocked Palisade with no enemy attack pressure")
	bot.detach()

func _check_bot_summon_and_intercept(failures: PackedStringArray) -> void:
	var game := GameManager.new()
	var player := Player.new()
	var opponent := Player.new()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 2
	var manager := MatchManager.new(game)
	var bot := PracticeFuzzPlayerBot.new()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var enki := EnkiLordOfEridu.new()
	enki.card_owner = opponent
	enki.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(enki)
	var berserker := Berserker.new()
	berserker.card_owner = opponent
	berserker.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[1].add_card(berserker)
	var mech := DevastatorMech.new()
	mech.card_owner = player
	player.hand_zone.add_card(mech)
	var plan := bot._plan_creature_summon()
	var command: Dictionary = plan.get("command", {})
	if command.get("card_uid") != mech.uid or command.get("mode") != Card.CreatureMode.AGGRESSIVE:
		failures.append("Bot overlooked a Devastator Mech summon with Berserker available to attack alongside Enki")
	player.hand_zone.remove_card(mech)
	player.frontline_zones[0].add_card(mech)
	mech.creature_mode = Card.CreatureMode.AGGRESSIVE
	var attack := bot._plan_combat(bot._get_combat_candidates())
	if attack.get("target") != berserker:
		failures.append("Bot did not choose Berserker over Enki and a less valuable direct attack")
	var intercept := {"attacker_uid": enki.uid, "target_uid": "0", "interceptor_uids": [mech.uid]}
	player.followers = 12
	if bot._choose_interceptor(intercept) != mech.uid:
		failures.append("Bot declined to lose its Mech to intercept a lethal follower attack it could survive")
	player.followers = 8
	if not bot._choose_interceptor(intercept).is_empty():
		failures.append("Bot chose a losing interception that still allowed lethal follower damage")
	bot.detach()

func _check_bot_main_phase_combat_order(failures: PackedStringArray) -> void:
	var game := GameManager.new()
	var player := Player.new()
	var opponent := Player.new()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 5
	var manager := MatchManager.new(game)
	var bot := PracticeFuzzPlayerBot.new()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var veteran := CreatureCard.new()
	veteran.card_owner = player
	veteran.strength = 20
	veteran.speed = 4
	veteran.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(veteran)
	var recruit := CreatureCard.new()
	recruit.card_owner = player
	recruit.strength = 8
	recruit.speed = 3
	recruit.mana_cost = 1
	player.hand_zone.add_card(recruit)
	var blocker := CreatureCard.new()
	blocker.card_owner = opponent
	blocker.strength = 10
	blocker.resilience = 12
	blocker.speed = 5
	blocker.creature_mode = Card.CreatureMode.DEFENSIVE
	opponent.frontline_zones[0].add_card(blocker)
	if not bot._take_main_phase_action() or recruit.current_zone not in player.frontline_zones \
			or recruit.creature_mode != Card.CreatureMode.AGGRESSIVE or game.has_resolved_attack_this_turn:
		failures.append("Bot attacked before summoning a second creature that could hit followers after the blocker fell")
	else:
		for _step in range(8):
			manager.advance_priority()
		var fight := bot._plan_combat(bot._get_combat_candidates())
		if fight.get("attacker") != veteran or fight.get("target") != blocker:
			failures.append("Bot did not use the stronger creature to clear the blocker after summoning")
		elif not bot._take_main_phase_action():
			failures.append("Bot did not submit the attack that clears the blocker")
		else:
			for _step in range(8):
				manager.advance_priority()
			var followers := opponent.followers
			if blocker.current_zone != opponent.graveyard_zone or not bot._take_main_phase_action():
				failures.append("Bot did not follow up with the newly summoned creature")
			else:
				for _step in range(8):
					manager.advance_priority()
				if opponent.followers != followers - recruit.strength:
					failures.append("Summoning first did not deliver the projected follower damage")
	bot.detach()

	game = GameManager.new()
	player = Player.new()
	opponent = Player.new()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 5
	manager = MatchManager.new(game)
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	recruit = CreatureCard.new()
	recruit.card_owner = player
	recruit.strength = 15
	recruit.resilience = 25
	recruit.mana_cost = 2
	player.hand_zone.add_card(recruit)
	blocker = CreatureCard.new()
	blocker.card_owner = opponent
	blocker.strength = 22
	blocker.speed = 5
	blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(blocker)
	var fall := FallOfTheMighty.new()
	fall.card_owner = player
	player.hand_zone.add_card(fall)
	if not bot._take_main_phase_action() or recruit.current_zone != player.hand_zone:
		failures.append("Bot summoned before Fall of the Mighty could clear the stronger creature")
	else:
		for _step in range(8):
			manager.advance_priority()
		if blocker.current_zone != opponent.graveyard_zone or not bot._take_main_phase_action() \
				or recruit.current_zone not in player.frontline_zones or recruit.creature_mode != Card.CreatureMode.AGGRESSIVE:
			failures.append("Bot did not follow Fall of the Mighty with a summon ready to attack")
	bot.detach()

func _check_bot_hermes_speed(failures: PackedStringArray) -> void:
	var game := GameManager.new()
	var player := Player.new()
	var opponent := Player.new()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 2
	var manager := MatchManager.new(game)
	var bot := PracticeFuzzPlayerBot.new()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var hermes := Hermes.new()
	hermes.card_owner = player
	player.god_zone.add_card(hermes)
	var attacker := CreatureCard.new()
	attacker.card_owner = player
	attacker.strength = 20
	attacker.speed = 2
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(attacker)
	var blocker := CreatureCard.new()
	blocker.card_owner = opponent
	blocker.strength = 8
	blocker.speed = 3
	blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(blocker)
	var attacks := bot._get_combat_candidates()
	if not bot._plan_hermes_speed(attacks, bot._plan_combat(attacks)).is_empty():
		failures.append("Hermes paid for a faster follower attack when the unbuffed frontline attack was already better")
	var shield := VoidShield.new()
	shield.card_owner = opponent
	shield.is_face_down = true
	shield.is_prepared = true
	opponent.reserve_zones[0].add_card(shield)
	game.prepared_hexes[shield] = game.turn_number - 1
	attacks = bot._get_combat_candidates()
	if not bot._plan_hermes_speed(attacks, bot._plan_combat(attacks)).is_empty():
		failures.append("Hermes used private information to outrun an unidentified prepared card")
	shield.add_status_effect("publicly_revealed", "Preflight")
	attacks = bot._get_combat_candidates()
	var speed_plan := bot._plan_hermes_speed(attacks, bot._plan_combat(attacks))
	if speed_plan.get("command", {}).get("target_uid") != attacker.uid:
		failures.append("Hermes did not outrun a known Void Shield when that improved the attack line")
	attacker.speed = 4
	attacks = bot._get_combat_candidates()
	if not bot._plan_hermes_speed(attacks, bot._plan_combat(attacks)).is_empty():
		failures.append("Hermes paid for speed even though the attacker already outran Void Shield")
	bot.detach()

func _check_bot_combat_buff_value(failures: PackedStringArray) -> void:
	var game := GameManager.new()
	var player := Player.new()
	var opponent := Player.new()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	var manager := MatchManager.new(game)
	var bot := PracticeFuzzPlayerBot.new()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var enkidu := Enkidu.new()
	enkidu.card_owner = player
	enkidu.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(enkidu)
	var asaruludu := Asaruludu.new()
	asaruludu.card_owner = opponent
	asaruludu.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(asaruludu)
	var first := FifaTheMagicalArrow.new()
	first.card_owner = player
	player.hand_zone.add_card(first)
	var second := FifaTheMagicalArrow.new()
	second.card_owner = player
	player.hand_zone.add_card(second)
	var attack := CardAction.new()
	attack.type = CardAction.Type.ATTACK
	attack.source_player = player
	attack.attacker = enkidu
	attack.target = asaruludu
	if int(bot._score_priority_card(first, attack, -1)["score"]) <= 0:
		failures.append("Bot did not value Fifa turning Enkidu's loss into a win")
	asaruludu.strength = 34
	var planned := bot._get_best_supported_attack([enkidu], [asaruludu])
	if planned.get("target") != asaruludu:
		failures.append("Bot did not see the two-Fifa combat line before declaring the attack")
	game.push_to_stack(attack)
	game.pass_priority()
	if bot._choose_priority_response() not in [first, second]:
		failures.append("Bot would not start the predicted two-Fifa combat line")
	game.action_stack.clear()
	asaruludu.strength = 28
	var pending := CardAction.new()
	pending.type = CardAction.Type.SPELL
	pending.source_player = player
	pending.card = first
	pending.target = enkidu
	game.push_to_stack(pending)
	game.pass_priority()
	if bot._choose_priority_response() != null:
		failures.append("Bot stacked another Fifa before the first one resolved")
	game.action_stack.push_front(attack)
	pending.response_to = attack
	opponent.followers = 8
	if bot._choose_priority_response() != second:
		failures.append("Bot did not anticipate lethal from both Fifas while the first was pending")
	if enkidu.get_effective_strength() != enkidu.strength:
		failures.append("Projecting pending buffs changed Enkidu's live stats")
	opponent.followers = 100
	asaruludu.strength = 34
	if bot._choose_priority_response() != second:
		failures.append("Bot did not anticipate that stacking two Fifas would flip the fight")
	asaruludu.strength = 28
	if bot._choose_priority_response() != null:
		failures.append("Bot stacked a second Fifa for nonlethal damage in a pending attack")
	game.action_stack.clear()
	first.resolve(game, enkidu)
	if int(bot._score_priority_card(second, attack, -1)["score"]) > 0:
		failures.append("Bot spent a second Fifa for five nonlethal followers after the fight was already won")
	opponent.followers = 8
	if int(bot._score_priority_card(second, attack, -1)["score"]) <= 0:
		failures.append("Bot did not value a second Fifa when the extra damage was lethal")
	bot.detach()

func _check_bot_reveal_defense(failures: PackedStringArray) -> void:
	var game := GameManager.new()
	var player := Player.new()
	var opponent := Player.new()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game.has_resolved_attack_this_turn = true
	player.followers = 15
	var manager := MatchManager.new(game)
	var bot := PracticeFuzzPlayerBot.new()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var priest := MasmassuPriest.new()
	priest.card_owner = player
	player.hand_zone.add_card(priest)
	var chump := CreatureCard.new()
	chump.card_owner = player
	chump.strength = 14
	chump.resilience = 6
	chump.speed = 2
	player.hand_zone.add_card(chump)
	var first := CreatureCard.new()
	first.card_owner = opponent
	first.creature_mode = Card.CreatureMode.AGGRESSIVE
	first.strength = 24
	first.speed = 1
	opponent.frontline_zones[0].add_card(first)
	var second := CreatureCard.new()
	second.card_owner = opponent
	second.creature_mode = Card.CreatureMode.AGGRESSIVE
	second.strength = 20
	second.speed = 1
	opponent.frontline_zones[1].add_card(second)
	var danger := bot._forecast_incoming_follower_loss()
	var command: Dictionary = bot._plan_creature_summon(danger).get("command", {})
	if danger < player.followers or command.get("card_uid") != priest.uid or not command.get("stealth", false):
		failures.append("Bot failed to choose the Stealth Priest over a plain blocker against two lethal attackers")
	first.speed = 2
	second.speed = 2
	command = bot._plan_creature_summon(danger).get("command", {})
	if command.get("card_uid") != chump.uid:
		failures.append("Bot credited the Priest with an interception against attackers it could not catch")
	player.hand_zone.remove_card(priest)
	player.frontline_zones[0].add_card(priest)
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.attacker = first
	action.target = player
	action.interceptor = priest
	manager.pending_combat_reveal_linger_action = action
	var reveal_command := BotCardPromptPolicy.build_command(bot, "masmassu_priest_reveal", {
		"source_uid": priest.uid, "target_uids": [first.uid, second.uid],
	})
	if reveal_command.get("target_uid") != second.uid:
		failures.append("Bot targeted the committed attacker with Dalkhu Break instead of stopping the lethal follow-up")
	player.frontline_zones[0].remove_card(priest)
	player.hand_zone.remove_card(chump)
	var beast := PictishBeast.new()
	beast.card_owner = player
	player.hand_zone.add_card(beast)
	opponent.frontline_zones[1].remove_card(second)
	first.speed = 1
	command = bot._plan_creature_summon(bot._forecast_incoming_follower_loss()).get("command", {})
	if command.get("card_uid") != beast.uid or not command.get("stealth", false):
		failures.append("Bot failed to include Pictish Beast's Mana Boon in its defensive summon")
	bot.detach()

func _check_bot_next_turn_lethal(failures: PackedStringArray) -> void:
	var game := GameManager.new()
	var player := Player.new()
	var opponent := Player.new()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.followers = 10
	player.mana = 3
	var manager := MatchManager.new(game)
	var bot := PracticeFuzzPlayerBot.new()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var attacker := CreatureCard.new()
	attacker.card_owner = opponent
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.strength = 20
	opponent.frontline_zones[0].add_card(attacker)
	var weak := CreatureCard.new()
	weak.card_owner = player
	weak.creature_mode = Card.CreatureMode.AGGRESSIVE
	weak.strength = 5
	player.frontline_zones[0].add_card(weak)
	var defender := CreatureCard.new()
	defender.card_owner = player
	defender.creature_mode = Card.CreatureMode.DEFENSIVE
	defender.resilience = 25
	player.frontline_zones[1].add_card(defender)
	var mummu := Mummu.new()
	mummu.card_owner = player
	player.god_zone.add_card(mummu)
	var danger := bot._forecast_incoming_follower_loss()
	if danger < player.followers or bot._forecast_incoming_follower_loss({"removed": [weak]}) >= player.followers:
		failures.append("Bot did not distinguish lethal through a weak aggressive creature from a covered direct attack")
	var stance: Dictionary = bot._plan_defensive_stance(danger).get("command", {})
	if stance.get("card_uid") != weak.uid:
		failures.append("Bot did not identify a defensive stance change that prevents lethal")
	weak.creature_major_action_used = true
	weak.creature_minor_actions_used = weak.get_max_minor_creature_actions_per_turn()
	var entropic: Dictionary = bot._plan_removal_god_ability(danger).get("command", {})
	if entropic.get("target_uid") != weak.uid:
		failures.append("Mummu failed to shelve the exposed creature when it could not change stance")
	elif not bot._take_main_phase_action():
		failures.append("Mummu did not submit the Entropic Force survival plan")
	else:
		for _step in range(8):
			manager.advance_priority()
		if weak.current_zone != player.deck_zone:
			failures.append("Entropic Force survival plan did not resolve through the match command path")
		else:
			player.move_card(weak, player.frontline_zones[0])
			weak.creature_mode = Card.CreatureMode.AGGRESSIVE
			weak.creature_major_action_used = true
			weak.creature_minor_actions_used = weak.get_max_minor_creature_actions_per_turn()
	player.god_zone.remove_card(mummu)
	var tez := TezcatlipocaTheSmokingMirror.new()
	tez.card_owner = player
	player.god_zone.add_card(tez)
	var offering: Dictionary = bot._plan_god_manifestation({}, danger).get("command", {})
	if offering.get("target_uid") != weak.uid:
		failures.append("Necoc Yaotl failed to sacrifice the creature exposing its followers to lethal")
	player.god_zone.remove_card(tez)
	var spell := BitMeseri.new()
	spell.card_owner = player
	player.hand_zone.add_card(spell)
	var alternative := CreatureCard.new()
	alternative.card_owner = opponent
	alternative.creature_mode = Card.CreatureMode.AGGRESSIVE
	alternative.strength = 15
	opponent.frontline_zones[1].add_card(alternative)
	var bit_meseri: Dictionary = bot._get_best_strategy_action([], {}, danger).get("command", {})
	if bit_meseri.get("target_uid") != weak.uid:
		failures.append("Bot failed to consider voiding its own creature when removing either individual attacker still leaves lethal")
	player.guard = 15
	if bot._forecast_incoming_follower_loss() >= player.followers:
		failures.append("Bot forecast lethal even though Guard and the defensive creature cover both attacks")
	player.guard = 0
	if not bot._take_main_phase_action():
		failures.append("Bot did not submit the Bit Meseri survival plan")
	else:
		for _step in range(8):
			manager.advance_priority()
		if weak.current_zone != player.abyss_zone:
			failures.append("Bit Meseri survival plan did not resolve through the match command path")
		else:
			player.move_card(weak, player.frontline_zones[0])
			weak.creature_mode = Card.CreatureMode.AGGRESSIVE
			weak.creature_major_action_used = true
			weak.creature_minor_actions_used = weak.get_max_minor_creature_actions_per_turn()
	var nimue := Nimue.new()
	player.mana = 3
	player.god_zone.add_card(mummu)
	mummu.is_muted = true
	nimue.card_owner = player
	nimue.creature_mode = Card.CreatureMode.DEFENSIVE
	player.reserve_zones[0].add_card(nimue)
	var entomb_plan := bot._get_best_strategy_action([], {}, danger)
	var entomb: Dictionary = entomb_plan.get("command", {})
	if entomb.get("source_uid") != nimue.uid or entomb.get("target_uid") != weak.uid:
		failures.append("Nimue did not consider shelving her own exposed creature")
	elif not bot._submit_strategy_plan(entomb_plan):
		failures.append("Nimue's Entomb survival plan was rejected")
	else:
		for _step in range(8):
			manager.advance_priority()
		if weak.current_zone != player.deck_zone:
			failures.append("Nimue's Entomb survival plan did not resolve")
		else:
			player.move_card(weak, player.frontline_zones[0])
			weak.creature_mode = Card.CreatureMode.AGGRESSIVE
			weak.creature_major_action_used = true
			weak.creature_minor_actions_used = weak.get_max_minor_creature_actions_per_turn()
	player.reserve_zones[0].remove_card(nimue)
	var pyre := AncientPyre.new()
	pyre.card_owner = player
	player.frontline_zones[2].add_card(pyre)
	weak.resilience = AncientPyre.EFFECT_AMOUNT
	var flame: Dictionary = bot._get_best_strategy_action([], {}, danger).get("command", {})
	if flame.get("source_uid") != pyre.uid or flame.get("target_uid") != weak.uid:
		failures.append("Ancient Pyre did not consider destroying its own exposed creature")
	weak.resilience += 1
	if bot._effect_follower_safety_gain(pyre, weak, danger) != 0:
		failures.append("Ancient Pyre was credited with destroying a creature above its damage threshold")
	weak.resilience -= 1
	weak.add_status_effect("berserker_mead_guard", "Preflight")
	if bot._effect_follower_safety_gain(pyre, weak, danger) != 0:
		failures.append("Ancient Pyre was credited with destroying a protected creature")
	weak.remove_status_effects_by_name("berserker_mead_guard")
	player.frontline_zones[2].remove_card(pyre)
	weak.card_types.append("Animal")
	var offering_bear := BrownBear.new()
	offering_bear.card_owner = player
	player.reserve_zones[1].add_card(offering_bear)
	var demon := Asakku.new()
	demon.card_owner = player
	player.graveyard_zone.add_card(demon)
	var key := KeyOfSolomon.new()
	key.card_owner = player
	player.hand_zone.add_card(key)
	var sacrifice_plan: Dictionary = bot._plan_sacrifice_spell(key, danger).get("command", {})
	if sacrifice_plan.get("sacrifice_uid") != weak.uid:
		failures.append("A sacrifice spell did not choose the friendly payment that prevents lethal")
	player.hand_zone.remove_card(key)
	player.reserve_zones[1].remove_card(offering_bear)
	var fenrir := Fenrir.new()
	fenrir.card_owner = player
	player.reserve_zones[0].add_card(fenrir)
	var impact := bot._choose_impact_removal_target(fenrir, [weak.uid, attacker.uid, alternative.uid])
	if impact != weak.uid:
		failures.append("Fenrir's removal prompt did not choose the friendly target that prevents lethal")
	player.reserve_zones[0].remove_card(fenrir)
	var ragnarok := Ragnarok.new()
	ragnarok.card_owner = player
	player.power_zones[0].add_card(ragnarok)
	player.mana = ragnarok.get_unlock_mana_cost(game)
	var wipe: Dictionary = bot._plan_power_unlock(danger).get("command", {})
	if wipe.get("power_uid") != ragnarok.uid:
		failures.append("Bot overlooked a legal Ragnarok unlock that prevents lethal")
	bot.detach()

func _check_standing_bot_seeks(failures: PackedStringArray) -> void:
	var lobby := LobbyServerScript.new()
	lobby.is_listening = true
	lobby.match_history_store = MatchHistoryStoreScript.new("preflight_standing_bot_seeks_%d.json" % OS.get_process_id(), true)
	lobby._ensure_server_bot_seeks()
	lobby._ensure_server_bot_seeks()
	var open_formats: Array[bool] = []
	for entry: Dictionary in lobby._build_room_list():
		if entry["host_is_bot"] and entry["member_count"] == 1:
			open_formats.append(entry["is_ranked"])
			if entry.has("bot_stars"):
				failures.append("Open bot challenge advertised a rank before matchmaking")
	if open_formats.size() != 2 or true not in open_formats or false not in open_formats:
		failures.append("Lobby did not maintain exactly one open rated and one open unrated bot seek")
	lobby.free()

func _check_request_next(failures: PackedStringArray) -> void:
	var lobby := RequestNextLobby.new()
	var supervisor := MatchSupervisorScript.new()
	lobby.match_supervisor = supervisor
	var target: Dictionary = lobby._create_session("Playing", 2, false, "", "target_account")
	var viewer: Dictionary = lobby._create_session("Challenger", 3, false, "", "viewer_account")
	var same_account: Dictionary = lobby._create_session("Playing", 4, false, "", "target_account")
	var room := LobbyRoom.new("NEXT", "BOT_A")
	room.add_member("BOT_A")
	room.add_member(target["session_id"])
	room.status = LobbyRoom.STATUS_IN_MATCH
	room.assigned_match_id = "match_next"
	lobby.rooms_by_id[room.room_id] = room
	var session := MatchSessionScript.new(room.assigned_match_id, room.room_id, "127.0.0.1", 12345, room.members, {}, {
		"BOT_A": {"player_name": "Thor"},
		target["session_id"]: {"player_name": "Playing"},
	})
	session.mark_active()
	session.server_mode = MatchSessionScript.SERVER_MODE_DEDICATED_HEADLESS
	session.status_file_path = "user://preflight_request_next_%d.json" % OS.get_process_id()
	supervisor.active_matches[session.match_id] = session
	if lobby._build_room_list(viewer["session_id"])[0].has("request_next_match_id"):
		failures.append("Request Next was advertised before the dedicated match started")
	if not JsonStoreScript.save_json(session.status_file_path, {"status": MatchSessionScript.STATUS_ACTIVE}, "preflight_probe"):
		failures.append("Could not write Request Next match status")
	var entry: Dictionary = lobby._build_room_list(viewer["session_id"])[0]
	if entry.get("request_next_match_id") != session.match_id or entry.get("match_player_names") != ["Thor", "Playing"] \
			or lobby._build_room_list(same_account["session_id"])[0].has("request_next_match_id") \
			or lobby._build_room_list()[0].has("request_next_match_id"):
		failures.append("Request Next was not advertised only to eligible viewers")
	var request := LobbyProtocol.make_message(LobbyProtocol.REQUEST_NEXT, {"match_id": session.match_id})
	lobby._handle_request(3, request)
	if lobby.events.size() != 2 \
			or lobby.events[0] != {"peer": 2, "type": LobbyProtocol.REQUEST_NEXT_RECEIVED, "payload": {"requester_name": "Challenger"}} \
			or lobby.events[1]["peer"] != 3 or lobby.events[1]["type"] != LobbyProtocol.REQUEST_NEXT_RESULT:
		failures.append("Request Next did not privately notify the player and confirm to the requester")
	lobby.events.clear()
	lobby._handle_request(3, request)
	lobby._handle_request(4, request)
	lobby._handle_request(5, request)
	if lobby.events.size() != 3 or lobby.events.any(func(event: Dictionary) -> bool: return event["type"] != LobbyProtocol.REQUEST_NEXT_RESULT) \
			or lobby._build_room_list(viewer["session_id"])[0].has("request_next_match_id"):
		failures.append("Request Next permitted a duplicate, self-request, or unauthenticated request")
	session.next_requests_by_account.clear()
	var finished_status := {
		"status": MatchSessionScript.STATUS_FINISHED,
		"waiting_for_reconnect": true,
		"reconnect_deadline_unix": int(Time.get_unix_time_from_system()) + 60,
	}
	if not JsonStoreScript.save_json(session.status_file_path, finished_status, "preflight_probe"):
		failures.append("Could not write finished Request Next match status")
	lobby.events.clear()
	lobby._handle_request(3, request)
	if not lobby._build_room_list(target["session_id"])[0]["viewer_can_rejoin"] \
			or lobby.events.size() != 1 or lobby.events[0]["type"] != LobbyProtocol.REQUEST_NEXT_RESULT \
			or lobby._build_room_list(viewer["session_id"])[0].has("request_next_match_id"):
		failures.append("Request Next did not distinguish a finished match from a rejoinable match")
	DirAccess.remove_absolute(session.status_file_path)
	DirAccess.remove_absolute(session.status_file_path + ".bak")
	supervisor.free()
	lobby.free()

func _check_ladder_pages(failures: PackedStringArray) -> void:
	var account_path := ProjectSettings.globalize_path("user://preflight_ladder_%d.json" % OS.get_process_id())
	var accounts := {}
	var player_count := NetworkManagerScript.MAX_NETWORK_PAYLOAD_ITEMS + 1
	var portrait := {"card": "Wolf Cub", "art": 0, "x": 0.2, "y": 0.75, "zoom": 2.125}
	for index in range(player_count):
		var account_id := "account_%d" % index
		accounts[account_id] = {"account_id": account_id, "username": "Player %03d" % index,
			"password_salt": "test_salt", "password_hash": "test_hash"}
		if index > 1:
			accounts[account_id]["rank_badges"] = {"0": portrait}
	accounts["account_1"]["rank_badges"] = {"0": {"card": "Freyja"}}
	if not JsonStoreScript.save_json(account_path, {"accounts_by_id": accounts}, "preflight_probe"):
		failures.append("Could not prepare ladder page test accounts")
		return
	var store := BadgeTestAccountStore.new()
	store.storage_path = account_path
	var lobby := LobbyServerScript.new()
	lobby.account_store = store
	var storage_file := "preflight_ladder_history_%d.json" % OS.get_process_id()
	var history := MatchHistoryStoreScript.new(storage_file, true)
	lobby.match_history_store = history
	var session := MatchSessionScript.new("ladder_bot_win", "preflight_room", "127.0.0.1", 12345, ["BOT_A", "human"], {
		"BOT_A": {"bot_god_name": "Thor", "cards": {"Thor": 1, "Berserker": 3}},
	}, {"human": {"account_id": "account_0"}})
	history.record_completed_match(session, 0, 1, "Thor", "Odin")
	var network := NetworkManagerScript.new()
	var names := {}
	var bot_count := 0
	var portraits_valid := true
	var capped_entry_count := mini(player_count + 1, 100)
	var last_page := ceili(float(capped_entry_count) / LobbyProtocolScript.LADDER_PAGE_SIZE) - 1
	for page in range(last_page + 1):
		var summary := lobby._build_ladder_page({"best_of": 1, "request_id": page, "page": page})
		var message := LobbyProtocolScript.make_message(LobbyProtocolScript.BOT_LADDER, summary)
		if summary["request_id"] != page or summary["page"] != page or summary["last_page"] != last_page \
				or not network.get_game_event_payload_rejection_reason("__lobby_event__", message).is_empty():
			failures.append("A ranked ladder page exceeded the network limits or reported incorrect page metadata")
			break
		for row: Dictionary in summary["ladder"]:
			if row.has("account_id") or row.has("email"):
				failures.append("Ladder exposed private account fields")
				break
			if row.get("is_bot", false):
				bot_count += 1
				if page != 0 or str(row.get("list_id", "")).is_empty():
					failures.append("Bo1 standings did not rank the winning bot or include its deck link")
			else:
				names[row["name"]] = true
				var expected := {} if row["name"] in ["Player 000", "Player 001"] else portrait
				portraits_valid = portraits_valid and row.get("portrait", {}) == expected
	if names.size() != capped_entry_count - 1:
		failures.append("Ladder pages did not expose the expected top 100 standings")
	if not portraits_valid:
		failures.append("Ladder pages did not return valid saved portraits and crops")
	var bo3 := lobby._build_ladder_page({"best_of": 3, "request_id": 0, "page": 0})
	if bot_count != 1 or bo3["ladder"].any(func(row: Dictionary) -> bool: return row.get("is_bot", false)):
		failures.append("Ladder did not show ranked bots in their match format")
	if not bo3["ladder"].any(func(row: Dictionary) -> bool: return row.get("portrait") == portrait):
		failures.append("Bo3 ladder did not include the player's saved crop")
	var legacy_summary := lobby._build_ladder_page({})
	if legacy_summary["ladder"].size() != 100:
		failures.append("Legacy ladder response did not cap standings at the top 100")
	network.free()
	lobby.free()
	DirAccess.remove_absolute(account_path)
	DirAccess.remove_absolute(account_path + ".bak")
	var result_dir := ServerPathsScript.get_server_data_file_path(storage_file).get_basename() + "_results"
	DirAccess.remove_absolute(result_dir.path_join("%s.json" % session.match_id.sha256_text()))
	DirAccess.remove_absolute(result_dir)

func _check_ranked_bot_pool(failures: PackedStringArray) -> void:
	var storage_file := "preflight_bot_pool_%d.json" % OS.get_process_id()
	var writer := MatchHistoryStoreScript.new(storage_file, true)
	var reader := MatchHistoryStoreScript.new(storage_file, true)
	var session := MatchSessionScript.new("bot_win", "preflight_room", "127.0.0.1", 12345, ["BOT_A", "human"], {
		"BOT_A": {"bot_god_name": "Thor", "cards": _known_good_deck_counts()},
	}, {"human": {"account_id": "human_account", "profile_id": "human_profile"}})
	if not session.to_match_info("human").get("has_bot", false):
		failures.append("Rated bot match assignment did not identify the bot")
	var saved := writer.record_completed_match(session, 0, 1, "", "Odin")
	var recap := reader.get_ranked_match_results(saved["entry"])
	if recap.has(0) or not recap.get(1, {}).get("loss_protected", false):
		failures.append("Rated bot match did not award a recap only to the signed-in player")
	var stored_results := reader.get_bot_deck_results()
	if stored_results.size() != 1 or stored_results[0]["god_name"] != "Thor" or stored_results[0]["result"] != "win":
		failures.append("Rated bot match did not persist the registered winning list")
	var lobby := LobbyServerScript.new()
	lobby.match_history_store = reader
	var seek := lobby._create_server_bot_seek(true)
	lobby.sessions_by_id["human"] = {"account_id": "human_account", "connected": true}
	lobby._join_room_for_session("human", seek.room_id)
	var matched_before := lobby._match_server_bot_to_player(seek)
	var before_win := seek.get_deck_submission(seek.host_session_id)
	var human_win := MatchSessionScript.new("human_win", "preflight_room", "127.0.0.1", 12345, ["human", "opponent"], {}, {
		"human": {"account_id": "human_account"},
		"opponent": {"account_id": "opponent_account"},
	})
	writer.record_completed_match(human_win, 0, 1, "Thor", "Odin")
	var matched_after := lobby._match_server_bot_to_player(seek)
	var after_win := seek.get_deck_submission(seek.host_session_id)
	var before_bot_rank := RankedProgressionScript.summarize_bot_stars(int(before_win.get("bot_stars", -1)))
	var after_bot_rank := RankedProgressionScript.summarize_bot_stars(int(after_win.get("bot_stars", -1)))
	if not matched_before or not matched_after \
			or absi(int(before_bot_rank["league"])) > 2 \
			or after_win.get("bot_list_id") != "bot_win" \
			or absi(int(after_bot_rank["league"]) - int(RankedProgressionScript.summarize_bot_stars(1)["league"])) > 2:
		failures.append("Bot challenge did not select an available deck within two leagues of the player's rank")
	lobby.free()
	var self_play := MatchSessionScript.new("bot_self_play", "preflight_room", "127.0.0.1", 12345, ["BOT_A", "BOT_B"], {
		"BOT_A": {"bot_god_name": "Thor", "bot_list_id": "bot_win", "bot_stars": 1, "cards": {"Thor": 1, "Berserker": 3}},
		"BOT_B": {"bot_god_name": "Odin", "cards": {"Odin": 1, "Brown Bear": 3}},
	}, {"BOT_A": {"player_name": "Thor: Bloodaxe"}, "BOT_B": {"player_name": "Odin: Test"}})
	if not self_play.to_spectator_match_info("observer").get("has_bot", false):
		failures.append("Self-play spectator assignment did not identify the bots")
	var self_play_saved := writer.record_completed_match(self_play, 1, 0, "Odin", "Thor", {"turns": 9})
	var recent := reader.get_recent_bot_matches(1)
	var self_play_results := reader.get_bot_deck_results()
	if (not self_play_saved.get("success", false)
			or self_play_saved["entry"].get("advances_rank", true)
			or self_play_results.size() != 3 or recent["matches"].size() != 1):
		failures.append("Self-play did not save both bot seats without changing human ranks")
	else:
		var battle: Dictionary = recent["matches"][0]
		if battle["players"][1]["name"] != "Odin: Test" or battle["battle"].get("turns") != 9:
			failures.append("Self-play history lost the names or battle summary")
	if (not RankedBotDeckPoolScript.can_self_play_pair({"stars": 14}, {"stars": 17})
			or RankedBotDeckPoolScript.can_self_play_pair({"stars": 0}, {"stars": 90})
			or RankedBotDeckPoolScript.can_self_play_pair({"stars": 14}, {"stars": 45})
			or not RankedBotDeckPoolScript.can_self_play_pair({"stars": 5}, {"stars": 9})
			or RankedBotDeckPoolScript.can_self_play_pair({"stars": 5, "list_id": "same"}, {"stars": 5, "list_id": "same"})):
		failures.append("Bot matchmaking did not enforce the two-league gap and distinct seats")
	var result_dir := ServerPathsScript.get_server_data_file_path(storage_file).get_basename() + "_results"
	DirAccess.remove_absolute(result_dir.path_join("%s.json" % session.match_id.sha256_text()))
	DirAccess.remove_absolute(result_dir.path_join("%s.json" % human_win.match_id.sha256_text()))
	DirAccess.remove_absolute(result_dir.path_join("%s.json" % self_play.match_id.sha256_text()))
	DirAccess.remove_absolute(result_dir)

	var pool := RankedBotDeckPoolScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	pool.refresh(stored_results)
	var first_list := pool.select_deck({}, rng, 1)
	if first_list.get("deck_name") != "Thor: Bloodaxe" or first_list.get("stars") != 1:
		failures.append("A winning bot list did not return with its permanent name and star")
	if pool.select_deck({}, rng, 0).is_empty():
		failures.append("Bot matchmaking did not allow a same-tier bot for a player at zero stars")
	pool.refresh(self_play_results)
	var after_self_play: Dictionary = pool.get_ladder_summary()
	if after_self_play["gods"].size() != 2:
		failures.append("Self-play did not promote the named winning bot")
	else:
		var odin: Dictionary = after_self_play["gods"][0]["lists"][0]
		var after_thor: Dictionary = after_self_play["gods"][1]["lists"][0]
		if odin["name"] != "Odin: Test" or odin["stars"] != 1 or after_thor["stars"] != 1:
			failures.append("Self-play did not award the win or protect the losing bot at its rank floor")

	var results: Array[Dictionary] = []
	for i in range(7):
		results.append(_bot_pool_result("list_%d" % i, "", {"Thor": 1, "Common": 30, "Variant %d" % i: 10}, "win"))
	results.append(_bot_pool_result("candidate", "", {"Thor": 1, "Common": 30, "Challenger": 10}, "win"))
	pool.refresh(results)
	var candidate := pool.select_deck({}, rng, 1)
	if pool.can_play_list("Thor", "list_0") or not pool.can_play_list("Thor", "list_1") \
			or candidate.is_empty() or candidate.get("stars") != 1:
		failures.append("The eighth bot list did not quarantine an incumbent while preserving same-tier matching")
	var high_rank_results := results.duplicate()
	for i in range(14):
		high_rank_results.append(_bot_pool_result("ranked_%d" % i, "list_1", {}, "win"))
	for i in range(15):
		high_rank_results.append(_bot_pool_result("quarantined_%d" % i, "list_0", {}, "win"))
	var high_rank_pool := RankedBotDeckPoolScript.new()
	high_rank_pool.refresh(high_rank_results)
	var high_rank_match := high_rank_pool.select_deck({}, rng, 16)
	var high_rank_alternative := high_rank_pool.select_deck({"list_1": true}, rng, 16)
	if high_rank_match.is_empty() or high_rank_alternative.is_empty() \
			or abs(int(RankedProgressionScript.summarize_bot_stars(int(high_rank_match["stars"]))["league"]) - 1) > 2 \
			or abs(int(RankedProgressionScript.summarize_bot_stars(int(high_rank_alternative["stars"]))["league"]) - 1) > 2 \
			or high_rank_alternative.get("list_id") == "list_1":
		failures.append("Bot matchmaking did not sample the same two-tier range while skipping busy lists")
	for i in range(6):
		var outcome := "loss" if i % 2 == 0 else "win"
		results.append(_bot_pool_result("trial_%d" % i, "candidate", {}, outcome))
	pool.refresh(results)
	if pool.can_play_list("Thor", "list_0"):
		failures.append("A bot list trial ended before seven completed matches")
	var ladder_summary := pool.get_ladder_summary()
	var thor: Dictionary = ladder_summary["gods"][0]
	var challenger: Dictionary = thor["challenger"]
	if thor["lists"].size() != 7 or not thor["lists"][0]["quarantined"] \
			or challenger.get("matches_played") != 6 or challenger.get("wins") != 4 \
			or challenger.get("losses") != 3 or challenger.get("draws") != 0 \
			or challenger.has("cards") or ladder_summary["trial_length"] != 7:
		failures.append("Bot ladder did not report the quarantined list and six completed trial matches")
	var quarantined_deck := pool.get_deck_details(thor["lists"][0]["list_id"])
	var challenger_deck := pool.get_deck_details(challenger.get("list_id", ""))
	if quarantined_deck.get("cards", {}).get("Variant 0") != 10 \
			or challenger_deck.get("cards", {}).get("Challenger") != 10:
		failures.append("Bot ladder did not resolve both quarantined and challenger deck contents")
	results.append(_bot_pool_result("trial_6", "candidate", {}, "win"))
	pool.refresh(results)
	if not pool.can_play_list("Thor", "list_0") or pool.can_play_list("Thor", "candidate"):
		failures.append("The stronger incumbent did not return after the seventh trial match")
	thor = pool.get_ladder_summary()["gods"][0]
	if not thor["challenger"].is_empty() or thor["lists"][0]["quarantined"]:
		failures.append("Bot ladder still showed a trial after the seventh match")
	if not pool.get_deck_details("candidate").is_empty():
		failures.append("Bot ladder still returned a retired challenger deck")

	var early_retirement_results: Array[Dictionary] = []
	for i in range(7):
		early_retirement_results.append(_bot_pool_result("early_list_%d" % i, "", {"Thor": 1, "Common": 30, "Variant %d" % i: 10}, "win"))
	early_retirement_results.append(_bot_pool_result("early_candidate", "", {"Thor": 1, "Common": 30, "Early Challenger": 10}, "win"))
	for i in range(2):
		early_retirement_results.append(_bot_pool_result("early_loss_%d" % i, "early_candidate", {}, "loss"))
	var early_retirement_pool := RankedBotDeckPoolScript.new()
	early_retirement_pool.refresh(early_retirement_results)
	var early_summary: Dictionary = early_retirement_pool.get_ladder_summary()["gods"][0]
	if not early_summary["challenger"].is_empty() or not early_retirement_pool.can_play_list("Thor", "early_list_0") \
			or not early_retirement_pool.get_deck_details("early_candidate").is_empty():
		failures.append("A challenger with a 1-2 record was not retired early")

	results.append(_bot_pool_result("distinct", "", {"Thor": 1, "Different": 40}, "win"))
	for i in range(7):
		var outcome := "loss" if i % 2 == 0 else "win"
		results.append(_bot_pool_result("variety_%d" % i, "distinct", {}, outcome))
	pool.refresh(results)
	if not pool.can_play_list("Thor", "distinct") or pool.can_play_list("Thor", "list_0"):
		failures.append("A bot list with over 75% different cards did not survive for variety")

func _bot_pool_result(match_id: String, list_id: String, cards: Dictionary, outcome: String) -> Dictionary:
	return {
		"match_id": match_id,
		"list_id": list_id,
		"god_name": "Thor",
		"cards": cards,
		"special_setup": {},
		"reinforcements": {},
		"result": outcome,
	}

func _script_path(card: Card) -> String:
	if card == null or card.get_script() == null:
		return ""
	return card.get_script().resource_path

func _known_good_deck_counts() -> Dictionary:
	return {
		"Thor": 1,
		"Askelladen": 3,
		"Berserker": 3,
		"Brown Bear": 3,
		"Byggvir": 3,
		"Bit Meseri": 3,
		"Absence": 3,
		"Warding Stone": 3,
		"Void Shield": 3,
		"Bearded Axe": 3,
		"Blot Sacrifice": 3,
		"Fall of the Mighty": 2,
		"Blessed Knights": 3,
		"Again-Walker": 3,
		"Alu": 2,
	}

func _cards_from_counts(card_counts: Dictionary) -> Array[Card]:
	var cards: Array[Card] = []
	for raw_card_name in card_counts.keys():
		var card_name := str(raw_card_name).strip_edges()
		var count := int(card_counts[raw_card_name])
		for _copy_index in range(maxi(0, count)):
			var card := CardCatalogScript.instantiate_card_by_name(card_name)
			if card != null:
				cards.append(card)
	return cards

func _write_result_file(success: bool, failures: PackedStringArray) -> void:
	var result_path := _get_result_path()
	if result_path.is_empty():
		return
	var parent_dir := result_path.get_base_dir()
	if not parent_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file == null:
		push_warning("preflight_probe: failed to open result file %s" % result_path)
		return
	if success:
		file.store_string("PASS\n")
	else:
		file.store_string("FAIL\n")
		for failure in failures:
			file.store_string("%s\n" % failure)
	file.flush()
	file.close()

func _get_result_path() -> String:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with(RESULT_ARG_PREFIX):
			var path := text.substr(RESULT_ARG_PREFIX.length()).strip_edges()
			if path.is_empty():
				return ""
			if path.begins_with("res://") or path.begins_with("user://"):
				return ProjectSettings.globalize_path(path)
			if path.is_absolute_path():
				return path
			return ProjectSettings.globalize_path("res://").path_join(path)
	return ""
