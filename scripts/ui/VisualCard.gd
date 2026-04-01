class_name VisualCard
extends PanelContainer

signal card_clicked(card: Card)
signal card_right_clicked(card: Card)
signal card_drag_released(card: Card, global_pos: Vector2, rotated: bool, stealth: bool)

var card_data: Card
var _disabled: bool = false
var is_rotated: bool = false
var _picked_up: bool = false
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_ghost: Control = null
var _drag_parent: Node = null
var _drag_index: int = -1
var _rot_ghost: Control = null
var _rot_tween: Tween = null
var _drag_rot_tween: Tween = null
var _drag_ghost_pivot: Vector2 = Vector2.ZERO
var _drag_target_rotation: float = 0.0
var _drag_stealth: bool = false
const _DRAG_PREPARE_OVERLAY_NAME := "DragPrepareOverlay"
const _DRAG_ROT_SPEED: float = 600.0  # degrees per second (90° in 0.15 s)
var _base_z_index: int = 0
const _HOVER_PANEL_Z_INDEX := 2000
const _HOVER_PANEL_WIDTH := 280.0
const _HOVER_PANEL_MAX_HEIGHT := 360.0
var _hover_panel: Control = null
var _hover_viewer: Player = null
var _waiting_on_priority: bool = false
var _priority_response_available: bool = false
var _blot_summonable: bool = false
var _blot_selected: bool = false
var _hover_preview_when_disabled: bool = false
var _display_mana_cost: int = -1
var _display_cost_adjustment_lines: Array[String] = []
var _ghostly_hand_proxy: bool = false
var _click_only: bool = false
var _dim_when_disabled: bool = true

func set_base_z_index(idx: int) -> void:
	_base_z_index = idx
	z_index = idx

const CARD_WIDTH := 150
const CARD_HEIGHT := 100

var _card_width: int = CARD_WIDTH
var _card_height: int = CARD_HEIGHT
var _inner: PanelContainer = null
var _art_rect: TextureRect = null
var _disabled_overlay: ColorRect = null
var _power_lock_overlay: TextureRect = null
const _POWER_LOCK_TEXTURE := preload("res://images/Norse Power Lock.png")

func setup(
	p_card: Card,
	width: int = CARD_WIDTH,
	height: int = CARD_HEIGHT,
	display_mana_cost: int = -1,
	display_cost_adjustment_lines: Array[String] = []
) -> void:
	card_data = p_card
	_card_width = width
	_card_height = height
	_display_mana_cost = display_mana_cost
	_display_cost_adjustment_lines = display_cost_adjustment_lines.duplicate()
	# Pre-compute natural height so get_combined_minimum_size() is reliable
	# before any layout pass runs (avoids RichTextLabel width=0 sizing explosion).
	var natural_h: float = _card_height if _card_height > 0 else _compute_natural_height()
	custom_minimum_size = Vector2(_card_width, natural_h)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_content()
	if card_data.exhausted_art_path != "":
		card_data.art_updated.connect(_on_art_updated)

func _get_display_mana_cost() -> int:
	return _display_mana_cost if _display_mana_cost >= 0 else card_data.mana_cost

func _compute_natural_height() -> float:
	var h := 22.0  # name + mana row
	if card_data.art_path != "":
		var tex: Texture2D = load(card_data.art_path)
		if tex:
			h += _card_width * float(tex.get_height()) / float(tex.get_width())
	if not (card_data.card_type == Card.CardType.CREATURE and card_data.is_god):
		h += 18.0  # stats / speed / resilience row
	if card_data.ability_text != "":
		var raw := card_data.ability_text.replace("[b]", "").replace("[/b]", "")
		var est_lines: int = max(2, ceili(float(raw.length()) / 28.0))
		h += float(est_lines) * 14.0
	return h

func _should_show_power_lock_overlay() -> bool:
	return card_data != null \
		and card_data.card_type == Card.CardType.POWER \
		and card_data.is_face_down

func _make_power_lock_overlay() -> TextureRect:
	if _POWER_LOCK_TEXTURE == null:
		return null
	var overlay := TextureRect.new()
	overlay.texture = _POWER_LOCK_TEXTURE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return overlay

func _build_art_node() -> TextureRect:
	if card_data.art_path == "":
		return null
	var tex: Texture2D = load(card_data.art_path)
	if tex == null:
		return null
	var art := TextureRect.new()
	art.texture = tex
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.custom_minimum_size = Vector2(_card_width, _card_width * float(tex.get_height()) / float(tex.get_width()))
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art_rect = art
	return art

func _on_art_updated(new_path: String) -> void:
	if _art_rect == null or not is_instance_valid(_art_rect):
		return
	var tex: Texture2D = load(new_path)
	if tex:
		_art_rect.texture = tex
		call_deferred("_layout_power_lock_overlay")

func _make_name_label() -> Label:
	var name_lbl := Label.new()
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.custom_minimum_size = Vector2(_card_width - 8, 0)
	name_lbl.text = card_data.get_display_name_for_control(name_lbl)
	return name_lbl

func _populate_vbox(vbox: VBoxContainer) -> void:
	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	if not card_data.name_at_bottom:
		top_row.add_child(_make_name_label())

	var mana_lbl := Label.new()
	var display_mana_cost := _get_display_mana_cost()
	mana_lbl.text = str(display_mana_cost) + "M"
	mana_lbl.add_theme_font_size_override("font_size", 14)
	if display_mana_cost > card_data.mana_cost:
		mana_lbl.add_theme_color_override("font_color", Color(1.0, 0.65, 0.65))
	elif display_mana_cost < card_data.mana_cost:
		mana_lbl.add_theme_color_override("font_color", Color(0.65, 1.0, 0.7))
	top_row.add_child(mana_lbl)

	var art := _build_art_node()
	if art:
		vbox.add_child(art)

	match card_data.card_type:
		Card.CardType.CREATURE:
			if not card_data.is_god:
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
		Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM:
			var spd_lbl := Label.new()
			spd_lbl.text = "SPD:%d" % card_data.speed
			spd_lbl.add_theme_font_size_override("font_size", 10)
			vbox.add_child(spd_lbl)

	if card_data.ability_text != "":
		var ability_lbl := RichTextLabel.new()
		ability_lbl.bbcode_enabled = true
		ability_lbl.text = BaseCard.apply_keyword_hints(card_data.ability_text)
		ability_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_lbl.add_theme_font_size_override("normal_font_size", 10)
		ability_lbl.add_theme_font_size_override("bold_font_size", 10)
		ability_lbl.add_theme_color_override("default_color", Color(0.9, 0.85, 1.0))
		ability_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ability_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ability_lbl.scroll_active = false
		vbox.add_child(ability_lbl)

	if card_data.name_at_bottom:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(spacer)
		vbox.add_child(_make_name_label())

func _build_content() -> void:
	# Outer (self) is a transparent layout-only shell — the HBoxContainer
	# manages it, but rotation never touches it, preventing re-sort cascades.
	var empty_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", empty_style)

	# Inner holds all visuals and can rotate freely without affecting layout.
	# No FULL_RECT anchors — PanelContainer still fills _inner to match self,
	# but without anchors the outer card's minimum height tracks VBox content.
	_inner = PanelContainer.new()
	_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inner)
	_apply_card_style()

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner.add_child(vbox)
	_populate_vbox(vbox)

	_disabled_overlay = ColorRect.new()
	_disabled_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_disabled_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disabled_overlay.visible = false
	_disabled_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inner.add_child(_disabled_overlay)

	_refresh_power_lock_overlay()
	_refresh_disabled_visual_state()
	call_deferred("_layout_power_lock_overlay")

func _apply_card_style() -> void:
	if _inner == null:
		return
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
		Card.CardType.CHARM:
			style.bg_color = Color(0.30, 0.12, 0.22)
			style.border_color = Color(0.95, 0.65, 0.35)
		Card.CardType.HEX:
			style.bg_color = Color(0.10, 0.24, 0.22)
			style.border_color = Color(0.2, 0.82, 0.72)
		Card.CardType.STRUCTURE:
			style.bg_color = Color(0.28, 0.18, 0.08)
			style.border_color = Color(0.75, 0.55, 0.3)
		_:
			style.bg_color = Color(0.15, 0.15, 0.15)
			style.border_color = Color(0.5, 0.5, 0.5)

	if _waiting_on_priority:
		style.border_color = Color(1.0, 0.88, 0.38, 0.98)
		style.shadow_color = Color(1.0, 0.82, 0.2, 0.7)
		style.shadow_size = 12
	if _priority_response_available:
		style.shadow_color = Color(0.34, 0.95, 0.42, 0.58)
		style.shadow_size = max(style.shadow_size, 7)
		if not _waiting_on_priority:
			style.border_color = Color(0.55, 1.0, 0.62, 0.96)
	if _blot_summonable:
		style.border_color = Color(0.45, 1.0, 0.52, 0.98)
		style.shadow_color = Color(0.25, 0.95, 0.4, 0.72)
		style.shadow_size = 16
	if _blot_selected:
		style.border_color = Color(0.82, 1.0, 0.55, 1.0)
		style.shadow_color = Color(0.52, 1.0, 0.4, 0.85)
		style.shadow_size = 20
	if _ghostly_hand_proxy:
		style.bg_color = Color(0.16, 0.24, 0.34, 0.48)
		style.border_color = Color(0.82, 0.96, 1.0, 0.92)
		style.shadow_color = Color(0.62, 0.88, 1.0, 0.32)
		style.shadow_size = max(style.shadow_size, 12)

	_inner.add_theme_stylebox_override("panel", style)
	_inner.self_modulate = Color(0.92, 0.98, 1.0, 0.82) if _ghostly_hand_proxy else Color.WHITE

func _type_abbrev() -> String:
	match card_data.card_type:
		Card.CardType.CREATURE: return "C"
		Card.CardType.SPELL:    return "S"
		Card.CardType.CHARM:    return "CH"
		Card.CardType.STRUCTURE:return "ST"
		Card.CardType.EQUIPMENT:return "EQ"
		Card.CardType.HEX:      return "H"
		_:                      return "?"

func _refresh_disabled_visual_state() -> void:
	if _disabled_overlay != null and is_instance_valid(_disabled_overlay):
		_disabled_overlay.visible = _disabled and _dim_when_disabled

func _refresh_power_lock_overlay() -> void:
	var should_show := _should_show_power_lock_overlay()
	if not should_show:
		if _power_lock_overlay != null and is_instance_valid(_power_lock_overlay):
			_power_lock_overlay.queue_free()
		_power_lock_overlay = null
		return
	if _power_lock_overlay == null or not is_instance_valid(_power_lock_overlay):
		_power_lock_overlay = _make_power_lock_overlay()
		if _power_lock_overlay == null:
			return
		add_child(_power_lock_overlay)
	_layout_power_lock_overlay()

func _layout_power_lock_overlay() -> void:
	if _power_lock_overlay == null or not is_instance_valid(_power_lock_overlay):
		return
	if _art_rect != null and is_instance_valid(_art_rect):
		_power_lock_overlay.position = _art_rect.global_position - global_position
		_power_lock_overlay.size = _art_rect.size
	elif _inner != null and is_instance_valid(_inner):
		_power_lock_overlay.position = _inner.global_position - global_position
		_power_lock_overlay.size = _inner.size

func set_disabled(value: bool, dim_visuals: bool = true) -> void:
	_disabled = value
	_dim_when_disabled = dim_visuals
	_refresh_mouse_filter()
	_refresh_disabled_visual_state()
	if value:
		_cancel_drag()
		_picked_up = false
		scale = Vector2(1.0, 1.0)

func set_hover_preview_when_disabled(value: bool) -> void:
	_hover_preview_when_disabled = value
	_refresh_mouse_filter()

func set_hand_proxy_visual(enabled: bool, click_only: bool = true) -> void:
	_ghostly_hand_proxy = enabled
	_click_only = click_only
	_apply_card_style()

func set_hover_viewer(viewer: Player) -> void:
	_hover_viewer = viewer

func _refresh_mouse_filter() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if (not _disabled or _hover_preview_when_disabled) else Control.MOUSE_FILTER_IGNORE

func set_highlighted(value: bool) -> void:
	modulate = Color(1.2, 1.2, 0.65) if value else Color.WHITE
	_picked_up = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func set_waiting_on_priority(value: bool) -> void:
	_waiting_on_priority = value
	_apply_card_style()

func set_priority_response_available(value: bool) -> void:
	_priority_response_available = value
	_apply_card_style()

func set_blot_summon_state(is_summonable: bool, is_selected: bool = false) -> void:
	_blot_summonable = is_summonable
	_blot_selected = is_selected
	_apply_card_style()

func _cancel_drag() -> void:
	if _dragging:
		_dragging = false
		if _drag_parent and is_instance_valid(_drag_parent):
			get_parent().remove_child(self)
			_drag_parent.add_child(self)
			_drag_parent.move_child(self, _drag_index)
		_drag_parent = null
		_drag_index = -1
		visible = true
		# Sync _inner rotation to match is_rotated — drag rotation only modifies
		# the drag ghost, so _inner can lag behind when the card returns to hand.
		if _inner:
			_inner.rotation_degrees = 90.0 if is_rotated else 0.0
			_inner.pivot_offset = size / 2.0
	if _drag_ghost and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
		_drag_ghost = null
	_drag_rot_tween = null
	_drag_stealth = false

func _cancel_rot_ghost() -> void:
	if _rot_tween and _rot_tween.is_valid():
		_rot_tween.kill()
	_rot_tween = null
	if _rot_ghost and is_instance_valid(_rot_ghost):
		_rot_ghost.queue_free()
	_rot_ghost = null
	if _inner:
		_inner.modulate.a = 1.0

func _can_toggle_drag_prepare() -> bool:
	return card_data != null and (card_data.card_type == Card.CardType.SPELL or card_data.card_type == Card.CardType.CHARM)

func _set_drag_prepare_preview(enabled: bool) -> void:
	if not (_drag_ghost and is_instance_valid(_drag_ghost)):
		return
	var ghost_inner := _drag_ghost.get_child(0) as Control
	if ghost_inner == null:
		return
	var existing := ghost_inner.get_node_or_null(_DRAG_PREPARE_OVERLAY_NAME)
	if existing != null:
		existing.queue_free()
	if not enabled:
		return

	var overlay := Control.new()
	overlay.name = _DRAG_PREPARE_OVERLAY_NAME
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var haze := ColorRect.new()
	haze.color = Color(0.05, 0.05, 0.2, 0.34)
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(haze)

	var ring := PanelContainer.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = 3
	ring.offset_top = 3
	ring.offset_right = -3
	ring.offset_bottom = -3
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_color = Color(0.62, 0.8, 1.0, 0.72)
	ring_style.corner_radius_top_left = 8
	ring_style.corner_radius_top_right = 8
	ring_style.corner_radius_bottom_left = 8
	ring_style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		ring_style.set_border_width(side, 2)
	ring.add_theme_stylebox_override("panel", ring_style)
	overlay.add_child(ring)

	var label := Label.new()
	label.text = "PREPARE"
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(0.88, 0.94, 1.0, 0.82)
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 6
	label.offset_bottom = 24
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(label)

	ghost_inner.add_child(overlay)

func _toggle_rotation() -> void:
	is_rotated = not is_rotated
	var target_angle := 90.0 if is_rotated else 0.0
	if _dragging and _drag_ghost and is_instance_valid(_drag_ghost):
		# Set the target; _process() animates toward it and updates position in
		# the same tick so rotation and position are never a frame out of sync.
		_drag_target_rotation = target_angle
	else:
		# Cancel any in-flight rotation ghost before starting a new one,
		# then snap _inner to the previous target so the new ghost starts correctly.
		_cancel_rot_ghost()
		_inner.rotation_degrees = 0.0 if is_rotated else 90.0  # previous angle
		_inner.pivot_offset = size / 2.0

		var current_angle := _inner.rotation_degrees
		var ghost := _build_rotation_ghost(current_angle)
		if ghost == null:
			_inner.pivot_offset = size / 2.0
			var tw := _inner.create_tween()
			tw.tween_property(_inner, "rotation_degrees", target_angle, 0.15)
			return
		_rot_ghost = ghost
		_inner.modulate.a = 0.0
		_rot_tween = ghost.create_tween()
		_rot_tween.tween_property(ghost, "rotation_degrees", target_angle, 0.15)
		_rot_tween.tween_callback(func() -> void:
			_inner.rotation_degrees = target_angle
			_inner.pivot_offset = size / 2.0
			_inner.modulate.a = 1.0
			if is_instance_valid(ghost):
				ghost.queue_free()
			_rot_ghost = null
			_rot_tween = null
		)

func _build_rotation_ghost(from_angle: float) -> Control:
	var tree := get_tree()
	if tree == null:
		return null
	var scene_root := tree.current_scene
	if scene_root == null:
		return null
	var ghost := duplicate(0) as Control
	ghost.z_index = 100
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate.a = 1.0
	ghost.scale = Vector2(1.0, 1.0)
	var sz := size
	if sz.y == 0:
		sz = get_combined_minimum_size()
	ghost.pivot_offset = sz / 2.0
	ghost.rotation_degrees = from_angle
	# Reset inner child state so the ghost shows the card flat (rotation is on outer)
	if _inner:
		var ghost_inner := ghost.get_child(0) as Control
		if ghost_inner:
			ghost_inner.rotation_degrees = 0.0
			ghost_inner.pivot_offset = Vector2.ZERO
			ghost_inner.modulate.a = 1.0
	# Add to tree BEFORE setting global_position — Control.global_position
	# only resolves correctly once the node is in the scene tree.
	var card_global_pos := global_position
	scene_root.add_child(ghost)
	ghost.global_position = card_global_pos
	return ghost

func _gui_input(event: InputEvent) -> void:
	if _disabled:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_drag_offset = get_global_mouse_position() - global_position
			_picked_up = true
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			card_right_clicked.emit(card_data)
			accept_event()

func _input(event: InputEvent) -> void:
	if not _picked_up:
		return
	if event is InputEventMouseMotion:
		if _click_only:
			return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not _dragging:
				_start_drag()
			_update_ghost_position()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _dragging:
				_finish_drag()
			else:
				card_clicked.emit(card_data)
			_picked_up = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _dragging:
			if _can_toggle_drag_prepare():
				_drag_stealth = not _drag_stealth
				_set_drag_prepare_preview(_drag_stealth)
			elif card_data.card_type == Card.CardType.CREATURE:
				_toggle_rotation()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and _dragging:
		if event.keycode == KEY_S and _can_toggle_drag_prepare():
			_drag_stealth = not _drag_stealth
			_set_drag_prepare_preview(_drag_stealth)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_S and card_data.card_type == Card.CardType.CREATURE:
			_drag_stealth = not _drag_stealth
			if _drag_stealth and not is_rotated:
				_toggle_rotation()
			elif not _drag_stealth and is_rotated:
				_toggle_rotation()
			get_viewport().set_input_as_handled()

func _update_ghost_position() -> void:
	if not (_drag_ghost and is_instance_valid(_drag_ghost)):
		return
	# Compute the card's visual centre offset at the ghost's current rotation.
	# With pivot_offset = Vector2.ZERO, Godot rotates around the node's top-left
	# corner. By rotating the half-size vector ourselves we find where that
	# top-left must sit so that the visual centre lands exactly on the cursor —
	# completely bypassing pivot_offset so Godot can't silently reset it.
	#
	# Godot's rotation convention (Y-down screen): the transform matrix is
	#   [ cos θ  -sin θ ]
	#   [ sin θ   cos θ ]
	# so a local point (x, y) maps to (-y, x) at θ=90°, matching CW on screen.
	var theta := deg_to_rad(_drag_ghost.rotation_degrees)
	var c := cos(theta)
	var s := sin(theta)
	var half := _drag_ghost_pivot                    # = size / 2 at build time
	var rotated_half := Vector2(c * half.x - s * half.y,
								s * half.x + c * half.y)
	_drag_ghost.global_position = get_viewport().get_mouse_position() - rotated_half

func _process(delta: float) -> void:
	if not _dragging or not (_drag_ghost and is_instance_valid(_drag_ghost)):
		return
	# Advance rotation toward target in the same tick as the position update so
	# they are never one frame out of step (which caused the wobble when a tween
	# owned rotation_degrees while _process owned position).
	var cur := _drag_ghost.rotation_degrees
	if cur != _drag_target_rotation:
		var step := _DRAG_ROT_SPEED * delta
		_drag_ghost.rotation_degrees = move_toward(cur, _drag_target_rotation, step)
	_update_ghost_position()

func _start_drag() -> void:
	_hide_hover_panel()
	# Flush any in-flight hand-rotation ghost so _inner is fully visible and
	# correctly rotated before _build_drag_ghost() duplicates it.
	if _rot_ghost or _rot_tween:
		_cancel_rot_ghost()
		_inner.rotation_degrees = 90.0 if is_rotated else 0.0
		_inner.pivot_offset = size / 2.0
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	_dragging = true
	_drag_ghost = _build_drag_ghost()
	_drag_target_rotation = _drag_ghost.rotation_degrees  # already at correct angle
	# Reparent to scene root so the hand HBox collapses the gap,
	# but the node stays in the tree so _input() keeps firing.
	var scene_root := tree.current_scene
	_drag_parent = get_parent()
	_drag_index = get_index()
	_drag_parent.remove_child(self)
	scene_root.add_child(self)
	visible = false
	scene_root.add_child(_drag_ghost)
	_update_ghost_position()

func _build_drag_ghost() -> Control:
	var ghost := duplicate(0) as Control
	ghost.z_index = 100
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate.a = 1.0
	ghost.scale = Vector2(1.0, 1.0)
	var sz := size
	if sz.y == 0:
		sz = get_combined_minimum_size()
	_drag_ghost_pivot = sz / 2.0
	ghost.pivot_offset = Vector2.ZERO   # centering is handled in _update_ghost_position
	# Consolidate _inner's rotation onto the ghost outer so the whole ghost
	# can be rotated cleanly during drag (ghost is at scene root, no Container).
	if _inner:
		ghost.rotation_degrees = _inner.rotation_degrees
		var ghost_inner := ghost.get_child(0) as Control
		if ghost_inner:
			ghost_inner.rotation_degrees = 0.0
			ghost_inner.pivot_offset = Vector2.ZERO
	_drag_ghost = ghost
	_set_drag_prepare_preview(_drag_stealth and _can_toggle_drag_prepare())
	_drag_ghost = null
	return ghost

func _finish_drag() -> void:
	_dragging = false
	_drag_parent = null
	_drag_index = -1
	var drop_pos := get_global_mouse_position()
	if _drag_ghost and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
		_drag_ghost = null
	# Sync _inner so it matches is_rotated — drag rotation only touches the
	# drag ghost, so _inner.rotation_degrees can lag behind is_rotated.
	if _inner:
		_inner.rotation_degrees = 90.0 if is_rotated else 0.0
		_inner.pivot_offset = size / 2.0
	var was_stealth := _drag_stealth
	_drag_stealth = false
	card_drag_released.emit(card_data, drop_pos, is_rotated, was_stealth)

func _show_hover_panel() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var scene_root := tree.current_scene
	if scene_root == null:
		return

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.top_level = true
	panel.z_index = _HOVER_PANEL_Z_INDEX
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.12, 0.97)
	style.border_color = Color(0.5, 0.7, 1.0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.custom_minimum_size = Vector2(_HOVER_PANEL_WIDTH - 20.0, 0.0)
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.custom_minimum_size.x = _HOVER_PANEL_WIDTH - 20.0
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(vbox)

	# Name
	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.text = card_data.get_display_name_for_control(name_lbl)
	vbox.add_child(name_lbl)

	# Types
	if card_data.card_types.size() > 0:
		var type_lbl := Label.new()
		type_lbl.text = " • ".join(card_data.card_types)
		type_lbl.add_theme_font_size_override("font_size", 11)
		type_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		type_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(type_lbl)

	# Level / Mana / Culture row
	var meta_parts: Array[String] = []
	if card_data.get_effective_level() > 0:
		meta_parts.append("Level " + str(card_data.get_effective_level()))
	meta_parts.append("Mana: " + str(_get_display_mana_cost()))
	if card_data.culture != "":
		meta_parts.append(card_data.culture)
	var meta_lbl := Label.new()
	meta_lbl.text = "  |  ".join(meta_parts)
	meta_lbl.add_theme_font_size_override("font_size", 11)
	meta_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	vbox.add_child(meta_lbl)

	# Stats
	match card_data.card_type:
		Card.CardType.CREATURE:
			if not card_data.is_god:
				var eff_str := card_data.get_effective_strength()
				var eff_res := card_data.get_effective_resilience()
				var eff_spd := card_data.get_effective_speed()
				var stats_lbl := Label.new()
				stats_lbl.text = "STR: %d   RES: %d   SPD: %d" % [eff_str, eff_res, eff_spd]
				stats_lbl.add_theme_font_size_override("font_size", 12)
				var tip_parts: Array[String] = []
				for entry in [["STR", "str"], ["RES", "res"], ["SPD", "spd"]]:
					var bd := card_data.get_full_stat_breakdown(entry[1])
					if bd != "":
						tip_parts.append(entry[0] + ": " + bd)
				if tip_parts.size() > 0:
					stats_lbl.tooltip_text = "\n".join(tip_parts)
					stats_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
				vbox.add_child(stats_lbl)
		Card.CardType.STRUCTURE:
			var res_lbl := Label.new()
			res_lbl.text = "RES: %d" % card_data.resilience
			res_lbl.add_theme_font_size_override("font_size", 12)
			vbox.add_child(res_lbl)
		Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM:
			var spd_lbl := Label.new()
			spd_lbl.text = "Speed: %d" % card_data.speed
			spd_lbl.add_theme_font_size_override("font_size", 12)
			vbox.add_child(spd_lbl)

	# Costs (non-zero extras)
	var cost_parts: Array[String] = []
	if card_data.sacrifice_cost > 0:
		cost_parts.append("Sacrifice: " + str(card_data.sacrifice_cost))
	if card_data.discard_cost > 0:
		cost_parts.append("Discard: " + str(card_data.discard_cost))
	if cost_parts.size() > 0:
		var cost_lbl := Label.new()
		cost_lbl.text = "  |  ".join(cost_parts)
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
		vbox.add_child(cost_lbl)

	if not _display_cost_adjustment_lines.is_empty():
		var summon_cost_lbl := Label.new()
		summon_cost_lbl.text = "\n".join(_display_cost_adjustment_lines)
		summon_cost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summon_cost_lbl.add_theme_font_size_override("font_size", 11)
		summon_cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.72))
		summon_cost_lbl.custom_minimum_size = Vector2(210, 0)
		vbox.add_child(summon_cost_lbl)

	# Separator
	if card_data.ability_text != "" or card_data.flavor_text != "":
		var sep := HSeparator.new()
		sep.add_theme_color_override("color", Color(0.3, 0.3, 0.5))
		vbox.add_child(sep)

	# Ability text
	if card_data.ability_text != "":
		var ability_lbl := Label.new()
		ability_lbl.text = card_data.ability_text.replace("[b]", "").replace("[/b]", "")
		ability_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_lbl.add_theme_font_size_override("font_size", 12)
		ability_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
		ability_lbl.custom_minimum_size = Vector2(210, 0)
		vbox.add_child(ability_lbl)

	# Flavor text
	if card_data.flavor_text != "":
		var flavor_lbl := Label.new()
		flavor_lbl.text = card_data.flavor_text
		flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavor_lbl.add_theme_font_size_override("font_size", 11)
		flavor_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(flavor_lbl)

	var hover_details := card_data.get_hover_detail_lines(_hover_viewer)
	if hover_details.size() > 0:
		var detail_sep := HSeparator.new()
		detail_sep.add_theme_color_override("color", Color(0.22, 0.45, 0.4))
		vbox.add_child(detail_sep)

		var detail_lbl := RichTextLabel.new()
		detail_lbl.bbcode_enabled = true
		detail_lbl.text = "\n".join(hover_details)
		detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_lbl.scroll_active = false
		detail_lbl.fit_content = true
		detail_lbl.add_theme_font_size_override("normal_font_size", 11)
		detail_lbl.add_theme_font_size_override("bold_font_size", 11)
		detail_lbl.add_theme_color_override("default_color", Color(0.72, 0.96, 0.86))
		detail_lbl.custom_minimum_size = Vector2(210, 0)
		vbox.add_child(detail_lbl)

	scene_root.add_child(panel)
	panel.move_to_front()
	var vp_size := get_viewport().get_visible_rect().size
	panel.size = Vector2(_HOVER_PANEL_WIDTH, minf(_HOVER_PANEL_MAX_HEIGHT, vp_size.y - 8.0))

	# Position: prefer right of card, flip left if off-screen
	var panel_size := panel.size
	var card_right := global_position.x + size.x + 8
	var px := card_right if card_right + panel_size.x < vp_size.x else global_position.x - panel_size.x - 8
	px = clampf(px, 4.0, max(4.0, vp_size.x - panel_size.x - 4.0))
	var py := clampf(global_position.y, 4.0, max(4.0, vp_size.y - panel_size.y - 4.0))
	panel.global_position = Vector2(px, py)

	_hover_panel = panel

func _hide_hover_panel() -> void:
	if _hover_panel and is_instance_valid(_hover_panel):
		_hover_panel.queue_free()
	_hover_panel = null

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			# Safe: setting _inner.pivot_offset only notifies self (outer),
			# not the HBoxContainer, so no re-sort cascade.
			if _inner:
				_inner.pivot_offset = size / 2.0
			_layout_power_lock_overlay()
		NOTIFICATION_MOUSE_ENTER:
			if (not _disabled or _hover_preview_when_disabled) and not _picked_up:
				pivot_offset = size / 2.0
				z_index = _base_z_index + 50
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)
				_show_hover_panel()
		NOTIFICATION_MOUSE_EXIT:
			if not _picked_up:
				z_index = _base_z_index
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
			_hide_hover_panel()
