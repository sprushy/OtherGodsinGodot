extends Control
class_name CombatMockGame

const EnHeduAnnaScript = preload("res://scripts/cards/Creatures/EnHeduAnna.gd")
const ErlqueensNightingaleScript = preload("res://scripts/cards/Creatures/ErlqueensNightingale.gd")
const SacrificeCursorSource = preload("res://images/card_art/BloodySacrificeCursor.png")
const DevourCursorSource = preload("res://images/card_art/BloodyWolfJawsPGN.png")
const SilenceCursorSource = preload("res://images/SilenceCursorPGN.png")
const GiantMasterArchitectCursorSource = preload("res://images/card_art/GiantMasterArchitectHammerCursor.png")
const GugalannaCursorSource = preload("res://images/card_art/JeweledHornsCursor.png")
const GuanYuCursorSource = preload("res://images/card_art/GuanYuCursor.png")
const PromptRouterScript = preload("res://scripts/server/PromptRouter.gd")
const HeadlessMatchHostScript = preload("res://scripts/server/HeadlessMatchHost.gd")
const MatchClientScript = preload("res://scripts/client/MatchClient.gd")
const DefaultMatchSetupScript = preload("res://scripts/server/DefaultMatchSetup.gd")

signal forfeit_requested
signal match_session_cleared

var player1: Player
var player2: Player
var network_manager: Node = null
var game_input: GameInput = null
var game_event_broadcaster: GameEventBroadcaster = null
var headless_match_host = null
var prompt_router = null
var match_client = null
var _is_networked_client: bool = false
var selected_card: Card = null
var selected_attacker: Card:
	get:
		if match_manager == null:
			return null
		return match_manager.selected_attacker
	set(val):
		if match_manager != null:
			match_manager.selected_attacker = val
var selected_interceptor: Card:
	get:
		if match_manager == null:
			return null
		return match_manager.selected_interceptor
	set(val):
		if match_manager != null:
			match_manager.selected_interceptor = val
var pending_attack_target:
	get:
		if match_manager == null:
			return null
		return match_manager.pending_attack_target
	set(val):
		if match_manager != null:
			match_manager.pending_attack_target = val
var placement_mode: String = ""
var awaiting_spell_target: bool:
	get:
		if match_manager == null:
			return false
		return match_manager.awaiting_spell_target
	set(val):
		if match_manager != null:
			match_manager.awaiting_spell_target = val
var spell_waiting_for_target: Card:
	get:
		if match_manager == null:
			return null
		return match_manager.spell_waiting_for_target
	set(val):
		if match_manager != null:
			match_manager.spell_waiting_for_target = val
var spell_waiting_for_action: CardAction:
	get:
		if match_manager == null:
			return null
		return match_manager.spell_waiting_for_action
	set(val):
		if match_manager != null:
			match_manager.spell_waiting_for_action = val
var spell_waiting_for_display_zone: Zone:
	get:
		if match_manager == null:
			return null
		return match_manager.spell_waiting_for_display_zone
	set(val):
		if match_manager != null:
			match_manager.spell_waiting_for_display_zone = val
var _pending_paid_hand_card: Card:
	get:
		if match_manager == null:
			return null
		return match_manager.pending_paid_hand_card
	set(val):
		if match_manager != null:
			match_manager.pending_paid_hand_card = val
var _pending_paid_hand_display_zone: Zone:
	get:
		if match_manager == null:
			return null
		return match_manager.pending_paid_hand_display_zone
	set(val):
		if match_manager != null:
			match_manager.pending_paid_hand_display_zone = val
var _pending_paid_hand_display_zone_auto: bool:
	get:
		if match_manager == null:
			return false
		return match_manager.pending_paid_hand_display_zone_auto
	set(val):
		if match_manager != null:
			match_manager.pending_paid_hand_display_zone_auto = val
var _pending_spell_display_zone: Zone:
	get:
		if match_manager == null:
			return null
		return match_manager.pending_spell_display_zone
	set(val):
		if match_manager != null:
			match_manager.pending_spell_display_zone = val
var _pending_click_selection_source: Card:
	get:
		if match_manager == null:
			return null
		return match_manager.pending_click_selection_source
	set(val):
		if match_manager != null:
			match_manager.pending_click_selection_source = val
var auto_priority: bool = true
var _fan_container: Control = null

const FAN_ROT_MAX     := 12.0   # degrees at the outermost card
const FAN_ARC_HEIGHT  := 22.0   # px the arc dips at centre
const FAN_CARD_SPACING := 130   # px between card pivot centres
const STACK_LINGER_SECONDS := 0.8

@onready var choice_container = $MainHBox/LeftPanel/ChoiceContainer
@onready var choice_intro_label = $MainHBox/LeftPanel/ChoiceContainer/ChoiceIntroLabel
@onready var draw_button = $MainHBox/LeftPanel/ChoiceContainer/DrawButton
@onready var mana_button = $MainHBox/LeftPanel/ChoiceContainer/ManaButton
var _sun_hunt_button: Button = null
@onready var left_panel = $MainHBox/LeftPanel
@onready var left_top_spacer = $MainHBox/LeftPanel/LeftTopSpacer
@onready var left_bottom_spacer = $MainHBox/LeftPanel/LeftBottomSpacer
@onready var end_turn_button = $MainHBox/RightPanel/EndTurnButton
@onready var forfeit_button = $ForfeitButton
@onready var all_attack_btn = $MainHBox/RightPanel/AllAttackBtn
@onready var turn_label = $MainHBox/RightPanel/TurnLabel
@onready var stats_container = $MainHBox/RightPanel/StatsContainer
@onready var right_panel = $MainHBox/RightPanel
@onready var right_top_spacer = $MainHBox/RightPanel/RightTopSpacer
@onready var right_bottom_spacer = $MainHBox/RightPanel/RightBottomSpacer
@onready var hand_container = $MainHBox/CenterPanel/HandContainer
@onready var board_container = $MainHBox/CenterPanel/BoardContainer
@onready var enemy_board_container = $MainHBox/CenterPanel/EnemyBoardContainer
@onready var center_panel = $MainHBox/CenterPanel
@onready var top_spacer = $MainHBox/CenterPanel/TopSpacer
@onready var board_separator = $MainHBox/CenterPanel/BoardSeparator
@onready var action_label = $MainHBox/LeftPanel/ActionLabel
@onready var placement_container = $MainHBox/LeftPanel/PlacementContainer
@onready var aggressive_stance_btn = $MainHBox/LeftPanel/PlacementContainer/AggressiveStanceBtn
@onready var defensive_stance_btn = $MainHBox/LeftPanel/PlacementContainer/DefensiveStanceBtn
@onready var stealth_mode_btn = $MainHBox/LeftPanel/PlacementContainer/StealthModeBtn

var game_manager: GameManager
var match_manager: MatchManager

# Visual UI state
var _hand_visual_cards: Array = []   # Array[VisualCard]
var _board_zone_uis: Array = []      # Array[BoardZoneUI]
var _enemy_zone_uis: Array = []      # Array[BoardZoneUI]
var _enemy_god_zone_ui: BoardZoneUI = null
var _player_god_zone_ui: BoardZoneUI = null
var _last_board_player: Player = null   # tracks which player the board was built for
var _last_enemy_player: Player = null   # tracks which player the enemy board was built for
var _pending_drop_zone: Zone = null  # Zone queued by a drag-drop before mode selection

var awaiting_god_ability_target: bool = false
var god_ability_source: Card = null
var awaiting_stupefy_target: bool = false
var stupefy_source: Card = null
var awaiting_pyre_target: bool = false
var pyre_source: AncientPyre = null
var awaiting_anointing_target: bool = false
var anointing_source: AnointingStatue = null
var _pending_retreat_action: CardAction = null
var _pending_retreat_target: Card = null
var _pending_retreat_prompts: Array[Askelladen] = []
var _pending_retreat_guardian_blocked: Array[Askelladen] = []
var _retreat_prompt_panel: Control = null
var _awaiting_creature_sacrifice: bool = false
var _sacrifice_pending_card: Card = null
var _sacrifice_pending_zone: Zone = null
var _sacrifice_pending_mode: String = ""
var _sacrifice_remaining: int = 0
var _drag_sacrifice_done: bool = false
var _awaiting_drag_sacrifice_zone: bool = false
var _drag_sacrifice_card: Card = null
var _drag_sacrifice_target: Card = null
var _drag_sacrifice_mode: String = ""
var _pending_structure_bonus_power: AdvancedBuildingTechniques = null
var _pending_structure_bonus_structure: Card = null
var _awaiting_altar_void_payment: bool = false
var _altar_pending_power: AltarOfDreams = null
var _altar_void_targets_chosen: Array[Card] = []
var _pending_demiurge_spell = null  # ApollyonsDemiurge — untyped for duck typing
var _pending_blot_spell = null  # BlotSacrifice — untyped for duck typing
var _pending_blot_sacrifice_target: Card = null
var _pending_blot_selected_creatures: Array[Card] = []
var _pending_blot_display_zone: Zone = null
var _pending_blot_costs_paid: bool = false
var _blot_panel: Control = null
var _pending_book_of_life_spell: BookOfLife = null
var _pending_deucalion_spell: DeucalionsInfants = null
var _pending_deucalion_friendly_targets: Array[Card] = []
var _deucalion_panel: Control = null
var _overlay_card_selected: Callable = Callable()
var _pending_absence_spell: Absence = null
var _pending_absence_target: Card = null
var _pending_blessed_knights: BlessedKnights = null
var _pending_byggvir: Byggvir = null
var _pending_byggvir_options: Array[Dictionary] = []
var _pending_summon_priority_events: Array[Dictionary] = []
var _pending_wolf_master_source: Card = null
var _pending_wolf_master_summon: Card = null
var _pending_wolf_master_mode: String = ""
var _pending_skoll_prompts: Array[Skoll] = []
var _pending_skoll_summon: Skoll = null
var _pending_skoll_mode: String = ""
var _queued_skoll_turn_start_summon: Skoll = null
var _queued_skoll_turn_start_zone: Zone = null
var _queued_skoll_turn_start_mode: String = ""
var _pending_creature_play_resolver: Callable = Callable()
var _pending_en_hedu_anna: Card = null
var _pending_erlqueens_nightingale: ErlqueensNightingaleScript = null
var _skoll_prompt_panel: Control = null
var _gala_tura_prompt_panel: Control = null
var _pending_gala_tura: Card = null
var _pending_gala_tura_selected: Array[Card] = []
var _breidablik_panel: Control = null
var _e2_abzu_panel: Control = null
var _divine_caprice_panel: Control = null
var _pending_divine_caprice_power: DivineCaprice = null
var _pending_divine_caprice_selected_zone: Zone = null
var _pending_divine_caprice_plan: Array[Dictionary] = []
var _pending_divine_caprice_virtual_slots: Dictionary = {}
var _pending_hand_play_events: Array[Card] = []
var _stack_resolution_paused: bool = false
var _pending_post_execute_source_player: Player = null
var _overlay_card_dismissed: Callable = Callable()
var _doorway_prompt_panel: Control = null
var _pending_doorway_structure: DoorwayToTheVoid = null
var _pending_doorway_card: Card = null
var _pending_doorway_combat_death: bool = false
var _pending_doorway_destruction: bool = false
var _pending_doorway_continue: Callable = Callable()
var _executing_stack_action: bool = false

# Board-creature drag state (managed here for reliability)
var _bdrag_card: Card = null
var _bdrag_from_zone: Zone = null
var _bdrag_active: bool = false
var _bdrag_ghost: Control = null

# Right-click context menu state
var _pending_move_card: Card = null
var _pending_equip_actor: Card = null
var _pending_equip_target: Card = null
var _pending_equip_action: String = ""  # "steal" or "destroy"
var _context_menu: Control = null
var _queued_attackers: Array[Card] = []
var _no_intercept_btn: Button = null
var _ui_refresh_queued: bool = false
var _power_hover_popup: Control = null
var _game_finished: bool = false
var _action_log_view: RichTextLabel = null
var _action_log_history_button: Button = null
var _action_log_messages: Array[String] = []
var _last_logged_action_text: String = ""
var _action_log_popup: PanelContainer = null
var _action_log_popup_view: RichTextLabel = null
var _center_action_panel: VBoxContainer = null
var _board_separator_line: ColorRect = null
var _sacrifice_cursor_texture: Texture2D = null
var _devour_cursor_texture: Texture2D = null
var _silence_cursor_texture: Texture2D = null
var _giant_master_architect_cursor_texture: Texture2D = null
var _gugalanna_cursor_texture: Texture2D = null
var _guan_yu_cursor_texture: Texture2D = null
var _active_selection_cursor_mode: String = ""
var _overlay_selection_cursor_mode: String = ""
var _devour_cancel_prompt: Control = null
var _suppress_next_devour_cancel_prompt: bool = false
var _pending_end_turn_discard_uids: Array = []
var _ui_update_pending: bool = false
var _match_reconnect_waiting: bool = false
var _match_reconnect_wait_message: String = "Waiting for opponent to reconnect..."
var _current_match_info: Dictionary = {}

const TRANSIENT_UI_Z_INDEX := 1000
const HOVER_PREVIEW_Z_INDEX := TRANSIENT_UI_Z_INDEX + 50
const ACTION_LOG_MAX_MESSAGES := 250
const ACTION_LOG_PREVIEW_COUNT := 2
const BOARD_ZONE_COLUMN_GAP := 2.0
const BOARD_MAIN_COLUMN_COUNT := 7.0
const BOARD_ROW_COUNT := 4.0
const CENTER_PANEL_SECTION_GAP := 2
const BOARD_SEPARATOR_HEIGHT := 4
const BOARD_SIZE_TRIM := 8.0
const HAND_DOCK_HEIGHT := 118.0
const HAND_CARD_PEEK_OVERLAP := 14.0
const HAND_CARD_EXPOSED_HEIGHT := 100.0
const HAND_LAYOUT_RESERVED := 0.0
const HAND_OVERLAY_SIDE_PADDING := 18.0
const HAND_OVERLAY_BOTTOM_PADDING := 4.0
const LEFT_PANEL_MIN_WIDTH := 140.0
const BOARD_RIGHT_NUDGE := 12.0
const SACRIFICE_CURSOR_TARGET_HEIGHT := 96
const SACRIFICE_CURSOR_HOTSPOT_RATIO := Vector2(0.03, 0.80)
const DEVOUR_CURSOR_TARGET_HEIGHT := 96
const DEVOUR_CURSOR_HOTSPOT_RATIO := Vector2(0.50, 0.52)
const SILENCE_CURSOR_TARGET_HEIGHT := 96
const SILENCE_CURSOR_HOTSPOT_RATIO := Vector2(0.49, 0.22)
const GIANT_MASTER_ARCHITECT_CURSOR_TARGET_HEIGHT := 96
const GIANT_MASTER_ARCHITECT_CURSOR_HOTSPOT_RATIO := Vector2(0.50, 0.18)
const GUGALANNA_CURSOR_TARGET_HEIGHT := 96
const GUGALANNA_CURSOR_HOTSPOT_RATIO := Vector2(0.50, 0.85)
const GUAN_YU_CURSOR_TARGET_HEIGHT := 96
const GUAN_YU_CURSOR_HOTSPOT_RATIO := Vector2(0.95, 0.94)
const SACRIFICE_CURSOR_SHAPES := [
	Input.CURSOR_ARROW,
	Input.CURSOR_POINTING_HAND,
	Input.CURSOR_HELP,
]
const ACTION_LOG_MIN_WIDTH := 126.0
const ACTION_LOG_PREVIEW_HEIGHT := 92.0
const ACTION_LOG_FONT_SIZE := 11
const ACTION_LOG_LINE_SEPARATION := 4
const ACTION_LOG_POPUP_WIDTH := 420.0
const ACTION_LOG_POPUP_HEIGHT := 320.0
const ACTION_LOG_LEFT_INSET := 6
const TURN_CHOICE_TOP_GAP := 10.0
const ZONE_INFO_ICON_SIZE := 74.0
const CENTER_ACTION_PANEL_WIDTH := 138.0
const CENTER_ACTION_PANEL_HEIGHT := 114.0
const CENTER_ACTION_BUTTON_HEIGHT := 28.0
const RIGHT_PANEL_MIN_WIDTH := 136.0
const RIGHT_PANEL_CONTROL_GAP := 6
const RIGHT_PANEL_TEXT_FONT_SIZE := 10

func _is_turn_choice_pending() -> bool:
	return choice_container.visible

func _can_activate_before_turn_choice(card: Card) -> bool:
	if card == null:
		return false
	if card.get_controller() != game_manager.current_player:
		return false
	if card is Breidablik:
		return (card as Breidablik).can_return_priest(game_manager)
	return false

func _reject_pre_turn_action() -> void:
	action_label.text = "Finish resolving upkeep before taking other actions."

func _promote_transient_ui(control: Control, overlay_z_index: int = TRANSIENT_UI_Z_INDEX) -> void:
	if control == null:
		return
	control.top_level = true
	control.z_index = overlay_z_index
	control.move_to_front()

func _get_doorway_replacement_source(card: Card) -> DoorwayToTheVoid:
	if game_manager == null or card == null or card.card_type != Card.CardType.CREATURE:
		return null
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return null
	if not game_manager.has_method("_get_active_structures"):
		return null
	for structure in game_manager._get_active_structures():
		if structure is DoorwayToTheVoid and structure.replaces_graveyard_send(card, game_manager):
			return structure as DoorwayToTheVoid
	return null

func _resolve_doorway_destination(send_to_abyss: bool) -> void:
	var structure := _pending_doorway_structure
	var card := _pending_doorway_card
	_hide_doorway_choice_prompt()
	if card == null or game_manager == null:
		return
	game_manager.resolve_pending_doorway_choice(send_to_abyss)
	if structure != null:
		if send_to_abyss:
			action_label.text = "%s chooses to send %s to the abyss." % [structure.card_owner.player_name, card.card_name]
		else:
			action_label.text = "%s chooses to send %s to the graveyard." % [structure.card_owner.player_name, card.card_name]
	if _stack_resolution_paused and game_manager != null and not game_manager.has_pending_doorway_choice():
		_resume_after_deferred_resolution(_consume_resolution_feedback(action_label.text))
	update_ui()

func _show_doorway_choice_prompt(structure: DoorwayToTheVoid, card: Card, combat_death: bool = false, destruction: bool = false, continue_callback: Callable = Callable()) -> bool:
	if structure == null or card == null:
		return false
	_hide_doorway_choice_prompt()
	_pending_doorway_structure = structure
	_pending_doorway_card = card
	_pending_doorway_combat_death = combat_death
	_pending_doorway_destruction = destruction
	_pending_doorway_continue = continue_callback

	var panel := PanelContainer.new()
	panel.name = "DoorwayChoicePromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.97)
	style.border_color = Color(0.62, 0.36, 0.82, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(280, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = structure.card_name
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "%s chooses where %s goes." % [structure.card_owner.player_name, card.card_name]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	var grave_btn := Button.new()
	grave_btn.text = "Graveyard"
	grave_btn.pressed.connect(func() -> void: _resolve_doorway_destination(false))
	buttons.add_child(grave_btn)

	var abyss_btn := Button.new()
	abyss_btn.text = "Abyss"
	abyss_btn.pressed.connect(func() -> void: _resolve_doorway_destination(true))
	buttons.add_child(abyss_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	_doorway_prompt_panel = panel
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -290
	panel.offset_right = -10
	panel.offset_top = 85
	panel.offset_bottom = 165
	return true

func _hide_doorway_choice_prompt() -> void:
	if _doorway_prompt_panel != null and is_instance_valid(_doorway_prompt_panel):
		_doorway_prompt_panel.queue_free()
	_doorway_prompt_panel = null
	_pending_doorway_structure = null
	_pending_doorway_card = null
	_pending_doorway_combat_death = false
	_pending_doorway_destruction = false
	_pending_doorway_continue = Callable()

func _on_doorway_choice_requested(structure: DoorwayToTheVoid, card: Card, combat_death: bool, destruction: bool) -> void:
	var target_player := structure.card_owner if structure != null else game_manager.current_player
	
	if network_manager != null and network_manager.is_server:
		if _executing_stack_action and not _stack_resolution_paused:
			_pause_stack_resolution(target_player)
			
	if _is_player_local(target_player):
		_show_doorway_choice_prompt(structure, card, combat_death, destruction)

func _ready() -> void:
	add_to_group("combat_mock_game")
	choice_container.visible = false
	end_turn_button.visible = false
	placement_container.visible = false
	board_container.size_flags_vertical = Control.SIZE_FILL
	enemy_board_container.size_flags_vertical = Control.SIZE_FILL
	top_spacer.size_flags_vertical = 0
	hand_container.size_flags_vertical = 0
	hand_container.visible = false
	center_panel.add_theme_constant_override("separation", CENTER_PANEL_SECTION_GAP)
	top_spacer.custom_minimum_size.y = 0
	board_separator.custom_minimum_size.y = BOARD_SEPARATOR_HEIGHT
	board_separator.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_separator.clip_contents = false
	board_separator.mouse_filter = Control.MOUSE_FILTER_PASS
	board_separator.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	left_panel.custom_minimum_size.x = LEFT_PANEL_MIN_WIDTH + BOARD_RIGHT_NUDGE
	left_top_spacer.visible = true
	left_bottom_spacer.visible = true
	right_panel.custom_minimum_size.x = RIGHT_PANEL_MIN_WIDTH
	right_panel.add_theme_constant_override("separation", RIGHT_PANEL_CONTROL_GAP)
	forfeit_button.offset_left = -112.0
	forfeit_button.offset_right = -2.0

	draw_button.pressed.connect(_on_draw_button_pressed)
	mana_button.pressed.connect(_on_mana_button_pressed)
	_setup_turn_choice_buttons()
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	forfeit_button.pressed.connect(_on_forfeit_button_pressed)
	all_attack_btn.pressed.connect(_on_all_attack_followers_pressed)
	aggressive_stance_btn.pressed.connect(_on_aggressive_stance_pressed)
	defensive_stance_btn.pressed.connect(_on_defensive_stance_pressed)
	stealth_mode_btn.pressed.connect(_on_stealth_mode_pressed)

	var priority_toggle := CheckButton.new()
	priority_toggle.text = "Auto Priority"
	priority_toggle.button_pressed = auto_priority
	priority_toggle.custom_minimum_size = Vector2(RIGHT_PANEL_MIN_WIDTH - 20.0, 24.0)
	priority_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	priority_toggle.add_theme_font_size_override("font_size", RIGHT_PANEL_TEXT_FONT_SIZE)
	priority_toggle.toggled.connect(func(on: bool) -> void: auto_priority = on)

	$MainHBox/RightPanel.add_child(priority_toggle)
	_setup_center_action_panel()
	if not board_container.resized.is_connected(_on_board_layout_resized):
		board_container.resized.connect(_on_board_layout_resized)
	if not enemy_board_container.resized.is_connected(_on_board_layout_resized):
		enemy_board_container.resized.connect(_on_board_layout_resized)
	if not center_panel.resized.is_connected(_on_board_layout_resized):
		center_panel.resized.connect(_on_board_layout_resized)
	_setup_action_log()
	_capture_action_log_message(true)

	_restore_default_selection_cursor()

func _exit_tree() -> void:
	_hide_devour_cancel_prompt()
	_restore_default_selection_cursor()

func _is_sacrifice_cursor_mode_active() -> bool:
	return _awaiting_creature_sacrifice or _is_blot_sacrifice_target_selection_active()

func _is_devour_cursor_mode_active() -> bool:
	return _has_pending_click_selection() and _get_pending_target_selection_name().contains("Devour")

func _is_silence_cursor_mode_active() -> bool:
	if _pending_absence_spell != null:
		return false
	if _has_pending_click_selection():
		return _is_silence_or_mute_targeting_source(_pending_click_selection_source) \
			and _is_live_silence_targeting_source(_pending_click_selection_source)
	if awaiting_spell_target and spell_waiting_for_target != null:
		return _is_silence_or_mute_targeting_source(spell_waiting_for_target) \
			and _is_live_silence_targeting_source(spell_waiting_for_target)
	return false

func _is_giant_master_architect_cursor_mode_active() -> bool:
	return _overlay_selection_cursor_mode == "giant_master_architect_structure"

func _is_gugalanna_cursor_mode_active() -> bool:
	return _overlay_selection_cursor_mode == "gugalanna_celestial_charge"

func _is_guan_yu_cursor_mode_active() -> bool:
	return awaiting_god_ability_target and god_ability_source is GuanYu

func _is_silence_or_mute_targeting_source(card: Card) -> bool:
	if card == null:
		return false
	if card is Absence or card is FirstSageAdapa:
		return true
	var ability_text_value := String(card.ability_text).to_lower()
	return ability_text_value.contains("silence") or ability_text_value.contains("mute")

func _is_live_silence_targeting_source(card: Card) -> bool:
	if card == null or card.current_zone == null:
		return false
	if card.card_type in [Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM]:
		return card.current_zone == card.card_owner.hand_zone or card.current_zone.is_board_zone()
	return card.current_zone.is_board_zone()

func _hide_devour_cancel_prompt() -> void:
	if _devour_cancel_prompt != null and is_instance_valid(_devour_cancel_prompt):
		_devour_cancel_prompt.queue_free()
	_devour_cancel_prompt = null

func _get_target_cancel_prompt_title() -> String:
	var selection_name := _get_pending_target_selection_name()
	if _is_devour_cursor_mode_active():
		return "Cancel Devour?"
	if selection_name.strip_edges() == "":
		return "Cancel Targeting?"
	return "Cancel " + selection_name + "?"

func _get_target_cancel_prompt_info() -> String:
	if _is_devour_cursor_mode_active():
		return "Click Confirm to cancel the current Devour target selection, or Keep Selecting to continue."
	return "Click Confirm to cancel the current target selection, or Keep Selecting to continue."

func _get_target_keep_selecting_text() -> String:
	if _is_devour_cursor_mode_active():
		return "Click a Devour target."
	var selection_name := _get_pending_target_selection_name()
	if selection_name.strip_edges() == "":
		return "Click a valid target."
	return selection_name + ": click a valid target."

func _show_target_cancel_prompt() -> void:
	if not _has_pending_target_selection():
		return
	_hide_devour_cancel_prompt()

	var panel := PanelContainer.new()
	panel.name = "DevourCancelPromptPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.top_level = true

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.04, 0.04, 0.96)
	style.border_color = Color(0.82, 0.22, 0.18, 0.98)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(320.0, 0.0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(260.0, 0.0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = _get_target_cancel_prompt_title()
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.9))
	vbox.add_child(title)

	var info := Label.new()
	info.text = _get_target_cancel_prompt_info()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", Color(0.95, 0.88, 0.88))
	vbox.add_child(info)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.pressed.connect(func() -> void:
		_hide_devour_cancel_prompt()
		_cancel_pending_target_selection(_get_pending_target_selection_name() + " cancelled.")
	)
	buttons.add_child(confirm_btn)

	var keep_btn := Button.new()
	keep_btn.text = "Keep Selecting"
	keep_btn.pressed.connect(func() -> void:
		_hide_devour_cancel_prompt()
		action_label.text = _get_target_keep_selecting_text()
		update_ui()
	)
	buttons.add_child(keep_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	_devour_cancel_prompt = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	call_deferred("_position_devour_cancel_prompt")

func _show_devour_cancel_prompt() -> void:
	_show_target_cancel_prompt()

func _position_devour_cancel_prompt() -> void:
	if _devour_cancel_prompt == null or not is_instance_valid(_devour_cancel_prompt):
		return
	var prompt_size := _devour_cancel_prompt.get_combined_minimum_size()
	if prompt_size == Vector2.ZERO:
		prompt_size = _devour_cancel_prompt.custom_minimum_size
	_devour_cancel_prompt.size = prompt_size
	var viewport_size := get_viewport_rect().size
	_devour_cancel_prompt.global_position = (viewport_size - prompt_size) * 0.5

func _get_selection_cursor_mode() -> String:
	if _is_gugalanna_cursor_mode_active():
		return "gugalanna"
	if _is_giant_master_architect_cursor_mode_active():
		return "giant_master_architect"
	if _is_guan_yu_cursor_mode_active():
		return "guan_yu"
	if _is_sacrifice_cursor_mode_active():
		return "sacrifice"
	if _is_devour_cursor_mode_active():
		return "devour"
	if _is_silence_cursor_mode_active():
		return "silence"
	return ""

func _build_cursor_texture(source_texture: Texture2D, target_height_limit: int) -> Texture2D:
	if source_texture == null:
		return null
	var source_image := source_texture.get_image()
	if source_image == null or source_image.is_empty():
		return null

	var used_rect := source_image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return ImageTexture.create_from_image(source_image)

	var cursor_image := source_image.get_region(used_rect)
	if cursor_image == null or cursor_image.is_empty():
		return null

	var target_height := mini(target_height_limit, cursor_image.get_height())
	var cursor_scale := float(target_height) / float(cursor_image.get_height())
	var target_width := maxi(1, int(round(cursor_image.get_width() * cursor_scale)))
	cursor_image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(cursor_image)

func _get_cursor_hotspot(texture: Texture2D, hotspot_ratio: Vector2) -> Vector2:
	if texture == null:
		return Vector2.ZERO

	return Vector2(
		clampi(
			int(round(float(texture.get_width()) * hotspot_ratio.x)),
			0,
			maxi(0, texture.get_width() - 1)
		),
		clampi(
			int(round(float(texture.get_height()) * hotspot_ratio.y)),
			0,
			maxi(0, texture.get_height() - 1)
		)
	)

func _apply_sacrifice_cursor() -> bool:
	if _sacrifice_cursor_texture == null:
		_sacrifice_cursor_texture = _build_cursor_texture(SacrificeCursorSource, SACRIFICE_CURSOR_TARGET_HEIGHT)
	if _sacrifice_cursor_texture == null:
		return false

	var hotspot := _get_cursor_hotspot(_sacrifice_cursor_texture, SACRIFICE_CURSOR_HOTSPOT_RATIO)
	for cursor_shape in SACRIFICE_CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(_sacrifice_cursor_texture, cursor_shape, hotspot)
	return true

func _apply_devour_cursor() -> bool:
	if _devour_cursor_texture == null:
		_devour_cursor_texture = _build_cursor_texture(DevourCursorSource, DEVOUR_CURSOR_TARGET_HEIGHT)
	if _devour_cursor_texture == null:
		return false

	var hotspot := _get_cursor_hotspot(_devour_cursor_texture, DEVOUR_CURSOR_HOTSPOT_RATIO)
	for cursor_shape in SACRIFICE_CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(_devour_cursor_texture, cursor_shape, hotspot)
	return true

func _apply_silence_cursor() -> bool:
	if _silence_cursor_texture == null:
		_silence_cursor_texture = _build_cursor_texture(SilenceCursorSource, SILENCE_CURSOR_TARGET_HEIGHT)
	if _silence_cursor_texture == null:
		return false

	var hotspot := _get_cursor_hotspot(_silence_cursor_texture, SILENCE_CURSOR_HOTSPOT_RATIO)
	for cursor_shape in SACRIFICE_CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(_silence_cursor_texture, cursor_shape, hotspot)
	return true

func _apply_gugalanna_cursor() -> bool:
	if _gugalanna_cursor_texture == null:
		_gugalanna_cursor_texture = _build_cursor_texture(GugalannaCursorSource, GUGALANNA_CURSOR_TARGET_HEIGHT)
	if _gugalanna_cursor_texture == null:
		return false
	var hotspot := _get_cursor_hotspot(_gugalanna_cursor_texture, GUGALANNA_CURSOR_HOTSPOT_RATIO)
	for cursor_shape in SACRIFICE_CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(_gugalanna_cursor_texture, cursor_shape, hotspot)
	return true

func _apply_giant_master_architect_cursor() -> bool:
	if _giant_master_architect_cursor_texture == null:
		_giant_master_architect_cursor_texture = _build_cursor_texture(
			GiantMasterArchitectCursorSource,
			GIANT_MASTER_ARCHITECT_CURSOR_TARGET_HEIGHT
		)
	if _giant_master_architect_cursor_texture == null:
		return false

	var hotspot := _get_cursor_hotspot(
		_giant_master_architect_cursor_texture,
		GIANT_MASTER_ARCHITECT_CURSOR_HOTSPOT_RATIO
	)
	for cursor_shape in SACRIFICE_CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(_giant_master_architect_cursor_texture, cursor_shape, hotspot)
	return true

func _apply_guan_yu_cursor() -> bool:
	if _guan_yu_cursor_texture == null:
		_guan_yu_cursor_texture = _build_cursor_texture(
			GuanYuCursorSource,
			GUAN_YU_CURSOR_TARGET_HEIGHT
		)
	if _guan_yu_cursor_texture == null:
		return false

	var hotspot := _get_cursor_hotspot(_guan_yu_cursor_texture, GUAN_YU_CURSOR_HOTSPOT_RATIO)
	for cursor_shape in SACRIFICE_CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(_guan_yu_cursor_texture, cursor_shape, hotspot)
	return true

func _restore_default_selection_cursor() -> void:
	for cursor_shape in SACRIFICE_CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(null, cursor_shape)
		_active_selection_cursor_mode = ""

func _sync_sacrifice_cursor() -> void:
	var cursor_mode := _get_selection_cursor_mode()
	if cursor_mode == _active_selection_cursor_mode:
		return

	if cursor_mode == "gugalanna":
		if _apply_gugalanna_cursor():
			_active_selection_cursor_mode = "gugalanna"
		else:
			_restore_default_selection_cursor()
		return

	if cursor_mode == "guan_yu":
		if _apply_guan_yu_cursor():
			_active_selection_cursor_mode = "guan_yu"
		else:
			_restore_default_selection_cursor()
		return

	if cursor_mode == "sacrifice":
		if _apply_sacrifice_cursor():
			_active_selection_cursor_mode = "sacrifice"
		else:
			_restore_default_selection_cursor()
		return

	if cursor_mode == "devour":
		if _apply_devour_cursor():
			_active_selection_cursor_mode = "devour"
		else:
			_restore_default_selection_cursor()
		return

	if cursor_mode == "silence":
		if _apply_silence_cursor():
			_active_selection_cursor_mode = "silence"
		else:
			_restore_default_selection_cursor()
		return

	if cursor_mode == "giant_master_architect":
		if _apply_giant_master_architect_cursor():
			_active_selection_cursor_mode = "giant_master_architect"
		else:
			_restore_default_selection_cursor()
		return

	_restore_default_selection_cursor()

func _setup_center_action_panel() -> void:
	if right_panel == null:
		return
	if _center_action_panel != null and is_instance_valid(_center_action_panel):
		_center_action_panel.queue_free()
	_center_action_panel = null
	if _board_separator_line != null and is_instance_valid(_board_separator_line):
		_board_separator_line.queue_free()
	_board_separator_line = null
	_reparent_control(turn_label, right_panel)
	_reparent_control(end_turn_button, right_panel)
	_reparent_control(all_attack_btn, right_panel)
	var insert_index := right_panel.get_children().find(right_bottom_spacer)
	if insert_index < 0:
		insert_index = right_panel.get_child_count()
	right_panel.move_child(turn_label, insert_index)
	right_panel.move_child(end_turn_button, insert_index + 1)
	right_panel.move_child(all_attack_btn, insert_index + 2)
	turn_label.custom_minimum_size = Vector2(RIGHT_PANEL_MIN_WIDTH - 4.0, 24.0)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", RIGHT_PANEL_TEXT_FONT_SIZE)
	end_turn_button.custom_minimum_size = Vector2(RIGHT_PANEL_MIN_WIDTH - 4.0, CENTER_ACTION_BUTTON_HEIGHT)
	end_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_turn_button.add_theme_font_size_override("font_size", RIGHT_PANEL_TEXT_FONT_SIZE)
	all_attack_btn.custom_minimum_size = Vector2(RIGHT_PANEL_MIN_WIDTH - 4.0, CENTER_ACTION_BUTTON_HEIGHT)
	all_attack_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all_attack_btn.add_theme_font_size_override("font_size", RIGHT_PANEL_TEXT_FONT_SIZE)
	right_top_spacer.visible = true
	right_bottom_spacer.visible = true

func _reparent_control(node: Control, new_parent: Control) -> void:
	if node == null or new_parent == null:
		return
	var old_parent := node.get_parent()
	if old_parent != null:
		old_parent.remove_child(node)
	new_parent.add_child(node)

func _update_center_action_panel_layout() -> void:
	if board_separator == null or _center_action_panel == null:
		return
	_center_action_panel.size = _center_action_panel.custom_minimum_size
	if _board_separator_line != null and is_instance_valid(_board_separator_line):
		_board_separator_line.position = Vector2.ZERO
		_board_separator_line.size = Vector2(_get_separator_line_width(), BOARD_SEPARATOR_HEIGHT)
	_center_action_panel.position = Vector2(
		maxf(0.0, (_get_separator_line_width() - _center_action_panel.size.x) * 0.5),
		BOARD_SEPARATOR_HEIGHT * 0.5 - _center_action_panel.size.y * 0.5
	)

func _process(_delta: float) -> void:
	_sync_sacrifice_cursor()
	_capture_action_log_message()

func _setup_action_log() -> void:
	if action_label == null:
		return
	var action_parent := action_label.get_parent()
	if action_parent == null:
		return
	action_label.visible = false

	var log_box := VBoxContainer.new()
	log_box.name = "ActionLogBox"
	log_box.add_theme_constant_override("separation", 4)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	log_box.add_child(header)

	var log_title := Label.new()
	log_title.text = "Recent Log"
	log_title.add_theme_font_size_override("font_size", 10)
	header.add_child(log_title)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var history_button := Button.new()
	history_button.text = "..."
	history_button.flat = true
	history_button.tooltip_text = "Open older log entries"
	history_button.custom_minimum_size = Vector2(24.0, 24.0)
	history_button.add_theme_font_size_override("font_size", 14)
	history_button.pressed.connect(_toggle_action_log_popup)
	header.add_child(history_button)

	var log_text := RichTextLabel.new()
	log_text.name = "ActionLogText"
	log_text.bbcode_enabled = false
	log_text.fit_content = false
	log_text.scroll_active = false
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_text.custom_minimum_size = Vector2(ACTION_LOG_MIN_WIDTH, ACTION_LOG_PREVIEW_HEIGHT)
	log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_text.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	log_text.add_theme_font_size_override("normal_font_size", ACTION_LOG_FONT_SIZE)
	log_text.add_theme_constant_override("line_separation", ACTION_LOG_LINE_SEPARATION)
	log_text.selection_enabled = true

	log_box.add_child(log_text)
	var log_shell := MarginContainer.new()
	log_shell.name = "ActionLogShell"
	log_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_shell.add_theme_constant_override("margin_left", ACTION_LOG_LEFT_INSET)
	log_shell.add_child(log_box)
	action_parent.add_child(log_shell)
	action_parent.move_child(log_shell, action_parent.get_children().find(action_label) + 1)

	var choice_gap := Control.new()
	choice_gap.name = "TurnChoiceGap"
	choice_gap.custom_minimum_size = Vector2(0.0, TURN_CHOICE_TOP_GAP)
	action_parent.add_child(choice_gap)
	action_parent.move_child(choice_gap, action_parent.get_children().find(log_shell) + 1)

	_action_log_view = log_text
	_action_log_history_button = history_button
	_refresh_action_log()

func _get_right_action_stack_height() -> float:
	if turn_label == null or end_turn_button == null or all_attack_btn == null or right_panel == null:
		return 0.0
	var separation: float = float(right_panel.get_theme_constant("separation"))
	return turn_label.get_combined_minimum_size().y \
		+ end_turn_button.get_combined_minimum_size().y \
		+ all_attack_btn.get_combined_minimum_size().y \
		+ separation * 2.0

func _update_side_panel_layout() -> void:
	var stats_height: float = BoardZoneUI.get_zone_extent()
	left_top_spacer.custom_minimum_size.y = stats_height
	left_bottom_spacer.custom_minimum_size.y = stats_height
	left_top_spacer.size_flags_vertical = 0
	left_bottom_spacer.size_flags_vertical = 0
	var action_stack_height: float = _get_right_action_stack_height()
	var board_midpoint: float = stats_height * 2.0 + BOARD_SEPARATOR_HEIGHT * 0.5
	right_top_spacer.custom_minimum_size.y = maxf(0.0, board_midpoint - action_stack_height * 0.5)
	right_top_spacer.size_flags_vertical = 0
	right_bottom_spacer.custom_minimum_size.y = 0.0
	right_bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _capture_action_log_message(force: bool = false) -> void:
	if action_label == null:
		return
	var message = action_label.text.strip_edges()
	if message == "":
		return
	if not force and message == _last_logged_action_text:
		return
	_last_logged_action_text = message
	_action_log_messages.append(message)
	if _action_log_messages.size() > ACTION_LOG_MAX_MESSAGES:
		_action_log_messages.pop_front()
	_refresh_action_log()

func _refresh_action_log() -> void:
	if _action_log_view == null or not is_instance_valid(_action_log_view):
		return
	var preview_messages := _get_action_log_preview_messages()
	_action_log_view.text = "\n".join(preview_messages) if not preview_messages.is_empty() else "No actions yet."
	_refresh_action_log_history_button()
	_refresh_action_log_popup()

func _get_action_log_preview_messages() -> Array[String]:
	var preview_messages: Array[String] = []
	var start_index := maxi(0, _action_log_messages.size() - ACTION_LOG_PREVIEW_COUNT)
	for i in range(start_index, _action_log_messages.size()):
		preview_messages.append(_action_log_messages[i])
	return preview_messages

func _get_action_log_history_messages() -> Array[String]:
	var history_messages: Array[String] = []
	var cutoff := maxi(0, _action_log_messages.size() - ACTION_LOG_PREVIEW_COUNT)
	for i in range(cutoff):
		history_messages.append(_action_log_messages[i])
	return history_messages

func _refresh_action_log_history_button() -> void:
	if _action_log_history_button == null or not is_instance_valid(_action_log_history_button):
		return
	var has_history := _action_log_messages.size() > ACTION_LOG_PREVIEW_COUNT
	_action_log_history_button.disabled = not has_history
	_action_log_history_button.tooltip_text = "Open older log entries" if has_history else "No older log entries yet"
	_action_log_history_button.modulate = Color(1, 1, 1, 1) if has_history else Color(1, 1, 1, 0.45)

func _toggle_action_log_popup() -> void:
	if _action_log_popup != null and is_instance_valid(_action_log_popup):
		_close_action_log_popup()
		return
	_open_action_log_popup()

func _open_action_log_popup() -> void:
	if _action_log_messages.size() <= ACTION_LOG_PREVIEW_COUNT:
		return
	_close_action_log_popup()

	var panel := PanelContainer.new()
	panel.name = "ActionLogPopupPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(ACTION_LOG_POPUP_WIDTH, ACTION_LOG_POPUP_HEIGHT)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.97)
	style.border_color = Color(0.78, 0.66, 0.34, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Log History"
	title.add_theme_font_size_override("font_size", 13)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close_action_log_popup)
	header.add_child(close_button)

	var history_view := RichTextLabel.new()
	history_view.name = "ActionLogPopupText"
	history_view.bbcode_enabled = false
	history_view.fit_content = false
	history_view.scroll_active = true
	history_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_view.selection_enabled = true
	history_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_view.custom_minimum_size = Vector2(ACTION_LOG_POPUP_WIDTH - 24.0, ACTION_LOG_POPUP_HEIGHT - 60.0)
	history_view.add_theme_font_size_override("normal_font_size", ACTION_LOG_FONT_SIZE)
	history_view.add_theme_constant_override("line_separation", ACTION_LOG_LINE_SEPARATION)
	vbox.add_child(history_view)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -ACTION_LOG_POPUP_WIDTH * 0.5
	panel.offset_right = ACTION_LOG_POPUP_WIDTH * 0.5
	panel.offset_top = -ACTION_LOG_POPUP_HEIGHT * 0.5
	panel.offset_bottom = ACTION_LOG_POPUP_HEIGHT * 0.5

	_action_log_popup = panel
	_action_log_popup_view = history_view
	_refresh_action_log_popup()

func _refresh_action_log_popup() -> void:
	if _action_log_popup_view == null or not is_instance_valid(_action_log_popup_view):
		return
	var history_messages := _get_action_log_history_messages()
	_action_log_popup_view.text = "\n".join(history_messages) if not history_messages.is_empty() else "No earlier log entries yet."
	call_deferred("_scroll_action_log_popup_to_bottom")

func _scroll_action_log_popup_to_bottom() -> void:
	if _action_log_popup_view == null or not is_instance_valid(_action_log_popup_view):
		return
	var bar := _action_log_popup_view.get_v_scroll_bar()
	if bar != null:
		_action_log_popup_view.scroll_to_line(maxi(0, _action_log_popup_view.get_line_count() - 1))

func _close_action_log_popup() -> void:
	if _action_log_popup != null and is_instance_valid(_action_log_popup):
		_action_log_popup.queue_free()
	_action_log_popup = null
	_action_log_popup_view = null

func start_game(
	is_host: bool = false,
	is_client: bool = false,
	server_ip: String = "127.0.0.1",
	server_port: int = 12345,
	match_info: Dictionary = {},
	server_match_session = null
) -> void:
	print("=== STARTING COMBAT MOCK GAME ===")
	_game_finished = false
	_current_match_info = match_info.duplicate(true)
	
	game_manager = GameManager.new()
	game_manager.set_interaction_host(self)
	match_manager = MatchManager.new(game_manager)
	prompt_router = PromptRouterScript.new(game_manager)
	headless_match_host = HeadlessMatchHostScript.new()
	headless_match_host.attach(game_manager, match_manager, prompt_router)
	if server_match_session != null:
		headless_match_host.configure_match_session(server_match_session)
	network_manager = headless_match_host.setup_transport(self, is_host, is_client, server_ip, server_port)
	match_client = MatchClientScript.new(
		match_manager,
		network_manager,
		headless_match_host.should_receive_network_events(),
		headless_match_host.is_networked_client(),
		match_info,
		server_ip,
		server_port
	)
	game_input = match_client.get_game_input()
	_is_networked_client = match_client.is_networked_client()
	
	if match_client.receives_network_events():
		match_client.game_event_received.connect(_apply_network_event)
		match_client.peer_disconnected.connect(_on_peer_disconnected)
	
	print("MatchManager initialized: ", match_manager)
	match_manager.action_resolved.connect(_on_match_action_resolved)
	
	# If we have a broadcaster, ui_interaction will come via network event instead
	var use_broadcaster: bool = headless_match_host != null and headless_match_host.should_route_prompts_via_network()
	if not use_broadcaster:
		match_manager.request_ui_interaction.connect(_on_match_ui_interaction)
	
	match_manager.move_validated.connect(_on_match_move_validated)
	match_manager.move_failed.connect(_on_match_move_failed)
	match_manager.targeting_started.connect(func(_source: Card, _target_type: String) -> void:
		_hide_devour_cancel_prompt()
		_sync_sacrifice_cursor()
	)
	match_manager.targeting_ended.connect(func() -> void:
		_hide_devour_cancel_prompt()
		_sync_sacrifice_cursor()
	)

	await get_tree().process_frame
	var default_match_setup = DefaultMatchSetupScript.new()
	var match_players: Dictionary = {}
	if server_match_session != null and not server_match_session.player_decks_by_session.is_empty():
		match_players = default_match_setup.build_match_from_session_decks(game_manager, server_match_session)
	if match_players.is_empty():
		match_players = default_match_setup.build_default_match(game_manager)
	player1 = match_players.get("player1", null)
	player2 = match_players.get("player2", null)
	if not game_manager.doorway_choice_requested.is_connected(_on_doorway_choice_requested):
		game_manager.doorway_choice_requested.connect(_on_doorway_choice_requested)
	if not game_manager.god_power_activated.is_connected(_on_god_power_activated):
		game_manager.god_power_activated.connect(_on_god_power_activated)
	if not game_manager.card_summoned.is_connected(_on_card_summoned):
		game_manager.card_summoned.connect(_on_card_summoned)

	player1.mana_changed.connect(_on_player_mana_changed)
	player1.followers_changed.connect(_on_player_followers_changed)
	player2.followers_changed.connect(_on_enemy_followers_changed)
	game_manager.game_ended.connect(_on_game_ended)

	# Broadcaster: server-side only, sends full state to clients after each action
	if headless_match_host != null and is_host:
		headless_match_host.enable_authoritative_broadcasts()
		game_event_broadcaster = headless_match_host.game_event_broadcaster

	if not player1.card_moved.is_connected(_on_local_player_card_moved):
		player1.card_moved.connect(_on_local_player_card_moved)
	if not player2.card_moved.is_connected(_on_local_player_card_moved):
		player2.card_moved.connect(_on_local_player_card_moved)
	
	for i in range(0):
		print("Ã‚Â  Drawing card ", i, " for P1")
		player1.draw_card()
		print("Ã‚Â  P1 hand size now: ", player1.hand_zone.cards.size())
		print("Ã‚Â  Drawing card ", i, " for P2")
		player2.draw_card()
		print("Ã‚Â  P2 hand size now: ", player2.hand_zone.cards.size())
	
	
	# Pin the server's view to Player 1 so the board never flips to P2's perspective
	if not _is_networked_client and game_manager.players.size() > 0:
		game_manager.feedback_viewer = game_manager.players[0]
	game_manager.start_turn()
	update_ui()
	_open_upkeep_choice_window()

func create_deck(player: Player) -> void:
	var deck: Array[Card] = []

	# Creatures
	deck.append(_own(Alu.new(), player))
	deck.append(_own(AsagTheDestroyer.new(), player))
	deck.append(_own(BrownBear.new(), player))
	deck.append(_own(AgainWalker.new(), player))
	deck.append(_own(Anzu.new(), player))
	deck.append(_own(Berserker.new(), player))
	deck.append(_own(Beyla.new(), player))
	deck.append(_own(BlessedKnights.new(), player))

	# Spells
	deck.append(_own(BitMeseri.new(), player))
	deck.append(_own(BitMeseri.new(), player))
	deck.append(_own(FallOfTheMighty.new(), player))
	deck.append(_own(CircleOfRebirth.new(), player))
	deck.append(_own(Absence.new(), player))
	deck.append(_own(Absence.new(), player))
	deck.append(_own(BlotSacrifice.new(), player))
	deck.append(_own(BlotSacrifice.new(), player))
	deck.append(_own(ApollyonsDemiurge.new(), player))

	# Structures
	deck.append(_own(WardingStone.new(), player))
	deck.append(_own(WardingStone.new(), player))

	# Hexes
	deck.append(_own(VoidShield.new(), player))
	deck.append(_own(VoidShield.new(), player))

	# Equipment
	deck.append(_own(BeardedAxe.new(), player))
	deck.append(_own(BeardedAxe.new(), player))

	deck.shuffle()
	for card in deck:
		player.deck_zone.add_card(card)

func _own(card: Card, player: Player) -> Card:
	card.card_owner = player
	return card

func show_turn_choice() -> void:
	if _game_finished:
		return
	choice_container.visible = true
	end_turn_button.visible = false
	_refresh_turn_choice_options()
	placement_container.visible = false

	for vc in _hand_visual_cards:
		vc.set_disabled(true)

func hide_turn_choice() -> void:
	if _game_finished:
		return
	choice_container.visible = false
	end_turn_button.visible = true
	_hide_sun_hunt_button()

	for vc in _hand_visual_cards:
		vc.set_disabled(false)

func _setup_turn_choice_buttons() -> void:
	if choice_container == null or _sun_hunt_button != null:
		return
	_sun_hunt_button = Button.new()
	_sun_hunt_button.name = "SunHuntButton"
	_sun_hunt_button.text = "Sun Hunt"
	_sun_hunt_button.visible = false
	_sun_hunt_button.pressed.connect(_on_sun_hunt_button_pressed)
	choice_container.add_child(_sun_hunt_button)

func _hide_sun_hunt_button() -> void:
	if _sun_hunt_button == null:
		return
	_sun_hunt_button.visible = false
	_sun_hunt_button.disabled = true

func _get_available_skoll_upkeep_cards() -> Array[Skoll]:
	var available: Array[Skoll] = []
	if game_manager == null or game_manager.current_player == null:
		return available
	for card in game_manager.current_player.hand_zone.cards:
		if card is Skoll and (card as Skoll).can_use_upkeep_summon(game_manager):
			available.append(card as Skoll)
	return available

func _refresh_turn_choice_options() -> void:
	choice_intro_label.text = "Choose one:"
	draw_button.text = "Draw Card"
	mana_button.text = "Gain 4 Mana"
	draw_button.disabled = false
	mana_button.disabled = false
	if _sun_hunt_button == null:
		return
	var available_skolls := _get_available_skoll_upkeep_cards()
	_sun_hunt_button.text = "Sun Hunt"
	_sun_hunt_button.visible = not available_skolls.is_empty()
	_sun_hunt_button.disabled = available_skolls.is_empty()

func _lock_turn_choice_for_sun_hunt() -> void:
	choice_intro_label.text = "Choose one:"
	draw_button.disabled = true
	mana_button.disabled = true
	if _sun_hunt_button != null:
		_sun_hunt_button.visible = true
		_sun_hunt_button.disabled = true

func _restore_turn_choice_after_skoll_prompt() -> void:
	_clear_skoll_upkeep_summon()
	_refresh_turn_choice_options()
	if _is_turn_choice_pending():
		action_label.text = "Choose Draw Card, Gain 4 Mana, or Sun Hunt."

func _can_interact_with_board_during_turn_choice(card: Card = null) -> bool:
	if _pending_skoll_summon != null:
		return true
	if _awaiting_creature_sacrifice or _awaiting_altar_void_payment or _awaiting_drag_sacrifice_zone:
		return true
	if card != null and _can_activate_before_turn_choice(card):
		return true
	return false

func update_ui() -> void:
	if game_manager == null:
		return
	if _is_networked_client or (network_manager != null and network_manager.get("is_server") == true):
		if _ui_update_pending:
			return
		_ui_update_pending = true
		call_deferred("_do_update_ui")
		return
	_do_update_ui()

func _do_update_ui() -> void:
	_ui_update_pending = false
	if game_manager == null:
		return
	_hide_power_hover_popup()
	_sync_blot_sacrifice_prompt_state()
	_capture_action_log_message()
	_update_board_zone_extent()
	var current = game_manager.turn_player if game_manager.turn_player != null else game_manager.current_player
	if current == null or game_manager.current_player == null or game_manager.other_player == null:
		if turn_label != null:
			turn_label.text = "Turn " + str(game_manager.turn_number)
		return

	turn_label.text = "Turn " + str(game_manager.turn_number) + " - " + current.player_name + "'s Turn"

	draw_hand()
	draw_board()
	draw_enemy_board()
	_sync_stack_zone_previews()

func _get_board_zone_extent_target() -> float:
	var base_extent := BoardZoneUI.get_base_zone_extent()
	if center_panel == null:
		return base_extent

	var available_width: float = center_panel.size.x - ZONE_INFO_ICON_SIZE - BOARD_ZONE_COLUMN_GAP * BOARD_MAIN_COLUMN_COUNT
	if available_width <= 0.0:
		return base_extent

	var section_gap_count := 3.0
	if hand_container != null and hand_container.visible:
		section_gap_count += 1.0
	var available_height: float = center_panel.size.y \
		- HAND_LAYOUT_RESERVED \
		- BOARD_SEPARATOR_HEIGHT \
		- (CENTER_PANEL_SECTION_GAP * section_gap_count)
	if available_height <= 0.0:
		return base_extent

	var horizontal_extent: float = floor(available_width / BOARD_MAIN_COLUMN_COUNT)
	var vertical_extent: float = floor(available_height / BOARD_ROW_COUNT) - BOARD_SIZE_TRIM
	return maxf(base_extent, minf(horizontal_extent, vertical_extent))

func _update_board_zone_extent() -> void:
	BoardZoneUI.set_zone_extent(_get_board_zone_extent_target())
	var board_half_height: float = BoardZoneUI.get_zone_extent() * 2.0
	_update_side_panel_layout()
	if enemy_board_container != null:
		enemy_board_container.custom_minimum_size.y = board_half_height
	if board_container != null:
		board_container.custom_minimum_size.y = board_half_height
	if hand_container != null:
		hand_container.custom_minimum_size.y = HAND_LAYOUT_RESERVED
	if board_separator != null:
		board_separator.custom_minimum_size = Vector2(_get_board_row_width(), BOARD_SEPARATOR_HEIGHT)
	call_deferred("_update_center_action_panel_layout")

func _on_board_layout_resized() -> void:
	if _fan_container != null and is_instance_valid(_fan_container):
		call_deferred("_layout_fan")
	if game_manager == null:
		return
	if not is_equal_approx(_get_board_zone_extent_target(), BoardZoneUI.get_zone_extent()):
		_request_ui_refresh()

func _get_zone_ui_for_zone(zone: Zone) -> BoardZoneUI:
	if zone == null:
		return null
	if _player_god_zone_ui != null and is_instance_valid(_player_god_zone_ui) and _player_god_zone_ui.zone == zone:
		return _player_god_zone_ui
	if _enemy_god_zone_ui != null and is_instance_valid(_enemy_god_zone_ui) and _enemy_god_zone_ui.zone == zone:
		return _enemy_god_zone_ui
	for zone_ui in _board_zone_uis:
		if zone_ui != null and is_instance_valid(zone_ui) and zone_ui.zone == zone:
			return zone_ui
	for zone_ui in _enemy_zone_uis:
		if zone_ui != null and is_instance_valid(zone_ui) and zone_ui.zone == zone:
			return zone_ui
	return null

func _sync_stack_zone_previews() -> void:
	for zone_ui in _board_zone_uis:
		if zone_ui != null and is_instance_valid(zone_ui):
			zone_ui.set_preview_card(null)
	for zone_ui in _enemy_zone_uis:
		if zone_ui != null and is_instance_valid(zone_ui):
			zone_ui.set_preview_card(null)
	if _player_god_zone_ui != null and is_instance_valid(_player_god_zone_ui):
		_player_god_zone_ui.set_preview_card(null)
	if _enemy_god_zone_ui != null and is_instance_valid(_enemy_god_zone_ui):
		_enemy_god_zone_ui.set_preview_card(null)
	for action in game_manager.action_stack:
		if action == null or action.card == null or action.display_zone == null:
			continue
		var zone_ui := _get_zone_ui_for_zone(action.display_zone)
		if zone_ui != null and is_instance_valid(zone_ui):
			zone_ui.set_preview_card(action.card)
	if _pending_paid_hand_card != null and _pending_paid_hand_display_zone != null:
		var paid_zone_ui := _get_zone_ui_for_zone(_pending_paid_hand_display_zone)
		if paid_zone_ui != null and is_instance_valid(paid_zone_ui):
			paid_zone_ui.set_preview_card(_pending_paid_hand_card)
	if _pending_blot_spell != null and _pending_blot_display_zone != null:
		var blot_zone_ui := _get_zone_ui_for_zone(_pending_blot_display_zone)
		if blot_zone_ui != null and is_instance_valid(blot_zone_ui):
			blot_zone_ui.set_preview_card(_pending_blot_spell)
	if awaiting_spell_target and spell_waiting_for_target != null and spell_waiting_for_display_zone != null:
		var pending_zone_ui := _get_zone_ui_for_zone(spell_waiting_for_display_zone)
		if pending_zone_ui != null and is_instance_valid(pending_zone_ui):
			pending_zone_ui.set_preview_card(spell_waiting_for_target)

func _find_available_stack_display_zone(player: Player) -> Zone:
	if player == null:
		return null
	for zone in player.frontline_zones + player.reserve_zones:
		if zone.cards.size() > 0:
			continue
		var already_reserved := false
		for action in game_manager.action_stack:
			if action != null and action.display_zone == zone:
				already_reserved = true
				break
		if not already_reserved:
			return zone
	return null

func _get_available_stack_display_zones(player: Player) -> Array[Zone]:
	var zones: Array[Zone] = []
	if player == null:
		return zones
	for zone in player.frontline_zones + player.reserve_zones:
		if zone.cards.size() > 0:
			continue
		var already_reserved := false
		for action in game_manager.action_stack:
			if action != null and action.display_zone == zone:
				already_reserved = true
				break
		if not already_reserved:
			zones.append(zone)
	return zones

func _find_nearest_stack_display_zone(player: Player, reference_zone: Zone) -> Zone:
	if player == null or reference_zone == null:
		return null
	var reference_ui := _get_zone_ui_for_zone(reference_zone)
	if reference_ui == null or not is_instance_valid(reference_ui):
		return _find_available_stack_display_zone(player)
	var reference_point := reference_ui.get_visual_anchor_global()
	var best_zone: Zone = null
	var best_distance := INF
	for candidate in _get_available_stack_display_zones(player):
		var candidate_ui := _get_zone_ui_for_zone(candidate)
		if candidate_ui == null or not is_instance_valid(candidate_ui):
			continue
		var distance := candidate_ui.get_visual_anchor_global().distance_squared_to(reference_point)
		if distance < best_distance:
			best_distance = distance
			best_zone = candidate
	if best_zone != null:
		return best_zone
	return _find_available_stack_display_zone(player)

func _resolve_stack_display_zone(source_card: Card, source_player: Player) -> Zone:
	if source_card != null and source_card.current_zone != null and source_card.current_zone.is_board_zone():
		return source_card.current_zone
	return _find_available_stack_display_zone(source_player)

func _assign_stack_display_zone(action: CardAction) -> void:
	if action == null or action.card == null:
		return
	if not action.card.goes_to_graveyard_after_use():
		return
	if action.display_zone != null:
		return
	action.display_zone = _resolve_stack_display_zone(action.card, action.source_player)

func _resolve_pending_display_zone(card: Card, preferred_zone: Zone = null) -> Zone:
	var source_player := card.card_owner if card != null and card.card_owner != null else game_manager.current_player
	if preferred_zone != null and preferred_zone.is_board_zone():
		if preferred_zone.zone_owner == source_player:
			return preferred_zone
		var nearest_zone := _find_nearest_stack_display_zone(source_player, preferred_zone)
		if nearest_zone != null:
			return nearest_zone
	if card != null and card.current_zone != null and card.current_zone.is_board_zone() and card.current_zone.zone_owner == source_player:
		return card.current_zone
	return _find_available_stack_display_zone(source_player)

func _begin_paid_hand_card_preview(card: Card, preferred_zone: Zone = null) -> Zone:
	if card == null:
		return null
	_pending_paid_hand_card = card
	_pending_paid_hand_display_zone = _resolve_pending_display_zone(card, preferred_zone)
	_pending_paid_hand_display_zone_auto = preferred_zone == null
	return _pending_paid_hand_display_zone

func _get_paid_hand_card_display_zone(card: Card) -> Zone:
	if _pending_paid_hand_card == card:
		return _pending_paid_hand_display_zone
	return null

func _clear_paid_hand_card_preview(card: Card = null) -> void:
	if card != null and _pending_paid_hand_card != card:
		return
	_pending_paid_hand_card = null
	_pending_paid_hand_display_zone = null
	_pending_paid_hand_display_zone_auto = false
	_pending_spell_display_zone = null

func _sync_blot_sacrifice_prompt_state() -> void:
	if _pending_blot_spell == null:
		if _blot_panel != null and is_instance_valid(_blot_panel):
			_blot_panel.free()
		_blot_panel = null
		return
	if _blot_panel == null or not is_instance_valid(_blot_panel):
		_blot_panel = null
	_show_blot_creature_prompt()
	_sanitize_blot_selected_creatures()
	if _pending_blot_spell == null:
		return
	if _blot_has_more_summonable_creatures(_pending_blot_spell):
		return
	if _pending_blot_selected_creatures.is_empty():
		_hide_blot_sacrifice_prompt()
		action_label.text = "Blot Sacrifice: no more creatures to summon."
		return
	_on_blot_sacrifice_confirm_pressed()

func _is_blot_selection_active() -> bool:
	return _pending_blot_spell != null and _pending_blot_sacrifice_target != null

func _is_blot_sacrifice_target_selection_active() -> bool:
	return _has_pending_click_selection() and _pending_click_selection_source != null and (_pending_click_selection_source is BlotSacrifice or _pending_click_selection_source.card_name == "Blot Sacrifice")

func _cancel_blot_sacrifice_target_selection(reason: String) -> bool:
	if not _is_blot_sacrifice_target_selection_active():
		return false
	return _cancel_pending_target_selection(reason)

func _sanitize_blot_selected_creatures() -> void:
	if _pending_blot_selected_creatures.is_empty():
		return
	var cleaned: Array[Card] = []
	var hand_zone := game_manager.current_player.hand_zone
	for creature in _pending_blot_selected_creatures:
		if creature == null:
			continue
		if creature.current_zone != hand_zone and creature not in hand_zone.cards:
			continue
		if creature in cleaned:
			continue
		cleaned.append(creature)
	_pending_blot_selected_creatures = cleaned

func _get_blot_remaining_levels() -> int:
	_sanitize_blot_selected_creatures()
	var used_levels: int = 0
	for chosen_card in _pending_blot_selected_creatures:
		used_levels += chosen_card.level
	return maxi(0, BlotSacrifice.MAX_SUMMON_LEVELS - used_levels)

func _get_blot_valid_choices(spell) -> Array[Card]:
	if spell == null:
		return []
	return spell.get_valid_hand_creatures(_get_blot_remaining_levels(), _pending_blot_selected_creatures)

func _get_blot_selection_summary() -> String:
	var chosen_count := _pending_blot_selected_creatures.size()
	var remaining_levels := _get_blot_remaining_levels()
	var open_zones = _pending_blot_spell.get_available_summon_zones().size() if _pending_blot_spell != null else 0
	return "Chosen %d  |  Levels left %d/%d  |  Open zones %d" % [
		chosen_count,
		remaining_levels,
		BlotSacrifice.MAX_SUMMON_LEVELS,
		open_zones
	]

func _try_add_creature_to_blot(card: Card) -> bool:
	var spell = _pending_blot_spell
	if not _is_blot_selection_active() or spell == null or card == null:
		return false
	if card.current_zone != game_manager.current_player.hand_zone:
		return true
	if card.card_type != Card.CardType.CREATURE or card.is_god:
		action_label.text = "Blot Sacrifice: click a green creature in hand."
		update_ui()
		return true

	_sanitize_blot_selected_creatures()
	var available_slots: int = spell.get_available_summon_zones().size()
	if _pending_blot_selected_creatures.size() >= available_slots:
		action_label.text = "Blot Sacrifice has no remaining summon slots."
		update_ui()
		return true

	var valid_choices: Array[Card] = _get_blot_valid_choices(spell)
	if card in _pending_blot_selected_creatures:
		_pending_blot_selected_creatures.erase(card)
		action_label.text = card.card_name + " removed from Blot Sacrifice."
		_show_blot_creature_prompt()
		update_ui()
		return true
	if card not in valid_choices:
		action_label.text = card.card_name + " is not summonable by Blot Sacrifice right now."
		update_ui()
		return true

	_pending_blot_selected_creatures.append(card)
	action_label.text = card.card_name + " added to Blot Sacrifice."
	if _blot_has_more_summonable_creatures(spell):
		_show_blot_creature_prompt()
	else:
		_on_blot_sacrifice_confirm_pressed()
	return true

func _refresh_side_stats() -> void:
	for child in stats_container.get_children():
		child.queue_free()

func _is_card_waiting_on_priority(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	for action in game_manager.action_stack:
		if action != null and action.card == card:
			return true
	return false

func _is_card_usable_for_priority(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	return game_manager.can_card_respond_to_priority(card, game_manager.priority_player)

func _get_visible_hand_player() -> Player:
	return _get_display_player()

func _get_display_player() -> Player:
	if game_manager == null:
		return null
	var viewer := game_manager.get_feedback_viewer()
	if viewer != null:
		return viewer
	return game_manager.current_player

func _get_display_opponent() -> Player:
	if game_manager == null:
		return null
	var display_player := _get_display_player()
	if display_player != null:
		var opponent := game_manager.get_opponent(display_player)
		if opponent != null:
			return opponent
	return game_manager.other_player

func _get_hand_overlay_rect() -> Rect2:
	if center_panel == null:
		return Rect2(Vector2.ZERO, Vector2(180.0, HAND_DOCK_HEIGHT))
	var center_rect: Rect2 = center_panel.get_global_rect()
	var local_top_left: Vector2 = get_global_transform().affine_inverse() * center_rect.position
	var overlay_width: float = maxf(180.0, center_rect.size.x - HAND_OVERLAY_SIDE_PADDING * 2.0)
	var overlay_x: float = local_top_left.x + HAND_OVERLAY_SIDE_PADDING
	var overlay_y: float = local_top_left.y + center_rect.size.y - HAND_DOCK_HEIGHT - HAND_OVERLAY_BOTTOM_PADDING
	return Rect2(Vector2(overlay_x, overlay_y), Vector2(overlay_width, HAND_DOCK_HEIGHT))

func _should_hide_hand_card(card: Card) -> bool:
	var hand_player := _get_visible_hand_player()
	if card == null or game_manager == null or hand_player == null:
		return false
	if card.current_zone != hand_player.hand_zone:
		return false
	if _pending_paid_hand_card == card and _pending_paid_hand_display_zone != null:
		return true
	if _pending_blot_spell == card and _pending_blot_display_zone != null:
		return true
	if awaiting_spell_target and spell_waiting_for_target == card and spell_waiting_for_display_zone != null:
		return true
	for action in game_manager.action_stack:
		if action != null and action.card == card and action.display_zone != null:
			return true
	return false

func _get_hand_card_display_mana_cost(card: Card) -> int:
	if card == null or game_manager == null:
		return 0 if card == null else card.mana_cost
	var hand_player := _get_visible_hand_player()
	if hand_player == null:
		return card.mana_cost
	if game_manager.card_uses_summon_cost_rules(card):
		return game_manager.get_card_summon_mana_cost(hand_player, card)
	return card.mana_cost

func _get_hand_card_cost_adjustment_lines(card: Card) -> Array[String]:
	var lines: Array[String] = []
	if card == null or game_manager == null:
		return lines
	var hand_player := _get_visible_hand_player()
	if hand_player == null or not game_manager.card_uses_summon_cost_rules(card):
		return lines
	return card.get_cost_adjustment_lines(
		card.mana_cost,
		Card.COST_KIND_CREATURE_SUMMON,
		game_manager,
		{"player": hand_player}
	)

func _get_graveyard_hand_proxy_cards(hand_player: Player) -> Array[Card]:
	var cards: Array[Card] = []
	if hand_player == null or hand_player.graveyard_zone == null or game_manager == null:
		return cards
	for card in hand_player.graveyard_zone.cards:
		if card == null:
			continue
		if not card.has_method("can_show_graveyard_hand_proxy"):
			continue
		if card.can_show_graveyard_hand_proxy(game_manager):
			cards.append(card)
	return cards

func _is_graveyard_hand_proxy(card: Card) -> bool:
	return card != null \
		and card.current_zone != null \
		and card.current_zone.zone_type == Zone.ZoneType.GRAVEYARD \
		and card.has_method("can_show_graveyard_hand_proxy") \
		and game_manager != null \
		and card.can_show_graveyard_hand_proxy(game_manager)

func _get_graveyard_hand_proxy_display_mana_cost(card: Card) -> int:
	if card == null:
		return 0
	if card.has_method("get_graveyard_hand_proxy_mana_cost"):
		return int(card.get_graveyard_hand_proxy_mana_cost())
	return card.mana_cost

func draw_hand() -> void:
	if _fan_container != null and is_instance_valid(_fan_container):
		remove_child(_fan_container)
		_fan_container.queue_free()
	_fan_container = null
	_hand_visual_cards.clear()
	var hand_player := _get_visible_hand_player()
	if hand_player == null:
		return
	var blot_valid_choices: Array[Card] = []
	if _is_blot_selection_active():
		blot_valid_choices = _get_blot_valid_choices(_pending_blot_spell)

	_fan_container = Control.new()
	_fan_container.name = "HandOverlay"
	_fan_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_fan_container.clip_contents = false
	_fan_container.z_index = TRANSIENT_UI_Z_INDEX - 10
	add_child(_fan_container)

	for card in hand_player.hand_zone.cards:
		if _should_hide_hand_card(card):
			continue
		var vc := VisualCard.new()
		_fan_container.add_child(vc)
		vc.setup(
			card,
			180,
			0,
			_get_hand_card_display_mana_cost(card),
			_get_hand_card_cost_adjustment_lines(card)
		)
		vc.set_hover_viewer(game_manager.get_feedback_viewer())
		vc.set_waiting_on_priority(_is_card_waiting_on_priority(card))
		vc.set_priority_response_available(_is_card_usable_for_priority(card))
		vc.set_blot_summon_state(card in blot_valid_choices, card in _pending_blot_selected_creatures)
		vc.card_clicked.connect(_on_hand_card_pressed)
		vc.card_right_clicked.connect(_on_hand_card_right_clicked)
		vc.card_drag_released.connect(_on_card_drag_released)
		_hand_visual_cards.append(vc)

	for card in _get_graveyard_hand_proxy_cards(hand_player):
		var vc := VisualCard.new()
		_fan_container.add_child(vc)
		vc.setup(
			card,
			180,
			0,
			_get_graveyard_hand_proxy_display_mana_cost(card)
		)
		vc.set_hand_proxy_visual(true, true)
		vc.set_hover_viewer(game_manager.get_feedback_viewer())
		vc.card_clicked.connect(_on_hand_card_pressed)
		vc.card_right_clicked.connect(_on_hand_card_right_clicked)
		vc.card_drag_released.connect(_on_card_drag_released)
		_hand_visual_cards.append(vc)

	if _hand_visual_cards.is_empty():
		remove_child(_fan_container)
		_fan_container.queue_free()
		_fan_container = null
		return

	call_deferred("_layout_fan")

func _layout_fan() -> void:
	if not _fan_container or not is_instance_valid(_fan_container):
		return
	var overlay_rect: Rect2 = _get_hand_overlay_rect()
	_fan_container.position = overlay_rect.position
	_fan_container.size = overlay_rect.size
	var cards := _hand_visual_cards
	var n := cards.size()
	if n == 0:
		return
	# Total span of card pivots; clamp so they fit in the container width
	var container_w: float = max(overlay_rect.size.x, 180.0)
	var spacing: float = FAN_CARD_SPACING if n == 1 else max(36.0, min(float(FAN_CARD_SPACING), (container_w - 180.0) / float(max(n - 1, 1))))
	var total_span: float = spacing * float(n - 1)
	var start_x: float = (container_w - total_span) * 0.5

	for i in range(n):
		var vc: VisualCard = cards[i]
		# get_combined_minimum_size() is reliable because VisualCard.setup()
		# pre-computes a natural height via _compute_natural_height().
		var sz := vc.get_combined_minimum_size()
		# t in [-1, 1]: left edge = -1, right edge = +1
		var t := 0.0 if n == 1 else (float(i) / float(n - 1)) * 2.0 - 1.0
		var rot := t * FAN_ROT_MAX
		# Arc: centre of fan is highest (y = 0), edges dip down
		var arc_y := FAN_ARC_HEIGHT * t * t
		var cx: float = start_x + float(i) * spacing
		vc.size = sz
		vc.pivot_offset = sz / 2.0
		vc.position = Vector2(cx - sz.x * 0.5, arc_y)
		vc.rotation_degrees = rot
		vc.set_base_z_index(i)

func _make_deck_panel(zone: Zone) -> Control:
	const CARD_BACK := "res://images/cardbackAI.png"
	const W := 165
	const H := 110
	var tex: Texture2D = load(CARD_BACK)

	# Outer container Ã¢â‚¬â€ standard zone size, shadows go inward
	var outer := Control.new()
	outer.custom_minimum_size = Vector2(W, H)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Stack shadows: top card is inset, shadows fill more of the zone,
	# peeking out at the bottom-right to simulate depth
	for i in range(2, 0, -1):
		var shadow := Control.new()
		shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shadow.offset_left   = i * 3
		shadow.offset_top    = i * 3
		shadow.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		outer.add_child(shadow)
		if tex:
			var back := TextureRect.new()
			back.texture = tex
			back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			back.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			back.modulate = Color(0.5, 0.45, 0.3, 1.0)
			back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shadow.add_child(back)

	# Top card: inset from the bottom-right so the shadows peek out
	var top := Control.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.offset_right  = -6
	top.offset_bottom = -6
	top.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(top)
	if tex:
		var art := TextureRect.new()
		art.texture = tex
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(art)

	# Count label pinned to bottom-centre of top card
	var count_lbl := Label.new()
	count_lbl.text = str(zone.cards.size())
	count_lbl.add_theme_font_size_override("font_size", 22)
	count_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	count_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	count_lbl.add_theme_constant_override("shadow_offset_x", 1)
	count_lbl.add_theme_constant_override("shadow_offset_y", 1)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	count_lbl.offset_top = -30
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(count_lbl)

	outer.tooltip_text = "Deck: " + str(zone.cards.size()) + " cards"
	return outer

func _make_zone_info_icon(label_text: String, short_label: String, zone: Zone, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ZONE_INFO_ICON_SIZE, ZONE_INFO_ICON_SIZE)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	style.bg_color = color.darkened(0.4)
	style.border_color = color
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = label_text + ": " + str(zone.cards.size()) + " cards"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	var name_lbl := Label.new()
	name_lbl.text = short_label
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	var count_lbl := Label.new()
	count_lbl.text = str(zone.cards.size())
	count_lbl.add_theme_font_size_override("font_size", 18)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(count_lbl)

	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_show_zone_contents(label_text, zone)
	)

	return panel

func _get_board_row_width() -> float:
	return BoardZoneUI.get_zone_extent() * BOARD_MAIN_COLUMN_COUNT + ZONE_INFO_ICON_SIZE + BOARD_ZONE_COLUMN_GAP * BOARD_MAIN_COLUMN_COUNT

func _get_separator_line_width() -> float:
	return BoardZoneUI.get_zone_extent() * BOARD_MAIN_COLUMN_COUNT + BOARD_ZONE_COLUMN_GAP * (BOARD_MAIN_COLUMN_COUNT - 1.0)

func _make_stats_panel(player: Player, show_mana: bool = true) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 128)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	style.border_color = Color(0.4, 0.4, 0.4)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var name_lbl := Label.new()
	name_lbl.text = player.player_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_lbl)
	var hand_lbl := Label.new()
	hand_lbl.text = "Hand: " + str(player.hand_zone.get_card_count())
	hand_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hand_lbl)
	if show_mana:
		var mana_lbl := Label.new()
		mana_lbl.text = "Mana: " + str(player.mana)
		mana_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(mana_lbl)
	var fol_lbl := Label.new()
	fol_lbl.text = "Followers:\n" + str(player.followers)
	fol_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(fol_lbl)
	var deck_lbl := Label.new()
	deck_lbl.text = "Deck: " + str(player.deck_zone.get_card_count())
	deck_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(deck_lbl)
	return panel

func _make_god_cluster(zone: Zone, player: Player, is_enemy: bool) -> Control:
	var zone_size := BoardZoneUI.get_zone_size()
	var cluster := Control.new()
	cluster.custom_minimum_size = zone_size
	cluster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cluster.clip_contents = false

	var god_wrapper := Control.new()
	god_wrapper.custom_minimum_size = zone_size
	god_wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	god_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cluster.add_child(god_wrapper)

	var god_zone_ui := BoardZoneUI.new()
	god_zone_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	god_wrapper.add_child(god_zone_ui)
	god_zone_ui.setup(zone, game_manager, player, -1, _on_card_dropped_to_zone, is_enemy, "God")

	var stats_panel := _make_stats_panel(player, true)
	stats_panel.custom_minimum_size = Vector2(102, BoardZoneUI.get_zone_extent())
	stats_panel.position = Vector2(-106, 0)
	cluster.add_child(stats_panel)

	if is_enemy:
		_enemy_god_zone_ui = god_zone_ui
		_enemy_god_zone_ui.card_clicked.connect(_on_enemy_card_pressed)
	else:
		_player_god_zone_ui = god_zone_ui
		_player_god_zone_ui.card_clicked.connect(_on_god_card_pressed)

	return cluster

func _add_power_icons(wrapper: Control, player: Player, is_enemy: bool) -> void:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 2)
	# Anchor strip to top of the wrapper
	strip.anchor_left   = 0.0
	strip.anchor_right  = 1.0
	strip.anchor_top    = 0.0
	strip.anchor_bottom = 0.0
	strip.offset_top    = 2
	strip.offset_bottom = 24
	strip.offset_left   = 2
	strip.offset_right  = -2
	strip.z_index = 5
	wrapper.add_child(strip)

	for i in range(3):
		var zone := player.power_zones[i]
		var card := zone.cards[0] if zone.cards.size() > 0 else null
		strip.add_child(_make_power_icon(card, is_enemy, player))

func _add_power_mute_affordance(parent: Control, turns_remaining: int, is_enemy: bool) -> void:
	if turns_remaining <= 0:
		return
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	badge.offset_left = 2
	badge.offset_right = -2
	badge.offset_top = -18
	badge.offset_bottom = -2
	badge.z_index = 5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.54, 0.14, 0.26, 0.92) if is_enemy else Color(0.46, 0.12, 0.22, 0.92)
	style.border_color = Color(1.0, 0.7, 0.82, 0.98)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "Muted %d" % turns_remaining
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.96))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	parent.add_child(badge)

func _show_power_hover_popup(source: Control, text: String, bbcode_text: String = "") -> void:
	if text.strip_edges() == "":
		return
	_hide_power_hover_popup()

	var popup := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.08, 0.14, 0.97)
	pstyle.border_color = Color(0.95, 0.72, 0.82, 0.95)
	pstyle.corner_radius_top_left = 6
	pstyle.corner_radius_top_right = 6
	pstyle.corner_radius_bottom_left = 6
	pstyle.corner_radius_bottom_right = 6
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		pstyle.set_border_width(side, 2)
	popup.add_theme_stylebox_override("panel", pstyle)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = HOVER_PREVIEW_Z_INDEX

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(220, 0)
	label.add_theme_font_size_override("normal_font_size", 12)
	label.add_theme_font_size_override("bold_font_size", 12)
	label.add_theme_color_override("default_color", Color(1.0, 0.95, 0.98))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = bbcode_text if bbcode_text.strip_edges() != "" else text
	popup.add_child(label)

	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	popup.top_level = true
	tree.current_scene.add_child(popup)
	_promote_transient_ui(popup, HOVER_PREVIEW_Z_INDEX)
	_power_hover_popup = popup
	call_deferred("_position_power_hover_popup", popup, source)

func _position_power_hover_popup(popup: Control, source: Control) -> void:
	if popup == null or not is_instance_valid(popup) or source == null or not is_instance_valid(source):
		return
	var pos := source.get_global_rect().position
	pos.y -= popup.size.y + 6
	var vp_size := get_viewport_rect().size
	pos.x = clamp(pos.x, 4.0, vp_size.x - popup.size.x - 4.0)
	pos.y = clamp(pos.y, 4.0, vp_size.y - popup.size.y - 4.0)
	popup.global_position = pos

func _hide_power_hover_popup() -> void:
	if _power_hover_popup and is_instance_valid(_power_hover_popup):
		_power_hover_popup.queue_free()
	_power_hover_popup = null

func _get_power_hover_text(card: Card) -> String:
	if card == null:
		return ""
	var power := card as PowerCard
	var hover_lines: Array[String] = [card.card_name]
	var ability_text := power.get_display_ability_text(game_manager) if power != null else card.ability_text
	if ability_text != "":
		hover_lines.append(ability_text)
	if power != null:
		var cost_lines := _get_power_cost_hover_lines(power)
		if not cost_lines.is_empty():
			if hover_lines.size() > 1:
				hover_lines.append("")
			hover_lines.append_array(cost_lines)
		var activation_cost_lines := _get_power_activation_cost_hover_lines(power)
		if not activation_cost_lines.is_empty():
			if hover_lines.size() > 1:
				hover_lines.append("")
			hover_lines.append_array(activation_cost_lines)
	var hover_viewer := game_manager.get_feedback_viewer() if game_manager != null else null
	var hover_details := card.get_hover_detail_lines(hover_viewer)
	if not hover_details.is_empty():
		if hover_lines.size() > 1:
			hover_lines.append("")
		hover_lines.append_array(hover_details)
	if power != null and power.is_muted and power.mute_turns_remaining > 0:
		if hover_lines.size() > 1:
			hover_lines.append("")
		hover_lines.append("Muted for %d more turn(s)." % power.mute_turns_remaining)
	return "\n".join(hover_lines)

func _get_power_hover_bbcode(card: Card) -> String:
	if card == null:
		return ""
	var power := card as PowerCard
	var sections: Array[String] = ["[b]%s[/b]" % card.card_name]
	var ability_text := power.get_display_ability_bbcode_text(game_manager) if power != null else card.ability_text
	if ability_text != "":
		sections.append(BaseCard.apply_keyword_hints(ability_text))
	if power != null:
		var cost_lines := _get_power_cost_hover_bbcode_lines(power)
		if not cost_lines.is_empty():
			sections.append("\n".join(cost_lines))
		var activation_cost_lines := _get_power_activation_cost_hover_bbcode_lines(power)
		if not activation_cost_lines.is_empty():
			sections.append("\n".join(activation_cost_lines))
	var hover_viewer := game_manager.get_feedback_viewer() if game_manager != null else null
	var hover_details := card.get_hover_detail_lines(hover_viewer)
	if not hover_details.is_empty():
		sections.append("\n".join(hover_details))
	if power != null and power.is_muted and power.mute_turns_remaining > 0:
		sections.append("Muted for %d more turn(s)." % power.mute_turns_remaining)
	return "\n\n".join(sections)

func _get_card_cost_hover_lines(
	card: Card,
	base_cost: int,
	cost_kind: String,
	metadata: Dictionary = {},
	extra_lines: Array[String] = [],
	cost_label: String = "Cost"
) -> Array[String]:
	var lines: Array[String] = []
	if card == null or game_manager == null:
		return lines
	var current_cost := card.get_adjusted_mana_cost(base_cost, cost_kind, game_manager, metadata)
	lines.append("%s: %d" % [cost_label, current_cost])
	lines.append_array(card.get_cost_adjustment_lines(base_cost, cost_kind, game_manager, metadata))
	for extra_line in extra_lines:
		if extra_line.strip_edges() != "":
			lines.append(extra_line)
	return lines

func _get_card_cost_hover_bbcode_lines(
	card: Card,
	base_cost: int,
	cost_kind: String,
	metadata: Dictionary = {},
	extra_lines: Array[String] = [],
	cost_label: String = "Cost"
) -> Array[String]:
	var lines: Array[String] = []
	if card == null or game_manager == null:
		return lines
	var current_cost := card.get_adjusted_mana_cost(base_cost, cost_kind, game_manager, metadata)
	var cost_line := "%s: %d" % [cost_label, current_cost]
	if current_cost < base_cost:
		cost_line = "[color=#66ff66]%s[/color]" % cost_line
	elif current_cost > base_cost:
		cost_line = "[color=#ff6666]%s[/color]" % cost_line
	lines.append(cost_line)
	for breakdown_line in card.get_cost_adjustment_lines(base_cost, cost_kind, game_manager, metadata):
		lines.append(breakdown_line)
	for extra_line in extra_lines:
		if extra_line.strip_edges() != "":
			lines.append(extra_line)
	return lines

func _get_power_cost_hover_lines(power: PowerCard) -> Array[String]:
	if power == null or game_manager == null or not power.is_face_down:
		return []
	var extra_lines: Array[String] = []
	if power.discard_cost > 0:
		extra_lines.append("Discard: %d" % power.discard_cost)
	return _get_card_cost_hover_lines(
		power,
		power.mana_cost,
		Card.COST_KIND_POWER_UNLOCK,
		{},
		extra_lines,
		"Unlock Cost"
	)

func _get_power_cost_hover_bbcode_lines(power: PowerCard) -> Array[String]:
	if power == null or game_manager == null or not power.is_face_down:
		return []
	var extra_lines: Array[String] = []
	if power.discard_cost > 0:
		extra_lines.append("Discard: %d" % power.discard_cost)
	return _get_card_cost_hover_bbcode_lines(
		power,
		power.mana_cost,
		Card.COST_KIND_POWER_UNLOCK,
		{},
		extra_lines,
		"Unlock Cost"
	)

func _get_power_activation_cost_hover_lines(power: PowerCard) -> Array[String]:
	if power == null or game_manager == null or power.is_face_down:
		return []
	var hover_data: Dictionary = power.get_activation_cost_hover_data(game_manager)
	if hover_data.is_empty():
		return []
	var base_cost := int(hover_data.get("base_cost", 0))
	var cost_kind := str(hover_data.get("cost_kind", Card.COST_KIND_POWER_ACTIVATION))
	var metadata: Dictionary = hover_data.get("metadata", {})
	var extra_lines: Array[String] = []
	for line in hover_data.get("extra_lines", []):
		extra_lines.append(str(line))
	var cost_label := str(hover_data.get("label", "Activation Cost"))
	return _get_card_cost_hover_lines(power, base_cost, cost_kind, metadata, extra_lines, cost_label)

func _get_power_activation_cost_hover_bbcode_lines(power: PowerCard) -> Array[String]:
	if power == null or game_manager == null or power.is_face_down:
		return []
	var hover_data: Dictionary = power.get_activation_cost_hover_data(game_manager)
	if hover_data.is_empty():
		return []
	var base_cost := int(hover_data.get("base_cost", 0))
	var cost_kind := str(hover_data.get("cost_kind", Card.COST_KIND_POWER_ACTIVATION))
	var metadata: Dictionary = hover_data.get("metadata", {})
	var extra_lines: Array[String] = []
	for line in hover_data.get("extra_lines", []):
		extra_lines.append(str(line))
	var cost_label := str(hover_data.get("label", "Activation Cost"))
	return _get_card_cost_hover_bbcode_lines(power, base_cost, cost_kind, metadata, extra_lines, cost_label)

func _get_power_unlock_cost_label(power: PowerCard) -> String:
	if power == null:
		return ""
	var parts: Array[String] = []
	var unlock_mana_cost := power.get_unlock_mana_cost(game_manager) if game_manager != null else power.mana_cost
	if unlock_mana_cost > 0:
		parts.append(str(unlock_mana_cost) + " Mana")
	if power.discard_cost > 0:
		parts.append(str(power.discard_cost) + " Discard")
	if parts.is_empty():
		return "Free"
	return " / ".join(parts)

func _complete_power_unlock(power: PowerCard) -> void:
	if power == null:
		return
	if _is_networked_client:
		game_input.submit_action({type = "unlock_power", power_uid = power.uid})
		return
	power.unlock(game_manager)
	action_label.text = power.card_name + " unlocked!"
	update_ui()

func _make_power_icon(card: Card, is_enemy: bool, _player: Player) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left    = 2
	style.corner_radius_top_right   = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)

	if card == null:
		style.bg_color     = Color(0.05, 0.05, 0.08, 0.6)
		style.border_color = Color(0.2, 0.2, 0.2, 0.4)
		panel.add_theme_stylebox_override("panel", style)
		panel.modulate.a = 0.35
		var empty_lbl := Label.new()
		empty_lbl.text = "-"
		empty_lbl.add_theme_font_size_override("font_size", 9)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(empty_lbl)
		return panel

	var power := card as PowerCard
	var can_show_hover := not (is_enemy and card.is_face_down and not ((power != null and power.is_publicly_revealed) or card.is_temporarily_revealed()))
	if can_show_hover:
		panel.tooltip_text = _get_power_hover_text(card)
		panel.mouse_entered.connect(func() -> void:
			panel.tooltip_text = _get_power_hover_text(card)
			_show_power_hover_popup(panel, panel.tooltip_text, _get_power_hover_bbcode(card))
		)
		panel.mouse_exited.connect(func() -> void:
			_hide_power_hover_popup()
		)
		panel.mouse_default_cursor_shape = Control.CURSOR_HELP

	var label_text := ""
	var font_size := 8
	if is_enemy:
		var enemy_power := power
		var revealed_face_down := card.is_face_down and ((enemy_power != null and enemy_power.is_publicly_revealed) or card.is_temporarily_revealed())
		if revealed_face_down:
			style.bg_color = Color(0.18, 0.10, 0.14, 0.9)
			style.border_color = Color(0.9, 0.45, 0.6, 0.95)
			panel.add_theme_stylebox_override("panel", style)
			if card.art_path != "":
				var tex := load(card.art_path) as Texture2D
				if tex:
					var art := TextureRect.new()
					art.texture = tex
					art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
					art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
					art.mouse_filter = Control.MOUSE_FILTER_IGNORE
					panel.add_child(art)
			var haze := ColorRect.new()
			haze.color = Color(0.85, 0.22, 0.45, 0.45)
			haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(haze)
			label_text = _get_power_unlock_cost_label(enemy_power)
		else:
			var enemy_power_unlocked := not card.is_face_down
			style.bg_color = Color(0.12, 0.08, 0.18, 0.85) if enemy_power_unlocked else Color(0.05, 0.05, 0.10, 0.85)
			style.border_color = Color(0.55, 0.3, 0.8) if enemy_power_unlocked else Color(0.25, 0.2, 0.35)
			panel.add_theme_stylebox_override("panel", style)
			label_text = "?" if not enemy_power_unlocked else "Active"
			font_size = 9
		var enemy_lbl := Label.new()
		enemy_lbl.text = label_text
		enemy_lbl.add_theme_font_size_override("font_size", font_size)
		enemy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		enemy_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		enemy_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		enemy_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		enemy_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(enemy_lbl)
		if enemy_power != null and enemy_power.is_muted and enemy_power.mute_turns_remaining > 0 and label_text != "?":
			_add_power_mute_affordance(panel, enemy_power.mute_turns_remaining, true)
		return panel

	var is_unlocked := not card.is_face_down
	var activatable := power != null and power.can_activate(game_manager)
	var can_unlock_now := power != null and power.can_unlock(game_manager)

	if is_unlocked and activatable:
		style.bg_color = Color(0.18, 0.14, 0.06, 0.92)
		style.border_color = Color(0.95, 0.78, 0.2)
	elif is_unlocked:
		style.bg_color = Color(0.10, 0.10, 0.14, 0.85)
		style.border_color = Color(0.45, 0.38, 0.2)
	elif can_unlock_now:
		style.bg_color = Color(0.06, 0.10, 0.16, 0.85)
		style.border_color = Color(0.3, 0.55, 0.85)
	else:
		style.bg_color = Color(0.06, 0.06, 0.10, 0.75)
		style.border_color = Color(0.2, 0.22, 0.3)
		panel.modulate.a = 0.65
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	if not is_unlocked:
		lbl.text = _get_power_unlock_cost_label(power)
	else:
		lbl.text = card.card_name.left(7)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)
	if power != null and power.is_muted and power.mute_turns_remaining > 0:
		_add_power_mute_affordance(panel, power.mute_turns_remaining, false)

	var can_target_with_god: bool = awaiting_god_ability_target \
		and god_ability_source != null \
		and god_ability_source.has_method("is_valid_activation_target") \
		and god_ability_source.is_valid_activation_target(card)

	if can_unlock_now or activatable or can_target_with_god:
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var captured := card as PowerCard
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_power_pressed(captured)
		)
	return panel
func _on_power_pressed(power: PowerCard) -> void:
	if _has_pending_target_selection():
		if _try_handle_pending_click_selection(power):
			return
		_handle_invalid_pending_target_click()
		return
	if _try_queue_god_targeted_ability(power):
		return
	if _is_turn_choice_pending() and not _can_activate_before_turn_choice(power):
		_reject_pre_turn_action()
		return
	if selected_card is Absence:
		_cast_targeted_spell(selected_card, power)
		return
	if power is DivineCaprice and not power.can_unlock(game_manager) and not power.can_activate(game_manager):
		action_label.text = _get_activation_unavailable_text(power, power.card_name + " cannot activate right now.")
		return
	if power.can_unlock(game_manager):
		if power.requires_chosen_hand_discards() and not power.has_pending_chosen_discards_for_cost():
			_prompt_chosen_hand_discards(
				power,
				func() -> void:
					_complete_power_unlock(power),
				func() -> void:
					action_label.text = "Cancelled " + power.card_name + "."
					update_ui()
			)
			return
		_complete_power_unlock(power)
	elif power.can_activate(game_manager):
		if power is Breidablik:
			_show_breidablik_prompt(power as Breidablik)
		elif power is DivineCaprice:
			_show_divine_caprice_prompt(power as DivineCaprice)
		elif power is AllfathersSacrifice:
			var allfather := power as AllfathersSacrifice
			_show_card_selection_overlay(
				"Choose a Spell to Move to the Top",
				allfather.get_spell_cards_in_deck(),
				func(chosen_card: Card) -> void:
					_queue_power_activation_action(
						allfather,
						chosen_card,
						_get_attack_card_label(allfather, allfather.card_name) + " is targeting " + _get_target_label(chosen_card, game_manager.get_feedback_viewer(), chosen_card.card_name) + ".",
						func() -> void:
							allfather.activate(game_manager, chosen_card)
					)
			)
		elif power is AnankesBinding:
			var ananke := power as AnankesBinding
			_show_card_selection_overlay(
				"Choose a Card to Bind",
				ananke.get_cards_in_deck(),
				func(chosen_card: Card) -> void:
					_queue_power_activation_action(
						ananke,
						chosen_card,
						_get_attack_card_label(ananke, ananke.card_name) + " is targeting " + _get_target_label(chosen_card, game_manager.get_feedback_viewer(), chosen_card.card_name) + ".",
						func() -> void:
							ananke.activate(game_manager, chosen_card)
					)
			)
		elif power is BerserkerMead:
			var mead := power as BerserkerMead
			_show_card_selection_overlay(
				"Choose a Norse Creature for Berserker Mead",
				mead.get_valid_targets(game_manager),
				func(chosen_card: Card) -> void:
					_queue_power_activation_action(
						mead,
						chosen_card,
						_get_attack_card_label(mead, mead.card_name) + " is targeting " + _get_target_label(chosen_card, game_manager.get_feedback_viewer(), chosen_card.card_name) + ".",
						func() -> void:
							mead.activate(game_manager, chosen_card)
					)
			)
		elif power.has_method("get_valid_targets"):
			var targets: Array = power.get_valid_targets(game_manager)
			if targets.is_empty():
				action_label.text = power.card_name + " has no valid targets right now."
				update_ui()
				return
			_show_card_selection_overlay(
				"Choose a target for " + power.card_name,
				targets,
				func(chosen_card: Card) -> void:
					_queue_power_activation_action(
						power,
						chosen_card,
						_get_attack_card_label(power, power.card_name) + " is targeting " + _get_target_label(chosen_card, game_manager.get_feedback_viewer(), chosen_card.card_name) + ".",
						func() -> void:
							power.activate(game_manager, chosen_card)
					)
			)
		else:
			_queue_power_activation_action(
				power,
				null,
				power.card_name + " activated!",
				func() -> void:
					power.activate(game_manager)
			)
	else:
		if power.is_face_down:
			action_label.text = power.get_unlock_failure_reason(game_manager)
			return
		if not power.is_muted and not power.is_activation_locked(game_manager):
			action_label.text = _get_activation_unavailable_text(power, power.card_name + " cannot activate right now.")
			return
		if power.is_muted:
			action_label.text = power.card_name + " is muted for " + str(power.mute_turns_remaining) + " more turn(s)."
		elif power.is_activation_locked(game_manager):
			action_label.text = power.card_name + " cannot be activated this turn."
		elif power.is_face_down:
			action_label.text = power.card_name + " Ã¢â‚¬â€ needs " + str(power.mana_cost) + " mana to unlock."
		else:
			action_label.text = power.card_name + " Ã¢â‚¬â€ cannot activate right now."

func _show_breidablik_prompt(power: Breidablik) -> void:
	_hide_breidablik_prompt()
	if power == null:
		update_ui()
		return
	var can_store: bool = not power.get_valid_field_priests(game_manager).is_empty()
	var can_return: bool = power.can_return_priest(game_manager)
	if not can_store and not can_return:
		action_label.text = power.card_name + " has no valid Priest action right now."
		update_ui()
		return

	var panel := PanelContainer.new()
	panel.name = "BreidablikPromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.18, 0.97)
	style.border_color = Color(0.45, 0.70, 1.0, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 220

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = power.card_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Choose a Priest action."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	if can_store:
		var store_btn := Button.new()
		store_btn.text = "Shelter Priest"
		store_btn.pressed.connect(func() -> void:
			_hide_breidablik_prompt()
			_show_card_selection_overlay(
				"Choose a Priest for Breidablik",
				power.get_valid_field_priests(game_manager),
				func(selected_priest: Card) -> void:
					if _is_networked_client:
						game_input.submit_action({type = "activate_power", power_uid = power.uid, target_uid = selected_priest.uid})
					else:
						_queue_magical_action(
							CardAction.Type.ABILITY,
							power,
							selected_priest,
							power.card_name + " shelters " + selected_priest.card_name + ".",
							func() -> void:
								power.activate(game_manager, selected_priest)
						)
			)
		)
		vbox.add_child(store_btn)

	if can_return:
		var return_btn := Button.new()
		return_btn.text = "Return Priest (1 mana)"
		return_btn.pressed.connect(func() -> void:
			_hide_breidablik_prompt()
			_show_card_selection_overlay(
				"Choose a Priest to Return",
				power.get_stored_priests(),
				func(selected_priest: Card) -> void:
					if _is_networked_client:
						game_input.submit_action({type = "activate_power", power_uid = power.uid, target_uid = selected_priest.uid, mode = "return_priest"})
					else:
						_queue_magical_action(
							CardAction.Type.ABILITY,
							power,
							selected_priest,
							power.card_name + " returns " + selected_priest.card_name + ".",
							func() -> void:
								power.return_priest(game_manager, selected_priest)
						)
			)
		)
		vbox.add_child(return_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_hide_breidablik_prompt)
	vbox.add_child(cancel_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -150
	panel.offset_right = 150
	panel.offset_top = -90
	panel.offset_bottom = 90
	_breidablik_panel = panel

func _get_divine_caprice_zone_title(zone: Zone) -> String:
	if zone == null:
		return "Unknown Slot"
	if game_manager == null or game_manager.current_player == null:
		return "Slot"
	if zone in game_manager.current_player.frontline_zones:
		return "Front " + str(zone.zone_index + 1)
	if zone in game_manager.current_player.reserve_zones:
		return "Reserve " + str(zone.zone_index + 1)
	return "Slot"

func _get_divine_caprice_slot_cards(zone: Zone) -> Array[Card]:
	var cards: Array[Card] = []
	if zone == null:
		return cards
	var raw_cards = _pending_divine_caprice_virtual_slots.get(zone, zone.cards)
	for card in raw_cards:
		if card is Card:
			cards.append(card as Card)
	return cards

func _get_divine_caprice_slot_label(zone: Zone) -> String:
	var title := _get_divine_caprice_zone_title(zone)
	var cards := _get_divine_caprice_slot_cards(zone)
	if cards.is_empty():
		return title + "\nEmpty"
	var main_card := cards[0]
	var is_hidden_card := main_card.is_face_down or main_card.is_prepared or main_card.is_stealth
	if main_card is PowerCard and (main_card as PowerCard).is_face_down and not (main_card as PowerCard).is_publicly_revealed and not main_card.is_temporarily_revealed():
		is_hidden_card = true
	var name_text := "Hidden card" if is_hidden_card else main_card.card_name
	if cards.size() > 1:
		name_text += " +" + str(cards.size() - 1)
	return title + "\n" + name_text

func _divine_caprice_can_target_zone(source_zone: Zone, target_zone: Zone) -> bool:
	var power := _pending_divine_caprice_power
	if power == null or source_zone == null or target_zone == null:
		return false
	if source_zone == target_zone:
		return false
	if _get_divine_caprice_slot_cards(source_zone).is_empty():
		return false
	return power.get_slot_group(source_zone) == power.get_slot_group(target_zone)

func _divine_caprice_source_has_target(source_zone: Zone) -> bool:
	var power := _pending_divine_caprice_power
	if power == null or source_zone == null:
		return false
	if _get_divine_caprice_slot_cards(source_zone).is_empty():
		return false
	for target_zone in power.get_reposition_zones():
		if _divine_caprice_can_target_zone(source_zone, target_zone):
			return true
	return false

func _apply_divine_caprice_virtual_swap(source_zone: Zone, target_zone: Zone) -> void:
	var source_cards := _get_divine_caprice_slot_cards(source_zone)
	var target_cards := _get_divine_caprice_slot_cards(target_zone)
	_pending_divine_caprice_virtual_slots[source_zone] = target_cards
	_pending_divine_caprice_virtual_slots[target_zone] = source_cards

func _show_divine_caprice_prompt(power: DivineCaprice) -> void:
	if power == null:
		update_ui()
		return
	if _pending_divine_caprice_power != power:
		_pending_divine_caprice_power = power
		_pending_divine_caprice_selected_zone = null
		_pending_divine_caprice_plan.clear()
		_pending_divine_caprice_virtual_slots.clear()
		for zone in power.get_reposition_zones():
			_pending_divine_caprice_virtual_slots[zone] = zone.cards.duplicate()
	_hide_divine_caprice_prompt(false)

	var panel := PanelContainer.new()
	panel.name = "DivineCapricePromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.16, 0.97)
	style.border_color = Color(0.92, 0.78, 0.38, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 220
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -190
	panel.offset_bottom = 190

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = power.card_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _pending_divine_caprice_selected_zone == null:
		info.text = "Choose an occupied friendly board slot, then choose another legal friendly board slot. You can plan multiple swaps before confirming."
	else:
		info.text = "Selected " + _get_divine_caprice_zone_title(_pending_divine_caprice_selected_zone) + ". Choose another legal friendly board slot."
	vbox.add_child(info)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	for zone in power.get_reposition_zones():
		var button := Button.new()
		button.custom_minimum_size = Vector2(116, 58)
		button.text = _get_divine_caprice_slot_label(zone)
		var is_selected := zone == _pending_divine_caprice_selected_zone
		if is_selected:
			button.text = "[Selected]\n" + button.text
		if _pending_divine_caprice_selected_zone == null:
			button.disabled = not _divine_caprice_source_has_target(zone)
		else:
			button.disabled = not is_selected and not _divine_caprice_can_target_zone(_pending_divine_caprice_selected_zone, zone)
		button.pressed.connect(_on_divine_caprice_zone_pressed.bind(zone))
		grid.add_child(button)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)

	var confirm_btn := Button.new()
	confirm_btn.text = "Queue Rearrangement"
	confirm_btn.disabled = _pending_divine_caprice_plan.is_empty()
	confirm_btn.pressed.connect(_on_divine_caprice_confirm_pressed)
	buttons.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_divine_caprice_cancel_pressed)
	buttons.add_child(cancel_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	_divine_caprice_panel = panel

func _hide_divine_caprice_prompt(clear_state: bool = true) -> void:
	if _divine_caprice_panel != null and is_instance_valid(_divine_caprice_panel):
		_divine_caprice_panel.queue_free()
	_divine_caprice_panel = null
	if clear_state:
		_pending_divine_caprice_power = null
		_pending_divine_caprice_selected_zone = null
		_pending_divine_caprice_plan.clear()
		_pending_divine_caprice_virtual_slots.clear()

func _on_divine_caprice_zone_pressed(zone: Zone) -> void:
	var power := _pending_divine_caprice_power
	if power == null or zone == null:
		return
	if _pending_divine_caprice_selected_zone == null:
		if not _divine_caprice_source_has_target(zone):
			action_label.text = _get_divine_caprice_zone_title(zone) + " cannot be moved."
			return
		_pending_divine_caprice_selected_zone = zone
		action_label.text = power.card_name + ": selected " + _get_divine_caprice_zone_title(zone) + "."
		_show_divine_caprice_prompt(power)
		return
	if zone == _pending_divine_caprice_selected_zone:
		_pending_divine_caprice_selected_zone = null
		action_label.text = power.card_name + ": selection cleared."
		_show_divine_caprice_prompt(power)
		return
	if not _divine_caprice_can_target_zone(_pending_divine_caprice_selected_zone, zone):
		action_label.text = "Choose another legal friendly board slot for Divine Caprice."
		return
	_pending_divine_caprice_plan.append({
		"source_zone": _pending_divine_caprice_selected_zone,
		"target_zone": zone
	})
	_apply_divine_caprice_virtual_swap(_pending_divine_caprice_selected_zone, zone)
	action_label.text = power.card_name + ": planned " + _get_divine_caprice_zone_title(_pending_divine_caprice_selected_zone) + " -> " + _get_divine_caprice_zone_title(zone) + "."
	_pending_divine_caprice_selected_zone = null
	_show_divine_caprice_prompt(power)

func _on_divine_caprice_confirm_pressed() -> void:
	var power := _pending_divine_caprice_power
	var plan := _pending_divine_caprice_plan.duplicate()
	_hide_divine_caprice_prompt()
	if power == null or plan.is_empty():
		update_ui()
		return
	if _is_networked_client:
		var serialized_plan: Array = []
		for step in plan:
			serialized_plan.append({
				source_zone = MatchManager.zone_to_dict(step.get("source_zone") as Zone, game_manager),
				target_zone = MatchManager.zone_to_dict(step.get("target_zone") as Zone, game_manager)
			})
		game_input.submit_action({type = "activate_divine_caprice", power_uid = power.uid, plan = serialized_plan})
		return
	_queue_magical_action(
		CardAction.Type.ABILITY,
		power,
		plan,
		power.card_name + " goes on the stack.",
		func() -> void:
			power.activate(game_manager, plan)
	)

func _on_divine_caprice_cancel_pressed() -> void:
	var power := _pending_divine_caprice_power
	_hide_divine_caprice_prompt()
	action_label.text = "Cancelled " + (power.card_name if power != null else "Divine Caprice") + "."
	update_ui()

func _hide_breidablik_prompt() -> void:
	if _breidablik_panel != null and is_instance_valid(_breidablik_panel):
		_breidablik_panel.queue_free()
	_breidablik_panel = null

func _show_e2_abzu_prompt(structure: E2Abzu) -> void:
	_hide_e2_abzu_prompt()
	if structure == null:
		update_ui()
		return
	var void_targets := structure.get_valid_void_targets(game_manager)
	var field_targets := structure.get_valid_field_targets(game_manager)
	var can_return := not void_targets.is_empty()
	var can_void := not field_targets.is_empty()
	if not can_return and not can_void:
		action_label.text = structure.card_name + " has no valid ability targets right now."
		update_ui()
		return

	var panel := PanelContainer.new()
	panel.name = "E2AbzuPromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.11, 0.18, 0.97)
	style.border_color = Color(0.38, 0.78, 0.92, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 220

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = structure.card_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Choose which ability to use."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	var return_btn := Button.new()
	return_btn.text = "Return from Void (3 mana)"
	return_btn.disabled = not can_return
	return_btn.pressed.connect(func() -> void:
		_hide_e2_abzu_prompt()
		_show_card_selection_overlay(
			"Choose a Mer Mage in your Void",
			void_targets,
			func(chosen_card: Card) -> void:
				_queue_targeted_ability_action(
					structure,
					chosen_card,
					func() -> void:
						structure.activate(game_manager, chosen_card)
				)
		)
	)
	vbox.add_child(return_btn)

	var void_btn := Button.new()
	void_btn.text = "Void from Field (2 mana)"
	void_btn.disabled = not can_void
	void_btn.pressed.connect(func() -> void:
		_hide_e2_abzu_prompt()
		_show_card_selection_overlay(
			"Choose a friendly Mer Mage on the field",
			field_targets,
			func(chosen_card: Card) -> void:
				_queue_targeted_ability_action(
					structure,
					chosen_card,
					func() -> void:
						structure.activate(game_manager, chosen_card)
				)
		)
	)
	vbox.add_child(void_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_hide_e2_abzu_prompt)
	vbox.add_child(cancel_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -160
	panel.offset_right = 160
	panel.offset_top = -95
	panel.offset_bottom = 95
	_e2_abzu_panel = panel

func _hide_e2_abzu_prompt() -> void:
	if _e2_abzu_panel != null and is_instance_valid(_e2_abzu_panel):
		_e2_abzu_panel.queue_free()
	_e2_abzu_panel = null

func _maybe_prompt_turn_start_windows() -> void:
	_hide_skoll_prompt()
	_pending_skoll_prompts.clear()
	_refresh_turn_choice_options()
	_maybe_prompt_breidablik_on_turn_start()

func _maybe_prompt_skoll_on_turn_start() -> bool:
	_hide_skoll_prompt()
	_pending_skoll_prompts.clear()
	if game_manager == null or game_manager.current_player == null:
		return false
	for card in game_manager.current_player.hand_zone.cards:
		if card is Skoll and (card as Skoll).can_use_upkeep_summon(game_manager):
			_pending_skoll_prompts.append(card as Skoll)
	if _pending_skoll_prompts.is_empty():
		return false
	_show_next_skoll_prompt()
	return true

func _show_next_skoll_prompt() -> void:
	_hide_skoll_prompt()
	while not _pending_skoll_prompts.is_empty():
		var skoll := _pending_skoll_prompts[0]
		if skoll != null and skoll.can_use_upkeep_summon(game_manager):
			_show_skoll_prompt(skoll)
			return
		_pending_skoll_prompts.remove_at(0)
	_restore_turn_choice_after_skoll_prompt()

func _show_skoll_prompt(skoll: Skoll) -> void:
	if skoll == null:
		_restore_turn_choice_after_skoll_prompt()
		return
	var panel := PanelContainer.new()
	panel.name = "SkollPromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.06, 0.97)
	style.border_color = Color(0.78, 0.58, 0.28, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 220

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = skoll.card_name
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Sun Hunt: summon this Skoll from your hand now? This summon costs no mana and no sacrifice, replaces Draw Card or Gain 4 Mana, and makes all other summoning cost 2 extra mana this turn."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 11)
	vbox.add_child(info)

	for entry in [["Summon Aggressive", "aggressive"], ["Summon Defensive", "defensive"], ["Summon Stealth", "stealth"]]:
		var summon_btn := Button.new()
		summon_btn.text = entry[0]
		var summon_mode: String = entry[1]
		summon_btn.pressed.connect(func() -> void:
			_begin_skoll_upkeep_summon(skoll, summon_mode)
		)
		vbox.add_child(summon_btn)

	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.pressed.connect(func() -> void:
		_skip_current_skoll_prompt()
	)
	vbox.add_child(skip_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -190
	panel.offset_right = 190
	panel.offset_top = -105
	panel.offset_bottom = 105
	_skoll_prompt_panel = panel
	action_label.text = "Sun Hunt: choose how to summon Skoll."

func _begin_skoll_upkeep_summon(skoll: Skoll, mode: String) -> void:
	if skoll == null or not skoll.can_use_upkeep_summon(game_manager):
		_restore_turn_choice_after_skoll_prompt()
		return
	_hide_skoll_prompt()
	_pending_skoll_summon = skoll
	_pending_skoll_mode = mode
	action_label.text = "Skoll: choose an empty friendly zone to summon in " + mode.to_upper() + "."
	update_ui()

func _resolve_skoll_upkeep_summon(zone: Zone) -> void:
	var skoll := _pending_skoll_summon
	var mode := _pending_skoll_mode
	if skoll == null or game_manager == null:
		_restore_turn_choice_after_skoll_prompt()
		update_ui()
		return
	if zone == null or zone.zone_owner != game_manager.current_player or zone.zone_type not in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE] or not zone.cards.is_empty():
		action_label.text = "Skoll: choose an empty friendly zone."
		update_ui()
		return
	selected_card = null
	placement_mode = ""
	placement_container.visible = false
	if _is_networked_client:
		game_input.submit_action({
			type = "skoll_upkeep_summon",
			skoll_uid = skoll.uid,
			player_index = game_manager.players.find(zone.zone_owner),
			zone_type = zone.zone_type,
			zone_index = zone.zone_index,
			mode = mode
		})
		_restore_turn_choice_after_skoll_prompt()
		update_ui()
		return
	_resolve_skoll_upkeep_creature_play(skoll, zone, mode)
	update_ui()

func _skip_current_skoll_prompt() -> void:
	var skoll := _pending_skoll_prompts[0] if not _pending_skoll_prompts.is_empty() else null
	_remove_skoll_from_prompt_queue(skoll)
	_clear_skoll_upkeep_summon()
	_show_next_skoll_prompt()
	update_ui()

func _resolve_skoll_upkeep_creature_play(card: Card, zone: Zone, mode: String) -> void:
	if card == null or zone == null or game_manager == null:
		action_label.text = "Skoll could not be summoned right now."
		_restore_turn_choice_after_skoll_prompt()
		return
	_queued_skoll_turn_start_summon = card as Skoll
	_queued_skoll_turn_start_zone = zone
	_queued_skoll_turn_start_mode = mode
	game_manager.player_chooses_upkeep_only()
	_close_turn_start_windows()
	update_ui()
	hide_turn_choice()
	if not _is_networked_client:
		_queue_skoll_turn_start_priority()

func _remove_skoll_from_prompt_queue(skoll: Skoll) -> void:
	if skoll == null:
		if not _pending_skoll_prompts.is_empty():
			_pending_skoll_prompts.remove_at(0)
		return
	var remaining: Array[Skoll] = []
	for candidate in _pending_skoll_prompts:
		if candidate != skoll:
			remaining.append(candidate)
	_pending_skoll_prompts = remaining

func _clear_skoll_upkeep_summon() -> void:
	_pending_skoll_summon = null
	_pending_skoll_mode = ""
	_pending_creature_play_resolver = Callable()

func _queue_skoll_turn_start_priority() -> void:
	var skoll := _queued_skoll_turn_start_summon
	if skoll == null or game_manager == null:
		_clear_queued_skoll_turn_start_summon()
		action_label.text = "Sun Hunt could not be queued."
		update_ui()
		return
	var resolve_sun_hunt := func() -> void:
		_resolve_queued_skoll_turn_start_summon()
	_queue_priority_event(
		"start_turn",
		skoll,
		0,
		resolve_sun_hunt,
		game_manager.current_player
	)
	action_label.text = "Sun Hunt chosen. Resolve start-of-turn priority to summon Skoll."

func _queue_standard_turn_start_priority(feedback_text: String = "") -> void:
	if game_manager == null:
		return
	var resolve_turn_start := func() -> void:
		if feedback_text.strip_edges() != "":
			action_label.text = feedback_text
			update_ui()
	_queue_priority_event(
		"start_turn",
		null,
		0,
		resolve_turn_start,
		game_manager.current_player
	)

func _resolve_queued_skoll_turn_start_summon() -> void:
	var skoll := _queued_skoll_turn_start_summon
	var zone := _queued_skoll_turn_start_zone
	var mode := _queued_skoll_turn_start_mode
	_clear_queued_skoll_turn_start_summon()
	if skoll == null or zone == null or game_manager == null:
		action_label.text = "Sun Hunt fizzles."
		update_ui()
		return
	if not skoll.can_use_upkeep_summon(game_manager):
		action_label.text = "Sun Hunt fizzles: Skoll is no longer available."
		update_ui()
		return
	if zone.zone_owner != game_manager.current_player or zone.zone_type not in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE] or not zone.cards.is_empty():
		action_label.text = "Sun Hunt fizzles: the chosen zone is no longer open."
		update_ui()
		return
	var summon_mode: Card.CreatureMode = Card.CreatureMode.DEFENSIVE
	if mode == "aggressive":
		summon_mode = Card.CreatureMode.AGGRESSIVE
	var stealth := mode == "stealth"
	var success := game_manager.summon_creature_by_effect(
		game_manager.current_player,
		skoll,
		zone,
		summon_mode,
		stealth,
		stealth,
		skoll,
		false,
		false
	)
	if not success:
		action_label.text = "Sun Hunt fizzles: Skoll could not be summoned."
		update_ui()
		return
	skoll.apply_upkeep_summon_tax(game_manager)
	action_label.text = "Sun Hunt resolved. Skoll was summoned, and all other summoning costs 2 additional mana this turn."
	update_ui()

func _clear_queued_skoll_turn_start_summon() -> void:
	_queued_skoll_turn_start_summon = null
	_queued_skoll_turn_start_zone = null
	_queued_skoll_turn_start_mode = ""

func _hide_skoll_prompt() -> void:
	if _skoll_prompt_panel != null and is_instance_valid(_skoll_prompt_panel):
		_skoll_prompt_panel.queue_free()
	_skoll_prompt_panel = null

func _on_sun_hunt_button_pressed() -> void:
	if _game_finished:
		return
	if not _maybe_prompt_skoll_on_turn_start():
		_refresh_turn_choice_options()
		action_label.text = "Sun Hunt is not available right now."
		update_ui()
		return
	_lock_turn_choice_for_sun_hunt()
	update_ui()

func _maybe_prompt_breidablik_on_turn_start() -> void:
	if game_manager == null or game_manager.current_player == null:
		return
	for zone in game_manager.current_player.power_zones:
		for card in zone.cards:
			if not (card is Breidablik):
				continue
			var power := card as Breidablik
			if power.is_face_down or power.is_muted:
				continue
			if not power.can_return_priest(game_manager):
				continue
			_show_breidablik_prompt(power)
			return

func _get_absence_targets() -> Array[Card]:
	var targets: Array[Card] = []
	for player in [player1, player2]:
		for god in player.god_zone.cards:
			if god != null and god.is_god:
				targets.append(god)
		for zone in player.power_zones:
			if zone.cards.is_empty():
				continue
			var power: Card = zone.cards[0]
			if power is PowerCard:
				targets.append(power)
	return targets

func _prompt_absence_target_selection() -> void:
	var spell := selected_card
	if spell == null or spell is not Absence:
		return
	var targets := _get_absence_targets()
	if targets.is_empty():
		action_label.text = "Absence has no valid targets."
		update_ui()
		return
	if not _can_cast_hand_spell(spell):
		action_label.text = "Cannot cast " + spell.card_name + "!"
		update_ui()
		return
	_begin_pending_click_selection(
		spell.card_name,
		spell,
		func(clicked_card: Card) -> bool:
			return clicked_card != null and clicked_card in _get_absence_targets(),
		func(clicked_card: Card) -> void:
			_cast_targeted_spell(spell, clicked_card)
	)
	action_label.text = "Absence: click a Power or God Ability to target."
	update_ui()

var _zone_overlay: Control = null

func _create_centered_overlay_panel(overlay: Control, width_ratio: float = 0.90, height_ratio: float = 0.42) -> PanelContainer:
	var panel := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.08, 0.14, 0.97)
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		pstyle.set_border_width(side, 2)
	pstyle.border_color = Color(0.5, 0.5, 0.75)
	panel.add_theme_stylebox_override("panel", pstyle)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5

	var viewport_size := get_viewport_rect().size
	var panel_width := minf(maxf(420.0, viewport_size.x * width_ratio), viewport_size.x - 40.0)
	var panel_height := minf(maxf(240.0, viewport_size.y * height_ratio), viewport_size.y - 40.0)
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5
	overlay.add_child(panel)
	return panel

func _show_zone_contents(zone_name: String, zone: Zone) -> void:
	if zone.cards.size() == 0:
		action_label.text = zone_name + " is empty."
		return

	# Dismiss any existing overlay first
	_dismiss_zone_overlay()

	# Full-screen dimmed backdrop
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 300
	add_child(overlay)
	_promote_transient_ui(overlay)
	_zone_overlay = overlay

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)

	var panel := _create_centered_overlay_panel(overlay)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = zone_name + " (%d)" % zone.cards.size()
	title.add_theme_font_size_override("font_size", 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# Scrollable row of cards
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, VisualCard.CARD_HEIGHT + 24)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(scroll)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(hbox)

	for card in zone.cards:
		var vc := VisualCard.new()
		vc.setup(card)
		vc.set_hover_viewer(game_manager.get_feedback_viewer())
		vc.set_hover_preview_when_disabled(true)
		vc.set_disabled(true, false)
		hbox.add_child(vc)

	# Clicking anywhere on the overlay closes it
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_dismiss_zone_overlay()
	)

func _show_card_selection_overlay(
	title_text: String,
	cards: Array,
	on_selected: Callable,
	on_cancel: Callable = Callable(),
	cursor_mode: String = ""
) -> void:
	if cards.is_empty():
		action_label.text = title_text + ": no valid cards."
		return

	_dismiss_zone_overlay()
	_overlay_card_selected = on_selected
	_overlay_card_dismissed = on_cancel
	_overlay_selection_cursor_mode = cursor_mode
	_sync_sacrifice_cursor()

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 300
	add_child(overlay)
	_promote_transient_ui(overlay)
	_zone_overlay = overlay

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)

	var panel := _create_centered_overlay_panel(overlay)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var title := Label.new()
	title.text = title_text + " (%d)" % cards.size()
	title.add_theme_font_size_override("font_size", 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, VisualCard.CARD_HEIGHT + 24)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(scroll)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(hbox)

	for card: Card in cards:
		var wrapper := PanelContainer.new()
		wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
		var wstyle := StyleBoxFlat.new()
		wstyle.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		wstyle.border_color = Color(0.7, 0.8, 1.0, 0.65)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			wstyle.set_border_width(side, 1)
		wrapper.add_theme_stylebox_override("panel", wstyle)
		hbox.add_child(wrapper)

		var vc := VisualCard.new()
		vc.setup(card)
		vc.set_hover_viewer(game_manager.get_feedback_viewer())
		vc.set_disabled(true, false)
		wrapper.add_child(vc)

		var captured: Card = card
		wrapper.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				var callback := _overlay_card_selected
				_overlay_card_dismissed = Callable()
				_dismiss_zone_overlay()
				if callback.is_valid():
					callback.call(captured)
		)

	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var dismiss_callback := _overlay_card_dismissed
			_dismiss_zone_overlay()
			if dismiss_callback.is_valid():
				dismiss_callback.call()
	)

func _dismiss_zone_overlay() -> void:
	if _zone_overlay and is_instance_valid(_zone_overlay):
		_zone_overlay.queue_free()
	_zone_overlay = null
	_overlay_card_selected = Callable()
	_overlay_card_dismissed = Callable()
	_overlay_selection_cursor_mode = ""
	_sync_sacrifice_cursor()

func _get_stack_card_type_label(card: Card) -> String:
	if card == null:
		return "Card"
	if card.has_type("Charm"):
		return "Charm"
	if card.is_god:
		return "God"
	if card.is_power:
		return "Power"
	return Card.CardType.keys()[card.card_type].capitalize()

func _get_card_name_safe(
	card: Card,
	fallback: String = "Card",
	viewer: Player = null,
	hidden_fallback: String = "Hidden card"
) -> String:
	if card == null:
		return fallback
	var resolved_viewer := viewer
	if resolved_viewer == null and game_manager != null:
		resolved_viewer = game_manager.get_feedback_viewer()
	return card.get_log_display_name(resolved_viewer, hidden_fallback)

func _get_zone_position_label(zone: Zone) -> String:
	if zone == null:
		return "unknown position"
	match zone.zone_type:
		Zone.ZoneType.FRONTLINE:
			return "Front Line position " + str(zone.zone_index + 1)
		Zone.ZoneType.RESERVE:
			return "Reserve Line position " + str(zone.zone_index + 1)
		Zone.ZoneType.POWER_SLOT:
			return "Power slot " + str(zone.zone_index + 1)
		Zone.ZoneType.GOD_SLOT:
			return "God slot"
	return "position " + str(zone.zone_index + 1)

func _get_hidden_target_label(card: Card, _viewer: Player = null) -> String:
	if card == null:
		return "a hidden target"
	return card.get_hidden_log_position_label()

func _get_target_label(card: Card, viewer: Player = null, fallback: String = "target") -> String:
	if card == null:
		return fallback
	var resolved_viewer := viewer
	if resolved_viewer == null and game_manager != null:
		resolved_viewer = game_manager.get_feedback_viewer()
	return card.get_target_log_display_name(resolved_viewer)

func _get_attack_card_label(card: Card, fallback: String = "Card") -> String:
	if card == null:
		return fallback
	var controller := card.get_controller()
	if controller != null and controller.player_name != "":
		return controller.player_name + "'s " + card.get_display_name()
	var owner_player := card.card_owner
	if owner_player != null and owner_player.player_name != "":
		return owner_player.player_name + "'s " + card.get_display_name()
	return card.get_display_name()

func _has_pending_target_selection() -> bool:
	return match_manager != null and match_manager.is_targeting_active()

func _get_pending_target_selection_name() -> String:
	return match_manager.get_targeting_name() if match_manager != null else "Target selection"

func _cancel_pending_target_selection(reason: String) -> bool:
	if not _has_pending_target_selection():
		return false
	_hide_devour_cancel_prompt()
	var paid_preview_card := _pending_paid_hand_card
	var selection_source = match_manager.pending_click_selection_source if match_manager != null else null
	var spell_source = match_manager.spell_waiting_for_target if match_manager != null else null
	var should_fizzle_paid_preview := paid_preview_card != null and (
		paid_preview_card == selection_source
		or paid_preview_card == spell_source
	)
	
	if match_manager != null:
		match_manager.cancel_targeting()
	
	selected_card = null
	if should_fizzle_paid_preview and paid_preview_card != null:
		_clear_paid_hand_card_preview(paid_preview_card)
	print(reason)
	action_label.text = reason
	update_ui()
	return true

func _consume_resolution_feedback(fallback: String = "") -> String:
	if game_manager != null:
		var feedback := game_manager.consume_player_feedback()
		if feedback.strip_edges() != "":
			return feedback
	return fallback

func _get_activation_unavailable_text(card: Card, fallback: String) -> String:
	if card != null and card.is_activation_locked(game_manager):
		return card.card_name + " cannot be activated this turn."
	if card != null and card.has_method("get_activation_failure_reason"):
		var reason = card.get_activation_failure_reason(game_manager)
		if reason is String and str(reason).strip_edges() != "":
			return str(reason)
	return fallback

func _begin_pending_click_selection(
		selection_name: String,
		source_card: Card,
		validator: Callable,
		confirm_callback: Callable,
		cancel_callback: Callable = Callable()
) -> void:
	if match_manager == null:
		return
	match_manager.start_click_selection(selection_name, source_card, validator, confirm_callback, cancel_callback)

func _clear_pending_click_selection() -> void:
	if match_manager == null:
		return
	_hide_devour_cancel_prompt()
	match_manager._clear_targeting_state()

func _has_pending_click_selection() -> bool:
	if match_manager == null:
		return false
	return match_manager.pending_click_selection_confirm.is_valid()

func _handle_invalid_pending_target_click(cancel_reason: String = "") -> bool:
	if not _has_pending_target_selection():
		return false
	if _is_devour_cursor_mode_active():
		if _suppress_next_devour_cancel_prompt:
			_suppress_next_devour_cancel_prompt = false
			if cancel_reason.strip_edges() != "":
				action_label.text = cancel_reason
				update_ui()
			else:
				action_label.text = _get_pending_target_selection_name() + ": click a valid target."
				update_ui()
			return true
		_show_devour_cancel_prompt()
	elif cancel_reason.strip_edges() != "":
		_cancel_pending_target_selection(cancel_reason)
	else:
		action_label.text = _get_pending_target_selection_name() + ": click a valid target."
		update_ui()
	return true

func _get_pending_click_invalid_reason(clicked_card: Card) -> String:
	if clicked_card == null or not _has_pending_click_selection():
		return ""
	var source := _pending_click_selection_source
	if source is Fenrir:
		return (source as Fenrir).get_devour_target_failure_reason(clicked_card)
	return ""

func _try_handle_pending_click_selection(clicked_card: Card) -> bool:
	if not _has_pending_click_selection():
		return false
	if clicked_card == null:
		return true
	
	if match_manager == null:
		return false
	if not match_manager.pending_click_selection_validator.call(clicked_card):
		return false
		
	match_manager.confirm_click_selection(clicked_card)
	return true

func _resolve_hand_permanent_hex_target(hex: PermanentHexCard, target: Card) -> void:
	if hex == null or target == null or game_manager == null:
		return
	if not hex.play_to_target(game_manager, target):
		action_label.text = hex.card_name + " fizzles: choose a valid creature."
		update_ui()
		return
	selected_card = null
	placement_mode = ""
	placement_container.visible = false
	var target_label := _get_target_label(target, game_manager.get_feedback_viewer(), "target")
	action_label.text = _consume_resolution_feedback(hex.card_name + " attaches to " + target_label + ".")
	update_ui()

func _begin_hand_permanent_hex_target_selection(hex: PermanentHexCard) -> void:
	if hex == null:
		return
	selected_card = hex
	for vc in _hand_visual_cards:
		vc.set_highlighted(vc.card_data == hex)
	var targets := hex.get_valid_targets(game_manager)
	if targets.is_empty():
		action_label.text = hex.card_name + " has no valid creature targets right now."
		update_ui()
		return
	_begin_pending_click_selection(
		hex.card_name,
		hex,
		func(clicked_card: Card) -> bool:
			return clicked_card != null and hex.can_play_to_target(game_manager, clicked_card),
		func(clicked_card: Card) -> void:
			_resolve_hand_permanent_hex_target(hex, clicked_card)
	)
	action_label.text = hex.card_name + ": click a creature to target."
	update_ui()

func _queue_priority_hex_response_with_target(
	hex: HexCard,
	source_action: CardAction,
	chosen_target: Card,
	target_is_attacker: bool
) -> void:
	if hex == null or source_action == null:
		return
	game_manager.prepared_hexes.erase(hex)
	hex.is_prepared = false
	hex.reveal(game_manager)
	_queue_hex_response_action(hex, source_action, chosen_target, target_is_attacker)

func _begin_priority_hex_target_selection(
	hex: HexCard,
	source_action: CardAction,
	target_is_attacker: bool
) -> void:
	if hex == null or source_action == null:
		return
	var current_targets := game_manager.get_priority_hex_targets(hex, source_action)
	if current_targets.is_empty():
		action_label.text = hex.card_name + " has no valid targets."
		update_ui()
		return
	if current_targets.size() == 1:
		_queue_priority_hex_response_with_target(hex, source_action, current_targets[0], target_is_attacker)
		return
	var validator := func(clicked_card: Card) -> bool:
		return clicked_card != null and clicked_card in game_manager.get_priority_hex_targets(hex, source_action)
	var confirm_selection := func(clicked_card: Card) -> void:
		_queue_priority_hex_response_with_target(hex, source_action, clicked_card, target_is_attacker)
	var cancel_selection := func() -> void:
		action_label.text = "Cancelled " + hex.card_name + " target selection."
		update_ui()
		_offer_priority()
	_begin_pending_click_selection(
		hex.card_name,
		hex,
		validator,
		confirm_selection,
		cancel_selection
	)
	action_label.text = hex.card_name + ": click a valid target."
	update_ui()

func _queue_magical_action(action_type: int, source_card: Card, target, resolution_text: String, resolve_callback: Callable, display_zone: Zone = null) -> void:
	var action := CardAction.new()
	action.type = action_type
	action.source_player = source_card.card_owner if source_card != null and source_card.card_owner != null else game_manager.current_player
	action.card = source_card
	action.target = target
	action.resolve_callback = resolve_callback
	action.resolution_text = resolution_text
	action.display_zone = display_zone
	_assign_stack_display_zone(action)
	game_manager.push_to_stack(action)
	_clear_paid_hand_card_preview(source_card)
	selected_card = null
	awaiting_spell_target = false
	spell_waiting_for_target = null
	spell_waiting_for_action = null
	spell_waiting_for_display_zone = null
	_pending_spell_display_zone = null
	update_ui()
	var _card_type_label: String = _get_stack_card_type_label(source_card)
	action_label.text = source_card.card_name + " [" + _card_type_label + "] goes on the stack."
	_offer_priority()

func _queue_targeted_ability_action(source_card: Card, target: Card, resolve_callback: Callable, resolution_text: String = "") -> void:
	if source_card == null or target == null:
		return
	if _is_networked_client:
		game_input.submit_action({type = "activate_card_ability", source_uid = source_card.uid, target_uid = target.uid})
		return
	var target_name := _get_target_label(target, game_manager.get_feedback_viewer(), "target")
	var queued_text := resolution_text if resolution_text != "" else _get_attack_card_label(source_card, source_card.card_name) + " is targeting " + target_name + "."
	_queue_magical_action(
		CardAction.Type.ABILITY,
		source_card,
		target,
		queued_text,
		resolve_callback
	)

func _queue_hex_response_action(
	hex: HexCard,
	source_action: CardAction,
	chosen_target: Card = null,
	chosen_target_is_attacker: bool = false
) -> void:
	if hex == null or source_action == null:
		return
	var ability := CardAction.new()
	ability.type = CardAction.Type.ABILITY
	ability.source_player = hex.card_owner
	ability.card = hex
	ability.response_to = source_action
	ability.attacker = chosen_target if chosen_target_is_attacker and chosen_target != null else source_action.attacker
	ability.interceptor = source_action.interceptor
	ability.target = chosen_target if not chosen_target_is_attacker and chosen_target != null else source_action.target
	_assign_stack_display_zone(ability)
	game_manager.push_to_stack(ability)
	var displayed_target := chosen_target if chosen_target != null else ability.attacker
	if displayed_target != null and hex.targets:
		action_label.text = _get_attack_card_label(hex, hex.card_name) + " is targeting " + _get_target_label(displayed_target, game_manager.get_feedback_viewer(), "target") + "."
	else:
		action_label.text = hex.card_name + " responds!"
	_offer_priority()

func _try_queue_god_targeted_ability(target: Card) -> bool:
	if not awaiting_god_ability_target or god_ability_source == null:
		return false
	if not god_ability_source.has_method("is_valid_activation_target") or not god_ability_source.is_valid_activation_target(target):
		_cancel_pending_target_selection(
			_get_pending_target_selection_name()
			+ " cancelled: invalid target "
			+ _get_card_name_safe(target, "selected")
			+ "."
		)
		return true
	var source_god := god_ability_source
	awaiting_god_ability_target = false
	god_ability_source = null
	if _is_networked_client:
		var god_uid: String = source_god.get("uid") if "uid" in source_god else ""
		var target_uid: String = target.get("uid") if target != null and "uid" in target else ""
		game_input.submit_action({type = "god_ability", god_uid = god_uid, target_uid = target_uid})
	else:
		_queue_targeted_ability_action(
			source_god,
			target,
			func() -> void:
				source_god.activate(game_manager, target)
		)
	return true

func _can_cast_hand_spell(spell: Card) -> bool:
	return spell != null \
		and game_manager != null \
		and spell.card_owner != null \
		and game_manager.can_play_card(spell.card_owner, spell, null)

func _pay_hand_card_costs(card: Card, custom_pay_callback: Callable = Callable()) -> bool:
	if card == null or game_manager == null or card.card_owner == null:
		return false
	if custom_pay_callback.is_valid():
		return custom_pay_callback.call() == true
	return card.pay_costs(card.card_owner, game_manager)

func _queue_power_activation_action(
	power: PowerCard,
	target,
	resolution_text: String,
	resolve_callback: Callable
) -> bool:
	if power == null:
		update_ui()
		return false
	if _is_networked_client:
		var target_uid: String = target.uid if target is Card else ""
		game_input.submit_action({type = "activate_power", power_uid = power.uid, target_uid = target_uid})
		return true
	if power.requires_activation_hand_discards() and not power.has_pending_activation_discards_for_cost():
		var on_choose_activation_cost := func() -> void:
			_queue_power_activation_action(power, target, resolution_text, resolve_callback)
		var on_cancel_activation_cost := func() -> void:
			power.clear_pending_activation_discards()
			action_label.text = "Cancelled " + power.card_name + "."
			update_ui()
		_prompt_power_activation_discards(power, on_choose_activation_cost, on_cancel_activation_cost)
		return true
	_queue_magical_action(
		CardAction.Type.ABILITY,
		power,
		target,
		resolution_text,
		func() -> void:
			if resolve_callback.is_valid():
				resolve_callback.call()
	)
	return true

func _prompt_chosen_hand_discards(card: Card, on_complete: Callable, on_cancel: Callable = Callable(), chosen: Array[Card] = []) -> bool:
	if card == null or card.card_owner == null or card.discard_cost <= 0:
		return false
	var chosen_discards: Array[Card] = chosen.duplicate()
	if chosen_discards.size() >= card.discard_cost:
		card.set_pending_chosen_discards(chosen_discards)
		if on_complete.is_valid():
			on_complete.call()
		return true
	var discard_choices: Array[Card] = card.get_valid_play_discards(card.card_owner)
	for already_chosen in chosen_discards:
		discard_choices.erase(already_chosen)
	if discard_choices.is_empty():
		card.clear_pending_chosen_discards()
		action_label.text = "Cannot play " + card.card_name + ": choose another card in hand to discard."
		update_ui()
		return true
	var on_choose_discard := func(selected_discard: Card) -> void:
		var next_chosen: Array[Card] = chosen_discards.duplicate()
		next_chosen.append(selected_discard)
		_prompt_chosen_hand_discards(card, on_complete, on_cancel, next_chosen)
	var on_cancel_discard := func() -> void:
		card.clear_pending_chosen_discards()
		if on_cancel.is_valid():
			on_cancel.call()
	_show_card_selection_overlay(
		"Choose discard %d of %d for %s" % [chosen_discards.size() + 1, card.discard_cost, card.card_name],
		discard_choices,
		on_choose_discard,
		on_cancel_discard
	)
	return true

func _prompt_power_activation_discards(power: PowerCard, on_complete: Callable, on_cancel: Callable = Callable(), chosen: Array[Card] = []) -> bool:
	if power == null or power.card_owner == null or power.get_activation_discard_cost() <= 0:
		return false
	var chosen_discards: Array[Card] = chosen.duplicate()
	if chosen_discards.size() >= power.get_activation_discard_cost():
		power.set_pending_activation_discards(chosen_discards)
		if on_complete.is_valid():
			on_complete.call()
		return true

	var discard_choices: Array[Card] = power.get_valid_activation_discards()
	for already_chosen in chosen_discards:
		discard_choices.erase(already_chosen)
	if discard_choices.is_empty():
		power.clear_pending_activation_discards()
		action_label.text = "Cannot choose a discard for " + power.card_name + "."
		update_ui()
		return false

	var on_choose_discard := func(chosen_card: Card) -> void:
		var next_chosen: Array[Card] = chosen_discards.duplicate()
		next_chosen.append(chosen_card)
		_prompt_power_activation_discards(power, on_complete, on_cancel, next_chosen)
	var on_cancel_discard := func() -> void:
		power.clear_pending_activation_discards()
		if on_cancel.is_valid():
			on_cancel.call()

	_show_card_selection_overlay(
		"Choose discard %d of %d for %s" % [chosen_discards.size() + 1, power.get_activation_discard_cost(), power.card_name],
		discard_choices,
		on_choose_discard,
		on_cancel_discard
	)
	return true

func _send_used_hand_card_to_graveyard(card: Card) -> void:
	if card == null or game_manager == null or card.card_owner == null:
		return
	if card.current_zone == card.card_owner.hand_zone:
		card.card_owner.hand_zone.cards.erase(card)
	if card.current_zone != card.card_owner.graveyard_zone:
		card.card_owner.move_card(card, card.card_owner.graveyard_zone)

func _queue_hand_spell_cast(
	spell: Card,
	target,
	resolution_text: String,
	resolve_callback: Callable,
	custom_pay_callback: Callable = Callable(),
	after_payment_callback: Callable = Callable()
) -> bool:
	if spell == null:
		update_ui()
		return false
	var display_zone := _get_paid_hand_card_display_zone(spell)
	if display_zone == null and _pending_spell_display_zone != null:
		display_zone = _resolve_pending_display_zone(spell, _pending_spell_display_zone)
	var costs_already_paid := display_zone != null
	if not costs_already_paid:
		if not custom_pay_callback.is_valid() and spell.requires_chosen_hand_discards() and not spell.has_pending_chosen_discards_for_cost():
			var on_choose_spell_cost := func() -> void:
				_queue_hand_spell_cast(spell, target, resolution_text, resolve_callback, custom_pay_callback, after_payment_callback)
			var on_cancel_spell_cost := func() -> void:
				action_label.text = "Cancelled " + spell.card_name + "."
				update_ui()
			_prompt_chosen_hand_discards(
				spell,
				on_choose_spell_cost,
				on_cancel_spell_cost
			)
			return true
		if not _can_cast_hand_spell(spell):
			action_label.text = "Cannot cast " + spell.card_name + "!"
			update_ui()
			return false
		if not _pay_hand_card_costs(spell, custom_pay_callback):
			action_label.text = "Cannot afford " + spell.card_name + "!"
			update_ui()
			return false
		if after_payment_callback.is_valid():
			after_payment_callback.call()
	var queued_resolve := func() -> void:
		game_manager.notify_spell_played(spell.card_owner, spell)
		if resolve_callback.is_valid():
			resolve_callback.call()
		_send_used_hand_card_to_graveyard(spell)
	_queue_magical_action(
		CardAction.Type.SPELL,
		spell,
		target,
		resolution_text,
		queued_resolve,
		display_zone
	)
	return true

func _queue_priority_event(
	event_name: String,
	source_card: Card = null,
	event_speed: int = 0,
	resolve_callback: Callable = Callable(),
	initial_priority_player: Player = null,
	source_player_override: Player = null
) -> void:
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = source_player_override if source_player_override != null else game_manager.current_player
	action.initial_priority_player = initial_priority_player
	action.card = source_card
	action.event_name = event_name
	action.event_speed = event_speed
	action.resolve_callback = resolve_callback
	game_manager.push_to_stack(action)
	update_ui()
	action_label.text = event_name.replace("_", " ").capitalize() + " window opened."
	_offer_priority()

func _pause_stack_resolution(source_player: Player) -> void:
	_stack_resolution_paused = true
	_pending_post_execute_source_player = source_player

func _resume_after_deferred_resolution(feedback_text: String = "") -> void:
	if not _stack_resolution_paused:
		if feedback_text.strip_edges() != "":
			action_label.text = feedback_text
			update_ui()
		return
	var source_player := _pending_post_execute_source_player
	_stack_resolution_paused = false
	_pending_post_execute_source_player = null
	update_ui()
	if feedback_text.strip_edges() != "":
		action_label.text = feedback_text
	else:
		action_label.text = _consume_resolution_feedback(action_label.text)
	_finish_post_execute(source_player)

func _queue_hand_spell_with_deferred_resolution(
	spell: Card,
	target,
	resolution_text: String,
	resolve_callback: Callable,
	custom_pay_callback: Callable = Callable(),
	after_payment_callback: Callable = Callable()
) -> bool:
	if spell == null:
		update_ui()
		return false
	var display_zone := _get_paid_hand_card_display_zone(spell)
	if display_zone == null and _pending_spell_display_zone != null:
		display_zone = _resolve_pending_display_zone(spell, _pending_spell_display_zone)
	var costs_already_paid := display_zone != null
	if not costs_already_paid:
		if not custom_pay_callback.is_valid() and spell.requires_chosen_hand_discards() and not spell.has_pending_chosen_discards_for_cost():
			var on_choose_deferred_spell_cost := func() -> void:
				_queue_hand_spell_with_deferred_resolution(spell, target, resolution_text, resolve_callback, custom_pay_callback, after_payment_callback)
			var on_cancel_deferred_spell_cost := func() -> void:
				action_label.text = "Cancelled " + spell.card_name + "."
				update_ui()
			_prompt_chosen_hand_discards(
				spell,
				on_choose_deferred_spell_cost,
				on_cancel_deferred_spell_cost
			)
			return true
		if not _can_cast_hand_spell(spell):
			action_label.text = "Cannot cast " + spell.card_name + "!"
			update_ui()
			return false
		if not _pay_hand_card_costs(spell, custom_pay_callback):
			action_label.text = "Cannot afford " + spell.card_name + "!"
			update_ui()
			return false
		if after_payment_callback.is_valid():
			after_payment_callback.call()
	var queued_resolve := func() -> void:
		game_manager.notify_spell_played(spell.card_owner, spell)
		if resolve_callback.is_valid():
			resolve_callback.call()
	_queue_magical_action(
		CardAction.Type.SPELL,
		spell,
		target,
		resolution_text,
		queued_resolve,
		display_zone
	)
	return true

func _prompt_charm_target_selection(charm: CharmCard, triggering_action: CardAction = null, display_zone: Zone = null) -> void:
	if charm == null or game_manager == null:
		return
	var targets := charm.get_valid_targets(game_manager)
	if targets.is_empty():
		action_label.text = charm.card_name + " has no valid targets."
		update_ui()
		return
	selected_card = charm
	var resolved_display_zone := _resolve_pending_display_zone(charm, display_zone)
	var from_hand: bool = charm.current_zone == charm.card_owner.hand_zone
	if from_hand and not charm.can_activate_from_hand(game_manager, triggering_action):
		action_label.text = charm.card_name + " cannot be played right now."
		update_ui()
		return
	_begin_pending_click_selection(
		charm.card_name,
		charm,
		func(clicked_card: Card) -> bool:
			return charm.is_valid_target(clicked_card),
		func(clicked_card: Card) -> void:
			spell_waiting_for_display_zone = resolved_display_zone
			_queue_charm_action(charm, triggering_action, clicked_card)
	)
	action_label.text = charm.card_name + ": choosing target. Click a valid card."
	update_ui()

func _queue_charm_action(charm: CharmCard, triggering_action: CardAction = null, target: Card = null) -> void:
	if charm == null or game_manager == null:
		return
	var source_action: CardAction = triggering_action
	if source_action == null and not game_manager.action_stack.is_empty():
		source_action = game_manager.action_stack.back()
	if charm.targets and not charm.is_valid_target(target):
		action_label.text = charm.card_name + " requires a valid target."
		update_ui()
		return
	var from_hand: bool = charm.current_zone == charm.card_owner.hand_zone
	if _is_networked_client:
		var charm_target_uid: String = target.uid if target is Card else ""
		game_input.submit_action({type = "cast_charm", charm_uid = charm.uid, target_uid = charm_target_uid, prepared = not from_hand})
		selected_card = null
		awaiting_spell_target = false
		spell_waiting_for_target = null
		spell_waiting_for_action = null
		spell_waiting_for_display_zone = null
		return
	var preferred_display_zone := _get_paid_hand_card_display_zone(charm)
	if preferred_display_zone == null and spell_waiting_for_display_zone != null:
		preferred_display_zone = _resolve_pending_display_zone(charm, spell_waiting_for_display_zone)
	elif preferred_display_zone == null and _pending_spell_display_zone != null:
		preferred_display_zone = _resolve_pending_display_zone(charm, _pending_spell_display_zone)
	elif preferred_display_zone == null and target is Card and (target as Card).current_zone != null:
		preferred_display_zone = _resolve_pending_display_zone(charm, (target as Card).current_zone)
	if from_hand and _pending_paid_hand_card == charm and _pending_paid_hand_display_zone_auto and target is Card and (target as Card).current_zone != null:
		preferred_display_zone = _resolve_pending_display_zone(charm, (target as Card).current_zone)
		_pending_paid_hand_display_zone = preferred_display_zone
		_pending_paid_hand_display_zone_auto = false
	if from_hand:
		if not charm.can_activate_from_hand(game_manager, source_action):
			action_label.text = charm.card_name + " cannot be played right now."
			return
		if _get_paid_hand_card_display_zone(charm) == null:
			if not charm.pay_costs(charm.card_owner, game_manager):
				action_label.text = "Cannot afford " + charm.card_name + "!"
				return
			_begin_paid_hand_card_preview(charm, preferred_display_zone)
	else:
		if not charm.can_activate_prepared(game_manager, source_action):
			action_label.text = charm.card_name + " is not ready to activate."
			return
		game_manager.prepared_charms.erase(charm)
		charm.is_prepared = false
		charm.reveal(game_manager)
	var action := CardAction.new()
	action.type = CardAction.Type.SPELL
	action.source_player = charm.card_owner
	action.card = charm
	action.target = target
	action.response_to = source_action
	if target != null:
		var target_name := _get_target_label(target, game_manager.get_feedback_viewer(), "target")
		action.resolution_text = _get_attack_card_label(charm, charm.card_name) + " is targeting " + target_name + "."
	else:
		action.resolution_text = charm.card_name + " resolved."
	action.resolve_callback = func() -> void:
		_resolve_charm_action(charm, target)
	action.display_zone = _get_paid_hand_card_display_zone(charm)
	if action.display_zone == null:
		action.display_zone = preferred_display_zone
	_assign_stack_display_zone(action)
	game_manager.push_to_stack(action)
	_clear_paid_hand_card_preview(charm)
	selected_card = null
	awaiting_spell_target = false
	spell_waiting_for_target = null
	spell_waiting_for_action = null
	spell_waiting_for_display_zone = null
	update_ui()
	if target != null:
		var stack_target_name := _get_target_label(target, game_manager.get_feedback_viewer(), "target")
		action_label.text = _get_attack_card_label(charm, charm.card_name) + " is targeting " + stack_target_name + "."
	else:
		action_label.text = charm.card_name + " [" + _get_stack_card_type_label(charm) + "] goes on the stack."
	_offer_priority()

func _resolve_charm_action(charm: CharmCard, target: Card = null) -> void:
	if charm == null:
		return
	if charm.current_zone != null and charm.current_zone.is_board_zone():
		charm.reveal(game_manager)
	charm.resolve(game_manager, target)
	if charm.current_zone != null and charm.current_zone != charm.card_owner.graveyard_zone:
		charm.card_owner.move_card(charm, charm.card_owner.graveyard_zone)

func _on_local_player_card_moved(card: Card, from_zone: Zone, to_zone: Zone) -> void:
	if card == null or from_zone == null or to_zone == null:
		return
	if from_zone.zone_type != Zone.ZoneType.HAND:
		return
	if to_zone.is_board_zone() and card.card_type in [Card.CardType.CREATURE, Card.CardType.STRUCTURE]:
		return
	if not _is_in_play_zone(to_zone):
		return
	if card.current_zone != to_zone:
		return
	if card.goes_to_graveyard_after_use():
		return
	if card in _pending_hand_play_events:
		return
	_pending_hand_play_events.append(card)
	call_deferred("_flush_hand_play_priority_events")

func _on_card_summoned(player: Player, card: Card, _from_zone: Zone, to_zone: Zone, _summon_source: Card, _face_down: bool, _stealth: bool) -> void:
	if player == null or card == null or to_zone == null:
		return
	_pending_summon_priority_events.append({
		"player": player,
		"card": card,
		"zone": to_zone,
	})
	call_deferred("_flush_summon_priority_events")

func _flush_summon_priority_events() -> void:
	if _pending_summon_priority_events.is_empty():
		return
	if game_manager == null:
		_pending_summon_priority_events.clear()
		return
	var event: Dictionary = _pending_summon_priority_events.pop_front()
	var player: Player = event.get("player", null)
	var card: Card = event.get("card", null)
	var zone: Zone = event.get("zone", null)
	if player == null or card == null or zone == null:
		if not _pending_summon_priority_events.is_empty():
			call_deferred("_flush_summon_priority_events")
		return
	if card.current_zone != zone:
		if not _pending_summon_priority_events.is_empty():
			call_deferred("_flush_summon_priority_events")
		return
	if not game_manager.action_stack.is_empty():
		if not _pending_summon_priority_events.is_empty():
			call_deferred("_flush_summon_priority_events")
		return
	var on_resolve := func() -> void:
		update_ui()
		action_label.text = card.card_name + " was summoned."
		if not _pending_summon_priority_events.is_empty():
			call_deferred("_flush_summon_priority_events")
	_queue_priority_event(
		"summon",
		card,
		card.get_effective_speed(),
		on_resolve,
		game_manager.get_opponent(player),
		player
	)

func _flush_hand_play_priority_events() -> void:
	if _pending_hand_play_events.is_empty():
		return
	if game_manager == null or not game_manager.action_stack.is_empty():
		call_deferred("_flush_hand_play_priority_events")
		return
	var played_card: Card = _pending_hand_play_events.pop_front()
	if played_card == null or played_card.current_zone == null or not _is_in_play_zone(played_card.current_zone):
		call_deferred("_flush_hand_play_priority_events")
		return
	_queue_priority_event(
		"hand_play",
		played_card,
		played_card.get_effective_speed(),
		func() -> void:
			update_ui()
			action_label.text = played_card.card_name + " was played from hand."
			if not _pending_hand_play_events.is_empty():
				call_deferred("_flush_hand_play_priority_events")
	)

func _is_in_play_zone(zone: Zone) -> bool:
	if zone == null:
		return false
	if zone.is_board_zone():
		return true
	return zone.zone_type == Zone.ZoneType.GOD_SLOT or zone.zone_type == Zone.ZoneType.POWER_SLOT

func draw_board() -> void:
	var display_player := _get_display_player()
	# Fast path: refresh existing zone UIs in-place if the player hasn't changed
	if display_player != null and display_player == _last_board_player \
			and not _board_zone_uis.is_empty():
		for zu in _board_zone_uis:
			if is_instance_valid(zu):
				zu._refresh_display()
		if _player_god_zone_ui != null and is_instance_valid(_player_god_zone_ui):
			_player_god_zone_ui._refresh_display()
		return
	# Full rebuild
	for child in board_container.get_children():
		child.queue_free()
	_board_zone_uis.clear()
	_last_board_player = display_player
	board_container.add_theme_constant_override("separation", 0)
	if display_player == null:
		return

	var board_row := HBoxContainer.new()
	board_row.add_theme_constant_override("separation", int(BOARD_ZONE_COLUMN_GAP))
	board_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_container.add_child(board_row)

	for i in range(2):
		var power_zone := display_player.power_zones[i]
		var pzu := BoardZoneUI.new()
		board_row.add_child(pzu)
		pzu.setup(power_zone, game_manager, display_player, i, _on_card_dropped_to_zone, false, "power")
		pzu.card_clicked.connect(func(card: Card) -> void:
			if card is PowerCard:
				_on_power_pressed(card as PowerCard)
		)
		_board_zone_uis.append(pzu)

	for i in range(display_player.frontline_zones.size()):
		var zone = display_player.frontline_zones[i]
		var zu := BoardZoneUI.new()
		board_row.add_child(zu)
		zu.setup(zone, game_manager, display_player, i, _on_card_dropped_to_zone, false, "front line")
		zu.zone_clicked.connect(_on_empty_zone_pressed)
		zu.card_clicked.connect(_on_board_card_pressed)
		zu.creature_drag_started.connect(_on_creature_drag_started)
		zu.creature_right_clicked.connect(_on_creature_right_clicked)
		_board_zone_uis.append(zu)

	board_row.add_child(_make_zone_info_icon("Grave", "GY", display_player.graveyard_zone, Color(0.3, 0.5, 0.3)))

	var reserve_row := HBoxContainer.new()
	reserve_row.add_theme_constant_override("separation", int(BOARD_ZONE_COLUMN_GAP))
	reserve_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reserve_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_container.add_child(reserve_row)
	reserve_row.add_child(_make_god_cluster(display_player.god_zone, display_player, false))

	var reserve_power_zone := display_player.power_zones[2]
	var rpzu := BoardZoneUI.new()
	reserve_row.add_child(rpzu)
	rpzu.setup(reserve_power_zone, game_manager, display_player, 2, _on_card_dropped_to_zone, false, "power")
	rpzu.card_clicked.connect(func(card: Card) -> void:
		if card is PowerCard:
			_on_power_pressed(card as PowerCard)
	)
	_board_zone_uis.append(rpzu)

	for i in range(display_player.reserve_zones.size()):
		var zone = display_player.reserve_zones[i]
		var zu := BoardZoneUI.new()
		reserve_row.add_child(zu)
		zu.setup(zone, game_manager, display_player, i, _on_card_dropped_to_zone, false, "reserve line")
		zu.zone_clicked.connect(_on_empty_zone_pressed)
		zu.card_clicked.connect(_on_board_card_pressed)
		zu.creature_drag_started.connect(_on_creature_drag_started)
		zu.creature_right_clicked.connect(_on_creature_right_clicked)
		_board_zone_uis.append(zu)

	reserve_row.add_child(_make_zone_info_icon("Abyss", "AB", display_player.abyss_zone, Color(0.6, 0.1, 0.6)))

func draw_enemy_board() -> void:
	var enemy_player := _get_display_opponent()
	# Fast path: refresh existing zone UIs in-place if the opponent hasn't changed
	if enemy_player != null and enemy_player == _last_enemy_player \
			and not _enemy_zone_uis.is_empty():
		for zu in _enemy_zone_uis:
			if is_instance_valid(zu):
				zu._refresh_display()
		if _enemy_god_zone_ui != null and is_instance_valid(_enemy_god_zone_ui):
			_enemy_god_zone_ui._refresh_display()
		return
	# Full rebuild
	_no_intercept_btn = null  # enemy_board_container children are about to be freed
	for child in enemy_board_container.get_children():
		child.queue_free()
	_enemy_zone_uis.clear()
	_enemy_god_zone_ui = null
	_last_enemy_player = enemy_player
	enemy_board_container.add_theme_constant_override("separation", 0)
	if enemy_player == null:
		return

	var enemy_reserve_row := HBoxContainer.new()
	enemy_reserve_row.add_theme_constant_override("separation", int(BOARD_ZONE_COLUMN_GAP))
	enemy_reserve_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enemy_reserve_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enemy_board_container.add_child(enemy_reserve_row)
	enemy_reserve_row.add_child(_make_god_cluster(enemy_player.god_zone, enemy_player, true))

	var enemy_reserve_power_zone := enemy_player.power_zones[2]
	var erpzu := BoardZoneUI.new()
	enemy_reserve_row.add_child(erpzu)
	erpzu.setup(enemy_reserve_power_zone, game_manager, enemy_player, 2, _on_card_dropped_to_zone, true, "power")
	erpzu.card_clicked.connect(_on_enemy_card_pressed)
	_enemy_zone_uis.append(erpzu)

	for i in range(enemy_player.reserve_zones.size()):
		var zone = enemy_player.reserve_zones[i]
		var zu := BoardZoneUI.new()
		enemy_reserve_row.add_child(zu)
		zu.setup(zone, game_manager, enemy_player, i, _on_card_dropped_to_zone, true, "reserve line")
		zu.card_clicked.connect(_on_enemy_card_pressed)
		_enemy_zone_uis.append(zu)

	enemy_reserve_row.add_child(_make_zone_info_icon("Abyss", "AB", enemy_player.abyss_zone, Color(0.6, 0.1, 0.6)))

	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", int(BOARD_ZONE_COLUMN_GAP))
	enemy_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enemy_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enemy_board_container.add_child(enemy_row)

	for i in range(2):
		var enemy_power_zone := enemy_player.power_zones[i]
		var epzu := BoardZoneUI.new()
		enemy_row.add_child(epzu)
		epzu.setup(enemy_power_zone, game_manager, enemy_player, i, _on_card_dropped_to_zone, true, "power")
		epzu.card_clicked.connect(_on_enemy_card_pressed)
		_enemy_zone_uis.append(epzu)

	for i in range(enemy_player.frontline_zones.size()):
		var zone = enemy_player.frontline_zones[i]
		var zu := BoardZoneUI.new()
		enemy_row.add_child(zu)
		zu.setup(zone, game_manager, enemy_player, i, _on_card_dropped_to_zone, true, "front line")
		zu.card_clicked.connect(_on_enemy_card_pressed)
		_enemy_zone_uis.append(zu)

	enemy_row.add_child(_make_zone_info_icon("Grave", "GY", enemy_player.graveyard_zone, Color(0.3, 0.5, 0.3)))

func _try_activate_graveyard_hand_proxy(card: Card) -> bool:
	if not _is_graveyard_hand_proxy(card):
		return false
	if game_manager == null:
		return true
	if not game_manager.action_stack.is_empty():
		action_label.text = card.card_name + " cannot return from the graveyard while another action is resolving."
		update_ui()
		return true
	if not card.has_method("activate_from_graveyard"):
		return true
	var feedback := str(card.activate_from_graveyard(game_manager))
	selected_card = null
	placement_mode = ""
	placement_container.visible = false
	action_label.text = feedback
	update_ui()
	return true

func _select_hand_card(card: Card) -> void:
	selected_card = card
	for vc in _hand_visual_cards:
		vc.set_highlighted(vc.card_data == card)

func _select_hand_creature_for_placement(card: Card, mode: String) -> void:
	_pending_spell_display_zone = null
	_pending_move_card = null
	_select_hand_card(card)
	placement_mode = mode
	placement_container.visible = false
	action_label.text = card.card_name + " selected - click an empty friendly zone to place (" + mode.to_upper() + ")"
	update_ui()

func _on_hand_card_pressed(card: Card) -> void:
	if _game_finished:
		return
	_pending_spell_display_zone = null
	if _is_card_usable_for_priority(card):
		_on_priority_response_chosen(card)
		return
	if game_manager != null and not game_manager.action_stack.is_empty():
		action_label.text = card.card_name + " is not a legal priority response."
		update_ui()
		return
	if _is_blot_selection_active():
		if _try_add_creature_to_blot(card):
			return
	if _has_pending_target_selection():
		_cancel_pending_target_selection(
			_get_pending_target_selection_name()
			+ " cancelled: "
			+ card.card_name
			+ " is not a valid target."
		)
		return
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		return
	if _try_activate_graveyard_hand_proxy(card):
		return
	if game_manager != null and game_manager.current_player != null and card.current_zone != game_manager.current_player.hand_zone:
		action_label.text = card.card_name + " is not playable from this hand right now."
		update_ui()
		return
	if card is PermanentHexCard:
		_begin_hand_permanent_hex_target_selection(card as PermanentHexCard)
		return
	_select_hand_card(card)
	var fenrir_hand_ability_available := card is Fenrir and (card as Fenrir).can_use_hand_ability(game_manager)
	if card is CharmCard:
		if (card as CharmCard).must_be_prepared_to_activate:
			placement_mode = "prepare_charm"
			action_label.text = card.card_name + " selected - click an empty friendly zone to prepare it."
		else:
			action_label.text = "Selected charm: " + card.card_name + " - click a zone to play it, right-click for menu, or drag with S/right-click to prepare it."
	elif card.card_type == Card.CardType.SPELL:
		placement_mode = ""
		if card is BitMeseri:
			action_label.text = "BitMeseri - Drag onto a creature or structure to void it"
		elif card is Absence:
			action_label.text = "Absence - click a Power or God Ability to target it, or drag onto one directly"
		else:
			action_label.text = "Selected spell: " + card.card_name + " - click a zone to cast it, or drag with S/right-click to prepare it."
	elif fenrir_hand_ability_available:
		action_label.text = card.card_name + " selected - right-click for placement options or Wolf Master, or drag to place (S while dragging = stealth)"
	elif card.card_type == Card.CardType.CREATURE and not card.is_god:
		action_label.text = card.card_name + " selected Ã¢â‚¬â€ right-click for placement options, or drag to place (S while dragging = stealth)"
	elif card.is_god:
		action_label.text = card.card_name + " Ã¢â‚¬â€ God card, place in your God slot"
	# --- STRUCTURE UI CHANGE START ---
	elif card.card_type == Card.CardType.STRUCTURE:
		# Structures don't need mode selection, but we set placement_mode for the next step to trigger the placement logic
		placement_mode = "defensive" 
		placement_container.visible = false 
		action_label.text = "Selected Structure: " + card.card_name + " - Click an empty zone to place it"
	# --- STRUCTURE UI CHANGE END ---
	else:
		action_label.text = "Card type not yet supported in this test UI"

func _on_hand_card_right_clicked(card: Card) -> void:
	if _game_finished:
		return
	if _reject_priority_locked_action():
		return
	if _has_pending_target_selection():
		_show_target_cancel_prompt()
		return
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		return
	if _try_activate_graveyard_hand_proxy(card):
		return
	if card == selected_card and card.card_type == Card.CardType.SPELL:
		_toggle_selected_spell_prepare_mode()
		return
	if card is CharmCard:
		_close_context_menu()
		var charm_panel := PanelContainer.new()
		charm_panel.name = "HandCardContextMenu"
		var charm_style := StyleBoxFlat.new()
		charm_style.bg_color = Color(0.1, 0.1, 0.18, 0.97)
		charm_style.border_color = Color(0.45, 0.82, 0.95)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			charm_style.set_border_width(side, 2)
		charm_style.corner_radius_top_left = 4
		charm_style.corner_radius_top_right = 4
		charm_style.corner_radius_bottom_left = 4
		charm_style.corner_radius_bottom_right = 4
		charm_panel.add_theme_stylebox_override("panel", charm_style)
		charm_panel.z_index = 200

		var charm_vbox := VBoxContainer.new()
		charm_vbox.add_theme_constant_override("separation", 4)
		charm_panel.add_child(charm_vbox)

		var charm_title := Label.new()
		charm_title.text = card.card_name
		charm_title.add_theme_font_size_override("font_size", 13)
		charm_title.modulate = Color(0.85, 0.95, 1.0)
		charm_vbox.add_child(charm_title)

		if not (card as CharmCard).must_be_prepared_to_activate:
			var play_btn := Button.new()
			play_btn.text = "Play Charm"
			play_btn.pressed.connect(func() -> void:
				_close_context_menu()
				selected_card = card
				placement_mode = ""
				action_label.text = card.card_name + " selected - click a zone to play it."
			)
			charm_vbox.add_child(play_btn)

		var prepare_btn := Button.new()
		prepare_btn.text = "Prepare Charm"
		prepare_btn.pressed.connect(func() -> void:
			_close_context_menu()
			selected_card = card
			placement_mode = "prepare_charm"
			action_label.text = card.card_name + " selected - click an empty friendly zone to prepare it."
		)
		charm_vbox.add_child(prepare_btn)

		var charm_cancel_btn := Button.new()
		charm_cancel_btn.text = "Cancel"
		charm_cancel_btn.pressed.connect(_close_context_menu)
		charm_vbox.add_child(charm_cancel_btn)

		_context_menu = charm_panel
		add_child(charm_panel)
		_promote_transient_ui(charm_panel)
		charm_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		var charm_mouse_pos := get_global_mouse_position()
		charm_panel.global_position = charm_mouse_pos
		await get_tree().process_frame
		if not is_instance_valid(charm_panel):
			return
		var charm_viewport_size := get_viewport_rect().size
		charm_panel.global_position = Vector2(
			clamp(charm_mouse_pos.x, 4.0, charm_viewport_size.x - charm_panel.size.x - 4.0),
			clamp(charm_mouse_pos.y, 4.0, charm_viewport_size.y - charm_panel.size.y - 4.0)
		)
		return

	if card.card_type != Card.CardType.CREATURE or card.is_god:
		return
	_close_context_menu()

	var panel := PanelContainer.new()
	panel.name = "HandCardContextMenu"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.18, 0.97)
	style.border_color = Color(0.5, 0.7, 1.0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	style.corner_radius_top_left = 4; style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4; style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 200

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = card.card_name
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.9, 0.9, 0.6)
	vbox.add_child(title)

	for entry in [["Play in Aggressive Stance", "aggressive"], ["Play in Defensive Stance", "defensive"], ["Play in Stealth Mode (face-down)", "stealth"]]:
		var btn := Button.new()
		btn.text = entry[0]
		var mode: String = entry[1]
		btn.pressed.connect(func():
			_close_context_menu()
			_select_hand_creature_for_placement(card, mode)
			return
			selected_card = card
			placement_mode = mode
			action_label.text = card.card_name + " Ã¢â‚¬â€ click an empty zone to place (" + mode.to_upper() + ")"
		)
		vbox.add_child(btn)

	if card is Fenrir and (card as Fenrir).can_use_hand_ability(game_manager):
		for entry in [["Wolf Master in Aggressive Stance", "aggressive"], ["Wolf Master in Defensive Stance", "defensive"], ["Wolf Master in Stealth Mode", "stealth"]]:
			var wolf_btn := Button.new()
			wolf_btn.text = entry[0]
			var wolf_mode: String = entry[1]
			wolf_btn.pressed.connect(func() -> void:
				_close_context_menu()
				_queue_fenrir_wolf_master(card as Fenrir, wolf_mode)
			)
			vbox.add_child(wolf_btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_close_context_menu)
	vbox.add_child(cancel)

	_context_menu = panel
	add_child(panel)
	_promote_transient_ui(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var _mp := get_global_mouse_position()
	panel.global_position = _mp
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	var _vp := get_viewport_rect().size
	panel.global_position = Vector2(
		clamp(_mp.x, 4.0, _vp.x - panel.size.x - 4.0),
		clamp(_mp.y, 4.0, _vp.y - panel.size.y - 4.0)
	)

func _toggle_selected_spell_prepare_mode() -> void:
	if selected_card == null or selected_card.card_type != Card.CardType.SPELL:
		return
	if placement_mode == "prepare_spell":
		placement_mode = ""
		action_label.text = "Selected spell: " + selected_card.card_name + " - click a zone to cast it, or drag with S/right-click to prepare it."
	else:
		placement_mode = "prepare_spell"
		action_label.text = "Selected spell: " + selected_card.card_name + " - preparation mode on. Click or drag to an empty friendly zone to prepare it face-down."
	update_ui()

func _on_aggressive_stance_pressed() -> void:
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		return
	placement_mode = "aggressive"
	action_label.text = "Aggressive stance selected - Click empty zone to place"
	if _pending_drop_zone != null:
		_on_empty_zone_pressed(_pending_drop_zone)
		_pending_drop_zone = null

func _on_defensive_stance_pressed() -> void:
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		return
	placement_mode = "defensive"
	action_label.text = "Defensive stance selected - Click empty zone to place"
	if _pending_drop_zone != null:
		_on_empty_zone_pressed(_pending_drop_zone)
		_pending_drop_zone = null

func _on_stealth_mode_pressed() -> void:
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		return
	placement_mode = "stealth"
	action_label.text = "Stealth mode selected - Click empty zone to place"
	if _pending_drop_zone != null:
		_on_empty_zone_pressed(_pending_drop_zone)
		_pending_drop_zone = null

func _on_empty_zone_pressed(zone: Zone) -> void:
	if _game_finished:
		return
	if _pending_skoll_summon != null and not _awaiting_creature_sacrifice and not _awaiting_altar_void_payment:
		_resolve_skoll_upkeep_summon(zone)
		return
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		return
	if _reject_priority_locked_action():
		return
	if _awaiting_drag_sacrifice_zone:
		if zone.zone_type in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE] \
				and zone.zone_owner == game_manager.current_player:
			_execute_drag_sacrifice(zone)
		else:
			action_label.text = "Choose an empty friendly zone to place " + _drag_sacrifice_card.card_name
		return
	if _pending_wolf_master_summon != null:
		_resolve_wolf_master_summon(zone)
		return
	if _has_pending_target_selection():
		if _is_devour_cursor_mode_active():
			_show_devour_cancel_prompt()
			return
		_cancel_pending_target_selection(
			_get_pending_target_selection_name()
			+ " cancelled: clicked an empty zone."
		)
		return

	# Handle pending move from context menu
	if _pending_move_card != null:
		var card := _pending_move_card
		_pending_move_card = null
		_close_context_menu()
		if zone.cards.size() == 0 and zone in card.card_owner.get_adjacent_zones(card.current_zone):
			if game_input.submit_action({type = "creature_move", card_uid = card.uid,
					player_index = game_manager.players.find(zone.zone_owner),
					zone_type = zone.zone_type, zone_index = zone.zone_index}):
				action_label.text = card.card_name + " moved."
				update_ui()
				return
		action_label.text = "Invalid move target Ã¢â‚¬â€ must be an adjacent empty zone."
		update_ui()
		return
	if selected_card == null:
		action_label.text = "Select a card from hand, or choose placement mode for creature first"
		return

	if selected_card is CharmCard:
		var charm := selected_card as CharmCard
		if placement_mode == "prepare_charm" or charm.must_be_prepared_to_activate:
			if game_input.submit_action({type = "prepare_card", card_uid = selected_card.uid,
					player_index = game_manager.players.find(zone.zone_owner),
					zone_type = zone.zone_type, zone_index = zone.zone_index}):
				action_label.text = "Prepared Charm: " + selected_card.card_name + " (face-down)!"
				selected_card = null
				placement_mode = ""
				placement_container.visible = false
				update_ui()
			else:
				action_label.text = "Cannot prepare " + selected_card.card_name + "!"
		else:
			if charm.targets:
				_prompt_charm_target_selection(charm)
			else:
				_queue_charm_action(charm)
		return
	if selected_card.card_type == Card.CardType.SPELL:
			if placement_mode == "prepare_spell":
				if game_input.submit_action({type = "prepare_card", card_uid = selected_card.uid,
						player_index = game_manager.players.find(zone.zone_owner),
						zone_type = zone.zone_type, zone_index = zone.zone_index}):
					action_label.text = "Prepared Spell: " + selected_card.card_name + " (face-down)!"
					selected_card = null
					placement_mode = ""
					placement_container.visible = false
					update_ui()
				else:
					action_label.text = "Cannot prepare " + selected_card.card_name + "!"
			elif game_manager.can_play_card(game_manager.current_player, selected_card, zone):
				if selected_card is ApollyonsDemiurge or selected_card.card_name == "Apollyon's Demiurge":
					_show_demiurge_prompt(selected_card)
				elif selected_card is BookOfLife:
					_show_book_of_life_prompt(selected_card as BookOfLife)
				elif selected_card is DeucalionsInfants:
					_queue_deucalion_resolution(selected_card as DeucalionsInfants)
				elif selected_card != null and (selected_card is BlotSacrifice or selected_card.card_name == "Blot Sacrifice"):
					_show_blot_sacrifice_prompt(selected_card)
				elif selected_card is Absence:
					_prompt_absence_target_selection()
				elif selected_card is CircleOfRebirth:
					var resurrect_count := get_resurrectible_cards().size()
					var spell := selected_card
					_queue_hand_spell_cast(
						spell,
						null,
						("Circle of Rebirth resurrected %d creature(s)!" % resurrect_count) if resurrect_count > 0 else "Cast Circle of Rebirth but no creatures to resurrect!",
						func() -> void:
							(spell as SpellCard).resolve(game_manager, null)
					)
				else:
					var spell := selected_card
					_queue_hand_spell_cast(
						spell,
						null,
						"Cast " + spell.card_name + "!",
						func() -> void:
							(spell as SpellCard).resolve(game_manager, null)
					)
			else:
				action_label.text = "Cannot cast spell! Not enough resources"
	elif selected_card.current_zone == game_manager.current_player.hand_zone \
			and selected_card.requires_chosen_hand_discards() \
			and not selected_card.has_pending_chosen_discards_for_cost():
		_prompt_chosen_hand_discards(
			selected_card,
			func() -> void:
				_on_empty_zone_pressed(zone),
			func() -> void:
				action_label.text = "Cancelled " + selected_card.card_name + "."
				update_ui()
		)
		return
	elif selected_card.card_type == Card.CardType.CREATURE and placement_mode != "":
		_try_play_selected_creature_to_zone(zone)
		return
	# --- STRUCTURE UI CHANGE START ---
	elif selected_card.card_type == Card.CardType.STRUCTURE:
		if game_manager.can_play_card(game_manager.current_player, selected_card, zone):
	# Structure defensive stance is handled internally by StructureCard.gd
			var played_structure := selected_card
			game_input.submit_action({type = "play_card", card_uid = selected_card.uid,
					player_index = game_manager.players.find(zone.zone_owner),
					zone_type = zone.zone_type, zone_index = zone.zone_index})
			var building_power := _get_active_advanced_building_techniques(game_manager.current_player)
			if building_power != null and building_power.can_offer_structure_bonus(played_structure, game_manager):
				action_label.text = "Played Structure: " + played_structure.card_name + "! Choose how much mana to spend on Advanced Building Techniques."
				_show_structure_bonus_prompt(building_power, played_structure)
			else:
				action_label.text = "Played Structure: " + played_structure.card_name + "!"
			
			selected_card = null
			placement_mode = ""
			placement_container.visible = false
			update_ui()
		else:
			action_label.text = "Cannot play Structure! Not enough resources."
	# --- STRUCTURE UI CHANGE END ---
	elif selected_card.card_type == Card.CardType.EQUIPMENT and selected_card.current_zone == game_manager.current_player.hand_zone:
		if game_manager.can_play_card(game_manager.current_player, selected_card, zone):
			var equip_name := selected_card.card_name
			game_input.submit_action({type = "play_card", card_uid = selected_card.uid,
					player_index = game_manager.players.find(zone.zone_owner),
					zone_type = zone.zone_type, zone_index = zone.zone_index})
			var creature_there := zone.get_creature()
			if creature_there != null:
				action_label.text = equip_name + " equipped to " + creature_there.card_name + "!"
			else:
				action_label.text = "Played " + equip_name + " to zone."
			selected_card = null
			placement_mode = ""
			placement_container.visible = false
			update_ui()
		else:
			action_label.text = "Cannot play " + selected_card.card_name + "! Not enough resources."
	elif selected_card.card_type == Card.CardType.HEX:
		if game_input.submit_action({type = "prepare_card", card_uid = selected_card.uid,
				player_index = game_manager.players.find(zone.zone_owner),
				zone_type = zone.zone_type, zone_index = zone.zone_index}):
			action_label.text = "Prepared Hex: " + selected_card.card_name + " (face-down)!"
			selected_card = null
			placement_mode = ""
			placement_container.visible = false
			update_ui()
		else:
			action_label.text = "Cannot prepare Hex! Not enough resources."
	else:
		action_label.text = "Select a card from hand, or choose placement mode for creature first"

func get_resurrectible_cards() -> Array[Card]:
	var cards: Array[Card] = []
	for player in [game_manager.current_player, game_manager.other_player]:
		for card in player.graveyard_zone.cards:
			if card.card_type == Card.CardType.CREATURE:
				if card.has_type("Plant") or card.has_type("Animal"):
					cards.append(card)
	return cards

func _on_god_card_pressed(card: Card) -> void:
	if _has_pending_target_selection():
		if _try_handle_pending_click_selection(card):
			return
		_handle_invalid_pending_target_click()
		return
	if selected_card is Absence and card.is_god:
		_cast_targeted_spell(selected_card, card)
		return
	if _try_queue_god_targeted_ability(card):
		return
	if not card.is_god:
		return
	if not card.has_method("can_activate"):
		action_label.text = card.card_name + " has no activatable ability."
		return
	if card.is_muted:
		action_label.text = card.card_name + " is muted for " + str(card.mute_turns_remaining) + " more turn(s)."
		return
	if choice_container.visible:
		action_label.text = "You must draw or take mana before activating a god ability."
		return
	if not card.can_activate(game_manager):
		action_label.text = _get_activation_unavailable_text(card, card.card_name + "'s ability cannot be activated right now.")
		return
	if card is AphroditeAreia:
		_show_aphrodite_prompt(card as AphroditeAreia)
	elif _god_ability_should_use_selection_overlay(card):
		var targets: Array = card.get_valid_targets(game_manager)
		if targets.is_empty():
			action_label.text = card.card_name + " has no valid targets right now."
			update_ui()
			return
		_show_card_selection_overlay(
			"Choose a target for " + card.card_name,
			targets,
			func(selected_target: Card) -> void:
				if _is_networked_client:
					var god_uid: String = card.get("uid") if "uid" in card else ""
					var target_uid: String = selected_target.get("uid") if "uid" in selected_target else ""
					game_input.submit_action({type = "god_ability", god_uid = god_uid, target_uid = target_uid})
				else:
					var resolution_text := _get_attack_card_label(card, card.card_name) + " is targeting " + _get_target_label(selected_target, game_manager.get_feedback_viewer(), selected_target.card_name) + "."
					_queue_targeted_ability_action(
						card,
						selected_target,
						func() -> void:
							card.activate(game_manager, selected_target),
						resolution_text
					)
		)
	else:
		awaiting_god_ability_target = true
		god_ability_source = card
		action_label.text = card.card_name + " - click a valid target."
		update_ui()

func _god_ability_should_use_selection_overlay(card: Card) -> bool:
	if card == null or game_manager == null or not card.has_method("get_valid_targets"):
		return false
	var targets: Array = card.get_valid_targets(game_manager)
	if targets.is_empty():
		return false
	for target in targets:
		var target_card := target as Card
		if target_card == null:
			return true
		if target_card.current_zone == null or not target_card.current_zone.is_board_zone():
			return true
	return false

func _on_god_power_activated(_turn_number: int, _player: Player, _god: Card, _target: Card) -> void:
	pass

func _execute_drag_sacrifice(zone: Zone) -> void:
	var card := _drag_sacrifice_card
	var sacrificed := _drag_sacrifice_target
	var mode := _drag_sacrifice_mode
	var total_sacrifice_cost := card.sacrifice_cost if card != null else 0
	_awaiting_drag_sacrifice_zone = false
	_drag_sacrifice_card = null
	_drag_sacrifice_target = null
	_drag_sacrifice_mode = ""
	# Sacrifice and summon simultaneously
	_resolve_creature_summon_sacrifice(
		sacrificed,
		card,
		func() -> void:
			if card == null:
				update_ui()
				return
			if total_sacrifice_cost > 1:
				_sacrifice_pending_card = card
				_sacrifice_pending_zone = zone
				_sacrifice_pending_mode = mode
				_sacrifice_remaining = total_sacrifice_cost - 1
				_awaiting_creature_sacrifice = true
				action_label.text = _get_creature_sacrifice_prompt(_sacrifice_pending_card, _sacrifice_remaining)
				update_ui()
				return
			_resolve_pending_creature_play(card, zone, mode)
			update_ui()
	)

func _do_place_creature(card: Card, zone: Zone, mode: String) -> void:
	var summon_mode: Card.CreatureMode = Card.CreatureMode.DEFENSIVE
	if mode == "aggressive":
		summon_mode = Card.CreatureMode.AGGRESSIVE
	var stealth := mode == "stealth"
	var card_uid: String = card.get("uid") if "uid" in card else ""
	var success := game_input.submit_action({
		type = "play_creature",
		card_uid = card_uid,
		player_index = game_manager.players.find(zone.zone_owner),
		zone_type = zone.zone_type,
		zone_index = zone.zone_index,
		mode = summon_mode,
		stealth = stealth,
	})
	if not _is_networked_client:
		if not success:
			action_label.text = "Cannot summon " + card.card_name + " right now."
			return
		action_label.text = "A creature was summoned in STEALTH!" if stealth else "Played " + card.card_name + " in " + ("aggressive stance" if mode == "aggressive" else "defensive stance") + "!"

func _resolve_pending_creature_play(card: Card, zone: Zone, mode: String) -> void:
	if card == null or zone == null:
		_pending_creature_play_resolver = Callable()
		return
	var resolver := _pending_creature_play_resolver
	_pending_creature_play_resolver = Callable()
	var orig_cost := card.sacrifice_cost
	if orig_cost > 0:
		card.sacrifice_cost = 0
	if resolver.is_valid():
		resolver.call(card, zone, mode)
	else:
		_do_place_creature(card, zone, mode)
	if orig_cost > 0:
		card.sacrifice_cost = orig_cost

func _can_use_zone_after_sacrifice(zone: Zone, sacrificed_card: Card) -> bool:
	if zone == null or sacrificed_card == null:
		return false
	if zone.zone_owner != game_manager.current_player:
		return false
	if zone.zone_type not in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE]:
		return false
	return zone.cards.size() == 1 and zone.cards[0] == sacrificed_card and _can_use_card_for_creature_sacrifice(sacrificed_card)

func _try_play_selected_creature_to_zone(zone: Zone) -> void:
	if selected_card == null or selected_card.card_type != Card.CardType.CREATURE or placement_mode == "":
		return
	if not game_manager.can_play_card(game_manager.current_player, selected_card, zone):
		action_label.text = "Cannot play card! Not enough resources or already summoned this turn"
		_pending_creature_play_resolver = Callable()
		return
	if selected_card.sacrifice_cost > 0 and not _drag_sacrifice_done:
		_sacrifice_pending_card = selected_card
		_sacrifice_pending_zone = zone
		_sacrifice_pending_mode = placement_mode
		_sacrifice_remaining = selected_card.sacrifice_cost
		var altar := _get_active_altar_of_dreams(game_manager.current_player)
		if altar != null and altar.has_enough_valid_void_targets(_sacrifice_pending_card, game_manager):
			selected_card = null
			placement_mode = ""
			placement_container.visible = false
			action_label.text = _get_sacrifice_payment_prompt(_sacrifice_pending_card)
			_show_sacrifice_payment_prompt(_sacrifice_pending_card, altar)
			return
		_awaiting_creature_sacrifice = true
		selected_card = null
		placement_mode = ""
		placement_container.visible = false
		action_label.text = _get_creature_sacrifice_prompt(_sacrifice_pending_card, _sacrifice_remaining)
		return
	_drag_sacrifice_done = false
	_resolve_pending_creature_play(selected_card, zone, placement_mode)
	selected_card = null
	placement_mode = ""
	placement_container.visible = false
	update_ui()

func _queue_fenrir_wolf_master(card: Fenrir, mode: String) -> void:
	if card == null or game_manager == null:
		return
	if not card.can_use_hand_ability(game_manager):
		action_label.text = "Wolf Master cannot be used right now."
		update_ui()
		return
	selected_card = null
	placement_mode = ""
	placement_container.visible = false
	if _is_networked_client:
		var network_lupines := card.get_valid_wolf_master_summons(game_manager)
		if network_lupines.is_empty():
			action_label.text = "Wolf Master: no payable Lupines in deck."
			update_ui()
			return
		_pending_wolf_master_source = card
		if network_lupines.size() == 1:
			_begin_wolf_master_summon(network_lupines[0], mode)
		else:
			_show_card_selection_overlay(
				"Choose a Lupine for Wolf Master",
				network_lupines,
				func(network_lupine: Card) -> void:
					_begin_wolf_master_summon(network_lupine, mode),
				func() -> void:
					_pending_wolf_master_source = null
					action_label.text = "Wolf Master cancelled."
					update_ui()
			)
		return
	if not card.perform_wolf_master_shuffle():
		action_label.text = "Wolf Master fizzles: " + card.card_name + " could not be shuffled."
		update_ui()
		return
	var shuffled_lupines := card.get_valid_wolf_master_summons(game_manager)
	if shuffled_lupines.is_empty():
		action_label.text = "Wolf Master fizzles: no payable Lupines are available in the deck."
		update_ui()
		return
	_pending_wolf_master_source = card
	if shuffled_lupines.size() == 1:
		_begin_wolf_master_summon(shuffled_lupines[0], mode)
		return
	_show_card_selection_overlay(
		"Choose a Lupine for Wolf Master",
		shuffled_lupines,
		func(shuffled_lupine: Card) -> void:
			_begin_wolf_master_summon(shuffled_lupine, mode),
		func() -> void:
			_pending_wolf_master_source = null
			action_label.text = "Wolf Master cancelled after shuffling " + card.card_name + "."
			update_ui()
	)

func _begin_wolf_master_summon(card: Card, mode: String) -> void:
	_pending_wolf_master_summon = card
	_pending_wolf_master_mode = mode
	selected_card = null
	placement_mode = ""
	placement_container.visible = false
	action_label.text = "Wolf Master: choose an empty friendly zone to summon " + card.card_name + " (" + mode.to_upper() + ")."
	update_ui()

func _resolve_wolf_master_summon(zone: Zone) -> void:
	var card := _pending_wolf_master_summon
	var mode := _pending_wolf_master_mode
	if card == null or game_manager == null:
		_clear_wolf_master_summon()
		update_ui()
		return
	if zone == null or zone.zone_owner != game_manager.current_player or zone.zone_type not in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE] or not zone.cards.is_empty():
		action_label.text = "Wolf Master: choose an empty friendly zone."
		update_ui()
		return
	if _is_networked_client:
		var wm_fenrir := _pending_wolf_master_source
		game_input.submit_action({
			type = "wolf_master_summon",
			fenrir_uid = wm_fenrir.uid if wm_fenrir != null else "",
			lupine_uid = card.uid,
			player_index = game_manager.players.find(zone.zone_owner),
			zone_type = zone.zone_type,
			zone_index = zone.zone_index,
			mode = mode
		})
		_clear_wolf_master_summon()
		update_ui()
		return
	selected_card = card
	placement_mode = mode
	placement_container.visible = false
	_pending_creature_play_resolver = Callable(self, "_resolve_wolf_master_creature_play")
	_try_play_selected_creature_to_zone(zone)
	if _pending_wolf_master_summon == card \
			and not _awaiting_creature_sacrifice \
			and not _awaiting_altar_void_payment \
			and card.current_zone == card.card_owner.deck_zone:
		_pending_creature_play_resolver = Callable()
		if selected_card == card:
			selected_card = null
		placement_mode = ""
		action_label.text = "Wolf Master fizzles: " + card.card_name + " could not be summoned."
		_clear_wolf_master_summon()
	update_ui()

func _clear_wolf_master_summon() -> void:
	_pending_wolf_master_source = null
	_pending_wolf_master_summon = null
	_pending_wolf_master_mode = ""
	_pending_creature_play_resolver = Callable()

func _resolve_wolf_master_creature_play(card: Card, zone: Zone, mode: String) -> void:
	if card == null or zone == null or game_manager == null:
		action_label.text = "Wolf Master fizzles: the summon could not be completed."
		_clear_wolf_master_summon()
		return
	var summon_mode: Card.CreatureMode = Card.CreatureMode.DEFENSIVE
	if mode == "aggressive":
		summon_mode = Card.CreatureMode.AGGRESSIVE
	var stealth := mode == "stealth"
	var summon_source := _pending_wolf_master_source
	var success := game_manager.summon_creature_by_effect(
		game_manager.current_player,
		card,
		zone,
		summon_mode,
		stealth,
		stealth,
		summon_source,
		true,
		true
	)
	if not success:
		action_label.text = "Wolf Master fizzles: " + card.card_name + " could not be summoned."
		_clear_wolf_master_summon()
		return
	action_label.text = "Wolf Master summoned " + card.card_name + " from the deck!"
	_clear_wolf_master_summon()

func _queue_blessed_knights_impact_prompt(card: BlessedKnights) -> void:
	if card == null or game_manager == null:
		return
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = card.card_owner
	action.card = card
	action.event_name = "blessed_knights_impact"
	action.event_speed = 0
	action.resolve_callback = func() -> void:
		if network_manager != null and network_manager.is_server:
			if _executing_stack_action and not _stack_resolution_paused:
				_pause_stack_resolution(card.card_owner)
			var player_idx := game_manager.players.find(card.card_owner)
			match_manager.request_ui_interaction.emit(player_idx, "blessed_knights_ward", {"source_uid": card.uid})
		else:
			_pause_stack_resolution(card.card_owner)
			_show_blessed_knights_prompt(card)
	game_manager.push_to_stack(action)
	update_ui()
	action_label.text = card.card_name + " impact waits on priority."
	_offer_priority()

func _queue_durinn_secondborn_impact_prompt(card: DurinnSecondborn) -> void:
	if card == null or game_manager == null:
		return
	var targets := card.get_valid_targets(game_manager)
	if targets.is_empty():
		return
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = card.card_owner
	action.card = card
	action.event_name = "durinn_secondborn_impact"
	action.event_speed = 0
	action.resolve_callback = func() -> void:
		var current_targets := card.get_valid_targets(game_manager)
		if current_targets.is_empty():
			var no_target_text := card.card_name + " found no weapons to reforge."
			if _stack_resolution_paused:
				_resume_after_deferred_resolution(no_target_text)
			else:
				action_label.text = no_target_text
				update_ui()
			return
		if current_targets.size() == 1:
			var auto_text := card.resolve_reforge_impact(game_manager, current_targets[0])
			if _stack_resolution_paused:
				_resume_after_deferred_resolution(auto_text)
			else:
				action_label.text = auto_text
				update_ui()
			return
		_pause_stack_resolution(card.card_owner)
		var on_choose_weapon := func(chosen_card: Card) -> void:
			_resume_after_deferred_resolution(card.resolve_reforge_impact(game_manager, chosen_card))
		var on_cancel_weapon := func() -> void:
			_resume_after_deferred_resolution(card.card_name + " impact fizzles.")
		_show_card_selection_overlay(
			"Choose a weapon for " + card.card_name,
			current_targets,
			on_choose_weapon,
			on_cancel_weapon
		)
	game_manager.push_to_stack(action)
	update_ui()
	action_label.text = card.card_name + " impact waits on priority."
	_offer_priority()

func _queue_first_sage_adapa_impact_prompt(card: FirstSageAdapa) -> void:
	if card == null or game_manager == null:
		return
	var targets := card.get_valid_targets(game_manager)
	if targets.is_empty():
		return
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = card.card_owner
	action.card = card
	action.event_name = "first_sage_adapa_impact"
	action.event_speed = 0
	action.resolve_callback = func() -> void:
		var current_targets := card.get_valid_targets(game_manager)
		if current_targets.is_empty():
			var no_target_text := card.card_name + " found no opposing powers or God abilities to silence."
			if _stack_resolution_paused:
				_resume_after_deferred_resolution(no_target_text)
			else:
				action_label.text = no_target_text
				update_ui()
			return
		if current_targets.size() == 1:
			var auto_text := card.resolve_silence_divine_impact(game_manager, current_targets[0])
			if _stack_resolution_paused:
				_resume_after_deferred_resolution(auto_text)
			else:
				action_label.text = auto_text
				update_ui()
			return
		_pause_stack_resolution(card.card_owner)
		_begin_pending_click_selection(
			card.card_name,
			card,
			func(clicked_card: Card) -> bool:
				return clicked_card != null and clicked_card in card.get_valid_targets(game_manager),
			func(clicked_card: Card) -> void:
				_resume_after_deferred_resolution(card.resolve_silence_divine_impact(game_manager, clicked_card)),
			func() -> void:
				_resume_after_deferred_resolution(card.card_name + " impact fizzles.")
		)
		action_label.text = card.card_name + ": click an opposing power or God ability to silence."
		update_ui()
	game_manager.push_to_stack(action)
	update_ui()
	action_label.text = card.card_name + " impact waits on priority."
	_offer_priority()

func _queue_fourth_sage_enmegalamma_impact_prompt(card) -> void:
	if card == null or game_manager == null:
		return
	var targets: Array[Card] = card.get_valid_targets(game_manager)
	if targets.is_empty():
		return
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = card.card_owner
	action.card = card
	action.event_name = "fourth_sage_enmegalamma_impact"
	action.event_speed = 0
	action.resolve_callback = func() -> void:
		var current_targets: Array[Card] = card.get_valid_targets(game_manager)
		if current_targets.is_empty():
			var no_target_text: String = card.resolve_search_sage_decline(game_manager)
			if _stack_resolution_paused:
				_resume_after_deferred_resolution(no_target_text)
			else:
				action_label.text = no_target_text
				update_ui()
			return
		if current_targets.size() == 1:
			var auto_text: String = card.resolve_search_sage_impact(game_manager, current_targets[0])
			if _stack_resolution_paused:
				_resume_after_deferred_resolution(auto_text)
			else:
				action_label.text = auto_text
				update_ui()
			return
		_pause_stack_resolution(card.card_owner)
		var on_choose_sage := func(chosen_card: Card) -> void:
			_resume_after_deferred_resolution(card.resolve_search_sage_impact(game_manager, chosen_card))
		var on_cancel_sage := func() -> void:
			_resume_after_deferred_resolution(card.resolve_search_sage_decline(game_manager))
		_show_card_selection_overlay(
			"Choose a Mer Sage for " + card.card_name,
			current_targets,
			on_choose_sage,
			on_cancel_sage
		)
	game_manager.push_to_stack(action)
	update_ui()
	action_label.text = card.card_name + " impact waits on priority."
	_offer_priority()

func _queue_gugalanna_impact_prompt(card) -> void:
	if card == null or game_manager == null:
		return
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = card.card_owner
	action.card = card
	action.event_name = "gugalanna_celestial_charge"
	action.event_speed = 0
	action.resolve_callback = func() -> void:
		var valid_targets: Array[Card] = card.get_valid_impact_targets(game_manager)
		if valid_targets.is_empty():
			# No valid targets — still return to hand.
			card.apply_celestial_charge(game_manager, null)
			var text: String = card.card_name + ": no valid targets. " + card.card_name + " returns to hand."
			if _stack_resolution_paused:
				_resume_after_deferred_resolution(text)
			else:
				action_label.text = text
				update_ui()
			return
		_pause_stack_resolution(card.card_owner)
		var on_choose := func(chosen: Card) -> void:
			card.apply_celestial_charge(game_manager, chosen)
			_resume_after_deferred_resolution(
				"Celestial Charge: %s destroys %s. %s returns to hand." % [
					card.card_name, chosen.card_name, card.card_name
				]
			)
		var on_cancel := func() -> void:
			card.apply_celestial_charge(game_manager, null)
			_resume_after_deferred_resolution(card.card_name + " skips Celestial Charge and returns to hand.")
		_show_card_selection_overlay(
			"Celestial Charge: choose a target (Res 30+, slower Spd) — or cancel to skip",
			valid_targets,
			on_choose,
			on_cancel,
			"gugalanna_celestial_charge"
		)
	game_manager.push_to_stack(action)
	update_ui()
	action_label.text = card.card_name + " Celestial Charge waits on priority."
	_offer_priority()

func _queue_giant_master_architect_impact_prompt(card) -> void:
	if card == null or game_manager == null:
		return
	var targets: Array[Card] = card.get_valid_targets(game_manager)
	if targets.is_empty():
		return
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = card.card_owner
	action.card = card
	action.event_name = "giant_master_architect_impact"
	action.event_speed = 0
	action.resolve_callback = func() -> void:
		var current_targets: Array[Card] = card.get_valid_targets(game_manager)
		if current_targets.is_empty():
			var no_target_text: String = card.resolve_no_structure_targets()
			if _stack_resolution_paused:
				_resume_after_deferred_resolution(no_target_text)
			else:
				action_label.text = no_target_text
				update_ui()
			return
		if current_targets.size() == 1:
			var auto_text: String = card.resolve_master_plan_impact(game_manager, current_targets[0])
			if _stack_resolution_paused:
				_resume_after_deferred_resolution(auto_text)
			else:
				action_label.text = auto_text
				update_ui()
			return
		_pause_stack_resolution(card.card_owner)
		var on_choose_structure := func(chosen_card: Card) -> void:
			_resume_after_deferred_resolution(card.resolve_master_plan_impact(game_manager, chosen_card))
		var on_cancel_structure := func() -> void:
			_resume_after_deferred_resolution(card.resolve_master_plan_cancel(game_manager))
		_show_card_selection_overlay(
			"Choose a structure for " + card.card_name,
			current_targets,
			on_choose_structure,
			on_cancel_structure,
			"giant_master_architect_structure"
		)
	game_manager.push_to_stack(action)
	update_ui()
	action_label.text = card.card_name + " impact waits on priority."
	_offer_priority()

func _queue_gala_tura_destroyed_prompt(card) -> void:
	if card == null or game_manager == null:
		return
	var targets: Array[Card] = card.get_destroyed_trigger_targets(game_manager)
	if targets.is_empty():
		var no_target_text: String = card.card_name + " found no creatures to return."
		if _stack_resolution_paused:
			_resume_after_deferred_resolution(no_target_text)
		else:
			action_label.text = no_target_text
			update_ui()
		return
	if _executing_stack_action and not _stack_resolution_paused:
		_pause_stack_resolution(card.card_owner)
	_pending_gala_tura = card
	_pending_gala_tura_selected.clear()
	_show_gala_tura_prompt()

func _show_gala_tura_prompt() -> void:
	var card := _pending_gala_tura
	if card == null or game_manager == null:
		_hide_gala_tura_prompt()
		update_ui()
		return
	_sanitize_gala_tura_selection()
	var valid_targets: Array[Card] = card.get_destroyed_trigger_targets(game_manager)
	var remaining_targets: Array[Card] = []
	for target in valid_targets:
		if target not in _pending_gala_tura_selected:
			remaining_targets.append(target)

	if _gala_tura_prompt_panel != null and is_instance_valid(_gala_tura_prompt_panel):
		_gala_tura_prompt_panel.queue_free()
	_gala_tura_prompt_panel = null

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.12, 0.97)
	style.border_color = Color(0.48, 0.82, 0.95, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(420, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = card.card_name
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Choose up to 3 creatures from your graveyard to return to the bottom of your deck."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var selected_label := Label.new()
	if _pending_gala_tura_selected.is_empty():
		selected_label.text = "Selected: none"
	else:
		var selected_names: Array[String] = []
		for selected_card in _pending_gala_tura_selected:
			selected_names.append(selected_card.card_name)
		selected_label.text = "Selected: " + ", ".join(selected_names)
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(selected_label)

	var choices_box := VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 4)
	vbox.add_child(choices_box)

	if _pending_gala_tura_selected.size() < 3:
		for target in remaining_targets:
			var add_btn := Button.new()
			add_btn.text = "Return " + target.card_name
			add_btn.pressed.connect(func() -> void:
				if target in _pending_gala_tura_selected:
					return
				_pending_gala_tura_selected.append(target)
				_show_gala_tura_prompt()
			)
			choices_box.add_child(add_btn)

	if remaining_targets.is_empty() or _pending_gala_tura_selected.size() >= 3:
		var done_label := Label.new()
		done_label.text = "No more selections available."
		choices_box.add_child(done_label)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	var done_btn := Button.new()
	done_btn.text = "Done"
	done_btn.pressed.connect(func() -> void:
		_resolve_gala_tura_prompt(true)
	)
	buttons.add_child(done_btn)

	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.pressed.connect(func() -> void:
		_resolve_gala_tura_prompt(false)
	)
	buttons.add_child(skip_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	_gala_tura_prompt_panel = panel
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -160
	panel.offset_bottom = 160

	action_label.text = "%s: choose up to 3 graveyard creatures to return." % card.card_name
	update_ui()

func _sanitize_gala_tura_selection() -> void:
	if _pending_gala_tura == null or game_manager == null:
		_pending_gala_tura_selected.clear()
		return
	var valid_targets: Array[Card] = _pending_gala_tura.get_destroyed_trigger_targets(game_manager)
	var cleaned: Array[Card] = []
	for card in _pending_gala_tura_selected:
		if card == null or card not in valid_targets or card in cleaned:
			continue
		cleaned.append(card)
		if cleaned.size() >= 3:
			break
	_pending_gala_tura_selected = cleaned

func _resolve_gala_tura_prompt(use_selection: bool) -> void:
	var card := _pending_gala_tura
	_sanitize_gala_tura_selection()
	var chosen_targets: Array[Card] = _pending_gala_tura_selected.duplicate() if use_selection else []
	_hide_gala_tura_prompt()
	if card == null or game_manager == null:
		update_ui()
		return
	var feedback: String = card.resolve_destroyed_trigger(game_manager, chosen_targets)
	if _stack_resolution_paused:
		_resume_after_deferred_resolution(feedback)
	else:
		action_label.text = feedback
		update_ui()

func _hide_gala_tura_prompt() -> void:
	if _gala_tura_prompt_panel != null and is_instance_valid(_gala_tura_prompt_panel):
		_gala_tura_prompt_panel.queue_free()
	_gala_tura_prompt_panel = null
	_pending_gala_tura = null
	_pending_gala_tura_selected.clear()

func _resolve_foolish_optimism_prompt(
	card: FoolishOptimism,
	_attacker_choices: Array,
	_defender_choices: Array
) -> void:
	if card == null or game_manager == null:
		if _stack_resolution_paused:
			_resume_after_deferred_resolution("Foolish Optimism fizzles.")
		else:
			update_ui()
		return

	_pause_stack_resolution(card.card_owner)

	var finish_resolution := func(chosen_attacker: Card, chosen_defender: Card) -> void:
		_resume_after_deferred_resolution(card.finish_prompt_resolution(game_manager, chosen_attacker, chosen_defender))

	var prompt_defender_choice := func(chosen_attacker: Card) -> void:
		var current_defender_choices := card.get_highest_level_defender_choices(game_manager)
		if current_defender_choices.is_empty():
			_resume_after_deferred_resolution(card.finish_prompt_resolution(game_manager, chosen_attacker, null))
			return
		if current_defender_choices.size() == 1:
			finish_resolution.call(chosen_attacker, current_defender_choices[0])
			return
		var on_choose_defender := func(chosen_defender: Card) -> void:
			finish_resolution.call(chosen_attacker, chosen_defender)
		var on_cancel_defender := func() -> void:
			card.send_to_graveyard_if_needed()
			_resume_after_deferred_resolution(card.card_name + " fizzles.")
		_show_card_selection_overlay(
			"Choose which tied highest-level face-up friendly creature is attacked for " + card.card_name,
			current_defender_choices,
			on_choose_defender,
			on_cancel_defender
		)

	var current_attacker_choices := card.get_lowest_level_attacker_choices(game_manager)
	if current_attacker_choices.is_empty():
		_resume_after_deferred_resolution(card.finish_prompt_resolution(game_manager, null, null))
		return
	if current_attacker_choices.size() == 1:
		prompt_defender_choice.call(current_attacker_choices[0])
		return

	var on_choose_attacker := func(chosen_attacker: Card) -> void:
		prompt_defender_choice.call(chosen_attacker)
	var on_cancel_attacker := func() -> void:
		card.send_to_graveyard_if_needed()
		_resume_after_deferred_resolution(card.card_name + " fizzles.")
	_show_card_selection_overlay(
		"Choose which tied lowest-level face-up opposing creature attacks for " + card.card_name,
		current_attacker_choices,
		on_choose_attacker,
		on_cancel_attacker
	)

func _queue_foolish_optimism_attack(card: FoolishOptimism, attacker: Card, defender: Card) -> String:
	if card == null or game_manager == null:
		return "Foolish Optimism fizzles."
	if attacker == null:
		return "%s fizzles: no opposing creature to compel when it resolves." % card.card_name
	if defender == null:
		return "%s fizzles: no friendly creature to attack when it resolves." % card.card_name
	if attacker.current_zone == null or not attacker.current_zone.is_board_zone():
		return "%s fizzles: the chosen attacker is no longer on the field." % card.card_name
	if defender.current_zone == null or not defender.current_zone.is_board_zone():
		return "%s fizzles: the chosen defender is no longer on the field." % card.card_name
	if not game_manager.can_cards_engage_each_other(attacker, defender):
		return "%s fizzles: %s cannot legally attack %s." % [card.card_name, attacker.card_name, defender.card_name]

	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.source_player = attacker.get_controller()
	action.card = card
	action.attacker = attacker
	action.united_front_partner = _get_declared_attack_partner(attacker)
	action.attack_speed_override = _get_declared_attack_speed(attacker)
	action.target = defender
	game_manager.push_to_stack(action)
	update_ui()
	return "%s compels %s to attack %s." % [card.card_name, attacker.card_name, defender.card_name]

func _queue_fenrir_devour_prompt(card: Fenrir) -> void:
	if card == null or game_manager == null:
		return
	var targets := card.get_valid_devour_targets(game_manager)
	if targets.is_empty():
		return
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = card.card_owner
	action.card = card
	action.event_name = "fenrir_devour_impact"
	action.event_speed = 0
	action.resolve_callback = func() -> void:
		var current_targets := card.get_valid_devour_targets(game_manager)
		if current_targets.is_empty():
			var no_target_text := card.card_name + " found no creature weak enough to devour."
			action.resolution_text = no_target_text
			if _stack_resolution_paused:
				_resume_after_deferred_resolution(no_target_text)
			else:
				action_label.text = no_target_text
				update_ui()
			return
		_pause_stack_resolution(card.card_owner)
		if current_targets.size() == 1:
			card.resolve_devour_impact(game_manager, current_targets[0], func(feedback: String) -> void:
				action.resolution_text = feedback
				_resume_after_deferred_resolution(feedback)
			)
			return
		action.resolution_text = "Click a Devour target."
		_begin_pending_click_selection(
			card.card_name + ": Devour",
			card,
			func(clicked_card: Card) -> bool:
				return clicked_card != null and clicked_card in card.get_valid_devour_targets(game_manager),
			func(chosen_card: Card) -> void:
				card.resolve_devour_impact(game_manager, chosen_card, func(feedback: String) -> void:
					_resume_after_deferred_resolution(feedback)
				),
			func() -> void:
				_resume_after_deferred_resolution(card.card_name + " impact fizzles.")
		)
		action_label.text = "Click a Devour target."
		_capture_action_log_message()
		update_ui()
	game_manager.push_to_stack(action)
	update_ui()
	action_label.text = card.card_name + " impact waits on priority."
	_offer_priority()

func _finish_creature_sacrifice_play() -> void:
	var card := _sacrifice_pending_card
	var zone := _sacrifice_pending_zone
	var mode := _sacrifice_pending_mode
	_awaiting_creature_sacrifice = false
	_sacrifice_pending_card = null
	_sacrifice_pending_zone = null
	_sacrifice_pending_mode = ""
	_sacrifice_remaining = 0
	_resolve_pending_creature_play(card, zone, mode)
	update_ui()

func _resolve_creature_summon_sacrifice(sacrificed: Card, summoned_card: Card, continue_callback: Callable = Callable()) -> void:
	if sacrificed == null:
		if continue_callback.is_valid():
			continue_callback.call()
		return
	var finish := func() -> void:
		if sacrificed.has_method("on_sacrificed_for_summon") and not sacrificed.abilities_suppressed():
			sacrificed.on_sacrificed_for_summon(game_manager, summoned_card)
		if continue_callback.is_valid():
			continue_callback.call()
	game_manager.request_send_to_graveyard(sacrificed, finish, false, false)

func _can_use_card_for_creature_sacrifice(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.can_be_used_for_creature_sacrifice

func _get_creature_sacrifice_prompt(card: Card, remaining: int) -> String:
	var card_name := card.card_name if card != null else "This card"
	return "%s - sacrifice needed: select a friendly creature to sacrifice (%d remaining)" % [
		card_name,
		remaining
	]

func _get_sacrifice_payment_prompt(card: Card) -> String:
	var card_name := card.card_name if card != null else "This card"
	return "%s - sacrifice needed: choose how to pay its sacrifice cost." % card_name

func _begin_normal_creature_sacrifice_selection() -> void:
	_hide_sacrifice_payment_prompt()
	_awaiting_altar_void_payment = false
	_altar_pending_power = null
	_altar_void_targets_chosen.clear()
	_awaiting_creature_sacrifice = true
	action_label.text = _get_creature_sacrifice_prompt(_sacrifice_pending_card, _sacrifice_remaining)
	update_ui()

func _begin_altar_void_selection() -> void:
	_hide_sacrifice_payment_prompt()
	_awaiting_creature_sacrifice = false
	_awaiting_altar_void_payment = true
	_altar_void_targets_chosen.clear()
	action_label.text = _sacrifice_pending_card.card_name + " - select a sleeping creature to void (" + str(_sacrifice_remaining) + " remaining)"
	update_ui()

func _finish_altar_void_play() -> void:
	var card := _sacrifice_pending_card
	var zone := _sacrifice_pending_zone
	var mode := _sacrifice_pending_mode
	var altar := _altar_pending_power
	var chosen_targets := _altar_void_targets_chosen.duplicate()
	_awaiting_altar_void_payment = false
	_altar_pending_power = null
	_altar_void_targets_chosen.clear()
	_sacrifice_pending_card = null
	_sacrifice_pending_zone = null
	_sacrifice_pending_mode = ""
	_sacrifice_remaining = 0
	if altar == null or card == null or zone == null:
		update_ui()
		return
	if not altar.pay_replacement_cost(card, chosen_targets, game_manager):
		action_label.text = "Altar of Dreams payment failed."
		update_ui()
		return
	_resolve_pending_creature_play(card, zone, mode)
	update_ui()

func _try_resolve_stupefy_target(card: Card) -> bool:
	if not awaiting_stupefy_target or stupefy_source == null:
		return false
	if card.card_type == Card.CardType.CREATURE and card.level <= stupefy_source.level:
		var source_stupefy := stupefy_source
		if game_manager.is_guardian_protected(card, source_stupefy):
			action_label.text = card.card_name + " is protected by Guardian!"
			return true
		if game_manager.is_immune_to_source(card, source_stupefy):
			action_label.text = card.card_name + " is immune to " + source_stupefy.card_name + "'s creature abilities this turn."
			return true
		_queue_targeted_ability_action(
			source_stupefy,
			card,
			func() -> void:
				source_stupefy.activate(game_manager, card),
			source_stupefy.card_name + " is targeting " + _get_target_label(card, game_manager.get_feedback_viewer(), card.card_name) + "."
		)
		awaiting_stupefy_target = false
		stupefy_source = null
		update_ui()
	else:
		action_label.text = "Invalid target Ã¢â‚¬â€ choose a creature of level " + str(stupefy_source.level) + " or lower."
	return true

func _on_board_card_pressed(card: Card) -> void:
	if _game_finished:
		return
	if _is_card_usable_for_priority(card):
		_on_priority_response_chosen(card)
		return
	if _has_pending_click_selection():
		if _try_handle_pending_click_selection(card):
			return
		_suppress_next_devour_cancel_prompt = _pending_click_selection_source is Fenrir
		_handle_invalid_pending_target_click(_get_pending_click_invalid_reason(card))
		return
	if _reject_priority_locked_action():
		return
	if _is_turn_choice_pending() and not _can_interact_with_board_during_turn_choice(card):
		_reject_pre_turn_action()
		return
	
	if match_manager == null:
		return
		
	if _awaiting_drag_sacrifice_zone:
		action_label.text = "Choose an empty friendly zone to place " + _drag_sacrifice_card.card_name
		if _can_use_zone_after_sacrifice(card.current_zone, card) and card == _drag_sacrifice_target:
			_execute_drag_sacrifice(card.current_zone)
		return

	if awaiting_pyre_target and pyre_source != null:
		var source_pyre := pyre_source
		_queue_targeted_ability_action(
			source_pyre,
			card,
			func() -> void:
				source_pyre.activate(game_manager, card),
			source_pyre.card_name + " is targeting " + _get_target_label(card, game_manager.get_feedback_viewer(), card.card_name) + "."
		)
		awaiting_pyre_target = false
		pyre_source = null
		update_ui()
		return

	if awaiting_anointing_target and anointing_source != null:
		var source_anointing := anointing_source
		if source_anointing.can_activate(game_manager, card):
			_queue_targeted_ability_action(
				source_anointing,
				card,
				func() -> void:
					source_anointing.activate(game_manager, card),
				source_anointing.card_name + " is targeting " + _get_target_label(card, game_manager.get_feedback_viewer(), card.card_name) + "."
			)
			awaiting_anointing_target = false
			anointing_source = null
			update_ui()
		else:
			_cancel_pending_target_selection(
				_get_pending_target_selection_name()
				+ " cancelled: invalid target "
				+ _get_card_name_safe(card, "selected")
				+ "."
			)
		return

	if awaiting_stupefy_target and stupefy_source != null \
			and not (card.card_type == Card.CardType.CREATURE and card.level <= stupefy_source.level):
		_cancel_pending_target_selection(
			_get_pending_target_selection_name()
			+ " cancelled: invalid target "
			+ _get_card_name_safe(card, "selected")
			+ "."
		)
		return
	if awaiting_stupefy_target and stupefy_source != null:
		if game_manager.is_guardian_protected(card, stupefy_source):
			_cancel_pending_target_selection(
				_get_pending_target_selection_name()
				+ " cancelled: "
				+ card.card_name
				+ " is protected by Guardian."
			)
			return
		if game_manager.is_immune_to_source(card, stupefy_source):
			_cancel_pending_target_selection(
				_get_pending_target_selection_name()
				+ " cancelled: "
				+ card.card_name
				+ " is immune to "
				+ stupefy_source.card_name
				+ "."
			)
			return

	if _try_resolve_stupefy_target(card):
		return

	if card is CharmCard and card.get_controller() == game_manager.current_player and card.is_prepared:
		var charm := card as CharmCard
		if charm.can_activate_prepared(game_manager):
			if charm.targets:
				_prompt_charm_target_selection(charm)
			else:
				_queue_charm_action(charm)
		else:
			action_label.text = charm.card_name + " is not ready to activate yet."
		return

	if selected_card != null \
			and selected_card.card_type == Card.CardType.CREATURE \
			and placement_mode != "" \
			and selected_card.sacrifice_cost > 0 \
			and _can_use_zone_after_sacrifice(card.current_zone, card):
		_try_play_selected_creature_to_zone(card.current_zone)
		return

	if _awaiting_creature_sacrifice:
		if card.get_controller() == game_manager.current_player and _can_use_card_for_creature_sacrifice(card):
			_resolve_creature_summon_sacrifice(
				card,
				_sacrifice_pending_card,
				func() -> void:
					_sacrifice_remaining -= 1
					if _sacrifice_remaining <= 0:
						_finish_creature_sacrifice_play()
					else:
						action_label.text = _get_creature_sacrifice_prompt(_sacrifice_pending_card, _sacrifice_remaining)
						update_ui()
			)
		else:
			action_label.text = "Select one of your sacrificable creatures."
		return

	if _awaiting_creature_sacrifice:
		if card.get_controller() == game_manager.current_player and _can_use_card_for_creature_sacrifice(card):
			_resolve_creature_summon_sacrifice(card, _sacrifice_pending_card)
			_sacrifice_remaining -= 1
			if _sacrifice_remaining <= 0:
				_finish_creature_sacrifice_play()
			else:
				action_label.text = _get_creature_sacrifice_prompt(_sacrifice_pending_card, _sacrifice_remaining)
				update_ui()
		else:
			action_label.text = "Select one of your sacrificable creatures."
		return

	if _awaiting_altar_void_payment:
		if card.card_type == Card.CardType.CREATURE and card.is_sleeping:
			if card in _altar_void_targets_chosen:
				action_label.text = card.card_name + " has already been chosen."
				return
			_altar_void_targets_chosen.append(card)
			_sacrifice_remaining -= 1
			if _sacrifice_remaining <= 0:
				_finish_altar_void_play()
			else:
				action_label.text = _sacrifice_pending_card.card_name + " - select a sleeping creature to void (" + str(_sacrifice_remaining) + " remaining)"
				update_ui()
		else:
			action_label.text = "Select a sleeping creature to void."
		return

	# Check if we're selecting a target for a god ability
	if _try_queue_god_targeted_ability(card):
		return

	# Non-targeted spell selected Ã¢â‚¬â€ clicking any zone (occupied or not) casts it
	# from the nearest available empty zone on the player's side.
	if selected_card != null and selected_card.card_type == Card.CardType.SPELL \
			and not awaiting_spell_target:
		var empty_zone := _find_empty_player_zone()
		if empty_zone != null:
			_on_empty_zone_pressed(empty_zone)
		else:
			action_label.text = "No empty zone available to cast " + selected_card.card_name + "!"
		return

	# Check if we're selecting a target for a spell
	if awaiting_spell_target and spell_waiting_for_target:
		if spell_waiting_for_target is BitMeseri:
			if card.card_type == Card.CardType.CREATURE or card.card_type == Card.CardType.STRUCTURE or card.card_type == Card.CardType.EQUIPMENT:
				if game_manager.is_guardian_protected(card, spell_waiting_for_target):
					_cancel_pending_target_selection(
						_get_pending_target_selection_name()
						+ " cancelled: "
						+ card.card_name
						+ " is protected by Guardian."
					)
				else:
					_cast_targeted_spell(spell_waiting_for_target, card)
			else:
				_cancel_pending_target_selection(
					_get_pending_target_selection_name()
					+ " cancelled: invalid target "
					+ _get_card_name_safe(card, "selected")
					+ "."
				)
		elif spell_waiting_for_target is CharmCard:
			var targeted_charm := spell_waiting_for_target as CharmCard
			if targeted_charm.is_valid_target(card):
				_queue_charm_action(targeted_charm, spell_waiting_for_action, card)
			else:
				_cancel_pending_target_selection(
					_get_pending_target_selection_name()
					+ " cancelled: invalid target "
					+ _get_card_name_safe(card, "selected")
					+ "."
				)
		return

	if selected_card is Absence and (card is PowerCard or card.is_god):
		_cast_targeted_spell(selected_card, card)
		return
	if _pending_equip_action != "":
		if card.get_controller() == game_manager.other_player and can_intercept(card, _pending_equip_actor, _pending_equip_target):
			_remove_no_intercept_button()
			action_label.text = card.card_name + " intercepts the " + _pending_equip_action + "!"
			resolve_pending_equip_action(card)
		else:
			action_label.text = "That creature cannot intercept"
		return

	if pending_attack_target != null:
		if card.get_controller() == game_manager.other_player and can_intercept(card, selected_attacker, pending_attack_target):
			_remove_no_intercept_button()
			selected_interceptor = card
			action_label.text = _get_card_name_safe(card) + " will intercept! Resolving combat..."
			resolve_pending_attack()
		else:
			action_label.text = "Cannot use this creature (wrong player, mode, or too slow)"
		return
	
	if card.get_controller() != game_manager.current_player:
		action_label.text = "That's not your card!"
		return
	
	if card.card_type == Card.CardType.STRUCTURE:
		if card is E2Abzu and card.get_controller() == game_manager.current_player:
			if (card as E2Abzu).can_activate(game_manager):
				_show_e2_abzu_prompt(card as E2Abzu)
			else:
				action_label.text = card.card_name + " has no usable mode right now."
				update_ui()
			return
		if card is AncientPyre and card.get_controller() == game_manager.current_player:
			if (card as AncientPyre).can_activate(game_manager):
				if (card as AncientPyre).is_frontline():
					awaiting_pyre_target = true
					pyre_source = card as AncientPyre
					action_label.text = "Ancient Pyre: Select a card to reduce Res by 5, or click the enemy god to Convert 5 followers."
				else:
					if _is_networked_client:
						game_input.submit_action({type = "activate_card_ability", source_uid = card.uid})
					else:
						_queue_magical_action(
							CardAction.Type.ABILITY,
							card,
							null,
							card.card_name + " activated!",
							func() -> void:
								(card as AncientPyre).activate(game_manager)
						)
					action_label.text = "Ancient Pyre: Ritual Flame Ã¢â‚¬â€ 5 followers converted!"
					update_ui()
			else:
				action_label.text = "Ancient Pyre cannot activate right now (need 2 mana or no valid targets)."
		elif card is AnointingStatue and card.get_controller() == game_manager.current_player:
			awaiting_anointing_target = true
			anointing_source = card as AnointingStatue
			action_label.text = "Anointing Statue: Select a creature to cleanse."
		else:
			action_label.text = card.card_name + " is a structure and cannot attack or move."
		return
	
	if card.card_type != Card.CardType.CREATURE:
		action_label.text = "That card cannot perform an action."
		return

	if card is EnHeduAnnaScript and card.can_activate(game_manager):
		_show_en_hedu_anna_prompt(card as EnHeduAnnaScript)
		return

	if network_manager != null:
		network_manager.request_action({
			"type": "select_attacker",
			"card_uid": card.get("uid")
		})
	else:
		match_manager.select_attacker(card)
	
	if match_manager.selected_attacker == card:
		action_label.text = "Selected attacker: " + _get_attack_card_label(card, "A creature") + " - Click enemy target or followers"
	elif match_manager.selected_attacker == null:
		action_label.text = card.card_name + " deselected"
	
	update_ui()

func _on_enemy_card_pressed(target_card: Card) -> void:
	if _game_finished:
		return
	if _is_card_usable_for_priority(target_card):
		_on_priority_response_chosen(target_card)
		return
	if _has_pending_click_selection():
		if _try_handle_pending_click_selection(target_card):
			return
		_suppress_next_devour_cancel_prompt = _pending_click_selection_source is Fenrir
		_handle_invalid_pending_target_click(_get_pending_click_invalid_reason(target_card))
		return
	if _reject_priority_locked_action():
		return
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		return
	if _awaiting_altar_void_payment:
		if target_card.card_type == Card.CardType.CREATURE and target_card.is_sleeping:
			if target_card in _altar_void_targets_chosen:
				action_label.text = target_card.card_name + " has already been chosen."
				return
			_altar_void_targets_chosen.append(target_card)
			_sacrifice_remaining -= 1
			if _sacrifice_remaining <= 0:
				_finish_altar_void_play()
			else:
				action_label.text = _sacrifice_pending_card.card_name + " - select a sleeping creature to void (" + str(_sacrifice_remaining) + " remaining)"
				update_ui()
		else:
			action_label.text = "Select a sleeping creature to void."
		return

	if awaiting_anointing_target and anointing_source != null:
		var source_anointing := anointing_source
		if source_anointing.can_activate(game_manager, target_card):
			_queue_targeted_ability_action(
				source_anointing,
				target_card,
				func() -> void:
					source_anointing.activate(game_manager, target_card),
				source_anointing.card_name + " is targeting " + _get_target_label(target_card, game_manager.get_feedback_viewer(), target_card.card_name) + "."
			)
			awaiting_anointing_target = false
			anointing_source = null
			update_ui()
		else:
			_cancel_pending_target_selection(
				_get_pending_target_selection_name()
				+ " cancelled: invalid target "
				+ _get_card_name_safe(target_card, "selected")
				+ "."
			)
		return

	if _try_queue_god_targeted_ability(target_card):
		return

	if selected_card is Absence and (target_card is PowerCard or target_card.is_god):
		_cast_targeted_spell(selected_card, target_card)
		return
	if awaiting_pyre_target and pyre_source != null:
		var source_pyre := pyre_source
		_queue_targeted_ability_action(
			source_pyre,
			target_card,
			func() -> void:
				source_pyre.activate(game_manager, target_card),
			source_pyre.card_name + " is targeting " + _get_target_label(target_card, game_manager.get_feedback_viewer(), target_card.card_name) + "."
		)
		awaiting_pyre_target = false
		pyre_source = null
		update_ui()
		return

	if awaiting_stupefy_target and stupefy_source != null \
			and not (target_card.card_type == Card.CardType.CREATURE and target_card.level <= stupefy_source.level):
		_cancel_pending_target_selection(
			_get_pending_target_selection_name()
			+ " cancelled: invalid target "
			+ _get_card_name_safe(target_card, "selected")
			+ "."
		)
		return
	if awaiting_stupefy_target and stupefy_source != null:
		if game_manager.is_guardian_protected(target_card, stupefy_source):
			_cancel_pending_target_selection(
				_get_pending_target_selection_name()
				+ " cancelled: "
				+ target_card.card_name
				+ " is protected by Guardian."
			)
			return
		if game_manager.is_immune_to_source(target_card, stupefy_source):
			_cancel_pending_target_selection(
				_get_pending_target_selection_name()
				+ " cancelled: "
				+ target_card.card_name
				+ " is immune to "
				+ stupefy_source.card_name
				+ "."
			)
			return

	if _try_resolve_stupefy_target(target_card):
		return

	# Non-targeted spell selected Ã¢â‚¬â€ redirect to an empty friendly zone
	# BlotSacrifice selected, clicking a friendly creature: auto-use as sacrifice target.
	if selected_card != null and (selected_card is BlotSacrifice or selected_card.card_name == "Blot Sacrifice") \
			and target_card.card_type == Card.CardType.CREATURE \
			and not target_card.is_god \
			and target_card.get_controller() == game_manager.current_player \
			and not awaiting_spell_target:
		if not game_manager.can_play_card(game_manager.current_player, selected_card, null):
			action_label.text = "Cannot cast " + selected_card.card_name + "!"
			return
		_initiate_blot_with_sacrifice(selected_card, target_card)
		selected_card = null
		return

	if selected_card != null and selected_card.card_type == Card.CardType.SPELL \
			and not awaiting_spell_target:
		var empty_zone := _find_empty_player_zone()
		if empty_zone != null:
			_on_empty_zone_pressed(empty_zone)
		else:
			action_label.text = "No empty zone available to cast " + selected_card.card_name + "!"
		return

	# Spell targeting takes priority
	if awaiting_spell_target and spell_waiting_for_target:
		if spell_waiting_for_target is BitMeseri:
			if target_card.card_type == Card.CardType.CREATURE or target_card.card_type == Card.CardType.STRUCTURE or target_card.card_type == Card.CardType.EQUIPMENT:
				if game_manager.is_guardian_protected(target_card, spell_waiting_for_target):
					_cancel_pending_target_selection(
						_get_pending_target_selection_name()
						+ " cancelled: "
						+ target_card.card_name
						+ " is protected by Guardian."
					)
				else:
					_cast_targeted_spell(spell_waiting_for_target, target_card)
			else:
				_cancel_pending_target_selection(
					_get_pending_target_selection_name()
					+ " cancelled: invalid target "
					+ _get_card_name_safe(target_card, "selected")
					+ "."
				)
		elif spell_waiting_for_target is CharmCard:
			var targeted_charm := spell_waiting_for_target as CharmCard
			if targeted_charm.is_valid_target(target_card):
				_queue_charm_action(targeted_charm, spell_waiting_for_action, target_card)
			else:
				_cancel_pending_target_selection(
					_get_pending_target_selection_name()
					+ " cancelled: invalid target "
					+ _get_card_name_safe(target_card, "selected")
					+ "."
				)
		return

	# Equipment action intercept selection
	if _pending_equip_action != "":
		if target_card.get_controller() == game_manager.other_player and can_intercept(target_card, _pending_equip_actor, _pending_equip_target):
			_remove_no_intercept_button()
			action_label.text = target_card.card_name + " intercepts the " + _pending_equip_action + "!"
			resolve_pending_equip_action(target_card)
		else:
			action_label.text = "That creature cannot intercept"
		return

	# Intercept selection (when an attack is already pending)
	if pending_attack_target != null:
		if target_card.get_controller() == game_manager.other_player and can_intercept(target_card, selected_attacker, pending_attack_target):
			_remove_no_intercept_button()
			selected_interceptor = target_card
			action_label.text = _get_card_name_safe(target_card, "An interceptor") + " will intercept! Resolving combat..."
			resolve_pending_attack()
		else:
			action_label.text = "This card cannot intercept"
		return

	# Direct attack target selection
	if selected_attacker:
		var target_id: String = ""
		if target_card.is_god:
			target_id = target_card.card_owner.player_name
		elif target_card.card_type == Card.CardType.CREATURE or target_card.card_type == Card.CardType.STRUCTURE:
			target_id = target_card.get("uid")
		
		if target_id != "":
			if network_manager != null:
				network_manager.request_action({
					"type": "request_attack",
					"attacker_uid": selected_attacker.get("uid"),
					"target_id": target_id
				})
			else:
				match_manager.request_attack(selected_attacker, target_id)
		else:
			action_label.text = "Can only attack creatures or structures"
	else:
		action_label.text = "Select your creature first to attack"

func _on_all_attack_followers_pressed() -> void:
	if _game_finished:
		return
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		return
	if game_manager.turn_number == 0:
		action_label.text = "Cannot attack on the first turn!"
		return
	if game_manager.attack_restrictions.has(game_manager.current_player):
		action_label.text = "Cannot attack! Attack restricted this turn."
		return

	var attackers: Array[Card] = []
	for zone in game_manager.current_player.frontline_zones:
		if zone.cards.size() == 0:
			continue
		var card: Card = zone.cards[0]
		if match_manager.can_attack(card):
			attackers.append(card)

	if attackers.is_empty():
		action_label.text = "No eligible frontline creatures available to attack"
		return

	_queued_attackers = attackers
	_advance_attack_queue()

func _advance_attack_queue() -> void:
	while not _queued_attackers.is_empty():
		var attacker: Card = _queued_attackers.pop_front()
		# Skip creatures that can no longer attack (died, acted, slept, etc.)
		if not match_manager.can_attack(attacker):
			continue
		# Set up exactly like a manual attack targeting followers
		match_manager.request_attack(attacker, game_manager.other_player)
		return
	# Queue exhausted
	_queued_attackers.clear()
	update_ui()

func _on_creature_right_clicked(card: Card) -> void:
	if _has_pending_target_selection():
		_show_target_cancel_prompt()
		return
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		return
	_close_context_menu()
	_pending_move_card = null

	# Build list of legal actions
	var can_attack  := match_manager.can_attack(card)
	var can_stance  := _creature_can_change_stance(card)
	var can_move    := _creature_can_move(card)
	var can_stupefy := false
	var can_activate_creature: bool = (
		card.get_controller() == game_manager.current_player
		and card.has_method("can_activate")
		and card.has_method("activate")
		and card.can_activate(game_manager)
	)
	var equipped_ability_cards: Array[Card] = []
	for equip in card.equipment:
		if equip == null:
			continue
		if equip.get_controller() != game_manager.current_player:
			continue
		if not equip.has_method("can_activate") or not equip.has_method("activate"):
			continue
		if not equip.can_activate(game_manager):
			continue
		equipped_ability_cards.append(equip)
	var equip_entries: Array[Dictionary] = []
	if _creature_can_use_equipment_action(card):
		equip_entries = _get_reachable_equipment(card)

	if not can_attack and not can_stance and not can_move and not can_activate_creature and equipped_ability_cards.is_empty() and equip_entries.is_empty():
		action_label.text = card.card_name + " has no available actions this turn."
		return

	var panel := PanelContainer.new()
	panel.name = "CreatureContextMenu"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.18, 0.97)
	style.border_color = Color(0.5, 0.7, 1.0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	style.corner_radius_top_left = 4; style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4; style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 200

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = card.card_name
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.9, 0.9, 0.6)
	vbox.add_child(title)

	if can_attack:
		var btn := Button.new()
		btn.text = "Attack"
		btn.pressed.connect(func():
			_close_context_menu()
			selected_attacker = card
			action_label.text = card.card_name + " ready to attack Ã¢â‚¬â€ click an enemy creature or zone"
		)
		vbox.add_child(btn)

	if can_stupefy:
		var btn := Button.new()
		btn.text = "Stupefy"
		btn.pressed.connect(func():
			_close_context_menu()
			awaiting_stupefy_target = true
			stupefy_source = card
			action_label.text = "Stupefy Ã¢â‚¬â€ click an enemy creature of level " + str(card.level) + " or lower"
		)
		vbox.add_child(btn)

	if can_activate_creature:
		var btn := Button.new()
		var card_activation_label: String = card.get_activation_label() if card.has_method("get_activation_label") else "Activate Ability"
		btn.text = card_activation_label
		btn.pressed.connect(func():
			_close_context_menu()
			if card is EnHeduAnnaScript:
				_show_en_hedu_anna_prompt(card as EnHeduAnnaScript)
				return
			if card is ErlqueensNightingaleScript:
				_show_erlqueens_nightingale_prompt(card as ErlqueensNightingaleScript)
				return
			if card.has_method("get_valid_targets"):
				var targets: Array = card.get_valid_targets(game_manager)
				if targets.is_empty():
					action_label.text = card.card_name + " has no valid targets right now."
					update_ui()
					return
				_show_card_selection_overlay(
					"Choose a target for " + card.card_name,
					targets,
					func(chosen_card: Card) -> void:
						_queue_targeted_ability_action(
							card,
							chosen_card,
							func() -> void:
								card.activate(game_manager, chosen_card)
						)
				)
			else:
				if _is_networked_client:
					game_input.submit_action({type = "activate_card_ability", source_uid = card.uid})
				else:
					_queue_magical_action(
						CardAction.Type.ABILITY,
						card,
						null,
						card.card_name + " activated!",
						func() -> void:
							card.activate(game_manager)
					)
		)
		vbox.add_child(btn)

	for equip in equipped_ability_cards:
		var equipped_card := equip
		var btn := Button.new()
		var activation_label: String = equipped_card.get_activation_label() if equipped_card.has_method("get_activation_label") else "Activate Ability"
		btn.text = "%s: %s" % [equipped_card.card_name, activation_label]
		btn.pressed.connect(func():
			_close_context_menu()
			if equipped_card.has_method("get_valid_targets"):
				var targets: Array = equipped_card.get_valid_targets(game_manager)
				if targets.is_empty():
					action_label.text = equipped_card.card_name + " has no valid targets right now."
					update_ui()
					return
				_show_card_selection_overlay(
					"Choose a target for " + equipped_card.card_name,
					targets,
					func(chosen_card: Card) -> void:
						_queue_targeted_ability_action(
							equipped_card,
							chosen_card,
							func() -> void:
								equipped_card.activate(game_manager, chosen_card)
						)
				)
			else:
				if _is_networked_client:
					game_input.submit_action({type = "activate_card_ability", source_uid = equipped_card.uid})
				else:
					_queue_magical_action(
						CardAction.Type.ABILITY,
						equipped_card,
						null,
						equipped_card.card_name + " activated!",
						func() -> void:
							equipped_card.activate(game_manager)
					)
		)
		vbox.add_child(btn)

	if can_stance:
		if card.is_stealth:
			var reveal_aggressive_btn := Button.new()
			reveal_aggressive_btn.text = "Reveal in Aggressive Stance"
			reveal_aggressive_btn.pressed.connect(func():
				_close_context_menu()
				var was_stealth: bool = card.is_stealth
				if game_input.submit_action({type = "change_mode", card_uid = card.uid, mode = Card.CreatureMode.AGGRESSIVE}):
					action_label.text = card.card_name + " revealed in aggressive stance."
					update_ui()
					_handle_post_reveal_prompt(card, was_stealth)
				else:
					action_label.text = card.card_name + " could not reveal in aggressive stance."
			)
			vbox.add_child(reveal_aggressive_btn)

			var reveal_defensive_btn := Button.new()
			reveal_defensive_btn.text = "Reveal in Defensive Stance"
			reveal_defensive_btn.pressed.connect(func():
				_close_context_menu()
				var was_stealth: bool = card.is_stealth
				if game_input.submit_action({type = "change_mode", card_uid = card.uid, mode = Card.CreatureMode.DEFENSIVE}):
					action_label.text = card.card_name + " revealed in defensive stance."
					update_ui()
					_handle_post_reveal_prompt(card, was_stealth)
				else:
					action_label.text = card.card_name + " could not reveal in defensive stance."
			)
			vbox.add_child(reveal_defensive_btn)
		else:
			var mode_name := "Switch to Defensive Stance" if card.creature_mode == Card.CreatureMode.AGGRESSIVE else "Switch to Aggressive Stance"
			var btn := Button.new()
			btn.text = mode_name
			btn.pressed.connect(func():
				_close_context_menu()
				game_input.submit_action({type = "change_mode", card_uid = card.uid, mode = -1})
				action_label.text = card.card_name + " changed stance."
				update_ui()
			)
			vbox.add_child(btn)

	if can_move:
		var btn := Button.new()
		btn.text = "Move"
		btn.pressed.connect(func():
			_close_context_menu()
			_pending_move_card = card
			action_label.text = card.card_name + " Ã¢â‚¬â€ click an adjacent empty zone to move"
		)
		vbox.add_child(btn)

	for entry in equip_entries:
		var equip: Card = entry["equipment"]
		var is_enemy: bool = entry["is_enemy"]
		var in_range: bool = entry["in_range"]
		var can_pick_up_this_entry := card.can_take_major_creature_action() if is_enemy else card.can_take_minor_creature_action()
		var can_break_this_entry := card.can_take_major_creature_action()
		var loc := ("zone %d" % equip.current_zone.zone_index) if equip.current_zone != null and equip.current_zone.zone_index >= 0 else "board"
		var owner_label := "Enemy" if is_enemy else "Own"
		var range_label := "" if in_range else " (out of range)"

		if not is_enemy and can_pick_up_this_entry:
			var pick_btn := Button.new()
			pick_btn.text = "Pick Up: %s [%s %s]" % [equip.card_name, owner_label, loc]
			pick_btn.pressed.connect(func():
				_close_context_menu()
				var ok := game_manager.creature_pick_up_equipment(card, equip)
				action_label.text = card.card_name + (" picks up " if ok else " failed to pick up ") + equip.card_name
				update_ui()
			)
			vbox.add_child(pick_btn)
		elif is_enemy and can_pick_up_this_entry:
			var steal_btn := Button.new()
			steal_btn.text = "Steal: %s [%s %s%s]" % [equip.card_name, owner_label, loc, range_label]
			steal_btn.pressed.connect(func():
				_close_context_menu()
				_pending_equip_actor = card
				_pending_equip_target = equip
				_pending_equip_action = "steal"
				check_for_possible_intercepts_for_equip_action()
			)
			vbox.add_child(steal_btn)

		if can_break_this_entry:
			var destroy_btn := Button.new()
			destroy_btn.text = "Destroy: %s [%s %s%s]" % [equip.card_name, owner_label, loc, range_label]
			destroy_btn.pressed.connect(func():
				_close_context_menu()
				if is_enemy:
					_pending_equip_actor = card
					_pending_equip_target = equip
					_pending_equip_action = "destroy"
					check_for_possible_intercepts_for_equip_action()
				else:
					var ok := game_manager.creature_destroy_equipment(card, equip)
					action_label.text = card.card_name + (" destroys " if ok else " failed to destroy ") + equip.card_name
					update_ui()
			)
			vbox.add_child(destroy_btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_close_context_menu)
	vbox.add_child(cancel)

	_context_menu = panel
	add_child(panel)
	_promote_transient_ui(panel)
	# Position near mouse, anchored to top-left
	var mp := get_global_mouse_position()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.global_position = mp

func _close_context_menu() -> void:
	if _context_menu and is_instance_valid(_context_menu):
		_context_menu.queue_free()
	_context_menu = null

func _on_creature_drag_started(card: Card, from_zone: Zone) -> void:
	if _is_turn_choice_pending():
		if _awaiting_creature_sacrifice or _awaiting_altar_void_payment:
			_on_board_card_pressed(card)
			return
		_reject_pre_turn_action()
		return
	if _has_pending_target_selection():
		_on_board_card_pressed(card)
		return
	if awaiting_god_ability_target and god_ability_source != null:
		_on_board_card_pressed(card)
		return
	# If a non-targeted spell is selected, treat the click as casting it
	if selected_card != null and selected_card.card_type == Card.CardType.SPELL \
			and not awaiting_spell_target:
		_on_board_card_pressed(card)
		return
	_bdrag_card = card
	_bdrag_from_zone = from_zone
	_bdrag_active = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton
		if mouse_button_event.pressed and mouse_button_event.button_index == MOUSE_BUTTON_RIGHT \
				and _has_pending_target_selection():
			_show_target_cancel_prompt()
			get_viewport().set_input_as_handled()
			return
		if mouse_button_event.pressed and mouse_button_event.button_index == MOUSE_BUTTON_LEFT \
				and _has_pending_target_selection() and _is_devour_cursor_mode_active():
			_suppress_next_devour_cancel_prompt = false
			if _devour_cancel_prompt == null or not is_instance_valid(_devour_cancel_prompt) \
					or not _devour_cancel_prompt.get_global_rect().has_point(mouse_button_event.position):
				call_deferred("_maybe_show_devour_cancel_prompt_after_invalid_click")

	if not _bdrag_active:
		return
	if event is InputEventMouseMotion:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_bdrag_cancel()
			return
		if _bdrag_ghost == null:
			_bdrag_start_ghost()
		else:
			_bdrag_ghost.global_position = get_global_mouse_position() - BoardZoneUI.get_zone_size() / 2.0
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _bdrag_ghost != null:
			_bdrag_finish(get_global_mouse_position())
		else:
			# Was a click (no movement) Ã¢â‚¬â€ treat as board card click
			if _bdrag_card != null:
				_on_board_card_pressed(_bdrag_card)
		_bdrag_cleanup()
		get_viewport().set_input_as_handled()

func _maybe_show_devour_cancel_prompt_after_invalid_click() -> void:
	if not _has_pending_target_selection() or not _is_devour_cursor_mode_active():
		return
	_show_devour_cancel_prompt()

func _is_priority_prompt_visible() -> bool:
	var panel = get_node_or_null("PriorityPromptPanel")
	return panel != null and panel.visible

func _reject_priority_locked_action(reason: String = "Only legal priority responses can be used right now.") -> bool:
	if not _is_priority_prompt_visible():
		return false
	if _has_pending_target_selection():
		return false
	action_label.text = reason
	update_ui()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE and _is_priority_prompt_visible():
			_on_priority_pass_pressed()
			get_viewport().set_input_as_handled()
			return
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_S and selected_card != null and selected_card.card_type == Card.CardType.SPELL:
			_toggle_selected_spell_prepare_mode()
			get_viewport().set_input_as_handled()
			return

	if _game_finished or not _has_pending_target_selection():
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_show_target_cancel_prompt()
		get_viewport().set_input_as_handled()
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if _is_devour_cursor_mode_active():
			_show_devour_cancel_prompt()
			get_viewport().set_input_as_handled()
			return
		_cancel_pending_target_selection(_get_pending_target_selection_name() + " cancelled: clicked off the board.")
		get_viewport().set_input_as_handled()

func _bdrag_start_ghost() -> void:
	var zone_size := BoardZoneUI.get_zone_size()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = zone_size
	panel.size = zone_size
	panel.z_index = 100
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color    = Color(0.13, 0.22, 0.42, 0.85)
	style.border_color = Color(0.4, 0.65, 1.0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	style.corner_radius_top_left = 4; style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4; style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)
	var nl := Label.new(); nl.text = _bdrag_card.card_name; nl.add_theme_font_size_override("font_size", 14); vbox.add_child(nl)
	if not _bdrag_card.is_god:
		var ml := Label.new(); ml.text = "DEF" if _bdrag_card.creature_mode == Card.CreatureMode.DEFENSIVE else "AGG"; ml.add_theme_font_size_override("font_size", 13); vbox.add_child(ml)
		var sl := Label.new(); sl.text = "STR:%d RES:%d SPD:%d" % [_bdrag_card.get_effective_strength(), _bdrag_card.get_effective_resilience(), _bdrag_card.get_effective_speed()]; sl.add_theme_font_size_override("font_size", 12); vbox.add_child(sl)
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	_bdrag_ghost = panel
	tree.current_scene.add_child(_bdrag_ghost)
	_bdrag_ghost.global_position = get_global_mouse_position() - zone_size / 2.0

func _bdrag_finish(drop_pos: Vector2) -> void:
	var card := _bdrag_card
	var from_zone := _bdrag_from_zone
	var target_zu: BoardZoneUI = null
	for zu in _board_zone_uis:
		if is_instance_valid(zu) and zu.get_global_rect().has_point(drop_pos):
			target_zu = zu; break
	if target_zu == null:
		for zu in _enemy_zone_uis:
			if is_instance_valid(zu) and zu.get_global_rect().has_point(drop_pos):
				target_zu = zu; break
	if target_zu == null and _enemy_god_zone_ui != null and is_instance_valid(_enemy_god_zone_ui):
		if _enemy_god_zone_ui.get_global_rect().has_point(drop_pos):
			target_zu = _enemy_god_zone_ui

	if target_zu == null:
		return

	var target_zone := target_zu.zone

	# Move: own empty adjacent zone
	if not target_zu._is_enemy and target_zone.cards.size() == 0:
		if not _creature_can_move(card):
			if card.is_sleeping:
				action_label.text = card.card_name + " is Sleeping and cannot move."
			elif card.creature_major_action_used:
				action_label.text = card.card_name + " has already used its major action this turn."
			elif card.creature_minor_actions_used >= 2:
				action_label.text = card.card_name + " has already used two minor actions this turn."
			else:
				action_label.text = card.card_name + " cannot move right now."
			return
		var controller := card.get_controller()
		if controller != null and target_zone in controller.get_adjacent_zones(from_zone):
			if game_input.submit_action({type = "creature_move", card_uid = card.uid,
					player_index = game_manager.players.find(target_zone.zone_owner),
					zone_type = target_zone.zone_type, zone_index = target_zone.zone_index}):
				action_label.text = card.card_name + " moved."
				update_ui()
		else:
			action_label.text = "Can only move to an adjacent or diagonal zone."
		return

	# Attack guard checks
	if not match_manager.can_attack(card):
		if card.is_sleeping:
			action_label.text = card.card_name + " is Sleeping and cannot act."
		elif card.creature_major_action_used:
			action_label.text = card.card_name + " has already used its major action this turn."
		elif card.creature_minor_actions_used >= 2:
			action_label.text = card.card_name + " has already used two minor actions this turn."
		elif card.creature_mode == Card.CreatureMode.DEFENSIVE:
			action_label.text = card.card_name + " is in defensive stance and cannot attack."
		elif from_zone.zone_type == Zone.ZoneType.RESERVE:
			action_label.text = card.card_name + " cannot attack from the back row."
		else:
			action_label.text = card.card_name + " cannot attack right now."
		return

	# Attack followers via God slot
	if target_zu._is_enemy and target_zone.zone_type == Zone.ZoneType.GOD_SLOT:
		selected_attacker = card
		_on_attack_followers_pressed()
		return

	# Attack followers via empty enemy frontline
	if target_zu._is_enemy and target_zone.cards.size() == 0 and target_zone.zone_type == Zone.ZoneType.FRONTLINE:
		selected_attacker = card
		_on_attack_followers_pressed()
		return

	# Attack creature or structure
	if target_zu._is_enemy and target_zone.cards.size() > 0:
		var target_card := target_zone.cards[0]
		if target_card.card_type == Card.CardType.CREATURE or target_card.card_type == Card.CardType.STRUCTURE:
			selected_attacker = card
			var attack_block := _get_attack_block_reason(card)
			if attack_block != "":
				action_label.text = attack_block
				return
			if not game_manager.can_cards_engage_each_other(card, target_card):
				action_label.text = _get_card_name_safe(card, "That card") + " cannot engage " + _get_card_name_safe(target_card, "that target") + "."
				return
			pending_attack_target = target_card
			action_label.text = _get_attack_card_label(card, "A creature") + " attacking " + _get_card_name_safe(target_card, "an enemy card") + "..."
			check_for_possible_intercepts()
			return

	action_label.text = "Invalid drop target."

func _bdrag_cancel() -> void:
	_bdrag_cleanup()

func _bdrag_cleanup() -> void:
	_bdrag_active = false
	_bdrag_card = null
	_bdrag_from_zone = null
	if _bdrag_ghost and is_instance_valid(_bdrag_ghost):
		_bdrag_ghost.queue_free()
	_bdrag_ghost = null

func _get_attack_block_reason(attacker: Card) -> String:
	if attacker == null or not attacker is Card:
		return "Invalid attacker selected."
	if game_manager.turn_number == 0:
		return "Cannot attack on the first turn!"
	if not attacker.can_take_major_creature_action():
		return _get_card_name_safe(attacker, "That creature") + " has already acted this turn."
	if game_manager.attack_restrictions.has(attacker.get_controller()):
		return "Cannot attack! Restricted for " + str(game_manager.attack_restrictions[attacker.get_controller()].turns) + " more turns."
	return ""

func _on_attack_followers_pressed() -> void:
	if selected_attacker:
		var block := _get_attack_block_reason(selected_attacker)
		if block != "":
			action_label.text = block
			return
		pending_attack_target = game_manager.other_player
		check_for_possible_intercepts()
	else:
		action_label.text = "Select your creature first to attack"

func _creature_can_use_equipment_action(card: Card) -> bool:
	return (
		card.card_type == Card.CardType.CREATURE
		and (card.can_take_major_creature_action() or card.can_take_minor_creature_action())
		and not card.is_sleeping
		and game_manager.turn_number > 0
		and card.get_controller() == game_manager.current_player
		and card.current_zone != null
		and card.current_zone.is_board_zone()
	)

# Returns array of {equipment, is_enemy, in_range} for all equipment the creature can interact with
func _get_reachable_equipment(creature: Card) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var controller := creature.get_controller()
	if controller == null:
		return result
	var reachable := game_manager.get_reachable_board_zones(creature)
	var seen: Array[Card] = []

	# Own + in-range enemy equipment
	for zone in reachable:
		for equip in zone.get_equipment():
			if equip in seen:
				continue
			seen.append(equip)
			result.append({
				"equipment": equip,
				"is_enemy": zone.zone_owner != controller,
				"in_range": true
			})

	# Out-of-range enemy equipment (frontline creature only)
	if creature.current_zone.zone_type == Zone.ZoneType.FRONTLINE:
		var opponent := game_manager.get_opponent(controller)
		if opponent != null:
			for zone in opponent.frontline_zones + opponent.reserve_zones:
				for equip in zone.get_equipment():
					if equip in seen:
						continue
					seen.append(equip)
					result.append({
						"equipment": equip,
						"is_enemy": true,
						"in_range": false
					})
	return result

func _creature_can_move(card: Card) -> bool:
	return (
		card.card_type == Card.CardType.CREATURE
		and card.can_take_minor_creature_action()
		and not card.summoned_this_turn
		and not card.is_sleeping
	)

func _creature_can_change_stance(card: Card) -> bool:
	return (
		card.card_type == Card.CardType.CREATURE
		and card.can_take_minor_creature_action()
		and not card.summoned_this_turn
		and not card.is_sleeping
	)

func _get_intercept_target_row_depth(protected_target) -> int:
	if protected_target is Player:
		return 2
	if not (protected_target is Card):
		return -1
	var target_card := protected_target as Card
	if target_card.card_type == Card.CardType.EQUIPMENT and target_card.equipped_on != null:
		return _get_intercept_target_row_depth(target_card.equipped_on)
	if target_card.current_zone == null:
		return -1
	match target_card.current_zone.zone_type:
		Zone.ZoneType.FRONTLINE:
			return 0
		Zone.ZoneType.RESERVE:
			return 1
		Zone.ZoneType.GOD_SLOT:
			return 2
		_:
			return -1

func _get_interceptor_row_depth(defender: Card) -> int:
	if defender == null or defender.current_zone == null:
		return -1
	match defender.current_zone.zone_type:
		Zone.ZoneType.FRONTLINE:
			return 0
		Zone.ZoneType.RESERVE:
			return 1
		_:
			return -1

func _get_intercept_row_distance(defender: Card, protected_target) -> int:
	var defender_depth := _get_interceptor_row_depth(defender)
	var target_depth := _get_intercept_target_row_depth(protected_target)
	if defender_depth < 0 or target_depth < 0 or target_depth < defender_depth:
		return -1
	return target_depth - defender_depth

func _get_minimum_intercept_row_distance(defender: Card) -> int:
	var minimum_depth := 1
	if defender.creature_mode == Card.CreatureMode.AGGRESSIVE:
		minimum_depth = 2
	minimum_depth = max(0, minimum_depth - defender.get_intercept_reach_bonus())
	return minimum_depth

func _get_declared_attack_partner(attacker: Card) -> Card:
	if attacker == null or not attacker.has_method("get_united_front_partner_for_attack"):
		return null
	return attacker.get_united_front_partner_for_attack(game_manager)

func _get_declared_attack_speed(attacker: Card) -> int:
	if attacker == null:
		return 0
	if attacker.has_method("get_united_front_attack_speed"):
		return attacker.get_united_front_attack_speed(game_manager)
	return attacker.get_effective_speed()

func can_intercept(defender: Card, attacker: Card, protected_target) -> bool:
	if attacker == null:
		return false
	if protected_target == null:
		return false
	if protected_target is Card and defender == protected_target:
		return false
	if defender.card_type != Card.CardType.CREATURE:
		return false
	if defender.is_sleeping:
		return false
	if defender.get_effective_speed() < _get_declared_attack_speed(attacker):
		return false
	if not game_manager.can_interceptor_engage_attacker(defender, attacker):
		return false
	# Aggressive-stance creatures can intercept once per turn at equal or greater speed
	if defender.creature_mode == Card.CreatureMode.AGGRESSIVE and defender.can_take_major_creature_action():
		return _get_intercept_row_distance(defender, protected_target) >= _get_minimum_intercept_row_distance(defender)
	if defender.creature_mode == Card.CreatureMode.DEFENSIVE:
		return _get_intercept_row_distance(defender, protected_target) >= _get_minimum_intercept_row_distance(defender)
	return false

func check_for_possible_intercepts() -> void:
	var possible_interceptors: Array[Card] = []

	var defender: Player = pending_attack_target if pending_attack_target is Player else pending_attack_target.get_controller()

	for zone in defender.frontline_zones + defender.reserve_zones:
		for card in zone.cards:
			if can_intercept(card, selected_attacker, pending_attack_target):
				possible_interceptors.append(card)

	# In a networked game the defending player may be the remote client.
	# Send them the intercept decision instead of showing server-side UI.
	var defender_idx := game_manager.players.find(defender)
	var defender_peer_id := -1
	if network_manager != null and defender_idx >= 0:
		defender_peer_id = int(network_manager.player_peer_ids.get(defender_idx, -1))
	var is_remote_defender: bool = network_manager != null \
		and network_manager.get("is_server") == true \
		and defender_peer_id > 1

	if is_remote_defender:
		if possible_interceptors.size() > 0:
			_broadcast_intercept_offered(possible_interceptors)
		else:
			action_label.text = _get_attack_card_label(selected_attacker, "A creature") + " attacking directly - no possible interceptors."
			resolve_pending_attack()
		return

	if possible_interceptors.size() > 0:
		var names = []
		for card in possible_interceptors:
			names.append(card.card_name)
		action_label.text = _get_attack_card_label(selected_attacker, "A creature") + " is attacking. Possible interceptors: " + ", ".join(names) + " - Click one to intercept or click 'No Intercept'"
		show_no_intercept_button()
	else:
		action_label.text = _get_attack_card_label(selected_attacker, "A creature") + " attacking directly - no possible interceptors."
		resolve_pending_attack()

func _broadcast_intercept_offered(possible_interceptors: Array[Card]) -> void:
	if network_manager == null or selected_attacker == null:
		return
	var interceptor_uids: Array = []
	for card in possible_interceptors:
		interceptor_uids.append(card.uid)
	var target_uid := ""
	var target_is_player := false
	if pending_attack_target is Card:
		target_uid = (pending_attack_target as Card).uid
	elif pending_attack_target is Player:
		target_is_player = true
		target_uid = str(game_manager.players.find(pending_attack_target as Player))
	var defender: Player = pending_attack_target if pending_attack_target is Player else (pending_attack_target as Card).get_controller()
	var defender_idx := game_manager.players.find(defender)
	var attacker_label := _get_attack_card_label(selected_attacker, "A creature")
	var event_data := {
		attacker_uid = selected_attacker.uid,
		target_uid = target_uid,
		target_is_player = target_is_player,
		interceptor_uids = interceptor_uids,
		action_message = attacker_label + " is attacking — intercept or allow?",
	}
	var peer_id: int = network_manager.player_peer_ids.get(defender_idx, -1)
	if peer_id == 1:
		network_manager.game_event_received.emit("intercept_offered", event_data)
	elif peer_id > 0:
		network_manager.broadcast_event_to_peer(peer_id, "intercept_offered", event_data)

func show_no_intercept_button() -> void:
	_remove_no_intercept_button()
	_no_intercept_btn = Button.new()
	_no_intercept_btn.text = "No Intercept - Allow Attack"
	_no_intercept_btn.pressed.connect(_on_no_intercept_pressed)
	enemy_board_container.add_child(_no_intercept_btn)

func _remove_no_intercept_button() -> void:
	if _no_intercept_btn and is_instance_valid(_no_intercept_btn):
		_no_intercept_btn.queue_free()
	_no_intercept_btn = null

func _on_no_intercept_pressed() -> void:
	selected_interceptor = null
	action_label.text = "No intercept - " + _get_attack_card_label(selected_attacker, "the attacker") + " attacks directly!"
	resolve_pending_attack()

func resolve_pending_attack() -> void:
	_remove_no_intercept_button()
	if selected_attacker == null:
		action_label.text = "No attacker is selected."
		update_ui()
		return

	var united_front_partner := _get_declared_attack_partner(selected_attacker)
	var declared_defender: Card = selected_interceptor if selected_interceptor != null else (pending_attack_target if pending_attack_target is Card else null)
	selected_attacker.reveal(game_manager)
	if united_front_partner != null:
		united_front_partner.reveal(game_manager)
	if declared_defender != null:
		declared_defender.reveal(game_manager)

	# Build and push the attack action onto the stack, then offer priority to opponent
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.source_player = game_manager.current_player
	action.attacker = selected_attacker
	action.united_front_partner = united_front_partner
	action.attack_speed_override = _get_declared_attack_speed(selected_attacker)
	action.interceptor = selected_interceptor
	action.target = pending_attack_target
	game_manager.push_to_stack(action)

	selected_attacker = null
	selected_interceptor = null
	pending_attack_target = null

	var declared_target_name := "followers"
	if action.interceptor != null:
		declared_target_name = _get_card_name_safe(action.interceptor, "an interceptor")
	elif action.target is Card:
		declared_target_name = _get_card_name_safe(action.target, "an enemy card")
	elif action.target is Player:
		declared_target_name = (action.target as Player).player_name + "'s followers"
	action_label.text = _get_attack_card_label(action.attacker, "A creature") + " declares an attack on " + declared_target_name + "!"
	_offer_priority()

func check_for_possible_intercepts_for_equip_action() -> void:
	var defender := game_manager.get_opponent(game_manager.current_player)
	var possible: Array[Card] = []
	for zone in defender.frontline_zones + defender.reserve_zones:
		for card in zone.cards:
			if can_intercept(card, _pending_equip_actor, _pending_equip_target):
				possible.append(card)
	if possible.size() > 0:
		var names: Array[String] = []
		for card in possible:
			names.append(card.card_name)
		action_label.text = "Intercept " + _pending_equip_actor.card_name + "'s " + _pending_equip_action + "? Possible interceptors: " + ", ".join(names) + " — click one or 'No Intercept'"
		_show_no_intercept_equip_button()
	else:
		resolve_pending_equip_action(null)

func _show_no_intercept_equip_button() -> void:
	_remove_no_intercept_button()
	_no_intercept_btn = Button.new()
	_no_intercept_btn.text = "No Intercept — Allow " + _pending_equip_action.capitalize()
	_no_intercept_btn.pressed.connect(func(): resolve_pending_equip_action(null))
	enemy_board_container.add_child(_no_intercept_btn)

func resolve_pending_equip_action(interceptor: Card) -> void:
	_remove_no_intercept_button()
	var actor := _pending_equip_actor
	var target := _pending_equip_target
	var action := _pending_equip_action
	_pending_equip_actor = null
	_pending_equip_target = null
	_pending_equip_action = ""
	if interceptor != null:
		interceptor.spend_major_creature_action()
		action_label.text = _get_card_name_safe(interceptor) + " intercepts!"
		game_manager.resolve_combat_with_continuation(actor, interceptor, func() -> void:
			update_ui()
		)
		return
	if action == "steal":
		var ok := game_manager.creature_pick_up_equipment(actor, target)
		action_label.text = _get_card_name_safe(actor) + (" steals " if ok else " failed to steal ") + _get_card_name_safe(target)
	elif action == "destroy":
		var ok := game_manager.creature_destroy_equipment(actor, target)
		action_label.text = _get_card_name_safe(actor) + (" destroys " if ok else " failed to destroy ") + _get_card_name_safe(target)
	update_ui()

func _offer_priority() -> void:
	var player := game_manager.priority_player
	var responses := game_manager.get_priority_responses(player)
	update_ui()

	var is_remote_priority: bool = network_manager != null \
		and network_manager.get("is_server") == true \
		and not game_manager.players.is_empty() \
		and player != game_manager.players[0]

	if responses.is_empty():
		_hide_priority_prompt()
		game_manager.pass_priority()
		if game_manager.both_passed():
			update_ui()
			await get_tree().create_timer(STACK_LINGER_SECONDS).timeout
			if game_manager.action_stack.is_empty():
				update_ui()
				return
			_execute_top_of_stack()
		else:
			_offer_priority()
		return

	if is_remote_priority:
		# The remote player has valid responses — ask them over the network.
		# The priority loop pauses here; it resumes when their command arrives.
		_broadcast_priority_offered(player, responses)
		return

	_show_priority_prompt(player)

func _broadcast_priority_offered(player: Player, responses: Array) -> void:
	if network_manager == null or game_manager.action_stack.is_empty():
		return
	var top: CardAction = game_manager.action_stack.back()
	var response_options: Array = []
	for card in responses:
		if card is HexCard:
			var hex := card as HexCard
			var targets := game_manager.get_priority_hex_targets(hex, top)
			var target_is_attacker := not hex.has_method("get_priority_targets") \
				and top.type == CardAction.Type.ATTACK
			var target_uids: Array = []
			for t in targets:
				target_uids.append(t.uid)
			response_options.append({
				response_type = "hex",
				card_uid = hex.uid,
				target_uids = target_uids,
				target_is_attacker = target_is_attacker,
			})
		elif card is CharmCard:
			var charm := card as CharmCard
			var targets := charm.get_valid_targets(game_manager)
			var target_uids: Array = []
			for t in targets:
				target_uids.append(t.uid)
			var from_hand := charm.current_zone == charm.card_owner.hand_zone
			response_options.append({
				response_type = "charm",
				card_uid = charm.uid,
				target_uids = target_uids,
				from_hand = from_hand,
			})

	var action_msg := ""
	if top.type == CardAction.Type.ATTACK and top.attacker != null:
		action_msg = top.attacker.card_name + " is attacking — you may respond!"

	var event_data := {responses = response_options, action_message = action_msg}
	var remote_player_idx := game_manager.players.find(player)
	var peer_id: int = network_manager.player_peer_ids.get(remote_player_idx, -1)
	if peer_id == 1:
		network_manager.game_event_received.emit("priority_offered", event_data)
	elif peer_id > 0:
		network_manager.broadcast_event_to_peer(peer_id, "priority_offered", event_data)

func _show_priority_prompt(player: Player) -> void:
	var panel = get_node_or_null("PriorityPromptPanel")
	if panel == null:
		panel = PanelContainer.new()
		panel.name = "PriorityPromptPanel"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
		style.border_color = Color(0.4, 0.7, 1.0)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			style.set_border_width(side, 2)
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size.x = 220
		add_child(panel)
		_promote_transient_ui(panel)
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.anchor_top = 0.5
		panel.anchor_bottom = 0.5
		panel.offset_left = -230
		panel.offset_right = -10
		panel.offset_top = -60

	# Clear and rebuild contents
	for child in panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = player.player_name + " has priority"
	lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl)

	var pass_btn := Button.new()
	pass_btn.text = "Pass Priority"
	pass_btn.pressed.connect(_on_priority_pass_pressed)
	vbox.add_child(pass_btn)

	_promote_transient_ui(panel)
	panel.show()

func _hide_priority_prompt() -> void:
	var panel = get_node_or_null("PriorityPromptPanel")
	if panel:
		panel.hide()

func _on_priority_pass_pressed() -> void:
	_hide_priority_prompt()
	if _is_networked_client:
		network_manager.request_action({type = "priority_pass"})
		return
	game_manager.pass_priority()
	if game_manager.both_passed():
		_execute_top_of_stack()
	else:
		_offer_priority()

func _on_priority_response_chosen(card: Card) -> void:
	_hide_priority_prompt()

	if card is HexCard:
		var top: CardAction = game_manager.action_stack.back()
		var hex := card as HexCard
		var has_manual_targets := hex.has_method("get_priority_targets") or top.type == CardAction.Type.ATTACK
		var hex_targets: Array = game_manager.get_priority_hex_targets(hex, top) if has_manual_targets else []
		var target_is_attacker := not hex.has_method("get_priority_targets") and top.type == CardAction.Type.ATTACK
		if hex is PermanentHexCard and hex.targets and has_manual_targets:
			_begin_priority_hex_target_selection(hex, top, target_is_attacker)
			return
		game_manager.prepared_hexes.erase(card)
		card.is_prepared = false
		card.reveal(game_manager)
		if hex.targets and hex_targets.size() > 1:
			_show_card_selection_overlay(
				"Choose a target for " + hex.card_name,
				hex_targets,
				func(chosen_card: Card) -> void:
					_queue_hex_response_action(hex, top, chosen_card, target_is_attacker)
			)
			return
		if has_manual_targets and hex.targets and hex_targets.is_empty():
			action_label.text = hex.card_name + " has no valid targets."
			update_ui()
			return
		var chosen_target: Card = hex_targets[0] if not hex_targets.is_empty() else null
		_queue_hex_response_action(hex, top, chosen_target, target_is_attacker)
	elif card is CharmCard:
		var charm := card as CharmCard
		if charm.targets:
			_prompt_charm_target_selection(charm, game_manager.action_stack.back())
		else:
			_queue_charm_action(charm, game_manager.action_stack.back())
	elif card is E2Abzu:
		var structure := card as E2Abzu
		var top: CardAction = game_manager.action_stack.back() as CardAction
		var targets: Array[Card] = structure.get_priority_field_targets(game_manager, top)
		if targets.is_empty():
			action_label.text = structure.card_name + " has no valid fast targets."
			update_ui()
			return
		var on_choose_fast_void_target := func(chosen_card: Card) -> void:
			var on_fast_void_activate := func() -> void:
				structure.activate(game_manager, chosen_card)
			_queue_targeted_ability_action(
				structure,
				chosen_card,
				on_fast_void_activate,
				structure.card_name + " fast-voids " + _get_target_label(chosen_card, game_manager.get_feedback_viewer(), chosen_card.card_name) + "."
			)
		_show_card_selection_overlay(
			"Choose a friendly Mer Mage to Void with " + structure.card_name,
			targets,
			on_choose_fast_void_target
		)
	elif card is SpellCard:
		selected_card = card
		for vc in _hand_visual_cards:
			vc.set_highlighted(vc.card_data == card)
		if card is BitMeseri:
			action_label.text = "BitMeseri - click a creature or structure to void it."
			update_ui()
		elif card is Absence:
			_prompt_absence_target_selection()
		elif card is ApollyonsDemiurge or card.card_name == "Apollyon's Demiurge":
			_show_demiurge_prompt(card)
		elif card is BookOfLife:
			_show_book_of_life_prompt(card as BookOfLife)
		elif card is DeucalionsInfants:
			_queue_deucalion_resolution(card as DeucalionsInfants)
		elif card != null and (card is BlotSacrifice or card.card_name == "Blot Sacrifice"):
			_show_blot_sacrifice_prompt(card)
		elif card is CircleOfRebirth:
			if _is_networked_client:
				var spell_uid: String = card.get("uid") if "uid" in card else ""
				game_input.submit_action({type = "cast_spell", spell_uid = spell_uid})
			else:
				var resurrect_count := get_resurrectible_cards().size()
				var spell := card
				_queue_hand_spell_cast(
					spell,
					null,
					("Circle of Rebirth resurrected %d creature(s)!" % resurrect_count) if resurrect_count > 0 else "Cast Circle of Rebirth but no creatures to resurrect!",
					func() -> void:
						(spell as SpellCard).resolve(game_manager, null)
				)
		else:
			if _is_networked_client:
				var spell_uid: String = card.get("uid") if "uid" in card else ""
				game_input.submit_action({type = "cast_spell", spell_uid = spell_uid})
			else:
				var spell := card
				_queue_hand_spell_cast(
					spell,
					null,
					"Cast " + spell.card_name + "!",
					func() -> void:
						(spell as SpellCard).resolve(game_manager, null)
				)

func _finish_post_execute(source_player: Player) -> void:
	game_manager.current_phase = GameManager.GamePhase.MAIN
	# Auto-fizzle any ATTACK on the stack whose attacker is no longer on the board
	while not game_manager.action_stack.is_empty():
		var next: CardAction = game_manager.action_stack.back()
		if next.type == CardAction.Type.ATTACK and not _is_attacker_on_board(next.attacker, next.source_player):
			game_manager.action_stack.pop_back()
			action_label.text = _get_card_name_safe(next.attacker, "An attacker") + "'s attack was cancelled!"
		else:
			break

	if _maybe_prompt_aphrodite_after_combat():
		update_ui()
		return

	if not game_manager.action_stack.is_empty():
		game_manager.consecutive_passes = 0
		game_manager.priority_player = game_manager.get_opponent(source_player)
		_offer_priority()
	elif not _queued_attackers.is_empty():
		_advance_attack_queue.call_deferred()
	else:
		update_ui()

func _maybe_prompt_aphrodite_after_combat() -> bool:
	if awaiting_god_ability_target:
		return false
	if get_node_or_null("AphroditePromptPanel") != null:
		return false
	if game_manager == null or game_manager.current_player == null:
		return false
	var god_zone := game_manager.current_player.god_zone
	if god_zone == null or god_zone.cards.is_empty():
		return false
	var god := god_zone.cards[0]
	if not (god is AphroditeAreia and (god as AphroditeAreia).can_activate(game_manager)):
		return false
	if network_manager != null and network_manager.is_server:
		# Route through request_ui_interaction so GameEventBroadcaster sends it to the right client
		var player_idx := game_manager.players.find(game_manager.current_player)
		match_manager.request_ui_interaction.emit(player_idx, "aphrodite_enslave", {"source_uid": god.uid})
		return true
	# Local game: show prompt directly
	_show_aphrodite_prompt(god as AphroditeAreia)
	action_label.text = god.card_name + " can enslave a creature."
	return true

func _get_retreat_opponent(ask_card: Askelladen, attacker: Card, defender: Card) -> Card:
	return defender if ask_card == attacker else attacker

func _is_askelladen_retreat_candidate(ask_card: Askelladen, other_card: Card) -> bool:
	return ask_card != null \
		and other_card != null \
		and not ask_card.is_face_down \
		and not ask_card.abilities_suppressed() \
		and not game_manager.is_immune_to_source(other_card, ask_card) \
		and other_card.get_effective_speed() <= ask_card.get_effective_speed()

func _can_askelladen_retreat(ask_card: Askelladen, other_card: Card) -> bool:
	return _is_askelladen_retreat_candidate(ask_card, other_card) \
		and not game_manager.is_guardian_protected(other_card, ask_card)

func _is_askelladen_retreat_guardian_blocked(ask_card: Askelladen, other_card: Card) -> bool:
	return _is_askelladen_retreat_candidate(ask_card, other_card) \
		and game_manager.is_guardian_protected(other_card, ask_card)

func _get_ordered_retreat_candidates(attacker: Card, defender: Card, turn_player: Player) -> Array[Askelladen]:
	var ordered: Array[Askelladen] = []
	var attacker_ask: Askelladen = null
	var defender_ask: Askelladen = null
	if attacker is Askelladen:
		attacker_ask = attacker as Askelladen
	if defender is Askelladen:
		defender_ask = defender as Askelladen

	if attacker_ask != null and attacker_ask.get_controller() == turn_player:
		ordered.append(attacker_ask)
	if defender_ask != null and defender_ask.get_controller() == turn_player and not ordered.has(defender_ask):
		ordered.append(defender_ask)
	if attacker_ask != null and not ordered.has(attacker_ask):
		ordered.append(attacker_ask)
	if defender_ask != null and not ordered.has(defender_ask):
		ordered.append(defender_ask)
	return ordered

func _get_retreating_askelladens(attacker: Card, defender: Card, turn_player: Player) -> Array[Askelladen]:
	var prompts: Array[Askelladen] = []
	for ask_card in _get_ordered_retreat_candidates(attacker, defender, turn_player):
		var other_card: Card = _get_retreat_opponent(ask_card, attacker, defender)
		if _can_askelladen_retreat(ask_card, other_card):
			prompts.append(ask_card)
	return prompts

func _get_guardian_blocked_retreats(attacker: Card, defender: Card, turn_player: Player) -> Array[Askelladen]:
	var blocked: Array[Askelladen] = []
	for ask_card in _get_ordered_retreat_candidates(attacker, defender, turn_player):
		var other_card: Card = _get_retreat_opponent(ask_card, attacker, defender)
		if _is_askelladen_retreat_guardian_blocked(ask_card, other_card):
			blocked.append(ask_card)
	return blocked

func _clear_pending_retreat_state() -> void:
	_hide_retreat_prompt()
	_pending_retreat_action = null
	_pending_retreat_target = null
	_pending_retreat_prompts.clear()
	_pending_retreat_guardian_blocked.clear()

func _send_to_deck_bottom(card: Card) -> void:
	game_manager.send_to_deck_bottom_with_hook(card)
	card.reset_creature_action_state()
	card.wake_up()

func _show_retreat_prompt(ask_card: Askelladen) -> void:
	_hide_retreat_prompt()
	var panel := PanelContainer.new()
	panel.name = "RetreatPromptPanel"
	_retreat_prompt_panel = panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.08, 0.97)
	style.border_color = Color(0.4, 0.9, 0.4)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = 240

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var lbl := Label.new()
	var ask_controller := ask_card.get_controller()
	if ask_controller == null:
		ask_controller = ask_card.card_owner
	var ask_owner_prefix := ""
	if ask_controller != null and ask_controller.player_name != "":
		ask_owner_prefix = ask_controller.player_name + "'s "
	lbl.text = ask_owner_prefix + "Askelladen may use Tactful Retreat.\nReturn both creatures to the bottom of their decks?"
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl)

	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)

	var yes_btn := Button.new()
	yes_btn.text = "Retreat"
	yes_btn.pressed.connect(_on_retreat_yes)
	hbox.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Fight"
	no_btn.pressed.connect(_on_retreat_no)
	hbox.add_child(no_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -120
	panel.offset_right = 120
	panel.offset_top = -40
	panel.offset_bottom = 40

func _hide_retreat_prompt() -> void:
	if _retreat_prompt_panel != null and is_instance_valid(_retreat_prompt_panel):
		_retreat_prompt_panel.visible = false
		if _retreat_prompt_panel.get_parent() != null:
			_retreat_prompt_panel.get_parent().remove_child(_retreat_prompt_panel)
		_retreat_prompt_panel.queue_free()
	_retreat_prompt_panel = null
	for child in get_children():
		if child != null and child.name == "RetreatPromptPanel":
			child.visible = false
			if child.get_parent() != null:
				child.get_parent().remove_child(child)
			child.queue_free()

func _get_active_altar_of_dreams(player: Player) -> AltarOfDreams:
	for zone in player.power_zones:
		if zone.cards.is_empty():
			continue
		var power := zone.cards[0] as AltarOfDreams
		if power != null and not power.is_face_down:
			return power
	return null

func _show_sacrifice_payment_prompt(card: Card, altar: AltarOfDreams) -> void:
	_hide_sacrifice_payment_prompt()
	_altar_pending_power = altar

	var panel := PanelContainer.new()
	panel.name = "SacrificePaymentPromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.14, 0.97)
	style.border_color = Color(0.72, 0.62, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(300, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Choose Sacrifice Payment"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "%s can use Altar of Dreams instead of sacrifice." % card.card_name
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var sacrifice_btn := Button.new()
	sacrifice_btn.text = "Sacrifice Creatures"
	sacrifice_btn.pressed.connect(_begin_normal_creature_sacrifice_selection)
	vbox.add_child(sacrifice_btn)

	var altar_btn := Button.new()
	altar_btn.text = "Void Sleeping Creatures"
	altar_btn.pressed.connect(_begin_altar_void_selection)
	vbox.add_child(altar_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -150
	panel.offset_right = 150
	panel.offset_top = -70
	panel.offset_bottom = 70

func _hide_sacrifice_payment_prompt() -> void:
	var panel := get_node_or_null("SacrificePaymentPromptPanel")
	if panel:
		panel.queue_free()

func _get_active_advanced_building_techniques(player: Player) -> AdvancedBuildingTechniques:
	for zone in player.power_zones:
		if zone.cards.is_empty():
			continue
		var power := zone.cards[0] as AdvancedBuildingTechniques
		if power != null and not power.is_face_down:
			return power
	return null

func _show_structure_bonus_prompt(power: AdvancedBuildingTechniques, structure: Card) -> void:
	_hide_structure_bonus_prompt()
	_pending_structure_bonus_power = power
	_pending_structure_bonus_structure = structure

	var panel := PanelContainer.new()
	panel.name = "StructureBonusPromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.97)
	style.border_color = Color(0.55, 0.78, 1.0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(280, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Advanced Building Techniques"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Spend mana to increase %s's Res by 6 per mana." % structure.card_name
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var max_mana := power.get_max_structure_bonus_mana(structure, game_manager)
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = max_mana
	spin.step = 1
	spin.value = 0
	spin.allow_greater = false
	spin.allow_lesser = false
	vbox.add_child(spin)

	var hint := Label.new()
	hint.text = "Available mana: %d" % max_mana
	hint.modulate = Color(0.75, 0.82, 0.95)
	vbox.add_child(hint)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	var confirm_btn := Button.new()
	confirm_btn.text = "Apply"
	confirm_btn.pressed.connect(_on_structure_bonus_confirm_pressed.bind(spin))
	buttons.add_child(confirm_btn)

	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.pressed.connect(_on_structure_bonus_skip_pressed)
	buttons.add_child(skip_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -140
	panel.offset_right = 140
	panel.offset_top = -70
	panel.offset_bottom = 70

func _hide_structure_bonus_prompt() -> void:
	var panel := get_node_or_null("StructureBonusPromptPanel")
	if panel:
		panel.queue_free()
	_pending_structure_bonus_power = null
	_pending_structure_bonus_structure = null

func _show_demiurge_prompt(spell) -> void:
	_hide_demiurge_prompt()
	_pending_demiurge_spell = spell

	var max_x: int = spell.get_max_x_value()
	if max_x <= 0:
		action_label.text = "Apollyon's Demiurge needs mana and enough cards in deck."
		return

	var panel := PanelContainer.new()
	panel.name = "DemiurgePromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.08, 0.97)
	style.border_color = Color(0.86, 0.58, 0.42)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(300, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Apollyon's Demiurge"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Choose X mana to spend and cards to mill."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = max_x
	spin.step = 1
	spin.value = 1
	spin.allow_greater = false
	spin.allow_lesser = false
	vbox.add_child(spin)

	var hint := Label.new()
	hint.text = "Available X: %d" % max_x
	hint.modulate = Color(0.95, 0.82, 0.74)
	vbox.add_child(hint)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	var confirm_btn := Button.new()
	confirm_btn.text = "Cast"
	confirm_btn.pressed.connect(_on_demiurge_confirm_pressed.bind(spin))
	buttons.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_demiurge_cancel_pressed)
	buttons.add_child(cancel_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -150
	panel.offset_right = 150
	panel.offset_top = -70
	panel.offset_bottom = 70

func _show_aphrodite_prompt(god: AphroditeAreia) -> void:
	_hide_aphrodite_prompt()

	var panel := PanelContainer.new()
	panel.name = "AphroditePromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.08, 0.12, 0.97)
	style.border_color = Color(0.92, 0.58, 0.7)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(320, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = god.card_name
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Use Violent Delights? Choose an enemy creature to enslave, or decline."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	var activate_btn := Button.new()
	activate_btn.text = "Choose Target"
	activate_btn.pressed.connect(_on_aphrodite_confirm_pressed.bind(god))
	buttons.add_child(activate_btn)

	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.pressed.connect(_on_aphrodite_decline_pressed)
	buttons.add_child(decline_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -160
	panel.offset_right = 160
	panel.offset_top = -60
	panel.offset_bottom = 60

func _show_absence_mode_prompt(spell: Absence, target: Card) -> void:
	_hide_absence_mode_prompt()
	_pending_absence_spell = spell
	_pending_absence_target = target

	var panel := PanelContainer.new()
	panel.name = "AbsenceModePromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 0.97)
	style.border_color = Color(0.82, 0.82, 0.92)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(340, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Absence"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Choose how to affect " + _get_target_label(target, game_manager.get_feedback_viewer(), "target") + "."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	if target is PowerCard:
		var relock_btn := Button.new()
		relock_btn.text = "Flip Down"
		relock_btn.pressed.connect(_on_absence_relock_pressed)
		buttons.add_child(relock_btn)

	var mute_btn := Button.new()
	mute_btn.text = "Mute"
	mute_btn.pressed.connect(_on_absence_mute_pressed)
	buttons.add_child(mute_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_absence_cancel_pressed)
	buttons.add_child(cancel_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -170
	panel.offset_right = 170
	panel.offset_top = -60
	panel.offset_bottom = 60

func _show_blessed_knights_prompt(card: BlessedKnights) -> void:
	_hide_blessed_knights_prompt()
	_pending_blessed_knights = card

	var panel := PanelContainer.new()
	panel.name = "BlessedKnightsPromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.16, 0.97)
	style.border_color = Color(0.55, 0.82, 0.98)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(420, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = card.card_name
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Choose what Blessed Ward protects against this turn."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	for ward_kind in card.get_blessed_ward_options():
		var btn := Button.new()
		btn.text = card.get_blessed_ward_label(ward_kind)
		btn.pressed.connect(_resolve_blessed_knights_impact.bind(ward_kind))
		buttons.add_child(btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -60
	panel.offset_bottom = 60

func _show_byggvir_reveal_prompt(card: Byggvir) -> void:
	_hide_byggvir_reveal_prompt()
	if card == null or game_manager == null or game_manager.current_player == null:
		return
	if not card.consume_brewing_reveal_pending():
		return
	var options: Array[Dictionary] = card.get_brewing_options(game_manager)
	if options.is_empty():
		action_label.text = card.card_name + " has no Brewing options on reveal."
		update_ui()
		return
	if options.size() == 1:
		action_label.text = card.resolve_brewing_option(game_manager, options[0])
		update_ui()
		return

	_pending_byggvir = card
	_pending_byggvir_options = options

	var panel := PanelContainer.new()
	panel.name = "ByggvirPromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.10, 0.06, 0.97)
	style.border_color = Color(0.89, 0.72, 0.42)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(460, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = card.card_name
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Choose a Brewing effect to resolve on reveal."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	for option in options:
		var btn := Button.new()
		btn.text = card.get_brewing_option_label(option)
		btn.pressed.connect(_resolve_byggvir_reveal_option.bind(option))
		vbox.add_child(btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -100
	panel.offset_bottom = 100

func _hide_byggvir_reveal_prompt() -> void:
	var panel := get_node_or_null("ByggvirPromptPanel")
	if panel:
		panel.queue_free()
	_pending_byggvir = null
	_pending_byggvir_options.clear()

func _resolve_byggvir_reveal_option(option: Dictionary) -> void:
	var card := _pending_byggvir
	_hide_byggvir_reveal_prompt()
	if card == null:
		update_ui()
		return
	action_label.text = card.resolve_brewing_option(game_manager, option)
	update_ui()

func _handle_post_reveal_prompt(card: Card, was_stealth: bool) -> void:
	if not was_stealth or card == null:
		return
	if card is Byggvir and (card as Byggvir).has_pending_brewing_reveal():
		_show_byggvir_reveal_prompt(card as Byggvir)

func _show_erlqueens_nightingale_prompt(card: ErlqueensNightingaleScript) -> void:
	_hide_erlqueens_nightingale_prompt()
	if game_manager == null or card == null:
		return
	if not card.can_activate(game_manager):
		update_ui()
		return

	_pending_erlqueens_nightingale = card

	var panel := PanelContainer.new()
	panel.name = "ErlqueensNightingalePromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.11, 0.07, 0.97)
	style.border_color = Color(0.72, 0.92, 0.62, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(430, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = card.card_name
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Shift this card, then choose whether it returns to your hand."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var shift_only_btn := Button.new()
	shift_only_btn.text = "Shift Only"
	shift_only_btn.pressed.connect(func() -> void:
		_resolve_erlqueens_nightingale_shift(false)
	)
	vbox.add_child(shift_only_btn)

	var shift_return_btn := Button.new()
	shift_return_btn.text = "Shift and Return to Hand"
	shift_return_btn.disabled = not card.can_return_to_hand_after_shift()
	shift_return_btn.pressed.connect(func() -> void:
		_resolve_erlqueens_nightingale_shift(true)
	)
	vbox.add_child(shift_return_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_hide_erlqueens_nightingale_prompt)
	vbox.add_child(cancel_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -215
	panel.offset_right = 215
	panel.offset_top = -90
	panel.offset_bottom = 90

func _hide_erlqueens_nightingale_prompt() -> void:
	var panel := get_node_or_null("ErlqueensNightingalePromptPanel")
	if panel:
		panel.queue_free()
	_pending_erlqueens_nightingale = null

func _resolve_erlqueens_nightingale_shift(return_to_hand_after_shift: bool) -> void:
	var card := _pending_erlqueens_nightingale
	_hide_erlqueens_nightingale_prompt()
	if card == null:
		update_ui()
		return
	if _is_networked_client:
		game_input.submit_action({type = "activate_card_ability", source_uid = card.uid, return_to_hand = return_to_hand_after_shift})
		return
	_queue_magical_action(
		CardAction.Type.ABILITY,
		card,
		{"return_to_hand": return_to_hand_after_shift},
		card.card_name + " activated!",
		func() -> void:
			card.activate(game_manager, {"return_to_hand": return_to_hand_after_shift})
	)
	update_ui()

func _show_en_hedu_anna_prompt(card: EnHeduAnnaScript) -> void:
	_hide_en_hedu_anna_prompt()
	if game_manager == null or card == null:
		return
	if not card.can_activate(game_manager):
		update_ui()
		return

	_pending_en_hedu_anna = card
	var options: Array[Dictionary] = card.get_exaltation_options()

	var panel := PanelContainer.new()
	panel.name = "EnHeduAnnaPromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.11, 0.07, 0.97)
	style.border_color = Color(0.92, 0.80, 0.56, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(470, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = card.card_name
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Choose an Exaltation bonus. %s cannot attack, be destroyed, or be targeted until the end of the next turn." % card.card_name
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	for option in options:
		var btn := Button.new()
		btn.text = card.get_exaltation_option_label(option)
		btn.pressed.connect(_resolve_en_hedu_anna_exaltation.bind(option))
		vbox.add_child(btn)

	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.pressed.connect(_decline_en_hedu_anna_exaltation)
	vbox.add_child(decline_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -235
	panel.offset_right = 235
	panel.offset_top = -110
	panel.offset_bottom = 120

func _hide_en_hedu_anna_prompt() -> void:
	var panel := get_node_or_null("EnHeduAnnaPromptPanel")
	if panel:
		panel.visible = false
		panel.queue_free()
	_pending_en_hedu_anna = null

func _resolve_en_hedu_anna_exaltation(option: Dictionary) -> void:
	var card := _pending_en_hedu_anna
	_hide_en_hedu_anna_prompt()
	if card == null:
		update_ui()
		return
	if _is_networked_client:
		game_input.submit_action({type = "en_hedu_anna_exaltation", source_uid = card.uid, option = option})
		return
	_queue_magical_action(
		CardAction.Type.ABILITY,
		card,
		option,
		card.card_name + " activated!",
		func() -> void:
			card.resolve_exaltation_choice(game_manager, option)
	)
	update_ui()

func _decline_en_hedu_anna_exaltation() -> void:
	var card := _pending_en_hedu_anna
	_hide_en_hedu_anna_prompt()
	action_label.text = (card.card_name if card != null else "En-hedu-anna") + " cancelled Exaltation."
	update_ui()

func _hide_blessed_knights_prompt() -> void:
	var panel := get_node_or_null("BlessedKnightsPromptPanel")
	if panel:
		panel.queue_free()
	_pending_blessed_knights = null

func _resolve_blessed_knights_impact(ward_kind: String) -> void:
	var card := _pending_blessed_knights
	_hide_blessed_knights_prompt()
	if card == null:
		if _stack_resolution_paused: _resume_after_deferred_resolution()
		else: update_ui()
		return
	
	if _is_networked_client:
		game_input.submit_action({"type": "blessed_knights_choice", "source_uid": card.uid, "ward_kind": ward_kind})
	else:
		card.apply_blessed_ward(game_manager, ward_kind)
		var resolution_text := card.card_name + " grants Blessed Ward against " + card.get_blessed_ward_label(ward_kind) + " this turn."
		if _stack_resolution_paused:
			_resume_after_deferred_resolution(resolution_text)
		else:
			action_label.text = resolution_text
			update_ui()

func _hide_absence_mode_prompt() -> void:
	var panel := get_node_or_null("AbsenceModePromptPanel")
	if panel:
		panel.queue_free()
	_pending_absence_spell = null
	_pending_absence_target = null

func _resolve_absence_with_mode(mode: String) -> void:
	var spell := _pending_absence_spell
	var target := _pending_absence_target
	_hide_absence_mode_prompt()
	if spell == null or target == null:
		update_ui()
		return
	if _is_networked_client:
		var spell_uid: String = spell.get("uid") if "uid" in spell else ""
		var target_uid: String = target.get("uid") if "uid" in target else ""
		game_input.submit_action({type = "cast_spell", spell_uid = spell_uid, target_uid = target_uid, mode = mode})
		return
	var target_label := _get_target_label(target, game_manager.get_feedback_viewer(), "target")
	var source_label := _get_attack_card_label(spell, spell.card_name)
	_queue_hand_spell_cast(
		spell,
		target,
		source_label + " is targeting " + target_label + ".",
		func() -> void:
			spell.apply_to_power(target, mode, game_manager)
	)

func _on_absence_relock_pressed() -> void:
	_resolve_absence_with_mode("relock")

func _on_absence_mute_pressed() -> void:
	_resolve_absence_with_mode("mute")

func _on_absence_cancel_pressed() -> void:
	_hide_absence_mode_prompt()
	selected_card = null
	action_label.text = "Cancelled Absence."
	update_ui()

func _hide_aphrodite_prompt() -> void:
	var panel := get_node_or_null("AphroditePromptPanel")
	if panel:
		panel.queue_free()

func _on_aphrodite_confirm_pressed(god: AphroditeAreia) -> void:
	_hide_aphrodite_prompt()
	if _is_networked_client:
		game_input.submit_action({"type": "aphrodite_enslave_choice", "source_uid": god.uid, "confirm": true})
	else:
		awaiting_god_ability_target = true
		god_ability_source = god
		action_label.text = god.card_name + " - Violent Delights: click an enemy creature to enslave."
		update_ui()

func _on_aphrodite_decline_pressed() -> void:
	_hide_aphrodite_prompt()
	if _is_networked_client:
		var god_uid := ""
		if game_manager.current_player != null:
			var god_zone := game_manager.current_player.god_zone
			if not god_zone.cards.is_empty():
				god_uid = god_zone.cards[0].uid
		game_input.submit_action({"type": "aphrodite_enslave_choice", "source_uid": god_uid, "confirm": false})
	else:
		awaiting_god_ability_target = false
		god_ability_source = null
		action_label.text = "Declined Aphrodite Areia."
		update_ui()

func _hide_demiurge_prompt() -> void:
	var panel := get_node_or_null("DemiurgePromptPanel")
	if panel:
		panel.queue_free()
	_pending_demiurge_spell = null

func _show_book_of_life_prompt(spell: BookOfLife) -> void:
	if spell == null:
		update_ui()
		return
	_queue_hand_spell_with_deferred_resolution(
		spell,
		null,
		"Book of Life resolves.",
		func() -> void:
			_begin_book_of_life_resolution(spell)
	)

func _begin_book_of_life_resolution(spell: BookOfLife) -> void:
	_pending_book_of_life_spell = spell
	if spell == null:
		update_ui()
		return
	var valid_creatures: Array[Card] = spell.get_valid_hand_creatures()
	if valid_creatures.is_empty():
		_resolve_book_of_life(null)
		return
	_pause_stack_resolution(spell.card_owner)
	var on_choose_creature := func(selected_creature: Card) -> void:
		_resolve_book_of_life(selected_creature)
	var on_cancel_creature := func() -> void:
		_resolve_book_of_life(null)
	_show_card_selection_overlay(
		"Choose a non-Machine creature for Book of Life",
		valid_creatures,
		on_choose_creature,
		on_cancel_creature
	)

func _resolve_book_of_life(chosen: Card) -> void:
	var spell := _pending_book_of_life_spell
	_pending_book_of_life_spell = null
	if spell == null:
		update_ui()
		return
	if _is_networked_client:
		var spell_uid: String = spell.get("uid") if "uid" in spell else ""
		var target_uid := ""
		if chosen != null and "uid" in chosen:
			target_uid = chosen.get("uid")
		game_input.submit_action({type = "cast_spell", spell_uid = spell_uid, target_uid = target_uid})
		return
	var resolution_text := "Book of Life gained 10 followers."
	if chosen != null:
		resolution_text = "Book of Life gained 10 followers and summoned " + chosen.card_name + " in silence."
	spell.resolve(game_manager, chosen)
	_send_used_hand_card_to_graveyard(spell)
	_resume_after_deferred_resolution(resolution_text)

func _show_deucalion_prompt(spell: DeucalionsInfants) -> void:
	if spell == null:
		update_ui()
		return
	if _pending_deucalion_spell != spell:
		_pending_deucalion_spell = spell
		_pending_deucalion_friendly_targets.clear()
	_sanitize_deucalion_targets()

	var friendly_choices: Array[Card] = spell.get_destroyable_friendly_cards(game_manager)
	var enemy_choices: Array[Card] = spell.get_destroyable_enemy_cards(game_manager)
	var destroyed_so_far: int = spell.get_destroyed_structure_or_golem_count_this_turn(game_manager)
	if friendly_choices.is_empty() and enemy_choices.is_empty() and destroyed_so_far <= 0:
		_hide_deucalion_prompt()
		action_label.text = "Deucalion's Infants has no structures or golems to affect."
		update_ui()
		return

	if _deucalion_panel != null and is_instance_valid(_deucalion_panel):
		_deucalion_panel.free()
	_deucalion_panel = null

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.09, 0.13, 0.97)
	style.border_color = Color(0.82, 0.70, 0.92)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(500, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Deucalion's Infants"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Choose any number of your structures or golems to destroy.\nEnemy structures/golems available: %d\nStructures/golems destroyed this turn: %d" % [
		enemy_choices.size(),
		destroyed_so_far
	]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	if not _pending_deucalion_friendly_targets.is_empty():
		var chosen_label := Label.new()
		var chosen_parts: Array[String] = []
		for chosen_card in _pending_deucalion_friendly_targets:
			chosen_parts.append(chosen_card.card_name)
		chosen_label.text = "Chosen to destroy: " + ", ".join(chosen_parts)
		chosen_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(chosen_label)

		var remove_row := HBoxContainer.new()
		vbox.add_child(remove_row)
		for kept_card in _pending_deucalion_friendly_targets:
			var captured_kept_card := kept_card
			var remove_btn := Button.new()
			remove_btn.text = "Keep " + captured_kept_card.card_name
			remove_btn.pressed.connect(func() -> void:
				_pending_deucalion_friendly_targets.erase(captured_kept_card)
				_show_deucalion_prompt(spell)
			)
			remove_row.add_child(remove_btn)

	var choices_box := VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 4)
	vbox.add_child(choices_box)
	for card in friendly_choices:
		if card in _pending_deucalion_friendly_targets:
			continue
		var add_btn := Button.new()
		add_btn.text = "Destroy " + card.card_name
		add_btn.pressed.connect(func() -> void:
			_pending_deucalion_friendly_targets.append(card)
			_show_deucalion_prompt(spell)
		)
		choices_box.add_child(add_btn)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	var confirm_btn := Button.new()
	confirm_btn.text = "Choose Enemy Card" if not enemy_choices.is_empty() else "Resolve"
	confirm_btn.disabled = _pending_deucalion_friendly_targets.is_empty() and enemy_choices.is_empty() and destroyed_so_far <= 0
	confirm_btn.pressed.connect(_on_deucalion_confirm_pressed)
	buttons.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_deucalion_cancel_pressed)
	buttons.add_child(cancel_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	_deucalion_panel = panel
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -120
	panel.offset_bottom = 120

func _sanitize_deucalion_targets() -> void:
	if _pending_deucalion_spell == null:
		_pending_deucalion_friendly_targets.clear()
		return
	var valid_targets: Array[Card] = _pending_deucalion_spell.get_destroyable_friendly_cards(game_manager)
	var cleaned: Array[Card] = []
	for card in _pending_deucalion_friendly_targets:
		if card != null and card in valid_targets and card not in cleaned:
			cleaned.append(card)
	_pending_deucalion_friendly_targets = cleaned

func _hide_deucalion_prompt() -> void:
	if _deucalion_panel != null and is_instance_valid(_deucalion_panel):
		_deucalion_panel.free()
	_deucalion_panel = null
	_pending_deucalion_spell = null
	_pending_deucalion_friendly_targets.clear()

func _on_deucalion_confirm_pressed() -> void:
	var spell := _pending_deucalion_spell
	_sanitize_deucalion_targets()
	var friendly_targets := _pending_deucalion_friendly_targets.duplicate()
	_hide_deucalion_prompt()
	if spell == null:
		update_ui()
		return

	var enemy_choices: Array[Card] = spell.get_destroyable_enemy_cards(game_manager)
	if enemy_choices.size() > 1:
		var opponent := game_manager.get_opponent(spell.card_owner)
		if opponent != null:
			action_label.text = opponent.player_name + " chooses which of their structures or golems is destroyed."
		_show_card_selection_overlay(
			"Opponent Chooses Which Card Is Destroyed",
			enemy_choices,
			func(selected_enemy: Card) -> void:
				_queue_deucalion_spell(spell, friendly_targets, selected_enemy)
		)
		return

	var chosen_enemy: Card = null
	if enemy_choices.size() == 1:
		chosen_enemy = enemy_choices[0]
	_queue_deucalion_spell(spell, friendly_targets, chosen_enemy)

func _queue_deucalion_spell(spell: DeucalionsInfants, friendly_targets: Array[Card], enemy_target: Card = null) -> void:
	if spell == null:
		update_ui()
		return
	if _is_networked_client:
		var spell_uid: String = spell.get("uid") if "uid" in spell else ""
		var choices: Array = []
		for c in friendly_targets:
			if c != null and "uid" in c:
				choices.append(c.uid)
		var enemy_uid: String = enemy_target.get("uid") if enemy_target != null and "uid" in enemy_target else ""
		game_input.submit_action({type = "cast_spell", spell_uid = spell_uid, choices = choices, enemy_target_uid = enemy_uid})
		return
	spell.resolve_with_choices(game_manager, friendly_targets, enemy_target, func() -> void:
		_send_used_hand_card_to_graveyard(spell)
		_resume_after_deferred_resolution(_consume_resolution_feedback("Cast " + spell.card_name + "!"))
	)

func _queue_deucalion_resolution(spell: DeucalionsInfants) -> void:
	if spell == null:
		update_ui()
		return
	_queue_hand_spell_with_deferred_resolution(
		spell,
		null,
		"Deucalion's Infants resolves.",
		func() -> void:
			_begin_deucalion_resolution(spell)
	)

func _begin_deucalion_resolution(spell: DeucalionsInfants) -> void:
	if spell == null:
		update_ui()
		return
	if _pending_deucalion_spell != spell:
		_pending_deucalion_spell = spell
		_pending_deucalion_friendly_targets.clear()
	_sanitize_deucalion_targets()
	var friendly_choices: Array[Card] = spell.get_destroyable_friendly_cards(game_manager)
	var enemy_choices: Array[Card] = spell.get_destroyable_enemy_cards(game_manager)
	var destroyed_so_far: int = spell.get_destroyed_structure_or_golem_count_this_turn(game_manager)
	if friendly_choices.is_empty() and enemy_choices.is_empty() and destroyed_so_far <= 0:
		spell.resolve_with_choices(game_manager, [], null)
		_send_used_hand_card_to_graveyard(spell)
		_pending_deucalion_spell = null
		_resume_after_deferred_resolution(_consume_resolution_feedback("Deucalion's Infants resolved."))
		return
	_pause_stack_resolution(spell.card_owner)
	_show_deucalion_prompt(spell)

func _on_deucalion_cancel_pressed() -> void:
	if _stack_resolution_paused and _pending_deucalion_spell != null:
		var spell := _pending_deucalion_spell
		var friendly_targets := _pending_deucalion_friendly_targets.duplicate()
		_hide_deucalion_prompt()
		var enemy_choices: Array[Card] = spell.get_destroyable_enemy_cards(game_manager)
		var chosen_enemy: Card = null
		if enemy_choices.size() == 1:
			chosen_enemy = enemy_choices[0]
		_queue_deucalion_spell(spell, friendly_targets, chosen_enemy)
		return
	_hide_deucalion_prompt()
	selected_card = null
	action_label.text = "Cancelled Deucalion's Infants."
	update_ui()

func _initiate_blot_with_sacrifice(spell, sacrifice_target: Card) -> void:
	_clear_pending_click_selection()
	_hide_blot_sacrifice_prompt()
	if spell == null or sacrifice_target == null:
		update_ui()
		return
	if not _can_use_card_for_creature_sacrifice(sacrifice_target):
		action_label.text = "Blot Sacrifice requires a sacrificable friendly creature."
		update_ui()
		return
	if not _can_cast_hand_spell(spell):
		action_label.text = "Blot Sacrifice cancelled: cannot pay costs."
		update_ui()
		return
	var orig_creature_cost: int = spell.sacrifice_cost
	spell.sacrifice_cost = 0
	var paid: bool = spell.pay_costs(game_manager.current_player, game_manager)
	spell.sacrifice_cost = orig_creature_cost
	if not paid:
		action_label.text = "Cannot cast Blot Sacrifice."
		update_ui()
		return
	game_manager.request_send_to_graveyard(sacrifice_target, func() -> void:
		var display_zone := _resolve_pending_display_zone(spell, null)
		var action := CardAction.new()
		action.type = CardAction.Type.SPELL
		action.source_player = spell.card_owner
		action.card = spell
		action.display_zone = display_zone
		action.resolution_text = "Blot Sacrifice resolves."
		action.resolve_callback = func() -> void:
			_begin_blot_resolution_prompt(spell, sacrifice_target, display_zone)
		_assign_stack_display_zone(action)
		game_manager.push_to_stack(action)
		selected_card = null
		update_ui()
		action_label.text = spell.card_name + " [" + _get_stack_card_type_label(spell) + "] goes on the stack."
		_offer_priority()
	)

func _begin_blot_resolution_prompt(spell, sacrifice_target: Card, display_zone: Zone = null) -> void:
	if spell == null:
		update_ui()
		return
	_pending_blot_spell = spell
	_pending_blot_sacrifice_target = sacrifice_target
	_pending_blot_selected_creatures.clear()
	_pending_blot_display_zone = display_zone
	_pending_blot_costs_paid = true
	game_manager.notify_spell_played(spell.card_owner, spell)
	if spell.get_available_summon_zones().is_empty():
		_send_used_hand_card_to_graveyard(spell)
		_hide_blot_sacrifice_prompt()
		game_manager.note_player_feedback("Blot Sacrifice resolved, but no open zone was available.")
		update_ui()
		return
	if spell.get_valid_hand_creatures(BlotSacrifice.MAX_SUMMON_LEVELS, []).is_empty():
		_send_used_hand_card_to_graveyard(spell)
		_hide_blot_sacrifice_prompt()
		game_manager.note_player_feedback("Blot Sacrifice resolved, but there were no valid creatures in hand to summon.")
		update_ui()
		return
	game_manager.note_player_feedback("Blot Sacrifice resolved. Choose creatures to summon.")
	_pause_stack_resolution(spell.card_owner)
	_show_blot_creature_prompt()

func _show_blot_sacrifice_prompt(spell) -> void:
	_hide_blot_sacrifice_prompt()
	if spell == null:
		update_ui()
		return
	var sacrifice_targets: Array[Card] = []
	for zone in game_manager.current_player.frontline_zones + game_manager.current_player.reserve_zones:
		for card in zone.cards:
			if _can_use_card_for_creature_sacrifice(card):
				sacrifice_targets.append(card)
	if sacrifice_targets.is_empty():
		action_label.text = "Blot Sacrifice needs a friendly creature to sacrifice."
		update_ui()
		return
	selected_card = spell
	_begin_pending_click_selection(
		"Blot Sacrifice",
		spell,
		func(clicked_card: Card) -> bool:
			return clicked_card != null \
				and clicked_card.get_controller() == game_manager.current_player \
				and _can_use_card_for_creature_sacrifice(clicked_card),
		func(clicked_card: Card) -> void:
			_initiate_blot_with_sacrifice(spell, clicked_card)
	)
	action_label.text = "Blot Sacrifice: select a friendly creature to sacrifice."
	update_ui()

func _show_blot_creature_prompt() -> void:
	var spell = _pending_blot_spell
	if spell == null:
		update_ui()
		return
	_sanitize_blot_selected_creatures()
	var remaining_levels: int = _get_blot_remaining_levels()
	var available_slots: int = spell.get_available_summon_zones().size()
	var valid_choices: Array[Card] = _get_blot_valid_choices(spell)
	if available_slots <= 0:
		_hide_blot_sacrifice_prompt()
		action_label.text = "Blot Sacrifice: no open zone to summon into."
		update_ui()
		return
	if _pending_blot_selected_creatures.size() >= available_slots or remaining_levels <= 0:
		if _pending_blot_selected_creatures.is_empty():
			_hide_blot_sacrifice_prompt()
			action_label.text = "Blot Sacrifice: no more creatures to summon."
			update_ui()
			return
		_on_blot_sacrifice_confirm_pressed()
		return
	if valid_choices.is_empty():
		if _pending_blot_selected_creatures.is_empty():
			_hide_blot_sacrifice_prompt()
			action_label.text = "Blot Sacrifice: no more creatures to summon."
			update_ui()
			return
		_on_blot_sacrifice_confirm_pressed()
		return

	if _blot_panel != null and is_instance_valid(_blot_panel):
		_blot_panel.free()
	_blot_panel = null

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.08, 0.96)
	style.border_color = Color(0.38, 0.82, 0.45)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(240, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Blot Sacrifice"
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Click green creatures in hand.\n%s" % _get_blot_selection_summary()
	info.add_theme_font_size_override("font_size", 11)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var sacrifice_label := Label.new()
	sacrifice_label.text = "Sacrificed: %s" % [
		_pending_blot_sacrifice_target.card_name if _pending_blot_sacrifice_target != null else "None"
	]
	sacrifice_label.add_theme_font_size_override("font_size", 10)
	sacrifice_label.modulate = Color(0.8, 0.92, 0.82)
	sacrifice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sacrifice_label)

	if not _pending_blot_selected_creatures.is_empty():
		var chosen_label := Label.new()
		var chosen_parts: Array[String] = []
		for chosen_card in _pending_blot_selected_creatures:
			chosen_parts.append("%s (Lv %d)" % [chosen_card.card_name, chosen_card.level])
		chosen_label.text = "Chosen: " + ", ".join(chosen_parts)
		chosen_label.add_theme_font_size_override("font_size", 10)
		chosen_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(chosen_label)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	var confirm_btn := Button.new()
	confirm_btn.text = "Summon Now"
	confirm_btn.disabled = _pending_blot_selected_creatures.is_empty()
	confirm_btn.pressed.connect(_on_blot_sacrifice_confirm_pressed)
	buttons.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_blot_sacrifice_cancel_pressed)
	buttons.add_child(cancel_btn)

	add_child(panel)
	_promote_transient_ui(panel)
	_blot_panel = panel
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -250
	panel.offset_right = -10
	panel.offset_top = -70
	panel.offset_bottom = 70

func _blot_has_more_summonable_creatures(spell) -> bool:
	if spell == null:
		return false
	_sanitize_blot_selected_creatures()
	var remaining_levels: int = _get_blot_remaining_levels()
	var available_slots: int = spell.get_available_summon_zones().size()
	if available_slots <= 0:
		return false
	if _pending_blot_selected_creatures.size() >= available_slots:
		return false
	if remaining_levels <= 0:
		return false
	return not _get_blot_valid_choices(spell).is_empty()

func _hide_blot_sacrifice_prompt() -> void:
	_dismiss_zone_overlay()
	if _blot_panel != null and is_instance_valid(_blot_panel):
		_blot_panel.free()
	_blot_panel = null
	_pending_blot_spell = null
	_pending_blot_sacrifice_target = null
	_pending_blot_selected_creatures.clear()
	_pending_blot_display_zone = null
	_pending_blot_costs_paid = false

func _on_blot_sacrifice_confirm_pressed() -> void:
	var spell = _pending_blot_spell
	var sacrifice_target := _pending_blot_sacrifice_target
	var costs_paid := _pending_blot_costs_paid
	_sanitize_blot_selected_creatures()
	var chosen_creatures := _pending_blot_selected_creatures.duplicate()
	_hide_blot_sacrifice_prompt()

	if _is_networked_client and spell != null and costs_paid:
		var spell_uid: String = spell.get("uid") if "uid" in spell else ""
		var choices: Array = []
		for c in chosen_creatures:
			if c != null and "uid" in c:
				choices.append(c.uid)
		# Include the sacrifice target UID so server knows which creature to sacrifice
		var sac_uid: String = sacrifice_target.get("uid") if sacrifice_target != null and "uid" in sacrifice_target else ""
		game_input.submit_action({type = "cast_spell", spell_uid = spell_uid, choices = choices, sacrifice_uid = sac_uid})
		return
	if spell == null or sacrifice_target == null:
		update_ui()
		return
	if chosen_creatures.is_empty():
		_send_used_hand_card_to_graveyard(spell)
		_resume_after_deferred_resolution("Blot Sacrifice fizzles: no creatures chosen to summon.")
		return
	if not costs_paid:
		_resume_after_deferred_resolution("Blot Sacrifice cancelled: costs were not paid.")
		return
	if spell.get_available_summon_zones().is_empty():
		_send_used_hand_card_to_graveyard(spell)
		_resume_after_deferred_resolution("Blot Sacrifice: no open zone to summon into.")
		return
	var summoned_creatures: Array[Card] = spell.summon_selected_creatures(game_manager, chosen_creatures)
	_send_used_hand_card_to_graveyard(spell)
	selected_card = null
	_resume_after_deferred_resolution("Blot Sacrifice summoned " + str(summoned_creatures.size()) + " creature(s).")

func _on_blot_sacrifice_cancel_pressed() -> void:
	var spell = _pending_blot_spell
	var costs_paid := _pending_blot_costs_paid
	_hide_blot_sacrifice_prompt()
	selected_card = null
	if costs_paid and spell != null:
		_send_used_hand_card_to_graveyard(spell)
		_resume_after_deferred_resolution("Blot Sacrifice fizzles.")
	else:
		action_label.text = "Cancelled Blot Sacrifice."
		update_ui()

func _dismiss_transient_prompts() -> void:
	_hide_devour_cancel_prompt()
	_dismiss_zone_overlay()
	_hide_priority_prompt()
	_hide_retreat_prompt()
	_hide_skoll_prompt()
	_hide_doorway_choice_prompt()
	_hide_sacrifice_payment_prompt()
	_hide_structure_bonus_prompt()
	_hide_demiurge_prompt()
	_pending_book_of_life_spell = null
	_hide_absence_mode_prompt()
	_hide_blessed_knights_prompt()
	_hide_byggvir_reveal_prompt()
	_hide_erlqueens_nightingale_prompt()
	_hide_breidablik_prompt()
	_hide_e2_abzu_prompt()
	_hide_divine_caprice_prompt()
	_hide_aphrodite_prompt()
	_hide_blot_sacrifice_prompt()
	_hide_deucalion_prompt()
	_pending_skoll_prompts.clear()
	_clear_skoll_upkeep_summon()
	if _resurrection_panel and is_instance_valid(_resurrection_panel):
		_resurrection_panel.queue_free()
	_resurrection_panel = null
	_resurrection_queue.clear()

func _on_demiurge_confirm_pressed(spin: SpinBox) -> void:
	var spell = _pending_demiurge_spell
	var x_value := int(spin.value)
	_hide_demiurge_prompt()
	if spell == null:
		update_ui()
		return
	if _is_networked_client:
		var spell_uid: String = spell.get("uid") if "uid" in spell else ""
		game_input.submit_action({type = "cast_spell", spell_uid = spell_uid, x_value = x_value})
		return
	if spell == null:
		update_ui()
		return
	if not _can_cast_hand_spell(spell):
		action_label.text = "Cannot cast " + spell.card_name + "!"
		update_ui()
		return
	if not spell.can_cast_with_x(game_manager, x_value):
		action_label.text = "Apollyon's Demiurge: invalid X cost."
		update_ui()
		return
	var pay_demiurge_costs := func() -> bool:
		return spell.can_cast_with_x(game_manager, x_value) \
			and spell.pay_costs(game_manager.current_player, game_manager) \
			and spell.pay_x_cost(game_manager, x_value)
	var resolve_demiurge := func() -> void:
		var demon_choices: Array = spell.resolve_with_x(game_manager, x_value, true)
		if demon_choices.is_empty():
			_send_used_hand_card_to_graveyard(spell)
			game_manager.note_player_feedback("Apollyon's Demiurge milled %d card(s), but no Demon was milled." % x_value)
			return
		if demon_choices.size() == 1:
			var summoned: bool = spell.summon_milled_demon(game_manager, demon_choices[0])
			_send_used_hand_card_to_graveyard(spell)
			game_manager.note_player_feedback(
				"Apollyon's Demiurge summoned %s." % demon_choices[0].card_name
				if summoned
				else "Apollyon's Demiurge found no open zone to summon into."
			)
			return
		_pause_stack_resolution(spell.card_owner)
		var on_choose_demon := func(selected_demon: Card) -> void:
			var summoned: bool = spell.summon_milled_demon(game_manager, selected_demon)
			_send_used_hand_card_to_graveyard(spell)
			_resume_after_deferred_resolution(
				"Apollyon's Demiurge summoned %s." % selected_demon.card_name
				if summoned
				else "Apollyon's Demiurge found no open zone to summon into."
			)
		var on_cancel_demon := func() -> void:
			_send_used_hand_card_to_graveyard(spell)
			_resume_after_deferred_resolution("Apollyon's Demiurge fizzles.")
		_show_card_selection_overlay(
			"Choose a Milled Demon to Summon",
			demon_choices,
			on_choose_demon,
			on_cancel_demon
		)
	_queue_hand_spell_with_deferred_resolution(
		spell,
		x_value,
		"Apollyon's Demiurge resolves for X = " + str(x_value) + ".",
		resolve_demiurge,
		pay_demiurge_costs
	)

func _on_demiurge_cancel_pressed() -> void:
	_hide_demiurge_prompt()
	action_label.text = "Cancelled Apollyon's Demiurge."
	update_ui()

func _on_structure_bonus_confirm_pressed(spin: SpinBox) -> void:
	var power := _pending_structure_bonus_power
	var structure := _pending_structure_bonus_structure
	var mana_to_spend := int(spin.value)
	_hide_structure_bonus_prompt()
	if power == null or structure == null:
		update_ui()
		return

	var gained := power.apply_structure_bonus(structure, mana_to_spend, game_manager)
	if gained > 0:
		action_label.text = "%s gains %d Res from Advanced Building Techniques." % [structure.card_name, gained]
	else:
		action_label.text = "No mana spent on Advanced Building Techniques."
	update_ui()

func _on_structure_bonus_skip_pressed() -> void:
	_hide_structure_bonus_prompt()
	action_label.text = "Skipped Advanced Building Techniques."
	update_ui()

func _on_retreat_yes() -> void:
	_hide_retreat_prompt()
	var action := _pending_retreat_action
	var defender := _pending_retreat_target
	_clear_pending_retreat_state()
	if action == null or defender == null:
		update_ui()
		return
	_send_to_deck_bottom(action.attacker)
	_send_to_deck_bottom(defender)
	action_label.text = "Tactful Retreat! Both creatures returned to the bottom of their decks."
	update_ui()
	_finish_post_execute(action.source_player)

func _on_retreat_no() -> void:
	_hide_retreat_prompt()
	var action := _pending_retreat_action
	var defender := _pending_retreat_target
	if not _pending_retreat_prompts.is_empty():
		_pending_retreat_prompts.remove_at(0)
	if action == null or defender == null:
		_clear_pending_retreat_state()
		update_ui()
		return
	if action.attacker == null:
		_clear_pending_retreat_state()
		action_label.text = "The attack can no longer continue."
		update_ui()
		_finish_post_execute(action.source_player)
		return
	if not _pending_retreat_prompts.is_empty():
		_show_retreat_prompt(_pending_retreat_prompts[0])
		return
	var blocked_ask: Askelladen = null
	if not _pending_retreat_guardian_blocked.is_empty():
		blocked_ask = _pending_retreat_guardian_blocked[0]
	_clear_pending_retreat_state()
	game_manager.resolve_combat_with_continuation(action.attacker, defender, func() -> void:
		if blocked_ask != null:
			action_label.text = "Asaruludu's Guardian prevented " + _get_card_name_safe(blocked_ask) + "'s Tactful Retreat!"
		else:
			action_label.text = _get_attack_card_label(action.attacker, "The attacker") + " fought " + _get_card_name_safe(defender) + "!"
		_capture_action_log_message(true)
		action.attacker.spend_major_creature_action()
		update_ui()
		_finish_post_execute(action.source_player)
	)

func _execute_top_of_stack() -> void:
	_hide_priority_prompt()
	if game_manager.action_stack.is_empty():
		update_ui()
		return

	_executing_stack_action = true
	var action: CardAction = game_manager.action_stack.pop_back()
	
	match_manager.resolve_action(action)
	# The rest is now handled by MatchManager and its callbacks/signals

func _on_match_action_resolved(action: CardAction) -> void:
	if match_manager.last_resolution_text != "":
		action_label.text = _consume_resolution_feedback(match_manager.last_resolution_text)
	
	if action.type == CardAction.Type.EVENT:
		_capture_action_log_message()

	_executing_stack_action = false
	if _stack_resolution_paused:
		return
		
	_finish_post_execute(action.source_player)
	update_ui()

func _on_match_move_validated(move: Dictionary) -> void:
	match move.get("type", ""):
		"upkeep_choice":
			# Client resolved upkeep; server must open the turn-start priority window
			# so both players can respond to upkeep effects (hexes, charms, etc.).
			var choice: String = move.get("choice", "")
			var feedback := "Drew a card." if choice == "draw" else "Gained 4 additional mana."
			_queue_standard_turn_start_priority(feedback)
		"skoll_upkeep_summon":
			# Skoll already summoned by MatchManager; open standard turn-start priority.
			_queue_standard_turn_start_priority("Skoll summoned via Sun Hunt.")
		"attack":
			var attacker: Card = move.get("attacker")
			var target = move.get("target")
			if target is Player:
				action_label.text = _get_attack_card_label(attacker, "A creature") + " attacks " + target.player_name + "'s followers!"
				check_for_possible_intercepts()
			elif target is Card:
				action_label.text = _get_attack_card_label(attacker, "A creature") + " attacking " + _get_card_name_safe(target, "an enemy card") + "..."
				check_for_possible_intercepts()
		"intercept_decision":
			# selected_interceptor was set by MatchManager; proceed to resolve the attack.
			resolve_pending_attack()
		"priority_pass":
			# Remote player passed priority; continue the server-side priority loop.
			game_manager.pass_priority()
			if game_manager.both_passed():
				_execute_top_of_stack()
			else:
				_offer_priority()
		"resurrection_choice":
			_continue_end_turn_sequence()
		"play_hex_response":
			# Remote player activated a hex; the ABILITY was already pushed by MatchManager.
			var phr_hex := game_manager.get_card_by_uid(move.get("hex_uid", ""))
			if phr_hex != null:
				action_label.text = phr_hex.card_name + " responds!"
			_offer_priority()
		"play_charm_response":
			# Remote player activated a charm; the SPELL was already pushed by MatchManager.
			var pcr_charm := game_manager.get_card_by_uid(move.get("charm_uid", ""))
			if pcr_charm != null:
				action_label.text = pcr_charm.card_name + " responds!"
			_offer_priority()
	update_ui()

func _on_match_move_failed(reason: String) -> void:
	action_label.text = reason
	update_ui()

func _on_match_ui_interaction(player_index: int, type: String, data: Dictionary) -> void:
	var target_player := game_manager.players[player_index]
	
	if network_manager != null and network_manager.is_server:
		if _executing_stack_action and not _stack_resolution_paused:
			_pause_stack_resolution(target_player)
			
	if not _is_player_local(target_player):
		return
		
	match type:
		"combat_retreat":
			var action: CardAction = data["action"]
			var target = data.get("target")
			if target == null:
				var target_uid: String = data.get("target_uid", "")
				target = game_manager.get_card_by_uid(target_uid)
				if target == null:
					var p_idx: int = data.get("target_player_index", -1)
					if p_idx >= 0 and p_idx < game_manager.players.size():
						target = game_manager.players[p_idx]
						
			var retreat_prompts := _get_retreating_askelladens(action.attacker, target, action.source_player)
			if not retreat_prompts.is_empty():
				_pending_retreat_action = action
				_pending_retreat_target = target
				_pending_retreat_prompts = retreat_prompts
				_pending_retreat_guardian_blocked = _get_guardian_blocked_retreats(action.attacker, target, action.source_player)
				_show_retreat_prompt(_pending_retreat_prompts[0])
			else:
				# No retreat, proceed with normal combat resolution
				var blocked_retreats := _get_guardian_blocked_retreats(action.attacker, target, action.source_player)
				var blocked_ask: Askelladen = blocked_retreats[0] if not blocked_retreats.is_empty() else null
				
				var finish_attack := func() -> void:
					var active_attackers: Array[Card] = []
					if action.united_front_partner != null:
						active_attackers = game_manager._get_active_united_front_attackers(action.attacker, action.united_front_partner)
					elif action.attacker.current_zone != null and action.attacker.current_zone.is_board_zone():
						active_attackers = [action.attacker]
						
					if blocked_ask != null:
						action_label.text = "Asaruludu's Guardian prevented " + _get_card_name_safe(blocked_ask) + "'s Tactful Retreat!"
					else:
						if active_attackers.size() >= 2:
							action_label.text = _get_attack_card_label(active_attackers[0], "The attacker") + " and " + _get_card_name_safe(active_attackers[1]) + " fought " + _get_card_name_safe(target) + "!"
						elif not active_attackers.is_empty():
							action_label.text = _get_attack_card_label(active_attackers[0], "The attacker") + " fought " + _get_card_name_safe(target) + "!"
					_capture_action_log_message(true)
					
					for combatant in active_attackers:
						combatant.spend_major_creature_action()
						combatant.mark_attacked_this_turn()
						
					update_ui()
					if _stack_resolution_paused:
						_resume_after_deferred_resolution(action_label.text)
					else:
						_finish_post_execute(action.source_player)
				
				_executing_stack_action = false
				if action.united_front_partner != null:
					game_manager.resolve_united_front_combat(action.attacker, action.united_front_partner, target)
					finish_attack.call()
				else:
					game_manager.resolve_combat_with_continuation(
						action.attacker,
						target,
						finish_attack,
						action.interceptor != null
					)
		"aphrodite_enslave":
			var god := game_manager.get_card_by_uid(data.get("source_uid", "")) as AphroditeAreia
			if god != null:
				_show_aphrodite_prompt(god)
		"blessed_knights_ward":
			var card := game_manager.get_card_by_uid(data.get("source_uid", "")) as BlessedKnights
			if card != null:
				_show_blessed_knights_prompt(card)
		"en_hedu_anna_exaltation":
			var card := game_manager.get_card_by_uid(data.get("source_uid", "")) as EnHeduAnna
			if card != null:
				_show_en_hedu_anna_prompt(card)

func _find_empty_player_zone() -> Zone:
	for zone in game_manager.current_player.frontline_zones + game_manager.current_player.reserve_zones:
		if zone.cards.size() == 0:
			return zone
	return null

func _find_nearest_empty_friendly_zone(drop_pos: Vector2) -> Zone:
	var best_zone: Zone = null
	var best_distance := INF
	for zu in _board_zone_uis:
		if zu == null or not is_instance_valid(zu):
			continue
		if zu._is_enemy or zu.zone == null or zu.zone.cards.size() > 0:
			continue
		var rect: Rect2 = zu.get_global_rect()
		var center: Vector2 = rect.position + rect.size * 0.5
		var distance: float = center.distance_to(drop_pos)
		if distance < best_distance:
			best_distance = distance
			best_zone = zu.zone
	return best_zone

func _is_attacker_on_board(attacker: Card, owning_player: Player) -> bool:
	for z in owning_player.frontline_zones + owning_player.reserve_zones:
		if attacker in z.cards:
			return true
	return false

func _on_draw_button_pressed() -> void:
	if _game_finished:
		return
	if _skoll_prompt_panel != null or _pending_skoll_summon != null:
		action_label.text = "Finish resolving Sun Hunt or cancel it before choosing another upkeep option."
		return
	var _deck_had_cards: bool = game_manager.current_player.deck_zone.get_card_count() > 0
	game_input.submit_action({type = "upkeep_choice", choice = "draw"})
	_close_turn_start_windows()
	update_ui()
	hide_turn_choice()
	if not _is_networked_client:
		_queue_standard_turn_start_priority("Drew a card." if _deck_had_cards else "No cards left to draw.")

func _on_mana_button_pressed() -> void:
	if _game_finished:
		return
	if _skoll_prompt_panel != null or _pending_skoll_summon != null:
		action_label.text = "Finish resolving Sun Hunt or cancel it before choosing another upkeep option."
		return
	game_input.submit_action({type = "upkeep_choice", choice = "mana"})
	_close_turn_start_windows()
	update_ui()
	hide_turn_choice()
	if not _is_networked_client:
		_queue_standard_turn_start_priority("Gained 4 additional mana.")

func _close_turn_start_windows() -> void:
	_hide_skoll_prompt()
	_pending_skoll_prompts.clear()
	_pending_skoll_summon = null
	_pending_skoll_mode = ""
	_pending_creature_play_resolver = Callable()
	if game_manager == null or game_manager.current_player == null:
		return
	for card in game_manager.current_player.god_zone.cards:
		if card.has_method("close_turn_start_window"):
			card.close_turn_start_window()
	for zone in game_manager.current_player.power_zones:
		for card in zone.cards:
			if card.has_method("close_turn_start_window"):
				card.close_turn_start_window()

func _get_end_turn_discard_count() -> int:
	return maxi(0, game_manager.current_player.hand_zone.get_card_count() - Player.MAX_HAND_SIZE)

func _prompt_end_turn_discards() -> void:
	var excess := _get_end_turn_discard_count()
	if excess <= 0:
		_continue_end_turn_sequence()
		return
	_show_card_selection_overlay(
		"Discard %d card(s) to reach %d cards" % [excess, Player.MAX_HAND_SIZE],
		game_manager.current_player.hand_zone.cards.duplicate(),
		func(chosen_card: Card) -> void:
			_discard_end_turn_card(chosen_card)
	)
	action_label.text = "Choose %d card(s) to discard before ending your turn." % excess

func _discard_end_turn_card(card: Card) -> void:
	if card == null or card.current_zone != game_manager.current_player.hand_zone:
		_prompt_end_turn_discards()
		return
	if _is_networked_client:
		# Stage discard locally so the count decreases; send all UIDs with "end_turn".
		game_manager.current_player.hand_zone.cards.erase(card)
		_pending_end_turn_discard_uids.append(card.uid)
		update_ui()
		_prompt_end_turn_discards()
		return
	game_manager.current_player.discard_card(card)
	update_ui()
	_prompt_end_turn_discards()

func _continue_end_turn_sequence() -> void:
	# Check for Again-Walker resurrections before committing end turn
	var candidates: Array[Card] = []
	for card in game_manager.pending_resurrections:
		if card.card_owner.mana >= 1 \
				and card.current_zone == card.card_owner.graveyard_zone:
			candidates.append(card)
			
	if candidates.is_empty():
		_do_end_turn()
		return

	# If server, we might need to ask a remote player
	if network_manager != null and network_manager.is_server:
		var card := candidates[0]
		if not _is_player_local(card.card_owner):
			var player_idx := game_manager.players.find(card.card_owner)
			match_manager.request_ui_interaction.emit(player_idx, "resurrection", {"card_uid": card.uid})
			return
			
	_show_resurrection_prompt(candidates)

func _on_end_turn_button_pressed() -> void:
	if _game_finished:
		return
	if _is_blot_selection_active():
		_hide_blot_sacrifice_prompt()
	_dismiss_transient_prompts()
	_close_context_menu()
	_pending_move_card = null
	_queued_attackers.clear()
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	pending_attack_target = null
	placement_mode = ""
	placement_container.visible = false
	awaiting_stupefy_target = false
	stupefy_source = null
	_awaiting_creature_sacrifice = false
	_sacrifice_pending_card = null
	_sacrifice_pending_zone = null
	_sacrifice_pending_mode = ""
	_sacrifice_remaining = 0
	_pending_creature_play_resolver = Callable()
	_drag_sacrifice_done = false
	_awaiting_drag_sacrifice_zone = false
	_drag_sacrifice_card = null
	_drag_sacrifice_target = null
	_drag_sacrifice_mode = ""
	_clear_wolf_master_summon()
	_prompt_end_turn_discards()

# ---------------------------------------------------------------------------
# Network event handling (client side)
# ---------------------------------------------------------------------------

func _is_player_local(player: Player) -> bool:
	if network_manager == null:
		return true # Local mode
	if network_manager.local_player_index < 0:
		return true # Not yet assigned, assume local for now
	var idx := game_manager.players.find(player)
	return idx == network_manager.local_player_index

func _on_peer_disconnected(_peer_id: int) -> void:
	if _game_finished:
		return
	if headless_match_host != null and headless_match_host.match_session != null:
		_set_match_reconnect_wait(true, "Opponent disconnected. Waiting for reconnect...")
		action_label.text = _match_reconnect_wait_message
		_dismiss_transient_prompts()
		_hide_priority_prompt()
		_hide_intercept_prompt()
		update_ui()
		return
	_game_finished = true
	action_label.text = "Opponent disconnected. Game over."
	_dismiss_transient_prompts()
	_hide_priority_prompt()
	_hide_intercept_prompt()
	_update_waiting_status(false)
	update_ui()

func _apply_network_event(event_type: String, data: Dictionary) -> void:
	match event_type:
		"full_state":
			_apply_full_state(data)
		"ui_interaction":
			_apply_ui_interaction(data)
		"match_join_ok":
			action_label.text = "Match authenticated. Waiting for state sync..."
			update_ui()
		"match_join_denied":
			action_label.text = str(data.get("reason", "Match authentication failed."))
			match_session_cleared.emit()
			update_ui()
		"peer_left":
			var player_idx := int(data.get("player_index", -1))
			var player_name := "Opponent"
			if player_idx >= 0 and player_idx < game_manager.players.size():
				player_name = game_manager.players[player_idx].player_name
			var reconnect_deadline := int(data.get("reconnect_deadline_unix", 0))
			var seconds_remaining := maxi(0, reconnect_deadline - int(Time.get_unix_time_from_system()))
			var wait_message := "%s disconnected. Waiting up to %ds for reconnect..." % [player_name, seconds_remaining]
			_set_match_reconnect_wait(true, wait_message)
			action_label.text = wait_message
			update_ui()
		"peer_rejoined":
			var rejoined_idx := int(data.get("player_index", -1))
			var rejoined_name := "Opponent"
			if rejoined_idx >= 0 and rejoined_idx < game_manager.players.size():
				rejoined_name = game_manager.players[rejoined_idx].player_name
			_set_match_reconnect_wait(false)
			action_label.text = "%s rejoined the match." % rejoined_name
			update_ui()
		"match_reconnect_started":
			var attempts_remaining := int(data.get("attempts_remaining", 0))
			_set_match_reconnect_wait(true, "Connection lost. Reconnecting to match server...")
			action_label.text = "Connection lost. Reconnecting to match server... (%d retries left)" % attempts_remaining
			update_ui()
		"match_reconnect_ok":
			_set_match_reconnect_wait(false)
			action_label.text = "Reconnected to the match server."
			update_ui()
		"match_reconnect_failed":
			_set_match_reconnect_wait(true, "Reconnect failed. You may need to rejoin the match.")
			action_label.text = str(data.get("reason", "Reconnect failed."))
			update_ui()
		"server_disconnected":
			_set_match_reconnect_wait(true, "Disconnected from match server. Reconnect may still be available.")
			action_label.text = _match_reconnect_wait_message
			_dismiss_transient_prompts()
			_hide_priority_prompt()
			_hide_intercept_prompt()
			update_ui()
		"upkeep_needed":
			# Server tells this client it's their turn and they need to choose upkeep
			if network_manager != null:
				var cp_idx: int = data.get("current_player_index", -1)
				if cp_idx == network_manager.local_player_index:
					call_deferred("_open_upkeep_choice_window")
		"turn_started":
			# Turn hooks resolved; update label only — upkeep_needed already opened the window
			pass
		"priority_offered":
			_apply_priority_offered(data)
		"intercept_offered":
			_apply_intercept_offered(data)
		"command_rejected":
			action_label.text = str(data.get("reason", "That move was rejected by the server."))
			update_ui()
		"game_ended":
			var winner_name: String = data.get("winner_name", "Unknown")
			action_label.text = winner_name + " wins!"
			_game_finished = true
			match_session_cleared.emit()
			update_ui()

func _apply_ui_interaction(event_data: Dictionary) -> void:
	var type: String = event_data.get("type", "")
	var payload: Dictionary = event_data.get("data", {})
	var local_idx: int = network_manager.local_player_index if network_manager != null else 0

	# Pause stack resolution on the host if a UI interaction arrives mid-action.
	# (On clients this is a no-op since _executing_stack_action is always false.)
	if _executing_stack_action and not _stack_resolution_paused:
		var p_idx: int = event_data.get("player_index", local_idx)
		var pause_player: Player = game_manager.players[p_idx] \
			if p_idx >= 0 and p_idx < game_manager.players.size() \
			else game_manager.current_player
		_pause_stack_resolution(pause_player)
	
	match type:
		"combat_retreat":
			var action_dict: Dictionary = payload.get("action", {})
			var action := CardAction.from_dict(action_dict, game_manager)
			var target_uid: String = payload.get("target_uid", "")
			var target = game_manager.get_card_by_uid(target_uid)
			if target == null:
				var p_idx: int = payload.get("target_player_index", -1)
				if p_idx >= 0 and p_idx < game_manager.players.size():
					target = game_manager.players[p_idx]
			_on_match_ui_interaction(local_idx, type, {"action": action, "target": target})
		"doorway_choice":
			var structure_uid: String = payload.get("structure_uid", "")
			var card_uid: String = payload.get("card_uid", "")
			var structure := game_manager.get_card_by_uid(structure_uid)
			var card := game_manager.get_card_by_uid(card_uid)
			_show_doorway_choice_prompt(
				structure, card, 
				payload.get("combat_death", false), 
				payload.get("destruction", false)
			)
		"resurrection":
			var card_uid: String = payload.get("card_uid", "")
			var card := game_manager.get_card_by_uid(card_uid)
			if card != null:
				_show_resurrection_prompt([card])
		"aphrodite_enslave":
			var god := game_manager.get_card_by_uid(payload.get("source_uid", "")) as AphroditeAreia
			if god != null:
				_show_aphrodite_prompt(god)
		"blessed_knights_ward":
			var card := game_manager.get_card_by_uid(payload.get("source_uid", "")) as BlessedKnights
			if card != null:
				_show_blessed_knights_prompt(card)
		"en_hedu_anna_exaltation":
			var card := game_manager.get_card_by_uid(payload.get("source_uid", "")) as EnHeduAnna
			if card != null:
				_show_en_hedu_anna_prompt(card)

func _apply_full_state(data: Dictionary) -> void:
	if _is_networked_client:
		# Client: clear stale card refs and rebuild ghost game_manager from server state
		_clear_network_selection_state()
		GameState.apply_to_manager(data.get("state", {}), game_manager)
		# Set feedback_viewer so client sees their own perspective
		if network_manager != null and network_manager.local_player_index >= 0:
			var local_idx: int = network_manager.local_player_index
			if local_idx < game_manager.players.size():
				game_manager.feedback_viewer = game_manager.players[local_idx]
	# Host has the live authoritative game_manager — no zone rebuild needed.
	# Show server's action message if any
	var msg: String = data.get("action_message", "")
	if msg != "":
		action_label.text = msg
		_capture_action_log_message(true)

	update_ui()
	_update_waiting_overlay()

func _update_waiting_status(is_waiting: bool, message: String = "Waiting for Opponent...") -> void:
	var panel = get_node_or_null("WaitingOverlay")
	if not is_waiting:
		if panel: panel.queue_free()
		return
	
	if panel == null:
		panel = ColorRect.new()
		panel.name = "WaitingOverlay"
		panel.color = Color(0, 0, 0, 0.3)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.z_index = 200
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(panel)
		_promote_transient_ui(panel)
		
		var label := Label.new()
		label.name = "WaitingLabel"
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		label.add_theme_stylebox_override("normal", style)
		panel.add_child(label)
	
	var lbl = panel.get_node("WaitingLabel")
	lbl.text = message

func _update_waiting_overlay() -> void:
	if _match_reconnect_waiting:
		_update_waiting_status(true, _match_reconnect_wait_message)
		return
	if not _is_networked_client:
		_update_waiting_status(false)
		return
		
	var local_idx = network_manager.local_player_index
	var current_priority_player := game_manager.priority_player
	var priority_idx := game_manager.players.find(current_priority_player)
	
	# If someone else has priority, we are waiting
	if priority_idx != -1 and priority_idx != local_idx:
		_update_waiting_status(true, "Opponent has priority...")
		return
		
	# If we are in combat and waiting for intercept
	if game_manager.current_phase == GameManager.GamePhase.COMBAT:
		# Check if we are the attacker and waiting for defender to intercept
		if selected_attacker != null and pending_attack_target != null:
			var defender: Player = pending_attack_target if pending_attack_target is Player else (pending_attack_target as Card).get_controller()
			if defender != null and game_manager.players.find(defender) != local_idx:
				_update_waiting_status(true, "Opponent is choosing interceptor...")
				return

	_update_waiting_status(false)

func _set_match_reconnect_wait(is_waiting: bool, message: String = "Waiting for opponent to reconnect...") -> void:
	_match_reconnect_waiting = is_waiting
	if is_waiting:
		_match_reconnect_wait_message = message
		_update_waiting_status(true, message)
		return
	_match_reconnect_wait_message = "Waiting for opponent to reconnect..."
	_update_waiting_status(false)

func _apply_priority_offered(data: Dictionary) -> void:
	var msg: String = data.get("action_message", "")
	if msg != "":
		action_label.text = msg
	_show_remote_priority_prompt(data.get("responses", []))

func _show_remote_priority_prompt(responses: Array) -> void:
	var panel = get_node_or_null("PriorityPromptPanel")
	if panel == null:
		panel = PanelContainer.new()
		panel.name = "PriorityPromptPanel"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
		style.border_color = Color(0.4, 0.7, 1.0)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			style.set_border_width(side, 2)
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size.x = 220
		add_child(panel)
		_promote_transient_ui(panel)
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.anchor_top = 0.5
		panel.anchor_bottom = 0.5
		panel.offset_left = -230
		panel.offset_right = -10
		panel.offset_top = -60

	for child in panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "You have priority"
	lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl)

	var pass_btn := Button.new()
	pass_btn.text = "Pass Priority"
	pass_btn.pressed.connect(func() -> void:
		_hide_priority_prompt()
		network_manager.request_action({type = "priority_pass"})
	)
	vbox.add_child(pass_btn)

	for response in responses:
		var rtype: String = response.get("response_type", "hex")
		var card_uid: String = response.get("card_uid", "")
		var target_uids: Array = response.get("target_uids", [])
		var resp_card := game_manager.get_card_by_uid(card_uid)
		if resp_card == null:
			continue
		var card_name: String = resp_card.card_name
		var btn := Button.new()
		btn.text = "Use " + card_name
		btn.pressed.connect(func() -> void:
			_hide_priority_prompt()
			if rtype == "hex":
				var target_is_attacker: bool = response.get("target_is_attacker", false)
				if target_uids.size() == 1:
					network_manager.request_action({
						type = "play_hex_response",
						hex_uid = card_uid,
						target_uid = target_uids[0],
						target_is_attacker = target_is_attacker,
					})
				elif target_uids.is_empty():
					network_manager.request_action({
						type = "play_hex_response",
						hex_uid = card_uid,
						target_uid = "",
						target_is_attacker = target_is_attacker,
					})
				else:
					var target_cards: Array[Card] = []
					for target_uid in target_uids:
						var c := game_manager.get_card_by_uid(target_uid as String)
						if c != null:
							target_cards.append(c)
					_show_card_selection_overlay(
						"Choose a target for " + card_name,
						target_cards,
						func(chosen_card: Card) -> void:
							network_manager.request_action({
								type = "play_hex_response",
								hex_uid = card_uid,
								target_uid = chosen_card.uid,
								target_is_attacker = target_is_attacker,
							})
					)
			elif rtype == "charm":
				var from_hand: bool = response.get("from_hand", false)
				if target_uids.size() == 1:
					network_manager.request_action({
						type = "play_charm_response",
						charm_uid = card_uid,
						target_uid = target_uids[0],
						from_hand = from_hand,
					})
				elif target_uids.is_empty():
					network_manager.request_action({
						type = "play_charm_response",
						charm_uid = card_uid,
						target_uid = "",
						from_hand = from_hand,
					})
				else:
					var target_cards: Array[Card] = []
					for target_uid in target_uids:
						var c := game_manager.get_card_by_uid(target_uid as String)
						if c != null:
							target_cards.append(c)
					_show_card_selection_overlay(
						"Choose a target for " + card_name,
						target_cards,
						func(chosen_card: Card) -> void:
							network_manager.request_action({
								type = "play_charm_response",
								charm_uid = card_uid,
								target_uid = chosen_card.uid,
								from_hand = from_hand,
							})
					)
		)
		vbox.add_child(btn)

	_promote_transient_ui(panel)
	panel.show()

func _apply_intercept_offered(data: Dictionary) -> void:
	var msg: String = data.get("action_message", "")
	if msg != "":
		action_label.text = msg
	_show_intercept_prompt(data.get("interceptor_uids", []))

func _show_intercept_prompt(interceptor_uids: Array) -> void:
	var panel = get_node_or_null("InterceptPromptPanel")
	if panel == null:
		panel = PanelContainer.new()
		panel.name = "InterceptPromptPanel"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
		style.border_color = Color(0.8, 0.4, 0.2)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			style.set_border_width(side, 2)
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size.x = 220
		add_child(panel)
		_promote_transient_ui(panel)
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.anchor_top = 0.5
		panel.anchor_bottom = 0.5
		panel.offset_left = -230
		panel.offset_right = -10
		panel.offset_top = -60

	for child in panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Intercept?"
	lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl)

	var no_btn := Button.new()
	no_btn.text = "No Intercept"
	no_btn.pressed.connect(func() -> void:
		_hide_intercept_prompt()
		network_manager.request_action({type = "intercept_decision", interceptor_uid = ""})
	)
	vbox.add_child(no_btn)

	for interceptor_uid in interceptor_uids:
		var card := game_manager.get_card_by_uid(interceptor_uid as String)
		if card == null:
			continue
		var card_name := card.card_name
		var captured_interceptor_uid: String = interceptor_uid as String
		var btn := Button.new()
		btn.text = "Intercept: " + card_name
		btn.pressed.connect(func() -> void:
			_hide_intercept_prompt()
			network_manager.request_action({type = "intercept_decision", interceptor_uid = captured_interceptor_uid})
		)
		vbox.add_child(btn)

	_promote_transient_ui(panel)
	panel.show()

func _hide_intercept_prompt() -> void:
	var panel = get_node_or_null("InterceptPromptPanel")
	if panel:
		panel.hide()

func _clear_network_selection_state() -> void:
	selected_card = null
	if match_manager != null:
		match_manager.selected_attacker = null
		match_manager.selected_interceptor = null
		match_manager.pending_attack_target = null
		match_manager.awaiting_spell_target = false
		match_manager.spell_waiting_for_target = null
		match_manager.spell_waiting_for_action = null
	placement_mode = ""
	if placement_container != null:
		placement_container.visible = false

# ---------------------------------------------------------------------------

func _on_forfeit_button_pressed() -> void:
	if _game_finished:
		return
	_set_match_reconnect_wait(false)
	if _is_blot_selection_active():
		_hide_blot_sacrifice_prompt()
	_dismiss_transient_prompts()
	_close_context_menu()
	_pending_move_card = null
	_pending_equip_actor = null
	_pending_equip_target = null
	_pending_equip_action = ""
	_queued_attackers.clear()
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	pending_attack_target = null
	placement_mode = ""
	placement_container.visible = false
	_clear_wolf_master_summon()
	action_label.text = "Game forfeited."
	match_session_cleared.emit()
	forfeit_requested.emit()

func _do_end_turn() -> void:
	if _game_finished:
		return
	print("=== TURN ENDED ===")
	_dismiss_transient_prompts()
	var end_turn_priority_owner := game_manager.current_player
	var resolve_end_turn := func() -> void:
		var et_cmd := {type = "end_turn"}
		if not _pending_end_turn_discard_uids.is_empty():
			et_cmd["discard_uids"] = _pending_end_turn_discard_uids.duplicate()
			_pending_end_turn_discard_uids.clear()
		game_input.submit_action(et_cmd)
		update_ui()
		if _is_networked_client:
			return  # Client waits for server to send upkeep_needed
		# GameEventBroadcaster sends upkeep_needed to the remote client via _on_turn_started.
		# Only open the window locally when it's still the host's (player 0) turn.
		var new_cp_idx: int = game_manager.players.find(game_manager.current_player)
		var is_remote_new_turn: bool = network_manager != null \
			and network_manager.get("is_server") == true \
			and new_cp_idx != 0
		if not is_remote_new_turn:
			call_deferred("_open_upkeep_choice_window")
	_queue_priority_event(
		"end_turn",
		null,
		0,
		resolve_end_turn,
		end_turn_priority_owner
	)

func _open_upkeep_choice_window() -> void:
	update_ui()
	show_turn_choice()
	action_label.text = "Upkeep for " + game_manager.current_player.player_name + ": choose your upkeep option."
	_maybe_prompt_turn_start_windows()

var _resurrection_panel: Control = null
var _resurrection_queue: Array[Card] = []

func _show_resurrection_prompt(candidates: Array[Card]) -> void:
	_resurrection_queue = candidates.duplicate()
	_next_resurrection_prompt()

var _pending_resurrection_card: Card = null

func _next_resurrection_prompt() -> void:
	if _resurrection_queue.is_empty():
		_do_end_turn()
		return
	var card: Card = _resurrection_queue.pop_front()
	_pending_resurrection_card = card
	# Build modal panel
	if _resurrection_panel and is_instance_valid(_resurrection_panel):
		_resurrection_panel.queue_free()
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 300
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_promote_transient_ui(overlay)
	_resurrection_panel = overlay

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(320, 0)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = card.card_name + " was destroyed!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	var body := Label.new()
	body.text = card.card_owner.player_name + ": pay 1 mana to resurrect in your reserve line?"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var mana_lbl := Label.new()
	mana_lbl.text = "%s's mana: %d" % [card.card_owner.player_name, card.card_owner.mana]
	mana_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_lbl.modulate = Color(0.6, 0.8, 1.0)
	vbox.add_child(mana_lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var yes_btn := Button.new()
	yes_btn.text = "Resurrect (1 mana)"
	yes_btn.pressed.connect(func() -> void: _on_resurrection_yes(card))
	hbox.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "No thanks"
	no_btn.pressed.connect(_on_resurrection_no)
	hbox.add_child(no_btn)

func _on_resurrection_yes(card: Card) -> void:
	if _resurrection_panel and is_instance_valid(_resurrection_panel):
		_resurrection_panel.queue_free()
	_resurrection_panel = null
	_pending_resurrection_card = null
	
	game_input.submit_action({"type": "resurrection_choice", "card_uid": card.uid, "confirm": true})

func _on_resurrection_no() -> void:
	var card := _pending_resurrection_card
	if _resurrection_panel and is_instance_valid(_resurrection_panel):
		_resurrection_panel.queue_free()
	_resurrection_panel = null
	_pending_resurrection_card = null
	
	if card != null:
		game_input.submit_action({"type": "resurrection_choice", "card_uid": card.uid, "confirm": false})

func _on_allow_ai_attack() -> void:
	pass

func _on_player_mana_changed(_new_mana: int) -> void:
	if game_manager and game_manager.current_player == player1:
		update_ui()

func _on_player_followers_changed(_new_followers: int) -> void:
	_request_ui_refresh()

func _on_enemy_followers_changed(_new_followers: int) -> void:
	_request_ui_refresh()

func _on_game_ended(winner: Player, loser: Player) -> void:
	_game_finished = true
	_set_match_reconnect_wait(false)
	choice_container.visible = false
	end_turn_button.visible = false
	placement_container.visible = false
	draw_button.disabled = true
	mana_button.disabled = true
	end_turn_button.disabled = true
	forfeit_button.disabled = true
	all_attack_btn.disabled = true
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	pending_attack_target = null
	placement_mode = ""
	action_label.text = winner.player_name + " wins the game! " + loser.player_name + " reached 0 followers." if winner != null and loser != null else "Game over!"
	match_session_cleared.emit()
	update_ui()

func _request_ui_refresh() -> void:
	if _ui_refresh_queued:
		return
	_ui_refresh_queued = true
	call_deferred("_flush_ui_refresh")

func _flush_ui_refresh() -> void:
	_ui_refresh_queued = false
	update_ui()

func _try_handle_blot_drag_selection(card: Card) -> bool:
	if card == null:
		return false
	return _try_add_creature_to_blot(card)

func _on_card_drag_released(card: Card, drop_pos: Vector2, card_rotated: bool, card_stealth: bool) -> void:
	if _game_finished:
		update_ui()
		return
	var priority_drop_allowed := game_manager != null and game_manager.can_card_respond_to_priority(card, game_manager.priority_player)
	if not priority_drop_allowed and _reject_priority_locked_action():
		update_ui()
		return
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		update_ui()
		return
	if _try_handle_blot_drag_selection(card):
		update_ui()
		return
	# Sacrifice-by-drag: creature card with sacrifice_cost dropped onto a friendly creature
	if card.card_type == Card.CardType.CREATURE and card.sacrifice_cost > 0:
		var blocked_target: Card = null
		for zu in _board_zone_uis:
			if not zu.get_global_rect().has_point(drop_pos):
				continue
			if zu._is_enemy or zu.zone.cards.size() == 0:
				continue
			var target: Card = zu.zone.cards[0]
			if target.get_controller() != game_manager.current_player or not _can_use_card_for_creature_sacrifice(target):
				blocked_target = target
				continue
			if card.get_effective_speed() == 1 and game_manager.current_player != card.card_owner:
				action_label.text = card.card_name + " cannot be played right now."
				update_ui()
				return
			if game_manager.current_player == card.card_owner and game_manager.current_player.has_summoned_this_turn:
				action_label.text = "You have already summoned a creature this turn."
				update_ui()
				return
			# Check only the remaining non-sacrifice costs here. The actual zone choice happens after the sacrifice.
			var orig := card.sacrifice_cost
			card.sacrifice_cost = 0
			var affordable := card.can_pay_costs(game_manager.current_player)
			card.sacrifice_cost = orig
			if not affordable:
				action_label.text = "Cannot afford " + card.card_name + "!"
				update_ui()
				return
			_awaiting_drag_sacrifice_zone = true
			_drag_sacrifice_card = card
			_drag_sacrifice_target = target
			_drag_sacrifice_mode = "stealth" if card_stealth else ("defensive" if card_rotated else "aggressive")
			action_label.text = "Choose an empty friendly zone to summon " + card.card_name + ". " + target.card_name + " will be sacrificed when you place it."
			update_ui()
			return
		if blocked_target != null:
			if blocked_target.card_type == Card.CardType.CREATURE and not blocked_target.is_god:
				action_label.text = blocked_target.card_name + " cannot be sacrificed for " + card.card_name + ". Choose another creature or an empty friendly zone first."
			else:
				action_label.text = "Drop " + card.card_name + " onto a sacrificable friendly creature, or onto an empty friendly zone first."
			update_ui()
			return

	# BlotSacrifice dropped onto an occupied friendly creature zone: auto-use that creature as sacrifice.
	if card is BlotSacrifice or card.card_name == "Blot Sacrifice":
		for zu in _board_zone_uis:
			if not zu.get_global_rect().has_point(drop_pos) or zu._is_enemy:
				continue
			if zu.zone.cards.is_empty():
				continue
			var target_creature: Card = zu.zone.cards[0]
			if not _can_use_card_for_creature_sacrifice(target_creature):
				continue
			if not game_manager.can_play_card(game_manager.current_player, card, null):
				action_label.text = "Cannot cast " + card.card_name + "!"
				return
			_initiate_blot_with_sacrifice(card, target_creature)
			update_ui()
			return

	# Non-targeted spell/hex dropped on any friendly zone (occupied or not):
	# find an empty zone and route through the normal cast/prepare flow there.
	if card.card_type in [Card.CardType.SPELL, Card.CardType.HEX] and not card.targets:
		for zu in _board_zone_uis:
			if zu.get_global_rect().has_point(drop_pos) and not zu._is_enemy:
				var empty_zone := _find_empty_player_zone()
				if empty_zone != null:
					_on_card_dropped_to_zone(card, empty_zone, card_rotated, card_stealth)
				else:
					action_label.text = "No empty zone available to place " + card.card_name + "!"
				update_ui()
				return

	# Creature dragged onto an empty friendly zone: resolve directly through the normal placement handler.
	if card.card_type == Card.CardType.CREATURE and not card.is_god:
		for zu in _board_zone_uis:
			if not zu.get_global_rect().has_point(drop_pos):
				continue
			if zu._is_enemy or zu.zone.cards.size() > 0:
				continue
			_on_card_dropped_to_zone(card, zu.zone, card_rotated, card_stealth)
			update_ui()
			return
		if board_container != null and board_container.get_global_rect().has_point(drop_pos):
			var nearest_zone := _find_nearest_empty_friendly_zone(drop_pos)
			if nearest_zone != null:
				_on_card_dropped_to_zone(card, nearest_zone, card_rotated, card_stealth)
				update_ui()
				return

	var drop_targets: Array[BoardZoneUI] = []
	drop_targets.append_array(_board_zone_uis)
	drop_targets.append_array(_enemy_zone_uis)
	if _player_god_zone_ui != null and is_instance_valid(_player_god_zone_ui):
		drop_targets.append(_player_god_zone_ui)
	if _enemy_god_zone_ui != null and is_instance_valid(_enemy_god_zone_ui):
		drop_targets.append(_enemy_god_zone_ui)

	for zu in drop_targets:
		if zu.get_global_rect().has_point(drop_pos) and zu.can_accept_card(card):
			_on_card_dropped_to_zone(card, zu.zone, card_rotated, card_stealth)
			update_ui()
			return
	update_ui()

func _cast_targeted_spell(spell: Card, target: Card) -> void:
	if _is_networked_client:
		var spell_uid: String = spell.get("uid") if "uid" in spell else ""
		var target_uid: String = target.get("uid") if target != null and "uid" in target else ""
		var cmd := {type = "cast_spell", spell_uid = spell_uid, target_uid = target_uid}
		if spell is Absence and target != null and (target.is_god or not (target is PowerCard) or (target as PowerCard).is_face_down):
			cmd["mode"] = "mute"
		# For unlocked powers, _show_absence_mode_prompt will add the mode
		# before submitting; skip submitting here so the prompt can run first
		if not (spell is Absence and target is PowerCard and not (target as PowerCard).is_face_down):
			game_input.submit_action(cmd)
			return
	var target_label := _get_target_label(target, game_manager.get_feedback_viewer(), target.card_name if target != null else "target")
	var source_label := _get_attack_card_label(spell, spell.card_name if spell != null else "Spell")
	if spell is Absence and target != null and target.is_god:
		_queue_hand_spell_cast(
			spell,
			target,
			source_label + " is targeting " + target_label + ".",
			func() -> void:
				(spell as Absence).apply_to_power(target, "mute", game_manager)
		)
		return
	if spell is Absence and target is PowerCard and not (target as PowerCard).is_face_down:
		_show_absence_mode_prompt(spell as Absence, target)
		return
	_queue_hand_spell_cast(
		spell,
		target,
		source_label + " is targeting " + target_label + ".",
		func() -> void:
			(spell as SpellCard).resolve(game_manager, target)
	)

func _notify_and_consume_hand_spell(spell: Card) -> void:
	game_manager.notify_spell_played(spell.card_owner, spell)
	_send_used_hand_card_to_graveyard(spell)

func _on_card_dropped_to_zone(card: Card, zone: Zone, is_rotated: bool = false, is_stealth: bool = false) -> void:
	if _game_finished:
		return
	var priority_drop_allowed := game_manager != null and game_manager.can_card_respond_to_priority(card, game_manager.priority_player)
	if not priority_drop_allowed and _reject_priority_locked_action():
		return
	_pending_spell_display_zone = zone
	var prepare_from_selected_mode := card == selected_card and placement_mode == "prepare_spell"
	var prepare_on_drop := prepare_from_selected_mode \
		or (card.card_type == Card.CardType.HEX and not card.targets) \
		or (is_stealth and (card.card_type == Card.CardType.SPELL or card is CharmCard))
	if prepare_on_drop:
		if zone == null or not zone.is_board_zone() or zone.zone_owner != game_manager.current_player or zone.cards.size() > 0:
			action_label.text = "Choose an empty friendly zone to prepare " + card.card_name + "."
			update_ui()
			return
		if not game_manager.can_prepare_card(game_manager.current_player, card, zone):
			action_label.text = "Cannot prepare " + card.card_name + "!"
			update_ui()
			return
		game_input.submit_action({type = "prepare_card", card_uid = card.uid,
				player_index = game_manager.players.find(zone.zone_owner),
				zone_type = zone.zone_type, zone_index = zone.zone_index})
		_pending_spell_display_zone = null
		action_label.text = "Prepared " + _get_stack_card_type_label(card) + ": " + card.card_name + " (face-down)!"
		selected_card = null
		placement_mode = ""
		placement_container.visible = false
		update_ui()
		return
	if card is BitMeseri:
		if zone.cards.size() > 0:
			_cast_targeted_spell(card, zone.cards[0])
		return
	if card is PermanentHexCard and zone.cards.size() > 0:
		var permanent_hex := card as PermanentHexCard
		var dropped_target := zone.get_creature()
		if dropped_target != null and permanent_hex.can_play_to_target(game_manager, dropped_target):
			_pending_drop_zone = null
			_resolve_hand_permanent_hex_target(permanent_hex, dropped_target)
		else:
			selected_card = permanent_hex
			action_label.text = permanent_hex.card_name + " must target a creature."
			update_ui()
		return
	if card is Absence:
		if zone.cards.size() > 0 and (zone.cards[0] is PowerCard or zone.cards[0].is_god):
			_cast_targeted_spell(card, zone.cards[0])
		else:
			selected_card = card
			_prompt_absence_target_selection()
		return
	if card is CharmCard and (card as CharmCard).targets:
		var charm := card as CharmCard
		var source_action: CardAction = game_manager.action_stack.back() if priority_drop_allowed and game_manager != null and not game_manager.action_stack.is_empty() else null
		if zone.cards.size() > 0 and charm.is_valid_target(zone.cards[0]):
			_queue_charm_action(charm, source_action, zone.cards[0])
		else:
			selected_card = charm
			_prompt_charm_target_selection(charm, source_action, zone)
		return
	selected_card = card
	for vc in _hand_visual_cards:
		vc.set_highlighted(vc.card_data == card)
	if card.card_type == Card.CardType.CREATURE:
		if is_stealth:
			placement_mode = "stealth"
		else:
			placement_mode = "defensive" if is_rotated else "aggressive"
		_pending_drop_zone = null
		_try_play_selected_creature_to_zone(zone)
		return
	else:
		_pending_drop_zone = null
		_on_empty_zone_pressed(zone)



func cleanup() -> void:
	_set_match_reconnect_wait(false)
	_current_match_info.clear()
	_hide_skoll_prompt()
	_pending_skoll_prompts.clear()
	_clear_skoll_upkeep_summon()
	_clear_wolf_master_summon()
	if game_manager:
		game_manager.set_interaction_host(null)
		game_manager = null
