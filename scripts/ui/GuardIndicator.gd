extends PanelContainer

const SYMBOL_TEXTURE := preload("res://images/ui/guard/GuardSymbol.svg")
const COUNT_COLOR := Color(0.76, 0.92, 1.0)

var _count_label: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(76, 30)
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.2, 0.97)
	style.border_color = Color(0.45, 0.72, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 7
	style.content_margin_right = 9
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 3
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	var symbol := TextureRect.new()
	symbol.texture = SYMBOL_TEXTURE
	symbol.custom_minimum_size = Vector2(24, 24)
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(symbol)
	_count_label = Label.new()
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 20)
	_count_label.add_theme_color_override("font_color", COUNT_COLOR)
	row.add_child(_count_label)

func set_guard(count: int, show_caption: bool = false) -> void:
	var count_text := "Guard: %d" % count
	var label_text := count_text if show_caption else str(count)
	if _count_label.text != label_text:
		_count_label.text = label_text
	tooltip_text = count_text + "\nGuard is lost first when you would take follower damage - Mana Guard."
	visible = count > 0
