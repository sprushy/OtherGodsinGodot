extends Node
class_name PreflightProbe

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const DefaultMatchSetupScript = preload("res://scripts/server/DefaultMatchSetup.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const MatchCommandRegistryScript = preload("res://scripts/Other/MatchCommandRegistry.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const MatchSupervisorScript = preload("res://scripts/server/MatchSupervisor.gd")
const NetworkManagerScript = preload("res://scripts/Other/NetworkManager.gd")

const MIN_CATALOG_CARDS := 200
const RESULT_ARG_PREFIX := "preflight_result_file="

var _ran := false

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
	proposed_main["Again-Walker"] = 2
	proposed_main["Tablet of Life"] = 1
	var proposed_reinforcements := {
		"Tablet of Life": 2,
		"Again-Walker": 1,
	}
	var swap_result: Dictionary = validator.validate_reinforcement_swap(
		valid_deck,
		registered_reinforcements,
		proposed_main,
		proposed_reinforcements
	)
	if not bool(swap_result.get("is_valid", false)):
		failures.append("legal one-for-one Reinforcement swap failed validation: %s" % str(swap_result.get("error", "")))
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
	game_manager.turn_number = 1

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
	for viewer_index in [0, 1, GameState.SPECTATOR_VIEWER_INDEX]:
		var event_payload := {
			"state": GameState.serialize(game_manager, viewer_index),
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
