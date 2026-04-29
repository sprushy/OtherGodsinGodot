extends Control

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")
const LobbyClientScript = preload("res://scripts/client/LobbyClient.gd")
const AppReleaseInfoScript = preload("res://scripts/client/AppReleaseInfo.gd")
const DeckCatalogUtilsScript = preload("res://scripts/core/DeckCatalogUtils.gd")
const LocalProfileStoreScript = preload("res://scripts/core/LocalProfileStore.gd")
const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const MatchHistoryStoreScript = preload("res://scripts/server/MatchHistoryStore.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const LobbyRoomScript = preload("res://scripts/server/LobbyRoom.gd")
const PracticeThorScene = preload("res://scenes/practice_thor_game.tscn")
const DEDICATED_LOBBY_ENTRY_SCRIPT_PATH := "res://scripts/server/DedicatedLobbyServerMain.gd"
const DEDICATED_SERVER_EXPORT_RELATIVE_PATH := "res://.exports/server/OtherGodsServer.exe"
const DEFAULT_LOBBY_HOST_SETTING := "application/config/default_lobby_host"
const DEFAULT_LOBBY_HOST := ""
const RULES_DOC_PATH := "res://docs/new-player-rules.md"
const AUTH_MODE_GUEST := "guest"
const AUTH_MODE_LOGIN := "login"
const AUTH_MODE_REGISTER := "register"
const SEEK_AUTO_REFRESH_INTERVAL_SECONDS := 3.0
const FRESH_LOBBY_RECONNECT_DELAY_SECONDS := 0.6
const ACTIVE_MATCH_AUTO_RESUME_SUPPRESS_SECONDS := 10.0

@onready var menu_container = $MenuContainer
@onready var game_container = $GameContainer
@onready var title_label = $MenuContainer/TitleLabel
@onready var rules_button = $MenuContainer/RulesButton
@onready var multiplayer_container = $MenuContainer/MultiplayerContainer
@onready var multiplayer_button = $MenuContainer/MultiplayerButton
@onready var multiplayer_back_button = $MenuContainer/MultiplayerContainer/MultiplayerHeaderRow/BackButton
@onready var ip_line_edit = $MenuContainer/MultiplayerContainer/IPLineEdit
@onready var player_name_line_edit = $MenuContainer/MultiplayerContainer/PlayerNameLineEdit
@onready var deck_picker_label = $MenuContainer/MultiplayerContainer/DeckPickerLabel
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
var lobby_server: LobbyServer = null
var lobby_client: LobbyClient = null
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
var _pending_room_is_ranked: bool = true
var _pending_local_lobby_launch_on_connect_failure: bool = false
var _spawned_lobby_process_id: int = 0
var _dedicated_lobby_connect_attempts_remaining: int = 0
var _local_profile_store = null
var _local_profile_id: String = ""
var _selected_multiplayer_deck_id: String = ""
var _multiplayer_deck_entries: Array[Dictionary] = []
var _deck_validator = DeckValidatorScript.new()
var _last_submitted_lobby_room_id: String = ""
var _last_submitted_lobby_deck_id: String = ""
var _last_submitted_lobby_deck_hash: String = ""
var _auth_mode_option: OptionButton = null
var _password_line_edit: LineEdit = null
var _switch_account_button: Button = null
var _resume_match_button: Button = null
var _create_unranked_seek_button: Button = null
var _profile_summary_panel: PanelContainer = null
var _profile_summary_label: Label = null
var _current_profile_summary: Dictionary = {}
var _profile_summary_expanded: bool = false
var _account_decks_cache: Array[Dictionary] = []
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
var _suppressed_active_match_id: String = ""
var _suppressed_active_match_room_id: String = ""
var _suppress_active_match_resume_until_msec: int = 0
var _bug_report_status_label: Label = null
var _bug_report_screenshot_label: Label = null
var _bug_report_screenshot_preview: TextureRect = null
var _bug_report_file_dialog: FileDialog = null
var _bug_report_selected_screenshot_path: String = ""
var _account_identity_label: Label = null
var _logged_in_account_username: String = ""
var _selected_auth_mode: String = AUTH_MODE_GUEST
var _selected_account_username: String = ""
var _selected_account_password: String = ""
var _account_switch_pending: bool = false
var _account_switch_retry_attempts: int = 0
var _authenticated_lobby_connect_serial: int = 0
var _update_check_request: HTTPRequest = null
var _update_prompt_overlay: Control = null
var _pending_update_release_version: String = ""
var _pending_update_release_url: String = AppReleaseInfoScript.RELEASES_PAGE_URL
var _pending_update_download_url: String = ""
var _update_download_request: HTTPRequest = null
var _update_now_button: Button = null
var _update_download_status_label: Label = null
var _is_auto_updating: bool = false
var _startup_prompt_gate_open: bool = false
var _rules_overlay: Control = null
var _seek_auto_refresh_elapsed: float = 0.0
var _seek_list_request_pending: bool = false
var _deck_picker_button: Button = null
var _deck_picker_popup: PanelContainer = null
var _deck_picker_popup_list: VBoxContainer = null
var _multiplayer_deck_summary_panel: PanelContainer = null
var _multiplayer_deck_summary_art: TextureRect = null
var _multiplayer_deck_summary_name_label: Label = null
var _multiplayer_deck_summary_god_label: Label = null
var _server_version_label: Label = null
var _connected_server_version: String = ""
var _menu_card_templates: Dictionary = {}
var _menu_card_art_cache: Dictionary = {}

func _ready() -> void:
	if _is_server_runtime_launch():
		return
	_fit_to_viewport()
	_build_server_version_overlay()
	get_viewport().size_changed.connect(_fit_to_viewport)
	if ip_line_edit != null:
		ip_line_edit.visible = true
		ip_line_edit.text = _get_project_default_lobby_host()
		ip_line_edit.placeholder_text = "Dedicated lobby IP or hostname"

	_ensure_practice_thor_entry()
	_hide_embedded_games()
	_bind_game_signals()

	var mock_btn = $MenuContainer/MockGameButton
	var deck_btn = $MenuContainer/DeckBuilderButton
	var rules_btn = $MenuContainer/RulesButton
	var card_test_btn = $MenuContainer/CardTestButton

	if mock_btn:
		if OS.is_debug_build():
			mock_btn.pressed.connect(_on_mock_game_pressed)
		else:
			mock_btn.visible = false
	if deck_btn:
		deck_btn.pressed.connect(_on_deck_builder_pressed)
	if rules_btn:
		rules_btn.pressed.connect(_open_rules_overlay)
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
	if seek_list != null and seek_list.has_signal("item_clicked"):
		seek_list.item_clicked.connect(_on_seek_item_clicked)
	if ready_button:
		ready_button.pressed.connect(_on_ready_button_pressed)

	_build_menu_card_template_cache()
	_build_multiplayer_deck_controls()
	_build_auth_controls()
	_ensure_local_profile_store()
	_restore_auth_preferences()
	_build_profile_summary_controls()
	_build_account_identity_controls()
	_build_resume_controls()
	_build_unranked_seek_controls()
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
	for node_name in _get_embedded_game_node_names():
		var game = get_node_or_null("GameContainer/" + node_name)
		if game != null and game.has_signal("forfeit_requested"):
			var callback := Callable(self, "_on_game_forfeit_requested")
			if not game.forfeit_requested.is_connected(callback):
				game.forfeit_requested.connect(callback)
		if game != null and game.has_signal("match_session_cleared"):
			var clear_callback := Callable(self, "_on_match_session_cleared")
			if not game.match_session_cleared.is_connected(clear_callback):
				game.match_session_cleared.connect(clear_callback)

func _ensure_practice_thor_entry() -> void:
	if game_container == null or menu_container == null:
		return
	var practice_game = game_container.get_node_or_null("PracticeThor")
	if practice_game == null and PracticeThorScene != null:
		var practice_instance := PracticeThorScene.instantiate()
		if practice_instance != null:
			practice_instance.name = "PracticeThor"
			if practice_instance is Control:
				practice_instance.visible = false
			game_container.add_child(practice_instance)
			practice_game = practice_instance
	var practice_button = menu_container.get_node_or_null("PracticeThorButton")
	if practice_button == null:
		practice_button = Button.new()
		practice_button.name = "PracticeThorButton"
		practice_button.text = "Practice vs Thor"
		menu_container.add_child(practice_button)
		var insert_index := multiplayer_button.get_index() if multiplayer_button != null else menu_container.get_child_count() - 1
		menu_container.move_child(practice_button, insert_index)
	if practice_button != null:
		practice_button.visible = practice_game != null
		var callback := Callable(self, "_on_practice_thor_pressed")
		if practice_game != null and not practice_button.pressed.is_connected(callback):
			practice_button.pressed.connect(_on_practice_thor_pressed)

func _get_embedded_game_node_names() -> Array[String]:
	return ["MockGame", "CardTest", "PracticeThor"]

func _hide_embedded_games() -> void:
	for node_name in _get_embedded_game_node_names():
		var game = get_node_or_null("GameContainer/" + node_name)
		if game != null:
			game.visible = false

func _show_embedded_game(node_name: String) -> Node:
	_hide_embedded_games()
	var game = get_node_or_null("GameContainer/" + node_name)
	if game != null:
		game.visible = true
	return game

func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	if _deck_picker_popup != null and is_instance_valid(_deck_picker_popup) and _deck_picker_popup.visible:
		_position_multiplayer_deck_popup()

func _build_server_version_overlay() -> void:
	if _server_version_label != null and is_instance_valid(_server_version_label):
		return
	var label := Label.new()
	label.name = "ServerVersionLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.tooltip_text = "Version reported by the connected lobby server."
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -260.0
	label.offset_top = 10.0
	label.offset_right = -14.0
	label.offset_bottom = 34.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.84, 0.90, 0.97, 0.94))
	add_child(label)
	_server_version_label = label
	_refresh_server_version_label()
	_refresh_server_version_overlay_visibility()

func _set_connected_server_version(version: String) -> void:
	_connected_server_version = AppReleaseInfoScript.normalize_version(version)
	_refresh_server_version_label()

func _refresh_server_version_label() -> void:
	if _server_version_label == null or not is_instance_valid(_server_version_label):
		return
	if _connected_server_version.is_empty():
		if _has_active_lobby_connection():
			_server_version_label.text = "Server: version unavailable"
			return
		_server_version_label.text = "Server: not connected"
		return
	_server_version_label.text = "Server: %s" % _connected_server_version

func _refresh_server_version_overlay_visibility() -> void:
	if _server_version_label == null or not is_instance_valid(_server_version_label):
		return
	var deck_builder := game_container.get_node_or_null("DeckBuilder") if game_container != null else null
	_server_version_label.visible = not (deck_builder != null and deck_builder.visible)

func _process(delta: float) -> void:
	if _is_auto_updating and _update_download_request != null and is_instance_valid(_update_download_request):
		if _update_download_status_label != null and is_instance_valid(_update_download_status_label):
			var total := _update_download_request.get_body_size()
			var downloaded := _update_download_request.get_downloaded_bytes()
			if total > 0:
				var percent := int(float(downloaded) / float(total) * 100.0)
				_update_download_status_label.text = "Downloading... %d%%" % percent
			else:
				_update_download_status_label.text = "Downloading... %.1f MB" % (float(downloaded) / 1048576.0)
	if not _should_auto_refresh_seeks():
		_seek_auto_refresh_elapsed = 0.0
		return
	_seek_auto_refresh_elapsed += delta
	if _seek_auto_refresh_elapsed < SEEK_AUTO_REFRESH_INTERVAL_SECONDS:
		return
	_seek_auto_refresh_elapsed = 0.0
	_queue_room_list_refresh(false)

func _input(event: InputEvent) -> void:
	if _deck_picker_popup == null or not is_instance_valid(_deck_picker_popup) or not _deck_picker_popup.visible:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			_hide_multiplayer_deck_popup()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		var popup_rect := _deck_picker_popup.get_global_rect()
		var button_rect := Rect2()
		if _deck_picker_button != null and is_instance_valid(_deck_picker_button):
			button_rect = _deck_picker_button.get_global_rect()
		if popup_rect.has_point(mouse_event.position) or button_rect.has_point(mouse_event.position):
			return
		_hide_multiplayer_deck_popup()

func show_menu() -> void:
	menu_container.visible = true
	game_container.visible = false
	_hide_multiplayer_deck_popup()
	_refresh_multiplayer_deck_options()
	_refresh_multiplayer_action_state()
	_refresh_server_version_overlay_visibility()

func show_game() -> void:
	menu_container.visible = false
	game_container.visible = true
	_hide_multiplayer_deck_popup()
	_refresh_server_version_overlay_visibility()

func _on_multiplayer_pressed() -> void:
	_open_multiplayer_screen()

func _on_multiplayer_back_pressed() -> void:
	multiplayer_container.visible = false
	_hide_multiplayer_deck_popup()
	status_label.text = "Refresh open seeks or create your own."
	_refresh_seek_list()
	_refresh_multiplayer_action_state()

func _open_multiplayer_screen() -> void:
	multiplayer_container.visible = true
	_refresh_multiplayer_deck_options()
	_refresh_auth_controls()
	if _current_profile_summary.is_empty() and not _has_active_lobby_connection():
		_refresh_profile_summary_from_local_history(_local_profile_id)
	_refresh_seek_list()
	_refresh_multiplayer_action_state()
	if not _current_room_snapshot.is_empty():
		_apply_room_snapshot(_current_room_snapshot)
		return
	if _has_active_lobby_connection():
		_queue_room_list_refresh()
		return
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
	_connect_to_browseable_lobby("Connecting to lobby...")

func _has_active_lobby_connection() -> bool:
	return lobby_client != null and is_instance_valid(lobby_client) and lobby_client.is_authenticated()

func _prepare_fresh_lobby_login() -> void:
	if not _account_switch_pending and not _has_active_lobby_connection():
		return
	# A fresh sign-in must not reuse reconnect tokens from the previous account session.
	_lobby_session_id = ""
	_lobby_reconnect_token = ""

func _cancel_pending_authenticated_lobby_connects() -> void:
	_authenticated_lobby_connect_serial += 1

func _should_delay_fresh_lobby_connect() -> bool:
	return lobby_client != null and is_instance_valid(lobby_client)

func _queue_authenticated_lobby_connect(connect_status: String = "Connecting to lobby...") -> void:
	_authenticated_lobby_connect_serial += 1
	call_deferred("_deferred_authenticated_lobby_connect", connect_status, _authenticated_lobby_connect_serial)

func _should_reuse_active_lobby_connection(target_lobby_ip: String) -> bool:
	if _account_switch_pending:
		return false
	if not _has_active_lobby_connection():
		return false
	if _current_lobby_ip != target_lobby_ip:
		return false
	var desired_auth_mode := _get_selected_auth_mode()
	var connected_auth_mode := _normalize_auth_mode(
		str(lobby_client.current_auth_mode) if lobby_client != null else "",
		AUTH_MODE_GUEST
	)
	if desired_auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		var desired_username := _get_preferred_account_username().strip_edges().to_lower()
		var connected_username := _get_connected_account_username().strip_edges().to_lower()
		return not desired_username.is_empty() \
			and connected_auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER] \
			and connected_username == desired_username
	return desired_auth_mode == AUTH_MODE_GUEST and connected_auth_mode == AUTH_MODE_GUEST

func _build_menu_card_template_cache() -> void:
	_menu_card_templates.clear()
	for card in CardCatalogScript.make_all_cards():
		if card == null:
			continue
		var card_name := str(card.card_name).strip_edges()
		if not card_name.is_empty():
			_menu_card_templates[card_name] = card
		var lookup_key := CardCatalogScript.to_lookup_key(card_name)
		if not lookup_key.is_empty():
			_menu_card_templates[lookup_key] = card

func _build_multiplayer_deck_controls() -> void:
	if menu_container == null or multiplayer_container == null or _deck_picker_button != null:
		return
	if deck_picker_label != null:
		deck_picker_label.visible = false
	if deck_picker_option != null:
		deck_picker_option.visible = false
		deck_picker_option.disabled = true
	if deck_hint_label != null:
		deck_hint_label.visible = false

	var button := Button.new()
	button.name = "DeckPickerButton"
	button.text = "Change Deck: No saved decks"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 36)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_toggle_multiplayer_deck_popup)
	menu_container.add_child(button)
	var menu_insert_index := multiplayer_button.get_index() if multiplayer_button != null else menu_container.get_child_count() - 1
	menu_container.move_child(button, menu_insert_index)
	_deck_picker_button = button

	var summary_panel := PanelContainer.new()
	summary_panel.name = "SelectedDeckSummaryPanel"
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var summary_style := StyleBoxFlat.new()
	summary_style.bg_color = Color(0.08, 0.09, 0.13, 0.95)
	summary_style.border_color = Color(0.32, 0.36, 0.46, 1.0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		summary_style.set_border_width(side as Side, 1)
	summary_style.corner_radius_top_left = 6
	summary_style.corner_radius_top_right = 6
	summary_style.corner_radius_bottom_left = 6
	summary_style.corner_radius_bottom_right = 6
	summary_panel.add_theme_stylebox_override("panel", summary_style)
	multiplayer_container.add_child(summary_panel)
	if create_seek_button != null:
		multiplayer_container.move_child(summary_panel, create_seek_button.get_index())
	_multiplayer_deck_summary_panel = summary_panel

	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 12)
	summary_panel.add_child(summary_row)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(78, 104)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_row.add_child(art)
	_multiplayer_deck_summary_art = art

	var summary_text := VBoxContainer.new()
	summary_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_text.add_theme_constant_override("separation", 4)
	summary_row.add_child(summary_text)

	var summary_name := Label.new()
	summary_name.text = "No deck selected"
	summary_name.add_theme_font_size_override("font_size", 17)
	summary_name.add_theme_color_override("font_color", Color(0.94, 0.90, 0.78))
	summary_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_text.add_child(summary_name)
	_multiplayer_deck_summary_name_label = summary_name

	var summary_god := Label.new()
	summary_god.text = ""
	summary_god.add_theme_font_size_override("font_size", 12)
	summary_god.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
	summary_god.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_text.add_child(summary_god)
	_multiplayer_deck_summary_god_label = summary_god

	var popup := PanelContainer.new()
	popup.name = "DeckPickerPopup"
	popup.visible = false
	popup.top_level = true
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.focus_mode = Control.FOCUS_NONE
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.08, 0.09, 0.14, 0.98)
	popup_style.border_color = Color(0.42, 0.46, 0.56, 1.0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		popup_style.set_border_width(side as Side, 1)
	popup_style.corner_radius_top_left = 6
	popup_style.corner_radius_top_right = 6
	popup_style.corner_radius_bottom_left = 6
	popup_style.corner_radius_bottom_right = 6
	popup.add_theme_stylebox_override("panel", popup_style)
	add_child(popup)
	_deck_picker_popup = popup

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 240)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	popup.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	_deck_picker_popup_list = list

func _get_saved_deck_name(saved_deck: Dictionary) -> String:
	var deck_name := str(saved_deck.get("name", "Deck")).strip_edges()
	if deck_name.is_empty():
		return "Deck"
	return deck_name

func _get_saved_deck_validation(saved_deck: Dictionary) -> Dictionary:
	if saved_deck.is_empty():
		return {"is_valid": false, "error": "Deck is missing."}
	return _deck_validator.validate_deck(saved_deck.get("cards", {}))

func _get_saved_decks_for_current_identity() -> Array[Dictionary]:
	if _uses_server_account_storage():
		var decks: Array[Dictionary] = []
		for entry in _account_decks_cache:
			decks.append(entry.duplicate(true))
		return decks
	if _local_profile_store == null or _local_profile_id.is_empty():
		return []
	return _local_profile_store.list_decks(_local_profile_id)

func _replace_account_decks_cache(decks: Array[Dictionary]) -> void:
	_account_decks_cache.clear()
	var visible_decks := DeckCatalogUtilsScript.dedupe_exact_copies(
		decks,
		_get_server_preferred_account_deck_id(),
		_selected_multiplayer_deck_id
	)
	for entry in visible_decks:
		_account_decks_cache.append(entry.duplicate(true))

func _get_local_saved_decks_for_active_profile() -> Array[Dictionary]:
	if _local_profile_store == null or _local_profile_id.is_empty():
		return []
	return _local_profile_store.list_decks(_local_profile_id)

func _get_synced_account_deck_lookup() -> Dictionary:
	var synced_lookup: Dictionary = {}
	if _local_profile_store == null or _local_profile_id.is_empty():
		return synced_lookup
	for deck_id in _local_profile_store.get_synced_account_deck_ids(_local_profile_id):
		var resolved_deck_id := str(deck_id).strip_edges()
		if resolved_deck_id.is_empty():
			continue
		synced_lookup[resolved_deck_id] = true
	return synced_lookup

func _get_deleted_account_deck_lookup() -> Dictionary:
	var deleted_lookup: Dictionary = {}
	if _local_profile_store == null or _local_profile_id.is_empty():
		return deleted_lookup
	for deck_id in _local_profile_store.get_deleted_account_deck_ids(_local_profile_id):
		var resolved_deck_id := str(deck_id).strip_edges()
		if resolved_deck_id.is_empty():
			continue
		deleted_lookup[resolved_deck_id] = true
	return deleted_lookup

static func _should_ignore_account_deck_sync_update(deck_id: String, deleted_lookup: Dictionary) -> bool:
	var resolved_deck_id := deck_id.strip_edges()
	if resolved_deck_id.is_empty():
		return true
	return bool(deleted_lookup.get(resolved_deck_id, false))

func _mark_active_profile_account_decks_synced(deck_ids: Array) -> void:
	if _local_profile_store == null or _local_profile_id.is_empty() or deck_ids.is_empty():
		return
	_local_profile_store.mark_account_decks_synced(_local_profile_id, deck_ids)

func _mirror_remote_account_deck_locally(deck: Dictionary) -> void:
	if _local_profile_store == null or _local_profile_id.is_empty() or deck.is_empty():
		return
	_local_profile_store.upsert_saved_deck(_local_profile_id, deck, false)

static func _merge_account_deck_catalogs(
	remote_decks: Array[Dictionary],
	local_decks: Array[Dictionary],
	synced_lookup: Dictionary,
	deleted_lookup: Dictionary
) -> Dictionary:
	var visible_decks: Array[Dictionary] = []
	var remote_deck_lookup: Dictionary = {}
	var local_migration_decks: Array[Dictionary] = []
	for remote_deck in remote_decks:
		var remote_id := str(remote_deck.get("deck_id", "")).strip_edges()
		if _should_ignore_account_deck_sync_update(remote_id, deleted_lookup) or remote_deck_lookup.has(remote_id):
			continue
		remote_deck_lookup[remote_id] = true
		visible_decks.append(remote_deck.duplicate(true))
	for local_deck in local_decks:
		var local_id := str(local_deck.get("deck_id", "")).strip_edges()
		if _should_ignore_account_deck_sync_update(local_id, deleted_lookup) or remote_deck_lookup.has(local_id):
			continue
		if bool(synced_lookup.get(local_id, false)):
			continue
		var copied_local_deck := local_deck.duplicate(true)
		visible_decks.append(copied_local_deck)
		local_migration_decks.append(copied_local_deck.duplicate(true))
	return {
		"visible_decks": visible_decks,
		"local_migration_decks": local_migration_decks,
	}

func _upsert_account_deck_cache(deck: Dictionary) -> void:
	var deck_id := str(deck.get("deck_id", "")).strip_edges()
	if deck_id.is_empty():
		return
	for index in range(_account_decks_cache.size()):
		if str(_account_decks_cache[index].get("deck_id", "")).strip_edges() != deck_id:
			continue
		_account_decks_cache[index] = deck.duplicate(true)
		return
	_account_decks_cache.append(deck.duplicate(true))

func _remove_account_deck_from_cache(deck_id: String) -> void:
	var resolved_deck_id := deck_id.strip_edges()
	if resolved_deck_id.is_empty():
		return
	for index in range(_account_decks_cache.size() - 1, -1, -1):
		if str(_account_decks_cache[index].get("deck_id", "")).strip_edges() == resolved_deck_id:
			_account_decks_cache.remove_at(index)

func _get_multiplayer_deck_entry(deck_id: String) -> Dictionary:
	var resolved_deck_id := deck_id.strip_edges()
	if resolved_deck_id.is_empty():
		return {}
	for entry in _multiplayer_deck_entries:
		if str(entry.get("deck_id", "")).strip_edges() == resolved_deck_id:
			return (entry as Dictionary).duplicate(true)
	return {}

func _get_selected_multiplayer_deck_entry() -> Dictionary:
	return _get_multiplayer_deck_entry(_selected_multiplayer_deck_id)

func _find_menu_card_template(card_name: String) -> Card:
	var resolved_name := str(card_name).strip_edges()
	if resolved_name.is_empty():
		return null
	if _menu_card_templates.has(resolved_name):
		return _menu_card_templates[resolved_name] as Card
	var lookup_key := CardCatalogScript.to_lookup_key(resolved_name)
	if _menu_card_templates.has(lookup_key):
		return _menu_card_templates[lookup_key] as Card
	return null

func _get_saved_deck_god_template(saved_deck: Dictionary) -> Card:
	if saved_deck.is_empty():
		return null
	var raw_deck_cards: Variant = saved_deck.get("cards", {})
	if not (raw_deck_cards is Dictionary):
		return null
	var deck_cards: Dictionary = raw_deck_cards as Dictionary
	for raw_card_name in deck_cards.keys():
		if int(deck_cards[raw_card_name]) <= 0:
			continue
		var card: Card = _find_menu_card_template(str(raw_card_name))
		if card != null and bool(card.is_god):
			return card
	return null

func _get_menu_card_art_texture(art_path: String) -> Texture2D:
	var resolved_path := art_path.strip_edges()
	if resolved_path.is_empty():
		return null
	if _menu_card_art_cache.has(resolved_path):
		return _menu_card_art_cache[resolved_path] as Texture2D
	var texture := load(resolved_path) as Texture2D
	_menu_card_art_cache[resolved_path] = texture
	return texture

func _refresh_multiplayer_deck_picker_button() -> void:
	if _deck_picker_button == null:
		return
	if _multiplayer_deck_entries.is_empty():
		_deck_picker_button.text = "Change Deck: No saved decks"
		_deck_picker_button.tooltip_text = "No saved decks yet."
		_deck_picker_button.disabled = true
		return
	var selected_entry: Dictionary = _get_selected_multiplayer_deck_entry()
	if selected_entry.is_empty():
		_deck_picker_button.text = "Change Deck: Choose a deck"
		_deck_picker_button.tooltip_text = "Choose one of your saved decks."
		_deck_picker_button.disabled = false
		return
	var deck_name := str(selected_entry.get("deck_name", "Deck"))
	if bool(selected_entry.get("is_legal", false)):
		_deck_picker_button.text = "Change Deck: %s" % deck_name
		_deck_picker_button.tooltip_text = "Current multiplayer deck: %s" % deck_name
	else:
		var reason := str(selected_entry.get("reason", "")).strip_edges()
		_deck_picker_button.text = "Change Deck: %s (Unavailable)" % deck_name
		_deck_picker_button.tooltip_text = reason if not reason.is_empty() else "This deck is unavailable for multiplayer."
	_deck_picker_button.disabled = false

func _make_multiplayer_deck_entry_row(entry: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 92
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	var is_legal := bool(entry.get("is_legal", false))
	var is_selected := str(entry.get("deck_id", "")).strip_edges() == _selected_multiplayer_deck_id.strip_edges()
	var entry_deck_name := str(entry.get("deck_name", "Deck"))
	var reason := str(entry.get("reason", "")).strip_edges()
	var god_card: Card = _get_saved_deck_god_template(entry.get("saved_deck", {}) as Dictionary)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.98) if is_legal else Color(0.15, 0.11, 0.12, 0.97)
	style.border_color = Color(0.86, 0.78, 0.36, 1.0) if is_selected else (Color(0.42, 0.46, 0.56, 1.0) if is_legal else Color(0.64, 0.26, 0.26, 1.0))
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side as Side, 2 if is_selected else 1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	row.add_theme_stylebox_override("panel", style)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	row.add_child(inner)

	var marker := Label.new()
	marker.custom_minimum_size = Vector2(18, 0)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 18)
	if is_legal:
		marker.text = ">" if is_selected else ""
		marker.add_theme_color_override("font_color", Color(0.96, 0.86, 0.34))
	else:
		marker.text = "X"
		marker.add_theme_color_override("font_color", Color(1.0, 0.26, 0.26))
	inner.add_child(marker)

	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size = Vector2(52, 72)
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color(0.06, 0.07, 0.10, 0.96)
	art_style.border_color = Color(0.34, 0.38, 0.48, 1.0) if is_legal else Color(0.56, 0.26, 0.26, 1.0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		art_style.set_border_width(side as Side, 1)
	art_style.corner_radius_top_left = 4
	art_style.corner_radius_top_right = 4
	art_style.corner_radius_bottom_left = 4
	art_style.corner_radius_bottom_right = 4
	art_frame.add_theme_stylebox_override("panel", art_style)
	inner.add_child(art_frame)

	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if god_card != null and str(god_card.art_path).strip_edges() != "":
		art.texture = _get_menu_card_art_texture(str(god_card.art_path))
	art.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_legal else Color(0.72, 0.72, 0.72, 0.80)
	art_frame.add_child(art)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	inner.add_child(text_box)

	var name_label := Label.new()
	name_label.text = "%s%s" % [entry_deck_name, "  [Loaded]" if is_selected else ""]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.96) if is_legal else Color(0.80, 0.80, 0.82))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(name_label)

	var detail_label := Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 11)
	if is_legal:
		detail_label.text = "Currently loaded for multiplayer." if is_selected else "Click to load this deck for multiplayer."
		detail_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.84))
	else:
		detail_label.text = reason if not reason.is_empty() else "This deck is unavailable for multiplayer."
		detail_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.76))
	text_box.add_child(detail_label)

	if god_card != null:
		var god_label := Label.new()
		god_label.text = god_card.get_display_name_for_control()
		god_label.add_theme_font_size_override("font_size", 11)
		god_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.66) if is_legal else Color(0.82, 0.76, 0.76))
		god_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_box.add_child(god_label)

	row.tooltip_text = reason if not reason.is_empty() else entry_deck_name
	if is_legal:
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				var mouse_event := event as InputEventMouseButton
				if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
					_select_multiplayer_deck(str(entry.get("deck_id", "")))
		)
	else:
		row.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		row.modulate = Color(0.8, 0.8, 0.8, 0.92)

	return row

func _rebuild_multiplayer_deck_popup() -> void:
	if _deck_picker_popup_list == null:
		return
	for child in _deck_picker_popup_list.get_children():
		child.queue_free()
	if _multiplayer_deck_entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No saved decks yet."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
		_deck_picker_popup_list.add_child(empty_label)
		return
	for entry in _multiplayer_deck_entries:
		_deck_picker_popup_list.add_child(_make_multiplayer_deck_entry_row(entry as Dictionary))

func _position_multiplayer_deck_popup() -> void:
	if _deck_picker_popup == null or not is_instance_valid(_deck_picker_popup):
		return
	if _deck_picker_button == null or not is_instance_valid(_deck_picker_button):
		return
	var button_rect: Rect2 = _deck_picker_button.get_global_rect()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var popup_width: float = minf(maxf(button_rect.size.x, 520.0), maxf(320.0, viewport_rect.size.x - 24.0))
	var row_count: int = maxi(1, _multiplayer_deck_entries.size())
	var target_height: float = 24.0 + float(mini(row_count, 4)) * 98.0
	var popup_height: float = minf(480.0, maxf(180.0, target_height))
	var popup_x: float = clampf(button_rect.position.x, 12.0, viewport_rect.size.x - popup_width - 12.0)
	var popup_y: float = button_rect.position.y + button_rect.size.y + 4.0
	if popup_y + popup_height > viewport_rect.size.y - 12.0:
		popup_y = maxf(12.0, button_rect.position.y - popup_height - 4.0)
	_deck_picker_popup.position = Vector2(popup_x, popup_y)
	_deck_picker_popup.size = Vector2(popup_width, popup_height)

func _show_multiplayer_deck_popup() -> void:
	if _deck_picker_popup == null or _deck_picker_button == null:
		return
	_rebuild_multiplayer_deck_popup()
	_deck_picker_popup.visible = true
	_position_multiplayer_deck_popup()

func _hide_multiplayer_deck_popup() -> void:
	if _deck_picker_popup != null and is_instance_valid(_deck_picker_popup):
		_deck_picker_popup.visible = false

func _toggle_multiplayer_deck_popup() -> void:
	if _deck_picker_popup == null or not is_instance_valid(_deck_picker_popup):
		return
	if _deck_picker_popup.visible:
		_hide_multiplayer_deck_popup()
		return
	_show_multiplayer_deck_popup()

func _select_multiplayer_deck(deck_id: String, persist: bool = true) -> void:
	var selected_entry: Dictionary = _get_multiplayer_deck_entry(deck_id)
	if selected_entry.is_empty() or not bool(selected_entry.get("is_legal", false)):
		return
	_selected_multiplayer_deck_id = str(selected_entry.get("deck_id", "")).strip_edges()
	if persist:
		if _uses_server_account_storage():
			var preferred_deck_id := _get_server_preferred_account_deck_id()
			if lobby_client != null and preferred_deck_id != _selected_multiplayer_deck_id:
				lobby_client.set_account_preferred_deck(_selected_multiplayer_deck_id)
		elif _local_profile_store != null and not _local_profile_id.is_empty():
			_local_profile_store.remember_last_selected_deck(_local_profile_id, _selected_multiplayer_deck_id)
	_refresh_multiplayer_deck_picker_button()
	_update_multiplayer_deck_hint()
	_refresh_multiplayer_action_state()
	_hide_multiplayer_deck_popup()
	if not _current_room_snapshot.is_empty():
		_maybe_submit_current_profile_deck(str(_current_room_snapshot.get("room_id", "")), _current_room_snapshot)

func _refresh_multiplayer_deck_options() -> void:
	_multiplayer_deck_entries.clear()

	var preferred_deck_id := _selected_multiplayer_deck_id
	if preferred_deck_id.is_empty():
		if _uses_server_account_storage():
			preferred_deck_id = _get_server_preferred_account_deck_id()
		elif _local_profile_store != null:
			preferred_deck_id = _local_profile_store.get_last_selected_deck_id(_local_profile_id)

	for saved_deck in _get_saved_decks_for_current_identity():
		var deck_id := str(saved_deck.get("deck_id", "")).strip_edges()
		if deck_id.is_empty():
			continue
		var saved_deck_copy: Dictionary = (saved_deck as Dictionary).duplicate(true)
		var validation: Dictionary = _get_saved_deck_validation(saved_deck_copy)
		var entry: Dictionary = {
			"deck_id": deck_id,
			"deck_name": _get_saved_deck_name(saved_deck_copy),
			"saved_deck": saved_deck_copy,
			"is_legal": bool(validation.get("is_valid", false)),
			"reason": str(validation.get("error", "")).strip_edges(),
			"validation": validation.duplicate(true),
		}
		_multiplayer_deck_entries.append(entry)

	var resolved_selected_deck_id := ""
	if not preferred_deck_id.is_empty():
		var preferred_entry: Dictionary = _get_multiplayer_deck_entry(preferred_deck_id)
		if not preferred_entry.is_empty():
			resolved_selected_deck_id = str(preferred_entry.get("deck_id", "")).strip_edges()
	if resolved_selected_deck_id.is_empty():
		for entry in _multiplayer_deck_entries:
			if bool(entry.get("is_legal", false)):
				resolved_selected_deck_id = str(entry.get("deck_id", "")).strip_edges()
				break
	if resolved_selected_deck_id.is_empty() and not _multiplayer_deck_entries.is_empty():
		resolved_selected_deck_id = str(_multiplayer_deck_entries[0].get("deck_id", "")).strip_edges()
	_selected_multiplayer_deck_id = resolved_selected_deck_id

	_refresh_multiplayer_deck_picker_button()
	_rebuild_multiplayer_deck_popup()
	if _deck_picker_popup != null and _deck_picker_popup.visible:
		_position_multiplayer_deck_popup()
	_update_multiplayer_deck_hint()
	_refresh_multiplayer_action_state()
	_maybe_submit_selected_deck_for_current_room()

func _update_multiplayer_deck_hint() -> void:
	var selected_entry: Dictionary = _get_selected_multiplayer_deck_entry()
	if _multiplayer_deck_summary_name_label != null:
		if selected_entry.is_empty():
			_multiplayer_deck_summary_name_label.text = "No deck selected" if _multiplayer_deck_entries.is_empty() else "Choose a deck on the main menu"
			if _multiplayer_deck_summary_god_label != null:
				_multiplayer_deck_summary_god_label.text = ""
			if _multiplayer_deck_summary_art != null:
				_multiplayer_deck_summary_art.texture = null
				_multiplayer_deck_summary_art.modulate = Color(1.0, 1.0, 1.0, 0.28)
		else:
			var deck_name := str(selected_entry.get("deck_name", "Deck"))
			var is_legal := bool(selected_entry.get("is_legal", false))
			_multiplayer_deck_summary_name_label.text = deck_name if is_legal else "%s (Unavailable)" % deck_name
			var god_card: Card = _get_saved_deck_god_template(selected_entry.get("saved_deck", {}) as Dictionary)
			if _multiplayer_deck_summary_god_label != null:
				_multiplayer_deck_summary_god_label.text = god_card.get_display_name_for_control() if god_card != null else ""
			if _multiplayer_deck_summary_art != null:
				if god_card != null and str(god_card.art_path).strip_edges() != "":
					_multiplayer_deck_summary_art.texture = _get_menu_card_art_texture(str(god_card.art_path))
				else:
					_multiplayer_deck_summary_art.texture = null
				_multiplayer_deck_summary_art.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_legal else Color(0.74, 0.74, 0.74, 0.82)
	if deck_hint_label == null:
		return
	if selected_entry.is_empty():
		if _multiplayer_deck_entries.is_empty():
			deck_hint_label.text = "No saved decks yet. Build one before you create or join a seek."
		else:
			deck_hint_label.text = "Choose one of your saved legal decks before you create or join a seek."
		return
	var deck_name := str(selected_entry.get("deck_name", "Deck"))
	if bool(selected_entry.get("is_legal", false)):
		deck_hint_label.text = "Current deck: %s" % deck_name
		return
	var reason := str(selected_entry.get("reason", "")).strip_edges()
	if reason.is_empty():
		reason = "This deck is unavailable for multiplayer."
	deck_hint_label.text = "Current deck unavailable: %s. %s" % [deck_name, reason]

func _get_selected_multiplayer_deck() -> Dictionary:
	var selected_entry: Dictionary = _get_selected_multiplayer_deck_entry()
	if selected_entry.is_empty() or not bool(selected_entry.get("is_legal", false)):
		return {}
	return (selected_entry.get("saved_deck", {}) as Dictionary).duplicate(true)

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
		var rank_tag := "" if bool(room.get("is_ranked", true)) else "[Unranked]  "
		seek_list.add_item("%s%s  %d/%d  %s" % [rank_tag, host_name, member_count, max_players, status])
		seek_list.set_item_metadata(seek_list.get_item_count() - 1, room_id)

func _refresh_multiplayer_action_state() -> void:
	var has_legal_deck := not _get_selected_multiplayer_deck().is_empty()
	var in_room := not _current_room_snapshot.is_empty()
	if create_seek_button != null:
		create_seek_button.disabled = not has_legal_deck or in_room
	if _create_unranked_seek_button != null:
		_create_unranked_seek_button.disabled = not has_legal_deck or in_room
	if leave_seek_button != null:
		leave_seek_button.visible = in_room
	if ready_button != null:
		ready_button.visible = false

func _maybe_submit_selected_deck_for_current_room() -> void:
	if _current_room_snapshot.is_empty():
		return
	var room_id := str(_current_room_snapshot.get("room_id", "")).strip_edges()
	if room_id.is_empty():
		return
	_maybe_submit_current_profile_deck(room_id, _current_room_snapshot)

func _should_auto_refresh_seeks() -> bool:
	return (
		multiplayer_container != null
		and multiplayer_container.visible
		and not _match_launch_queued
		and lobby_client != null
		and is_instance_valid(lobby_client)
		and lobby_client.is_authenticated()
	)

func _queue_room_list_refresh(show_status: bool = true) -> void:
	if lobby_client == null:
		return
	if not lobby_client.is_authenticated():
		return
	if _seek_list_request_pending:
		return
	_seek_list_request_pending = true
	if show_status:
		status_label.text = "Refreshing open seeks..."
	lobby_client.list_rooms()

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
	_pending_room_is_ranked = true
	_pending_join_room_id = ""
	_pending_local_lobby_launch_on_connect_failure = false
	multiplayer_container.visible = true
	_connect_to_browseable_lobby("Connecting to lobby...")

func _on_create_unranked_seek_pressed() -> void:
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
	_pending_room_is_ranked = false
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

func _connect_to_browseable_lobby(connect_status: String, connect_serial: int = 0) -> void:
	if connect_serial > 0 and connect_serial != _authenticated_lobby_connect_serial:
		return
	var target_error := _validate_multiplayer_target()
	if not target_error.is_empty():
		status_label.text = target_error
		return
	var target_lobby_ip := _get_lobby_ip()
	if _should_reuse_active_lobby_connection(target_lobby_ip):
		_run_pending_multiplayer_action()
		return
	_prepare_fresh_lobby_login()
	var should_delay_connect := _should_delay_fresh_lobby_connect()
	_current_lobby_ip = target_lobby_ip
	_cleanup_lobby_client()
	_set_connected_server_version("")
	if should_delay_connect:
		status_label.text = "Closing previous lobby session..."
		await get_tree().process_frame
		await get_tree().create_timer(FRESH_LOBBY_RECONNECT_DELAY_SECONDS).timeout
		if connect_serial > 0 and connect_serial != _authenticated_lobby_connect_serial:
			return
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

func _maybe_connect_authenticated_lobby(connect_status: String = "Connecting to lobby...", connect_serial: int = 0) -> void:
	if connect_serial > 0 and connect_serial != _authenticated_lobby_connect_serial:
		return
	if _get_selected_auth_mode() not in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return
	var auth_error := _validate_auth_inputs()
	if not auth_error.is_empty():
		status_label.text = auth_error
		return
	var target_error := _validate_multiplayer_target()
	if not target_error.is_empty():
		status_label.text = target_error
		return
	_pending_host_room_creation = false
	_pending_join_room_id = ""
	_pending_local_lobby_launch_on_connect_failure = false
	_connect_to_browseable_lobby(connect_status, connect_serial)

func _deferred_authenticated_lobby_connect(connect_status: String = "Connecting to lobby...", connect_serial: int = 0) -> void:
	if connect_serial > 0 and connect_serial != _authenticated_lobby_connect_serial:
		return
	if _account_switch_pending:
		await get_tree().process_frame
	if connect_serial > 0 and connect_serial != _authenticated_lobby_connect_serial:
		return
	_maybe_connect_authenticated_lobby(connect_status, connect_serial)

func _run_pending_multiplayer_action() -> void:
	if lobby_client == null:
		return
	if _pending_host_room_creation:
		var is_ranked := _pending_room_is_ranked
		_pending_host_room_creation = false
		_pending_room_is_ranked = true
		_pending_local_lobby_launch_on_connect_failure = false
		status_label.text = "Creating seek..."
		lobby_client.create_room(is_ranked)
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
	_last_submitted_lobby_deck_hash = ""
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
		"User-Agent: OtherGods",
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
	var download_url := ""
	var assets: Array = payload.get("assets", [])
	var windows_asset_names := PackedStringArray([
		"OtherGods-windows.zip",
		"ClaudeOtherGods-windows.zip",
	])
	for asset_name in windows_asset_names:
		for asset in assets:
			if str(asset.get("name", "")) != asset_name:
				continue
			download_url = str(asset.get("browser_download_url", "")).strip_edges()
			break
		if not download_url.is_empty():
			break
	_show_update_prompt(latest_version, release_url, download_url)

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

func _show_update_prompt(latest_version: String, release_url: String, download_url: String = "") -> void:
	if _update_prompt_overlay != null and is_instance_valid(_update_prompt_overlay):
		return
	_pending_update_release_version = latest_version
	_pending_update_release_url = release_url
	_pending_update_download_url = download_url

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
		panel_style.set_border_width(side as Side, 2)
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
	body_label.text = "You're running %s, and the latest release is %s." % [current_version, latest_version]
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

	if not download_url.is_empty() and OS.get_name() == "Windows":
		var auto_button := Button.new()
		auto_button.text = "Update Now"
		auto_button.custom_minimum_size = Vector2(130, 38)
		auto_button.pressed.connect(_on_update_prompt_auto_update_pressed)
		button_row.add_child(auto_button)
		_update_now_button = auto_button

		var progress_label := Label.new()
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress_label.visible = false
		content.add_child(progress_label)
		_update_download_status_label = progress_label

		auto_button.grab_focus()
	else:
		update_button.grab_focus()

func _dismiss_update_prompt() -> void:
	if _update_download_request != null and is_instance_valid(_update_download_request):
		_update_download_request.cancel_request()
		_update_download_request.queue_free()
	_update_download_request = null
	_is_auto_updating = false
	_update_now_button = null
	_update_download_status_label = null
	_pending_update_download_url = ""
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

func _on_update_prompt_auto_update_pressed() -> void:
	if _is_auto_updating:
		return
	_is_auto_updating = true
	if _update_now_button != null and is_instance_valid(_update_now_button):
		_update_now_button.disabled = true
	if _update_download_status_label != null and is_instance_valid(_update_download_status_label):
		_update_download_status_label.text = "Downloading..."
		_update_download_status_label.visible = true

	var zip_path := OS.get_user_data_dir() + "/update_download.zip"
	if FileAccess.file_exists(zip_path):
		DirAccess.remove_absolute(zip_path)

	_update_download_request = HTTPRequest.new()
	_update_download_request.name = "UpdateDownloadRequest"
	_update_download_request.download_file = zip_path
	_update_download_request.use_threads = true
	_update_download_request.request_completed.connect(_on_auto_update_download_completed.bind(zip_path))
	add_child(_update_download_request)

	if _update_download_request.request(_pending_update_download_url) != OK:
		_on_auto_update_failed("Failed to start download.")

func _on_auto_update_download_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray,
	zip_path: String
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_on_auto_update_failed("Download failed (HTTP %d)." % response_code)
		return
	_apply_update_and_restart(zip_path)

func _apply_update_and_restart(zip_path: String) -> void:
	if _update_download_status_label != null and is_instance_valid(_update_download_status_label):
		_update_download_status_label.text = "Applying update..."

	var current_exe := OS.get_executable_path()
	if current_exe.is_empty():
		_on_auto_update_failed("Couldn't locate the current app executable.")
		return
	var staging_root := OS.get_user_data_dir() + "/self_update_staging"
	if not _clear_update_staging_root(staging_root):
		_on_auto_update_failed("Couldn't clear the update staging folder.")
		return
	if DirAccess.make_dir_recursive_absolute(staging_root) != OK:
		_on_auto_update_failed("Couldn't create the update staging folder.")
		return

	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		_on_auto_update_failed("Failed to open downloaded archive.")
		return

	var extracted_files := _extract_update_archive_to_staging(zip, staging_root)
	zip.close()
	DirAccess.remove_absolute(zip_path)
	if extracted_files.is_empty():
		_clear_update_staging_root(staging_root)
		_on_auto_update_failed("Failed to extract the downloaded update.")
		return

	var exe_dir := current_exe.get_base_dir()
	var current_exe_name := current_exe.get_file()
	var target_exe_name := "OtherGods.exe"
	if target_exe_name.is_empty():
		target_exe_name = current_exe_name
	if not _align_staged_windows_build_names(staging_root, extracted_files, target_exe_name):
		_clear_update_staging_root(staging_root)
		_on_auto_update_failed("The downloaded update didn't contain a usable app build.")
		return

	var batch_dir := OS.get_user_data_dir() + "/self_update_runner"
	if not _clear_update_staging_root(batch_dir):
		_on_auto_update_failed("Couldn't clear the updater runner folder.")
		return
	if DirAccess.make_dir_recursive_absolute(batch_dir) != OK:
		_on_auto_update_failed("Couldn't create the updater runner folder.")
		return

	var current_exe_win := current_exe.replace("/", "\\")
	var target_exe_path := exe_dir.path_join(target_exe_name)
	var target_exe_win := target_exe_path.replace("/", "\\")
	var current_pck_win := exe_dir.path_join("%s.pck" % current_exe_name.get_basename()).replace("/", "\\")
	var target_pck_win := exe_dir.path_join("%s.pck" % target_exe_name.get_basename()).replace("/", "\\")
	var exe_dir_win := exe_dir.replace("/", "\\")
	var staging_root_win := staging_root.replace("/", "\\")
	var bat_path := batch_dir + "/updater.bat"
	var bat_path_win := bat_path.replace("/", "\\")
	var bat_content := (
		"@echo off\r\n"
		+ "setlocal\r\n"
		+ "set retry_count=0\r\n"
		+ ":copy_retry\r\n"
		+ "timeout /t 1 /nobreak >nul\r\n"
		+ "xcopy /E /I /Y \"" + staging_root_win + "\\*\" \"" + exe_dir_win + "\\\" >nul\r\n"
		+ "if %errorlevel% lss 4 goto copy_ok\r\n"
		+ "set /a retry_count+=1\r\n"
		+ "if %retry_count% lss 15 goto copy_retry\r\n"
		+ "if %errorlevel% geq 4 goto copy_failed\r\n"
		+ ":copy_ok\r\n"
		+ "if /I not \"" + current_exe_win + "\"==\"" + target_exe_win + "\" del /f /q \"" + current_exe_win + "\" 2>nul\r\n"
		+ "if /I not \"" + current_pck_win + "\"==\"" + target_pck_win + "\" del /f /q \"" + current_pck_win + "\" 2>nul\r\n"
		+ "start \"\" \"" + target_exe_win + "\"\r\n"
		+ "rd /s /q \"" + staging_root_win + "\"\r\n"
		+ "rd /s /q \"" + batch_dir.replace("/", "\\") + "\" 2>nul\r\n"
		+ "(goto) 2>nul & del \"%~f0\"\r\n"
		+ "exit /b 0\r\n"
		+ ":copy_failed\r\n"
		+ "start \"\" \"" + current_exe_win + "\"\r\n"
		+ "(goto) 2>nul & del \"%~f0\"\r\n"
		+ "exit /b 1\r\n"
	)
	var bat_file := FileAccess.open(bat_path, FileAccess.WRITE)
	if bat_file == null:
		_on_auto_update_failed("Failed to write updater script.")
		return
	bat_file.store_string(bat_content)
	bat_file.close()

	if _update_download_status_label != null and is_instance_valid(_update_download_status_label):
		_update_download_status_label.text = "Restarting to finish update..."
	var updater_pid := OS.create_process("C:/Windows/System32/cmd.exe", ["/c", bat_path_win])
	if updater_pid == -1:
		_on_auto_update_failed("Failed to launch the updater.")
		return
	get_tree().quit()

func _on_auto_update_failed(message: String) -> void:
	_is_auto_updating = false
	if _update_now_button != null and is_instance_valid(_update_now_button):
		_update_now_button.disabled = false
	if _update_download_status_label != null and is_instance_valid(_update_download_status_label):
		_update_download_status_label.text = message

func _extract_update_archive_to_staging(zip: ZIPReader, staging_root: String) -> Array[String]:
	var extracted_files: Array[String] = []
	if zip == null:
		return extracted_files
	for archive_path_raw: String in zip.get_files():
		var archive_path := archive_path_raw.replace("\\", "/")
		if archive_path.is_empty() or archive_path.ends_with("/"):
			continue
		var output_path := staging_root.path_join(archive_path)
		if DirAccess.make_dir_recursive_absolute(output_path.get_base_dir()) != OK:
			return []
		var contents := zip.read_file(archive_path_raw)
		if contents.is_empty() and not archive_path.to_lower().ends_with(".md"):
			return []
		var out_file := FileAccess.open(output_path, FileAccess.WRITE)
		if out_file == null:
			return []
		out_file.store_buffer(contents)
		out_file.close()
		extracted_files.append(archive_path)
	return extracted_files

func _align_staged_windows_build_names(
	staging_root: String,
	extracted_files: Array[String],
	target_exe_name: String
) -> bool:
	if extracted_files.is_empty() or target_exe_name.is_empty():
		return false
	var staged_executable := ""
	for relative_path in extracted_files:
		if relative_path.to_lower().ends_with(".exe"):
			staged_executable = relative_path
			break
	if staged_executable.is_empty():
		return false

	var staged_exe_dir := staged_executable.get_base_dir()
	if staged_exe_dir == ".":
		staged_exe_dir = ""
	var staged_exe_name := staged_executable.get_file()
	var staged_exe_base := staged_exe_name.get_basename()
	var target_exe_base := target_exe_name.get_basename()

	if staged_exe_name != target_exe_name:
		var renamed_exe_relative := target_exe_name if staged_exe_dir.is_empty() else staged_exe_dir.path_join(target_exe_name)
		if DirAccess.rename_absolute(
			staging_root.path_join(staged_executable),
			staging_root.path_join(renamed_exe_relative)
		) != OK:
			return false
		staged_executable = renamed_exe_relative

	for relative_path in extracted_files:
		if not relative_path.to_lower().ends_with(".pck"):
			continue
		if relative_path.get_file().get_basename() != staged_exe_base:
			continue
		var pck_dir := relative_path.get_base_dir()
		if pck_dir == ".":
			pck_dir = ""
		var renamed_pck_relative := "%s.pck" % target_exe_base
		if not pck_dir.is_empty():
			renamed_pck_relative = pck_dir.path_join(renamed_pck_relative)
		if relative_path == renamed_pck_relative:
			break
		if DirAccess.rename_absolute(
			staging_root.path_join(relative_path),
			staging_root.path_join(renamed_pck_relative)
		) != OK:
			return false
		break

	return true

func _clear_update_staging_root(path: String) -> bool:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return true
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var child_name := dir.get_next()
	while child_name != "":
		if child_name == "." or child_name == "..":
			child_name = dir.get_next()
			continue
		var child_path := path.path_join(child_name)
		if dir.current_is_dir():
			if not _clear_update_staging_root(child_path):
				dir.list_dir_end()
				return false
		else:
			if DirAccess.remove_absolute(child_path) != OK:
				dir.list_dir_end()
				return false
		child_name = dir.get_next()
	dir.list_dir_end()
	return DirAccess.remove_absolute(path) == OK

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
		panel_style.set_border_width(side as Side, 2)
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
	_account_switch_pending = true
	_account_switch_retry_attempts = 0
	_cancel_pending_authenticated_lobby_connects()
	_set_selected_account_username("")
	if _local_profile_store != null:
		_local_profile_store.set_preferred_auth_mode(AUTH_MODE_LOGIN)
		_local_profile_store.clear_account_password()
	_set_selected_account_password("")
	_set_auth_mode(AUTH_MODE_LOGIN)
	if _auth_onboarding_username_edit != null and is_instance_valid(_auth_onboarding_username_edit):
		_auth_onboarding_username_edit.text = ""
	if _password_line_edit != null:
		_password_line_edit.text = ""
	if _auth_onboarding_password_edit != null and is_instance_valid(_auth_onboarding_password_edit):
		_auth_onboarding_password_edit.text = ""
	if _auth_onboarding_overlay == null or not is_instance_valid(_auth_onboarding_overlay):
		_show_auth_onboarding()
	_begin_auth_onboarding_account_flow(AUTH_MODE_LOGIN)

func _is_account_logged_in() -> bool:
	return not _get_effective_account_username().is_empty()

func _uses_server_account_storage() -> bool:
	if lobby_client == null:
		return false
	return not str(lobby_client.current_account_id).strip_edges().is_empty()

func _get_server_preferred_account_deck_id() -> String:
	if not _uses_server_account_storage() or lobby_client == null:
		return ""
	return str(lobby_client.current_preferred_account_deck_id).strip_edges()

func _normalize_auth_mode(auth_mode: String, fallback_mode: String = AUTH_MODE_GUEST) -> String:
	var resolved_auth_mode := auth_mode.strip_edges().to_lower()
	match resolved_auth_mode:
		AUTH_MODE_GUEST, LobbyProtocolScript.LOGIN_GUEST:
			return AUTH_MODE_GUEST
		AUTH_MODE_LOGIN, LobbyProtocolScript.LOGIN_ACCOUNT:
			return AUTH_MODE_LOGIN
		AUTH_MODE_REGISTER, LobbyProtocolScript.REGISTER_ACCOUNT:
			return AUTH_MODE_REGISTER
		_:
			return fallback_mode

func _get_saved_account_username() -> String:
	if _local_profile_store == null:
		return ""
	return _local_profile_store.get_last_account_username()

func _get_editable_account_username() -> String:
	if _auth_onboarding_username_edit != null \
		and is_instance_valid(_auth_onboarding_username_edit) \
		and _auth_onboarding_username_edit.visible:
		return _auth_onboarding_username_edit.text.strip_edges()
	if player_name_line_edit != null and player_name_line_edit.editable:
		return player_name_line_edit.text.strip_edges()
	return ""

func _set_selected_account_username(username: String, sync_field: bool = true) -> void:
	_selected_account_username = username.strip_edges()
	if sync_field and player_name_line_edit != null and _selected_auth_mode != AUTH_MODE_GUEST:
		player_name_line_edit.text = _selected_account_username

func _set_selected_account_password(password: String, sync_field: bool = true) -> void:
	_selected_account_password = password
	if sync_field and _password_line_edit != null:
		_password_line_edit.text = _selected_account_password

func _sync_legacy_auth_fields() -> void:
	if _auth_mode_option != null:
		for index in range(_auth_mode_option.item_count):
			if str(_auth_mode_option.get_item_metadata(index)) != _selected_auth_mode:
				continue
			_auth_mode_option.select(index)
			break
	if player_name_line_edit != null and _selected_auth_mode != AUTH_MODE_GUEST:
		player_name_line_edit.text = _selected_account_username
	if _password_line_edit != null:
		_password_line_edit.text = _selected_account_password

func _should_recover_saved_account_identity() -> bool:
	if _local_profile_store == null:
		return false
	var saved_username: String = _get_saved_account_username()
	if saved_username.is_empty():
		return false
	var guest_profile_id: String = _local_profile_store.get_guest_profile_id()
	var current_profile_id: String = _local_profile_store.get_current_profile_id()
	if not guest_profile_id.is_empty() and current_profile_id != guest_profile_id:
		return false
	return not _local_profile_store.find_profile_id_by_account_username(saved_username).is_empty()

func _get_connected_account_username() -> String:
	if _account_switch_pending:
		return ""
	if lobby_client == null:
		return ""
	if not lobby_client.is_authenticated():
		return ""
	var lobby_username := str(lobby_client.current_username).strip_edges()
	if lobby_username.is_empty():
		return ""
	var lobby_auth_mode := _normalize_auth_mode(str(lobby_client.current_auth_mode), "")
	if not str(lobby_client.current_account_id).strip_edges().is_empty():
		return lobby_username
	if lobby_auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return lobby_username
	return ""

func _get_effective_account_username() -> String:
	if _account_switch_pending:
		return ""
	var connected_username := _get_connected_account_username()
	if not connected_username.is_empty():
		return connected_username
	return _logged_in_account_username.strip_edges()

func _get_preferred_account_username() -> String:
	var connected_username := _get_connected_account_username()
	if not connected_username.is_empty():
		return connected_username
	var auth_mode := _get_selected_auth_mode()
	if auth_mode not in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return ""
	if not _selected_account_username.is_empty():
		return _selected_account_username
	var editable_username := _get_editable_account_username()
	if not editable_username.is_empty():
		return editable_username
	var saved_username := _get_saved_account_username()
	if not saved_username.is_empty():
		return saved_username
	return ""

func _get_effective_identity_name(default_name: String = "Guest") -> String:
	var account_username := _get_effective_account_username()
	if not account_username.is_empty():
		return account_username
	var fallback_name := default_name.strip_edges()
	if fallback_name.is_empty():
		fallback_name = "Guest"
	if _get_selected_auth_mode() in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		var selected_account_username := _get_selected_account_username()
		if not selected_account_username.is_empty():
			return selected_account_username
	return _get_preferred_guest_display_name(fallback_name)

func _get_selected_account_username() -> String:
	var auth_mode := _get_selected_auth_mode()
	if auth_mode not in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return ""
	if not _selected_account_username.is_empty():
		return _selected_account_username
	var editable_username := _get_editable_account_username()
	if not editable_username.is_empty():
		return editable_username
	var saved_account_username := _get_saved_account_username()
	if not saved_account_username.is_empty():
		return saved_account_username
	return ""

func _get_active_profile_display_name(default_name: String = "Player") -> String:
	var resolved_default := default_name.strip_edges()
	if resolved_default.is_empty():
		resolved_default = "Player"
	var active_account_username := _get_effective_account_username()
	if not active_account_username.is_empty():
		return active_account_username
	var selected_account_username := _get_selected_account_username()
	if not selected_account_username.is_empty():
		return selected_account_username
	if _local_profile_store != null and not _local_profile_id.is_empty():
		var profile: Dictionary = _local_profile_store.get_profile(_local_profile_id)
		var profile_display_name := str(profile.get("display_name", "")).strip_edges()
		if not profile_display_name.is_empty():
			return profile_display_name
	return _get_effective_identity_name(resolved_default)

func _activate_account_profile(
	account_username: String,
	preferred_profile_id: String = "",
	auth_mode: String = AUTH_MODE_LOGIN,
	persist_password: bool = false,
	prefer_preferred_profile_id: bool = false
) -> String:
	_ensure_local_profile_store()
	var resolved_username := account_username.strip_edges()
	if _local_profile_store == null or resolved_username.is_empty():
		return _local_profile_id
	var profile: Dictionary = _local_profile_store.activate_account_session(
		resolved_username,
		preferred_profile_id,
		auth_mode,
		_get_auth_password(),
		persist_password,
		prefer_preferred_profile_id
	)
	_set_selected_account_username(resolved_username)
	_local_profile_id = str(profile.get("profile_id", _local_profile_id)).strip_edges()
	return _local_profile_id

func _on_switch_account_pressed() -> void:
	_account_switch_pending = true
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
		panel_style.set_border_width(side as Side, 2)
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

	var launch_auth_mode := _get_launch_auth_mode()
	if launch_auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		_begin_auth_onboarding_account_flow(launch_auth_mode)
	else:
		_set_auth_onboarding_hint("")
		if _auth_onboarding_username_edit != null:
			_auth_onboarding_username_edit.visible = false
			_auth_onboarding_username_edit.text = ""
		if _auth_onboarding_password_edit != null:
			_auth_onboarding_password_edit.visible = false
			_auth_onboarding_password_edit.text = ""
		if _auth_onboarding_continue_button != null:
			_auth_onboarding_continue_button.visible = false

func _begin_auth_onboarding_account_flow(auth_mode: String) -> void:
	if auth_mode not in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		auth_mode = AUTH_MODE_LOGIN
	_auth_onboarding_selected_mode = auth_mode
	_set_auth_onboarding_hint("")
	if _auth_onboarding_username_edit != null:
		_auth_onboarding_username_edit.visible = true
		if _auth_onboarding_username_edit.text.strip_edges().is_empty():
			var saved_username := ""
			if _local_profile_store != null:
				saved_username = _local_profile_store.get_last_account_username()
			if saved_username.is_empty():
				saved_username = _selected_account_username
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
	_set_selected_account_username(username)
	_set_selected_account_password(password)
	_prepare_submitted_account_auth(username)
	_complete_auth_onboarding(auth_mode, "Account details saved. Open Multiplayer to sign in.")
	return true

func _prepare_submitted_account_auth(username: String) -> void:
	var requested_username := username.strip_edges()
	if requested_username.is_empty():
		return
	_cancel_pending_authenticated_lobby_connects()
	var requested_key := requested_username.to_lower()
	var connected_key := _get_connected_account_username().strip_edges().to_lower()
	var logged_key := _logged_in_account_username.strip_edges().to_lower()
	if connected_key == requested_key and (logged_key.is_empty() or logged_key == requested_key):
		return
	_account_switch_pending = true
	_account_switch_retry_attempts = 0
	_logged_in_account_username = ""
	_lobby_session_id = ""
	_lobby_reconnect_token = ""

func _get_launch_auth_mode() -> String:
	if _local_profile_store == null:
		return AUTH_MODE_GUEST
	var preferred_auth_mode: String = _local_profile_store.get_preferred_auth_mode()
	if preferred_auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return preferred_auth_mode
	if preferred_auth_mode == AUTH_MODE_GUEST and _should_recover_saved_account_identity():
		return AUTH_MODE_LOGIN
	var saved_username: String = _get_saved_account_username()
	if not saved_username.is_empty():
		return AUTH_MODE_LOGIN
	return AUTH_MODE_GUEST

func _should_prompt_for_account_recovery(message: String) -> bool:
	if _is_account_logged_in():
		return false
	var normalized_message := message.strip_edges().to_lower()
	return normalized_message in [
		"that account was not found.",
		"incorrect password.",
	]

func _show_auth_recovery_prompt(message: String) -> void:
	_maybe_show_auth_onboarding()
	_begin_auth_onboarding_account_flow(AUTH_MODE_LOGIN)
	_set_auth_onboarding_hint("%s Use Continue as Guest if this server doesn't know this account yet." % message, true)

func _set_auth_onboarding_hint(message: String, is_error: bool = false) -> void:
	if _auth_onboarding_mode_hint_label == null:
		return
	_auth_onboarding_mode_hint_label.visible = not message.is_empty()
	_auth_onboarding_mode_hint_label.text = message
	_auth_onboarding_mode_hint_label.modulate = Color(1.0, 0.72, 0.72) if is_error else Color(0.76, 0.80, 0.92)

func _complete_auth_onboarding(auth_mode: String, message: String) -> void:
	_set_auth_mode(auth_mode)
	if auth_mode == AUTH_MODE_GUEST:
		_cancel_pending_authenticated_lobby_connects()
		_account_switch_pending = false
		_account_switch_retry_attempts = 0
		_apply_guest_display_name("Guest")
	else:
		var selected_account_username := _get_selected_account_username()
		if not selected_account_username.is_empty():
			_activate_account_profile(selected_account_username, "", auth_mode, true)
	multiplayer_container.visible = false
	ready_button.visible = false
	status_label.text = message
	show_menu()
	_refresh_open_deck_builder_saved_decks()
	if auth_mode != AUTH_MODE_GUEST:
		_current_profile_summary.clear()
		_refresh_profile_summary_label()
	_refresh_profile_summary_from_local_history(_local_profile_id)
	_update_resume_controls()
	_refresh_account_identity_label()
	_refresh_auth_controls()
	if multiplayer_button != null:
		multiplayer_button.grab_focus()
	_dismiss_auth_onboarding()
	if auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		_queue_authenticated_lobby_connect("Signing in to lobby...")

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
	var existing := game_container.get_node_or_null("DeckBuilder")
	if existing:
		existing.queue_free()

	var db := DeckBuilderUI.new()
	db.name = "DeckBuilder"
	db.configure_profile_store(_local_profile_store, _local_profile_id, _get_active_profile_display_name("Player"))
	if db.has_method("configure_online_sync"):
		db.configure_online_sync(lobby_client)
	if db.has_method("configure_account_decks"):
		db.configure_account_decks(
			_account_decks_cache,
			_uses_server_account_storage(),
			_get_server_preferred_account_deck_id()
		)
	if db.has_signal("account_deck_deleted_locally") and not db.account_deck_deleted_locally.is_connected(_on_deck_builder_account_deck_deleted_locally):
		db.account_deck_deleted_locally.connect(_on_deck_builder_account_deck_deleted_locally)
	_maybe_request_account_decks()
	db.back_pressed.connect(func() -> void:
		db.queue_free()
		show_menu()
	)
	_hide_embedded_games()
	game_container.add_child(db)
	_refresh_server_version_overlay_visibility()
	show_game()

func _open_rules_overlay() -> void:
	if _rules_overlay != null and is_instance_valid(_rules_overlay):
		return

	_rules_overlay = Control.new()
	_rules_overlay.name = "RulesOverlay"
	_rules_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rules_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_rules_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_rules_overlay.add_child(shade)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 40)
	outer_margin.add_theme_constant_override("margin_right", 40)
	outer_margin.add_theme_constant_override("margin_top", 36)
	outer_margin.add_theme_constant_override("margin_bottom", 36)
	outer_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rules_overlay.add_child(outer_margin)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	panel_style.border_color = Color(0.54, 0.76, 1.0, 0.95)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		panel_style.set_border_width(side as Side, 2)
	panel.add_theme_stylebox_override("panel", panel_style)
	outer_margin.add_child(panel)

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 18)
	inner_margin.add_theme_constant_override("margin_right", 18)
	inner_margin.add_theme_constant_override("margin_top", 18)
	inner_margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(inner_margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	inner_margin.add_child(content)

	var title := Label.new()
	title.text = "Rules"
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)

	var intro := Label.new()
	intro.text = "New player rules reference."
	intro.modulate = Color(0.78, 0.83, 0.95)
	content.add_child(intro)

	var rules_view := RichTextLabel.new()
	rules_view.bbcode_enabled = false
	rules_view.fit_content = false
	rules_view.scroll_active = true
	rules_view.selection_enabled = true
	rules_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_view.custom_minimum_size = Vector2(0, 420)
	rules_view.text = _get_rules_display_text()
	content.add_child(rules_view)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(110, 38)
	close_btn.pressed.connect(_close_rules_overlay)
	actions.add_child(close_btn)

	close_btn.grab_focus()

func _close_rules_overlay() -> void:
	if _rules_overlay == null:
		return
	if is_instance_valid(_rules_overlay):
		_rules_overlay.queue_free()
	_rules_overlay = null
	if rules_button != null:
		rules_button.grab_focus()

func _get_rules_display_text() -> String:
	var file := FileAccess.open(RULES_DOC_PATH, FileAccess.READ)
	if file == null:
		return "Unable to load the rules document at %s." % RULES_DOC_PATH
	return _format_rules_text(file.get_as_text())

func _format_rules_text(markdown: String) -> String:
	var formatted_lines: Array[String] = []
	for raw_line in markdown.split("\n"):
		var line := raw_line.rstrip("\r").replace("`", "")
		if line.begins_with("# "):
			formatted_lines.append(line.substr(2))
			formatted_lines.append("")
			continue
		if line.begins_with("## "):
			formatted_lines.append(line.substr(3))
			continue
		if line.begins_with("- "):
			formatted_lines.append("- " + line.substr(2))
			continue
		formatted_lines.append(line)
	return "\n".join(formatted_lines)

func _on_mock_game_pressed() -> void:
	_match_launch_queued = false
	_cleanup_lobby(true)
	_show_embedded_game("MockGame")
	show_game()
	get_node("GameContainer/MockGame").start_game()

func _on_card_test_pressed() -> void:
	_match_launch_queued = false
	_cleanup_lobby(true)
	_show_embedded_game("CardTest")
	show_game()
	var card_test: CardTestGame = get_node("GameContainer/CardTest")
	await card_test.start_game()

func _on_practice_thor_pressed() -> void:
	_refresh_multiplayer_deck_options()
	var selected_practice_deck := _get_selected_multiplayer_deck()
	_match_launch_queued = false
	_cleanup_lobby(true)
	var practice_game = _show_embedded_game("PracticeThor")
	show_game()
	if practice_game != null:
		practice_game.set_player_practice_deck(selected_practice_deck)
		await practice_game.start_game()

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
		status_label.text = "Could not start the dedicated lobby server. Make sure OtherGodsServer.exe is installed with the client."
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

	var should_delay_connect := _should_delay_fresh_lobby_connect()
	_prepare_fresh_lobby_login()
	_cleanup_lobby_client()
	_set_connected_server_version("")
	_is_local_lobby_host = false
	_current_lobby_ip = _get_lobby_ip()
	if should_delay_connect:
		status_label.text = "Closing previous lobby session..."
		await get_tree().process_frame
		await get_tree().create_timer(FRESH_LOBBY_RECONNECT_DELAY_SECONDS).timeout
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
	var should_delay_connect := _should_delay_fresh_lobby_connect()
	_prepare_fresh_lobby_login()
	_cleanup_lobby_client()
	_set_connected_server_version("")
	if should_delay_connect:
		status_label.text = "Closing previous lobby session..."
		await get_tree().process_frame
		await get_tree().create_timer(FRESH_LOBBY_RECONNECT_DELAY_SECONDS).timeout
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
	if not lobby_client.server_version_updated.is_connected(_on_server_version_updated):
		lobby_client.server_version_updated.connect(_on_server_version_updated)
	_set_connected_server_version(lobby_client.current_server_version)

func _on_lobby_connected() -> void:
	_write_smoke_trace("lobby_connected")
	status_label.text = "Connected to lobby. Signing in..."

func _on_server_version_updated(version: String) -> void:
	_set_connected_server_version(version)

func _on_lobby_login_succeeded(session_id: String, reconnect_token: String, player_name: String) -> void:
	_write_smoke_trace("lobby_login_succeeded session=%s player=%s host=%s" % [session_id, player_name, str(_is_local_lobby_host)])
	if _retry_account_switch_if_identity_mismatch(player_name):
		return
	_set_connected_server_version(lobby_client.current_server_version if lobby_client != null else "")
	_lobby_session_id = session_id
	_lobby_reconnect_token = reconnect_token
	_seek_list_request_pending = false
	_seek_auto_refresh_elapsed = SEEK_AUTO_REFRESH_INTERVAL_SECONDS
	_capture_logged_in_profile(player_name)
	_refresh_account_identity_label()
	_save_lobby_resume()
	_current_profile_summary.clear()
	_refresh_profile_summary_label()
	_maybe_request_account_decks()
	_maybe_request_profile_summary()
	var resolved_identity_name := _get_effective_identity_name(player_name)
	player_name_line_edit.text = resolved_identity_name
	_refresh_open_deck_builder_saved_decks()
	_update_resume_controls()
	var active_match_info: Dictionary = {}
	if lobby_client != null:
		active_match_info = lobby_client.current_active_match_info.duplicate(true)
	if not active_match_info.is_empty():
		if not _should_suppress_active_match_auto_resume(active_match_info):
			_save_active_match_resume(active_match_info)
			status_label.text = "Signed in as %s. Rejoining your active match..." % resolved_identity_name
			call_deferred("_resume_active_match_from_lobby", active_match_info)
			return
		_clear_saved_match_resume()
	if not _get_saved_active_match().is_empty():
		_clear_saved_match_resume()
	status_label.text = "Signed in as %s." % resolved_identity_name
	_run_pending_multiplayer_action()

func _on_lobby_reconnect_succeeded(
	session_id: String,
	reconnect_token: String,
	player_name: String,
	room: Dictionary,
	active_match_info: Dictionary
) -> void:
	_write_smoke_trace("lobby_reconnect_succeeded session=%s player=%s" % [session_id, player_name])
	if _retry_account_switch_if_identity_mismatch(player_name):
		return
	_set_connected_server_version(lobby_client.current_server_version if lobby_client != null else "")
	_lobby_session_id = session_id
	_lobby_reconnect_token = reconnect_token
	_seek_list_request_pending = false
	_seek_auto_refresh_elapsed = SEEK_AUTO_REFRESH_INTERVAL_SECONDS
	_capture_logged_in_profile(player_name)
	_refresh_account_identity_label()
	_save_lobby_resume()
	_current_profile_summary.clear()
	_refresh_profile_summary_label()
	_maybe_request_account_decks()
	_maybe_request_profile_summary()
	var resolved_identity_name := _get_effective_identity_name(player_name)
	player_name_line_edit.text = resolved_identity_name
	_refresh_open_deck_builder_saved_decks()
	_update_resume_controls()
	if not active_match_info.is_empty():
		if not _should_suppress_active_match_auto_resume(active_match_info):
			_save_active_match_resume(active_match_info)
			status_label.text = "Lobby session restored. Rejoining your active match..."
			call_deferred("_resume_active_match_from_lobby", active_match_info)
			return
		_clear_saved_match_resume()
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
	_seek_list_request_pending = false
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
	var room_status := str(snapshot.get("status", "")).strip_edges().to_lower()
	if room_status == "in_match" and not _match_launch_queued and lobby_client != null:
		var active_match_info: Dictionary = lobby_client.current_active_match_info.duplicate(true)
		if not active_match_info.is_empty() and str(active_match_info.get("room_id", "")).strip_edges() == room_id:
			if _should_suppress_active_match_auto_resume(active_match_info):
				_clear_saved_match_resume()
				return
			_save_active_match_resume(active_match_info)
			call_deferred("_resume_active_match_from_lobby", active_match_info)
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
	var mock_game = _show_embedded_game("MockGame")
	if mock_game != null and mock_game.has_method("_prepare_for_match_launch"):
		mock_game._prepare_for_match_launch("Connecting to match...")
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
	if _should_prompt_for_account_recovery(message):
		_show_auth_recovery_prompt(message)
	_fail_smoke_if_enabled("ROOM_ERROR:%s" % message)

func _on_lobby_status_changed(message: String) -> void:
	_write_smoke_trace("lobby_status %s" % message)
	status_label.text = message

func _on_lobby_connection_failed(message: String) -> void:
	_write_smoke_trace("lobby_connection_failed %s" % message)
	_set_connected_server_version("")
	_seek_list_request_pending = false
	_seek_auto_refresh_elapsed = 0.0
	if _should_retry_host_lobby_connect():
		_queue_host_lobby_retry(message)
		return
	_logged_in_account_username = ""
	_refresh_account_identity_label()
	status_label.text = message
	_fail_smoke_if_enabled("CONNECTION_FAILED:%s" % message)

func _on_lobby_disconnected() -> void:
	_write_smoke_trace("lobby_disconnected")
	_set_connected_server_version("")
	_seek_list_request_pending = false
	_seek_auto_refresh_elapsed = 0.0
	if _should_retry_host_lobby_connect():
		_queue_host_lobby_retry("Dedicated lobby disconnected before room setup completed.")
		return
	_refresh_account_identity_label()
	_clear_current_seek_state()
	status_label.text = "Lobby connection lost. Refresh open seeks to reconnect."
	_fail_smoke_if_enabled("DISCONNECTED_FROM_LOBBY")

func _on_back_to_menu_pressed() -> void:
	_return_to_menu()

func _on_game_forfeit_requested() -> void:
	_return_to_menu()

func _return_to_menu() -> void:
	_suppress_active_match_auto_resume_from_embedded_games()
	show_menu()
	_match_launch_queued = false
	_cleanup_lobby(true)
	for node_name in _get_embedded_game_node_names():
		var game = get_node_or_null("GameContainer/" + node_name)
		if game and game.has_method("cleanup"):
			game.cleanup()
	var db := game_container.get_node_or_null("DeckBuilder")
	if db:
		db.queue_free()
	_refresh_server_version_overlay_visibility()
	multiplayer_container.visible = false
	_maybe_connect_authenticated_lobby("Reconnecting to lobby...")

func _suppress_active_match_auto_resume_from_embedded_games() -> void:
	for node_name in _get_embedded_game_node_names():
		var game = get_node_or_null("GameContainer/" + node_name)
		if game == null or not bool(game.get("visible")):
			continue
		var match_info = game.get("_current_match_info")
		if not (match_info is Dictionary):
			continue
		var active_match_info: Dictionary = match_info
		var match_id := str(active_match_info.get("match_id", "")).strip_edges()
		var room_id := str(active_match_info.get("room_id", "")).strip_edges()
		if match_id.is_empty() and room_id.is_empty():
			continue
		_suppressed_active_match_id = match_id
		_suppressed_active_match_room_id = room_id
		_suppress_active_match_resume_until_msec = Time.get_ticks_msec() + int(ACTIVE_MATCH_AUTO_RESUME_SUPPRESS_SECONDS * 1000.0)
		return

func _should_suppress_active_match_auto_resume(active_match_info: Dictionary) -> bool:
	if Time.get_ticks_msec() > _suppress_active_match_resume_until_msec:
		_suppressed_active_match_id = ""
		_suppressed_active_match_room_id = ""
		_suppress_active_match_resume_until_msec = 0
		return false
	var match_id := str(active_match_info.get("match_id", "")).strip_edges()
	var room_id := str(active_match_info.get("room_id", "")).strip_edges()
	if not _suppressed_active_match_id.is_empty() and match_id == _suppressed_active_match_id:
		return true
	if not _suppressed_active_match_room_id.is_empty() and room_id == _suppressed_active_match_room_id:
		return true
	return false

func _cleanup_lobby(clear_session: bool) -> void:
	_cleanup_lobby_client()
	_cleanup_lobby_server()
	_set_connected_server_version("")
	_clear_current_seek_state()
	_open_seek_rooms.clear()
	_seek_list_request_pending = false
	_seek_auto_refresh_elapsed = 0.0
	_refresh_seek_list()
	if clear_session:
		_match_launch_queued = false
		_pending_host_room_creation = false
		_pending_local_lobby_launch_on_connect_failure = false
		_dedicated_lobby_connect_attempts_remaining = 0
		_last_submitted_lobby_room_id = ""
		_last_submitted_lobby_deck_id = ""
		_last_submitted_lobby_deck_hash = ""
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
		_account_decks_cache.clear()
		_refresh_profile_summary_label()
		_refresh_account_identity_label()
		status_label.text = "Refresh open seeks or create your own."
	_update_resume_controls()
	_refresh_multiplayer_action_state()

func _cleanup_lobby_client() -> void:
	if lobby_client == null:
		return
	var existing_client: LobbyClient = lobby_client
	lobby_client = null
	existing_client.disconnect_from_server()
	if existing_client.get_parent() != null:
		existing_client.get_parent().remove_child(existing_client)
	existing_client.queue_free()
	_cleanup_dedicated_lobby_mount_if_unused()

func _cleanup_lobby_server() -> void:
	if lobby_server == null:
		return
	var existing_server: LobbyServer = lobby_server
	lobby_server = null
	existing_server.stop_server()
	if existing_server.get_parent() != null:
		existing_server.get_parent().remove_child(existing_server)
	existing_server.queue_free()

func _attach_lobby_client(client: Node) -> void:
	var active_scene := get_tree().current_scene
	var parent_node: Node = active_scene if active_scene != null else self
	var existing_client: Node = parent_node.get_node_or_null(NodePath(client.name))
	if existing_client != null and existing_client != client:
		parent_node.remove_child(existing_client)
		existing_client.queue_free()
	parent_node.add_child(client)
	if client is LobbyClient:
		if active_scene != null:
			client.multiplayer_mount_path = active_scene.get_path()
		else:
			client.multiplayer_mount_path = NodePath("")

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
	if ip_line_edit != null:
		var typed_host = ip_line_edit.text.strip_edges()
		if not typed_host.is_empty():
			return typed_host
	var configured_host := str(ProjectSettings.get_setting(DEFAULT_LOBBY_HOST_SETTING, DEFAULT_LOBBY_HOST)).strip_edges()
	if configured_host.is_empty():
		return DEFAULT_LOBBY_HOST.strip_edges()
	return configured_host

func _get_project_default_lobby_host() -> String:
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
	var player_name := ""
	if _get_selected_auth_mode() in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		player_name = _get_selected_account_username()
	elif player_name_line_edit != null:
		player_name = player_name_line_edit.text.strip_edges()
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
	var profile: Dictionary = _local_profile_store.activate_guest_session(player_name)
	_local_profile_id = str(profile.get("profile_id", _local_profile_id)).strip_edges()
	_selected_multiplayer_deck_id = ""
	_refresh_open_deck_builder_saved_decks()
	_refresh_profile_summary_from_local_history(_local_profile_id)
	_update_resume_controls()
	_refresh_account_identity_label()
	return str(profile.get("display_name", player_name))

func _get_saved_guest_display_name(default_name: String = "Player") -> String:
	_ensure_local_profile_store()
	var resolved_default := default_name.strip_edges()
	if resolved_default.is_empty():
		resolved_default = "Player"
	if _local_profile_store == null:
		return resolved_default
	var profile: Dictionary = _local_profile_store.get_profile(_local_profile_id)
	var display_name := str(profile.get("display_name", resolved_default)).strip_edges()
	if display_name.is_empty():
		display_name = resolved_default
	var saved_account_username = _local_profile_store.get_last_account_username()
	if not saved_account_username.is_empty() and display_name == saved_account_username:
		display_name = resolved_default
	return display_name

func _get_preferred_guest_display_name(default_name: String = "Guest") -> String:
	var resolved_default := default_name.strip_edges()
	if resolved_default.is_empty():
		resolved_default = "Guest"
	return resolved_default

func _apply_guest_display_name(default_name: String = "Player") -> String:
	var guest_display_name := _get_preferred_guest_display_name(default_name)
	if _local_profile_store != null:
		var profile: Dictionary = _local_profile_store.activate_guest_session(guest_display_name)
		_local_profile_id = str(profile.get("profile_id", _local_profile_id)).strip_edges()
		guest_display_name = str(profile.get("display_name", guest_display_name)).strip_edges()
		_selected_multiplayer_deck_id = ""
		_refresh_open_deck_builder_saved_decks()
		_refresh_profile_summary_from_local_history(_local_profile_id)
		_update_resume_controls()
		_refresh_account_identity_label()
	if player_name_line_edit != null:
		player_name_line_edit.text = guest_display_name
	return guest_display_name

func _capture_logged_in_profile(player_name: String) -> void:
	_ensure_local_profile_store()
	if _local_profile_store == null:
		return
	_account_switch_pending = false
	_account_switch_retry_attempts = 0
	var previous_profile_id := _local_profile_id.strip_edges()
	var resolved_profile_id := previous_profile_id
	var resolved_auth_mode := _get_selected_auth_mode()
	var resolved_account_username := ""
	if lobby_client != null:
		resolved_profile_id = str(lobby_client.current_profile_id).strip_edges()
		var lobby_auth_mode := _normalize_auth_mode(str(lobby_client.current_auth_mode), resolved_auth_mode)
		if lobby_auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
			resolved_auth_mode = lobby_auth_mode
		resolved_account_username = _get_connected_account_username()
		if resolved_account_username.is_empty() and resolved_auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
			resolved_account_username = str(lobby_client.current_username).strip_edges()
		if resolved_account_username.is_empty() and resolved_auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
			resolved_account_username = player_name.strip_edges()
	if resolved_profile_id.is_empty():
		resolved_profile_id = previous_profile_id
	if resolved_account_username.is_empty() and resolved_auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		resolved_account_username = _get_preferred_account_username()
	if not resolved_account_username.is_empty():
		_account_decks_cache.clear()
		_logged_in_account_username = resolved_account_username
		_set_selected_account_username(resolved_account_username)
		var prefer_connected_profile_id := not resolved_profile_id.is_empty() \
			and resolved_auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]
		resolved_profile_id = _activate_account_profile(
			resolved_account_username,
			resolved_profile_id,
			resolved_auth_mode,
			not _get_auth_password().is_empty(),
			prefer_connected_profile_id
		)
		_local_profile_id = resolved_profile_id
	else:
		_logged_in_account_username = ""
		_account_decks_cache.clear()
		resolved_auth_mode = AUTH_MODE_GUEST
		var guest_profile: Dictionary = _local_profile_store.activate_guest_session("Guest")
		_local_profile_id = str(guest_profile.get("profile_id", resolved_profile_id)).strip_edges()
		if player_name_line_edit != null:
			player_name_line_edit.text = str(guest_profile.get("display_name", "Guest")).strip_edges()
	_selected_multiplayer_deck_id = ""
	_set_auth_mode(resolved_auth_mode)
	_refresh_open_deck_builder_saved_decks()
	_refresh_profile_summary_from_local_history(_local_profile_id)
	_update_resume_controls()
	_refresh_account_identity_label()

func _retry_account_switch_if_identity_mismatch(player_name: String) -> bool:
	if not _account_switch_pending or lobby_client == null:
		return false
	var desired_username := _selected_account_username.strip_edges().to_lower()
	if desired_username.is_empty():
		return false
	var actual_username := str(lobby_client.current_username).strip_edges().to_lower()
	if actual_username.is_empty():
		actual_username = player_name.strip_edges().to_lower()
	if actual_username.is_empty() or actual_username == desired_username:
		return false
	if _account_switch_retry_attempts >= 1:
		return false
	_account_switch_retry_attempts += 1
	_write_smoke_trace("account_switch_retry desired=%s actual=%s" % [desired_username, actual_username])
	_lobby_session_id = ""
	_lobby_reconnect_token = ""
	_cleanup_lobby_client()
	_set_connected_server_version("")
	status_label.text = "Retrying account switch..."
	_queue_authenticated_lobby_connect("Retrying account switch...")
	return true

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

func _on_account_deck_list_received(decks, preferred_deck_id: String = "") -> void:
	var remote_decks: Array[Dictionary] = []
	if decks is Array:
		for entry in decks:
			if entry is Dictionary:
				remote_decks.append((entry as Dictionary).duplicate(true))
	var deleted_lookup := _get_deleted_account_deck_lookup()
	var remote_deck_ids: Array[String] = []
	for remote_deck in remote_decks:
		var remote_deck_id := str(remote_deck.get("deck_id", "")).strip_edges()
		if _should_ignore_account_deck_sync_update(remote_deck_id, deleted_lookup):
			continue
		remote_deck_ids.append(remote_deck_id)
		_mirror_remote_account_deck_locally(remote_deck)
	_mark_active_profile_account_decks_synced(remote_deck_ids)
	var merged_decks := _merge_account_deck_catalogs(
		remote_decks,
		_get_local_saved_decks_for_active_profile(),
		_get_synced_account_deck_lookup(),
		deleted_lookup
	)
	var visible_decks: Array[Dictionary] = merged_decks.get("visible_decks", [])
	var local_migration_decks: Array[Dictionary] = merged_decks.get("local_migration_decks", [])
	_replace_account_decks_cache(visible_decks)
	for local_deck in local_migration_decks:
		if lobby_client == null:
			break
		lobby_client.save_account_deck(
			str(local_deck.get("name", "Deck")),
			local_deck.get("cards", {}),
			str(local_deck.get("deck_id", "")),
			local_deck.get("special_setup", {})
		)
	var resolved_preferred_deck_id := preferred_deck_id.strip_edges()
	if resolved_preferred_deck_id.is_empty():
		resolved_preferred_deck_id = _get_server_preferred_account_deck_id()
	var has_selected_deck := false
	if not _selected_multiplayer_deck_id.is_empty():
		for entry in visible_decks:
			if str(entry.get("deck_id", "")).strip_edges() == _selected_multiplayer_deck_id:
				has_selected_deck = true
				break
	if not resolved_preferred_deck_id.is_empty():
		var has_preferred_deck := false
		for entry in visible_decks:
			if str(entry.get("deck_id", "")).strip_edges() == resolved_preferred_deck_id:
				has_preferred_deck = true
				break
		if has_preferred_deck:
			_selected_multiplayer_deck_id = resolved_preferred_deck_id
		elif not has_selected_deck:
			_selected_multiplayer_deck_id = ""
	elif not has_selected_deck:
		_selected_multiplayer_deck_id = ""
	_refresh_open_deck_builder_saved_decks()

func _on_account_deck_saved(deck) -> void:
	if not (deck is Dictionary):
		return
	var saved_deck := (deck as Dictionary).duplicate(true)
	var saved_deck_id := str(saved_deck.get("deck_id", "")).strip_edges()
	if _should_ignore_account_deck_sync_update(saved_deck_id, _get_deleted_account_deck_lookup()):
		_remove_account_deck_from_cache(saved_deck_id)
		_refresh_open_deck_builder_saved_decks()
		return
	_upsert_account_deck_cache(saved_deck)
	_mirror_remote_account_deck_locally(saved_deck)
	_mark_active_profile_account_decks_synced([saved_deck_id])
	_refresh_open_deck_builder_saved_decks()

func _on_account_deck_deleted(deck_id: String) -> void:
	var resolved_deck_id := deck_id.strip_edges()
	_remove_account_deck_from_cache(resolved_deck_id)
	if _local_profile_store != null and not _local_profile_id.is_empty():
		_local_profile_store.mark_account_decks_deleted(_local_profile_id, [resolved_deck_id])
		_local_profile_store.delete_deck(_local_profile_id, resolved_deck_id)
	if _get_server_preferred_account_deck_id() == resolved_deck_id and lobby_client != null:
		lobby_client.current_preferred_account_deck_id = ""
	if _selected_multiplayer_deck_id == resolved_deck_id:
		_selected_multiplayer_deck_id = ""
	_refresh_open_deck_builder_saved_decks()

func _on_deck_builder_account_deck_deleted_locally(deck_id: String) -> void:
	var resolved_deck_id := deck_id.strip_edges()
	if resolved_deck_id.is_empty():
		return
	_remove_account_deck_from_cache(resolved_deck_id)
	if _get_server_preferred_account_deck_id() == resolved_deck_id and lobby_client != null:
		lobby_client.current_preferred_account_deck_id = ""
	if _selected_multiplayer_deck_id == resolved_deck_id:
		_selected_multiplayer_deck_id = ""
	_refresh_open_deck_builder_saved_decks()

func _on_profile_summary_received(summary) -> void:
	if not (summary is Dictionary):
		return
	_current_profile_summary = (summary as Dictionary).duplicate(true)
	_refresh_profile_summary_label()

func _refresh_open_deck_builder_saved_decks() -> void:
	_refresh_multiplayer_deck_options()
	var deck_builder = game_container.get_node_or_null("DeckBuilder")
	if deck_builder == null:
		return
	if deck_builder.has_method("configure_profile_store"):
		deck_builder.configure_profile_store(_local_profile_store, _local_profile_id, _get_active_profile_display_name("Player"))
	if deck_builder.has_method("configure_online_sync"):
		deck_builder.configure_online_sync(lobby_client)
	if deck_builder.has_method("configure_account_decks"):
		deck_builder.configure_account_decks(
			_account_decks_cache,
			_uses_server_account_storage(),
			_get_server_preferred_account_deck_id()
		)
	if not deck_builder.has_method("reload_saved_decks_from_store"):
		return
	deck_builder.reload_saved_decks_from_store()

func _build_profile_summary_controls() -> void:
	if multiplayer_container == null or _profile_summary_label != null:
		return
	var panel := PanelContainer.new()
	panel.name = "ProfileSummaryPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_profile_summary_panel_gui_input)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.92)
	style.border_color = Color(0.30, 0.40, 0.55, 0.8)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side as Side, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	_profile_summary_panel = panel
	_profile_summary_label = Label.new()
	_profile_summary_label.name = "ProfileSummaryLabel"
	_profile_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_profile_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_profile_summary_label.add_theme_font_size_override("font_size", 13)
	_profile_summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_profile_summary_label)
	multiplayer_container.add_child(panel)
	if seek_list != null:
		multiplayer_container.move_child(panel, seek_list.get_index())

func _build_account_identity_controls() -> void:
	if _account_identity_label != null and is_instance_valid(_account_identity_label):
		_account_identity_label.queue_free()
	_account_identity_label = null
	_refresh_account_identity_label()

func _refresh_account_identity_label() -> void:
	var active_account_username := _get_effective_account_username()
	if _logged_in_account_username != active_account_username:
		_logged_in_account_username = active_account_username
	if title_label != null:
		title_label.text = _get_effective_identity_name("Guest")
	if _account_identity_label == null:
		return
	if not active_account_username.is_empty():
		_account_identity_label.text = "Signed in: %s" % active_account_username
		_account_identity_label.visible = true
		_refresh_auth_controls()
		return
	var selected_account_username := _get_selected_account_username()
	if selected_account_username.is_empty():
		_account_identity_label.visible = false
		_account_identity_label.text = ""
		_refresh_auth_controls()
		return
	_account_identity_label.text = "Account: %s" % selected_account_username
	_account_identity_label.visible = true
	_refresh_auth_controls()

func _refresh_profile_summary_label() -> void:
	if _profile_summary_label == null:
		return
	var panel := _profile_summary_panel if _profile_summary_panel != null else _profile_summary_label.get_parent()
	if _current_profile_summary.is_empty():
		_profile_summary_label.text = ""
		if panel != null:
			panel.visible = false
		return
	var total_wins: int = int(_current_profile_summary.get("total_wins", 0))
	var total_losses: int = int(_current_profile_summary.get("total_losses", 0))
	var summary_line := "Match Record: %d-%d" % [total_wins, total_losses]
	var lines: Array[String] = [summary_line]

	var god_records = _current_profile_summary.get("god_records", [])
	var deck_records = _current_profile_summary.get("deck_records", [])
	var recent_matches = _current_profile_summary.get("recent_matches", [])
	var has_details := (
		(god_records is Array and not (god_records as Array).is_empty())
		or (deck_records is Array and not (deck_records as Array).is_empty())
		or (recent_matches is Array and not (recent_matches as Array).is_empty())
	)

	if _profile_summary_expanded and has_details:
		if god_records is Array and not (god_records as Array).is_empty():
			lines.append("")
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

		if deck_records is Array and not (deck_records as Array).is_empty():
			lines.append("")
			lines.append("By Deck:")
			var displayed_deck_records: int = 0
			for raw_record in deck_records:
				if not (raw_record is Dictionary):
					continue
				var deck_record: Dictionary = raw_record as Dictionary
				lines.append("%s %d-%d" % [
					_get_profile_summary_deck_name(str(deck_record.get("deck_name", ""))),
					int(deck_record.get("wins", 0)),
					int(deck_record.get("losses", 0)),
				])
				displayed_deck_records += 1
				if displayed_deck_records >= 3:
					break

		if recent_matches is Array and not (recent_matches as Array).is_empty():
			lines.append("")
			lines.append("Recent:")
			var displayed_recent_matches: int = 0
			for raw_match in recent_matches:
				if not (raw_match is Dictionary):
					continue
				var recent_match: Dictionary = raw_match as Dictionary
				var result_text: String = "W" if str(recent_match.get("result", "")).to_lower() == "win" else "L"
				lines.append("%s as %s vs %s" % [
					result_text,
					_get_profile_summary_loadout(
						str(recent_match.get("god_name", "Unknown God")),
						str(recent_match.get("deck_name", ""))
					),
					_get_profile_summary_loadout(
						str(recent_match.get("opponent_god_name", "Unknown God")),
						str(recent_match.get("opponent_deck_name", ""))
					),
				])
				displayed_recent_matches += 1
				if displayed_recent_matches >= 3:
					break

		lines.append("")
		lines.append("Tap to collapse")
	elif has_details:
		lines.append("Tap for details")

	_profile_summary_label.text = "\n".join(lines)
	if panel != null:
		panel.visible = true

func _on_profile_summary_panel_gui_input(event: InputEvent) -> void:
	if _current_profile_summary.is_empty():
		return
	var wants_toggle := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		wants_toggle = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		wants_toggle = touch_event.pressed
	if not wants_toggle:
		return
	var god_records = _current_profile_summary.get("god_records", [])
	var deck_records = _current_profile_summary.get("deck_records", [])
	var recent_matches = _current_profile_summary.get("recent_matches", [])
	var has_details := (
		(god_records is Array and not (god_records as Array).is_empty())
		or (deck_records is Array and not (deck_records as Array).is_empty())
		or (recent_matches is Array and not (recent_matches as Array).is_empty())
	)
	if not has_details:
		return
	_profile_summary_expanded = not _profile_summary_expanded
	_refresh_profile_summary_label()

func _get_profile_summary_deck_name(deck_name: String) -> String:
	var resolved_deck_name := deck_name.strip_edges()
	if resolved_deck_name.is_empty():
		return "Unknown Deck"
	return resolved_deck_name

func _get_profile_summary_loadout(god_name: String, deck_name: String) -> String:
	var resolved_god_name := god_name.strip_edges()
	if resolved_god_name.is_empty():
		resolved_god_name = "Unknown God"
	var resolved_deck_name := deck_name.strip_edges()
	if resolved_deck_name.is_empty():
		return resolved_god_name
	return "%s (%s)" % [resolved_god_name, resolved_deck_name]

func _refresh_profile_summary_from_local_history(profile_id: String) -> void:
	if _is_account_logged_in() or _get_selected_auth_mode() in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return
	var resolved_profile_id := profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		return
	var history_store = MatchHistoryStoreScript.new()
	_current_profile_summary = history_store.get_profile_summary(resolved_profile_id)
	_refresh_profile_summary_label()

func _should_refresh_profile_summary_from_local_history(saved_match: Dictionary) -> bool:
	if saved_match.is_empty():
		return false
	if _is_local_lobby_host:
		return true
	return str(saved_match.get("server_mode", "")).strip_edges() == MatchSessionScript.SERVER_MODE_IN_PROCESS_HOST

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

func _build_unranked_seek_controls() -> void:
	if multiplayer_container == null or create_seek_button == null or _create_unranked_seek_button != null:
		return
	_create_unranked_seek_button = Button.new()
	_create_unranked_seek_button.name = "CreateUnrankedSeekButton"
	_create_unranked_seek_button.text = "Create Unranked Seek"
	_create_unranked_seek_button.pressed.connect(_on_create_unranked_seek_pressed)
	multiplayer_container.add_child(_create_unranked_seek_button)
	multiplayer_container.move_child(_create_unranked_seek_button, create_seek_button.get_index() + 1)

func _restore_saved_resume_state() -> void:
	_update_resume_controls()
	_refresh_profile_summary_label()
	if _get_selected_auth_mode() != AUTH_MODE_GUEST:
		return
	var saved_match := _get_saved_active_match_for_profile(_local_profile_id)
	var saved_lobby_resume := _get_saved_lobby_resume_for_profile(_local_profile_id)
	if saved_match.is_empty() or saved_lobby_resume.is_empty():
		return
	multiplayer_container.visible = false
	ready_button.visible = false
	status_label.text = "A live match can be resumed from this device."

func _update_resume_controls() -> void:
	if _resume_match_button == null or _local_profile_store == null:
		return
	var has_resume := false
	if _get_selected_auth_mode() == AUTH_MODE_GUEST:
		has_resume = not _get_saved_active_match_for_profile(_local_profile_id).is_empty() \
			and not _get_saved_lobby_resume_for_profile(_local_profile_id).is_empty()
	_resume_match_button.visible = has_resume

func _get_saved_lobby_resume() -> Dictionary:
	if _local_profile_store == null:
		return {}
	return _local_profile_store.get_lobby_resume(_get_resume_profile_id())

func _get_saved_active_match() -> Dictionary:
	if _local_profile_store == null:
		return {}
	return _local_profile_store.get_active_match(_get_resume_profile_id())

func _get_saved_lobby_resume_for_profile(profile_id: String) -> Dictionary:
	if _local_profile_store == null:
		return {}
	return _local_profile_store.get_lobby_resume(profile_id)

func _get_saved_active_match_for_profile(profile_id: String) -> Dictionary:
	if _local_profile_store == null:
		return {}
	return _local_profile_store.get_active_match(profile_id)

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
		auth_mode = _normalize_auth_mode(str(lobby_client.current_auth_mode), auth_mode)
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
		_normalize_auth_mode(str(saved_lobby_resume.get("auth_mode", AUTH_MODE_GUEST)), AUTH_MODE_GUEST),
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
	var saved_match := _get_saved_active_match()
	var resume_profile_id := _get_resume_profile_id()
	_clear_saved_match_resume()
	if _should_refresh_profile_summary_from_local_history(saved_match):
		_refresh_profile_summary_from_local_history(resume_profile_id)
	_maybe_request_profile_summary()

func _maybe_submit_current_profile_deck(room_id: String, snapshot: Dictionary) -> void:
	if lobby_client == null or _lobby_session_id.is_empty():
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
		_last_submitted_lobby_deck_hash = ""
		_refresh_multiplayer_action_state()
		return
	var selected_deck_hash := LobbyRoomScript.compute_deck_hash(
		str(selected_deck.get("name", "Default Deck")),
		selected_deck.get("cards", {}) as Dictionary,
		selected_deck.get("special_setup", {})
	)
	var submitted_deck_id := str(local_member.get("selected_deck_id", "")).strip_edges()
	var submitted_deck_hash := str(local_member.get("selected_deck_hash", "")).strip_edges()
	if bool(local_member.get("has_valid_deck", false)) \
			and submitted_deck_id == selected_deck_id \
			and submitted_deck_hash == selected_deck_hash:
		_last_submitted_lobby_room_id = room_id
		_last_submitted_lobby_deck_id = selected_deck_id
		_last_submitted_lobby_deck_hash = selected_deck_hash
		return
	if _last_submitted_lobby_room_id == room_id \
			and _last_submitted_lobby_deck_id == selected_deck_id \
			and _last_submitted_lobby_deck_hash == selected_deck_hash:
		return
	if _uses_server_account_storage():
		lobby_client.submit_deck("", {}, selected_deck_id)
	else:
		lobby_client.submit_deck(
			str(selected_deck.get("name", "Default Deck")),
			selected_deck.get("cards", {}),
			selected_deck_id,
			selected_deck.get("special_setup", {})
		)
	_last_submitted_lobby_room_id = room_id
	_last_submitted_lobby_deck_id = selected_deck_id
	_last_submitted_lobby_deck_hash = selected_deck_hash

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
	_set_selected_account_username(str(_smoke_config.get("player_name", "Smoke%s" % role.capitalize())))
	var smoke_auth_mode: String = str(_smoke_config.get("auth_mode", AUTH_MODE_GUEST)).strip_edges().to_lower()
	if smoke_auth_mode not in [AUTH_MODE_GUEST, AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		smoke_auth_mode = AUTH_MODE_GUEST
	_set_auth_mode(smoke_auth_mode)
	_set_selected_account_password(str(_smoke_config.get("password", "")))

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

	if role == "practice_thor":
		call_deferred("_run_practice_thor_smoke")
		return

	if role == "card_test_turn2":
		call_deferred("_run_card_test_turn2_smoke")
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

func _run_practice_thor_smoke() -> void:
	var practice_game = _show_embedded_game("PracticeThor")
	if practice_game == null:
		_complete_practice_thor_smoke(false, "practice_thor_missing")
		return
	show_game()
	practice_game.set_player_practice_deck({})
	await practice_game.start_game()
	await get_tree().process_frame
	await get_tree().process_frame

	var setup_error := _get_practice_thor_smoke_setup_error(practice_game)
	if not setup_error.is_empty():
		_complete_practice_thor_smoke(false, setup_error)
		return

	if not practice_game.game_input.submit_action({type = "upkeep_choice", choice = "draw"}):
		_complete_practice_thor_smoke(false, "practice_thor_upkeep_choice_failed")
		return
	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return practice_game.game_manager.current_player == practice_game.player1 \
				and practice_game.game_manager.has_resolved_turn_upkeep() \
				and practice_game.game_manager.action_stack.is_empty(),
		180
	):
		_complete_practice_thor_smoke(false, "practice_thor_player_one_upkeep_timeout")
		return

	practice_game._do_end_turn()
	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return practice_game.game_manager.current_player == practice_game.player1 \
				and practice_game.game_manager.turn_number >= 3 \
				and practice_game.game_manager.action_stack.is_empty(),
		400
	):
		_complete_practice_thor_smoke(false, "practice_thor_turn_timeout")
		return

	if _count_cards_of_type_in_zones(practice_game.player2.frontline_zones + practice_game.player2.reserve_zones, HariiWarrior) != 1:
		_complete_practice_thor_smoke(false, "practice_thor_missing_harii")
		return
	if _count_cards_of_type_in_zones(practice_game.player2.frontline_zones + practice_game.player2.reserve_zones, MeadOfPoetry, true) != 1:
		_complete_practice_thor_smoke(false, "practice_thor_missing_mead")
		return
	if _count_cards_of_type_in_zones(practice_game.player2.frontline_zones + practice_game.player2.reserve_zones, VoidShield, true) != 1:
		_complete_practice_thor_smoke(false, "practice_thor_missing_void_shield")
		return
	if practice_game.player1.followers >= 100:
		_complete_practice_thor_smoke(false, "practice_thor_no_direct_attack")
		return

	_complete_practice_thor_smoke(true, "practice_thor")

func _get_practice_thor_smoke_setup_error(practice_game) -> String:
	if practice_game == null:
		return "practice_thor_missing"
	if practice_game.player2 == null or practice_game.player1 == null:
		return "practice_thor_players_missing"
	if practice_game.player2.player_name != "Thor":
		return "practice_thor_wrong_name"
	if practice_game.player2.god_zone.cards.size() != 1 or not (practice_game.player2.god_zone.cards[0] is Thor):
		return "practice_thor_wrong_god"
	if practice_game.game_manager.current_player != practice_game.player1:
		return "practice_thor_wrong_start_player"
	if practice_game.game_manager.has_resolved_turn_upkeep():
		return "practice_thor_upkeep_already_resolved"
	if practice_game.player2.mana != 2:
		return "practice_thor_wrong_starting_mana"
	var regular_zones := [practice_game.player2.hand_zone, practice_game.player2.deck_zone]
	if _count_cards_of_type_in_zones(regular_zones, EnkiLordOfEridu) != 2:
		return "practice_thor_wrong_enki_count"
	if _count_cards_of_type_in_zones(regular_zones, MeadOfPoetry) != 1:
		return "practice_thor_wrong_mead_count"
	if _count_cards_of_type_in_zones(regular_zones, HariiWarrior) != 3:
		return "practice_thor_wrong_harii_count"
	if _count_cards_of_type_in_zones(regular_zones, BrownBear) != 3:
		return "practice_thor_wrong_brown_bear_count"
	if _count_cards_of_type_in_zones(regular_zones, FallOfTheMighty) != 3:
		return "practice_thor_wrong_fall_count"
	if _count_cards_of_type_in_zones(regular_zones, VoidShield) != 3:
		return "practice_thor_wrong_void_shield_count"
	if _count_cards_of_type_in_zones(regular_zones, DivineLightning) != 3:
		return "practice_thor_wrong_divine_lightning_count"
	return ""

func _count_cards_of_type_in_zones(zones: Array, script_type, prepared_only: bool = false) -> int:
	var count := 0
	for zone in zones:
		if zone == null:
			continue
		for card in zone.cards:
			if prepared_only and not card.is_prepared:
				continue
			if is_instance_of(card, script_type):
				count += 1
	return count

func _wait_for_practice_thor_smoke_condition(predicate: Callable, max_frames: int) -> bool:
	for _frame in range(max_frames):
		if predicate.call():
			return true
		await get_tree().process_frame
	return false

func _complete_practice_thor_smoke(success: bool, message: String) -> void:
	if success:
		_finish_smoke_if_enabled("PASS:%s" % message)
	else:
		_fail_smoke_if_enabled(message)

func _run_card_test_turn2_smoke() -> void:
	var card_test = _show_embedded_game("CardTest")
	if card_test == null:
		_fail_smoke_if_enabled("card_test_missing")
		return
	show_game()
	await card_test.start_game()
	await get_tree().process_frame
	await get_tree().process_frame

	if not card_test.game_input.submit_action({type = "upkeep_choice", choice = "mana"}):
		_fail_smoke_if_enabled("card_test_turn1_upkeep_choice_failed")
		return
	if not await _wait_for_card_test_turn2_smoke_condition(
		func() -> bool:
			return card_test.game_manager.current_player == card_test.player1 \
				and card_test.game_manager.has_resolved_turn_upkeep() \
				and card_test.game_manager.action_stack.is_empty(),
		180
	):
		_fail_smoke_if_enabled("card_test_turn1_upkeep_timeout")
		return

	card_test._do_end_turn()
	if not await _wait_for_card_test_turn2_smoke_condition(
		func() -> bool:
			return card_test.game_manager.current_player == card_test.player2 \
				and card_test.choice_container.visible,
		240
	):
		_fail_smoke_if_enabled("card_test_turn2_entry_timeout")
		return

	if not card_test.game_input.submit_action({type = "upkeep_choice", choice = "mana"}):
		_fail_smoke_if_enabled("card_test_turn2_upkeep_choice_failed")
		return
	if not await _wait_for_card_test_turn2_smoke_condition(
		func() -> bool:
			return card_test.game_manager.current_player == card_test.player2 \
				and card_test.game_manager.has_resolved_turn_upkeep() \
				and card_test.game_manager.action_stack.is_empty() \
				and not card_test._stack_resolution_paused \
				and not card_test._executing_stack_action,
		240
	):
		_fail_smoke_if_enabled(
			"card_test_turn2_stalled stack=%d paused=%s executing=%s label=%s" % [
				card_test.game_manager.action_stack.size(),
				str(card_test._stack_resolution_paused),
				str(card_test._executing_stack_action),
				str(card_test.action_label.text).replace("\n", " "),
			]
		)
		return

	_finish_smoke_if_enabled("PASS:card_test_turn2")

func _wait_for_card_test_turn2_smoke_condition(predicate: Callable, max_frames: int) -> bool:
	for _frame in range(max_frames):
		if predicate.call():
			return true
		await get_tree().process_frame
	return false
	get_tree().quit()

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
		executable_dir.path_join("OtherGodsServer.exe"),
		executable_dir.path_join("OtherGodsServer_console.exe"),
		executable_dir.path_join("ClaudeOtherGodsServer.exe"),
		executable_dir.path_join("ClaudeOtherGodsServer_console.exe"),
		executable_dir.path_join("server").path_join("OtherGodsServer.exe"),
		executable_dir.path_join("server").path_join("ClaudeOtherGodsServer.exe"),
		executable_parent_dir.path_join("server").path_join("OtherGodsServer.exe"),
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
	_sync_legacy_auth_fields()
	_refresh_auth_controls()

func _restore_auth_preferences() -> void:
	if _local_profile_store == null:
		return
	var auth_mode: String = _normalize_auth_mode(_local_profile_store.get_preferred_auth_mode(), AUTH_MODE_GUEST)
	var saved_username := _get_saved_account_username()
	if auth_mode == AUTH_MODE_GUEST and _should_recover_saved_account_identity():
		auth_mode = AUTH_MODE_LOGIN
		_local_profile_store.set_preferred_auth_mode(auth_mode)
	_set_selected_account_username(saved_username)
	_set_selected_account_password(_local_profile_store.get_last_account_password())
	_set_auth_mode(auth_mode)
	if auth_mode != AUTH_MODE_GUEST:
		if not saved_username.is_empty():
			_activate_account_profile(saved_username, "", auth_mode, false)
	else:
		_apply_guest_display_name("Guest")
	_refresh_auth_controls()
	_refresh_account_identity_label()
	if auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		_queue_authenticated_lobby_connect("Restoring lobby session...")

func _on_auth_mode_selected(_index: int) -> void:
	if _auth_mode_option != null and _auth_mode_option.item_count > 0:
		var metadata = _auth_mode_option.get_item_metadata(_auth_mode_option.selected)
		_selected_auth_mode = _normalize_auth_mode(str(metadata), AUTH_MODE_GUEST)
	_refresh_auth_controls()
	if _local_profile_store == null:
		return
	var auth_mode := _get_selected_auth_mode()
	if auth_mode != AUTH_MODE_GUEST:
		var preferred_account_username := _get_preferred_account_username()
		if not preferred_account_username.is_empty():
			_set_selected_account_username(preferred_account_username)
			_activate_account_profile(preferred_account_username, "", auth_mode, false)
		elif _local_profile_store != null:
			_local_profile_store.set_preferred_auth_mode(auth_mode)
		if _get_auth_password().is_empty():
			_set_selected_account_password(_local_profile_store.get_last_account_password())
	else:
		_apply_guest_display_name("Guest")
	_refresh_open_deck_builder_saved_decks()
	_refresh_profile_summary_from_local_history(_local_profile_id)
	_update_resume_controls()
	_refresh_account_identity_label()

func _set_auth_mode(auth_mode: String) -> void:
	_selected_auth_mode = _normalize_auth_mode(auth_mode, AUTH_MODE_GUEST)
	if _auth_mode_option == null:
		_refresh_auth_controls()
		return
	for index in range(_auth_mode_option.item_count):
		if str(_auth_mode_option.get_item_metadata(index)) != _selected_auth_mode:
			continue
		_auth_mode_option.select(index)
		break
	_refresh_auth_controls()

func _get_selected_auth_mode() -> String:
	return _selected_auth_mode

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
	var username: String = _get_preferred_account_username()
	if username.is_empty():
		return "Enter an account username first."
	if _get_auth_password().is_empty():
		return "Enter your account password first."
	return ""

func _get_auth_password() -> String:
	if not _selected_account_password.is_empty():
		return _selected_account_password
	if _password_line_edit == null:
		return ""
	return _password_line_edit.text

func _get_lobby_login_name(default_name: String) -> String:
	var auth_mode := _get_selected_auth_mode()
	if auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		var preferred_account_username := _get_preferred_account_username()
		if not preferred_account_username.is_empty():
			_set_selected_account_username(preferred_account_username)
			_activate_account_profile(
				preferred_account_username,
				_local_profile_id,
				auth_mode,
				not _get_auth_password().is_empty()
			)
			return preferred_account_username
	if auth_mode == AUTH_MODE_GUEST:
		var guest_name := _get_preferred_guest_display_name(default_name)
		return _remember_local_profile(guest_name)
	var player_name := _get_player_name(default_name)
	return player_name
