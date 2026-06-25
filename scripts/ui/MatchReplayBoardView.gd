extends Control
class_name MatchReplayBoardView

const DefaultMatchSetupScript = preload("res://scripts/server/DefaultMatchSetup.gd")
const GameStateScript = preload("res://scripts/Other/GameState.gd")
const BoardZoneUIScript = preload("res://scripts/ui/BoardZoneUI.gd")
const VisualCardScript = preload("res://scripts/ui/VisualCard.gd")
const CardBackTexture = preload("res://images/cardbackAI.png")

const PLAYER_HAND_CARD_WIDTH := 132
const ENEMY_HAND_CARD_WIDTH := 96
const HIDDEN_HAND_CARD_HEIGHT_RATIO := 1.4
const BOARD_ROW_GAP := 8
const BOARD_COLUMN_GAP := 8

var _default_match_setup = DefaultMatchSetupScript.new()
var _ghost_game_manager: GameManager = null

var _step_label: Label = null
var _turn_label: Label = null
var _action_message_label: Label = null
var _enemy_player_summary: Label = null
var _display_player_summary: Label = null
var _enemy_hand_row: HFlowContainer = null
var _display_hand_row: HFlowContainer = null
var _enemy_board_container: VBoxContainer = null
var _display_board_container: VBoxContainer = null

var _display_zone_uis: Array[BoardZoneUI] = []
var _enemy_zone_uis: Array[BoardZoneUI] = []
var _display_god_zone_ui: BoardZoneUI = null
var _enemy_god_zone_ui: BoardZoneUI = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func set_snapshot(
	state: Dictionary,
	action_message: String,
	viewer_player_index: int,
	step_index: int,
	total_steps: int
) -> void:
	if _step_label == null:
		_build_ui()
	_ensure_ghost_game_manager()
	if _ghost_game_manager == null:
		return

	GameStateScript.apply_to_manager(state, _ghost_game_manager)
	_assign_feedback_viewer(viewer_player_index)

	var current_turn_index := int(state.get("current_player_index", -1))
	var current_turn_player := _get_player_by_index(current_turn_index)
	var viewer := _ghost_game_manager.get_feedback_viewer()
	var viewer_name := viewer.player_name if viewer != null else "Player"
	var turn_name := current_turn_player.player_name if current_turn_player != null else viewer_name
	var turn_number := int(state.get("turn_number", 0))

	_step_label.text = "Action %d / %d" % [step_index + 1, maxi(total_steps, 1)]
	_turn_label.text = "Turn %d - %s's perspective" % [turn_number, viewer_name]
	var resolved_message := action_message.strip_edges()
	if resolved_message == "":
		resolved_message = "%s's turn." % turn_name
	_action_message_label.text = resolved_message

	_refresh_player_summaries()
	_rebuild_board_views()
	_rebuild_hand_rows()
	_sync_stack_zone_previews()

func _build_ui() -> void:
	if _step_label != null:
		return
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	root.add_child(header)

	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.add_theme_font_size_override("font_size", 15)
	_step_label.add_theme_color_override("font_color", Color(0.93, 0.87, 0.58))
	header.add_child(_step_label)

	_turn_label = Label.new()
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_turn_label)

	_action_message_label = Label.new()
	_action_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_message_label.add_theme_font_size_override("font_size", 14)
	header.add_child(_action_message_label)

	_enemy_player_summary = _make_player_summary_label()
	root.add_child(_enemy_player_summary)

	root.add_child(_make_hand_scroll(true))

	var board_scroll := ScrollContainer.new()
	board_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	board_scroll.follow_focus = true
	root.add_child(board_scroll)

	var board_stack := VBoxContainer.new()
	board_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_stack.add_theme_constant_override("separation", 12)
	board_scroll.add_child(board_stack)

	_enemy_board_container = VBoxContainer.new()
	_enemy_board_container.add_theme_constant_override("separation", BOARD_ROW_GAP)
	board_stack.add_child(_enemy_board_container)

	var separator := ColorRect.new()
	separator.color = Color(0.86, 0.74, 0.38, 0.55)
	separator.custom_minimum_size = Vector2(0.0, 4.0)
	board_stack.add_child(separator)

	_display_board_container = VBoxContainer.new()
	_display_board_container.add_theme_constant_override("separation", BOARD_ROW_GAP)
	board_stack.add_child(_display_board_container)

	root.add_child(_make_hand_scroll(false))

	_display_player_summary = _make_player_summary_label()
	root.add_child(_display_player_summary)

func _make_player_summary_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94))
	return label

func _make_hand_scroll(is_enemy: bool) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 160 if is_enemy else 220
	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	scroll.add_child(row)
	if is_enemy:
		_enemy_hand_row = row
	else:
		_display_hand_row = row
	return scroll

func _ensure_ghost_game_manager() -> void:
	if _ghost_game_manager != null:
		return
	_ghost_game_manager = GameManager.new()
	_default_match_setup.build_empty_match_shell(_ghost_game_manager, 2, [])

func _assign_feedback_viewer(viewer_player_index: int) -> void:
	if _ghost_game_manager == null:
		return
	var viewer := _get_player_by_index(viewer_player_index)
	if viewer == null and _ghost_game_manager.players.size() > 0:
		viewer = _ghost_game_manager.players[0]
	_ghost_game_manager.feedback_viewer = viewer

func _get_player_by_index(player_index: int) -> Player:
	if _ghost_game_manager == null:
		return null
	if player_index < 0 or player_index >= _ghost_game_manager.players.size():
		return null
	return _ghost_game_manager.players[player_index]

func _get_display_player() -> Player:
	if _ghost_game_manager == null:
		return null
	var viewer := _ghost_game_manager.get_feedback_viewer()
	if viewer != null:
		return viewer
	return _ghost_game_manager.current_player

func _get_display_opponent() -> Player:
	if _ghost_game_manager == null:
		return null
	var display_player := _get_display_player()
	if display_player == null:
		return _ghost_game_manager.other_player
	var opponent := _ghost_game_manager.get_opponent(display_player)
	if opponent != null:
		return opponent
	return _ghost_game_manager.other_player

func _refresh_player_summaries() -> void:
	var enemy_player := _get_display_opponent()
	var display_player := _get_display_player()
	_enemy_player_summary.text = _build_player_summary(enemy_player)
	_display_player_summary.text = _build_player_summary(display_player)

func _build_player_summary(player: Player) -> String:
	if player == null:
		return ""
	return "%s   Followers %d   Mana %d   Deck %d   Grave %d   Abyss %d" % [
		player.player_name,
		player.followers,
		player.mana,
		player.deck_zone.cards.size(),
		player.graveyard_zone.cards.size(),
		player.abyss_zone.cards.size(),
	]

func _rebuild_board_views() -> void:
	_detach_container_children(_enemy_board_container)
	_detach_container_children(_display_board_container)
	_enemy_zone_uis.clear()
	_display_zone_uis.clear()
	_enemy_god_zone_ui = null
	_display_god_zone_ui = null

	var enemy_player := _get_display_opponent()
	var display_player := _get_display_player()
	if enemy_player != null:
		_build_enemy_board(enemy_player)
	if display_player != null:
		_build_display_board(display_player)

func _build_enemy_board(enemy_player: Player) -> void:
	var reserve_row := _make_board_row()
	_enemy_board_container.add_child(reserve_row)
	_add_zone_ui_to_row(reserve_row, enemy_player.god_zone, enemy_player, 0, true, "god", true)
	_add_zone_ui_to_row(reserve_row, enemy_player.power_zones[2], enemy_player, 2, true, "power")
	for zone_index in range(enemy_player.reserve_zones.size()):
		_add_zone_ui_to_row(reserve_row, enemy_player.reserve_zones[zone_index], enemy_player, zone_index, true, "reserve line")

	var front_row := _make_board_row()
	_enemy_board_container.add_child(front_row)
	for zone_index in range(2):
		_add_zone_ui_to_row(front_row, enemy_player.power_zones[zone_index], enemy_player, zone_index, true, "power")
	for zone_index in range(enemy_player.frontline_zones.size()):
		_add_zone_ui_to_row(front_row, enemy_player.frontline_zones[zone_index], enemy_player, zone_index, true, "front line")

func _build_display_board(display_player: Player) -> void:
	var front_row := _make_board_row()
	_display_board_container.add_child(front_row)
	for zone_index in range(2):
		_add_zone_ui_to_row(front_row, display_player.power_zones[zone_index], display_player, zone_index, false, "power")
	for zone_index in range(display_player.frontline_zones.size()):
		_add_zone_ui_to_row(front_row, display_player.frontline_zones[zone_index], display_player, zone_index, false, "front line")

	var reserve_row := _make_board_row()
	_display_board_container.add_child(reserve_row)
	_add_zone_ui_to_row(reserve_row, display_player.god_zone, display_player, 0, false, "god", true)
	_add_zone_ui_to_row(reserve_row, display_player.power_zones[2], display_player, 2, false, "power")
	for zone_index in range(display_player.reserve_zones.size()):
		_add_zone_ui_to_row(reserve_row, display_player.reserve_zones[zone_index], display_player, zone_index, false, "reserve line")

func _make_board_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", BOARD_COLUMN_GAP)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return row

func _add_zone_ui_to_row(
	row: HBoxContainer,
	zone: Zone,
	player: Player,
	zone_index: int,
	is_enemy: bool,
	row_label: String,
	is_god_zone: bool = false
) -> void:
	var zone_ui := BoardZoneUIScript.new()
	row.add_child(zone_ui)
	zone_ui.setup(zone, _ghost_game_manager, player, zone_index, Callable(), is_enemy, row_label)
	if is_enemy:
		if is_god_zone:
			_enemy_god_zone_ui = zone_ui
		else:
			_enemy_zone_uis.append(zone_ui)
	else:
		if is_god_zone:
			_display_god_zone_ui = zone_ui
		else:
			_display_zone_uis.append(zone_ui)

func _rebuild_hand_rows() -> void:
	_rebuild_hand_row(_enemy_hand_row, _get_display_opponent(), true)
	_rebuild_hand_row(_display_hand_row, _get_display_player(), false)

func _rebuild_hand_row(row: HFlowContainer, player: Player, is_enemy: bool) -> void:
	if row == null:
		return
	_detach_container_children(row)
	if player == null:
		return
	for card in player.hand_zone.cards:
		row.add_child(_make_hand_card_control(card, is_enemy))

func _make_hand_card_control(card: Card, is_enemy: bool) -> Control:
	if card == null:
		return Control.new()
	var card_width := ENEMY_HAND_CARD_WIDTH if is_enemy else PLAYER_HAND_CARD_WIDTH
	if _is_hidden_hand_placeholder(card):
		return _make_hidden_hand_card(card_width)
	var visual_card := VisualCardScript.new()
	visual_card.set_hand_mode(true)
	visual_card.setup(card, card_width, 0)
	visual_card.set_hover_viewer(_ghost_game_manager.get_feedback_viewer())
	visual_card.set_hover_preview_when_disabled(true)
	visual_card.set_disabled(true, false)
	return visual_card

func _is_hidden_hand_placeholder(card: Card) -> bool:
	return card != null and card.card_name == "Hidden card"

func _make_hidden_hand_card(card_width: float) -> Control:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(card_width, card_width * HIDDEN_HAND_CARD_HEIGHT_RATIO)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.98)
	style.border_color = Color(0.66, 0.61, 0.48, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side as Side, 1)
	holder.add_theme_stylebox_override("panel", style)

	var back := TextureRect.new()
	back.texture = CardBackTexture
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.offset_left = 3.0
	back.offset_top = 3.0
	back.offset_right = -3.0
	back.offset_bottom = -3.0
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(back)
	return holder

func _sync_stack_zone_previews() -> void:
	for zone_ui in _display_zone_uis:
		if zone_ui != null and is_instance_valid(zone_ui):
			zone_ui.set_preview_card(null)
	for zone_ui in _enemy_zone_uis:
		if zone_ui != null and is_instance_valid(zone_ui):
			zone_ui.set_preview_card(null)
	if _display_god_zone_ui != null and is_instance_valid(_display_god_zone_ui):
		_display_god_zone_ui.set_preview_card(null)
	if _enemy_god_zone_ui != null and is_instance_valid(_enemy_god_zone_ui):
		_enemy_god_zone_ui.set_preview_card(null)
	if _ghost_game_manager == null:
		return
	for action in _ghost_game_manager.action_stack:
		if action == null or action.card == null or action.display_zone == null:
			continue
		var zone_ui := _get_zone_ui_for_zone(action.display_zone)
		if zone_ui != null and is_instance_valid(zone_ui):
			zone_ui.set_preview_card(action.card)

func _get_zone_ui_for_zone(zone: Zone) -> BoardZoneUI:
	if zone == null:
		return null
	if _display_god_zone_ui != null and is_instance_valid(_display_god_zone_ui) and _display_god_zone_ui.zone == zone:
		return _display_god_zone_ui
	if _enemy_god_zone_ui != null and is_instance_valid(_enemy_god_zone_ui) and _enemy_god_zone_ui.zone == zone:
		return _enemy_god_zone_ui
	for zone_ui in _display_zone_uis:
		if zone_ui != null and is_instance_valid(zone_ui) and zone_ui.zone == zone:
			return zone_ui
	for zone_ui in _enemy_zone_uis:
		if zone_ui != null and is_instance_valid(zone_ui) and zone_ui.zone == zone:
			return zone_ui
	return null

func _detach_container_children(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
