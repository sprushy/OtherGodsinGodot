class_name BoardZoneUI
extends PanelContainer

const CardDetailContentBuilderScript = preload("res://scripts/ui/CardDetailContentBuilder.gd")
const BaseCardScript = preload("res://scripts/cards/BaseCard.gd")
const LockedPowerCursorScript = preload("res://scripts/ui/LockedPowerCursor.gd")
const DefenseShieldOverlayScript = preload("res://scripts/ui/DefenseShieldOverlay.gd")
const AggressiveSwordOverlay = preload("res://scripts/ui/AggressiveSwordOverlay.gd")
const LevelSymbolRowScript = preload("res://scripts/ui/LevelSymbolRow.gd")
const DebuffBadgeScript = preload("res://scripts/ui/DebuffBadge.gd")
const CHAMPIONS_CALL_BADGE_TEXTURE := preload("res://images/Champion's Call Horn Badge.png")
const SMOKING_MIRROR_BADGE_TEXTURE := preload("res://images/Smoking Mirror Icon.png")
const TEZ_SACRIFICE_BADGE_TEXTURE := preload("res://images/TezSacBadge.png")
const APHRODITE_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/AphroditeViolentDelightsBadge.png")
const DELLINGR_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/DellingrRevealingLightBadge.png")
const FREYJA_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/FreyjaReceiverOfTheSlainBadge.png")
const GUAN_YU_TACTICAL_BREAK_BADGE_TEXTURE := preload("res://images/ability_badges/GuanYuTacticalBreakBadge.png")
const HERMES_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/HermesBadge.png")
const MANNAN_MAC_LIR_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/MannanBadge.png")
const MUMMU_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/MummuBadge.png")
const NUSKU_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/NuskuBadge.png")
const BERSERKER_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/BerserkerRageBadge.png")
const BEYLA_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/BeylaReviveBadge.png")
const ROBOTIC_FOOTSOLDIER_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/RoboticFootsoldierUnitedFrontBadge.png")
const SEVENTH_SAGE_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/SeventhSageImbueAllyBadge.png")
const TEZCATLIPOCA_BLASPHEMER_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/TezcatlipocaBlasphemerBloodMagicBadge.png")
const WHITE_SERPENT_MEDICINE_BADGE_TEXTURE := preload("res://images/ability_badges/WhiteSerpentMedicineBadge.png")
const WINGED_LION_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/WingedLionFlankBadge.png")
const ALU_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/AluStupefyBadge.png")
const ANCIENT_PYRE_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/AncientPyreBadge.png")
const ANOINTING_STATUE_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/AnointingStatueBadge.png")
const CLAY_EATERS_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/ClayEatersGeophagiaBadge.png")
const EN_HEDU_ANNA_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/EnHeduAnnaExaltationBadge.png")
const GAMBANTEINN_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/GambanteinnBadge.png")
const GAWAIN_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/GawainHealingHandsBadge.png")
const GUDU_PRIEST_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/GuduPriestBadge.png")
const HARII_SHAMAN_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/HariiShamanBadge.png")
const ISIMUD_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/IsimudRevelationBadge.png")
const KUR_JARA_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/KurJaraSeedOfLifeBadge.png")
const LAMASHATU_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/LamashatuSuckleBadge.png")
const LINDWYRM_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/LindwyrmBadge.png")
const MOPSUS_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/MopsusBadge.png")
const NIMUE_ENTOMB_BADGE_TEXTURE := preload("res://images/ability_badges/NimueEntombBadge.png")
const NIMUE_PRESENT_BADGE_TEXTURE := preload("res://images/ability_badges/NimuePresentBadge.png")
const SHIFT_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/ShiftAbilityBadge.png")
const THRONE_OF_ODIN_ABILITY_BADGE_TEXTURE := preload("res://images/ability_badges/ThroneofOdinBadge.png")
const GUAN_YU_MANOEUVRE_BADGE_TEXTURE := preload("res://images/ability_badges/GuanYuManeuverBadge.png")
const ODIN_RUNIC_KNOWLEDGE_BADGE_TEXTURE := preload("res://images/ability_badges/OdinRunicKnowledgeBadge.png")
const E2_ABZU_RETURN_BADGE_TEXTURE := preload("res://images/ability_badges/E2AbzuReturnBadge.png")
const E2_ABZU_VOID_BADGE_TEXTURE := preload("res://images/ability_badges/E2AbzuVoidBadge.png")
const TEZ_BLOODSTREAK_TEXTURE := preload("res://images/Bloodstreak.png")
const AGGRESSIVE_ATTACK_TARGET_TEXTURE := preload("res://images/ui/attack_targets/AggressiveAttackTarget.png")
const RES_ATTACK_TARGET_TEXTURE := preload("res://images/ui/attack_targets/ResAttackTarget.png")
const DESTROY_ATTACK_TARGET_TEXTURE := preload("res://images/ui/attack_targets/BrokenSword.png")
const STEAL_ATTACK_TARGET_TEXTURE := preload("res://images/ui/attack_targets/StealGlove.png")
const FOLLOWERS_ATTACK_TARGET_TEXTURE := preload("res://images/ui/attack_targets/FollowerAttack.png")
const MOVE_STRAIGHT_INDICATOR_TEXTURE := preload("res://images/ui/move_arrows/ArrowIndicator.png")
const MOVE_DIAGONAL_INDICATOR_TEXTURE := preload("res://images/ui/move_arrows/AngleArrow.png")
const MINOR_ACTION_SYMBOL_TEXTURE := preload("res://images/ui/MinorActionSymbol.png")
const MAJOR_ACTION_SYMBOL_TEXTURE := preload("res://images/ui/MajorActionSymbol.png")
const MANA_ORB_TEXTURE := preload("res://images/ui/ManaOrb.png")
const SWITCH_TO_AGGRESSIVE_SYMBOL_TEXTURE := preload("res://images/ui/SwitchToAggressiveSymbol.png")
const SWITCH_TO_DEFENSIVE_SYMBOL_TEXTURE := preload("res://images/ui/SwitchToDefensiveSymbol.png")
const BOARD_ZONE_SLAB_TEXTURE_PATHS := [
	"res://images/board/stone_zone_slab.png",
	"res://images/board/slot_tile_1.png",
	"res://images/board/slot_tile_2.png",
	"res://images/board/slot_tile_3.png",
	"res://images/board/slot_tile_4.png",
	"res://images/board/slot_tile_5.png",
	"res://images/board/slot_tile_6.png",
	"res://images/board/slot_tile_7.png",
	"res://images/board/slot_tile_8.png",
	"res://images/board/slot_tile_9.png",
]
const BOARD_ZONE_ROW_TILE_COUNT := 5
const TEZ_TONAL_MASTERY_TEXTURES := [
	preload("res://images/TezTonalMastery0.png"),
	preload("res://images/TezTonalMastery1.png"),
	preload("res://images/TezTonalMastery2.png"),
	preload("res://images/TezTonalMastery3.png"),
]
const TEZ_NORMAL_GOD_NAME := "Tezcatlipoca, the Smoking Mirror"
const TEZ_REQUIRED_SACRIFICES := 4
const TEZ_TONAL_MASTERY_TOKEN_THRESHOLD := 3
const LEVEL_BADGE_TOP := -12.0
const LEVEL_BADGE_BOTTOM := 12.0
const BADGE_ROW_GAP := 6.0
const BADGE_ROW_TOP := LEVEL_BADGE_BOTTOM + BADGE_ROW_GAP + 31.0
const GOD_ABILITY_BADGE_TOP_OFFSET := -22.0
const TEZ_PRIMARY_BADGE_SIZE := 58.0 * 1.25
const TEZ_BADGE_RIGHT := -4
const TEZ_BADGE_LEFT := TEZ_BADGE_RIGHT - TEZ_PRIMARY_BADGE_SIZE
const TEZ_PRIMARY_BADGE_TOP := BADGE_ROW_TOP
const TEZ_PRIMARY_BADGE_BOTTOM := TEZ_PRIMARY_BADGE_TOP + TEZ_PRIMARY_BADGE_SIZE
const TEZ_SECONDARY_BADGE_LEFT := -63
const TEZ_SECONDARY_BADGE_RIGHT := -3
const TEZ_SECONDARY_BADGE_TOP := TEZ_PRIMARY_BADGE_BOTTOM + BADGE_ROW_GAP
const TEZ_SECONDARY_BADGE_BOTTOM := TEZ_SECONDARY_BADGE_TOP + 60.0
const BASE_BOARD_Z_INDEX := 0
const RAISED_BOARD_Z_INDEX := 2
const GOD_INDICATOR_Z_INDEX := 3
const PRIORITY_RESPONSE_GLOW_COLOR := Color(0.28, 0.92, 0.50, 0.95)
# Keep hovered board cards above the hand fan overlay, but below the larger
# transient previews and modal UI promoted by CombatMockGame.
const HOVER_BOARD_Z_INDEX := 2260
const POPUP_Z_INDEX := 2290

func _get_badge_row_top() -> float:
	return BADGE_ROW_TOP

func _get_left_affordance_row_top(card: Card) -> float:
	if card == null:
		return _get_badge_row_top()
	return 32.0 if card.is_sleeping else _get_badge_row_top()

func _get_secondary_left_affordance_row_top(card: Card) -> float:
	var badge_top := _get_left_affordance_row_top(card)
	if card != null and not card.equipment.is_empty():
		return badge_top + EquipmentCard.EQUIPPED_AFFORDANCE_SIZE.y + EQUIPMENT_AFFORDANCE_GAP
	return badge_top

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

class PriorityResponseAura extends Control:
	const _ARC_STEPS := 8

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var outer_rect := Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0))
		if outer_rect.size.x <= 0.0 or outer_rect.size.y <= 0.0:
			return

		_draw_rounded_outline(outer_rect, 10.0, Color(0.28, 0.92, 0.50, 0.10), 16.0)
		_draw_rounded_outline(outer_rect, 10.0, Color(0.28, 0.92, 0.50, 0.20), 10.0)
		_draw_rounded_outline(outer_rect, 10.0, Color(0.28, 0.92, 0.50, 0.34), 5.0)
		_draw_rounded_outline(outer_rect, 10.0, Color(0.28, 0.92, 0.50, 0.98), 2.6)

		var inner_rect := outer_rect.grow(-6.0)
		if inner_rect.size.x > 0.0 and inner_rect.size.y > 0.0:
			_draw_rounded_outline(inner_rect, 7.0, Color(0.74, 1.0, 0.78, 0.66), 1.2)

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
signal equipment_target_action_clicked(card: Card, action: String)
signal champions_call_clicked(card: GodCard)
signal god_ability_badge_clicked(card: Card)
signal tez_necoc_yaotl_badge_clicked(card: Card)
signal creature_stance_switch_clicked(card: Card, target_mode: Card.CreatureMode)
signal creature_ability_badge_clicked(card: Card)
signal creature_ability_option_badge_clicked(card: Card, ability: String)
signal e2_abzu_badge_clicked(card: Card, mode: String)
signal nimue_badge_clicked(card: Card, mode: String)
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
var viewer_override: Player = null
var _hovered: bool = false
var _badge_hovered: bool = false
var _pinned: bool = false
var _hide_pending: bool = false
var _hover_exit_refresh_pending: bool = false
var _move_indicator_active: bool = false
var _move_indicator_direction: Vector2 = Vector2.ZERO
var _move_indicator_source_center: Vector2 = Vector2.ZERO
var _move_indicator_target_center: Vector2 = Vector2.ZERO
var _defense_overlay: Control = null
var _raised_overlay: Control = null  # non-null for DEF or stealth - floats above the zone row
var _visual_state_card: Card = null
var _badge_hover_popup: Control = null

const BASE_ZONE_EXTENT := 165.0
const DROMI_BINDING_NAME := "Dromi"
const DROMI_BINDING_HOVER_TEXT := "Cannot attack. Losing 7 followers on opponent's turn start - Dromi"
const THIRD_SAGE_GOOD_FORTUNE_STATUS := "third_sage_good_fortune"
const EQUIPMENT_AFFORDANCE_GAP := 4.0
const EQUIPMENT_AFFORDANCE_TOP := 28.0
const DEBUFF_AFFORDANCE_GAP := DebuffBadgeScript.GAP
const DEBUFF_BADGE_SIZE := DebuffBadgeScript.SIZE
const ABILITY_BADGE_SIZE := 76.8
const CREATURE_ABILITY_BADGE_SIZE := ABILITY_BADGE_SIZE
const CREATURE_ABILITY_BADGE_TOP_OFFSET := -23.0
const E2_ABZU_BADGE_ICON_INSET := 10.0
const ATTACK_TARGET_ICON_SIZE := 74.0
const TARGET_ICON_PAD := 5.0
const TARGET_ICON_GROUP_GAP := 8.0
const STANCE_SWITCH_BADGE_SIZE := 64.0
const STANCE_SWITCH_ICON_LEFT := 3.0
const STANCE_SWITCH_ICON_TOP := -4.0
const STANCE_SWITCH_ICON_SIZE := 58.0
const STANCE_SWITCH_COST_ROW_WIDTH := 34.0
const STANCE_SWITCH_COST_ROW_HEIGHT := 18.0
const ACTION_COST_MARKER_HEIGHT := 18.0
const ACTION_COST_MARKER_ACTION_WIDTH := 34.0
const ACTION_COST_MARKER_MANA_WIDTH := 60.0
const ACTION_COST_MARKER_GROUP := "action_cost_markers"
const FOLLOWERS_ATTACK_RESULT_SECONDS := 0.66
const MOVE_INDICATOR_WIDTH := 104.0
const HOVER_CARD_OPTIONS_ALPHA := 0.56
const ACTION_POINT_BURST_Z_INDEX := 2400
const ACTION_POINT_BURST_PARTICLE_COUNT := 22
const ACTION_POINT_BURST_DURATION := 0.68
const ACTION_POINT_BURST_RADIUS := 54.0
const POWER_LOCK_TEXTURE := preload("res://images/Default Power Lock.png")
const ANCIENT_POWER_LOCK_TEXTURE := preload("res://images/Ancient Power Lock.png")
const NORSE_POWER_LOCK_TEXTURE := preload("res://images/Norse Power Lock.png")
const TIAMAT_GOD_SCRIPT := preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")
const KEYWORD_PANEL_GAP := 8.0
const USER_SETTINGS_PATH := "user://settings.cfg"
const COMBAT_SETTINGS_SECTION := "combat"
const ALWAYS_SHOW_ABILITY_BADGES_KEY := "always_show_ability_badges"
static var _zone_extent: float = BASE_ZONE_EXTENT
static var _creature_action_symbol_state_by_card_uid: Dictionary = {}
static var _always_show_ability_badges: bool = false
static var _always_show_ability_badges_loaded: bool = false
static var _active_affordance_hover_owner_id: int = 0

var _row_label: String = ""
var _followers_attack_result_text: String = ""
var _followers_attack_result_sequence: int = 0
static var _board_zone_slab_textures: Array[Texture2D] = []
static var _board_zone_slot_texture_indices: Array[int] = []

static func get_base_zone_extent() -> float:
	return BASE_ZONE_EXTENT

static func get_zone_extent() -> float:
	return _zone_extent

static func get_zone_size() -> Vector2:
	return Vector2(_zone_extent, _zone_extent)

static func set_zone_extent(extent: float) -> void:
	_zone_extent = max(BASE_ZONE_EXTENT, floor(extent))

static func set_always_show_ability_badges(enabled: bool) -> void:
	_always_show_ability_badges = enabled
	_always_show_ability_badges_loaded = true

static func get_always_show_ability_badges() -> bool:
	if not _always_show_ability_badges_loaded:
		_load_always_show_ability_badges_setting()
	return _always_show_ability_badges

static func _load_always_show_ability_badges_setting() -> void:
	_always_show_ability_badges_loaded = true
	var config := ConfigFile.new()
	if config.load(USER_SETTINGS_PATH) != OK:
		return
	var value = config.get_value(COMBAT_SETTINGS_SECTION, ALWAYS_SHOW_ABILITY_BADGES_KEY, _always_show_ability_badges)
	if value is bool:
		_always_show_ability_badges = value
	elif value is String:
		var text := str(value).strip_edges().to_lower()
		if text in ["true", "1", "yes", "on"]:
			_always_show_ability_badges = true
		elif text in ["false", "0", "no", "off"]:
			_always_show_ability_badges = false

static func get_action_point_card_uid(card: Card) -> String:
	if card == null:
		return ""
	var uid := str(card.uid).strip_edges()
	if uid != "":
		return uid
	return str(card.get_instance_id())

func _find_zone_card_by_uid(card_uid: String) -> Card:
	if card_uid.strip_edges() == "" or zone == null:
		return null
	for zone_card in zone.cards:
		var card := zone_card as Card
		if card == null:
			continue
		if BoardZoneUI.get_action_point_card_uid(card) == card_uid:
			return card
	return null

func _emit_creature_ability_badge_clicked_for_uid(card_uid: String) -> void:
	var resolved_card := _find_zone_card_by_uid(card_uid)
	if resolved_card != null:
		creature_ability_badge_clicked.emit(resolved_card)

func _emit_creature_ability_option_badge_clicked_for_uid(card_uid: String, ability: String) -> void:
	var resolved_card := _find_zone_card_by_uid(card_uid)
	if resolved_card != null:
		creature_ability_option_badge_clicked.emit(resolved_card, ability)

func _emit_e2_abzu_badge_clicked_for_uid(card_uid: String, mode: String) -> void:
	var resolved_card := _find_zone_card_by_uid(card_uid)
	if resolved_card != null:
		e2_abzu_badge_clicked.emit(resolved_card, mode)

func _emit_nimue_badge_clicked_for_uid(card_uid: String, mode: String) -> void:
	var resolved_card := _find_zone_card_by_uid(card_uid)
	if resolved_card != null:
		nimue_badge_clicked.emit(resolved_card, mode)

func _emit_card_clicked_for_uid(card_uid: String) -> void:
	var resolved_card := _find_zone_card_by_uid(card_uid)
	if resolved_card != null:
		card_clicked.emit(resolved_card)

func _emit_champions_call_clicked_for_uid(card_uid: String) -> void:
	var resolved_card := _find_zone_card_by_uid(card_uid)
	if resolved_card != null:
		champions_call_clicked.emit(resolved_card)

func _emit_god_ability_badge_clicked_for_uid(card_uid: String) -> void:
	var resolved_card := _find_zone_card_by_uid(card_uid)
	if resolved_card != null:
		god_ability_badge_clicked.emit(resolved_card)

func _emit_tez_necoc_yaotl_badge_clicked_for_uid(card_uid: String) -> void:
	var resolved_card := _find_zone_card_by_uid(card_uid)
	if resolved_card != null:
		tez_necoc_yaotl_badge_clicked.emit(resolved_card)

func _emit_equipment_target_action_clicked_for_uid(card_uid: String, action: String) -> void:
	var resolved_card := _find_zone_card_by_uid(card_uid)
	if resolved_card != null:
		equipment_target_action_clicked.emit(resolved_card, action)

func _emit_creature_stance_switch_clicked_for_uid(card_uid: String, target_mode: Card.CreatureMode) -> void:
	var resolved_card := _find_zone_card_by_uid(card_uid)
	if resolved_card != null:
		creature_stance_switch_clicked.emit(resolved_card, target_mode)

func _connect_badge_click_action(badge_control: Control, action_name: String, card_uid: String = "", extra_value = null) -> void:
	if badge_control == null or action_name.strip_edges() == "":
		return
	badge_control.set_meta("badge_click_action", action_name)
	badge_control.set_meta("badge_click_card_uid", card_uid)
	if extra_value != null:
		badge_control.set_meta("badge_click_extra", extra_value)
	elif badge_control.has_meta("badge_click_extra"):
		badge_control.remove_meta("badge_click_extra")
	badge_control.gui_input.connect(Callable(self, "_on_badge_gui_input"))

func _on_badge_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var hovered_control := get_viewport().gui_get_hovered_control()
	var badge_control := hovered_control
	while badge_control != null and not badge_control.has_meta("badge_click_action"):
		badge_control = badge_control.get_parent() as Control
	if badge_control == null:
		return
	# Badge actions can synchronously rebuild the board and free this control.
	# Consume the click before dispatch so it cannot become an off-board click
	# for a targeting prompt opened by the action.
	accept_event()
	var action_name := str(badge_control.get_meta("badge_click_action", ""))
	var card_uid := str(badge_control.get_meta("badge_click_card_uid", ""))
	var extra_value = badge_control.get_meta("badge_click_extra") if badge_control.has_meta("badge_click_extra") else null
	match action_name:
		"champions_call":
			_emit_champions_call_clicked_for_uid(card_uid)
		"god_ability":
			_emit_god_ability_badge_clicked_for_uid(card_uid)
		"tez_necoc_yaotl":
			_emit_tez_necoc_yaotl_badge_clicked_for_uid(card_uid)
		"e2_abzu":
			_emit_e2_abzu_badge_clicked_for_uid(card_uid, str(extra_value))
		"nimue":
			_emit_nimue_badge_clicked_for_uid(card_uid, str(extra_value))
		"creature_ability":
			_emit_creature_ability_badge_clicked_for_uid(card_uid)
		"creature_ability_option":
			_emit_creature_ability_option_badge_clicked_for_uid(card_uid, str(extra_value))
		"card_clicked":
			_emit_card_clicked_for_uid(card_uid)
		"equipment_target":
			_emit_equipment_target_action_clicked_for_uid(card_uid, str(extra_value))
		"creature_stance_switch":
			_emit_creature_stance_switch_clicked_for_uid(card_uid, int(extra_value) as Card.CreatureMode)

static func get_creature_action_symbol_entries(card: Card) -> Array[Dictionary]:
	var symbols: Array[Dictionary] = []
	if card == null or card.card_type != Card.CardType.CREATURE:
		return symbols

	var max_minor := maxi(0, card.get_max_minor_creature_actions_per_turn())
	if max_minor > 0:
		var base_minor_capacity := mini(Card.DEFAULT_MINOR_CREATURE_ACTIONS_PER_TURN, max_minor)
		symbols.append({
			"key": "minor_0",
			"kind": Card.ACTION_COST_MINOR,
			"used": card.creature_minor_actions_used >= base_minor_capacity,
			"tooltip": "Minor actions: %d/%d" % [mini(card.creature_minor_actions_used, max_minor), max_minor],
		})
		var extra_minor_count := maxi(0, max_minor - Card.DEFAULT_MINOR_CREATURE_ACTIONS_PER_TURN)
		for i in range(extra_minor_count):
			var threshold := Card.DEFAULT_MINOR_CREATURE_ACTIONS_PER_TURN + i + 1
			symbols.append({
				"key": "minor_%d" % threshold,
				"kind": Card.ACTION_COST_MINOR,
				"used": card.creature_minor_actions_used >= threshold,
				"tooltip": "Additional minor action %d" % (i + 1),
			})
	symbols.append({
		"key": "major",
		"kind": Card.ACTION_COST_MAJOR,
		"used": card.creature_major_action_used,
		"tooltip": "Major action used" if card.creature_major_action_used else "Major action available",
	})
	return symbols

static func get_creature_action_symbol_hover_text(symbol: Dictionary, card: Card) -> String:
	if card == null:
		return ""
	var kind := str(symbol.get("kind", Card.ACTION_COST_NONE))
	match kind:
		Card.ACTION_COST_MINOR:
			var max_minor := maxi(0, card.get_max_minor_creature_actions_per_turn())
			var used_minor := mini(card.creature_minor_actions_used, max_minor)
			var remaining_minor := maxi(0, max_minor - used_minor)
			var lines := [
				"Minor Action Point",
				"%s has %d of %d minor action point(s) remaining this turn." % [card.card_name, remaining_minor, max_minor],
				"Minor actions are used for moving, changing mode, picking up nearby equipment, and some abilities.",
			]
			return "\n".join(lines)
		Card.ACTION_COST_MAJOR:
			var lines := [
				"Major Action Point",
				"%s has already spent its major action point this turn." % card.card_name,
				"Major actions are used for attacking, destroying enemy equipment, and major creature abilities.",
			]
			if not card.creature_major_action_used:
				lines[1] = "%s still has its major action point this turn." % card.card_name
			return "\n".join(lines)
	return str(symbol.get("tooltip", ""))

static func get_creature_action_symbol_state(card: Card) -> Dictionary:
	var state := {}
	for symbol in get_creature_action_symbol_entries(card):
		var key := str(symbol.get("key", ""))
		if key == "":
			continue
		state[key] = {
			"kind": str(symbol.get("kind", Card.ACTION_COST_NONE)),
			"used": bool(symbol.get("used", false)),
		}
	return state

static func get_spent_action_kinds(previous_state: Dictionary, current_state: Dictionary) -> Array[String]:
	var spent: Array[String] = []
	for key in current_state.keys():
		if not previous_state.has(key):
			continue
		var previous_entry = previous_state.get(key, {})
		var current_entry = current_state.get(key, {})
		if not (previous_entry is Dictionary) or not (current_entry is Dictionary):
			continue
		if bool((previous_entry as Dictionary).get("used", false)):
			continue
		if not bool((current_entry as Dictionary).get("used", false)):
			continue
		var kind := str((current_entry as Dictionary).get("kind", Card.ACTION_COST_NONE))
		if kind != Card.ACTION_COST_NONE:
			spent.append(kind)
	return spent

static func get_pending_action_point_spend_visual_kinds(card: Card) -> Array[String]:
	if card == null or not card.has_method("peek_action_point_spend_visual_kinds"):
		return []
	var raw_kinds = card.call("peek_action_point_spend_visual_kinds")
	var kinds: Array[String] = []
	if not (raw_kinds is Array):
		return kinds
	for raw_kind in raw_kinds:
		var kind := str(raw_kind)
		if kind != Card.ACTION_COST_NONE:
			kinds.append(kind)
	return kinds

static func clear_pending_action_point_spend_visual_kinds(card: Card) -> void:
	if card != null and card.has_method("clear_action_point_spend_visual_kinds"):
		card.call("clear_action_point_spend_visual_kinds")

static func _get_action_point_texture(action_cost_kind: String) -> Texture2D:
	match action_cost_kind:
		Card.ACTION_COST_MINOR:
			return MINOR_ACTION_SYMBOL_TEXTURE
		Card.ACTION_COST_MAJOR:
			return MAJOR_ACTION_SYMBOL_TEXTURE
	return null

static func _get_action_point_burst_color(action_cost_kind: String) -> Color:
	match action_cost_kind:
		Card.ACTION_COST_MINOR:
			return Color(0.58, 0.95, 1.0, 0.96)
		Card.ACTION_COST_MAJOR:
			return Color(1.0, 0.78, 0.28, 0.98)
	return Color(1.0, 0.92, 0.62, 0.96)

static func _expand_action_cost_entry_kinds(action_cost_entries: Array) -> Array[String]:
	var kinds: Array[String] = []
	for raw_entry in action_cost_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry := raw_entry as Dictionary
		var kind := str(entry.get("kind", Card.ACTION_COST_NONE))
		var amount := maxi(0, int(entry.get("amount", 0)))
		if kind == Card.ACTION_COST_NONE:
			continue
		for _i in range(amount):
			kinds.append(kind)
	return kinds

static func register_action_cost_marker_for_kinds(marker: Control, actor: Card, kinds: Array) -> void:
	if marker == null or actor == null:
		return
	var actor_uid := get_action_point_card_uid(actor)
	if actor_uid == "":
		return
	var clean_kinds: Array[String] = []
	for raw_kind in kinds:
		var kind := str(raw_kind)
		if kind == Card.ACTION_COST_NONE or kind in clean_kinds:
			continue
		clean_kinds.append(kind)
	if clean_kinds.is_empty():
		return
	marker.set_meta("action_cost_actor_uid", actor_uid)
	marker.set_meta("action_cost_kinds", clean_kinds)
	marker.add_to_group(ACTION_COST_MARKER_GROUP)

static func register_action_cost_marker(marker: Control, actor: Card, action_cost_entries: Array) -> void:
	register_action_cost_marker_for_kinds(marker, actor, _expand_action_cost_entry_kinds(action_cost_entries))

static func spawn_action_point_spend_effect(parent: Node, global_center: Vector2, action_cost_kind: String, source_size: float = 22.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if not parent.is_inside_tree():
		return
	var texture := _get_action_point_texture(action_cost_kind)
	if texture == null:
		return

	var burst := Control.new()
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.top_level = true
	burst.z_as_relative = false
	burst.z_index = ACTION_POINT_BURST_Z_INDEX
	burst.size = Vector2.ZERO
	parent.add_child(burst)
	burst.global_position = global_center

	var color := _get_action_point_burst_color(action_cost_kind)
	var major_burst := action_cost_kind == Card.ACTION_COST_MAJOR
	var duration := ACTION_POINT_BURST_DURATION * (1.45 if major_burst else 1.0)
	var radius := ACTION_POINT_BURST_RADIUS * (1.28 if major_burst else 1.0)
	var particle_count := ACTION_POINT_BURST_PARTICLE_COUNT + (18 if major_burst else 0)
	var icon_size := maxf(14.0, source_size) * (1.18 if major_burst else 1.0)
	var core := TextureRect.new()
	core.texture = texture
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	core.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	core.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	core.size = Vector2(icon_size, icon_size)
	core.position = -core.size * 0.5
	core.pivot_offset = core.size * 0.5
	core.modulate = Color(1.0, 1.0, 1.0, 0.98)
	burst.add_child(core)

	var ring_size := maxf(icon_size + 8.0, 28.0)
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(ring_size, ring_size)
	ring.position = -ring.size * 0.5
	ring.pivot_offset = ring.size * 0.5
	ring.modulate = Color(1.0, 1.0, 1.0, 0.9)
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_color = color
	ring_style.corner_radius_top_left = int(ceil(ring_size * 0.5))
	ring_style.corner_radius_top_right = int(ceil(ring_size * 0.5))
	ring_style.corner_radius_bottom_left = int(ceil(ring_size * 0.5))
	ring_style.corner_radius_bottom_right = int(ceil(ring_size * 0.5))
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		ring_style.set_border_width(side, 2 if major_burst else 1)
	ring.add_theme_stylebox_override("panel", ring_style)
	burst.add_child(ring)

	var tween := burst.create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "scale", Vector2(1.9, 1.9), duration * 0.74).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(core, "rotation", 0.35 if major_burst else -0.22, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(core, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(ring, "scale", Vector2(2.35, 2.35), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	for i in range(particle_count):
		var dot_size := 3.0 + float(i % 4)
		var dot := Panel.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size = Vector2(dot_size, dot_size)
		dot.position = -dot.size * 0.5
		dot.pivot_offset = dot.size * 0.5
		dot.modulate = Color(1.0, 1.0, 1.0, 0.94)
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = color
		dot_style.corner_radius_top_left = int(ceil(dot_size))
		dot_style.corner_radius_top_right = int(ceil(dot_size))
		dot_style.corner_radius_bottom_left = int(ceil(dot_size))
		dot_style.corner_radius_bottom_right = int(ceil(dot_size))
		dot.add_theme_stylebox_override("panel", dot_style)
		burst.add_child(dot)

		var angle := TAU * (float(i) / float(particle_count)) + (0.18 if i % 2 == 0 else -0.12)
		var distance := radius * (0.66 + 0.075 * float(i % 5))
		var target_pos := Vector2(cos(angle), sin(angle)) * distance - dot.size * 0.5
		tween.tween_property(dot, "position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(dot, "scale", Vector2(0.12, 0.12), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(dot, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		if i % 2 == 0:
			var ray := ColorRect.new()
			ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ray.color = color
			ray.size = Vector2(2.0, 10.0 + float(i % 3) * 3.0)
			ray.position = -ray.size * 0.5
			ray.pivot_offset = ray.size * 0.5
			ray.rotation = angle
			ray.modulate = Color(1.0, 1.0, 1.0, 0.88)
			burst.add_child(ray)

			var ray_distance := distance * 0.72
			var ray_target := Vector2(cos(angle), sin(angle)) * ray_distance - ray.size * 0.5
			tween.tween_property(ray, "position", ray_target, duration * 0.86).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(ray, "scale", Vector2(0.18, 1.55), duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(ray, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.finished.connect(_free_control_if_valid.bind(burst))

static func _free_control_if_valid(control: Control) -> void:
	if control != null and is_instance_valid(control):
		control.queue_free()

func _get_viewer_player() -> Player:
	if viewer_override != null:
		return viewer_override
	if game_manager == null:
		return null
	return game_manager.get_feedback_viewer()

func _is_public_power(card: Card) -> bool:
	return card is PowerCard and ((card as PowerCard).is_publicly_revealed or card.is_revealed_to_all() or not card.is_face_down)

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
		return power.get_unlock_display_cost_lines(game_manager)

	var hover_data: Dictionary = power.get_activation_cost_hover_data(game_manager)
	if hover_data.is_empty():
		return lines

	var base_cost: int = int(hover_data.get("base_cost", 0))
	var cost_kind: String = str(hover_data.get("cost_kind", Card.COST_KIND_POWER_ACTIVATION))
	var metadata: Dictionary = hover_data.get("metadata", {})
	var label: String = str(hover_data.get("label", "Activation Cost"))
	var current_cost := power.get_adjusted_mana_cost(base_cost, cost_kind, game_manager, metadata)
	if power.should_include_activation_cost_summary_line(game_manager):
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
	var cost_parts := card.get_cost_shorthand_parts(current_cost)
	if not cost_parts.is_empty():
		lines.append("Activation Cost: " + " ".join(cost_parts))

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

func _get_prepared_magical_cost_badge_width(cost_parts: Array[String]) -> float:
	var width := 48.0
	for part in cost_parts:
		var part_text := str(part)
		if part_text.ends_with("M") and part_text.length() > 1:
			width += 14.0
		else:
			width += 17.0 + float(maxi(0, part_text.length() - 2)) * 5.0
	return clampf(width, 60.0, 116.0)

func _add_sleep_affordance(overlay: Control, card: Card) -> void:
	if card == null or not card.is_sleeping:
		return

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -78
	badge.offset_top = 6
	badge.offset_right = -6
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
	label.add_theme_font_size_override("font_size", 14)
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
	var cost_parts := card.get_cost_shorthand_parts(display_cost)
	if cost_parts.is_empty():
		return

	var font_color := Color(0.92, 0.97, 1.0)
	if display_cost > card.mana_cost:
		font_color = Color(1.0, 0.7, 0.7)
	elif display_cost < card.mana_cost:
		font_color = Color(0.65, 1.0, 0.72)

	var badge := _make_empty_field_badge()
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var badge_width := _get_prepared_magical_cost_badge_width(cost_parts)
	badge.offset_left = -badge_width
	badge.offset_top = 6
	badge.offset_right = -6
	badge.offset_bottom = 28.0

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(row)
	_populate_cost_text_row(row, " ".join(cost_parts), 12, font_color, 13.0)
	overlay.add_child(badge)

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

func _make_field_mana_badge(
	prefix: String,
	mana_cost: int,
	font_size: int = 12,
	font_color: Color = Color(0.92, 0.97, 1.0),
	icon_size: float = 13.0
) -> PanelContainer:
	var badge := _make_empty_field_badge()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(row)
	if prefix != "":
		row.add_child(_make_field_badge_label(prefix, font_size, font_color))
	row.add_child(_make_field_badge_label(str(mana_cost), font_size, font_color))
	row.add_child(_make_field_mana_icon(icon_size))
	return badge

func _make_empty_field_badge() -> PanelContainer:
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
	return badge

func _make_field_badge_label(text: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_field_mana_icon(icon_size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = MANA_ORB_TEXTURE
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _populate_cost_text_row(
	row: HBoxContainer,
	cost_text: String,
	font_size: int,
	font_color: Color,
	icon_size: float
) -> void:
	if row == null:
		return
	for raw_part in cost_text.split(" ", false):
		var part := str(raw_part)
		if part.ends_with("M") and part.length() > 1:
			row.add_child(_make_field_badge_label(part.substr(0, part.length() - 1), font_size, font_color))
			row.add_child(_make_field_mana_icon(icon_size))
		else:
			row.add_child(_make_field_badge_label(part, font_size, font_color))

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

func _add_overlay_mana_badge(
	overlay: Control,
	prefix: String,
	mana_cost: int,
	anchor_preset: int,
	left: float,
	top: float,
	right: float,
	bottom: float,
	font_color: Color = Color(0.92, 0.97, 1.0)
) -> PanelContainer:
	if overlay == null or not is_instance_valid(overlay) or overlay.is_queued_for_deletion():
		return null
	var badge := _make_field_mana_badge(prefix, mana_cost, 12, font_color, 13.0)
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
	_right: float,
	bottom: float
) -> PanelContainer:
	if overlay == null or card == null or card.is_god or card.is_power:
		return null
	var effective_level := card.get_effective_level()
	var symbol_color := Color(1.0, 0.96, 0.78)
	if effective_level > card.level:
		symbol_color = Color(0.4, 1.0, 0.4)
	elif effective_level < card.level:
		symbol_color = Color(1.0, 0.35, 0.35)

	var symbol_size := maxf(6.0, bottom - top - 4.0)
	var badge_width := symbol_size * float(effective_level) + 10.0
	var badge := _make_empty_field_badge()
	badge.set_anchors_preset(anchor_preset)
	badge.offset_left = left
	badge.offset_top = top
	badge.offset_right = left + badge_width
	badge.offset_bottom = bottom
	var row := LevelSymbolRowScript.new()
	row.setup(
		effective_level,
		symbol_size,
		symbol_color,
		LevelSymbolRowScript.get_symbol_texture_for_card(card)
	)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(row)
	overlay.add_child(badge)
	var tooltip_lines := PackedStringArray(["Level: %d" % effective_level])
	var breakdown := card.get_full_stat_breakdown("lvl")
	if breakdown != "":
		tooltip_lines.append("LVL:\n" + breakdown)
	if badge != null:
		badge.tooltip_text = "\n".join(tooltip_lines)
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
	return badge

func _add_token_badge(
	overlay: Control,
	card: Card,
	anchor_preset: int,
	left: float,
	top: float,
	right: float,
	bottom: float
) -> PanelContainer:
	if overlay == null or card == null or not card.is_token or card.card_type != Card.CardType.CREATURE:
		return null
	var badge := _add_overlay_stat_badge(
		overlay,
		"TOKEN",
		anchor_preset,
		left,
		top,
		right,
		bottom,
		Color(0.84, 0.95, 1.0)
	)
	if badge != null:
		badge.tooltip_text = "Token Creature"
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
	return badge

func _add_turn_countdown_badge(overlay: Control, card: Card) -> void:
	if overlay == null or card == null or not card.has_method("get_turn_countdown_badge_text"):
		return
	var badge_text := str(card.call("get_turn_countdown_badge_text", game_manager)).strip_edges()
	if badge_text == "":
		return
	var badge := _add_overlay_stat_badge(
		overlay,
		badge_text,
		Control.PRESET_TOP_RIGHT,
		-48,
		6,
		-6,
		28,
		Color(1.0, 0.88, 0.48)
	)
	if badge == null:
		return
	var hover_text := ""
	if card.has_method("get_turn_countdown_badge_hover_text"):
		hover_text = str(card.call("get_turn_countdown_badge_hover_text", game_manager)).strip_edges()
	if hover_text != "":
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		_connect_badge_hover(badge, hover_text)

func _get_power_status_cost_text(card: Card) -> String:
	if not (card is PowerCard):
		return ""
	var power_card := card as PowerCard
	if power_card.is_face_down:
		var viewer := _get_viewer_player()
		if viewer == null or power_card.get_controller() != viewer:
			return ""
		var unlock_cost_text: String = power_card.get_unlock_display_cost_shorthand(game_manager, true)
		if unlock_cost_text.is_empty():
			return "Unlock Free"
		return "Unlock %s" % unlock_cost_text

	var activation_cost := _get_power_activation_mana_cost(power_card)
	if activation_cost <= 0:
		return ""
	return "M:%d" % activation_cost

func _get_power_activation_mana_cost(power_card: PowerCard) -> int:
	var hover_data: Dictionary = power_card.get_activation_cost_hover_data(game_manager)
	if not hover_data.is_empty():
		var base_cost: int = int(hover_data.get("base_cost", 0))
		if base_cost > 0:
			return power_card.get_activation_mana_cost(base_cost, game_manager)

	if power_card.ability_text.find("[b]Activate[/b]") == -1:
		return 0

	var regex := RegEx.new()
	if regex.compile("(?i)pay\\s+(\\d+)\\s+mana") != OK:
		return 0
	var result := regex.search(power_card.get_display_ability_text(game_manager))
	if result == null:
		return 0
	var parsed_cost := int(result.get_string(1))
	return maxi(parsed_cost, 0)

func _get_creature_ability_badge_effect_text(card: Card) -> String:
	if card == null:
		return ""
	var ability_text := str(card.ability_text).strip_edges()
	if ability_text == "":
		return ""
	var colon_index := ability_text.find(":")
	if colon_index == -1:
		return ability_text
	return ability_text.substr(colon_index + 1).strip_edges()

func _add_power_cost_badge(overlay: Control, card: Card) -> void:
	if overlay == null or card == null:
		return
	var badge_text := _get_power_status_cost_text(card)
	if badge_text == "":
		return
	if not is_instance_valid(overlay) or overlay.is_queued_for_deletion():
		return

	if not card.is_face_down:
		var activation_badge := _add_overlay_mana_badge(
			overlay,
			"",
			_get_power_activation_mana_cost(card as PowerCard),
			Control.PRESET_TOP_RIGHT,
			-66,
			6,
			-6,
			28.0,
			Color(0.78, 1.0, 0.82)
		)
		if activation_badge != null:
			activation_badge.tooltip_text = "Activation Cost: %d" % _get_power_activation_mana_cost(card as PowerCard)
			activation_badge.mouse_filter = Control.MOUSE_FILTER_STOP
		return

	var lock_badge := PanelContainer.new()
	lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_badge.set_anchors_preset(Control.PRESET_CENTER)
	lock_badge.offset_left = -34
	lock_badge.offset_top = 32
	lock_badge.offset_right = 34
	lock_badge.offset_bottom = 52

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	badge_style.border_color = Color(1.0, 0.86, 0.42, 0.96)
	badge_style.corner_radius_top_left = 6
	badge_style.corner_radius_top_right = 6
	badge_style.corner_radius_bottom_left = 6
	badge_style.corner_radius_bottom_right = 6
	badge_style.content_margin_left = 5
	badge_style.content_margin_right = 5
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		badge_style.set_border_width(side, 1)
	lock_badge.add_theme_stylebox_override("panel", badge_style)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_badge.add_child(row)
	_populate_cost_text_row(row, badge_text, 9, Color(1.0, 0.95, 0.72), 10.0)
	overlay.add_child(lock_badge)

func _add_power_lock_overlay(overlay: Control, card: Card) -> void:
	if overlay == null or card == null:
		return
	if card.card_type != Card.CardType.POWER or not card.is_face_down:
		return
	if _is_public_power(card) or card.is_temporarily_revealed():
		return
	var viewer := _get_viewer_player()
	var culture_is_known := viewer != null and card.get_controller() == viewer
	_add_power_lock_texture_overlay(overlay, card, culture_is_known)
	_add_power_cost_badge(overlay, card)

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

func _apply_priority_response_style(style: StyleBoxFlat) -> void:
	if style == null:
		return
	style.border_color = PRIORITY_RESPONSE_GLOW_COLOR
	style.shadow_color = PRIORITY_RESPONSE_GLOW_COLOR
	style.shadow_size = max(style.shadow_size, 16)

func _add_champions_call_badge(overlay: Control, card: Card, is_ready: bool) -> void:
	if overlay == null or card == null:
		return
	var god := card as GodCard
	if god == null:
		return

	var clickable := not _is_enemy and god.get_controller() == _get_viewer_player()
	var god_uid := BoardZoneUI.get_action_point_card_uid(god)
	if not _should_show_ability_badge_control(god, is_ready, clickable):
		return
	var badge := Control.new()
	badge.name = "ChampionsCallBadge"
	badge.tooltip_text = "Champion's Call"
	badge.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	badge.z_index = 30
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var badge_top := _get_badge_row_top() + GOD_ABILITY_BADGE_TOP_OFFSET
	badge.offset_left = -6.0 - ABILITY_BADGE_SIZE
	badge.offset_top = badge_top
	badge.offset_right = -6
	badge.offset_bottom = badge_top + ABILITY_BADGE_SIZE

	var icon := TextureRect.new()
	icon.texture = CHAMPIONS_CALL_BADGE_TEXTURE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.modulate = Color(1, 1, 1, 1) if is_ready else Color(0.72, 0.72, 0.72, 0.72)
	badge.add_child(icon)

	if clickable:
		_connect_badge_click_action(badge, "champions_call", god_uid)
	_connect_badge_hover(badge, "Champion's Call", _get_hover_summoned_active_god(god))
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

func _is_tez_tonal_mastery_card(card: Card) -> bool:
	return card != null \
		and card.card_name == TEZ_NORMAL_GOD_NAME \
		and card.has_method("get_tonal_mastery_token_count")

func _get_tez_tonal_mastery_token_count(card: Card) -> int:
	if not _is_tez_tonal_mastery_card(card):
		return 0
	return clampi(int(card.call("get_tonal_mastery_token_count")), 0, TEZ_TONAL_MASTERY_TOKEN_THRESHOLD)

func _get_tez_tonal_mastery_texture(card: Card) -> Texture2D:
	var token_count := clampi(_get_tez_tonal_mastery_token_count(card), 0, TEZ_TONAL_MASTERY_TEXTURES.size() - 1)
	return TEZ_TONAL_MASTERY_TEXTURES[token_count] as Texture2D

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

func _add_tez_tonal_mastery_badge(overlay: Control, card: Card) -> void:
	if overlay == null or card == null or not _is_tez_tonal_mastery_card(card):
		return

	var token_count := _get_tez_tonal_mastery_token_count(card)
	var texture := _get_tez_tonal_mastery_texture(card)
	if texture == null:
		return

	var badge := Control.new()
	badge.name = "TezTonalMasteryBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	badge.mouse_default_cursor_shape = Control.CURSOR_ARROW
	badge.z_index = 31
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = TEZ_SECONDARY_BADGE_LEFT
	badge.offset_top = TEZ_SECONDARY_BADGE_TOP
	badge.offset_right = TEZ_SECONDARY_BADGE_RIGHT
	badge.offset_bottom = TEZ_SECONDARY_BADGE_BOTTOM

	var icon := TextureRect.new()
	icon.texture = texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(icon)

	_connect_badge_hover(
		badge,
		"Tonal Mastery: %d/%d tokens\nAt 3 tokens, gain 3 mana and reset." % [
			token_count,
			TEZ_TONAL_MASTERY_TOKEN_THRESHOLD
		]
	)
	overlay.add_child(badge)

func _add_smoking_mirror_badge(overlay: Control, card: Card) -> void:
	if overlay == null or card == null:
		return
	if not _is_tez_necoc_yaotl_card(card):
		return

	var clickable := not _is_enemy and card.get_controller() == _get_viewer_player()
	var card_uid := BoardZoneUI.get_action_point_card_uid(card)
	var badge_ready := game_manager != null \
		and card.has_method("can_resolve_necoc_yaotl_summon") \
		and bool(card.call("can_resolve_necoc_yaotl_summon", game_manager))
	if not _should_show_ability_badge_control(card, badge_ready, clickable):
		return
	var badge := Control.new()
	badge.name = "SmokingMirrorBadge"
	var hover_text := "Summon Tezcatlipoca, Active God"
	if not badge_ready and game_manager != null and card.has_method("get_necoc_yaotl_summon_failure_reason"):
		var failure_reason := str(card.call("get_necoc_yaotl_summon_failure_reason", game_manager))
		if failure_reason != "":
			hover_text = failure_reason
	badge.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	badge.z_index = 31
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = TEZ_BADGE_LEFT
	badge.offset_top = TEZ_PRIMARY_BADGE_TOP
	badge.offset_right = TEZ_BADGE_RIGHT
	badge.offset_bottom = TEZ_PRIMARY_BADGE_BOTTOM

	var icon := TextureRect.new()
	icon.texture = SMOKING_MIRROR_BADGE_TEXTURE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.modulate = Color(1, 1, 1, 1) if badge_ready else Color(0.78, 0.74, 0.82, 0.86)
	badge.add_child(icon)

	if clickable:
		_connect_badge_click_action(badge, "tez_necoc_yaotl", card_uid)
	_connect_badge_hover(badge, hover_text, _get_hover_summoned_active_god(card))
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
	var card_uid := BoardZoneUI.get_action_point_card_uid(card)
	var badge_ready := game_manager != null \
		and sacrifice_count < TEZ_REQUIRED_SACRIFICES \
		and card.has_method("can_activate") \
		and bool(card.call("can_activate", game_manager)) \
		and not _get_tez_valid_sacrifices(card).is_empty()
	var clickable := not _is_enemy and card.get_controller() == _get_viewer_player()
	if not _should_show_ability_badge_control(card, badge_ready, clickable):
		return

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
	badge.offset_left = TEZ_BADGE_LEFT
	badge.offset_top = TEZ_PRIMARY_BADGE_TOP
	badge.offset_right = TEZ_BADGE_RIGHT
	badge.offset_bottom = TEZ_PRIMARY_BADGE_BOTTOM

	var icon := TextureRect.new()
	icon.texture = TEZ_SACRIFICE_BADGE_TEXTURE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.modulate = Color(1, 1, 1, 1) if badge_ready else Color(0.86, 0.82, 0.76, 0.92)
	badge.add_child(icon)

	_add_tez_bloodstreaks(badge, sacrifice_count)

	if clickable:
		_connect_badge_click_action(badge, "tez_necoc_yaotl", card_uid)
	_connect_badge_hover(badge, hover_text, _get_hover_summoned_active_god(card))
	overlay.add_child(badge)

func _get_creature_ability_badge_texture(card: Card) -> Texture2D:
	if card == null:
		return null
	if card.has_method("get_activation_label") and str(card.get_activation_label()) == "Shift":
		return SHIFT_ABILITY_BADGE_TEXTURE
	if card.card_name == "Berserker":
		return BERSERKER_ABILITY_BADGE_TEXTURE
	if card.card_name == "Beyla":
		return BEYLA_ABILITY_BADGE_TEXTURE
	if card.card_name == "Robotic Footsoldier":
		return ROBOTIC_FOOTSOLDIER_ABILITY_BADGE_TEXTURE
	if card.card_name == "Seventh Sage Utuabzu":
		return SEVENTH_SAGE_ABILITY_BADGE_TEXTURE
	if card.card_name == "Tezcatlipoca Blasphemer":
		return TEZCATLIPOCA_BLASPHEMER_ABILITY_BADGE_TEXTURE
	if card.card_name == "Winged Lion":
		return WINGED_LION_ABILITY_BADGE_TEXTURE
	if card.card_name == "Alu":
		return ALU_ABILITY_BADGE_TEXTURE
	if card.card_name == "Clay-Eaters":
		return CLAY_EATERS_ABILITY_BADGE_TEXTURE
	if card.card_name == "En-hedu-anna":
		return EN_HEDU_ANNA_ABILITY_BADGE_TEXTURE
	if card.card_name == "Gawain":
		return GAWAIN_ABILITY_BADGE_TEXTURE
	if card.card_name == "Gudu Priest":
		return GUDU_PRIEST_ABILITY_BADGE_TEXTURE
	if card.card_name == "Harii Shaman":
		return HARII_SHAMAN_ABILITY_BADGE_TEXTURE
	if card.card_name == "Isimud":
		return ISIMUD_ABILITY_BADGE_TEXTURE
	if card.card_name == "Kur-Jara":
		return KUR_JARA_ABILITY_BADGE_TEXTURE
	if card.card_name == "Lamashatu":
		return LAMASHATU_ABILITY_BADGE_TEXTURE
	if card.card_name == "Lindwyrm":
		return LINDWYRM_ABILITY_BADGE_TEXTURE
	if card.card_name == "Mopsus":
		return MOPSUS_ABILITY_BADGE_TEXTURE
	return null

func _get_god_custom_ability_badge_texture(card: Card) -> Texture2D:
	if card == null:
		return null
	if card.card_name == "Aphrodite Areia":
		var cropped_texture := AtlasTexture.new()
		cropped_texture.atlas = APHRODITE_ABILITY_BADGE_TEXTURE
		cropped_texture.region = Rect2(87, 20, 850, 850)
		return cropped_texture
	if card.card_name == "Dellingr, the Dayspring":
		return DELLINGR_ABILITY_BADGE_TEXTURE
	if card.card_name == "Freyja":
		return FREYJA_ABILITY_BADGE_TEXTURE
	if card.card_name == "Guan Yu":
		return GUAN_YU_TACTICAL_BREAK_BADGE_TEXTURE
	if card.card_name == "Guan Yu, Active God":
		return GUAN_YU_MANOEUVRE_BADGE_TEXTURE
	if card.card_name == "Hermes":
		return HERMES_ABILITY_BADGE_TEXTURE
	if card.card_name == "Odin, the Allfather":
		return ODIN_RUNIC_KNOWLEDGE_BADGE_TEXTURE
	if card.card_name == "Mummu, The One Who Has Awoken" or card.card_name == "Mummu, Active God":
		return MUMMU_ABILITY_BADGE_TEXTURE
	if card.card_name == "Nusku, Firebearer" or card.card_name == "Nusku, Active God":
		return NUSKU_ABILITY_BADGE_TEXTURE
	if CardCatalog.to_lookup_key(card.card_name) in ["manannnmaclir", "manannanmaclir"]:
		return MANNAN_MAC_LIR_ABILITY_BADGE_TEXTURE
	return null

func _get_board_card_custom_ability_badge_texture(card: Card) -> Texture2D:
	if card == null:
		return null
	if card.card_name == "Ancient Pyre":
		return ANCIENT_PYRE_ABILITY_BADGE_TEXTURE
	if card.card_name == "Anointing Statue":
		return ANOINTING_STATUE_ABILITY_BADGE_TEXTURE
	if card.card_name == "Hildskjalf: Throne of Odin":
		return THRONE_OF_ODIN_ABILITY_BADGE_TEXTURE
	if card.card_name == "Gambanteinn":
		return GAMBANTEINN_ABILITY_BADGE_TEXTURE
	return null

func _can_show_board_card_custom_ability_badge_as_ready(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	if card is AnointingStatue:
		var statue := card as AnointingStatue
		for player in game_manager.players:
			if player == null:
				continue
			for zone in player.frontline_zones + player.reserve_zones:
				for target in zone.cards:
					if statue.can_activate(game_manager, target):
						return true
		return false
	return card.has_method("can_activate") and card.has_method("activate") and card.can_activate(game_manager)

func _get_creature_ability_badge_mana_cost(card: Card) -> int:
	if card == null:
		return 0
	var ability_text := str(card.ability_text)
	if ability_text == "":
		return 0
	var regex := RegEx.new()
	if regex.compile("(?i)(?:cost\\s*(\\d+)|(\\d+)\\s+mana|pay\\s+(\\d+)\\s+mana)") != OK:
		return 0
	var result := regex.search(ability_text)
	if result == null:
		return 0
	for group_index in [1, 2, 3]:
		var raw_value := result.get_string(group_index)
		if raw_value != "":
			return maxi(int(raw_value), 0)
	return 0

func _get_creature_ability_badge_hover_text(card: Card) -> String:
	if card == null:
		return ""
	var mana_cost := _get_creature_ability_badge_mana_cost(card)
	var ability_text := str(card.ability_text).strip_edges()
	if ability_text == "":
		return str(card.get_activation_label()) if card.has_method("get_activation_label") else ""
	if mana_cost > 0 and card.has_method("get_activation_label"):
		var effect_text := _get_creature_ability_badge_effect_text(card)
		var header := "[b]%s[/b] (%d %s)" % [
			str(card.get_activation_label()),
			mana_cost,
			BaseCardScript.get_mana_symbol_bbcode(14)
		]
		ability_text = header + (": " + effect_text if effect_text != "" else "")
	return BaseCardScript.apply_keyword_hints(BaseCardScript.apply_action_cost_symbols(ability_text, card))

func _get_creature_ability_badge_right(card: Card) -> float:
	var badge_right := -6.0
	if card == null:
		return badge_right
	var debuff_entries := _get_debuff_affordance_entries(card)
	badge_right -= float(debuff_entries.size()) * (DEBUFF_BADGE_SIZE + DEBUFF_AFFORDANCE_GAP)
	return badge_right

func _get_e2_abzu_badge_hover_text(mode: String) -> String:
	match mode:
		"return":
			return BaseCardScript.apply_keyword_hints(BaseCardScript.apply_action_cost_symbols(
				"[b]Return from Void[/b] (3 " + BaseCardScript.get_mana_symbol_bbcode(14) + "): Add a Mer Mage from your [b]Void[/b] to your hand with level less than your mana count."
			))
		"void":
			return BaseCardScript.apply_keyword_hints(BaseCardScript.apply_action_cost_symbols(
				"[b]Send to Void[/b] (2 " + BaseCardScript.get_mana_symbol_bbcode(14) + ", [b]Spd[/b] 3): [b]Void[/b] a friendly Mer Mage from the field until end of turn."
			))
	return ""

func _add_e2_abzu_mode_badge(
	overlay: Control,
	card: Card,
	card_uid: String,
	mode: String,
	texture: Texture2D,
	top: float,
	badge_ready: bool,
	hover_text: String,
	clickable: bool
) -> void:
	if overlay == null or texture == null or hover_text.strip_edges() == "":
		return
	if not _should_show_ability_badge_control(card, badge_ready, clickable):
		return
	var badge_right := _get_creature_ability_badge_right(card)
	var badge := Control.new()
	badge.name = "E2AbzuBadge_%s" % mode
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	badge.z_index = 31
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = badge_right - CREATURE_ABILITY_BADGE_SIZE
	badge.offset_top = top
	badge.offset_right = badge_right
	badge.offset_bottom = top + CREATURE_ABILITY_BADGE_SIZE

	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = E2_ABZU_BADGE_ICON_INSET
	icon.offset_top = E2_ABZU_BADGE_ICON_INSET
	icon.offset_right = -E2_ABZU_BADGE_ICON_INSET
	icon.offset_bottom = -E2_ABZU_BADGE_ICON_INSET
	icon.modulate = Color(1, 1, 1, 1) if badge_ready else Color(0.78, 0.82, 0.88, 0.88)
	badge.add_child(icon)

	if clickable and card_uid != "":
		_connect_badge_click_action(badge, "e2_abzu", card_uid, mode)
	_connect_badge_hover(badge, hover_text)
	overlay.add_child(badge)

func _add_e2_abzu_badges(overlay: Control, card: Card) -> void:
	if overlay == null or not (card is E2Abzu):
		return
	var structure := card as E2Abzu
	var card_uid := BoardZoneUI.get_action_point_card_uid(card)
	var clickable := not _is_enemy and card.get_controller() == _get_viewer_player()
	var can_return := false
	var can_void := false
	if game_manager != null:
		var top_action: CardAction = null
		if not game_manager.action_stack.is_empty():
			top_action = game_manager.action_stack.back() as CardAction
		can_return = top_action == null \
			and structure.get_controller() == game_manager.current_player \
			and not structure.get_valid_void_targets(game_manager).is_empty()
		var can_fast_void := top_action != null and structure.can_respond_to_priority_action(top_action, game_manager) and not structure.get_priority_field_targets(game_manager, top_action).is_empty()
		var can_normal_void := structure.get_controller() == game_manager.current_player and not structure.get_valid_field_targets(game_manager).is_empty()
		can_void = can_fast_void or can_normal_void
	var top_badge_top := _get_badge_row_top() + CREATURE_ABILITY_BADGE_TOP_OFFSET
	var lower_badge_top := top_badge_top + CREATURE_ABILITY_BADGE_SIZE + 4.0
	_add_e2_abzu_mode_badge(
		overlay,
		card,
		card_uid,
		"return",
		E2_ABZU_RETURN_BADGE_TEXTURE,
		top_badge_top,
		can_return,
		_get_e2_abzu_badge_hover_text("return"),
		clickable
	)
	_add_e2_abzu_mode_badge(
		overlay,
		card,
		card_uid,
		"void",
		E2_ABZU_VOID_BADGE_TEXTURE,
		lower_badge_top,
		can_void,
		_get_e2_abzu_badge_hover_text("void"),
		clickable
	)

func _get_nimue_badge_hover_text(mode: String) -> String:
	match mode:
		"entomb":
			return BaseCardScript.apply_keyword_hints(BaseCardScript.apply_action_cost_symbols(
				"[b]Entomb[/b] ([b]Major Action[/b]): Pay mana equal to a creature's Lvl to [b]Shelve[/b] it."
			))
		"present":
			return BaseCardScript.apply_keyword_hints(BaseCardScript.apply_action_cost_symbols(
				"[b]Present[/b] ([b]Major Action[/b]): Put an Equipment card from your graveyard onto the field."
			))
	return ""

func _add_nimue_mode_badge(
	overlay: Control,
	card: Card,
	card_uid: String,
	mode: String,
	texture: Texture2D,
	top: float,
	badge_ready: bool,
	hover_text: String,
	clickable: bool
) -> void:
	if overlay == null or texture == null or hover_text.strip_edges() == "":
		return
	if not _should_show_ability_badge_control(card, badge_ready, clickable):
		return
	var badge_right := _get_creature_ability_badge_right(card)
	var badge := Control.new()
	badge.name = "NimueBadge_%s" % mode
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	badge.z_index = 31
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = badge_right - CREATURE_ABILITY_BADGE_SIZE
	badge.offset_top = top
	badge.offset_right = badge_right
	badge.offset_bottom = top + CREATURE_ABILITY_BADGE_SIZE

	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.modulate = Color(1, 1, 1, 1) if badge_ready else Color(0.78, 0.82, 0.88, 0.88)
	badge.add_child(icon)

	if clickable and card_uid != "":
		_connect_badge_click_action(badge, "nimue", card_uid, mode)
	_connect_badge_hover(badge, hover_text)
	overlay.add_child(badge)

func _add_nimue_badges(overlay: Control, card: Card) -> void:
	if overlay == null or not (card is Nimue):
		return
	var nimue := card as Nimue
	var card_uid := BoardZoneUI.get_action_point_card_uid(card)
	var clickable := not _is_enemy and card.get_controller() == _get_viewer_player()
	var can_entomb := false
	var can_present := false
	if game_manager != null:
		can_entomb = nimue.can_activate_entomb(game_manager)
		can_present = nimue.can_activate_present(game_manager)
	var top_badge_top := _get_badge_row_top() + CREATURE_ABILITY_BADGE_TOP_OFFSET
	var lower_badge_top := top_badge_top + CREATURE_ABILITY_BADGE_SIZE + 4.0
	_add_nimue_mode_badge(
		overlay,
		card,
		card_uid,
		"entomb",
		NIMUE_ENTOMB_BADGE_TEXTURE,
		top_badge_top,
		can_entomb,
		_get_nimue_badge_hover_text("entomb"),
		clickable
	)
	_add_nimue_mode_badge(
		overlay,
		card,
		card_uid,
		"present",
		NIMUE_PRESENT_BADGE_TEXTURE,
		lower_badge_top,
		can_present,
		_get_nimue_badge_hover_text("present"),
		clickable
	)

func _add_white_serpent_medicine_badge(overlay: Control, card: Card) -> void:
	if overlay == null or not (card is TheWhiteSerpent):
		return
	var serpent := card as TheWhiteSerpent
	var viewer := _get_viewer_player()
	var can_view_stealth := not card.is_stealth or card.get_controller() == viewer or card.is_temporarily_revealed()
	if card.is_face_down or card.is_prepared or not can_view_stealth:
		return

	var clickable := not _is_enemy and card.get_controller() == viewer
	var badge_ready := clickable and (
		_is_card_usable_for_priority(card) if _is_priority_badge_filter_active() else (
			game_manager != null and serpent.can_activate_medicine(game_manager)
		)
	)
	if not _should_show_ability_badge_control(card, badge_ready, clickable):
		return

	var badge_right := _get_creature_ability_badge_right(card)
	var badge_top := _get_badge_row_top() + CREATURE_ABILITY_BADGE_TOP_OFFSET + CREATURE_ABILITY_BADGE_SIZE + 4.0
	var badge := Control.new()
	badge.name = "WhiteSerpentMedicineBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	badge.z_index = 31
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = badge_right - CREATURE_ABILITY_BADGE_SIZE
	badge.offset_top = badge_top
	badge.offset_right = badge_right
	badge.offset_bottom = badge_top + CREATURE_ABILITY_BADGE_SIZE

	var icon := TextureRect.new()
	icon.texture = WHITE_SERPENT_MEDICINE_BADGE_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.modulate = Color(1, 1, 1, 1) if badge_ready else Color(0.82, 0.82, 0.86, 0.9)
	badge.add_child(icon)

	if clickable:
		_connect_badge_click_action(
			badge,
			"creature_ability_option",
			BoardZoneUI.get_action_point_card_uid(card),
			"medicine"
		)
	_connect_badge_hover(
		badge,
		BaseCardScript.apply_keyword_hints(BaseCardScript.apply_action_cost_symbols(
			"Medicine ([b]Activate[/b], [b]Spd[/b] 2): Negate enemy effects targeting your cards until end of turn.",
			card
		))
	)
	overlay.add_child(badge)

func _add_creature_ability_badge(overlay: Control, card: Card) -> void:
	if overlay == null or card == null or card.card_type != Card.CardType.CREATURE or card.is_god:
		return
	var texture := _get_creature_ability_badge_texture(card)
	if texture == null:
		return
	var viewer := _get_viewer_player()
	var can_view_stealth := not card.is_stealth or card.get_controller() == viewer or card.is_temporarily_revealed()
	if card.is_face_down or card.is_prepared or not can_view_stealth:
		return

	var clickable := not _is_enemy and card.get_controller() == viewer
	var card_uid := BoardZoneUI.get_action_point_card_uid(card)
	var badge_ready = clickable and (
		_is_card_usable_for_priority(card) if _is_priority_badge_filter_active() else (
			game_manager != null
			and card.has_method("can_activate")
			and card.has_method("activate")
			and card.can_activate(game_manager)
		)
	)
	if not _should_show_ability_badge_control(card, badge_ready, clickable):
		return
	var hover_text := _get_creature_ability_badge_hover_text(card)
	var badge_right := _get_creature_ability_badge_right(card)
	var badge_top := _get_badge_row_top() + CREATURE_ABILITY_BADGE_TOP_OFFSET

	var badge := Control.new()
	badge.name = "CreatureAbilityBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_STOP if hover_text.strip_edges() != "" else Control.MOUSE_FILTER_IGNORE
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	badge.z_index = 31
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = badge_right - CREATURE_ABILITY_BADGE_SIZE
	badge.offset_top = badge_top
	badge.offset_right = badge_right
	badge.offset_bottom = badge_top + CREATURE_ABILITY_BADGE_SIZE

	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.modulate = Color(1, 1, 1, 1) if badge_ready else Color(0.82, 0.82, 0.86, 0.9)
	badge.add_child(icon)

	if clickable and card_uid != "":
		_connect_badge_click_action(badge, "creature_ability", card_uid)
	_connect_badge_hover(badge, hover_text)
	overlay.add_child(badge)

func _add_board_card_custom_ability_badge(overlay: Control, card: Card) -> void:
	if overlay == null or card == null:
		return
	if card.card_type != Card.CardType.STRUCTURE and card.card_type != Card.CardType.EQUIPMENT:
		return
	var texture := _get_board_card_custom_ability_badge_texture(card)
	if texture == null:
		return
	var viewer := _get_viewer_player()
	var can_view_stealth := not card.is_stealth or card.get_controller() == viewer or card.is_temporarily_revealed()
	if card.is_face_down or card.is_prepared or not can_view_stealth:
		return

	var clickable := not _is_enemy and card.get_controller() == viewer
	var card_uid := BoardZoneUI.get_action_point_card_uid(card)
	var badge_ready = clickable and (
		_is_card_usable_for_priority(card) if _is_priority_badge_filter_active() else _can_show_board_card_custom_ability_badge_as_ready(card)
	)
	if not _should_show_ability_badge_control(card, badge_ready, clickable):
		return
	var hover_text := _get_creature_ability_badge_hover_text(card)
	var badge_right := _get_creature_ability_badge_right(card)
	var badge_top := _get_badge_row_top() + CREATURE_ABILITY_BADGE_TOP_OFFSET

	var badge := Control.new()
	badge.name = "BoardCardCustomAbilityBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_STOP if hover_text.strip_edges() != "" else Control.MOUSE_FILTER_IGNORE
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	badge.z_index = 31
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = badge_right - CREATURE_ABILITY_BADGE_SIZE
	badge.offset_top = badge_top
	badge.offset_right = badge_right
	badge.offset_bottom = badge_top + CREATURE_ABILITY_BADGE_SIZE

	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.modulate = Color(1, 1, 1, 1) if badge_ready else Color(0.82, 0.82, 0.86, 0.9)
	badge.add_child(icon)

	if clickable and card_uid != "":
		_connect_badge_click_action(badge, "creature_ability", card_uid)
	_connect_badge_hover(badge, hover_text)
	overlay.add_child(badge)

func _add_god_custom_ability_badge(overlay: Control, card: Card) -> void:
	if overlay == null or card == null or not card.is_god:
		return
	var texture := _get_god_custom_ability_badge_texture(card)
	if texture == null:
		return
	var viewer := _get_viewer_player()
	var clickable := not _is_enemy and card.get_controller() == viewer
	var badge_ready = clickable and (
		_is_card_usable_for_priority(card) if _is_priority_badge_filter_active() else (
			game_manager != null
			and card.has_method("can_activate")
			and card.has_method("activate")
			and card.can_activate(game_manager)
		)
	)
	if card.card_name == "Guan Yu" and not _is_priority_badge_filter_active():
		badge_ready = clickable \
			and game_manager != null \
			and card.has_method("_can_use_tactical_break") \
			and bool(card.call("_can_use_tactical_break", game_manager))
	if not _should_show_ability_badge_control(card, badge_ready, clickable):
		return
	var hover_text := _get_creature_ability_badge_hover_text(card)

	var badge := Control.new()
	badge.name = "GodCustomAbilityBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_STOP if hover_text.strip_edges() != "" else Control.MOUSE_FILTER_IGNORE
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	badge.z_index = 31
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var badge_top := _get_badge_row_top() + 26.0 + GOD_ABILITY_BADGE_TOP_OFFSET
	if card.card_name == "Guan Yu":
		badge_top = _get_badge_row_top() + GOD_ABILITY_BADGE_TOP_OFFSET + ABILITY_BADGE_SIZE + 4.0
	badge.offset_left = -6.0 - ABILITY_BADGE_SIZE
	badge.offset_top = badge_top
	badge.offset_right = -6
	badge.offset_bottom = badge_top + ABILITY_BADGE_SIZE

	if badge_ready:
		_add_badge_image_glow(badge, texture, _get_god_ability_badge_glow_color(card), 6.0)

	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.modulate = Color(1, 1, 1, 1) if badge_ready else Color(0.82, 0.82, 0.86, 0.9)
	badge.add_child(icon)

	var card_uid := BoardZoneUI.get_action_point_card_uid(card)
	if clickable:
		_connect_badge_click_action(badge, "god_ability", card_uid)
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

func _connect_badge_hover(badge_control: Control, text: String, preview_card: Card = null) -> void:
	if badge_control == null:
		return
	badge_control.set_meta("hover_badge_text", text)
	if preview_card != null:
		badge_control.set_meta("hover_badge_preview_card", preview_card)
	badge_control.mouse_entered.connect(Callable(self, "_on_badge_mouse_entered"))
	badge_control.mouse_exited.connect(Callable(self, "_on_badge_mouse_exited"))

func _get_hover_summoned_active_god(card: Card) -> Card:
	if card == null:
		return null
	var active_gods := card.get_hover_summoned_active_gods(_get_viewer_player())
	return active_gods[0] if not active_gods.is_empty() else null

func _on_badge_mouse_entered() -> void:
	_badge_hovered = true
	_hovered = true
	_active_affordance_hover_owner_id = get_instance_id()
	_hide_ability_popup()
	var hovered_control := get_viewport().gui_get_hovered_control()
	var badge_control := hovered_control
	while badge_control != null and not badge_control.has_meta("hover_badge_text"):
		badge_control = badge_control.get_parent() as Control
	if badge_control == null:
		return
	var preview_card: Card = null
	if badge_control.has_meta("hover_badge_preview_card"):
		preview_card = badge_control.get_meta("hover_badge_preview_card") as Card
	_show_badge_hover_popup(badge_control, str(badge_control.get_meta("hover_badge_text", "")), preview_card)

func _on_badge_mouse_exited() -> void:
	_badge_hovered = false
	_hide_badge_hover_popup()
	_schedule_hover_exit_refresh()

func _is_mouse_over_owned_badge() -> bool:
	if get_viewport() == null:
		return false
	var hovered_control := get_viewport().gui_get_hovered_control()
	var control := hovered_control
	while control != null:
		if control == self:
			return hovered_control != null and _has_badge_hover_ancestor(hovered_control)
		control = control.get_parent() as Control
	return false

func _has_badge_hover_ancestor(control: Control) -> bool:
	var current := control
	while current != null:
		if current.has_meta("hover_badge_text"):
			return true
		if current == self:
			return false
		current = current.get_parent() as Control
	return false

func _is_mouse_in_affordance_hover_area() -> bool:
	if get_viewport() == null:
		return false
	if _active_affordance_hover_owner_id != get_instance_id():
		return false
	var hover_rect := get_global_rect().grow(ABILITY_BADGE_SIZE + 18.0)
	return hover_rect.has_point(get_global_mouse_position())

func _on_popup_mouse_exited() -> void:
	if not _pinned:
		_schedule_hide()

func _show_badge_hover_popup(anchor: Control, text: String, preview_card: Card = null) -> void:
	_hide_badge_hover_popup()
	if anchor == null or (text.strip_edges() == "" and preview_card == null) or not is_inside_tree() or is_queued_for_deletion():
		return
	var floating_parent := _get_floating_popup_parent()
	if floating_parent == null:
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

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(content)

	if text.strip_edges() != "":
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.scroll_active = false
		label.fit_content = true
		label.add_theme_font_size_override("normal_font_size", 14)
		label.add_theme_font_size_override("bold_font_size", 14)
		label.add_theme_color_override("default_color", Color(1.0, 0.95, 0.75))
		label.mouse_filter = Control.MOUSE_FILTER_STOP if text.contains("[hint=") else Control.MOUSE_FILTER_IGNORE
		if text.length() >= 80 or text.contains("\n"):
			label.custom_minimum_size = Vector2(240.0, 0.0)
		content.add_child(label)

	if preview_card != null:
		content.add_child(CardDetailContentBuilderScript.make_full_card_preview(
			preview_card,
			_get_viewer_player(),
			240.0,
			game_manager
		))

	_badge_hover_popup = popup_root
	floating_parent.add_child(popup_root)
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

	var aura := PriorityResponseAura.new()
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.z_index = 20
	aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_card_option_visual(aura)
	overlay.add_child(aura)

func _add_attack_aura(overlay: Control) -> void:
	if overlay == null:
		return

	var aura := AttackAura.new()
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.z_index = 20
	aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_card_option_visual(aura)
	overlay.add_child(aura)

func _add_followers_attack_target_tint(overlay: Control) -> void:
	if overlay == null:
		return

	var glow := ColorRect.new()
	glow.color = Color(0.92, 0.10, 0.08, 0.22)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_card_option_visual(glow)
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
	_fade_card_option_visual(ring)
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
	marker.z_index = 32
	marker.set_anchors_preset(Control.PRESET_CENTER)
	marker.offset_left = -11
	marker.offset_top = -11
	marker.offset_right = 11
	marker.offset_bottom = 11
	_fade_card_option_visual(marker)
	overlay.add_child(marker)

func _add_target_aura(overlay: Control) -> void:
	if overlay == null:
		return

	var aura := TargetAura.new()
	aura.z_index = 3
	aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_card_option_visual(aura)
	overlay.add_child(aura)

func _uses_res_attack_target_icon(card: Card) -> bool:
	if card == null:
		return false
	if card.card_type == Card.CardType.STRUCTURE:
		return true
	if card.card_type == Card.CardType.EQUIPMENT:
		return true
	if card.card_type == Card.CardType.CREATURE:
		return card.creature_mode == Card.CreatureMode.DEFENSIVE or card.is_petrified()
	return false

func _get_attack_target_texture(card: Card) -> Texture2D:
	if card == null:
		return null
	if card.card_type == Card.CardType.EQUIPMENT:
		return DESTROY_ATTACK_TARGET_TEXTURE
	return RES_ATTACK_TARGET_TEXTURE if _uses_res_attack_target_icon(card) else AGGRESSIVE_ATTACK_TARGET_TEXTURE

func _get_attack_target_hover_text(card: Card) -> String:
	if card == null:
		return ""
	if card.card_type == Card.CardType.EQUIPMENT:
		return "Destroy"
	return "Attack"

func _get_card_target_icon_entries(card: Card) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _is_card_attack_candidate(card):
		var texture := _get_attack_target_texture(card)
		if texture != null:
			var scene_root := _get_targeting_scene_root()
			var actor := _get_selected_attacker(scene_root)
			var action_name := "destroy equipment" if card.card_type == Card.CardType.EQUIPMENT else "attack"
			var action_cost_entries := _get_attack_action_cost_entries(actor) if action_name == "attack" else _make_action_cost_entries(Card.ACTION_COST_MAJOR)
			entries.append({
				"actor": actor,
				"texture": texture,
				"border_color": Color(1.0, 0.32, 0.18, 0.92),
				"hover_text": _get_attack_target_hover_text(card),
				"action": "",
				"action_cost_entries": action_cost_entries,
				"action_mana_cost": _get_creature_action_mana_cost(actor, action_name),
			})
	var equipment_action_entry := _get_equipment_target_action_icon_entry(card)
	if not equipment_action_entry.is_empty():
		entries.append(equipment_action_entry)
	return entries

func _add_attack_target_icon(overlay: Control, card: Card) -> void:
	if overlay == null:
		return
	var entries := _get_card_target_icon_entries(card)
	if entries.is_empty():
		return
	_add_centered_target_icon_group(overlay, entries, card)

func _get_equipment_target_action_icon_entry(card: Card) -> Dictionary:
	if card == null or card.card_type != Card.CardType.EQUIPMENT or card.equipped_on != null:
		return {}
	if game_manager == null:
		return {}
	var scene_root := _get_targeting_scene_root()
	if scene_root == null:
		return {}
	var actor := _get_selected_attacker(scene_root)
	if actor == null or actor == card:
		return {}
	var equipment_entry := _get_reachable_equipment_entry(scene_root, actor, card)
	if equipment_entry.is_empty():
		return {}
	var is_enemy := bool(equipment_entry.get("is_enemy", false))
	var action_cost_kind := Card.ACTION_COST_MAJOR if is_enemy else _get_minor_action_cost_kind_for_card(actor)
	var pick_up_label := str(equipment_entry.get("pick_up_label", "Pick Up"))
	var action_name := "pick up equipment"
	if not is_enemy and pick_up_label == "Mount":
		action_name = "mount"
	return {
		"actor": actor,
		"texture": STEAL_ATTACK_TARGET_TEXTURE,
		"border_color": Color(1.0, 0.74, 0.34, 0.95) if is_enemy else Color(0.44, 0.96, 0.58, 0.95),
		"hover_text": "Steal" if is_enemy else pick_up_label,
		"action": "steal" if is_enemy else "pick_up",
		"action_cost_entries": _make_action_cost_entries(action_cost_kind),
		"action_mana_cost": _get_creature_action_mana_cost(actor, action_name),
	}

func _add_followers_attack_target_icon(overlay: Control) -> void:
	if overlay == null or FOLLOWERS_ATTACK_TARGET_TEXTURE == null:
		return
	var scene_root := _get_targeting_scene_root()
	var actor := _get_selected_attacker(scene_root)
	var entries: Array[Dictionary] = [{
		"actor": actor,
		"texture": FOLLOWERS_ATTACK_TARGET_TEXTURE,
		"border_color": Color(1.0, 0.32, 0.18, 0.92),
		"hover_text": "Attack",
		"action": "",
		"action_cost_entries": _get_attack_action_cost_entries(actor),
		"action_mana_cost": _get_creature_action_mana_cost(actor, "attack"),
	}]
	_add_centered_target_icon_group(overlay, entries, null)

func _has_card_target_icon_candidate(card: Card) -> bool:
	return not _get_card_target_icon_entries(card).is_empty()

func _is_card_equipment_action_candidate(card: Card) -> bool:
	return not _get_equipment_target_action_icon_entry(card).is_empty()

func _get_reachable_equipment_entry(scene_root: Node, actor: Card, equipment: Card) -> Dictionary:
	if scene_root == null or actor == null or equipment == null or not scene_root.has_method("_get_reachable_equipment"):
		return {}
	var entries = scene_root.call("_get_reachable_equipment", actor)
	if not (entries is Array):
		return {}
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var dict: Dictionary = entry
		if dict.get("equipment", null) != equipment:
			continue
		if not bool(dict.get("allow_pick_up", true)):
			return {}
		if scene_root.has_method("_can_pick_up_equipment_entry"):
			var is_enemy := bool(dict.get("is_enemy", false))
			if not bool(scene_root.call("_can_pick_up_equipment_entry", actor, is_enemy)):
				return {}
		return dict
	return {}

func _should_show_steal_target_icon(card: Card) -> bool:
	var entry := _get_equipment_target_action_icon_entry(card)
	return not entry.is_empty() and str(entry.get("hover_text", "")) == "Steal"

func _has_steal_action_entry(scene_root: Node, actor: Card, equipment: Card) -> bool:
	var entry := _get_reachable_equipment_entry(scene_root, actor, equipment)
	return not entry.is_empty() and bool(entry.get("is_enemy", false))

func _get_minor_action_cost_kind_for_card(card: Card) -> String:
	if card == null:
		return Card.ACTION_COST_MINOR
	if card.has_method("get_effective_minor_action_cost_kind"):
		return str(card.call("get_effective_minor_action_cost_kind"))
	return Card.ACTION_COST_MINOR

func _get_creature_action_mana_cost(card: Card, action_name: String = "") -> int:
	if card == null or game_manager == null:
		return 0
	if not game_manager.has_method("get_creature_action_mana_cost"):
		return 0
	return maxi(0, int(game_manager.call("get_creature_action_mana_cost", card, action_name)))

func _make_action_cost_entries(action_cost_kind: String, amount: int = 1) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if action_cost_kind == Card.ACTION_COST_NONE or amount <= 0:
		return entries
	entries.append({
		"kind": action_cost_kind,
		"amount": amount,
	})
	return entries

func _get_attack_action_cost_entries(card: Card) -> Array[Dictionary]:
	var entries := _make_action_cost_entries(Card.ACTION_COST_MAJOR)
	if card == null:
		return entries
	var exhausts_minor := false
	if card.has_method("does_attack_exhaust_minor_creature_actions"):
		exhausts_minor = bool(card.call("does_attack_exhaust_minor_creature_actions"))
	if not exhausts_minor:
		return entries
	var minor_count := Card.DEFAULT_MINOR_CREATURE_ACTIONS_PER_TURN
	if card.has_method("get_max_minor_creature_actions_per_turn"):
		minor_count = maxi(0, int(card.call("get_max_minor_creature_actions_per_turn")))
	entries.append_array(_make_action_cost_entries(Card.ACTION_COST_MINOR, minor_count))
	return entries

func _get_action_cost_marker_texture(action_cost_kind: String) -> Texture2D:
	match action_cost_kind:
		Card.ACTION_COST_MINOR:
			return MINOR_ACTION_SYMBOL_TEXTURE
		Card.ACTION_COST_MAJOR:
			return MAJOR_ACTION_SYMBOL_TEXTURE
	return null

func _get_action_cost_entry_label(entry: Dictionary) -> String:
	var action_cost_kind := str(entry.get("kind", Card.ACTION_COST_NONE))
	var amount := maxi(0, int(entry.get("amount", 0)))
	match action_cost_kind:
		Card.ACTION_COST_MINOR:
			return "%d minor %s" % [amount, "action" if amount == 1 else "actions"]
		Card.ACTION_COST_MAJOR:
			return "%d major %s" % [amount, "action" if amount == 1 else "actions"]
	return ""

func _with_action_cost_hover_text(hover_text: String, action_cost_entries: Array[Dictionary], mana_cost: int = 0) -> String:
	var cost_parts: Array[String] = []
	for entry in action_cost_entries:
		var action_cost_label := _get_action_cost_entry_label(entry)
		if action_cost_label != "":
			cost_parts.append(action_cost_label)
	if mana_cost > 0:
		cost_parts.append("%d mana" % mana_cost)
	if cost_parts.is_empty():
		return hover_text
	return hover_text + "\nCost: " + ", ".join(cost_parts)

func _get_action_cost_marker_size(action_cost_entries: Array[Dictionary], mana_cost: int = 0) -> Vector2:
	var cost_pair_count := action_cost_entries.size() + (1 if mana_cost > 0 else 0)
	var width := ACTION_COST_MARKER_ACTION_WIDTH + maxf(0.0, float(cost_pair_count - 1) * 24.0)
	return Vector2(width, ACTION_COST_MARKER_HEIGHT)

func _add_cost_amount_icon(row: HBoxContainer, amount_text: String, texture: Texture2D) -> void:
	if row == null or texture == null:
		return
	var amount := Label.new()
	amount.text = amount_text
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override("font_size", 11)
	amount.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78))
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(amount)

	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(13.0, 13.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

func _add_action_cost_marker(parent: Control, action_cost_entries: Array[Dictionary], mana_cost: int = 0, actor: Card = null) -> void:
	if parent == null or action_cost_entries.is_empty():
		return
	var marker_size := _get_action_cost_marker_size(action_cost_entries, mana_cost)
	var marker := PanelContainer.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = 4
	marker.custom_minimum_size = marker_size
	marker.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	marker.offset_left = -marker_size.x - 3.0
	marker.offset_top = -marker_size.y - 3.0
	marker.offset_right = -3.0
	marker.offset_bottom = -3.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.03, 0.88)
	style.border_color = Color(1.0, 0.93, 0.62, 0.96)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	marker.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	marker.add_child(row)

	for entry in action_cost_entries:
		var action_cost_kind := str(entry.get("kind", Card.ACTION_COST_NONE))
		var texture := _get_action_cost_marker_texture(action_cost_kind)
		var amount := maxi(0, int(entry.get("amount", 0)))
		if texture == null or amount <= 0:
			continue
		_add_cost_amount_icon(row, str(amount), texture)
	if mana_cost > 0:
		_add_cost_amount_icon(row, str(mana_cost), MANA_ORB_TEXTURE)

	parent.add_child(marker)
	BoardZoneUI.register_action_cost_marker(marker, actor, action_cost_entries)

func _add_centered_target_icon_group(overlay: Control, entries: Array[Dictionary], card: Card = null) -> void:
	if overlay == null or entries.is_empty():
		return
	var icon_size := minf(ATTACK_TARGET_ICON_SIZE, maxf(56.0, minf(size.x, size.y) * 0.48))
	var badge_size := icon_size + TARGET_ICON_PAD * 2.0
	var group_width := badge_size * entries.size() + TARGET_ICON_GROUP_GAP * maxi(0, entries.size() - 1)

	var group := Control.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.z_index = 32
	group.set_anchors_preset(Control.PRESET_CENTER)
	group.offset_left = -group_width * 0.5
	group.offset_top = -badge_size * 0.5
	group.offset_right = group_width * 0.5
	group.offset_bottom = badge_size * 0.5
	_fade_card_option_visual(group)
	overlay.add_child(group)

	var left := 0.0
	for entry in entries:
		var entry_texture := entry.get("texture", null) as Texture2D
		if entry_texture == null:
			continue
		var border_color: Color = entry.get("border_color", Color(1.0, 0.85, 0.4, 0.92))
		var hover_text := str(entry.get("hover_text", ""))
		var action := str(entry.get("action", ""))
		var action_cost_entries: Array[Dictionary] = []
		var raw_action_cost_entries = entry.get("action_cost_entries", [])
		if raw_action_cost_entries is Array:
			for raw_entry in raw_action_cost_entries:
				if raw_entry is Dictionary:
					action_cost_entries.append(raw_entry as Dictionary)
		if action_cost_entries.is_empty():
			action_cost_entries = _make_action_cost_entries(str(entry.get("action_cost_kind", Card.ACTION_COST_NONE)))
		var action_mana_cost := maxi(0, int(entry.get("action_mana_cost", 0)))
		var actor := entry.get("actor", null) as Card
		var badge := _make_target_icon_badge(
			entry_texture,
			border_color,
			icon_size,
			badge_size,
			hover_text,
			action,
			card,
			actor,
			action_cost_entries,
			action_mana_cost
		)
		badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		badge.offset_left = left
		badge.offset_top = 0.0
		badge.offset_right = left + badge_size
		badge.offset_bottom = badge_size
		group.add_child(badge)
		left += badge_size + TARGET_ICON_GROUP_GAP

func _make_target_icon_badge(
	texture: Texture2D,
	border_color: Color,
	icon_size: float,
	badge_size: float,
	hover_text: String = "",
	action: String = "",
	target_card: Card = null,
	actor: Card = null,
	action_cost_entries: Array[Dictionary] = [],
	action_mana_cost: int = 0
) -> Control:
	var badge := Control.new()
	var preview_only := _is_hover_card_options_preview_active()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE if preview_only else (Control.MOUSE_FILTER_STOP if action.strip_edges() != "" else (Control.MOUSE_FILTER_PASS if hover_text.strip_edges() != "" else Control.MOUSE_FILTER_IGNORE))
	badge.custom_minimum_size = Vector2(badge_size, badge_size)

	var background := Panel.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.03, 0.66)
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	background.add_theme_stylebox_override("panel", style)
	badge.add_child(background)

	var icon := TextureRect.new()
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = TARGET_ICON_PAD
	icon.offset_top = TARGET_ICON_PAD
	icon.offset_right = -TARGET_ICON_PAD
	icon.offset_bottom = -TARGET_ICON_PAD
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	badge.add_child(icon)
	_add_action_cost_marker(badge, action_cost_entries, action_mana_cost, actor)
	if hover_text.strip_edges() != "" and not preview_only:
		_connect_badge_hover(badge, _with_action_cost_hover_text(hover_text, action_cost_entries, action_mana_cost))
	var target_card_uid := BoardZoneUI.get_action_point_card_uid(target_card)
	if action.strip_edges() != "" and target_card != null and not preview_only:
		_connect_badge_click_action(badge, "equipment_target", target_card_uid, action)

	return badge

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

	var badge_top := _get_left_affordance_row_top(card)
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
	var badge_top := _get_secondary_left_affordance_row_top(card)
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

	var badge_top := 32.0 if _is_card_targeted_on_stack(card) else _get_badge_row_top()
	var badge_right := -6.0
	for entry in entries:
		var preview := _make_debuff_source_preview(entry)
		if preview == null:
			continue
		var badge := DebuffBadgeScript.create(preview, int(entry.get("count", 1)))
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = badge_right - DEBUFF_BADGE_SIZE
		badge.offset_top = badge_top
		badge.offset_right = badge_right
		badge.offset_bottom = badge_top + DEBUFF_BADGE_SIZE
		overlay.add_child(badge)

		badge_right -= DEBUFF_BADGE_SIZE + DEBUFF_AFFORDANCE_GAP

func _add_boon_affordances(overlay: Control, card: Card) -> void:
	if overlay == null or card == null or card.card_type != Card.CardType.CREATURE or card.is_god:
		return
	var entries := _get_boon_affordance_entries(card)
	if entries.is_empty():
		return

	var badge_top := _get_secondary_left_affordance_row_top(card)
	var badge_left := 6.0
	for entry in entries:
		var preview := _make_debuff_source_preview(entry)
		if preview == null:
			var label := Label.new()
			label.text = str(entry.get("label", "?"))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 9)
			label.add_theme_color_override("font_color", Color(0.95, 1.0, 0.82))
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			preview = label

		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		badge.tooltip_text = str(entry.get("tooltip", "Good Fortune"))
		badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		badge.offset_left = badge_left
		badge.offset_top = badge_top
		badge.offset_right = badge_left + DEBUFF_BADGE_SIZE
		badge.offset_bottom = badge_top + DEBUFF_BADGE_SIZE

		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0.04, 0.18, 0.13, 0.95)
		badge_style.border_color = Color(0.55, 1.0, 0.76, 0.98)
		badge_style.shadow_color = Color(0.0, 0.16, 0.08, 0.52)
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

		badge_left += DEBUFF_BADGE_SIZE + DEBUFF_AFFORDANCE_GAP

func _get_boon_affordance_entries(card: Card) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if card == null:
		return entries
	var seen: Dictionary = {}
	for status in card.active_statuses:
		if str(status.get("name", "")) != THIRD_SAGE_GOOD_FORTUNE_STATUS:
			continue
		var source_key := _get_debuff_source_key(status)
		var key := "good_fortune:%s" % source_key
		var ward_kind := str(status.get("ward_kind", "")).strip_edges()
		if seen.has(key):
			var index := int(seen[key])
			var merged := entries[index]
			var ward_kinds: Array = merged.get("ward_kinds", [])
			if ward_kind != "" and ward_kind not in ward_kinds:
				ward_kinds.append(ward_kind)
			merged["ward_kinds"] = ward_kinds
			merged["tooltip"] = _get_good_fortune_tooltip(status, ward_kinds)
			entries[index] = merged
			continue

		var initial_ward_kinds: Array = []
		if ward_kind != "":
			initial_ward_kinds.append(ward_kind)
		var entry := {
			"key": key,
			"source_card": status.get("source_card", null),
			"source": status.get("source", "Good Fortune"),
			"label": "GF",
			"ward_kinds": initial_ward_kinds,
			"tooltip": _get_good_fortune_tooltip(status, initial_ward_kinds),
		}
		seen[key] = entries.size()
		entries.append(entry)
	return entries

func _get_good_fortune_tooltip(status: Dictionary, ward_kinds: Array) -> String:
	var source := str(status.get("source", "Good Fortune"))
	var readable_kinds: Array[String] = []
	for ward_kind in ward_kinds:
		var readable := str(ward_kind).replace("_", " ").capitalize()
		if readable != "":
			readable_kinds.append(readable)
	if readable_kinds.is_empty():
		return "Good Fortune from " + source
	return "Good Fortune vs " + " and ".join(readable_kinds) + " from " + source

func _get_debuff_affordance_entries(card: Card) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if card == null:
		return entries

	var seen: Dictionary = {}
	for status in card._get_effective_statuses():
		_append_debuff_affordance_entry(entries, seen, _build_debuff_entry_from_status(card, status))
	for buff in card._get_effective_buffs():
		_append_debuff_affordance_entry(entries, seen, _build_debuff_entry_from_buff(buff))
	for binding in _get_attached_permanent_hexes(card):
		_append_debuff_affordance_entry(entries, seen, _build_debuff_entry_from_binding(binding))
	return entries

func _is_card_soft_selected(card: Card) -> bool:
	if card == null:
		return false
	var scene_root := _get_targeting_scene_root()
	if scene_root == null:
		return false
	var selected = scene_root.get("selected_card")
	return selected is Card and selected == card

func _get_explicit_selected_attacker(scene_root: Node) -> Card:
	if scene_root == null:
		return null
	var targeting_match_manager := _get_targeting_match_manager(scene_root)
	if targeting_match_manager != null and targeting_match_manager.selected_attacker is Card:
		return targeting_match_manager.selected_attacker as Card
	var attacker = scene_root.get("selected_attacker")
	if attacker is Card:
		return attacker as Card
	return null

func _is_card_click_selected(card: Card) -> bool:
	if card == null:
		return false
	if _is_card_soft_selected(card):
		return true
	var scene_root := _get_targeting_scene_root()
	if scene_root == null:
		return false
	if _get_explicit_selected_attacker(scene_root) == card:
		return true
	var indicated_move_card = scene_root.get("_indicated_move_card")
	return indicated_move_card is Card and indicated_move_card == card

func _should_show_creature_action_symbols(card: Card) -> bool:
	if card == null:
		return false
	if _hovered or _pinned:
		return true
	if _is_card_selected_attacker(card) or _is_card_selected_interceptor(card):
		return true
	if _is_card_pending_selection_source(card) or _is_card_pending_target(card) or _is_card_pending_attack_target(card):
		return true
	if _is_card_soft_selected(card):
		return true
	return _get_hover_card_options_card() == card

func _should_show_stance_switch_symbol(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	if _is_enemy:
		return false
	if card.card_type != Card.CardType.CREATURE or card.is_god:
		return false
	if card.is_face_down or card.is_prepared or card.is_stealth:
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	if card.get_controller() != game_manager.current_player:
		return false
	if not card.can_take_minor_creature_action() or card.is_sleeping:
		return false
	return _is_card_click_selected(card)

func _get_stance_switch_hover_text(card: Card, target_mode: Card.CreatureMode) -> String:
	if card == null:
		return ""
	var target_label := "aggressive" if target_mode == Card.CreatureMode.AGGRESSIVE else "defensive"
	var lines := [
		"Switch Stance",
		"Click to switch %s to %s stance." % [card.card_name, target_label],
	]
	return "\n".join(lines)

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

func _get_power_lock_texture(card: Card, culture_is_known: bool = true) -> Texture2D:
	if card != null:
		if not culture_is_known:
			return POWER_LOCK_TEXTURE
		if str(card.culture).strip_edges() == "Ancient" or card.has_type("Ancient Power"):
			return ANCIENT_POWER_LOCK_TEXTURE
		if str(card.culture).strip_edges() == "Norse":
			return NORSE_POWER_LOCK_TEXTURE
	return POWER_LOCK_TEXTURE

func _add_power_lock_texture_overlay(overlay: Control, card: Card = null, culture_is_known: bool = true) -> void:
	var power_lock_texture := _get_power_lock_texture(card, culture_is_known)
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
	brood_art.brood_card_clicked.connect(_on_tiamat_brood_card_clicked)
	overlay.add_child(brood_art)

	if not _is_tiamat_power_creature_stack_revealed():
		var viewer := _get_viewer_player()
		var slot_card := zone.cards[0]
		var culture_is_known := viewer != null and slot_card != null and slot_card.get_controller() == viewer
		_add_power_lock_texture_overlay(overlay, slot_card, culture_is_known)

func _on_tiamat_brood_card_clicked(slot_card: Card) -> void:
	card_clicked.emit(slot_card)

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

func _build_debuff_entry_from_binding(binding: Card) -> Dictionary:
	if not (binding is PermanentHexCard):
		return {}
	return {
		"key": "binding:%s" % _get_debuff_source_key({
			"source_card": binding,
			"source": binding.card_name,
		}),
		"source_card": binding,
		"count": 1,
	}

func _is_debuff_status_from_attached_binding(card: Card, status: Dictionary) -> bool:
	if card == null or status.is_empty():
		return false
	var source_card = status.get("source_card", null)
	return source_card is PermanentHexCard and (source_card as PermanentHexCard).attached_target == card

func _build_debuff_entry_from_status(card: Card, status: Dictionary) -> Dictionary:
	if card == null or status.is_empty():
		return {}
	var status_name := str(status.get("name", ""))
	if status_name in ["", "sleep", "temporarily_revealed", "blessed_ward", Card.EXTERNAL_EFFECT_NEGATION_STATUS]:
		return {}
	if _is_debuff_status_from_attached_binding(card, status):
		return {}
	var source_key := _get_debuff_source_key(status)
	var source_card := status.get("source_card", null) as Card
	if status_name == "malinalxochitl_poison" or status_name.contains("poison"):
		return {
			"key": "source:%s" % source_key,
			"source_card": source_card,
			"count": 1,
		}
	if status_name in ["cannot_attack", "cannot_intercept", "cannot_move", "activation_locked", Card.ABILITY_NEGATED_STATUS]:
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

func _get_hover_card_options_card(scene_root: Node = null) -> Card:
	var root := scene_root if scene_root != null else _get_targeting_scene_root()
	if root == null or not root.has_method("_get_hover_card_options_card"):
		return null
	var preview = root.call("_get_hover_card_options_card")
	if preview is Card:
		return preview as Card
	return null

func _get_hover_card_options_attacker(scene_root: Node = null) -> Card:
	var root := scene_root if scene_root != null else _get_targeting_scene_root()
	if root == null:
		return null
	if root.has_method("_get_hover_card_options_attacker"):
		var preview_attacker = root.call("_get_hover_card_options_attacker")
		if preview_attacker is Card:
			return preview_attacker as Card
		return null
	return _get_hover_card_options_card(root)

func _is_hover_card_options_preview_active() -> bool:
	var scene_root := _get_targeting_scene_root()
	if scene_root == null or not scene_root.has_method("_is_hover_card_options_preview_active"):
		return false
	return bool(scene_root.call("_is_hover_card_options_preview_active"))

func _get_card_option_visual_alpha() -> float:
	return HOVER_CARD_OPTIONS_ALPHA if _is_hover_card_options_preview_active() else 1.0

func _fade_card_option_visual(control: CanvasItem) -> void:
	if control == null:
		return
	var alpha := _get_card_option_visual_alpha()
	if alpha >= 0.99:
		return
	var current := control.modulate
	current.a *= alpha
	control.modulate = current

func _notify_hover_card_options_changed(card: Card) -> void:
	var scene_root := _get_targeting_scene_root()
	if scene_root == null or not scene_root.has_method("_set_hover_card_options_card"):
		return
	scene_root.call("_set_hover_card_options_card", card)

func _get_floating_popup_parent() -> Node:
	if not is_inside_tree() or is_queued_for_deletion():
		return null
	var node: Node = self
	while node != null:
		if node is CanvasLayer:
			return node
		if node.is_in_group("combat_mock_game"):
			return node
		node = node.get_parent()
	var tree := get_tree()
	if tree == null:
		return null
	for candidate in tree.get_nodes_in_group("combat_mock_game"):
		if candidate is Node and is_instance_valid(candidate):
			return candidate as Node
	var viewport := get_viewport()
	if viewport != null:
		return viewport
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
		var pyre_source = scene_root.get("pyre_source")
		if pyre_source != null and pyre_source.has_method("is_valid_card_selection_target"):
			return pyre_source.is_valid_card_selection_target(card, game_manager)
		return pyre_source != null \
			and pyre_source.has_method("is_valid_activation_target") \
			and pyre_source.is_valid_activation_target(card)

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
	var hover_options_card := _get_hover_card_options_attacker(scene_root)
	if hover_options_card != null:
		return hover_options_card
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

func _is_attack_target_card_type(card: Card) -> bool:
	if card == null:
		return false
	if card.card_type == Card.CardType.CREATURE or card.card_type == Card.CardType.STRUCTURE:
		return true
	return card.card_type == Card.CardType.EQUIPMENT and card.equipped_on == null

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
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	return _is_attack_target_card_type(card) \
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
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	if not (card.is_face_down or card.is_stealth or card.is_prepared):
		return false
	var viewer := _get_viewer_player()
	return card.get_controller() != viewer and not card.is_revealed_to_all()

func _is_card_usable_for_priority(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	if _is_hidden_board_card_for_priority_visuals(card):
		return false
	return game_manager.can_card_respond_to_priority(card, game_manager.priority_player)

func _should_show_playing_aura(card: Card) -> bool:
	return _preview_card != null or _is_card_waiting_on_priority(card) or _is_card_pending_selection_source(card)

func _get_god_culture_glow_color(card: Card) -> Color:
	if card == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	match card.culture:
		"Triskelion":
			return Color(0.25, 0.56, 1.0, 0.95)
		"Norse":
			return PRIORITY_RESPONSE_GLOW_COLOR
		"Ancient":
			return Color(0.02, 0.02, 0.02, 0.95)
		"Tian":
			return Color(1.0, 0.88, 0.24, 0.95)
		"Nahutl", "Nahuatl":
			return Color(0.94, 0.24, 0.18, 0.95)
		"Olympic":
			return Color(0.66, 0.34, 0.98, 0.95)
	return Color(0.0, 0.0, 0.0, 0.0)

func _get_god_ability_badge_glow_color(card: Card) -> Color:
	if card is AphroditeAreia:
		return Color(1.0, 0.45, 0.74, 0.58)
	if card != null and card.card_name in ["Nusku, Firebearer", "Nusku, Active God"]:
		return Color(1.0, 0.18, 0.12, 0.62)
	var glow_color := _get_god_culture_glow_color(card)
	if glow_color.a <= 0.0:
		return glow_color
	glow_color.a = 0.52
	return glow_color

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

func _is_viewer_priority_player() -> bool:
	if game_manager == null or game_manager.action_stack.is_empty():
		return false
	return game_manager.priority_player != null and game_manager.priority_player == _get_viewer_player()

func _is_priority_badge_filter_active() -> bool:
	return game_manager != null and (game_manager.priority_player != null or not game_manager.action_stack.is_empty())

func _should_show_ability_badge_control(card: Card, badge_ready: bool = false, clickable: bool = false) -> bool:
	if BoardZoneUI.get_always_show_ability_badges():
		return true
	if _is_priority_badge_filter_active():
		return clickable and badge_ready and _is_card_usable_for_priority(card)
	if _hovered or _badge_hovered or _is_mouse_in_affordance_hover_area():
		return true
	if _is_card_click_selected(card):
		return true
	return clickable and badge_ready and _is_viewer_priority_player()

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

static func _load_png_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("BoardZoneUI: failed to load board texture %s" % path)
		return null
	return texture

static func _get_board_zone_slab_textures() -> Array[Texture2D]:
	if _board_zone_slab_textures.is_empty():
		for texture_path in BOARD_ZONE_SLAB_TEXTURE_PATHS:
			var texture := _load_png_texture(texture_path)
			if texture != null:
				_board_zone_slab_textures.append(texture)
	return _board_zone_slab_textures

static func _get_board_zone_slot_texture_indices() -> Array[int]:
	var slab_textures := _get_board_zone_slab_textures()
	if slab_textures.is_empty():
		return []
	if _board_zone_slot_texture_indices.size() != slab_textures.size():
		_board_zone_slot_texture_indices.clear()
		for texture_index in range(slab_textures.size()):
			_board_zone_slot_texture_indices.append(texture_index)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for index in range(_board_zone_slot_texture_indices.size() - 1, 0, -1):
			var swap_index := rng.randi_range(0, index)
			var current_value := _board_zone_slot_texture_indices[index]
			_board_zone_slot_texture_indices[index] = _board_zone_slot_texture_indices[swap_index]
			_board_zone_slot_texture_indices[swap_index] = current_value
	return _board_zone_slot_texture_indices

func _get_board_zone_slab_texture() -> Texture2D:
	var slab_textures := _get_board_zone_slab_textures()
	if slab_textures.is_empty():
		return null

	if zone != null and zone.zone_type in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE]:
		var slot_texture_indices := _get_board_zone_slot_texture_indices()
		var board_slot_index := zone_index
		if zone.zone_index >= 0:
			board_slot_index = zone.zone_index
		if zone.zone_type == Zone.ZoneType.RESERVE:
			board_slot_index += BOARD_ZONE_ROW_TILE_COUNT
		var texture_index := slot_texture_indices[posmod(board_slot_index, slot_texture_indices.size())]
		return slab_textures[texture_index]

	var variant_seed := zone_index
	if zone != null:
		variant_seed += int(zone.zone_type) * 13
	if _is_enemy:
		variant_seed += 7
	return slab_textures[posmod(variant_seed, slab_textures.size())]

func _get_empty_zone_slab_tint() -> Color:
	if zone == null:
		return Color(1.0, 1.0, 1.0, 0.9)
	if zone.zone_type == Zone.ZoneType.GOD_SLOT:
		return Color(1.08, 0.98, 0.72, 0.96)
	if zone.zone_type == Zone.ZoneType.POWER_SLOT:
		return Color(1.02, 0.98, 0.88, 0.9)
	return Color(1.0, 1.0, 1.0, 0.88)

func _add_empty_zone_slab_label(parent: Control) -> void:
	if not _should_show_empty_zone_label():
		return
	var lbl := Label.new()
	lbl.text = _row_label if _row_label != "" else str(zone_index + 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.custom_minimum_size = get_zone_size()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.96, 1.0, 0.85, 0.98))
	lbl.add_theme_color_override("font_shadow_color", Color(0.03, 0.045, 0.025, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)

func _should_show_empty_zone_label() -> bool:
	if not _hovered:
		return false
	if zone == null or not zone.cards.is_empty():
		return false
	return true

func _add_empty_zone_slab() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.custom_minimum_size = get_zone_size()
	overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var slab := TextureRect.new()
	slab.texture = _get_board_zone_slab_texture()
	slab.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slab.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slab.modulate = _get_empty_zone_slab_tint()
	slab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(slab)

	_add_empty_zone_slab_label(overlay)

func _refresh_mouse_cursor_shape(card: Card = null) -> void:
	if card != null and card.card_type == Card.CardType.POWER and card.is_face_down:
		mouse_default_cursor_shape = LockedPowerCursorScript.get_control_cursor_shape(Control.CURSOR_ARROW as Control.CursorShape)
		return
	if _is_hover_card_options_preview_active():
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	if card != null and (_has_card_target_icon_candidate(card) or _is_god_attack_candidate(card)):
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		return
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func set_move_indicator_path(source_center: Vector2, target_center: Vector2) -> void:
	var direction := target_center - source_center
	if direction == Vector2.ZERO:
		clear_move_indicator()
		return
	if _move_indicator_active \
			and _move_indicator_source_center.is_equal_approx(source_center) \
			and _move_indicator_target_center.is_equal_approx(target_center):
		return
	_move_indicator_active = true
	_move_indicator_direction = direction.normalized()
	_move_indicator_source_center = source_center
	_move_indicator_target_center = target_center
	_refresh_display()

func clear_move_indicator() -> void:
	if not _move_indicator_active and _move_indicator_direction == Vector2.ZERO:
		return
	_move_indicator_active = false
	_move_indicator_direction = Vector2.ZERO
	_move_indicator_source_center = Vector2.ZERO
	_move_indicator_target_center = Vector2.ZERO
	_refresh_display()

func _add_move_indicator_overlay() -> void:
	if not _move_indicator_active or _move_indicator_direction == Vector2.ZERO:
		return
	if zone == null or not zone.cards.is_empty():
		return

	var path_length := _move_indicator_source_center.distance_to(_move_indicator_target_center)
	if path_length <= 0.0:
		return
	var path_midpoint := (_move_indicator_source_center + _move_indicator_target_center) * 0.5
	var local_midpoint := path_midpoint - global_position
	var is_straight := absf(_move_indicator_direction.x) <= 0.01 or absf(_move_indicator_direction.y) <= 0.01
	var indicator_size := Vector2.ZERO
	var base_direction := Vector2.UP
	if is_straight:
		var indicator_width := minf(MOVE_INDICATOR_WIDTH, maxf(64.0, path_length * 0.62))
		indicator_size = Vector2(indicator_width, path_length)
	else:
		var diagonal_side := path_length / sqrt(2.0)
		indicator_size = Vector2(diagonal_side, diagonal_side)
		base_direction = Vector2(1.0, -1.0).normalized()

	var path_overlay := Control.new()
	path_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	path_overlay.clip_contents = false
	path_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(path_overlay)

	var indicator := TextureRect.new()
	indicator.texture = MOVE_STRAIGHT_INDICATOR_TEXTURE if is_straight else MOVE_DIAGONAL_INDICATOR_TEXTURE
	if indicator.texture == null:
		return
	indicator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	indicator.stretch_mode = TextureRect.STRETCH_SCALE
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.position = local_midpoint - indicator_size * 0.5
	indicator.size = indicator_size
	indicator.pivot_offset = indicator_size * 0.5
	indicator.rotation = base_direction.angle_to(_move_indicator_direction)
	indicator.modulate = Color(1.0, 1.0, 1.0, 0.98)
	path_overlay.add_child(indicator)

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
			and (card.get_controller() == face_down_viewer or card.is_revealed_to_all())
		var is_stack_magical_preview := game_manager != null \
			and card.is_magical_card() \
			and game_manager._has_pending_stack_action_for_card(card)

		# Face-down cards: own stealth creatures that are visible to the viewer use the normal
		# renderer below so they keep their full stats and defensive shield placement.
		# Played magical cards on the stack should also render with their art instead of
		# briefly inheriting hidden board-card visuals from their source state.
		if card.is_face_down and not can_render_stealth_creature_normally and not is_stack_magical_preview:
			add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			var fd_overlay := Control.new()
			fd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fd_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(fd_overlay)
			var revealed_face_down_card := (card is PowerCard and (card as PowerCard).is_publicly_revealed) or card.is_revealed_to_all()
			var is_own_hidden_card := card.get_controller() == face_down_viewer and (
				card.is_stealth
				or card.is_power
				or card.is_prepared
			)
			var show_revealed_card_art := revealed_face_down_card and card.art_path != ""
			var tex: Texture2D = null
			if show_revealed_card_art or (is_own_hidden_card and card.art_path != ""):
				tex = load(card.art_path)
			else:
				tex = load("res://images/cardbackAI.png")
			if tex:
				var art := TextureRect.new()
				art.texture = tex
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fd_overlay.add_child(art)
			if show_revealed_card_art:
				var revealed_haze := ColorRect.new()
				var is_own_revealed_card := card.get_controller() == face_down_viewer
				revealed_haze.color = Color(0.22, 0.45, 0.85, 0.26) if is_own_revealed_card else Color(0.85, 0.22, 0.45, 0.28)
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
			if _is_card_usable_for_priority(card):
				_add_priority_response_aura(fd_overlay)
			var is_face_down_attack_candidate := _is_card_attack_candidate(card)
			var is_face_down_target_icon_candidate := _has_card_target_icon_candidate(card)
			if _is_card_targeted_on_stack(card) or _is_card_pending_target(card) or _is_card_pending_attack_target(card) or is_face_down_target_icon_candidate:
				if is_face_down_attack_candidate or _is_card_targeted_on_stack(card) or _is_card_pending_target(card) or _is_card_pending_attack_target(card):
					_add_target_aura(fd_overlay)
				if is_face_down_target_icon_candidate:
					_add_attack_target_icon(fd_overlay, card)
				else:
					_add_stack_target_indicator(fd_overlay)
			var _fd_is_def := card.card_type == Card.CardType.CREATURE and (
				card.creature_mode == Card.CreatureMode.DEFENSIVE
				or card.is_stealth
			)
			if _fd_is_def:
				var shield_scale := DefenseShieldOverlayScript.STEALTH_VIEW_SIZE_MULTIPLIER if card.is_stealth else 1.0
				DefenseShieldOverlayScript.ensure_on(fd_overlay, DefenseShieldOverlayScript.LAYOUT_CENTER, shield_scale)
			_defense_overlay = fd_overlay if _fd_is_def else null
			_raised_overlay  = fd_overlay if (_fd_is_def or card.is_stealth) else null
			z_index = _get_resting_z_index()
			return

		# God slot: show art image filling the zone
		if zone.zone_type == Zone.ZoneType.GOD_SLOT and card.art_path != "":
			var show_champions_call_badge := _should_show_champions_call_badge(card)
			var glow_champions_call_badge := _should_glow_champions_call_badge(card)
			var show_god_attack_aura := _is_card_attacking_on_stack(card) or _is_card_intercepting_on_stack(card) or _is_card_selected_attacker(card) or _is_card_selected_interceptor(card)
			var show_god_playing_aura := _should_show_playing_aura(card)
			var show_god_priority_aura := _is_card_usable_for_priority(card)
			var show_god_target_aura := _is_card_targeted_on_stack(card) \
				or _is_card_pending_target(card) \
				or _is_card_pending_attack_target(card) \
				or _is_god_targeted_by_followers_attack(card) \
				or _is_god_pending_followers_attack(card)
			var show_god_followers_target_icon := _is_god_targeted_by_followers_attack(card) \
				or _is_god_pending_followers_attack(card) \
				or _is_god_attack_candidate(card)

			style.bg_color     = Color(0.35, 0.28, 0.04, 0.9)
			style.border_color = Color(0.9, 0.75, 0.2)
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				style.set_border_width(side, 2)
			if show_god_priority_aura:
				_apply_priority_response_style(style)
			add_theme_stylebox_override("panel", style)
			z_index = GOD_INDICATOR_Z_INDEX if (
				show_god_attack_aura
				or show_god_playing_aura
				or show_god_priority_aura
				or show_god_target_aura
				or show_god_followers_target_icon
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
				if show_god_followers_target_icon:
					_add_followers_attack_target_icon(god_overlay)

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
				if _is_tez_tonal_mastery_card(card):
					_add_tez_tonal_mastery_badge(god_overlay, card)
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
					counter_badge.offset_top = _get_badge_row_top()
					counter_badge.offset_bottom = _get_badge_row_top() + 22.0
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
				_add_god_custom_ability_badge(god_overlay, card)

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
				_add_creature_action_symbols(god_overlay, card)
				_add_stance_switch_symbol(god_overlay, card)
				_add_followers_attack_result_label(god_overlay)
			return

		var is_def_creature := card.card_type == Card.CardType.CREATURE and card.creature_mode == Card.CreatureMode.DEFENSIVE
		var shows_defense_shield := card.card_type == Card.CardType.CREATURE and (is_def_creature or card.is_stealth)
		var shows_aggressive_sword := card.card_type == Card.CardType.CREATURE and card.creature_mode == Card.CreatureMode.AGGRESSIVE and not card.is_stealth
		var show_card_priority_aura := _is_card_usable_for_priority(card)
		match card.card_type:
			Card.CardType.CREATURE:
				style.bg_color    = Color(0.13, 0.22, 0.42)
				style.border_color = Color(0.4, 0.65, 1.0)
			Card.CardType.STRUCTURE:
				style.bg_color    = Color(0.28, 0.18, 0.08)
				style.border_color = Color(0.75, 0.55, 0.3)
			_:
				style.bg_color    = Color(0.18, 0.18, 0.18)
				style.border_color = Color(0.5, 0.5, 0.5)
		if show_card_priority_aura:
			_apply_priority_response_style(style)
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
		var is_attack_candidate := _is_card_attack_candidate(card)
		var is_target_icon_candidate := _has_card_target_icon_candidate(card)
		if _is_card_targeted_on_stack(card) or _is_card_pending_target(card) or _is_card_pending_attack_target(card) or is_target_icon_candidate:
			if is_attack_candidate or _is_card_targeted_on_stack(card) or _is_card_pending_target(card) or _is_card_pending_attack_target(card):
				_add_target_aura(card_overlay)
			if is_target_icon_candidate:
				_add_attack_target_icon(card_overlay, card)
			else:
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
			var shield_layout := DefenseShieldOverlayScript.LAYOUT_STAT_UNDER
			if card.is_stealth and not can_view_stealth_details:
				shield_layout = DefenseShieldOverlayScript.LAYOUT_CENTER
			var shield_scale := DefenseShieldOverlayScript.STEALTH_VIEW_SIZE_MULTIPLIER if shield_layout == DefenseShieldOverlayScript.LAYOUT_CENTER else 1.0
			DefenseShieldOverlayScript.ensure_on(card_overlay, shield_layout, shield_scale)
		elif shows_aggressive_sword:
			AggressiveSwordOverlay.ensure_on(card_overlay, AggressiveSwordOverlay.LAYOUT_STAT_UNDER)
		_add_level_badge(card_overlay, card, Control.PRESET_TOP_LEFT, 6, LEVEL_BADGE_TOP, 54, LEVEL_BADGE_BOTTOM)
		_add_token_badge(card_overlay, card, Control.PRESET_TOP_LEFT, 6, 28, 66, 46)
		_add_turn_countdown_badge(card_overlay, card)
		_add_prepared_magical_mana_badge(card_overlay, card)
		if card.is_power:
			_add_power_cost_badge(card_overlay, card)
		_add_e2_abzu_badges(card_overlay, card)

		_add_sleep_affordance(card_overlay, card)
		if not card.is_stealth or card.get_controller() == board_viewer or card.is_temporarily_revealed():
			_add_equipment_affordances(card_overlay, card)
			_add_boon_affordances(card_overlay, card)
			_add_debuff_affordances(card_overlay, card)
			_add_nimue_badges(card_overlay, card)
			_add_white_serpent_medicine_badge(card_overlay, card)
			_add_creature_ability_badge(card_overlay, card)
			_add_board_card_custom_ability_badge(card_overlay, card)

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

		_add_creature_action_symbols(card_overlay, card)
		_add_stance_switch_symbol(card_overlay, card)
		_defense_overlay = card_overlay if shows_defense_shield else null
		_raised_overlay  = card_overlay if card.is_stealth else null
		z_index = _get_resting_z_index()

	else:
		z_index = BASE_BOARD_Z_INDEX
		_add_empty_zone_slab()

	_add_move_indicator_overlay()

func _add_creature_action_symbols(overlay: Control, card: Card) -> void:
	if overlay == null or card == null or card.card_type != Card.CardType.CREATURE:
		return
	var viewer := _get_viewer_player()
	var can_view_stealth := not card.is_stealth or card.get_controller() == viewer or card.is_temporarily_revealed()
	if card.is_face_down or card.is_prepared or not can_view_stealth:
		return
	var symbols := BoardZoneUI.get_creature_action_symbol_entries(card)
	if symbols.is_empty():
		return

	var card_uid := BoardZoneUI.get_action_point_card_uid(card)
	var current_state := BoardZoneUI.get_creature_action_symbol_state(card)
	var previous_state = _creature_action_symbol_state_by_card_uid.get(card_uid, {})
	var spent_kinds: Array[String] = []
	if previous_state is Dictionary:
		spent_kinds = BoardZoneUI.get_spent_action_kinds(previous_state as Dictionary, current_state)
	_creature_action_symbol_state_by_card_uid[card_uid] = current_state
	var pending_spend_kinds := BoardZoneUI.get_pending_action_point_spend_visual_kinds(card)
	var has_spend_effect := not spent_kinds.is_empty() or not pending_spend_kinds.is_empty()

	var has_visible_symbol := false
	for symbol in symbols:
		if not bool(symbol.get("used", false)):
			has_visible_symbol = true
			break
	var should_render_static_icons := _hovered and _should_show_creature_action_symbols(card)
	if not should_render_static_icons and not has_spend_effect:
		return
	if not has_visible_symbol and not has_spend_effect:
		return

	var icon_size := 22.0
	var gap := 3.0
	var total_width := icon_size * float(symbols.size()) + gap * float(maxi(0, symbols.size() - 1))
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -total_width * 0.5
	row.offset_right = total_width * 0.5
	row.offset_top = -32.0
	row.offset_bottom = -8.0
	row.custom_minimum_size = Vector2(total_width, icon_size)
	row.size = Vector2(total_width, icon_size)
	overlay.add_child(row)

	var zone_rect := get_global_rect()
	var row_global_origin := Vector2(
		zone_rect.position.x + zone_rect.size.x * 0.5 - total_width * 0.5,
		zone_rect.position.y + zone_rect.size.y - 32.0
	)
	var burst_requests: Array[Dictionary] = []
	for symbol_index in range(symbols.size()):
		var symbol := symbols[symbol_index] as Dictionary
		var kind := str(symbol.get("kind", Card.ACTION_COST_NONE))
		var used := bool(symbol.get("used", false))
		var key := str(symbol.get("key", ""))
		var left := float(symbol_index) * (icon_size + gap)
		if used:
			var should_burst := false
			if previous_state is Dictionary and (previous_state as Dictionary).has(key):
				var previous_entry = (previous_state as Dictionary).get(key, {})
				if previous_entry is Dictionary and not bool((previous_entry as Dictionary).get("used", false)):
					should_burst = true
			if kind in pending_spend_kinds:
				should_burst = true
				pending_spend_kinds.erase(kind)
			if should_burst:
				burst_requests.append({
					"kind": kind,
					"center": row_global_origin + Vector2(left + icon_size * 0.5, icon_size * 0.5),
				})
			continue
		if not should_render_static_icons:
			continue
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.custom_minimum_size = Vector2(icon_size, icon_size)
		slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
		slot.offset_left = left
		slot.offset_top = 0.0
		slot.offset_right = left + icon_size
		slot.offset_bottom = icon_size
		var hover_text := BoardZoneUI.get_creature_action_symbol_hover_text(symbol, card)
		slot.tooltip_text = hover_text
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			style.set_border_width(side, 0)
		style.border_color = Color(0.68, 0.68, 0.68, 0.95)
		slot.add_theme_stylebox_override("panel", style)
		var icon := TextureRect.new()
		icon.texture = MINOR_ACTION_SYMBOL_TEXTURE if kind == Card.ACTION_COST_MINOR else MAJOR_ACTION_SYMBOL_TEXTURE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color.WHITE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_connect_badge_hover(slot, hover_text)
		row.add_child(slot)

	if not burst_requests.is_empty():
		BoardZoneUI.clear_pending_action_point_spend_visual_kinds(card)
		call_deferred("_play_creature_action_symbol_spend_bursts", burst_requests, icon_size)

func _add_stance_switch_symbol(overlay: Control, card: Card) -> void:
	if overlay == null or card == null:
		return
	if not _should_show_stance_switch_symbol(card):
		return

	var target_mode: Card.CreatureMode = Card.CreatureMode.AGGRESSIVE if card.creature_mode == Card.CreatureMode.DEFENSIVE else Card.CreatureMode.DEFENSIVE
	var texture := SWITCH_TO_AGGRESSIVE_SYMBOL_TEXTURE if target_mode == Card.CreatureMode.AGGRESSIVE else SWITCH_TO_DEFENSIVE_SYMBOL_TEXTURE
	if texture == null:
		return

	var badge := Control.new()
	var card_uid := BoardZoneUI.get_action_point_card_uid(card)
	var action_cost_entries := _make_action_cost_entries(_get_minor_action_cost_kind_for_card(card))
	var action_mana_cost := _get_creature_action_mana_cost(card, "change stance")
	var hover_text := _with_action_cost_hover_text(
		_get_stance_switch_hover_text(card, target_mode),
		action_cost_entries,
		action_mana_cost
	)
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	badge.tooltip_text = hover_text
	badge.anchor_left = 0.0
	badge.anchor_right = 0.0
	badge.anchor_top = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_left = 4.0
	badge.offset_top = -102.0
	badge.offset_right = 4.0 + STANCE_SWITCH_BADGE_SIZE
	badge.offset_bottom = -38.0

	var background := Panel.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.10, 0.16, 0.94)
	style.border_color = Color(0.84, 0.88, 0.96, 0.98)
	style.shadow_color = Color(0.02, 0.02, 0.03, 0.42)
	style.shadow_size = 4
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	background.add_theme_stylebox_override("panel", style)
	badge.add_child(background)

	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	icon.offset_left = STANCE_SWITCH_ICON_LEFT
	icon.offset_top = STANCE_SWITCH_ICON_TOP
	icon.offset_right = STANCE_SWITCH_ICON_LEFT + STANCE_SWITCH_ICON_SIZE
	icon.offset_bottom = STANCE_SWITCH_ICON_TOP + STANCE_SWITCH_ICON_SIZE
	badge.add_child(icon)

	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 2)
	cost_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cost_row.offset_left = (STANCE_SWITCH_BADGE_SIZE - STANCE_SWITCH_COST_ROW_WIDTH) * 0.5
	cost_row.offset_top = STANCE_SWITCH_BADGE_SIZE - STANCE_SWITCH_COST_ROW_HEIGHT - 2.0
	cost_row.offset_right = cost_row.offset_left + STANCE_SWITCH_COST_ROW_WIDTH
	cost_row.offset_bottom = STANCE_SWITCH_BADGE_SIZE
	for entry in action_cost_entries:
		var action_cost_kind := str(entry.get("kind", Card.ACTION_COST_NONE))
		var action_texture := _get_action_cost_marker_texture(action_cost_kind)
		var amount := maxi(0, int(entry.get("amount", 0)))
		if action_texture == null or amount <= 0:
			continue
		_add_cost_amount_icon(cost_row, str(amount), action_texture)
	badge.add_child(cost_row)
	BoardZoneUI.register_action_cost_marker(cost_row, card, action_cost_entries)

	_connect_badge_hover(badge, hover_text)
	_connect_badge_click_action(badge, "creature_stance_switch", card_uid, int(target_mode))
	overlay.add_child(badge)

func _play_creature_action_symbol_spend_bursts(burst_requests: Array, icon_size: float) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var parent := _get_floating_popup_parent()
	if parent == null:
		return
	for raw_request in burst_requests:
		if not (raw_request is Dictionary):
			continue
		var request := raw_request as Dictionary
		var kind := str(request.get("kind", Card.ACTION_COST_NONE))
		var center = request.get("center", Vector2.ZERO)
		if not (center is Vector2):
			continue
		var center_vec: Vector2 = center
		BoardZoneUI.spawn_action_point_spend_effect(parent, center_vec, kind, icon_size)

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
			if not card.is_face_down or card.get_controller() == viewer or _is_public_power(card) or card.is_revealed_to_all():
				_pinned = true
				_hide_ability_popup()
				_show_ability_popup()
				accept_event()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EXIT_TREE:
			if _active_affordance_hover_owner_id == get_instance_id():
				_active_affordance_hover_owner_id = 0
			_pinned = false
			_hovered = false
			_badge_hovered = false
			_hide_pending = false
			_hover_exit_refresh_pending = false
			_disconnect_visual_state_card()
			_hide_badge_hover_popup()
			_hide_ability_popup()
		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			_active_affordance_hover_owner_id = get_instance_id()
			var _c := _preview_card if _preview_card != null else (zone.cards[0] if zone != null and zone.cards.size() > 0 else null)
			if _c != null:
				_notify_hover_card_options_changed(_c)
				_refresh_display()
			if _c != null:
				z_index = HOVER_BOARD_Z_INDEX
			elif zone != null and zone.cards.is_empty():
				_refresh_display()
			var viewer := _get_viewer_player()
			if _c != null and (not _c.is_face_down or _c.get_controller() == viewer or _is_public_power(_c) or _c.is_revealed_to_all()):
				var _delay := 1.0 if (_c.is_god) else 1.5
				if is_inside_tree() and not is_queued_for_deletion():
					get_tree().create_timer(_delay).timeout.connect(Callable(self, "_try_show_popup"))
		NOTIFICATION_MOUSE_EXIT:
			if _badge_hovered or _is_mouse_over_owned_badge() or _is_mouse_in_affordance_hover_area():
				_hovered = true
				_schedule_hover_exit_refresh()
				return
			_hovered = false
			_badge_hovered = false
			_notify_hover_card_options_changed(null)
			z_index = _get_resting_z_index()
			if zone != null and zone.cards.is_empty():
				_refresh_display()
			elif zone != null and not zone.cards.is_empty():
				_schedule_hover_exit_refresh()
			_schedule_hide()

func _schedule_hover_exit_refresh() -> void:
	if _hover_exit_refresh_pending:
		return
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_hover_exit_refresh_pending = true
	await get_tree().create_timer(0.06).timeout
	_hover_exit_refresh_pending = false
	if not is_inside_tree() or is_queued_for_deletion() or get_viewport() == null:
		return
	if _hovered or _badge_hovered or _is_mouse_over_owned_badge():
		return
	if get_global_rect().has_point(get_global_mouse_position()) or _is_mouse_in_affordance_hover_area():
		_hovered = true
		_schedule_hover_exit_refresh()
		return
	_refresh_display()

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
	if _badge_hovered or _is_mouse_over_owned_badge() or _is_mouse_in_affordance_hover_area():
		return  # Mouse is over an affordance extending outside the zone
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
	if _hovered and not _badge_hovered and not _is_mouse_over_owned_badge() and not _is_mouse_in_affordance_hover_area():
		_hovered = false
		_notify_hover_card_options_changed(null)
		z_index = _get_resting_z_index()
		_refresh_display()
		return
	if _popup and is_instance_valid(_popup):
		var over_zone  := get_global_rect().has_point(get_global_mouse_position())
		var over_popup := _popup.get_global_rect().has_point(get_global_mouse_position())
		var over_badge := _badge_hovered or _is_mouse_over_owned_badge() or _is_mouse_in_affordance_hover_area()
		if not over_zone and not over_popup and not over_badge:
			_schedule_hide()

func _try_show_popup() -> void:
	if not _hovered:
		return
	if _badge_hovered or _is_mouse_over_owned_badge() or not get_global_rect().has_point(get_global_mouse_position()):
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
	var floating_parent := _get_floating_popup_parent()
	if floating_parent == null:
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
	popup.mouse_exited.connect(Callable(self, "_on_popup_mouse_exited"))

	var popup_viewer_shared := _get_viewer_player()
	var is_hidden_card_shared := (card.is_stealth or (card.is_face_down and not _is_public_power(card))) and card.get_controller() != popup_viewer_shared and not card.is_revealed_to_all()

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

	popup.add_child(CardDetailContentBuilderScript.build_board_popup_body(
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
		var keywords := CardDetailContentBuilderScript.extract_card_keywords(card)
		if not keywords.is_empty():
			keywords_panel = CardDetailContentBuilderScript.build_keywords_panel(keywords)
			popup_root.add_child(keywords_panel)

	_popup = popup_root
	floating_parent.add_child(popup_root)
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
