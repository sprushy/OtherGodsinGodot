extends PanelContainer

const SYMBOL_TEXTURE := preload("res://images/ui/followers/FollowersSymbol.svg")
const COUNT_COLOR := Color(1.0, 0.94, 0.74)
const LOSS_COLOR := Color(1.0, 0.18, 0.14)
const LOSS_FLASH_SECONDS := 0.7

var _count_label: Label
var _loss_flash_started_msec: int = -1

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(76, 32)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.035, 0.97)
	style.border_color = Color(0.88, 0.69, 0.32)
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
	set_process(false)

func set_followers(count: int, show_caption: bool = false) -> void:
	var count_text := "Followers: %d" % count
	var label_text := count_text if show_caption else str(count)
	if _count_label.text != label_text:
		_count_label.text = label_text
	tooltip_text = count_text

func show_loss_flash(started_msec: int) -> void:
	_loss_flash_started_msec = started_msec
	_process(0.0)

func _process(_delta: float) -> void:
	var elapsed := float(Time.get_ticks_msec() - _loss_flash_started_msec) / 1000.0
	var active := _loss_flash_started_msec >= 0 and elapsed < LOSS_FLASH_SECONDS
	var color := COUNT_COLOR
	if active:
		# Hold red briefly, then fade back; use elapsed time to survive board redraws.
		var fade := clampf((elapsed - 0.15) / (LOSS_FLASH_SECONDS - 0.15), 0.0, 1.0)
		color = LOSS_COLOR.lerp(COUNT_COLOR, fade)
	_count_label.add_theme_color_override("font_color", color)
	set_process(active)
