extends Control

var player1: Player
var player2: Player
var selected_card: Card = null
var selected_attacker: Card = null
var selected_interceptor: Card = null
var pending_attack_target = null
var placement_mode: String = ""
var pending_resurrections: Array[Card] = []
var current_resurrection_index: int = 0
var awaiting_spell_target: bool = false
var spell_waiting_for_target: Card = null
var auto_priority: bool = true

@onready var mana_label = $VBoxContainer/StatsContainer/ManaLabel
@onready var followers_label = $VBoxContainer/StatsContainer/FollowersLabel
@onready var enemy_followers_label = $VBoxContainer/StatsContainer/EnemyFollowersLabel
@onready var choice_container = $VBoxContainer/ChoiceContainer
@onready var draw_button = $VBoxContainer/ChoiceContainer/DrawButton
@onready var mana_button = $VBoxContainer/ChoiceContainer/ManaButton
@onready var end_turn_button = $VBoxContainer/EndTurnButton
@onready var turn_label = $VBoxContainer/TurnLabel
@onready var hand_container = $VBoxContainer/HandContainer
@onready var board_container = $VBoxContainer/BoardContainer
@onready var enemy_board_container = $VBoxContainer/EnemyBoardContainer
@onready var action_label = $VBoxContainer/ActionLabel
@onready var placement_container = $VBoxContainer/PlacementContainer
@onready var attack_mode_btn = $VBoxContainer/PlacementContainer/AttackModeBtn
@onready var defense_mode_btn = $VBoxContainer/PlacementContainer/DefenseModeBtn
@onready var stealth_mode_btn = $VBoxContainer/PlacementContainer/StealthModeBtn

var game_manager: GameManager

# Visual UI state
var _hand_visual_cards: Array = []   # Array[VisualCard]
var _board_zone_uis: Array = []      # Array[BoardZoneUI]
var _enemy_zone_uis: Array = []      # Array[BoardZoneUI]
var _pending_drop_zone: Zone = null  # Zone queued by a drag-drop before mode selection

func _ready() -> void:
	choice_container.visible = false
	end_turn_button.visible = false
	placement_container.visible = false

	draw_button.pressed.connect(_on_draw_button_pressed)
	mana_button.pressed.connect(_on_mana_button_pressed)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	attack_mode_btn.pressed.connect(_on_attack_mode_pressed)
	defense_mode_btn.pressed.connect(_on_defense_mode_pressed)
	stealth_mode_btn.pressed.connect(_on_stealth_mode_pressed)

	var priority_toggle := CheckButton.new()
	priority_toggle.text = "Auto Priority"
	priority_toggle.button_pressed = auto_priority
	priority_toggle.toggled.connect(func(on: bool) -> void: auto_priority = on)
	$VBoxContainer/StatsContainer.add_child(priority_toggle)

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
	
	create_test_deck(player1)
	create_test_deck(player2)
	
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
	
	setup_enemy_board()
	
	game_manager.turn_number = 0
	update_ui()
	show_turn_choice()

func create_test_deck(player: Player) -> void:
	var deck: Array[Card] = []
	
	for i in range(3):
		var anzu: Card = Anzu.new()
		anzu.card_owner = player
		deck.append(anzu)
	
	# Warding Stone added to test deck
	for i in range(3):
		var wardingS: Card = WardingStone.new()
		wardingS.card_owner = player
		deck.append(wardingS)
	
	for i in range(2):
		var bitmeseri: Card = BitMeseri.new()
		bitmeseri.card_owner = player
		deck.append(bitmeseri)

	for i in range(2):
		var void_shield: Card = VoidShield.new()
		void_shield.card_owner = player
		deck.append(void_shield)
	
	for i in range(3):
		var bear: Card = BrownBear.new()
		bear.card_owner = player
		deck.append(bear)
	
	for i in range(4):
		var warrior: Card = Card.new()
		warrior.card_name = "Test Warrior " + str(i)
		warrior.card_type = Card.CardType.CREATURE
		var warrior_types: Array[String] = ["Warrior", "Animal"]
		warrior.card_types = warrior_types
		warrior.strength = 5
		warrior.resilience = 5
		warrior.speed = 4
		warrior.mana_cost = 2
		warrior.card_owner = player
		deck.append(warrior)
	
	deck.shuffle()
	for card in deck:
		player.deck_zone.add_card(card)
	
	print("Test deck built for ", player.player_name)
	print("  Deck size: ", player.deck_zone.cards.size())

func setup_enemy_board() -> void:
	var creature1: Card = Card.new()
	creature1.card_name = "Enemy Guard"
	creature1.card_type = Card.CardType.CREATURE
	creature1.strength = 4
	creature1.resilience = 6
	creature1.speed = 2
	creature1.creature_mode = Card.CreatureMode.DEFENSE
	creature1.card_owner = player2
	player2.frontline_zones[2].add_card(creature1)
	
	var creature2: Card = Card.new()
	creature2.card_name = "Enemy Striker"
	creature2.card_type = Card.CardType.CREATURE
	creature2.strength = 7
	creature2.resilience = 4
	creature2.speed = 3
	creature2.creature_mode = Card.CreatureMode.ATTACK
	creature2.card_owner = player2
	player2.frontline_zones[4].add_card(creature2)
	
	# Add a prepared VoidShield hex for testing
	var void_shield := VoidShield.new()
	void_shield.card_owner = player2
	void_shield.is_prepared = true
	void_shield.is_face_down = true
	player2.reserve_zones[3].add_card(void_shield)
	game_manager.prepared_hexes[void_shield] = -1  # Ready from the start

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
	var enemy = game_manager.other_player
	
	if current == player1:
		mana_label.text = "P1 Mana: " + str(player1.mana)
		followers_label.text = "P1 Followers: " + str(player1.followers)
		enemy_followers_label.text = "P2 Followers: " + str(player2.followers)
	else:
		mana_label.text = "P2 Mana: " + str(player2.mana)
		followers_label.text = "P2 Followers: " + str(player2.followers)
		enemy_followers_label.text = "P1 Followers: " + str(player1.followers)
	
	turn_label.text = "Turn " + str(game_manager.turn_number) + " - " + current.player_name + "'s Turn"
	
	draw_hand()
	draw_board()
	draw_enemy_board()

func draw_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	_hand_visual_cards.clear()

	var label = Label.new()
	label.text = game_manager.current_player.player_name + "'s Hand:"
	hand_container.add_child(label)
	
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	hand_container.add_child(row)

	for card in game_manager.current_player.hand_zone.cards:
		var vc := VisualCard.new()
		row.add_child(vc)
		vc.setup(card)
		vc.card_clicked.connect(_on_hand_card_pressed.bind(card))
		vc.card_drag_released.connect(_on_card_drag_released)
		_hand_visual_cards.append(vc)

func _make_zone_info_panel(label_text: String, zone: Zone, clickable: bool, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 100)
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

func _show_zone_contents(zone_name: String, zone: Zone) -> void:
	if zone.cards.size() == 0:
		action_label.text = zone_name + " is empty."
		return
	var names: Array = []
	for card in zone.cards:
		names.append(card.card_name)
	action_label.text = zone_name + " (" + str(zone.cards.size()) + "): " + ", ".join(names)

func draw_board() -> void:
	for child in board_container.get_children():
		child.queue_free()
	_board_zone_uis.clear()

	var board_row := HBoxContainer.new()
	board_row.add_theme_constant_override("separation", 4)
	board_container.add_child(board_row)

	board_row.add_child(_make_zone_info_panel("Deck", game_manager.current_player.deck_zone, false, Color(0.2, 0.3, 0.5)))

	for i in range(5):
		var zone = game_manager.current_player.frontline_zones[i]
		var zu := BoardZoneUI.new()
		board_row.add_child(zu)
		zu.setup(zone, game_manager, game_manager.current_player, i, _on_card_dropped_to_zone, false, "front line")
		zu.zone_clicked.connect(_on_empty_zone_pressed)
		zu.card_clicked.connect(_on_board_card_pressed)
		_board_zone_uis.append(zu)

	board_row.add_child(_make_zone_info_panel("Grave", game_manager.current_player.graveyard_zone, true, Color(0.3, 0.5, 0.3)))

	var back_label := Label.new()
	back_label.text = "Back Line"
	board_container.add_child(back_label)

	var reserve_row := HBoxContainer.new()
	reserve_row.add_theme_constant_override("separation", 4)
	board_container.add_child(reserve_row)

	reserve_row.add_child(_make_zone_info_panel("God", game_manager.current_player.god_zone, false, Color(0.9, 0.75, 0.2)))

	for i in range(5):
		var zone = game_manager.current_player.reserve_zones[i]
		var zu := BoardZoneUI.new()
		reserve_row.add_child(zu)
		zu.setup(zone, game_manager, game_manager.current_player, i, _on_card_dropped_to_zone, false, "back line")
		zu.zone_clicked.connect(_on_empty_zone_pressed)
		zu.card_clicked.connect(_on_board_card_pressed)
		_board_zone_uis.append(zu)

	reserve_row.add_child(_make_zone_info_panel("Abyss", game_manager.current_player.abyss_zone, true, Color(0.6, 0.1, 0.6)))

func draw_enemy_board() -> void:
	for child in enemy_board_container.get_children():
		child.queue_free()
	_enemy_zone_uis.clear()

	var enemy_back_label := Label.new()
	enemy_back_label.text = "Back Line"
	enemy_board_container.add_child(enemy_back_label)

	var enemy_reserve_row := HBoxContainer.new()
	enemy_reserve_row.add_theme_constant_override("separation", 4)
	enemy_board_container.add_child(enemy_reserve_row)

	enemy_reserve_row.add_child(_make_zone_info_panel("God", game_manager.other_player.god_zone, false, Color(0.9, 0.75, 0.2)))

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
	enemy_board_container.add_child(enemy_row)

	enemy_row.add_child(_make_zone_info_panel("Deck", game_manager.other_player.deck_zone, false, Color(0.2, 0.3, 0.5)))

	for i in range(5):
		var zone = game_manager.other_player.frontline_zones[i]
		var zu := BoardZoneUI.new()
		enemy_row.add_child(zu)
		zu.setup(zone, game_manager, game_manager.other_player, i, _on_card_dropped_to_zone, true, "front line")
		zu.card_clicked.connect(_on_enemy_card_pressed)
		_enemy_zone_uis.append(zu)

	enemy_row.add_child(_make_zone_info_panel("Grave", game_manager.other_player.graveyard_zone, true, Color(0.3, 0.5, 0.3)))

	var followers_btn = Button.new()
	followers_btn.text = "Attack " + game_manager.other_player.player_name + " Followers (" + str(game_manager.other_player.followers) + ")"
	followers_btn.pressed.connect(_on_attack_followers_pressed)
	enemy_board_container.add_child(followers_btn)

func _on_hand_card_pressed(card: Card) -> void:
	selected_card = card
	for vc in _hand_visual_cards:
		vc.set_highlighted(vc.card_data == card)
	if card.card_type == Card.CardType.SPELL:
		if card is BitMeseri:
			action_label.text = "BitMeseri - Drag onto a creature or structure to void it"
		else:
			action_label.text = "Selected spell: " + card.card_name + " - Click a zone to cast it there"
	elif card.card_type == Card.CardType.CREATURE:
		action_label.text = card.card_name + " selected - Right-click to rotate (defense), drag to place"
	# --- STRUCTURE UI CHANGE START ---
	elif card.card_type == Card.CardType.STRUCTURE:
		# Structures don't need mode selection, but we set placement_mode for the next step to trigger the placement logic
		placement_mode = "defense" 
		placement_container.visible = false 
		action_label.text = "Selected Structure: " + card.card_name + " - Click an empty zone to place it"
	# --- STRUCTURE UI CHANGE END ---
	else:
		action_label.text = "Card type not yet supported in this test UI"

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
	# Check if we're placing a resurrected creature
	if pending_resurrections.size() > 0:
		var card = pending_resurrections[current_resurrection_index]
		if zone.cards.size() == 0:
			var owner = card.card_owner
			if (zone in owner.frontline_zones or zone in owner.reserve_zones):
				owner.move_card(card, zone)
				card.has_acted_this_turn = false
				card.is_stealth = false
				card.is_face_down = false
				card.creature_mode = Card.CreatureMode.ATTACK if placement_mode == "attack" else Card.CreatureMode.DEFENSE
				action_label.text = "Resurrected " + card.card_name + " in " + placement_mode.to_upper() + " mode!"
				
				current_resurrection_index += 1
				if current_resurrection_index >= pending_resurrections.size():
					pending_resurrections.clear()
					current_resurrection_index = 0
					placement_mode = ""
					placement_container.visible = false
					action_label.text = "All creatures resurrected!"
					update_ui()
				else:
					show_resurrection_choice()
			else:
				action_label.text = "Must place in that player's zones!"
		else:
			action_label.text = "Zone is occupied!"
		return
	
	if selected_card:
		if selected_card.card_type == Card.CardType.SPELL:
			if game_manager.can_play_card(game_manager.current_player, selected_card, zone):
				if selected_card is CircleOfRebirth:
					var resurrect_cards = get_resurrectible_cards()
					if resurrect_cards.size() > 0:
						game_manager.play_card(game_manager.current_player, selected_card, zone)
						pending_resurrections = resurrect_cards
						current_resurrection_index = 0
						selected_card = null
						show_resurrection_choice()
					else:
						game_manager.play_card(game_manager.current_player, selected_card, zone)
						action_label.text = "Cast " + selected_card.card_name + " but no creatures to resurrect!"
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
				if placement_mode == "stealth":
					game_manager.play_creature_stealth(game_manager.current_player, selected_card, zone)
					action_label.text = "Played " + selected_card.card_name + " in STEALTH!"
				else:
					if placement_mode == "attack":
						selected_card.creature_mode = Card.CreatureMode.ATTACK
					else:
						selected_card.creature_mode = Card.CreatureMode.DEFENSE
					game_manager.play_card(game_manager.current_player, selected_card, zone)
					action_label.text = "Played " + selected_card.card_name + " in " + placement_mode.to_upper() + " mode!"
				
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

func show_resurrection_choice() -> void:
	if current_resurrection_index < pending_resurrections.size():
		var card = pending_resurrections[current_resurrection_index]
		placement_container.visible = true
		action_label.text = "Resurrecting " + card.card_name + " (" + str(current_resurrection_index + 1) + "/" + str(pending_resurrections.size()) + ") - Choose Attack or Defense, then click empty zone on " + card.card_owner.player_name + "'s board"
		placement_mode = ""

func _on_board_card_pressed(card: Card) -> void:
	# Check if we're selecting a target for a spell
	if awaiting_spell_target and spell_waiting_for_target:
		if spell_waiting_for_target is BitMeseri:
			if card.card_type == Card.CardType.CREATURE or card.card_type == Card.CardType.STRUCTURE or card.card_type == Card.CardType.EQUIPMENT:
				if game_manager.can_play_card(game_manager.current_player, spell_waiting_for_target, null):
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
			var btn = enemy_board_container.get_node_or_null("NoInterceptBtn")
			if btn:
				btn.queue_free()
			
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
		action_label.text = card.card_name + " is a structure and cannot attack or move."
		return
	
	if card.card_type != Card.CardType.CREATURE:
		action_label.text = "That card cannot perform an action."
		return

	if card.has_acted_this_turn:
		action_label.text = card.card_name + " has already acted this turn."
		return

	if card.creature_mode == Card.CreatureMode.DEFENSE:
		action_label.text = card.card_name + " is in defense mode and cannot attack."
		return

	if selected_attacker == card:
		game_manager.creature_change_mode(card)
		var new_mode = "ATTACK" if card.creature_mode == Card.CreatureMode.ATTACK else "DEFENSE"
		action_label.text = card.card_name + " switched to " + new_mode
		selected_attacker = null
		update_ui()
	else:
		selected_attacker = card
		action_label.text = "Selected attacker: " + card.card_name + " - Click enemy target or followers"

func _on_enemy_card_pressed(target_card: Card) -> void:
	# Spell targeting takes priority
	if awaiting_spell_target and spell_waiting_for_target:
		if spell_waiting_for_target is BitMeseri:
			if target_card.card_type == Card.CardType.CREATURE or target_card.card_type == Card.CardType.STRUCTURE or target_card.card_type == Card.CardType.EQUIPMENT:
				if game_manager.can_play_card(game_manager.current_player, spell_waiting_for_target, null):
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
			var no_btn = enemy_board_container.get_node_or_null("NoInterceptBtn")
			if no_btn:
				no_btn.queue_free()
			selected_interceptor = target_card
			action_label.text = target_card.card_name + " will intercept! Resolving combat..."
			resolve_pending_attack()
		else:
			action_label.text = "This card cannot intercept"
		return

	# Direct attack target selection
	if selected_attacker:
		if target_card.card_type == Card.CardType.CREATURE or target_card.card_type == Card.CardType.STRUCTURE:
			pending_attack_target = target_card
			action_label.text = selected_attacker.card_name + " attacking " + target_card.card_name + " - resolving..."
			resolve_pending_attack()
		else:
			action_label.text = "Can only attack creatures or structures"
	else:
		action_label.text = "Select your creature first to attack"

func _on_attack_followers_pressed() -> void:
	
	if selected_attacker:
		if not selected_attacker is Card:
			action_label.text = "Invalid attacker selected"
			selected_attacker = null
			return
		if game_manager.attack_restrictions.has(selected_attacker.card_owner):
			action_label.text = "Cannot attack! Restricted for " + str(game_manager.attack_restrictions[selected_attacker.card_owner]) + " more turns"
			return
		pending_attack_target = game_manager.other_player
		check_for_possible_intercepts()
	else:
		action_label.text = "Select your creature first to attack"

func can_intercept(defender: Card, attacker: Card) -> bool:
	# Structures do not intercept, so this check only needs to worry about creatures
	if defender.card_type != Card.CardType.CREATURE:
		return false
	if defender.creature_mode == Card.CreatureMode.DEFENSE:
		return true
	if defender.creature_mode == Card.CreatureMode.ATTACK and defender.get_effective_speed() > attacker.get_effective_speed():
		return true
	return false

func check_for_possible_intercepts() -> void:
	var possible_interceptors: Array[Card] = []
	
	var defender = player2 if pending_attack_target == game_manager.other_player else pending_attack_target.card_owner
	
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
	var no_intercept_btn = Button.new()
	no_intercept_btn.text = "No Intercept - Allow Attack"
	no_intercept_btn.name = "NoInterceptBtn"
	no_intercept_btn.pressed.connect(_on_no_intercept_pressed)
	enemy_board_container.add_child(no_intercept_btn)

func _on_no_intercept_pressed() -> void:
	selected_interceptor = null
	action_label.text = "No intercept - attacking directly!"
	resolve_pending_attack()

func resolve_pending_attack() -> void:
	var no_intercept_btn = enemy_board_container.get_node_or_null("NoInterceptBtn")
	if no_intercept_btn:
		no_intercept_btn.queue_free()

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
	var existing = get_node_or_null("PriorityPromptPanel")
	if existing:
		existing.queue_free()

	var panel := PanelContainer.new()
	panel.name = "PriorityPromptPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
	style.border_color = Color(0.4, 0.7, 1.0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	panel.add_theme_stylebox_override("panel", style)

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

	panel.custom_minimum_size.x = 220
	add_child(panel)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -230
	panel.offset_right = -10
	panel.offset_top = 10

func _on_priority_pass_pressed() -> void:
	var panel = get_node_or_null("PriorityPromptPanel")
	if panel:
		panel.queue_free()
	game_manager.pass_priority()
	if game_manager.both_passed():
		_execute_top_of_stack()
	else:
		_offer_priority()

func _on_priority_response_chosen(card: Card) -> void:
	var panel = get_node_or_null("PriorityPromptPanel")
	if panel:
		panel.queue_free()

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

func _execute_top_of_stack() -> void:
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
			var actual_target = action.interceptor if action.interceptor != null else action.target
			if actual_target is Card:
				game_manager.resolve_combat(action.attacker, actual_target)
				action_label.text = action.attacker.card_name + " fought " + actual_target.card_name + "!"
			elif actual_target is Player:
				actual_target.lose_followers(action.attacker.get_effective_strength())
				action_label.text = action.attacker.card_name + " dealt " + str(action.attacker.get_effective_strength()) + " damage to followers!"
			action.attacker.has_acted_this_turn = true

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
		game_manager.priority_player = game_manager.get_opponent(action.source_player)
		_offer_priority()
	else:
		update_ui()

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
	print("=== TURN ENDED ===")
	game_manager.end_turn()
	update_ui()
	show_turn_choice()
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	pending_attack_target = null
	placement_mode = ""
	placement_container.visible = false
	action_label.text = "Turn ended - Now controlling " + game_manager.current_player.player_name

func _on_allow_ai_attack() -> void:
	pass

func _on_player_mana_changed(new_mana: int) -> void:
	if game_manager and game_manager.current_player == player1:
		update_ui()

func _on_player_followers_changed(new_followers: int) -> void:
	update_ui()

func _on_enemy_followers_changed(new_followers: int) -> void:
	update_ui()

func _on_card_drag_released(card: Card, drop_pos: Vector2, card_rotated: bool) -> void:
	for zu in _board_zone_uis + _enemy_zone_uis:
		if zu.get_global_rect().has_point(drop_pos) and zu.can_accept_card(card):
			_on_card_dropped_to_zone(card, zu.zone, card_rotated)
			return

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

func _on_card_dropped_to_zone(card: Card, zone: Zone, is_rotated: bool = false) -> void:
	if card is BitMeseri:
		if zone.cards.size() > 0:
			_cast_targeted_spell(card, zone.cards[0])
		return
	selected_card = card
	for vc in _hand_visual_cards:
		vc.set_highlighted(vc.card_data == card)
	if card.card_type == Card.CardType.CREATURE:
		placement_mode = "defense" if is_rotated else "attack"
		_pending_drop_zone = null
		_on_empty_zone_pressed(zone)
	else:
		_pending_drop_zone = null
		_on_empty_zone_pressed(zone)



func cleanup() -> void:
	if game_manager:
		game_manager.queue_free()
