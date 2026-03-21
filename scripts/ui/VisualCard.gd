class_name VisualCard
extends PanelContainer

signal card_clicked(card: Card)
signal card_drag_released(card: Card, global_pos: Vector2, rotated: bool)

var card_data: Card
var _disabled: bool = false
var is_rotated: bool = false
var _picked_up: bool = false
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_ghost: Control = null

const CARD_WIDTH := 150
const CARD_HEIGHT := 100

func setup(p_card: Card) -> void:
	card_data = p_card
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_card_style()
	_build_content()

func _build_content() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var mana_lbl := Label.new()
	mana_lbl.text = str(card_data.mana_cost) + "M"
	mana_lbl.add_theme_font_size_override("font_size", 14)
	top_row.add_child(mana_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var type_lbl := Label.new()
	type_lbl.text = _type_abbrev()
	type_lbl.add_theme_font_size_override("font_size", 13)
	top_row.add_child(type_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var name_lbl := Label.new()
	name_lbl.text = card_data.card_name
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(name_lbl)

	match card_data.card_type:
		Card.CardType.CREATURE:
			var stats_lbl := Label.new()
			stats_lbl.text = "STR:%d RES:%d SPD:%d" % [
				card_data.strength, card_data.resilience, card_data.speed
			]
			stats_lbl.add_theme_font_size_override("font_size", 13)
			vbox.add_child(stats_lbl)
		Card.CardType.STRUCTURE:
			var res_lbl := Label.new()
			res_lbl.text = "RES:%d" % card_data.resilience
			res_lbl.add_theme_font_size_override("font_size", 10)
			vbox.add_child(res_lbl)
		Card.CardType.SPELL:
			var spd_lbl := Label.new()
			spd_lbl.text = "SPD:%d" % card_data.speed
			spd_lbl.add_theme_font_size_override("font_size", 10)
			vbox.add_child(spd_lbl)

func _apply_card_style() -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)

	match card_data.card_type:
		Card.CardType.CREATURE:
			style.bg_color = Color(0.13, 0.22, 0.42)
			style.border_color = Color(0.4, 0.65, 1.0)
		Card.CardType.SPELL:
			style.bg_color = Color(0.32, 0.08, 0.42)
			style.border_color = Color(0.75, 0.3, 1.0)
		Card.CardType.STRUCTURE:
			style.bg_color = Color(0.28, 0.18, 0.08)
			style.border_color = Color(0.75, 0.55, 0.3)
		_:
			style.bg_color = Color(0.15, 0.15, 0.15)
			style.border_color = Color(0.5, 0.5, 0.5)

	add_theme_stylebox_override("panel", style)

func _type_abbrev() -> String:
	match card_data.card_type:
		Card.CardType.CREATURE: return "C"
		Card.CardType.SPELL:    return "S"
		Card.CardType.STRUCTURE:return "ST"
		Card.CardType.EQUIPMENT:return "EQ"
		Card.CardType.HEX:      return "H"
		_:                      return "?"

func set_disabled(value: bool) -> void:
	_disabled = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	modulate.a = 0.45 if value else 1.0
	if value:
		_cancel_drag()
		_picked_up = false
		scale = Vector2(1.0, 1.0)

func set_highlighted(value: bool) -> void:
	modulate = Color(1.2, 1.2, 0.65) if value else Color.WHITE
	if not value:
		_picked_up = false
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _cancel_drag() -> void:
	if _dragging:
		_dragging = false
		modulate.a = 1.0
	if _drag_ghost and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
		_drag_ghost = null

func _toggle_rotation() -> void:
	is_rotated = not is_rotated
	var target_angle := 90.0 if is_rotated else 0.0
	if _dragging and _drag_ghost and is_instance_valid(_drag_ghost):
		# Ghost pivot is always the known card center (size is unreliable pre-layout)
		_drag_ghost.pivot_offset = Vector2(CARD_WIDTH, CARD_HEIGHT) / 2.0
		var tw := _drag_ghost.create_tween()
		tw.tween_property(_drag_ghost, "rotation_degrees", target_angle, 0.15)
	else:
		# Hand card: size is valid after layout
		pivot_offset = size / 2.0
		var tw := create_tween()
		tw.tween_property(self, "rotation_degrees", target_angle, 0.15)

func _gui_input(event: InputEvent) -> void:
	if _disabled:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_drag_offset = get_global_mouse_position() - global_position
			_picked_up = true
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
			card_clicked.emit(card_data)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if card_data.card_type == Card.CardType.CREATURE:
				_toggle_rotation()

func _input(event: InputEvent) -> void:
	if not _picked_up:
		return
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not _dragging:
				_start_drag()
			_update_ghost_position()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _dragging:
				_finish_drag()
			_picked_up = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _dragging:
			if card_data.card_type == Card.CardType.CREATURE:
				_toggle_rotation()
			get_viewport().set_input_as_handled()

func _update_ghost_position() -> void:
	if _drag_ghost and is_instance_valid(_drag_ghost):
		# Center ghost on cursor; pivot_offset = (CARD_WIDTH/2, CARD_HEIGHT/2) so rotation is around the center
		_drag_ghost.global_position = get_global_mouse_position() - Vector2(CARD_WIDTH, CARD_HEIGHT) / 2.0

func _start_drag() -> void:
	_dragging = true
	modulate.a = 0.15
	_drag_ghost = _build_drag_ghost()
	get_tree().current_scene.add_child(_drag_ghost)
	_update_ghost_position()

func _build_drag_ghost() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	panel.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	panel.pivot_offset = Vector2(CARD_WIDTH, CARD_HEIGHT) / 2.0
	panel.rotation_degrees = rotation_degrees
	panel.scale = Vector2(1.15, 1.15)
	panel.z_index = 100
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style:
		panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)
	var mana_lbl := Label.new()
	mana_lbl.text = str(card_data.mana_cost) + "M"
	mana_lbl.add_theme_font_size_override("font_size", 14)
	top_row.add_child(mana_lbl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var type_lbl := Label.new()
	type_lbl.text = _type_abbrev()
	type_lbl.add_theme_font_size_override("font_size", 13)
	top_row.add_child(type_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var name_lbl := Label.new()
	name_lbl.text = card_data.card_name
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(name_lbl)

	match card_data.card_type:
		Card.CardType.CREATURE:
			var stats_lbl := Label.new()
			stats_lbl.text = "STR:%d RES:%d SPD:%d" % [
				card_data.strength, card_data.resilience, card_data.speed
			]
			stats_lbl.add_theme_font_size_override("font_size", 13)
			vbox.add_child(stats_lbl)
		Card.CardType.STRUCTURE:
			var res_lbl := Label.new()
			res_lbl.text = "RES:%d" % card_data.resilience
			res_lbl.add_theme_font_size_override("font_size", 10)
			vbox.add_child(res_lbl)
		Card.CardType.SPELL:
			var spd_lbl := Label.new()
			spd_lbl.text = "SPD:%d" % card_data.speed
			spd_lbl.add_theme_font_size_override("font_size", 10)
			vbox.add_child(spd_lbl)

	return panel

func _finish_drag() -> void:
	_dragging = false
	modulate.a = 1.0
	var drop_pos := get_global_mouse_position()
	if _drag_ghost and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
		_drag_ghost = null
	card_drag_released.emit(card_data, drop_pos, is_rotated)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			if not _disabled and not _picked_up:
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)
		NOTIFICATION_MOUSE_EXIT:
			if not _picked_up:
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
