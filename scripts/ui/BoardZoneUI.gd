class_name BoardZoneUI
extends PanelContainer

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
var _hovered: bool = false
var _pinned: bool = false
var _hide_pending: bool = false
var _defense_overlay: Control = null
var _raised_overlay: Control = null  # non-null for DEF or stealth — floats above the zone row

const ZONE_WIDTH  := 165
const ZONE_HEIGHT := 110

var _row_label: String = ""

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
	haze.color = Color(0.2, 0.28, 0.45, 0.18)
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(haze)

func setup(p_zone: Zone, p_gm: GameManager, p_player: Player, idx: int,
		drop_cb: Callable, is_enemy: bool = false, row_label: String = "") -> void:
	zone         = p_zone
	game_manager = p_gm
	owning_player = p_player
	zone_index   = idx
	_drop_callback = drop_cb
	_is_enemy    = is_enemy
	_row_label   = row_label
	custom_minimum_size = Vector2(ZONE_WIDTH, ZONE_HEIGHT)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_display()

func _refresh_display() -> void:
	_hide_ability_popup()
	_raised_overlay = null
	for child in get_children():
		child.queue_free()

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left    = 4
	style.corner_radius_top_right   = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)

	if zone.cards.size() > 0:
		var card := zone.cards[0]

		# Face-down cards: own stealth / locked powers / prepared cards show hazed art; others show cardback
		if card.is_face_down:
			add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			var fd_overlay := Control.new()
			fd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(fd_overlay)
			var is_own_hidden_card := card.get_controller() == game_manager.current_player and (
				card.is_stealth
				or card.is_power
				or card.is_prepared
			)
			var tex_path := card.art_path if is_own_hidden_card and card.art_path != "" else "res://images/cardbackAI.png"
			var tex: Texture2D = load(tex_path)
			if tex:
				var art := TextureRect.new()
				art.texture = tex
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fd_overlay.add_child(art)
			if is_own_hidden_card:
				var haze := ColorRect.new()
				haze.color = Color(0.05, 0.05, 0.2, 0.6)
				haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fd_overlay.add_child(haze)
			var _fd_is_def := card.card_type == Card.CardType.CREATURE and card.creature_mode == Card.CreatureMode.DEFENSE
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
				add_child(overlay)

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
				name_lbl.text = card.card_name
				name_lbl.add_theme_font_size_override("font_size", 11)
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
				name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
			return

		var is_def_creature := card.card_type == Card.CardType.CREATURE and card.creature_mode == Card.CreatureMode.DEFENSE
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
		add_child(overlay)

		# Art background; stealth shows hazed art (own) or cardback (opponent)
		if card.is_stealth:
			var is_own := card.get_controller() == game_manager.current_player
			var tex_path := card.art_path if is_own and card.art_path != "" else "res://images/cardbackAI.png"
			var tex: Texture2D = load(tex_path)
			if tex:
				var art := TextureRect.new()
				art.texture = tex
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				overlay.add_child(art)
			if is_own:
				var haze := ColorRect.new()
				haze.color = Color(0.05, 0.05, 0.2, 0.6)
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

		# VBox fills the zone; spacer pushes the stat label to the bottom
		var vbox := VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(vbox)

		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(spacer)

		var is_own_stealth_faceup := card.is_stealth and card.get_controller() == game_manager.current_player
		if card.card_type == Card.CardType.CREATURE and not card.is_god and (not card.is_stealth or is_own_stealth_faceup):
			var eff_str := card.get_effective_strength()
			var eff_res := card.get_effective_resilience()
			var eff_spd := card.get_effective_speed()
			var is_def := card.creature_mode == Card.CreatureMode.DEFENSE
			var stat_row := HBoxContainer.new()
			stat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var left_lbl := Label.new()
			left_lbl.text = "RES:%d" % eff_res if is_def else "STR:%d" % eff_str
			left_lbl.add_theme_font_size_override("font_size", 13)
			left_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var left_base := card.resilience if is_def else card.strength
			var left_eff  := eff_res if is_def else eff_str
			if left_eff > left_base:
				left_lbl.modulate = Color(0.4, 1.0, 0.4)
			elif left_eff < left_base:
				left_lbl.modulate = Color(1.0, 0.35, 0.35)
			stat_row.add_child(left_lbl)

			var mid_spacer := Control.new()
			mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stat_row.add_child(mid_spacer)

			var right_lbl := Label.new()
			right_lbl.text = "SPD:%d" % eff_spd
			right_lbl.add_theme_font_size_override("font_size", 13)
			right_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if eff_spd > card.speed:
				right_lbl.modulate = Color(0.4, 1.0, 0.4)
			elif eff_spd < card.speed:
				right_lbl.modulate = Color(1.0, 0.35, 0.35)
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
	var card := zone.cards[0]
	if card.card_type != Card.CardType.CREATURE:
		return false
	if card.is_god:
		return false
	if card.get_controller() != game_manager.current_player:
		return false
	if card.has_moved_this_turn and card.has_acted_this_turn:
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
			if card.card_type == Card.CardType.CREATURE and card.get_controller() == game_manager.current_player:
				creature_right_clicked.emit(card)
			# Pin the info popup on right-click for any visible card
			if not card.is_face_down or card.get_controller() == game_manager.current_player:
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
			if _c != null and (not _c.is_face_down or _c.get_controller() == game_manager.current_player):
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
	var scene_root := get_tree().current_scene
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
	var hidden := card.is_stealth and card.get_controller() != game_manager.current_player

	# Name
	var name_lbl := Label.new()
	name_lbl.text = card.card_name if not hidden else "???"
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# Types
	if not hidden and card.card_types.size() > 0:
		var type_lbl := Label.new()
		type_lbl.text = " • ".join(card.card_types)
		type_lbl.add_theme_font_size_override("font_size", 11)
		type_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		type_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(type_lbl)

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
			mode_lbl.text = "DEF" if card.creature_mode == Card.CreatureMode.DEFENSE else "ATK"
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

		# Acted / moved
		if card.has_acted_this_turn:
			var acted_lbl := Label.new()
			acted_lbl.text = "✓ acted"
			acted_lbl.add_theme_font_size_override("font_size", 9)
			acted_lbl.modulate = Color(0.8, 0.8, 0.4)
			acted_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(acted_lbl)
		elif card.has_moved_this_turn:
			var moved_lbl := Label.new()
			moved_lbl.text = "✓ moved"
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

	# Ability text
	if card.ability_text != "" and not hidden:
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.text = BaseCard.apply_keyword_hints(card.ability_text)
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.add_theme_font_size_override("normal_font_size", 11)
		rtl.add_theme_font_size_override("bold_font_size", 11)
		rtl.add_theme_color_override("default_color", Color(0.9, 0.85, 1.0))
		rtl.scroll_active = false
		rtl.fit_content = true
		rtl.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(rtl)

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
			return false
		var target := zone.cards[0]
		if target.card_type != Card.CardType.CREATURE and target.card_type != Card.CardType.STRUCTURE and target.card_type != Card.CardType.EQUIPMENT:
			return false
		return game_manager.can_play_card(game_manager.current_player, card, null)
	if card is Absence:
		if zone.cards.size() == 0:
			return false
		var target := zone.cards[0]
		if target is not PowerCard:
			return false
		return game_manager.can_play_card(game_manager.current_player, card, null)
	if _is_enemy:
		return false
	if zone.cards.size() > 0:
		return false
	if owning_player != game_manager.current_player:
		return false
	return game_manager.can_play_card(owning_player, card, zone)
