extends Control

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")
const LobbyClientScript = preload("res://scripts/client/LobbyClient.gd")
const AppReleaseInfoScript = preload("res://scripts/client/AppReleaseInfo.gd")
const LocalProfileStoreScript = preload("res://scripts/client/LocalProfileStore.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const DEDICATED_LOBBY_ENTRY_SCRIPT_PATH := "res://scripts/server/DedicatedLobbyServerMain.gd"
const DEDICATED_SERVER_EXPORT_RELATIVE_PATH := "res://.exports/server/ClaudeOtherGodsServer.exe"
const DEFAULT_LOBBY_HOST_SETTING := "application/config/default_lobby_host"
const DEFAULT_LOBBY_HOST := ""
const AUTH_MODE_GUEST := "guest"
const AUTH_MODE_LOGIN := "login"
const AUTH_MODE_REGISTER := "register"

@onready var menu_container = $MenuContainer
@onready var game_container = $GameContainer
@onready var multiplayer_container = $MenuContainer/MultiplayerContainer
@onready var multiplayer_button = $MenuContainer/MultiplayerButton
@onready var multiplayer_back_button = $MenuContainer/MultiplayerContainer/MultiplayerHeaderRow/BackButton
@onready var ip_line_edit = $MenuContainer/MultiplayerContainer/IPLineEdit
@onready var player_name_line_edit = $MenuContainer/MultiplayerContainer/PlayerNameLineEdit
@onready var deck_picker_option = $MenuContainer/MultiplayerContainer/DeckPickerOption
@onready var deck_hint_label = $MenuContainer/MultiplayerContainer/DeckHintLabel
@onready var create_seek_button = $MenuContainer/MultiplayerContainer/CreateSeekButton
@onready var seek_list = $MenuContainer/MultiplayerContainer/SeekList
@onready var leave_seek_button = $MenuContainer/MultiplayerContainer/LeaveSeekButton
@onready var room_code_line_edit = $MenuContainer/MultiplayerContainer/RoomCodeLineEdit
@onready var connect_button = $MenuContainer/MultiplayerContainer/MultiplayerHeaderRow/ConnectButton
@onready var ready_button = $MenuContainer/MultiplayerContainer/ReadyButton
@onready var status_label = $MenuContainer/MultiplayerContainer/StatusLabel

var _smoke_config: Dictionary = {}
var lobby_server = null
var lobby_client = null
var _current_room_snapshot: Dictionary = {}
var _open_seek_rooms: Array[Dictionary] = []
var _lobby_session_id: String = ""
var _lobby_reconnect_token: String = ""
var _pending_join_room_code: String = ""
var _pending_join_room_id: String = ""
var _current_lobby_ip: String = ""
var _is_local_lobby_host: bool = false
var _match_launch_queued: bool = false
var _pending_host_room_creation: bool = false
var _pending_local_lobby_launch_on_connect_failure: bool = false
var _spawned_lobby_process_id: int = 0
var _dedicated_lobby_connect_attempts_remaining: int = 0
var _local_profile_store = null
var _local_profile_id: String = ""
var _selected_multiplayer_deck_id: String = ""
var _legal_multiplayer_decks: Array[Dictionary] = []
var _deck_validator = DeckValidatorScript.new()
var _last_submitted_lobby_room_id: String = ""
var _last_submitted_lobby_deck_id: String = ""
var _auth_mode_option: OptionButton = null
var _password_line_edit: LineEdit = null
var _switch_account_button: Button = null
var _resume_match_button: Button = null
var _profile_summary_label: Label = null
var _current_profile_summary: Dictionary = {}
var _auth_onboarding_overlay: Control = null
var _auth_onboarding_selected_mode: String = AUTH_MODE_GUEST
var _auth_onboarding_mode_hint_label: Label = null
var _auth_onboarding_username_edit: LineEdit = null
var _auth_onboarding_password_edit: LineEdit = null
var _auth_onboarding_continue_button: Button = null
var _report_bug_button: Button = null
var _bug_report_overlay: Control = null
var _bug_report_expected_edit: TextEdit = null
var _bug_report_actual_edit: TextEdit = null
var _bug_report_status_label: Label = null
var _bug_report_screenshot_label: Label = null
var _bug_report_screenshot_preview: TextureRect = null
var _bug_report_file_dialog: FileDialog = null
var _bug_report_selected_screenshot_path: String = ""
var _account_identity_label: Label = null
var _logged_in_account_username: String = ""
var _update_check_request: HTTPRequest = null
var _update_prompt_overlay: Control = null
var _pending_update_release_version: String = ""
var _pending_update_release_url: String = AppReleaseInfoScript.RELEASES_PAGE_URL
var _startup_prompt_gate_open: bool = false

func _ready() -> void:
	if _is_server_runtime_launch():
		return
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	if ip_line_edit != null:
		ip_line_edit.visible = false
		ip_line_edit.text = ""
		ip_line_edit.placeholder_text = "Dedicated lobby IP or hostname"

	get_node("GameContainer/MockGame").visible = false
	get_node("GameContainer/CardTest").visible = false
	_bind_game_signals()

	var mock_btn = $MenuContainer/MockGameButton
	var deck_btn = $MenuContainer/DeckBuilderButton
	var card_test_btn = $MenuContainer/CardTestButton

	if mock_btn:
		if OS.is_debug_build():
			mock_btn.pressed.connect(_on_mock_game_pressed)
		else:
			mock_btn.visible = false
	if deck_btn:
		deck_btn.pressed.connect(_on_deck_builder_pressed)
	if card_test_btn:
		if OS.is_debug_build():
			card_test_btn.pressed.connect(_on_card_test_pressed)
		else:
			card_test_btn.visible = false
	if multiplayer_button:
		multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	if multiplayer_back_button:
		multiplayer_back_button.pressed.connect(_on_multiplayer_back_pressed)
	if connect_button:
		connect_button.pressed.connect(_on_refresh_seeks_pressed)
	if create_seek_button:
		create_seek_button.pressed.connect(_on_create_seek_pressed)
	if leave_seek_button:
		leave_seek_button.pressed.connect(_on_leave_seek_pressed)
	if deck_picker_option:
		deck_picker_option.item_selected.connect(_on_multiplayer_deck_selected)
	if seek_list != null and seek_list.has_signal("item_clicked"):
		seek_list.item_clicked.connect(_on_seek_item_clicked)
	if ready_button:
		ready_button.pressed.connect(_on_ready_button_pressed)

	_build_auth_controls()
	_ensure_local_profile_store()
	_restore_auth_preferences()
	_build_profile_summary_controls()
	_build_account_identity_controls()
	_build_resume_controls()
	_refresh_multiplayer_deck_options()
	_refresh_seek_list()
	_refresh_multiplayer_action_state()
	_restore_saved_resume_state()
	show_menu()
	_smoke_config = _parse_smoke_config(OS.get_cmdline_user_args())
	if not _smoke_config.is_empty():
		call_deferred("_start_smoke_mode")
	else:
		call_deferred("_begin_startup_prompts")

func _bind_game_signals() -> void:
	for node_name in ["MockGame", "CardTest"]:
		var game = get_node_or_null("GameContainer/" + node_name)
		if game != null and game.has_signal("forfeit_requested"):
			var callback := Callable(self, "_on_game_forfeit_requested")
			if not game.forfeit_requested.is_connected(callback):
				game.forfeit_requested.connect(callback)
		if game != null and game.has_signal("match_session_cleared"):
			var clear_callback := Callable(self, "_on_match_session_cleared")
			if not game.match_session_cleared.is_connected(clear_callback):
				game.match_session_cleared.connect(clear_callback)

func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size

func show_menu() -> void:
	menu_container.visible = true
	game_container.visible = false
	_refresh_multiplayer_deck_options()
	_refresh_multiplayer_action_state()

func show_game() -> void:
	menu_container.visible = false
	game_container.visible = true

func _on_multiplayer_pressed() -> void:
	_open_multiplayer_screen()

func _on_multiplayer_back_pressed() -> void:
	_cleanup_lobby(true)
	multiplayer_container.visible = false
	status_label.text = "Refresh open seeks or create your own."
	_refresh_seek_list()
	_refresh_multiplayer_action_state()

func _open_multiplayer_screen() -> void:
	multiplayer_container.visible = true
	_refresh_multiplayer_deck_options()
	_refresh_auth_controls()
	_refresh_seek_list()
	_refresh_multiplayer_action_state()
	if not _current_room_snapshot.is_empty():
		_apply_room_snapshot(_current_room_snapshot)
		return
	if _has_active_lobby_connection():
		status_label.text = "Refreshing open seeks..."
		lobby_client.list_rooms()
		return
	status_label.text = "Choose a deck, then refresh open seeks or create your own."

func _has_active_lobby_connection() -> bool:
	return lobby_client != null and is_instance_valid(lobby_client) and not _lobby_session_id.is_empty()

func _refresh_multiplayer_deck_options() -> void:
	_legal_multiplayer_decks.clear()
	if deck_picker_option == null:
		return
	deck_picker_option.clear()

	var preferred_deck_id := _selected_multiplayer_deck_id
	if preferred_deck_id.is_empty() and _local_profile_store != null:
		preferred_deck_id = _local_profile_store.get_last_selected_deck_id(_local_profile_id)

	var preferred_deck: Dictionary = {}
	if _local_profile_store != null and not _local_profile_id.is_empty():
		for saved_deck in _local_profile_store.list_decks(_local_profile_id):
			if not _is_saved_deck_legal(saved_deck):
				continue
			var deck_id := str(saved_deck.get("deck_id", "")).strip_edges()
			if deck_id == preferred_deck_id and preferred_deck.is_empty():
				preferred_deck = saved_deck.duplicate(true)
				continue
			_legal_multiplayer_decks.append(saved_deck.duplicate(true))

	if not preferred_deck.is_empty():
		_legal_multiplayer_decks.push_front(preferred_deck)

	if _legal_multiplayer_decks.is_empty():
		deck_picker_option.disabled = true
		deck_picker_option.add_item("No legal saved decks")
		deck_picker_option.set_item_metadata(0, "")
		_selected_multiplayer_deck_id = ""
		_update_multiplayer_deck_hint()
		_refresh_multiplayer_action_state()
		return

	deck_picker_option.disabled = false
	var selected_index := 0
	for index in range(_legal_multiplayer_decks.size()):
		var saved_deck: Dictionary = _legal_multiplayer_decks[index]
		var deck_id := str(saved_deck.get("deck_id", "")).strip_edges()
		var deck_name := str(saved_deck.get("name", "Deck")).strip_edges()
		if deck_name.is_empty():
			deck_name = "Deck"
		deck_picker_option.add_item(deck_name)
		deck_picker_option.set_item_metadata(index, deck_id)
		if deck_id == preferred_deck_id:
			selected_index = index

	deck_picker_option.select(selected_index)
	_selected_multiplayer_deck_id = str(deck_picker_option.get_item_metadata(selected_index)).strip_edges()
	_update_multiplayer_deck_hint()
	_refresh_multiplayer_action_state()

func _is_saved_deck_legal(saved_deck: Dictionary) -> bool:
	if saved_deck.is_empty():
		return false
	var validation: Dictionary = _deck_validator.validate_deck(saved_deck.get("cards", {}))
	return bool(validation.get("is_valid", false))

func _update_multiplayer_deck_hint() -> void:
	if deck_hint_label == null:
		return
	var selected_deck: Dictionary = _get_selected_multiplayer_deck()
	if selected_deck.is_empty():
		deck_hint_label.text = "Choose one of your saved legal decks before you create or join a seek."
		return
	deck_hint_label.text = "Selected deck: %s" % str(selected_deck.get("name", "Deck"))

func _get_selected_multiplayer_deck() -> Dictionary:
	var selected_deck_id := _selected_multiplayer_deck_id.strip_edges()
	if selected_deck_id.is_empty():
		return {}
	for saved_deck in _legal_multiplayer_decks:
		if str(saved_deck.get("deck_id", "")).strip_edges() == selected_deck_id:
			return saved_deck.duplicate(true)
	if _local_profile_store == null or _local_profile_id.is_empty():
		return {}
	var saved_deck: Dictionary = _local_profile_store.get_deck(_local_profile_id, selected_deck_id)
	if saved_deck.is_empty() or not _is_saved_deck_legal(saved_deck):
		return {}
	return saved_deck

func _refresh_seek_list() -> void:
	if seek_list == null:
		return
	seek_list.clear()
	if _open_seek_rooms.is_empty():
		seek_list.add_item("No open seeks right now.")
		seek_list.set_item_disabled(0, true)
		return
	for room in _open_seek_rooms:
		var room_id := str(room.get("room_id", "")).strip_edges()
		var host_name := str(room.get("host_name", "Host")).strip_edges()
		var member_count := int(room.get("member_count", 0))
		var max_players := int(room.get("max_players", 2))
		var status := str(room.get("status", "waiting")).capitalize()
		seek_list.add_item("%s  %d/%d  %s" % [host_name, member_count, max_players, status])
		seek_list.set_item_metadata(seek_list.get_item_count() - 1, room_id)

func _refresh_multiplayer_action_state() -> void:
	var has_legal_deck := not _get_selected_multiplayer_deck().is_empty()
	var in_room := not _current_room_snapshot.is_empty()
	if create_seek_button != null:
		create_seek_button.disabled = not has_legal_deck or in_room
	if leave_seek_button != null:
		leave_seek_button.visible = in_room
	if ready_button != null:
		ready_button.visible = false

func _queue_room_list_refresh() -> void:
	if lobby_client == null:
		return
	status_label.text = "Refreshing open seeks..."
	lobby_client.list_rooms()

func _on_multiplayer_deck_selected(index: int) -> void:
	if deck_picker_option == null:
		return
	var deck_id := str(deck_picker_option.get_item_metadata(index)).strip_edges()
	if deck_id.is_empty():
		return
	_selected_multiplayer_deck_id = deck_id
	if _local_profile_store != null and not _local_profile_id.is_empty():
		_local_profile_store.remember_last_selected_deck(_local_profile_id, deck_id)
	_update_multiplayer_deck_hint()
	_refresh_multiplayer_action_state()
	if not _current_room_snapshot.is_empty():
		_maybe_submit_current_profile_deck(str(_current_room_snapshot.get("room_id", "")), _current_room_snapshot)

func _on_seek_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if seek_list == null or index < 0 or index >= seek_list.get_item_count():
		return
	if seek_list.is_item_disabled(index):
		return
	if not _current_room_snapshot.is_empty():
		status_label.text = "Leave your current seek before joining another."
		return
	if _get_selected_multiplayer_deck().is_empty():
		status_label.text = "Choose a saved legal deck before joining a seek."
		return
	var room_id := str(seek_list.get_item_metadata(index)).strip_edges()
	if room_id.is_empty():
		return
	_on_join_seek_requested(room_id)

func _on_refresh_seeks_pressed() -> void:
	var target_error := _validate_multiplayer_target()
	if not target_error.is_empty():
		status_label.text = target_error
		return
	var auth_error := _validate_auth_inputs()
	if not auth_error.is_empty():
		status_label.text = auth_error
		return
	_pending_host_room_creation = false
	_pending_join_room_id = ""
	_pending_local_lobby_launch_on_connect_failure = false
	multiplayer_container.visible = true
	_connect_to_browseable_lobby("Connecting to lobby...")

func _on_create_seek_pressed() -> void:
	var target_error := _validate_multiplayer_target()
	if not target_error.is_empty():
		status_label.text = target_error
		return
	var auth_error := _validate_auth_inputs()
	if not auth_error.is_empty():
		status_label.text = auth_error
		return
	if _get_selected_multiplayer_deck().is_empty():
		status_label.text = "Choose a saved legal deck before creating a seek."
		return
	if not _current_room_snapshot.is_empty():
		status_label.text = "Leave your current seek before creating another."
		return
	_pending_host_room_creation = true
	_pending_join_room_id = ""
	_pending_local_lobby_launch_on_connect_failure = false
	multiplayer_container.visible = true
	_connect_to_browseable_lobby("Connecting to lobby...")

func _on_join_seek_requested(room_id: String) -> void:
	var target_error := _validate_multiplayer_target()
	if not target_error.is_empty():
		status_label.text = target_error
		return
	var auth_error := _validate_auth_inputs()
	if not auth_error.is_empty():
		status_label.text = auth_error
		return
	if _get_selected_multiplayer_deck().is_empty():
		status_label.text = "Choose a saved legal deck before joining a seek."
		return
	if not _current_room_snapshot.is_empty():
		status_label.text = "Leave your current seek before joining a new one."
		return
	_pending_host_room_creation = false
	_pending_join_room_id = room_id.strip_edges().to_upper()
	_pending_local_lobby_launch_on_connect_failure = false
	multiplayer_container.visible = true
	_connect_to_browseable_lobby("Connecting to lobby...")

func _on_leave_seek_pressed() -> void:
	if lobby_client == null:
		return
	_clear_current_seek_state()
	status_label.text = "Leaving seek..."
	lobby_client.leave_room()

func _connect_to_browseable_lobby(connect_status: String) -> void:
	var target_error := _validate_multiplayer_target()
	if not target_error.is_empty():
		status_label.text = target_error
		return
	var target_lobby_ip := _get_lobby_ip()
	if _has_active_lobby_connection() and _current_lobby_ip == target_lobby_ip:
		_run_pending_multiplayer_action()
		return

	_current_lobby_ip = target_lobby_ip
	_cleanup_lobby_client()
	status_label.text = connect_status

	lobby_client = LobbyClientScript.new()
	lobby_client.name = "LobbyPeer"
	lobby_client.use_default_multiplayer = true
	_configure_lobby_client_trace(lobby_client)
	_attach_lobby_client(lobby_client)
	_bind_lobby_client_signals()

	var connect_err: Error = lobby_client.connect_to_server(
		_current_lobby_ip,
		_get_lobby_login_name("Guest"),
		_lobby_session_id,
		_lobby_reconnect_token,
		_get_configured_lobby_port(),
		_local_profile_id,
		_get_selected_auth_mode(),
		_get_auth_password()
	)
	if connect_err != OK:
		status_label.text = "Could not connect to the lobby."

func _run_pending_multiplayer_action() -> void:
	if lobby_client == null:
		return
	if _pending_host_room_creation:
		_pending_host_room_creation = false
		_pending_local_lobby_launch_on_connect_failure = false
		status_label.text = "Creating seek..."
		lobby_client.create_room()
		return
	if not _pending_join_room_id.is_empty():
		var room_id := _pending_join_room_id
		_pending_join_room_id = ""
		status_label.text = "Joining seek %s..." % room_id
		lobby_client.join_room(room_id)
		return
	_queue_room_list_refresh()

func _is_local_lobby_target(host: String) -> bool:
	var normalized_host := host.strip_edges().to_lower()
	return normalized_host.is_empty() or normalized_host == "127.0.0.1" or normalized_host == "localhost"

func _clear_current_seek_state() -> void:
	_current_room_snapshot.clear()
	ready_button.visible = false
	leave_seek_button.visible = false
	_last_submitted_lobby_room_id = ""
	_last_submitted_lobby_deck_id = ""
	status_label.text = "Refresh open seeks or create your own."
	_refresh_multiplayer_action_state()

func _is_server_runtime_launch() -> bool:
	if OS.has_feature("dedicated_server"):
		return true
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg).strip_edges()
		if arg.begins_with("server_mode="):
			return true
		if arg.begins_with("match_config="):
			return true
	return false

func _begin_startup_prompts() -> void:
	_startup_prompt_gate_open = true
	if _should_check_for_updates():
		_start_update_check()
		return
	_complete_startup_prompts()

func _complete_startup_prompts() -> void:
	if not _startup_prompt_gate_open:
		return
	_startup_prompt_gate_open = false
	_maybe_show_auth_onboarding()

func _should_check_for_updates() -> bool:
	if not _smoke_config.is_empty():
		return false
	return AppReleaseInfoScript.is_release_version(AppReleaseInfoScript.get_current_version())

func _ensure_update_check_request() -> void:
	if _update_check_request != null and is_instance_valid(_update_check_request):
		return
	_update_check_request = HTTPRequest.new()
	_update_check_request.name = "LatestReleaseRequest"
	_update_check_request.timeout = 5.0
	_update_check_request.request_completed.connect(_on_update_check_request_completed)
	add_child(_update_check_request)

func _start_update_check() -> void:
	_ensure_update_check_request()
	var headers := PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: ClaudeOtherGods",
		"X-GitHub-Api-Version: 2022-11-28",
	])
	var request_error := _update_check_request.request(AppReleaseInfoScript.RELEASES_API_URL, headers)
	if request_error != OK:
		_complete_startup_prompts()

func _on_update_check_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_complete_startup_prompts()
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_complete_startup_prompts()
		return
	var payload := parsed as Dictionary
	var latest_version := AppReleaseInfoScript.normalize_version(str(payload.get("tag_name", "")))
	if not _should_prompt_for_update(latest_version):
		_complete_startup_prompts()
		return
	var release_url := str(payload.get("html_url", AppReleaseInfoScript.RELEASES_PAGE_URL)).strip_edges()
	if release_url.is_empty():
		release_url = AppReleaseInfoScript.RELEASES_PAGE_URL
	_show_update_prompt(latest_version, release_url)

func _should_prompt_for_update(latest_version: String) -> bool:
	if not AppReleaseInfoScript.is_release_version(latest_version):
		return false
	var current_version := AppReleaseInfoScript.get_current_version()
	if AppReleaseInfoScript.compare_versions(current_version, latest_version) >= 0:
		return false
	if _local_profile_store == null:
		return true
	var dismissed_version: String = str(_local_profile_store.get_dismissed_release_version()).strip_edges()
	if not dismissed_version.is_empty() and AppReleaseInfoScript.compare_versions(current_version, dismissed_version) >= 0:
		_local_profile_store.remember_dismissed_release_version("")
		dismissed_version = ""
	return dismissed_version != latest_version

func _show_update_prompt(latest_version: String, release_url: String) -> void:
	if _update_prompt_overlay != null and is_instance_valid(_update_prompt_overlay):
		return
	_pending_update_release_version = latest_version
	_pending_update_release_url = release_url

	_update_prompt_overlay = Control.new()
	_update_prompt_overlay.name = "UpdatePromptOverlay"
	_update_prompt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_prompt_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_update_prompt_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_update_prompt_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_prompt_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.10, 0.16, 0.98)
	panel_style.border_color = Color(0.38, 0.66, 1.0, 0.95)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		panel_style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title := Label.new()
	title.text = "Update Available"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var current_version := AppReleaseInfoScript.get_current_version()
	var body_label := Label.new()
	body_label.text = "You're running %s, and the latest release is %s. Open the release page to download the newest build." % [current_version, latest_version]
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(body_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 8)
	content.add_child(button_row)

	var later_button := Button.new()
	later_button.text = "Later"
	later_button.custom_minimum_size = Vector2(110, 38)
	later_button.pressed.connect(_on_update_prompt_later_pressed)
	button_row.add_child(later_button)

	var update_button := Button.new()
	update_button.text = "Open Download Page"
	update_button.custom_minimum_size = Vector2(180, 38)
	update_button.pressed.connect(_on_update_prompt_open_pressed)
	button_row.add_child(update_button)

	update_button.grab_focus()

func _dismiss_update_prompt() -> void:
	if _update_prompt_overlay != null and is_instance_valid(_update_prompt_overlay):
		_update_prompt_overlay.queue_free()
	_update_prompt_overlay = null
	_pending_update_release_version = ""
	_pending_update_release_url = AppReleaseInfoScript.RELEASES_PAGE_URL

func _on_update_prompt_later_pressed() -> void:
	if _local_profile_store != null and not _pending_update_release_version.is_empty():
		_local_profile_store.remember_dismissed_release_version(_pending_update_release_version)
	_dismiss_update_prompt()
	_complete_startup_prompts()

func _on_update_prompt_open_pressed() -> void:
	var release_url := _pending_update_release_url
	if release_url.is_empty():
		release_url = AppReleaseInfoScript.RELEASES_PAGE_URL
	var open_error := OS.shell_open(release_url)
	if open_error == OK:
		status_label.text = "Opened the latest release page in your browser."
	else:
		status_label.text = "Couldn't open the latest release page automatically."
	_dismiss_update_prompt()
	_complete_startup_prompts()

func _build_bug_report_controls() -> void:
	if _report_bug_button == null:
		_report_bug_button = Button.new()
		_report_bug_button.name = "ReportBugButton"
		_report_bug_button.text = "Report Bug"
		_report_bug_button.custom_minimum_size = Vector2(120, 38)
		_report_bug_button.anchor_left = 1.0
		_report_bug_button.anchor_right = 1.0
		_report_bug_button.anchor_top = 1.0
		_report_bug_button.anchor_bottom = 1.0
		_report_bug_button.offset_left = -142
		_report_bug_button.offset_right = -18
		_report_bug_button.offset_top = -54
		_report_bug_button.offset_bottom = -16
		_report_bug_button.pressed.connect(_open_bug_report_overlay)
		add_child(_report_bug_button)

	if _bug_report_file_dialog == null:
		_bug_report_file_dialog = FileDialog.new()
		_bug_report_file_dialog.name = "BugReportScreenshotDialog"
		_bug_report_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_bug_report_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_bug_report_file_dialog.title = "Choose Screenshot"
		_bug_report_file_dialog.filters = PackedStringArray([
			"*.png, *.jpg, *.jpeg, *.webp ; Image Files",
		])
		_bug_report_file_dialog.file_selected.connect(_on_bug_report_screenshot_selected)
		add_child(_bug_report_file_dialog)

func _open_bug_report_overlay() -> void:
	if _bug_report_overlay != null and is_instance_valid(_bug_report_overlay):
		return

	_bug_report_overlay = Control.new()
	_bug_report_overlay.name = "BugReportOverlay"
	_bug_report_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bug_report_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bug_report_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.05, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_bug_report_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bug_report_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	panel_style.border_color = Color(0.54, 0.76, 1.0, 0.95)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		panel_style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 18)
	outer_margin.add_theme_constant_override("margin_right", 18)
	outer_margin.add_theme_constant_override("margin_top", 18)
	outer_margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(outer_margin)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(640, 0)
	content.add_theme_constant_override("separation", 10)
	outer_margin.add_child(content)

	var title := Label.new()
	title.text = "Bug Report"
	title.add_theme_font_size_override("font_size", 22)
	content.add_child(title)

	var intro := Label.new()
	intro.text = "Tell us what you expected to happen, what happened instead, and optionally attach a screenshot."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)

	var expected_label := Label.new()
	expected_label.text = "What did you expect to happen?"
	content.add_child(expected_label)

	_bug_report_expected_edit = TextEdit.new()
	_bug_report_expected_edit.custom_minimum_size = Vector2(0, 110)
	_bug_report_expected_edit.placeholder_text = "Describe the expected result."
	_bug_report_expected_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(_bug_report_expected_edit)

	var actual_label := Label.new()
	actual_label.text = "What happened?"
	content.add_child(actual_label)

	_bug_report_actual_edit = TextEdit.new()
	_bug_report_actual_edit.custom_minimum_size = Vector2(0, 140)
	_bug_report_actual_edit.placeholder_text = "Describe what the game actually did."
	_bug_report_actual_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(_bug_report_actual_edit)

	var screenshot_label := Label.new()
	screenshot_label.text = "Screenshot"
	content.add_child(screenshot_label)

	var screenshot_row := HBoxContainer.new()
	screenshot_row.add_theme_constant_override("separation", 8)
	content.add_child(screenshot_row)

	var choose_btn := Button.new()
	choose_btn.text = "Add Screenshot"
	choose_btn.custom_minimum_size = Vector2(160, 36)
	choose_btn.pressed.connect(_open_bug_report_file_dialog)
	screenshot_row.add_child(choose_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Screenshot"
	clear_btn.custom_minimum_size = Vector2(150, 36)
	clear_btn.pressed.connect(_clear_bug_report_screenshot)
	screenshot_row.add_child(clear_btn)

	_bug_report_screenshot_label = Label.new()
	_bug_report_screenshot_label.text = "No screenshot selected."
	_bug_report_screenshot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bug_report_screenshot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screenshot_row.add_child(_bug_report_screenshot_label)

	_bug_report_screenshot_preview = TextureRect.new()
	_bug_report_screenshot_preview.custom_minimum_size = Vector2(240, 135)
	_bug_report_screenshot_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bug_report_screenshot_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bug_report_screenshot_preview.visible = false
	content.add_child(_bug_report_screenshot_preview)

	_bug_report_status_label = Label.new()
	_bug_report_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bug_report_status_label.visible = false
	content.add_child(_bug_report_status_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)

	var cancel_btn := Button.new()
	cancel_btn.text = "Close"
	cancel_btn.custom_minimum_size = Vector2(110, 38)
	cancel_btn.pressed.connect(_close_bug_report_overlay)
	actions.add_child(cancel_btn)

	var submit_btn := Button.new()
	submit_btn.text = "Save Report"
	submit_btn.custom_minimum_size = Vector2(130, 38)
	submit_btn.pressed.connect(_submit_bug_report)
	actions.add_child(submit_btn)

	_refresh_bug_report_screenshot_preview()
	_bug_report_expected_edit.grab_focus()

func _close_bug_report_overlay() -> void:
	if _bug_report_overlay == null:
		return
	if is_instance_valid(_bug_report_overlay):
		_bug_report_overlay.queue_free()
	_bug_report_overlay = null
	_bug_report_expected_edit = null
	_bug_report_actual_edit = null
	_bug_report_status_label = null
	_bug_report_screenshot_label = null
	_bug_report_screenshot_preview = null

func _open_bug_report_file_dialog() -> void:
	if _bug_report_file_dialog == null:
		return
	_bug_report_file_dialog.popup_centered_ratio(0.7)

func _on_bug_report_screenshot_selected(path: String) -> void:
	_bug_report_selected_screenshot_path = path.strip_edges()
	_refresh_bug_report_screenshot_preview()

func _clear_bug_report_screenshot() -> void:
	_bug_report_selected_screenshot_path = ""
	_refresh_bug_report_screenshot_preview()

func _refresh_bug_report_screenshot_preview() -> void:
	if _bug_report_screenshot_label != null:
		_bug_report_screenshot_label.text = "No screenshot selected." if _bug_report_selected_screenshot_path.is_empty() else _bug_report_selected_screenshot_path
	if _bug_report_screenshot_preview == null:
		return
	_bug_report_screenshot_preview.texture = null
	_bug_report_screenshot_preview.visible = false
	if _bug_report_selected_screenshot_path.is_empty():
		return
	var image := Image.new()
	var err := image.load(_bug_report_selected_screenshot_path)
	if err != OK:
		if _bug_report_status_label != null:
			_bug_report_status_label.visible = true
			_bug_report_status_label.text = "Could not load the selected screenshot preview."
		return
	_bug_report_screenshot_preview.texture = ImageTexture.create_from_image(image)
	_bug_report_screenshot_preview.visible = true

func _submit_bug_report() -> void:
	if _bug_report_expected_edit == null or _bug_report_actual_edit == null:
		return
	var expected_text := _bug_report_expected_edit.text.strip_edges()
	var actual_text := _bug_report_actual_edit.text.strip_edges()
	if expected_text.is_empty():
		_set_bug_report_status("Please fill in what you expected to happen.")
		_bug_report_expected_edit.grab_focus()
		return
	if actual_text.is_empty():
		_set_bug_report_status("Please fill in what happened.")
		_bug_report_actual_edit.grab_focus()
		return

	var report_id := "report_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec() % 100000]
	var reports_dir := "user://bug_reports"
	var screenshots_dir := reports_dir + "/screenshots"
	_ensure_user_directory(reports_dir)
	_ensure_user_directory(screenshots_dir)

	var screenshot_saved_path := ""
	if not _bug_report_selected_screenshot_path.is_empty():
		screenshot_saved_path = _copy_bug_report_screenshot(_bug_report_selected_screenshot_path, screenshots_dir, report_id)
		if screenshot_saved_path.is_empty():
			_set_bug_report_status("The report text was ready, but the screenshot could not be copied.")
			return

	var report_data := {
		"report_id": report_id,
		"reported_at_unix": int(Time.get_unix_time_from_system()),
		"reported_at_utc": Time.get_datetime_string_from_system(true, true),
		"expected_behavior": expected_text,
		"actual_behavior": actual_text,
		"screenshot_original_path": _bug_report_selected_screenshot_path,
		"screenshot_saved_path": screenshot_saved_path,
		"profile_id": _local_profile_id,
		"lobby_session_id": _lobby_session_id,
		"selected_auth_mode": _get_selected_auth_mode(),
		"menu_visible": menu_container.visible,
		"game_visible": game_container.visible,
		"pending_room_code": _pending_join_room_code,
	}

	var report_path := "%s/%s.json" % [reports_dir, report_id]
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		_set_bug_report_status("Could not save the bug report file.")
		return
	file.store_string(JSON.stringify(report_data, "\t"))
	file.flush()
	file.close()

	_set_bug_report_status("Bug report saved to %s" % report_path)
	status_label.text = "Bug report saved to %s" % report_path
	_bug_report_expected_edit.text = ""
	_bug_report_actual_edit.text = ""
	_bug_report_selected_screenshot_path = ""
	_refresh_bug_report_screenshot_preview()

func _set_bug_report_status(message: String) -> void:
	if _bug_report_status_label == null:
		return
	_bug_report_status_label.visible = not message.is_empty()
	_bug_report_status_label.text = message

func _ensure_user_directory(path: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(global_path)

func _copy_bug_report_screenshot(source_path: String, screenshots_dir: String, report_id: String) -> String:
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return ""
	var bytes := source_file.get_buffer(source_file.get_length())
	source_file.close()
	var extension := source_path.get_extension().to_lower()
	if extension.is_empty():
		extension = "png"
	var destination_path := "%s/%s.%s" % [screenshots_dir, report_id, extension]
	var destination_file := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination_file == null:
		return ""
	destination_file.store_buffer(bytes)
	destination_file.flush()
	destination_file.close()
	return destination_path

func _maybe_show_auth_onboarding() -> void:
	if _local_profile_store == null:
		return
	if _auth_onboarding_overlay != null and is_instance_valid(_auth_onboarding_overlay):
		return
	_show_auth_onboarding()

func _prompt_account_login() -> void:
	if _local_profile_store != null:
		_local_profile_store.set_preferred_auth_mode(AUTH_MODE_LOGIN)
		_local_profile_store.clear_account_password()
	_set_auth_mode(AUTH_MODE_LOGIN)
	if _password_line_edit != null:
		_password_line_edit.text = ""
	if _auth_onboarding_overlay == null or not is_instance_valid(_auth_onboarding_overlay):
		_show_auth_onboarding()
	_begin_auth_onboarding_account_flow(AUTH_MODE_LOGIN)

func _is_account_logged_in() -> bool:
	return not _logged_in_account_username.is_empty()

func _on_switch_account_pressed() -> void:
	_cleanup_lobby(true)
	_logged_in_account_username = ""
	_current_profile_summary.clear()
	_refresh_profile_summary_label()
	_refresh_account_identity_label()
	_refresh_auth_controls()
	_prompt_account_login()

func _show_auth_onboarding() -> void:
	_auth_onboarding_selected_mode = AUTH_MODE_GUEST
	_auth_onboarding_overlay = Control.new()
	_auth_onboarding_overlay.name = "AuthOnboardingOverlay"
	_auth_onboarding_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_auth_onboarding_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_auth_onboarding_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_auth_onboarding_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_auth_onboarding_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.10, 0.16, 0.98)
	panel_style.border_color = Color(0.38, 0.66, 1.0, 0.95)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		panel_style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(420, 0)
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	content.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	margin.add_child(inner)

	var title := Label.new()
	title.text = "Sign In"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title)

	var body := Label.new()
	body.text = "Use your account to keep decks, stats, and match history tied to your profile."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(body)

	var button_column := VBoxContainer.new()
	button_column.add_theme_constant_override("separation", 8)
	inner.add_child(button_column)

	var login_btn := Button.new()
	login_btn.text = "Login"
	login_btn.custom_minimum_size = Vector2(0, 40)
	login_btn.pressed.connect(func() -> void:
		_begin_auth_onboarding_account_flow(AUTH_MODE_LOGIN)
	)
	button_column.add_child(login_btn)

	var register_btn := Button.new()
	register_btn.text = "Create Account"
	register_btn.custom_minimum_size = Vector2(0, 40)
	register_btn.pressed.connect(func() -> void:
		_begin_auth_onboarding_account_flow(AUTH_MODE_REGISTER)
	)
	button_column.add_child(register_btn)

	var guest_btn := Button.new()
	guest_btn.text = "Continue as Guest"
	guest_btn.custom_minimum_size = Vector2(0, 40)
	guest_btn.pressed.connect(func() -> void:
		_complete_auth_onboarding(
			AUTH_MODE_GUEST,
			"Guest mode selected. Open Multiplayer whenever you're ready."
		)
	)
	button_column.add_child(guest_btn)

	_auth_onboarding_mode_hint_label = Label.new()
	_auth_onboarding_mode_hint_label.text = ""
	_auth_onboarding_mode_hint_label.visible = false
	_auth_onboarding_mode_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auth_onboarding_mode_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_auth_onboarding_mode_hint_label.modulate = Color(0.76, 0.80, 0.92)
	inner.add_child(_auth_onboarding_mode_hint_label)

	_auth_onboarding_username_edit = LineEdit.new()
	_auth_onboarding_username_edit.placeholder_text = "Account username"
	_auth_onboarding_username_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auth_onboarding_username_edit.visible = false
	_auth_onboarding_username_edit.text_submitted.connect(func(_text: String) -> void:
		_submit_auth_onboarding()
	)
	inner.add_child(_auth_onboarding_username_edit)

	_auth_onboarding_password_edit = LineEdit.new()
	_auth_onboarding_password_edit.placeholder_text = "Account password"
	_auth_onboarding_password_edit.secret = true
	_auth_onboarding_password_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auth_onboarding_password_edit.visible = false
	_auth_onboarding_password_edit.text_submitted.connect(func(_text: String) -> void:
		_submit_auth_onboarding()
	)
	inner.add_child(_auth_onboarding_password_edit)

	var continue_row := HBoxContainer.new()
	continue_row.add_theme_constant_override("separation", 8)
	inner.add_child(continue_row)

	_auth_onboarding_continue_button = Button.new()
	_auth_onboarding_continue_button.text = "Login"
	_auth_onboarding_continue_button.custom_minimum_size = Vector2(0, 40)
	_auth_onboarding_continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auth_onboarding_continue_button.pressed.connect(func() -> void:
		_submit_auth_onboarding()
	)
	continue_row.add_child(_auth_onboarding_continue_button)

	_begin_auth_onboarding_account_flow(_get_launch_auth_mode())

func _begin_auth_onboarding_account_flow(auth_mode: String) -> void:
	_auth_onboarding_selected_mode = auth_mode
	_set_auth_onboarding_hint("")
	if _auth_onboarding_username_edit != null:
		_auth_onboarding_username_edit.visible = true
		if _auth_onboarding_username_edit.text.strip_edges().is_empty():
			var saved_username := ""
			if _local_profile_store != null:
				saved_username = _local_profile_store.get_last_account_username()
			if saved_username.is_empty():
				saved_username = player_name_line_edit.text.strip_edges()
			_auth_onboarding_username_edit.text = saved_username
	if _auth_onboarding_password_edit != null:
		_auth_onboarding_password_edit.visible = true
		if _local_profile_store != null:
			_auth_onboarding_password_edit.text = _local_profile_store.get_last_account_password()
		else:
			_auth_onboarding_password_edit.text = ""
	if _auth_onboarding_continue_button != null:
		_auth_onboarding_continue_button.visible = true
		_auth_onboarding_continue_button.text = "Create Account" if auth_mode == AUTH_MODE_REGISTER else "Login"
	if _auth_onboarding_username_edit != null and _auth_onboarding_username_edit.text.strip_edges().is_empty():
		_auth_onboarding_username_edit.grab_focus()
	elif _auth_onboarding_password_edit != null:
		_auth_onboarding_password_edit.grab_focus()

func _submit_auth_onboarding() -> bool:
	var auth_mode := _auth_onboarding_selected_mode
	if auth_mode == AUTH_MODE_GUEST:
		_complete_auth_onboarding(
			AUTH_MODE_GUEST,
			"Guest mode selected. Open Multiplayer whenever you're ready."
		)
		return true
	if auth_mode not in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return false
	var username := ""
	var password := ""
	if _auth_onboarding_username_edit != null:
		username = _auth_onboarding_username_edit.text.strip_edges()
	if _auth_onboarding_password_edit != null:
		password = _auth_onboarding_password_edit.text
	if username.is_empty():
		_set_auth_onboarding_hint("Enter an account username to continue.", true)
		if _auth_onboarding_username_edit != null:
			_auth_onboarding_username_edit.grab_focus()
		return false
	if password.is_empty():
		_set_auth_onboarding_hint("Enter an account password to continue.", true)
		if _auth_onboarding_password_edit != null:
			_auth_onboarding_password_edit.grab_focus()
		return false
	if _local_profile_store != null:
		_local_profile_store.remember_account_username(username)
		_local_profile_store.remember_account_password(password)
	player_name_line_edit.text = username
	if _password_line_edit != null:
		_password_line_edit.text = password
	_complete_auth_onboarding(auth_mode, "Account details saved. Open Multiplayer to sign in.")
	return true

func _get_launch_auth_mode() -> String:
	if _local_profile_store == null:
		return AUTH_MODE_GUEST
	var saved_username: String = _local_profile_store.get_last_account_username()
	if not saved_username.is_empty():
		return AUTH_MODE_LOGIN
	var preferred_auth_mode: String = _local_profile_store.get_preferred_auth_mode()
	if preferred_auth_mode in [AUTH_MODE_GUEST, AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return preferred_auth_mode
	return AUTH_MODE_GUEST

func _set_auth_onboarding_hint(message: String, is_error: bool = false) -> void:
	if _auth_onboarding_mode_hint_label == null:
		return
	_auth_onboarding_mode_hint_label.visible = not message.is_empty()
	_auth_onboarding_mode_hint_label.text = message
	_auth_onboarding_mode_hint_label.modulate = Color(1.0, 0.72, 0.72) if is_error else Color(0.76, 0.80, 0.92)

func _complete_auth_onboarding(auth_mode: String, message: String) -> void:
	_set_auth_mode(auth_mode)
	if _local_profile_store != null:
		_local_profile_store.set_preferred_auth_mode(auth_mode)
		_local_profile_store.mark_auth_onboarding_seen()
	multiplayer_container.visible = false
	ready_button.visible = false
	status_label.text = message
	show_menu()
	_refresh_auth_controls()
	if multiplayer_button != null:
		multiplayer_button.grab_focus()
	_dismiss_auth_onboarding()

func _dismiss_auth_onboarding() -> void:
	if _auth_onboarding_overlay == null:
		return
	if is_instance_valid(_auth_onboarding_overlay):
		_auth_onboarding_overlay.queue_free()
	_auth_onboarding_overlay = null
	_auth_onboarding_mode_hint_label = null
	_auth_onboarding_username_edit = null
	_auth_onboarding_password_edit = null
	_auth_onboarding_continue_button = null

func _on_deck_builder_pressed() -> void:
	_cleanup_lobby(true)

	var existing := game_container.get_node_or_null("DeckBuilder")
	if existing:
		existing.queue_free()

	var db := DeckBuilderUI.new()
	db.name = "DeckBuilder"
	db.configure_profile_store(_local_profile_store, _local_profile_id, _get_player_name("Player"))
	if db.has_method("configure_online_sync"):
		db.configure_online_sync(lobby_client)
	db.back_pressed.connect(func() -> void:
		db.queue_free()
		show_menu()
	)
	get_node("GameContainer/MockGame").visible = false
	get_node("GameContainer/CardTest").visible = false
	game_container.add_child(db)
	show_game()

func _on_mock_game_pressed() -> void:
	_match_launch_queued = false
	_cleanup_lobby(true)
	get_node("GameContainer/MockGame").visible = true
	get_node("GameContainer/CardTest").visible = false
	show_game()
	get_node("GameContainer/MockGame").start_game()

func _on_card_test_pressed() -> void:
	_match_launch_queued = false
	_cleanup_lobby(true)
	get_node("GameContainer/CardTest").visible = true
	get_node("GameContainer/MockGame").visible = false
	show_game()
	get_node("GameContainer/CardTest").start_game()

func _on_host_game_pressed() -> void:
	var target_error := _validate_multiplayer_target()
	if not target_error.is_empty():
		status_label.text = target_error
		return
	var auth_error := _validate_auth_inputs()
	if not auth_error.is_empty():
		status_label.text = auth_error
		return
	_match_launch_queued = false
	_cleanup_lobby(false)
	_is_local_lobby_host = true
	_pending_host_room_creation = true
	_current_lobby_ip = _get_lobby_ip()
	_write_smoke_trace("host_pressed")
	multiplayer_container.visible = true
	ready_button.visible = false
	status_label.text = "Starting dedicated lobby server..."
	_dedicated_lobby_connect_attempts_remaining = 20
	_spawned_lobby_process_id = _launch_dedicated_lobby_server()
	if _spawned_lobby_process_id <= 0:
		status_label.text = "Could not start the dedicated lobby server. Make sure ClaudeOtherGodsServer.exe is installed with the client."
		return
	if _spawned_lobby_process_id > 0:
		_write_smoke_trace("host_spawned_lobby_pid=%d" % _spawned_lobby_process_id)
		_write_smoke_lobby_pid(_spawned_lobby_process_id)
	call_deferred("_connect_local_host_to_dedicated_lobby")

func _on_join_game_pressed() -> void:
	_match_launch_queued = false
	_cleanup_lobby(false)
	_is_local_lobby_host = false
	_pending_host_room_creation = false
	multiplayer_container.visible = true
	ready_button.visible = false
	status_label.text = "Enter a room code, then join the lobby."

func _on_connect_pressed() -> void:
	var target_error := _validate_multiplayer_target()
	if not target_error.is_empty():
		status_label.text = target_error
		return
	_match_launch_queued = false
	_pending_host_room_creation = false
	_pending_join_room_code = room_code_line_edit.text.strip_edges().to_upper()
	_write_smoke_trace("join_connect_pressed room=%s" % _pending_join_room_code)
	if _pending_join_room_code.is_empty():
		status_label.text = "Enter a room code before joining."
		return

	_cleanup_lobby_client()
	_is_local_lobby_host = false
	_current_lobby_ip = _get_lobby_ip()
	status_label.text = "Connecting to lobby..."

	lobby_client = LobbyClientScript.new()
	lobby_client.name = "LobbyPeer"
	lobby_client.use_default_multiplayer = true
	_configure_lobby_client_trace(lobby_client)
	_attach_lobby_client(lobby_client)
	_bind_lobby_client_signals()

	var connect_err: Error = lobby_client.connect_to_server(
		_current_lobby_ip,
		_get_lobby_login_name("Guest"),
		_lobby_session_id,
		_lobby_reconnect_token,
		_get_configured_lobby_port(),
		_local_profile_id,
		_get_selected_auth_mode(),
		_get_auth_password()
	)
	if connect_err != OK:
		status_label.text = "Could not connect to the lobby."

func _connect_local_host_to_dedicated_lobby() -> void:
	var auth_error := _validate_auth_inputs()
	if not auth_error.is_empty():
		status_label.text = auth_error
		_fail_smoke_if_enabled("AUTH_ERROR:%s" % auth_error)
		return
	_write_smoke_trace("host_connect_attempt remaining=%d" % _dedicated_lobby_connect_attempts_remaining)
	if _dedicated_lobby_connect_attempts_remaining <= 0:
		status_label.text = "Dedicated lobby server did not become available."
		_fail_smoke_if_enabled("LOBBY_HOST_CONNECT_TIMEOUT")
		return
	_dedicated_lobby_connect_attempts_remaining -= 1
	if _smoke_config.has("lobby_ready_file"):
		var ready_file := str(_smoke_config.get("lobby_ready_file", "")).strip_edges()
		if not ready_file.is_empty() and not FileAccess.file_exists(ready_file):
			var ready_wait_timer := get_tree().create_timer(0.5)
			ready_wait_timer.timeout.connect(func() -> void:
				_connect_local_host_to_dedicated_lobby()
			)
			return
	var wait_seconds := 0.8 if _spawned_lobby_process_id > 0 else 0.25
	await get_tree().create_timer(wait_seconds).timeout
	_cleanup_lobby_client()
	status_label.text = "Connecting to dedicated lobby..."
	_write_smoke_trace("host_connecting_to_lobby ip=%s port=%d" % [_current_lobby_ip, _get_configured_lobby_port()])
	lobby_client = LobbyClientScript.new()
	lobby_client.name = "LobbyPeer"
	lobby_client.use_default_multiplayer = true
	_configure_lobby_client_trace(lobby_client)
	_attach_lobby_client(lobby_client)
	_bind_lobby_client_signals()
	var connect_err: Error = lobby_client.connect_to_server(
		_current_lobby_ip,
		_get_lobby_login_name("Host"),
		_lobby_session_id,
		_lobby_reconnect_token,
		_get_configured_lobby_port(),
		_local_profile_id,
		_get_selected_auth_mode(),
		_get_auth_password()
	)
	if connect_err != OK:
		_queue_host_lobby_retry("Could not connect to dedicated lobby at %s." % _current_lobby_ip)

func _on_ready_button_pressed() -> void:
	status_label.text = "Your seek locks in automatically once your selected deck is valid."

func _bind_lobby_server_signals() -> void:
	if lobby_server == null:
		return
	if not lobby_server.local_room_snapshot_updated.is_connected(_on_local_room_snapshot_updated):
		lobby_server.local_room_snapshot_updated.connect(_on_local_room_snapshot_updated)
	if not lobby_server.local_match_assigned.is_connected(_on_local_match_assigned):
		lobby_server.local_match_assigned.connect(_on_local_match_assigned)
	if not lobby_server.status_changed.is_connected(_on_lobby_status_changed):
		lobby_server.status_changed.connect(_on_lobby_status_changed)

func _bind_lobby_client_signals() -> void:
	if lobby_client == null:
		return
	if not lobby_client.connected_to_lobby.is_connected(_on_lobby_connected):
		lobby_client.connected_to_lobby.connect(_on_lobby_connected)
	if not lobby_client.login_succeeded.is_connected(_on_lobby_login_succeeded):
		lobby_client.login_succeeded.connect(_on_lobby_login_succeeded)
	if not lobby_client.reconnect_succeeded.is_connected(_on_lobby_reconnect_succeeded):
		lobby_client.reconnect_succeeded.connect(_on_lobby_reconnect_succeeded)
	if not lobby_client.room_list_updated.is_connected(_on_lobby_room_list_updated):
		lobby_client.room_list_updated.connect(_on_lobby_room_list_updated)
	if not lobby_client.room_snapshot_updated.is_connected(_on_lobby_room_snapshot_updated):
		lobby_client.room_snapshot_updated.connect(_on_lobby_room_snapshot_updated)
	if not lobby_client.room_error.is_connected(_on_lobby_room_error):
		lobby_client.room_error.connect(_on_lobby_room_error)
	if not lobby_client.match_assigned.is_connected(_on_remote_match_assigned):
		lobby_client.match_assigned.connect(_on_remote_match_assigned)
	if not lobby_client.account_deck_list_received.is_connected(_on_account_deck_list_received):
		lobby_client.account_deck_list_received.connect(_on_account_deck_list_received)
	if not lobby_client.account_deck_saved.is_connected(_on_account_deck_saved):
		lobby_client.account_deck_saved.connect(_on_account_deck_saved)
	if not lobby_client.account_deck_deleted.is_connected(_on_account_deck_deleted):
		lobby_client.account_deck_deleted.connect(_on_account_deck_deleted)
	if not lobby_client.profile_summary_received.is_connected(_on_profile_summary_received):
		lobby_client.profile_summary_received.connect(_on_profile_summary_received)
	if not lobby_client.connection_failed.is_connected(_on_lobby_connection_failed):
		lobby_client.connection_failed.connect(_on_lobby_connection_failed)
	if not lobby_client.disconnected_from_lobby.is_connected(_on_lobby_disconnected):
		lobby_client.disconnected_from_lobby.connect(_on_lobby_disconnected)

func _on_lobby_connected() -> void:
	_write_smoke_trace("lobby_connected")
	status_label.text = "Connected to lobby. Signing in..."

func _on_lobby_login_succeeded(session_id: String, reconnect_token: String, player_name: String) -> void:
	_write_smoke_trace("lobby_login_succeeded session=%s player=%s host=%s" % [session_id, player_name, str(_is_local_lobby_host)])
	_lobby_session_id = session_id
	_lobby_reconnect_token = reconnect_token
	_capture_logged_in_profile(player_name)
	_refresh_account_identity_label()
	_save_lobby_resume()
	_current_profile_summary.clear()
	_refresh_profile_summary_label()
	_maybe_request_account_decks()
	_maybe_request_profile_summary()
	player_name_line_edit.text = player_name
	_update_resume_controls()
	status_label.text = "Signed in as %s." % player_name
	_run_pending_multiplayer_action()

func _on_lobby_reconnect_succeeded(
	session_id: String,
	reconnect_token: String,
	player_name: String,
	room: Dictionary,
	active_match_info: Dictionary
) -> void:
	_write_smoke_trace("lobby_reconnect_succeeded session=%s player=%s" % [session_id, player_name])
	_lobby_session_id = session_id
	_lobby_reconnect_token = reconnect_token
	_capture_logged_in_profile(player_name)
	_refresh_account_identity_label()
	_save_lobby_resume()
	_current_profile_summary.clear()
	_refresh_profile_summary_label()
	_maybe_request_account_decks()
	_maybe_request_profile_summary()
	player_name_line_edit.text = player_name
	_update_resume_controls()
	if not active_match_info.is_empty():
		_save_active_match_resume(active_match_info)
		status_label.text = "Lobby session restored. Rejoining your active match..."
		call_deferred("_resume_active_match_from_lobby", active_match_info)
		return
	if not _get_saved_active_match().is_empty():
		_clear_saved_match_resume()
	if _pending_host_room_creation:
		if room.is_empty():
			status_label.text = "Lobby session restored."
			_run_pending_multiplayer_action()
			return
	if room.is_empty():
		status_label.text = "Lobby session restored."
		_run_pending_multiplayer_action()
		return
	_apply_room_snapshot(room)
	status_label.text = "Lobby session restored."

func _on_lobby_room_list_updated(rooms: Array) -> void:
	_open_seek_rooms.clear()
	var current_room_id := str(_current_room_snapshot.get("room_id", "")).strip_edges()
	var current_room_still_visible := false
	for room in rooms:
		if not (room is Dictionary):
			continue
		var entry: Dictionary = (room as Dictionary).duplicate(true)
		if str(entry.get("room_id", "")).strip_edges() == current_room_id:
			current_room_still_visible = true
		if int(entry.get("member_count", 0)) >= int(entry.get("max_players", 2)):
			continue
		if str(entry.get("status", "")).strip_edges().to_lower() == "in_match":
			continue
		_open_seek_rooms.append(entry)
	if not current_room_id.is_empty() and not current_room_still_visible:
		_clear_current_seek_state()
	_refresh_seek_list()
	if _current_room_snapshot.is_empty():
		if _open_seek_rooms.is_empty():
			status_label.text = "No open seeks right now. Create one to start a match."
		else:
			status_label.text = "Click an open seek to join, or create your own."
	_refresh_multiplayer_action_state()

func _on_lobby_room_snapshot_updated(snapshot: Dictionary) -> void:
	_apply_room_snapshot(snapshot)

func _on_local_room_snapshot_updated(snapshot: Dictionary) -> void:
	_apply_room_snapshot(snapshot)

func _apply_room_snapshot(snapshot: Dictionary) -> void:
	_current_room_snapshot = snapshot.duplicate(true)
	var room_id := str(snapshot.get("room_id", "")).strip_edges()
	if room_id.is_empty():
		return
	_write_smoke_trace("room_snapshot room=%s members=%d" % [room_id, snapshot.get("members", []).size()])
	room_code_line_edit.text = room_id
	_write_smoke_room_code(room_id)
	_maybe_submit_current_profile_deck(room_id, snapshot)
	ready_button.visible = false
	leave_seek_button.visible = true

	var member_lines: Array[String] = []
	var local_member: Dictionary = {}
	for member in snapshot.get("members", []):
		var player_name := str(member.get("player_name", "Guest"))
		var ready_text := "ready" if bool(member.get("is_ready", false)) else "waiting"
		var connect_text := "online" if bool(member.get("is_connected", false)) else "offline"
		var host_text := " (host)" if bool(member.get("is_host", false)) else ""
		var deck_text := "deck ok" if bool(member.get("has_valid_deck", false)) else "deck missing"
		var selected_deck_name := str(member.get("selected_deck_name", "")).strip_edges()
		if not selected_deck_name.is_empty():
			deck_text = selected_deck_name
		if str(member.get("session_id", "")) == _lobby_session_id:
			local_member = (member as Dictionary).duplicate(true)
		member_lines.append("%s%s - %s, %s, %s" % [player_name, host_text, ready_text, connect_text, deck_text])

	var guidance := "Waiting for another player to join your seek."
	if int(snapshot.get("member_count", 0)) >= int(snapshot.get("max_players", 2)):
		guidance = "Both players are here. Launching automatically once both decks are valid."
	var local_deck_message := ""
	var deck_error := str(local_member.get("deck_error", "")).strip_edges()
	if not deck_error.is_empty():
		local_deck_message = deck_error
	elif not str(local_member.get("selected_deck_name", "")).strip_edges().is_empty():
		local_deck_message = "Your deck: %s" % str(local_member.get("selected_deck_name", ""))
	status_label.text = "Seek %s\n%s\n%s%s" % [
		room_id,
		"\n".join(member_lines),
		guidance,
		"\n%s" % local_deck_message if not local_deck_message.is_empty() else ""
	]
	_refresh_multiplayer_action_state()
	_maybe_progress_smoke_from_room_snapshot(room_id)

func _on_local_match_assigned(match_info: Dictionary) -> void:
	if _match_launch_queued:
		return
	_match_launch_queued = true
	_save_active_match_resume(match_info)
	_write_smoke_trace("local_match_assigned match=%s" % str(match_info.get("match_id", "")))
	status_label.text = "Both players joined. Preparing the match server..."
	_write_smoke_result("MATCH_ASSIGNED_HOST:%s" % str(match_info))
	call_deferred("_launch_host_match_after_lobby_handoff", match_info)

func _on_remote_match_assigned(match_info: Dictionary) -> void:
	if _match_launch_queued:
		return
	_match_launch_queued = true
	_save_active_match_resume(match_info)
	_write_smoke_trace("remote_match_assigned match=%s" % str(match_info.get("match_id", "")))
	var match_ip := str(match_info.get("server_ip", _current_lobby_ip))
	var match_port := int(match_info.get("match_port", _get_configured_match_port()))
	status_label.text = "Match found. Connecting to %s..." % match_ip
	_write_smoke_result("MATCH_ASSIGNED_CLIENT:%s" % str(match_info))
	_cleanup_lobby(false)
	call_deferred("_launch_assigned_match", false, match_ip, match_port, match_info)

func _launch_assigned_match(
	is_host: bool,
	server_ip: String,
	match_port: int = LobbyProtocolScript.MATCH_PORT,
	match_info: Dictionary = {},
	server_match_session = null
) -> void:
	get_node("GameContainer/MockGame").visible = true
	get_node("GameContainer/CardTest").visible = false
	show_game()
	if is_host:
		get_node("GameContainer/MockGame").start_game(true, false, server_ip, match_port, match_info, server_match_session)
		_finish_smoke_if_enabled("PASS:host_launched_match")
		return
	var connect_delay_seconds := 0.4
	if _uses_dedicated_match_server(match_info):
		connect_delay_seconds = 1.1
	await get_tree().create_timer(connect_delay_seconds).timeout
	get_node("GameContainer/MockGame").start_game(false, true, server_ip, match_port, match_info)
	_finish_smoke_if_enabled("PASS:client_launched_match")

func _launch_host_match_after_lobby_handoff(match_info: Dictionary) -> void:
	if _uses_dedicated_match_server(match_info):
		await get_tree().create_timer(1.1).timeout
		_launch_assigned_match(
			false,
			str(match_info.get("server_ip", _current_lobby_ip)),
			int(match_info.get("match_port", _get_configured_match_port())),
			match_info
		)
		return
	var match_session = null
	if lobby_server != null:
		match_session = lobby_server.get_match_session(str(match_info.get("match_id", "")))
	await get_tree().create_timer(0.75).timeout
	_cleanup_lobby(false)
	_launch_assigned_match(
		true,
		str(match_info.get("server_ip", _current_lobby_ip)),
		int(match_info.get("match_port", _get_configured_match_port())),
		match_info,
		match_session
	)

func _uses_dedicated_match_server(match_info: Dictionary) -> bool:
	return str(match_info.get("server_mode", "")) == MatchSessionScript.SERVER_MODE_DEDICATED_HEADLESS

func _on_lobby_room_error(message: String) -> void:
	_write_smoke_trace("lobby_room_error %s" % message)
	status_label.text = message
	_fail_smoke_if_enabled("ROOM_ERROR:%s" % message)

func _on_lobby_status_changed(message: String) -> void:
	_write_smoke_trace("lobby_status %s" % message)
	status_label.text = message

func _on_lobby_connection_failed(message: String) -> void:
	_write_smoke_trace("lobby_connection_failed %s" % message)
	if _should_retry_host_lobby_connect():
		_queue_host_lobby_retry(message)
		return
	_logged_in_account_username = ""
	_refresh_account_identity_label()
	status_label.text = message
	_fail_smoke_if_enabled("CONNECTION_FAILED:%s" % message)

func _on_lobby_disconnected() -> void:
	_write_smoke_trace("lobby_disconnected")
	if _should_retry_host_lobby_connect():
		_queue_host_lobby_retry("Dedicated lobby disconnected before room setup completed.")
		return
	_logged_in_account_username = ""
	_refresh_account_identity_label()
	_clear_current_seek_state()
	status_label.text = "Lobby connection lost. Refresh open seeks to reconnect."
	_fail_smoke_if_enabled("DISCONNECTED_FROM_LOBBY")

func _on_back_to_menu_pressed() -> void:
	_return_to_menu()

func _on_game_forfeit_requested() -> void:
	_return_to_menu()

func _return_to_menu() -> void:
	show_menu()
	_match_launch_queued = false
	_cleanup_lobby(true)
	for node_name in ["MockGame", "CardTest"]:
		var game = get_node_or_null("GameContainer/" + node_name)
		if game and game.has_method("cleanup"):
			game.cleanup()
	var db := game_container.get_node_or_null("DeckBuilder")
	if db:
		db.queue_free()
	multiplayer_container.visible = false

func _cleanup_lobby(clear_session: bool) -> void:
	_cleanup_lobby_client()
	_cleanup_lobby_server()
	_clear_current_seek_state()
	_open_seek_rooms.clear()
	_refresh_seek_list()
	if clear_session:
		_match_launch_queued = false
		_pending_host_room_creation = false
		_pending_local_lobby_launch_on_connect_failure = false
		_dedicated_lobby_connect_attempts_remaining = 0
		_last_submitted_lobby_room_id = ""
		_last_submitted_lobby_deck_id = ""
		_lobby_session_id = ""
		_lobby_reconnect_token = ""
		_pending_join_room_code = ""
		_pending_join_room_id = ""
		_current_lobby_ip = ""
		_is_local_lobby_host = false
		room_code_line_edit.text = ""
		_clear_saved_lobby_resume()
		_clear_saved_match_resume()
		_current_profile_summary.clear()
		_logged_in_account_username = ""
		_refresh_profile_summary_label()
		_refresh_account_identity_label()
		status_label.text = "Refresh open seeks or create your own."
	_update_resume_controls()
	_refresh_multiplayer_action_state()

func _cleanup_lobby_client() -> void:
	if lobby_client == null:
		return
	lobby_client.disconnect_from_server()
	lobby_client.queue_free()
	lobby_client = null
	_cleanup_dedicated_lobby_mount_if_unused()

func _cleanup_lobby_server() -> void:
	if lobby_server == null:
		return
	lobby_server.stop_server()
	lobby_server.queue_free()
	lobby_server = null

func _attach_lobby_client(client: Node) -> void:
	var active_scene := get_tree().current_scene
	if active_scene == null:
		add_child(client)
		return
	active_scene.add_child(client)
	if client is LobbyClient:
		client.multiplayer_mount_path = active_scene.get_path()

func _cleanup_dedicated_lobby_mount_if_unused() -> void:
	pass

func _configure_lobby_client_trace(client: LobbyClient) -> void:
	if client == null or _smoke_config.is_empty():
		return
	var trace_file := str(_smoke_config.get("trace_file", "")).strip_edges()
	if trace_file.is_empty():
		return
	client.trace_file_path = trace_file

func _is_local_player_ready() -> bool:
	for member in _current_room_snapshot.get("members", []):
		if str(member.get("session_id", "")) == _lobby_session_id:
			return bool(member.get("is_ready", false))
	return false

func _get_configured_lobby_host() -> String:
	if not _smoke_config.is_empty():
		return str(_smoke_config.get("ip", "")).strip_edges()
	var configured_host := str(ProjectSettings.get_setting(DEFAULT_LOBBY_HOST_SETTING, DEFAULT_LOBBY_HOST)).strip_edges()
	if configured_host.is_empty():
		return DEFAULT_LOBBY_HOST.strip_edges()
	return configured_host

func _validate_multiplayer_target() -> String:
	var host := _get_configured_lobby_host()
	if not _smoke_config.is_empty():
		if host.is_empty():
			return "Enter the lobby IP first."
		return ""
	if host.is_empty():
		return "Multiplayer is not configured in this build yet."
	if _is_local_lobby_target(host):
		return "Set application/config/default_lobby_host to your public laptop address before shipping this build."
	return ""

func _get_lobby_ip() -> String:
	return _get_configured_lobby_host()

func _get_player_name(default_name: String) -> String:
	var player_name: String = player_name_line_edit.text.strip_edges()
	if player_name.is_empty():
		return default_name
	return player_name

func _ensure_local_profile_store() -> void:
	if _local_profile_store != null:
		return
	_local_profile_store = LocalProfileStoreScript.new()
	var profile: Dictionary = _local_profile_store.restore_last_profile("Player")
	_local_profile_id = str(profile.get("profile_id", "")).strip_edges()
	var display_name := str(profile.get("display_name", "Player")).strip_edges()
	if not display_name.is_empty():
		player_name_line_edit.text = display_name

func _remember_local_profile(player_name: String) -> String:
	_ensure_local_profile_store()
	if _local_profile_store == null:
		return player_name
	var profile: Dictionary = _local_profile_store.remember_profile(_local_profile_id, player_name)
	_local_profile_id = str(profile.get("profile_id", _local_profile_id)).strip_edges()
	return str(profile.get("display_name", player_name))

func _capture_logged_in_profile(player_name: String) -> void:
	_ensure_local_profile_store()
	if _local_profile_store == null:
		return
	var resolved_auth_mode := AUTH_MODE_GUEST
	if lobby_client != null:
		_local_profile_id = str(lobby_client.current_profile_id).strip_edges()
		if not str(lobby_client.current_account_id).strip_edges().is_empty():
			_logged_in_account_username = str(lobby_client.current_username).strip_edges()
			resolved_auth_mode = AUTH_MODE_LOGIN
		else:
			_logged_in_account_username = ""
		if not str(lobby_client.current_username).strip_edges().is_empty():
			_local_profile_store.remember_account_username(str(lobby_client.current_username))
			_local_profile_store.set_preferred_auth_mode(AUTH_MODE_LOGIN)
			if _password_line_edit != null and not _password_line_edit.text.is_empty():
				_local_profile_store.remember_account_password(_password_line_edit.text)
		else:
			_local_profile_store.set_preferred_auth_mode(AUTH_MODE_GUEST)
	_set_auth_mode(resolved_auth_mode)
	var profile: Dictionary = _local_profile_store.remember_profile(_local_profile_id, player_name)
	_local_profile_id = str(profile.get("profile_id", _local_profile_id)).strip_edges()
	_update_resume_controls()
	_refresh_account_identity_label()

func _maybe_request_account_decks() -> void:
	if lobby_client == null:
		return
	if str(lobby_client.current_account_id).strip_edges().is_empty():
		return
	lobby_client.request_account_decks()

func _maybe_request_profile_summary() -> void:
	if lobby_client == null:
		return
	if str(lobby_client.current_profile_id).strip_edges().is_empty():
		return
	lobby_client.request_profile_summary()

func _on_account_deck_list_received(decks) -> void:
	_ensure_local_profile_store()
	if _local_profile_store == null or _local_profile_id.is_empty():
		return
	var remote_decks: Array[Dictionary] = []
	if decks is Array:
		for entry in decks:
			if entry is Dictionary:
				remote_decks.append((entry as Dictionary).duplicate(true))
	if remote_decks.is_empty():
		for local_deck in _local_profile_store.list_decks(_local_profile_id):
			if lobby_client == null:
				break
			lobby_client.save_account_deck(
				str(local_deck.get("name", "")),
				local_deck.get("cards", {}),
				str(local_deck.get("deck_id", ""))
			)
		_refresh_open_deck_builder_saved_decks()
		return
	_local_profile_store.merge_decks(_local_profile_id, remote_decks)
	_refresh_open_deck_builder_saved_decks()

func _on_account_deck_saved(deck) -> void:
	_ensure_local_profile_store()
	if _local_profile_store == null or _local_profile_id.is_empty() or not (deck is Dictionary):
		return
	_local_profile_store.upsert_saved_deck(_local_profile_id, deck as Dictionary)
	_refresh_open_deck_builder_saved_decks()

func _on_account_deck_deleted(deck_id: String) -> void:
	_ensure_local_profile_store()
	if _local_profile_store == null or _local_profile_id.is_empty():
		return
	_local_profile_store.delete_deck(_local_profile_id, deck_id)
	_refresh_open_deck_builder_saved_decks()

func _on_profile_summary_received(summary) -> void:
	if not (summary is Dictionary):
		return
	_current_profile_summary = (summary as Dictionary).duplicate(true)
	_refresh_profile_summary_label()

func _refresh_open_deck_builder_saved_decks() -> void:
	_refresh_multiplayer_deck_options()
	var deck_builder = game_container.get_node_or_null("DeckBuilder")
	if deck_builder == null or not deck_builder.has_method("reload_saved_decks_from_store"):
		return
	deck_builder.reload_saved_decks_from_store()

func _build_profile_summary_controls() -> void:
	if multiplayer_container == null or _profile_summary_label != null:
		return
	_profile_summary_label = Label.new()
	_profile_summary_label.name = "ProfileSummaryLabel"
	_profile_summary_label.visible = false
	_profile_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_profile_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	multiplayer_container.add_child(_profile_summary_label)

func _build_account_identity_controls() -> void:
	if _account_identity_label != null:
		return
	_account_identity_label = Label.new()
	_account_identity_label.name = "AccountIdentityLabel"
	_account_identity_label.visible = false
	_account_identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_account_identity_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_account_identity_label.anchor_left = 1.0
	_account_identity_label.anchor_right = 1.0
	_account_identity_label.offset_left = -280
	_account_identity_label.offset_right = -18
	_account_identity_label.offset_top = 16
	_account_identity_label.offset_bottom = 48
	add_child(_account_identity_label)
	_refresh_account_identity_label()

func _refresh_account_identity_label() -> void:
	if _account_identity_label == null:
		return
	if _logged_in_account_username.is_empty():
		_account_identity_label.visible = false
		_account_identity_label.text = ""
		_refresh_auth_controls()
		return
	_account_identity_label.text = "Signed in: %s" % _logged_in_account_username
	_account_identity_label.visible = true
	_refresh_auth_controls()

func _refresh_profile_summary_label() -> void:
	if _profile_summary_label == null:
		return
	if _current_profile_summary.is_empty():
		_profile_summary_label.visible = false
		_profile_summary_label.text = ""
		return
	var total_wins: int = int(_current_profile_summary.get("total_wins", 0))
	var total_losses: int = int(_current_profile_summary.get("total_losses", 0))
	var lines: Array[String] = []
	lines.append("Match Record: %d-%d" % [total_wins, total_losses])

	var god_records = _current_profile_summary.get("god_records", [])
	if god_records is Array and not (god_records as Array).is_empty():
		lines.append("By God:")
		var displayed_god_records: int = 0
		for raw_record in god_records:
			if not (raw_record is Dictionary):
				continue
			var god_record: Dictionary = raw_record as Dictionary
			lines.append("%s %d-%d" % [
				str(god_record.get("god_name", "Unknown God")),
				int(god_record.get("wins", 0)),
				int(god_record.get("losses", 0)),
			])
			displayed_god_records += 1
			if displayed_god_records >= 4:
				break

	var recent_matches = _current_profile_summary.get("recent_matches", [])
	if recent_matches is Array and not (recent_matches as Array).is_empty():
		lines.append("Recent:")
		var displayed_recent_matches: int = 0
		for raw_match in recent_matches:
			if not (raw_match is Dictionary):
				continue
			var recent_match: Dictionary = raw_match as Dictionary
			var result_text: String = "W" if str(recent_match.get("result", "")).to_lower() == "win" else "L"
			lines.append("%s as %s vs %s" % [
				result_text,
				str(recent_match.get("god_name", "Unknown God")),
				str(recent_match.get("opponent_god_name", "Unknown God")),
			])
			displayed_recent_matches += 1
			if displayed_recent_matches >= 3:
				break

	_profile_summary_label.text = "\n".join(lines)
	_profile_summary_label.visible = true

func _build_resume_controls() -> void:
	if multiplayer_container == null or _resume_match_button != null:
		return
	_resume_match_button = Button.new()
	_resume_match_button.name = "ResumeMatchButton"
	_resume_match_button.text = "Resume Match"
	_resume_match_button.visible = false
	_resume_match_button.pressed.connect(_on_resume_match_pressed)
	multiplayer_container.add_child(_resume_match_button)
	var insert_index := multiplayer_container.get_children().find(create_seek_button)
	if insert_index >= 0:
		multiplayer_container.move_child(_resume_match_button, insert_index)

func _restore_saved_resume_state() -> void:
	_update_resume_controls()
	_refresh_profile_summary_label()
	var saved_match := _get_saved_active_match()
	var saved_lobby_resume := _get_saved_lobby_resume()
	if saved_match.is_empty() or saved_lobby_resume.is_empty():
		return
	multiplayer_container.visible = false
	ready_button.visible = false
	status_label.text = "A live match can be resumed from this device."

func _update_resume_controls() -> void:
	if _resume_match_button == null or _local_profile_store == null:
		return
	var has_resume := not _get_saved_active_match().is_empty() and not _get_saved_lobby_resume().is_empty()
	_resume_match_button.visible = has_resume

func _get_saved_lobby_resume() -> Dictionary:
	if _local_profile_store == null:
		return {}
	return _local_profile_store.get_lobby_resume(_get_resume_profile_id())

func _get_saved_active_match() -> Dictionary:
	if _local_profile_store == null:
		return {}
	return _local_profile_store.get_active_match(_get_resume_profile_id())

func _get_resume_profile_id() -> String:
	if _local_profile_store == null:
		return _local_profile_id
	if not _local_profile_store.get_active_match(_local_profile_id).is_empty() and not _local_profile_store.get_lobby_resume(_local_profile_id).is_empty():
		return _local_profile_id
	var fallback_profile_id: String = str(_local_profile_store.get_latest_resume_profile_id())
	if not fallback_profile_id.is_empty():
		return fallback_profile_id
	return _local_profile_id

func _save_lobby_resume() -> void:
	if _local_profile_store == null or _local_profile_id.is_empty() or _lobby_session_id.is_empty() or _lobby_reconnect_token.is_empty():
		return
	var username := ""
	var auth_mode := _get_selected_auth_mode()
	if lobby_client != null:
		username = str(lobby_client.current_username).strip_edges()
		auth_mode = str(lobby_client.current_auth_mode).strip_edges().to_lower()
	_local_profile_store.remember_lobby_resume(
		_local_profile_id,
		_lobby_session_id,
		_lobby_reconnect_token,
		player_name_line_edit.text.strip_edges(),
		_current_lobby_ip,
		_get_configured_lobby_port(),
		username,
		auth_mode
	)
	_update_resume_controls()

func _clear_saved_lobby_resume() -> void:
	if _local_profile_store == null:
		return
	_local_profile_store.clear_lobby_resume(_get_resume_profile_id())
	_update_resume_controls()

func _save_active_match_resume(match_info: Dictionary) -> void:
	if _local_profile_store == null or _local_profile_id.is_empty() or match_info.is_empty():
		return
	_local_profile_store.remember_active_match(_local_profile_id, match_info)
	_update_resume_controls()

func _clear_saved_match_resume() -> void:
	if _local_profile_store == null:
		return
	_local_profile_store.clear_active_match(_get_resume_profile_id())
	_update_resume_controls()

func _on_resume_match_pressed() -> void:
	var resume_profile_id := _get_resume_profile_id()
	var saved_lobby_resume := _get_saved_lobby_resume()
	var saved_match := _get_saved_active_match()
	if saved_lobby_resume.is_empty() or saved_match.is_empty():
		status_label.text = "No saved match resume data was found."
		_update_resume_controls()
		return
	if not resume_profile_id.is_empty():
		_local_profile_id = resume_profile_id
	_cleanup_lobby(false)
	_match_launch_queued = false
	_pending_host_room_creation = false
	_pending_join_room_code = ""
	_is_local_lobby_host = false
	multiplayer_container.visible = true
	ready_button.visible = false
	_current_lobby_ip = str(saved_lobby_resume.get("lobby_ip", _get_configured_lobby_host())).strip_edges()
	if _current_lobby_ip.is_empty():
		status_label.text = "Multiplayer is not configured in this build yet."
		return
	status_label.text = "Restoring your lobby session..."
	lobby_client = LobbyClientScript.new()
	lobby_client.name = "LobbyPeer"
	lobby_client.use_default_multiplayer = true
	_configure_lobby_client_trace(lobby_client)
	_attach_lobby_client(lobby_client)
	_bind_lobby_client_signals()
	var connect_err: Error = lobby_client.connect_to_server(
		_current_lobby_ip,
		str(saved_lobby_resume.get("username", saved_lobby_resume.get("player_name", "Player"))),
		str(saved_lobby_resume.get("session_id", "")),
		str(saved_lobby_resume.get("reconnect_token", "")),
		int(saved_lobby_resume.get("lobby_port", _get_configured_lobby_port())),
		_local_profile_id,
		str(saved_lobby_resume.get("auth_mode", AUTH_MODE_GUEST)),
		""
	)
	if connect_err != OK:
		status_label.text = "Could not restore the saved lobby session."

func _resume_active_match_from_lobby(match_info: Dictionary) -> void:
	if match_info.is_empty() or _match_launch_queued:
		return
	_match_launch_queued = true
	_cleanup_lobby(false)
	call_deferred(
		"_launch_assigned_match",
		false,
		str(match_info.get("server_ip", _current_lobby_ip)),
		int(match_info.get("match_port", _get_configured_match_port())),
		match_info
	)

func _on_match_session_cleared() -> void:
	_clear_saved_match_resume()

func _maybe_submit_current_profile_deck(room_id: String, snapshot: Dictionary) -> void:
	if lobby_client == null or _local_profile_store == null or _lobby_session_id.is_empty():
		return
	var local_member: Dictionary = {}
	for member in snapshot.get("members", []):
		if str(member.get("session_id", "")) != _lobby_session_id:
			continue
		local_member = member
		break
	if local_member.is_empty():
		return

	var selected_deck_id: String = _selected_multiplayer_deck_id.strip_edges()
	var selected_deck: Dictionary = _get_selected_multiplayer_deck()
	if selected_deck.is_empty() and not _smoke_config.is_empty():
		selected_deck = {
			"deck_id": "smoke_default",
			"name": "Smoke Default Deck",
			"cards": {
				"Baldr": 1,
				"Blessed Knights": 3,
				"Brown Bear": 3,
				"Berserker": 3,
				"Again-Walker": 3,
				"Byggvir": 3,
				"Bit Meseri": 3,
				"Absence": 3,
				"Warding Stone": 3,
				"Void Shield": 3,
				"Bearded Axe": 3,
				"Blot Sacrifice": 3,
				"Fall of the Mighty": 2,
			},
		}
		selected_deck_id = "smoke_default"
	if selected_deck.is_empty():
		status_label.text = "Choose a saved legal deck before joining or creating a seek."
		_last_submitted_lobby_room_id = ""
		_last_submitted_lobby_deck_id = ""
		_refresh_multiplayer_action_state()
		return
	var submitted_deck_id := str(local_member.get("selected_deck_id", "")).strip_edges()
	if bool(local_member.get("has_valid_deck", false)) and submitted_deck_id == selected_deck_id:
		_last_submitted_lobby_room_id = room_id
		_last_submitted_lobby_deck_id = selected_deck_id
		return
	if _last_submitted_lobby_room_id == room_id and _last_submitted_lobby_deck_id == selected_deck_id:
		return
	lobby_client.submit_deck(
		str(selected_deck.get("name", "Default Deck")),
		selected_deck.get("cards", {}),
		selected_deck_id
	)
	_last_submitted_lobby_room_id = room_id
	_last_submitted_lobby_deck_id = selected_deck_id

func _get_configured_lobby_port() -> int:
	if _smoke_config.is_empty():
		return LobbyProtocolScript.PORT
	return int(_smoke_config.get("lobby_port", LobbyProtocolScript.PORT))

func _get_configured_match_port() -> int:
	if _smoke_config.is_empty():
		return LobbyProtocolScript.MATCH_PORT
	return int(_smoke_config.get("match_port", LobbyProtocolScript.MATCH_PORT))

func _start_smoke_mode() -> void:
	var role := str(_smoke_config.get("role", "")).to_lower()
	if role.is_empty():
		return

	ip_line_edit.text = str(_smoke_config.get("ip", "127.0.0.1"))
	player_name_line_edit.text = str(_smoke_config.get("player_name", "Smoke%s" % role.capitalize()))
	var smoke_auth_mode: String = str(_smoke_config.get("auth_mode", AUTH_MODE_GUEST)).strip_edges().to_lower()
	if smoke_auth_mode not in [AUTH_MODE_GUEST, AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		smoke_auth_mode = AUTH_MODE_GUEST
	_set_auth_mode(smoke_auth_mode)
	if _password_line_edit != null:
		_password_line_edit.text = str(_smoke_config.get("password", ""))

	var timeout_seconds := float(_smoke_config.get("timeout", 25.0))
	var timeout_timer := get_tree().create_timer(timeout_seconds)
	timeout_timer.timeout.connect(func() -> void:
		_fail_smoke_if_enabled("TIMEOUT")
	)

	if role == "host":
		_on_host_game_pressed()
		return

	if role == "client":
		_on_join_game_pressed()
		var room_code := _read_smoke_room_code()
		if room_code.is_empty():
			_wait_for_smoke_room_code()
			return
		_join_smoke_room(room_code)
		return

	if role == "resume":
		var resume_timer := get_tree().create_timer(0.5)
		resume_timer.timeout.connect(func() -> void:
			_on_resume_match_pressed()
		)

func _wait_for_smoke_room_code() -> void:
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void:
		var room_code := _read_smoke_room_code()
		if room_code.is_empty():
			_wait_for_smoke_room_code()
			return
		_join_smoke_room(room_code)
	)

func _join_smoke_room(room_code: String) -> void:
	room_code_line_edit.text = room_code
	_pending_join_room_code = room_code
	_on_connect_pressed()

func _maybe_progress_smoke_from_room_snapshot(room_id: String) -> void:
	if _smoke_config.is_empty():
		return

	var role := str(_smoke_config.get("role", "")).to_lower()
	if role == "client":
		var expected_room := str(_pending_join_room_code).strip_edges().to_upper()
		if expected_room.is_empty() or room_id != expected_room:
			return

func _parse_smoke_config(args: Array) -> Dictionary:
	var config: Dictionary = {}
	for raw_arg in args:
		var arg := str(raw_arg)
		var separator := arg.find("=")
		if separator <= 0:
			continue
		var key := arg.substr(0, separator)
		var value := arg.substr(separator + 1)
		config[key] = value

	if not config.has("smoke_role"):
		return {}

	return {
		"role": str(config.get("smoke_role", "")),
		"ip": str(config.get("smoke_ip", "127.0.0.1")),
		"player_name": str(config.get("smoke_name", "")),
		"auth_mode": str(config.get("smoke_auth_mode", AUTH_MODE_GUEST)),
		"password": str(config.get("smoke_password", "")),
		"room_file": str(config.get("smoke_room_file", "")),
		"result_file": str(config.get("smoke_result_file", "")),
		"trace_file": str(config.get("smoke_trace_file", "")),
		"lobby_server_trace_file": str(config.get("smoke_lobby_server_trace_file", "")),
		"lobby_server_log_file": str(config.get("smoke_lobby_server_log_file", "")),
		"lobby_pid_file": str(config.get("smoke_lobby_pid_file", "")),
		"lobby_ready_file": str(config.get("smoke_lobby_ready_file", "")),
		"timeout": float(str(config.get("smoke_timeout", "25")).to_float()),
		"lobby_port": int(str(config.get("smoke_lobby_port", str(LobbyProtocolScript.PORT))).to_int()),
		"match_port": int(str(config.get("smoke_match_port", str(LobbyProtocolScript.MATCH_PORT))).to_int()),
	}

func _write_smoke_room_code(room_code: String) -> void:
	if _smoke_config.is_empty():
		return
	var room_file := str(_smoke_config.get("room_file", "")).strip_edges()
	if room_file.is_empty():
		return
	var file := FileAccess.open(room_file, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(room_code)
	file.flush()
	file.close()

func _read_smoke_room_code() -> String:
	if _smoke_config.is_empty():
		return ""
	var room_file := str(_smoke_config.get("room_file", "")).strip_edges()
	if room_file.is_empty() or not FileAccess.file_exists(room_file):
		return ""
	var file := FileAccess.open(room_file, FileAccess.READ)
	if file == null:
		return ""
	var room_code := file.get_as_text().strip_edges().to_upper()
	file.close()
	return room_code

func _write_smoke_result(message: String) -> void:
	if _smoke_config.is_empty():
		return
	var result_file := str(_smoke_config.get("result_file", "")).strip_edges()
	if result_file.is_empty():
		return
	var file := FileAccess.open(result_file, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(message)
	file.flush()
	file.close()

func _write_smoke_trace(message: String) -> void:
	if _smoke_config.is_empty():
		return
	var trace_file := str(_smoke_config.get("trace_file", "")).strip_edges()
	if trace_file.is_empty():
		return
	var file := FileAccess.open(trace_file, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(trace_file, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(message)
	file.flush()
	file.close()

func _write_smoke_lobby_pid(pid: int) -> void:
	if _smoke_config.is_empty():
		return
	var pid_file := str(_smoke_config.get("lobby_pid_file", "")).strip_edges()
	if pid_file.is_empty():
		return
	var file := FileAccess.open(pid_file, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(str(pid))
	file.flush()
	file.close()

func _finish_smoke_if_enabled(message: String) -> void:
	if _smoke_config.is_empty():
		return
	_write_smoke_result(message)

func _fail_smoke_if_enabled(message: String) -> void:
	if _smoke_config.is_empty():
		return
	_write_smoke_result("FAIL:%s" % message)

func _launch_dedicated_lobby_server() -> int:
	var project_path := ProjectSettings.globalize_path("res://")
	var exported_server_path := _resolve_dedicated_server_runtime_path()
	if not exported_server_path.is_empty():
		return _launch_exported_dedicated_lobby_server(exported_server_path)
	if OS.has_feature("template"):
		return 0

	var executable_path := _resolve_headless_executable_path(OS.get_executable_path())
	if project_path.is_empty() or executable_path.is_empty():
		return 0
	var args := PackedStringArray(["--headless"])
	var lobby_server_log_file := str(_smoke_config.get("lobby_server_log_file", "")).strip_edges()
	if not lobby_server_log_file.is_empty():
		args.append_array(["--log-file", lobby_server_log_file])
	if not OS.has_feature("template"):
		args.append("--editor")
	args.append_array([
		"--path",
		project_path,
		"--script",
		DEDICATED_LOBBY_ENTRY_SCRIPT_PATH,
		"--",
		"lobby_host=%s" % _current_lobby_ip,
		"lobby_port=%d" % _get_configured_lobby_port(),
		"match_port=%d" % _get_configured_match_port(),
	])
	var ready_file := str(_smoke_config.get("lobby_ready_file", "")).strip_edges()
	if not ready_file.is_empty():
		args.append("ready_file=%s" % ready_file)
	var lobby_server_trace_file := str(_smoke_config.get("lobby_server_trace_file", "")).strip_edges()
	if not lobby_server_trace_file.is_empty():
		args.append("trace_file=%s" % lobby_server_trace_file)
	return OS.create_process(executable_path, args, false)

func _launch_exported_dedicated_lobby_server(executable_path: String) -> int:
	var args := PackedStringArray(["--headless"])
	var lobby_server_log_file := str(_smoke_config.get("lobby_server_log_file", "")).strip_edges()
	if not lobby_server_log_file.is_empty():
		args.append_array(["--log-file", lobby_server_log_file])
	args.append_array([
		"--",
		"server_mode=lobby",
		"lobby_host=%s" % _current_lobby_ip,
		"lobby_port=%d" % _get_configured_lobby_port(),
		"match_port=%d" % _get_configured_match_port(),
	])
	var ready_file := str(_smoke_config.get("lobby_ready_file", "")).strip_edges()
	if not ready_file.is_empty():
		args.append("ready_file=%s" % ready_file)
	var lobby_server_trace_file := str(_smoke_config.get("lobby_server_trace_file", "")).strip_edges()
	if not lobby_server_trace_file.is_empty():
		args.append("trace_file=%s" % lobby_server_trace_file)
	return OS.create_process(executable_path, args, false)

func _resolve_headless_executable_path(executable_path: String) -> String:
	var normalized_path := executable_path.strip_edges()
	if normalized_path.is_empty():
		return normalized_path
	if normalized_path.ends_with(".exe"):
		var console_candidate := normalized_path.substr(0, normalized_path.length() - 4) + "_console.exe"
		if FileAccess.file_exists(console_candidate):
			return console_candidate
	return normalized_path

func _resolve_dedicated_server_runtime_path() -> String:
	var executable_dir := OS.get_executable_path().get_base_dir()
	var executable_parent_dir := executable_dir.get_base_dir()
	var candidates := PackedStringArray([
		ProjectSettings.globalize_path(DEDICATED_SERVER_EXPORT_RELATIVE_PATH),
		executable_dir.path_join("ClaudeOtherGodsServer.exe"),
		executable_dir.path_join("ClaudeOtherGodsServer_console.exe"),
		executable_dir.path_join("server").path_join("ClaudeOtherGodsServer.exe"),
		executable_parent_dir.path_join("server").path_join("ClaudeOtherGodsServer.exe"),
	])
	for candidate in candidates:
		if candidate.is_empty():
			continue
		if FileAccess.file_exists(candidate):
			return candidate
	return ""

func _should_retry_host_lobby_connect() -> bool:
	return _is_local_lobby_host and not _match_launch_queued and _current_room_snapshot.is_empty()

func _queue_host_lobby_retry(message: String) -> void:
	if _dedicated_lobby_connect_attempts_remaining <= 0:
		status_label.text = message
		_fail_smoke_if_enabled("CONNECTION_FAILED:%s" % message)
		return
	status_label.text = "%s Retrying..." % message
	var timer := get_tree().create_timer(0.75)
	timer.timeout.connect(func() -> void:
		_connect_local_host_to_dedicated_lobby()
	)

func _on_aggressive_stance_btn_pressed() -> void:
	pass

func _on_defensive_stance_btn_pressed() -> void:
	pass

func _on_stealth_mode_btn_pressed() -> void:
	pass

func _on_toggle_mode_button_pressed() -> void:
	pass

func _build_auth_controls() -> void:
	if multiplayer_container == null or menu_container == null:
		return
	if _auth_mode_option == null:
		_auth_mode_option = OptionButton.new()
		_auth_mode_option.name = "AuthModeOption"
		_auth_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_auth_mode_option.add_item("Guest")
		_auth_mode_option.set_item_metadata(0, AUTH_MODE_GUEST)
		_auth_mode_option.add_item("Login")
		_auth_mode_option.set_item_metadata(1, AUTH_MODE_LOGIN)
		_auth_mode_option.add_item("Register")
		_auth_mode_option.set_item_metadata(2, AUTH_MODE_REGISTER)
		_auth_mode_option.item_selected.connect(_on_auth_mode_selected)
		multiplayer_container.add_child(_auth_mode_option)
		var auth_insert_index := multiplayer_container.get_children().find(player_name_line_edit) + 1
		multiplayer_container.move_child(_auth_mode_option, auth_insert_index)
	if _password_line_edit == null:
		_password_line_edit = LineEdit.new()
		_password_line_edit.name = "PasswordLineEdit"
		_password_line_edit.secret = true
		_password_line_edit.placeholder_text = "Account password"
		_password_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		multiplayer_container.add_child(_password_line_edit)
		var password_insert_index := multiplayer_container.get_children().find(_auth_mode_option) + 1
		multiplayer_container.move_child(_password_line_edit, password_insert_index)
	if _switch_account_button == null:
		_switch_account_button = Button.new()
		_switch_account_button.name = "SwitchAccountButton"
		_switch_account_button.text = "Switch Account"
		_switch_account_button.visible = false
		_switch_account_button.pressed.connect(_on_switch_account_pressed)
		menu_container.add_child(_switch_account_button)
		var switch_insert_index := menu_container.get_children().find(multiplayer_button) + 1
		if switch_insert_index <= 0:
			switch_insert_index = menu_container.get_child_count()
		menu_container.move_child(_switch_account_button, switch_insert_index)
	_refresh_auth_controls()

func _restore_auth_preferences() -> void:
	if _local_profile_store == null:
		return
	var auth_mode: String = _local_profile_store.get_preferred_auth_mode()
	_set_auth_mode(auth_mode)
	if auth_mode != AUTH_MODE_GUEST:
		var saved_username: String = _local_profile_store.get_last_account_username()
		if not saved_username.is_empty():
			player_name_line_edit.text = saved_username
		if _password_line_edit != null:
			_password_line_edit.text = _local_profile_store.get_last_account_password()
	_refresh_auth_controls()

func _on_auth_mode_selected(_index: int) -> void:
	_refresh_auth_controls()
	if _local_profile_store == null:
		return
	var auth_mode := _get_selected_auth_mode()
	_local_profile_store.set_preferred_auth_mode(auth_mode)
	if auth_mode != AUTH_MODE_GUEST:
		_local_profile_store.remember_account_username(player_name_line_edit.text)
		if _password_line_edit != null and _password_line_edit.text.is_empty():
			_password_line_edit.text = _local_profile_store.get_last_account_password()

func _set_auth_mode(auth_mode: String) -> void:
	if _auth_mode_option == null:
		return
	for index in range(_auth_mode_option.item_count):
		if str(_auth_mode_option.get_item_metadata(index)) != auth_mode:
			continue
		_auth_mode_option.select(index)
		break
	_refresh_auth_controls()

func _get_selected_auth_mode() -> String:
	if _auth_mode_option == null or _auth_mode_option.item_count <= 0:
		return AUTH_MODE_GUEST
	var metadata = _auth_mode_option.get_item_metadata(_auth_mode_option.selected)
	var auth_mode := str(metadata).strip_edges().to_lower()
	if auth_mode in [AUTH_MODE_GUEST, AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return auth_mode
	return AUTH_MODE_GUEST

func _refresh_auth_controls() -> void:
	var auth_mode := _get_selected_auth_mode()
	var signed_in_account := _is_account_logged_in()
	if player_name_line_edit != null:
		player_name_line_edit.placeholder_text = "Player name" if auth_mode == AUTH_MODE_GUEST else "Account username"
		player_name_line_edit.editable = not signed_in_account
		player_name_line_edit.visible = false
	if _password_line_edit != null:
		_password_line_edit.visible = false
	if _auth_mode_option != null:
		_auth_mode_option.visible = false
	if _switch_account_button != null:
		_switch_account_button.visible = signed_in_account

func _validate_auth_inputs() -> String:
	var auth_mode: String = _get_selected_auth_mode()
	if _is_account_logged_in():
		return ""
	if auth_mode == AUTH_MODE_GUEST:
		return ""
	var username: String = player_name_line_edit.text.strip_edges()
	if username.is_empty():
		return "Enter an account username first."
	if _password_line_edit == null or _password_line_edit.text.is_empty():
		return "Enter your account password first."
	return ""

func _get_auth_password() -> String:
	if _password_line_edit == null:
		return ""
	return _password_line_edit.text

func _get_lobby_login_name(default_name: String) -> String:
	var auth_mode := _get_selected_auth_mode()
	if _is_account_logged_in():
		if _local_profile_store != null:
			_local_profile_store.set_preferred_auth_mode(AUTH_MODE_LOGIN)
			_local_profile_store.remember_account_username(_logged_in_account_username)
		return _logged_in_account_username
	var player_name := _get_player_name(default_name)
	if auth_mode == AUTH_MODE_GUEST:
		return _remember_local_profile(player_name)
	if _local_profile_store != null:
		_local_profile_store.set_preferred_auth_mode(auth_mode)
		_local_profile_store.remember_account_username(player_name)
		_local_profile_store.remember_account_password(_get_auth_password())
	return player_name
