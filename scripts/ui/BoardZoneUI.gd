class_name BoardZoneUI
extends PanelContainer

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

class DromiChainIndicator extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(18, 18)

	func _draw() -> void:
		var chain_color := Color(0.95, 0.18, 0.15, 0.98)
		var glow_color := Color(1.0, 0.55, 0.44, 0.72)
		var shadow_color := Color(0.26, 0.03, 0.03, 0.92)
		draw_arc(Vector2(6.0, 7.6), 3.7, PI * 0.15, PI * 1.87, 20, glow_color, 4.2, true)
		draw_arc(Vector2(11.9, 10.3), 3.7, -PI * 0.83, PI * 0.88, 20, glow_color, 4.2, true)
		draw_arc(Vector2(6.0, 7.6), 3.3, PI * 0.15, PI * 1.87, 20, chain_color, 2.4, true)
		draw_arc(Vector2(11.9, 10.3), 3.3, -PI * 0.83, PI * 0.88, 20, chain_color, 2.4, true)
		draw_line(Vector2(8.2, 8.8), Vector2(9.8, 9.4), shadow_color, 2.2, true)
		draw_line(Vector2(8.4, 7.7), Vector2(10.6, 10.5), chain_color, 2.2, true)
		draw_line(Vector2(10.5, 7.2), Vector2(7.7, 10.8), chain_color, 2.2, true)
		draw_circle(Vector2(9.2, 9.1), 1.1, Color(1.0, 0.83, 0.76, 0.92))

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

signal zone_clicked(zone: Zone)
signal card_clicked(card: Card)
signal creature_attack_requested(attacker: Card, target: Card)
signal creature_attack_followers_requested(attacker: Card)
signal board_creature_dropped(card: Card, from_zone: Zone, drop_position: Vector2)
signal creature_drag_started(card: Card, from_zone: Zone)
signal creature_right_clicked(card: Card)

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
var _raised_overlay: Control = null  # non-null for DEF or stealth — floats above the zone row

const BASE_ZONE_EXTENT := 165.0
const DROMI_BINDING_NAME := "Dromi"
const DROMI_BINDING_HOVER_TEXT := "Cannot attack. Losing 7 followers on opponent's turn start - Dromi"
const EQUIPMENT_AFFORDANCE_GAP := 4.0
static var _zone_extent: float = BASE_ZONE_EXTENT

var _row_label: String = ""

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
	if card.speed <= 0:
		return

	var eff_spd := card.get_effective_speed()
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -62
	badge.offset_top = -30
	badge.offset_right = -6
	badge.offset_bottom = -6

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.24, 0.9)
	style.border_color = Color(0.62, 0.8, 1.0, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "SPD:%d" % eff_spd
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if eff_spd > card.speed:
		label.modulate = Color(0.4, 1.0, 0.4)
	elif eff_spd < card.speed:
		label.modulate = Color(1.0, 0.35, 0.35)
	badge.add_child(label)

	overlay.add_child(badge)

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
	aura.z_index = 1
	aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(aura)

func _add_stack_target_indicator(overlay: Control) -> void:
	if overlay == null:
		return

	var marker := StackTargetIndicator.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	marker.offset_left = -28
	marker.offset_top = 6
	marker.offset_right = -6
	marker.offset_bottom = 28
	overlay.add_child(marker)

func _add_equipment_indicator_badge(
	overlay: Control,
	icon: Control,
	offset_left: float,
	offset_top: float,
	fill_color: Color,
	border_color: Color
) -> void:
	if overlay == null or icon == null:
		return
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.offset_left = offset_left
	badge.offset_top = offset_top
	badge.offset_right = offset_left + 22.0
	badge.offset_bottom = offset_top + 22.0

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
	if card == null or card.current_zone == null:
		return bindings
	for zone_card in card.current_zone.cards:
		if zone_card == null or zone_card == card:
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
	if not _has_dromi_binding(card):
		return
	var badge_top := 32.0 if card.is_sleeping else 6.0
	if not card.equipment.is_empty():
		badge_top += EquipmentCard.EQUIPPED_AFFORDANCE_SIZE.y + EQUIPMENT_AFFORDANCE_GAP
	_add_equipment_indicator_badge(
		overlay,
		DromiChainIndicator.new(),
		6.0,
		badge_top,
		Color(0.28, 0.05, 0.05, 0.94),
		Color(1.0, 0.35, 0.28, 0.96)
	)

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
		if action.target is Card and action.target == card:
			return true
	return false

func _is_card_pending_target(card: Card) -> bool:
	if card == null:
		return false
	var tree := get_tree()
	if tree == null:
		return false
	var scene_root := tree.current_scene
	if scene_root == null:
		return false

	var pending_validator = scene_root.get("_pending_click_selection_validator")
	if pending_validator is Callable and (pending_validator as Callable).is_valid():
		return (pending_validator as Callable).call(card) == true

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
	var tree := get_tree()
	if tree == null:
		return false
	var scene_root := tree.current_scene
	if scene_root == null:
		return false
	return scene_root.get("_pending_click_selection_source") == card

func _is_card_waiting_on_priority(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	for action in game_manager.action_stack:
		if action != null and action.card == card:
			return true
	return false

func _is_card_attacking_on_stack(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	for action in game_manager.action_stack:
		if action == null or action.type != CardAction.Type.ATTACK:
			continue
		if action.attacker == card or action.united_front_partner == card:
			return true
	return false

func _is_card_usable_for_priority(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	return game_manager.can_card_respond_to_priority(card, game_manager.priority_player)

func _should_show_playing_aura(card: Card) -> bool:
	return _preview_card != null or _is_card_waiting_on_priority(card) or _is_card_pending_selection_source(card)

func set_preview_card(card: Card) -> void:
	_preview_card = card
	_refresh_display()

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
	_refresh_display()

func _refresh_display() -> void:
	_hide_ability_popup()
	_raised_overlay = null
	for child in get_children():
		child.queue_free()
	var card: Card = _preview_card if _preview_card != null else (zone.cards[0] if zone.cards.size() > 0 else null)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left    = 4
	style.corner_radius_top_right   = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)

	if card != null:

		# Face-down cards: own stealth / locked powers / prepared cards show hazed art; others show cardback
		if card.is_face_down:
			add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			var fd_overlay := Control.new()
			fd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(fd_overlay)
			var viewer := _get_viewer_player()
			var revealed_face_down_power := (card is PowerCard and (card as PowerCard).is_publicly_revealed) or card.is_temporarily_revealed()
			var is_own_hidden_card := card.get_controller() == viewer and (
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
				var is_own_revealed_power := card.get_controller() == viewer
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
			if card.get_controller() == viewer and card.is_prepared and card.is_magical_card():
				_add_speed_badge(fd_overlay, card)
			if _is_card_attacking_on_stack(card):
				_add_attack_aura(fd_overlay)
			if _is_card_targeted_on_stack(card) or _is_card_pending_target(card):
				_add_stack_target_indicator(fd_overlay)
			var _fd_is_def := card.card_type == Card.CardType.CREATURE and card.creature_mode == Card.CreatureMode.DEFENSIVE
			_defense_overlay = fd_overlay if _fd_is_def else null
			_raised_overlay  = fd_overlay if (_fd_is_def or card.is_stealth) else null
			z_index = 2 if _raised_overlay != null else 0
			return

		# God slot: show art image filling the zone
		if zone.zone_type == Zone.ZoneType.GOD_SLOT and card.art_path != "":
			style.bg_color     = Color(0.35, 0.28, 0.04, 0.9)
			style.border_color = Color(0.9, 0.75, 0.2)
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				style.set_border_width(side, 2)
			add_theme_stylebox_override("panel", style)
			var tex: Texture2D = load(card.art_path)
			if tex:
				# Single Control overlay — PanelContainer fills it to the zone size.
				# Children inside use anchors relative to the overlay, bypassing
				# PanelContainer's child-fill behaviour entirely.
				var overlay := Control.new()
				overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
				overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				add_child(overlay)
				if _is_card_attacking_on_stack(card):
					_add_attack_aura(overlay)
				if _should_show_playing_aura(card):
					_add_playing_aura(overlay)
				if _is_card_usable_for_priority(card):
					_add_priority_response_aura(overlay)
				if _is_card_targeted_on_stack(card) or _is_card_pending_target(card):
					_add_stack_target_indicator(overlay)

				var art := TextureRect.new()
				art.texture = tex
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				overlay.add_child(art)

				# VBoxContainer fills overlay via anchors; spacer pushes label to correct edge
				var name_vbox := VBoxContainer.new()
				name_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				name_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
				overlay.add_child(name_vbox)

				if card.name_at_bottom:
					var spacer := Control.new()
					spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
					spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
					name_vbox.add_child(spacer)

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
					var spacer := Control.new()
					spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
					spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
					name_vbox.add_child(spacer)

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
				overlay.add_child(deck_lbl)

				if card.is_power and card.is_muted and card.mute_turns_remaining > 0:
					var muted_badge := PanelContainer.new()
					muted_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
					muted_badge.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
					muted_badge.offset_left = 6
					muted_badge.offset_right = -6
					muted_badge.offset_top = -26
					muted_badge.offset_bottom = -6
					var muted_style := StyleBoxFlat.new()
					var viewer := _get_viewer_player()
					muted_style.bg_color = Color(0.22, 0.14, 0.34, 0.9) if card.get_controller() == viewer else Color(0.56, 0.18, 0.28, 0.9)
					muted_style.border_color = Color(0.82, 0.9, 1.0, 0.95) if card.get_controller() == viewer else Color(1.0, 0.76, 0.84, 0.95)
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
					overlay.add_child(muted_badge)
			return

		var is_def_creature := card.card_type == Card.CardType.CREATURE and card.creature_mode == Card.CreatureMode.DEFENSIVE
		match card.card_type:
			Card.CardType.CREATURE:
				if is_def_creature:
					# Transparent — the rotated overlay IS the visual
					add_theme_stylebox_override("panel", StyleBoxEmpty.new())
				else:
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

		var overlay := Control.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(overlay)
		if _is_card_attacking_on_stack(card):
			_add_attack_aura(overlay)
		if _should_show_playing_aura(card):
			_add_playing_aura(overlay)
		if _is_card_usable_for_priority(card):
			_add_priority_response_aura(overlay)
		if _is_card_targeted_on_stack(card) or _is_card_pending_target(card):
			_add_stack_target_indicator(overlay)

		# Art background; stealth shows hazed art (own) or cardback (opponent)
		var show_public_stealth := card.is_stealth and card.is_temporarily_revealed()
		if card.is_stealth:
			var viewer := _get_viewer_player()
			var is_own := card.get_controller() == viewer
			var tex_path := card.art_path if (is_own or show_public_stealth) and card.art_path != "" else "res://images/cardbackAI.png"
			var tex: Texture2D = load(tex_path)
			if tex:
				var art := TextureRect.new()
				art.texture = tex
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				overlay.add_child(art)
			if is_own or show_public_stealth:
				var haze := ColorRect.new()
				haze.color = Color(0.05, 0.05, 0.2, 0.34) if is_own else Color(0.85, 0.22, 0.45, 0.18)
				haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
				overlay.add_child(haze)
		elif card.art_path != "":
			var tex: Texture2D = load(card.art_path)
			if tex:
				var art := TextureRect.new()
				art.texture = tex
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				overlay.add_child(art)

		_add_sleep_affordance(overlay, card)
		var viewer := _get_viewer_player()
		if not card.is_stealth or card.get_controller() == viewer or card.is_temporarily_revealed():
			_add_equipment_affordances(overlay, card)
			_add_binding_affordances(overlay, card)

		# VBox fills the zone; spacer pushes the stat label to the bottom
		var vbox := VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(vbox)

		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(spacer)

		var is_own_stealth_faceup := card.is_stealth and (card.get_controller() == viewer or card.is_temporarily_revealed())
		if card.card_type == Card.CardType.CREATURE and not card.is_god and (not card.is_stealth or is_own_stealth_faceup):
			var eff_str := card.get_effective_strength()
			var eff_res := card.get_effective_resilience()
			var eff_spd := card.get_effective_speed()
			var is_def := card.creature_mode == Card.CreatureMode.DEFENSIVE
			var stat_row := HBoxContainer.new()
			stat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var left_lbl := Label.new()
			left_lbl.text = "RES:%d" % eff_res if is_def else "STR:%d" % eff_str
			left_lbl.add_theme_font_size_override("font_size", 13)
			var left_base := card.resilience if is_def else card.strength
			var left_eff  := eff_res if is_def else eff_str
			var left_stat := "res" if is_def else "str"
			if left_eff > left_base:
				left_lbl.modulate = Color(0.4, 1.0, 0.4)
			elif left_eff < left_base:
				left_lbl.modulate = Color(1.0, 0.35, 0.35)
			var left_breakdown := card.get_full_stat_breakdown(left_stat)
			if left_breakdown != "":
				left_lbl.tooltip_text = left_breakdown
				left_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				left_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stat_row.add_child(left_lbl)

			var mid_spacer := Control.new()
			mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stat_row.add_child(mid_spacer)

			var right_lbl := Label.new()
			right_lbl.text = "SPD:%d" % eff_spd
			right_lbl.add_theme_font_size_override("font_size", 13)
			if eff_spd > card.speed:
				right_lbl.modulate = Color(0.4, 1.0, 0.4)
			elif eff_spd < card.speed:
				right_lbl.modulate = Color(1.0, 0.35, 0.35)
			var spd_breakdown := card.get_full_stat_breakdown("spd")
			if spd_breakdown != "":
				right_lbl.tooltip_text = spd_breakdown
				right_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				right_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stat_row.add_child(right_lbl)

			vbox.add_child(stat_row)

		elif card.card_type == Card.CardType.STRUCTURE:
			var eff_res_s := card.get_effective_resilience()
			var res_lbl := Label.new()
			res_lbl.text = "RES:%d" % eff_res_s
			res_lbl.add_theme_font_size_override("font_size", 13)
			res_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var breakdown := card.get_buff_tooltip("res")
			if eff_res_s < card.resilience:
				res_lbl.modulate = Color(1.0, 0.35, 0.35)
				if breakdown != "":
					res_lbl.tooltip_text = "RES:\n" + breakdown
					res_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
			elif eff_res_s > card.resilience:
				res_lbl.modulate = Color(0.4, 1.0, 0.4)
				if breakdown != "":
					res_lbl.tooltip_text = "RES:\n" + breakdown
					res_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
			vbox.add_child(res_lbl)

		if card.is_power and card.is_muted and card.mute_turns_remaining > 0:
			var muted_badge := PanelContainer.new()
			muted_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			muted_badge.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			muted_badge.offset_left = 6
			muted_badge.offset_right = -6
			muted_badge.offset_top = -26
			muted_badge.offset_bottom = -6
			var muted_style := StyleBoxFlat.new()
			muted_style.bg_color = Color(0.22, 0.14, 0.34, 0.9) if card.get_controller() == viewer else Color(0.56, 0.18, 0.28, 0.9)
			muted_style.border_color = Color(0.82, 0.9, 1.0, 0.95) if card.get_controller() == viewer else Color(1.0, 0.76, 0.84, 0.95)
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
			overlay.add_child(muted_badge)

		_defense_overlay = overlay if is_def_creature else null
		_raised_overlay  = overlay if (is_def_creature or card.is_stealth) else null
		z_index = 2 if _raised_overlay != null else 0

	else:
		# Empty zone styling — God slot gets gold treatment
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
	if card.creature_major_action_used or card.creature_minor_actions_used >= 2:
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
			_hide_ability_popup()
		NOTIFICATION_SORT_CHILDREN:
			# Fires after PanelContainer has sized its children. Re-apply defense
			# rotation here so the pivot uses the overlay's actual post-layout size.
			if _defense_overlay and is_instance_valid(_defense_overlay):
				_defense_overlay.pivot_offset = _defense_overlay.size / 2.0
				_defense_overlay.rotation_degrees = 90.0

		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			z_index = 10
			var _c := zone.cards[0] if zone != null and zone.cards.size() > 0 else null
			var viewer := _get_viewer_player()
			if _c != null and (not _c.is_face_down or _c.get_controller() == viewer or _is_public_power(_c) or _c.is_temporarily_revealed()):
				var _delay := 1.0 if (_c.is_god) else 1.5
				get_tree().create_timer(_delay).timeout.connect(
					func() -> void: _try_show_popup()
				)
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			z_index = 2 if (_raised_overlay and is_instance_valid(_raised_overlay)) else 0
			_schedule_hide()

func _schedule_hide() -> void:
	if _pinned or _hide_pending:
		return
	_hide_pending = true
	await get_tree().create_timer(0.15).timeout
	_hide_pending = false
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
	if _popup and is_instance_valid(_popup):
		var over_zone  := get_global_rect().has_point(get_global_mouse_position())
		var over_popup := _popup.get_global_rect().has_point(get_global_mouse_position())
		if not over_zone and not over_popup:
			_schedule_hide()

func _try_show_popup() -> void:
	if not _hovered:
		return
	if not get_global_rect().has_point(get_global_mouse_position()):
		return
	_show_ability_popup()

func _show_ability_popup() -> void:
	if _popup and is_instance_valid(_popup):
		return
	if zone == null or zone.cards.size() == 0:
		return
	var card := zone.cards[0]
	var tree := get_tree()
	if tree == null:
		return
	var scene_root := tree.current_scene
	if scene_root == null:
		return

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
	popup.z_index = 200
	popup.mouse_exited.connect(func() -> void:
		if not _pinned:
			_schedule_hide()
	)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(210, 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(vbox)

	# Hidden = opponent's stealth card; own stealth cards show full info
	var viewer := _get_viewer_player()
	var hidden := (card.is_stealth or (card.is_face_down and not _is_public_power(card))) and card.get_controller() != viewer and not card.is_temporarily_revealed()

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header_row)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.text = card.get_display_name_for_control(name_lbl) if not hidden else "???"
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(name_lbl)

	if not hidden and card.culture != "":
		var culture_lbl := Label.new()
		culture_lbl.text = card.culture
		culture_lbl.add_theme_font_size_override("font_size", 11)
		culture_lbl.add_theme_color_override("font_color", Color(0.96, 0.88, 0.62))
		culture_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		culture_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_row.add_child(culture_lbl)

	# Types
	if not hidden:
		var type_lbl := Label.new()
		var type_parts: Array[String] = [_get_card_type_label(card)]
		for card_type_name in card.card_types:
			if card_type_name not in type_parts:
				type_parts.append(card_type_name)
		type_lbl.text = " • ".join(type_parts)
		type_lbl.add_theme_font_size_override("font_size", 11)
		type_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55) if card.is_petrified() else Color(0.7, 0.85, 1.0))
		type_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(type_lbl)

		if card.is_petrified():
			var petrified_lbl := Label.new()
			petrified_lbl.text = "Status: Petrified Creature"
			petrified_lbl.add_theme_font_size_override("font_size", 11)
			petrified_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			petrified_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(petrified_lbl)
		if card.is_muted and card.mute_turns_remaining > 0:
			var muted_status_lbl := Label.new()
			muted_status_lbl.text = "Status: Muted (%d turn%s)" % [
				card.mute_turns_remaining,
				"" if card.mute_turns_remaining == 1 else "s"
			]
			muted_status_lbl.add_theme_font_size_override("font_size", 11)
			muted_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.86))
			muted_status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(muted_status_lbl)

	# Level (gods have no level)
	if not hidden and not card.is_god:
		var level_lbl := Label.new()
		level_lbl.text = "Level %d" % card.level
		level_lbl.add_theme_font_size_override("font_size", 11)
		level_lbl.modulate = Color(0.7, 0.7, 0.7)
		level_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(level_lbl)

	if card.card_type == Card.CardType.CREATURE and not card.is_god:
		if not hidden:
			if card.is_sleeping:
				var sleep_lbl := Label.new()
				sleep_lbl.text = "Sleeping"
				sleep_lbl.add_theme_font_size_override("font_size", 11)
				sleep_lbl.modulate = Color(0.7, 0.86, 1.0)
				sleep_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				vbox.add_child(sleep_lbl)

			var mode_lbl := Label.new()
			mode_lbl.text = "DEF" if card.creature_mode == Card.CreatureMode.DEFENSIVE else "AGG"
			mode_lbl.add_theme_font_size_override("font_size", 11)
			mode_lbl.modulate = Color(0.7, 0.7, 0.7)
			mode_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(mode_lbl)

			# Full stats
			var eff_str := card.get_effective_strength()
			var eff_res := card.get_effective_resilience()
			var eff_spd := card.get_effective_speed()
			var stats_rtl := RichTextLabel.new()
			stats_rtl.bbcode_enabled = true
			stats_rtl.add_theme_font_size_override("normal_font_size", 11)
			stats_rtl.scroll_active = false
			stats_rtl.fit_content = true
			stats_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var stat_parts: Array[String] = []
			var tooltip_lines: Array[String] = []
			for s_info in [["STR", eff_str, card.strength, "str"], ["RES", eff_res, card.resilience, "res"], ["SPD", eff_spd, card.speed, "spd"]]:
				var lbl_text: String = s_info[0] + ":" + str(s_info[1])
				if s_info[1] != s_info[2]:
					var breakdown := card.get_buff_tooltip(s_info[3])
					if s_info[1] > s_info[2]:
						stat_parts.append("[color=#66ff66]" + lbl_text + "[/color]")
					else:
						stat_parts.append("[color=#ff5555]" + lbl_text + "[/color]")
					if breakdown != "":
						tooltip_lines.append(s_info[0] + ":\n" + breakdown)
				else:
					stat_parts.append(lbl_text)
			stats_rtl.text = " ".join(stat_parts)
			if tooltip_lines.size() > 0:
				stats_rtl.tooltip_text = "\n\n".join(tooltip_lines)
				stats_rtl.mouse_filter = Control.MOUSE_FILTER_STOP
			vbox.add_child(stats_rtl)

			var effect_lines := card.get_effect_summary_lines()
			if effect_lines.size() > 0:
				var effects_lbl := Label.new()
				effects_lbl.text = "\n".join(effect_lines)
				effects_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				effects_lbl.add_theme_font_size_override("font_size", 10)
				effects_lbl.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0))
				effects_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				vbox.add_child(effects_lbl)

			var equipment_lines := card.get_equipment_summary_lines()
			if equipment_lines.size() > 0:
				var equipment_lbl := Label.new()
				equipment_lbl.text = "Equipment:\n" + "\n".join(equipment_lines)
				equipment_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				equipment_lbl.add_theme_font_size_override("font_size", 10)
				equipment_lbl.add_theme_color_override("font_color", Color(1.0, 0.87, 0.62))
				equipment_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				vbox.add_child(equipment_lbl)

			var binding_lines: Array[String] = []
			for binding in _get_attached_permanent_hexes(card):
				var line := binding.card_name
				var binding_effect_lines := _get_binding_hover_lines(binding)
				if binding_effect_lines.is_empty():
					binding_lines.append(line)
				else:
					binding_lines.append(line + ": " + " | ".join(binding_effect_lines))
			var has_dromi_line := false
			for line in binding_lines:
				if line.begins_with(DROMI_BINDING_NAME):
					has_dromi_line = true
					break
			if not has_dromi_line and _has_dromi_binding(card):
				var dromi_source := _get_dromi_binding_source(card)
				if dromi_source != null and dromi_source != card:
					var dromi_effect_lines := _get_binding_hover_lines(dromi_source)
					if dromi_effect_lines.is_empty():
						binding_lines.append(DROMI_BINDING_NAME + ": " + DROMI_BINDING_HOVER_TEXT)
					else:
						binding_lines.append(DROMI_BINDING_NAME + ": " + " | ".join(dromi_effect_lines))
				else:
					binding_lines.append(DROMI_BINDING_NAME + ": " + DROMI_BINDING_HOVER_TEXT)
			if binding_lines.size() > 0:
				var binding_lbl := Label.new()
				binding_lbl.text = "Bindings:\n" + "\n".join(binding_lines)
				binding_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				binding_lbl.add_theme_font_size_override("font_size", 10)
				binding_lbl.add_theme_color_override("font_color", Color(0.66, 0.97, 0.93))
				binding_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				vbox.add_child(binding_lbl)

		# Action usage
		if card.creature_major_action_used:
			var acted_lbl := Label.new()
			acted_lbl.text = "Major action used"
			acted_lbl.add_theme_font_size_override("font_size", 9)
			acted_lbl.modulate = Color(0.8, 0.8, 0.4)
			acted_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(acted_lbl)
		elif card.creature_minor_actions_used > 0:
			var moved_lbl := Label.new()
			moved_lbl.text = "Minor actions: %d/2" % card.creature_minor_actions_used
			moved_lbl.add_theme_font_size_override("font_size", 9)
			moved_lbl.modulate = Color(0.6, 0.9, 0.6)
			moved_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(moved_lbl)

	elif card.card_type == Card.CardType.STRUCTURE:
		var eff_res_s := card.get_effective_resilience()
		var res_lbl := Label.new()
		res_lbl.text = "RES:%d" % eff_res_s
		res_lbl.add_theme_font_size_override("font_size", 11)
		res_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var breakdown := card.get_buff_tooltip("res")
		if eff_res_s < card.resilience:
			res_lbl.modulate = Color(1.0, 0.35, 0.35)
			if breakdown != "":
				res_lbl.tooltip_text = "RES:\n" + breakdown
				res_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		elif eff_res_s > card.resilience:
			res_lbl.modulate = Color(0.4, 1.0, 0.4)
			if breakdown != "":
				res_lbl.tooltip_text = "RES:\n" + breakdown
				res_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(res_lbl)

		var effect_lines := card.get_effect_summary_lines()
		if effect_lines.size() > 0:
			var effects_lbl := Label.new()
			effects_lbl.text = "\n".join(effect_lines)
			effects_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			effects_lbl.add_theme_font_size_override("font_size", 10)
			effects_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45) if card.is_petrified() else Color(0.78, 0.9, 1.0))
			effects_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(effects_lbl)
	elif not hidden and card.speed > 0:
		var eff_spd := card.get_effective_speed()
		var spd_lbl := Label.new()
		spd_lbl.text = "SPD:%d" % eff_spd
		spd_lbl.add_theme_font_size_override("font_size", 11)
		spd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var spd_breakdown := card.get_full_stat_breakdown("spd")
		if eff_spd < card.speed:
			spd_lbl.modulate = Color(1.0, 0.35, 0.35)
			if spd_breakdown != "":
				spd_lbl.tooltip_text = "SPD:\n" + spd_breakdown
				spd_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		elif eff_spd > card.speed:
			spd_lbl.modulate = Color(0.4, 1.0, 0.4)
			if spd_breakdown != "":
				spd_lbl.tooltip_text = "SPD:\n" + spd_breakdown
				spd_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(spd_lbl)

	# Ability text
	if card.ability_text != "" and not hidden:
		var display_ability_text := (card as PowerCard).get_display_ability_bbcode_text(game_manager) if card is PowerCard else card.ability_text
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.text = BaseCard.apply_keyword_hints(display_ability_text)
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.add_theme_font_size_override("normal_font_size", 11)
		rtl.add_theme_font_size_override("bold_font_size", 11)
		rtl.add_theme_color_override("default_color", Color(0.9, 0.85, 1.0))
		rtl.scroll_active = false
		rtl.fit_content = true
		rtl.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(rtl)

	if card is PowerCard and not hidden:
		var power_cost_lines := _get_power_hover_cost_lines(card as PowerCard)
		if power_cost_lines.size() > 0:
			var cost_lbl := Label.new()
			cost_lbl.text = "\n".join(power_cost_lines)
			cost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cost_lbl.add_theme_font_size_override("font_size", 10)
			cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.62))
			cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(cost_lbl)

	var hover_detail_lines := card.get_hover_detail_lines(viewer)
	if hover_detail_lines.size() > 0 and not hidden:
		var hover_details_lbl := Label.new()
		hover_details_lbl.text = "\n".join(hover_detail_lines)
		hover_details_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hover_details_lbl.add_theme_font_size_override("font_size", 10)
		hover_details_lbl.add_theme_color_override("font_color", Color(0.66, 0.97, 0.93))
		hover_details_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(hover_details_lbl)

	# Flavor text
	if card.flavor_text != "" and not hidden:
		var flavor_lbl := Label.new()
		flavor_lbl.text = card.flavor_text
		flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavor_lbl.add_theme_font_size_override("font_size", 10)
		flavor_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		flavor_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(flavor_lbl)

	_popup = popup
	scene_root.add_child(popup)

	# Wait one frame for the popup to size itself, then position it
	await get_tree().process_frame
	if not is_instance_valid(popup):
		return
	var vp_size := get_viewport_rect().size
	var pos := global_position
	pos.y -= popup.size.y + 6
	if pos.y < 0:
		pos.y = global_position.y + size.y + 6
	pos.x = clamp(pos.x, 4.0, vp_size.x - popup.size.x - 4.0)
	popup.global_position = pos

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
