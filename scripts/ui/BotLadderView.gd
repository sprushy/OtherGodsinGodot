extends ColorRect

signal close_requested
signal refresh_requested
signal page_requested(page: int)
signal deck_requested(list_id: String)

const TITLE_FONT = preload("res://fonts/custom_ui/Norsebold.otf")
const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")
const GOLD := Color("f1ce89")
const MUTED := Color("acb9ce")

var _panel: PanelContainer
var _refresh_button: Button
var _close_button: Button
var _status: Label
var _table: Tree
var _format: OptionButton
var _pagination: HBoxContainer
var _previous_page: Button
var _next_page: Button
var _page_label: Label
var _back_button: Button
var _deck_contents: RichTextLabel
var _deck_timeout: Timer
var _selected_list_id := ""
var _paging_supported := false
var _current_page := 0
var _last_page := 0

func _ready() -> void:
	name = "BotLadderView"
	color = Color(0.025, 0.035, 0.065, 0.9)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101725")
	style.border_color = Color("786441")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 16)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	_panel.add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)
	var title := Label.new()
	title.text = "Ranked Ladder"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)
	_format = OptionButton.new()
	_format.add_item("Bo1", 1)
	_format.add_item("Bo3", 3)
	_format.select(0)
	_format.hide()
	_format.item_selected.connect(func(_index: int) -> void:
		_current_page = 0
		_last_page = 0
		_table.clear()
		page_requested.emit(0)
	)
	header.add_child(_format)
	_refresh_button = _add_button(header, "Refresh", refresh_requested.emit)
	_back_button = _add_button(header, "Back to ladder", close_deck)
	_back_button.hide()
	_close_button = _add_button(header, "Close", close_requested.emit)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", MUTED)
	body.add_child(_status)

	_table = Tree.new()
	_table.columns = 4
	_table.hide_root = true
	_table.set_column_titles_visible(true)
	_table.set_column_title(0, "Name")
	_table.set_column_title(1, "Stars")
	_table.set_column_title(2, "Rank")
	_table.set_column_title(3, "Player type")
	_table.set_column_custom_minimum_width(0, 170)
	for column in [1, 2, 3]:
		_table.set_column_expand(column, false)
		_table.set_column_custom_minimum_width(column, [64, 130, 155][column - 1])
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table.select_mode = Tree.SELECT_ROW
	_table.item_selected.connect(_open_selected_deck)
	_table.item_activated.connect(_open_selected_deck)
	body.add_child(_table)
	_pagination = HBoxContainer.new()
	_pagination.alignment = BoxContainer.ALIGNMENT_CENTER
	_pagination.hide()
	body.add_child(_pagination)
	_previous_page = _add_button(_pagination, "Previous", func() -> void: page_requested.emit(_current_page - 1))
	_page_label = Label.new()
	_pagination.add_child(_page_label)
	_next_page = _add_button(_pagination, "Next", func() -> void: page_requested.emit(_current_page + 1))
	_deck_contents = RichTextLabel.new()
	_deck_contents.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deck_contents.focus_mode = Control.FOCUS_ALL
	_deck_contents.hide()
	body.add_child(_deck_contents)
	_deck_timeout = Timer.new()
	_deck_timeout.one_shot = true
	_deck_timeout.wait_time = 5.0
	_deck_timeout.timeout.connect(func() -> void:
		_deck_contents.text = "The lobby did not respond. Go back and select the list to retry."
	)
	add_child(_deck_timeout)
	_close_button.grab_focus()
	resized.connect(_fit_panel)
	_fit_panel()

func set_status(message: String, can_refresh: bool, clear_table: bool = false) -> void:
	_status.text = message
	_status.visible = not message.is_empty() and _selected_list_id.is_empty()
	_refresh_button.disabled = not can_refresh
	if clear_table:
		close_deck()
		_table.clear()
		_current_page = 0
		_last_page = 0
	_previous_page.disabled = not can_refresh or _current_page == 0
	_next_page.disabled = not can_refresh or _current_page >= _last_page
	_pagination.visible = _last_page > 0 and _selected_list_id.is_empty()
	_page_label.text = "Page %d of %d" % [_current_page + 1, _last_page + 1]
	if _selected_list_id.is_empty():
		_set_ladder_focus_order()

func set_paging_supported(supported: bool) -> void:
	_paging_supported = supported
	_format.visible = supported and _selected_list_id.is_empty()
	if not supported:
		_format.select(0)
		_current_page = 0
		_last_page = 0

func get_best_of() -> int:
	return _format.get_selected_id()

func get_current_page() -> int:
	return _current_page

func show_summary(summary: Dictionary) -> void:
	_table.clear()
	_current_page = int(summary.get("page", 0))
	_last_page = int(summary.get("last_page", 0))
	var entries: Array = summary.get("ladder", [])
	var root := _table.create_item()
	var has_bot := false
	for entry: Dictionary in entries:
		var row := _table.create_item(root)
		var is_bot := bool(entry.get("is_bot", false))
		row.set_text(0, str(entry["name"]))
		row.set_tooltip_text(0, str(entry["name"]))
		row.set_text(1, "%d ★" % int(entry["stars"]))
		row.set_text(2, str(entry["rank"]))
		row.set_text(3, "Bot" if is_bot else "Player")
		if is_bot:
			row.set_metadata(0, str(entry["list_id"]))
			row.set_custom_color(0, GOLD)
			has_bot = true
	var message := ""
	if entries.is_empty():
		message = "No ladder entries yet."
	elif not _paging_supported:
		message = "Best-of-one ladder. Select a bot to see its deck." if has_bot else "Best-of-one ladder."
	elif has_bot:
		message = "Select a bot to see its deck."
	set_status(message, true)

func _open_selected_deck() -> void:
	var selected := _table.get_selected()
	if selected == null or not _selected_list_id.is_empty():
		return
	var list_id = selected.get_metadata(0)
	if not list_id is String or list_id.is_empty():
		return
	_selected_list_id = list_id
	_deck_contents.text = "Loading %s…" % selected.get_text(0)
	_deck_contents.show()
	_back_button.show()
	_back_button.grab_focus()
	_table.hide()
	_status.hide()
	_refresh_button.hide()
	_format.hide()
	_pagination.hide()
	_set_focus_order([_back_button, _close_button, _deck_contents])
	_deck_timeout.start()
	deck_requested.emit(list_id)

func show_deck(list_id: String, deck: Dictionary) -> void:
	if _selected_list_id.is_empty() or list_id != _selected_list_id:
		return
	_deck_timeout.stop()
	if deck.is_empty():
		_deck_contents.text = "This list is no longer available. Go back and refresh the ladder."
		return
	_deck_contents.clear()
	_deck_contents.push_color(GOLD)
	_deck_contents.add_text(str(deck["name"]) + "\n\n")
	_deck_contents.pop()
	_add_card_section("Main deck", deck["cards"])
	var reinforcements: Dictionary = deck["reinforcements"]
	if not reinforcements.is_empty():
		_add_card_section("Reinforcements", reinforcements)
	var slots := TiamatScript.get_slot_card_names_from_setup(deck["special_setup"])
	var setup_cards := {}
	for card_name in slots:
		if not str(card_name).is_empty():
			setup_cards[card_name] = int(setup_cards.get(card_name, 0)) + 1
	if not setup_cards.is_empty():
		_add_card_section("Tiamat's power slots", setup_cards)
	_deck_contents.scroll_to_line(0)

func _add_card_section(heading: String, cards: Dictionary) -> void:
	var names := cards.keys()
	names.sort()
	var count := 0
	for copies in cards.values():
		count += int(copies)
	_deck_contents.push_color(GOLD)
	_deck_contents.add_text("%s (%d cards)\n" % [heading, count])
	_deck_contents.pop()
	for card_name in names:
		_deck_contents.add_text("%d × %s\n" % [cards[card_name], card_name])
	_deck_contents.add_text("\n")

func close_deck() -> bool:
	if _selected_list_id.is_empty():
		return false
	_selected_list_id = ""
	_deck_timeout.stop()
	_deck_contents.hide()
	_back_button.hide()
	_status.visible = not _status.text.is_empty()
	_refresh_button.show()
	_format.visible = _paging_supported
	_pagination.visible = _last_page > 0
	_table.deselect_all()
	_table.show()
	_set_ladder_focus_order()
	_table.grab_focus()
	return true

func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(72, 36)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _set_ladder_focus_order() -> void:
	var controls: Array[Control] = []
	if _format.visible:
		controls.append(_format)
	if not _refresh_button.disabled:
		controls.append(_refresh_button)
	controls.append_array([_close_button, _table])
	if _pagination.visible:
		for button in [_previous_page, _next_page]:
			if not button.disabled:
				controls.append(button)
	_set_focus_order(controls)

func _set_focus_order(controls: Array[Control]) -> void:
	for i in range(controls.size()):
		var control := controls[i]
		control.focus_next = control.get_path_to(controls[(i + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[posmod(i - 1, controls.size())])

func _fit_panel() -> void:
	_panel.custom_minimum_size = Vector2(clampf(size.x - 32.0, 0.0, 860.0), clampf(size.y - 32.0, 0.0, 680.0))
