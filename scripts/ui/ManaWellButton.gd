extends Button

const WELL_SCENE := preload("res://scenes/ui/mana_well_visual.tscn")
const WELL_SIZE := Vector2(196.0, 216.0)

var _well: ManaWellVisual
var _available: bool = false
var _choice_caption: Label
var _choice_highlight_overlay: Control
var choice_highlight_amount: float = 0.0:
	set(value):
		choice_highlight_amount = value
		if _choice_highlight_overlay != null:
			_choice_highlight_overlay.queue_redraw()

func _ready() -> void:
	# Reserve the same real layout area as DrawDeckButton, including its height.
	custom_minimum_size = WELL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	for button_state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(button_state, StyleBoxEmpty.new())
	for font_state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color", "font_outline_color"]:
		add_theme_color_override(font_state, Color.TRANSPARENT)
	_well = WELL_SCENE.instantiate() as ManaWellVisual
	_well.state = ManaWellVisual.WellState.CLOSED
	_well.custom_minimum_size = Vector2.ZERO
	add_child(_well)
	_well.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_highlight_overlay = Control.new()
	_choice_highlight_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_choice_highlight_overlay)
	_choice_highlight_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_highlight_overlay.draw.connect(_draw_choice_highlight)
	_choice_caption = Label.new()
	_choice_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_caption.add_theme_font_override("font", ThemeDB.fallback_font)
	_choice_caption.add_theme_font_size_override("font_size", 22)
	_choice_caption.add_theme_color_override("font_color", Color(0.97, 0.89, 0.70))
	_choice_caption.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_choice_caption.add_theme_constant_override("outline_size", 4)
	add_child(_choice_caption)
	resized.connect(_sync_visual_state)
	mouse_entered.connect(_sync_visual_state)
	mouse_exited.connect(_sync_visual_state)
	focus_entered.connect(_sync_visual_state)
	focus_exited.connect(_sync_visual_state)
	_sync_visual_state()

func _draw_choice_highlight() -> void:
	if choice_highlight_amount <= 0.0 or not _available or disabled:
		return
	var snow_style := _well.snow_style
	var center := size * (Vector2(0.503, 0.630) if snow_style else Vector2(0.48, 0.47))
	var radius := size * (Vector2(0.325, 0.265) if snow_style else Vector2(0.385, 0.365))
	_choice_highlight_overlay.draw_set_transform(center, 0.0, Vector2(1.0, radius.y / radius.x))
	# Overlapping translucent bands feather the aura instead of outlining the rim.
	for band in range(12, 0, -1):
		var spread := float(band) * (2.0 + choice_highlight_amount * 0.5)
		_choice_highlight_overlay.draw_arc(Vector2.ZERO, radius.x, 0.0, TAU, 96, Color(0.25, 1.0, 0.48, 0.055 * choice_highlight_amount), spread, true)
	_choice_highlight_overlay.draw_set_transform(Vector2.ZERO)

func _process(_delta: float) -> void:
	# The match controller also changes disabled during prompts and network updates.
	_sync_visual_state()

func _sync_visual_state() -> void:
	if _well == null:
		return
	var next_state := ManaWellVisual.WellState.CLOSED
	if _available:
		next_state = ManaWellVisual.WellState.ACTIVATED if is_hovered() else ManaWellVisual.WellState.OPEN
	if _well.state != next_state:
		_well.state = next_state
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	tooltip_text = "Choose %s instead of drawing a card." % text if _available else "Choose extra mana at the start of your turn."
	_choice_caption.text = text
	_choice_caption.visible = _available and not disabled
	_choice_highlight_overlay.visible = _available and not disabled
	_choice_caption.position = Vector2(0.0, size.y * 0.5 + 24.0)
	_choice_caption.size = Vector2(size.x, 30.0)

func set_available(available: bool) -> void:
	_available = available
	_sync_visual_state()

func set_board_style(style: String) -> void:
	if _well != null:
		_well.snow_style = style == "snow"
