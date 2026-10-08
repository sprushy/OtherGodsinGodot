extends Button

const CARD_BACK := preload("res://images/cardbackAI.png")
const CARD_PROTECTOR := preload("res://images/ui/zones/snow_gargoyle_card_protector_cw45.png")
const OPPONENT_CARD_PROTECTOR := preload("res://images/ui/zones/snow_gargoyle_card_protector_opponent_v7.png")
const OPPONENT_PROTECTOR_SCALE := 0.94
const CARD_PROTECTOR_SCALE := 1.25
const GOLD := Color(0.91, 0.74, 0.40)
const CARD_SIZE := Vector2(104.0, 157.0)
const CARD_LAYER_OFFSET := Vector2(0.32, 0.65)
const DECK_ROTATION_DEGREES := -2.0
const COUNT_CHANGE_DISPLAY_MSEC := 2500
const SHELVE_INSERT_OFFSET := Vector2(28.0, 38.0)
const MINIMUM_HEIGHT := 216.0

var _deck_count: int = 0
var _hover_amount: float = 0.0
var _card_protector_enabled: bool = false
var _draw_available: bool = false
var _opponent_view: bool = false
var _opponent_draw_available: bool = false
var _protector_side_amount: float = 0.0
var _stack_card_style: StyleBoxFlat
var _count_visible_until_msec: int = 0

func _get_minimum_size() -> Vector2:
	# Keep even unusually large decks inside the clickable area.
	var stack_offset := _get_stack_offset()
	return Vector2(
		maxf(180.0, CARD_SIZE.x + stack_offset.x + 24.0),
		maxf(MINIMUM_HEIGHT, CARD_SIZE.y + stack_offset.y + 24.0)
	)

func _ready() -> void:
	custom_minimum_size = Vector2(196.0, MINIMUM_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color", "font_outline_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	_stack_card_style = StyleBoxFlat.new()
	_stack_card_style.bg_color = Color(0.73, 0.71, 0.64)
	_stack_card_style.border_color = Color(0.32, 0.30, 0.25)
	_stack_card_style.set_border_width_all(1)
	_stack_card_style.set_corner_radius_all(6)
	resized.connect(queue_redraw)

func set_deck_count(count: int) -> void:
	var next_count := maxi(0, count)
	var next_tooltip := "%d cards remaining in the opponent's deck" % next_count if _opponent_view else "%d cards remaining in your deck" % next_count
	if _deck_count == next_count and tooltip_text == next_tooltip:
		return
	if _deck_count != next_count:
		show_deck_count_temporarily()
	_deck_count = next_count
	tooltip_text = next_tooltip
	update_minimum_size()
	queue_redraw()

func show_deck_count_temporarily() -> void:
	_count_visible_until_msec = Time.get_ticks_msec() + COUNT_CHANGE_DISPLAY_MSEC
	queue_redraw()

func set_card_protector_enabled(enabled: bool) -> void:
	_card_protector_enabled = enabled
	_protector_side_amount = 1.0 if enabled and not disabled else 0.0
	queue_redraw()

func set_draw_available(available: bool) -> void:
	_draw_available = available
	queue_redraw()

func set_opponent_view(enabled: bool) -> void:
	_opponent_view = enabled
	if enabled:
		disabled = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()

func set_opponent_draw_available(available: bool) -> void:
	_opponent_draw_available = available

func _is_draw_available() -> bool:
	return _opponent_draw_available if _opponent_view else _draw_available

func get_top_card_rect() -> Rect2:
	var card_x := 12.0 if _card_protector_enabled else (size.x - CARD_SIZE.x - _get_stack_offset().x) * 0.5
	return Rect2(Vector2(card_x, 12.0 - _hover_amount * 6.0), CARD_SIZE)

func _get_stack_offset() -> Vector2:
	return CARD_LAYER_OFFSET * float(maxi(0, _deck_count - 1))

func get_shelve_insert_rect() -> Rect2:
	var top := get_top_card_rect()
	return Rect2(top.position + _get_stack_offset() + SHELVE_INSERT_OFFSET, CARD_SIZE)

func get_bottom_card_rotation() -> float:
	return deg_to_rad(DECK_ROTATION_DEGREES)

func insert_shelved_card() -> void:
	# State may already have updated the count before the flight arrived.
	# Reveal it here too, then give it a full display window after insertion.
	show_deck_count_temporarily()
	var back := TextureRect.new()
	back.texture = CARD_BACK
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.show_behind_parent = true
	back.set_meta("shelve_insertion", true)
	back.size = CARD_SIZE
	back.pivot_offset = CARD_SIZE * 0.5
	back.rotation = get_bottom_card_rotation()
	back.position = get_shelve_insert_rect().position
	add_child(back)
	# The deck and protector draw over this card as it slides under the stack.
	var tween := back.create_tween()
	tween.tween_property(back, "position", back.position - SHELVE_INSERT_OFFSET, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(show_deck_count_temporarily)
	tween.tween_callback(back.queue_free)

func clear_shelve_insertions() -> void:
	for child in get_children():
		if child.has_meta("shelve_insertion"):
			child.queue_free()

func get_top_card_rotation() -> float:
	return deg_to_rad(DECK_ROTATION_DEGREES - _hover_amount) + (PI if _opponent_view else 0.0)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var hover_target := 1.0 if _is_draw_available() and (is_hovered() or has_focus()) else 0.0
	_hover_amount = move_toward(_hover_amount, hover_target, delta * 7.0)
	if _card_protector_enabled:
		_protector_side_amount = move_toward(_protector_side_amount, 1.0 if _is_draw_available() else 0.0, delta * 4.0)
	queue_redraw()

func _draw() -> void:
	var top := get_top_card_rect()
	var center := top.get_center()
	if _deck_count > 0:
		# One aligned paper edge per actual card beneath the top card. Each
		# draw removes exactly one layer; a single remaining card is flat.
		for i in range(_deck_count - 1, 0, -1):
			draw_set_transform(center + CARD_LAYER_OFFSET * float(i), deg_to_rad(DECK_ROTATION_DEGREES))
			draw_style_box(_stack_card_style, Rect2(-CARD_SIZE * 0.5, CARD_SIZE))
		draw_set_transform(Vector2.ZERO)
		var tint := Color.WHITE if _is_draw_available() else Color(0.64, 0.62, 0.57)
		_draw_card_back(center, get_top_card_rotation(), tint)
	else:
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color(0.04, 0.045, 0.05, 0.65)
		empty.border_color = Color(GOLD, 0.25)
		empty.set_border_width_all(1)
		empty.set_corner_radius_all(7)
		draw_style_box(empty, top)
		_draw_centered_text("EMPTY", center.y + 5.0, 16, Color(GOLD, 0.55))
	if _card_protector_enabled:
		_draw_card_protector(center)
	if _is_draw_available() and _deck_count > 0:
		_draw_draw_caption(center)
	var hovered := Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
	var remaining_msec := _count_visible_until_msec - Time.get_ticks_msec()
	if hovered or remaining_msec > 0:
		_draw_deck_count(center, 1.0 if hovered else minf(1.0, float(remaining_msec) / 300.0))

func _draw_deck_count(deck_center: Vector2, alpha: float) -> void:
	var font := get_theme_font("font")
	var badge := Rect2(Vector2(deck_center.x + 30.0, 145.0), Vector2(42.0, 24.0))
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.055, 0.06, 0.065, 0.96 * alpha)
	badge_style.border_color = Color(GOLD, 0.65 * alpha)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(12)
	draw_style_box(badge_style, badge)
	var count_text := str(_deck_count)
	var count_width := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, Vector2(badge.get_center().x - count_width * 0.5, badge.position.y + 17.0), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.96, 0.88, 0.70, alpha))

func _draw_draw_caption(deck_center: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var caption := "Draw"
	var font_size := 22
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_set_transform(deck_center)
	var text_position := Vector2(-width * 0.5, 46.0)
	draw_string_outline(font, text_position, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.0, 0.0, 0.0, 0.95))
	draw_string(font, text_position, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.97, 0.89, 0.70))
	draw_set_transform(Vector2.ZERO)

func _draw_card_protector(deck_center: Vector2) -> void:
	var protector_texture := OPPONENT_CARD_PROTECTOR if _opponent_view else CARD_PROTECTOR
	var travel := smoothstep(0.0, 1.0, _protector_side_amount)
	var protector_scale := CARD_PROTECTOR_SCALE * (OPPONENT_PROTECTOR_SCALE if _opponent_view else 1.0)
	var statue_height := lerpf(82.0, 62.0, travel) * protector_scale
	var texture_aspect := float(protector_texture.get_width()) / float(protector_texture.get_height())
	var statue_size := Vector2(statue_height * texture_aspect, statue_height)
	var base := (deck_center + Vector2(0.0, 36.0)).lerp(Vector2(size.x - 26.0, 177.0), travel)
	base.y -= sin(travel * PI) * 18.0
	var rect := Rect2(base - Vector2(statue_size.x * 0.5, statue_size.y), statue_size)
	# The overhead round plinth casts its shadow beneath the full silhouette.
	draw_set_transform(rect.get_center() + Vector2(0.0, 3.0), 0.0, Vector2(1.0, 0.92))
	draw_circle(Vector2.ZERO, statue_size.x * 0.43, Color(0.0, 0.0, 0.0, 0.32), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(protector_texture, rect, false)

func _draw_card_back(center: Vector2, angle: float, tint: Color) -> void:
	draw_set_transform(center, angle)
	var rect := Rect2(-CARD_SIZE * 0.5, CARD_SIZE)
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color(0.12, 0.10, 0.065)
	edge.border_color = Color(GOLD, 0.8)
	edge.set_border_width_all(1)
	edge.set_corner_radius_all(6)
	edge.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	edge.shadow_size = 4
	edge.shadow_offset = Vector2(2.0, 3.0)
	draw_style_box(edge, rect.grow(1.0))
	draw_texture_rect(CARD_BACK, rect, false, tint)
	draw_set_transform(Vector2.ZERO)

func _draw_centered_text(value: String, baseline: float, font_size: int, color: Color) -> void:
	var font := get_theme_font("font")
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
