class_name DebuffBadge
extends RefCounted

const SIZE := 50.0
const GAP := 4.0

static func create(preview: Control, count: int = 1) -> PanelContainer:
	if preview == null:
		return null
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.02, 0.02, 0.95)
	style.border_color = Color(1.0, 0.28, 0.24, 0.98)
	style.shadow_color = Color(0.28, 0.02, 0.02, 0.52)
	style.shadow_size = 4
	style.corner_radius_top_left = 11
	style.corner_radius_top_right = 11
	style.corner_radius_bottom_left = 11
	style.corner_radius_bottom_right = 11
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	badge.add_theme_stylebox_override("panel", style)
	badge.add_child(preview)

	if count > 1:
		var count_label := Label.new()
		count_label.text = str(count)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.add_theme_font_size_override("font_size", 9)
		count_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.94))
		count_label.add_theme_color_override("font_shadow_color", Color(0.22, 0.0, 0.0, 0.9))
		count_label.add_theme_constant_override("shadow_offset_x", 1)
		count_label.add_theme_constant_override("shadow_offset_y", 1)
		count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_label.offset_left = -10
		count_label.offset_top = -10
		count_label.offset_right = 0
		count_label.offset_bottom = 0
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(count_label)

	return badge
