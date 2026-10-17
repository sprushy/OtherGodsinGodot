extends ColorRect
## A self-contained match recap. The controller keeps ownership of navigation.

signal review_requested
signal replay_requested
signal rematch_requested
signal menu_requested

const TextureCache = preload("res://scripts/ui/UITextureCache.gd")
const TITLE_FONT = preload("res://fonts/custom_ui/Norsebold.otf")
const GOLD := Color("eac67d")
const INK := Color("101725")
const MUTED := Color("a7b3c8")
const WHITE := Color("f4efe4")

var _panel: PanelContainer
var _awards: GridContainer
var _spark_time := 0.0

func build(result_title: String, message: String, stats: Dictionary, reason: String, can_rematch: bool, can_replay: bool, auto_return: bool, animate: bool = true) -> void:
	name = "GameResultOverlay"
	color = Color(0.025, 0.035, 0.065, 0.97)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(INK, Color("796344"), 24, 24))
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	_label(body, "O T H E R   G O D S   /   M A T C H   C O M P L E T E", 13, GOLD)
	var title := _label(body, result_title.to_upper(), 66, GOLD if result_title != "Defeat" else Color("da9c96"))
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_color_override("font_shadow_color", Color(0.8, 0.5, 0.12, 0.25))
	title.add_theme_constant_override("shadow_offset_y", 4)
	_label(body, "A legend written. A pantheon remembered.", 16, MUTED)
	_label(body, message, 16, WHITE)
	var turns := int(stats.get("turns", 0))
	var seconds := int(stats.get("duration_seconds", 0))
	_label(body, "%d TURNS   /   %d:%02d   /   THE FINAL CHRONICLE" % [turns, seconds / 60, seconds % 60], 13, GOLD)
	_rule(body)
	_label(body, "HALL OF LEGENDS", 18, GOLD)
	_label(body, "Awards across both pantheons · damage counts actual enemy followers lost", 13, MUTED)
	_awards = GridContainer.new()
	_awards.columns = 3
	_awards.add_theme_constant_override("h_separation", 14)
	_awards.add_theme_constant_override("v_separation", 14)
	body.add_child(_awards)
	_award("01   /   MVP", "The heaviest hitter", stats.get("mvp", {}), stats, "total damage", "No damage dealt", GOLD)
	var finisher_empty := "No card finisher"
	if reason in ["forfeit", "match_forfeit"]:
		finisher_empty = "Won by forfeit"
	elif reason == "draw":
		finisher_empty = "A shared fate"
	_award("02   /   KILLING BLOW", "The final word", stats.get("killing_blow", {}), stats, "final damage", finisher_empty, Color("e5a095"))
	_award("03   /   BIGGEST HIT", "One unforgettable strike", stats.get("biggest_hit", {}), stats, "damage in one hit", "No damage dealt", Color("91cfcd"))
	if not stats.is_empty():
		_rule(body)
		_label(body, "THE MATCH IN NUMBERS", 16, GOLD)
		_scoreboard(body, stats)
	else:
		_label(body, "Detailed statistics are unavailable for this match.", 14, MUTED)
	_rule(body)
	if auto_return:
		_label(body, "Returning to menu…", 16, MUTED)
	else:
		var buttons := HFlowContainer.new()
		buttons.alignment = FlowContainer.ALIGNMENT_CENTER
		buttons.add_theme_constant_override("h_separation", 10)
		buttons.add_theme_constant_override("v_separation", 10)
		body.add_child(buttons)
		_button(buttons, "Review Board", review_requested.emit)
		var replay := _button(buttons, "View Replay", replay_requested.emit)
		replay.disabled = not can_replay
		replay.tooltip_text = "Watch the match unfold again" if can_replay else "No replay history for this match"
		if can_rematch:
			_button(buttons, "Offer Rematch", rematch_requested.emit, true)
		var menu := _button(buttons, "Back to Menu", menu_requested.emit, not can_rematch)
		menu.grab_focus.call_deferred()
	resized.connect(_layout)
	_layout()
	if animate:
		_panel.modulate.a = 0.0
		create_tween().tween_property(_panel, "modulate:a", 1.0, 0.45)
	set_process(animate)

func _style(background: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _label(parent: Node, text: String, font_size: int, tint: Color, centered: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _rule(parent: Node) -> void:
	var rule := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color(0.8, 0.66, 0.4, 0.22)
	style.thickness = 1
	rule.add_theme_stylebox_override("separator", style)
	parent.add_child(rule)

func _award(title: String, subtitle: String, entry: Dictionary, stats: Dictionary, unit: String, empty_text: String, accent: Color) -> void:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", _style(Color("172132"), Color(accent, 0.45), 14, 14))
	_awards.add_child(tile)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	tile.add_child(column)
	_label(column, title, 15, accent)
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size.y = 124
	portrait.clip_contents = true
	portrait.add_theme_stylebox_override("panel", _style(Color("0b111c"), Color(accent, 0.2), 8, 0))
	column.add_child(portrait)
	var art_path := str(entry.get("art_path", ""))
	if not art_path.is_empty() and ResourceLoader.exists(art_path):
		var art := TextureRect.new()
		art.texture = TextureCache.get_texture(art_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(art)
		var wash := TextureRect.new()
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.03, 0.04, 0.07, 0.0))
		gradient.set_color(1, Color(0.03, 0.04, 0.07, 0.8))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill_from = Vector2(0, 0)
		texture.fill_to = Vector2(0, 1)
		wash.texture = texture
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(wash)
	else:
		var emblem := _label(portrait, "◇", 64, accent)
		emblem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var card_name := str(entry.get("name", empty_text))
	var card_label := _label(column, card_name, 20, WHITE)
	card_label.custom_minimum_size.y = 44
	card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_label.tooltip_text = card_name
	var owner := "—"
	var players: Array = stats.get("players", [])
	var index := int(entry.get("player_index", -1))
	if index >= 0 and index < players.size():
		owner = str(players[index].get("name", ""))
	_label(column, owner, 13, MUTED)
	_label(column, str(entry.get("damage", "—")), 34, accent)
	_label(column, unit if not entry.is_empty() else "No eligible card", 13, MUTED)
	_label(column, subtitle, 13, accent)

func _scoreboard(parent: Node, stats: Dictionary) -> void:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)
	for heading in ["PANTHEON", "DAMAGE", "RESTORED", "SUMMONS", "FOLLOWERS"]:
		var label := _label(grid, heading, 12, MUTED, heading != "PANTHEON")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for player: Dictionary in stats.get("players", []):
		var name_label := _label(grid, str(player.get("name", "Player")), 15, WHITE, false)
		name_label.custom_minimum_size.x = 80
		name_label.tooltip_text = name_label.text
		for key in ["damage", "restored", "summoned", "followers"]:
			_label(grid, str(player.get(key, 0)), 20, GOLD)
	_label(parent, "Restored includes converted followers. United Front damage is shared by strength; joint finishers are named together.", 12, MUTED)

func _button(parent: Node, text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(148, 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", INK if primary else WHITE)
	button.add_theme_color_override("font_hover_color", INK if primary else WHITE)
	button.add_theme_color_override("font_focus_color", INK if primary else WHITE)
	button.add_theme_stylebox_override("normal", _style(GOLD if primary else Color("1c293d"), GOLD if primary else Color("4a586f"), 8, 12))
	button.add_theme_stylebox_override("hover", _style(Color("f7da9f") if primary else Color("2b3c55"), GOLD, 8, 12))
	button.add_theme_stylebox_override("pressed", _style(Color("c2a268") if primary else Color("101725"), GOLD, 8, 12))
	var focus := _style(Color.TRANSPARENT, WHITE, 8, 0)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _layout() -> void:
	if _panel == null:
		return
	var extent := Vector2(minf(1140, maxf(260, size.x - 48)), minf(940, maxf(240, size.y - 48)))
	_panel.size = extent
	_panel.position = (size - extent) * 0.5
	_awards.columns = 1 if extent.x < 730 else 3
	queue_redraw()

func _process(delta: float) -> void:
	_spark_time += delta
	queue_redraw()

func _draw() -> void:
	var center := size * Vector2(0.5, 0.44)
	for radius in [360.0, 430.0, 500.0]:
		draw_arc(center, radius, 0, TAU, 100, Color(0.85, 0.68, 0.36, 0.08), 1.0, true)
	for i in 38:
		var x := fmod(float(i * 157 + 31), maxf(1, size.x))
		var y := fposmod(float(i * 97) - _spark_time * (8 + i % 4), maxf(1, size.y))
		var alpha := 0.16 + 0.14 * sin(float(i) + _spark_time)
		draw_circle(Vector2(x, y), 1.2 + float(i % 3) * 0.4, Color(GOLD, alpha), true, -1, true)
