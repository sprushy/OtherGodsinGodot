extends Control

# Presentation only: keep the real board controls and their normal input paths.
# Moving MainHBox leaves prompts, menus and these navigation controls unzoomed.
const SMALL_WINDOW_SIZE := Vector2i(1280, 720)
const PLAQUE_TEXTURE := preload("res://images/ui/clocktower/stone_plaque.png")
const PLAQUE_REGION := Rect2(12.0, 148.0, 1960.0, 492.0)
const TITLE_FONT := preload("res://fonts/custom_ui/Norsebold.otf")
const SWITCH_ICON := preload("res://images/ui/play_view/switch_sides.svg")
const OPTIONS_ICON := preload("res://images/ui/play_view/play_options.svg")
const OVERVIEW_ICON := preload("res://images/ui/play_view/main_view.svg")
const GOLD := Color(0.95, 0.82, 0.57)
const VIEW_TRANSITION_SECONDS := 0.42
const RETURN_TRANSITION_SECONDS := 0.34

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
var _overview_button: Button
var _ui_scale: float = 1.0
var _hidden_hands: Array[Control] = []
var _view_tween: Tween
var _toolbar_tween: Tween
var _returning: bool = false
var _has_view_target: bool = false
var _target_position := Vector2.ZERO
var _target_scale := Vector2.ONE

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
	_toolbar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_toolbar.add_theme_stylebox_override("panel", _plaque_style(Color(0.48, 0.44, 0.36)))
	add_child(_toolbar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_toolbar.add_child(column)
	_title = Label.new()
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_font_size_override("font_size", 23)
	_title.add_theme_color_override("font_color", GOLD)
	_title.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02))
	_title.add_theme_constant_override("outline_size", 2)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_title)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	_switch_button = _add_button(buttons, "Switch Side", _switch_side, SWITCH_ICON)
	_options_button = _add_button(buttons, "Play Options", _show_play_options, OPTIONS_ICON)
	_overview_button = _add_button(buttons, "Main View", exit_focus, OVERVIEW_ICON)
	_feedback = Label.new()
	_feedback.add_theme_font_size_override("font_size", 16)
	_feedback.add_theme_color_override("font_color", Color(0.91, 0.88, 0.79))
	_feedback.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.02))
	_feedback.add_theme_constant_override("outline_size", 2)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.max_lines_visible = 2
	_feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_feedback)

func _plaque_style(tint: Color) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = PLAQUE_TEXTURE
	atlas.region = PLAQUE_REGION
	var style := StyleBoxTexture.new()
	style.texture = atlas
	style.modulate_color = tint
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _theme_button(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", TITLE_FONT)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.73))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.56))
	button.add_theme_color_override("font_disabled_color", Color(0.57, 0.54, 0.47))
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_stylebox_override("normal", _plaque_style(Color(0.70, 0.65, 0.53)))
	button.add_theme_stylebox_override("hover", _plaque_style(Color(0.94, 0.83, 0.62)))
	button.add_theme_stylebox_override("pressed", _plaque_style(Color(0.48, 0.43, 0.34)))
	button.add_theme_stylebox_override("disabled", _plaque_style(Color(0.36, 0.35, 0.31)))
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = GOLD
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("focus", focus_style)

func _add_button(parent: Control, text: String, callback: Callable, icon: Texture2D) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = text
	button.accessibility_name = text
	button.custom_minimum_size.y = 48.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.icon = icon
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 26)
	button.add_theme_constant_override("h_separation", 7)
	_theme_button(button)
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
	var entering := not active
	if entering and not _returning:
		_original_position = _board_layout.position
		_original_scale = _board_layout.scale
	_returning = false
	_card_uid = card.uid
	_opponent_side = _default_opponent_side(card)
	if str(_game.get("placement_mode")) in ["prepare_spell", "prepare_charm"]:
		_opponent_side = false
	active = true
	show()
	if entering:
		if is_instance_valid(_toolbar_tween):
			_toolbar_tween.kill()
		_toolbar.modulate.a = 0.0
		_toolbar_tween = create_tween()
		_toolbar_tween.tween_property(_toolbar, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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

func exit_focus(immediate: bool = false) -> void:
	if not active:
		return
	active = false
	_card_uid = ""
	_returning = true
	_has_view_target = false
	# Returning to the overview preserves any pending play/paid targeting.
	_game.call("_close_context_menu")
	if is_instance_valid(_toolbar_tween):
		_toolbar_tween.kill()
	if immediate or not _game.is_visible_in_tree():
		_finish_exit()
		return
	_toolbar_tween = create_tween()
	_toolbar_tween.tween_property(_toolbar, "modulate:a", 0.0, 0.16)
	_transition_to(_original_position, _original_scale, RETURN_TRANSITION_SECONDS)
	_view_tween.finished.connect(_finish_exit, CONNECT_ONE_SHOT)

func _finish_exit() -> void:
	if is_instance_valid(_view_tween):
		_view_tween.kill()
	if is_instance_valid(_toolbar_tween):
		_toolbar_tween.kill()
	_returning = false
	_has_view_target = false
	_board_layout.scale = _original_scale
	_board_layout.position = _original_position
	for hand in _hidden_hands:
		if is_instance_valid(hand):
			hand.show()
	_hidden_hands.clear()
	hide()

func _process(_delta: float) -> void:
	if _returning and not _game.is_visible_in_tree():
		_finish_exit()
	if not active:
		return
	if not _game.is_visible_in_tree() or bool(_game.get("_game_finished")) \
			or not bool(_game.call("_uses_small_screen_play_controls")) or not _is_card_pending(_card_uid):
		exit_focus(not _game.is_visible_in_tree())
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
	var toolbar_width := minf(760.0, maxf(1.0, (_game.size.x - margin * 2.0) / _ui_scale))
	var compact := toolbar_width < 520.0
	_switch_button.icon = null if compact else SWITCH_ICON
	_options_button.icon = null if compact else OPTIONS_ICON
	_overview_button.icon = null if compact else OVERVIEW_ICON
	for button in [_switch_button, _options_button, _overview_button]:
		button.add_theme_font_size_override("font_size", 18 if compact else 21)
	_options_button.text = "Options" if compact else "Play Options"
	_toolbar.scale = Vector2.ONE * _ui_scale
	_toolbar.position = Vector2(margin, margin)
	_toolbar.size.x = toolbar_width
	_toolbar.position.x = (_game.size.x - _toolbar.size.x * _ui_scale) * 0.5
	var selected := _game.get("selected_card") as Card
	var card_name := selected.card_name if selected != null else "Choose a target"
	_title.text = "%s - %s" % [card_name, "Opponent's board" if _opponent_side else "Your board"]
	_switch_button.text = "Your Side" if _opponent_side else "Opponent Side"
	if compact and not _opponent_side:
		_switch_button.text = "Their Side"
	_switch_button.tooltip_text = "Show your board" if _opponent_side else "Show the opponent's board"
	_switch_button.accessibility_name = _switch_button.tooltip_text
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
	var next_scale := Vector2.ONE * zoom
	var next_position := available.get_center() - bounds.get_center() * zoom
	# Ignore subpixel round-off from measuring controls during the tween, so
	# the same destination does not restart the animation every frame.
	if not _has_view_target or next_scale.distance_to(_target_scale) > 0.001 \
			or next_position.distance_to(_target_position) > 1.0:
		_transition_to(next_position, next_scale, VIEW_TRANSITION_SECONDS)

func _transition_to(target_position: Vector2, target_scale: Vector2, duration: float) -> void:
	if is_instance_valid(_view_tween):
		_view_tween.kill()
	_has_view_target = true
	_target_position = target_position
	_target_scale = target_scale
	_view_tween = create_tween().set_parallel(true)
	_view_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_view_tween.tween_property(_board_layout, "position", target_position, duration)
	_view_tween.tween_property(_board_layout, "scale", target_scale, duration)

func _hide_hands() -> void:
	for property in ["_fan_container", "_enemy_hand_overlay"]:
		var hand := _game.get(property) as Control
		if is_instance_valid(hand) and hand.visible:
			if not _hidden_hands.has(hand):
				_hidden_hands.append(hand)
			hand.hide()

func _switch_side() -> void:
	if not active:
		return
	_opponent_side = not _opponent_side
	_game.call("_close_context_menu")
	_update_view()

func _show_play_options() -> void:
	if not active:
		return
	var selected := _game.get("selected_card") as Card
	if selected != null:
		_game.call("_on_hand_card_right_clicked", selected)

func prepare_options(panel: Control) -> void:
	panel.scale = Vector2.ONE * _ui_scale
	panel.add_theme_stylebox_override("panel", _plaque_style(Color(0.48, 0.44, 0.36)))
	_enlarge_option_controls(panel)

func _enlarge_option_controls(node: Node) -> void:
	if node is Button:
		node.custom_minimum_size.y = 48.0
		_theme_button(node)
	for child in node.get_children():
		_enlarge_option_controls(child)

func position_options(panel: Control) -> void:
	var panel_size := panel.size * panel.scale
	var viewport_size := get_viewport_rect().size
	panel.global_position = Vector2(
		maxf(4.0, (viewport_size.x - panel_size.x) * 0.5),
		maxf(4.0, (viewport_size.y - panel_size.y) * 0.5)
	)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
