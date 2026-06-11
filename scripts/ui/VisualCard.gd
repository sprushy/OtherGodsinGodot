class_name VisualCard
extends PanelContainer

const CardDetailContentBuilderScript = preload("res://scripts/ui/CardDetailContentBuilder.gd")
const LockedPowerCursorScript = preload("res://scripts/ui/LockedPowerCursor.gd")
const DefenseShieldOverlayScript = preload("res://scripts/ui/DefenseShieldOverlay.gd")
const BoardZoneUIScript = preload("res://scripts/ui/BoardZoneUI.gd")
const LevelSymbolRowScript = preload("res://scripts/ui/LevelSymbolRow.gd")
const DebuffBadgeScript = preload("res://scripts/ui/DebuffBadge.gd")
const MINOR_ACTION_SYMBOL_TEXTURE := preload("res://images/ui/MinorActionSymbol.png")
const MAJOR_ACTION_SYMBOL_TEXTURE := preload("res://images/ui/MajorActionSymbol.png")
const MANA_ORB_TEXTURE := preload("res://images/ui/ManaOrb.png")
const REVEALED_HAND_BADGE_TEXTURE := preload("res://images/ability_badges/MopsusBadge.png")
const DEBUFF_BADGE_SIZE := DebuffBadgeScript.SIZE
const PRIORITY_RESPONSE_GLOW_COLOR := Color(0.28, 0.92, 0.50, 0.95)

signal card_clicked(card: Card)
signal card_right_clicked(card: Card)
signal card_drag_released(card: Card, global_pos: Vector2, rotated: bool, stealth: bool)
signal hand_hovered(vc: VisualCard)
signal hand_unhovered(vc: VisualCard)

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
const _SUMMON_ACTION_ICON_ROW_NAME := "SummonActionCostIcons"
const _LEVEL_TAG_NAME := "LevelTag"
const _LEVEL_SYMBOL_ROW_NAME := "LevelSymbolRow"
const _DRAG_LEVEL_OVERLAY_NAME := "DragLevelOverlay"
const _STATS_LABEL_NAME := "StatsLabel"
const _FLOATING_GHOST_Z_INDEX := 1300
const _DRAG_ROT_SPEED: float = 600.0  # degrees per second (90° in 0.15 s)
var _base_z_index: int = 0
const _HOVER_PANEL_Z_INDEX := 2000
const _HOVER_PANEL_WIDTH := 320.0
const _HOVER_PANEL_MAX_HEIGHT := 420.0
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
var _hand_mode: bool = false
var _hand_hover_hit_rect: Rect2 = Rect2()

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
var _defense_shield_overlay: Control = null
var _level_tag: PanelContainer = null
var _level_label: Control = null
var _stats_label: Label = null
const _DEFAULT_POWER_LOCK_TEXTURE := preload("res://images/Default Power Lock.png")
const _ANCIENT_POWER_LOCK_TEXTURE := preload("res://images/Ancient Power Lock.png")
const _NORSE_POWER_LOCK_TEXTURE := preload("res://images/Norse Power Lock.png")
const _MANA_ORB_ICON_SIZE := 18.0
const _LEVEL_SYMBOL_SIZE := 19.0

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
	# Treat the requested height as a floor, not a cap, so long rules text
	# can still grow the card instead of getting clipped at the bottom.
	var natural_h: float = maxf(float(_card_height), _compute_natural_height())
	custom_minimum_size = Vector2(_card_width, natural_h)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_mouse_cursor_shape()
	_build_content()
	_bind_visual_state()
	if card_data.exhausted_art_path != "":
		card_data.art_updated.connect(_on_art_updated)

func _get_display_mana_cost() -> int:
	return _display_mana_cost if _display_mana_cost >= 0 else card_data.mana_cost

func _compute_natural_height() -> float:
	var h := 26.0  # name + mana row
	if card_data.art_path != "":
		var tex: Texture2D = load(card_data.art_path)
		if tex:
			h += _card_width * float(tex.get_height()) / float(tex.get_width())
	if not card_data.is_god:
		h += 22.0  # stats / speed / resilience row
	if card_data.ability_text != "":
		var raw := card_data.ability_text.replace("[b]", "").replace("[/b]", "")
		var content_width := maxf(96.0, float(_card_width) - 10.0)
		var chars_per_line = max(12, int(floor(content_width / 7.2)))
		var est_lines := 0
		for part in raw.split("\n", false):
			est_lines += max(1, ceili(float(part.length()) / float(chars_per_line)))
		est_lines = max(est_lines, 2)
		h += float(est_lines) * 18.0 + 12.0
	return h

func _compute_compact_height() -> float:
	var h := 26.0  # name + mana row
	if card_data.art_path != "":
		var tex: Texture2D = load(card_data.art_path)
		if tex:
			h += _card_width * float(tex.get_height()) / float(tex.get_width())
	if not card_data.is_god:
		h += 22.0  # stats / speed / resilience row
	return h

func _sync_minimum_height() -> void:
	var measured_h := maxf(float(_card_height), _compute_natural_height())
	custom_minimum_size = Vector2(_card_width, measured_h)

func _should_show_power_lock_overlay() -> bool:
	return card_data != null \
		and card_data.card_type == Card.CardType.POWER \
		and card_data.is_face_down

func _make_power_lock_overlay() -> TextureRect:
	var power_lock_texture := _get_power_lock_texture()
	if power_lock_texture == null:
		return null
	var overlay := TextureRect.new()
	overlay.texture = power_lock_texture
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return overlay

func _get_power_lock_texture() -> Texture2D:
	if card_data != null and card_data.card_type == Card.CardType.POWER:
		if str(card_data.culture).strip_edges() == "Ancient" or card_data.has_type("Ancient Power"):
			return _ANCIENT_POWER_LOCK_TEXTURE
		if str(card_data.culture).strip_edges() == "Norse":
			return _NORSE_POWER_LOCK_TEXTURE
	return _DEFAULT_POWER_LOCK_TEXTURE

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
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_rect = art
	return art

func _on_art_updated(new_path: String) -> void:
	if _art_rect == null or not is_instance_valid(_art_rect):
		return
	var tex: Texture2D = load(new_path)
	if tex:
		_art_rect.texture = tex
		_sync_minimum_height()
		call_deferred("_sync_minimum_height")
		call_deferred("_layout_power_lock_overlay")

func _make_name_label() -> Label:
	var name_lbl := Label.new()
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.custom_minimum_size = Vector2(maxf(36.0, float(_card_width) - 132.0), 0.0)
	name_lbl.text = card_data.get_display_name_for_control(name_lbl)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return name_lbl

func _get_level_symbol_color(effective_level: int) -> Color:
	if effective_level > card_data.level:
		return Color(0.4, 1.0, 0.4)
	if effective_level < card_data.level:
		return Color(1.0, 0.35, 0.35)
	return Color(1.0, 0.96, 0.78)

func _refresh_level_tag_tooltip() -> void:
	if _level_tag == null or not is_instance_valid(_level_tag) or card_data == null:
		return
	var tooltip_lines := PackedStringArray(["Level: %d" % card_data.get_effective_level()])
	var level_breakdown := card_data.get_buff_tooltip("lvl")
	if level_breakdown != "":
		tooltip_lines.append("LVL:\n" + level_breakdown)
	_level_tag.tooltip_text = "\n".join(tooltip_lines)
	_level_tag.mouse_filter = Control.MOUSE_FILTER_STOP

func _apply_level_badge_state(level_tag: PanelContainer) -> void:
	if level_tag == null or card_data == null:
		return
	var effective_level := card_data.get_effective_level()
	var tag_size := Vector2(_LEVEL_SYMBOL_SIZE * float(effective_level) + 10.0, _LEVEL_SYMBOL_SIZE + 8.0)
	level_tag.custom_minimum_size = tag_size
	level_tag.size = tag_size
	level_tag.update_minimum_size()

func _populate_level_badge(level_tag: PanelContainer, track_instance: bool = true) -> void:
	if level_tag == null or card_data == null:
		return
	for child in level_tag.get_children():
		level_tag.remove_child(child)
		child.queue_free()
	var effective_level := card_data.get_effective_level()
	var texture := LevelSymbolRowScript.get_symbol_texture_for_card(card_data)
	var color := _get_level_symbol_color(effective_level)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_tag.add_child(center)
	var row := HBoxContainer.new()
	row.name = _LEVEL_SYMBOL_ROW_NAME
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	for _i in range(effective_level):
		var icon := TextureRect.new()
		icon.texture = texture
		icon.modulate = color
		icon.custom_minimum_size = Vector2(_LEVEL_SYMBOL_SIZE, _LEVEL_SYMBOL_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	if track_instance:
		_level_label = row
	_apply_level_badge_state(level_tag)

func _make_level_label(track_instance: bool = true) -> Control:
	if card_data == null or card_data.is_god:
		return null
	var effective_level := card_data.get_effective_level()
	var tag := PanelContainer.new()
	tag.name = _LEVEL_TAG_NAME
	tag.mouse_filter = Control.MOUSE_FILTER_STOP
	tag.custom_minimum_size = Vector2(_LEVEL_SYMBOL_SIZE * float(effective_level) + 10.0, _LEVEL_SYMBOL_SIZE + 8.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.94)
	style.border_color = Color(0.72, 0.84, 1.0, 0.98)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	tag.add_theme_stylebox_override("panel", style)
	_populate_level_badge(tag, track_instance)
	if track_instance:
		_level_tag = tag
		_refresh_level_tag_tooltip()
	return tag

func _make_cost_number_label(text: String, display_mana_cost: int = -1) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if display_mana_cost > card_data.mana_cost:
		label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.65))
	elif display_mana_cost < card_data.mana_cost:
		label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.7))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_mana_orb_icon(icon_size: float = _MANA_ORB_ICON_SIZE) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = MANA_ORB_TEXTURE
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _make_cost_node(cost_text: String, display_mana_cost: int) -> Control:
	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_theme_constant_override("separation", 2)
	cost_row.alignment = BoxContainer.ALIGNMENT_END
	cost_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	if card_data.card_type == Card.CardType.CREATURE:
		var icon_row := HBoxContainer.new()
		icon_row.name = _SUMMON_ACTION_ICON_ROW_NAME
		icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_row.add_theme_constant_override("separation", 1)
		_populate_summon_action_icon_row(icon_row, Card.get_creature_summon_action_cost_kinds(false), 18.0)
		cost_row.add_child(icon_row)

	if display_mana_cost > 0:
		cost_row.add_child(_make_cost_number_label(str(display_mana_cost), display_mana_cost))
		cost_row.add_child(_make_mana_orb_icon(_MANA_ORB_ICON_SIZE))
	for part in card_data.get_cost_shorthand_parts(0):
		cost_row.add_child(_make_cost_number_label(part))
	if cost_row.get_child_count() == 0:
		cost_row.add_child(_make_cost_number_label(cost_text, display_mana_cost))
	return cost_row

func _make_summon_action_icon(action_kind: String, icon_size: float = 18.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = MAJOR_ACTION_SYMBOL_TEXTURE if action_kind == Card.ACTION_COST_MAJOR else MINOR_ACTION_SYMBOL_TEXTURE
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _populate_summon_action_icon_row(icon_row: HBoxContainer, action_kinds: Array[String], icon_size: float = 18.0) -> void:
	if icon_row == null:
		return
	for child in icon_row.get_children():
		icon_row.remove_child(child)
		child.queue_free()
	for action_kind in action_kinds:
		icon_row.add_child(_make_summon_action_icon(action_kind, icon_size))

func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found := _find_descendant_by_name(child, target_name)
		if found != null:
			return found
	return null

func _refresh_drag_summon_action_cost_preview() -> void:
	if not (_drag_ghost and is_instance_valid(_drag_ghost)):
		return
	var icon_row := _find_descendant_by_name(_drag_ghost, _SUMMON_ACTION_ICON_ROW_NAME) as HBoxContainer
	if icon_row == null:
		return
	_populate_summon_action_icon_row(
		icon_row,
		Card.get_creature_summon_action_cost_kinds(_drag_stealth),
		18.0
	)

func _refresh_drag_ghost_level_preview() -> void:
	if not (_drag_ghost and is_instance_valid(_drag_ghost)):
		return
	if _drag_ghost is BoardZoneUI:
		return
	var existing_overlay := _drag_ghost.get_node_or_null(_DRAG_LEVEL_OVERLAY_NAME)
	if existing_overlay != null:
		_drag_ghost.remove_child(existing_overlay)
		existing_overlay.queue_free()
	if card_data == null or card_data.is_god:
		return
	var level_tag := _find_descendant_by_name(_drag_ghost, _LEVEL_TAG_NAME) as PanelContainer
	if level_tag == null:
		return
	level_tag.visible = true
	level_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_populate_level_badge(level_tag, false)

func _bind_visual_state() -> void:
	if card_data == null:
		return
	if not card_data.visual_state_changed.is_connected(_on_card_visual_state_changed):
		card_data.visual_state_changed.connect(_on_card_visual_state_changed)

func _unbind_visual_state() -> void:
	if card_data == null:
		return
	if card_data.visual_state_changed.is_connected(_on_card_visual_state_changed):
		card_data.visual_state_changed.disconnect(_on_card_visual_state_changed)

func _refresh_dynamic_labels() -> void:
	if card_data == null:
		return
	if _level_label != null and is_instance_valid(_level_label):
		_populate_level_badge(_level_tag)
		_refresh_level_tag_tooltip()
	_refresh_drag_ghost_level_preview()
	if _stats_label == null or not is_instance_valid(_stats_label):
		return
	_apply_stats_label_state(_stats_label, is_rotated, false)
	_refresh_drag_stats_preview()

func _apply_stats_label_state(target_label: Label, preview_rotated: bool, preview_stealth: bool) -> void:
	if target_label == null or not is_instance_valid(target_label) or card_data == null:
		return
	match card_data.card_type:
		Card.CardType.CREATURE:
			var defensive_preview := preview_rotated or preview_stealth
			if defensive_preview:
				target_label.text = "DEF RES:%d SPD:%d" % [
					card_data.get_effective_resilience(),
					card_data.get_effective_speed()
				]
			else:
				target_label.text = "STR:%d RES:%d SPD:%d" % [
					card_data.get_effective_strength(),
					card_data.get_effective_resilience(),
					card_data.get_effective_speed()
				]
			var creature_tooltips: Array[String] = []
			for stat_info in [["STR", "str"], ["RES", "res"], ["SPD", "spd"]]:
				var breakdown := card_data.get_full_stat_breakdown(stat_info[1])
				if breakdown != "":
					creature_tooltips.append(stat_info[0] + ":\n" + breakdown)
			target_label.tooltip_text = "\n\n".join(creature_tooltips)
			target_label.mouse_filter = Control.MOUSE_FILTER_STOP if not creature_tooltips.is_empty() else Control.MOUSE_FILTER_IGNORE
		Card.CardType.STRUCTURE:
			target_label.text = "RES:%d" % card_data.get_effective_resilience()
			var structure_breakdown := card_data.get_full_stat_breakdown("res")
			target_label.tooltip_text = "RES:\n" + structure_breakdown if structure_breakdown != "" else ""
			target_label.mouse_filter = Control.MOUSE_FILTER_STOP if structure_breakdown != "" else Control.MOUSE_FILTER_IGNORE
		Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM:
			target_label.text = "SPD:%d" % card_data.get_effective_speed()
			var speed_breakdown := card_data.get_full_stat_breakdown("spd")
			target_label.tooltip_text = "SPD:\n" + speed_breakdown if speed_breakdown != "" else ""
			target_label.mouse_filter = Control.MOUSE_FILTER_STOP if speed_breakdown != "" else Control.MOUSE_FILTER_IGNORE
		_:
			target_label.tooltip_text = ""
			target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh_drag_stats_preview() -> void:
	if not (_drag_ghost and is_instance_valid(_drag_ghost)):
		return
	if _drag_ghost is BoardZoneUI:
		return
	var labels := _find_drag_stats_labels(_drag_ghost)
	for ghost_stats_label in labels:
		_apply_stats_label_state(ghost_stats_label, is_rotated, _drag_stealth)

func _find_drag_stats_labels(root: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if root == null:
		return labels
	if root is Label:
		var label := root as Label
		if label.name == _STATS_LABEL_NAME or label.text.begins_with("STR:") or label.text.begins_with("DEF ") or label.text.begins_with("RES:"):
			labels.append(label)
	for child in root.get_children():
		labels.append_array(_find_drag_stats_labels(child))
	return labels

func _refresh_drag_summon_preview() -> void:
	if _drag_ghost is BoardZoneUI:
		_refresh_drag_board_summon_preview()
		return
	_refresh_drag_stats_preview()
	_refresh_drag_summon_action_cost_preview()

func _refresh_drag_board_summon_preview() -> void:
	var board_ghost := _drag_ghost as BoardZoneUI
	if board_ghost == null or not is_instance_valid(board_ghost):
		return
	if card_data == null or card_data.card_type != Card.CardType.CREATURE:
		board_ghost.set_preview_card(null)
		return

	var preview_card := card_data.duplicate(true) as Card
	if preview_card == null:
		return
	preview_card.card_owner = card_data.card_owner
	preview_card.is_prepared = false
	preview_card.is_face_down = _drag_stealth
	preview_card.is_stealth = _drag_stealth
	preview_card.creature_mode = Card.CreatureMode.DEFENSIVE if (is_rotated or _drag_stealth) else Card.CreatureMode.AGGRESSIVE
	preview_card.summoned_this_turn = true

	var preview_zone := Zone.new()
	preview_zone.zone_type = Zone.ZoneType.FRONTLINE
	preview_zone.zone_index = 0
	preview_zone.zone_owner = card_data.card_owner
	preview_zone.cards.clear()
	preview_zone.cards.append(preview_card)
	preview_card.current_zone = preview_zone

	board_ghost.zone = preview_zone
	board_ghost.owning_player = card_data.card_owner
	board_ghost.viewer_override = _hover_viewer if _hover_viewer != null else card_data.card_owner
	board_ghost.zone_index = 0
	board_ghost.set_preview_card(preview_card)
	board_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_card_visual_state_changed() -> void:
	_refresh_dynamic_labels()
	_apply_card_style()
	if _hover_panel != null and is_instance_valid(_hover_panel):
		_hide_hover_panel()
		_show_hover_panel()

func _build_art_container(art: TextureRect) -> Control:
	if art == null:
		return null
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size = art.custom_minimum_size
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(art)
	if _hand_mode:
		return holder
	var level_tag := _make_level_label()
	if level_tag != null:
		level_tag.set_anchors_preset(Control.PRESET_TOP_LEFT)
		level_tag.offset_left = 6
		level_tag.offset_top = -8
		level_tag.offset_right = level_tag.offset_left + level_tag.custom_minimum_size.x
		level_tag.offset_bottom = level_tag.offset_top + level_tag.custom_minimum_size.y
		holder.add_child(level_tag)
	return holder

func _populate_vbox(vbox: VBoxContainer) -> void:
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.custom_minimum_size = Vector2(_card_width, 0.0)
	vbox.add_child(top_row)

	if not card_data.name_at_bottom:
		top_row.add_child(_make_name_label())

	var level_lbl: Control = null
	if _hand_mode:
		level_lbl = _make_level_label()
		if level_lbl != null:
			top_row.add_child(level_lbl)

	var display_mana_cost := _get_display_mana_cost()
	var cost_text := card_data.get_cost_shorthand(display_mana_cost)
	if cost_text != "" or card_data.card_type == Card.CardType.CREATURE:
		top_row.add_child(_make_cost_node(cost_text, display_mana_cost))

	var art := _build_art_node()
	if art:
		vbox.add_child(_build_art_container(art))
	elif card_data != null and not card_data.name_at_bottom and not _hand_mode:
		if level_lbl == null:
			level_lbl = _make_level_label()
		if level_lbl != null:
			top_row.add_child(level_lbl)

	match card_data.card_type:
		Card.CardType.GOD:
			pass
		Card.CardType.CREATURE:
			var stats_lbl := Label.new()
			stats_lbl.name = _STATS_LABEL_NAME
			stats_lbl.add_theme_font_size_override("font_size", 19)
			_stats_label = stats_lbl
			vbox.add_child(stats_lbl)
		Card.CardType.STRUCTURE:
			var res_lbl := Label.new()
			res_lbl.name = _STATS_LABEL_NAME
			res_lbl.add_theme_font_size_override("font_size", 16)
			_stats_label = res_lbl
			vbox.add_child(res_lbl)
		Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM:
			var spd_lbl := Label.new()
			spd_lbl.name = _STATS_LABEL_NAME
			spd_lbl.add_theme_font_size_override("font_size", 16)
			_stats_label = spd_lbl
			vbox.add_child(spd_lbl)

	if card_data.ability_text != "":
		var ability_lbl := RichTextLabel.new()
		ability_lbl.bbcode_enabled = true
		ability_lbl.text = BaseCard.apply_keyword_hints(BaseCard.apply_action_cost_symbols(card_data.ability_text, card_data))
		ability_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_lbl.fit_content = true
		ability_lbl.add_theme_font_size_override("normal_font_size", 14)
		ability_lbl.add_theme_font_size_override("bold_font_size", 14)
		ability_lbl.add_theme_color_override("default_color", Color(0.9, 0.85, 1.0))
		ability_lbl.custom_minimum_size = Vector2(maxf(96.0, float(_card_width) - 10.0), 0.0)
		ability_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ability_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ability_lbl.scroll_active = false
		ability_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(ability_lbl)

	if card_data.name_at_bottom:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(spacer)
		vbox.add_child(_make_name_label())

func _build_content() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_level_tag = null
	_level_label = null
	_stats_label = null
	_inner = null
	_art_rect = null
	_disabled_overlay = null
	_power_lock_overlay = null
	_defense_shield_overlay = null
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
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(vbox)
	_populate_vbox(vbox)
	_sync_minimum_height()

	_disabled_overlay = ColorRect.new()
	_disabled_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_disabled_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disabled_overlay.visible = false
	_disabled_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inner.add_child(_disabled_overlay)

	_add_revealed_hand_badge()
	_refresh_power_lock_overlay()
	_refresh_defense_shield_overlay()
	_refresh_disabled_visual_state()
	_refresh_dynamic_labels()
	call_deferred("_sync_minimum_height")
	call_deferred("_layout_power_lock_overlay")

func _add_revealed_hand_badge() -> void:
	if _inner == null or card_data == null or not card_data.is_revealed_in_hand():
		return
	if card_data.current_zone == null or card_data.current_zone.zone_type != Zone.ZoneType.HAND:
		return
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inner.add_child(overlay)

	var preview := TextureRect.new()
	preview.texture = REVEALED_HAND_BADGE_TEXTURE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 2.0
	preview.offset_top = 2.0
	preview.offset_right = -2.0
	preview.offset_bottom = -2.0

	var badge := DebuffBadgeScript.create(preview)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -6.0 - DEBUFF_BADGE_SIZE
	badge.offset_top = 32.0
	badge.offset_right = -6.0
	badge.offset_bottom = 32.0 + DEBUFF_BADGE_SIZE
	overlay.add_child(badge)

func _make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)

	match card_data.card_type:
		Card.CardType.GOD:
			style.bg_color = Color(0.38, 0.28, 0.08)
			style.border_color = Color(0.95, 0.8, 0.28)
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
		style.shadow_color = PRIORITY_RESPONSE_GLOW_COLOR
		style.shadow_size = max(style.shadow_size, 16)
		if not _waiting_on_priority:
			style.border_color = PRIORITY_RESPONSE_GLOW_COLOR
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
	return style

func _apply_card_style() -> void:
	if _inner == null:
		return
	_inner.add_theme_stylebox_override("panel", _make_card_style())
	_inner.self_modulate = Color(0.92, 0.98, 1.0, 0.82) if _ghostly_hand_proxy else Color.WHITE

func _refresh_disabled_visual_state() -> void:
	if _disabled_overlay != null and is_instance_valid(_disabled_overlay):
		_disabled_overlay.visible = _disabled and _dim_when_disabled

func _refresh_power_lock_overlay() -> void:
	var should_show := _should_show_power_lock_overlay()
	_refresh_mouse_cursor_shape()
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

func _refresh_defense_shield_overlay() -> void:
	if _inner == null or not is_instance_valid(_inner):
		_defense_shield_overlay = null
		return
	if is_rotated:
		_defense_shield_overlay = DefenseShieldOverlayScript.ensure_on(_inner, DefenseShieldOverlayScript.LAYOUT_CENTER)
	else:
		DefenseShieldOverlayScript.remove_from(_inner)
		_defense_shield_overlay = null

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

func set_hand_mode(enabled: bool) -> void:
	if _hand_mode == enabled:
		if not enabled:
			_hand_hover_hit_rect = Rect2()
		return
	_hand_mode = enabled
	if not enabled:
		_hand_hover_hit_rect = Rect2()
	if card_data != null:
		_build_content()

func set_hand_hover_hit_rect(rect: Rect2) -> void:
	_hand_hover_hit_rect = rect

func _refresh_mouse_filter() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if (not _disabled or _hover_preview_when_disabled) else Control.MOUSE_FILTER_IGNORE

func _refresh_mouse_cursor_shape() -> void:
	if _should_show_power_lock_overlay():
		mouse_default_cursor_shape = LockedPowerCursorScript.get_control_cursor_shape(Control.CURSOR_POINTING_HAND as Control.CursorShape)
		return
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _has_point(point: Vector2) -> bool:
	var hit_rect := Rect2(Vector2.ZERO, size)
	if _hand_mode and _hand_hover_hit_rect.size.x > 0.0 and _hand_hover_hit_rect.size.y > 0.0:
		hit_rect = _hand_hover_hit_rect
		if hit_rect.has_point(point):
			return true
		var bottom_band_height := minf(size.y, maxf(44.0, size.y * 0.16))
		var bottom_band_top := maxf(0.0, size.y - bottom_band_height)
		return point.x >= 0.0 and point.x < size.x and point.y >= bottom_band_top and point.y < size.y
	return hit_rect.has_point(point)

func contains_global_point(global_point: Vector2) -> bool:
	var local_point := get_global_transform().affine_inverse() * global_point
	return _has_point(local_point)

func proxy_mouse_button_press(button_index: MouseButton, global_mouse_pos: Vector2) -> void:
	if _disabled:
		return
	if button_index == MOUSE_BUTTON_LEFT:
		_drag_offset = global_mouse_pos - global_position
		_picked_up = true
	elif button_index == MOUSE_BUTTON_RIGHT:
		card_right_clicked.emit(card_data)

func is_hand_interacting() -> bool:
	return _picked_up or _dragging

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
			_inner.rotation_degrees = 0.0
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

# Legacy name: this toggles the defensive summon preview state.
func _toggle_rotation() -> void:
	is_rotated = not is_rotated
	_drag_target_rotation = 0.0
	if _inner:
		_inner.rotation_degrees = 0.0
		_inner.pivot_offset = size / 2.0
	_refresh_defense_shield_overlay()
	_refresh_dynamic_labels()

func apply_creature_drag_defensive_preview() -> bool:
	if card_data == null or card_data.card_type != Card.CardType.CREATURE or not _dragging:
		return false
	_drag_stealth = false
	if not is_rotated:
		_toggle_rotation()
	_refresh_drag_summon_preview()
	return true

func apply_creature_drag_stealth_preview() -> bool:
	if card_data == null or card_data.card_type != Card.CardType.CREATURE or not _dragging:
		return false
	_drag_stealth = true
	if not is_rotated:
		_toggle_rotation()
	_refresh_drag_summon_preview()
	return true

func _build_rotation_ghost(from_angle: float) -> Control:
	var floating_parent := _get_floating_parent()
	if floating_parent == null:
		return null
	var ghost := duplicate(0) as Control
	ghost.top_level = true
	ghost.z_index = _FLOATING_GHOST_Z_INDEX
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
	floating_parent.add_child(ghost)
	ghost.move_to_front()
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
				_refresh_drag_stats_preview()
			elif card_data.card_type == Card.CardType.CREATURE:
				apply_creature_drag_defensive_preview()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and _dragging:
		if event.keycode == KEY_S and _can_toggle_drag_prepare():
			_drag_stealth = not _drag_stealth
			_set_drag_prepare_preview(_drag_stealth)
			_refresh_drag_stats_preview()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_S and card_data.card_type == Card.CardType.CREATURE:
			apply_creature_drag_stealth_preview()
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
	_drag_ghost.global_position = _clamp_drag_ghost_position(
		get_viewport().get_mouse_position() - rotated_half
	)

func _clamp_drag_ghost_position(target_pos: Vector2) -> Vector2:
	if _drag_ghost == null or not is_instance_valid(_drag_ghost):
		return target_pos
	var viewport_size := get_viewport().get_visible_rect().size
	var ghost_size := _drag_ghost.size
	if ghost_size.x <= 0.0 or ghost_size.y <= 0.0:
		ghost_size = _drag_ghost.get_combined_minimum_size()
	var rect := _get_drag_ghost_bounds(target_pos, ghost_size)
	var padding := 4.0
	var correction := Vector2.ZERO
	if rect.position.x < padding:
		correction.x = padding - rect.position.x
	elif rect.end.x > viewport_size.x - padding:
		correction.x = viewport_size.x - padding - rect.end.x
	if rect.position.y < padding:
		correction.y = padding - rect.position.y
	elif rect.end.y > viewport_size.y - padding:
		correction.y = viewport_size.y - padding - rect.end.y
	return target_pos + correction

func _get_drag_ghost_bounds(target_pos: Vector2, ghost_size: Vector2) -> Rect2:
	var theta := deg_to_rad(_drag_ghost.rotation_degrees)
	var c := cos(theta)
	var s := sin(theta)
	var points := [
		Vector2.ZERO,
		Vector2(ghost_size.x, 0.0),
		Vector2(0.0, ghost_size.y),
		ghost_size,
	]
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for point in points:
		var rotated := Vector2(c * point.x - s * point.y, s * point.x + c * point.y)
		var global_point := target_pos + rotated
		min_point = min_point.min(global_point)
		max_point = max_point.max(global_point)
	return Rect2(min_point, max_point - min_point)

func _get_floating_parent() -> Node:
	var node: Node = self
	while node != null:
		if node is CanvasLayer:
			return node
		node = node.get_parent()
	var viewport := get_viewport()
	if viewport != null:
		return viewport
	var tree := get_tree()
	if tree != null:
		return tree.current_scene
	return null

func _process(delta: float) -> void:
	if not _dragging:
		return
	_sync_creature_drag_preview_from_input_state()
	if not (_drag_ghost and is_instance_valid(_drag_ghost)):
		return
	# Advance rotation toward target in the same tick as the position update so
	# they are never one frame out of step (which caused the wobble when a tween
	# owned rotation_degrees while _process owned position).
	var cur := _drag_ghost.rotation_degrees
	if cur != _drag_target_rotation:
		var step := _DRAG_ROT_SPEED * delta
		_drag_ghost.rotation_degrees = move_toward(cur, _drag_target_rotation, step)
	_update_ghost_position()

func _sync_creature_drag_preview_from_input_state() -> void:
	if card_data == null or card_data.card_type != Card.CardType.CREATURE:
		return
	if Input.is_key_pressed(KEY_S):
		apply_creature_drag_stealth_preview()
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		apply_creature_drag_defensive_preview()

func _start_drag() -> void:
	_hide_hover_panel()
	# Flush any in-flight hand-rotation ghost so _inner is fully visible and
	# correctly rotated before _build_drag_ghost() duplicates it.
	if _rot_ghost or _rot_tween:
		_cancel_rot_ghost()
		_inner.rotation_degrees = 0.0
		_inner.pivot_offset = size / 2.0
	var tree := get_tree()
	var floating_parent := _get_floating_parent()
	if tree == null or floating_parent == null:
		return
	_dragging = true
	_drag_ghost = _build_drag_ghost()
	_drag_target_rotation = _drag_ghost.rotation_degrees  # already at correct angle
	# Reparent to scene root so the hand HBox collapses the gap,
	# but the node stays in the tree so _input() keeps firing.
	_drag_parent = get_parent()
	_drag_index = get_index()
	_drag_parent.remove_child(self)
	floating_parent.add_child(self)
	visible = false
	if _drag_ghost != null and is_instance_valid(_drag_ghost):
		floating_parent.add_child(_drag_ghost)
		_drag_ghost.move_to_front()
		_recompact_drag_ghost()
		call_deferred("_recompact_drag_ghost")
		_update_ghost_position()

func _build_drag_ghost() -> Control:
	if card_data != null and card_data.card_type == Card.CardType.CREATURE:
		return _build_creature_board_drag_ghost()
	var ghost := duplicate(0) as Control
	ghost.top_level = true
	ghost.z_index = _FLOATING_GHOST_Z_INDEX
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate.a = 1.0
	ghost.scale = Vector2(1.0, 1.0)
	var sz := size
	if sz.y == 0:
		sz = get_combined_minimum_size()
	ghost.pivot_offset = Vector2.ZERO   # centering is handled in _update_ghost_position
	# Consolidate _inner's rotation onto the ghost outer so the whole ghost
	# can be rotated cleanly during drag (ghost is at scene root, no Container).
	if _inner:
		ghost.rotation_degrees = 0.0
		var ghost_inner := ghost.get_child(0) as Control
		if ghost_inner:
			ghost_inner.rotation_degrees = 0.0
			ghost_inner.pivot_offset = Vector2.ZERO
			_compact_drag_ghost(ghost, ghost_inner)
			sz = ghost.size
	_drag_ghost_pivot = sz / 2.0
	_drag_ghost = ghost
	_set_drag_prepare_preview(_drag_stealth and _can_toggle_drag_prepare())
	_refresh_drag_summon_preview()
	_refresh_drag_ghost_level_preview()
	_drag_ghost = null
	return ghost

func _build_creature_board_drag_ghost() -> Control:
	var ghost := BoardZoneUIScript.new()
	ghost.top_level = true
	ghost.z_index = _FLOATING_GHOST_Z_INDEX
	ghost.z_as_relative = false
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.viewer_override = _hover_viewer if _hover_viewer != null else card_data.card_owner
	ghost.custom_minimum_size = BoardZoneUIScript.get_zone_size()
	ghost.size = BoardZoneUIScript.get_zone_size()
	ghost.pivot_offset = Vector2.ZERO
	ghost.rotation_degrees = 0.0
	_drag_ghost_pivot = ghost.size / 2.0
	return ghost

func _compact_drag_ghost(ghost: Control, ghost_inner: Control) -> void:
	_remove_drag_ghost_rules_text(ghost)
	var compact_size := Vector2(float(_card_width), _compute_compact_height())
	ghost.clip_contents = true
	ghost.custom_minimum_size = compact_size
	ghost.size = compact_size
	ghost_inner.clip_contents = true
	ghost_inner.custom_minimum_size = compact_size
	ghost_inner.size = compact_size
	if ghost_inner.get_child_count() > 0:
		var content := ghost_inner.get_child(0) as Control
		if content != null:
			content.clip_contents = true
			content.custom_minimum_size = compact_size
			content.size = compact_size
			content.update_minimum_size()
	ghost_inner.update_minimum_size()
	ghost.update_minimum_size()

func _recompact_drag_ghost() -> void:
	if not (_drag_ghost and is_instance_valid(_drag_ghost)):
		return
	if _drag_ghost is BoardZoneUI:
		_drag_ghost_pivot = _drag_ghost.size / 2.0
		_refresh_drag_summon_preview()
		_update_ghost_position()
		return
	var ghost_inner := _drag_ghost.get_child(0) as Control
	if ghost_inner == null:
		return
	_compact_drag_ghost(_drag_ghost, ghost_inner)
	_drag_ghost_pivot = _drag_ghost.size / 2.0
	_refresh_drag_ghost_level_preview()
	_refresh_drag_summon_preview()
	_update_ghost_position()

func _remove_drag_ghost_rules_text(node: Node) -> void:
	if node is RichTextLabel:
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.queue_free()
		return
	for child in node.get_children().duplicate():
		_remove_drag_ghost_rules_text(child)

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
		_inner.rotation_degrees = 0.0
		_inner.pivot_offset = size / 2.0
	var was_stealth := _drag_stealth
	_drag_stealth = false
	card_drag_released.emit(card_data, drop_pos, is_rotated, was_stealth)

func _show_hover_panel() -> void:
	var floating_parent := _get_floating_parent()
	if floating_parent == null:
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
	var hover_body := CardDetailContentBuilderScript.build_visual_hover_body(
		card_data,
		_hover_viewer,
		{
			"content_width": _HOVER_PANEL_WIDTH - 20.0,
			"display_mana_cost": _get_display_mana_cost(),
			"display_cost_adjustment_lines": _display_cost_adjustment_lines
		}
	)
	panel.add_child(hover_body)

	floating_parent.add_child(panel)
	if hover_body is ScrollContainer:
		var hover_scroll := hover_body as ScrollContainer
		CardDetailContentBuilderScript.apply_deckbuilder_scrollbar_style(hover_scroll, true)
		hover_scroll.ready.connect(Callable(self, "_apply_hover_scrollbar_style").bind(hover_scroll), CONNECT_ONE_SHOT)
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

func _apply_hover_scrollbar_style(scroll: ScrollContainer) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	CardDetailContentBuilderScript.apply_deckbuilder_scrollbar_style(scroll, true)

func _hide_hover_panel() -> void:
	if _hover_panel and is_instance_valid(_hover_panel):
		_hover_panel.queue_free()
	_hover_panel = null

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			_bind_visual_state()
		NOTIFICATION_EXIT_TREE:
			_unbind_visual_state()
		NOTIFICATION_RESIZED:
			# Safe: setting _inner.pivot_offset only notifies self (outer),
			# not the HBoxContainer, so no re-sort cascade.
			if _inner:
				_inner.pivot_offset = size / 2.0
			_layout_power_lock_overlay()
		NOTIFICATION_MOUSE_ENTER:
			if _hand_mode:
				if not _picked_up:
					hand_hovered.emit(self)
				return
			if (not _disabled or _hover_preview_when_disabled) and not _picked_up:
				pivot_offset = size / 2.0
				z_index = _base_z_index + 50
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)
				_show_hover_panel()
		NOTIFICATION_MOUSE_EXIT:
			if _hand_mode:
				if not _picked_up:
					hand_unhovered.emit(self)
				return
			if not _picked_up:
				z_index = _base_z_index
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
			_hide_hover_panel()
