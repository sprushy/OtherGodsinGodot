# DeckBuilderUI.gd
# Full deck builder screen built entirely in code.
extends Control
class_name DeckBuilderUICodexArchive

signal back_pressed

# ── constants ──────────────────────────────────────────────────────
const CARD_W    := 140
const CARD_H    := 192
const MIN_DECK  := 20

# ── state ──────────────────────────────────────────────────────────
var _all_cards: Array  = []        # template Card instances (read-only)
var _deck: Dictionary  = {}        # card_name (String) -> count (int)
var _filter: String         = "All"
var _faction_filter: String = "All"

# ── major UI refs ──────────────────────────────────────────────────
var _grid:             HFlowContainer
var _deck_list:        VBoxContainer
var _deck_count_lbl:   Label
var _validation_lbl:   Label
# preview
var _prev_art:         TextureRect
var _prev_name:        Label
var _prev_type:        Label
var _prev_stats:       Label
var _prev_ability:     RichTextLabel
var _prev_flavor:      Label
# per-card count badge in collection (card_name -> Label)
var _count_badges: Dictionary = {}

# ── init ───────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_all_cards = _make_all_cards()
	_build_ui()
	_refresh_grid()
	_refresh_deck_panel()

func _make_all_cards() -> Array:
	return [
		Thor.new(), Mummu.new(), AphroditeAreia.new(), Baldr.new(), DellingrTheDayspring.new(), Freyja.new(),
		AcceleratedFate.new(), ACostToWalkTheWorlds.new(), AdvancedBuildingTechniques.new(), AllfathersSacrifice.new(), AltarOfDreams.new(), AnankesBinding.new(), AncientWisdom.new(), BerserkerMead.new(), Breidablik.new(), CallOfTheValkyrie.new(), FeastOfAmbrosiaAndNectar.new(), FerociousDefence.new(), FireAndGold.new(),
		Berserker.new(), Beyla.new(), BlessedKnights.new(), BrownBear.new(), Byggvir.new(), DurinnSecondborn.new(), Fenrir.new(), FirstSageAdapa.new(), load("res://scripts/cards/Creatures/FourthSageEnmegalamma.gd").new(), Skoll.new(), AnkouServantToTheReaper.new(), Anzu.new(), AnTheBowbender.new(),
		AsagTheDestroyer.new(), Asakku.new(), Asaruludu.new(),
		AgainWalker.new(), Alu.new(), Askelladen.new(), Aurboda.new(), EnkiLordOfEridu.new(), Gallu.new(),
		BitMeseri.new(), CircleOfRebirth.new(), FallOfTheMighty.new(), Famine.new(), FoolishOptimism.new(), preload("res://scripts/cards/Spells/FiresOfJudgment.gd").new(), ApollyonsDemiurge.new(), Absence.new(), BaneOfTheSvartalfar.new(), BlotSacrifice.new(), BookOfLife.new(), DeucalionsInfants.new(), MeadOfPoetry.new(), DivineLightning.new(), FifaTheMagicalArrow.new(),
		BeardedAxe.new(), Gambanteinn.new(),
		WardingStone.new(), AncientPyre.new(), AnointingStatue.new(), DoorwayToTheVoid.new(), E2Abzu.new(),
		VoidShield.new(), Banishment.new(), Dromi.new(),
	]

# ── UI construction ────────────────────────────────────────────────
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_build_top_bar(root)
	_build_faction_bar(root)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	root.add_child(body)

	_build_collection_panel(body)
	_build_deck_panel(body)

func _build_top_bar(parent: Control) -> void:
	var bar := PanelContainer.new()
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.10, 0.10, 0.16)
	bar.add_theme_stylebox_override("panel", bar_style)
	parent.add_child(bar)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	bar.add_child(inner)

	var pad_l := Control.new()
	pad_l.custom_minimum_size.x = 8
	inner.add_child(pad_l)

	var title := Label.new()
	title.text = "DECK BUILDER"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 44
	title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)

	var btn_group := ButtonGroup.new()
	for label in ["All", "Gods", "Powers", "Creatures", "Equipment", "Charms", "Spells", "Structures", "Hexes"]:
		var btn := Button.new()
		btn.text = label
		btn.toggle_mode = true
		btn.button_group = btn_group
		btn.button_pressed = (label == _filter)
		btn.custom_minimum_size = Vector2(72, 32)
		var captured_label: String = label
		btn.pressed.connect(func() -> void: _set_filter(captured_label))
		inner.add_child(btn)

	var gap := Control.new()
	gap.custom_minimum_size.x = 16
	inner.add_child(gap)

	var back_btn := Button.new()
	back_btn.text = "← Menu"
	back_btn.custom_minimum_size = Vector2(90, 32)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	inner.add_child(back_btn)

	var pad_r := Control.new()
	pad_r.custom_minimum_size.x = 8
	inner.add_child(pad_r)

func _build_faction_bar(parent: Control) -> void:
	var bar := PanelContainer.new()
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.08, 0.08, 0.13)
	bar.add_theme_stylebox_override("panel", bar_style)
	parent.add_child(bar)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	bar.add_child(inner)

	var pad_l := Control.new()
	pad_l.custom_minimum_size.x = 8
	inner.add_child(pad_l)

	var faction_lbl := Label.new()
	faction_lbl.text = "Faction:"
	faction_lbl.add_theme_font_size_override("font_size", 11)
	faction_lbl.modulate = Color(0.7, 0.7, 0.7)
	faction_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	faction_lbl.custom_minimum_size.y = 30
	faction_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(faction_lbl)

	# Collect unique cultures from card pool, sorted
	var cultures: Array = []
	for card in _all_cards:
		if card.culture != "" and card.culture not in cultures:
			cultures.append(card.culture)
	cultures.sort()

	var btn_group := ButtonGroup.new()
	for label in (["All"] as Array) + cultures:
		var btn := Button.new()
		btn.text = label
		btn.toggle_mode = true
		btn.button_group = btn_group
		btn.button_pressed = (label == _faction_filter)
		btn.custom_minimum_size = Vector2(72, 26)
		var captured: String = label
		btn.pressed.connect(func() -> void: _set_faction_filter(captured))
		inner.add_child(btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)

func _build_collection_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.09, 0.13)
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

func _build_deck_panel(parent: Control) -> void:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 295
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 5)
	parent.add_child(panel)

	# ── preview ──────────────────────────────────────────
	var prev_outer := PanelContainer.new()
	prev_outer.custom_minimum_size = Vector2(295, 190)
	var prev_style := StyleBoxFlat.new()
	prev_style.bg_color = Color(0.10, 0.10, 0.16)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		prev_style.set_border_width(side, 1)
	prev_style.border_color = Color(0.3, 0.3, 0.5)
	prev_outer.add_theme_stylebox_override("panel", prev_style)
	panel.add_child(prev_outer)

	var prev_hbox := HBoxContainer.new()
	prev_hbox.add_theme_constant_override("separation", 8)
	prev_outer.add_child(prev_hbox)

	_prev_art = TextureRect.new()
	_prev_art.custom_minimum_size = Vector2(100, 133)
	_prev_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_prev_art.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_prev_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prev_hbox.add_child(_prev_art)

	var prev_text := VBoxContainer.new()
	prev_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_text.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	prev_text.add_theme_constant_override("separation", 3)
	prev_hbox.add_child(prev_text)

	_prev_name = Label.new()
	_prev_name.text = "Hover a card to preview"
	_prev_name.add_theme_font_size_override("font_size", 12)
	_prev_name.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_prev_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prev_text.add_child(_prev_name)

	_prev_type = Label.new()
	_prev_type.text = ""
	_prev_type.add_theme_font_size_override("font_size", 10)
	_prev_type.modulate = Color(0.7, 0.85, 1.0)
	_prev_type.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prev_text.add_child(_prev_type)

	_prev_stats = Label.new()
	_prev_stats.text = ""
	_prev_stats.add_theme_font_size_override("font_size", 10)
	prev_text.add_child(_prev_stats)

	_prev_ability = RichTextLabel.new()
	_prev_ability.bbcode_enabled  = true
	_prev_ability.text            = ""
	_prev_ability.autowrap_mode   = TextServer.AUTOWRAP_WORD_SMART
	_prev_ability.add_theme_font_size_override("normal_font_size", 9)
	_prev_ability.add_theme_font_size_override("bold_font_size", 9)
	_prev_ability.add_theme_color_override("default_color", Color(0.85, 0.8, 1.0))
	_prev_ability.scroll_active   = false
	_prev_ability.fit_content     = true
	_prev_ability.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prev_ability.custom_minimum_size.y = 28
	_prev_ability.mouse_filter    = Control.MOUSE_FILTER_STOP
	prev_text.add_child(_prev_ability)

	_prev_flavor = Label.new()
	_prev_flavor.text = ""
	_prev_flavor.add_theme_font_size_override("font_size", 9)
	_prev_flavor.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_prev_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prev_text.add_child(_prev_flavor)

	# ── deck header ──────────────────────────────────────
	var hdr := HBoxContainer.new()
	panel.add_child(hdr)

	var deck_title := Label.new()
	deck_title.text = "MY DECK"
	deck_title.add_theme_font_size_override("font_size", 13)
	deck_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	deck_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(deck_title)

	_deck_count_lbl = Label.new()
	_deck_count_lbl.text = "0 cards"
	_deck_count_lbl.add_theme_font_size_override("font_size", 11)
	_deck_count_lbl.modulate = Color(0.7, 0.7, 0.7)
	hdr.add_child(_deck_count_lbl)

	# ── deck scroll list ─────────────────────────────────
	var deck_scroll := ScrollContainer.new()
	deck_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	deck_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(deck_scroll)

	_deck_list = VBoxContainer.new()
	_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_list.add_theme_constant_override("separation", 2)
	deck_scroll.add_child(_deck_list)

	var sep := HSeparator.new()
	panel.add_child(sep)

	# ── validation status ────────────────────────────────
	_validation_lbl = Label.new()
	_validation_lbl.text = ""
	_validation_lbl.add_theme_font_size_override("font_size", 10)
	_validation_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_validation_lbl)

	# ── action buttons ───────────────────────────────────
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	panel.add_child(btns)

	var save_btn := Button.new()
	save_btn.text = "Save Deck"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_save_deck)
	btns.add_child(save_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_clear_deck)
	btns.add_child(clear_btn)

	var pad_bot := Control.new()
	pad_bot.custom_minimum_size.y = 4
	panel.add_child(pad_bot)

# ── collection grid ────────────────────────────────────────────────
func _refresh_grid() -> void:
	_count_badges.clear()
	for child in _grid.get_children():
		child.queue_free()

	var visible_card_filter := func(card: Card) -> bool:
		return _matches_filter(card)
	var visible_cards: Array = _all_cards.filter(visible_card_filter)
	visible_cards.sort_custom(_alphabetical_card_less)
	for card in visible_cards:
		if not _matches_filter(card):
			continue
		_grid.add_child(_make_card_item(card))

func _matches_filter(card: Card) -> bool:
	if _faction_filter != "All" and card.culture != _faction_filter:
		return false
	match _filter:
		"All":       return true
		"Gods":      return card.is_god
		"Powers":    return card.is_power and not card.is_god
		"Creatures": return card.card_type == Card.CardType.CREATURE and not card.is_god
		"Equipment": return card.card_type == Card.CardType.EQUIPMENT
		"Charms":    return card.card_type == Card.CardType.CHARM
		"Spells":    return card.card_type == Card.CardType.SPELL
		"Structures":return card.card_type == Card.CardType.STRUCTURE
		"Hexes":     return card.card_type == Card.CardType.HEX
	return true

func _make_card_item(card: Card) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	# Border / background
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tc := _get_type_color(card)
	var sty := StyleBoxFlat.new()
	sty.bg_color = tc.darkened(0.75)
	sty.border_color = tc
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sty.set_border_width(side, 2)
	sty.corner_radius_top_left    = 4; sty.corner_radius_top_right    = 4
	sty.corner_radius_bottom_left = 4; sty.corner_radius_bottom_right = 4
	bg.add_theme_stylebox_override("panel", sty)
	root.add_child(bg)

	# Art
	if card.art_path != "":
		var tex: Texture2D = load(card.art_path)
		if tex:
			var art := TextureRect.new()
			art.texture      = tex
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(art)

	# Name bar (bottom 22%)
	var name_bg := ColorRect.new()
	name_bg.color = Color(0.0, 0.0, 0.0, 0.80)
	name_bg.anchor_left = 0; name_bg.anchor_right = 1
	name_bg.anchor_top  = 1; name_bg.anchor_bottom = 1
	name_bg.offset_top  = -42; name_bg.offset_bottom = 0
	name_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_bg)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.anchor_left  = 0; name_lbl.anchor_right  = 1
	name_lbl.anchor_top   = 1; name_lbl.anchor_bottom = 1
	name_lbl.offset_top   = -42; name_lbl.offset_bottom = 0
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.text = card.get_display_name_for_control(name_lbl)
	root.add_child(name_lbl)

	# Type badge (top-left)
	var type_lbl := Label.new()
	type_lbl.text = _get_type_label(card)
	type_lbl.add_theme_font_size_override("font_size", 8)
	type_lbl.add_theme_color_override("font_color", tc)
	type_lbl.anchor_left  = 0; type_lbl.anchor_top  = 0
	type_lbl.offset_left  = 4; type_lbl.offset_top  = 4
	type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(type_lbl)

	# Mana cost (top-right, only if > 0)
	if card.mana_cost > 0:
		var mana_bg := ColorRect.new()
		mana_bg.color = Color(0.1, 0.25, 0.55, 0.85)
		mana_bg.custom_minimum_size = Vector2(22, 22)
		mana_bg.anchor_right  = 1; mana_bg.anchor_left  = 1
		mana_bg.anchor_top    = 0; mana_bg.anchor_bottom = 0
		mana_bg.offset_left   = -24; mana_bg.offset_right  = -2
		mana_bg.offset_top    = 2;   mana_bg.offset_bottom = 24
		mana_bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		root.add_child(mana_bg)

		var mana_lbl := Label.new()
		mana_lbl.text = str(card.mana_cost)
		mana_lbl.add_theme_font_size_override("font_size", 11)
		mana_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		mana_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mana_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		mana_lbl.anchor_right  = 1; mana_lbl.anchor_left  = 1
		mana_lbl.anchor_top    = 0; mana_lbl.anchor_bottom = 0
		mana_lbl.offset_left   = -24; mana_lbl.offset_right  = -2
		mana_lbl.offset_top    = 2;   mana_lbl.offset_bottom = 24
		mana_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		root.add_child(mana_lbl)

	# Count badge (bottom-right, overlaid on name bar)
	var count_lbl := Label.new()
	count_lbl.text = ""
	count_lbl.add_theme_font_size_override("font_size", 14)
	count_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	count_lbl.anchor_right  = 1; count_lbl.anchor_left  = 1
	count_lbl.anchor_bottom = 1; count_lbl.anchor_top   = 1
	count_lbl.offset_left   = -24; count_lbl.offset_right  = -4
	count_lbl.offset_top    = -38; count_lbl.offset_bottom = -2
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(count_lbl)
	_count_badges[card.card_name] = count_lbl

	# Dim overlay (filled when at max copies)
	var dim := ColorRect.new()
	dim.name  = "DimOverlay"
	dim.color = Color(0.0, 0.0, 0.0, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	# Input
	root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				_add_to_deck(card)
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				_remove_from_deck(card.card_name)
	)
	root.mouse_entered.connect(func() -> void: _show_preview(card))

	return root

# ── deck panel refresh ─────────────────────────────────────────────
func _refresh_deck_panel() -> void:
	for child in _deck_list.get_children():
		child.queue_free()

	var total := 0
	for cnt: int in _deck.values():
		total += cnt
	_deck_count_lbl.text = "%d cards" % total

	# Sort: gods → creatures → spells → structures → hexes, then alphabetical
	var in_deck_filter := func(c: Card) -> bool:
		return _deck.has(c.card_name) and _deck[c.card_name] > 0
	var in_deck: Array = _all_cards.filter(in_deck_filter)
	var in_deck_sort := func(a: Card, b: Card) -> bool:
		var oa := _type_order(a)
		var ob := _type_order(b)
		if oa != ob:
			return oa < ob
		return _alphabetical_card_less(a, b)
	in_deck.sort_custom(in_deck_sort)

	var last_section := ""
	for card: Card in in_deck:
		var sec := _section_name(card)
		if sec != last_section:
			last_section = sec
			var sep_lbl := Label.new()
			sep_lbl.text = sec
			sep_lbl.add_theme_font_size_override("font_size", 9)
			sep_lbl.add_theme_color_override("font_color", _get_type_color(card).lerp(Color.WHITE, 0.3))
			_deck_list.add_child(sep_lbl)
		_deck_list.add_child(_make_deck_row(card))

	_update_validation()
	_update_count_badges()

func _make_deck_row(card: Card) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(7, 7)
	dot.color = _get_type_color(card)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text = card.get_display_name_for_control(name_lbl)
	row.add_child(name_lbl)

	var cnt_lbl := Label.new()
	cnt_lbl.text = "×%d" % _deck[card.card_name]
	cnt_lbl.add_theme_font_size_override("font_size", 10)
	cnt_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
	cnt_lbl.custom_minimum_size.x = 22
	row.add_child(cnt_lbl)

	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(24, 22)
	minus.pressed.connect(func() -> void: _remove_from_deck(card.card_name))
	row.add_child(minus)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(24, 22)
	plus.pressed.connect(func() -> void: _add_to_deck(card))
	row.add_child(plus)

	return row

# ── deck mutation ──────────────────────────────────────────────────
func _add_to_deck(card: Card) -> void:
	var current: int = _deck.get(card.card_name, 0)
	if current >= _max_copies(card):
		return
	# Only one god allowed total
	if card.is_god:
		for deck_card_name in _deck:
			var tmpl := _find_template(deck_card_name)
			if tmpl and tmpl.is_god and _deck[deck_card_name] > 0:
				return
	_deck[card.card_name] = current + 1
	_refresh_deck_panel()

func _remove_from_deck(card_name: String) -> void:
	if not _deck.has(card_name) or _deck[card_name] <= 0:
		return
	_deck[card_name] -= 1
	if _deck[card_name] == 0:
		_deck.erase(card_name)
	_refresh_deck_panel()

func _clear_deck() -> void:
	_deck.clear()
	_refresh_deck_panel()

func _save_deck() -> void:
	if _deck.is_empty():
		print("DeckBuilder: nothing to save.")
		return
	var file := FileAccess.open("user://saved_deck.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_deck, "\t"))
		file.close()
		print("DeckBuilder: saved to user://saved_deck.json")
		# Flash save button text feedback
		_validation_lbl.text = "✓ Deck saved!\n" + _validation_lbl.text
		get_tree().create_timer(2.0).timeout.connect(
			func() -> void: if is_instance_valid(_validation_lbl): _update_validation()
		)
	else:
		print("DeckBuilder: save failed.")

# ── validation ─────────────────────────────────────────────────────
func _update_validation() -> void:
	var total := 0
	var god_count := 0
	var power_count := 0
	var regular_count := 0
	var legendary_count := 0

	for card_name: String in _deck:
		var cnt: int = _deck[card_name]
		var card := _find_template(card_name)
		if card == null:
			continue
		total += cnt
		if card.is_god:
			god_count += cnt
		elif card.is_power and not card.is_god:
			power_count += cnt
		else:
			regular_count += cnt
			if card.is_legendary:
				legendary_count += cnt

	var max_legends := int(regular_count / 10.0)
	var lines: PackedStringArray = []
	var ok := true

	if god_count == 0:
		lines.append("✗ God: none required");   ok = false
	elif god_count == 1:
		lines.append("✓ God: present")
	else:
		lines.append("✗ God: max 1");           ok = false

	if power_count <= 3:
		lines.append("✓ Powers: %d / 3" % power_count)
	else:
		lines.append("✗ Powers: %d / 3" % power_count); ok = false

	if legendary_count <= max_legends:
		lines.append("✓ Legendaries: %d / %d" % [legendary_count, max_legends])
	else:
		lines.append("✗ Legendaries: %d / %d" % [legendary_count, max_legends]); ok = false

	if total < MIN_DECK:
		lines.append("✗ Total: %d (min %d)" % [total, MIN_DECK]); ok = false
	else:
		lines.append("  Total: %d cards" % total)

	_validation_lbl.text = "\n".join(lines)
	_validation_lbl.modulate = Color(0.5, 1.0, 0.55) if ok else Color(1.0, 0.85, 0.45)

func _update_count_badges() -> void:
	for card_name: String in _count_badges:
		var lbl: Label = _count_badges[card_name]
		if not is_instance_valid(lbl):
			continue
		var count: int = _deck.get(card_name, 0)
		lbl.text = "×%d" % count if count > 0 else ""

		# Dim card when at max copies
		var card := _find_template(card_name)
		var is_max := card != null and count >= _max_copies(card)
		# Dim overlay is the last child of the card root
		var card_root := lbl.get_parent()
		if card_root:
			var dim_node := card_root.get_node_or_null("DimOverlay")
			if dim_node is ColorRect:
				dim_node.color = Color(0.0, 0.0, 0.0, 0.5) if is_max else Color(0.0, 0.0, 0.0, 0.0)

# ── preview ────────────────────────────────────────────────────────
func _show_preview(card: Card) -> void:
	if card.art_path != "":
		_prev_art.texture = load(card.art_path) as Texture2D
	else:
		_prev_art.texture = null

	_prev_name.text = card.get_display_name_for_control(_prev_name)

	var type_parts: PackedStringArray = [_get_type_label(card)]
	if card.culture != "":
		type_parts.append(card.culture)
	if card.card_types.size() > 0:
		type_parts.append(" • ".join(Array(card.card_types)))
	_prev_type.text = " | ".join(type_parts)
	_prev_type.add_theme_color_override("font_color", _get_type_color(card))

	var stat_parts: PackedStringArray = []
	if card.card_type == Card.CardType.CREATURE and not card.is_god:
		stat_parts.append("STR:%d  RES:%d  SPD:%d" % [card.strength, card.resilience, card.speed])
	elif card.card_type == Card.CardType.STRUCTURE:
		stat_parts.append("RES:%d" % card.resilience)
	elif card.card_type == Card.CardType.EQUIPMENT:
		var equip_parts: PackedStringArray = []
		if card.strength_modifier != 0:
			equip_parts.append("STR %+d" % card.strength_modifier)
		if card.resilience_modifier != 0:
			equip_parts.append("RES %+d" % card.resilience_modifier)
		if card.speed_modifier != 0:
			equip_parts.append("SPD %+d" % card.speed_modifier)
		stat_parts.append("  ".join(equip_parts))
	elif card.card_type in [Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM]:
		stat_parts.append("SPD:%d" % card.speed)
	if card.mana_cost > 0:
		stat_parts.append("Mana: %d" % card.mana_cost)
	_prev_stats.text = "  ".join(stat_parts)

	_prev_ability.text = BaseCard.apply_keyword_hints(BaseCard.apply_action_cost_symbols(card.ability_text, card)) if card.ability_text != "" else ""
	_prev_flavor.text  = card.flavor_text if card.should_show_flavor_text_in_hover() else ""

# ── filter ─────────────────────────────────────────────────────────
func _set_filter(new_filter: String) -> void:
	_filter = new_filter
	_refresh_grid()
	_update_count_badges()

func _set_faction_filter(new_faction: String) -> void:
	_faction_filter = new_faction
	_refresh_grid()
	_update_count_badges()

# ── helpers ────────────────────────────────────────────────────────
func _max_copies(card: Card) -> int:
	if card.is_god:       return 1
	if card.is_legendary: return 1
	return 3

func _find_template(card_name: String) -> Card:
	for card: Card in _all_cards:
		if card.card_name == card_name:
			return card
	return null

func _alphabetical_card_less(a: Card, b: Card) -> bool:
	var a_name := a.get_normalized_card_name().to_lower()
	var b_name := b.get_normalized_card_name().to_lower()
	if a_name == b_name:
		return a.card_name < b.card_name
	return a_name < b_name

func _get_type_color(card: Card) -> Color:
	if card.is_god: return Color(0.9, 0.75, 0.2)
	if card.is_power: return Color(0.85, 0.55, 0.18)
	match card.card_type:
		Card.CardType.CREATURE:  return Color(0.3, 0.55, 0.95)
		Card.CardType.EQUIPMENT: return Color(0.78, 0.78, 0.82)
		Card.CardType.CHARM:     return Color(0.95, 0.6, 0.3)
		Card.CardType.SPELL:     return Color(0.7, 0.35, 0.95)
		Card.CardType.STRUCTURE: return Color(0.7, 0.5, 0.2)
		Card.CardType.HEX:       return Color(0.2, 0.82, 0.72)
	return Color(0.55, 0.55, 0.55)

func _get_type_label(card: Card) -> String:
	if card.is_god: return "God"
	if card.is_power: return "Power"
	match card.card_type:
		Card.CardType.CREATURE:  return "Creature"
		Card.CardType.EQUIPMENT: return "Equipment"
		Card.CardType.CHARM:     return "Charm"
		Card.CardType.SPELL:     return "Spell"
		Card.CardType.STRUCTURE: return "Structure"
		Card.CardType.HEX:       return "Hex"
	return "Card"

func _type_order(card: Card) -> int:
	if card.is_god: return 0
	if card.is_power: return 1
	match card.card_type:
		Card.CardType.CREATURE:  return 2
		Card.CardType.EQUIPMENT: return 3
		Card.CardType.CHARM:     return 4
		Card.CardType.SPELL:     return 5
		Card.CardType.STRUCTURE: return 6
		Card.CardType.HEX:       return 7
	return 8

func _section_name(card: Card) -> String:
	if card.is_god: return "— Gods —"
	if card.is_power: return "— Powers —"
	match card.card_type:
		Card.CardType.CREATURE:  return "— Creatures —"
		Card.CardType.EQUIPMENT: return "— Equipment —"
		Card.CardType.CHARM:     return "— Charms —"
		Card.CardType.SPELL:     return "— Spells —"
		Card.CardType.STRUCTURE: return "— Structures —"
		Card.CardType.HEX:       return "— Hexes —"
	return "— Other —"
