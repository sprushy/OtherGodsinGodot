extends ColorRect

signal close_requested
signal save_requested(best_of: int, portrait: Dictionary)

const Catalog = preload("res://scripts/core/RankBadgeCatalog.gd")
const Badge = preload("res://scripts/ui/RankBadge.gd")

var _best_of: int
var _rank: String
var _league: int
var _cards: Dictionary
var _portrait: Dictionary
var _card_list: ItemList
var _art_options: OptionButton
var _preview: Badge
var _zoom: HSlider
var _save: Button
var _status: Label
var _save_timeout: Timer
var _dragging := false
var _reset_requested := false

func _init(best_of: int, rank: String, portrait: Dictionary) -> void:
	_best_of = best_of
	_rank = rank
	_league = Catalog.league_for_rank(rank)
	_cards = Catalog.get_cards(_league)
	_portrait = Catalog.resolve_portrait(_league, portrait)

func _ready() -> void:
	color = Color(0.025, 0.035, 0.065, 0.93)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101725")
	style.border_color = Color("92774b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)

	var title := Label.new()
	title.text = "%s Badge" % _rank.get_slice(" ", 0)
	title.add_theme_font_size_override("font_size", 26)
	body.add_child(title)
	var columns := HBoxContainer.new()
	columns.custom_minimum_size.y = 250
	columns.add_theme_constant_override("separation", 14)
	body.add_child(columns)
	_card_list = ItemList.new()
	_card_list.custom_minimum_size.x = 190
	_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_card_list)
	var names := _cards.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	for card_name: String in names:
		_card_list.add_item(card_name)
		_card_list.set_item_tooltip(_card_list.item_count - 1, card_name)
	_card_list.item_selected.connect(_select_card)

	var editor := VBoxContainer.new()
	editor.custom_minimum_size.x = 184
	editor.add_theme_constant_override("separation", 8)
	columns.add_child(editor)
	_preview = Badge.new()
	_preview.custom_minimum_size = Vector2(148, 148)
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_preview.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_preview.gui_input.connect(_on_preview_input)
	_preview.mouse_exited.connect(func() -> void: _dragging = false)
	editor.add_child(_preview)
	_art_options = OptionButton.new()
	_art_options.item_selected.connect(_select_art)
	editor.add_child(_art_options)
	var zoom_label := Label.new()
	zoom_label.text = "Drag to center · Zoom"
	editor.add_child(zoom_label)
	_zoom = HSlider.new()
	_zoom.min_value = 1.0
	_zoom.max_value = Catalog.MAX_ZOOM
	_zoom.step = 0.01
	_zoom.value_changed.connect(_set_zoom)
	editor.add_child(_zoom)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("ffb7a2"))
	body.add_child(_status)
	_status.hide()
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(buttons)
	_add_button(buttons, "Use Default", _use_default)
	_add_button(buttons, "Cancel", close_requested.emit)
	_save = _add_button(buttons, "Save", _submit)
	_save_timeout = Timer.new()
	_save_timeout.one_shot = true
	_save_timeout.wait_time = 8.0
	_save_timeout.timeout.connect(show_save_error.bind("The lobby did not respond. Try saving again."))
	add_child(_save_timeout)
	_show_selection()
	_card_list.grab_focus()

func _add_button(parent: Control, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _select_card(index: int) -> void:
	var card_name := _card_list.get_item_text(index)
	if card_name == _portrait.get("card"):
		return
	_reset_requested = false
	_portrait = Catalog.validate_portrait(_league, {"card": card_name})
	_show_selection()

func _show_selection() -> void:
	if _portrait.is_empty():
		_save.disabled = true
		return
	for index in range(_card_list.item_count):
		if _card_list.get_item_text(index) == _portrait["card"]:
			_card_list.select(index)
			_card_list.ensure_current_is_visible()
			break
	var card: Card = _cards[_portrait["card"]]
	var paths := Catalog.art_paths(card)
	_art_options.clear()
	for index in range(paths.size()):
		_art_options.add_item("Artwork %d" % (index + 1))
	_art_options.select(_portrait["art"])
	_art_options.visible = paths.size() > 1
	_zoom.set_value_no_signal(_portrait["zoom"])
	_update_preview()

func _select_art(index: int) -> void:
	_reset_requested = false
	_portrait.merge({"art": index, "x": 0.5, "y": 0.5, "zoom": 1.0}, true)
	_zoom.set_value_no_signal(1.0)
	_update_preview()

func _set_zoom(zoom: float) -> void:
	_reset_requested = false
	_portrait["zoom"] = zoom
	_update_preview()

func _on_preview_input(event: InputEvent) -> void:
	if _save.disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_preview.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_pan(event.relative)
	elif event is InputEventScreenDrag:
		_pan(event.relative)
	elif event is InputEventMagnifyGesture:
		_zoom.value *= event.factor
		_preview.accept_event()

func _pan(relative: Vector2) -> void:
	var center := _preview.get_crop_center_after_drag(relative)
	_reset_requested = false
	_portrait["x"] = center.x
	_portrait["y"] = center.y
	_update_preview()
	_preview.accept_event()

func _update_preview() -> void:
	_preview.set_badge(_rank, _portrait)

func _use_default() -> void:
	if _save.disabled:
		return
	_reset_requested = true
	_portrait = Catalog.resolve_portrait(_league, {})
	_show_selection()

func _submit() -> void:
	_save.disabled = true
	_card_list.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	_card_list.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_art_options.disabled = true
	_zoom.editable = false
	_status.text = "Saving…"
	_status.show()
	_save_timeout.start()
	save_requested.emit(_best_of, {} if _reset_requested else _portrait.duplicate())

func show_save_error(message: String) -> void:
	_save_timeout.stop()
	_save.disabled = _portrait.is_empty()
	_card_list.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	_card_list.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	_art_options.disabled = false
	_zoom.editable = true
	_status.text = message
	_status.show()
