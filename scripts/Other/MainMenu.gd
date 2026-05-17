extends Control

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")
const AccountStoreScript = preload("res://scripts/server/AccountStore.gd")
const LobbyClientScript = preload("res://scripts/client/LobbyClient.gd")
const AppReleaseInfoScript = preload("res://scripts/client/AppReleaseInfo.gd")
const DeckCatalogUtilsScript = preload("res://scripts/core/DeckCatalogUtils.gd")
const LocalProfileStoreScript = preload("res://scripts/core/LocalProfileStore.gd")
const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const PracticeAutofillDeckFactoryScript = preload("res://scripts/server/PracticeAutofillDeckFactory.gd")
const PracticeFuzzPlayerBotScript = preload("res://scripts/bots/PracticeFuzzPlayerBot.gd")
const BotGameInputScript = preload("res://scripts/bots/BotGameInput.gd")
const MatchHistoryStoreScript = preload("res://scripts/server/MatchHistoryStore.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const LobbyRoomScript = preload("res://scripts/server/LobbyRoom.gd")
const STARTUP_SPLASH_IMAGE_PATH := "res://images/ui/splash/other_gods_splash.png"
const STARTUP_MUSIC_PATH := "res://audio/relaxingtime-relaxing-music-119247.mp3"
const USER_SETTINGS_PATH := "user://settings.cfg"
const AUDIO_SETTINGS_SECTION := "audio"
const MUSIC_MUTED_KEY := "music_muted"
const PRACTICE_THOR_SCENE_PATH := "res://scenes/practice_thor_game.tscn"
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
const STARTUP_MENU_FADE_SECONDS := 3.0

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
var _smoke_finished: bool = false
var lobby_server: LobbyServer = null
var lobby_client: LobbyClient = null
var _current_room_snapshot: Dictionary = {}
var _open_seek_rooms: Array[Dictionary] = []
var _lobby_session_id: String = ""
var _lobby_reconnect_token: String = ""
var _pending_join_room_code: String = ""
var _pending_join_room_id: String = ""
var _pending_observe_room_id: String = ""
var _pending_rematch_room_id: String = ""
var _pending_rematch_ready_submitted: bool = false
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
var _auth_onboarding_selected_mode: String = AUTH_MODE_LOGIN
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
var _selected_auth_mode: String = AUTH_MODE_LOGIN
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
var _automatic_update_required: bool = false
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
var _friends_button: Button = null
var _friends_overlay: Control = null
var _friends_state: Dictionary = {}
var _friends_status_label: Label = null
var _friends_username_edit: LineEdit = null
var _friends_content_list: VBoxContainer = null
var _friends_send_deck_dialog: ConfirmationDialog = null
var _friends_send_deck_option: OptionButton = null
var _friends_pending_send_username: String = ""
var _close_confirm_overlay: Control = null
var _startup_splash_background: TextureRect = null
var _startup_music_player: AudioStreamPlayer = null
var _music_mute_button: Button = null
var _music_muted: bool = false
var _startup_menu_fade_started: bool = false

func _ready() -> void:
	if _is_server_runtime_launch():
		return
	add_to_group("music_controls")
	_load_audio_preferences()
	_ensure_startup_splash_background()
	_ensure_startup_music()
	_prepare_startup_menu_fade()
	_fit_to_viewport()
	_build_server_version_overlay()
	_build_music_mute_button()
	get_viewport().size_changed.connect(_fit_to_viewport)
	if ip_line_edit != null:
		ip_line_edit.visible = true
		ip_line_edit.text = _get_project_default_lobby_host()
		ip_line_edit.placeholder_text = "Dedicated lobby IP or hostname"

	_ensure_practice_thor_entry()
	_hide_embedded_games()
	_bind_game_signals()

	var deck_btn = $MenuContainer/DeckBuilderButton
	var rules_btn = $MenuContainer/RulesButton
	var card_test_btn = $MenuContainer/CardTestButton

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
	_build_friends_controls()
	_build_resume_controls()
	_build_unranked_seek_controls()
	_refresh_multiplayer_deck_options()
	_refresh_seek_list()
	_refresh_multiplayer_action_state()
	_restore_saved_resume_state()
	_smoke_config = _parse_smoke_config(OS.get_cmdline_user_args())
	show_menu()
	if not _smoke_config.is_empty():
		if menu_container != null:
			menu_container.modulate.a = 1.0
		call_deferred("_start_smoke_mode")
	else:
		_begin_startup_menu_fade()
		call_deferred("_begin_startup_prompts")

func _ensure_startup_splash_background() -> void:
	if _startup_splash_background != null and is_instance_valid(_startup_splash_background):
		return
	var splash_texture := _load_startup_splash_texture()
	if splash_texture == null:
		return
	var background := TextureRect.new()
	background.name = "StartupSplashBackground"
	background.texture = splash_texture
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	move_child(background, 0)
	_startup_splash_background = background

func _ensure_startup_music() -> void:
	if _startup_music_player != null and is_instance_valid(_startup_music_player):
		if not _music_muted and not _startup_music_player.playing:
			_startup_music_player.play()
		_apply_music_mute_state()
		return
	var player := AudioStreamPlayer.new()
	player.name = "StartupMusicPlayer"
	var music_stream := _load_startup_music_stream()
	if music_stream == null:
		return
	player.stream = music_stream
	player.autoplay = false
	add_child(player)
	_startup_music_player = player
	_apply_music_mute_state()

func _load_startup_splash_texture() -> Texture2D:
	if ResourceLoader.exists(STARTUP_SPLASH_IMAGE_PATH):
		var imported_resource := load(STARTUP_SPLASH_IMAGE_PATH)
		if imported_resource is Texture2D:
			return imported_resource as Texture2D
	var image := Image.new()
	var error := image.load(STARTUP_SPLASH_IMAGE_PATH)
	if error != OK:
		push_warning("Could not load startup splash image: %s" % STARTUP_SPLASH_IMAGE_PATH)
		return null
	return ImageTexture.create_from_image(image)

func _load_startup_music_stream() -> AudioStream:
	if ResourceLoader.exists(STARTUP_MUSIC_PATH):
		var imported_resource := load(STARTUP_MUSIC_PATH)
		if imported_resource is AudioStream:
			var imported_stream := (imported_resource as AudioStream).duplicate()
			if imported_stream is AudioStreamMP3:
				(imported_stream as AudioStreamMP3).loop = true
			return imported_stream
	if not FileAccess.file_exists(STARTUP_MUSIC_PATH):
		push_warning("Could not find startup music: %s" % STARTUP_MUSIC_PATH)
		return null
	var bytes := FileAccess.get_file_as_bytes(STARTUP_MUSIC_PATH)
	if bytes.is_empty():
		push_warning("Could not read startup music: %s" % STARTUP_MUSIC_PATH)
		return null
	var stream := AudioStreamMP3.new()
	stream.data = bytes
	stream.loop = true
	return stream

func _load_audio_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(USER_SETTINGS_PATH) != OK:
		_music_muted = false
		return
	_music_muted = bool(config.get_value(AUDIO_SETTINGS_SECTION, MUSIC_MUTED_KEY, false))

func _save_audio_preferences() -> void:
	var config := ConfigFile.new()
	config.load(USER_SETTINGS_PATH)
	config.set_value(AUDIO_SETTINGS_SECTION, MUSIC_MUTED_KEY, _music_muted)
	var error := config.save(USER_SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save audio settings: %s" % str(error))

func is_music_muted() -> bool:
	return _music_muted

func set_music_muted(muted: bool) -> void:
	if _music_muted == muted:
		_apply_music_mute_state()
		return
	_music_muted = muted
	_apply_music_mute_state()
	_save_audio_preferences()

func toggle_music_mute() -> void:
	set_music_muted(not _music_muted)

func _apply_music_mute_state() -> void:
	if _startup_music_player != null and is_instance_valid(_startup_music_player):
		if _music_muted:
			_startup_music_player.stream_paused = true
		else:
			if not _startup_music_player.playing:
				_startup_music_player.play()
			_startup_music_player.stream_paused = false
	_refresh_music_mute_button()
	if is_inside_tree():
		get_tree().call_group("music_mute_observers", "_on_music_mute_changed", _music_muted)

func _build_music_mute_button() -> void:
	if _music_mute_button != null and is_instance_valid(_music_mute_button):
		_refresh_music_mute_button()
		return
	var button := Button.new()
	button.name = "MusicMuteButton"
	button.tooltip_text = "Toggle background music."
	button.custom_minimum_size = Vector2(146.0, 28.0)
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -266.0
	button.offset_top = -60.0
	button.offset_right = -120.0
	button.offset_bottom = -32.0
	button.z_index = 2100
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(toggle_music_mute)
	add_child(button)
	_music_mute_button = button
	_refresh_music_mute_button()

func _refresh_music_mute_button() -> void:
	if _music_mute_button == null or not is_instance_valid(_music_mute_button):
		return
	_music_mute_button.text = "Music Muted" if _music_muted else "Mute Music"
	_music_mute_button.modulate = Color(0.78, 0.86, 0.92, 0.96) if _music_muted else Color(1, 1, 1, 0.96)

func _prepare_startup_menu_fade() -> void:
	if menu_container == null:
		return
	menu_container.modulate.a = 0.0

func _begin_startup_menu_fade() -> void:
	if _startup_menu_fade_started or menu_container == null:
		return
	_startup_menu_fade_started = true
	menu_container.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(menu_container, "modulate:a", 1.0, STARTUP_MENU_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _is_practice_thor_enabled() -> bool:
	return true

func _bind_game_signals() -> void:
	for node_name in _get_embedded_game_node_names():
		var game = get_node_or_null("GameContainer/" + node_name)
		if game != null and game.has_signal("forfeit_requested"):
			var callback := Callable(self, "_on_game_forfeit_requested")
			if not game.forfeit_requested.is_connected(callback):
				game.forfeit_requested.connect(callback)
		if game != null and game.has_signal("return_to_menu_requested"):
			var return_callback := Callable(self, "_on_game_return_to_menu_requested")
			if not game.return_to_menu_requested.is_connected(return_callback):
				game.return_to_menu_requested.connect(return_callback)
		if game != null and game.has_signal("leave_match_requested"):
			var leave_callback := Callable(self, "_on_game_leave_match_requested")
			if not game.leave_match_requested.is_connected(leave_callback):
				game.leave_match_requested.connect(leave_callback)
		if game != null and game.has_signal("rematch_requested"):
			var rematch_callback := Callable(self, "_on_game_rematch_requested")
			if not game.rematch_requested.is_connected(rematch_callback):
				game.rematch_requested.connect(rematch_callback)
		if game != null and game.has_signal("match_session_cleared"):
			var clear_callback := Callable(self, "_on_match_session_cleared")
			if not game.match_session_cleared.is_connected(clear_callback):
				game.match_session_cleared.connect(clear_callback)

func _ensure_practice_thor_entry() -> void:
	if game_container == null or menu_container == null:
		return
	var practice_button = menu_container.get_node_or_null("PracticeThorButton")
	if not _is_practice_thor_enabled():
		if practice_button != null:
			practice_button.visible = false
		return
	var practice_game = game_container.get_node_or_null("PracticeThor")
	if practice_game == null:
		var practice_scene := load(PRACTICE_THOR_SCENE_PATH)
		var practice_instance = practice_scene.instantiate() if practice_scene is PackedScene else null
		if practice_instance != null:
			practice_instance.name = "PracticeThor"
			if practice_instance is Control:
				practice_instance.visible = false
			game_container.add_child(practice_instance)
			practice_game = practice_instance
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
	var node_names: Array[String] = ["MockGame", "CardTest"]
	if _is_practice_thor_enabled():
		node_names.append("PracticeThor")
	return node_names

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
	label.tooltip_text = "Versions for the connected lobby server and this client."
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -260.0
	label.offset_top = 10.0
	label.offset_right = -14.0
	label.offset_bottom = 52.0
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
	var server_text := ""
	if _connected_server_version.is_empty():
		if _has_connected_lobby_transport():
			server_text = "Server: version unavailable"
		else:
			server_text = "Server: not connected"
	else:
		server_text = "Server: %s" % _connected_server_version
	var client_version := AppReleaseInfoScript.get_current_version()
	_server_version_label.text = "%s\nClient: %s" % [server_text, client_version]

func _is_deck_builder_open() -> bool:
	if game_container == null:
		return false
	var deck_builder := game_container.get_node_or_null("DeckBuilder")
	return (
		deck_builder != null
		and is_instance_valid(deck_builder)
		and not deck_builder.is_queued_for_deletion()
		and bool(deck_builder.visible)
	)

func _refresh_server_version_overlay_visibility() -> void:
	if _server_version_label == null or not is_instance_valid(_server_version_label):
		return
	var multiplayer_visible = multiplayer_container != null and multiplayer_container.visible
	var game_visible = game_container != null and game_container.visible
	_server_version_label.visible = (
		menu_container != null
		and menu_container.visible
		and not multiplayer_visible
		and not game_visible
		and not _is_deck_builder_open()
	)

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
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			if _deck_picker_popup != null and is_instance_valid(_deck_picker_popup) and _deck_picker_popup.visible:
				_hide_multiplayer_deck_popup()
				get_viewport().set_input_as_handled()
				return
			if _handle_escape_navigation():
				get_viewport().set_input_as_handled()
				return
	if _deck_picker_popup == null or not is_instance_valid(_deck_picker_popup) or not _deck_picker_popup.visible:
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

func _handle_escape_navigation() -> bool:
	if _close_confirm_overlay != null and is_instance_valid(_close_confirm_overlay):
		_close_program()
		return true
	if _rules_overlay != null and is_instance_valid(_rules_overlay):
		_close_rules_overlay()
		show_menu()
		return true
	if _friends_overlay != null and is_instance_valid(_friends_overlay):
		_close_friends_overlay()
		show_menu()
		return true
	if _is_deck_builder_open():
		_return_to_menu()
		return true
	if menu_container != null and menu_container.visible and multiplayer_container != null and not multiplayer_container.visible:
		_open_close_confirm_overlay()
		return true
	return false

func _open_close_confirm_overlay() -> void:
	if _close_confirm_overlay != null and is_instance_valid(_close_confirm_overlay):
		return
	_close_confirm_overlay = Control.new()
	_close_confirm_overlay.name = "CloseConfirmOverlay"
	_close_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_close_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_close_confirm_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_confirm_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(360, 0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.position = Vector2(-180, -110)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	panel_style.border_color = Color(0.88, 0.44, 0.40, 0.95)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		panel_style.set_border_width(side as Side, 2)
	panel.add_theme_stylebox_override("panel", panel_style)
	_close_confirm_overlay.add_child(panel)

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
	title.text = "Close Other Gods?"
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)

	var body := Label.new()
	body.text = "Press Escape again or click Close to exit the program."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.modulate = Color(0.82, 0.87, 0.95)
	content.add_child(body)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(110, 38)
	cancel_btn.pressed.connect(_close_close_confirm_overlay)
	actions.add_child(cancel_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(110, 38)
	close_btn.pressed.connect(_close_program)
	actions.add_child(close_btn)

	cancel_btn.grab_focus()

func _close_close_confirm_overlay() -> void:
	if _close_confirm_overlay == null:
		return
	if is_instance_valid(_close_confirm_overlay):
		_close_confirm_overlay.queue_free()
	_close_confirm_overlay = null

func _close_program() -> void:
	_close_close_confirm_overlay()
	get_tree().quit()

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
	status_label.text = "Refresh seeks to join a room or watch a live match."
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
	_pending_observe_room_id = ""
	_pending_local_lobby_launch_on_connect_failure = false
	_connect_to_browseable_lobby("Connecting to lobby...")

func _has_active_lobby_connection() -> bool:
	return lobby_client != null and is_instance_valid(lobby_client) and lobby_client.is_authenticated()

func _has_connected_lobby_transport() -> bool:
	return lobby_client != null and is_instance_valid(lobby_client) and lobby_client.is_transport_connected()

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
		AUTH_MODE_LOGIN
	)
	if desired_auth_mode not in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return false
	var desired_username := _get_preferred_account_username().strip_edges().to_lower()
	var connected_username := _get_connected_account_username().strip_edges().to_lower()
	return not desired_username.is_empty() \
		and connected_auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER] \
		and connected_username == desired_username

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
		seek_list.add_item("No open seeks or live matches right now.")
		seek_list.set_item_disabled(0, true)
		return
	for room in _open_seek_rooms:
		var room_id := str(room.get("room_id", "")).strip_edges()
		var host_name := str(room.get("host_name", "Host")).strip_edges()
		var member_count := int(room.get("member_count", 0))
		var max_players := int(room.get("max_players", 2))
		var room_status := str(room.get("status", "waiting")).strip_edges().to_lower()
		var status := "Live" if room_status == LobbyRoomScript.STATUS_IN_MATCH else room_status.capitalize()
		var rank_tag := "" if bool(room.get("is_ranked", true)) else "[Unranked]  "
		var action_hint := "  Click to Observe" if room_status == LobbyRoomScript.STATUS_IN_MATCH else "  Click to Join"
		seek_list.add_item("%s%s  %d/%d  %s%s" % [rank_tag, host_name, member_count, max_players, status, action_hint])
		seek_list.set_item_metadata(seek_list.get_item_count() - 1, room.duplicate(true))

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
		status_label.text = "Refreshing seeks and live matches..."
	lobby_client.list_rooms()

func _on_seek_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if seek_list == null or index < 0 or index >= seek_list.get_item_count():
		return
	if seek_list.is_item_disabled(index):
		return
	if not _current_room_snapshot.is_empty():
		status_label.text = "Leave your current seek before joining another."
		return
	var room_entry = seek_list.get_item_metadata(index)
	if not (room_entry is Dictionary):
		return
	var room_data := room_entry as Dictionary
	var room_status := str(room_data.get("status", "")).strip_edges().to_lower()
	var room_id := str(room_data.get("room_id", "")).strip_edges()
	if room_id.is_empty():
		return
	if room_status == LobbyRoomScript.STATUS_IN_MATCH:
		_on_observe_match_requested(room_id)
		return
	if _get_selected_multiplayer_deck().is_empty():
		status_label.text = "Choose a saved legal deck before joining a seek."
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
	_pending_observe_room_id = ""
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
	_pending_observe_room_id = ""
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
	_pending_observe_room_id = ""
	_pending_local_lobby_launch_on_connect_failure = false
	multiplayer_container.visible = true
	_connect_to_browseable_lobby("Connecting to lobby...")

func _on_observe_match_requested(room_id: String) -> void:
	var target_error := _validate_multiplayer_target()
	if not target_error.is_empty():
		status_label.text = target_error
		return
	var auth_error := _validate_auth_inputs()
	if not auth_error.is_empty():
		status_label.text = auth_error
		return
	if not _current_room_snapshot.is_empty():
		status_label.text = "Leave your current seek before observing another match."
		return
	_pending_host_room_creation = false
	_pending_join_room_id = ""
	_pending_observe_room_id = room_id.strip_edges().to_upper()
	_pending_local_lobby_launch_on_connect_failure = false
	room_code_line_edit.text = room_id.strip_edges().to_upper()
	multiplayer_container.visible = true
	_connect_to_browseable_lobby("Connecting to live match...")

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
		_get_lobby_login_name("Player"),
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
	_pending_observe_room_id = ""
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
	if not _pending_observe_room_id.is_empty():
		var observe_room_id := _pending_observe_room_id
		_pending_observe_room_id = ""
		status_label.text = "Observing match %s..." % observe_room_id
		lobby_client.observe_room(observe_room_id)
		return
	_queue_room_list_refresh()

func _is_local_lobby_target(host: String) -> bool:
	var normalized_host := host.strip_edges().to_lower()
	return normalized_host.is_empty() or normalized_host == "127.0.0.1" or normalized_host == "localhost"

func _clear_current_seek_state() -> void:
	_current_room_snapshot.clear()
	_pending_rematch_ready_submitted = false
	ready_button.visible = false
	leave_seek_button.visible = false
	_last_submitted_lobby_room_id = ""
	_last_submitted_lobby_deck_id = ""
	_last_submitted_lobby_deck_hash = ""
	status_label.text = "Refresh seeks to join a room or watch a live match."
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
	var windows_asset_names := AppReleaseInfoScript.WINDOWS_ASSET_NAMES
	for asset_name in windows_asset_names:
		for asset in assets:
			if str(asset.get("name", "")) != asset_name:
				continue
			download_url = str(asset.get("browser_download_url", "")).strip_edges()
			break
		if not download_url.is_empty():
			break
	_begin_required_update(latest_version, release_url, download_url)

func _should_prompt_for_update(latest_version: String) -> bool:
	if not AppReleaseInfoScript.is_release_version(latest_version):
		return false
	var current_version := AppReleaseInfoScript.get_current_version()
	if AppReleaseInfoScript.compare_versions(current_version, latest_version) >= 0:
		return false
	if _local_profile_store != null:
		var dismissed_version: String = str(_local_profile_store.get_dismissed_release_version()).strip_edges()
		if not dismissed_version.is_empty():
			# "Later" is only meant to dismiss the prompt for the current session.
			# Clear any persisted dismissal so the update is offered again on next open.
			_local_profile_store.remember_dismissed_release_version("")
	return true

func _begin_required_update(latest_version: String, release_url: String, download_url: String = "") -> void:
	if not download_url.is_empty() and OS.get_name() == "Windows":
		_show_update_prompt(latest_version, release_url, download_url, true)
		call_deferred("_on_update_prompt_auto_update_pressed")
		return
	var open_error := OS.shell_open(release_url)
	if open_error == OK:
		status_label.text = "Opened the latest release page for %s." % latest_version
	else:
		status_label.text = "Update %s is available, but the release page could not be opened automatically." % latest_version
	_complete_startup_prompts()

func _show_update_prompt(latest_version: String, release_url: String, download_url: String = "", auto_update: bool = false) -> void:
	if _update_prompt_overlay != null and is_instance_valid(_update_prompt_overlay):
		return
	_pending_update_release_version = latest_version
	_pending_update_release_url = release_url
	_pending_update_download_url = download_url
	_automatic_update_required = auto_update

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
	title.text = "Updating Other Gods" if auto_update else "Update Available"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var current_version := AppReleaseInfoScript.get_current_version()
	var body_label := Label.new()
	if auto_update:
		body_label.text = "You're running %s. Installing %s now." % [current_version, latest_version]
	else:
		body_label.text = "You're running %s, and the latest release is %s." % [current_version, latest_version]
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(body_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 8)
	content.add_child(button_row)

	if not auto_update:
		var later_button := Button.new()
		later_button.text = "Later"
		later_button.custom_minimum_size = Vector2(110, 38)
		later_button.pressed.connect(_on_update_prompt_later_pressed)
		button_row.add_child(later_button)

	var update_button := Button.new()
	update_button.text = "Open Download Page"
	update_button.custom_minimum_size = Vector2(180, 38)
	update_button.pressed.connect(_on_update_prompt_open_pressed)
	if not auto_update:
		button_row.add_child(update_button)

	if not download_url.is_empty() and OS.get_name() == "Windows":
		if not auto_update:
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

		if not auto_update and _update_now_button != null:
			_update_now_button.grab_focus()
	elif not auto_update:
		update_button.grab_focus()
	if auto_update:
		button_row.visible = false

func _dismiss_update_prompt() -> void:
	if _update_download_request != null and is_instance_valid(_update_download_request):
		_update_download_request.cancel_request()
		_update_download_request.queue_free()
	_update_download_request = null
	_is_auto_updating = false
	_update_now_button = null
	_update_download_status_label = null
	_pending_update_download_url = ""
	_automatic_update_required = false
	if _update_prompt_overlay != null and is_instance_valid(_update_prompt_overlay):
		_update_prompt_overlay.queue_free()
	_update_prompt_overlay = null
	_pending_update_release_version = ""
	_pending_update_release_url = AppReleaseInfoScript.RELEASES_PAGE_URL

func _on_update_prompt_later_pressed() -> void:
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
	extracted_files = _flatten_staged_update_archive(staging_root, extracted_files)
	if extracted_files.is_empty():
		_clear_update_staging_root(staging_root)
		_on_auto_update_failed("The downloaded update archive had an unexpected layout.")
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
	if _automatic_update_required:
		if _update_download_status_label != null and is_instance_valid(_update_download_status_label):
			_update_download_status_label.text = "%s Opening the release page..." % message
		OS.shell_open(_pending_update_release_url)
		_dismiss_update_prompt()
		_complete_startup_prompts()
		return
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

func _flatten_staged_update_archive(staging_root: String, extracted_files: Array[String]) -> Array[String]:
	if extracted_files.is_empty():
		return extracted_files
	var top_level_dirs := {}
	for relative_path in extracted_files:
		var normalized_path := relative_path.replace("\\", "/").strip_edges()
		if normalized_path.is_empty():
			continue
		var slash_index := normalized_path.find("/")
		if slash_index <= 0:
			return extracted_files
		top_level_dirs[normalized_path.substr(0, slash_index)] = true
	if top_level_dirs.size() != 1:
		return extracted_files
	var top_level_dir := String(top_level_dirs.keys()[0])
	if top_level_dir.is_empty():
		return extracted_files

	var flattened_files: Array[String] = []
	for relative_path in extracted_files:
		var normalized_path := relative_path.replace("\\", "/")
		var prefix := "%s/" % top_level_dir
		if not normalized_path.begins_with(prefix):
			return []
		var flattened_relative := normalized_path.trim_prefix(prefix)
		if flattened_relative.is_empty():
			continue
		var source_path := staging_root.path_join(normalized_path)
		var destination_path := staging_root.path_join(flattened_relative)
		if DirAccess.make_dir_recursive_absolute(destination_path.get_base_dir()) != OK:
			return []
		if DirAccess.rename_absolute(source_path, destination_path) != OK:
			return []
		flattened_files.append(flattened_relative)

	var wrapped_root_path := staging_root.path_join(top_level_dir)
	if DirAccess.dir_exists_absolute(wrapped_root_path):
		if not _clear_update_staging_root(wrapped_root_path):
			return []
	return flattened_files

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

func _normalize_auth_mode(auth_mode: String, fallback_mode: String = AUTH_MODE_LOGIN) -> String:
	var resolved_auth_mode := auth_mode.strip_edges().to_lower()
	match resolved_auth_mode:
		AUTH_MODE_GUEST, LobbyProtocolScript.LOGIN_GUEST:
			return fallback_mode
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
	if sync_field and player_name_line_edit != null:
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
	if player_name_line_edit != null:
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

func _get_effective_identity_name(default_name: String = "Player") -> String:
	var account_username := _get_effective_account_username()
	if not account_username.is_empty():
		return account_username
	var fallback_name := default_name.strip_edges()
	if fallback_name.is_empty():
		fallback_name = "Player"
	if _get_selected_auth_mode() in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		var selected_account_username := _get_selected_account_username()
		if not selected_account_username.is_empty():
			return selected_account_username
	return fallback_name

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
	_auth_onboarding_selected_mode = AUTH_MODE_LOGIN
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
	_auth_onboarding_username_edit.text_changed.connect(func(_new_text: String) -> void:
		_refresh_auth_onboarding_form_state()
	)
	_auth_onboarding_username_edit.text_submitted.connect(func(_text: String) -> void:
		_submit_auth_onboarding()
	)
	inner.add_child(_auth_onboarding_username_edit)

	_auth_onboarding_password_edit = LineEdit.new()
	_auth_onboarding_password_edit.placeholder_text = "Account password"
	_auth_onboarding_password_edit.secret = true
	_auth_onboarding_password_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auth_onboarding_password_edit.visible = false
	_auth_onboarding_password_edit.text_changed.connect(func(_new_text: String) -> void:
		_refresh_auth_onboarding_form_state()
	)
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
	_begin_auth_onboarding_account_flow(launch_auth_mode)
	_refresh_auth_onboarding_form_state()

func _begin_auth_onboarding_account_flow(auth_mode: String) -> void:
	if auth_mode not in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		auth_mode = AUTH_MODE_LOGIN
	_auth_onboarding_selected_mode = auth_mode
	if auth_mode == AUTH_MODE_REGISTER:
		_set_auth_onboarding_hint("New account passwords must be at least %d characters." % _get_account_min_password_length())
	else:
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
	_refresh_auth_onboarding_form_state()
	if _auth_onboarding_username_edit != null and _auth_onboarding_username_edit.text.strip_edges().is_empty():
		_auth_onboarding_username_edit.grab_focus()
	elif _auth_onboarding_password_edit != null:
		_auth_onboarding_password_edit.grab_focus()

func _submit_auth_onboarding() -> bool:
	var auth_mode := _auth_onboarding_selected_mode
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
	var credential_error := _validate_account_auth_details(auth_mode, username, password)
	if not credential_error.is_empty():
		_set_auth_onboarding_hint(credential_error, true)
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
		return AUTH_MODE_LOGIN
	var preferred_auth_mode: String = _local_profile_store.get_preferred_auth_mode()
	if preferred_auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return preferred_auth_mode
	var saved_username: String = _get_saved_account_username()
	if not saved_username.is_empty():
		return AUTH_MODE_LOGIN
	return AUTH_MODE_LOGIN

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
	_set_auth_onboarding_hint(message, true)

func _set_auth_onboarding_hint(message: String, is_error: bool = false) -> void:
	if _auth_onboarding_mode_hint_label == null:
		return
	_auth_onboarding_mode_hint_label.visible = not message.is_empty()
	_auth_onboarding_mode_hint_label.text = message
	_auth_onboarding_mode_hint_label.modulate = Color(1.0, 0.72, 0.72) if is_error else Color(0.76, 0.80, 0.92)

func _refresh_auth_onboarding_form_state() -> void:
	var auth_mode := _auth_onboarding_selected_mode
	var min_password_length := _get_account_min_password_length()
	if _auth_onboarding_password_edit != null:
		_auth_onboarding_password_edit.placeholder_text = "Account password (min %d characters)" % min_password_length if auth_mode == AUTH_MODE_REGISTER else "Account password"
	if _auth_onboarding_continue_button == null:
		return
	if auth_mode not in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		_auth_onboarding_continue_button.disabled = true
		return
	var username := _auth_onboarding_username_edit.text.strip_edges() if _auth_onboarding_username_edit != null else ""
	var password := _auth_onboarding_password_edit.text if _auth_onboarding_password_edit != null else ""
	var can_submit := not username.is_empty() and not password.is_empty()
	if auth_mode == AUTH_MODE_REGISTER:
		can_submit = can_submit and password.strip_edges().length() >= min_password_length
		if not can_submit and not username.is_empty() and not password.is_empty():
			_set_auth_onboarding_hint("Passwords for new accounts must be at least %d characters." % min_password_length, true)
		elif _auth_onboarding_mode_hint_label != null and _auth_onboarding_mode_hint_label.visible \
				and str(_auth_onboarding_mode_hint_label.text).begins_with("Passwords for new accounts must be at least "):
			_set_auth_onboarding_hint("")
	_auth_onboarding_continue_button.disabled = not can_submit

func _get_account_min_password_length() -> int:
	return int(AccountStoreScript.MIN_PASSWORD_LENGTH)

func _validate_account_auth_details(auth_mode: String, username: String, password: String) -> String:
	if auth_mode != AUTH_MODE_REGISTER:
		return ""
	var min_password_length := _get_account_min_password_length()
	if password.strip_edges().length() < min_password_length:
		return "Passwords for new accounts must be at least %d characters." % min_password_length
	return ""

func _complete_auth_onboarding(auth_mode: String, message: String) -> void:
	_set_auth_mode(auth_mode)
	var selected_account_username := _get_selected_account_username()
	if not selected_account_username.is_empty():
		_activate_account_profile(selected_account_username, "", auth_mode, true)
	multiplayer_container.visible = false
	ready_button.visible = false
	status_label.text = message
	show_menu()
	_refresh_open_deck_builder_saved_decks()
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
	if db.has_method("configure_friends"):
		db.configure_friends(_get_friend_usernames())
	if db.has_signal("account_deck_deleted_locally") and not db.account_deck_deleted_locally.is_connected(_on_deck_builder_account_deck_deleted_locally):
		db.account_deck_deleted_locally.connect(_on_deck_builder_account_deck_deleted_locally)
	if db.has_signal("send_deck_to_friend_requested") and not db.send_deck_to_friend_requested.is_connected(_on_deck_builder_send_deck_to_friend_requested):
		db.send_deck_to_friend_requested.connect(_on_deck_builder_send_deck_to_friend_requested)
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

func _on_card_test_pressed() -> void:
	_match_launch_queued = false
	_cleanup_lobby(true)
	_show_embedded_game("CardTest")
	show_game()
	var card_test: CardTestGame = get_node("GameContainer/CardTest")
	await card_test.start_game()

func _on_practice_thor_pressed() -> void:
	if not _is_practice_thor_enabled():
		return
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
		_get_lobby_login_name("Player"),
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
	if lobby_client.has_signal("friends_state_received") and not lobby_client.friends_state_received.is_connected(_on_friends_state_received):
		lobby_client.friends_state_received.connect(_on_friends_state_received)
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
	_request_friends_state()
	var resolved_identity_name := _get_effective_identity_name(player_name)
	player_name_line_edit.text = resolved_identity_name
	_refresh_open_deck_builder_saved_decks()
	_update_resume_controls()
	var active_match_info: Dictionary = {}
	if lobby_client != null:
		active_match_info = lobby_client.current_active_match_info.duplicate(true)
	if not active_match_info.is_empty():
		if _has_pending_new_seek_action():
			_abandon_current_lobby_match()
			_clear_saved_match_resume()
		elif not _should_suppress_active_match_auto_resume(active_match_info):
			_save_active_match_resume(active_match_info)
			status_label.text = "Signed in as %s. Rejoining your active match..." % resolved_identity_name
			call_deferred("_resume_active_match_from_lobby", active_match_info)
			return
		else:
			_abandon_current_lobby_match()
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
	_request_friends_state()
	var resolved_identity_name := _get_effective_identity_name(player_name)
	player_name_line_edit.text = resolved_identity_name
	_refresh_open_deck_builder_saved_decks()
	_update_resume_controls()
	if not active_match_info.is_empty():
		if _has_pending_new_seek_action():
			_abandon_current_lobby_match()
			_clear_saved_match_resume()
		elif not _should_suppress_active_match_auto_resume(active_match_info):
			_save_active_match_resume(active_match_info)
			status_label.text = "Lobby session restored. Rejoining your active match..."
			call_deferred("_resume_active_match_from_lobby", active_match_info)
			return
		else:
			_abandon_current_lobby_match()
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
		var room_status := str(entry.get("status", "")).strip_edges().to_lower()
		if room_status != LobbyRoomScript.STATUS_IN_MATCH and int(entry.get("member_count", 0)) >= int(entry.get("max_players", 2)):
			continue
		_open_seek_rooms.append(entry)
	if not current_room_id.is_empty() and not current_room_still_visible:
		_clear_current_seek_state()
	_refresh_seek_list()
	if _current_room_snapshot.is_empty():
		if _open_seek_rooms.is_empty():
			status_label.text = "No open seeks or live matches right now. Create one to start a match."
		else:
			status_label.text = "Click a seek to join, or click a Live room to observe."
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
			if room_id == _pending_rematch_room_id and _should_suppress_active_match_auto_resume(active_match_info):
				status_label.text = "Waiting for the finished match to close so the rematch can start..."
				return
			if _has_pending_new_seek_action() or _should_suppress_active_match_auto_resume(active_match_info):
				_abandon_current_lobby_match()
				_clear_saved_match_resume()
				return
			_save_active_match_resume(active_match_info)
			call_deferred("_resume_active_match_from_lobby", active_match_info)
			return
	_write_smoke_trace("room_snapshot room=%s members=%d" % [room_id, snapshot.get("members", []).size()])
	room_code_line_edit.text = room_id
	_write_smoke_room_code(room_id)
	_maybe_submit_current_profile_deck(room_id, snapshot)
	_maybe_submit_rematch_ready(room_id, snapshot)
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

func _maybe_submit_rematch_ready(room_id: String, snapshot: Dictionary) -> void:
	if _pending_rematch_room_id.is_empty():
		return
	if room_id != _pending_rematch_room_id:
		return
	if lobby_client == null:
		return
	var room_status := str(snapshot.get("status", "")).strip_edges().to_lower()
	if room_status == LobbyRoomScript.STATUS_IN_MATCH:
		return
	var local_member := _get_room_member_snapshot(snapshot, _lobby_session_id)
	if local_member.is_empty():
		return
	if bool(local_member.get("is_ready", false)):
		_pending_rematch_ready_submitted = false
		status_label.text = "Rematch offered. Waiting for your opponent to accept."
		return
	if not bool(local_member.get("has_valid_deck", false)):
		_pending_rematch_ready_submitted = false
		status_label.text = "Choose a valid deck to offer the rematch."
		return
	if _pending_rematch_ready_submitted:
		return
	_pending_rematch_ready_submitted = true
	status_label.text = "Offering rematch..."
	lobby_client.set_ready(true)

func _get_room_member_snapshot(snapshot: Dictionary, session_id: String) -> Dictionary:
	if session_id.is_empty():
		return {}
	for member in snapshot.get("members", []):
		if str(member.get("session_id", "")) == session_id and member is Dictionary:
			return (member as Dictionary).duplicate(true)
	return {}

func _on_local_match_assigned(match_info: Dictionary) -> void:
	if _match_launch_queued:
		return
	_pending_rematch_room_id = ""
	_pending_rematch_ready_submitted = false
	_match_launch_queued = true
	_save_active_match_resume(match_info)
	_write_smoke_trace("local_match_assigned match=%s" % str(match_info.get("match_id", "")))
	status_label.text = "Both players joined. Preparing the match server..."
	_write_smoke_result("MATCH_ASSIGNED_HOST:%s" % str(match_info))
	call_deferred("_launch_host_match_after_lobby_handoff", match_info)

func _on_remote_match_assigned(match_info: Dictionary) -> void:
	if _match_launch_queued:
		return
	_pending_rematch_room_id = ""
	_pending_rematch_ready_submitted = false
	_match_launch_queued = true
	_save_active_match_resume(match_info)
	_write_smoke_trace("remote_match_assigned match=%s" % str(match_info.get("match_id", "")))
	var match_ip := str(match_info.get("server_ip", _current_lobby_ip))
	var match_port := int(match_info.get("match_port", _get_configured_match_port()))
	status_label.text = (
		"Live match found. Connecting to %s..." % match_ip
		if bool(match_info.get("observer_mode", false))
		else "Match found. Connecting to %s..." % match_ip
	)
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
	_set_friends_status(message)
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
	if _should_ignore_lobby_failure_for_smoke():
		return
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
	status_label.text = "Lobby connection lost. Refresh seeks to reconnect."
	if _should_ignore_lobby_failure_for_smoke():
		return
	_fail_smoke_if_enabled("DISCONNECTED_FROM_LOBBY")

func _on_back_to_menu_pressed() -> void:
	_return_to_menu()

func _on_game_forfeit_requested() -> void:
	_return_to_menu()

func _on_game_leave_match_requested() -> void:
	_return_to_menu()

func _on_game_rematch_requested() -> void:
	var active_game = _get_active_embedded_game()
	var match_info: Dictionary = {}
	if active_game != null:
		var active_match_info = active_game.get("_current_match_info")
		if active_match_info is Dictionary:
			match_info = (active_match_info as Dictionary).duplicate(true)
	var room_id := str(match_info.get("room_id", "")).strip_edges()
	if room_id.is_empty():
		_return_to_menu()
		return
	_pending_rematch_room_id = room_id
	_pending_rematch_ready_submitted = false
	_return_to_lobby_for_rematch()

func _on_game_return_to_menu_requested() -> void:
	var active_game = _get_active_embedded_game()
	if active_game != null:
		var reconnect_waiting := bool(active_game.get("_match_reconnect_waiting"))
		var awaiting_initial_state := bool(active_game.get("_awaiting_initial_full_state"))
		var game_finished := bool(active_game.get("_game_finished"))
		var networked_client := bool(active_game.get("_is_networked_client"))
		if networked_client and not game_finished and (reconnect_waiting or awaiting_initial_state):
			return
	_return_to_menu()

func _return_to_lobby_for_rematch() -> void:
	_suppress_active_match_auto_resume_from_embedded_games()
	show_menu()
	_match_launch_queued = false
	_cleanup_lobby(false)
	for node_name in _get_embedded_game_node_names():
		var game = get_node_or_null("GameContainer/" + node_name)
		if game and game.has_method("cleanup"):
			game.cleanup()
	_clear_saved_match_resume()
	_refresh_server_version_overlay_visibility()
	multiplayer_container.visible = true
	status_label.text = "Reconnecting to lobby for rematch..."
	_maybe_connect_authenticated_lobby("Reconnecting to lobby for rematch...")

func _return_to_menu() -> void:
	_pending_rematch_room_id = ""
	_pending_rematch_ready_submitted = false
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

func _get_active_embedded_game() -> Node:
	for node_name in _get_embedded_game_node_names():
		var game = get_node_or_null("GameContainer/" + node_name)
		if game != null and bool(game.get("visible")):
			return game
	return null

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

func _has_pending_new_seek_action() -> bool:
	return _pending_host_room_creation or not _pending_join_room_id.is_empty() or not _pending_observe_room_id.is_empty()

func _abandon_current_lobby_match() -> void:
	if lobby_client == null:
		return
	if lobby_client.current_active_match_info.is_empty():
		return
	lobby_client.leave_room()
	lobby_client.current_active_match_info.clear()

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
		_pending_observe_room_id = ""
		_current_lobby_ip = ""
		_is_local_lobby_host = false
		room_code_line_edit.text = ""
		_clear_saved_lobby_resume()
		_clear_saved_match_resume()
		_current_profile_summary.clear()
		_account_decks_cache.clear()
		_friends_state.clear()
		_refresh_friends_button()
		_refresh_friends_overlay()
		_refresh_profile_summary_label()
		_refresh_account_identity_label()
		status_label.text = "Refresh seeks to join a room or watch a live match."
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
		resolved_auth_mode = AUTH_MODE_LOGIN
		if player_name_line_edit != null:
			player_name_line_edit.text = ""
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
	if deck_builder.has_method("configure_friends"):
		deck_builder.configure_friends(_get_friend_usernames())
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

func _build_friends_controls() -> void:
	if menu_container == null or _friends_button != null:
		return
	_friends_button = Button.new()
	_friends_button.name = "FriendsButton"
	_friends_button.text = "Friends"
	_friends_button.pressed.connect(_open_friends_overlay)
	menu_container.add_child(_friends_button)
	var insert_index := menu_container.get_children().find(multiplayer_button) + 1
	if insert_index <= 0:
		insert_index = menu_container.get_child_count()
	menu_container.move_child(_friends_button, insert_index)
	_refresh_friends_button()

func _refresh_friends_button() -> void:
	if _friends_button == null or not is_instance_valid(_friends_button):
		return
	var pending_count := _get_pending_friend_notification_count()
	_friends_button.text = "Friends (%d)" % pending_count if pending_count > 0 else "Friends"
	_friends_button.disabled = not _uses_server_account_storage()
	_friends_button.tooltip_text = "" if _uses_server_account_storage() else "Log into or create an account to use friends. Guest names are not searchable."

func _get_pending_friend_notification_count() -> int:
	var incoming_requests = _friends_state.get("incoming_requests", [])
	var incoming_deck_shares = _friends_state.get("incoming_deck_shares", [])
	var count := 0
	if incoming_requests is Array:
		count += (incoming_requests as Array).size()
	if incoming_deck_shares is Array:
		count += (incoming_deck_shares as Array).size()
	return count

func _open_friends_overlay() -> void:
	if not _uses_server_account_storage():
		status_label.text = "Log into or create an account before using friends. Guest names are not searchable."
		return
	if _friends_overlay != null and is_instance_valid(_friends_overlay):
		return
	_friends_overlay = Control.new()
	_friends_overlay.name = "FriendsOverlay"
	_friends_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_friends_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_friends_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_friends_overlay.add_child(shade)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 44)
	outer_margin.add_theme_constant_override("margin_right", 44)
	outer_margin.add_theme_constant_override("margin_top", 38)
	outer_margin.add_theme_constant_override("margin_bottom", 38)
	_friends_overlay.add_child(outer_margin)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	panel_style.border_color = Color(0.48, 0.64, 0.92, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		panel_style.set_border_width(side as Side, 2)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	outer_margin.add_child(panel)

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 16)
	inner_margin.add_theme_constant_override("margin_right", 16)
	inner_margin.add_theme_constant_override("margin_top", 16)
	inner_margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(inner_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	inner_margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	var title := Label.new()
	title.text = "Friends"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_request_friends_state)
	header.add_child(refresh_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_friends_overlay)
	header.add_child(close_btn)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	content.add_child(add_row)

	_friends_username_edit = LineEdit.new()
	_friends_username_edit.placeholder_text = "Username"
	_friends_username_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(_friends_username_edit)

	var add_btn := Button.new()
	add_btn.text = "Add Friend"
	add_btn.pressed.connect(_on_send_friend_request_pressed)
	add_row.add_child(add_btn)

	var account_hint := Label.new()
	account_hint.text = "Friends uses registered account usernames. Guest names will not appear here."
	account_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_hint.modulate = Color(0.72, 0.78, 0.90)
	content.add_child(account_hint)

	_friends_status_label = Label.new()
	_friends_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_friends_status_label.modulate = Color(0.80, 0.86, 0.96)
	content.add_child(_friends_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(scroll)

	_friends_content_list = VBoxContainer.new()
	_friends_content_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friends_content_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_friends_content_list)

	_request_friends_state()
	_refresh_friends_overlay()

func _close_friends_overlay() -> void:
	if _friends_overlay == null:
		return
	if is_instance_valid(_friends_overlay):
		_friends_overlay.queue_free()
	_friends_overlay = null
	_friends_status_label = null
	_friends_username_edit = null
	_friends_content_list = null
	if _friends_button != null:
		_friends_button.grab_focus()

func _request_friends_state() -> void:
	if lobby_client == null or not _uses_server_account_storage():
		return
	lobby_client.request_friends()

func _on_send_friend_request_pressed() -> void:
	if lobby_client == null or _friends_username_edit == null:
		return
	var username := _friends_username_edit.text.strip_edges()
	if username.is_empty():
		_set_friends_status("Enter a username first.")
		return
	lobby_client.send_friend_request(username)
	_set_friends_status("Looking up account username %s..." % username)

func _on_friend_request_response_pressed(request_id: String, accept: bool) -> void:
	if lobby_client == null:
		return
	lobby_client.respond_friend_request(request_id, accept)
	_set_friends_status("Friend request updated.")

func _on_deck_share_response_pressed(share_id: String, accept: bool) -> void:
	if lobby_client == null:
		return
	lobby_client.respond_deck_share(share_id, accept)
	_set_friends_status("Deck share updated.")

func _on_friends_state_received(state) -> void:
	if state is Dictionary:
		_friends_state = (state as Dictionary).duplicate(true)
	_refresh_friends_button()
	_refresh_friends_overlay()
	_refresh_open_deck_builder_saved_decks()

func _refresh_friends_overlay() -> void:
	if _friends_content_list == null or not is_instance_valid(_friends_content_list):
		return
	for child in _friends_content_list.get_children():
		child.queue_free()
	var friends = _friends_state.get("friends", [])
	var incoming_requests = _friends_state.get("incoming_requests", [])
	var outgoing_requests = _friends_state.get("outgoing_requests", [])
	var incoming_deck_shares = _friends_state.get("incoming_deck_shares", [])
	var outgoing_deck_shares = _friends_state.get("outgoing_deck_shares", [])
	_add_friends_section("Friends", friends, Callable(self, "_make_friend_row"))
	_add_friends_section("Incoming Requests", incoming_requests, Callable(self, "_make_incoming_friend_request_row"))
	_add_friends_section("Sent Requests", outgoing_requests, Callable(self, "_make_outgoing_friend_request_row"))
	_add_friends_section("Decks Sent To You", incoming_deck_shares, Callable(self, "_make_incoming_deck_share_row"))
	_add_friends_section("Decks You Sent", outgoing_deck_shares, Callable(self, "_make_outgoing_deck_share_row"))
	if _friends_content_list.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "No friends or pending requests yet."
		empty_label.modulate = Color(0.78, 0.82, 0.90)
		_friends_content_list.add_child(empty_label)

func _add_friends_section(title: String, entries, row_factory: Callable) -> void:
	if _friends_content_list == null or not (entries is Array) or (entries as Array).is_empty():
		return
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color(0.95, 0.84, 0.48))
	_friends_content_list.add_child(header)
	for entry in entries:
		if entry is Dictionary:
			_friends_content_list.add_child(row_factory.call(entry as Dictionary))

func _make_friend_row(entry: Dictionary) -> Control:
	var username := str(entry.get("username", "Friend")).strip_edges()
	if username.is_empty():
		username = "Friend"
	var row := _make_friend_row_base()
	row.add_child(_make_friend_row_label(username))
	var send_btn := Button.new()
	send_btn.text = "Send Deck"
	send_btn.disabled = _get_saved_decks_for_current_identity().is_empty()
	send_btn.pressed.connect(func() -> void:
		_show_friend_send_deck_dialog(username)
	)
	row.add_child(send_btn)
	var friend_status_badge := Label.new()
	friend_status_badge.text = "Friend"
	friend_status_badge.modulate = Color(0.76, 0.82, 0.94)
	friend_status_badge.custom_minimum_size.x = 90
	row.add_child(friend_status_badge)
	return row

func _make_outgoing_friend_request_row(entry: Dictionary) -> Control:
	return _make_friend_text_row(str(entry.get("recipient_username", "Friend")), "Pending")

func _make_outgoing_deck_share_row(entry: Dictionary) -> Control:
	var deck: Dictionary = entry.get("deck", {}) if entry.get("deck", {}) is Dictionary else {}
	return _make_friend_text_row(
		"%s to %s" % [str(deck.get("name", "Deck")), str(entry.get("recipient_username", "Friend"))],
		"Pending"
	)

func _make_incoming_friend_request_row(entry: Dictionary) -> Control:
	var row := _make_friend_row_base()
	var label := _make_friend_row_label("%s wants to be friends" % str(entry.get("requester_username", "Someone")))
	row.add_child(label)
	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.pressed.connect(func() -> void:
		_on_friend_request_response_pressed(str(entry.get("request_id", "")), true)
	)
	row.add_child(accept_btn)
	var reject_btn := Button.new()
	reject_btn.text = "Reject"
	reject_btn.pressed.connect(func() -> void:
		_on_friend_request_response_pressed(str(entry.get("request_id", "")), false)
	)
	row.add_child(reject_btn)
	return row

func _make_incoming_deck_share_row(entry: Dictionary) -> Control:
	var row := _make_friend_row_base()
	var deck: Dictionary = entry.get("deck", {}) if entry.get("deck", {}) is Dictionary else {}
	var label := _make_friend_row_label(
		"%s sent %s" % [
			str(entry.get("sender_username", "A friend")),
			str(deck.get("name", "a deck")),
		]
	)
	row.add_child(label)
	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.pressed.connect(func() -> void:
		_on_deck_share_response_pressed(str(entry.get("share_id", "")), true)
	)
	row.add_child(accept_btn)
	var reject_btn := Button.new()
	reject_btn.text = "Reject"
	reject_btn.pressed.connect(func() -> void:
		_on_deck_share_response_pressed(str(entry.get("share_id", "")), false)
	)
	row.add_child(reject_btn)
	return row

func _make_friend_text_row(text: String, status: String) -> Control:
	var row := _make_friend_row_base()
	row.add_child(_make_friend_row_label(text))
	var row_status_label := Label.new()
	row_status_label.text = status
	row_status_label.modulate = Color(0.76, 0.82, 0.94)
	row_status_label.custom_minimum_size.x = 90
	row.add_child(row_status_label)
	return row

func _make_friend_row_base() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	return row

func _make_friend_row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _show_friend_send_deck_dialog(friend_username: String) -> void:
	if lobby_client == null or not _uses_server_account_storage():
		_set_friends_status("Log into an account before sending decks.")
		return
	var decks := _get_saved_decks_for_current_identity()
	if decks.is_empty():
		_maybe_request_account_decks()
		_set_friends_status("No saved decks found. Save a deck in Deck Builder first.")
		return
	_friends_pending_send_username = friend_username.strip_edges()
	if _friends_pending_send_username.is_empty():
		return
	_ensure_friends_send_deck_dialog()
	if _friends_send_deck_option == null:
		return
	_friends_send_deck_option.clear()
	for saved_deck in decks:
		var deck_id := str(saved_deck.get("deck_id", "")).strip_edges()
		if deck_id.is_empty():
			continue
		var deck_name := _get_saved_deck_name(saved_deck)
		var item_index := _friends_send_deck_option.item_count
		_friends_send_deck_option.add_item(deck_name)
		_friends_send_deck_option.set_item_metadata(item_index, deck_id)
	if _friends_send_deck_option.item_count <= 0:
		_set_friends_status("No saved decks found. Save a deck in Deck Builder first.")
		return
	_friends_send_deck_dialog.dialog_text = "Send a deck to %s." % _friends_pending_send_username
	_friends_send_deck_dialog.popup_centered(Vector2i(440, 170))

func _ensure_friends_send_deck_dialog() -> void:
	if _friends_send_deck_dialog != null and is_instance_valid(_friends_send_deck_dialog):
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Send Deck"
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	dialog.exclusive = true
	dialog.min_size = Vector2i(440, 170)
	dialog.get_ok_button().text = "Send Deck"
	dialog.confirmed.connect(_confirm_friend_send_deck)
	add_child(dialog)
	_friends_send_deck_dialog = dialog

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	dialog.add_child(margin)

	_friends_send_deck_option = OptionButton.new()
	_friends_send_deck_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_friends_send_deck_option)

func _confirm_friend_send_deck() -> void:
	if _friends_send_deck_option == null or _friends_send_deck_option.item_count <= 0:
		return
	var metadata = _friends_send_deck_option.get_item_metadata(_friends_send_deck_option.selected)
	var deck_id := str(metadata).strip_edges()
	if deck_id.is_empty():
		return
	for saved_deck in _get_saved_decks_for_current_identity():
		if str(saved_deck.get("deck_id", "")).strip_edges() != deck_id:
			continue
		_send_deck_to_friend(_friends_pending_send_username, saved_deck)
		return
	_set_friends_status("That saved deck was not found.")

func _set_friends_status(message: String) -> void:
	if _friends_status_label != null and is_instance_valid(_friends_status_label):
		_friends_status_label.text = message

func _get_friend_usernames() -> PackedStringArray:
	var usernames := PackedStringArray()
	var friends = _friends_state.get("friends", [])
	if not (friends is Array):
		return usernames
	for entry in friends:
		if not (entry is Dictionary):
			continue
		var username := str((entry as Dictionary).get("username", "")).strip_edges()
		if username.is_empty():
			continue
		usernames.append(username)
	return usernames

func _on_deck_builder_send_deck_to_friend_requested(friend_username: String, deck: Dictionary) -> void:
	_send_deck_to_friend(friend_username, deck)

func _send_deck_to_friend(friend_username: String, deck: Dictionary) -> void:
	if lobby_client == null or not _uses_server_account_storage():
		return
	lobby_client.send_deck_to_friend(
		friend_username,
		str(deck.get("name", "Deck")),
		deck.get("cards", {}),
		deck.get("special_setup", {})
	)
	_set_friends_status("Sending deck to %s..." % friend_username)
	status_label.text = "Sending deck to %s..." % friend_username

func _refresh_account_identity_label() -> void:
	var active_account_username := _get_effective_account_username()
	if _logged_in_account_username != active_account_username:
		_logged_in_account_username = active_account_username
	if title_label != null:
		title_label.text = _get_effective_identity_name("Guest")
	_refresh_friends_button()
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

func _update_resume_controls() -> void:
	if _resume_match_button == null:
		return
	_resume_match_button.visible = false

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
	if bool(match_info.get("observer_mode", false)):
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
		_normalize_auth_mode(str(saved_lobby_resume.get("auth_mode", AUTH_MODE_LOGIN)), AUTH_MODE_LOGIN),
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
	_smoke_finished = false

	ip_line_edit.text = str(_smoke_config.get("ip", "127.0.0.1"))
	_set_selected_account_username(str(_smoke_config.get("player_name", "Smoke%s" % role.capitalize())))
	var smoke_auth_mode: String = str(_smoke_config.get("auth_mode", AUTH_MODE_LOGIN)).strip_edges().to_lower()
	if smoke_auth_mode not in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		smoke_auth_mode = AUTH_MODE_LOGIN
	_set_auth_mode(smoke_auth_mode)
	_set_selected_account_password(str(_smoke_config.get("password", "")))

	var timeout_seconds := float(_smoke_config.get("timeout", 25.0))
	var timeout_timer := get_tree().create_timer(timeout_seconds)
	timeout_timer.timeout.connect(func() -> void:
		if _smoke_finished:
			return
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

	if role == "practice_thor_summon":
		call_deferred("_run_practice_thor_summon_smoke")
		return

	if role == "practice_thor_intercept":
		call_deferred("_run_practice_thor_intercept_smoke")
		return

	if role == "practice_thor_divine_lightning":
		call_deferred("_run_practice_thor_divine_lightning_smoke")
		return

	if role == "practice_thor_byggvir":
		call_deferred("_run_practice_thor_byggvir_smoke")
		return

	if role == "practice_thor_fuzz":
		call_deferred("_run_practice_thor_fuzz_smoke")
		return

	if role == "ranked_timeout_upkeep":
		call_deferred("_run_ranked_timeout_upkeep_smoke")
		return

	if role == "card_test_turn2":
		call_deferred("_run_card_test_turn2_smoke")
		return

	if role == "card_test_occult_singularity":
		call_deferred("_run_card_test_occult_singularity_smoke")
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

	if not practice_game.game_input.submit_action({type = "end_turn", discard_uids = []}):
		_complete_practice_thor_smoke(false, "practice_thor_end_turn_failed")
		return
	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return practice_game.game_manager.current_player == practice_game.player1 \
				and practice_game.game_manager.turn_number >= 3 \
				and practice_game.game_manager.action_stack.is_empty(),
		900
	):
		_complete_practice_thor_smoke(false, "practice_thor_turn_timeout")
		return

	var bot_board_count := _count_cards_in_zones(practice_game.player2.frontline_zones + practice_game.player2.reserve_zones)
	if bot_board_count <= 0 and practice_game.player1.followers >= 100:
		_complete_practice_thor_smoke(false, "practice_thor_no_bot_progress")
		return

	_complete_practice_thor_smoke(true, "practice_thor")

func _get_practice_thor_smoke_setup_error(practice_game) -> String:
	if practice_game == null:
		return "practice_thor_missing"
	if practice_game.player2 == null or practice_game.player1 == null:
		return "practice_thor_players_missing"
	if practice_game.player2.player_name != "Thor":
		return "practice_thor_wrong_name"
	if practice_game.match_manager == null or not practice_game.match_manager.authoritative_match_flow_enabled:
		return "practice_thor_not_authoritative"
	if practice_game.network_manager == null or not bool(practice_game.network_manager.get("is_server")):
		return "practice_thor_not_server"
	if practice_game.get("_thor_bot") == null:
		return "practice_thor_bot_missing"
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
	if _count_cards_of_type_in_zones(regular_zones, VisionOfOdin) != 2:
		return "practice_thor_wrong_vision_count"
	if _count_cards_of_type_in_zones(regular_zones, Askelladen) != 2:
		return "practice_thor_wrong_askelladen_count"
	return ""

func _count_cards_in_zones(zones: Array) -> int:
	var count := 0
	for zone in zones:
		if zone != null:
			count += zone.cards.size()
	return count

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

func _run_practice_thor_summon_smoke() -> void:
	_write_smoke_trace("practice_thor_summon:start")
	var practice_game = _show_embedded_game("PracticeThor")
	if practice_game == null:
		_fail_smoke_if_enabled("practice_thor_summon_missing")
		return
	show_game()
	practice_game.set_player_practice_deck({})
	await practice_game.start_game()
	await get_tree().process_frame
	await get_tree().process_frame
	_write_smoke_trace("practice_thor_summon:started_game")

	var setup_error := _get_practice_thor_smoke_setup_error(practice_game)
	if not setup_error.is_empty():
		_fail_smoke_if_enabled("practice_thor_summon_setup_%s" % setup_error)
		return
	_write_smoke_trace("practice_thor_summon:setup_ok")

	if not practice_game.game_input.submit_action({type = "upkeep_choice", choice = "draw"}):
		_fail_smoke_if_enabled("practice_thor_summon_upkeep_choice_failed")
		return
	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return practice_game.game_manager.current_player == practice_game.player1 \
				and practice_game.game_manager.has_resolved_turn_upkeep() \
				and practice_game.game_manager.action_stack.is_empty(),
		180
	):
		_fail_smoke_if_enabled("practice_thor_summon_player_one_upkeep_timeout")
		return
	_write_smoke_trace("practice_thor_summon:turn1_upkeep_ok")

	if not practice_game.game_input.submit_action({type = "end_turn", discard_uids = []}):
		_fail_smoke_if_enabled("practice_thor_summon_end_turn_failed")
		return
	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return practice_game.game_manager.current_player == practice_game.player1 \
				and practice_game.game_manager.turn_number >= 3 \
				and practice_game.game_manager.action_stack.is_empty(),
		400
	):
		_fail_smoke_if_enabled("practice_thor_summon_turn_timeout")
		return
	_write_smoke_trace("practice_thor_summon:turn3_entry_ok")

	if not practice_game.game_input.submit_action({type = "upkeep_choice", choice = "mana"}):
		_fail_smoke_if_enabled("practice_thor_summon_turn3_upkeep_choice_failed")
		return
	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return practice_game.game_manager.current_player == practice_game.player1 \
				and practice_game.game_manager.turn_number >= 3 \
				and practice_game.game_manager.has_resolved_turn_upkeep() \
				and practice_game.game_manager.action_stack.is_empty(),
		240
	):
		_fail_smoke_if_enabled("practice_thor_summon_turn3_upkeep_timeout")
		return
	_write_smoke_trace("practice_thor_summon:turn3_upkeep_ok mana=%d hand=%s" % [
		practice_game.player1.mana,
		_describe_smoke_hand(practice_game.player1),
	])

	var summon_zone := _find_first_open_smoke_summon_zone(practice_game.player1)
	var summon_card := _find_first_playable_smoke_creature(practice_game.game_manager, practice_game.player1, summon_zone)
	if summon_zone != null and summon_card == null:
		var seeded_card := BrownBear.new()
		seeded_card.card_owner = practice_game.player1
		practice_game.player1.hand_zone.add_card(seeded_card)
		summon_card = _find_first_playable_smoke_creature(practice_game.game_manager, practice_game.player1, summon_zone)
	if summon_zone == null or summon_card == null:
		_fail_smoke_if_enabled("practice_thor_summon_no_playable_creature hand=%s mana=%d" % [
			_describe_smoke_hand(practice_game.player1),
			practice_game.player1.mana,
		])
		return
	_write_smoke_trace("practice_thor_summon:selected card=%s zone=%d mana=%d" % [
		summon_card.card_name,
		summon_zone.zone_index,
		practice_game.player1.mana,
	])

	if not practice_game.game_input.submit_action({
		type = "play_creature",
		card_uid = summon_card.uid,
		player_index = practice_game.game_manager.players.find(practice_game.player1),
		zone_type = summon_zone.zone_type,
		zone_index = summon_zone.zone_index,
		mode = Card.CreatureMode.AGGRESSIVE,
		stealth = false,
		sacrifice_uids = [],
		altar_void_uids = [],
	}):
		_fail_smoke_if_enabled("practice_thor_summon_submit_failed card=%s hand=%s mana=%d" % [
			summon_card.card_name,
			_describe_smoke_hand(practice_game.player1),
			practice_game.player1.mana,
		])
		return
	_write_smoke_trace("practice_thor_summon:submitted card=%s zone=%d" % [
		summon_card.card_name,
		summon_zone.zone_index,
	])

	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return summon_card.current_zone == summon_zone \
				and practice_game.game_manager.current_player == practice_game.player1 \
				and practice_game.game_manager.action_stack.is_empty() \
				and not practice_game._stack_resolution_paused \
				and not practice_game._executing_stack_action,
		300
	):
		var top_action: CardAction = practice_game.game_manager.action_stack.back() if not practice_game.game_manager.action_stack.is_empty() else null
		var top_label := "none"
		if top_action != null:
			top_label = "%s:%s" % [str(top_action.type), str(top_action.event_name)]
		_fail_smoke_if_enabled("practice_thor_summon_stalled card=%s zone=%d stack=%d top=%s paused=%s executing=%s label=%s" % [
			summon_card.card_name,
			summon_zone.zone_index,
			practice_game.game_manager.action_stack.size(),
			top_label,
			str(practice_game._stack_resolution_paused),
			str(practice_game._executing_stack_action),
			str(practice_game.action_label.text).replace("\n", " "),
		])
		return

	_finish_smoke_if_enabled("PASS:practice_thor_summon")

func _run_practice_thor_intercept_smoke() -> void:
	_write_smoke_trace("practice_thor_intercept:start")
	var practice_game = _show_embedded_game("PracticeThor")
	if practice_game == null:
		_fail_smoke_if_enabled("practice_thor_intercept_missing")
		return
	show_game()
	practice_game.set_player_practice_deck({})
	await practice_game.start_game()
	await get_tree().process_frame
	await get_tree().process_frame
	_write_smoke_trace("practice_thor_intercept:started_game")

	var setup_error := _get_practice_thor_smoke_setup_error(practice_game)
	if not setup_error.is_empty():
		_fail_smoke_if_enabled("practice_thor_intercept_setup_%s" % setup_error)
		return
	practice_game._shutdown_thor_bot()

	if not practice_game.game_input.submit_action({type = "upkeep_choice", choice = "draw"}):
		_fail_smoke_if_enabled("practice_thor_intercept_upkeep_choice_failed")
		return
	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return practice_game.game_manager.current_player == practice_game.player1 \
				and practice_game.game_manager.has_resolved_turn_upkeep() \
				and practice_game.game_manager.action_stack.is_empty(),
		180
	):
		_fail_smoke_if_enabled("practice_thor_intercept_upkeep_timeout")
		return

	practice_game.game_manager.current_player = practice_game.player2
	practice_game.game_manager.turn_number = 2
	practice_game.game_manager._upkeep_started_turn = 2
	practice_game.game_manager._upkeep_resolved_turn = 2

	var attacker_zone := _find_first_open_smoke_frontline_zone(practice_game.player2)
	var interceptor_zone := _find_first_open_smoke_frontline_zone(practice_game.player1)
	if attacker_zone == null or interceptor_zone == null:
		_fail_smoke_if_enabled("practice_thor_intercept_missing_frontline_zone")
		return

	var attacker := HariiWarrior.new()
	attacker.card_owner = practice_game.player2
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.is_sleeping = false
	attacker_zone.add_card(attacker)

	var interceptor := StoneMonkey.new()
	interceptor.card_owner = practice_game.player1
	interceptor.creature_mode = Card.CreatureMode.DEFENSIVE
	interceptor.is_sleeping = false
	interceptor_zone.add_card(interceptor)

	await get_tree().process_frame
	await get_tree().process_frame
	practice_game.update_ui()

	if not practice_game.match_manager.can_attack(attacker):
		_fail_smoke_if_enabled("practice_thor_intercept_attacker_invalid:%s" % practice_game.match_manager.get_attack_invalid_reason(attacker))
		return
	if interceptor not in practice_game.match_manager._get_possible_interceptors(attacker, practice_game.player1):
		_fail_smoke_if_enabled("practice_thor_intercept_no_interceptor")
		return

	practice_game.match_manager.last_move_failed_reason = ""
	practice_game.match_manager.request_attack(attacker, practice_game.player1)
	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return _is_smoke_intercept_prompt_visible(practice_game) \
				and _count_pending_smoke_prompts_of_type(practice_game.match_manager, "intercept") == 1,
		120
	):
		_fail_smoke_if_enabled("practice_thor_intercept_prompt_missing reason=%s pending=%d" % [
			practice_game.match_manager.last_move_failed_reason,
			_count_pending_smoke_prompts_of_type(practice_game.match_manager, "intercept"),
		])
		return
	_write_smoke_trace("practice_thor_intercept:prompt_visible")
	var pending_intercept_prompt: Dictionary = {}
	for idx in range(practice_game.match_manager._pending_ui_interactions.size() - 1, -1, -1):
		var entry: Dictionary = practice_game.match_manager._pending_ui_interactions[idx]
		if str(entry.get("type", "")) == "intercept":
			pending_intercept_prompt = entry
			break
	var intercept_prompt_data: Dictionary = pending_intercept_prompt.get("data", {})
	if str(intercept_prompt_data.get("attacker_uid", "")) != attacker.uid:
		_fail_smoke_if_enabled("practice_thor_intercept_missing_attacker_uid")
		return
	if str(intercept_prompt_data.get("target_uid", "")) != str(practice_game.game_manager.players.find(practice_game.player1)):
		_fail_smoke_if_enabled("practice_thor_intercept_missing_target_uid")
		return

	var prompt_id_before_duplicate := int(pending_intercept_prompt.get("prompt_id", -1))
	var next_prompt_id_before_duplicate := int(practice_game.match_manager.get("_next_ui_interaction_id"))
	practice_game.match_manager.emit_ui_interaction_for_player(
		pending_intercept_prompt.get("player", practice_game.player1),
		"intercept",
		intercept_prompt_data
	)
	await get_tree().process_frame
	if _count_pending_smoke_prompts_of_type(practice_game.match_manager, "intercept") != 1:
		_fail_smoke_if_enabled("practice_thor_intercept_duplicate_prompt_count")
		return
	var duplicate_check_prompt: Dictionary = {}
	for idx in range(practice_game.match_manager._pending_ui_interactions.size() - 1, -1, -1):
		var entry: Dictionary = practice_game.match_manager._pending_ui_interactions[idx]
		if str(entry.get("type", "")) == "intercept":
			duplicate_check_prompt = entry
			break
	if int(duplicate_check_prompt.get("prompt_id", -1)) != prompt_id_before_duplicate \
			or int(practice_game.match_manager.get("_next_ui_interaction_id")) != next_prompt_id_before_duplicate:
		_fail_smoke_if_enabled("practice_thor_intercept_duplicate_prompt_reoffered")
		return
	_write_smoke_trace("practice_thor_intercept:duplicate_offer_suppressed prompt_id=%d" % prompt_id_before_duplicate)

	var validation: Dictionary = practice_game.match_manager._validate_pending_ui_interaction_for_command({
		type = "intercept_decision",
		interceptor_uid = interceptor.uid,
	})
	var validation_error := str(validation.get("error", ""))
	if not validation_error.is_empty():
		var selected_uid: String = practice_game.match_manager.selected_attacker.uid if practice_game.match_manager.selected_attacker != null else "<none>"
		var pending_target = practice_game.match_manager.pending_attack_target
		var pending_target_label := "<none>"
		if pending_target is Card:
			pending_target_label = "card:%s" % (pending_target as Card).uid
		elif pending_target is Player:
			pending_target_label = "player:%d" % practice_game.game_manager.players.find(pending_target)
		_fail_smoke_if_enabled("practice_thor_intercept_validation_failed:%s selected=%s pending=%s pending_ui=%s" % [
			validation_error,
			selected_uid,
			pending_target_label,
			practice_game.match_manager._get_pending_ui_debug_summary(),
		])
		return
	var prompt_id := int(validation.get("prompt_id", -1))
	if prompt_id < 0:
		_fail_smoke_if_enabled("practice_thor_intercept_missing_prompt_id")
		return
	if not practice_game._try_submit_visible_interceptor_card(interceptor):
		_fail_smoke_if_enabled("practice_thor_intercept_card_click_submit_failed")
		return
	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return not _is_smoke_intercept_prompt_visible(practice_game) \
				and _count_pending_smoke_prompts_of_type(practice_game.match_manager, "intercept") == 0,
		30
	):
		_fail_smoke_if_enabled("practice_thor_intercept_consumption_stuck prompt_id=%d pending=%d visible=%s" % [
			prompt_id,
			_count_pending_smoke_prompts_of_type(practice_game.match_manager, "intercept"),
			str(_is_smoke_intercept_prompt_visible(practice_game)),
		])
		return
	if practice_game.game_manager.action_stack.is_empty():
		_fail_smoke_if_enabled("practice_thor_intercept_no_attack_on_stack")
		return
	var attack_action: CardAction = practice_game.game_manager.action_stack.back()
	if attack_action == null or attack_action.type != CardAction.Type.ATTACK:
		_fail_smoke_if_enabled("practice_thor_intercept_wrong_stack_action")
		return
	if attack_action.interceptor != interceptor:
		_fail_smoke_if_enabled("practice_thor_intercept_wrong_interceptor")
		return
	_write_smoke_trace("practice_thor_intercept:accepted prompt_id=%d interceptor=%s" % [prompt_id, interceptor.uid])
	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return practice_game.game_manager.action_stack.is_empty() \
				and not practice_game.match_manager.is_authoritative_stack_resolution_pending(),
		1200
	):
		var stuck_action: CardAction = practice_game.game_manager.action_stack.back() if not practice_game.game_manager.action_stack.is_empty() else null
		var stuck_summary: String = practice_game.match_manager._get_action_debug_summary(stuck_action) if stuck_action != null else "<none>"
		_fail_smoke_if_enabled("practice_thor_intercept_resolution_stuck stack=%d pending=%s label=%s" % [
			practice_game.game_manager.action_stack.size(),
			str(practice_game.match_manager.is_authoritative_stack_resolution_pending()),
			str(practice_game.action_label.text).replace("\n", " ") + " action=" + stuck_summary,
		])
		return
	if not attacker.creature_major_action_used or not attacker.has_attacked_this_turn:
		_fail_smoke_if_enabled("practice_thor_intercept_attacker_action_not_spent")
		return
	if interceptor.current_zone == null or not interceptor.current_zone.is_board_zone():
		_fail_smoke_if_enabled("practice_thor_intercept_stone_monkey_left_board")
		return
	if _is_smoke_intercept_prompt_visible(practice_game) \
			or _count_pending_smoke_prompts_of_type(practice_game.match_manager, "intercept") != 0:
		_fail_smoke_if_enabled("practice_thor_intercept_prompt_returned")
		return
	_write_smoke_trace("practice_thor_intercept:resolved attacker_spent=%s interceptor_zone=%d" % [
		str(attacker.creature_major_action_used),
		interceptor.current_zone.zone_index,
	])

	_finish_smoke_if_enabled("PASS:practice_thor_intercept")

func _run_practice_thor_divine_lightning_smoke() -> void:
	_write_smoke_trace("practice_thor_divine_lightning:start")
	var practice_game = _show_embedded_game("PracticeThor")
	if practice_game == null:
		_fail_smoke_if_enabled("practice_thor_divine_lightning_missing")
		return
	show_game()
	practice_game.set_player_practice_deck({})
	await practice_game.start_game()
	await get_tree().process_frame
	await get_tree().process_frame
	_write_smoke_trace("practice_thor_divine_lightning:started_game")

	var setup_error := _get_practice_thor_smoke_setup_error(practice_game)
	if not setup_error.is_empty():
		_fail_smoke_if_enabled("practice_thor_divine_lightning_setup_%s" % setup_error)
		return

	var thor_bot: ThorPracticeBot = practice_game.get("_thor_bot") as ThorPracticeBot
	if thor_bot == null:
		_fail_smoke_if_enabled("practice_thor_divine_lightning_bot_missing")
		return

	var divine_lightning := thor_bot._find_hand_divine_lightning()
	if divine_lightning == null:
		divine_lightning = DivineLightning.new()
		divine_lightning.card_owner = practice_game.player2
		practice_game.player2.hand_zone.add_card(divine_lightning)

	var target_zone := _find_first_open_smoke_summon_zone(practice_game.player1)
	if target_zone == null:
		_fail_smoke_if_enabled("practice_thor_divine_lightning_target_zone_missing")
		return
	var target := Hringhorni.new()
	target.card_owner = practice_game.player1
	target_zone.add_card(target)

	var top_action := CardAction.new()
	top_action.type = CardAction.Type.EVENT
	top_action.event_name = "smoke_priority"
	top_action.source_player = practice_game.player1
	top_action.initial_priority_player = practice_game.player2
	top_action.card = target
	practice_game.game_manager.action_stack.append(top_action)
	practice_game.game_manager.priority_player = practice_game.player2

	await get_tree().process_frame

	var smoke_targets: Array[Card] = divine_lightning.get_priority_targets(practice_game.game_manager, top_action)
	if smoke_targets.is_empty():
		_fail_smoke_if_enabled("practice_thor_divine_lightning_no_targets")
		return

	var submitted := thor_bot._submit_priority_response(divine_lightning)
	_write_smoke_trace("practice_thor_divine_lightning:submit_result=%s target=%s" % [str(submitted), target.uid])

	_finish_smoke_if_enabled("PASS:practice_thor_divine_lightning")

func _run_practice_thor_byggvir_smoke() -> void:
	_write_smoke_trace("practice_thor_byggvir:start")
	var practice_game = _show_embedded_game("PracticeThor")
	if practice_game == null:
		_fail_smoke_if_enabled("practice_thor_byggvir_missing")
		return
	show_game()
	practice_game.set_player_practice_deck({})
	await practice_game.start_game()
	await get_tree().process_frame
	await get_tree().process_frame
	_write_smoke_trace("practice_thor_byggvir:started_game")

	var setup_error := _get_practice_thor_smoke_setup_error(practice_game)
	if not setup_error.is_empty():
		_fail_smoke_if_enabled("practice_thor_byggvir_setup_%s" % setup_error)
		return

	var byggvir := Byggvir.new()
	byggvir.card_owner = practice_game.player1
	var raw_options: Array = [
		{
			"kind": "flip",
			"label": "Unlock Mead of Poetry",
			"power_uid": "smoke_power_uid",
		},
		{
			"kind": "return",
			"label": "Return Mead of Poetry to hand",
			"card_uid": "smoke_card_uid",
		},
	]

	practice_game._show_byggvir_reveal_prompt(byggvir, raw_options)
	await get_tree().process_frame

	var panel: Control = practice_game.get_node_or_null("ByggvirPromptPanel") as Control
	var pending_options = practice_game.get("_pending_byggvir_options")
	if panel == null or not panel.visible:
		_fail_smoke_if_enabled("practice_thor_byggvir_prompt_missing")
		return
	if not (pending_options is Array) or (pending_options as Array).size() != 2:
		_fail_smoke_if_enabled("practice_thor_byggvir_options_missing")
		return
	_write_smoke_trace("practice_thor_byggvir:prompt_visible options=%d" % (pending_options as Array).size())

	_finish_smoke_if_enabled("PASS:practice_thor_byggvir")

func _run_practice_thor_fuzz_smoke() -> void:
	_write_smoke_trace("practice_thor_fuzz:start")
	var practice_game = _show_embedded_game("PracticeThor")
	if practice_game == null:
		_fail_smoke_if_enabled("practice_thor_fuzz_missing")
		return
	show_game()
	var deck_factory := PracticeAutofillDeckFactoryScript.new()
	var total_games := maxi(1, int(_smoke_config.get("games", 20)))
	var base_seed := int(_smoke_config.get("seed", 1337))
	var stall_frames := maxi(60, int(_smoke_config.get("stall_frames", 360)))
	var match_frames := maxi(stall_frames + 60, int(_smoke_config.get("match_frames", 2400)))
	var player_wins := 0
	var thor_wins := 0
	for game_index in range(total_games):
		var player_seed := base_seed + game_index * 2
		var thor_seed := base_seed + game_index * 2 + 1
		var player_deck := deck_factory.build_random_deck(player_seed)
		if player_deck.is_empty():
			_fail_smoke_if_enabled("practice_thor_fuzz_player_deck_failed index=%d seed=%d" % [game_index, player_seed])
			return
		var thor_deck := deck_factory.build_random_deck(thor_seed, "Thor")
		if thor_deck.is_empty():
			_fail_smoke_if_enabled("practice_thor_fuzz_thor_deck_failed index=%d seed=%d" % [game_index, thor_seed])
			return
		_write_smoke_trace("practice_thor_fuzz:match=%d player_seed=%d thor_seed=%d player_god=%s thor_god=%s" % [
			game_index,
			player_seed,
			thor_seed,
			str(player_deck.get("god_name", "")),
			str(thor_deck.get("god_name", "")),
		])
		var match_result := await _run_single_practice_thor_fuzz_game(
			practice_game,
			player_deck,
			thor_deck,
			game_index,
			player_seed,
			thor_seed,
			stall_frames,
			match_frames
		)
		if not bool(match_result.get("ok", false)):
			if practice_game.has_method("cleanup"):
				practice_game.cleanup()
			await get_tree().process_frame
			await get_tree().process_frame
			_fail_smoke_if_enabled(str(match_result.get("message", "practice_thor_fuzz_match_failed")))
			return
		var winner_name := str(match_result.get("winner", "")).strip_edges()
		if winner_name == "Player 1":
			player_wins += 1
		elif winner_name == "Thor":
			thor_wins += 1
	if practice_game.has_method("cleanup"):
		practice_game.cleanup()
	await get_tree().process_frame
	await get_tree().process_frame
	_write_smoke_trace("practice_thor_fuzz:complete games=%d player_wins=%d thor_wins=%d" % [total_games, player_wins, thor_wins])
	_finish_smoke_if_enabled("PASS:practice_thor_fuzz games=%d player_wins=%d thor_wins=%d seed=%d" % [
		total_games,
		player_wins,
		thor_wins,
		base_seed,
	])

func _run_ranked_timeout_upkeep_smoke() -> void:
	_write_smoke_trace("ranked_timeout_upkeep:start")
	var mock_game = _show_embedded_game("MockGame")
	if mock_game == null:
		_fail_smoke_if_enabled("ranked_timeout_upkeep_missing")
		return
	show_game()
	var deck_factory := PracticeAutofillDeckFactoryScript.new()
	var host_session_id := "ranked_timeout_host"
	var guest_session_id := "ranked_timeout_guest"
	var match_session := MatchSessionScript.new(
		"ranked-timeout-smoke",
		"ranked-timeout-room",
		"127.0.0.1",
		0,
		[host_session_id, guest_session_id],
		{
			host_session_id: deck_factory.build_random_deck(70101, "Thor"),
			guest_session_id: deck_factory.build_random_deck(70102, "Thor"),
		},
		{
			host_session_id: {"player_name": "Smoke Host"},
			guest_session_id: {"player_name": "Smoke Guest"},
		}
	)
	match_session.is_ranked = true
	match_session.server_mode = MatchSessionScript.SERVER_MODE_IN_PROCESS_HOST
	match_session.mark_active()
	var match_info := match_session.to_match_info(host_session_id)
	if mock_game.has_method("_prepare_for_match_launch"):
		mock_game._prepare_for_match_launch("Connecting to match...")
	mock_game.start_game(true, false, "127.0.0.1", 0, match_info, match_session)
	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return mock_game.game_manager != null \
				and mock_game.player1 != null \
				and mock_game.player2 != null \
				and mock_game.game_manager.current_player == mock_game.player1 \
				and not mock_game.game_manager.has_resolved_turn_upkeep() \
				and bool(mock_game._current_match_info.get("is_ranked", false)),
		120
	):
		_fail_smoke_if_enabled("ranked_timeout_upkeep_setup_failed")
		return
	mock_game._move_timer_remaining_msec = 0
	mock_game._move_timer_turn_number = mock_game.game_manager.turn_number
	mock_game._move_timer_player_index = mock_game.game_manager.players.find(mock_game.game_manager.current_player)
	mock_game._move_timer_active_started_msec = mock_game._now_msec()
	mock_game._move_timer_running = true
	mock_game._move_timer_timeout_pending = false
	mock_game._sync_turn_activity_timers()
	if not await _wait_for_practice_thor_smoke_condition(
		func() -> bool:
			return mock_game.game_manager != null \
				and mock_game.game_manager.current_player == mock_game.player2 \
				and mock_game.game_manager.turn_number == 2,
		240
	):
		_fail_smoke_if_enabled("ranked_timeout_upkeep_turn_not_passed current=%d turn=%d upkeep=%s label=%s" % [
			mock_game.game_manager.players.find(mock_game.game_manager.current_player) if mock_game.game_manager != null else -1,
			mock_game.game_manager.turn_number if mock_game.game_manager != null else -1,
			str(mock_game.game_manager.has_resolved_turn_upkeep() if mock_game.game_manager != null else false),
			str(mock_game.action_label.text if mock_game.action_label != null else ""),
		])
		return
	_finish_smoke_if_enabled("PASS:ranked_timeout_upkeep")

func _run_single_practice_thor_fuzz_game(
	practice_game,
	player_deck: Dictionary,
	thor_deck: Dictionary,
	game_index: int,
	player_seed: int,
	thor_seed: int,
	stall_frames: int,
	match_frames: int
) -> Dictionary:
	if practice_game == null:
		return {"ok": false, "message": "practice_thor_fuzz_missing_game"}
	if practice_game.has_method("cleanup"):
		practice_game.cleanup()
	await get_tree().process_frame
	await get_tree().process_frame
	practice_game.set_player_practice_deck(player_deck)
	if practice_game.has_method("set_thor_practice_deck"):
		practice_game.set_thor_practice_deck(thor_deck)
	await practice_game.start_game()
	await get_tree().process_frame
	await get_tree().process_frame
	var setup_error := _get_practice_thor_fuzz_setup_error(practice_game)
	if not setup_error.is_empty():
		return {
			"ok": false,
			"message": "practice_thor_fuzz_setup_%s index=%d player_seed=%d thor_seed=%d" % [
				setup_error,
				game_index,
				player_seed,
				thor_seed,
			],
		}
	var player_bot := PracticeFuzzPlayerBotScript.new()
	var player_bot_input := BotGameInputScript.new(practice_game.match_manager, 0)
	player_bot.attach(practice_game.game_manager, practice_game.match_manager, player_bot_input, 0)
	player_bot.poll()
	var validated_trace := func(command: Dictionary) -> void:
		_write_smoke_trace("practice_thor_fuzz:validated index=%d type=%s current=%d turn=%d" % [
			game_index,
			str(command.get("type", "")),
			practice_game.game_manager.players.find(practice_game.game_manager.current_player) if practice_game.game_manager != null else -1,
			practice_game.game_manager.turn_number if practice_game.game_manager != null else -1,
		])
	var failed_trace := func(reason: String) -> void:
		_write_smoke_trace("practice_thor_fuzz:move_failed index=%d reason=%s" % [game_index, reason])
	if not practice_game.match_manager.move_validated.is_connected(validated_trace):
		practice_game.match_manager.move_validated.connect(validated_trace)
	if not practice_game.match_manager.move_failed.is_connected(failed_trace):
		practice_game.match_manager.move_failed.connect(failed_trace)
	var last_snapshot := _build_practice_thor_fuzz_snapshot(practice_game)
	var unchanged_frames := 0
	for frame_index in range(match_frames):
		if practice_game.game_manager != null and practice_game.game_manager.is_game_over:
			if practice_game.match_manager.move_validated.is_connected(validated_trace):
				practice_game.match_manager.move_validated.disconnect(validated_trace)
			if practice_game.match_manager.move_failed.is_connected(failed_trace):
				practice_game.match_manager.move_failed.disconnect(failed_trace)
			player_bot.detach()
			var winner_name := _get_practice_thor_fuzz_winner_name(practice_game)
			_write_smoke_trace("practice_thor_fuzz:match=%d winner=%s frames=%d turn=%d" % [
				game_index,
				winner_name,
				frame_index,
				practice_game.game_manager.turn_number if practice_game.game_manager != null else -1,
			])
			return {"ok": true, "winner": winner_name}
		await get_tree().process_frame
		var snapshot := _build_practice_thor_fuzz_snapshot(practice_game)
		if snapshot == last_snapshot:
			unchanged_frames += 1
		else:
			last_snapshot = snapshot
			unchanged_frames = 0
		if unchanged_frames >= stall_frames:
			if practice_game.match_manager.move_validated.is_connected(validated_trace):
				practice_game.match_manager.move_validated.disconnect(validated_trace)
			if practice_game.match_manager.move_failed.is_connected(failed_trace):
				practice_game.match_manager.move_failed.disconnect(failed_trace)
			player_bot.detach()
			_write_smoke_trace("practice_thor_fuzz:stall index=%d player_seed=%d thor_seed=%d state=%s" % [
				game_index,
				player_seed,
				thor_seed,
				snapshot,
			])
			_write_smoke_trace("practice_thor_fuzz:player_deck=%s" % JSON.stringify(player_deck))
			_write_smoke_trace("practice_thor_fuzz:thor_deck=%s" % JSON.stringify(thor_deck))
			return {
				"ok": false,
				"message": "practice_thor_fuzz_stall index=%d player_seed=%d thor_seed=%d" % [
					game_index,
					player_seed,
					thor_seed,
				],
			}
	if practice_game.match_manager.move_validated.is_connected(validated_trace):
		practice_game.match_manager.move_validated.disconnect(validated_trace)
	if practice_game.match_manager.move_failed.is_connected(failed_trace):
		practice_game.match_manager.move_failed.disconnect(failed_trace)
	player_bot.detach()
	_write_smoke_trace("practice_thor_fuzz:timeout index=%d player_seed=%d thor_seed=%d state=%s" % [
		game_index,
		player_seed,
		thor_seed,
		last_snapshot,
	])
	_write_smoke_trace("practice_thor_fuzz:player_deck=%s" % JSON.stringify(player_deck))
	_write_smoke_trace("practice_thor_fuzz:thor_deck=%s" % JSON.stringify(thor_deck))
	return {
		"ok": false,
		"message": "practice_thor_fuzz_timeout index=%d player_seed=%d thor_seed=%d" % [
			game_index,
			player_seed,
			thor_seed,
		],
	}

func _get_practice_thor_fuzz_setup_error(practice_game) -> String:
	if practice_game == null:
		return "missing"
	if practice_game.player1 == null or practice_game.player2 == null:
		return "players_missing"
	if practice_game.match_manager == null or not practice_game.match_manager.authoritative_match_flow_enabled:
		return "not_authoritative"
	if practice_game.network_manager == null or not bool(practice_game.network_manager.get("is_server")):
		return "not_server"
	if practice_game.get("_thor_bot") == null:
		return "thor_bot_missing"
	if practice_game.player2.player_name != "Thor":
		return "wrong_enemy_name"
	if practice_game.game_manager == null:
		return "game_manager_missing"
	return ""

func _get_practice_thor_fuzz_winner_name(practice_game) -> String:
	if practice_game == null or practice_game.player1 == null or practice_game.player2 == null:
		return ""
	if practice_game.player1.is_defeated and not practice_game.player2.is_defeated:
		return "Thor"
	if practice_game.player2.is_defeated and not practice_game.player1.is_defeated:
		return "Player 1"
	if practice_game.player1.followers > practice_game.player2.followers:
		return "Player 1"
	if practice_game.player2.followers > practice_game.player1.followers:
		return "Thor"
	return "draw"

func _build_practice_thor_fuzz_snapshot(practice_game) -> String:
	if practice_game == null or practice_game.game_manager == null:
		return "missing"
	var game_manager: GameManager = practice_game.game_manager
	var match_manager: MatchManager = practice_game.match_manager
	var player1: Player = practice_game.player1
	var player2: Player = practice_game.player2
	var snapshot := {
		"turn": game_manager.turn_number,
		"current_player": game_manager.players.find(game_manager.current_player),
		"priority_player": game_manager.players.find(game_manager.priority_player),
		"upkeep_resolved": game_manager.has_resolved_turn_upkeep(),
		"stack": game_manager.action_stack.size(),
		"resolving": game_manager.resolving_stack_actions.size(),
		"pending_prompts": _count_pending_smoke_prompts(match_manager),
		"p1_followers": player1.followers if player1 != null else -1,
		"p2_followers": player2.followers if player2 != null else -1,
		"p1_mana": player1.mana if player1 != null else -1,
		"p2_mana": player2.mana if player2 != null else -1,
		"p1_hand": player1.hand_zone.cards.size() if player1 != null and player1.hand_zone != null else -1,
		"p2_hand": player2.hand_zone.cards.size() if player2 != null and player2.hand_zone != null else -1,
		"p1_deck": player1.deck_zone.cards.size() if player1 != null and player1.deck_zone != null else -1,
		"p2_deck": player2.deck_zone.cards.size() if player2 != null and player2.deck_zone != null else -1,
		"p1_board": _count_board_cards_for_player(player1),
		"p2_board": _count_board_cards_for_player(player2),
	}
	return JSON.stringify(snapshot)

func _count_pending_smoke_prompts(match_manager: MatchManager) -> int:
	if match_manager == null:
		return 0
	var pending_prompts = match_manager.get("_pending_ui_interactions")
	return (pending_prompts as Array).size() if pending_prompts is Array else 0

func _count_board_cards_for_player(player: Player) -> int:
	if player == null:
		return 0
	var total := 0
	for zone in player.frontline_zones + player.reserve_zones:
		if zone != null:
			total += zone.cards.size()
	return total

func _find_first_open_smoke_frontline_zone(player: Player) -> Zone:
	if player == null:
		return null
	for zone in player.frontline_zones:
		if zone != null and zone.cards.is_empty():
			return zone
	return null

func _find_first_open_smoke_summon_zone(player: Player) -> Zone:
	if player == null:
		return null
	for zone in player.frontline_zones:
		if zone != null and zone.cards.is_empty():
			return zone
	for zone in player.reserve_zones:
		if zone != null and zone.cards.is_empty():
			return zone
	return null

func _find_first_playable_smoke_creature(game_manager: GameManager, player: Player, zone: Zone) -> Card:
	if game_manager == null or player == null or zone == null:
		return null
	for card in player.hand_zone.cards:
		if card != null \
				and card.card_type == Card.CardType.CREATURE \
				and game_manager.can_play_card(player, card, zone):
			return card
	return null

func _find_smoke_hand_card_by_name(player: Player, expected_name: String) -> Card:
	if player == null or player.hand_zone == null:
		return null
	for card in player.hand_zone.cards:
		if card != null and card.card_name == expected_name:
			return card
	return null

func _count_smoke_board_magical_cards(game_manager: GameManager) -> int:
	if game_manager == null:
		return 0
	var count := 0
	for player: Player in game_manager.players:
		if player == null:
			continue
		for zone: Zone in player.frontline_zones + player.reserve_zones:
			if zone == null:
				continue
			for card: Card in zone.cards:
				if card != null and card.current_zone == zone and card.is_magical_card():
					count += 1
	return count

func _describe_smoke_hand(player: Player) -> String:
	if player == null or player.hand_zone == null:
		return ""
	var names: Array[String] = []
	for card in player.hand_zone.cards:
		if card != null:
			names.append(card.card_name)
	return ",".join(names)

func _is_smoke_intercept_prompt_visible(practice_game) -> bool:
	if practice_game == null:
		return false
	var panel: Control = practice_game.get_node_or_null("InterceptPromptPanel") as Control
	return panel != null and panel.visible

func _count_pending_smoke_prompts_of_type(match_manager: MatchManager, prompt_type: String) -> int:
	if match_manager == null:
		return 0
	var pending_prompts = match_manager.get("_pending_ui_interactions")
	if not (pending_prompts is Array):
		return 0
	var count := 0
	for entry in pending_prompts:
		if entry is Dictionary and str((entry as Dictionary).get("type", "")) == prompt_type:
			count += 1
	return count

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

func _run_card_test_occult_singularity_smoke() -> void:
	var card_test = _show_embedded_game("CardTest")
	if card_test == null:
		_fail_smoke_if_enabled("card_test_missing")
		return
	show_game()
	await card_test.start_game()
	card_test.load_n_o_card_scenario()
	await get_tree().process_frame
	await get_tree().process_frame

	if not card_test.game_input.submit_action({type = "upkeep_choice", choice = "mana"}):
		_fail_smoke_if_enabled("card_test_occult_singularity_upkeep_choice_failed")
		return
	if not await _wait_for_card_test_turn2_smoke_condition(
		func() -> bool:
			return card_test.game_manager.current_player == card_test.player1 \
				and card_test.game_manager.has_resolved_turn_upkeep() \
				and card_test.game_manager.action_stack.is_empty(),
		180
	):
		_fail_smoke_if_enabled("card_test_occult_singularity_upkeep_timeout")
		return

	var occult := _find_smoke_hand_card_by_name(card_test.player1, "Occult Singularity")
	if occult == null:
		_fail_smoke_if_enabled("card_test_occult_singularity_missing_spell")
		return
	var magical_before := _count_smoke_board_magical_cards(card_test.game_manager)
	if magical_before < 2:
		_fail_smoke_if_enabled("card_test_occult_singularity_missing_targets count=%d" % magical_before)
		return
	card_test.match_manager.authoritative_match_flow_enabled = true
	if not card_test.game_input.submit_action({type = "cast_spell", spell_uid = occult.uid}):
		_fail_smoke_if_enabled("card_test_occult_singularity_cast_failed")
		return
	if not await _wait_for_card_test_turn2_smoke_condition(
		func() -> bool:
			return card_test.game_manager.action_stack.is_empty() \
				and not card_test._stack_resolution_paused \
				and not card_test._executing_stack_action \
				and not card_test.game_manager.has_pending_doorway_choice() \
				and not card_test.game_manager.has_pending_return_to_hand_choice(),
		240
	):
		_fail_smoke_if_enabled(
			"card_test_occult_singularity_stalled stack=%d paused=%s executing=%s doorway=%s return=%s label=%s" % [
				card_test.game_manager.action_stack.size(),
				str(card_test._stack_resolution_paused),
				str(card_test._executing_stack_action),
				str(card_test.game_manager.has_pending_doorway_choice()),
				str(card_test.game_manager.has_pending_return_to_hand_choice()),
				str(card_test.action_label.text).replace("\n", " "),
			]
		)
		return

	var magical_after := _count_smoke_board_magical_cards(card_test.game_manager)
	if magical_after >= magical_before:
		_fail_smoke_if_enabled("card_test_occult_singularity_no_change before=%d after=%d" % [magical_before, magical_after])
		return

	_finish_smoke_if_enabled("PASS:card_test_occult_singularity before=%d after=%d" % [magical_before, magical_after])

func _wait_for_card_test_turn2_smoke_condition(predicate: Callable, max_frames: int) -> bool:
	for _frame in range(max_frames):
		if predicate.call():
			return true
		await get_tree().process_frame
	return false

func _maybe_progress_smoke_from_room_snapshot(room_id: String) -> void:
	if _smoke_config.is_empty():
		return

	var role := str(_smoke_config.get("role", "")).to_lower()
	if role == "client":
		var expected_room := str(_pending_join_room_code).strip_edges().to_upper()
		if expected_room.is_empty() or room_id != expected_room:
			return

func _should_ignore_lobby_failure_for_smoke() -> bool:
	if _smoke_config.is_empty():
		return false
	var role := str(_smoke_config.get("role", "")).to_lower()
	return role in [
		"practice_thor",
		"practice_thor_summon",
		"practice_thor_intercept",
		"practice_thor_divine_lightning",
		"practice_thor_byggvir",
		"practice_thor_fuzz",
		"ranked_timeout_upkeep",
		"card_test_turn2",
		"card_test_occult_singularity",
	]

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
		"auth_mode": str(config.get("smoke_auth_mode", AUTH_MODE_LOGIN)),
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
		"games": int(str(config.get("smoke_games", "20")).to_int()),
		"seed": int(str(config.get("smoke_seed", "1337")).to_int()),
		"stall_frames": int(str(config.get("smoke_stall_frames", "360")).to_int()),
		"match_frames": int(str(config.get("smoke_match_frames", "2400")).to_int()),
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
	_complete_smoke_if_enabled(message)

func _fail_smoke_if_enabled(message: String) -> void:
	if _smoke_config.is_empty():
		return
	_complete_smoke_if_enabled("FAIL:%s" % message)

func _complete_smoke_if_enabled(message: String) -> void:
	if _smoke_finished:
		return
	_smoke_finished = true
	_write_smoke_result(message)
	call_deferred("_close_program")

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
	# Keep the dedicated lobby in a plain headless runtime instead of editor mode.
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
		_auth_mode_option.add_item("Login")
		_auth_mode_option.set_item_metadata(0, AUTH_MODE_LOGIN)
		_auth_mode_option.add_item("Register")
		_auth_mode_option.set_item_metadata(1, AUTH_MODE_REGISTER)
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
	var auth_mode: String = _normalize_auth_mode(_local_profile_store.get_preferred_auth_mode(), AUTH_MODE_LOGIN)
	var saved_username := _get_saved_account_username()
	_set_selected_account_username(saved_username)
	_set_selected_account_password(_local_profile_store.get_last_account_password())
	_set_auth_mode(auth_mode)
	if not saved_username.is_empty():
		_activate_account_profile(saved_username, "", auth_mode, false)
	_refresh_auth_controls()
	_refresh_account_identity_label()
	if auth_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		_queue_authenticated_lobby_connect("Restoring lobby session...")

func _on_auth_mode_selected(_index: int) -> void:
	if _auth_mode_option != null and _auth_mode_option.item_count > 0:
		var metadata = _auth_mode_option.get_item_metadata(_auth_mode_option.selected)
		_selected_auth_mode = _normalize_auth_mode(str(metadata), AUTH_MODE_LOGIN)
	_refresh_auth_controls()
	if _local_profile_store == null:
		return
	var auth_mode := _get_selected_auth_mode()
	var preferred_account_username := _get_preferred_account_username()
	if not preferred_account_username.is_empty():
		_set_selected_account_username(preferred_account_username)
		_activate_account_profile(preferred_account_username, "", auth_mode, false)
	elif _local_profile_store != null:
		_local_profile_store.set_preferred_auth_mode(auth_mode)
	if _get_auth_password().is_empty():
		_set_selected_account_password(_local_profile_store.get_last_account_password())
	_refresh_open_deck_builder_saved_decks()
	_refresh_profile_summary_from_local_history(_local_profile_id)
	_update_resume_controls()
	_refresh_account_identity_label()

func _set_auth_mode(auth_mode: String) -> void:
	_selected_auth_mode = _normalize_auth_mode(auth_mode, AUTH_MODE_LOGIN)
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
		player_name_line_edit.placeholder_text = "Account username"
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
	var username: String = _get_preferred_account_username()
	if username.is_empty():
		return "Enter an account username first."
	var password := _get_auth_password()
	if password.is_empty():
		return "Enter your account password first."
	var credential_error := _validate_account_auth_details(auth_mode, username, password)
	if not credential_error.is_empty():
		return credential_error
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
	var player_name := _get_player_name(default_name)
	return player_name
