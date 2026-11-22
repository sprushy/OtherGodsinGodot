extends ColorRect

signal close_requested

const RankedProgressionScript = preload("res://scripts/server/RankedProgression.gd")
const TITLE_FONT = preload("res://fonts/custom_ui/Norsebold.otf")
const GOLD := Color("f1ce89")
const TEXT := Color("edf0f6")
const MUTED := Color("acb9ce")

var _panel: PanelContainer
var _scroll: ScrollContainer
var _progress_label: Label
var _promotion_label: Label
var _rank_cells: Dictionary[String, PanelContainer] = {}
var _promotion_targets: Dictionary[String, String] = {}
var _current_rank := ""
var _selected_format := 1
var _progress_by_format: Dictionary = {}
var _empty_message := ""
var _cell_style := _style(Color("1d283b"), Color("39495f"), 1, 7)
var _current_style := _style(Color("4c3a22"), GOLD, 2, 7)

func _ready() -> void:
	name = "RankedLadderView"
	color = Color(0.025, 0.035, 0.065, 0.9)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	var panel_style := _style(Color("101725"), Color("786441"), 1, 14)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		panel_style.set_content_margin(side, 16)
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _label(header, "Ranked Ladder", 32, GOLD)
	title.add_theme_font_override("font", TITLE_FONT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(72, 36)
	close_button.pressed.connect(close_requested.emit)
	header.add_child(close_button)
	close_button.grab_focus()

	var formats := HBoxContainer.new()
	formats.add_theme_constant_override("separation", 8)
	content.add_child(formats)
	var format_group := ButtonGroup.new()
	var focus_order: Array[Control] = [close_button]
	for best_of in [1, 3]:
		var format_button := Button.new()
		format_button.text = "Bo%d" % best_of
		format_button.custom_minimum_size = Vector2(72, 32)
		format_button.toggle_mode = true
		format_button.button_group = format_group
		format_button.set_pressed_no_signal(best_of == _selected_format)
		format_button.pressed.connect(_select_format.bind(best_of))
		formats.add_child(format_button)
		focus_order.append(format_button)

	var progress_details := VBoxContainer.new()
	progress_details.add_theme_constant_override("separation", 3)
	content.add_child(progress_details)
	_progress_label = _label(progress_details, "", 16, TEXT)
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_promotion_label = _label(progress_details, "", 16, GOLD)
	_promotion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_promotion_label.hide()
	content.add_child(HSeparator.new())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.focus_mode = Control.FOCUS_ALL
	content.add_child(_scroll)
	focus_order.append(_scroll)
	for i in range(focus_order.size()):
		var control := focus_order[i]
		control.focus_next = control.get_path_to(focus_order[(i + 1) % focus_order.size()])
		control.focus_previous = control.get_path_to(focus_order[posmod(i - 1, focus_order.size())])
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 7)
	_scroll.add_child(rows)
	var next_league_rank := ""
	var divisions: Array = RankedProgressionScript.DIVISIONS
	for league_index in range(RankedProgressionScript.LEAGUES.size() - 1, -1, -1):
		var league_name: String = RankedProgressionScript.LEAGUES[league_index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		rows.add_child(row)
		var league_label := _label(row, league_name, 17, MUTED)
		league_label.custom_minimum_size.x = 100
		if league_index == RankedProgressionScript.DIVINE:
			_add_rank_cell(row, league_name, "Open-ended")
			next_league_rank = league_name
			continue
		for division_index in range(divisions.size()):
			var division: String = divisions[division_index]
			var rank_name := "%s %s" % [league_name, division]
			_add_rank_cell(row, rank_name, division)
			var next_division := division_index + 1
			_promotion_targets[rank_name] = (
				"%s %s" % [league_name, divisions[next_division]] if next_division < divisions.size() else next_league_rank
			)
		next_league_rank = "%s %s" % [league_name, divisions[0]]

	resized.connect(_fit_panel)
	_fit_panel()

func update_progress(bo1_progress: Dictionary, bo3_progress: Dictionary, empty_message: String) -> void:
	_progress_by_format = {1: bo1_progress, 3: bo3_progress}
	_empty_message = empty_message
	_render_progress()

func _select_format(best_of: int) -> void:
	_selected_format = best_of
	_render_progress(true)

func _render_progress(scroll_to_rank: bool = false) -> void:
	var progress: Dictionary = _progress_by_format.get(_selected_format, {})
	var rank := str(progress.get("rank_name", ""))
	if rank != _current_rank:
		if _rank_cells.has(_current_rank):
			_rank_cells[_current_rank].add_theme_stylebox_override("panel", _cell_style)
		_current_rank = rank
		if _rank_cells.has(rank):
			_rank_cells[rank].add_theme_stylebox_override("panel", _current_style)
			scroll_to_rank = true
	if rank.is_empty():
		_progress_label.text = _empty_message
		_promotion_label.hide()
		return
	var stars := int(progress.get("stars", 0))
	var required := int(progress.get("stars_required", 0))
	var stars_text := "%d / %d stars" % [stars, required] if required > 0 else "%d %s stars" % [stars, rank]
	_progress_label.text = "Your rank  ·  %s  ·  %s" % [rank, stars_text]
	var promotion_text := ""
	if _promotion_targets.has(rank) and required > stars:
		var remaining := required - stars
		var unit := "star" if remaining == 1 else "stars"
		promotion_text = "%d %s to %s" % [remaining, unit, _promotion_targets[rank]]
	elif rank == RankedProgressionScript.LEAGUES[RankedProgressionScript.DIVINE]:
		promotion_text = "Highest rank reached"
	_promotion_label.text = promotion_text
	_promotion_label.visible = not promotion_text.is_empty()
	if scroll_to_rank:
		await get_tree().process_frame
		if is_visible_in_tree() and _rank_cells.has(_current_rank):
			_scroll.ensure_control_visible(_rank_cells[_current_rank])

func _add_rank_cell(row: HBoxContainer, rank_name: String, display_text: String) -> void:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(36, 38)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_stylebox_override("panel", _cell_style)
	cell.tooltip_text = rank_name
	row.add_child(cell)
	_label(cell, display_text, 16, TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_cells[rank_name] = cell

func _label(parent: Node, text: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label

func _style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style

func _fit_panel() -> void:
	_panel.custom_minimum_size = Vector2(
		clampf(size.x - 32.0, 0.0, 620.0),
		clampf(size.y - 32.0, 0.0, 550.0)
	)
