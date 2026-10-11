extends Button

const WELL_SCENE := preload("res://scenes/ui/mana_well_visual.tscn")
const WELL_SIZE := Vector2(196.0, 216.0)

var _well: ManaWellVisual
var _available: bool = false
var _choice_caption: Label

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
	_choice_caption.position = Vector2(0.0, size.y * 0.5 + 24.0)
	_choice_caption.size = Vector2(size.x, 30.0)

func set_available(available: bool) -> void:
	_available = available
	_sync_visual_state()

func set_board_style(style: String) -> void:
	if _well != null:
		_well.snow_style = style == "snow"
