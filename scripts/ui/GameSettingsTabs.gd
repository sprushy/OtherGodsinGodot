class_name GameSettingsTabs
extends RefCounted

const AUDIO_SETTINGS_SECTION := "audio"
const COMBAT_SETTINGS_SECTION := "combat"
const GOD_SPECIFIC_SETTINGS_SECTION := "god_specific"

const MUSIC_MUTED_KEY := "music_muted"
const ALL_SOUND_MUTED_KEY := "all_sound_muted"
const STARTUP_MUSIC_TRACK_KEY := "startup_music_track"
const MASTER_VOLUME_KEY := "master_volume"
const MUSIC_VOLUME_KEY := "music_volume"
const EFFECTS_VOLUME_KEY := "effects_volume"
const STARTUP_MUSIC_TRACK_IF_THEY_HAD_HEARTS := "if_they_had_hearts"
const STARTUP_MUSIC_TRACK_RELAXING_TIME := "relaxing_time"
const AUTO_SELECT_SPELL_PLAY_ZONES_KEY := "auto_select_spell_play_zones"
const AUTO_SELECT_SPELL_PREPARE_ZONES_KEY := "auto_select_spell_prepare_zones"
const AUTO_SELECT_HEX_PREPARE_ZONES_KEY := "auto_select_hex_prepare_zones"
const AUTO_SELECT_CHARM_PLAY_ZONES_KEY := "auto_select_charm_play_zones"
const AUTO_SELECT_CHARM_PREPARE_ZONES_KEY := "auto_select_charm_prepare_zones"
const BOARD_STYLE_KEY := "board_style"
const BOARD_STYLE_NORMAL := "normal"
const BOARD_STYLE_SNOW := "snow"
const USE_SPLASH_BOARD_BACKGROUND_KEY := "use_splash_board_background"
const HOVER_SHOW_CARD_OPTIONS_KEY := "hover_show_card_options"
const ALWAYS_SHOW_ABILITY_BADGES_KEY := "always_show_ability_badges"
const HIDE_UNALTERED_REACH_TAG_KEY := "hide_unaltered_reach_tag"
const ADD_PRIORITY_TOGGLES_TO_ALL_CARDS_KEY := "add_priority_toggles_to_all_cards"
const HERMES_AUTO_PASS_END_PRIORITY_KEY := "hermes_auto_pass_end_priority"
const HERMES_AUTO_PASS_UPKEEP_PRIORITY_KEY := "hermes_auto_pass_upkeep_priority"
const HERMES_ADD_PRIORITY_TOGGLE_KEY := "hermes_add_priority_toggle_to_card"

# Builds the game-settings tabs shared by the main menu Settings overlay and the
# in-match pause menu settings page. Hosts supply the current value and the
# apply/persist behavior through callables:
#   get_value.call(section: String, key: String, default_value: bool) -> bool
#   set_value.call(section: String, key: String, value: bool) -> void
# Option rows additionally use string callables:
#   get_text_value.call(section: String, key: String, default_value: String) -> String
#   set_text_value.call(section: String, key: String, value: String) -> void
# Volume slider rows use float callables:
#   get_number_value.call(section: String, key: String, default_value: float) -> float
#   set_number_value.call(section: String, key: String, value: float) -> void
# When created_toggles is provided it is filled with "section/key" -> CheckButton
# so hosts can keep external references (e.g. for observer-driven resync).

static func build_general_tab(get_value: Callable, set_value: Callable, created_toggles: Dictionary = {}, get_text_value: Callable = Callable(), set_text_value: Callable = Callable(), get_number_value: Callable = Callable(), set_number_value: Callable = Callable()) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "General"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var settings := VBoxContainer.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation", 8)
	scroll.add_child(settings)

	var settings_info := Label.new()
	settings_info.text = "When enabled, right-click Play/Prepare will auto-pick a friendly zone and prefer reserve line slots."
	settings_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_info.add_theme_color_override("font_color", Color(0.80, 0.85, 0.92))
	settings.add_child(settings_info)

	settings.add_child(_make_section_label("Placement"))
	_add_setting_toggle(settings, "Auto-select spell play zones", COMBAT_SETTINGS_SECTION, AUTO_SELECT_SPELL_PLAY_ZONES_KEY, true, get_value, set_value, created_toggles)
	_add_setting_toggle(settings, "Auto-select spell prepare zones", COMBAT_SETTINGS_SECTION, AUTO_SELECT_SPELL_PREPARE_ZONES_KEY, true, get_value, set_value, created_toggles)
	_add_setting_toggle(settings, "Auto-select hex prepare zones", COMBAT_SETTINGS_SECTION, AUTO_SELECT_HEX_PREPARE_ZONES_KEY, true, get_value, set_value, created_toggles)
	_add_setting_toggle(settings, "Auto-select charm play zones", COMBAT_SETTINGS_SECTION, AUTO_SELECT_CHARM_PLAY_ZONES_KEY, true, get_value, set_value, created_toggles)
	_add_setting_toggle(settings, "Auto-select charm prepare zones", COMBAT_SETTINGS_SECTION, AUTO_SELECT_CHARM_PREPARE_ZONES_KEY, true, get_value, set_value, created_toggles)

	settings.add_child(_make_section_label("Audio"))
	_add_setting_toggle(settings, "Mute music", AUDIO_SETTINGS_SECTION, MUSIC_MUTED_KEY, false, get_value, set_value, created_toggles)
	_add_setting_toggle(settings, "Mute all sound", AUDIO_SETTINGS_SECTION, ALL_SOUND_MUTED_KEY, false, get_value, set_value, created_toggles)
	if get_text_value.is_valid() and set_text_value.is_valid():
		_add_setting_option(settings, "Startup music", AUDIO_SETTINGS_SECTION, STARTUP_MUSIC_TRACK_KEY, STARTUP_MUSIC_TRACK_IF_THEY_HAD_HEARTS, [
			{"label": "If They Had Hearts", "value": STARTUP_MUSIC_TRACK_IF_THEY_HAD_HEARTS},
			{"label": "Relaxing Time (classic)", "value": STARTUP_MUSIC_TRACK_RELAXING_TIME},
		], get_text_value, set_text_value)
	if get_number_value.is_valid() and set_number_value.is_valid():
		_add_setting_slider(settings, "Master volume", AUDIO_SETTINGS_SECTION, MASTER_VOLUME_KEY, 1.0, get_number_value, set_number_value)
		_add_setting_slider(settings, "Music volume", AUDIO_SETTINGS_SECTION, MUSIC_VOLUME_KEY, 1.0, get_number_value, set_number_value)
		_add_setting_slider(settings, "Effects volume", AUDIO_SETTINGS_SECTION, EFFECTS_VOLUME_KEY, 1.0, get_number_value, set_number_value)

	settings.add_child(_make_section_label("Visual"))
	if get_text_value.is_valid() and set_text_value.is_valid():
		_add_setting_option(settings, "Board style", COMBAT_SETTINGS_SECTION, BOARD_STYLE_KEY, BOARD_STYLE_NORMAL, [
			{"label": "Moss Stone (Normal)", "value": BOARD_STYLE_NORMAL},
			{"label": "Snow Stone (Snow)", "value": BOARD_STYLE_SNOW},
		], get_text_value, set_text_value)
	_add_setting_toggle(settings, "Use splash image board background", COMBAT_SETTINGS_SECTION, USE_SPLASH_BOARD_BACKGROUND_KEY, false, get_value, set_value, created_toggles)
	_add_setting_toggle(settings, "Hover show card options", COMBAT_SETTINGS_SECTION, HOVER_SHOW_CARD_OPTIONS_KEY, true, get_value, set_value, created_toggles)
	_add_setting_toggle(settings, "Always show ability badges", COMBAT_SETTINGS_SECTION, ALWAYS_SHOW_ABILITY_BADGES_KEY, false, get_value, set_value, created_toggles)
	_add_setting_toggle(settings, "Hide Reach tag unless altered", COMBAT_SETTINGS_SECTION, HIDE_UNALTERED_REACH_TAG_KEY, false, get_value, set_value, created_toggles)

	settings.add_child(_make_section_label("Priority"))
	_add_setting_toggle(settings, "Add priority toggles to every card", COMBAT_SETTINGS_SECTION, ADD_PRIORITY_TOGGLES_TO_ALL_CARDS_KEY, false, get_value, set_value, created_toggles)

	return scroll

static func build_god_tab(get_value: Callable, set_value: Callable, created_toggles: Dictionary = {}) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "God-Specific Settings"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var settings := VBoxContainer.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation", 8)
	scroll.add_child(settings)

	settings.add_child(_make_section_label("Hermes"))
	_add_setting_toggle(settings, "Auto-pass end phase priority (even with Offer Priority enabled)", GOD_SPECIFIC_SETTINGS_SECTION, HERMES_AUTO_PASS_END_PRIORITY_KEY, true, get_value, set_value, created_toggles)
	_add_setting_toggle(settings, "Auto-pass upkeep priority (even with Offer Priority enabled)", GOD_SPECIFIC_SETTINGS_SECTION, HERMES_AUTO_PASS_UPKEEP_PRIORITY_KEY, true, get_value, set_value, created_toggles)
	_add_setting_toggle(settings, "Add priority toggle to card", GOD_SPECIFIC_SETTINGS_SECTION, HERMES_ADD_PRIORITY_TOGGLE_KEY, true, get_value, set_value, created_toggles)

	var hermes_note := Label.new()
	hermes_note.text = "When the card toggle is hidden or set to off, Hermes will not open priority prompts himself. He remains available in priority prompts opened by another response."
	hermes_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hermes_note.add_theme_color_override("font_color", Color(0.80, 0.85, 0.92))
	settings.add_child(hermes_note)

	return scroll

static func _make_section_label(label_text: String) -> Label:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.68))
	return label

static func _add_setting_toggle(parent: Node, label_text: String, section: String, key: String, default_value: bool, get_value: Callable, set_value: Callable, created_toggles: Dictionary) -> void:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.button_pressed = bool(get_value.call(section, key, default_value))
	toggle.custom_minimum_size = Vector2(0, 34)
	var apply_setting := func(pressed: bool) -> void:
		set_value.call(section, key, pressed)
	toggle.toggled.connect(apply_setting)
	parent.add_child(toggle)
	created_toggles[_toggle_ref_key(section, key)] = toggle

static func _add_setting_option(parent: Node, label_text: String, section: String, key: String, default_value: String, options: Array, get_value: Callable, set_value: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(220, 34)
	var selected_index := 0
	for option_index in range(options.size()):
		var option_entry: Dictionary = options[option_index]
		option.add_item(str(option_entry.get("label", "")), option_index)
		option.set_item_metadata(option_index, str(option_entry.get("value", "")))
	var current_value := str(get_value.call(section, key, default_value))
	for option_index in range(options.size()):
		if str(option.get_item_metadata(option_index)) == current_value:
			selected_index = option_index
			break
	option.select(selected_index)
	var apply_setting := func(option_index: int) -> void:
		set_value.call(section, key, str(option.get_item_metadata(option_index)))
	option.item_selected.connect(apply_setting)
	row.add_child(option)

static func _add_setting_slider(parent: Node, label_text: String, section: String, key: String, default_value: float, get_number_value: Callable, set_number_value: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(220, 34)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(48, 0)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	var current_value := clampf(float(get_number_value.call(section, key, default_value)), 0.0, 1.0)
	slider.set_value_no_signal(current_value)
	value_label.text = "%d%%" % int(round(current_value * 100.0))
	var apply_setting := func(new_value: float) -> void:
		value_label.text = "%d%%" % int(round(new_value * 100.0))
		set_number_value.call(section, key, new_value)
	slider.value_changed.connect(apply_setting)

static func _toggle_ref_key(section: String, key: String) -> String:
	return "%s/%s" % [section, key]
