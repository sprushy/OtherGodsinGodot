class_name BoardZoneUI
extends PanelContainer

const CardDetailContentBuilder = preload("res://scripts/ui/CardDetailContentBuilder.gd")
const LockedPowerCursor = preload("res://scripts/ui/LockedPowerCursor.gd")
const DefenseShieldOverlay = preload("res://scripts/ui/DefenseShieldOverlay.gd")
const CHAMPIONS_CALL_BADGE_TEXTURE := preload("res://images/Champion's Call Horn Badge.png")
const SMOKING_MIRROR_BADGE_TEXTURE := preload("res://images/Smoking Mirror Icon.png")
const TEZ_SACRIFICE_BADGE_TEXTURE := preload("res://images/TezSacBadge.png")
const TEZ_BLOODSTREAK_TEXTURE := preload("res://images/Bloodstreak.png")
const TEZ_NORMAL_GOD_NAME := "Tezcatlipoca, the Smoking Mirror"
const TEZ_REQUIRED_SACRIFICES := 4
const BASE_BOARD_Z_INDEX := 0
const RAISED_BOARD_Z_INDEX := 2
const GOD_INDICATOR_Z_INDEX := 3
# Keep hovered board cards above the hand fan overlay, but below the larger
# transient previews and modal UI promoted by CombatMockGame.
const HOVER_BOARD_Z_INDEX := 2260
const POPUP_Z_INDEX := 2290

class StackTargetIndicator extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(22, 22)

	func _draw() -> void:
		var center := size * 0.5
		var radius = min(size.x, size.y) * 0.34
		draw_arc(center, radius + 2.0, 0.0, TAU, 36, Color(0.66, 0.44, 0.05, 0.92), 6.0, true)
		draw_arc(center, radius, 0.0, TAU, 36, Color(1.0, 0.87, 0.36, 0.98), 4.0, true)
		draw_arc(center + Vector2(-1.0, -1.0), radius - 1.5, 0.0, PI * 1.35, 24, Color(1.0, 0.97, 0.72, 0.82), 1.4, true)

class BindingHexIndicator extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(18, 18)

	func _draw() -> void:
		var ring_color := Color(0.48, 0.92, 0.88, 0.98)
		var accent_color := Color(0.15, 0.42, 0.44, 0.95)
		draw_arc(Vector2(6.2, 9.0), 3.8, PI * 0.15, PI * 1.85, 18, ring_color, 2.2, true)
		draw_arc(Vector2(11.8, 9.0), 3.8, PI * 1.15, PI * 2.85, 18, ring_color, 2.2, true)
		draw_line(Vector2(7.8, 6.0), Vector2(10.2, 12.0), accent_color, 1.8, true)
		draw_line(Vector2(10.2, 6.0), Vector2(7.8, 12.0), accent_color, 1.8, true)
		draw_circle(Vector2(9.0, 9.0), 1.2, Color(0.85, 1.0, 0.98, 0.95))

class TiamatBroodSlotArt extends Control:
	signal brood_card_clicked(card: Card)

	var cards: Array[Card] = []
	var textures: Array[Texture2D] = []
	var selectable: bool = false
	var _hovered_slice_index: int = -1

	func setup(slot_cards: Array[Card], is_selectable: bool = false) -> void:
		cards = slot_cards.duplicate()
		selectable = is_selectable
		mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if selectable else Control.CURSOR_ARROW
		textures.clear()
		for slot_card in cards:
			if slot_card == null or slot_card.art_path == "":
				textures.append(null)
				continue
			var tex := load(slot_card.art_path) as Texture2D
			textures.append(tex)
		queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE

	func _gui_input(event: InputEvent) -> void:
		if not selectable:
			return
		if event is InputEventMouseMotion:
			_set_hovered_slice_index(_get_slice_index_at_position(event.position))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var clicked_index := _get_slice_index_at_position(event.position)
				if clicked_index >= 0 and clicked_index < cards.size():
					brood_card_clicked.emit(cards[clicked_index])
					accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			_set_hovered_slice_index(_get_slice_index_at_position(get_local_mouse_position()))
		elif what == NOTIFICATION_MOUSE_EXIT:
			_set_hovered_slice_index(-1)

	func _draw() -> void:
		var slice_count := textures.size()
		if slice_count <= 0 or size.x <= 0.0 or size.y <= 0.0:
			return

		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.05, 0.96), true)
		var output_aspect := size.x / size.y
		for slice_index in range(slice_count):
			var left := size.x * float(slice_index) / float(slice_count)
			var right := size.x * float(slice_index + 1) / float(slice_count)
			var dest_rect := Rect2(Vector2(left, 0.0), Vector2(right - left, size.y))
			var tex := textures[slice_index]
			if tex == null:
				continue
			var cover_region := _get_cover_source_region(tex.get_size(), output_aspect)
			var source_left := cover_region.position.x + cover_region.size.x * float(slice_index) / float(slice_count)
			var source_right := cover_region.position.x + cover_region.size.x * float(slice_index + 1) / float(slice_count)
			var source_rect := Rect2(
				Vector2(source_left, cover_region.position.y),
				Vector2(source_right - source_left, cover_region.size.y)
			)
			draw_texture_rect_region(tex, dest_rect, source_rect)

		for slice_index in range(1, slice_count):
			var divider_x := size.x * float(slice_index) / float(slice_count)
			draw_line(
				Vector2(divider_x, 0.0),
				Vector2(divider_x, size.y),
				Color(0.98, 0.9, 0.56, 0.82),
				1.5,
				true
			)
		if selectable and _hovered_slice_index >= 0 and _hovered_slice_index < slice_count:
			var hover_left := size.x * float(_hovered_slice_index) / float(slice_count)
			var hover_right := size.x * float(_hovered_slice_index + 1) / float(slice_count)
			var hover_rect := Rect2(Vector2(hover_left, 0.0), Vector2(hover_right - hover_left, size.y))
			draw_rect(hover_rect, Color(1.0, 0.84, 0.22, 0.12), true)
			draw_rect(hover_rect.grow(-1.0), Color(1.0, 0.92, 0.36, 0.95), false, 2.2)
			draw_rect(hover_rect.grow(-4.0), Color(1.0, 0.98, 0.72, 0.66), false, 1.2)

	func _set_hovered_slice_index(index: int) -> void:
		if _hovered_slice_index == index:
			return
		_hovered_slice_index = index
		queue_redraw()

	func _get_slice_index_at_position(local_position: Vector2) -> int:
		var slice_count := cards.size()
		if slice_count <= 0 or size.x <= 0.0 or size.y <= 0.0:
			return -1
		if local_position.x < 0.0 or local_position.x > size.x or local_position.y < 0.0 or local_position.y > size.y:
			return -1
		return clampi(int(floor(local_position.x / size.x * float(slice_count))), 0, slice_count - 1)

	func _get_cover_source_region(texture_size: Vector2, output_aspect: float) -> Rect2:
		if texture_size.x <= 0.0 or texture_size.y <= 0.0 or output_aspect <= 0.0:
			return Rect2(Vector2.ZERO, texture_size)
		var texture_aspect := texture_size.x / texture_size.y
		if texture_aspect > output_aspect:
			var source_width := texture_size.y * output_aspect
			return Rect2(
				Vector2((texture_size.x - source_width) * 0.5, 0.0),
				Vector2(source_width, texture_size.y)
			)
		var source_height := texture_size.x / output_aspect
		return Rect2(
			Vector2(0.0, (texture_size.y - source_height) * 0.5),
			Vector2(texture_size.x, source_height)
		)

class AttackAura extends Control:
	const _ARC_STEPS := 8

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var outer_rect := Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0))
		if outer_rect.size.x <= 0.0 or outer_rect.size.y <= 0.0:
			return

		_draw_rounded_outline(outer_rect, 11.0, Color(1.0, 0.10, 0.08, 0.10), 12.0)
		_draw_rounded_outline(outer_rect, 11.0, Color(1.0, 0.12, 0.10, 0.18), 8.0)
		_draw_rounded_outline(outer_rect, 11.0, Color(1.0, 0.16, 0.12, 0.30), 4.0)
		_draw_rounded_outline(outer_rect, 11.0, Color(0.98, 0.20, 0.14, 0.95), 2.2)

		var inner_rect := outer_rect.grow(-5.0)
		if inner_rect.size.x > 0.0 and inner_rect.size.y > 0.0:
			_draw_rounded_outline(inner_rect, 7.0, Color(1.0, 0.58, 0.34, 0.78), 1.2)

	func _draw_rounded_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
		var points := _build_rounded_rect_points(rect, radius)
		if points.size() >= 2:
			draw_polyline(points, color, width, true)

	func _build_rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
		var clamped_radius := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var points := PackedVector2Array()
		points.append(rect.position + Vector2(clamped_radius, 0.0))
		_append_arc(
			points,
			rect.position + Vector2(rect.size.x - clamped_radius, clamped_radius),
			-PI * 0.5,
			0.0,
			clamped_radius
		)
		_append_arc(
			points,
			rect.position + Vector2(rect.size.x - clamped_radius, rect.size.y - clamped_radius),
			0.0,
			PI * 0.5,
			clamped_radius
		)
		_append_arc(
			points,
			rect.position + Vector2(clamped_radius, rect.size.y - clamped_radius),
			PI * 0.5,
			PI,
			clamped_radius
		)
		_append_arc(
			points,
			rect.position + Vector2(clamped_radius, clamped_radius),
			PI,
			PI * 1.5,
			clamped_radius
		)
		points.append(points[0])
		return points

	func _append_arc(
		points: PackedVector2Array,
		center: Vector2,
		from_angle: float,
		to_angle: float,
		radius: float
	) -> void:
		for step in range(1, _ARC_STEPS + 1):
			var t := float(step) / float(_ARC_STEPS)
			var angle := lerpf(from_angle, to_angle, t)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)

class TargetAura extends Control:
	const _ARC_STEPS := 8

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var outer_rect := Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0))
		if outer_rect.size.x <= 0.0 or outer_rect.size.y <= 0.0:
			return

		_draw_rounded_outline(outer_rect, 10.0, Color(1.0, 0.80, 0.18, 0.10), 16.0)
		_draw_rounded_outline(outer_rect, 10.0, Color(1.0, 0.84, 0.22, 0.20), 10.0)
		_draw_rounded_outline(outer_rect, 10.0, Color(1.0, 0.88, 0.32, 0.34), 5.0)
		_draw_rounded_outline(outer_rect, 10.0, Color(1.0, 0.92, 0.48, 0.98), 2.6)

		var inner_rect := outer_rect.grow(-6.0)
		if inner_rect.size.x > 0.0 and inner_rect.size.y > 0.0:
			_draw_rounded_outline(inner_rect, 7.0, Color(1.0, 0.97, 0.74, 0.66), 1.2)

	func _draw_rounded_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
		var points := _build_rounded_rect_points(rect, radius)
		if points.size() >= 2:
			draw_polyline(points, color, width, true)

	func _build_rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
		var clamped_radius := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var points := PackedVector2Array()
		points.append(rect.position + Vector2(clamped_radius, 0.0))
		_append_arc(
			points,
			rect.position + Vector2(rect.size.x - clamped_radius, clamped_radius),
			-PI * 0.5,
			0.0,
			clamped_radius
		)
		_append_arc(
			points,
			rect.position + Vector2(rect.size.x - clamped_radius, rect.size.y - clamped_radius),
			0.0,
			PI * 0.5,
			clamped_radius
		)
		_append_arc(
			points,
			rect.position + Vector2(clamped_radius, rect.size.y - clamped_radius),
			PI * 0.5,
			PI,
			clamped_radius
		)
		_append_arc(
			points,
			rect.position + Vector2(clamped_radius, clamped_radius),
			PI,
			PI * 1.5,
			clamped_radius
		)
		points.append(points[0])
		return points

	func _append_arc(
		points: PackedVector2Array,
		center: Vector2,
		from_angle: float,
		to_angle: float,
		radius: float
	) -> void:
		for step in range(1, _ARC_STEPS + 1):
			var t := float(step) / float(_ARC_STEPS)
			var angle := lerpf(from_angle, to_angle, t)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)

signal zone_clicked(zone: Zone)
signal card_clicked(card: Card)
signal champions_call_clicked(card: GodCard)
signal tez_necoc_yaotl_badge_clicked(card: Card)
signal creature_drag_started(card: Card, from_zone: Zone)
signal creature_right_clicked(card: Card)
signal god_right_clicked(card: Card)

var zone: Zone
var game_manager: GameManager
var owning_player: Player
var zone_index: int
var _drop_callback: Callable
var _is_enemy: bool = false
var _popup: Control = null
var _preview_card: Card = null
var _hovered: bool = false
var _pinned: bool = false
var _hide_pending: bool = false
var _defense_overlay: Control = null
var _raised_overlay: Control = null  # non-null for DEF or stealth - floats above the zone row
var _visual_state_card: Card = null
var _badge_hover_popup: Control = null

const BASE_ZONE_EXTENT := 165.0
const DROMI_BINDING_NAME := "Dromi"
const DROMI_BINDING_HOVER_TEXT := "Cannot attack. Losing 7 followers on opponent's turn start - Dromi"
const EQUIPMENT_AFFORDANCE_GAP := 4.0
const DEBUFF_AFFORDANCE_GAP := 4.0
const DEBUFF_BADGE_SIZE := 22.0
const FOLLOWERS_ATTACK_RESULT_SECONDS := 0.66
const POWER_LOCK_TEXTURE := preload("res://images/Norse Power Lock.png")
const ANCIENT_POWER_LOCK_TEXTURE := preload("res://images/Ancient Power Lock.png")
const TIAMAT_GOD_SCRIPT := preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")
const KEYWORD_PANEL_GAP := 8.0
static var _zone_extent: float = BASE_ZONE_EXTENT

var _row_label: String = ""
var _followers_attack_result_text: String = ""
var _followers_attack_result_sequence: int = 0

static func get_base_zone_extent() -> float:
	return BASE_ZONE_EXTENT

static func get_zone_extent() -> float:
	return _zone_extent

static func get_zone_size() -> Vector2:
	return Vector2(_zone_extent, _zone_extent)

static func set_zone_extent(extent: float) -> void:
	_zone_extent = max(BASE_ZONE_EXTENT, floor(extent))

func _get_viewer_player() -> Player:
	if game_manager == null:
		return null
	return game_manager.get_feedback_viewer()

func _is_public_power(card: Card) -> bool:
	return card is PowerCard and ((card as PowerCard).is_publicly_revealed or card.is_temporarily_revealed() or not card.is_face_down)

func _get_card_type_label(card: Card) -> String:
	if card == null:
		return "Card"
	if card.is_god:
		return "God"
	if card.is_power:
		return "Power"
	if card.has_type("Charm"):
		return "Charm"
	match card.card_type:
		Card.CardType.CREATURE:
			return "Creature"
		Card.CardType.CHARM:
			return "Charm"
		Card.CardType.SPELL:
			return "Spell"
		Card.CardType.STRUCTURE:
			return "Structure"
		Card.CardType.HEX:
			return "Hex"
		Card.CardType.EQUIPMENT:
			return "Equipment"
	return "Card"

func _get_power_hover_cost_lines(power: PowerCard) -> Array[String]:
	var lines: Array[String] = []
	if power == null or game_manager == null:
		return lines

	if power.is_face_down:
		var unlock_cost := power.get_unlock_mana_cost(game_manager)
		lines.append("Unlock Cost: %d" % unlock_cost)
		if power.discard_cost > 0:
			lines.append("Discard: %d" % power.discard_cost)
		for breakdown_line in power.get_cost_adjustment_lines(power.mana_cost, Card.COST_KIND_POWER_UNLOCK, game_manager):
			lines.append(breakdown_line)
		return lines

	var hover_data: Dictionary = power.get_activation_cost_hover_data(game_manager)
	if hover_data.is_empty():
		return lines

	var base_cost: int = int(hover_data.get("base_cost", 0))
	var cost_kind: String = str(hover_data.get("cost_kind", Card.COST_KIND_POWER_ACTIVATION))
	var metadata: Dictionary = hover_data.get("metadata", {})
	var label: String = str(hover_data.get("label", "Activation Cost"))
	var current_cost := power.get_adjusted_mana_cost(base_cost, cost_kind, game_manager, metadata)
	lines.append("%s: %d" % [label, current_cost])
	for breakdown_line in power.get_cost_adjustment_lines(base_cost, cost_kind, game_manager, metadata):
		lines.append(breakdown_line)
	for extra_line in hover_data.get("extra_lines", []):
		var text := str(extra_line).strip_edges()
		if text != "":
			lines.append(text)
	return lines

func _can_show_prepared_magical_cost(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	if not card.is_prepared or not card.is_magical_card():
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	return card.get_controller() == _get_viewer_player()

func _get_prepared_magical_cost_player(card: Card) -> Player:
	if card == null:
		return null
	var controller := card.get_controller()
	if controller != null:
		return controller
	return card.card_owner

func _get_prepared_magical_display_mana_cost(card: Card) -> int:
	if not _can_show_prepared_magical_cost(card):
		return 0
	var paying_player := _get_prepared_magical_cost_player(card)
	if paying_player == null:
		return card.mana_cost
	return game_manager.get_prepared_card_activation_mana_cost(paying_player, card)

func _get_prepared_magical_hover_cost_lines(card: Card) -> Array[String]:
	var lines: Array[String] = []
	if not _can_show_prepared_magical_cost(card):
		return lines

	var current_cost := _get_prepared_magical_display_mana_cost(card)
	if current_cost > 0 or card.mana_cost > 0:
		lines.append("Activation Cost: %d" % current_cost)

	var paying_player := _get_prepared_magical_cost_player(card)
	if paying_player != null:
		for breakdown_line in card.get_cost_adjustment_lines(
			card.mana_cost,
			Card.COST_KIND_HAND_PLAY,
			game_manager,
			{"player": paying_player, "prepared": true}
		):
			lines.append(breakdown_line)

	return lines

func _add_sleep_affordance(overlay: Control, card: Card) -> void:
	if card == null or not card.is_sleeping:
		return

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.offset_left = 6
	badge.offset_top = 6
	badge.offset_right = 78
	badge.offset_bottom = 28

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.18, 0.9)
	style.border_color = Color(0.62, 0.8, 1.0, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "SLEEP"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)

	overlay.add_child(badge)

	var haze := ColorRect.new()
	haze.color = Color(0.2, 0.28, 0.45, 0.12)
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(haze)

func _add_speed_badge(overlay: Control, card: Card) -> void:
	if overlay == null or card == null:
		return
	if not is_instance_valid(overlay) or overlay.is_queued_for_deletion():
		return
	if card.speed <= 0:
		return

	var eff_spd := card.get_effective_speed()
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -66
	badge.offset_top = -32
	badge.offset_right = -6
	badge.offset_bottom = -6

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.24, 0.9)
	style.border_color = Color(0.62, 0.8, 1.0, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "SPD:%d" % eff_spd
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if eff_spd > card.speed:
		label.modulate = Color(0.4, 1.0, 0.4)
	elif eff_spd < card.speed:
		label.modulate = Color(1.0, 0.35, 0.35)
	badge.add_child(label)

	if not is_instance_valid(overlay) or overlay.is_queued_for_deletion():
		return
	overlay.add_child(badge)

func _add_prepared_magical_mana_badge(overlay: Control, card: Card) -> void:
	if overlay == null or card == null:
		return
	if not is_instance_valid(overlay) or overlay.is_queued_for_deletion():
		return
	if not _can_show_prepared_magical_cost(card):
		return

	var display_cost := _get_prepared_magical_display_mana_cost(card)
	if display_cost <= 0 and card.mana_cost <= 0:
		return

	var font_color := Color(0.92, 0.97, 1.0)
	if display_cost > card.mana_cost:
		font_color = Color(1.0, 0.7, 0.7)
	elif display_cost < card.mana_cost:
		font_color = Color(0.65, 1.0, 0.72)

	var badge := _add_overlay_stat_badge(
		overlay,
		"M:%d" % display_cost,
		Control.PRESET_TOP_RIGHT,
		-66,
		6,
		-6,
		28,
		font_color
	)
	var tooltip_lines := _get_prepared_magical_hover_cost_lines(card)
	if badge != null and not tooltip_lines.is_empty():
		badge.tooltip_text = "\n".join(tooltip_lines)
		badge.mouse_filter = Control.MOUSE_FILTER_STOP

func _make_field_stat_badge(text: String, font_size: int = 15, font_color: Color = Color(0.92, 0.97, 1.0)) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.24, 0.9)
	style.border_color = Color(0.62, 0.8, 1.0, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)

	return badge

func _add_overlay_stat_badge(
	overlay: Control,
	text: String,
	anchor_preset: int,
	left: float,
	top: float,
	right: float,
	bottom: float,
	font_color: Color = Color(0.92, 0.97, 1.0)
) -> PanelContainer:
	if overlay == null or not is_instance_valid(overlay) or overlay.is_queued_for_deletion():
		return null
	var badge := _make_field_stat_badge(text, 12, font_color)
	badge.set_anchors_preset(anchor_preset)
	badge.offset_left = left
	badge.offset_top = top
	badge.offset_right = right
	badge.offset_bottom = bottom
	overlay.add_child(badge)
	return badge

func _add_level_badge(
	overlay: Control,
	card: Card,
	anchor_preset: int,
	left: float,
	top: float,
	right: float,
	bottom: float
) -> PanelContainer:
	if overlay == null or card == null or card.is_god or card.is_power:
		return null
	var effective_level := card.get_effective_level()
	var font_color := Color(1.0, 0.96, 0.78)
	if effective_level > card.level:
		font_color = Color(0.4, 1.0, 0.4)
	elif effective_level < card.level:
		font_color = Color(1.0, 0.35, 0.35)
	var badge := _add_overlay_stat_badge(
		overlay,
		"LV:%d" % effective_level,
		anchor_preset,
		left,
		top,
		right,
		bottom,
		font_color
	)
	var breakdown := card.get_full_stat_breakdown("lvl")
	if badge != null and breakdown != "":
		badge.tooltip_text = breakdown
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
	return badge

func _add_hidden_creature_stat_badge(
	overlay: Control,
	card: Card,
	is_def: bool,
	eff_str: int,
	_eff_res: int
) -> void:
	if overlay == null or card == null or not is_def:
		return
	var hidden_stat := "str"
	var hidden_base := card.strength
	var hidden_eff := eff_str
	if hidden_eff == hidden_base:
		return

	var hidden_label := "STR:%d" % hidden_eff
	var hidden_font_color := Color(0.92, 0.97, 1.0)
	if hidden_eff > hidden_base:
		hidden_font_color = Color(0.4, 1.0, 0.4)
	elif hidden_eff < hidden_base:
		hidden_font_color = Color(1.0, 0.35, 0.35)

	var hidden_badge := _add_overlay_stat_badge(
		overlay,
		hidden_label,
		Control.PRESET_BOTTOM_LEFT,
		6,
		-58,
		74,
		-32,
		hidden_font_color
	)
	var hidden_breakdown := card.get_full_stat_breakdown(hidden_stat)
	if hidden_badge != null and hidden_breakdown != "":
		hidden_badge.tooltip_text = hidden_breakdown
		hidden_badge.mouse_filter = Control.MOUSE_FILTER_STOP

func _add_power_lock_overlay(overlay: Control, card: Card) -> void:
	if overlay == null or card == null:
		return
	if card.card_type != Card.CardType.POWER or not card.is_face_down:
		return
	if _is_public_power(card) or card.is_temporarily_revealed():
		return
	_add_power_lock_texture_overlay(overlay, card)

func _add_playing_aura(overlay: Control) -> void:
	if overlay == null:
		return

	var glow := ColorRect.new()
	glow.color = Color(0.98, 0.84, 0.22, 0.18)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(glow)

	var ring := PanelContainer.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = 3
	ring.offset_top = 3
	ring.offset_right = -3
	ring.offset_bottom = -3

	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_color = Color(1.0, 0.88, 0.38, 0.98)
	ring_style.shadow_color = Color(1.0, 0.82, 0.2, 0.7)
	ring_style.shadow_size = 12
	ring_style.corner_radius_top_left = 8
	ring_style.corner_radius_top_right = 8
	ring_style.corner_radius_bottom_left = 8
	ring_style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		ring_style.set_border_width(side, 2)
	ring.add_theme_stylebox_override("panel", ring_style)
	overlay.add_child(ring)

func _add_aphrodite_activation_aura(overlay: Control) -> void:
	if overlay == null:
		return

	var glow := ColorRect.new()
	glow.color = Color(1.0, 0.56, 0.78, 0.12)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(glow)

	var ring := PanelContainer.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = 5
	ring.offset_top = 5
	ring.offset_right = -5
	ring.offset_bottom = -5

	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_color = Color(1.0, 0.76, 0.90, 0.92)
	ring_style.shadow_color = Color(1.0, 0.45, 0.74, 0.5)
	ring_style.shadow_size = 9
	ring_style.corner_radius_top_left = 8
	ring_style.corner_radius_top_right = 8
	ring_style.corner_radius_bottom_left = 8
	ring_style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		ring_style.set_border_width(side, 2)
	ring.add_theme_stylebox_override("panel", ring_style)
	overlay.add_child(ring)

func _apply_aphrodite_activation_style(style: StyleBoxFlat) -> void:
	if style == null:
		return
	style.border_color = Color(1.0, 0.78, 0.90, 0.98)
	style.shadow_color = Color(1.0, 0.45, 0.74, 0.72)
	style.shadow_size = max(style.shadow_size, 16)

func _apply_nusku_activation_style(style: StyleBoxFlat) -> void:
	if style == null:
		return
	style.border_color = Color(1.0, 0.42, 0.36, 0.98)
	style.shadow_color = Color(1.0, 0.18, 0.12, 0.78)
	style.shadow_size = max(style.shadow_size, 16)

func _apply_generic_god_activation_style(style: StyleBoxFlat, aura_color: Color) -> void:
	if style == null or aura_color.a <= 0.0:
		return
	style.border_color = aura_color
	style.shadow_color = aura_color
	style.shadow_size = max(style.shadow_size, 16)

func _add_champions_call_badge(overlay: Control, card: Card, is_ready: bool) -> void:
	if overlay == null or card == null:
		return
	var god := card as GodCard
	if god == null:
		return

	var clickable := not _is_enemy and god.get_controller() == _get_viewer_player()
	var badge := PanelContainer.new()
	badge.name = "ChampionsCallBadge"
	badge.tooltip_text = "Champion's Call"
	badge.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	badge.z_index = 30
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -46
	badge.offset_top = 30
	badge.offset_right = -6
	badge.offset_bottom = 70

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.09, 0.045, 0.015, 0.82)
	badge_style.border_color = Color(0.92, 0.62, 0.18, 0.82)
	badge_style.shadow_color = Color(0.05, 0.025, 0.0, 0.58)
	badge_style.shadow_size = 4
	if is_ready:
		badge_style.bg_color = Color(0.20, 0.09, 0.02, 0.94)
		badge_style.border_color = Color(1.0, 0.78, 0.22, 1.0)
		badge_style.shadow_color = Color(1.0, 0.62, 0.12, 0.78)
		badge_style.shadow_size = 12
	badge_style.corner_radius_top_left = 20
	badge_style.corner_radius_top_right = 20
	badge_style.corner_radius_bottom_left = 20
	badge_style.corner_radius_bottom_right = 20
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		badge_style.set_border_width(side, 2 if is_ready else 1)
	badge.add_theme_stylebox_override("panel", badge_style)

	var icon := TextureRect.new()
	icon.texture = CHAMPIONS_CALL_BADGE_TEXTURE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 3
	icon.offset_top = 3
	icon.offset_right = -3
	icon.offset_bottom = -3
	icon.modulate = Color(1, 1, 1, 1) if is_ready else Color(0.72, 0.72, 0.72, 0.72)
	badge.add_child(icon)

	if clickable:
		badge.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				champions_call_clicked.emit(god)
				accept_event()
		)
	overlay.add_child(badge)

func _should_show_smoking_mirror_badge(card: Card) -> bool:
	if not _is_tez_necoc_yaotl_card(card):
		return false
	return _get_tez_necoc_yaotl_sacrifice_count(card) >= TEZ_REQUIRED_SACRIFICES

func _should_show_tez_sacrifice_badge(card: Card) -> bool:
	if not _is_tez_necoc_yaotl_card(card):
		return false
	return _get_tez_necoc_yaotl_sacrifice_count(card) < TEZ_REQUIRED_SACRIFICES

func _is_tez_necoc_yaotl_card(card: Card) -> bool:
	return card != null \
		and card.card_name == TEZ_NORMAL_GOD_NAME \
		and card.has_method("get_necoc_yaotl_sacrifices")

func _get_tez_necoc_yaotl_sacrifice_count(card: Card) -> int:
	if not _is_tez_necoc_yaotl_card(card):
		return 0
	var sacrifices = card.call("get_necoc_yaotl_sacrifices")
	if sacrifices is Array:
		return (sacrifices as Array).size()
	return 0

func _get_tez_necoc_yaotl_total_level(card: Card) -> int:
	if not _is_tez_necoc_yaotl_card(card):
		return 0
	if card.has_method("get_necoc_yaotl_total_level"):
		return int(card.call("get_necoc_yaotl_total_level"))
	var total := 0
	var sacrifices = card.call("get_necoc_yaotl_sacrifices")
	if sacrifices is Array:
		for sacrifice in sacrifices:
			var sacrifice_card := sacrifice as Card
			if sacrifice_card != null:
				total += sacrifice_card.get_effective_level()
	return total

func _add_smoking_mirror_badge(overlay: Control, card: Card) -> void:
	if overlay == null or card == null:
		return
	if not _is_tez_necoc_yaotl_card(card):
		return

	var clickable := not _is_enemy and card.get_controller() == _get_viewer_player()
	var ready := game_manager != null \
		and card.has_method("can_resolve_necoc_yaotl_summon") \
		and bool(card.call("can_resolve_necoc_yaotl_summon", game_manager))
	var badge := Control.new()
	badge.name = "SmokingMirrorBadge"
	var hover_text := "Summon Tezcatlipoca, Active God"
	if not ready and game_manager != null and card.has_method("get_necoc_yaotl_summon_failure_reason"):
		var failure_reason := str(card.call("get_necoc_yaotl_summon_failure_reason", game_manager))
		if failure_reason != "":
			hover_text = failure_reason
	badge.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	badge.z_index = 31
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -62
	badge.offset_top = 4
	badge.offset_right = -4
	badge.offset_bottom = 62

	if ready:
		_add_badge_image_glow(badge, SMOKING_MIRROR_BADGE_TEXTURE, Color(0.75, 0.24, 1.0, 0.58))

	var icon := TextureRect.new()
	icon.texture = SMOKING_MIRROR_BADGE_TEXTURE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.modulate = Color(1, 1, 1, 1) if ready else Color(0.78, 0.74, 0.82, 0.86)
	badge.add_child(icon)

	if clickable:
		badge.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				tez_necoc_yaotl_badge_clicked.emit(card)
				accept_event()
		)
	_connect_badge_hover(badge, hover_text)
	overlay.add_child(badge)

func _add_tez_sacrifice_badge(overlay: Control, card: Card) -> void:
	if overlay == null or card == null:
		return
	if not _is_tez_necoc_yaotl_card(card):
		return

	var sacrifice_count := mini(
		_get_tez_necoc_yaotl_sacrifice_count(card),
		TEZ_REQUIRED_SACRIFICES
	)
	var ready := game_manager != null \
		and sacrifice_count < TEZ_REQUIRED_SACRIFICES \
		and card.has_method("can_activate") \
		and bool(card.call("can_activate", game_manager)) \
		and not _get_tez_valid_sacrifices(card).is_empty()
	var clickable := not _is_enemy and card.get_controller() == _get_viewer_player()

	var badge := Control.new()
	badge.name = "TezSacrificeBadge"
	var hover_text := "%d/%d sacrifices" % [
		sacrifice_count,
		TEZ_REQUIRED_SACRIFICES
	]
	hover_text += "\nSacrificed levels: %d" % _get_tez_necoc_yaotl_total_level(card)
	badge.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	badge.z_index = 31
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -62
	badge.offset_top = 4
	badge.offset_right = -4
	badge.offset_bottom = 62

	if ready:
		_add_badge_image_glow(badge, TEZ_SACRIFICE_BADGE_TEXTURE, Color(1.0, 0.0, 0.0, 0.92), 8.0)

	var icon := TextureRect.new()
	icon.texture = TEZ_SACRIFICE_BADGE_TEXTURE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.modulate = Color(1, 1, 1, 1) if ready else Color(0.86, 0.82, 0.76, 0.92)
	badge.add_child(icon)

	_add_tez_bloodstreaks(badge, sacrifice_count)

	if clickable:
		badge.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				tez_necoc_yaotl_badge_clicked.emit(card)
				accept_event()
		)
	_connect_badge_hover(badge, hover_text)
	overlay.add_child(badge)

func _get_tez_valid_sacrifices(card: Card) -> Array:
	if game_manager == null or not _is_tez_necoc_yaotl_card(card) or not card.has_method("get_valid_targets"):
		return []
	var sacrifices = card.call("get_valid_targets", game_manager)
	if sacrifices is Array:
		return sacrifices as Array
	return []

func _add_badge_image_glow(badge: Control, texture: Texture2D, color: Color, spread: float = 4.0) -> void:
	if badge == null or texture == null:
		return
	var glow := TextureRect.new()
	glow.texture = texture
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -spread
	glow.offset_top = -spread
	glow.offset_right = spread
	glow.offset_bottom = spread
	glow.modulate = color
	badge.add_child(glow)

func _connect_badge_hover(badge: Control, text: String) -> void:
	if badge == null:
		return
	badge.mouse_entered.connect(func() -> void:
		_show_badge_hover_popup(badge, text)
	)
	badge.mouse_exited.connect(func() -> void:
		_hide_badge_hover_popup()
	)

func _show_badge_hover_popup(anchor: Control, text: String) -> void:
	_hide_badge_hover_popup()
	if anchor == null or text.strip_edges() == "" or not is_inside_tree() or is_queued_for_deletion():
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return

	var popup_root := Control.new()
	popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_root.top_level = true
	popup_root.z_as_relative = false
	popup_root.z_index = POPUP_Z_INDEX + 1

	var popup := PanelContainer.new()
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.96)
	style.border_color = Color(0.5, 0.5, 0.75)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	popup.add_theme_stylebox_override("panel", style)
	popup_root.add_child(popup)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(label)

	_badge_hover_popup = popup_root
	tree.current_scene.add_child(popup_root)
	popup_root.move_to_front()

	await get_tree().process_frame
	if not is_instance_valid(popup_root) or not is_instance_valid(popup) or not is_instance_valid(anchor):
		return
	var popup_size := popup.get_combined_minimum_size()
	popup.size = popup_size
	popup_root.size = popup_size
	var anchor_rect := anchor.get_global_rect()
	var viewport_size := get_viewport_rect().size
	var popup_pos := Vector2(
		anchor_rect.position.x + (anchor_rect.size.x - popup_size.x) * 0.5,
		anchor_rect.position.y - popup_size.y - 6.0
	)
	if popup_pos.y < 4.0:
		popup_pos.y = anchor_rect.end.y + 6.0
	popup_pos.x = clamp(popup_pos.x, 4.0, viewport_size.x - popup_size.x - 4.0)
	popup_root.global_position = popup_pos

func _hide_badge_hover_popup() -> void:
	if _badge_hover_popup != null and is_instance_valid(_badge_hover_popup):
		_badge_hover_popup.queue_free()
	_badge_hover_popup = null

func _add_tez_bloodstreaks(badge: Control, sacrifice_count: int) -> void:
	if badge == null:
		return
	var positions := [
		{"left": 0.0, "right": 0.0},
		{"left": -16.0, "right": -16.0},
		{"left": 16.0, "right": 16.0},
	]
	for i in range(mini(sacrifice_count, positions.size())):
		var streak := TextureRect.new()
		streak.texture = TEZ_BLOODSTREAK_TEXTURE
		streak.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		streak.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		streak.z_index = 2
		streak.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var pos: Dictionary = positions[i]
		streak.offset_left = float(pos.get("left", 0.0))
		streak.offset_right = float(pos.get("right", 0.0))
		streak.offset_top = 6.0
		streak.offset_bottom = -6.0
		streak.modulate = Color(1.0, 1.0, 1.0, 0.92)
		badge.add_child(streak)

func _add_priority_response_aura(overlay: Control) -> void:
	if overlay == null:
		return

	var ring := PanelContainer.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = 9
	ring.offset_top = 9
	ring.offset_right = -9
	ring.offset_bottom = -9

	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_color = Color(0.5, 1.0, 0.58, 0.92)
	ring_style.shadow_color = Color(0.28, 0.95, 0.38, 0.55)
	ring_style.shadow_size = 8
	ring_style.corner_radius_top_left = 8
	ring_style.corner_radius_top_right = 8
	ring_style.corner_radius_bottom_left = 8
	ring_style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		ring_style.set_border_width(side, 2)
	ring.add_theme_stylebox_override("panel", ring_style)
	overlay.add_child(ring)

func _add_attack_aura(overlay: Control) -> void:
	if overlay == null:
		return

	var aura := AttackAura.new()
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.z_index = 20
	aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(aura)

func _add_followers_attack_target_tint(overlay: Control) -> void:
	if overlay == null:
		return

	var glow := ColorRect.new()
	glow.color = Color(0.92, 0.10, 0.08, 0.22)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(glow)

	var ring := PanelContainer.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = 4
	ring.offset_top = 4
	ring.offset_right = -4
	ring.offset_bottom = -4

	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_color = Color(0.98, 0.28, 0.22, 0.96)
	ring_style.shadow_color = Color(0.82, 0.08, 0.05, 0.34)
	ring_style.shadow_size = 10
	ring_style.corner_radius_top_left = 8
	ring_style.corner_radius_top_right = 8
	ring_style.corner_radius_bottom_left = 8
	ring_style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		ring_style.set_border_width(side, 2)
	ring.add_theme_stylebox_override("panel", ring_style)
	overlay.add_child(ring)

func _add_followers_attack_result_label(overlay: Control) -> void:
	if overlay == null or _followers_attack_result_text == "":
		return

	var result_label := Label.new()
	result_label.text = _followers_attack_result_text
	result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_label.offset_left = 8
	result_label.offset_top = 40
	result_label.offset_right = -8
	result_label.offset_bottom = -40
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 34)
	result_label.add_theme_color_override("font_color", Color(1.0, 0.18, 0.14, 0.98))
	overlay.add_child(result_label)

func _add_stack_target_indicator(overlay: Control) -> void:
	if overlay == null:
		return

	var marker := StackTargetIndicator.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = 4
	marker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	marker.offset_left = -28
	marker.offset_top = 6
	marker.offset_right = -6
	marker.offset_bottom = 28
	overlay.add_child(marker)

func _add_target_aura(overlay: Control) -> void:
	if overlay == null:
		return

	var aura := TargetAura.new()
	aura.z_index = 3
	aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(aura)

func _add_equipment_indicator_badge(
	overlay: Control,
	icon: Control,
	badge_offset_left: float,
	badge_offset_top: float,
	fill_color: Color,
	border_color: Color
) -> void:
	if overlay == null or icon == null:
		return
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.offset_left = badge_offset_left
	badge.offset_top = badge_offset_top
	badge.offset_right = badge_offset_left + 22.0
	badge.offset_bottom = badge_offset_top + 22.0

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = fill_color
	badge_style.border_color = border_color
	badge_style.shadow_color = Color(0.04, 0.03, 0.01, 0.4)
	badge_style.shadow_size = 4
	badge_style.corner_radius_top_left = 11
	badge_style.corner_radius_top_right = 11
	badge_style.corner_radius_bottom_left = 11
	badge_style.corner_radius_bottom_right = 11
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		badge_style.set_border_width(side, 1)
	badge.add_theme_stylebox_override("panel", badge_style)
	overlay.add_child(badge)

	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 2
	icon.offset_top = 2
	icon.offset_right = -2
	icon.offset_bottom = -2
	badge.add_child(icon)

func _add_equipment_affordances(overlay: Control, card: Card) -> void:
	if overlay == null or card == null or card.card_type != Card.CardType.CREATURE:
		return
	if card.equipment.is_empty():
		return

	var badge_top := 32.0 if card.is_sleeping else 6.0
	var badge_left := 6.0
	for equip in card.equipment:
		if equip == null:
			continue
		var affordance: Control = null
		if equip is EquipmentCard:
			affordance = (equip as EquipmentCard).create_equipped_affordance()
		elif equip.art_path != "":
			affordance = PanelContainer.new()
			affordance.mouse_filter = Control.MOUSE_FILTER_IGNORE
			affordance.custom_minimum_size = EquipmentCard.EQUIPPED_AFFORDANCE_SIZE
			affordance.clip_contents = true
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.10, 0.08, 0.06, 0.96)
			style.border_color = Color(0.96, 0.84, 0.58, 0.95)
			style.shadow_color = Color(0.02, 0.02, 0.02, 0.45)
			style.shadow_size = 4
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				style.set_border_width(side, 1)
			affordance.add_theme_stylebox_override("panel", style)
			var art_preview := _make_card_art_preview(equip)
			if art_preview != null:
				affordance.add_child(art_preview)
		if affordance == null:
			continue
		var affordance_size := affordance.custom_minimum_size
		if affordance_size == Vector2.ZERO:
			affordance_size = EquipmentCard.EQUIPPED_AFFORDANCE_SIZE
		affordance.mouse_filter = Control.MOUSE_FILTER_IGNORE
		affordance.set_anchors_preset(Control.PRESET_TOP_LEFT)
		affordance.offset_left = badge_left
		affordance.offset_top = badge_top
		affordance.offset_right = badge_left + affordance_size.x
		affordance.offset_bottom = badge_top + affordance_size.y
		overlay.add_child(affordance)
		badge_left += affordance_size.x + EQUIPMENT_AFFORDANCE_GAP

func _get_attached_permanent_hexes(card: Card) -> Array[Card]:
	var bindings: Array[Card] = []
	if card == null:
		return bindings
	var scanned_zones: Array[Zone] = []
	if game_manager != null:
		for player in game_manager.players:
			scanned_zones.append_array(player.frontline_zones)
			scanned_zones.append_array(player.reserve_zones)
			scanned_zones.append_array(player.power_zones)
	elif card.current_zone != null:
		scanned_zones.append(card.current_zone)
	for scanned_zone in scanned_zones:
		if scanned_zone == null:
			continue
		for zone_card in scanned_zone.cards:
			if zone_card == null or zone_card == card or zone_card in bindings:
				continue
			if zone_card is PermanentHexCard and (zone_card as PermanentHexCard).attached_target == card:
				bindings.append(zone_card)
	return bindings

func _get_dromi_binding_source(card: Card) -> Card:
	if card == null:
		return null
	for binding in _get_attached_permanent_hexes(card):
		if binding != null and binding.card_name == DROMI_BINDING_NAME:
			return binding
	var cannot_attack_status := card.get_status_effect("cannot_attack")
	if cannot_attack_status.is_empty():
		return null
	var source_name := str(cannot_attack_status.get("source", ""))
	var source_card = cannot_attack_status.get("source_card", null)
	if source_card is Card and (source_card as Card).card_name == DROMI_BINDING_NAME:
		return source_card as Card
	if source_name == DROMI_BINDING_NAME:
		if source_card is Card:
			return source_card as Card
		return card
	return null

func _has_dromi_binding(card: Card) -> bool:
	return _get_dromi_binding_source(card) != null

func _add_binding_affordances(overlay: Control, card: Card) -> void:
	if overlay == null or card == null or card.card_type != Card.CardType.CREATURE:
		return
	var dromi_source := _get_dromi_binding_source(card)
	if dromi_source == null:
		return
	var badge_top := 32.0 if card.is_sleeping else 6.0
	if not card.equipment.is_empty():
		badge_top += EquipmentCard.EQUIPPED_AFFORDANCE_SIZE.y + EQUIPMENT_AFFORDANCE_GAP
	var art_preview: Control = null
	if dromi_source != card:
		art_preview = _make_card_art_preview(dromi_source)
	if art_preview == null:
		return
	_add_equipment_indicator_badge(
		overlay,
		art_preview,
		6.0,
		badge_top,
		Color(0.28, 0.05, 0.05, 0.94),
		Color(1.0, 0.35, 0.28, 0.96)
	)

func _add_debuff_affordances(overlay: Control, card: Card) -> void:
	if overlay == null or card == null or card.card_type != Card.CardType.CREATURE or card.is_god:
		return
	var entries := _get_debuff_affordance_entries(card)
	if entries.is_empty():
		return

	var badge_top := 32.0 if _is_card_targeted_on_stack(card) else 6.0
	var badge_right := -6.0
	for entry in entries:
		var preview := _make_debuff_source_preview(entry)
		if preview == null:
			continue
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = badge_right - DEBUFF_BADGE_SIZE
		badge.offset_top = badge_top
		badge.offset_right = badge_right
		badge.offset_bottom = badge_top + DEBUFF_BADGE_SIZE

		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0.18, 0.02, 0.02, 0.95)
		badge_style.border_color = Color(1.0, 0.28, 0.24, 0.98)
		badge_style.shadow_color = Color(0.28, 0.02, 0.02, 0.52)
		badge_style.shadow_size = 4
		badge_style.corner_radius_top_left = 11
		badge_style.corner_radius_top_right = 11
		badge_style.corner_radius_bottom_left = 11
		badge_style.corner_radius_bottom_right = 11
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			badge_style.set_border_width(side, 1)
		badge.add_theme_stylebox_override("panel", badge_style)
		overlay.add_child(badge)

		badge.add_child(preview)

		var count := int(entry.get("count", 1))
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

		badge_right -= DEBUFF_BADGE_SIZE + DEBUFF_AFFORDANCE_GAP

func _get_debuff_affordance_entries(card: Card) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if card == null:
		return entries

	var seen: Dictionary = {}
	for status in card._get_effective_statuses():
		_append_debuff_affordance_entry(entries, seen, _build_debuff_entry_from_status(card, status))
	for buff in card._get_effective_buffs():
		_append_debuff_affordance_entry(entries, seen, _build_debuff_entry_from_buff(buff))
	return entries

func _append_debuff_affordance_entry(entries: Array[Dictionary], seen: Dictionary, entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var key := str(entry.get("key", ""))
	if key != "" and seen.has(key):
		var index := int(seen[key])
		var merged := entries[index]
		merged["count"] = int(merged.get("count", 1)) + int(entry.get("count", 1))
		entries[index] = merged
		return
	if not entry.has("count"):
		entry["count"] = 1
	if key != "":
		seen[key] = entries.size()
	entries.append(entry)

func _make_card_art_preview(source_card: Card) -> Control:
	if source_card == null or source_card.art_path == "":
		return null
	var tex := load(source_card.art_path) as Texture2D
	if tex == null:
		return null
	var art := TextureRect.new()
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 2
	art.offset_top = 2
	art.offset_right = -2
	art.offset_bottom = -2
	return art

func _is_tiamat_power_creature_zone() -> bool:
	if _preview_card != null:
		return false
	if zone == null or owning_player == null:
		return false
	if zone.zone_type != Zone.ZoneType.POWER_SLOT or zone.cards.is_empty():
		return false
	if owning_player.god_zone == null or owning_player.god_zone.cards.is_empty():
		return false
	if not TIAMAT_GOD_SCRIPT.is_tiamat_god(owning_player.god_zone.cards[0]):
		return false
	for slot_card in zone.cards:
		if not TIAMAT_GOD_SCRIPT.is_valid_slot_creature(slot_card):
			return false
	return true

func _get_power_lock_texture(card: Card) -> Texture2D:
	if card != null:
		if str(card.culture).strip_edges() == "Ancient" or card.has_type("Ancient Power"):
			return ANCIENT_POWER_LOCK_TEXTURE
	return POWER_LOCK_TEXTURE

func _add_power_lock_texture_overlay(overlay: Control, card: Card = null) -> void:
	var power_lock_texture := _get_power_lock_texture(card)
	if overlay == null or power_lock_texture == null:
		return

	var lock_overlay := TextureRect.new()
	lock_overlay.texture = power_lock_texture
	lock_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	lock_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)
	lock_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(lock_overlay)

func _can_select_tiamat_brood_slot_for_upkeep() -> bool:
	if game_manager == null or owning_player == null or zone == null:
		return false
	if owning_player != game_manager.current_player:
		return false
	if zone.zone_type != Zone.ZoneType.POWER_SLOT or zone not in owning_player.power_zones:
		return false
	return TIAMAT_GOD_SCRIPT.can_offer_matriarch_rule(game_manager)

func _add_tiamat_brood_slot_art(overlay: Control) -> void:
	if overlay == null or zone == null or zone.cards.is_empty():
		return

	var slot_cards: Array[Card] = []
	for card_index in range(zone.cards.size()):
		var slot_card := zone.cards[card_index] as Card
		if slot_card != null:
			slot_cards.append(slot_card)
	if slot_cards.is_empty():
		return

	var brood_art := TiamatBroodSlotArt.new()
	brood_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brood_art.setup(slot_cards, _can_select_tiamat_brood_slot_for_upkeep())
	brood_art.brood_card_clicked.connect(func(slot_card: Card) -> void:
		card_clicked.emit(slot_card)
	)
	overlay.add_child(brood_art)

	if not _is_tiamat_power_creature_stack_revealed():
		_add_power_lock_texture_overlay(overlay, zone.cards[0])

func _is_tiamat_power_creature_stack_revealed() -> bool:
	if zone == null:
		return false
	var viewer := _get_viewer_player()
	if owning_player != null and viewer != null and owning_player == viewer:
		return true
	for slot_card in zone.cards:
		if slot_card != null and slot_card.is_temporarily_revealed():
			return true
	return false

func _make_debuff_source_preview(entry: Dictionary) -> Control:
	var source_card := entry.get("source_card", null) as Card
	return _make_card_art_preview(source_card)

func _build_debuff_entry_from_status(card: Card, status: Dictionary) -> Dictionary:
	if card == null or status.is_empty():
		return {}
	var status_name := str(status.get("name", ""))
	if status_name in ["", "sleep", "temporarily_revealed", "blessed_ward", Card.EXTERNAL_EFFECT_NEGATION_STATUS]:
		return {}
	if status_name == "cannot_attack":
		var dromi_source := _get_dromi_binding_source(card)
		var source_card := status.get("source_card", null) as Card
		if dromi_source != null and (source_card == dromi_source or str(status.get("source", "")) == DROMI_BINDING_NAME):
			return {}

	var source_key := _get_debuff_source_key(status)
	var source_card := status.get("source_card", null) as Card
	if status_name == "malinalxochitl_poison" or status_name.contains("poison"):
		return {
			"key": "source:%s" % source_key,
			"source_card": source_card,
			"count": 1,
		}
	if status_name in ["cannot_attack", "cannot_move", "activation_locked", Card.ABILITY_NEGATED_STATUS]:
		return {
			"key": "source:%s" % source_key,
			"source_card": source_card,
			"count": 1,
		}
	if status_name in ["doomed", "petrified"]:
		return {
			"key": "source:%s" % source_key,
			"source_card": source_card,
			"count": 1,
		}
	return {}

func _build_debuff_entry_from_buff(buff: Dictionary) -> Dictionary:
	if buff.is_empty():
		return {}
	var str_change := int(buff.get("str", 0))
	var res_change := int(buff.get("res", 0))
	var spd_change := int(buff.get("spd", 0))
	var lvl_change := int(buff.get("lvl", 0))
	if str_change >= 0 and res_change >= 0 and spd_change >= 0 and lvl_change >= 0:
		return {}

	var effect_type := str(buff.get("effect_type", ""))
	var source := str(buff.get("source", ""))
	var lower_source := source.to_lower()
	if effect_type.contains("poison") or lower_source.contains("poison"):
		return {}

	var source_key := _get_debuff_source_key(buff)
	return {
		"key": "source:%s" % source_key,
		"source_card": buff.get("source_card", null),
		"count": 1,
	}

func _get_debuff_source_key(entry: Dictionary) -> String:
	var source_card := entry.get("source_card", null) as Card
	if source_card != null and source_card.uid != "":
		return source_card.uid
	var source := str(entry.get("source", ""))
	if source != "":
		return source
	return str(entry.get("name", "effect"))

func _get_binding_hover_lines(binding: Card) -> Array[String]:
	var details: Array[String] = []
	if binding == null:
		return details
	if binding.card_name == DROMI_BINDING_NAME:
		details.append(DROMI_BINDING_HOVER_TEXT)
		return details
	var ability_summary := binding.get_inline_ability_summary()
	if ability_summary != "":
		details.append(ability_summary)
	for effect_line in binding.get_effect_summary_lines():
		if effect_line == "" or effect_line in details:
			continue
		details.append(effect_line)
	return details

func _is_card_targeted_on_stack(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	for action in game_manager.action_stack:
		if action == null:
			continue
		if action.type == CardAction.Type.ATTACK and not _is_attack_stack_action_active(action):
			continue
		if action.target is Card and action.target == card:
			return true
	return false

func _is_attack_stack_action_active(action: CardAction) -> bool:
	if action == null or action.type != CardAction.Type.ATTACK:
		return true
	var attacker_active := action.attacker != null \
		and action.attacker.current_zone != null \
		and action.attacker.current_zone.is_board_zone()
	var partner_active := action.united_front_partner != null \
		and action.united_front_partner.current_zone != null \
		and action.united_front_partner.current_zone.is_board_zone()
	return attacker_active or partner_active

func _get_targeting_scene_root() -> Node:
	if not is_inside_tree() or is_queued_for_deletion():
		return null
	# CombatMockGame is often embedded under a menu/root scene, so current_scene
	# may be the shell rather than the node that owns transient targeting state.
	var node: Node = self
	while node != null:
		if node.is_in_group("combat_mock_game"):
			return node
		node = node.get_parent()
	var tree := get_tree()
	if tree == null:
		return null
	for candidate in tree.get_nodes_in_group("combat_mock_game"):
		if candidate is Node and is_instance_valid(candidate):
			return candidate as Node
	return tree.current_scene

func _get_targeting_match_manager(scene_root: Node) -> MatchManager:
	if scene_root == null:
		return null
	var manager = scene_root.get("match_manager")
	if manager is MatchManager:
		return manager as MatchManager
	return null

func _get_pending_target_validator(scene_root: Node) -> Callable:
	if scene_root == null:
		return Callable()
	var targeting_match_manager := _get_targeting_match_manager(scene_root)
	if targeting_match_manager != null and targeting_match_manager.pending_click_selection_validator.is_valid():
		return targeting_match_manager.pending_click_selection_validator
	var pending_validator = scene_root.get("_pending_click_selection_validator")
	if pending_validator is Callable and (pending_validator as Callable).is_valid():
		return pending_validator as Callable
	return Callable()

func _get_pending_target_source(scene_root: Node) -> Card:
	if scene_root == null:
		return null
	var targeting_match_manager := _get_targeting_match_manager(scene_root)
	if targeting_match_manager != null and targeting_match_manager.pending_click_selection_source is Card:
		return targeting_match_manager.pending_click_selection_source as Card
	var pending_source = scene_root.get("_pending_click_selection_source")
	if pending_source is Card:
		return pending_source as Card
	if scene_root.get("awaiting_pyre_target") == true and scene_root.get("pyre_source") is Card:
		return scene_root.get("pyre_source") as Card
	if scene_root.get("awaiting_anointing_target") == true and scene_root.get("anointing_source") is Card:
		return scene_root.get("anointing_source") as Card
	if scene_root.get("awaiting_stupefy_target") == true and scene_root.get("stupefy_source") is Card:
		return scene_root.get("stupefy_source") as Card
	if scene_root.get("awaiting_god_ability_target") == true and scene_root.get("god_ability_source") is Card:
		return scene_root.get("god_ability_source") as Card
	if scene_root.get("awaiting_spell_target") == true and scene_root.get("spell_waiting_for_target") is Card:
		return scene_root.get("spell_waiting_for_target") as Card
	return null

func _method_allows_self_target(source: Card, method_name: String, args: Array = []) -> bool:
	if source == null or not source.has_method(method_name):
		return false
	var result = null
	match args.size():
		0:
			result = source.call(method_name)
		1:
			result = source.call(method_name, args[0])
		2:
			result = source.call(method_name, args[0], args[1])
		_:
			return false
	if result is Array:
		return source in (result as Array)
	return false

func _allows_pending_self_target_highlight(source: Card, scene_root: Node) -> bool:
	if source == null:
		return false
	if _method_allows_self_target(source, "get_valid_targets", [game_manager]):
		return true
	if _method_allows_self_target(source, "get_valid_devour_targets", [game_manager]):
		return true
	if _method_allows_self_target(source, "get_valid_impact_targets", [game_manager]):
		return true
	if source.has_method("is_valid_activation_target") and source.call("is_valid_activation_target", source) == true:
		return true
	if source.has_method("is_valid_target") and source.call("is_valid_target", source) == true:
		return true
	if source.has_method("can_play_to_target") and source.call("can_play_to_target", game_manager, source) == true:
		return true
	if scene_root != null and scene_root.get("awaiting_pyre_target") == true and scene_root.get("pyre_source") == source:
		return true
	return false

func _is_card_pending_target(card: Card) -> bool:
	if card == null:
		return false
	var scene_root := _get_targeting_scene_root()
	if scene_root == null:
		return false
	var source := _get_pending_target_source(scene_root)
	if source == card and not _allows_pending_self_target_highlight(source, scene_root):
		return false

	var pending_validator := _get_pending_target_validator(scene_root)
	if pending_validator.is_valid():
		return pending_validator.call(card) == true

	if scene_root.get("awaiting_pyre_target") == true:
		return true

	if scene_root.get("awaiting_anointing_target") == true:
		var anointing_source = scene_root.get("anointing_source")
		return anointing_source != null and anointing_source.can_activate(game_manager, card)

	if scene_root.get("awaiting_stupefy_target") == true:
		var stupefy_source = scene_root.get("stupefy_source")
		return stupefy_source != null \
			and stupefy_source.has_method("get_valid_targets") \
			and card in stupefy_source.get_valid_targets(game_manager)

	if scene_root.get("awaiting_god_ability_target") == true:
		var god_source = scene_root.get("god_ability_source")
		return god_source != null \
			and god_source.has_method("is_valid_activation_target") \
			and god_source.is_valid_activation_target(card)

	if scene_root.get("awaiting_spell_target") == true:
		var spell_source = scene_root.get("spell_waiting_for_target")
		if spell_source is CharmCard:
			return (spell_source as CharmCard).is_valid_target(card)
		if spell_source != null and spell_source.has_method("is_valid_target"):
			return spell_source.is_valid_target(card)

	return false

func _is_card_pending_selection_source(card: Card) -> bool:
	if card == null:
		return false
	var scene_root := _get_targeting_scene_root()
	if scene_root == null:
		return false
	return _get_pending_target_source(scene_root) == card

func _get_selected_attacker(scene_root: Node) -> Card:
	if scene_root == null:
		return null
	var targeting_match_manager := _get_targeting_match_manager(scene_root)
	if targeting_match_manager != null and targeting_match_manager.selected_attacker is Card:
		return targeting_match_manager.selected_attacker as Card
	var attacker = scene_root.get("selected_attacker")
	if attacker is Card:
		return attacker as Card
	return null

func _get_selected_interceptor(scene_root: Node) -> Card:
	if scene_root == null:
		return null
	var targeting_match_manager := _get_targeting_match_manager(scene_root)
	if targeting_match_manager != null and targeting_match_manager.selected_interceptor is Card:
		return targeting_match_manager.selected_interceptor as Card
	var interceptor = scene_root.get("selected_interceptor")
	if interceptor is Card:
		return interceptor as Card
	return null

func _get_pending_attack_target(scene_root: Node):
	if scene_root == null:
		return null
	var targeting_match_manager := _get_targeting_match_manager(scene_root)
	if targeting_match_manager != null:
		return targeting_match_manager.pending_attack_target
	return scene_root.get("pending_attack_target")

func _get_declared_attack_partner(scene_root: Node, attacker: Card) -> Card:
	if scene_root == null or attacker == null or not scene_root.has_method("_get_declared_attack_partner"):
		return null
	var partner = scene_root.call("_get_declared_attack_partner", attacker)
	if partner is Card:
		return partner as Card
	return null

func _is_card_selected_attacker(card: Card) -> bool:
	if card == null:
		return false
	var scene_root := _get_targeting_scene_root()
	if scene_root == null:
		return false
	return _get_selected_attacker(scene_root) == card

func _is_card_selected_interceptor(card: Card) -> bool:
	if card == null:
		return false
	var scene_root := _get_targeting_scene_root()
	if scene_root == null:
		return false
	return _get_selected_interceptor(scene_root) == card

func _is_card_pending_attack_target(card: Card) -> bool:
	if card == null:
		return false
	var scene_root := _get_targeting_scene_root()
	if scene_root == null:
		return false
	var pending_target = _get_pending_attack_target(scene_root)
	return pending_target is Card and pending_target == card

func _is_card_attack_candidate(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	var scene_root := _get_targeting_scene_root()
	if scene_root == null:
		return false
	if _get_pending_attack_target(scene_root) != null:
		return false
	var attacker := _get_selected_attacker(scene_root)
	if attacker == null or attacker == card or card.get_controller() == attacker.get_controller():
		return false
	return (card.card_type == Card.CardType.CREATURE or card.card_type == Card.CardType.STRUCTURE) \
		and game_manager.can_cards_engage_each_other(attacker, card)

func _can_selected_attacker_hit_followers(scene_root: Node) -> bool:
	if scene_root == null or game_manager == null or owning_player == null:
		return false
	if _get_pending_attack_target(scene_root) != null:
		return false
	var attacker := _get_selected_attacker(scene_root)
	if attacker == null or attacker.get_controller() == owning_player:
		return false
	var allied_attackers: Array = []
	var united_front_partner := _get_declared_attack_partner(scene_root, attacker)
	if united_front_partner != null:
		allied_attackers.append(united_front_partner)
	return not game_manager.is_followers_attack_blocked_by_active_structure(attacker, owning_player, allied_attackers)

func _is_god_pending_followers_attack(card: Card) -> bool:
	if card == null or not card.is_god or owning_player == null:
		return false
	if zone == null or zone.zone_type != Zone.ZoneType.GOD_SLOT:
		return false
	var scene_root := _get_targeting_scene_root()
	if scene_root == null:
		return false
	if _get_selected_interceptor(scene_root) != null:
		return false
	var pending_target = _get_pending_attack_target(scene_root)
	return pending_target is Player and pending_target == owning_player

func _is_god_attack_candidate(card: Card) -> bool:
	if card == null or not card.is_god:
		return false
	if zone == null or zone.zone_type != Zone.ZoneType.GOD_SLOT:
		return false
	var scene_root := _get_targeting_scene_root()
	if scene_root == null:
		return false
	return _can_selected_attacker_hit_followers(scene_root)

func _is_card_pending_intercepting_followers_attack(card: Card) -> bool:
	if card == null:
		return false
	var scene_root := _get_targeting_scene_root()
	if scene_root == null:
		return false
	var pending_target = _get_pending_attack_target(scene_root)
	return pending_target is Player and _get_selected_interceptor(scene_root) == card

func _is_card_waiting_on_priority(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	if _is_hidden_board_card_for_priority_visuals(card):
		return false
	if game_manager.action_stack.is_empty():
		return false
	var top_action: CardAction = game_manager.action_stack.back()
	return top_action != null and top_action.card == card

func _is_card_attacking_on_stack(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	for action in game_manager.action_stack:
		if action == null or action.type != CardAction.Type.ATTACK:
			continue
		if action.attacker == card or action.united_front_partner == card:
			return true
	return false

func _is_card_intercepting_on_stack(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	for action in game_manager.action_stack:
		if action == null or action.type != CardAction.Type.ATTACK:
			continue
		if action.interceptor == card:
			return true
	return false

func _is_god_targeted_by_followers_attack(card: Card) -> bool:
	if card == null or not card.is_god or game_manager == null or owning_player == null:
		return false
	if zone == null or zone.zone_type != Zone.ZoneType.GOD_SLOT:
		return false
	for action in game_manager.action_stack:
		if action == null or action.type != CardAction.Type.ATTACK:
			continue
		if action.target is Player and action.target == owning_player and action.interceptor == null:
			return true
	return false

func _is_card_intercepting_followers_attack(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	for action in game_manager.action_stack:
		if action == null or action.type != CardAction.Type.ATTACK:
			continue
		if action.interceptor == card and action.target is Player:
			return true
	return false

func _is_hidden_board_card_for_priority_visuals(card: Card) -> bool:
	if card == null:
		return false
	return card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and (card.is_face_down or card.is_stealth or card.is_prepared)

func _is_card_usable_for_priority(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	if _is_hidden_board_card_for_priority_visuals(card):
		return false
	return game_manager.can_card_respond_to_priority(card, game_manager.priority_player)

func _should_show_playing_aura(card: Card) -> bool:
	return _preview_card != null or _is_card_waiting_on_priority(card) or _is_card_pending_selection_source(card)

func _should_show_aphrodite_activation_aura(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	if card is not AphroditeAreia:
		return false
	if not _can_show_god_activation_aura(card):
		return false
	return card.can_activate(game_manager)

func _should_show_nusku_activation_aura(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	if card is not NuskuFirebearer:
		return false
	if not _can_show_god_activation_aura(card):
		return false
	return card.can_activate(game_manager)

func _get_deckbuilder_god_glow_color(card: Card) -> Color:
	if card == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	match card.culture:
		"Triskelion":
			return Color(0.25, 0.56, 1.0, 0.95)
		"Norse":
			return Color(0.28, 0.92, 0.50, 0.95)
		"Ancient":
			return Color(0.02, 0.02, 0.02, 0.95)
		"Tian":
			return Color(1.0, 0.88, 0.24, 0.95)
		"Nahutl", "Nahuatl":
			return Color(0.94, 0.24, 0.18, 0.95)
		"Olympic":
			return Color(0.66, 0.34, 0.98, 0.95)
	return Color(0.0, 0.0, 0.0, 0.0)

func _has_custom_god_activation_aura(card: Card) -> bool:
	return card is AphroditeAreia or card is NuskuFirebearer

func _can_show_god_activation_aura(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	var viewer := _get_viewer_player()
	if viewer == null or card.get_controller() != viewer:
		return false
	var controller := card.get_controller()
	if controller == null:
		return false
	if game_manager.is_player_in_upkeep_window(controller):
		return false
	if game_manager.priority_player != null or not game_manager.action_stack.is_empty():
		return false
	return true

func _should_show_generic_god_activation_aura(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	if card is not GodCard:
		return false
	if _has_custom_god_activation_aura(card):
		return false
	if card is TezcatlipocaTheSmokingMirror:
		return false
	if not _can_show_god_activation_aura(card):
		return false
	if not card.has_method("can_activate"):
		return false
	if card.has_method("should_show_activation_aura"):
		return bool(card.call("should_show_activation_aura", game_manager))
	return bool(card.call("can_activate", game_manager))

func _should_show_champions_call_badge(card: Card) -> bool:
	var god := card as GodCard
	if god == null:
		return false
	return god.has_champions_call()

func _should_glow_champions_call_badge(card: Card) -> bool:
	var god := card as GodCard
	if god == null or game_manager == null:
		return false
	if god.get_controller() != _get_viewer_player():
		return false
	return god.can_use_champions_call(game_manager)

func set_preview_card(card: Card) -> void:
	_preview_card = card
	_refresh_display()

func _sync_visual_state_card(card: Card) -> void:
	if _visual_state_card == card:
		return
	if _visual_state_card != null and _visual_state_card.visual_state_changed.is_connected(_on_visual_state_card_changed):
		_visual_state_card.visual_state_changed.disconnect(_on_visual_state_card_changed)
	_visual_state_card = card
	if _visual_state_card != null and not _visual_state_card.visual_state_changed.is_connected(_on_visual_state_card_changed):
		_visual_state_card.visual_state_changed.connect(_on_visual_state_card_changed)

func _disconnect_visual_state_card() -> void:
	if _visual_state_card != null and _visual_state_card.visual_state_changed.is_connected(_on_visual_state_card_changed):
		_visual_state_card.visual_state_changed.disconnect(_on_visual_state_card_changed)
	_visual_state_card = null

func _on_visual_state_card_changed() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	call_deferred("_refresh_display")

func _clear_followers_attack_result_if_current(sequence: int) -> void:
	if is_queued_for_deletion():
		return
	if _followers_attack_result_sequence != sequence:
		return
	_followers_attack_result_text = ""
	_refresh_display()

func show_followers_attack_result(new_followers: int, duration_seconds: float = FOLLOWERS_ATTACK_RESULT_SECONDS) -> void:
	_followers_attack_result_text = str(new_followers)
	_followers_attack_result_sequence += 1
	var flash_sequence := _followers_attack_result_sequence
	_refresh_display()

	if not is_inside_tree() or is_queued_for_deletion():
		return
	var tree := get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(maxf(duration_seconds, 0.0))
	timer.timeout.connect(
		Callable(self, "_clear_followers_attack_result_if_current").bind(flash_sequence),
		CONNECT_ONE_SHOT
	)

func get_visual_anchor_global() -> Vector2:
	var anchor_control: Control = _raised_overlay
	if anchor_control == null or not is_instance_valid(anchor_control):
		anchor_control = _defense_overlay
	if anchor_control == null or not is_instance_valid(anchor_control):
		anchor_control = self
	var rect: Rect2 = anchor_control.get_global_rect()
	return rect.position + rect.size * 0.5

func _get_minimum_size() -> Vector2:
	return get_zone_size()

func _refresh_mouse_cursor_shape(card: Card = null) -> void:
	if card != null and card.card_type == Card.CardType.POWER and card.is_face_down:
		mouse_default_cursor_shape = LockedPowerCursor.get_control_cursor_shape(Control.CURSOR_ARROW)
		return
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func setup(p_zone: Zone, p_gm: GameManager, p_player: Player, idx: int,
		drop_cb: Callable, is_enemy: bool = false, row_label: String = "") -> void:
	zone         = p_zone
	game_manager = p_gm
	owning_player = p_player
	zone_index   = idx
	_drop_callback = drop_cb
	_is_enemy    = is_enemy
	_row_label   = row_label
	custom_minimum_size = get_zone_size()
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	_refresh_display()

func _get_resting_z_index() -> int:
	return RAISED_BOARD_Z_INDEX if (_raised_overlay and is_instance_valid(_raised_overlay)) else BASE_BOARD_Z_INDEX

func _refresh_display() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_hide_ability_popup()
	_hide_badge_hover_popup()
	_defense_overlay = null
	_raised_overlay = null
	for child in get_children():
		child.queue_free()
	var card: Card = _preview_card if _preview_card != null else (zone.cards[0] if zone.cards.size() > 0 else null)
	_sync_visual_state_card(card)
	_refresh_mouse_cursor_shape(card)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left    = 4
	style.corner_radius_top_right   = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)

	if card != null:
		if _is_tiamat_power_creature_zone():
			style.bg_color = Color(0.09, 0.12, 0.16, 0.92)
			style.border_color = Color(0.82, 0.72, 0.36, 0.96)
			add_theme_stylebox_override("panel", style)
			z_index = BASE_BOARD_Z_INDEX

			var tiamat_overlay := Control.new()
			tiamat_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tiamat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(tiamat_overlay)
			_add_tiamat_brood_slot_art(tiamat_overlay)
			_add_followers_attack_result_label(tiamat_overlay)
			return

		var face_down_viewer := _get_viewer_player()
		var can_render_stealth_creature_normally := card.card_type == Card.CardType.CREATURE \
			and card.is_stealth \
			and (card.get_controller() == face_down_viewer or card.is_temporarily_revealed())

		# Face-down cards: own stealth creatures that are visible to the viewer use the normal
		# renderer below so they keep their full stats and defensive shield placement.
		if card.is_face_down and not can_render_stealth_creature_normally:
			add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			var fd_overlay := Control.new()
			fd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fd_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(fd_overlay)
			var revealed_face_down_power := (card is PowerCard and (card as PowerCard).is_publicly_revealed) or card.is_temporarily_revealed()
			var is_own_hidden_card := card.get_controller() == face_down_viewer and (
				card.is_stealth
				or card.is_power
				or card.is_prepared
			)
			var show_revealed_power_art := revealed_face_down_power and card.art_path != ""
			var tex_path := card.art_path if (show_revealed_power_art or (is_own_hidden_card and card.art_path != "")) else "res://images/cardbackAI.png"
			var tex: Texture2D = load(tex_path)
			if tex:
				var art := TextureRect.new()
				art.texture = tex
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fd_overlay.add_child(art)
			if show_revealed_power_art:
				var revealed_haze := ColorRect.new()
				var is_own_revealed_power := card.get_controller() == face_down_viewer
				revealed_haze.color = Color(0.22, 0.45, 0.85, 0.26) if is_own_revealed_power else Color(0.85, 0.22, 0.45, 0.28)
				revealed_haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				revealed_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fd_overlay.add_child(revealed_haze)
				var public_power := card as PowerCard
				if public_power != null and public_power.is_muted and public_power.mute_turns_remaining > 0:
					var mute_badge := PanelContainer.new()
					mute_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
					mute_badge.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
					mute_badge.offset_left = 6
					mute_badge.offset_right = -6
					mute_badge.offset_top = -26
					mute_badge.offset_bottom = -6
					var badge_style := StyleBoxFlat.new()
					badge_style.bg_color = Color(0.56, 0.18, 0.28, 0.9)
					badge_style.border_color = Color(1.0, 0.76, 0.84, 0.95)
					badge_style.corner_radius_top_left = 6
					badge_style.corner_radius_top_right = 6
					badge_style.corner_radius_bottom_left = 6
					badge_style.corner_radius_bottom_right = 6
					for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
						badge_style.set_border_width(side, 1)
					mute_badge.add_theme_stylebox_override("panel", badge_style)
					var mute_lbl := Label.new()
					mute_lbl.text = "Muted %d" % public_power.mute_turns_remaining
					mute_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					mute_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					mute_lbl.add_theme_font_size_override("font_size", 11)
					mute_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.98))
					mute_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					mute_badge.add_child(mute_lbl)
					fd_overlay.add_child(mute_badge)
			elif is_own_hidden_card:
				var haze := ColorRect.new()
				haze.color = Color(0.05, 0.05, 0.2, 0.38)
				haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fd_overlay.add_child(haze)
			_add_power_lock_overlay(fd_overlay, card)
			if card.get_controller() == face_down_viewer and card.is_prepared and card.is_magical_card():
				_add_speed_badge(fd_overlay, card)
				_add_prepared_magical_mana_badge(fd_overlay, card)
			if _is_card_attacking_on_stack(card) or _is_card_intercepting_on_stack(card) or _is_card_selected_attacker(card) or _is_card_selected_interceptor(card):
				_add_attack_aura(fd_overlay)
			if _is_card_targeted_on_stack(card) or _is_card_pending_target(card) or _is_card_pending_attack_target(card) or _is_card_attack_candidate(card):
				_add_target_aura(fd_overlay)
				_add_stack_target_indicator(fd_overlay)
			var _fd_is_def := card.card_type == Card.CardType.CREATURE and (
				card.creature_mode == Card.CreatureMode.DEFENSIVE
				or card.is_stealth
			)
			if _fd_is_def:
				var shield_scale := DefenseShieldOverlay.STEALTH_VIEW_SIZE_MULTIPLIER if card.is_stealth else 1.0
				DefenseShieldOverlay.ensure_on(fd_overlay, DefenseShieldOverlay.LAYOUT_CENTER, shield_scale)
			_defense_overlay = fd_overlay if _fd_is_def else null
			_raised_overlay  = fd_overlay if (_fd_is_def or card.is_stealth) else null
			z_index = _get_resting_z_index()
			return

		# God slot: show art image filling the zone
		if zone.zone_type == Zone.ZoneType.GOD_SLOT and card.art_path != "":
			var show_aphrodite_activation_aura := _should_show_aphrodite_activation_aura(card)
			var show_nusku_activation_aura := _should_show_nusku_activation_aura(card)
			var show_generic_god_activation_aura := _should_show_generic_god_activation_aura(card)
			var show_champions_call_badge := _should_show_champions_call_badge(card)
			var glow_champions_call_badge := _should_glow_champions_call_badge(card)
			var show_god_attack_aura := _is_card_attacking_on_stack(card) or _is_card_intercepting_on_stack(card) or _is_card_selected_attacker(card) or _is_card_selected_interceptor(card)
			var show_god_playing_aura := _should_show_playing_aura(card)
			var show_god_priority_aura := _is_card_usable_for_priority(card)
			var show_god_target_aura := _is_card_targeted_on_stack(card) or _is_card_pending_target(card) or _is_card_pending_attack_target(card) or _is_card_attack_candidate(card)
			var show_god_followers_tint := _is_god_targeted_by_followers_attack(card) or _is_god_pending_followers_attack(card) or _is_god_attack_candidate(card)

			style.bg_color     = Color(0.35, 0.28, 0.04, 0.9)
			style.border_color = Color(0.9, 0.75, 0.2)
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				style.set_border_width(side, 2)
			if show_aphrodite_activation_aura:
				_apply_aphrodite_activation_style(style)
			elif show_nusku_activation_aura:
				_apply_nusku_activation_style(style)
			elif show_generic_god_activation_aura:
				_apply_generic_god_activation_style(style, _get_deckbuilder_god_glow_color(card))
			add_theme_stylebox_override("panel", style)
			z_index = GOD_INDICATOR_Z_INDEX if (
				show_aphrodite_activation_aura
				or show_nusku_activation_aura
				or show_generic_god_activation_aura
				or show_god_attack_aura
				or show_god_playing_aura
				or show_god_priority_aura
				or show_god_target_aura
				or show_god_followers_tint
				or glow_champions_call_badge
			) else BASE_BOARD_Z_INDEX
			var tex: Texture2D = load(card.art_path)
			if tex:
				# Single Control overlay - PanelContainer fills it to the zone size.
				# Children inside use anchors relative to the overlay, bypassing
				# PanelContainer's child-fill behaviour entirely.
				var god_overlay := Control.new()
				god_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
				god_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				add_child(god_overlay)
				if show_god_attack_aura:
					_add_attack_aura(god_overlay)
				if show_god_playing_aura:
					_add_playing_aura(god_overlay)
				if show_god_priority_aura:
					_add_priority_response_aura(god_overlay)
				if show_god_target_aura:
					_add_target_aura(god_overlay)
					_add_stack_target_indicator(god_overlay)

				var art := TextureRect.new()
				art.texture = tex
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				god_overlay.add_child(art)
				if show_god_followers_tint:
					_add_followers_attack_target_tint(god_overlay)

				# VBoxContainer fills overlay via anchors; spacer pushes label to correct edge
				var name_vbox := VBoxContainer.new()
				name_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				name_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
				god_overlay.add_child(name_vbox)

				if card.name_at_bottom:
					var top_name_spacer := Control.new()
					top_name_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
					top_name_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
					name_vbox.add_child(top_name_spacer)

				var name_lbl := Label.new()
				name_lbl.add_theme_font_size_override("font_size", 11)
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
				name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				name_lbl.text = card.get_display_name_for_control(name_lbl)
				name_vbox.add_child(name_lbl)

				if not card.name_at_bottom:
					var bottom_name_spacer := Control.new()
					bottom_name_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
					bottom_name_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
					name_vbox.add_child(bottom_name_spacer)

				var deck_lbl := Label.new()
				deck_lbl.text = "Deck: %d" % owning_player.deck_zone.cards.size()
				deck_lbl.add_theme_font_size_override("font_size", 10)
				deck_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
				deck_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				deck_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
				deck_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
				deck_lbl.offset_left = 6
				deck_lbl.offset_top = 4
				deck_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				god_overlay.add_child(deck_lbl)
				_add_level_badge(god_overlay, card, Control.PRESET_TOP_LEFT, 6, 24, 54, 42)

				var _effect_lines: Array[String] = []
				if card.has_method("get_effect_summary_lines"):
					_effect_lines = card.get_effect_summary_lines()
				if _should_show_smoking_mirror_badge(card):
					_add_smoking_mirror_badge(god_overlay, card)
				elif _should_show_tez_sacrifice_badge(card):
					_add_tez_sacrifice_badge(god_overlay, card)
				elif not _effect_lines.is_empty():
					var counter_badge := PanelContainer.new()
					counter_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
					counter_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
					counter_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
					counter_badge.grow_vertical = Control.GROW_DIRECTION_END
					counter_badge.offset_left = -6
					counter_badge.offset_right = -4
					counter_badge.offset_top = 4
					counter_badge.offset_bottom = 26
					var counter_style := StyleBoxFlat.new()
					counter_style.bg_color = Color(0.55, 0.38, 0.04, 0.92)
					counter_style.border_color = Color(1.0, 0.88, 0.35, 0.95)
					counter_style.corner_radius_top_left = 5
					counter_style.corner_radius_top_right = 5
					counter_style.corner_radius_bottom_left = 5
					counter_style.corner_radius_bottom_right = 5
					for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
						counter_style.set_border_width(side, 1)
					counter_badge.add_theme_stylebox_override("panel", counter_style)
					var counter_lbl := Label.new()
					counter_lbl.text = "\n".join(_effect_lines)
					counter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					counter_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					counter_lbl.add_theme_font_size_override("font_size", 10)
					counter_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
					counter_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					counter_badge.add_child(counter_lbl)
					god_overlay.add_child(counter_badge)

				if show_champions_call_badge:
					_add_champions_call_badge(god_overlay, card, glow_champions_call_badge)

				if card.is_power and card.is_muted and card.mute_turns_remaining > 0:
					var muted_badge := PanelContainer.new()
					muted_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
					muted_badge.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
					muted_badge.offset_left = 6
					muted_badge.offset_right = -6
					muted_badge.offset_top = -26
					muted_badge.offset_bottom = -6
					var muted_style := StyleBoxFlat.new()
					var muted_badge_viewer := _get_viewer_player()
					muted_style.bg_color = Color(0.22, 0.14, 0.34, 0.9) if card.get_controller() == muted_badge_viewer else Color(0.56, 0.18, 0.28, 0.9)
					muted_style.border_color = Color(0.82, 0.9, 1.0, 0.95) if card.get_controller() == muted_badge_viewer else Color(1.0, 0.76, 0.84, 0.95)
					muted_style.corner_radius_top_left = 6
					muted_style.corner_radius_top_right = 6
					muted_style.corner_radius_bottom_left = 6
					muted_style.corner_radius_bottom_right = 6
					for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
						muted_style.set_border_width(side, 1)
					muted_badge.add_theme_stylebox_override("panel", muted_style)
					var muted_lbl := Label.new()
					muted_lbl.text = "Muted %d" % card.mute_turns_remaining
					muted_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					muted_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					muted_lbl.add_theme_font_size_override("font_size", 11)
					muted_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
					muted_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					muted_badge.add_child(muted_lbl)
					god_overlay.add_child(muted_badge)
				_add_followers_attack_result_label(god_overlay)
			return

		var is_def_creature := card.card_type == Card.CardType.CREATURE and card.creature_mode == Card.CreatureMode.DEFENSIVE
		var shows_defense_shield := card.card_type == Card.CardType.CREATURE and (is_def_creature or card.is_stealth)
		match card.card_type:
			Card.CardType.CREATURE:
				style.bg_color    = Color(0.13, 0.22, 0.42)
				style.border_color = Color(0.4, 0.65, 1.0)
				add_theme_stylebox_override("panel", style)
			Card.CardType.STRUCTURE:
				style.bg_color    = Color(0.28, 0.18, 0.08)
				style.border_color = Color(0.75, 0.55, 0.3)
				add_theme_stylebox_override("panel", style)
			_:
				style.bg_color    = Color(0.18, 0.18, 0.18)
				style.border_color = Color(0.5, 0.5, 0.5)
				add_theme_stylebox_override("panel", style)

		var board_viewer := _get_viewer_player()
		var can_view_stealth_details := card.get_controller() == board_viewer or card.is_temporarily_revealed()
		var card_overlay := Control.new()
		card_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(card_overlay)
		if _is_card_attacking_on_stack(card) or _is_card_intercepting_on_stack(card) or _is_card_selected_attacker(card) or _is_card_selected_interceptor(card):
			_add_attack_aura(card_overlay)
		if _should_show_playing_aura(card):
			_add_playing_aura(card_overlay)
		if _is_card_usable_for_priority(card):
			_add_priority_response_aura(card_overlay)
		if _is_card_targeted_on_stack(card) or _is_card_pending_target(card) or _is_card_pending_attack_target(card) or _is_card_attack_candidate(card):
			_add_target_aura(card_overlay)
			_add_stack_target_indicator(card_overlay)
		if _is_card_intercepting_followers_attack(card) or _is_card_pending_intercepting_followers_attack(card):
			_add_followers_attack_target_tint(card_overlay)

		# Art background; stealth shows hazed art (own) or cardback (opponent)
		var show_public_stealth := card.is_stealth and card.is_temporarily_revealed()
		if card.is_stealth:
			var stealth_viewer := _get_viewer_player()
			var is_own := card.get_controller() == stealth_viewer
			var tex_path := card.art_path if (is_own or show_public_stealth) and card.art_path != "" else "res://images/cardbackAI.png"
			var tex: Texture2D = load(tex_path)
			if tex:
				var art := TextureRect.new()
				art.texture = tex
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card_overlay.add_child(art)
			if is_own or show_public_stealth:
				var haze := ColorRect.new()
				haze.color = Color(0.05, 0.05, 0.2, 0.34) if is_own else Color(0.85, 0.22, 0.45, 0.18)
				haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card_overlay.add_child(haze)
		elif card.art_path != "":
			var tex: Texture2D = load(card.art_path)
			if tex:
				var art := TextureRect.new()
				art.texture = tex
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card_overlay.add_child(art)
		if shows_defense_shield:
			var shield_layout := DefenseShieldOverlay.LAYOUT_STAT_UNDER
			if card.is_stealth and not can_view_stealth_details:
				shield_layout = DefenseShieldOverlay.LAYOUT_CENTER
			var shield_scale := DefenseShieldOverlay.STEALTH_VIEW_SIZE_MULTIPLIER if shield_layout == DefenseShieldOverlay.LAYOUT_CENTER else 1.0
			DefenseShieldOverlay.ensure_on(card_overlay, shield_layout, shield_scale)
		_add_level_badge(card_overlay, card, Control.PRESET_TOP_LEFT, 6, 6, 54, 24)
		_add_prepared_magical_mana_badge(card_overlay, card)

		_add_sleep_affordance(card_overlay, card)
		if not card.is_stealth or card.get_controller() == board_viewer or card.is_temporarily_revealed():
			_add_equipment_affordances(card_overlay, card)
			_add_binding_affordances(card_overlay, card)
			_add_debuff_affordances(card_overlay, card)

		# VBox fills the zone; spacer pushes the stat label to the bottom
		var vbox := VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_overlay.add_child(vbox)

		var stats_spacer := Control.new()
		stats_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(stats_spacer)

		var is_own_stealth_faceup := card.is_stealth and (card.get_controller() == board_viewer or card.is_temporarily_revealed())
		if card.card_type == Card.CardType.CREATURE and not card.is_god and (not card.is_stealth or is_own_stealth_faceup):
			var eff_str := card.get_effective_strength()
			var eff_res := card.get_effective_resilience()
			var eff_spd := card.get_effective_speed()
			var is_def := card.creature_mode == Card.CreatureMode.DEFENSIVE

			var left_base := card.resilience if is_def else card.strength
			var left_eff  := eff_res if is_def else eff_str
			var left_stat := "res" if is_def else "str"
			var left_font_color := Color(0.92, 0.97, 1.0)
			if left_eff > left_base:
				left_font_color = Color(0.4, 1.0, 0.4)
			elif left_eff < left_base:
				left_font_color = Color(1.0, 0.35, 0.35)
			var left_badge := _add_overlay_stat_badge(
				card_overlay,
				"RES:%d" % eff_res if is_def else "STR:%d" % eff_str,
				Control.PRESET_BOTTOM_LEFT,
				6,
				-32,
				66,
				-6,
				left_font_color
			)
			var left_breakdown := card.get_full_stat_breakdown(left_stat)
			if left_badge != null and left_breakdown != "":
				left_badge.tooltip_text = left_breakdown
				left_badge.mouse_filter = Control.MOUSE_FILTER_STOP

			var right_font_color := Color(0.92, 0.97, 1.0)
			if eff_spd > card.speed:
				right_font_color = Color(0.4, 1.0, 0.4)
			elif eff_spd < card.speed:
				right_font_color = Color(1.0, 0.35, 0.35)
			var right_badge := _add_overlay_stat_badge(
				card_overlay,
				"SPD:%d" % eff_spd,
				Control.PRESET_BOTTOM_RIGHT,
				-66,
				-32,
				-6,
				-6,
				right_font_color
			)
			var spd_breakdown := card.get_full_stat_breakdown("spd")
			if right_badge != null and spd_breakdown != "":
				right_badge.tooltip_text = spd_breakdown
				right_badge.mouse_filter = Control.MOUSE_FILTER_STOP

			_add_hidden_creature_stat_badge(card_overlay, card, is_def, eff_str, eff_res)

		elif card.card_type == Card.CardType.STRUCTURE:
			var eff_res_s := card.get_effective_resilience()
			var breakdown := card.get_buff_tooltip("res")
			var res_font_color := Color(0.92, 0.97, 1.0)
			if eff_res_s < card.resilience:
				res_font_color = Color(1.0, 0.35, 0.35)
			elif eff_res_s > card.resilience:
				res_font_color = Color(0.4, 1.0, 0.4)
			var res_badge := _add_overlay_stat_badge(
				card_overlay,
				"RES:%d" % eff_res_s,
				Control.PRESET_BOTTOM_LEFT,
				6,
				-32,
				66,
				-6,
				res_font_color
			)
			if res_badge != null and breakdown != "":
				res_badge.tooltip_text = "RES:\n" + breakdown
				res_badge.mouse_filter = Control.MOUSE_FILTER_STOP

		if card.is_power and card.is_muted and card.mute_turns_remaining > 0:
			var muted_badge := PanelContainer.new()
			muted_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			muted_badge.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			muted_badge.offset_left = 6
			muted_badge.offset_right = -6
			muted_badge.offset_top = -26
			muted_badge.offset_bottom = -6
			var muted_style := StyleBoxFlat.new()
			muted_style.bg_color = Color(0.22, 0.14, 0.34, 0.9) if card.get_controller() == board_viewer else Color(0.56, 0.18, 0.28, 0.9)
			muted_style.border_color = Color(0.82, 0.9, 1.0, 0.95) if card.get_controller() == board_viewer else Color(1.0, 0.76, 0.84, 0.95)
			muted_style.corner_radius_top_left = 6
			muted_style.corner_radius_top_right = 6
			muted_style.corner_radius_bottom_left = 6
			muted_style.corner_radius_bottom_right = 6
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				muted_style.set_border_width(side, 1)
			muted_badge.add_theme_stylebox_override("panel", muted_style)
			var muted_lbl := Label.new()
			muted_lbl.text = "Muted %d" % card.mute_turns_remaining
			muted_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			muted_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			muted_lbl.add_theme_font_size_override("font_size", 11)
			muted_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
			muted_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			muted_badge.add_child(muted_lbl)
			card_overlay.add_child(muted_badge)

		_defense_overlay = card_overlay if shows_defense_shield else null
		_raised_overlay  = card_overlay if (shows_defense_shield or card.is_stealth) else null
		z_index = _get_resting_z_index()

	else:
		# Empty zone styling - God slot gets gold treatment
		z_index = BASE_BOARD_Z_INDEX
		if zone.zone_type == Zone.ZoneType.GOD_SLOT:
			style.bg_color    = Color(0.35, 0.28, 0.04, 0.7)
			style.border_color = Color(0.9, 0.75, 0.2)
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				style.set_border_width(side, 2)
		else:
			style.bg_color    = Color(0.07, 0.12, 0.07, 0.55)
			style.border_color = Color(0.22, 0.35, 0.22, 0.7)
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				style.set_border_width(side, 1)
		add_theme_stylebox_override("panel", style)

		var lbl := Label.new()
		lbl.text = _row_label if _row_label != "" else str(zone_index + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		lbl.modulate.a = 0.4
		add_child(lbl)

func _is_draggable_creature() -> bool:
	if zone.cards.size() == 0:
		return false
	if _is_enemy:
		return false
	var card := zone.cards[0]
	if card.card_type != Card.CardType.CREATURE:
		return false
	if card.is_god:
		return false
	if card.get_controller() != game_manager.current_player:
		return false
	if not card.can_take_major_creature_action() and not card.can_take_minor_creature_action():
		return false
	return true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_draggable_creature():
			creature_drag_started.emit(zone.cards[0], zone)
			accept_event()
		elif zone.cards.size() > 0:
			card_clicked.emit(zone.cards[0])
			accept_event()
		else:
			zone_clicked.emit(zone)
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if zone.cards.size() > 0:
			var card := zone.cards[0]
			if not _is_enemy and card.card_type == Card.CardType.CREATURE and card.get_controller() == game_manager.current_player:
				creature_right_clicked.emit(card)
			elif not _is_enemy and card.is_god and card.get_controller() == game_manager.current_player:
				god_right_clicked.emit(card)
				accept_event()
				return
			# Pin the info popup on right-click for any visible card
			var viewer := _get_viewer_player()
			if not card.is_face_down or card.get_controller() == viewer or _is_public_power(card) or card.is_temporarily_revealed():
				_pinned = true
				_hide_ability_popup()
				_show_ability_popup()
				accept_event()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EXIT_TREE:
			_pinned = false
			_hovered = false
			_hide_pending = false
			_disconnect_visual_state_card()
			_hide_badge_hover_popup()
			_hide_ability_popup()
		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			var _c := _preview_card if _preview_card != null else (zone.cards[0] if zone != null and zone.cards.size() > 0 else null)
			if _c != null:
				z_index = HOVER_BOARD_Z_INDEX
			var viewer := _get_viewer_player()
			if _c != null and (not _c.is_face_down or _c.get_controller() == viewer or _is_public_power(_c) or _c.is_temporarily_revealed()):
				var _delay := 1.0 if (_c.is_god) else 1.5
				if is_inside_tree() and not is_queued_for_deletion():
					get_tree().create_timer(_delay).timeout.connect(
						func() -> void: _try_show_popup()
					)
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			z_index = _get_resting_z_index()
			_schedule_hide()

func _schedule_hide() -> void:
	if _pinned or _hide_pending:
		return
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_hide_pending = true
	await get_tree().create_timer(0.15).timeout
	_hide_pending = false
	if not is_inside_tree() or is_queued_for_deletion() or get_viewport() == null:
		return
	if _pinned:
		return
	if _popup and is_instance_valid(_popup):
		if _popup.get_global_rect().has_point(get_global_mouse_position()):
			return  # Mouse is over the popup
	if get_global_rect().has_point(get_global_mouse_position()):
		return  # Mouse returned to zone
	_hide_ability_popup()

func _input(event: InputEvent) -> void:
	if not _pinned:
		return
	if event is InputEventMouseButton and event.pressed:
		# Any click anywhere unpins
		_pinned = false
		_hide_ability_popup()

func _process(_delta: float) -> void:
	# Failsafe only when not pinned and no hide already pending
	if _pinned or _hide_pending:
		return
	if not is_inside_tree() or is_queued_for_deletion() or get_viewport() == null:
		return
	if _popup and is_instance_valid(_popup):
		var over_zone  := get_global_rect().has_point(get_global_mouse_position())
		var over_popup := _popup.get_global_rect().has_point(get_global_mouse_position())
		if not over_zone and not over_popup:
			_schedule_hide()

func _try_show_popup() -> void:
	if not _hovered:
		return
	if not is_inside_tree() or is_queued_for_deletion() or get_viewport() == null:
		return
	if not get_global_rect().has_point(get_global_mouse_position()):
		return
	_show_ability_popup()

func _show_ability_popup() -> void:
	if _popup and is_instance_valid(_popup):
		return
	if zone == null or zone.cards.size() == 0:
		return
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var card := zone.cards[0]
	var tree := get_tree()
	if tree == null:
		return
	var scene_root := tree.current_scene
	if scene_root == null:
		return

	var popup_root := Control.new()
	popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_root.top_level = true
	popup_root.z_as_relative = false
	popup_root.z_index = POPUP_Z_INDEX

	var popup := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.08, 0.14, 0.96)
	pstyle.corner_radius_top_left    = 5
	pstyle.corner_radius_top_right   = 5
	pstyle.corner_radius_bottom_left = 5
	pstyle.corner_radius_bottom_right = 5
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		pstyle.set_border_width(side, 1)
	pstyle.border_color = Color(0.5, 0.5, 0.75)
	popup.add_theme_stylebox_override("panel", pstyle)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.mouse_exited.connect(func() -> void:
		if not _pinned:
			_schedule_hide()
	)

	var popup_viewer_shared := _get_viewer_player()
	var is_hidden_card_shared := (card.is_stealth or (card.is_face_down and not _is_public_power(card))) and card.get_controller() != popup_viewer_shared and not card.is_temporarily_revealed()

	var effect_lines_shared: Array[String] = []
	var equipment_lines_shared: Array[String] = []
	var binding_lines_shared: Array[String] = []
	var power_cost_lines_shared: Array[String] = []
	var cost_lines_shared: Array[String] = []
	if not is_hidden_card_shared:
		if card.card_type == Card.CardType.CREATURE:
			effect_lines_shared = card.get_effect_summary_lines()
			equipment_lines_shared = card.get_equipment_summary_lines()
			for binding in _get_attached_permanent_hexes(card):
				var line := binding.card_name
				var binding_effect_lines := _get_binding_hover_lines(binding)
				if binding_effect_lines.is_empty():
					binding_lines_shared.append(line)
				else:
					binding_lines_shared.append(line + ": " + " | ".join(binding_effect_lines))
			var has_dromi_line := false
			for line in binding_lines_shared:
				if line.begins_with(DROMI_BINDING_NAME):
					has_dromi_line = true
					break
			if not has_dromi_line and _has_dromi_binding(card):
				var dromi_source := _get_dromi_binding_source(card)
				if dromi_source != null and dromi_source != card:
					var dromi_effect_lines := _get_binding_hover_lines(dromi_source)
					if dromi_effect_lines.is_empty():
						binding_lines_shared.append(DROMI_BINDING_NAME + ": " + DROMI_BINDING_HOVER_TEXT)
					else:
						binding_lines_shared.append(DROMI_BINDING_NAME + ": " + " | ".join(dromi_effect_lines))
				else:
					binding_lines_shared.append(DROMI_BINDING_NAME + ": " + DROMI_BINDING_HOVER_TEXT)
		elif card.card_type == Card.CardType.STRUCTURE:
			effect_lines_shared = card.get_effect_summary_lines()
		elif card.card_type == Card.CardType.EQUIPMENT:
			effect_lines_shared = card.get_effect_summary_lines()
		if card is PowerCard:
			power_cost_lines_shared = _get_power_hover_cost_lines(card as PowerCard)
		elif card.is_prepared and card.is_magical_card():
			cost_lines_shared = _get_prepared_magical_hover_cost_lines(card)

	popup.add_child(CardDetailContentBuilder.build_board_popup_body(
		card,
		popup_viewer_shared,
		{
			"is_hidden_card": is_hidden_card_shared,
			"type_label": _get_card_type_label(card),
			"effect_lines": effect_lines_shared,
			"equipment_lines": equipment_lines_shared,
			"binding_lines": binding_lines_shared,
			"cost_lines": cost_lines_shared,
			"power_cost_lines": power_cost_lines_shared,
			"game_manager": game_manager
		}
	))

	popup_root.add_child(popup)

	var keywords_panel: Control = null
	if not is_hidden_card_shared:
		var keywords := CardDetailContentBuilder.extract_card_keywords(card)
		if not keywords.is_empty():
			keywords_panel = CardDetailContentBuilder.build_keywords_panel(keywords)
			popup_root.add_child(keywords_panel)

	_popup = popup_root
	scene_root.add_child(popup_root)
	popup_root.move_to_front()

	await get_tree().process_frame
	if not is_instance_valid(popup_root) or not is_instance_valid(popup):
		return
	var popup_vp_size_shared := get_viewport_rect().size
	var popup_size := popup.get_combined_minimum_size()
	popup.size = popup_size
	popup.position = Vector2.ZERO

	var keyword_size := Vector2.ZERO
	var keywords_on_left := false
	if keywords_panel != null and is_instance_valid(keywords_panel):
		keyword_size = keywords_panel.get_combined_minimum_size()
		var room_on_right := popup_vp_size_shared.x - (global_position.x + popup_size.x) - 4.0
		var room_on_left := global_position.x - keyword_size.x - KEYWORD_PANEL_GAP - 4.0
		keywords_on_left = room_on_right < keyword_size.x + KEYWORD_PANEL_GAP and room_on_left > 0.0
		keywords_panel.position = Vector2.ZERO if keywords_on_left else Vector2(popup_size.x + KEYWORD_PANEL_GAP, 0.0)
		keywords_panel.size = keyword_size
		if keywords_on_left:
			popup.position = Vector2(keyword_size.x + KEYWORD_PANEL_GAP, 0.0)

	var popup_root_size := Vector2(
		popup_size.x + (keyword_size.x + KEYWORD_PANEL_GAP if keyword_size.x > 0.0 else 0.0),
		maxf(popup_size.y, keyword_size.y)
	)
	popup_root.size = popup_root_size

	var popup_pos_shared := global_position
	popup_pos_shared.y -= popup.size.y + 6
	if popup_pos_shared.y < 0:
		popup_pos_shared.y = global_position.y + size.y + 6
	var desired_x := global_position.x - (keyword_size.x + KEYWORD_PANEL_GAP if keywords_on_left else 0.0)
	popup_pos_shared.x = clamp(desired_x, 4.0, popup_vp_size_shared.x - popup_root_size.x - 4.0)
	popup_root.global_position = popup_pos_shared

func _hide_ability_popup() -> void:
	if _popup and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null

func can_accept_card(card: Card) -> bool:
	if card is BitMeseri:
		if zone.cards.size() == 0:
			return game_manager.can_play_card(game_manager.current_player, card, null)
		var target := zone.cards[0]
		if target.card_type != Card.CardType.CREATURE and target.card_type != Card.CardType.STRUCTURE and target.card_type != Card.CardType.EQUIPMENT:
			return false
		return game_manager.can_play_card(game_manager.current_player, card, null)
	if card is Absence:
		if zone.cards.size() == 0:
			return game_manager.can_play_card(game_manager.current_player, card, null)
		var target := zone.cards[0]
		if target is not PowerCard and not target.is_god:
			return false
		return game_manager.can_play_card(game_manager.current_player, card, null)
	if card is CharmCard and (card as CharmCard).targets:
		if zone.cards.size() == 0:
			if card.current_zone == card.card_owner.hand_zone:
				return (card as CharmCard).can_activate_from_hand(game_manager) \
					or game_manager.can_prepare_card(game_manager.current_player, card, zone)
			return (card as CharmCard).can_activate_prepared(game_manager)
		var charm := card as CharmCard
		var target := zone.cards[0]
		if not charm.is_valid_target(target):
			return false
		if card.current_zone == card.card_owner.hand_zone:
			return charm.can_activate_from_hand(game_manager)
		return charm.can_activate_prepared(game_manager)
	if card is CharmCard:
		if zone.cards.size() > 0:
			return false
		if card.current_zone == card.card_owner.hand_zone:
			return (card as CharmCard).can_activate_from_hand(game_manager) \
				or game_manager.can_prepare_card(owning_player, card, zone)
		return (card as CharmCard).can_activate_prepared(game_manager)
	if card.card_type == Card.CardType.HEX:
		if zone.cards.size() > 0:
			return false
		return game_manager.can_prepare_card(owning_player, card, zone)
	if _is_enemy:
		return false
	if owning_player != game_manager.current_player:
		return false
	# Equipment from hand can be dropped onto a creature's zone (auto-equip)
	if card.card_type == Card.CardType.EQUIPMENT and card.current_zone == owning_player.hand_zone:
		return game_manager.can_play_card(owning_player, card, zone)
	if zone.cards.size() > 0:
		return false
	return game_manager.can_play_card(owning_player, card, zone)
