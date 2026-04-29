# DeckBuilderUI.gd
# Full deck builder screen built entirely in code.
extends Control
class_name DeckBuilderUI

const LocalProfileStoreScript = preload("res://scripts/core/LocalProfileStore.gd")
const DeckCatalogUtilsScript = preload("res://scripts/core/DeckCatalogUtils.gd")
const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")

signal back_pressed
signal account_deck_deleted_locally(deck_id: String)

# ── constants ──────────────────────────────────────────────────────
const CARD_W    := 140
const CARD_H    := 192
const MIN_REGULAR_CARDS := 35
const DEFAULT_COLLECTION_ROWS := 3
const COLLECTION_GAP  := 8.0
const PAGE_REPEAT_INTERVAL_MS := 90
const COLLECTION_MODE_CARDS := "cards"
const COLLECTION_MODE_SAVED_DECKS := "saved_decks"
const LEVEL_FILTER_ANY := "Any"
const MAX_DECK_UNDO_STATES := 100
const MIN_DECK_PANEL_WIDTH := 260.0
const MAX_DECK_PANEL_WIDTH := 380.0
const NARROW_DECK_PANEL_WIDTH := 300.0
const COMPACT_PREVIEW_WIDTH_THRESHOLD := 300.0
const STACKED_LAYOUT_WIDTH_THRESHOLD := 900.0
const DESKTOP_LAYOUT_BOTTOM_CLEARANCE := 44.0
const CARD_VIEW_PRESETS := [
	{"label": "Tiny", "rows": 5},
	{"label": "Small", "rows": 4},
	{"label": "Medium", "rows": 3},
	{"label": "Large", "rows": 2},
	{"label": "XL", "rows": 1},
]

# ── state ──────────────────────────────────────────────────────────
var _all_cards: Array  = []        # template Card instances (read-only)
var _deck: Dictionary  = {}        # card_name (String) -> count (int)
var _filter: String         = "All"
var _faction_filter: String = "All"
var _level_filter: String = LEVEL_FILTER_ANY
var _search_query: String = ""
var _collection_sort: String = "Default"
var _filtered_cards_cache: Array = []
var _current_page: int      = 0
var _grid_columns: int      = 1
var _page_grid_columns: int = 1
var _card_size: Vector2     = Vector2(CARD_W, CARD_H)
var _collection_rows: int   = DEFAULT_COLLECTION_ROWS
var _visible_collection_rows: int = DEFAULT_COLLECTION_ROWS
var _page_visible_collection_rows: int = DEFAULT_COLLECTION_ROWS
var _last_page_turn_ms: int = -PAGE_REPEAT_INTERVAL_MS
var _art_cache: Dictionary = {}
var _collection_mode: String = COLLECTION_MODE_CARDS
var _saved_decks_cache: Array[Dictionary] = []

# ── major UI refs ──────────────────────────────────────────────────
var _grid:             HFlowContainer
var _body_scroll:      ScrollContainer
var _body_grid:        GridContainer
var _collection_panel: PanelContainer
var _collection_host:  Control
var _deck_scroll:      ScrollContainer
var _page_label:       Label
var _prev_page_btn:    Button
var _next_page_btn:    Button
var _card_view_controls_bar: HBoxContainer
var _deck_panel:       VBoxContainer
var _preview_outer:    PanelContainer
var _preview_layout:   HBoxContainer
var _preview_text_box: VBoxContainer
var _deck_list:        VBoxContainer
var _deck_count_lbl:   Label
var _validation_lbl:   Label
var _profile_lbl:      Label
var _deck_name_edit:   LineEdit
var _saved_decks_option: OptionButton
var _saved_decks_view_btn: Button
var _saved_actions_bar: HBoxContainer
var _deck_footer_buttons: HFlowContainer
var _delete_confirm_dialog: ConfirmationDialog
var _search_edit:      LineEdit
var _tiamat_panel:     PanelContainer
var _tiamat_hint_lbl:  Label
var _tiamat_rows:      VBoxContainer
var _filter_buttons: Dictionary = {}
var _faction_buttons: Dictionary = {}
var _level_filter_buttons: Dictionary = {}
# preview
var _prev_art:         TextureRect
var _prev_name:        Label
var _prev_type:        Label
var _prev_stats:       Label
var _prev_ability:     RichTextLabel
var _prev_flavor:      Label
# per-card count badge in collection (card_name -> Label)
var _count_badges: Dictionary = {}
var _local_profile_store = null
var _active_profile_id: String = ""
var _active_player_name: String = "Player"
var _selected_saved_deck_id: String = ""
var _pending_remote_saved_deck_id: String = ""
var _online_lobby_client = null
var _remote_account_decks_cache: Array[Dictionary] = []
var _use_remote_account_decks: bool = false
var _remote_preferred_deck_id: String = ""
var _pending_delete_deck_id: String = ""
var _tiamat_slots: Array = [[], [], []]
var _tiamat_assignment_slot_index: int = -1
var _deck_id_rng := RandomNumberGenerator.new()
var _deck_undo_history: Array[Dictionary] = []

func _escape_preview_bbcode_text(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")

# ── init ───────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deck_id_rng.randomize()
	resized.connect(_queue_responsive_layout_refresh)
	_all_cards = _make_all_cards()
	_rebuild_filtered_cards_cache()
	_build_ui()
	_queue_responsive_layout_refresh()
	_ensure_local_profile_store()
	_load_profile_decks()
	_apply_default_collection_mode()
	_refresh_grid()
	_queue_collection_layout_refresh()
	_refresh_deck_panel()

func configure_profile_store(profile_store, profile_id: String, player_name: String = "") -> void:
	_local_profile_store = profile_store
	_active_profile_id = profile_id.strip_edges()
	_active_player_name = player_name.strip_edges()
	if _active_player_name.is_empty():
		_active_player_name = "Player"
	if is_inside_tree():
		_ensure_local_profile_store()
		_load_profile_decks()
		_apply_default_collection_mode()
		_refresh_collection_grid_and_layout()
		_refresh_profile_labels()

func configure_online_sync(lobby_client) -> void:
	_online_lobby_client = lobby_client

func configure_account_decks(decks: Array, use_remote: bool = false, preferred_deck_id: String = "") -> void:
	_remote_account_decks_cache.clear()
	var visible_decks: Array[Dictionary] = []
	for entry in decks:
		if entry is Dictionary:
			visible_decks.append((entry as Dictionary).duplicate(true))
	visible_decks = DeckCatalogUtilsScript.dedupe_exact_copies(
		visible_decks,
		preferred_deck_id,
		_pending_remote_saved_deck_id if not _pending_remote_saved_deck_id.is_empty() else _selected_saved_deck_id
	)
	for entry in visible_decks:
		_remote_account_decks_cache.append(entry.duplicate(true))
	_use_remote_account_decks = use_remote
	if not _use_remote_account_decks:
		_pending_remote_saved_deck_id = ""
	_remote_preferred_deck_id = preferred_deck_id.strip_edges()
	if is_inside_tree():
		_load_profile_decks()
		_apply_default_collection_mode()
		_refresh_collection_grid_and_layout()
		_refresh_profile_labels()

func _make_all_cards() -> Array:
	return CardCatalogScript.make_all_cards()

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

	var body_scroll := ScrollContainer.new()
	_body_scroll = body_scroll
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.follow_focus = true
	body_scroll.clip_contents = true
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(body_scroll)

	var body := GridContainer.new()
	_body_grid = body
	body.columns = 2
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_theme_constant_override("separation", 6)
	body_scroll.add_child(body)

	_build_collection_panel(body)
	_build_deck_panel(body)
	_build_delete_confirm_dialog()

func _build_top_bar(parent: Control) -> void:
	var bar := PanelContainer.new()
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.10, 0.10, 0.16)
	bar.add_theme_stylebox_override("panel", bar_style)
	parent.add_child(bar)

	var inner := HFlowContainer.new()
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

	var title_gap := Control.new()
	title_gap.custom_minimum_size.x = 16
	inner.add_child(title_gap)

	_add_faction_filter_controls(inner, 30)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)

	var btn_group := ButtonGroup.new()
	for label in ["All", "Gods", "Active Gods", "Powers", "Legendaries", "Creatures", "Equipment", "Charms", "Spells", "Structures", "Hexes"]:
		var btn := Button.new()
		btn.text = label
		btn.toggle_mode = true
		btn.button_group = btn_group
		btn.button_pressed = (label == _filter)
		btn.custom_minimum_size = Vector2(96 if label == "Legendaries" or label == "Active Gods" else 72, 32)
		var captured_label: String = label
		btn.pressed.connect(func() -> void: _set_filter(captured_label))
		_filter_buttons[label] = btn
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

func _add_faction_filter_controls(parent: Control, button_height: float = 26.0) -> void:
	# Collect unique cultures from card pool, sorted.
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
		btn.custom_minimum_size = Vector2(72, button_height)
		var captured: String = label
		btn.pressed.connect(func() -> void: _set_faction_filter(captured))
		_faction_buttons[label] = btn
		parent.add_child(btn)

func _add_level_filter_controls(parent: Control) -> void:
	var level_group := ButtonGroup.new()
	for label in [LEVEL_FILTER_ANY, "0", "1", "2", "3", "4", "5+"]:
		var btn := Button.new()
		btn.text = label
		btn.toggle_mode = true
		btn.button_group = level_group
		btn.button_pressed = (label == _level_filter)
		btn.custom_minimum_size = Vector2(46 if label == LEVEL_FILTER_ANY else 36, 28)
		var captured_label: String = label
		btn.pressed.connect(func() -> void: _set_level_filter(captured_label))
		_level_filter_buttons[label] = btn
		parent.add_child(btn)

func _add_card_view_controls(parent: Control) -> void:
	var view_group := ButtonGroup.new()
	for preset: Dictionary in CARD_VIEW_PRESETS:
		var btn := Button.new()
		btn.text = str(preset["label"])
		btn.toggle_mode = true
		btn.button_group = view_group
		btn.button_pressed = int(preset["rows"]) == _collection_rows
		btn.custom_minimum_size = Vector2(64, 28)
		var captured_rows: int = int(preset["rows"])
		btn.pressed.connect(func() -> void: _set_collection_rows(captured_rows))
		parent.add_child(btn)

func _build_collection_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	_collection_panel = panel
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.09, 0.13)
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)

	var view_bar := HBoxContainer.new()
	view_bar.add_theme_constant_override("separation", 6)
	content.add_child(view_bar)

	var sort_lbl := Label.new()
	sort_lbl.text = "Sort:"
	sort_lbl.add_theme_font_size_override("font_size", 11)
	sort_lbl.modulate = Color(0.7, 0.7, 0.7)
	sort_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	view_bar.add_child(sort_lbl)

	var sort_group := ButtonGroup.new()
	for label in ["Default", "Alphabetical"]:
		var sort_btn := Button.new()
		sort_btn.text = label
		sort_btn.toggle_mode = true
		sort_btn.button_group = sort_group
		sort_btn.button_pressed = (label == _collection_sort)
		sort_btn.custom_minimum_size = Vector2(108, 28)
		var captured_sort: String = label
		sort_btn.pressed.connect(func() -> void: _set_collection_sort(captured_sort))
		view_bar.add_child(sort_btn)

	var level_lbl := Label.new()
	level_lbl.text = "Level:"
	level_lbl.add_theme_font_size_override("font_size", 11)
	level_lbl.modulate = Color(0.7, 0.7, 0.7)
	level_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	view_bar.add_child(level_lbl)

	_add_level_filter_controls(view_bar)

	var search_lbl := Label.new()
	search_lbl.text = "Search:"
	search_lbl.add_theme_font_size_override("font_size", 11)
	search_lbl.modulate = Color(0.7, 0.7, 0.7)
	search_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	view_bar.add_child(search_lbl)

	var search_edit := LineEdit.new()
	_search_edit = search_edit
	search_edit.placeholder_text = "Card names or tags"
	search_edit.text = _search_query
	search_edit.clear_button_enabled = true
	search_edit.custom_minimum_size = Vector2(420, 28)
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.text_changed.connect(_set_search_query)
	view_bar.add_child(search_edit)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_bar.add_child(spacer)

	var saved_hdr := HBoxContainer.new()
	_saved_actions_bar = saved_hdr
	saved_hdr.add_theme_constant_override("separation", 6)
	saved_hdr.size_flags_horizontal = Control.SIZE_SHRINK_END
	view_bar.add_child(saved_hdr)

	var save_btn := Button.new()
	save_btn.text = "Save Deck"
	save_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	save_btn.pressed.connect(_save_profile_deck)
	saved_hdr.add_child(save_btn)

	var new_btn := Button.new()
	new_btn.text = "New Deck"
	new_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	new_btn.pressed.connect(_new_deck)
	saved_hdr.add_child(new_btn)

	_saved_decks_view_btn = Button.new()
	_saved_decks_view_btn.text = "Saved Decks"
	_saved_decks_view_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_saved_decks_view_btn.pressed.connect(_toggle_saved_decks_view)
	saved_hdr.add_child(_saved_decks_view_btn)

	_collection_host = Control.new()
	_collection_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection_host.clip_contents = true
	_collection_host.resized.connect(_queue_collection_layout_refresh)
	content.add_child(_collection_host)

	_grid = HFlowContainer.new()
	_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid.add_theme_constant_override("h_separation", int(COLLECTION_GAP))
	_grid.add_theme_constant_override("v_separation", int(COLLECTION_GAP))
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection_host.add_child(_grid)

	var page_bar := HBoxContainer.new()
	page_bar.add_theme_constant_override("separation", 6)
	page_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(page_bar)

	_prev_page_btn = Button.new()
	_prev_page_btn.text = "Previous Page"
	_prev_page_btn.custom_minimum_size = Vector2(120, 28)
	_prev_page_btn.pressed.connect(_show_previous_page)
	page_bar.add_child(_prev_page_btn)

	_page_label = Label.new()
	_page_label.text = "Page 1 / 1"
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.add_theme_font_size_override("font_size", 12)
	page_bar.add_child(_page_label)

	_next_page_btn = Button.new()
	_next_page_btn.text = "Next Page"
	_next_page_btn.custom_minimum_size = Vector2(120, 28)
	_next_page_btn.pressed.connect(_show_next_page)

	var card_view_bar := HBoxContainer.new()
	_card_view_controls_bar = card_view_bar
	card_view_bar.add_theme_constant_override("separation", 6)
	page_bar.add_child(card_view_bar)

	var view_lbl := Label.new()
	view_lbl.text = "Card View:"
	view_lbl.add_theme_font_size_override("font_size", 11)
	view_lbl.modulate = Color(0.7, 0.7, 0.7)
	view_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_view_bar.add_child(view_lbl)

	_add_card_view_controls(card_view_bar)

	var page_spacer := Control.new()
	page_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_bar.add_child(page_spacer)

	page_bar.add_child(_next_page_btn)

func _build_deck_panel(parent: Control) -> void:
	var panel := VBoxContainer.new()
	_deck_panel = panel
	panel.custom_minimum_size.x = NARROW_DECK_PANEL_WIDTH
	panel.size_flags_horizontal = Control.SIZE_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 6)
	parent.add_child(panel)

	# ── preview ──────────────────────────────────────────
	var prev_outer := PanelContainer.new()
	_preview_outer = prev_outer
	prev_outer.custom_minimum_size = Vector2(NARROW_DECK_PANEL_WIDTH, 220)
	prev_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_outer.clip_contents = true
	var prev_style := StyleBoxFlat.new()
	prev_style.bg_color = Color(0.10, 0.10, 0.16)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		prev_style.set_border_width(side as Side, 1)
	prev_style.border_color = Color(0.3, 0.3, 0.5)
	prev_outer.add_theme_stylebox_override("panel", prev_style)
	panel.add_child(prev_outer)

	var prev_hbox := HBoxContainer.new()
	_preview_layout = prev_hbox
	prev_hbox.add_theme_constant_override("separation", 6)
	prev_outer.add_child(prev_hbox)

	_prev_art = TextureRect.new()
	_prev_art.custom_minimum_size = Vector2(112, 150)
	_prev_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_prev_art.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_prev_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prev_hbox.add_child(_prev_art)

	var prev_text := VBoxContainer.new()
	_preview_text_box = prev_text
	prev_text.custom_minimum_size.x = 0
	prev_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_text.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	prev_text.add_theme_constant_override("separation", 5)
	prev_hbox.add_child(prev_text)

	_prev_name = Label.new()
	_prev_name.text = "Hover a card to preview"
	_prev_name.add_theme_font_size_override("font_size", 20)
	_prev_name.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_prev_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prev_text.add_child(_prev_name)

	_prev_type = Label.new()
	_prev_type.text = ""
	_prev_type.add_theme_font_size_override("font_size", 13)
	_prev_type.modulate = Color(0.7, 0.85, 1.0)
	_prev_type.autowrap_mode = TextServer.AUTOWRAP_OFF
	_prev_type.clip_text = true

	var details_scroll := ScrollContainer.new()
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.custom_minimum_size.y = 0
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	prev_text.add_child(details_scroll)

	var details_box := VBoxContainer.new()
	details_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_box.add_theme_constant_override("separation", 5)
	details_scroll.add_child(details_box)

	details_box.add_child(_prev_type)

	_prev_stats = Label.new()
	_prev_stats.text = ""
	_prev_stats.add_theme_font_size_override("font_size", 16)
	details_box.add_child(_prev_stats)

	_prev_ability = RichTextLabel.new()
	_prev_ability.bbcode_enabled  = true
	_prev_ability.text            = ""
	_prev_ability.autowrap_mode   = TextServer.AUTOWRAP_WORD_SMART
	_prev_ability.add_theme_font_size_override("normal_font_size", 15)
	_prev_ability.add_theme_font_size_override("bold_font_size", 15)
	_prev_ability.add_theme_color_override("default_color", Color(0.85, 0.8, 1.0))
	_prev_ability.scroll_active   = false
	_prev_ability.fit_content     = true
	_prev_ability.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_prev_ability.custom_minimum_size.y = 64
	_prev_ability.mouse_filter    = Control.MOUSE_FILTER_STOP
	details_box.add_child(_prev_ability)

	_prev_flavor = Label.new()
	_prev_flavor.text = ""
	_prev_flavor.add_theme_font_size_override("font_size", 14)
	_prev_flavor.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_prev_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prev_flavor.visible = false

	# ── deck header ──────────────────────────────────────

	# ── deck scroll list ─────────────────────────────────
	var deck_name_row := HBoxContainer.new()
	deck_name_row.add_theme_constant_override("separation", 4)
	panel.add_child(deck_name_row)

	_deck_name_edit = LineEdit.new()
	_deck_name_edit.placeholder_text = "Default Deck"
	_deck_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_name_edit.custom_minimum_size.y = 28
	deck_name_row.add_child(_deck_name_edit)

	_saved_decks_option = OptionButton.new()
	_saved_decks_option.visible = false
	_saved_decks_option.item_selected.connect(_on_saved_deck_selected)
	panel.add_child(_saved_decks_option)

	var tiamat_panel := PanelContainer.new()
	_tiamat_panel = tiamat_panel
	var tiamat_style := StyleBoxFlat.new()
	tiamat_style.bg_color = Color(0.12, 0.10, 0.08)
	tiamat_style.border_color = Color(0.44, 0.35, 0.24)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		tiamat_style.set_border_width(side as Side, 1)
	tiamat_panel.add_theme_stylebox_override("panel", tiamat_style)
	panel.add_child(tiamat_panel)

	var tiamat_box := VBoxContainer.new()
	tiamat_box.add_theme_constant_override("separation", 6)
	tiamat_panel.add_child(tiamat_box)

	var tiamat_title := Label.new()
	tiamat_title.text = "MATRIARCH SLOTS"
	tiamat_title.add_theme_font_size_override("font_size", 12)
	tiamat_title.add_theme_color_override("font_color", Color(0.92, 0.80, 0.58))
	tiamat_box.add_child(tiamat_title)

	_tiamat_hint_lbl = Label.new()
	_tiamat_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tiamat_hint_lbl.add_theme_font_size_override("font_size", 10)
	_tiamat_hint_lbl.modulate = Color(0.74, 0.74, 0.74)
	tiamat_box.add_child(_tiamat_hint_lbl)

	_tiamat_rows = VBoxContainer.new()
	_tiamat_rows.add_theme_constant_override("separation", 4)
	tiamat_box.add_child(_tiamat_rows)

	var deck_scroll := ScrollContainer.new()
	_deck_scroll = deck_scroll
	deck_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	deck_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_scroll.custom_minimum_size.y = 280
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deck_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(deck_scroll)

	_deck_list = VBoxContainer.new()
	_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_list.add_theme_constant_override("separation", 4)
	deck_scroll.add_child(_deck_list)


	# ── validation status ────────────────────────────────
	_validation_lbl = Label.new()
	_validation_lbl.text = ""
	_validation_lbl.add_theme_font_size_override("font_size", 12)
	_validation_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_validation_lbl.clip_text = true
	_validation_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(_validation_lbl)

	# ── action buttons ───────────────────────────────────
	var btns := HFlowContainer.new()
	_deck_footer_buttons = btns
	btns.add_theme_constant_override("separation", 6)
	panel.add_child(btns)

	var autofill_btn := Button.new()
	autofill_btn.text = "Auto Fill"
	autofill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	autofill_btn.pressed.connect(_autofill_deck_to_minimum)
	btns.add_child(autofill_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.pressed.connect(_clear_deck)
	btns.add_child(clear_btn)

	var pad_bot := Control.new()
	pad_bot.custom_minimum_size.y = 4
	panel.add_child(pad_bot)

func _build_delete_confirm_dialog() -> void:
	if _delete_confirm_dialog != null and is_instance_valid(_delete_confirm_dialog):
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Saved Deck?"
	dialog.dialog_text = "Delete this saved deck?"
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	dialog.exclusive = true
	dialog.get_ok_button().text = "Delete"
	dialog.get_ok_button().modulate = Color(1.0, 0.84, 0.84)
	dialog.canceled.connect(func() -> void:
		_pending_delete_deck_id = ""
	)
	dialog.confirmed.connect(_confirm_delete_saved_deck)
	add_child(dialog)
	_delete_confirm_dialog = dialog

# ── collection grid ────────────────────────────────────────────────
func _refresh_grid() -> void:
	_count_badges.clear()
	for child in _grid.get_children():
		child.queue_free()

	var total_items := _current_grid_total()
	var total_pages := _page_count(total_items)
	_current_page = clampi(_current_page, 0, total_pages - 1)

	var start_index := _current_page * _page_size()
	var end_index := mini(start_index + _page_size(), total_items)
	if _collection_mode == COLLECTION_MODE_SAVED_DECKS:
		for idx in range(start_index, end_index):
			if idx == 0:
				_grid.add_child(_make_new_deck_cover())
				continue
			var deck_idx := idx - 1
			if deck_idx >= 0 and deck_idx < _saved_decks_cache.size():
				_grid.add_child(_make_saved_deck_cover(_saved_decks_cache[deck_idx]))
	else:
		for idx in range(start_index, end_index):
			var card: Card = _filtered_cards_cache[idx]
			_grid.add_child(_make_card_item(card))

	_update_pagination_controls(total_items)
	if _collection_mode == COLLECTION_MODE_CARDS:
		_update_count_badges()

func _matches_filter(card: Card) -> bool:
	if card is ActiveGodCard:
		if _filter != "Active Gods":
			return false
	elif _filter == "Active Gods":
		return false

	if _faction_filter != "All" and card.culture != _faction_filter:
		return false
	if not _matches_level_filter(card):
		return false
	if not _matches_search_query(card):
		return false
	match _filter:
		"All":       return true
		"Gods":      return card.is_god
		"Active Gods": return card is ActiveGodCard
		"Powers":    return card.is_power and not card.is_god
		"Legendaries": return card.is_legendary and not card.is_god and not card.is_power
		"Creatures": return card.card_type == Card.CardType.CREATURE and not card.is_god
		"Equipment": return card.card_type == Card.CardType.EQUIPMENT
		"Charms":    return card.card_type == Card.CardType.CHARM
		"Spells":    return card.card_type == Card.CardType.SPELL
		"Structures":return card.card_type == Card.CardType.STRUCTURE
		"Hexes":     return card.card_type == Card.CardType.HEX
	return true

func _matches_level_filter(card: Card) -> bool:
	if _level_filter == LEVEL_FILTER_ANY:
		return true
	if _level_filter == "5+":
		return int(card.level) >= 5
	return int(card.level) == int(_level_filter)

func _matches_search_query(card: Card) -> bool:
	if _search_query.is_empty():
		return true

	var search_key := _to_search_key(_search_query)
	if search_key.is_empty():
		return true

	if _to_search_key(card.get_normalized_card_name()).contains(search_key):
		return true
	if _to_search_key(card.get_ascii_card_name()).contains(search_key):
		return true
	if _to_search_key(_get_type_label(card)).contains(search_key):
		return true
	if _to_search_key(card.culture).contains(search_key):
		return true

	for card_type: String in card.card_types:
		if _to_search_key(card_type).contains(search_key):
			return true

	return false

func _to_search_key(value: String) -> String:
	return CardCatalogScript.to_lookup_key(str(value))

func _make_card_item(card: Card) -> Control:
	var root := Control.new()
	root.custom_minimum_size = _card_size
	root.size = _card_size
	root.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var unavailable_reason := _get_card_unavailable_reason(card)
	var is_unavailable := not unavailable_reason.is_empty()
	if is_unavailable:
		root.tooltip_text = unavailable_reason
		root.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	var unavailable_badge_text := _get_card_unavailable_badge_text(card)

	# Border / background
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tc := _get_type_color(card)
	var sty := StyleBoxFlat.new()
	sty.bg_color = tc.darkened(0.75)
	sty.border_color = tc
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sty.set_border_width(side as Side, 2)
	sty.corner_radius_top_left    = 4; sty.corner_radius_top_right    = 4
	sty.corner_radius_bottom_left = 4; sty.corner_radius_bottom_right = 4
	bg.add_theme_stylebox_override("panel", sty)
	root.add_child(bg)

	# Art
	if card.art_path != "":
		var tex := _get_card_art_texture(card.art_path)
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
	name_lbl.add_theme_font_size_override("font_size", 13)
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
	type_lbl.add_theme_font_size_override("font_size", 10)
	type_lbl.add_theme_color_override("font_color", tc)
	type_lbl.anchor_left  = 0; type_lbl.anchor_top  = 0
	type_lbl.offset_left  = 4; type_lbl.offset_top  = 4
	type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(type_lbl)

	# Cost badge (top-right)
	if card.has_listed_play_costs():
		var cost_text := card.get_cost_shorthand()
		var badge_width := maxi(22, 12 + cost_text.length() * 6)
		var mana_bg := ColorRect.new()
		mana_bg.color = Color(0.1, 0.25, 0.55, 0.85)
		mana_bg.custom_minimum_size = Vector2(badge_width, 22)
		mana_bg.anchor_right  = 1; mana_bg.anchor_left  = 1
		mana_bg.anchor_top    = 0; mana_bg.anchor_bottom = 0
		mana_bg.offset_left   = -badge_width - 2; mana_bg.offset_right  = -2
		mana_bg.offset_top    = 2;   mana_bg.offset_bottom = 24
		mana_bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		root.add_child(mana_bg)

		var mana_lbl := Label.new()
		mana_lbl.text = cost_text
		mana_lbl.add_theme_font_size_override("font_size", 10 if cost_text.length() > 3 else 11)
		mana_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		mana_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mana_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		mana_lbl.anchor_right  = 1; mana_lbl.anchor_left  = 1
		mana_lbl.anchor_top    = 0; mana_lbl.anchor_bottom = 0
		mana_lbl.offset_left   = -badge_width - 2; mana_lbl.offset_right  = -2
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

	var unavailable_overlay := ColorRect.new()
	unavailable_overlay.name = "UnavailableOverlay"
	unavailable_overlay.color = Color(0.05, 0.0, 0.0, 0.62) if is_unavailable else Color(0.0, 0.0, 0.0, 0.0)
	unavailable_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	unavailable_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(unavailable_overlay)

	var unavailable_mark := Label.new()
	unavailable_mark.name = "UnavailableMark"
	unavailable_mark.text = "X" if is_unavailable else ""
	unavailable_mark.visible = is_unavailable
	unavailable_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unavailable_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	unavailable_mark.add_theme_font_size_override("font_size", 72)
	unavailable_mark.add_theme_color_override("font_color", Color(1.0, 0.24, 0.24, 0.9))
	unavailable_mark.add_theme_color_override("font_shadow_color", Color(0.08, 0.0, 0.0, 0.85))
	unavailable_mark.add_theme_constant_override("shadow_offset_x", 2)
	unavailable_mark.add_theme_constant_override("shadow_offset_y", 2)
	unavailable_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	unavailable_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(unavailable_mark)

	if is_unavailable and not unavailable_badge_text.is_empty():
		var unavailable_band := ColorRect.new()
		unavailable_band.name = "UnavailableReasonBand"
		unavailable_band.color = Color(0.35, 0.0, 0.0, 0.88)
		unavailable_band.anchor_left = 0
		unavailable_band.anchor_right = 1
		unavailable_band.anchor_top = 1
		unavailable_band.anchor_bottom = 1
		unavailable_band.offset_left = 0
		unavailable_band.offset_right = 0
		unavailable_band.offset_top = -74
		unavailable_band.offset_bottom = -44
		unavailable_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(unavailable_band)

		var unavailable_reason_lbl := Label.new()
		unavailable_reason_lbl.name = "UnavailableReasonLabel"
		unavailable_reason_lbl.text = unavailable_badge_text
		unavailable_reason_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unavailable_reason_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unavailable_reason_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		unavailable_reason_lbl.add_theme_font_size_override("font_size", 10)
		unavailable_reason_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.86))
		unavailable_reason_lbl.anchor_left = 0
		unavailable_reason_lbl.anchor_right = 1
		unavailable_reason_lbl.anchor_top = 1
		unavailable_reason_lbl.anchor_bottom = 1
		unavailable_reason_lbl.offset_left = 6
		unavailable_reason_lbl.offset_right = -6
		unavailable_reason_lbl.offset_top = -74
		unavailable_reason_lbl.offset_bottom = -44
		unavailable_reason_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(unavailable_reason_lbl)

	# Active God tag
	if card.is_god:
		var active_candidate := _get_active_god_form(card)
		if active_candidate != null:
			var active_tag := PanelContainer.new()
			active_tag.mouse_filter = Control.MOUSE_FILTER_STOP
			
			active_tag.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.pressed:
					# Prevent clicking the tag from also clicking the card under it
					get_viewport().set_input_as_handled()
			)
			
			active_tag.anchor_left = 1; active_tag.anchor_right = 1
			active_tag.anchor_top = 1; active_tag.anchor_bottom = 1
			active_tag.offset_left = -64; active_tag.offset_right = -4
			active_tag.offset_top = -62; active_tag.offset_bottom = -46			
			var tag_style := StyleBoxFlat.new()
			tag_style.bg_color = Color(0.15, 0.45, 0.15, 0.9)
			tag_style.border_color = Color(0.6, 1.0, 0.6, 0.8)
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				tag_style.set_border_width(side as Side, 1)
			tag_style.corner_radius_top_left = 4; tag_style.corner_radius_top_right = 4
			tag_style.corner_radius_bottom_left = 4; tag_style.corner_radius_bottom_right = 4
			active_tag.add_theme_stylebox_override("panel", tag_style)
			
			var tag_lbl := Label.new()
			tag_lbl.text = "ACTIVE GOD"
			tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			tag_lbl.add_theme_font_size_override("font_size", 8)
			tag_lbl.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
			active_tag.add_child(tag_lbl)
			root.add_child(active_tag)
			
			active_tag.mouse_entered.connect(func() -> void: _show_preview(active_candidate))
			active_tag.mouse_exited.connect(func() -> void: _show_preview(card))

	# Input
	root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				if is_unavailable:
					_set_status_flash(unavailable_reason)
					return
				_handle_collection_card_add(card)
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
	for card_name in _deck:
		var card := _find_template(card_name)
		if card != null:
			total += int(_deck[card_name])
	if _deck_count_lbl != null:
		_deck_count_lbl.text = "%d cards" % total

	# Sort: gods → creatures → spells → structures → hexes, then alphabetical
	var in_deck_filter := func(c: Card) -> bool:
		if not _deck.has(c.card_name) or _deck[c.card_name] <= 0:
			return false
		return true
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
			sep_lbl.add_theme_font_size_override("font_size", 11)
			sep_lbl.add_theme_color_override("font_color", _get_type_color(card).lerp(Color.WHITE, 0.3))
			_deck_list.add_child(sep_lbl)
		_deck_list.add_child(_make_deck_row(card))

	_refresh_tiamat_panel()
	_update_validation()
	_rebuild_filtered_cards_cache()
	_refresh_collection_grid_and_layout()
	_queue_responsive_layout_refresh()

func _refresh_tiamat_panel() -> void:
	if _tiamat_panel == null or _tiamat_rows == null or _tiamat_hint_lbl == null:
		return
	var show_panel := _deck_uses_tiamat() or _has_any_tiamat_slot_cards()
	_tiamat_panel.visible = show_panel
	if not show_panel:
		return

	for child in _tiamat_rows.get_children():
		child.queue_free()

	if _deck_uses_tiamat():
		if _tiamat_assignment_slot_index >= 0:
			_tiamat_hint_lbl.text = "Slot %d selected. Click Ancient Demon or Dragon cards in the collection to assign them here." % [_tiamat_assignment_slot_index + 1]
		else:
			_tiamat_hint_lbl.text = "Select a slot, then click Ancient Demon or Dragon cards in the collection to add them. Each slot may hold up to 6 total levels."
	else:
		_tiamat_hint_lbl.text = "These saved Matriarch slots only apply while Tiamat is your god."

	for slot_index in range(_tiamat_slots.size()):
		var slot_cards: Array = _tiamat_slots[slot_index]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		_tiamat_rows.add_child(row)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 4)
		row.add_child(header)

		var slot_label := Label.new()
		slot_label.text = "Slot %d  Lv %d/%d" % [
			slot_index + 1,
			_get_tiamat_slot_level_total(slot_index),
			TiamatScript.MAX_SLOT_LEVEL_TOTAL
		]
		slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_label.add_theme_font_size_override("font_size", 10)
		header.add_child(slot_label)

		var select_btn := Button.new()
		select_btn.text = "Selected" if _tiamat_assignment_slot_index == slot_index else "Select"
		select_btn.custom_minimum_size = Vector2(64, 22)
		select_btn.disabled = not _deck_uses_tiamat()
		select_btn.pressed.connect(func() -> void:
			_tiamat_assignment_slot_index = -1 if _tiamat_assignment_slot_index == slot_index else slot_index
			_refresh_deck_panel()
		)
		header.add_child(select_btn)

		var clear_btn := Button.new()
		clear_btn.text = "Clear"
		clear_btn.custom_minimum_size = Vector2(52, 22)
		clear_btn.disabled = slot_cards.is_empty()
		clear_btn.pressed.connect(func() -> void:
			_tiamat_slots[slot_index].clear()
			if _tiamat_assignment_slot_index == slot_index and _tiamat_slots[slot_index].is_empty():
				_tiamat_assignment_slot_index = -1
			_refresh_deck_panel()
		)
		header.add_child(clear_btn)

		if slot_cards.is_empty():
			var empty_label := Label.new()
			empty_label.text = "Empty"
			empty_label.add_theme_font_size_override("font_size", 10)
			empty_label.modulate = Color(0.7, 0.7, 0.7)
			row.add_child(empty_label)
			continue

		for card_name in slot_cards:
			var entry := HBoxContainer.new()
			entry.add_theme_constant_override("separation", 4)
			row.add_child(entry)

			var entry_label := Label.new()
			entry_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			entry_label.add_theme_font_size_override("font_size", 10)
			var card := _find_template(card_name)
			var card_level := card.level if card != null else 0
			entry_label.text = "%s (Lv %d)" % [card_name, card_level]
			entry.add_child(entry_label)

			var remove_btn := Button.new()
			remove_btn.text = "-"
			remove_btn.custom_minimum_size = Vector2(24, 20)
			remove_btn.pressed.connect(func() -> void:
				_remove_tiamat_slot_card(slot_index, card_name)
			)
			entry.add_child(remove_btn)

func _make_deck_row(card: Card) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 34.0

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(11, 11)
	dot.color = _get_type_color(card)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text = card.get_display_name_for_control(name_lbl)
	row.add_child(name_lbl)

	var legendary_lbl := Label.new()
	legendary_lbl.text = "L" if card.is_legendary else ""
	legendary_lbl.add_theme_font_size_override("font_size", 14)
	legendary_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.28))
	legendary_lbl.custom_minimum_size.x = 18
	legendary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(legendary_lbl)

	var cnt_lbl := Label.new()
	cnt_lbl.text = "×%d" % _deck[card.card_name]
	cnt_lbl.add_theme_font_size_override("font_size", 14)
	cnt_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
	cnt_lbl.custom_minimum_size.x = 42
	cnt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(cnt_lbl)

	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(32, 28)
	minus.pressed.connect(func() -> void: _remove_from_deck(card.card_name))
	row.add_child(minus)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(32, 28)
	plus.pressed.connect(func() -> void: _add_to_deck(card))
	row.add_child(plus)

	row.mouse_entered.connect(func() -> void: _show_preview(card))

	return row

func _handle_collection_card_add(card: Card) -> void:
	if _try_assign_card_to_tiamat_slot(card):
		return
	_add_to_deck(card)

func _deck_uses_tiamat() -> bool:
	return TiamatScript.is_tiamat_god(_get_selected_god_template())

func _has_any_tiamat_slot_cards() -> bool:
	for slot_cards in _tiamat_slots:
		if not slot_cards.is_empty():
			return true
	return false

func _get_tiamat_special_setup() -> Dictionary:
	return TiamatScript.build_special_setup(_tiamat_slots)

func _clear_tiamat_slots() -> void:
	_tiamat_slots = [[], [], []]
	_tiamat_assignment_slot_index = -1

func _count_tiamat_occupied_slots() -> int:
	var occupied := 0
	for slot_cards in _tiamat_slots:
		if not slot_cards.is_empty():
			occupied += 1
	return occupied

func _get_tiamat_slot_level_total(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= _tiamat_slots.size():
		return 0
	var total := 0
	for card_name in _tiamat_slots[slot_index]:
		var card := _find_template(card_name)
		if card != null:
			total += int(card.level)
	return total

func _find_tiamat_slot_for_card(card_name: String) -> int:
	for slot_index in range(_tiamat_slots.size()):
		if card_name in _tiamat_slots[slot_index]:
			return slot_index
	return -1

func _get_tiamat_assignment_error(card: Card, slot_index: int) -> String:
	if card == null:
		return "No card selected for Matriarch Rule."
	if not _deck_uses_tiamat():
		return "Choose Tiamat as your god before assigning Matriarch slot creatures."
	if slot_index < 0 or slot_index >= _tiamat_slots.size():
		return "Select a Matriarch slot first."
	if not TiamatScript.is_valid_slot_creature(card):
		return "Only Ancient Demons or Dragons can be assigned to Matriarch slots."
	var existing_slot := _find_tiamat_slot_for_card(card.card_name)
	if existing_slot >= 0:
		return "%s is already assigned to slot %d." % [card.card_name, existing_slot + 1]
	var new_slot_total := _get_tiamat_slot_level_total(slot_index) + int(card.level)
	if new_slot_total > TiamatScript.MAX_SLOT_LEVEL_TOTAL:
		return "Slot %d would exceed %d total levels." % [slot_index + 1, TiamatScript.MAX_SLOT_LEVEL_TOTAL]
	var occupied_slots := _count_tiamat_occupied_slots()
	if _tiamat_slots[slot_index].is_empty():
		occupied_slots += 1
	if _count_powers_in_current_deck() + occupied_slots > 3:
		return "Powers and Matriarch slots together can occupy at most 3 power slots."
	return ""

func _try_assign_card_to_tiamat_slot(card: Card) -> bool:
	if _tiamat_assignment_slot_index < 0 or card == null or not TiamatScript.is_valid_slot_creature(card):
		return false
	var error := _get_tiamat_assignment_error(card, _tiamat_assignment_slot_index)
	if not error.is_empty():
		_set_status_flash(error)
		return true
	_push_current_deck_undo_state()
	_tiamat_slots[_tiamat_assignment_slot_index].append(card.card_name)
	_refresh_deck_panel()
	_set_status_flash("%s assigned to Matriarch slot %d." % [card.card_name, _tiamat_assignment_slot_index + 1])
	return true

func _remove_tiamat_slot_card(slot_index: int, card_name: String) -> void:
	if slot_index < 0 or slot_index >= _tiamat_slots.size():
		return
	_push_current_deck_undo_state()
	_tiamat_slots[slot_index] = _tiamat_slots[slot_index].filter(func(existing_name: String) -> bool:
		return existing_name != card_name
	)
	if _tiamat_assignment_slot_index == slot_index and _tiamat_slots[slot_index].is_empty():
		_tiamat_assignment_slot_index = -1
	_refresh_deck_panel()

func _make_deck_undo_state() -> Dictionary:
	return {
		"deck": _deck.duplicate(true),
		"tiamat_slots": _tiamat_slots.duplicate(true),
		"deck_name": _deck_name_edit.text if _deck_name_edit != null else "",
		"selected_saved_deck_id": _selected_saved_deck_id,
		"pending_remote_saved_deck_id": _pending_remote_saved_deck_id,
	}

func _deck_undo_states_equal(a: Dictionary, b: Dictionary) -> bool:
	return (
		a.get("deck", {}) == b.get("deck", {})
		and a.get("tiamat_slots", []) == b.get("tiamat_slots", [])
		and str(a.get("deck_name", "")) == str(b.get("deck_name", ""))
		and str(a.get("selected_saved_deck_id", "")) == str(b.get("selected_saved_deck_id", ""))
		and str(a.get("pending_remote_saved_deck_id", "")) == str(b.get("pending_remote_saved_deck_id", ""))
	)

func _push_current_deck_undo_state() -> void:
	var snapshot := _make_deck_undo_state()
	if not _deck_undo_history.is_empty():
		var last_snapshot: Dictionary = _deck_undo_history[_deck_undo_history.size() - 1]
		if _deck_undo_states_equal(last_snapshot, snapshot):
			return
	_deck_undo_history.append(snapshot)
	if _deck_undo_history.size() > MAX_DECK_UNDO_STATES:
		_deck_undo_history.remove_at(0)

func _restore_deck_undo_state(state: Dictionary) -> void:
	_deck = (state.get("deck", {}) as Dictionary).duplicate(true)
	_tiamat_slots = (state.get("tiamat_slots", []) as Array).duplicate(true)
	_selected_saved_deck_id = str(state.get("selected_saved_deck_id", "")).strip_edges()
	_pending_remote_saved_deck_id = str(state.get("pending_remote_saved_deck_id", "")).strip_edges()
	if _deck_name_edit != null:
		_deck_name_edit.text = str(state.get("deck_name", LocalProfileStoreScript.DEFAULT_DECK_NAME))
	_select_saved_deck(_selected_saved_deck_id)
	_refresh_saved_deck_gallery(_get_saved_decks())
	_refresh_deck_panel()

func _undo_last_deck_change() -> bool:
	if _deck_undo_history.is_empty():
		return false
	var previous_state: Dictionary = _deck_undo_history[_deck_undo_history.size() - 1]
	_deck_undo_history.remove_at(_deck_undo_history.size() - 1)
	_restore_deck_undo_state(previous_state)
	_set_status_flash("Undid deck change.")
	return true

func _is_text_input_focused() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is CodeEdit

func _get_active_god_form(god: Card) -> ActiveGodCard:
	if god == null or not god.is_god:
		return null
	var god_card := god as GodCard
	if god_card == null:
		return null
	for card in _all_cards:
		var active_god := card as ActiveGodCard
		if active_god != null and god_card.is_own_active_god_card(active_god):
			return active_god
	return null

# ── deck mutation ──────────────────────────────────────────────────
func _add_to_deck(card: Card) -> void:
	var current: int = _deck.get(card.card_name, 0)
	if current >= _max_copies(card):
		return
	var unavailable_reason := _get_card_unavailable_reason(card)
	if not unavailable_reason.is_empty():
		_set_status_flash(unavailable_reason)
		return
	# Only one god allowed total
	if card.is_god:
		if not _can_add_god_to_current_deck(card):
			return

		for deck_card_name in _deck:
			var tmpl := _find_template(deck_card_name)
			if tmpl and tmpl.is_god and _deck[deck_card_name] > 0:
				return

		_push_current_deck_undo_state()

	elif card.is_power and not _can_add_power_to_current_deck(card):
		return
	elif not card.is_power:
		_push_current_deck_undo_state()

	if card.is_power:
		_push_current_deck_undo_state()
	_deck[card.card_name] = current + 1
	if card.is_god and not TiamatScript.is_tiamat_god(card):
		_clear_tiamat_slots()
	_refresh_deck_panel()
	if card.is_god:
		_focus_power_selection()

func _remove_from_deck(card_name: String) -> void:
	if not _deck.has(card_name) or _deck[card_name] <= 0:
		return

	_push_current_deck_undo_state()
	_deck[card_name] -= 1
	if _deck[card_name] == 0:
		_deck.erase(card_name)
	if not _deck_uses_tiamat():
		_clear_tiamat_slots()
	_refresh_deck_panel()

func _clear_deck() -> void:
	if _deck.is_empty() and not _has_any_tiamat_slot_cards():
		return
	_push_current_deck_undo_state()
	_deck.clear()
	_clear_tiamat_slots()
	_refresh_deck_panel()

func _autofill_deck_to_minimum() -> void:
	var current_regular_count := _count_regular_cards_in_current_deck()
	var cards_needed := maxi(0, MIN_REGULAR_CARDS - current_regular_count)
	var current_power_count := _count_powers_in_current_deck()
	var powers_needed := maxi(0, 3 - current_power_count)
	if cards_needed <= 0 and powers_needed <= 0:
		_set_status_flash("Deck already meets the auto-fill targets.")
		return

	var target_legendary_total := mini(int(MIN_REGULAR_CARDS / 10.0), _count_regular_legendary_cards_in_current_deck() + cards_needed)
	var legendary_cards_needed := maxi(0, target_legendary_total - _count_regular_legendary_cards_in_current_deck())
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var undo_history_size_before := _deck_undo_history.size()
	_push_current_deck_undo_state()
	var regular_added := 0
	regular_added += _add_random_regular_cards(rng, legendary_cards_needed, true)
	regular_added += _add_random_regular_cards(rng, cards_needed - regular_added, false)
	var powers_added := _add_random_powers(rng, powers_needed)
	var added_count := regular_added + powers_added

	if added_count <= 0:
		if _deck_undo_history.size() > undo_history_size_before:
			_deck_undo_history.remove_at(_deck_undo_history.size() - 1)
		_set_status_flash("No legal cards were available to auto-fill this deck.")
		return

	_refresh_deck_panel()
	if regular_added < cards_needed:
		_set_status_flash(
			"Auto-filled %d regular cards and %d powers, but there were not enough legal cards to reach %d regular cards."
			% [regular_added, powers_added, MIN_REGULAR_CARDS]
		)
		return
	if powers_added < powers_needed:
		_set_status_flash(
			"Auto-filled %d regular cards and %d powers. Regular cards reached %d, but fewer than 3 legal powers were available."
			% [regular_added, powers_added, MIN_REGULAR_CARDS]
		)
		return
	_set_status_flash("Auto-filled %d regular cards and %d powers." % [regular_added, powers_added])

func _add_random_regular_cards(rng: RandomNumberGenerator, count: int, legendary_only: bool) -> int:
	var added := 0
	while added < count:
		var candidates := _get_autofill_candidates(legendary_only)
		if candidates.is_empty():
			break
		var chosen: Card = candidates[rng.randi_range(0, candidates.size() - 1)]
		var copies_to_add := _get_autofill_regular_copy_count(chosen)
		if copies_to_add <= 0:
			break
		_deck[chosen.card_name] = int(_deck.get(chosen.card_name, 0)) + copies_to_add
		added += copies_to_add
	return added

func _get_autofill_regular_copy_count(card: Card) -> int:
	if card == null:
		return 0
	var current_count := int(_deck.get(card.card_name, 0))
	var remaining_copies := maxi(0, _max_copies(card) - current_count)
	if remaining_copies <= 0:
		return 0
	if card.card_name == "Hyena Pack":
		return remaining_copies
	return 1

func _add_random_powers(rng: RandomNumberGenerator, count: int) -> int:
	var added := 0
	while added < count and _count_powers_in_current_deck() < 3:
		var candidates := _get_autofill_power_candidates()
		if candidates.is_empty():
			break
		var chosen: Card = candidates[rng.randi_range(0, candidates.size() - 1)]
		_deck[chosen.card_name] = int(_deck.get(chosen.card_name, 0)) + 1
		added += 1
	return added

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
func _save_profile_deck() -> void:
	if _deck.is_empty():
		_set_status_flash("Nothing to save.")
		return
	var deck_name := _deck_name_edit.text if _deck_name_edit != null else ""
	if _uses_remote_account_decks():
		if not _can_sync_account_decks():
			_set_status_flash("Connect to the lobby to save account decks.")
			return
		var resolved_name := deck_name.strip_edges()
		if resolved_name.is_empty():
			resolved_name = LocalProfileStoreScript.DEFAULT_DECK_NAME
		if _deck_name_edit != null:
			_deck_name_edit.text = resolved_name
		if _selected_saved_deck_id.is_empty():
			_selected_saved_deck_id = _generate_saved_deck_id()
		_pending_remote_saved_deck_id = _selected_saved_deck_id
		_online_lobby_client.save_account_deck(
			resolved_name,
			_deck,
			_selected_saved_deck_id,
			_get_tiamat_special_setup()
		)
		_set_status_flash("Saving deck for %s..." % _active_player_name)
		return
	_ensure_local_profile_store()
	if _local_profile_store == null:
		print("DeckBuilder: local profile store unavailable.")
		return
	var saved_deck: Dictionary = _local_profile_store.save_deck(
		_active_profile_id,
		deck_name,
		_deck,
		_selected_saved_deck_id,
		_get_tiamat_special_setup()
	)
	_pending_remote_saved_deck_id = ""
	_selected_saved_deck_id = str(saved_deck.get("deck_id", _selected_saved_deck_id)).strip_edges()
	if _deck_name_edit != null:
		_deck_name_edit.text = str(saved_deck.get("name", _deck_name_edit.text))
	_load_profile_decks()
	_set_status_flash("Deck saved for %s." % _active_player_name)

func _load_selected_deck() -> void:
	if _selected_saved_deck_id.is_empty():
		return
	var saved_deck: Dictionary = _get_saved_deck_by_id(_selected_saved_deck_id)
	if saved_deck.is_empty():
		return
	_push_current_deck_undo_state()
	_apply_saved_deck(saved_deck)
	_set_collection_mode(COLLECTION_MODE_CARDS, false)
	_set_status_flash("Loaded %s." % str(saved_deck.get("name", "deck")))

func _delete_selected_deck() -> void:
	_request_delete_saved_deck(_selected_saved_deck_id)

func _request_delete_saved_deck(deck_id: String) -> void:
	var resolved_deck_id := deck_id.strip_edges()
	if resolved_deck_id.is_empty():
		return
	var saved_deck := _get_saved_deck_by_id(resolved_deck_id)
	if saved_deck.is_empty():
		return
	_pending_delete_deck_id = resolved_deck_id
	if _delete_confirm_dialog != null and is_instance_valid(_delete_confirm_dialog):
		_delete_confirm_dialog.dialog_text = "Delete \"%s\"? This can't be undone." % str(saved_deck.get("name", "Deck"))
		_delete_confirm_dialog.popup_centered()

func _confirm_delete_saved_deck() -> void:
	var resolved_deck_id := _pending_delete_deck_id.strip_edges()
	_pending_delete_deck_id = ""
	if resolved_deck_id.is_empty():
		return
	_delete_saved_deck(resolved_deck_id)

func _delete_saved_deck(deck_id: String) -> void:
	var deleted_deck_id: String = deck_id.strip_edges()
	if deleted_deck_id.is_empty():
		return
	var deleted_selected_deck := deleted_deck_id == _selected_saved_deck_id
	if deleted_deck_id == _pending_remote_saved_deck_id:
		_pending_remote_saved_deck_id = ""
	if _uses_remote_account_decks():
		var should_request_remote_delete := _is_synced_account_deck_id(deleted_deck_id)
		if should_request_remote_delete and not _can_sync_account_decks():
			_set_status_flash("Connect to the lobby to delete account decks.")
			return
		if deleted_selected_deck:
			_selected_saved_deck_id = ""
		if deleted_selected_deck and _deck_name_edit != null:
			_deck_name_edit.text = LocalProfileStoreScript.DEFAULT_DECK_NAME
		_remove_account_deck_locally(deleted_deck_id)
		_remove_remote_account_deck_from_cache(deleted_deck_id)
		account_deck_deleted_locally.emit(deleted_deck_id)
		_load_profile_decks()
		if should_request_remote_delete:
			_online_lobby_client.delete_account_deck(deleted_deck_id)
			_set_status_flash("Deleting saved deck...")
		else:
			_set_status_flash("Saved deck deleted.")
		return
	_ensure_local_profile_store()
	if _local_profile_store == null:
		return
	if deleted_selected_deck:
		_selected_saved_deck_id = ""
	if deleted_selected_deck and _deck_name_edit != null:
		_deck_name_edit.text = LocalProfileStoreScript.DEFAULT_DECK_NAME
	_local_profile_store.delete_deck(_active_profile_id, deleted_deck_id)
	_load_profile_decks()
	_set_status_flash("Saved deck deleted.")

func _copy_saved_deck(deck_id: String) -> void:
	var source_deck := _get_saved_deck_by_id(deck_id)
	if source_deck.is_empty():
		return
	var copied_deck_name := _make_copied_deck_name(str(source_deck.get("name", LocalProfileStoreScript.DEFAULT_DECK_NAME)))
	var copied_deck_id := _generate_saved_deck_id()
	if _uses_remote_account_decks():
		if not _can_sync_account_decks():
			_set_status_flash("Connect to the lobby to copy account decks.")
			return
		_selected_saved_deck_id = copied_deck_id
		_pending_remote_saved_deck_id = copied_deck_id
		_online_lobby_client.save_account_deck(
			copied_deck_name,
			source_deck.get("cards", {}),
			copied_deck_id,
			source_deck.get("special_setup", {})
		)
		_set_status_flash("Copying saved deck...")
		return
	_ensure_local_profile_store()
	if _local_profile_store == null:
		return
	var copied_deck: Dictionary = _local_profile_store.save_deck(
		_active_profile_id,
		copied_deck_name,
		source_deck.get("cards", {}),
		copied_deck_id,
		source_deck.get("special_setup", {})
	)
	_selected_saved_deck_id = str(copied_deck.get("deck_id", copied_deck_id)).strip_edges()
	_pending_remote_saved_deck_id = ""
	_load_profile_decks()
	_apply_saved_deck(copied_deck)
	_set_status_flash("Saved deck copied.")

func _make_copied_deck_name(source_name: String) -> String:
	var resolved_name := source_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = LocalProfileStoreScript.DEFAULT_DECK_NAME
	return "%s Copy" % resolved_name

func _apply_saved_deck_action_button_style(button: Button, accent_color: Color) -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.10, 0.12, 0.18, 0.92)
	normal_style.border_color = Color(0.42, 0.46, 0.56, 0.92)
	normal_style.corner_radius_top_left = 7
	normal_style.corner_radius_top_right = 7
	normal_style.corner_radius_bottom_left = 7
	normal_style.corner_radius_bottom_right = 7
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		normal_style.set_border_width(side as Side, 1)
	button.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(
		clampf(accent_color.r * 0.35, 0.0, 1.0),
		clampf(accent_color.g * 0.35, 0.0, 1.0),
		clampf(accent_color.b * 0.35, 0.0, 1.0),
		0.98
	)
	hover_style.border_color = accent_color
	hover_style.shadow_color = accent_color
	hover_style.shadow_size = 8
	hover_style.shadow_offset = Vector2.ZERO
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)
	button.modulate = Color(0.86, 0.90, 0.97, 0.96)
	button.mouse_entered.connect(func() -> void:
		button.modulate = accent_color.lightened(0.25)
	)
	button.mouse_exited.connect(func() -> void:
		button.modulate = Color(0.86, 0.90, 0.97, 0.96)
	)

func _is_synced_account_deck_id(deck_id: String) -> bool:
	_ensure_local_profile_store()
	var resolved_deck_id := deck_id.strip_edges()
	if _local_profile_store == null or _active_profile_id.is_empty() or resolved_deck_id.is_empty():
		return false
	for synced_deck_id in _local_profile_store.get_synced_account_deck_ids(_active_profile_id):
		if str(synced_deck_id).strip_edges() == resolved_deck_id:
			return true
	return false

func _remove_account_deck_locally(deck_id: String) -> void:
	_ensure_local_profile_store()
	var resolved_deck_id := deck_id.strip_edges()
	if _local_profile_store == null or _active_profile_id.is_empty() or resolved_deck_id.is_empty():
		return
	_local_profile_store.mark_account_decks_deleted(_active_profile_id, [resolved_deck_id])
	_local_profile_store.delete_deck(_active_profile_id, resolved_deck_id)

func _remove_remote_account_deck_from_cache(deck_id: String) -> void:
	var resolved_deck_id := deck_id.strip_edges()
	if resolved_deck_id.is_empty():
		return
	for index in range(_remote_account_decks_cache.size() - 1, -1, -1):
		if str(_remote_account_decks_cache[index].get("deck_id", "")).strip_edges() == resolved_deck_id:
			_remote_account_decks_cache.remove_at(index)

func _new_deck() -> void:
	_push_current_deck_undo_state()
	_pending_remote_saved_deck_id = ""
	_selected_saved_deck_id = ""
	_deck.clear()
	_clear_tiamat_slots()
	if _deck_name_edit != null:
		_deck_name_edit.text = LocalProfileStoreScript.DEFAULT_DECK_NAME
		_deck_name_edit.grab_focus()
		_deck_name_edit.select_all()
	_select_saved_deck("")
	_refresh_saved_deck_gallery(_get_saved_decks())
	_focus_god_selection()
	_refresh_deck_panel()
	_set_status_flash("Started a new deck.")

func _on_saved_deck_selected(index: int) -> void:
	if _saved_decks_option == null:
		return
	var metadata = _saved_decks_option.get_item_metadata(index)
	if metadata == null:
		_selected_saved_deck_id = ""
		return
	_selected_saved_deck_id = str(metadata).strip_edges()
	if not _selected_saved_deck_id.is_empty():
		_load_selected_deck()

func _ensure_local_profile_store() -> void:
	if _local_profile_store == null:
		_local_profile_store = LocalProfileStoreScript.new()
	if _active_profile_id.is_empty():
		var restored_profile: Dictionary = _local_profile_store.restore_last_profile("Player")
		_active_profile_id = str(restored_profile.get("profile_id", _active_profile_id)).strip_edges()
	var resolved_profile_name := _get_resolved_profile_name("Player")
	var profile: Dictionary = _local_profile_store.get_profile(_active_profile_id)
	if profile.is_empty():
		profile = _local_profile_store.ensure_profile(_active_profile_id, resolved_profile_name, false)
		_active_profile_id = str(profile.get("profile_id", _active_profile_id)).strip_edges()
	_active_player_name = _local_profile_store.get_profile_display_name(_active_profile_id, resolved_profile_name)

func _uses_remote_account_decks() -> bool:
	return _use_remote_account_decks

func _get_saved_decks() -> Array[Dictionary]:
	if _uses_remote_account_decks():
		var decks: Array[Dictionary] = []
		for entry in _remote_account_decks_cache:
			decks.append(entry.duplicate(true))
		return decks
	_ensure_local_profile_store()
	if _local_profile_store == null or _active_profile_id.is_empty():
		return []
	return _local_profile_store.list_decks(_active_profile_id)

func _get_saved_deck_by_id(deck_id: String) -> Dictionary:
	var resolved_deck_id := deck_id.strip_edges()
	if resolved_deck_id.is_empty():
		return {}
	for saved_deck in _get_saved_decks():
		if str(saved_deck.get("deck_id", "")).strip_edges() == resolved_deck_id:
			return saved_deck.duplicate(true)
	return {}

func _get_last_selected_saved_deck_id() -> String:
	if _uses_remote_account_decks():
		var pending_deck_id := _pending_remote_saved_deck_id.strip_edges()
		if not pending_deck_id.is_empty():
			return pending_deck_id
		var resolved_selected_deck_id := _selected_saved_deck_id.strip_edges()
		if not resolved_selected_deck_id.is_empty():
			for saved_deck in _remote_account_decks_cache:
				if str(saved_deck.get("deck_id", "")).strip_edges() == resolved_selected_deck_id:
					return resolved_selected_deck_id
		return _remote_preferred_deck_id.strip_edges()
	_ensure_local_profile_store()
	if _local_profile_store == null:
		return ""
	return str(_local_profile_store.get_last_selected_deck_id(_active_profile_id)).strip_edges()

func _remember_selected_saved_deck(deck_id: String) -> void:
	_selected_saved_deck_id = deck_id.strip_edges()
	if _uses_remote_account_decks():
		return
	_ensure_local_profile_store()
	if _local_profile_store == null or _active_profile_id.is_empty() or _selected_saved_deck_id.is_empty():
		return
	_local_profile_store.remember_last_selected_deck(_active_profile_id, _selected_saved_deck_id)

func _get_resolved_profile_name(default_name: String = "Player") -> String:
	var resolved_default := default_name.strip_edges()
	if resolved_default.is_empty():
		resolved_default = "Player"
	if _local_profile_store != null and not _active_profile_id.is_empty():
		var existing_profile: Dictionary = _local_profile_store.get_profile(_active_profile_id)
		var existing_name := str(existing_profile.get("display_name", "")).strip_edges()
		if not existing_name.is_empty():
			return existing_name
	var resolved_name := _active_player_name.strip_edges()
	if resolved_name.is_empty():
		return resolved_default
	return resolved_name

func _load_profile_decks() -> void:
	_refresh_profile_labels()
	if _saved_decks_option == null:
		return
	_saved_decks_option.clear()
	_saved_decks_option.add_item("Saved Decks")
	_saved_decks_option.set_item_metadata(0, "")
	var decks: Array[Dictionary] = _get_saved_decks()
	if not _pending_remote_saved_deck_id.is_empty():
		for deck in decks:
			if str(deck.get("deck_id", "")).strip_edges() == _pending_remote_saved_deck_id:
				_pending_remote_saved_deck_id = ""
				break
	for deck in decks:
		var saved_deck_name := str(deck.get("name", "Deck"))
		_saved_decks_option.add_item(saved_deck_name)
		_saved_decks_option.set_item_metadata(_saved_decks_option.get_item_count() - 1, str(deck.get("deck_id", "")))

	var preferred_deck_id := _get_last_selected_saved_deck_id()
	if preferred_deck_id.is_empty() and not decks.is_empty():
		preferred_deck_id = str(decks[0].get("deck_id", "")).strip_edges()
	_select_saved_deck(preferred_deck_id)
	_refresh_saved_deck_gallery(decks)
	if not preferred_deck_id.is_empty() and _deck.is_empty():
		var saved_deck: Dictionary = _get_saved_deck_by_id(preferred_deck_id)
		if not saved_deck.is_empty():
			_apply_saved_deck(saved_deck)
	elif _deck_name_edit != null and _deck_name_edit.text.strip_edges().is_empty():
		_deck_name_edit.text = LocalProfileStoreScript.DEFAULT_DECK_NAME

func _apply_default_collection_mode() -> void:
	_collection_mode = COLLECTION_MODE_SAVED_DECKS if not _saved_decks_cache.is_empty() else COLLECTION_MODE_CARDS
	_current_page = 0
	_refresh_saved_decks_view_button()

func reload_saved_decks_from_store() -> void:
	_load_profile_decks()

func _refresh_profile_labels() -> void:
	if _profile_lbl != null:
		_profile_lbl.text = _active_player_name
	if _deck_name_edit != null and _deck_name_edit.text.strip_edges().is_empty():
		_deck_name_edit.text = LocalProfileStoreScript.DEFAULT_DECK_NAME
	_refresh_saved_decks_view_button()

func _select_saved_deck(deck_id: String) -> void:
	_selected_saved_deck_id = deck_id.strip_edges()
	if _saved_decks_option == null:
		return
	for index in _saved_decks_option.get_item_count():
		var metadata = _saved_decks_option.get_item_metadata(index)
		if str(metadata).strip_edges() != _selected_saved_deck_id:
			continue
		_saved_decks_option.select(index)
		return
	_saved_decks_option.select(0)

func _apply_saved_deck(saved_deck: Dictionary) -> void:
	_selected_saved_deck_id = str(saved_deck.get("deck_id", _selected_saved_deck_id)).strip_edges()
	_pending_remote_saved_deck_id = ""
	if _deck_name_edit != null:
		_deck_name_edit.text = str(saved_deck.get("name", LocalProfileStoreScript.DEFAULT_DECK_NAME))
	_deck = {}
	var cards = saved_deck.get("cards", {})
	if cards is Dictionary:
		for raw_card_name in (cards as Dictionary).keys():
			var count := int((cards as Dictionary)[raw_card_name])
			if count > 0:
				_deck[str(raw_card_name)] = count
	_tiamat_slots = TiamatScript.get_slot_card_names_from_setup(saved_deck.get("special_setup", {}))
	if not _deck_uses_tiamat():
		_clear_tiamat_slots()
	_remember_selected_saved_deck(_selected_saved_deck_id)
	_select_saved_deck(_selected_saved_deck_id)
	_refresh_saved_deck_gallery(_get_saved_decks())
	_refresh_deck_panel()

func _refresh_saved_deck_gallery(decks: Array[Dictionary]) -> void:
	_saved_decks_cache.clear()
	_saved_decks_cache.append_array(decks)
	if _collection_mode == COLLECTION_MODE_SAVED_DECKS:
		_refresh_grid()
		_queue_collection_layout_refresh()

func _make_saved_deck_cover(saved_deck: Dictionary) -> Control:
	var deck_id := str(saved_deck.get("deck_id", "")).strip_edges()
	var saved_deck_name := str(saved_deck.get("name", "Deck")).strip_edges()
	if saved_deck_name.is_empty():
		saved_deck_name = "Deck"
	var glow_margin := 12
	var wrapper := MarginContainer.new()
	wrapper.add_theme_constant_override("margin_left", glow_margin)
	wrapper.add_theme_constant_override("margin_top", glow_margin)
	wrapper.add_theme_constant_override("margin_right", glow_margin)
	wrapper.add_theme_constant_override("margin_bottom", glow_margin)
	wrapper.custom_minimum_size = _card_size + Vector2(glow_margin * 2, glow_margin * 2)
	var cover := Button.new()
	cover.flat = false
	cover.custom_minimum_size = _card_size
	cover.focus_mode = Control.FOCUS_NONE
	cover.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cover.pressed.connect(func() -> void:
		_on_saved_deck_cover_pressed(deck_id)
	)
	wrapper.add_child(cover)

	var actions := VBoxContainer.new()
	actions.anchor_left = 1.0
	actions.anchor_right = 1.0
	actions.anchor_top = 0.0
	actions.anchor_bottom = 0.0
	actions.offset_left = -40
	actions.offset_right = -6
	actions.offset_top = 8
	actions.offset_bottom = 72
	actions.add_theme_constant_override("separation", 6)
	actions.visible = false
	actions.z_index = 10
	actions.mouse_filter = Control.MOUSE_FILTER_PASS
	cover.add_child(actions)

	var copy_btn := Button.new()
	copy_btn.text = "⎘"
	copy_btn.tooltip_text = "Copy Deck"
	copy_btn.custom_minimum_size = Vector2(32, 28)
	copy_btn.focus_mode = Control.FOCUS_NONE
	_apply_saved_deck_action_button_style(copy_btn, Color(0.92, 0.82, 0.32, 1.0))
	copy_btn.pressed.connect(func() -> void:
		_copy_saved_deck(deck_id)
	)
	copy_btn.mouse_entered.connect(func() -> void:
		actions.visible = true
	)
	copy_btn.mouse_exited.connect(func() -> void:
		_queue_saved_deck_actions_visibility_update(cover, actions)
	)
	actions.add_child(copy_btn)

	var delete_btn := Button.new()
	delete_btn.text = "🗑"
	delete_btn.tooltip_text = "Delete Deck"
	delete_btn.custom_minimum_size = Vector2(32, 28)
	delete_btn.focus_mode = Control.FOCUS_NONE
	_apply_saved_deck_action_button_style(delete_btn, Color(1.0, 0.46, 0.40, 1.0))
	delete_btn.pressed.connect(func() -> void:
		_request_delete_saved_deck(deck_id)
	)
	delete_btn.mouse_entered.connect(func() -> void:
		actions.visible = true
	)
	delete_btn.mouse_exited.connect(func() -> void:
		_queue_saved_deck_actions_visibility_update(cover, actions)
	)
	actions.add_child(delete_btn)

	var panel_style := StyleBoxFlat.new()
	var cards = saved_deck.get("cards", {})
	var god := _get_saved_deck_god_template(saved_deck)
	var glow_color := _get_saved_deck_glow_color(god)
	panel_style = _make_saved_deck_cover_style(deck_id == _selected_saved_deck_id, glow_color, false)
	cover.add_theme_stylebox_override("normal", panel_style)
	cover.add_theme_stylebox_override("hover", _make_saved_deck_cover_style(deck_id == _selected_saved_deck_id, glow_color, true))
	cover.add_theme_stylebox_override("pressed", _make_saved_deck_cover_style(deck_id == _selected_saved_deck_id, glow_color, true))
	if god != null and god.art_path != "":
		var art := TextureRect.new()
		art.texture = _get_card_art_texture(god.art_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.add_child(art)
		cover.mouse_entered.connect(func() -> void:
			actions.visible = true
			_show_preview(god)
		)
	else:
		var fallback := ColorRect.new()
		fallback.color = Color(0.18, 0.21, 0.28)
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.add_child(fallback)
		cover.mouse_entered.connect(func() -> void:
			actions.visible = true
		)
	actions.mouse_entered.connect(func() -> void:
		actions.visible = true
	)
	actions.mouse_exited.connect(func() -> void:
		_queue_saved_deck_actions_visibility_update(cover, actions)
	)
	cover.mouse_exited.connect(func() -> void:
		_queue_saved_deck_actions_visibility_update(cover, actions)
	)

	var text_band := ColorRect.new()
	text_band.color = Color(0.0, 0.0, 0.0, 0.74)
	text_band.anchor_left = 0
	text_band.anchor_right = 1
	text_band.anchor_top = 1
	text_band.anchor_bottom = 1
	text_band.offset_top = -48
	text_band.offset_bottom = 0
	text_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(text_band)

	var info := VBoxContainer.new()
	info.anchor_left = 0
	info.anchor_right = 1
	info.anchor_top = 1
	info.anchor_bottom = 1
	info.offset_left = 8
	info.offset_right = -8
	info.offset_top = -46
	info.offset_bottom = -6
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = saved_deck_name
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.82))
	info.add_child(name_lbl)

	var god_lbl := Label.new()
	god_lbl.text = _get_saved_deck_god_name(saved_deck)
	god_lbl.add_theme_font_size_override("font_size", 10)
	god_lbl.modulate = Color(0.72, 0.82, 0.96)
	info.add_child(god_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "%d cards" % _count_cards_in_dictionary(cards)
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.modulate = Color(0.82, 0.82, 0.82)
	info.add_child(count_lbl)

	return wrapper

func _make_new_deck_cover() -> Control:
	var glow_margin := 12
	var wrapper := MarginContainer.new()
	wrapper.add_theme_constant_override("margin_left", glow_margin)
	wrapper.add_theme_constant_override("margin_top", glow_margin)
	wrapper.add_theme_constant_override("margin_right", glow_margin)
	wrapper.add_theme_constant_override("margin_bottom", glow_margin)
	wrapper.custom_minimum_size = _card_size + Vector2(glow_margin * 2, glow_margin * 2)

	var cover := Button.new()
	cover.flat = false
	cover.custom_minimum_size = _card_size
	cover.focus_mode = Control.FOCUS_NONE
	cover.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cover.pressed.connect(_new_deck)
	wrapper.add_child(cover)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.16)
	style.border_color = Color(0.28, 0.32, 0.42)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side as Side, 2)
	cover.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.border_color = Color(0.95, 0.82, 0.38)
	cover.add_theme_stylebox_override("hover", hover_style)
	cover.add_theme_stylebox_override("pressed", hover_style)

	var plus_label := Label.new()
	plus_label.text = "+"
	plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus_label.add_theme_font_size_override("font_size", 56)
	plus_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.38))
	plus_label.anchor_left = 0
	plus_label.anchor_right = 1
	plus_label.anchor_top = 0
	plus_label.anchor_bottom = 1
	plus_label.offset_top = -20
	plus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(plus_label)

	var caption := Label.new()
	caption.text = "New Deck"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	caption.anchor_left = 0
	caption.anchor_right = 1
	caption.anchor_top = 1
	caption.anchor_bottom = 1
	caption.offset_top = -42
	caption.offset_bottom = -10
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(caption)

	return wrapper

func _make_saved_deck_cover_style(is_selected: bool, glow_color: Color, hovered: bool) -> StyleBoxFlat:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.13, 0.18)
	panel_style.border_color = Color(0.95, 0.82, 0.38) if is_selected else Color(0.28, 0.32, 0.42)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		panel_style.set_border_width(side as Side, 2)
	if hovered and glow_color.a > 0.0:
		panel_style.shadow_color = glow_color
		panel_style.shadow_size = 24
		panel_style.shadow_offset = Vector2.ZERO
		if not is_selected:
			panel_style.border_color = Color(0.28, 0.32, 0.42)
	return panel_style

func _get_saved_deck_glow_color(god: Card) -> Color:
	if god == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	match god.culture:
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

func _on_saved_deck_cover_pressed(deck_id: String) -> void:
	if deck_id.is_empty():
		return
	_select_saved_deck(deck_id)
	_load_selected_deck()

func _queue_saved_deck_actions_visibility_update(cover: Control, actions: Control) -> void:
	call_deferred("_update_saved_deck_actions_visibility", cover, actions)

func _update_saved_deck_actions_visibility(cover: Control, actions: Control) -> void:
	if cover == null or actions == null:
		return
	if not is_instance_valid(cover) or not is_instance_valid(actions):
		return
	var mouse_position := cover.get_global_mouse_position()
	var cover_rect := Rect2(cover.global_position, cover.size)
	actions.visible = cover_rect.has_point(mouse_position)

func _make_saved_decks_empty_state() -> Control:
	var empty_state := PanelContainer.new()
	empty_state.custom_minimum_size = Vector2(maxf(260.0, _card_size.x * 1.8), maxf(160.0, _card_size.y * 0.8))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.16)
	style.border_color = Color(0.22, 0.26, 0.34)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side as Side, 1)
	empty_state.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "No saved decks yet.\nBuild a deck and press Save Deck."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(0.82, 0.82, 0.86)
	empty_state.add_child(label)
	return empty_state

func _get_saved_deck_god_template(saved_deck: Dictionary) -> Card:
	var cards = saved_deck.get("cards", {})
	if not (cards is Dictionary):
		return null
	for raw_card_name in (cards as Dictionary).keys():
		if int((cards as Dictionary)[raw_card_name]) <= 0:
			continue
		var card := _find_template(str(raw_card_name))
		if card != null and card.is_god:
			return card
	return null

func _get_saved_deck_god_name(saved_deck: Dictionary) -> String:
	var god := _get_saved_deck_god_template(saved_deck)
	if god == null:
		return "No god selected"
	return god.get_display_name_for_control(null)

func _count_cards_in_dictionary(cards) -> int:
	if not (cards is Dictionary):
		return 0
	var total := 0
	for value in (cards as Dictionary).values():
		total += int(value)
	return total

func _can_sync_account_decks() -> bool:
	if _online_lobby_client == null or not is_instance_valid(_online_lobby_client):
		return false
	if str(_online_lobby_client.current_account_id).strip_edges().is_empty():
		return false
	return _online_lobby_client.is_authenticated()

func _set_status_flash(message: String) -> void:
	if _validation_lbl == null:
		return
	_validation_lbl.text = "%s\n%s" % [message, _validation_lbl.text]
	get_tree().create_timer(2.0).timeout.connect(
		func() -> void:
			if is_instance_valid(_validation_lbl):
				_update_validation()
	)

func _update_validation() -> void:
	var regular_count_summary := 0
	var legendary_count_summary := 0
	var selected_god_template := _get_selected_god_template() as GodCard

	for card_name: String in _deck:
		var cnt: int = _deck[card_name]
		var card := _find_template(card_name)
		if card == null or card.is_god or card.is_power:
			continue
		if _is_illegal_active_god_for_god(card, selected_god_template):
			continue
		regular_count_summary += cnt
		if card.is_legendary:
			legendary_count_summary += cnt

	var max_legends_summary := int(regular_count_summary / 10.0)
	var summary_ok := regular_count_summary >= MIN_REGULAR_CARDS and legendary_count_summary <= max_legends_summary
	_validation_lbl.text = "Card Count: %d / %d      Legendaries: %d / %d" % [
		regular_count_summary,
		MIN_REGULAR_CARDS,
		legendary_count_summary,
		max_legends_summary
	]
	_validation_lbl.modulate = Color(0.5, 1.0, 0.55) if summary_ok else Color(1.0, 0.85, 0.45)
	_validation_lbl.tooltip_text = ""

func _legacy_validation_details() -> void:
	var total := 0
	var god_count := 0
	var power_count := 0
	var regular_count := 0
	var legendary_count := 0
	var tiamat_slot_count := _count_tiamat_occupied_slots()
	var invalid_culture_cards: PackedStringArray = []
	var illegal_active_gods: PackedStringArray = []
	var duplicate_powers: PackedStringArray = []
	var god_culture := ""
	var god_name := ""
	var god_template: GodCard = null

	for card_name: String in _deck:
		var cnt: int = _deck[card_name]
		var card := _find_template(card_name)
		if card == null:
			continue
		total += cnt
		if card.is_god:
			god_count += cnt
			if god_name == "":
				god_name = card.card_name
				god_culture = card.culture
				god_template = card as GodCard
		elif card.is_power and not card.is_god:
			power_count += cnt
			if cnt > 1:
				duplicate_powers.append(card.card_name)
		else:
			regular_count += cnt
			if card.is_legendary:
				legendary_count += cnt

	if god_culture != "":
		for card_name: String in _deck:
			var card := _find_template(card_name)
			if card == null or card.is_god:
				continue
			if card is ActiveGodCard:
				if _is_illegal_active_god_for_god(card, god_template):
					illegal_active_gods.append(card.card_name)
					var illegal_count := int(_deck.get(card_name, 0))
					regular_count -= illegal_count
					if card.is_legendary:
						legendary_count -= illegal_count
				continue
			if god_template != null and god_template.uses_culture_locked_deckbuilding():
				if not god_template.can_include_card_in_culture_locked_deck(card):
					invalid_culture_cards.append(card.card_name)
			elif card.is_power and not _is_power_compatible_with_culture(card, god_culture):
				invalid_culture_cards.append(card.card_name)

	var max_legends := int(regular_count / 10.0)
	var lines: PackedStringArray = []
	var ok := true
	var occupied_power_slots := power_count + tiamat_slot_count

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

	if occupied_power_slots <= 3:
		lines.append("✓ Occupied Power Slots: %d / 3" % occupied_power_slots)
	else:
		lines.append("✗ Occupied Power Slots: %d / 3" % occupied_power_slots); ok = false

	if duplicate_powers.is_empty():
		lines.append("✓ Power copies: unique")
	else:
		lines.append("✗ Power copies: %s" % ", ".join(duplicate_powers)); ok = false

	if invalid_culture_cards.is_empty():
		if god_template != null and god_template.uses_culture_locked_deckbuilding():
			lines.append("✓ Deck culture: Neutral or %s" % god_culture)
		elif god_culture != "":
			lines.append("✓ Power culture: Neutral or %s" % god_culture)
	elif god_name != "":
		if god_template != null and god_template.uses_culture_locked_deckbuilding():
			lines.append("✗ Deck culture: %s" % ", ".join(invalid_culture_cards)); ok = false
		else:
			lines.append("✗ Power culture: %s" % ", ".join(invalid_culture_cards)); ok = false

	if legendary_count <= max_legends:
		lines.append("✓ Legendaries: %d / %d" % [legendary_count, max_legends])
	else:
		lines.append("✗ Legendaries: %d / %d" % [legendary_count, max_legends]); ok = false

	if regular_count < MIN_REGULAR_CARDS:
		lines.append("✗ Regular Cards: %d (min %d, God/Powers excluded)" % [regular_count, MIN_REGULAR_CARDS]); ok = false
	else:
		lines.append("✓ Regular Cards: %d / %d" % [regular_count, MIN_REGULAR_CARDS])

	if _deck_uses_tiamat() or tiamat_slot_count > 0:
		if _deck_uses_tiamat():
			lines.append("✓ Matriarch Rule: enabled")
		else:
			lines.append("✗ Matriarch Rule: requires Tiamat as your god"); ok = false
		lines.append("  Matriarch Slots: %d / %d" % [tiamat_slot_count, TiamatScript.POWER_SLOT_COUNT])
		for slot_index in range(TiamatScript.POWER_SLOT_COUNT):
			var slot_total := _get_tiamat_slot_level_total(slot_index)
			if slot_total <= TiamatScript.MAX_SLOT_LEVEL_TOTAL:
				lines.append("  Slot %d Levels: %d / %d" % [slot_index + 1, slot_total, TiamatScript.MAX_SLOT_LEVEL_TOTAL])
			else:
				lines.append("✗ Slot %d Levels: %d / %d" % [slot_index + 1, slot_total, TiamatScript.MAX_SLOT_LEVEL_TOTAL]); ok = false

	if illegal_active_gods.is_empty():
		if god_template != null:
			lines.append("✓ Active Gods: own form excluded")
	else:
		lines.append("✗ Active Gods: illegal in main deck: %s" % ", ".join(illegal_active_gods)); ok = false

	lines.append("  Total Cards: %d" % total)

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
		_prev_art.texture = _get_card_art_texture(card.art_path)
	else:
		_prev_art.texture = null

	_prev_name.text = card.get_display_name_for_control(_prev_name)

	var type_parts: PackedStringArray = [_get_type_label(card)]
	if card.culture != "":
		type_parts.append(card.culture)
	if card.card_types.size() > 0:
		type_parts.append("/".join(Array(card.card_types)))
	_prev_type.text = " · ".join(type_parts)
	_prev_type.tooltip_text = _prev_type.text
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
	if card.has_listed_play_costs():
		stat_parts.append("Cost: " + card.get_cost_shorthand())
	_prev_stats.text = "  ".join(stat_parts)

	var preview_body := ""
	if card.ability_text != "":
		preview_body = BaseCard.apply_keyword_hints(card.ability_text)
	if card.flavor_text != "":
		var escaped_flavor := _escape_preview_bbcode_text(card.flavor_text)
		if not preview_body.is_empty():
			preview_body += "\n\n[color=#7f7f89][i]%s[/i][/color]" % escaped_flavor
		else:
			preview_body = "[color=#7f7f89][i]%s[/i][/color]" % escaped_flavor
	_prev_ability.text = preview_body
	_prev_ability.custom_minimum_size.y = 64 if not preview_body.is_empty() else 0
	_prev_flavor.text = ""

# ── filter ─────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed:
		return
	if _try_handle_deck_undo_shortcut(key_event):
		get_viewport().set_input_as_handled()
		return
	if _try_handle_page_key(key_event.keycode, key_event.echo):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed:
		return
	if _try_handle_deck_undo_shortcut(key_event):
		get_viewport().set_input_as_handled()
		return
	if _try_handle_page_key(key_event.keycode, key_event.echo):
		get_viewport().set_input_as_handled()

func _set_filter(new_filter: String) -> void:
	_set_collection_mode(COLLECTION_MODE_CARDS, false)
	_filter = new_filter
	_current_page = 0
	_refresh_filter_button_states()
	_rebuild_filtered_cards_cache()
	_refresh_collection_grid_and_layout()

func _set_faction_filter(new_faction: String) -> void:
	_set_collection_mode(COLLECTION_MODE_CARDS, false)
	_faction_filter = new_faction
	_current_page = 0
	_refresh_faction_button_states()
	_rebuild_filtered_cards_cache()
	_refresh_collection_grid_and_layout()

func _set_level_filter(new_filter: String) -> void:
	_set_collection_mode(COLLECTION_MODE_CARDS, false)
	_level_filter = new_filter
	_current_page = 0
	_refresh_level_filter_button_states()
	_rebuild_filtered_cards_cache()
	_refresh_collection_grid_and_layout()

func _set_search_query(new_query: String) -> void:
	_set_collection_mode(COLLECTION_MODE_CARDS, false)
	var normalized_query := new_query.strip_edges()
	if normalized_query == _search_query:
		return
	_search_query = normalized_query
	_current_page = 0
	_rebuild_filtered_cards_cache()
	_refresh_collection_grid_and_layout()

func _set_collection_rows(rows: int) -> void:
	if rows == _collection_rows:
		return
	_collection_rows = max(1, rows)
	_current_page = 0
	_refresh_collection_grid_and_layout()

func _set_collection_sort(new_sort: String) -> void:
	if new_sort == _collection_sort:
		return
	_set_collection_mode(COLLECTION_MODE_CARDS, false)
	_collection_sort = new_sort
	_current_page = 0
	_rebuild_filtered_cards_cache()
	_refresh_collection_grid_and_layout()

# helpers
func _refresh_collection_grid_and_layout() -> void:
	_refresh_grid()
	_update_count_badges()
	if is_instance_valid(_collection_host) and is_instance_valid(_grid) and _collection_host.size.x > 0.0 and _collection_host.size.y > 0.0:
		_update_collection_layout()
	else:
		_queue_collection_layout_refresh()

func _show_previous_page() -> void:
	if _current_page <= 0:
		return
	_current_page -= 1
	_refresh_grid()

func _show_next_page() -> void:
	var total_pages := _page_count(_current_grid_total())
	if _current_page >= total_pages - 1:
		return
	_current_page += 1
	_refresh_grid()

func _try_handle_page_key(keycode: Key, is_echo: bool) -> bool:
	if keycode != KEY_LEFT and keycode != KEY_RIGHT:
		return false

	if is_echo:
		var now := Time.get_ticks_msec()
		if now - _last_page_turn_ms < PAGE_REPEAT_INTERVAL_MS:
			return true
		_last_page_turn_ms = now
	else:
		_last_page_turn_ms = Time.get_ticks_msec()

	if keycode == KEY_LEFT:
		_show_previous_page()
	else:
		_show_next_page()
	return true

func _try_handle_deck_undo_shortcut(key_event: InputEventKey) -> bool:
	if key_event.echo:
		return false
	if _is_text_input_focused():
		return false
	if key_event.alt_pressed or key_event.shift_pressed:
		return false
	if key_event.keycode != KEY_Z:
		return false
	if not key_event.ctrl_pressed and not key_event.meta_pressed:
		return false
	return _undo_last_deck_change()

func _queue_collection_layout_refresh() -> void:
	call_deferred("_update_collection_layout")

func _queue_responsive_layout_refresh() -> void:
	call_deferred("_update_responsive_layout")

func _update_responsive_layout() -> void:
	if not is_instance_valid(_deck_panel) or not is_instance_valid(_body_grid):
		return

	var viewport_width := size.x
	var viewport_height := size.y
	if viewport_width <= 0.0:
		return

	var use_stacked_layout := viewport_width < STACKED_LAYOUT_WIDTH_THRESHOLD
	var body_available_height := 0.0
	if is_instance_valid(_body_scroll) and _body_scroll.size.y > 0.0:
		body_available_height = _body_scroll.size.y
	else:
		var body_top := _body_scroll.position.y if is_instance_valid(_body_scroll) else 84.0
		body_available_height = maxf(0.0, viewport_height - body_top - 18.0)
	body_available_height = maxf(0.0, body_available_height - 12.0)
	var column_available_height := body_available_height
	if not use_stacked_layout:
		column_available_height = maxf(0.0, body_available_height - DESKTOP_LAYOUT_BOTTOM_CLEARANCE)
	_body_grid.columns = 1 if use_stacked_layout else 2
	_body_grid.custom_minimum_size.x = maxf(0.0, viewport_width - 16.0)
	_body_grid.custom_minimum_size.y = column_available_height * (2.0 if use_stacked_layout else 1.0)
	if is_instance_valid(_body_scroll):
		_body_scroll.custom_minimum_size.y = 0.0
		_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if use_stacked_layout else ScrollContainer.SCROLL_MODE_DISABLED
		_body_scroll.scroll_vertical = 0

	var target_panel_width := clampf(floor(viewport_width * 0.34), MIN_DECK_PANEL_WIDTH, MAX_DECK_PANEL_WIDTH)
	if use_stacked_layout:
		target_panel_width = max(MIN_DECK_PANEL_WIDTH, viewport_width - 24.0)
	else:
		if viewport_width < 1100.0:
			target_panel_width = min(target_panel_width, NARROW_DECK_PANEL_WIDTH)
		if viewport_width < 860.0:
			target_panel_width = MIN_DECK_PANEL_WIDTH

	_deck_panel.custom_minimum_size.x = target_panel_width
	_deck_panel.custom_minimum_size.y = column_available_height
	_deck_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if use_stacked_layout else Control.SIZE_FILL
	_deck_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if is_instance_valid(_collection_panel):
		_collection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_collection_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_collection_panel.custom_minimum_size.y = column_available_height
	if is_instance_valid(_collection_host):
		_collection_host.custom_minimum_size.y = maxf(196.0, column_available_height - 84.0)

	var preview_height := 252.0
	if is_instance_valid(_preview_outer):
		if target_panel_width <= COMPACT_PREVIEW_WIDTH_THRESHOLD:
			preview_height = 212.0
		if viewport_height < 1200.0:
			preview_height = min(preview_height, 228.0)
		if viewport_height < 900.0:
			preview_height = min(preview_height, 204.0)
		if viewport_height < 800.0:
			preview_height = min(preview_height, 184.0)
		if viewport_height < 720.0:
			preview_height = min(preview_height, 164.0)
		_preview_outer.custom_minimum_size = Vector2(target_panel_width, preview_height)

	if is_instance_valid(_preview_layout):
		_preview_layout.add_theme_constant_override("separation", 4 if target_panel_width <= COMPACT_PREVIEW_WIDTH_THRESHOLD else 6)

	if is_instance_valid(_prev_art):
		if target_panel_width <= COMPACT_PREVIEW_WIDTH_THRESHOLD:
			_prev_art.custom_minimum_size = Vector2(80, 108)
		else:
			_prev_art.custom_minimum_size = Vector2(104, 140)

	if is_instance_valid(_preview_text_box):
		_preview_text_box.custom_minimum_size.x = 0

	if is_instance_valid(_deck_scroll):
		var visible_child_count := 0
		var fixed_deck_panel_height := 0.0
		for child in _deck_panel.get_children():
			if not (child is Control):
				continue
			var control_child := child as Control
			if not control_child.visible:
				continue
			visible_child_count += 1
			if control_child == _deck_scroll:
				continue
			fixed_deck_panel_height += control_child.get_combined_minimum_size().y

		var deck_panel_separation := float(_deck_panel.get_theme_constant("separation"))
		fixed_deck_panel_height += maxf(0.0, float(visible_child_count - 1)) * deck_panel_separation
		var deck_scroll_height := maxf(72.0, column_available_height - fixed_deck_panel_height)
		_deck_scroll.custom_minimum_size.y = deck_scroll_height

	if is_instance_valid(_prev_page_btn):
		var page_button_width := 96.0 if viewport_width < 1100.0 else 120.0
		_prev_page_btn.custom_minimum_size.x = page_button_width
	if is_instance_valid(_next_page_btn):
		var next_button_width := 96.0 if viewport_width < 1100.0 else 120.0
		_next_page_btn.custom_minimum_size.x = next_button_width

func _update_collection_layout() -> void:
	if not is_instance_valid(_collection_host) or not is_instance_valid(_grid):
		return

	var available: Vector2 = _collection_host.size
	if available.x <= 0.0 or available.y <= 0.0:
		return

	var total_items := _current_grid_total()
	var aspect: float = CARD_W / float(CARD_H)
	var previous_page_grid_columns := _page_grid_columns
	var previous_page_visible_rows := _page_visible_collection_rows
	var columns := 1
	var next_size := Vector2(CARD_W, CARD_H)
	var visible_rows := 1
	var max_card_height := 1.0
	var width_limited := 1.0
	var estimated_width := 1.0
	var height_from_width := 1.0

	if _collection_mode == COLLECTION_MODE_SAVED_DECKS and total_items > 0:
		if total_items <= 2:
			columns = 1
		elif total_items <= 4:
			columns = 2
		else:
			columns = 3

		var target_rows := maxi(1, int(ceil(total_items / float(columns))))
		max_card_height = floor((available.y - COLLECTION_GAP * float(target_rows - 1)) / float(target_rows))
		max_card_height = max(max_card_height, 1.0)
		width_limited = floor((available.x - COLLECTION_GAP * float(columns - 1)) / float(columns))
		estimated_width = floor(max_card_height * aspect)
		height_from_width = floor(width_limited / aspect)

		if height_from_width < max_card_height:
			max_card_height = height_from_width
			estimated_width = width_limited
		else:
			estimated_width = floor(max_card_height * aspect)

		next_size = Vector2(max(1.0, estimated_width), max(1.0, max_card_height))
		visible_rows = target_rows
		_page_grid_columns = columns
		_page_visible_collection_rows = visible_rows
	else:
		var base_max_card_height = floor((available.y - COLLECTION_GAP * float(_collection_rows - 1)) / float(_collection_rows))
		base_max_card_height = max(base_max_card_height, 1.0)
		var base_estimated_width = floor(base_max_card_height * aspect)
		var base_columns = max(1, int(floor((available.x + COLLECTION_GAP) / max(1.0, base_estimated_width + COLLECTION_GAP))))
		var base_width_limited = floor((available.x - COLLECTION_GAP * float(base_columns - 1)) / float(base_columns))
		var base_height_from_width = floor(base_width_limited / aspect)

		if base_height_from_width < base_max_card_height:
			base_max_card_height = base_height_from_width
			base_estimated_width = base_width_limited
		else:
			base_estimated_width = floor(base_max_card_height * aspect)

		var base_card_size := Vector2(max(1.0, base_estimated_width), max(1.0, base_max_card_height))
		var base_visible_rows := maxi(1, mini(_collection_rows, int(floor((available.y + COLLECTION_GAP) / max(1.0, base_card_size.y + COLLECTION_GAP)))))
		next_size = base_card_size
		columns = base_columns
		visible_rows = base_visible_rows
		_page_grid_columns = columns
		_page_visible_collection_rows = visible_rows

	_grid.custom_minimum_size.y = visible_rows * next_size.y + COLLECTION_GAP * float(visible_rows - 1)

	if columns != _grid_columns \
			or next_size != _card_size \
			or visible_rows != _visible_collection_rows \
			or previous_page_grid_columns != _page_grid_columns \
			or previous_page_visible_rows != _page_visible_collection_rows:
		_grid_columns = columns
		_card_size = next_size
		_visible_collection_rows = visible_rows
		_refresh_grid()
		return

	_update_pagination_controls(_current_grid_total())

func _filtered_cards() -> Array:
	return _filtered_cards_cache

func _rebuild_filtered_cards_cache() -> void:
	_filtered_cards_cache.clear()
	var selected_god := _get_selected_god_template()
	for card in _all_cards:
		if selected_god != null and card.is_god and _filter != "Gods":
			continue
		if _matches_filter(card):
			_filtered_cards_cache.append(card)
	if _collection_sort == "Alphabetical":
		_filtered_cards_cache.sort_custom(_alphabetical_card_less)

func _alphabetical_card_less(a: Card, b: Card) -> bool:
	var a_name := a.get_normalized_card_name().to_lower()
	var b_name := b.get_normalized_card_name().to_lower()
	if a_name == b_name:
		return a.card_name < b.card_name
	return a_name < b_name

func _get_card_art_texture(art_path: String) -> Texture2D:
	if art_path == "":
		return null
	if _art_cache.has(art_path):
		return _art_cache[art_path] as Texture2D
	var tex := load(art_path) as Texture2D
	_art_cache[art_path] = tex
	return tex

func _page_size() -> int:
	return max(1, _page_grid_columns * _page_visible_collection_rows)

func _page_count(total_cards: int) -> int:
	if total_cards <= 0:
		return 1
	return max(1, int(ceil(total_cards / float(_page_size()))))

func _update_pagination_controls(total_cards: int) -> void:
	if not is_instance_valid(_page_label):
		return

	var total_pages := _page_count(total_cards)
	var shown_start := 0
	var shown_end := 0
	if total_cards > 0:
		shown_start = _current_page * _page_size() + 1
		shown_end = mini((_current_page + 1) * _page_size(), total_cards)

	var item_label := "cards" if _collection_mode == COLLECTION_MODE_CARDS else "saved decks"
	_page_label.text = "Page %d / %d    %d-%d of %d %s" % [_current_page + 1, total_pages, shown_start, shown_end, total_cards, item_label]
	_prev_page_btn.disabled = (_current_page <= 0)
	_next_page_btn.disabled = (_current_page >= total_pages - 1)

func _current_grid_total() -> int:
	if _collection_mode == COLLECTION_MODE_SAVED_DECKS:
		return _saved_decks_cache.size() + 1
	return _filtered_cards_cache.size()

func _toggle_saved_decks_view() -> void:
	if _collection_mode == COLLECTION_MODE_SAVED_DECKS:
		_set_collection_mode(COLLECTION_MODE_CARDS)
	else:
		_set_collection_mode(COLLECTION_MODE_SAVED_DECKS)

func _set_collection_mode(mode: String, reset_page: bool = true) -> void:
	if mode != COLLECTION_MODE_CARDS and mode != COLLECTION_MODE_SAVED_DECKS:
		return
	if _collection_mode == mode:
		_refresh_saved_decks_view_button()
		_queue_collection_layout_refresh()
		return
	_collection_mode = mode
	if reset_page:
		_current_page = 0
	_refresh_saved_decks_view_button()
	_refresh_grid()
	_queue_collection_layout_refresh()

func _refresh_saved_decks_view_button() -> void:
	if _saved_decks_view_btn == null:
		return
	_saved_decks_view_btn.text = "Back to Cards" if _collection_mode == COLLECTION_MODE_SAVED_DECKS else "Saved Decks"
	if _card_view_controls_bar != null:
		_card_view_controls_bar.visible = (_collection_mode == COLLECTION_MODE_CARDS)

func _generate_saved_deck_id() -> String:
	var existing_deck_ids: Dictionary = {}
	for saved_deck in _get_saved_decks():
		var deck_id := str(saved_deck.get("deck_id", "")).strip_edges()
		if not deck_id.is_empty():
			existing_deck_ids[deck_id] = true
	if not _pending_remote_saved_deck_id.is_empty():
		existing_deck_ids[_pending_remote_saved_deck_id] = true
	for _attempt in range(32):
		var candidate := "deck_%d%06d" % [
			int(Time.get_unix_time_from_system()),
			_deck_id_rng.randi_range(0, 999999),
		]
		if not existing_deck_ids.has(candidate):
			return candidate
	return "deck_%d" % int(Time.get_ticks_usec())

func _max_copies(card: Card) -> int:
	if card.is_god:       return 1
	if card.is_power:     return 1
	if card.is_legendary: return 1
	return 3

func _get_autofill_candidates(legendary_only: bool) -> Array[Card]:
	var candidates: Array[Card] = []
	var god := _get_selected_god_template() as GodCard
	for card: Card in _all_cards:
		if not _can_autofill_regular_card(card, god, legendary_only):
			continue
		candidates.append(card)
	return candidates

func _get_autofill_power_candidates() -> Array[Card]:
	var candidates: Array[Card] = []
	var god := _get_selected_god_template() as GodCard
	for card: Card in _all_cards:
		if not _can_autofill_power_card(card, god):
			continue
		candidates.append(card)
	return candidates

func _count_regular_cards_in_current_deck() -> int:
	var total := 0
	var god := _get_selected_god_template() as GodCard
	for card_name: String in _deck:
		var card := _find_template(card_name)
		if not _is_regular_card(card):
			continue
		if _is_illegal_active_god_for_god(card, god):
			continue
		total += int(_deck.get(card_name, 0))
	return total

func _count_powers_in_current_deck() -> int:
	var total := 0
	for card_name: String in _deck:
		var card := _find_template(card_name)
		if card == null or not card.is_power or card.is_god:
			continue
		total += int(_deck.get(card_name, 0))
	return total

func _count_regular_legendary_cards_in_current_deck() -> int:
	var total := 0
	var god := _get_selected_god_template() as GodCard
	for card_name: String in _deck:
		var card := _find_template(card_name)
		if not _is_regular_card(card) or not card.is_legendary:
			continue
		if _is_illegal_active_god_for_god(card, god):
			continue
		total += int(_deck.get(card_name, 0))
	return total

func _is_regular_card(card: Card) -> bool:
	return card != null and not card.is_god and not card.is_power

func _can_autofill_regular_card(card: Card, god: GodCard, legendary_only: bool) -> bool:
	if not _is_regular_card(card):
		return false
	if legendary_only and not card.is_legendary:
		return false
	if not legendary_only and card.is_legendary:
		return false
	if int(_deck.get(card.card_name, 0)) >= _max_copies(card):
		return false
	if god == null:
		return card is not ActiveGodCard
	return _is_card_compatible_with_selected_god(card, god)

func _can_autofill_power_card(card: Card, god: GodCard) -> bool:
	if card == null or not card.is_power or card.is_god:
		return false
	if int(_deck.get(card.card_name, 0)) >= _max_copies(card):
		return false
	if god == null:
		return str(card.culture).strip_edges() == "Neutral"
	return _is_card_compatible_with_selected_god(card, god)

func _find_template(card_name: String) -> Card:
	for card: Card in _all_cards:
		if card.card_name == card_name:
			return card
	return null

func _get_selected_god_template() -> Card:
	for card_name: String in _deck:
		var card := _find_template(card_name)
		if card != null and card.is_god and _deck.get(card_name, 0) > 0:
			return card
	return null

func _get_card_unavailable_badge_text(card: Card) -> String:
	if card == null:
		return ""
	var god := _get_selected_god_template() as GodCard
	if card is ActiveGodCard:
		if god == null:
			return "Pick God First"
		var active_god := card as ActiveGodCard
		if god.get_active_god_deck_role(active_god) == GodCard.ACTIVE_GOD_DECK_ROLE_ALLOWED:
			return ""
		return "Own Active God" if god.is_own_active_god_card(active_god) else "Unavailable"
	if god != null and not card.is_god and not _is_card_compatible_with_selected_god(card, god):
		return "Needs %s or Neutral" % god.culture
	if card.is_god and not _can_add_god_to_current_deck(card):
		var god_card := card as GodCard
		return "Conflicts with deck" if god_card != null and god_card.uses_culture_locked_deckbuilding() else "Conflicts with powers"
	return ""

func _get_card_unavailable_reason(card: Card) -> String:
	if card == null:
		return ""
	var god := _get_selected_god_template() as GodCard
	if card is ActiveGodCard:
		if god == null:
			return "Unavailable: choose a god before adding Active God cards."
		var active_god := card as ActiveGodCard
		match god.get_active_god_deck_role(active_god):
			GodCard.ACTIVE_GOD_DECK_ROLE_ALLOWED:
				return ""
			GodCard.ACTIVE_GOD_DECK_ROLE_RESERVED:
				return "Unavailable: %s summons its own Active God separately; it cannot go in the main deck." % god.get_display_name_for_control()
			_:
				if god.uses_culture_locked_deckbuilding():
					return "Unavailable: %s decks can only include off-god Active Gods from %s or Neutral." % [
						god.get_display_name_for_control(),
						god.culture
					]
				return "Unavailable: only Patriarch and Matriarch decks can include off-god Active Gods."
	if god != null and not card.is_god and not _is_card_compatible_with_selected_god(card, god):
		if god.uses_culture_locked_deckbuilding():
			return "Unavailable: %s decks can only use %s or Neutral cards. %s is %s." % [
				god.get_display_name_for_control(),
				god.culture,
				card.get_display_name_for_control(),
				card.culture
			]
		return "Unavailable: %s decks can only use %s or Neutral powers. %s is %s." % [
			god.get_display_name_for_control(),
			god.culture,
			card.get_display_name_for_control(),
			card.culture
		]
	if card.is_god and not _can_add_god_to_current_deck(card):
		var god_card := card as GodCard
		if god_card != null and god_card.uses_culture_locked_deckbuilding():
			return "Unavailable: this god conflicts with cards already in the deck. Patriarch and Matriarch decks can only use matching-culture or Neutral cards."
		return "Unavailable: this god conflicts with powers already in the deck. Powers must match your god's culture or be Neutral."
	return ""

func _is_power_compatible_with_culture(power: Card, culture: String) -> bool:
	if power == null or not power.is_power or power.is_god:
		return true
	return power.culture == "Neutral" or culture == "" or power.culture == culture

func _is_card_compatible_with_selected_god(card: Card, god: GodCard) -> bool:
	if card == null or god == null or card.is_god:
		return true

	var active_god := card as ActiveGodCard
	if active_god != null:
		return god.get_active_god_deck_role(active_god) == GodCard.ACTIVE_GOD_DECK_ROLE_ALLOWED

	if god.uses_culture_locked_deckbuilding():
		return god.can_include_card_in_culture_locked_deck(card)
	if card.is_power and not card.is_god:
		return _is_power_compatible_with_culture(card, god.culture)
	return true

func _is_illegal_active_god_for_god(card: Card, god: GodCard) -> bool:
	var active_god := card as ActiveGodCard
	if active_god == null:
		return false
	return god == null or god.get_active_god_deck_role(active_god) != GodCard.ACTIVE_GOD_DECK_ROLE_ALLOWED

func _can_add_power_to_current_deck(power: Card) -> bool:
	var god := _get_selected_god_template() as GodCard
	if god == null:
		return true
	return _is_card_compatible_with_selected_god(power, god)

func _can_add_god_to_current_deck(god: Card) -> bool:
	var god_card := god as GodCard
	if god_card == null or not god.is_god:
		return false
	for card_name: String in _deck:
		var card := _find_template(card_name)
		if card == null or card.is_god or _deck.get(card_name, 0) <= 0:
			continue
		if not _is_card_compatible_with_selected_god(card, god_card):
			return false
	return true

func _refresh_filter_button_states() -> void:
	for label in _filter_buttons.keys():
		var button = _filter_buttons.get(label)
		if button is Button:
			(button as Button).button_pressed = str(label) == _filter

func _refresh_faction_button_states() -> void:
	for label in _faction_buttons.keys():
		var button = _faction_buttons.get(label)
		if button is Button:
			(button as Button).button_pressed = str(label) == _faction_filter

func _refresh_level_filter_button_states() -> void:
	for label in _level_filter_buttons.keys():
		var button = _level_filter_buttons.get(label)
		if button is Button:
			(button as Button).button_pressed = str(label) == _level_filter

func _apply_guided_collection_view(filter_name: String) -> void:
	_collection_mode = COLLECTION_MODE_CARDS
	_filter = filter_name
	_faction_filter = "All"
	_level_filter = LEVEL_FILTER_ANY
	_current_page = 0
	_search_query = ""
	if _search_edit != null:
		_search_edit.text = ""
	_refresh_saved_decks_view_button()
	_refresh_filter_button_states()
	_refresh_faction_button_states()
	_refresh_level_filter_button_states()
	_rebuild_filtered_cards_cache()
	_refresh_collection_grid_and_layout()

func _focus_god_selection() -> void:
	_apply_guided_collection_view("Gods")

func _focus_power_selection() -> void:
	_apply_guided_collection_view("Powers")

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
