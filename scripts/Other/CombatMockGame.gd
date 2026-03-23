extends Control
class_name CombatMockGame

var player1: Player
var player2: Player
var selected_card: Card = null
var selected_attacker: Card = null
var selected_interceptor: Card = null
var pending_attack_target = null
var placement_mode: String = ""
var awaiting_spell_target: bool = false
var spell_waiting_for_target: Card = null
var auto_priority: bool = true
var _fan_container: Control = null

const FAN_ROT_MAX     := 12.0   # degrees at the outermost card
const FAN_ARC_HEIGHT  := 22.0   # px the arc dips at centre
const FAN_CARD_SPACING := 130   # px between card pivot centres

@onready var choice_container = $MainHBox/LeftPanel/ChoiceContainer
@onready var draw_button = $MainHBox/LeftPanel/ChoiceContainer/DrawButton
@onready var mana_button = $MainHBox/LeftPanel/ChoiceContainer/ManaButton
@onready var end_turn_button = $MainHBox/RightPanel/EndTurnButton
@onready var all_attack_btn = $MainHBox/RightPanel/AllAttackBtn
@onready var turn_label = $MainHBox/RightPanel/TurnLabel
@onready var hand_container = $MainHBox/CenterPanel/HandContainer
@onready var board_container = $MainHBox/CenterPanel/BoardContainer
@onready var enemy_board_container = $MainHBox/CenterPanel/EnemyBoardContainer
@onready var action_label = $MainHBox/LeftPanel/ActionLabel
@onready var placement_container = $MainHBox/LeftPanel/PlacementContainer
@onready var attack_mode_btn = $MainHBox/LeftPanel/PlacementContainer/AttackModeBtn
@onready var defense_mode_btn = $MainHBox/LeftPanel/PlacementContainer/DefenseModeBtn
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
var _pending_retreat_action: CardAction = null
var _pending_retreat_target: Card = null
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

# Board-creature drag state (managed here for reliability)
var _bdrag_card: Card = null
var _bdrag_from_zone: Zone = null
var _bdrag_active: bool = false
var _bdrag_ghost: Control = null

# Right-click context menu state
var _pending_move_card: Card = null
var _context_menu: Control = null
var _queued_attackers: Array[Card] = []
var _no_intercept_btn: Button = null

func _ready() -> void:
	choice_container.visible = false
	end_turn_button.visible = false
	placement_container.visible = false

	draw_button.pressed.connect(_on_draw_button_pressed)
	mana_button.pressed.connect(_on_mana_button_pressed)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	all_attack_btn.pressed.connect(_on_all_attack_followers_pressed)
	attack_mode_btn.pressed.connect(_on_attack_mode_pressed)
	defense_mode_btn.pressed.connect(_on_defense_mode_pressed)
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

func start_game() -> void:
	print("=== STARTING COMBAT MOCK GAME ===")
	
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

	# Place Thor as Player 1's god
	var thor := Thor.new()
	thor.card_owner = player1
	player1.god_zone.add_card(thor)

	# Place Mummu as Player 2's god
	var mummu := Mummu.new()
	mummu.card_owner = player2
	player2.god_zone.add_card(mummu)

	game_manager.setup_game()
	
	player1.mana_changed.connect(_on_player_mana_changed)
	player1.followers_changed.connect(_on_player_followers_changed)
	player2.followers_changed.connect(_on_enemy_followers_changed)
	
	player1.gain_mana(20)
	player2.gain_mana(20)
	
	print("Drawing initial hands...")
	for i in range(5):
		print("  Drawing card ", i, " for P1")
		player1.draw_card()
		print("  P1 hand size now: ", player1.hand_zone.cards.size())
		print("  Drawing card ", i, " for P2")
		player2.draw_card()
		print("  P2 hand size now: ", player2.hand_zone.cards.size())
	
	
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

	# Spells
	deck.append(_own(BitMeseri.new(), player))
	deck.append(_own(BitMeseri.new(), player))
	deck.append(_own(FallOfTheMighty.new(), player))
	deck.append(_own(CircleOfRebirth.new(), player))

	# Structures
	deck.append(_own(WardingStone.new(), player))
	deck.append(_own(WardingStone.new(), player))

	# Hexes
	deck.append(_own(VoidShield.new(), player))
	deck.append(_own(VoidShield.new(), player))

	deck.shuffle()
	for card in deck:
		player.deck_zone.add_card(card)

func _own(card: Card, player: Player) -> Card:
	card.card_owner = player
	return card

func show_turn_choice() -> void:
	choice_container.visible = true
	end_turn_button.visible = false
	draw_button.disabled = false
	mana_button.disabled = false
	placement_container.visible = false

	for vc in _hand_visual_cards:
		vc.set_disabled(true)

func hide_turn_choice() -> void:
	choice_container.visible = false
	end_turn_button.visible = true

	for vc in _hand_visual_cards:
		vc.set_disabled(false)

func update_ui() -> void:
	var current = game_manager.current_player

	turn_label.text = "Turn " + str(game_manager.turn_number) + " - " + current.player_name + "'s Turn"
	
	draw_hand()
	draw_board()
	draw_enemy_board()

func draw_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	_hand_visual_cards.clear()

	# Small gap between board and hand
	var top_gap := Control.new()
	top_gap.custom_minimum_size = Vector2(0, 6)
	hand_container.add_child(top_gap)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hand_container.add_child(hbox)

	var label := Label.new()
	label.text = game_manager.current_player.player_name + "\nHand:"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(label)

	_fan_container = Control.new()
	_fan_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fan_container.custom_minimum_size = Vector2(0, 130)
	_fan_container.clip_contents = false
	hbox.add_child(_fan_container)

	for card in game_manager.current_player.hand_zone.cards:
		var vc := VisualCard.new()
		_fan_container.add_child(vc)
		vc.setup(card, 180, 0)
		vc.card_clicked.connect(_on_hand_card_pressed.bind(card))
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

	# Outer container — standard zone size, shadows go inward
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

func _make_stats_panel(player: Player, show_mana: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 110)
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

func _make_power_icon(card: Card, is_enemy: bool, player: Player) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		var lbl := Label.new()
		lbl.text = "-"
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lbl)
		return panel

	if is_enemy:
		# Show that a power exists but keep it hidden
		var unlocked := not card.is_face_down
		style.bg_color     = Color(0.12, 0.08, 0.18, 0.85) if unlocked else Color(0.05, 0.05, 0.10, 0.85)
		style.border_color = Color(0.55, 0.3, 0.8) if unlocked else Color(0.25, 0.2, 0.35)
		panel.add_theme_stylebox_override("panel", style)
		var lbl := Label.new()
		lbl.text = "?" if not unlocked else "★"
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lbl)
		return panel

	# Own power
	var power := card as PowerCard
	var unlocked := not card.is_face_down
	var activatable := power != null and power.can_activate(game_manager)
	var can_unlock_now := power != null and power.can_unlock(game_manager)

	if unlocked and activatable:
		style.bg_color     = Color(0.18, 0.14, 0.06, 0.92)
		style.border_color = Color(0.95, 0.78, 0.2)
	elif unlocked:
		style.bg_color     = Color(0.10, 0.10, 0.14, 0.85)
		style.border_color = Color(0.45, 0.38, 0.2)
	elif can_unlock_now:
		style.bg_color     = Color(0.06, 0.10, 0.16, 0.85)
		style.border_color = Color(0.3, 0.55, 0.85)
	else:
		style.bg_color     = Color(0.06, 0.06, 0.10, 0.75)
		style.border_color = Color(0.2, 0.22, 0.3)
		panel.modulate.a   = 0.65

	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	if not unlocked:
		lbl.text = str(card.mana_cost) + "◆"
	else:
		# Abbreviate to fit
		lbl.text = card.card_name.left(7)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

	if not is_enemy and (can_unlock_now or activatable):
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var captured := card as PowerCard
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_power_pressed(captured)
		)
		panel.tooltip_text = card.card_name + "\n" + card.ability_text

	return panel

func _on_power_pressed(power: PowerCard) -> void:
	if power.can_unlock(game_manager):
		power.unlock(game_manager)
		action_label.text = power.card_name + " unlocked!"
		update_ui()
	elif power.can_activate(game_manager):
		power.activate(game_manager)
		action_label.text = power.card_name + " activated!"
		update_ui()
	else:
		if power.is_face_down:
			action_label.text = power.card_name + " — needs " + str(power.mana_cost) + " mana to unlock."
		else:
			action_label.text = power.card_name + " — cannot activate right now."

var _zone_overlay: Control = null

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
	_zone_overlay = overlay

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)

	# Centered panel
	var panel := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.08, 0.14, 0.97)
	pstyle.corner_radius_top_left    = 8
	pstyle.corner_radius_top_right   = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		pstyle.set_border_width(side, 2)
	pstyle.border_color = Color(0.5, 0.5, 0.75)
	panel.add_theme_stylebox_override("panel", pstyle)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
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
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	var max_w := get_viewport_rect().size.x * 0.85
	var card_w := float(zone.cards.size()) * (VisualCard.CARD_WIDTH + 6) + 12.0
	scroll.custom_minimum_size = Vector2(min(card_w, max_w), VisualCard.CARD_HEIGHT + 24)
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

func _dismiss_zone_overlay() -> void:
	if _zone_overlay and is_instance_valid(_zone_overlay):
		_zone_overlay.queue_free()
	_zone_overlay = null

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

	var _fl_spacer := Control.new()
	_fl_spacer.custom_minimum_size = Vector2(110, 0)
	board_row.add_child(_fl_spacer)
	board_row.add_child(_make_deck_panel(game_manager.current_player.deck_zone))

	for i in range(5):
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

	reserve_row.add_child(_make_stats_panel(game_manager.current_player, true))
	var god_wrapper := Control.new()
	god_wrapper.custom_minimum_size = Vector2(BoardZoneUI.ZONE_WIDTH, BoardZoneUI.ZONE_HEIGHT)
	god_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reserve_row.add_child(god_wrapper)
	_player_god_zone_ui = BoardZoneUI.new()
	_player_god_zone_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	god_wrapper.add_child(_player_god_zone_ui)
	_player_god_zone_ui.setup(game_manager.current_player.god_zone, game_manager, game_manager.current_player, -1, _on_card_dropped_to_zone, false, "God")
	_player_god_zone_ui.card_clicked.connect(_on_god_card_pressed)
	_add_power_icons(god_wrapper, game_manager.current_player, false)

	for i in range(5):
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

	enemy_reserve_row.add_child(_make_stats_panel(game_manager.other_player, false))
	var enemy_god_wrapper := Control.new()
	enemy_god_wrapper.custom_minimum_size = Vector2(BoardZoneUI.ZONE_WIDTH, BoardZoneUI.ZONE_HEIGHT)
	enemy_god_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_reserve_row.add_child(enemy_god_wrapper)
	_enemy_god_zone_ui = BoardZoneUI.new()
	_enemy_god_zone_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enemy_god_wrapper.add_child(_enemy_god_zone_ui)
	_enemy_god_zone_ui.setup(game_manager.other_player.god_zone, game_manager, game_manager.other_player, -1, _on_card_dropped_to_zone, true, "God")
	_enemy_god_zone_ui.card_clicked.connect(_on_enemy_card_pressed)
	_add_power_icons(enemy_god_wrapper, game_manager.other_player, true)

	for i in range(5):
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

	var _el_spacer := Control.new()
	_el_spacer.custom_minimum_size = Vector2(110, 0)
	enemy_row.add_child(_el_spacer)
	enemy_row.add_child(_make_deck_panel(game_manager.other_player.deck_zone))

	for i in range(5):
		var zone = game_manager.other_player.frontline_zones[i]
		var zu := BoardZoneUI.new()
		enemy_row.add_child(zu)
		zu.setup(zone, game_manager, game_manager.other_player, i, _on_card_dropped_to_zone, true, "front line")
		zu.card_clicked.connect(_on_enemy_card_pressed)
		_enemy_zone_uis.append(zu)

	enemy_row.add_child(_make_zone_info_panel("Grave", game_manager.other_player.graveyard_zone, true, Color(0.3, 0.5, 0.3)))

func _on_hand_card_pressed(card: Card) -> void:
	selected_card = card
	for vc in _hand_visual_cards:
		vc.set_highlighted(vc.card_data == card)
	if card.card_type == Card.CardType.SPELL:
		if card is BitMeseri:
			action_label.text = "BitMeseri - Drag onto a creature or structure to void it"
		else:
			action_label.text = "Selected spell: " + card.card_name + " - Click a zone to cast it there"
	elif card.card_type == Card.CardType.CREATURE and not card.is_god:
		action_label.text = card.card_name + " selected — right-click for placement options, or drag to place (S while dragging = stealth)"
	elif card.is_god:
		action_label.text = card.card_name + " — God card, place in your God slot"
	# --- STRUCTURE UI CHANGE START ---
	elif card.card_type == Card.CardType.STRUCTURE:
		# Structures don't need mode selection, but we set placement_mode for the next step to trigger the placement logic
		placement_mode = "defense" 
		placement_container.visible = false 
		action_label.text = "Selected Structure: " + card.card_name + " - Click an empty zone to place it"
	# --- STRUCTURE UI CHANGE END ---
	else:
		action_label.text = "Card type not yet supported in this test UI"

func _on_hand_card_right_clicked(card: Card) -> void:
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

	for entry in [["Play in Attack Mode", "attack"], ["Play in Defense Mode", "defense"], ["Play in Stealth Mode (face-down)", "stealth"]]:
		var btn := Button.new()
		btn.text = entry[0]
		var mode: String = entry[1]
		btn.pressed.connect(func():
			_close_context_menu()
			selected_card = card
			placement_mode = mode
			action_label.text = card.card_name + " — click an empty zone to place (" + mode.to_upper() + ")"
		)
		vbox.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_close_context_menu)
	vbox.add_child(cancel)

	_context_menu = panel
	add_child(panel)
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

func _on_attack_mode_pressed() -> void:
	placement_mode = "attack"
	action_label.text = "Attack mode selected - Click empty zone to place"
	if _pending_drop_zone != null:
		_on_empty_zone_pressed(_pending_drop_zone)
		_pending_drop_zone = null

func _on_defense_mode_pressed() -> void:
	placement_mode = "defense"
	action_label.text = "Defense mode selected - Click empty zone to place"
	if _pending_drop_zone != null:
		_on_empty_zone_pressed(_pending_drop_zone)
		_pending_drop_zone = null

func _on_stealth_mode_pressed() -> void:
	placement_mode = "stealth"
	action_label.text = "Stealth mode selected - Click empty zone to place"
	if _pending_drop_zone != null:
		_on_empty_zone_pressed(_pending_drop_zone)
		_pending_drop_zone = null

func _on_empty_zone_pressed(zone: Zone) -> void:
	if _awaiting_drag_sacrifice_zone:
		if zone.zone_type in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE] \
				and zone.zone_owner == game_manager.current_player:
			_execute_drag_sacrifice(zone)
		else:
			action_label.text = "Choose a valid friendly zone to place " + _drag_sacrifice_card.card_name
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
		action_label.text = "Invalid move target — must be an adjacent empty zone."
		update_ui()
		return

	
	if selected_card:
		if selected_card.card_type == Card.CardType.SPELL:
			if game_manager.can_play_card(game_manager.current_player, selected_card, zone):
				if selected_card is CircleOfRebirth:
					var resurrect_count := get_resurrectible_cards().size()
					game_manager.play_card(game_manager.current_player, selected_card, zone)
					if resurrect_count > 0:
						action_label.text = "Circle of Rebirth resurrected %d creature(s)!" % resurrect_count
					else:
						action_label.text = "Cast Circle of Rebirth but no creatures to resurrect!"
					selected_card = null
					update_ui()
				else:
					game_manager.play_card(game_manager.current_player, selected_card, zone)
					action_label.text = "Cast " + selected_card.card_name + "!"
					selected_card = null
					update_ui()
			else:
				action_label.text = "Cannot cast spell! Not enough resources"
		elif selected_card.card_type == Card.CardType.CREATURE and placement_mode != "":
			if game_manager.can_play_card(game_manager.current_player, selected_card, zone):
				if selected_card.creature_sacrifice_cost > 0 and not _drag_sacrifice_done:
					_sacrifice_pending_card = selected_card
					_sacrifice_pending_zone = zone
					_sacrifice_pending_mode = placement_mode
					_sacrifice_remaining = selected_card.creature_sacrifice_cost
					_awaiting_creature_sacrifice = true
					selected_card = null
					placement_mode = ""
					placement_container.visible = false
					action_label.text = _sacrifice_pending_card.card_name + " — select a friendly creature to sacrifice (" + str(_sacrifice_remaining) + " remaining)"
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
				# Structure's defense mode is handled internally by StructureCard.gd
				game_manager.play_card(game_manager.current_player, selected_card, zone)
				action_label.text = "Played Structure: " + selected_card.card_name + "!"
				
				selected_card = null
				placement_mode = ""
				placement_container.visible = false
				update_ui()
			else:
				action_label.text = "Cannot play Structure! Not enough resources."
		# --- STRUCTURE UI CHANGE END ---
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
	if not card.is_god:
		return
	if not card.has_method("can_activate"):
		action_label.text = card.card_name + " has no activatable ability."
		return
	if choice_container.visible:
		action_label.text = "You must draw or take mana before activating a god ability."
		return
	if not card.can_activate(game_manager):
		action_label.text = card.card_name + "'s ability cannot be activated right now."
		return
	awaiting_god_ability_target = true
	god_ability_source = card
	action_label.text = card.card_name + " — Entropic Force: click a face-up card you control to return it to your deck."

func _execute_drag_sacrifice(zone: Zone) -> void:
	var card := _drag_sacrifice_card
	var sacrificed := _drag_sacrifice_target
	var mode := _drag_sacrifice_mode
	_awaiting_drag_sacrifice_zone = false
	_drag_sacrifice_card = null
	_drag_sacrifice_target = null
	_drag_sacrifice_mode = ""
	# Sacrifice and summon simultaneously
	game_manager._send_to_graveyard_with_hook(sacrificed)
	var orig_cost := card.creature_sacrifice_cost
	card.creature_sacrifice_cost = 0
	_do_place_creature(card, zone, mode)
	card.creature_sacrifice_cost = orig_cost
	update_ui()

func _do_place_creature(card: Card, zone: Zone, mode: String) -> void:
	if mode == "stealth":
		game_manager.play_creature_stealth(game_manager.current_player, card, zone)
		action_label.text = "Played " + card.card_name + " in STEALTH!"
	else:
		card.creature_mode = Card.CreatureMode.ATTACK if mode == "attack" else Card.CreatureMode.DEFENSE
		game_manager.play_card(game_manager.current_player, card, zone)
		action_label.text = "Played " + card.card_name + " in " + mode.to_upper() + " mode!"

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

func _try_resolve_stupefy_target(card: Card) -> bool:
	if not awaiting_stupefy_target or stupefy_source == null:
		return false
	if card.card_type == Card.CardType.CREATURE and card.level <= stupefy_source.level:
		if game_manager.is_guardian_protected(card, stupefy_source):
			action_label.text = card.card_name + " is protected by Guardian!"
			return true
		stupefy_source.stupefy(card)
		awaiting_stupefy_target = false
		stupefy_source = null
		update_ui()
		action_label.text = card.card_name + " is now Sleeping!"
	else:
		action_label.text = "Invalid target — choose a creature of level " + str(stupefy_source.level) + " or lower."
	return true

func _on_board_card_pressed(card: Card) -> void:
	if _awaiting_drag_sacrifice_zone:
		if card == _drag_sacrifice_target:
			_execute_drag_sacrifice(card.current_zone)
		else:
			action_label.text = "Click a zone or " + _drag_sacrifice_target.card_name + "'s zone to place " + _drag_sacrifice_card.card_name
		return

	if awaiting_pyre_target and pyre_source != null:
		pyre_source.activate(game_manager, card)
		awaiting_pyre_target = false
		pyre_source = null
		action_label.text = "Ancient Pyre: Ritual Flame resolved."
		update_ui()
		return

	if _try_resolve_stupefy_target(card):
		return

	if _awaiting_creature_sacrifice:
		if card.card_owner == game_manager.current_player and card.card_type == Card.CardType.CREATURE:
			game_manager._send_to_graveyard_with_hook(card)
			_sacrifice_remaining -= 1
			if _sacrifice_remaining <= 0:
				_finish_creature_sacrifice_play()
			else:
				action_label.text = _sacrifice_pending_card.card_name + " — select a friendly creature to sacrifice (" + str(_sacrifice_remaining) + " remaining)"
				update_ui()
		else:
			action_label.text = "Select one of your creatures to sacrifice."
		return

	# Check if we're selecting a target for a god ability
	if awaiting_god_ability_target and god_ability_source != null:
		if card.card_owner == game_manager.current_player and not card.is_face_down:
			god_ability_source.activate(game_manager, card)
			awaiting_god_ability_target = false
			god_ability_source = null
			update_ui()
			action_label.text = "Entropic Force resolved."
		else:
			action_label.text = "Invalid target — choose a face-up card you control."
		return

	# Non-targeted spell selected — clicking any zone (occupied or not) casts it
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
					action_label.text = card.card_name + " is protected by Guardian!"
				elif game_manager.can_play_card(game_manager.current_player, spell_waiting_for_target, null):
					# Cast the spell with the target
					var temp_zone = game_manager.current_player.frontline_zones[0]
					if spell_waiting_for_target.pay_costs(game_manager.current_player):
						spell_waiting_for_target.resolve(game_manager, card)
						game_manager.current_player.hand_zone.cards.erase(spell_waiting_for_target)
						game_manager.current_player.move_card(spell_waiting_for_target, game_manager.current_player.graveyard_zone)
						action_label.text = "Cast " + spell_waiting_for_target.card_name + " on " + card.card_name + "!"
					else:
						action_label.text = "Cannot afford spell!"
				else:
					action_label.text = "Cannot cast spell!"
				awaiting_spell_target = false
				spell_waiting_for_target = null
				selected_card = null
				update_ui()
			else:
				action_label.text = "BitMeseri can only target creatures, structures, or equipment!"
		return
	
	if pending_attack_target != null:
		if card.card_owner == game_manager.other_player and can_intercept(card, selected_attacker):
			_remove_no_intercept_button()
			selected_interceptor = card
			action_label.text = card.card_name + " will intercept! Resolving combat..."
			resolve_pending_attack()
		else:
			action_label.text = "Cannot use this creature (wrong player, mode, or too slow)"
		return
	
	if card.card_owner != game_manager.current_player:
		action_label.text = "That's not your card!"
		return
	
	if card.card_type == Card.CardType.STRUCTURE:
		if card is AncientPyre and card.card_owner == game_manager.current_player:
			if (card as AncientPyre).can_activate(game_manager):
				if (card as AncientPyre).is_frontline():
					awaiting_pyre_target = true
					pyre_source = card as AncientPyre
					action_label.text = "Ancient Pyre: Select a card to reduce Res by 5, or click the enemy god to Convert 5 followers."
				else:
					(card as AncientPyre).activate(game_manager)
					action_label.text = "Ancient Pyre: Ritual Flame — 5 followers converted!"
					update_ui()
			else:
				action_label.text = "Ancient Pyre cannot activate right now (need 2 mana or no valid targets)."
		else:
			action_label.text = card.card_name + " is a structure and cannot attack or move."
		return
	
	if card.card_type != Card.CardType.CREATURE:
		action_label.text = "That card cannot perform an action."
		return

	if not _creature_can_attack(card):
		if card.is_sleeping:
			action_label.text = card.card_name + " is Sleeping and cannot act."
		elif card.has_acted_this_turn:
			action_label.text = card.card_name + " has already acted this turn."
		elif card.creature_mode == Card.CreatureMode.DEFENSE:
			action_label.text = card.card_name + " is in defense mode and cannot attack."
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
		action_label.text = "Selected attacker: " + card.card_name + " - Click enemy target or followers"

func _on_enemy_card_pressed(target_card: Card) -> void:
	if awaiting_pyre_target and pyre_source != null:
		pyre_source.activate(game_manager, target_card)
		awaiting_pyre_target = false
		pyre_source = null
		action_label.text = "Ancient Pyre: Ritual Flame resolved."
		update_ui()
		return

	if _try_resolve_stupefy_target(target_card):
		return

	# Non-targeted spell selected — redirect to an empty friendly zone
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
					action_label.text = target_card.card_name + " is protected by Guardian!"
				elif game_manager.can_play_card(game_manager.current_player, spell_waiting_for_target, null):
					if spell_waiting_for_target.pay_costs(game_manager.current_player):
						spell_waiting_for_target.resolve(game_manager, target_card)
						game_manager.current_player.hand_zone.cards.erase(spell_waiting_for_target)
						game_manager.current_player.move_card(spell_waiting_for_target, game_manager.current_player.graveyard_zone)
						action_label.text = "Cast " + spell_waiting_for_target.card_name + " on " + target_card.card_name + "!"
					else:
						action_label.text = "Cannot afford spell!"
				else:
					action_label.text = "Cannot cast spell!"
				awaiting_spell_target = false
				spell_waiting_for_target = null
				selected_card = null
				update_ui()
			else:
				action_label.text = "BitMeseri can only target creatures, structures, or equipment!"
		return

	# Attack restriction guard
	if selected_attacker and game_manager.attack_restrictions.has(selected_attacker.card_owner):
		action_label.text = "Cannot attack! Restricted for " + str(game_manager.attack_restrictions[selected_attacker.card_owner]) + " more turns"
		return

	# Intercept selection (when an attack is already pending)
	if pending_attack_target != null:
		if target_card.card_owner == game_manager.other_player and can_intercept(target_card, selected_attacker):
			_remove_no_intercept_button()
			selected_interceptor = target_card
			action_label.text = target_card.card_name + " will intercept! Resolving combat..."
			resolve_pending_attack()
		else:
			action_label.text = "This card cannot intercept"
		return

	# Direct attack target selection
	if selected_attacker:
		if target_card.is_god:
			# Attacking an enemy god is treated as attacking their followers directly
			pending_attack_target = target_card.card_owner
			action_label.text = selected_attacker.card_name + " attacks " + target_card.card_owner.player_name + "'s followers!"
			resolve_pending_attack()
		elif target_card.card_type == Card.CardType.CREATURE or target_card.card_type == Card.CardType.STRUCTURE:
			pending_attack_target = target_card
			action_label.text = selected_attacker.card_name + " attacking " + target_card.card_name + " - resolving..."
			resolve_pending_attack()
		else:
			action_label.text = "Can only attack creatures or structures"
	else:
		action_label.text = "Select your creature first to attack"

func _on_all_attack_followers_pressed() -> void:
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
		action_label.text = attacker.card_name + " attacking followers — opponent may intercept"
		check_for_possible_intercepts()
		return
	# Queue exhausted
	_queued_attackers.clear()
	update_ui()

func _on_creature_right_clicked(card: Card) -> void:
	_close_context_menu()
	_pending_move_card = null

	# Build list of legal actions
	var can_attack  := _creature_can_attack(card)
	var can_stance  := _creature_can_change_stance(card)
	var can_move    := _creature_can_move(card)
	var can_stupefy := (card is Alu and card.card_owner == game_manager.current_player and _creature_can_attack(card))

	if not can_attack and not can_stance and not can_move and not can_stupefy:
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
			action_label.text = card.card_name + " ready to attack — click an enemy creature or zone"
		)
		vbox.add_child(btn)

	if can_stupefy:
		var btn := Button.new()
		btn.text = "Stupefy"
		btn.pressed.connect(func():
			_close_context_menu()
			awaiting_stupefy_target = true
			stupefy_source = card
			action_label.text = "Stupefy — click an enemy creature of level " + str(card.level) + " or lower"
		)
		vbox.add_child(btn)

	if can_stance:
		var mode_name := "Switch to Defense" if card.creature_mode == Card.CreatureMode.ATTACK else "Switch to Attack"
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
			action_label.text = card.card_name + " — click an adjacent empty zone to move"
		)
		vbox.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_close_context_menu)
	vbox.add_child(cancel)

	_context_menu = panel
	add_child(panel)
	# Position near mouse, anchored to top-left
	var mp := get_global_mouse_position()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.global_position = mp

func _close_context_menu() -> void:
	if _context_menu and is_instance_valid(_context_menu):
		_context_menu.queue_free()
	_context_menu = null

func _on_creature_drag_started(card: Card, from_zone: Zone) -> void:
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
			# Was a click (no movement) — treat as board card click
			if _bdrag_card != null:
				_on_board_card_pressed(_bdrag_card)
		_bdrag_cleanup()
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
	var ml := Label.new(); ml.text = "DEF" if _bdrag_card.creature_mode == Card.CreatureMode.DEFENSE else "ATK"; ml.add_theme_font_size_override("font_size", 13); vbox.add_child(ml)
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
			elif card.has_moved_this_turn:
				action_label.text = card.card_name + " has already moved this turn."
			else:
				action_label.text = card.card_name + " cannot move right now."
			return
		if target_zone in card.card_owner.get_adjacent_zones(from_zone):
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
		elif card.has_acted_this_turn:
			action_label.text = card.card_name + " has already acted this turn."
		elif card.creature_mode == Card.CreatureMode.DEFENSE:
			action_label.text = card.card_name + " is in defense mode and cannot attack."
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
			action_label.text = card.card_name + " attacking " + target_card.card_name + "..."
			resolve_pending_attack()
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
		if game_manager.attack_restrictions.has(selected_attacker.card_owner):
			action_label.text = "Cannot attack! Restricted for " + str(game_manager.attack_restrictions[selected_attacker.card_owner].turns) + " more turns"
			return
		pending_attack_target = game_manager.other_player
		check_for_possible_intercepts()
	else:
		action_label.text = "Select your creature first to attack"

func _creature_can_attack(card: Card) -> bool:
	return (
		card.card_type == Card.CardType.CREATURE
		and not card.has_acted_this_turn
		and not card.is_sleeping
		and game_manager.turn_number > 0
		and card.creature_mode == Card.CreatureMode.ATTACK
		and card.current_zone != null
		and card.current_zone.zone_type == Zone.ZoneType.FRONTLINE
		and not game_manager.attack_restrictions.has(card.card_owner)
	)

func _creature_can_move(card: Card) -> bool:
	return (
		card.card_type == Card.CardType.CREATURE
		and not card.has_moved_this_turn
		and not card.summoned_this_turn
		and not card.is_sleeping
	)

func _creature_can_change_stance(card: Card) -> bool:
	return (
		card.card_type == Card.CardType.CREATURE
		and not card.has_acted_this_turn
		and not card.summoned_this_turn
		and not card.is_sleeping
	)

func can_intercept(defender: Card, attacker: Card) -> bool:
	# Structures do not intercept, so this check only needs to worry about creatures
	if defender.card_type != Card.CardType.CREATURE:
		return false
	if defender.is_sleeping:
		return false
	if defender.creature_mode == Card.CreatureMode.DEFENSE:
		return true
	if defender.creature_mode == Card.CreatureMode.ATTACK and defender.get_effective_speed() > attacker.get_effective_speed():
		return true
	return false

func check_for_possible_intercepts() -> void:
	var possible_interceptors: Array[Card] = []
	
	var defender: Player = pending_attack_target if pending_attack_target is Player else pending_attack_target.card_owner
	
	for zone in defender.frontline_zones + defender.reserve_zones:
		for card in zone.cards:
			if can_intercept(card, selected_attacker):
				possible_interceptors.append(card)
	
	if possible_interceptors.size() > 0:
		var names = []
		for card in possible_interceptors:
			names.append(card.card_name)
		action_label.text = "Possible interceptors: " + ", ".join(names) + " - Click one to intercept or click 'No Intercept'"
		show_no_intercept_button()
	else:
		action_label.text = "No possible interceptors, attacking directly!"
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
	action_label.text = "No intercept - attacking directly!"
	resolve_pending_attack()

func resolve_pending_attack() -> void:
	_remove_no_intercept_button()

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

	action_label.text = action.attacker.card_name + " declares an attack!"
	_offer_priority()

func _offer_priority() -> void:
	var player := game_manager.priority_player
	var responses := game_manager.get_priority_responses(player)

	# In auto mode, skip the prompt if neither player has anything to respond with
	if auto_priority:
		var opponent_responses := game_manager.get_priority_responses(game_manager.get_opponent(player))
		if responses.is_empty() and opponent_responses.is_empty():
			_execute_top_of_stack()
			return

	_show_priority_prompt(player, responses)

func _show_priority_prompt(player: Player, responses: Array) -> void:
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

	for response in responses:
		var btn := Button.new()
		btn.text = "Play: " + response.card_name
		btn.pressed.connect(_on_priority_response_chosen.bind(response))
		vbox.add_child(btn)

	var pass_btn := Button.new()
	pass_btn.text = "Pass Priority"
	pass_btn.pressed.connect(_on_priority_pass_pressed)
	vbox.add_child(pass_btn)

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
		var ability := CardAction.new()
		ability.type = CardAction.Type.ABILITY
		ability.source_player = card.card_owner
		ability.card = card
		ability.attacker = top.attacker
		ability.interceptor = top.interceptor
		ability.target = top.target
		game_manager.push_to_stack(ability)
		action_label.text = card.card_name + " responds!"
		_offer_priority()

func _finish_post_execute(source_player: Player) -> void:
	game_manager.current_phase = GameManager.GamePhase.MAIN
	# Auto-fizzle any ATTACK on the stack whose attacker is no longer on the board
	while not game_manager.action_stack.is_empty():
		var next: CardAction = game_manager.action_stack.back()
		if next.type == CardAction.Type.ATTACK and not _is_attacker_on_board(next.attacker, next.source_player):
			game_manager.action_stack.pop_back()
			action_label.text = next.attacker.card_name + "'s attack was cancelled!"
		else:
			break

	if not game_manager.action_stack.is_empty():
		game_manager.consecutive_passes = 0
		game_manager.priority_player = game_manager.get_opponent(source_player)
		_offer_priority()
	elif not _queued_attackers.is_empty():
		_advance_attack_queue.call_deferred()
	else:
		update_ui()

func _get_retreating_askelladen(attacker: Card, defender: Card) -> Askelladen:
	if attacker is Askelladen and not attacker.is_face_down \
			and defender.get_effective_speed() <= attacker.get_effective_speed() \
			and not game_manager.is_guardian_protected(defender, attacker):
		return attacker as Askelladen
	if defender is Askelladen and not defender.is_face_down \
			and attacker.get_effective_speed() <= defender.get_effective_speed() \
			and not game_manager.is_guardian_protected(attacker, defender):
		return defender as Askelladen
	return null

# Returns true when Askelladen's retreat condition is met but Guardian blocked it.
func _guardian_blocked_retreat(attacker: Card, defender: Card) -> bool:
	if attacker is Askelladen and not attacker.is_face_down \
			and defender.get_effective_speed() <= attacker.get_effective_speed() \
			and game_manager.is_guardian_protected(defender, attacker):
		return true
	if defender is Askelladen and not defender.is_face_down \
			and attacker.get_effective_speed() <= defender.get_effective_speed() \
			and game_manager.is_guardian_protected(attacker, defender):
		return true
	return false

func _send_to_deck_bottom(card: Card) -> void:
	if card.current_zone:
		card.current_zone.remove_card(card)
	var owner := card.card_owner
	owner.deck_zone.cards.append(card)
	card.current_zone = owner.deck_zone
	card.has_acted_this_turn = false
	card.has_moved_this_turn = false
	card.is_sleeping = false
	card.sleeping_from = null

func _show_retreat_prompt(ask_card: Askelladen) -> void:
	var panel := PanelContainer.new()
	panel.name = "RetreatPromptPanel"
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
	lbl.text = "Tactful Retreat?\nReturn both creatures to the bottom of their decks?"
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
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -120
	panel.offset_right = 120
	panel.offset_top = -40
	panel.offset_bottom = 40

func _hide_retreat_prompt() -> void:
	var panel := get_node_or_null("RetreatPromptPanel")
	if panel:
		panel.queue_free()

func _on_retreat_yes() -> void:
	_hide_retreat_prompt()
	var action := _pending_retreat_action
	var defender := _pending_retreat_target
	_pending_retreat_action = null
	_pending_retreat_target = null
	_send_to_deck_bottom(action.attacker)
	_send_to_deck_bottom(defender)
	action_label.text = "Tactful Retreat! Both creatures returned to the bottom of their decks."
	update_ui()
	_finish_post_execute(action.source_player)

func _on_retreat_no() -> void:
	_hide_retreat_prompt()
	var action := _pending_retreat_action
	var defender := _pending_retreat_target
	_pending_retreat_action = null
	_pending_retreat_target = null
	game_manager.resolve_combat(action.attacker, defender)
	action_label.text = action.attacker.card_name + " fought " + defender.card_name + "!"
	action.attacker.has_acted_this_turn = true
	_finish_post_execute(action.source_player)

func _execute_top_of_stack() -> void:
	_hide_priority_prompt()
	if game_manager.action_stack.is_empty():
		update_ui()
		return

	var action: CardAction = game_manager.action_stack.pop_back()

	match action.type:
		CardAction.Type.ABILITY:
			if action.card is HexCard:
				var hex := action.card as HexCard
				var def_card: Card = action.interceptor if action.interceptor != null else (action.target if action.target is Card else null)
				game_manager.activate_hex(hex, action.attacker, def_card)
				action_label.text = hex.card_name + " triggered! " + action.attacker.card_name + " was sent to the abyss!"

		CardAction.Type.ATTACK:
			game_manager.current_phase = GameManager.GamePhase.COMBAT
			action.attacker.reveal_from_stealth()
			var actual_target = action.interceptor if action.interceptor != null else action.target
			if actual_target is Card:
				var ask := _get_retreating_askelladen(action.attacker, actual_target)
				if ask != null:
					_pending_retreat_action = action
					_pending_retreat_target = actual_target
					_show_retreat_prompt(ask)
					return  # Wait for player choice before advancing
				var blocked := _guardian_blocked_retreat(action.attacker, actual_target)
				game_manager.resolve_combat(action.attacker, actual_target)
				if blocked:
					action_label.text = "Asaruludu's Guardian prevented " + action.attacker.card_name + "'s Tactful Retreat!"
				else:
					action_label.text = action.attacker.card_name + " fought " + actual_target.card_name + "!"
			elif actual_target is Player:
				actual_target.lose_followers(action.attacker.get_effective_strength())
				action_label.text = action.attacker.card_name + " dealt " + str(action.attacker.get_effective_strength()) + " damage to followers!"
			action.attacker.has_acted_this_turn = true

	_finish_post_execute(action.source_player)
	return

func _find_empty_player_zone() -> Zone:
	for zone in game_manager.current_player.frontline_zones + game_manager.current_player.reserve_zones:
		if zone.cards.size() == 0:
			return zone
	return null

func _is_attacker_on_board(attacker: Card, owner: Player) -> bool:
	for z in owner.frontline_zones + owner.reserve_zones:
		if attacker in z.cards:
			return true
	return false

func _on_draw_button_pressed() -> void:
	game_manager.player_chooses_draw()
	update_ui()
	hide_turn_choice()
	action_label.text = "Drew a card"

func _on_mana_button_pressed() -> void:
	game_manager.player_chooses_mana()
	update_ui()
	hide_turn_choice()
	action_label.text = "Gained 5 mana"

func _on_end_turn_button_pressed() -> void:
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

func _do_end_turn() -> void:
	print("=== TURN ENDED ===")
	game_manager.end_turn()
	update_ui()
	show_turn_choice()
	action_label.text = "Turn ended - Now controlling " + game_manager.current_player.player_name

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
			card.creature_mode = Card.CreatureMode.ATTACK
			card.is_face_down = false
			card.is_stealth = false
			card.has_acted_this_turn = false
			placed = true
			print("Again-Walker resurrected to reserve zone %d" % zone.zone_index)
			break
	if not placed:
		print("No empty reserve zone — Again-Walker stays in graveyard")
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
	update_ui()

func _on_enemy_followers_changed(new_followers: int) -> void:
	update_ui()

func _on_card_drag_released(card: Card, drop_pos: Vector2, card_rotated: bool, card_stealth: bool) -> void:
	# Sacrifice-by-drag: card with creature_sacrifice_cost dropped onto a friendly creature
	if card.card_type == Card.CardType.CREATURE and card.creature_sacrifice_cost > 0:
		for zu in _board_zone_uis:
			if not zu.get_global_rect().has_point(drop_pos):
				continue
			if zu._is_enemy or zu.zone.cards.size() == 0:
				continue
			var target: Card = zu.zone.cards[0]
			if target.card_type != Card.CardType.CREATURE or target.card_owner != game_manager.current_player:
				continue
			# Check other costs (mana etc.) with creature_sacrifice_cost zeroed
			var orig := card.creature_sacrifice_cost
			card.creature_sacrifice_cost = 0
			var affordable := game_manager.can_play_card(game_manager.current_player, card, game_manager.current_player.frontline_zones[0])
			card.creature_sacrifice_cost = orig
			if not affordable:
				action_label.text = "Cannot afford " + card.card_name + "!"
				return
			_awaiting_drag_sacrifice_zone = true
			_drag_sacrifice_card = card
			_drag_sacrifice_target = target
			_drag_sacrifice_mode = "stealth" if card_stealth else ("defense" if card_rotated else "attack")
			action_label.text = "Click a zone to summon " + card.card_name + " (you may click " + target.card_name + "'s zone)"
			update_ui()
			return

	# Non-targeted spell dropped on any friendly zone (occupied or not): find an empty zone and cast.
	if card.card_type == Card.CardType.SPELL and not card.targets:
		for zu in _board_zone_uis:
			if zu.get_global_rect().has_point(drop_pos) and not zu._is_enemy:
				var empty_zone := _find_empty_player_zone()
				if empty_zone != null:
					selected_card = card
					_on_empty_zone_pressed(empty_zone)
				else:
					action_label.text = "No empty zone available to cast " + card.card_name + "!"
				return

	for zu in _board_zone_uis + _enemy_zone_uis:
		if zu.get_global_rect().has_point(drop_pos) and zu.can_accept_card(card):
			_on_card_dropped_to_zone(card, zu.zone, card_rotated, card_stealth)
			return
	update_ui()

func _cast_targeted_spell(spell: Card, target: Card) -> void:
	if game_manager.can_play_card(game_manager.current_player, spell, null):
		if spell.pay_costs(game_manager.current_player):
			(spell as SpellCard).resolve(game_manager, target)
			game_manager.current_player.hand_zone.cards.erase(spell)
			game_manager.current_player.move_card(spell, game_manager.current_player.graveyard_zone)
			action_label.text = "Cast " + spell.card_name + " on " + target.card_name + "!"
			awaiting_spell_target = false
			spell_waiting_for_target = null
			selected_card = null
			update_ui()
		else:
			action_label.text = "Cannot afford " + spell.card_name + "!"
	else:
		action_label.text = "Cannot cast " + spell.card_name + "!"

func _on_card_dropped_to_zone(card: Card, zone: Zone, is_rotated: bool = false, is_stealth: bool = false) -> void:
	if card is BitMeseri:
		if zone.cards.size() > 0:
			_cast_targeted_spell(card, zone.cards[0])
		return
	selected_card = card
	for vc in _hand_visual_cards:
		vc.set_highlighted(vc.card_data == card)
	if card.card_type == Card.CardType.CREATURE:
		if is_stealth:
			placement_mode = "stealth"
		else:
			placement_mode = "defense" if is_rotated else "attack"
		_pending_drop_zone = null
		_on_empty_zone_pressed(zone)
	else:
		_pending_drop_zone = null
		_on_empty_zone_pressed(zone)



func cleanup() -> void:
	if game_manager:
		game_manager.queue_free()
