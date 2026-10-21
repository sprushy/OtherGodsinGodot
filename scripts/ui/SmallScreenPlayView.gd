extends Control

# Presentation only: keep the real board controls and their normal input paths.
# Moving MainHBox leaves prompts, menus and these navigation controls unzoomed.
const SMALL_WINDOW_SIZE := Vector2i(1280, 720)

var active: bool = false
var _game: Control
var _board_layout: Control
var _card_uid: String = ""
var _opponent_side: bool = false
var _original_position := Vector2.ZERO
var _original_scale := Vector2.ONE
var _toolbar: PanelContainer
var _title: Label
var _feedback: Label
var _switch_button: Button
var _options_button: Button
var _ui_scale: float = 1.0
var _hidden_hands: Array[Control] = []

static func uses_tap_controls(viewport: Viewport, force_phone_controls: bool = false) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if force_phone_controls:
		return true
	if OS.has_feature("ios") or OS.has_feature("android"):
		return true
	var window_size := viewport.get_window().size
	return window_size.x <= SMALL_WINDOW_SIZE.x or window_size.y <= SMALL_WINDOW_SIZE.y

func setup(game: Control) -> void:
	_game = game
	_board_layout = game.get_node("MainHBox") as Control
	name = "SmallScreenPlayView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 2205
	_build_toolbar()
	hide()

func _build_toolbar() -> void:
	_toolbar = PanelContainer.new()
	_toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.14, 0.98)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_toolbar.add_theme_stylebox_override("panel", style)
	add_child(_toolbar)
	var column := VBoxContainer.new()
	_toolbar.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_title)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	_switch_button = _add_button(buttons, "Switch Side", _switch_side)
	_options_button = _add_button(buttons, "Play Options", _show_play_options)
	_add_button(buttons, "Main View", exit_focus)
	_feedback = Label.new()
	_feedback.add_theme_font_size_override("font_size", 16)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.max_lines_visible = 2
	_feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_feedback)

func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func focus_card(card: Card) -> void:
	if card == null or not bool(_game.call("_uses_small_screen_play_controls")) \
			or not _game.is_visible_in_tree() or bool(_game.get("_is_observer_mode")):
		return
	# This runs deferred, after selection/command submission has settled.
	if not _is_card_pending(card.uid):
		return
	if not active:
		_original_position = _board_layout.position
		_original_scale = _board_layout.scale
	_card_uid = card.uid
	_opponent_side = _default_opponent_side(card)
	if str(_game.get("placement_mode")) in ["prepare_spell", "prepare_charm"]:
		_opponent_side = false
	active = true
	show()
	_game.call("_hide_hand_hover_preview")
	_update_view()

func _default_opponent_side(card: Card) -> bool:
	var opponent_side := card.card_type in [Card.CardType.SPELL, Card.CardType.HEX]
	if card is CharmCard:
		opponent_side = card.targets and not card.must_be_prepared_to_activate
	# Prefer the friendly side when a targeted spell only offers friendly choices
	# (for example, resurrection). Mixed targets retain the opponent default.
	if opponent_side and card.targets and card.has_method("get_valid_targets"):
		var targets: Array = card.call("get_valid_targets", _game.get("game_manager"))
		var viewer := _game.call("_get_display_player") as Player
		if not targets.is_empty() and viewer != null:
			for target in targets:
				if not (target is Card) or target.get_controller() != viewer:
					return true
			return false
	return opponent_side

func focus_friendly() -> void:
	if active:
		_opponent_side = false
		_update_view()

func exit_focus() -> void:
	if not active:
		return
	active = false
	_card_uid = ""
	_board_layout.scale = _original_scale
	_board_layout.position = _original_position
	for hand in _hidden_hands:
		if is_instance_valid(hand):
			hand.show()
	_hidden_hands.clear()
	hide()
	# Returning to the overview preserves any pending play/paid targeting.
	_game.call("_close_context_menu")

func _process(_delta: float) -> void:
	if not active:
		return
	if not _game.is_visible_in_tree() or bool(_game.get("_game_finished")) \
			or not bool(_game.call("_uses_small_screen_play_controls")) or not _is_card_pending(_card_uid):
		exit_focus()
		return
	# These flows need access to the hand rather than a board destination.
	if bool(_game.call("_is_blot_selection_active")) \
			or bool(_game.call("_is_mopsus_hand_selection_active")):
		exit_focus()
		return
	_update_view()

func _is_card_pending(uid: String) -> bool:
	var selected := _game.get("selected_card") as Card
	if selected != null and selected.uid == uid:
		return true
	var manager := _game.get("match_manager") as MatchManager
	if manager != null:
		for source in [manager.pending_click_selection_source, manager.spell_waiting_for_target]:
			if source != null and source.uid == uid:
				return true
	return false

func _update_view() -> void:
	var window_size := Vector2(get_viewport().get_window().size)
	var viewport_size := get_viewport_rect().size
	_ui_scale = maxf(1.0, viewport_size.x / maxf(window_size.x, 1.0))
	var margin := 8.0 * _ui_scale
	_toolbar.scale = Vector2.ONE * _ui_scale
	_toolbar.position = Vector2(margin, margin)
	_toolbar.size.x = maxf(1.0, (_game.size.x - margin * 2.0) / _ui_scale)
	var selected := _game.get("selected_card") as Card
	var card_name := selected.card_name if selected != null else "Choose a target"
	_title.text = "%s - %s" % [card_name, "Opponent's board" if _opponent_side else "Your board"]
	_switch_button.text = "Your Side" if _opponent_side else "Opponent Side"
	_options_button.disabled = selected == null or bool(_game.call("_has_pending_target_selection"))
	_options_button.visible = selected != null and (selected is SpellCard or selected is HexCard \
		or selected is CharmCard or (selected.card_type == Card.CardType.CREATURE and not selected.is_god))
	var action_label := _game.get("action_label") as Label
	_feedback.text = action_label.text if action_label != null else ""
	_feedback.tooltip_text = _feedback.text
	_hide_hands()
	var board := _game.get("enemy_board_container" if _opponent_side else "board_container") as Control
	if board == null or board.get_child_count() == 0:
		return
	var inverse := _board_layout.get_global_transform().affine_inverse()
	var bounds := Rect2()
	for child in board.get_children():
		if child is Control and child.visible:
			var rect: Rect2 = inverse * child.get_global_rect()
			bounds = rect if not bounds.has_area() else bounds.merge(rect)
	if not bounds.has_area():
		return
	bounds = bounds.grow(12.0)
	var top := _toolbar.position.y + _toolbar.size.y * _ui_scale + margin
	var available := Rect2(Vector2(margin, top), Vector2(_game.size.x - margin * 2.0, maxf(1.0, _game.size.y - top - margin)))
	var zoom := minf(available.size.x / bounds.size.x, available.size.y / bounds.size.y)
	_board_layout.scale = Vector2.ONE * zoom
	_board_layout.position = available.get_center() - bounds.get_center() * zoom

func _hide_hands() -> void:
	for property in ["_fan_container", "_enemy_hand_overlay"]:
		var hand := _game.get(property) as Control
		if is_instance_valid(hand) and hand.visible:
			if not _hidden_hands.has(hand):
				_hidden_hands.append(hand)
			hand.hide()

func _switch_side() -> void:
	_opponent_side = not _opponent_side
	_game.call("_close_context_menu")
	_update_view()

func _show_play_options() -> void:
	var selected := _game.get("selected_card") as Card
	if selected != null:
		_game.call("_on_hand_card_right_clicked", selected)

func prepare_options(panel: Control) -> void:
	panel.scale = Vector2.ONE * _ui_scale
	_enlarge_option_controls(panel)

func _enlarge_option_controls(node: Node) -> void:
	if node is Button:
		node.custom_minimum_size.y = 44.0
		node.add_theme_font_size_override("font_size", 18)
	for child in node.get_children():
		_enlarge_option_controls(child)

func position_options(panel: Control) -> void:
	var panel_size := panel.size * panel.scale
	var viewport_size := get_viewport_rect().size
	panel.global_position = Vector2(
		maxf(4.0, (viewport_size.x - panel_size.x) * 0.5),
		maxf(4.0, (viewport_size.y - panel_size.y) * 0.5)
	)
