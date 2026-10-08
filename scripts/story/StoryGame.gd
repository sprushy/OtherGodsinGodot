extends "res://scripts/Other/PracticeThorGame.gd"
class_name StoryGame

signal story_board_ready

const STORY_ZONE_SCALE := 1.25
const STORY_DRAW_DECK_SCALE := 1.15
const STORY_WOLF_DECK_SIZE := 35
const StoryWolfBotScript = preload("res://scripts/story/StoryWolfBot.gd")
const StoryBotInputScript = preload("res://scripts/bots/BotGameInput.gd")

var _story_turn_clock: Label = null
var _story_board_ready: bool = false

func _ensure_board_art_background() -> void:
	_board_art_background = get_node("SnowForestMap") as TextureRect
	_board_art_background.visible = true
	_layout_board_art_background()

func _apply_board_art_background_texture() -> void:
	# Story owns its forest texture and terrain material independently of board settings.
	if _board_art_background != null:
		_board_art_background.visible = true

func _ready() -> void:
	get_node("MainHBox").modulate.a = 0.0
	super._ready()
	# Keep its layout space reserved even when the story controls are hidden.
	left_panel.visible = true
	left_panel.modulate.a = 0.0
	if _action_log_shell != null:
		_action_log_shell.visible = false
	right_panel.visible = true
	stats_container.visible = false
	forfeit_button.text = "Main Menu"
	choice_container.modulate.a = 0.0
	end_turn_button.modulate.a = 0.0
	end_turn_button.reparent(self, false)
	end_turn_button.custom_minimum_size = Vector2(180.0, 60.0)
	end_turn_button.add_theme_font_size_override("font_size", 24)
	end_turn_button.add_theme_color_override("font_color", Color.WHITE)
	for button_state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.24, 0.34, 0.98) if button_state == "normal" else Color(0.12, 0.38, 0.50, 1.0)
		style.border_color = Color(0.65, 0.90, 1.0)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		end_turn_button.add_theme_stylebox_override(button_state, style)
	# Use the standard match side panel and the same 24px clock as match stats.
	_story_turn_clock = Label.new()
	_story_turn_clock.name = "StoryTurnClock"
	_story_turn_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_turn_clock.add_theme_font_size_override("font_size", 24)
	_story_turn_clock.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0, 0.98))
	right_panel.add_child(_story_turn_clock)
	right_panel.move_child(_story_turn_clock, turn_label.get_index() + 1)
	BoardZoneUI.set_zone_extent(BoardZoneUI.get_base_zone_extent() * STORY_ZONE_SCALE)
	get_tree().call_group(SNOWSTORM_CONTROL_GROUP, "set_snowstorm_active", false)
	call_deferred("_start_story")

func _start_story() -> void:
	await start_game()
	# Build at the final story extent before exposing the initial container layout.
	_do_update_ui()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	RenderingServer.frame_pre_draw.connect(_reveal_story_board, CONNECT_ONE_SHOT)

func _get_board_zone_extent_target() -> float:
	return BoardZoneUI.get_base_zone_extent() * STORY_ZONE_SCALE

func _reveal_story_board() -> void:
	if not is_inside_tree():
		return
	_apply_board_horizontal_offset()
	if board_separator != null:
		var midpoint_y: float = board_separator.get_global_rect().get_center().y
		_center_story_control(end_turn_button, right_panel, midpoint_y)
	_story_board_ready = true
	_sync_story_draw_deck()
	_layout_turn_start_props()
	get_node("MainHBox").modulate.a = 1.0
	end_turn_button.modulate.a = 1.0
	_reveal_story_turn_choice()
	_apply_story_snow()
	story_board_ready.emit()

func _build_initial_match_players(_default_match_setup, _server_match_session = null, _match_info: Dictionary = {}) -> Dictionary:
	var human := Player.new()
	human.player_name = "Player 1"
	var wolves := Player.new()
	wolves.player_name = "Wolves"
	game_manager.players.assign([human, wolves])
	game_manager.upkeep_mana_enabled = true
	game_manager.setup_game()
	for player in [human, wolves]:
		player.spend_mana(player.mana)
		player.followers_enabled = false
	var askelladen := Askelladen.new()
	askelladen.card_owner = human
	askelladen.creature_mode = Card.CreatureMode.AGGRESSIVE
	askelladen.reset_creature_action_state()
	askelladen.summoned_this_turn = false
	askelladen.wake_up()
	human.frontline_zones[2].add_card(askelladen)
	_add_story_card(human, human.hand_zone, StoryArnbjorn.new())
	_add_story_card(human, human.deck_zone, Snowball.new())
	var shortsword := RunicShortsword.new()
	shortsword.set_art_variant(1)
	_add_story_card(human, human.deck_zone, shortsword)
	for _card_index in range(STORY_WOLF_DECK_SIZE):
		_add_story_card(wolves, wolves.deck_zone, WolfAdolescent.new())
	return {"player1": human, "player2": wolves}

func _add_story_card(player: Player, zone: Zone, card: Card) -> void:
	card.card_owner = player
	zone.add_card(card)

func _attach_thor_bot(thor_player: Player = null) -> void:
	if _thor_bot != null:
		return
	var opponent := thor_player if thor_player != null else player2
	if game_manager == null or match_manager == null or opponent == null:
		return
	var seat := game_manager.players.find(opponent)
	_thor_bot = StoryWolfBotScript.new()
	_thor_bot.attach(game_manager, match_manager, StoryBotInputScript.new(match_manager, seat), seat)

func _show_practice_intro() -> void:
	_set_action_label_text("Askelladen is already on your frontline. Place Arnbjørn from your hand.")

func _refresh_turn_choice_options() -> void:
	super._refresh_turn_choice_options()
	choice_intro_label.visible = false
	draw_button.text = "Draw"
	_sync_story_draw_deck()

func show_turn_choice() -> void:
	left_panel.modulate.a = 1.0
	# Keep the choice invisible until containers have finished their initial layout.
	choice_container.modulate.a = 0.0
	super.show_turn_choice()
	if not RenderingServer.frame_pre_draw.is_connected(_reveal_story_turn_choice):
		RenderingServer.frame_pre_draw.connect(_reveal_story_turn_choice, CONNECT_ONE_SHOT)

func _reveal_story_turn_choice() -> void:
	if not _story_board_ready:
		return
	if not is_inside_tree() or choice_container == null or not choice_container.visible:
		return
	_layout_turn_start_props()
	choice_container.modulate.a = 1.0

func hide_turn_choice() -> void:
	left_panel.modulate.a = 0.0
	super.hide_turn_choice()
	_sync_story_draw_deck()

func _sync_story_draw_deck() -> void:
	_sync_turn_start_props()

func _turn_start_props_are_ready() -> bool:
	return _story_board_ready and super._turn_start_props_are_ready()

func _get_turn_start_prop_scale() -> float:
	return STORY_DRAW_DECK_SCALE

func _get_turn_start_prop_horizontal_blend() -> float:
	return 0.35

func _sync_turn_choice_vertical_order() -> void:
	# The story choice floats over the reserved left panel space.
	return

func _process(delta: float) -> void:
	super._process(delta)
	_sync_story_draw_deck()
	if board_separator == null:
		return
	var midpoint_y: float = board_separator.get_global_rect().get_center().y
	if end_turn_button != null and end_turn_button.visible:
		_center_story_control(end_turn_button, right_panel, midpoint_y)
	# Keep the turn text and timer above the centered button.
	if right_top_spacer != null and _story_turn_clock != null:
		var panel_midpoint: float = (right_panel.get_global_transform().affine_inverse() * Vector2(0.0, midpoint_y)).y
		var label_height: float = turn_label.get_combined_minimum_size().y + _story_turn_clock.get_combined_minimum_size().y
		right_top_spacer.custom_minimum_size.y = maxf(0.0, panel_midpoint - 30.0 - label_height - 20.0)

func _center_story_control(control: Control, panel: Control, midpoint_y: float) -> void:
	var control_size: Vector2 = control.get_combined_minimum_size()
	control.size = control_size
	var center := Vector2(panel.get_global_rect().get_center().x, midpoint_y)
	control.position = get_global_transform().affine_inverse() * center - control_size * control.scale * 0.5

func _sync_network_turn_controls() -> void:
	# Clear stale choice visibility once the player or bot has resolved upkeep.
	if game_manager != null and game_manager.has_resolved_turn_upkeep() \
			and choice_container.visible and not _game_finished:
		hide_turn_choice()
	super._sync_network_turn_controls()
	_sync_story_draw_deck()

func _update_match_side_panel_layout() -> void:
	super._update_match_side_panel_layout()
	if right_panel != null:
		right_panel.custom_minimum_size.x = 184.0
	if end_turn_button != null:
		end_turn_button.custom_minimum_size = Vector2(180.0, 60.0)
	if turn_label != null:
		turn_label.custom_minimum_size.x = 180.0
	if choice_container != null:
		choice_container.custom_minimum_size.x = 180.0
		for child in choice_container.get_children():
			var control := child as Control
			if control != null:
				control.custom_minimum_size.x = 180.0

func _refresh_turn_label() -> void:
	super._refresh_turn_label()
	if _story_turn_clock == null:
		return
	var active_player: Player = game_manager.current_player if game_manager != null else null
	var clock_data := _get_stats_panel_turn_clock_data(active_player)
	_story_turn_clock.text = str(clock_data.get("text", "--:--"))
	_story_turn_clock.modulate = clock_data.get("color", Color(0.72, 0.74, 0.78, 0.92))

func _get_display_player() -> Player:
	return player1

func _get_display_opponent() -> Player:
	return player2

func _is_player_local(player: Player) -> bool:
	return player != null and player == player1

func _get_authoritative_turn_local_player_index() -> int:
	return 0 if player1 != null else -1

func _get_local_interaction_player_index(_preferred_player: Player = null) -> int:
	return _get_authoritative_turn_local_player_index()

func _on_match_ui_interaction(player_index: int, type: String, data: Dictionary) -> void:
	if player_index != 0:
		return
	super._on_match_ui_interaction(player_index, type, data)

func draw_board() -> void:
	_draw_story_row(board_container, _get_display_player(), false)

func draw_enemy_board() -> void:
	_draw_story_row(enemy_board_container, _get_display_opponent(), true)

func _sync_heavy_snow_weather_visuals(_force: bool = false) -> void:
	_apply_story_snow()

func _apply_story_snow() -> void:
	var weather := get_node("SnowWeather") as SnowV2WeatherController
	weather.set_snowstorm_profile(
		1.0,
		0.10,
		0.62,
		Vector2(-1.0, 0.16),
		1.65
	)

func _exit_tree() -> void:
	_shutdown_thor_bot()
	var tree := get_tree()
	if tree != null:
		tree.call_group(SNOWSTORM_CONTROL_GROUP, "set_snowstorm_active", false)
	BoardZoneUI.set_zone_extent(BoardZoneUI.get_base_zone_extent())
	super._exit_tree()

func _sync_follower_casualties_for_player(_player: Player, _new_followers: int, _play_hurt: bool) -> void:
	return

func _sync_follower_casualty_overlay() -> void:
	_clear_follower_casualty_overlay()

func _get_board_drag_followers_target_rects(_include_god_zone: bool = true) -> Array[Rect2]:
	return []

func _should_show_followers_attack_target_highlight() -> bool:
	return false

func _can_selected_attacker_target_followers() -> bool:
	return false

func _can_board_drag_attack_followers(_target_player: Player) -> bool:
	return false

func _on_player_followers_changed(_new_followers: int) -> void:
	_clear_follower_casualty_overlay()

func _on_enemy_followers_changed(_new_followers: int) -> void:
	_clear_follower_casualty_overlay()

func _draw_story_row(container: VBoxContainer, player: Player, is_opponent: bool) -> void:
	# Drag release and targeting use these same zone lists in normal matches.
	if is_opponent:
		_enemy_zone_uis.clear()
	else:
		_board_zone_uis.clear()
	_detach_container_children(container)
	if player == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(BOARD_ZONE_COLUMN_GAP))
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.add_child(row)
	for lane_index in range(player.frontline_zones.size()):
		var zone: Zone = player.frontline_zones[lane_index]
		var zone_ui := BoardZoneUI.new()
		row.add_child(zone_ui)
		zone_ui.setup(zone, game_manager, player, lane_index, _on_card_dropped_to_zone, is_opponent, "front line")
		if is_opponent:
			_enemy_zone_uis.append(zone_ui)
			zone_ui.card_clicked.connect(_on_enemy_card_pressed)
			zone_ui.equipment_target_action_clicked.connect(_on_equipment_target_action_clicked)
		else:
			_board_zone_uis.append(zone_ui)
			zone_ui.zone_clicked.connect(_on_empty_zone_pressed)
			zone_ui.card_clicked.connect(_on_board_card_pressed)
			zone_ui.creature_stance_switch_clicked.connect(_on_creature_stance_switch_clicked)
			zone_ui.creature_ability_badge_clicked.connect(_on_creature_ability_badge_clicked)
			zone_ui.creature_ability_option_badge_clicked.connect(_on_creature_ability_option_badge_clicked)
			zone_ui.e2_abzu_badge_clicked.connect(_on_e2_abzu_badge_clicked)
			zone_ui.nimue_badge_clicked.connect(_on_nimue_badge_clicked)
			zone_ui.equipment_target_action_clicked.connect(_on_equipment_target_action_clicked)
			zone_ui.creature_drag_started.connect(_on_creature_drag_started)
			zone_ui.creature_right_clicked.connect(_on_creature_right_clicked)

func _on_forfeit_button_pressed() -> void:
	_shutdown_thor_bot()
	_emit_return_to_menu_requested()
