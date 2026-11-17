extends ColorRect

signal close_requested
signal refresh_requested
signal page_requested(page: int)
signal search_requested(query: String)
signal deck_requested(list_id: String)
signal delete_requested(list_id: String)

const TITLE_FONT = preload("res://fonts/custom_ui/Norsebold.otf")
const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")
const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const RankBadgeScript = preload("res://scripts/ui/RankBadge.gd")
const TextureCacheScript = preload("res://scripts/ui/UITextureCache.gd")
const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const BADGE_SIZE := Vector2i(36, 36)
const GOLD := Color("f1ce89")
const MUTED := Color("acb9ce")
# Mirrors DeckBuilderUI's deck ordering: gods → powers → creatures → equipment
# → charms → spells → structures → hexes.
const TYPE_SECTION_NAMES := {
	0: "— Gods —",
	1: "— Powers —",
	2: "— Creatures —",
	3: "— Equipment —",
	4: "— Charms —",
	5: "— Spells —",
	6: "— Structures —",
	7: "— Hexes —",
	8: "— Other —",
}

var _panel: PanelContainer
var _refresh_button: Button
var _close_button: Button
var _status: Label
var _table: Tree
var _filter_bar: HBoxContainer
var _search: LineEdit
var _player_filter: OptionButton
var _format: OptionButton
var _pagination: HBoxContainer
var _previous_page: Button
var _next_page: Button
var _page_label: Label
var _back_button: Button
var _view_deck_button: Button
var _delete_button: Button
var _deck_contents: RichTextLabel
var _deck_timeout: Timer
var _selected_list_id := ""
var _selected_entry: Dictionary = {}
var _paging_supported := false
var _filter_supported := false
var _current_page := 0
var _last_page := 0
var _ladder_entries: Array = []
var _status_message := ""
var _search_debounce: Timer
var _badge_viewports: Dictionary[String, SubViewport] = {}
var _god_art_paths: Dictionary[String, String] = {}
var _god_icon_viewports: Dictionary[String, SubViewport] = {}
var _card_templates_by_name: Dictionary = {}

func _ready() -> void:
	name = "BotLadderView"
	color = Color(0.025, 0.035, 0.065, 0.9)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 20.0
	_panel.offset_top = 20.0
	_panel.offset_right = -20.0
	_panel.offset_bottom = -20.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101725")
	style.border_color = Color("786441")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 16)
	_panel.add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	_panel.add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)
	var title := Label.new()
	title.text = "Ranked Ladder"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)
	_format = OptionButton.new()
	_format.add_item("Bo1", 1)
	_format.add_item("Bo3", 3)
	_format.select(0)
	_format.hide()
	_format.item_selected.connect(func(_index: int) -> void:
		_current_page = 0
		_last_page = 0
		_clear_ladder_rows()
		page_requested.emit(0)
	)
	header.add_child(_format)
	_refresh_button = _add_button(header, "Refresh", refresh_requested.emit)
	_back_button = _add_button(header, "Back to ladder", close_deck)
	_back_button.hide()
	_view_deck_button = _add_button(header, "View bot deck", _request_selected_deck)
	_view_deck_button.hide()
	_delete_button = _add_button(header, "Delete bot", _request_delete_selected)
	_delete_button.hide()
	_close_button = _add_button(header, "Close", close_requested.emit)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", MUTED)
	body.add_child(_status)
	_filter_bar = HBoxContainer.new()
	_filter_bar.add_theme_constant_override("separation", 8)
	body.add_child(_filter_bar)
	_search = LineEdit.new()
	_search.placeholder_text = "Search the whole ladder"
	_search.max_length = 64
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_search_text_changed)
	_filter_bar.add_child(_search)
	_search_debounce = Timer.new()
	_search_debounce.one_shot = true
	_search_debounce.wait_time = 0.3
	_search_debounce.timeout.connect(func() -> void: search_requested.emit(_search.text.strip_edges()))
	add_child(_search_debounce)
	_player_filter = OptionButton.new()
	_player_filter.add_item("Everyone", 0)
	_player_filter.add_item("Players", 1)
	_player_filter.add_item("Bots", 2)
	_player_filter.item_selected.connect(func(_index: int) -> void: _on_player_filter_selected())
	_filter_bar.add_child(_player_filter)

	_table = Tree.new()
	_table.columns = 7
	_table.hide_root = true
	_table.set_column_titles_visible(true)
	_table.set_column_title(0, "Rank")
	_table.set_column_title(1, "Name")
	_table.set_column_title(2, "Ranked record")
	_table.set_column_title(3, "Main God")
	_table.set_column_title(4, "Stars")
	_table.set_column_title(5, "Tier")
	_table.set_column_title(6, "Player type")
	_table.set_column_expand(0, false)
	_table.set_column_expand(1, true)
	_table.set_column_custom_minimum_width(0, 54)
	_table.set_column_custom_minimum_width(1, 230)
	for column in [2, 3, 4, 5, 6]:
		_table.set_column_expand(column, false)
	_table.set_column_custom_minimum_width(2, 112)
	_table.set_column_custom_minimum_width(3, 210)
	_table.set_column_custom_minimum_width(4, 78)
	_table.set_column_custom_minimum_width(5, 145)
	_table.set_column_custom_minimum_width(6, 105)
	_table.add_theme_constant_override("item_height", 38)
	_table.add_theme_font_size_override("font_size", 18)
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table.select_mode = Tree.SELECT_ROW
	_table.item_selected.connect(_open_selected_entry)
	_table.item_activated.connect(_open_selected_entry)
	body.add_child(_table)
	_pagination = HBoxContainer.new()
	_pagination.alignment = BoxContainer.ALIGNMENT_CENTER
	_pagination.hide()
	body.add_child(_pagination)
	_previous_page = _add_button(_pagination, "Previous", func() -> void: page_requested.emit(_current_page - 1))
	_page_label = Label.new()
	_pagination.add_child(_page_label)
	_next_page = _add_button(_pagination, "Next", func() -> void: page_requested.emit(_current_page + 1))
	_deck_contents = RichTextLabel.new()
	_deck_contents.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deck_contents.focus_mode = Control.FOCUS_ALL
	_deck_contents.hide()
	body.add_child(_deck_contents)
	_deck_timeout = Timer.new()
	_deck_timeout.one_shot = true
	_deck_timeout.wait_time = 5.0
	_deck_timeout.timeout.connect(func() -> void:
		_deck_contents.text = "The lobby did not respond. Go back and select the list to retry."
	)
	add_child(_deck_timeout)
	_close_button.grab_focus()
	resized.connect(_fit_panel)
	_fit_panel()

func set_status(message: String, can_refresh: bool, clear_table: bool = false) -> void:
	_status_message = message
	_status.text = message
	_status.visible = not message.is_empty() and _selected_entry.is_empty()
	_refresh_button.disabled = not can_refresh
	if clear_table:
		close_deck()
		_clear_ladder_rows()
		_ladder_entries.clear()
		_current_page = 0
		_last_page = 0
	_previous_page.disabled = not can_refresh or _current_page == 0
	_next_page.disabled = not can_refresh or _current_page >= _last_page
	_pagination.visible = _last_page > 0 and _selected_entry.is_empty()
	_filter_bar.visible = _selected_entry.is_empty()
	_page_label.text = "Page %d of %d" % [_current_page + 1, _last_page + 1]
	if _selected_entry.is_empty():
		_set_ladder_focus_order()

func set_paging_supported(supported: bool) -> void:
	_paging_supported = supported
	_format.visible = supported and _selected_entry.is_empty()
	if not supported:
		_format.select(0)
		_current_page = 0
		_last_page = 0

func set_filter_supported(supported: bool) -> void:
	_filter_supported = supported

func get_best_of() -> int:
	return _format.get_selected_id()

func get_current_page() -> int:
	return _current_page

func get_search_query() -> String:
	return _search.text.strip_edges()

func get_player_filter() -> String:
	match _player_filter.get_selected_id():
		1:
			return LobbyProtocolScript.LADDER_FILTER_PLAYERS
		2:
			return LobbyProtocolScript.LADDER_FILTER_BOTS
	return LobbyProtocolScript.LADDER_FILTER_EVERYONE

func _on_player_filter_selected() -> void:
	if not _filter_supported:
		# Older lobby servers cannot filter standings server-side, so keep the
		# local per-page filter instead of re-requesting.
		_render_ladder_rows()
		return
	_current_page = 0
	_last_page = 0
	_clear_ladder_rows()
	page_requested.emit(0)

func _on_search_text_changed(_text: String) -> void:
	_current_page = 0
	_search_debounce.start()

func show_summary(summary: Dictionary) -> void:
	_current_page = int(summary.get("page", 0))
	_last_page = int(summary.get("last_page", 0))
	_ladder_entries = summary.get("ladder", []).duplicate()
	var entries: Array = _ladder_entries
	var has_bot := entries.any(func(entry: Dictionary) -> bool: return bool(entry.get("is_bot", false)))
	var message := ""
	if entries.is_empty():
		var has_narrowing := not get_search_query().is_empty() \
			or get_player_filter() != LobbyProtocolScript.LADDER_FILTER_EVERYONE
		message = "No matching ladder entries." if has_narrowing else "No ladder entries yet."
	elif not _paging_supported:
		message = "Best-of-one ladder. Select a bot to see its deck." if has_bot else "Best-of-one ladder."
	elif has_bot:
		message = "Select a bot to see its deck."
	set_status(message, true)
	_render_ladder_rows()

func _render_ladder_rows() -> void:
	_clear_ladder_rows()
	var root := _table.create_item()
	var search_text := get_search_query().to_lower()
	var selected_filter := _player_filter.get_selected_id()
	var has_visible_bot := false
	var visible_count := 0
	for index in range(_ladder_entries.size()):
		var entry: Dictionary = _ladder_entries[index]
		var is_bot := bool(entry.get("is_bot", false))
		if (selected_filter == 1 and is_bot) or (selected_filter == 2 and not is_bot):
			continue
		var player_name := str(entry["name"])
		# Older lobby servers return the complete unpaged ladder, so retain a
		# local search fallback for those responses.
		if not _paging_supported and not search_text.is_empty() and not player_name.to_lower().contains(search_text):
			continue
		var rank_name := str(entry["rank"])
		var row := _table.create_item(root)
		row.set_text(0, str(entry.get("ladder_position", _current_page * LobbyProtocolScript.LADDER_PAGE_SIZE + index + 1)))
		row.set_metadata(0, entry.duplicate(true))
		row.set_text(1, player_name)
		row.set_tooltip_text(1, player_name)
		row.set_icon(1, _get_badge_icon(rank_name, entry.get("portrait", {})))
		var wins := int(entry.get("wins", 0))
		var losses := int(entry.get("losses", 0))
		var draws := int(entry.get("draws", 0))
		row.set_text(2, "%d-%d-%d" % [wins, losses, draws])
		row.set_tooltip_text(2, "%d wins · %d losses · %d draws since the ranked ladder began" % [wins, losses, draws])
		var main_gods: Array = entry.get("main_gods", [])
		var main_god_names := PackedStringArray()
		for god_name in main_gods:
			var clean_god_name := str(god_name).strip_edges()
			if not clean_god_name.is_empty():
				main_god_names.append(clean_god_name)
		row.set_text(3, " / ".join(main_god_names))
		row.set_tooltip_text(3, "Most played ranked God(s)" if main_god_names.is_empty() else "Most played: %s" % " / ".join(main_god_names))
		if not main_god_names.is_empty():
			row.set_icon(3, _get_god_icon(main_god_names))
		row.set_text(4, "%d ★" % int(entry["stars"]))
		row.set_text(5, rank_name)
		row.set_text(6, "Bot" if is_bot else "Player")
		visible_count += 1
		if is_bot:
			row.set_metadata(1, str(entry["list_id"]))
			row.set_custom_color(1, GOLD)
			has_visible_bot = true
	if _ladder_entries.is_empty():
		var has_narrowing := not get_search_query().is_empty() \
			or get_player_filter() != LobbyProtocolScript.LADDER_FILTER_EVERYONE
		_status.text = "No matching ladder entries." if has_narrowing else "No ladder entries yet."
	elif visible_count == 0:
		_status.text = "No matching entries on this page."
	elif not has_visible_bot and _status_message.begins_with("Select a bot"):
		_status.text = "Search and filter the ranked ladder."
	else:
		_status.text = _status_message
	_status.visible = _selected_entry.is_empty()

func _clear_ladder_rows() -> void:
	_table.clear()
	for viewport in _badge_viewports.values():
		viewport.queue_free()
	_badge_viewports.clear()
	for viewport in _god_icon_viewports.values():
		viewport.queue_free()
	_god_icon_viewports.clear()

func _get_badge_icon(rank_name: String, portrait: Dictionary) -> Texture2D:
	var key := JSON.stringify([rank_name, portrait])
	if _badge_viewports.has(key):
		return _badge_viewports[key].get_texture()
	var viewport := SubViewport.new()
	viewport.size = BADGE_SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	var badge := RankBadgeScript.new()
	badge.size = Vector2(BADGE_SIZE)
	badge.set_badge(rank_name, portrait)
	viewport.add_child(badge)
	add_child(viewport)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_badge_viewports[key] = viewport
	return viewport.get_texture()

func _get_god_icon(god_names: PackedStringArray) -> Texture2D:
	if god_names.is_empty():
		return null
	var god_name := str(god_names[0])
	if _god_icon_viewports.has(god_name):
		return _god_icon_viewports[god_name].get_texture()
	var art_path := str(_god_art_paths.get(god_name, ""))
	if art_path.is_empty():
		for card: Card in CardCatalogScript.get_cached_card_templates():
			if card.is_god and card.card_name == god_name:
				art_path = card.art_path
				_god_art_paths[god_name] = art_path
				break
	var texture := TextureCacheScript.get_texture(art_path)
	if texture == null:
		return null
	var viewport := SubViewport.new()
	viewport.size = BADGE_SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	var thumbnail := TextureRect.new()
	thumbnail.texture = texture
	thumbnail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	viewport.add_child(thumbnail)
	add_child(viewport)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_god_icon_viewports[god_name] = viewport
	return viewport.get_texture()

func _open_selected_entry() -> void:
	var selected := _table.get_selected()
	if selected == null or not _selected_entry.is_empty():
		return
	var metadata = selected.get_metadata(0)
	if not metadata is Dictionary:
		return
	_selected_entry = metadata.duplicate(true)
	_selected_list_id = str(_selected_entry.get("list_id", ""))
	_deck_contents.clear()
	_render_recent_record_details()
	_deck_contents.show()
	_back_button.show()
	_view_deck_button.visible = not _selected_list_id.is_empty()
	_delete_button.visible = not _selected_list_id.is_empty() and bool(_selected_entry.get("can_delete", false))
	_table.hide()
	_filter_bar.hide()
	_status.hide()
	_refresh_button.hide()
	_format.hide()
	_pagination.hide()
	var focus_order: Array[Control] = [_back_button]
	if _view_deck_button.visible:
		focus_order.append(_view_deck_button)
	if _delete_button.visible:
		focus_order.append(_delete_button)
	focus_order.append_array([_close_button, _deck_contents])
	_set_focus_order(focus_order)
	_back_button.grab_focus()

func _render_recent_record_details() -> void:
	var player_name := str(_selected_entry.get("name", "Player"))
	var wins := int(_selected_entry.get("wins", 0))
	var losses := int(_selected_entry.get("losses", 0))
	var draws := int(_selected_entry.get("draws", 0))
	_deck_contents.push_color(GOLD)
	_deck_contents.add_text("%s\n" % player_name)
	_deck_contents.pop()
	_deck_contents.push_color(MUTED)
	_deck_contents.add_text("Lifetime ranked record: %d wins · %d losses · %d draws\n" % [wins, losses, draws])
	var owner_name := str(_selected_entry.get("owner_name", "")).strip_edges()
	if not owner_name.is_empty():
		_deck_contents.add_text("Created by: %s\n" % owner_name)
	var main_gods: Array = _selected_entry.get("main_gods", [])
	if not main_gods.is_empty():
		var god_names := PackedStringArray()
		for god in main_gods:
			god_names.append(str(god))
		_deck_contents.add_text("Most played God: %s\n" % " / ".join(god_names))
	_deck_contents.add_text("\nRecent ranked matches\n")
	_deck_contents.pop()
	var recent_matches: Array = _selected_entry.get("recent_matches", [])
	if recent_matches.is_empty():
		_deck_contents.add_text("No ranked matches recorded yet.\n")
	else:
		for recent: Dictionary in recent_matches:
			var result := str(recent.get("result", "draw")).capitalize()
			var opponent := str(recent.get("opponent_name", "Opponent"))
			var opponent_god := str(recent.get("opponent_god_name", "")).strip_edges()
			var date := _format_match_date(int(recent.get("played_unix", 0)))
			var opponent_text := opponent if opponent_god.is_empty() else "%s (%s)" % [opponent, opponent_god]
			_deck_contents.add_text("%s · Bo%d · %s vs %s\n" % [
				date, int(recent.get("best_of", 1)), result, opponent_text,
			])
	_deck_contents.scroll_to_line(0)

func _format_match_date(unix_time: int) -> String:
	if unix_time <= 0:
		return "Recent"
	var date := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]

func _request_selected_deck() -> void:
	if _selected_list_id.is_empty():
		return
	_deck_contents.text = "Loading %s…" % str(_selected_entry.get("name", "bot deck"))
	_view_deck_button.hide()
	_delete_button.hide()
	_deck_timeout.start()
	deck_requested.emit(_selected_list_id)

func _request_delete_selected() -> void:
	if _selected_list_id.is_empty():
		return
	delete_requested.emit(_selected_list_id)

func show_deck(list_id: String, deck: Dictionary) -> void:
	if _selected_list_id.is_empty() or list_id != _selected_list_id:
		return
	_deck_timeout.stop()
	if deck.is_empty():
		_deck_contents.text = "This list is no longer available. Go back and refresh the ladder."
		return
	_deck_contents.clear()
	_view_deck_button.hide()
	_delete_button.hide()
	_deck_contents.push_color(GOLD)
	_deck_contents.add_text(str(deck["name"]) + "\n\n")
	_deck_contents.pop()
	_deck_contents.push_color(MUTED)
	_deck_contents.add_text("Record: %d wins · %d losses · %d draws\n" % [
		int(deck.get("wins", 0)), int(deck.get("losses", 0)), int(deck.get("draws", 0)),
	])
	var owner_name := str(deck.get("owner_name", "")).strip_edges()
	if not owner_name.is_empty():
		_deck_contents.add_text("Created by: %s\n" % owner_name)
	_deck_contents.add_text("\n")
	_deck_contents.pop()
	_add_card_section("Main deck", deck["cards"])
	var reinforcements: Dictionary = deck["reinforcements"]
	if not reinforcements.is_empty():
		_add_card_section("Reinforcements", reinforcements)
	var god_name := str(deck.get("god_name", "")).strip_edges()
	if god_name == TiamatScript.TIAMAT_CARD_NAME:
		_add_brood_slot_section(TiamatScript.get_slot_card_names_from_setup(deck.get("special_setup", {})))
	_deck_contents.scroll_to_line(0)

func _add_card_section(heading: String, cards: Dictionary) -> void:
	var names := cards.keys()
	names.sort_custom(_compare_deck_card_names)
	var count := 0
	for copies in cards.values():
		count += int(copies)
	_deck_contents.push_color(GOLD)
	_deck_contents.add_text("%s (%d cards)\n" % [heading, count])
	_deck_contents.pop()
	var last_section := ""
	for card_name in names:
		var section := str(TYPE_SECTION_NAMES.get(_deck_type_order(str(card_name)), "— Other —"))
		if section != last_section:
			last_section = section
			_deck_contents.push_color(MUTED)
			_deck_contents.add_text("%s\n" % section)
			_deck_contents.pop()
		_deck_contents.add_text("%d × %s\n" % [cards[card_name], card_name])
	_deck_contents.add_text("\n")

func _add_brood_slot_section(slots: Array) -> void:
	var has_slot_cards := false
	for slot_cards in slots:
		if slot_cards is Array and not (slot_cards as Array).is_empty():
			has_slot_cards = true
			break
	if not has_slot_cards:
		return
	_deck_contents.push_color(GOLD)
	_deck_contents.add_text("Tiamat's brood slots\n")
	_deck_contents.pop()
	for slot_index in range(slots.size()):
		var slot_text := "Slot %d: " % (slot_index + 1)
		var slot_cards: Array = slots[slot_index]
		if slot_cards.is_empty():
			slot_text += "empty"
		else:
			var slot_counts := {}
			for card_name in slot_cards:
				var clean_name := str(card_name).strip_edges()
				if clean_name.is_empty():
					continue
				slot_counts[clean_name] = int(slot_counts.get(clean_name, 0)) + 1
			var parts := PackedStringArray()
			for card_name in slot_counts.keys():
				parts.append("%d × %s" % [slot_counts[card_name], card_name])
			if parts.is_empty():
				slot_text += "empty"
			else:
				slot_text += ", ".join(parts)
		_deck_contents.add_text("%s\n" % slot_text)
	_deck_contents.add_text("\n")

func _compare_deck_card_names(a: String, b: String) -> bool:
	var order_a := _deck_type_order(a)
	var order_b := _deck_type_order(b)
	if order_a != order_b:
		return order_a < order_b
	var a_name := str(a).to_lower()
	var b_name := str(b).to_lower()
	if a_name == b_name:
		return a < b
	return a_name < b_name

func _deck_type_order(card_name: String) -> int:
	var card := _get_card_template(card_name)
	if card == null:
		return 8
	if card.is_god:
		return 0
	if card.is_power:
		return 1
	match card.card_type:
		Card.CardType.CREATURE:
			return 2
		Card.CardType.EQUIPMENT:
			return 3
		Card.CardType.CHARM:
			return 4
		Card.CardType.SPELL:
			return 5
		Card.CardType.STRUCTURE:
			return 6
		Card.CardType.HEX:
			return 7
	return 8

func _get_card_template(card_name: String) -> Card:
	var clean_name := str(card_name).strip_edges()
	if clean_name.is_empty():
		return null
	if _card_templates_by_name.is_empty():
		for template: Card in CardCatalogScript.get_cached_card_templates():
			_card_templates_by_name[str(template.card_name)] = template
	var template: Card = _card_templates_by_name.get(clean_name, null)
	return template

func close_deck() -> bool:
	if _selected_entry.is_empty():
		return false
	_selected_list_id = ""
	_selected_entry.clear()
	_deck_timeout.stop()
	_deck_contents.hide()
	_back_button.hide()
	_view_deck_button.hide()
	_delete_button.hide()
	_status.visible = not _status.text.is_empty()
	_refresh_button.show()
	_format.visible = _paging_supported
	_filter_bar.show()
	_pagination.visible = _last_page > 0
	_table.deselect_all()
	_table.show()
	_set_ladder_focus_order()
	_table.grab_focus()
	return true

func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(72, 36)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _set_ladder_focus_order() -> void:
	var controls: Array[Control] = []
	if _format.visible:
		controls.append(_format)
	if not _refresh_button.disabled:
		controls.append(_refresh_button)
	controls.append(_close_button)
	if _filter_bar.visible:
		controls.append_array([_search, _player_filter])
	controls.append(_table)
	if _pagination.visible:
		for button in [_previous_page, _next_page]:
			if not button.disabled:
				controls.append(button)
	_set_focus_order(controls)

func _set_focus_order(controls: Array[Control]) -> void:
	for i in range(controls.size()):
		var control := controls[i]
		control.focus_next = control.get_path_to(controls[(i + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[posmod(i - 1, controls.size())])

func _fit_panel() -> void:
	_panel.custom_minimum_size = Vector2.ZERO
