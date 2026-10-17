extends Control
## Presentation for the existing move timer and end-turn button. Owns no game clock.

const TOWER_TEXTURE := preload("res://images/ui/clocktower/turn_clocktower.png")
const BELL_TEXTURE := preload("res://images/ui/clocktower/end_turn_bell.png")
const PLAQUE_TEXTURE := preload("res://images/ui/clocktower/stone_plaque.png")
# Solid stone bounds; get_used_rect() also includes faint alpha far outside it.
const PLAQUE_REGION := Rect2(12.0, 148.0, 1960.0, 492.0)
const BELL_SOUND := preload("res://audio/turn_bell.mp3")
const ART_SIZE := Vector2(168.0, 252.0)
const ROOF_SPLIT_Y := 86.0
const NAME_BAND_HEIGHT := 30.0
const DISPLAY_SIZE := ART_SIZE + Vector2(0.0, NAME_BAND_HEIGHT)
const DIAL_CENTER := Vector2(0.50, 0.454) * ART_SIZE + Vector2(0.0, NAME_BAND_HEIGHT)
const DIAL_RADIUS := 23.0
const BELL_RECT := Rect2(56.0, 154.0 + NAME_BAND_HEIGHT, 56.0, 56.0)
const NAME_RECT := Rect2(47.0, ROOF_SPLIT_Y + 2.0, 74.0, 26.0)
const CAPTION_RECT := Rect2(44.0, 212.0 + NAME_BAND_HEIGHT, 80.0, 26.0)
const GOLD := Color(0.94, 0.77, 0.43)
const SILVER := Color(0.80, 0.86, 0.92)

var _button: Button
var _bell: TextureRect
var _clock_label: Label
var _caption: Label
var _caption_panel: PanelContainer
var _name_panel: PanelContainer
var _name_label: Label
var _name_style: StyleBoxTexture
var _bell_player: AudioStreamPlayer
var _ring_tween: Tween
var _remaining_msec: int = -1
var _budget_msec: int = 180000
var _running := false
var _available := false
var _hovered := false
var _opponent_turn := false
var _status := ""


func _init() -> void:
	size = DISPLAY_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _ready() -> void:
	_bell = TextureRect.new()
	_bell.name = "BellArt"
	_bell.texture = BELL_TEXTURE
	_bell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bell.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bell.position = BELL_RECT.position
	_bell.size = BELL_RECT.size
	_bell.pivot_offset = Vector2(BELL_RECT.size.x * 0.5, 3.0)
	add_child(_bell)
	_clock_label = _make_label("Countdown", 19, GOLD)
	_clock_label.position = DIAL_CENTER - Vector2(32.0, 16.0)
	_clock_label.size = Vector2(64.0, 32.0)
	_name_panel = PanelContainer.new()
	_name_panel.name = "TurnOwnerPlaque"
	_name_panel.position = NAME_RECT.position
	_name_panel.size = NAME_RECT.size
	_name_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_name_style = StyleBoxTexture.new()
	var plaque_atlas := AtlasTexture.new()
	plaque_atlas.atlas = PLAQUE_TEXTURE
	plaque_atlas.region = PLAQUE_REGION
	_name_style.texture = plaque_atlas
	_name_style.content_margin_left = 6.0
	_name_style.content_margin_right = 6.0
	_name_style.content_margin_top = 4.0
	_name_style.content_margin_bottom = 4.0
	_name_panel.add_theme_stylebox_override("panel", _name_style)
	add_child(_name_panel)
	_name_label = _make_label("TurnOwnerName", 11, GOLD)
	_name_label.add_theme_constant_override("outline_size", 1)
	_name_label.add_theme_color_override("font_shadow_color", Color(0.10, 0.09, 0.07, 0.9))
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_label.reparent(_name_panel, false)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption_panel = PanelContainer.new()
	_caption_panel.name = "EndTurnPlaque"
	_caption_panel.position = CAPTION_RECT.position
	_caption_panel.size = CAPTION_RECT.size
	_caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_panel.add_theme_stylebox_override("panel", _name_style)
	add_child(_caption_panel)
	_caption = _make_label("BellCaption", 11, GOLD)
	_caption.add_theme_constant_override("outline_size", 1)
	_caption.add_theme_color_override("font_shadow_color", Color(0.10, 0.09, 0.07, 0.9))
	_caption.add_theme_constant_override("shadow_offset_y", 1)
	_caption.text = "End Turn"
	_caption.reparent(_caption_panel, false)
	_bell_player = AudioStreamPlayer.new()
	_bell_player.name = "BellSound"
	_bell_player.stream = BELL_SOUND
	_bell_player.bus = "SFX"
	add_child(_bell_player)
	_update_display()


func _make_label(node_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.03))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	return label


func bind_end_turn_button(button: Button) -> void:
	if _button != button:
		_button = button
		_button.mouse_entered.connect(_set_hovered.bind(true))
		_button.mouse_exited.connect(_set_hovered.bind(false))
		_button.focus_entered.connect(_set_hovered.bind(true))
		_button.focus_exited.connect(_set_hovered.bind(false))
		_button.pressed.connect(_ring_bell)
	if _button.get_parent() != self:
		_button.reparent(self, false)
	_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_button.custom_minimum_size = Vector2.ZERO
	_button.text = ""
	_button.icon = null
	_button.tooltip_text = "Ring the bell to end your turn"
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(8)
	_button.add_theme_stylebox_override("focus", focus)
	# One existing button covers the bell and End Turn plaque, so either target
	# emits the same end-turn signal and bell feedback exactly once.
	var click_rect := BELL_RECT.grow(3.0).merge(CAPTION_RECT)
	_button.position = click_rect.position
	_button.size = click_rect.size
	_button.move_to_front()


func set_turn_state(remaining_msec: int, budget_msec: int, running: bool, status: String, player_name: String, opponent_turn: bool, turn_number: int) -> void:
	var available := is_instance_valid(_button) and _button.visible and not _button.disabled
	# Refresh once per displayed second; the authoritative controller owns pauses/bonuses.
	var seconds := int(ceil(maxi(0, remaining_msec) / 1000.0))
	var old_seconds := int(ceil(maxi(0, _remaining_msec) / 1000.0))
	var changed := seconds != old_seconds or (remaining_msec < 0) != (_remaining_msec < 0) \
		or running != _running or available != _available or _status != status \
		or opponent_turn != _opponent_turn or _name_label.text != player_name
	_remaining_msec = remaining_msec
	_budget_msec = maxi(1, budget_msec)
	_running = running
	_available = available
	_opponent_turn = opponent_turn
	_status = status
	_name_label.text = player_name
	_name_panel.tooltip_text = "Turn %d — %s's turn" % [turn_number, player_name]
	if changed:
		_update_display()


func _update_display() -> void:
	if _clock_label == null:
		return
	var seconds := int(ceil(maxi(0, _remaining_msec) / 1000.0))
	_clock_label.text = "%d:%02d" % [int(seconds / 60.0), seconds % 60] if _remaining_msec >= 0 else "—:—"
	_clock_label.add_theme_color_override("font_color", _clock_color())
	_caption.add_theme_color_override("font_color", _turn_color())
	_name_label.add_theme_color_override("font_color", _turn_color())
	_clock_label.tooltip_text = "Turn timer paused" if _remaining_msec >= 0 and not _running else "Time left to act"
	_clock_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_bell.modulate = Color(1.30, 1.16, 0.94) if _available and _hovered else (Color(1.10, 1.04, 0.94) if _available else Color(0.64, 0.64, 0.64))
	_caption_panel.modulate = Color.WHITE if _available else Color(0.68, 0.68, 0.68)
	queue_redraw()


func _turn_color() -> Color:
	return SILVER if _opponent_turn else GOLD


func _clock_color() -> Color:
	if _remaining_msec < 0:
		return SILVER if _opponent_turn else Color(0.60, 0.63, 0.62)
	if _opponent_turn:
		return SILVER
	if _remaining_msec <= 10000:
		return Color(1.0, 0.36, 0.24)
	if _remaining_msec <= 30000:
		return Color(1.0, 0.65, 0.22)
	return _turn_color()


func _draw() -> void:
	# Insert a short stone band under the roof without stretching the clock/bell.
	var source_scale := TOWER_TEXTURE.get_size() / ART_SIZE
	draw_texture_rect_region(TOWER_TEXTURE,
		Rect2(0.0, 0.0, ART_SIZE.x, ROOF_SPLIT_Y),
		Rect2(0.0, 0.0, TOWER_TEXTURE.get_width(), ROOF_SPLIT_Y * source_scale.y))
	draw_texture_rect_region(TOWER_TEXTURE,
		Rect2(0.0, ROOF_SPLIT_Y, ART_SIZE.x, NAME_BAND_HEIGHT),
		Rect2(0.0, (ROOF_SPLIT_Y - 4.0) * source_scale.y, TOWER_TEXTURE.get_width(), 4.0 * source_scale.y))
	draw_texture_rect_region(TOWER_TEXTURE,
		Rect2(0.0, ROOF_SPLIT_Y + NAME_BAND_HEIGHT, ART_SIZE.x, ART_SIZE.y - ROOF_SPLIT_Y),
		Rect2(0.0, ROOF_SPLIT_Y * source_scale.y, TOWER_TEXTURE.get_width(), (ART_SIZE.y - ROOF_SPLIT_Y) * source_scale.y))
	if _remaining_msec >= 0:
		var fraction := clampf(float(_remaining_msec) / _budget_msec, 0.0, 1.0)
		draw_arc(DIAL_CENTER, DIAL_RADIUS, -PI * 0.5, TAU - PI * 0.5, 64, Color(0.31, 0.28, 0.20, 0.65), 2.0, true)
		if fraction > 0.0:
			draw_arc(DIAL_CENTER, DIAL_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * fraction, 64, _clock_color(), 2.0, true)
		if not _running:
			for offset_x in [-3.0, 2.0]:
				draw_line(DIAL_CENTER + Vector2(offset_x, 14.0), DIAL_CENTER + Vector2(offset_x, 19.0), _turn_color(), 2.0, true)


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_update_display()


func _ring_bell() -> void:
	if DisplayServer.get_name() != "headless":
		_bell_player.play()
	if is_instance_valid(_ring_tween):
		_ring_tween.kill()
	_ring_tween = create_tween()
	_ring_tween.set_trans(Tween.TRANS_SINE)
	_ring_tween.tween_property(_bell, "rotation", -0.22, 0.07)
	_ring_tween.tween_property(_bell, "rotation", 0.18, 0.12)
	_ring_tween.tween_property(_bell, "rotation", -0.11, 0.12)
	_ring_tween.tween_property(_bell, "rotation", 0.06, 0.10)
	_ring_tween.tween_property(_bell, "rotation", 0.0, 0.10)
