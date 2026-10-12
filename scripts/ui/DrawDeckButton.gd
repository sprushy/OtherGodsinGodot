extends Button

const CARD_BACK := preload("res://images/cardbackAI.png")
const CARD_PROTECTOR := preload("res://images/ui/zones/snow_gargoyle_card_protector_cw45.png")
const OPPONENT_CARD_PROTECTOR := preload("res://images/ui/zones/snow_gargoyle_card_protector_opponent_v7.png")
const OPPONENT_PROTECTOR_SCALE := 0.94
const CARD_PROTECTOR_SCALE := 1.25
const GOLD := Color(0.91, 0.74, 0.40)
const CARD_SIZE := Vector2(104.0, 157.0)
const CARD_LAYER_OFFSET := Vector2(0.3, 0.55)
const MAX_VISIBLE_STACK_LAYERS := 40
const PAPER_SEAM_WIDTH := 0.35
const PAPER_EDGE := Color(0.82, 0.79, 0.72)
const PAPER_SEAM := Color(0.51, 0.48, 0.41)
const PAPER_SIDE_SEAM := Color(0.60, 0.56, 0.48)
const COUNT_CHANGE_DISPLAY_MSEC := 2500
const SHELVE_INSERT_OFFSET := Vector2(28.0, 38.0)
const MINIMUM_HEIGHT := 216.0
const PEEL_SEGMENTS := 32
const PEEL_SLIDE := 56.0
const PEEL_BEND_START := 0.65
const PEEL_BEND_ANGLE := 1.15

var _deck_count: int = 0
var _hover_amount: float = 0.0
var _card_protector_enabled: bool = false
var _draw_available: bool = false
var _opponent_view: bool = false
var _opponent_draw_available: bool = false
var _protector_side_amount: float = 0.0
var _stack_card_style: StyleBoxFlat
var _stack_shadow_style: StyleBoxFlat
# Canvas drawing is deferred, so the textured mesh must outlive _draw().
var _peeled_card_mesh := ArrayMesh.new()
var _count_visible_until_msec: int = 0
var choice_highlight_amount: float = 0.0:
	set(value):
		choice_highlight_amount = value
		queue_redraw()

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
	_stack_card_style.bg_color = PAPER_EDGE
	_stack_card_style.set_corner_radius_all(6)
	_stack_shadow_style = _stack_card_style.duplicate() as StyleBoxFlat
	_stack_shadow_style.bg_color = Color(0.16, 0.14, 0.10)
	_stack_shadow_style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	_stack_shadow_style.shadow_size = 4
	_stack_shadow_style.shadow_offset = Vector2(2.0, 3.0)
	resized.connect(queue_redraw)

func set_deck_count(count: int) -> void:
	var next_count := maxi(0, count)
	if _deck_count == next_count:
		_update_tooltip()
		return
	if _deck_count != next_count:
		show_deck_count_temporarily()
	_deck_count = next_count
	_update_tooltip()
	update_minimum_size()
	queue_redraw()

func _update_tooltip() -> void:
	if _opponent_view:
		tooltip_text = "%d cards remaining in the opponent's deck" % _deck_count
	else:
		var choice_text := "Choose +1 card instead of extra mana." if _draw_available else "Choose +1 card at the start of your turn."
		tooltip_text = "%s\n%d cards remaining in your deck" % [choice_text, _deck_count]

func show_deck_count_temporarily() -> void:
	_count_visible_until_msec = Time.get_ticks_msec() + COUNT_CHANGE_DISPLAY_MSEC
	queue_redraw()

func set_card_protector_enabled(enabled: bool) -> void:
	_card_protector_enabled = enabled
	_protector_side_amount = 1.0 if enabled and not disabled else 0.0
	queue_redraw()

func set_draw_available(available: bool) -> void:
	_draw_available = available
	_update_tooltip()
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
	return Rect2(Vector2(card_x, 12.0), CARD_SIZE)

func _get_stack_offset() -> Vector2:
	return CARD_LAYER_OFFSET * float(_get_visible_stack_layers())

func _get_visible_stack_layers() -> int:
	return mini(MAX_VISIBLE_STACK_LAYERS, maxi(0, _deck_count - 1))

func get_shelve_insert_rect() -> Rect2:
	var top := get_top_card_rect()
	return Rect2(top.position + _get_stack_offset() + SHELVE_INSERT_OFFSET, CARD_SIZE)

func get_bottom_card_rotation() -> float:
	return 0.0

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
	return PI if _opponent_view else 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var can_peel := _deck_count > 0 and _is_draw_available() and (not disabled or _opponent_view)
	var hover_target := 1.0 if can_peel and (is_hovered() or has_focus()) else 0.0
	_hover_amount = move_toward(_hover_amount, hover_target, delta * (3.6 if hover_target > 0.0 else 4.5))
	if _card_protector_enabled:
		_protector_side_amount = move_toward(_protector_side_amount, 1.0 if _is_draw_available() else 0.0, delta * 4.0)
	queue_redraw()

func _draw() -> void:
	var top := get_top_card_rect()
	var center := top.get_center()
	if _deck_count > 0:
		# Ground the whole stack; a shadow on the top card hides the paper seams.
		draw_style_box(_stack_shadow_style, Rect2(top.position + _get_stack_offset(), CARD_SIZE))
		# Cap visible thickness for large decks. Smaller stacks lose one layer
		# per draw, and a single remaining card is flat.
		for i in range(_get_visible_stack_layers(), 0, -1):
			var layer := Rect2(top.position + CARD_LAYER_OFFSET * float(i), CARD_SIZE)
			draw_style_box(_stack_card_style, layer)
			# Thin seams leave a bright paper band between cards, with a darker
			# right edge to distinguish the two exposed sides of the stack.
			draw_line(Vector2(layer.position.x + 6.0, layer.end.y), Vector2(layer.end.x - 6.0, layer.end.y), PAPER_SEAM, PAPER_SEAM_WIDTH, true)
			draw_line(Vector2(layer.end.x, layer.position.y + 6.0), Vector2(layer.end.x, layer.end.y - 6.0), PAPER_SIDE_SEAM, PAPER_SEAM_WIDTH, true)
			draw_arc(layer.end - Vector2(6.0, 6.0), 6.0, 0.0, PI * 0.5, 8, PAPER_SEAM, PAPER_SEAM_WIDTH, true)
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
	var caption := "Draw" if _opponent_view else "+1 card"
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
	if choice_highlight_amount > 0.0 and _draw_available and not disabled and not _opponent_view:
		# Layer soft shadows behind the card for a green halo with no hard border.
		for spread in [22, 14, 7]:
			var aura := StyleBoxFlat.new()
			aura.bg_color = Color.TRANSPARENT
			aura.set_corner_radius_all(7)
			aura.shadow_color = Color(0.25, 1.0, 0.48, 0.32 * choice_highlight_amount)
			aura.shadow_size = spread
			draw_style_box(aura, rect.grow(2.0))
	# A second card stays on the deck while only the top sheet bends away.
	# A lone remaining card has no duplicate underneath it.
	if _hover_amount > 0.0 and _deck_count == 1:
		_draw_peeled_card(tint)
		draw_set_transform(Vector2.ZERO)
		return
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color(0.12, 0.10, 0.065)
	edge.border_color = Color(GOLD, 0.8)
	edge.set_border_width_all(1)
	edge.set_corner_radius_all(6)
	draw_style_box(edge, rect.grow(1.0))
	draw_texture_rect(CARD_BACK, rect, false, tint)
	if _hover_amount > 0.0:
		_draw_peeled_card(tint)
	draw_set_transform(Vector2.ZERO)

func _draw_peeled_card(tint: Color) -> void:
	var peel := smoothstep(0.0, 1.0, _hover_amount)
	var slide := PEEL_SLIDE * smoothstep(0.0, 0.9, _hover_amount)
	var bend_angle := PEEL_BEND_ANGLE * smoothstep(0.15, 1.0, _hover_amount)
	var bend_length := CARD_SIZE.y * (1.0 - PEEL_BEND_START)
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	var shadow_left := PackedVector2Array()
	var shadow_right := PackedVector2Array()
	for row in range(PEEL_SEGMENTS + 1):
		var v := float(row) / float(PEEL_SEGMENTS)
		var surface_y := (v - 0.5) * CARD_SIZE.y + slide
		var height := 0.0
		var local_angle := 0.0
		if v > PEEL_BEND_START and bend_angle > 0.001:
			# Roll only the lower third into a cylindrical curve. Project its
			# height upward while preserving the length of the paper along the arc.
			var radius := bend_length / bend_angle
			local_angle = bend_angle * (v - PEEL_BEND_START) / (1.0 - PEEL_BEND_START)
			height = radius * (1.0 - cos(local_angle))
			surface_y = (PEEL_BEND_START - 0.5) * CARD_SIZE.y + slide + radius * sin(local_angle) - height * 0.38
		# Rounded paper corners follow the bend instead of stretching square.
		var corner_distance := minf(v, 1.0 - v) * CARD_SIZE.y
		var inset := 0.0
		if corner_distance < 6.0:
			inset = 6.0 - sqrt(36.0 - pow(6.0 - corner_distance, 2.0))
		var row_light := 1.0 - 0.24 * (1.0 - cos(local_angle))
		for side in range(2):
			var u := (inset / CARD_SIZE.x) if side == 0 else (1.0 - inset / CARD_SIZE.x)
			# Both corners rise together: the card pulls straight down without twisting.
			var point := Vector2((u - 0.5) * CARD_SIZE.x, surface_y)
			vertices.append(point)
			uvs.append(Vector2(u, v))
			colors.append(Color(row_light, row_light, row_light, 1.0))
			# Project the lifted portion's shadow back down onto the deck/table.
			var shadow_point := point + Vector2(2.0 * peel, 2.0 * peel + height * 0.65)
			if side == 0:
				left_edge.append(point)
				shadow_left.append(shadow_point)
			else:
				right_edge.append(point)
				shadow_right.append(shadow_point)
		if row < PEEL_SEGMENTS:
			var i := row * 2
			indices.append_array(PackedInt32Array([i, i + 1, i + 2, i + 1, i + 3, i + 2]))
	var outline := left_edge.duplicate()
	var shadow_outline := shadow_left.duplicate()
	for row in range(PEEL_SEGMENTS, -1, -1):
		outline.append(right_edge[row])
		shadow_outline.append(shadow_right[row])
	draw_colored_polygon(shadow_outline, Color(0.0, 0.0, 0.0, 0.17 * peel))
	shadow_outline.append(shadow_outline[0])
	for width in [10.0, 6.0, 3.0]:
		draw_polyline(shadow_outline, Color(0.0, 0.0, 0.0, 0.035 * peel), width, true)
	# A single textured mesh keeps the artwork continuous across the curve.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_peeled_card_mesh.clear_surfaces()
	_peeled_card_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	draw_mesh(_peeled_card_mesh, CARD_BACK, Transform2D.IDENTITY, tint)
	outline.append(outline[0])
	draw_polyline(outline, Color(PAPER_EDGE, 0.7 * peel), 1.4, true)
	draw_polyline(outline, Color(0.12, 0.10, 0.065, 0.8), 0.6, true)

func _draw_centered_text(value: String, baseline: float, font_size: int, color: Color) -> void:
	var font := get_theme_font("font")
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
