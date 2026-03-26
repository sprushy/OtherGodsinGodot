extends Control
class_name CombatMockGame

class TargetLineOverlay extends Control:
	var game_view = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if game_view == null or not is_instance_valid(game_view):
			return
		game_view._draw_target_lines(self)

signal forfeit_requested

var player1: Player
var player2: Player
var selected_card: Card = null
var selected_attacker: Card = null
var selected_interceptor: Card = null
var pending_attack_target = null
var placement_mode: String = ""
var awaiting_spell_target: bool = false
var spell_waiting_for_target: Card = null
var spell_waiting_for_action: CardAction = null
var spell_waiting_for_display_zone: Zone = null
var _pending_paid_hand_card: Card = null
var _pending_paid_hand_display_zone: Zone = null
var _pending_paid_hand_display_zone_auto: bool = false
var _pending_spell_display_zone: Zone = null
var _pending_click_selection_name: String = ""
var _pending_click_selection_source: Card = null
var _pending_click_selection_validator: Callable = Callable()
var _pending_click_selection_confirm: Callable = Callable()
var _pending_click_selection_cancel: Callable = Callable()
var auto_priority: bool = true
var _fan_container: Control = null

const FAN_ROT_MAX     := 12.0   # degrees at the outermost card
const FAN_ARC_HEIGHT  := 22.0   # px the arc dips at centre
const FAN_CARD_SPACING := 130   # px between card pivot centres
const STACK_LINGER_SECONDS := 0.6

@onready var choice_container = $MainHBox/LeftPanel/ChoiceContainer
@onready var draw_button = $MainHBox/LeftPanel/ChoiceContainer/DrawButton
@onready var mana_button = $MainHBox/LeftPanel/ChoiceContainer/ManaButton
@onready var end_turn_button = $MainHBox/RightPanel/EndTurnButton
@onready var forfeit_button = $ForfeitButton
@onready var all_attack_btn = $MainHBox/RightPanel/AllAttackBtn
@onready var turn_label = $MainHBox/RightPanel/TurnLabel
@onready var stats_container = $MainHBox/RightPanel/StatsContainer
@onready var hand_container = $MainHBox/CenterPanel/HandContainer
@onready var board_container = $MainHBox/CenterPanel/BoardContainer
@onready var enemy_board_container = $MainHBox/CenterPanel/EnemyBoardContainer
@onready var action_label = $MainHBox/LeftPanel/ActionLabel
@onready var placement_container = $MainHBox/LeftPanel/PlacementContainer
@onready var aggressive_stance_btn = $MainHBox/LeftPanel/PlacementContainer/AggressiveStanceBtn
@onready var defensive_stance_btn = $MainHBox/LeftPanel/PlacementContainer/DefensiveStanceBtn
@onready var stealth_mode_btn = $MainHBox/LeftPanel/PlacementContainer/StealthModeBtn

var game_manager: GameManager

# Visual UI state
var _hand_visual_cards: Array = []   # Array[VisualCard]
var _board_zone_uis: Array = []      # Array[BoardZoneUI]
var _enemy_zone_uis: Array = []      # Array[BoardZoneUI]
var _enemy_god_zone_ui: BoardZoneUI = null
var _player_god_zone_ui: BoardZoneUI = null
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
var _breidablik_panel: Control = null
var _divine_caprice_panel: Control = null
var _pending_divine_caprice_power: DivineCaprice = null
var _pending_divine_caprice_selected_zone: Zone = null
var _pending_divine_caprice_plan: Array[Dictionary] = []
var _pending_divine_caprice_virtual_slots: Dictionary = {}
var _pending_hand_summon_events: Array[Card] = []
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
var _target_line_overlay: TargetLineOverlay = null

const TRANSIENT_UI_Z_INDEX := 1000

func _is_turn_choice_pending() -> bool:
	return choice_container.visible

func _can_activate_before_turn_choice(card: Card) -> bool:
	if card == null:
		return false
	if card.get_controller() != game_manager.current_player:
		return false
	if card is CharmCard:
		return (card as CharmCard).can_activate_prepared(game_manager)
	if card is Breidablik:
		return (card as Breidablik).can_return_priest(game_manager)
	if not card.is_prepared:
		return false
	if card.card_type == Card.CardType.CREATURE:
		return false
	return card.get_effective_speed() > 1

func _reject_pre_turn_action() -> void:
	action_label.text = "Choose draw or mana before taking actions. Only prepared fast cards can be used first."

func _promote_transient_ui(control: Control, z_index: int = TRANSIENT_UI_Z_INDEX) -> void:
	if control == null:
		return
	control.top_level = true
	control.z_index = z_index
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
	if _executing_stack_action and not _stack_resolution_paused:
		_pause_stack_resolution(structure.card_owner if structure != null else game_manager.current_player)
	_show_doorway_choice_prompt(structure, card, combat_death, destruction)

func _ready() -> void:
	add_to_group("combat_mock_game")
	choice_container.visible = false
	end_turn_button.visible = false
	placement_container.visible = false

	draw_button.pressed.connect(_on_draw_button_pressed)
	mana_button.pressed.connect(_on_mana_button_pressed)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	forfeit_button.pressed.connect(_on_forfeit_button_pressed)
	all_attack_btn.pressed.connect(_on_all_attack_followers_pressed)
	aggressive_stance_btn.pressed.connect(_on_aggressive_stance_pressed)
	defensive_stance_btn.pressed.connect(_on_defensive_stance_pressed)
	stealth_mode_btn.pressed.connect(_on_stealth_mode_pressed)

	var priority_toggle := CheckButton.new()
	priority_toggle.text = "Auto Priority"
	priority_toggle.button_pressed = auto_priority
	priority_toggle.toggled.connect(func(on: bool) -> void: auto_priority = on)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	$MainHBox/RightPanel.add_child(spacer)
	$MainHBox/RightPanel.add_child(priority_toggle)
	$MainHBox/RightPanel.move_child(spacer, $MainHBox/RightPanel.get_child_count() - 2)

	_target_line_overlay = TargetLineOverlay.new()
	_target_line_overlay.game_view = self
	add_child(_target_line_overlay)
	_target_line_overlay.z_index = TRANSIENT_UI_Z_INDEX + 50
	_target_line_overlay.move_to_front()

func start_game() -> void:
	print("=== STARTING COMBAT MOCK GAME ===")
	_game_finished = false
	
	game_manager = GameManager.new()
	add_child(game_manager)
	
	player1 = Player.new()
	player1.player_name = "Player 1"
	game_manager.add_child(player1)
	
	player2 = Player.new()
	player2.player_name = "Player 2"
	game_manager.add_child(player2)
	
	await get_tree().process_frame
	
	create_deck(player1)
	create_deck(player2)

	# Place Baldr as Player 1's god
	var baldr := Baldr.new()
	baldr.card_owner = player1
	player1.god_zone.add_card(baldr)

	# Place Mummu as Player 2's god
	var mummu := Mummu.new()
	mummu.card_owner = player2
	player2.god_zone.add_card(mummu)

	game_manager.setup_game()
	if not game_manager.doorway_choice_requested.is_connected(_on_doorway_choice_requested):
		game_manager.doorway_choice_requested.connect(_on_doorway_choice_requested)

	# Place Ananke's Binding in player 1's first power slot
	var ananke := AnankesBinding.new()
	ananke.card_owner = player1
	ananke.is_face_down = false
	player1.power_zones[0].add_card(ananke)

	# Place a BeardedAxe in empty reserve zones to test equipment mechanics
	var axe1 := BeardedAxe.new()
	axe1.card_owner = player1
	player1.reserve_zones[3].add_card(axe1)

	var axe2 := BeardedAxe.new()
	axe2.card_owner = player2
	player2.reserve_zones[3].add_card(axe2)

	player1.mana_changed.connect(_on_player_mana_changed)
	player1.followers_changed.connect(_on_player_followers_changed)
	player2.followers_changed.connect(_on_enemy_followers_changed)
	game_manager.game_ended.connect(_on_game_ended)
	if not player1.card_moved.is_connected(_on_local_player_card_moved):
		player1.card_moved.connect(_on_local_player_card_moved)
	if not player2.card_moved.is_connected(_on_local_player_card_moved):
		player2.card_moved.connect(_on_local_player_card_moved)
	
	player1.gain_mana(20)
	player2.gain_mana(20)
	
	print("Drawing initial hands...")
	for i in range(5):
		print("Ã‚Â  Drawing card ", i, " for P1")
		player1.draw_card()
		print("Ã‚Â  P1 hand size now: ", player1.hand_zone.cards.size())
		print("Ã‚Â  Drawing card ", i, " for P2")
		player2.draw_card()
		print("Ã‚Â  P2 hand size now: ", player2.hand_zone.cards.size())
	
	
	game_manager.turn_number = 0
	update_ui()
	show_turn_choice()

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
	draw_button.disabled = false
	mana_button.disabled = false
	placement_container.visible = false

	for vc in _hand_visual_cards:
		vc.set_disabled(true)

func hide_turn_choice() -> void:
	if _game_finished:
		return
	choice_container.visible = false
	end_turn_button.visible = true

	for vc in _hand_visual_cards:
		vc.set_disabled(false)

func update_ui() -> void:
	_hide_power_hover_popup()
	_sync_blot_sacrifice_prompt_state()
	var current = game_manager.turn_player if game_manager.turn_player != null else game_manager.current_player

	turn_label.text = "Turn " + str(game_manager.turn_number) + " - " + current.player_name + "'s Turn"
	
	draw_hand()
	draw_board()
	draw_enemy_board()
	_sync_stack_zone_previews()
	if _target_line_overlay != null and is_instance_valid(_target_line_overlay):
		_target_line_overlay.queue_redraw()

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

func _get_zone_ui_center(zone_ui: BoardZoneUI) -> Vector2:
	if zone_ui == null or not is_instance_valid(zone_ui):
		return Vector2.ZERO
	return _to_overlay_point(zone_ui.get_visual_anchor_global())

func _to_overlay_point(global_point: Vector2) -> Vector2:
	if _target_line_overlay == null or not is_instance_valid(_target_line_overlay):
		return global_point - global_position
	return _target_line_overlay.get_global_transform().affine_inverse() * global_point

func _get_target_line_end(action: CardAction) -> Vector2:
	if action == null:
		return Vector2.ZERO
	if action.target is Card:
		var target_card := action.target as Card
		if target_card != null and target_card.current_zone != null:
			var target_zone_ui := _get_zone_ui_for_zone(target_card.current_zone)
			if target_zone_ui != null and is_instance_valid(target_zone_ui):
				return _get_zone_ui_center(target_zone_ui)
	return Vector2.ZERO

func _draw_target_lines(overlay: Control) -> void:
	if game_manager == null:
		return
	for action in game_manager.action_stack:
		if action == null or action.display_zone == null or not (action.target is Card):
			continue
		var source_zone_ui := _get_zone_ui_for_zone(action.display_zone)
		if source_zone_ui == null or not is_instance_valid(source_zone_ui):
			continue
		var from_point := _get_zone_ui_center(source_zone_ui)
		var to_point := _get_target_line_end(action)
		if to_point == Vector2.ZERO:
			continue
		overlay.draw_line(from_point, to_point, Color(1.0, 0.92, 0.3, 0.98), 5.0, true)
		overlay.draw_circle(to_point, 7.0, Color(1.0, 0.92, 0.3, 0.98))

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
	if game_manager == null:
		return null
	if not game_manager.action_stack.is_empty() and game_manager.priority_player != null:
		return game_manager.priority_player
	return game_manager.current_player

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

func draw_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	_hand_visual_cards.clear()
	var hand_player := _get_visible_hand_player()
	if hand_player == null:
		return
	var blot_valid_choices: Array[Card] = []
	if _is_blot_selection_active():
		blot_valid_choices = _get_blot_valid_choices(_pending_blot_spell)

	# Small gap between board and hand
	var top_gap := Control.new()
	top_gap.custom_minimum_size = Vector2(0, 6)
	hand_container.add_child(top_gap)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hand_container.add_child(hbox)

	var label := Label.new()
	label.text = hand_player.player_name + "\nHand:"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(label)

	_fan_container = Control.new()
	_fan_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fan_container.custom_minimum_size = Vector2(0, 130)
	_fan_container.clip_contents = false
	hbox.add_child(_fan_container)

	for card in hand_player.hand_zone.cards:
		if _should_hide_hand_card(card):
			continue
		var vc := VisualCard.new()
		_fan_container.add_child(vc)
		vc.setup(card, 180, 0)
		vc.set_waiting_on_priority(_is_card_waiting_on_priority(card))
		vc.set_priority_response_available(_is_card_usable_for_priority(card))
		vc.set_blot_summon_state(card in blot_valid_choices, card in _pending_blot_selected_creatures)
		vc.card_clicked.connect(_on_hand_card_pressed)
		vc.card_right_clicked.connect(_on_hand_card_right_clicked)
		vc.card_drag_released.connect(_on_card_drag_released)
		_hand_visual_cards.append(vc)

	call_deferred("_layout_fan")

func _layout_fan() -> void:
	if not _fan_container or not is_instance_valid(_fan_container):
		return
	var cards := _hand_visual_cards
	var n := cards.size()
	if n == 0:
		return
	# Total span of card pivots; clamp so they fit in the container width
	var container_w: float = _fan_container.size.x
	var spacing: float = FAN_CARD_SPACING if n == 1 else min(float(FAN_CARD_SPACING), (container_w - 180.0) / float(max(n - 1, 1)))
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

func _make_zone_info_panel(label_text: String, zone: Zone, clickable: bool, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(165, 110)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	style.bg_color = color.darkened(0.4)
	style.border_color = color
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = label_text + ": " + str(zone.cards.size()) + " cards"

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	var count_lbl := Label.new()
	count_lbl.text = str(zone.cards.size())
	count_lbl.add_theme_font_size_override("font_size", 20)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(count_lbl)

	if clickable:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_show_zone_contents(label_text, zone)
		)

	return panel

func _make_stats_panel(player: Player, show_mana: bool = true) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 128)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	return panel

func _make_god_cluster(zone: Zone, player: Player, is_enemy: bool) -> Control:
	var cluster := Control.new()
	cluster.custom_minimum_size = Vector2(BoardZoneUI.ZONE_WIDTH, BoardZoneUI.ZONE_HEIGHT)
	cluster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cluster.clip_contents = false

	var god_wrapper := Control.new()
	god_wrapper.custom_minimum_size = Vector2(BoardZoneUI.ZONE_WIDTH, BoardZoneUI.ZONE_HEIGHT)
	god_wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	god_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cluster.add_child(god_wrapper)

	var god_zone_ui := BoardZoneUI.new()
	god_zone_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	god_wrapper.add_child(god_zone_ui)
	god_zone_ui.setup(zone, game_manager, player, -1, _on_card_dropped_to_zone, is_enemy, "God")

	var stats_panel := _make_stats_panel(player, true)
	stats_panel.custom_minimum_size = Vector2(102, BoardZoneUI.ZONE_HEIGHT)
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

func _show_power_hover_popup(source: Control, text: String) -> void:
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
	popup.z_index = 250

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(220, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.98))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(label)

	popup.top_level = true
	get_tree().current_scene.add_child(popup)
	_promote_transient_ui(popup)
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

func _make_power_icon(card: Card, is_enemy: bool, player: Player) -> Control:
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
	var mute_suffix := "\nMuted for %d more turn(s)." % power.mute_turns_remaining if power != null and power.is_muted and power.mute_turns_remaining > 0 else ""
	var hover_text := card.card_name + "\n" + card.ability_text + mute_suffix
	var can_show_hover := not (is_enemy and card.is_face_down and not ((power != null and power.is_publicly_revealed) or card.is_temporarily_revealed()))
	if can_show_hover:
		panel.mouse_entered.connect(func() -> void:
			_show_power_hover_popup(panel, hover_text)
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
			label_text = str(card.mana_cost) + " Cost"
		else:
			var unlocked := not card.is_face_down
			style.bg_color = Color(0.12, 0.08, 0.18, 0.85) if unlocked else Color(0.05, 0.05, 0.10, 0.85)
			style.border_color = Color(0.55, 0.3, 0.8) if unlocked else Color(0.25, 0.2, 0.35)
			panel.add_theme_stylebox_override("panel", style)
			label_text = "?" if not unlocked else "Active"
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

	var unlocked := not card.is_face_down
	var activatable := power != null and power.can_activate(game_manager)
	var can_unlock_now := power != null and power.can_unlock(game_manager)

	if unlocked and activatable:
		style.bg_color = Color(0.18, 0.14, 0.06, 0.92)
		style.border_color = Color(0.95, 0.78, 0.2)
	elif unlocked:
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
	if not unlocked:
		lbl.text = str(card.mana_cost) + " Cost"
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
	if awaiting_god_ability_target and god_ability_source != null:
		if god_ability_source.has_method("is_valid_activation_target") and god_ability_source.is_valid_activation_target(power):
			var source_god := god_ability_source
			var was_immune := game_manager.is_immune_to_source(power, source_god)
			god_ability_source.activate(game_manager, power)
			awaiting_god_ability_target = false
			god_ability_source = null
			action_label.text = _consume_resolution_feedback(power.card_name + " is immune to " + source_god.card_name + "." if was_immune else "God ability resolved.")
			update_ui()
		else:
			_cancel_pending_target_selection(
				_get_pending_target_selection_name()
				+ " cancelled: invalid target "
				+ _get_card_name_safe(power, "selected")
				+ "."
			)
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
		power.unlock(game_manager)
		action_label.text = power.card_name + " unlocked!"
		update_ui()
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
				func(chosen: Card) -> void:
					_queue_magical_action(
						CardAction.Type.ABILITY,
						allfather,
						chosen,
						allfather.card_name + " activated! Chose " + chosen.card_name + ".",
						func() -> void:
							allfather.activate(game_manager, chosen)
					)
			)
		elif power is AnankesBinding:
			var ananke := power as AnankesBinding
			_show_card_selection_overlay(
				"Choose a Card to Bind",
				ananke.get_cards_in_deck(),
				func(chosen: Card) -> void:
					_queue_magical_action(
						CardAction.Type.ABILITY,
						ananke,
						chosen,
						ananke.card_name + " bound " + chosen.card_name + ".",
						func() -> void:
							ananke.activate(game_manager, chosen)
					)
			)
		elif power is BerserkerMead:
			var mead := power as BerserkerMead
			_show_card_selection_overlay(
				"Choose a Norse Creature for Berserker Mead",
				mead.get_valid_targets(game_manager),
				func(chosen: Card) -> void:
					_queue_magical_action(
						CardAction.Type.ABILITY,
						mead,
						chosen,
						mead.card_name + " empowers " + chosen.card_name + ".",
						func() -> void:
							mead.activate(game_manager, chosen)
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
				func(chosen: Card) -> void:
					_queue_magical_action(
						CardAction.Type.ABILITY,
						power,
						chosen,
						power.card_name + " targeted " + chosen.card_name + ".",
						func() -> void:
							power.activate(game_manager, chosen)
					)
			)
		else:
			_queue_magical_action(
				CardAction.Type.ABILITY,
				power,
				null,
				power.card_name + " activated!",
				func() -> void:
					power.activate(game_manager)
			)
	else:
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
				func(chosen: Card) -> void:
					_queue_magical_action(
						CardAction.Type.ABILITY,
						power,
						chosen,
						power.card_name + " shelters " + chosen.card_name + ".",
						func() -> void:
							power.activate(game_manager, chosen)
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
				func(chosen: Card) -> void:
					_queue_magical_action(
						CardAction.Type.ABILITY,
						power,
						chosen,
						power.card_name + " returns " + chosen.card_name + ".",
						func() -> void:
							power.return_priest(game_manager, chosen)
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
	var hidden := main_card.is_face_down or main_card.is_prepared or main_card.is_stealth
	if main_card is PowerCard and (main_card as PowerCard).is_face_down and not (main_card as PowerCard).is_publicly_revealed and not main_card.is_temporarily_revealed():
		hidden = true
	var name_text := "Hidden card" if hidden else main_card.card_name
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
	panel.offset_left = -270
	panel.offset_right = 270
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
	grid.columns = 4
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
	if _get_paid_hand_card_display_zone(spell) == null:
		if not _can_cast_hand_spell(spell):
			action_label.text = "Cannot cast " + spell.card_name + "!"
			update_ui()
			return
		if not spell.pay_costs(spell.card_owner, game_manager):
			action_label.text = "Cannot afford " + spell.card_name + "!"
			update_ui()
			return
		_begin_paid_hand_card_preview(spell)
	_show_card_selection_overlay(
		"Choose a Power or God Ability for Absence",
		targets,
		func(chosen: Card) -> void:
			_cast_targeted_spell(spell, chosen)
	)

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
		vc.set_disabled(true)
		vc.modulate.a = 1.0
		hbox.add_child(vc)

	# Clicking anywhere on the overlay closes it
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_dismiss_zone_overlay()
	)

func _show_card_selection_overlay(title_text: String, cards: Array[Card], on_selected: Callable, on_cancel: Callable = Callable()) -> void:
	if cards.is_empty():
		action_label.text = title_text + ": no valid cards."
		return

	_dismiss_zone_overlay()
	_overlay_card_selected = on_selected
	_overlay_card_dismissed = on_cancel

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

	for card in cards:
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
		vc.set_disabled(true)
		vc.modulate.a = 1.0
		wrapper.add_child(vc)

		var captured := card
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

func _get_attack_card_label(card: Card, fallback: String = "Card") -> String:
	if card == null:
		return fallback
	var controller := card.get_controller()
	if controller != null and controller.player_name != "":
		return controller.player_name + "'s " + card.get_display_name()
	var owner := card.card_owner
	if owner != null and owner.player_name != "":
		return owner.player_name + "'s " + card.get_display_name()
	return card.get_display_name()

func _has_pending_target_selection() -> bool:
	return _has_pending_click_selection() \
		or awaiting_spell_target \
		or awaiting_god_ability_target \
		or awaiting_stupefy_target \
		or awaiting_pyre_target \
		or awaiting_anointing_target

func _get_pending_target_selection_name() -> String:
	if _has_pending_click_selection():
		return _pending_click_selection_name
	if awaiting_pyre_target and pyre_source != null:
		return pyre_source.card_name + ": Ritual Flame"
	if awaiting_anointing_target and anointing_source != null:
		return anointing_source.card_name
	if awaiting_god_ability_target and god_ability_source != null:
		return god_ability_source.card_name
	if awaiting_stupefy_target and stupefy_source != null:
		return stupefy_source.card_name + ": Stupefy"
	if awaiting_spell_target and spell_waiting_for_target != null:
		return spell_waiting_for_target.card_name
	return "Target selection"

func _cancel_pending_target_selection(reason: String) -> bool:
	if not _has_pending_target_selection():
		return false
	var paid_preview_card := _pending_paid_hand_card
	var should_fizzle_paid_preview := paid_preview_card != null and (
		paid_preview_card == _pending_click_selection_source
		or paid_preview_card == spell_waiting_for_target
	)
	var click_cancel_callback := _pending_click_selection_cancel
	var had_pending_click_selection := _has_pending_click_selection()
	_clear_pending_click_selection()
	awaiting_spell_target = false
	spell_waiting_for_target = null
	spell_waiting_for_action = null
	spell_waiting_for_display_zone = null
	awaiting_god_ability_target = false
	god_ability_source = null
	awaiting_stupefy_target = false
	stupefy_source = null
	awaiting_pyre_target = false
	pyre_source = null
	awaiting_anointing_target = false
	anointing_source = null
	selected_card = null
	if had_pending_click_selection and click_cancel_callback.is_valid():
		click_cancel_callback.call()
	if should_fizzle_paid_preview and paid_preview_card != null:
		_clear_paid_hand_card_preview(paid_preview_card)
		_send_used_hand_card_to_graveyard(paid_preview_card)
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
		name: String,
		source_card: Card,
		validator: Callable,
		confirm_callback: Callable,
		cancel_callback: Callable = Callable()
) -> void:
	_pending_click_selection_name = name
	_pending_click_selection_source = source_card
	_pending_click_selection_validator = validator
	_pending_click_selection_confirm = confirm_callback
	_pending_click_selection_cancel = cancel_callback

func _clear_pending_click_selection() -> void:
	_pending_click_selection_name = ""
	_pending_click_selection_source = null
	_pending_click_selection_validator = Callable()
	_pending_click_selection_confirm = Callable()
	_pending_click_selection_cancel = Callable()

func _has_pending_click_selection() -> bool:
	return _pending_click_selection_confirm.is_valid()

func _try_handle_pending_click_selection(clicked_card: Card) -> bool:
	if not _has_pending_click_selection():
		return false
	if clicked_card == null:
		return true
	if _pending_click_selection_validator.is_valid() and not bool(_pending_click_selection_validator.call(clicked_card)):
		return false
	var confirm_callback := _pending_click_selection_confirm
	_clear_pending_click_selection()
	confirm_callback.call(clicked_card)
	return true

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

func _can_cast_hand_spell(spell: Card) -> bool:
	return spell != null \
		and game_manager != null \
		and spell.card_owner != null \
		and game_manager.can_play_card(spell.card_owner, spell, null)

func _pay_hand_card_costs(card: Card, custom_pay_callback: Callable = Callable()) -> bool:
	if card == null or game_manager == null or card.card_owner == null:
		return false
	if custom_pay_callback.is_valid():
		return bool(custom_pay_callback.call())
	return card.pay_costs(card.card_owner, game_manager)

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
	initial_priority_player: Player = null
) -> void:
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = game_manager.current_player
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
	if from_hand and _get_paid_hand_card_display_zone(charm) == null:
		if not charm.can_activate_from_hand(game_manager, triggering_action):
			action_label.text = charm.card_name + " cannot be played right now."
			update_ui()
			return
		if not charm.pay_costs(charm.card_owner, game_manager):
			action_label.text = "Cannot afford " + charm.card_name + "!"
			update_ui()
			return
		resolved_display_zone = _begin_paid_hand_card_preview(charm, resolved_display_zone)
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
		var target_name := _get_card_name_safe(target, "target", game_manager.current_player, "a hidden card")
		action.resolution_text = charm.card_name + " targeted " + target_name + "."
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
		var stack_target_name := _get_card_name_safe(target, "target", game_manager.get_feedback_viewer(), "a hidden card")
		action_label.text = charm.card_name + " targets " + stack_target_name + " and goes on the stack."
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
	if card.card_type != Card.CardType.CREATURE or card.is_god:
		return
	if from_zone.zone_type != Zone.ZoneType.HAND:
		return
	if not to_zone.is_board_zone():
		return
	if card.is_face_down:
		return
	if card in _pending_hand_summon_events:
		return
	_pending_hand_summon_events.append(card)
	call_deferred("_flush_hand_summon_priority_events")

func _flush_hand_summon_priority_events() -> void:
	if _pending_hand_summon_events.is_empty():
		return
	if game_manager == null or not game_manager.action_stack.is_empty():
		call_deferred("_flush_hand_summon_priority_events")
		return
	var summoned_card: Card = _pending_hand_summon_events.pop_front()
	if summoned_card == null or summoned_card.current_zone == null or not summoned_card.current_zone.is_board_zone():
		call_deferred("_flush_hand_summon_priority_events")
		return
	_queue_priority_event(
		"hand_summon",
		summoned_card,
		summoned_card.get_effective_speed(),
		func() -> void:
			update_ui()
			action_label.text = summoned_card.card_name + " was summoned from hand."
			if not _pending_hand_summon_events.is_empty():
				call_deferred("_flush_hand_summon_priority_events")
	)

func draw_board() -> void:
	for child in board_container.get_children():
		child.queue_free()
	_board_zone_uis.clear()
	board_container.add_theme_constant_override("separation", 0)

	var board_row := HBoxContainer.new()
	board_row.add_theme_constant_override("separation", 4)
	board_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_container.add_child(board_row)

	for i in range(2):
		var power_zone := game_manager.current_player.power_zones[i]
		var pzu := BoardZoneUI.new()
		board_row.add_child(pzu)
		pzu.setup(power_zone, game_manager, game_manager.current_player, i, _on_card_dropped_to_zone, false, "power")
		pzu.card_clicked.connect(func(card: Card) -> void:
			if card is PowerCard:
				_on_power_pressed(card as PowerCard)
		)
		_board_zone_uis.append(pzu)

	for i in range(game_manager.current_player.frontline_zones.size()):
		var zone = game_manager.current_player.frontline_zones[i]
		var zu := BoardZoneUI.new()
		board_row.add_child(zu)
		zu.setup(zone, game_manager, game_manager.current_player, i, _on_card_dropped_to_zone, false, "front line")
		zu.zone_clicked.connect(_on_empty_zone_pressed)
		zu.card_clicked.connect(_on_board_card_pressed)
		zu.creature_drag_started.connect(_on_creature_drag_started)
		zu.creature_right_clicked.connect(_on_creature_right_clicked)
		_board_zone_uis.append(zu)

	board_row.add_child(_make_zone_info_panel("Grave", game_manager.current_player.graveyard_zone, true, Color(0.3, 0.5, 0.3)))

	var reserve_row := HBoxContainer.new()
	reserve_row.add_theme_constant_override("separation", 4)
	reserve_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reserve_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_container.add_child(reserve_row)
	reserve_row.add_child(_make_god_cluster(game_manager.current_player.god_zone, game_manager.current_player, false))

	var reserve_power_zone := game_manager.current_player.power_zones[2]
	var rpzu := BoardZoneUI.new()
	reserve_row.add_child(rpzu)
	rpzu.setup(reserve_power_zone, game_manager, game_manager.current_player, 2, _on_card_dropped_to_zone, false, "power")
	rpzu.card_clicked.connect(func(card: Card) -> void:
		if card is PowerCard:
			_on_power_pressed(card as PowerCard)
	)
	_board_zone_uis.append(rpzu)

	for i in range(game_manager.current_player.reserve_zones.size()):
		var zone = game_manager.current_player.reserve_zones[i]
		var zu := BoardZoneUI.new()
		reserve_row.add_child(zu)
		zu.setup(zone, game_manager, game_manager.current_player, i, _on_card_dropped_to_zone, false, "back line")
		zu.zone_clicked.connect(_on_empty_zone_pressed)
		zu.card_clicked.connect(_on_board_card_pressed)
		zu.creature_drag_started.connect(_on_creature_drag_started)
		zu.creature_right_clicked.connect(_on_creature_right_clicked)
		_board_zone_uis.append(zu)

	reserve_row.add_child(_make_zone_info_panel("Abyss", game_manager.current_player.abyss_zone, true, Color(0.6, 0.1, 0.6)))

func draw_enemy_board() -> void:
	_no_intercept_btn = null  # enemy_board_container children are about to be freed
	for child in enemy_board_container.get_children():
		child.queue_free()
	_enemy_zone_uis.clear()
	_enemy_god_zone_ui = null
	enemy_board_container.add_theme_constant_override("separation", 0)

	var enemy_reserve_row := HBoxContainer.new()
	enemy_reserve_row.add_theme_constant_override("separation", 4)
	enemy_reserve_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enemy_reserve_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_board_container.add_child(enemy_reserve_row)
	enemy_reserve_row.add_child(_make_god_cluster(game_manager.other_player.god_zone, game_manager.other_player, true))

	var enemy_reserve_power_zone := game_manager.other_player.power_zones[2]
	var erpzu := BoardZoneUI.new()
	enemy_reserve_row.add_child(erpzu)
	erpzu.setup(enemy_reserve_power_zone, game_manager, game_manager.other_player, 2, _on_card_dropped_to_zone, true, "power")
	erpzu.card_clicked.connect(_on_enemy_card_pressed)
	_enemy_zone_uis.append(erpzu)

	for i in range(game_manager.other_player.reserve_zones.size()):
		var zone = game_manager.other_player.reserve_zones[i]
		var zu := BoardZoneUI.new()
		enemy_reserve_row.add_child(zu)
		zu.setup(zone, game_manager, game_manager.other_player, i, _on_card_dropped_to_zone, true, "back line")
		zu.card_clicked.connect(_on_enemy_card_pressed)
		_enemy_zone_uis.append(zu)

	enemy_reserve_row.add_child(_make_zone_info_panel("Abyss", game_manager.other_player.abyss_zone, true, Color(0.6, 0.1, 0.6)))

	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 4)
	enemy_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enemy_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_board_container.add_child(enemy_row)

	for i in range(2):
		var enemy_power_zone := game_manager.other_player.power_zones[i]
		var epzu := BoardZoneUI.new()
		enemy_row.add_child(epzu)
		epzu.setup(enemy_power_zone, game_manager, game_manager.other_player, i, _on_card_dropped_to_zone, true, "power")
		epzu.card_clicked.connect(_on_enemy_card_pressed)
		_enemy_zone_uis.append(epzu)

	for i in range(game_manager.other_player.frontline_zones.size()):
		var zone = game_manager.other_player.frontline_zones[i]
		var zu := BoardZoneUI.new()
		enemy_row.add_child(zu)
		zu.setup(zone, game_manager, game_manager.other_player, i, _on_card_dropped_to_zone, true, "front line")
		zu.card_clicked.connect(_on_enemy_card_pressed)
		_enemy_zone_uis.append(zu)

	enemy_row.add_child(_make_zone_info_panel("Grave", game_manager.other_player.graveyard_zone, true, Color(0.3, 0.5, 0.3)))

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
	selected_card = card
	for vc in _hand_visual_cards:
		vc.set_highlighted(vc.card_data == card)
	if card is CharmCard:
		if (card as CharmCard).must_be_prepared_to_activate:
			placement_mode = "prepare_charm"
			action_label.text = card.card_name + " selected - click an empty friendly zone to prepare it."
		else:
			action_label.text = "Selected charm: " + card.card_name + " - click a zone to play it, right-click for menu, or drag with S/right-click to prepare it."
	elif card.card_type == Card.CardType.SPELL:
		if card is BitMeseri:
			action_label.text = "BitMeseri - Drag onto a creature or structure to void it"
		elif card is Absence:
			action_label.text = "Absence - Drag onto a power card to target it, or click to choose a power"
		else:
			action_label.text = "Selected spell: " + card.card_name + " - click a zone to cast it, or drag with S/right-click to prepare it."
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
	if _cancel_pending_target_selection(_get_pending_target_selection_name() + " cancelled with right-click."):
		return
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		return
	if card is CharmCard:
		_close_context_menu()
		var panel := PanelContainer.new()
		panel.name = "HandCardContextMenu"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.18, 0.97)
		style.border_color = Color(0.45, 0.82, 0.95)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			style.set_border_width(side, 2)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", style)
		panel.z_index = 200

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		panel.add_child(vbox)

		var title := Label.new()
		title.text = card.card_name
		title.add_theme_font_size_override("font_size", 13)
		title.modulate = Color(0.85, 0.95, 1.0)
		vbox.add_child(title)

		if not (card as CharmCard).must_be_prepared_to_activate:
			var play_btn := Button.new()
			play_btn.text = "Play Charm"
			play_btn.pressed.connect(func() -> void:
				_close_context_menu()
				selected_card = card
				placement_mode = ""
				action_label.text = card.card_name + " selected - click a zone to play it."
			)
			vbox.add_child(play_btn)

		var prepare_btn := Button.new()
		prepare_btn.text = "Prepare Charm"
		prepare_btn.pressed.connect(func() -> void:
			_close_context_menu()
			selected_card = card
			placement_mode = "prepare_charm"
			action_label.text = card.card_name + " selected - click an empty friendly zone to prepare it."
		)
		vbox.add_child(prepare_btn)

		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.pressed.connect(_close_context_menu)
		vbox.add_child(cancel_btn)

		_context_menu = panel
		add_child(panel)
		_promote_transient_ui(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		var mouse_pos := get_global_mouse_position()
		panel.global_position = mouse_pos
		await get_tree().process_frame
		if not is_instance_valid(panel):
			return
		var viewport_size := get_viewport_rect().size
		panel.global_position = Vector2(
			clamp(mouse_pos.x, 4.0, viewport_size.x - panel.size.x - 4.0),
			clamp(mouse_pos.y, 4.0, viewport_size.y - panel.size.y - 4.0)
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
			selected_card = card
			placement_mode = mode
			action_label.text = card.card_name + " Ã¢â‚¬â€ click an empty zone to place (" + mode.to_upper() + ")"
		)
		vbox.add_child(btn)

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
	if _has_pending_target_selection():
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
			if game_manager.creature_move(card, zone):
				action_label.text = card.card_name + " moved."
				update_ui()
				return
		action_label.text = "Invalid move target Ã¢â‚¬â€ must be an adjacent empty zone."
		update_ui()
		return

	
	if selected_card:
		if selected_card is CharmCard:
			var charm := selected_card as CharmCard
			if placement_mode == "prepare_charm" or charm.must_be_prepared_to_activate:
				if game_manager.can_play_card(game_manager.current_player, selected_card, zone):
					game_manager.prepare_card(game_manager.current_player, selected_card, zone)
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
			if game_manager.can_play_card(game_manager.current_player, selected_card, zone):
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
		elif selected_card.card_type == Card.CardType.CREATURE and placement_mode != "":
			if game_manager.can_play_card(game_manager.current_player, selected_card, zone):
				if selected_card.creature_sacrifice_cost > 0 and not _drag_sacrifice_done:
					_sacrifice_pending_card = selected_card
					_sacrifice_pending_zone = zone
					_sacrifice_pending_mode = placement_mode
					_sacrifice_remaining = selected_card.creature_sacrifice_cost
					var altar := _get_active_altar_of_dreams(game_manager.current_player)
					if altar != null and altar.has_enough_valid_void_targets(_sacrifice_pending_card, game_manager):
						selected_card = null
						placement_mode = ""
						placement_container.visible = false
						action_label.text = _sacrifice_pending_card.card_name + " - choose how to pay its creature sacrifice cost."
						_show_sacrifice_payment_prompt(_sacrifice_pending_card, altar)
						return
					_awaiting_creature_sacrifice = true
					selected_card = null
					placement_mode = ""
					placement_container.visible = false
					action_label.text = _sacrifice_pending_card.card_name + " Ã¢â‚¬â€ select a friendly creature to sacrifice (" + str(_sacrifice_remaining) + " remaining)"
				else:
					_drag_sacrifice_done = false
					var orig_cost := selected_card.creature_sacrifice_cost
					if orig_cost > 0:
						selected_card.creature_sacrifice_cost = 0
					_do_place_creature(selected_card, zone, placement_mode)
					if orig_cost > 0:
						selected_card.creature_sacrifice_cost = orig_cost
					selected_card = null
					placement_mode = ""
					placement_container.visible = false
					update_ui()
			else:
				action_label.text = "Cannot play card! Not enough resources or already summoned this turn"
		# --- STRUCTURE UI CHANGE START ---
		elif selected_card.card_type == Card.CardType.STRUCTURE:
			if game_manager.can_play_card(game_manager.current_player, selected_card, zone):
	# Structure defensive stance is handled internally by StructureCard.gd
				var played_structure := selected_card
				game_manager.play_card(game_manager.current_player, selected_card, zone)
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
				game_manager.play_card(game_manager.current_player, selected_card, zone)
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
			if game_manager.can_play_card(game_manager.current_player, selected_card, zone):
				game_manager.prepare_card(game_manager.current_player, selected_card, zone)
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
	if selected_card is Absence and card.is_god:
		_cast_targeted_spell(selected_card, card)
		return
	if awaiting_god_ability_target and god_ability_source != null:
		if god_ability_source.has_method("is_valid_activation_target") and god_ability_source.is_valid_activation_target(card):
			var source_god := god_ability_source
			var was_immune := game_manager.is_immune_to_source(card, source_god)
			god_ability_source.activate(game_manager, card)
			awaiting_god_ability_target = false
			god_ability_source = null
			action_label.text = _consume_resolution_feedback(card.card_name + " is immune to " + source_god.card_name + "." if was_immune else "God ability resolved.")
			update_ui()
		else:
			_cancel_pending_target_selection(
				_get_pending_target_selection_name()
				+ " cancelled: invalid target "
				+ _get_card_name_safe(card, "selected")
				+ "."
			)
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
	else:
		awaiting_god_ability_target = true
		god_ability_source = card
		action_label.text = card.card_name + " - click a valid target."
		update_ui()

func _execute_drag_sacrifice(zone: Zone) -> void:
	var card := _drag_sacrifice_card
	var sacrificed := _drag_sacrifice_target
	var mode := _drag_sacrifice_mode
	_awaiting_drag_sacrifice_zone = false
	_drag_sacrifice_card = null
	_drag_sacrifice_target = null
	_drag_sacrifice_mode = ""
	# Sacrifice and summon simultaneously
	_resolve_creature_summon_sacrifice(
		sacrificed,
		card,
		func() -> void:
			var orig_cost := card.creature_sacrifice_cost
			card.creature_sacrifice_cost = 0
			_do_place_creature(card, zone, mode)
			card.creature_sacrifice_cost = orig_cost
			update_ui()
	)

func _do_place_creature(card: Card, zone: Zone, mode: String) -> void:
	if mode == "stealth":
		game_manager.play_creature_stealth(game_manager.current_player, card, zone)
		action_label.text = "A creature was played in STEALTH!"
	else:
		card.creature_mode = Card.CreatureMode.AGGRESSIVE if mode == "aggressive" else Card.CreatureMode.DEFENSIVE
		game_manager.play_card(game_manager.current_player, card, zone)
		action_label.text = "Played " + card.card_name + " in " + ("aggressive stance" if mode == "aggressive" else "defensive stance") + "!"
		if card is BlessedKnights:
			call_deferred("_queue_blessed_knights_impact_prompt", card)

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
		_pause_stack_resolution(card.card_owner)
		_show_blessed_knights_prompt(card)
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
	# Temporarily zero out the cost since we paid it interactively
	var orig_cost := card.creature_sacrifice_cost
	card.creature_sacrifice_cost = 0
	_do_place_creature(card, zone, mode)
	card.creature_sacrifice_cost = orig_cost
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

func _begin_normal_creature_sacrifice_selection() -> void:
	_hide_sacrifice_payment_prompt()
	_awaiting_altar_void_payment = false
	_altar_pending_power = null
	_altar_void_targets_chosen.clear()
	_awaiting_creature_sacrifice = true
	action_label.text = _sacrifice_pending_card.card_name + " - select a friendly creature to sacrifice (" + str(_sacrifice_remaining) + " remaining)"
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
	var orig_cost := card.creature_sacrifice_cost
	card.creature_sacrifice_cost = 0
	_do_place_creature(card, zone, mode)
	card.creature_sacrifice_cost = orig_cost
	update_ui()

func _try_resolve_stupefy_target(card: Card) -> bool:
	if not awaiting_stupefy_target or stupefy_source == null:
		return false
	if card.card_type == Card.CardType.CREATURE and card.level <= stupefy_source.level:
		if game_manager.is_guardian_protected(card, stupefy_source):
			action_label.text = card.card_name + " is protected by Guardian!"
			return true
		if game_manager.is_immune_to_source(card, stupefy_source):
			action_label.text = card.card_name + " is immune to " + stupefy_source.card_name + "'s creature abilities this turn."
			return true
		stupefy_source.stupefy(card)
		awaiting_stupefy_target = false
		stupefy_source = null
		update_ui()
		action_label.text = card.card_name + " is now Sleeping!"
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
		action_label.text = _get_pending_target_selection_name() + ": click a valid target."
		update_ui()
		return
	if _reject_priority_locked_action():
		return
	if _is_turn_choice_pending() and not _can_activate_before_turn_choice(card):
		_reject_pre_turn_action()
		return
	if _awaiting_drag_sacrifice_zone:
		action_label.text = "Choose an empty friendly zone to place " + _drag_sacrifice_card.card_name
		return

	if awaiting_pyre_target and pyre_source != null:
		pyre_source.activate(game_manager, card)
		awaiting_pyre_target = false
		pyre_source = null
		action_label.text = "Ancient Pyre: Ritual Flame resolved."
		update_ui()
		return

	if awaiting_anointing_target and anointing_source != null:
		if anointing_source.can_activate(game_manager, card):
			anointing_source.activate(game_manager, card)
			awaiting_anointing_target = false
			anointing_source = null
			action_label.text = "Anointing Statue resolved."
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
						action_label.text = _sacrifice_pending_card.card_name + " - select a friendly creature to sacrifice (" + str(_sacrifice_remaining) + " remaining)"
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
				action_label.text = _sacrifice_pending_card.card_name + " Ã¢â‚¬â€ select a friendly creature to sacrifice (" + str(_sacrifice_remaining) + " remaining)"
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
	if awaiting_god_ability_target and god_ability_source != null:
		if god_ability_source.has_method("is_valid_activation_target") and god_ability_source.is_valid_activation_target(card):
			var source_god := god_ability_source
			var was_immune := game_manager.is_immune_to_source(card, source_god)
			god_ability_source.activate(game_manager, card)
			awaiting_god_ability_target = false
			god_ability_source = null
			update_ui()
			action_label.text = _consume_resolution_feedback(card.card_name + " is immune to " + source_god.card_name + "." if was_immune else "God ability resolved.")
		else:
			_cancel_pending_target_selection(
				_get_pending_target_selection_name()
				+ " cancelled: invalid target "
				+ _get_card_name_safe(card, "selected")
				+ "."
			)
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
		if card is AncientPyre and card.get_controller() == game_manager.current_player:
			if (card as AncientPyre).can_activate(game_manager):
				if (card as AncientPyre).is_frontline():
					awaiting_pyre_target = true
					pyre_source = card as AncientPyre
					action_label.text = "Ancient Pyre: Select a card to reduce Res by 5, or click the enemy god to Convert 5 followers."
				else:
					(card as AncientPyre).activate(game_manager)
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

	if not _creature_can_attack(card):
		if card.is_sleeping:
			action_label.text = card.card_name + " is Sleeping and cannot act."
		elif card.creature_major_action_used:
			action_label.text = card.card_name + " has already used its major action this turn."
		elif card.creature_minor_actions_used >= 2:
			action_label.text = card.card_name + " has already used two minor actions this turn."
		elif card.creature_mode == Card.CreatureMode.DEFENSIVE:
			action_label.text = card.card_name + " is in defensive stance and cannot attack."
		elif card.current_zone.zone_type == Zone.ZoneType.RESERVE:
			action_label.text = card.card_name + " cannot attack from the back row."
		elif game_manager.turn_number == 0:
			action_label.text = "Cannot attack on the first turn!"
		else:
			action_label.text = card.card_name + " cannot attack right now."
		return

	if selected_attacker == card:
		selected_attacker = null
		action_label.text = card.card_name + " deselected"
		update_ui()
	else:
		selected_attacker = card
		action_label.text = "Selected attacker: " + _get_attack_card_label(card, "A creature") + " - Click enemy target or followers"

func _on_enemy_card_pressed(target_card: Card) -> void:
	if _game_finished:
		return
	if _is_card_usable_for_priority(target_card):
		_on_priority_response_chosen(target_card)
		return
	if _has_pending_click_selection():
		if _try_handle_pending_click_selection(target_card):
			return
		action_label.text = _get_pending_target_selection_name() + ": click a valid target."
		update_ui()
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
		if anointing_source.can_activate(game_manager, target_card):
			anointing_source.activate(game_manager, target_card)
			awaiting_anointing_target = false
			anointing_source = null
			action_label.text = "Anointing Statue resolved."
			update_ui()
		else:
			_cancel_pending_target_selection(
				_get_pending_target_selection_name()
				+ " cancelled: invalid target "
				+ _get_card_name_safe(target_card, "selected")
				+ "."
			)
		return

	if awaiting_god_ability_target and god_ability_source != null:
		if god_ability_source.has_method("is_valid_activation_target") and god_ability_source.is_valid_activation_target(target_card):
			var source_god := god_ability_source
			var was_immune := game_manager.is_immune_to_source(target_card, source_god)
			god_ability_source.activate(game_manager, target_card)
			awaiting_god_ability_target = false
			god_ability_source = null
			action_label.text = _consume_resolution_feedback(target_card.card_name + " is immune to " + source_god.card_name + "." if was_immune else "God ability resolved.")
			update_ui()
		else:
			_cancel_pending_target_selection(
				_get_pending_target_selection_name()
				+ " cancelled: invalid target "
				+ _get_card_name_safe(target_card, "selected")
				+ "."
			)
		return

	if selected_card is Absence and (target_card is PowerCard or target_card.is_god):
		_cast_targeted_spell(selected_card, target_card)
		return

	if awaiting_pyre_target and pyre_source != null:
		pyre_source.activate(game_manager, target_card)
		awaiting_pyre_target = false
		pyre_source = null
		action_label.text = "Ancient Pyre: Ritual Flame resolved."
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

	# Attack restriction guard
	if selected_attacker and game_manager.attack_restrictions.has(selected_attacker.get_controller()):
		action_label.text = "Cannot attack! Restricted for " + str(game_manager.attack_restrictions[selected_attacker.get_controller()]) + " more turns"
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
		if target_card.is_god:
			# Attacking an enemy god is treated as attacking their followers directly
			pending_attack_target = target_card.card_owner
			action_label.text = _get_attack_card_label(selected_attacker, "A creature") + " attacks " + target_card.card_owner.player_name + "'s followers!"
			check_for_possible_intercepts()
		elif target_card.card_type == Card.CardType.CREATURE or target_card.card_type == Card.CardType.STRUCTURE:
			pending_attack_target = target_card
			action_label.text = _get_attack_card_label(selected_attacker, "A creature") + " attacking " + _get_card_name_safe(target_card, "an enemy card") + " - opponent may intercept"
			check_for_possible_intercepts()
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
		if _creature_can_attack(card):
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
		if not _creature_can_attack(attacker):
			continue
		# Set up exactly like a manual attack targeting followers
		selected_attacker = attacker
		pending_attack_target = game_manager.other_player
		action_label.text = _get_attack_card_label(attacker, "A creature") + " attacking followers - opponent may intercept"
		check_for_possible_intercepts()
		return
	# Queue exhausted
	_queued_attackers.clear()
	update_ui()

func _on_creature_right_clicked(card: Card) -> void:
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		return
	_close_context_menu()
	_pending_move_card = null

	# Build list of legal actions
	var can_attack  := _creature_can_attack(card)
	var can_stance  := _creature_can_change_stance(card)
	var can_move    := _creature_can_move(card)
	var can_stupefy := (card is Alu and card.get_controller() == game_manager.current_player and _creature_can_attack(card) and not card.abilities_suppressed())
	var can_activate_creature: bool = (
		card.get_controller() == game_manager.current_player
		and card.has_method("can_activate")
		and card.has_method("activate")
		and card.can_activate(game_manager)
	)
	var equip_entries: Array[Dictionary] = []
	if _creature_can_use_equipment_action(card):
		equip_entries = _get_reachable_equipment(card)

	if not can_attack and not can_stance and not can_move and not can_stupefy and not can_activate_creature and equip_entries.is_empty():
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
		btn.text = card.get_activation_label() if card.has_method("get_activation_label") else "Activate Ability"
		btn.pressed.connect(func():
			_close_context_menu()
			if card.has_method("get_valid_targets"):
				var targets: Array = card.get_valid_targets(game_manager)
				if targets.is_empty():
					action_label.text = card.card_name + " has no valid targets right now."
					update_ui()
					return
				_show_card_selection_overlay(
					"Choose a target for " + card.card_name,
					targets,
					func(chosen: Card) -> void:
						card.activate(game_manager, chosen)
						action_label.text = _consume_resolution_feedback(card.card_name + " targeted " + chosen.card_name + ".")
						update_ui()
				)
			else:
				card.activate(game_manager)
				action_label.text = _consume_resolution_feedback(card.card_name + " used " + (card.get_activation_label() if card.has_method("get_activation_label") else "its ability") + ".")
				update_ui()
		)
		vbox.add_child(btn)

	if can_stance:
		if card.is_stealth:
			var reveal_aggressive_btn := Button.new()
			reveal_aggressive_btn.text = "Reveal in Aggressive Stance"
			reveal_aggressive_btn.pressed.connect(func():
				_close_context_menu()
				var was_stealth: bool = card.is_stealth
				if game_manager.creature_change_mode(card, Card.CreatureMode.AGGRESSIVE):
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
				if game_manager.creature_change_mode(card, Card.CreatureMode.DEFENSIVE):
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
				game_manager.creature_change_mode(card)
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
		_reject_pre_turn_action()
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
	if not _bdrag_active:
		return
	if event is InputEventMouseMotion:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_bdrag_cancel()
			return
		if _bdrag_ghost == null:
			_bdrag_start_ghost()
		else:
			_bdrag_ghost.global_position = get_global_mouse_position() - Vector2(BoardZoneUI.ZONE_WIDTH, BoardZoneUI.ZONE_HEIGHT) / 2.0
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

	if _game_finished or not _has_pending_target_selection():
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_pending_target_selection(_get_pending_target_selection_name() + " cancelled with right-click.")
		get_viewport().set_input_as_handled()
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_cancel_pending_target_selection(_get_pending_target_selection_name() + " cancelled: clicked off the board.")
		get_viewport().set_input_as_handled()

func _bdrag_start_ghost() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(BoardZoneUI.ZONE_WIDTH, BoardZoneUI.ZONE_HEIGHT)
	panel.size = Vector2(BoardZoneUI.ZONE_WIDTH, BoardZoneUI.ZONE_HEIGHT)
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
	_bdrag_ghost = panel
	get_tree().current_scene.add_child(_bdrag_ghost)
	_bdrag_ghost.global_position = get_global_mouse_position() - Vector2(BoardZoneUI.ZONE_WIDTH, BoardZoneUI.ZONE_HEIGHT) / 2.0

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
			game_manager.creature_move(card, target_zone)
			action_label.text = card.card_name + " moved."
			update_ui()
		else:
			action_label.text = "Can only move to an adjacent or diagonal zone."
		return

	# Attack guard checks
	if not _creature_can_attack(card):
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
			pending_attack_target = target_card
			action_label.text = _get_attack_card_label(card, "A creature") + " attacking " + _get_card_name_safe(target_card, "an enemy card") + " - opponent may intercept"
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

func _on_attack_followers_pressed() -> void:

	if selected_attacker:
		if not selected_attacker is Card:
			action_label.text = "Invalid attacker selected"
			selected_attacker = null
			return
		if game_manager.turn_number == 0:
			action_label.text = "Cannot attack on the first turn!"
			return
		if game_manager.attack_restrictions.has(selected_attacker.get_controller()):
			action_label.text = "Cannot attack! Restricted for " + str(game_manager.attack_restrictions[selected_attacker.get_controller()].turns) + " more turns"
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

func _creature_can_attack(card: Card) -> bool:
	return (
		card.card_type == Card.CardType.CREATURE
		and card.can_take_major_creature_action()
		and not card.is_sleeping
		and game_manager.turn_number > 0
		and card.creature_mode == Card.CreatureMode.AGGRESSIVE
		and card.current_zone != null
		and card.current_zone.zone_type == Zone.ZoneType.FRONTLINE
		and not game_manager.attack_restrictions.has(card.get_controller())
	)

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

func can_intercept(defender: Card, attacker: Card, protected_target) -> bool:
	if attacker == null:
		return false
	if protected_target == null:
		return false
	if defender.card_type != Card.CardType.CREATURE:
		return false
	if defender.is_sleeping:
		return false
	if defender.get_effective_speed() < attacker.get_effective_speed():
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
	
	if possible_interceptors.size() > 0:
		var names = []
		for card in possible_interceptors:
			names.append(card.card_name)
		action_label.text = _get_attack_card_label(selected_attacker, "A creature") + " is attacking. Possible interceptors: " + ", ".join(names) + " - Click one to intercept or click 'No Intercept'"
		show_no_intercept_button()
	else:
		action_label.text = _get_attack_card_label(selected_attacker, "A creature") + " attacking directly - no possible interceptors."
		resolve_pending_attack()

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

	var declared_defender: Card = selected_interceptor if selected_interceptor != null else (pending_attack_target if pending_attack_target is Card else null)
	selected_attacker.reveal(game_manager)
	if declared_defender != null:
		declared_defender.reveal(game_manager)

	# Build and push the attack action onto the stack, then offer priority to opponent
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.source_player = game_manager.current_player
	action.attacker = selected_attacker
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

	if auto_priority:
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

	_show_priority_prompt(player)

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
	game_manager.pass_priority()
	if game_manager.both_passed():
		_execute_top_of_stack()
	else:
		_offer_priority()

func _on_priority_response_chosen(card: Card) -> void:
	_hide_priority_prompt()

	if card is HexCard:
		var top: CardAction = game_manager.action_stack.back()
		var def_card: Card = top.interceptor if top.interceptor != null else (top.target if top.target is Card else null)
		game_manager.prepared_hexes.erase(card)
		card.is_prepared = false
		card.reveal(game_manager)
		var ability := CardAction.new()
		ability.type = CardAction.Type.ABILITY
		ability.source_player = card.card_owner
		ability.card = card
		ability.response_to = top
		ability.attacker = top.attacker
		ability.interceptor = top.interceptor
		ability.target = top.target
		_assign_stack_display_zone(ability)
		game_manager.push_to_stack(ability)
		action_label.text = card.card_name + " responds!"
		_offer_priority()
	elif card is CharmCard:
		var charm := card as CharmCard
		if charm.targets:
			_prompt_charm_target_selection(charm, game_manager.action_stack.back())
		else:
			_queue_charm_action(charm, game_manager.action_stack.back())
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
	if god is AphroditeAreia and (god as AphroditeAreia).can_activate(game_manager):
		_show_aphrodite_prompt(god as AphroditeAreia)
		action_label.text = god.card_name + " can enslave a creature."
		return true
	return false

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
	lbl.text = ask_card.get_controller().player_name + "'s Askelladen may use Tactful Retreat.\nReturn both creatures to the bottom of their decks?"
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
	info.text = "%s can use Altar of Dreams instead of creature sacrifice." % card.card_name
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
	info.text = "Choose how to affect " + target.card_name + "."
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

func _hide_blessed_knights_prompt() -> void:
	var panel := get_node_or_null("BlessedKnightsPromptPanel")
	if panel:
		panel.queue_free()
	_pending_blessed_knights = null

func _resolve_blessed_knights_impact(ward_kind: String) -> void:
	var card := _pending_blessed_knights
	_hide_blessed_knights_prompt()
	if card == null:
		if _stack_resolution_paused:
			_resume_after_deferred_resolution()
		else:
			update_ui()
		return
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
	var target_label := target.card_name
	if target is PowerCard and (target as PowerCard).is_face_down and not (target as PowerCard).is_publicly_revealed:
		target_label = "a face-down power"
	_queue_hand_spell_cast(
		spell,
		target,
		"Cast Absence on " + target_label + " (" + ("flip down" if mode == "relock" else "mute") + ").",
		func() -> void:
			spell.apply_to_power(target, mode, game_manager)
	)

func _on_absence_relock_pressed() -> void:
	_resolve_absence_with_mode("relock")

func _on_absence_mute_pressed() -> void:
	_resolve_absence_with_mode("mute")

func _on_absence_cancel_pressed() -> void:
	var spell := _pending_absence_spell
	_hide_absence_mode_prompt()
	if spell != null and _get_paid_hand_card_display_zone(spell) != null:
		_clear_paid_hand_card_preview(spell)
		_send_used_hand_card_to_graveyard(spell)
		action_label.text = "Absence fizzles."
	else:
		action_label.text = "Cancelled Absence."
	update_ui()

func _hide_aphrodite_prompt() -> void:
	var panel := get_node_or_null("AphroditePromptPanel")
	if panel:
		panel.queue_free()

func _on_aphrodite_confirm_pressed(god: AphroditeAreia) -> void:
	_hide_aphrodite_prompt()
	awaiting_god_ability_target = true
	god_ability_source = god
	action_label.text = god.card_name + " - Violent Delights: click an enemy creature to enslave."
	update_ui()

func _on_aphrodite_decline_pressed() -> void:
	_hide_aphrodite_prompt()
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
	var on_choose_creature := func(chosen: Card) -> void:
		_resolve_book_of_life(chosen)
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
		for chosen in _pending_deucalion_friendly_targets:
			var remove_btn := Button.new()
			remove_btn.text = "Keep " + chosen.card_name
			remove_btn.pressed.connect(func() -> void:
				_pending_deucalion_friendly_targets.erase(chosen)
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
			func(chosen: Card) -> void:
				_queue_deucalion_spell(spell, friendly_targets, chosen)
		)
		return

	var chosen_enemy: Card = enemy_choices[0] if enemy_choices.size() == 1 else null
	_queue_deucalion_spell(spell, friendly_targets, chosen_enemy)

func _queue_deucalion_spell(spell: DeucalionsInfants, friendly_targets: Array[Card], enemy_target: Card = null) -> void:
	if spell == null:
		update_ui()
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
		var chosen_enemy: Card = enemy_choices[0] if enemy_choices.size() == 1 else null
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
	var orig_creature_cost: int = spell.creature_sacrifice_cost
	spell.creature_sacrifice_cost = 0
	var paid: bool = spell.pay_costs(game_manager.current_player, game_manager)
	spell.creature_sacrifice_cost = orig_creature_cost
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
	_dismiss_zone_overlay()
	_hide_priority_prompt()
	_hide_retreat_prompt()
	_hide_doorway_choice_prompt()
	_hide_sacrifice_payment_prompt()
	_hide_structure_bonus_prompt()
	_hide_demiurge_prompt()
	_pending_book_of_life_spell = null
	_hide_absence_mode_prompt()
	_hide_blessed_knights_prompt()
	_hide_byggvir_reveal_prompt()
	_hide_breidablik_prompt()
	_hide_divine_caprice_prompt()
	_hide_aphrodite_prompt()
	_hide_blot_sacrifice_prompt()
	_hide_deucalion_prompt()
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
			var summoned: bool = spell.summon_milled_demon(demon_choices[0])
			_send_used_hand_card_to_graveyard(spell)
			game_manager.note_player_feedback(
				"Apollyon's Demiurge summoned %s." % demon_choices[0].card_name
				if summoned
				else "Apollyon's Demiurge found no open zone to summon into."
			)
			return
		_pause_stack_resolution(spell.card_owner)
		var on_choose_demon := func(chosen: Card) -> void:
			var summoned: bool = spell.summon_milled_demon(chosen)
			_send_used_hand_card_to_graveyard(spell)
			_resume_after_deferred_resolution(
				"Apollyon's Demiurge summoned %s." % chosen.card_name
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

	match action.type:
		CardAction.Type.ABILITY:
			if action.card is HexCard:
				var hex := action.card as HexCard
				if hex.has_method("on_activate_action"):
					hex.on_activate_action(game_manager, action)
					action_label.text = hex.card_name + " negated " + (action.response_to.card.card_name if action.response_to != null and action.response_to.card != null else "the effect") + "!"
				else:
					var def_card: Card = action.interceptor if action.interceptor != null else (action.target if action.target is Card else null)
					game_manager.activate_hex(hex, action.attacker, def_card)
					if game_manager.last_hex_resolution_text != "":
						action_label.text = game_manager.last_hex_resolution_text
					else:
						action_label.text = hex.card_name + " triggered! " + _get_card_name_safe(action.attacker, "the attacker") + " was sent to the abyss!"
			elif action.resolve_callback.is_valid():
				action.resolve_callback.call()
				action_label.text = _consume_resolution_feedback(action.resolution_text if action.resolution_text != "" else action.card.card_name + " resolved!")

		CardAction.Type.SPELL:
			if action.resolve_callback.is_valid():
				action.resolve_callback.call()
				action_label.text = _consume_resolution_feedback(action.resolution_text if action.resolution_text != "" else action.card.card_name + " [" + _get_stack_card_type_label(action.card) + "] resolved!")

		CardAction.Type.EVENT:
			if action.resolve_callback.is_valid():
				action.resolve_callback.call()
			else:
				action_label.text = action.event_name.replace("_", " ").capitalize() + " passed."

		CardAction.Type.ATTACK:
			if action.attacker == null:
				_executing_stack_action = false
				action_label.text = "An attack was cancelled."
				_finish_post_execute(action.source_player)
				return
			game_manager.current_phase = GameManager.GamePhase.COMBAT
			var actual_target = action.interceptor if action.interceptor != null else action.target
			action.attacker.reveal(game_manager)
			if actual_target is Card:
				actual_target.reveal(game_manager)
			action.attacker.mark_attacked_this_turn()
			if actual_target is Card:
				var retreat_prompts: Array[Askelladen] = _get_retreating_askelladens(action.attacker, actual_target, action.source_player)
				if not retreat_prompts.is_empty():
					_pending_retreat_action = action
					_pending_retreat_target = actual_target
					_pending_retreat_prompts = retreat_prompts
					_pending_retreat_guardian_blocked = _get_guardian_blocked_retreats(action.attacker, actual_target, action.source_player)
					_show_retreat_prompt(_pending_retreat_prompts[0])
					return  # Wait for player choice before advancing
				var blocked_retreats: Array[Askelladen] = _get_guardian_blocked_retreats(action.attacker, actual_target, action.source_player)
				var blocked_ask: Askelladen = null
				if not blocked_retreats.is_empty():
					blocked_ask = blocked_retreats[0]
				var finish_attack := func() -> void:
					if blocked_ask != null:
						action_label.text = "Asaruludu's Guardian prevented " + _get_card_name_safe(blocked_ask) + "'s Tactful Retreat!"
					else:
						action_label.text = _get_attack_card_label(action.attacker, "The attacker") + " fought " + _get_card_name_safe(actual_target) + "!"
					action.attacker.spend_major_creature_action()
					update_ui()
					if _stack_resolution_paused:
						_resume_after_deferred_resolution(action_label.text)
					else:
						_finish_post_execute(action.source_player)
				_executing_stack_action = false
				game_manager.resolve_combat_with_continuation(action.attacker, actual_target, finish_attack)
				return
			elif actual_target is Player:
				actual_target.lose_followers(action.attacker.get_effective_strength())
				game_manager._notify_after_combat(action.attacker, null)
				action_label.text = _get_attack_card_label(action.attacker, "The attacker") + " dealt " + str(action.attacker.get_effective_strength()) + " damage to followers!"
			action.attacker.spend_major_creature_action()

	_executing_stack_action = false
	if _stack_resolution_paused:
		return
	_finish_post_execute(action.source_player)
	return

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

func _is_attacker_on_board(attacker: Card, owner: Player) -> bool:
	for z in owner.frontline_zones + owner.reserve_zones:
		if attacker in z.cards:
			return true
	return false

func _on_draw_button_pressed() -> void:
	if _game_finished:
		return
	var _deck_had_cards: bool = game_manager.current_player.deck_zone.get_card_count() > 0
	game_manager.player_chooses_draw()
	_close_turn_start_windows()
	update_ui()
	hide_turn_choice()
	action_label.text = "Drew a card" if _deck_had_cards else "No cards left to draw"

func _on_mana_button_pressed() -> void:
	if _game_finished:
		return
	game_manager.player_chooses_mana()
	_close_turn_start_windows()
	update_ui()
	hide_turn_choice()
	action_label.text = "Gained 5 mana"

func _close_turn_start_windows() -> void:
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
		func(chosen: Card) -> void:
			_discard_end_turn_card(chosen)
	)
	action_label.text = "Choose %d card(s) to discard before ending your turn." % excess

func _discard_end_turn_card(card: Card) -> void:
	if card == null or card.current_zone != game_manager.current_player.hand_zone:
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
	else:
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
	_drag_sacrifice_done = false
	_awaiting_drag_sacrifice_zone = false
	_drag_sacrifice_card = null
	_drag_sacrifice_target = null
	_drag_sacrifice_mode = ""
	_prompt_end_turn_discards()

func _on_forfeit_button_pressed() -> void:
	if _game_finished:
		return
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
	action_label.text = "Game forfeited."
	forfeit_requested.emit()

func _do_end_turn() -> void:
	if _game_finished:
		return
	print("=== TURN ENDED ===")
	_dismiss_transient_prompts()
	var end_turn_priority_owner := game_manager.current_player
	var resolve_end_turn := func() -> void:
		game_manager.end_turn()
		update_ui()
		call_deferred("_open_start_turn_priority_window")
	_queue_priority_event(
		"end_turn",
		null,
		0,
		resolve_end_turn,
		end_turn_priority_owner
	)

func _open_start_turn_priority_window() -> void:
	var start_turn_priority_owner := game_manager.current_player
	var resolve_start_turn := func() -> void:
		update_ui()
		show_turn_choice()
		action_label.text = "Start of turn - choose draw or mana for " + game_manager.current_player.player_name + "."
		_maybe_prompt_breidablik_on_turn_start()
	_queue_priority_event(
		"start_turn",
		null,
		0,
		resolve_start_turn,
		start_turn_priority_owner
	)

var _resurrection_panel: Control = null
var _resurrection_queue: Array[Card] = []

func _show_resurrection_prompt(candidates: Array[Card]) -> void:
	_resurrection_queue = candidates.duplicate()
	_next_resurrection_prompt()

func _next_resurrection_prompt() -> void:
	if _resurrection_queue.is_empty():
		_do_end_turn()
		return
	var card: Card = _resurrection_queue.pop_front()
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
	body.text = card.card_owner.player_name + ": pay 1 mana to resurrect in your back line?"
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
	var player: Player = card.card_owner
	player.spend_mana(1)
	# Find an empty reserve zone, preferring the same column the card died in
	var preferred_idx: int = card.last_board_zone_index
	var zones_to_try: Array[Zone] = []
	if preferred_idx >= 0 and preferred_idx < player.reserve_zones.size():
		zones_to_try.append(player.reserve_zones[preferred_idx])
	for zone in player.reserve_zones:
		if zone not in zones_to_try:
			zones_to_try.append(zone)
	var placed := false
	for zone in zones_to_try:
		if zone.cards.is_empty():
			player.move_card(card, zone)
			card.creature_mode = Card.CreatureMode.AGGRESSIVE
			card.is_face_down = false
			card.is_stealth = false
			card.reset_creature_action_state()
			placed = true
			print("Again-Walker resurrected to reserve zone %d" % zone.zone_index)
			break
	if not placed:
		print("No empty reserve zone Ã¢â‚¬â€ Again-Walker stays in graveyard")
	update_ui()
	_next_resurrection_prompt()

func _on_resurrection_no() -> void:
	if _resurrection_panel and is_instance_valid(_resurrection_panel):
		_resurrection_panel.queue_free()
	_resurrection_panel = null
	_next_resurrection_prompt()

func _on_allow_ai_attack() -> void:
	pass

func _on_player_mana_changed(new_mana: int) -> void:
	if game_manager and game_manager.current_player == player1:
		update_ui()

func _on_player_followers_changed(new_followers: int) -> void:
	_request_ui_refresh()

func _on_enemy_followers_changed(new_followers: int) -> void:
	_request_ui_refresh()

func _on_game_ended(winner: Player, loser: Player) -> void:
	_game_finished = true
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
		return
	var priority_drop_allowed := game_manager != null and game_manager.can_card_respond_to_priority(card, game_manager.priority_player)
	if not priority_drop_allowed and _reject_priority_locked_action():
		return
	if _is_turn_choice_pending():
		_reject_pre_turn_action()
		return
	if _try_handle_blot_drag_selection(card):
		return
	# Sacrifice-by-drag: card with creature_sacrifice_cost dropped onto a friendly creature
	if card.card_type == Card.CardType.CREATURE and card.creature_sacrifice_cost > 0:
		for zu in _board_zone_uis:
			if not zu.get_global_rect().has_point(drop_pos):
				continue
			if zu._is_enemy or zu.zone.cards.size() == 0:
				continue
			var target: Card = zu.zone.cards[0]
			if target.get_controller() != game_manager.current_player or not _can_use_card_for_creature_sacrifice(target):
				continue
			if card.get_effective_speed() == 1 and game_manager.current_player != card.card_owner:
				action_label.text = card.card_name + " cannot be played right now."
				return
			if game_manager.current_player == card.card_owner and game_manager.current_player.has_summoned_this_turn:
				action_label.text = "You have already summoned a creature this turn."
				return
			# Check only the remaining non-sacrifice costs here. The actual zone choice happens after the sacrifice.
			var orig := card.creature_sacrifice_cost
			card.creature_sacrifice_cost = 0
			var affordable := card.can_pay_costs(game_manager.current_player)
			card.creature_sacrifice_cost = orig
			if not affordable:
				action_label.text = "Cannot afford " + card.card_name + "!"
				return
			_resolve_creature_summon_sacrifice(target, card)
			_awaiting_drag_sacrifice_zone = true
			_drag_sacrifice_card = card
			_drag_sacrifice_target = null
			_drag_sacrifice_mode = "stealth" if card_stealth else ("defensive" if card_rotated else "aggressive")
			action_label.text = target.card_name + " was sacrificed. Choose an empty friendly zone to summon " + card.card_name
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
			return

	# Non-targeted spell dropped on any friendly zone (occupied or not): find an empty zone and cast or prepare.
	if card.card_type == Card.CardType.SPELL and not card.targets:
		for zu in _board_zone_uis:
			if zu.get_global_rect().has_point(drop_pos) and not zu._is_enemy:
				var empty_zone := _find_empty_player_zone()
				if empty_zone != null:
					_on_card_dropped_to_zone(card, empty_zone, card_rotated, card_stealth)
				else:
					action_label.text = "No empty zone available to place " + card.card_name + "!"
				return

	# Creature dragged onto an empty friendly zone: resolve directly through the normal placement handler.
	if card.card_type == Card.CardType.CREATURE and not card.is_god:
		for zu in _board_zone_uis:
			if not zu.get_global_rect().has_point(drop_pos):
				continue
			if zu._is_enemy or zu.zone.cards.size() > 0:
				continue
			_on_card_dropped_to_zone(card, zu.zone, card_rotated, card_stealth)
			return
		if board_container != null and board_container.get_global_rect().has_point(drop_pos):
			var nearest_zone := _find_nearest_empty_friendly_zone(drop_pos)
			if nearest_zone != null:
				_on_card_dropped_to_zone(card, nearest_zone, card_rotated, card_stealth)
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
			return
	update_ui()

func _cast_targeted_spell(spell: Card, target: Card) -> void:
	if spell is Absence and target != null and target.is_god:
		_queue_hand_spell_cast(
			spell,
			target,
			"Cast Absence on " + target.card_name + " (mute).",
			func() -> void:
				(spell as Absence).apply_to_power(target, "mute", game_manager)
		)
		return
	if spell is Absence and target is PowerCard and not (target as PowerCard).is_face_down:
		_show_absence_mode_prompt(spell as Absence, target)
		return
	var target_label := target.card_name
	if target is PowerCard and (target as PowerCard).is_face_down and not (target as PowerCard).is_publicly_revealed:
		target_label = "a face-down power"
	_queue_hand_spell_cast(
		spell,
		target,
		"Cast " + spell.card_name + " on " + target_label + "!",
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
	var prepare_on_drop := is_stealth and (card.card_type == Card.CardType.SPELL or card is CharmCard)
	if prepare_on_drop:
		if zone == null or not zone.is_board_zone() or zone.zone_owner != game_manager.current_player or zone.cards.size() > 0:
			action_label.text = "Choose an empty friendly zone to prepare " + card.card_name + "."
			update_ui()
			return
		if not game_manager.can_play_card(game_manager.current_player, card, zone):
			action_label.text = "Cannot prepare " + card.card_name + "!"
			update_ui()
			return
		game_manager.prepare_card(game_manager.current_player, card, zone)
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
		_on_empty_zone_pressed(zone)
	else:
		_pending_drop_zone = null
		_on_empty_zone_pressed(zone)



func cleanup() -> void:
	if game_manager:
		game_manager.queue_free()
