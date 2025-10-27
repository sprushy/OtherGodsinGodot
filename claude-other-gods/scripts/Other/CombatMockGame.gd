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

@onready var mana_label = $ScrollContainer/VBoxContainer/StatsContainer/ManaLabel
@onready var followers_label = $ScrollContainer/VBoxContainer/StatsContainer/FollowersLabel
@onready var enemy_followers_label = $ScrollContainer/VBoxContainer/StatsContainer/EnemyFollowersLabel
@onready var choice_container = $ScrollContainer/VBoxContainer/ChoiceContainer
@onready var draw_button = $ScrollContainer/VBoxContainer/ChoiceContainer/DrawButton
@onready var mana_button = $ScrollContainer/VBoxContainer/ChoiceContainer/ManaButton
@onready var end_turn_button = $ScrollContainer/VBoxContainer/EndTurnButton
@onready var turn_label = $ScrollContainer/VBoxContainer/TurnLabel
@onready var hand_container = $ScrollContainer/VBoxContainer/HandContainer
@onready var board_container = $ScrollContainer/VBoxContainer/BoardContainer
@onready var enemy_board_container = $ScrollContainer/VBoxContainer/EnemyBoardContainer
@onready var action_label = $ScrollContainer/VBoxContainer/ActionLabel
@onready var placement_container = $ScrollContainer/VBoxContainer/PlacementContainer
@onready var attack_mode_btn = $ScrollContainer/VBoxContainer/PlacementContainer/AttackModeBtn
@onready var defense_mode_btn = $ScrollContainer/VBoxContainer/PlacementContainer/DefenseModeBtn
@onready var stealth_mode_btn = $ScrollContainer/VBoxContainer/PlacementContainer/StealthModeBtn

var game_manager: GameManager

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
		warrior.speed = 2
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
	
	# Add an enemy structure for testing UI display
	var structure1: Card = WardingStone.new()
	structure1.card_owner = player2
	player2.frontline_zones[0].add_card(structure1)

func show_turn_choice() -> void:
	choice_container.visible = true
	end_turn_button.visible = false
	draw_button.disabled = false
	mana_button.disabled = false
	
	# Disable all card interactions during choice phase
	for child in hand_container.get_children():
		if child is Button:
			child.disabled = true
	for child in board_container.get_children():
		if child is Button:
			child.disabled = true
	placement_container.visible = false

func hide_turn_choice() -> void:
	choice_container.visible = false
	end_turn_button.visible = true
	
	# Re-enable card interactions after choice
	for child in hand_container.get_children():
		if child is Button:
			child.disabled = false
	for child in board_container.get_children():
		if child is Button:
			child.disabled = false

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
	
	var label = Label.new()
	label.text = game_manager.current_player.player_name + "'s Hand:"
	hand_container.add_child(label)
	
	print("Drawing hand for: ", game_manager.current_player.player_name)
	print("Hand size: ", game_manager.current_player.hand_zone.cards.size())
	
	for card in game_manager.current_player.hand_zone.cards:
		print("  Card in hand: ", card.card_name, " Type: ", card.card_type)
		var btn = Button.new()
		var cost_str = str(card.mana_cost) + "M"
		if card.sacrifice_cost > 0:
			cost_str += " " + str(card.sacrifice_cost) + "F"
		
		if card.card_type == Card.CardType.CREATURE:
			btn.text = card.card_name + " (" + cost_str + ")\nSTR:" + str(card.strength) + " RES:" + str(card.resilience) + " SPD:" + str(card.speed)
		elif card.card_type == Card.CardType.SPELL:
			btn.text = card.card_name + " (SPELL) (" + cost_str + ")\nSPD:" + str(card.speed)
		# --- STRUCTURE UI CHANGE START ---
		elif card.card_type == Card.CardType.STRUCTURE:
			btn.text = card.card_name + " (STRUCTURE) (" + cost_str + ")\nRES:" + str(card.resilience)
		# --- STRUCTURE UI CHANGE END ---
		else:
			btn.text = card.card_name + " (" + cost_str + ")"
		
		btn.pressed.connect(_on_hand_card_pressed.bind(card))
		hand_container.add_child(btn)

func draw_board() -> void:
	for child in board_container.get_children():
		child.queue_free()
	
	var label = Label.new()
	label.text = game_manager.current_player.player_name + "'s Board (Frontline):"
	board_container.add_child(label)
	
	for i in range(7):
		var zone = game_manager.current_player.frontline_zones[i]
		var btn = Button.new()
		if zone.cards.size() > 0:
			var card = zone.cards[0]
			if card.card_type == Card.CardType.CREATURE:
				var mode_text = "???" if card.is_stealth else ("DEF" if card.creature_mode == Card.CreatureMode.DEFENSE else "ATK")
				var acted = " ✓" if card.has_acted_this_turn else ""
				btn.text = (card.card_name if not card.is_stealth else "Hidden") + "\n" + mode_text + " STR:" + str(card.get_effective_strength()) + " RES:" + str(card.get_effective_resilience()) + " SPD:" + str(card.get_effective_speed()) + acted
			elif card.card_type == Card.CardType.SPELL:
				btn.text = card.card_name + "\n(SPELL)"
			# --- STRUCTURE UI CHANGE START ---
			elif card.card_type == Card.CardType.STRUCTURE:
				btn.text = card.card_name + "\n(STRUCTURE) RES:" + str(card.resilience)
			# --- STRUCTURE UI CHANGE END ---
			else:
				btn.text = card.card_name
			btn.pressed.connect(_on_board_card_pressed.bind(card))
		else:
			btn.text = "Empty [" + str(i) + "]"
			btn.pressed.connect(_on_empty_zone_pressed.bind(zone))
		board_container.add_child(btn)

func draw_enemy_board() -> void:
	for child in enemy_board_container.get_children():
		child.queue_free()
	
	var label = Label.new()
	label.text = game_manager.other_player.player_name + "'s Board (Frontline):"
	enemy_board_container.add_child(label)
	
	for i in range(7):
		var zone = game_manager.other_player.frontline_zones[i]
		var btn = Button.new()
		if zone.cards.size() > 0:
			var card = zone.cards[0]
			if card.card_type == Card.CardType.CREATURE:
				var mode_text = "???" if card.is_stealth else ("DEF" if card.creature_mode == Card.CreatureMode.DEFENSE else "ATK")
				btn.text = (card.card_name if not card.is_stealth else "Hidden") + "\n" + mode_text + " STR:" + str(card.get_effective_strength()) + " RES:" + str(card.get_effective_resilience()) + " SPD:" + str(card.get_effective_speed())
			elif card.card_type == Card.CardType.SPELL:
				btn.text = card.card_name + "\n(SPELL)"
			# --- STRUCTURE UI CHANGE START ---
			elif card.card_type == Card.CardType.STRUCTURE:
				btn.text = card.card_name + "\n(STRUCTURE) RES:" + str(card.resilience)
			# --- STRUCTURE UI CHANGE END ---
			else:
				btn.text = card.card_name
			btn.pressed.connect(_on_enemy_card_pressed.bind(card))
		else:
			btn.text = "Empty [" + str(i) + "]"
		enemy_board_container.add_child(btn)
	
	var followers_btn = Button.new()
	followers_btn.text = "Attack " + game_manager.other_player.player_name + " Followers (" + str(game_manager.other_player.followers) + ")"
	followers_btn.pressed.connect(_on_attack_followers_pressed)
	enemy_board_container.add_child(followers_btn)

func _on_hand_card_pressed(card: Card) -> void:
	selected_card = card
	if card.card_type == Card.CardType.SPELL:
		# Check if this is a targeted spell like BitMeseri
		if card is BitMeseri:
			awaiting_spell_target = true
			spell_waiting_for_target = card
			action_label.text = "Select a target creature or structure for " + card.card_name
		else:
			# Non-targeted spells like CircleOfRebirth
			action_label.text = "Selected spell: " + card.card_name + " - Click a zone to cast it there"
	elif card.card_type == Card.CardType.CREATURE:
		placement_container.visible = true
		action_label.text = "Selected: " + card.card_name + " - Choose placement mode, then click empty zone"
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

func _on_defense_mode_pressed() -> void:
	placement_mode = "defense"
	action_label.text = "Defense mode selected - Click empty zone to place"

func _on_stealth_mode_pressed() -> void:
	placement_mode = "stealth"
	action_label.text = "Stealth mode selected - Click empty zone to place"

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
			if card.card_type == Card.CardType.CREATURE or card.card_type == Card.CardType.STRUCTURE:
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
				action_label.text = "BitMeseri can only target creatures or structures!"
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
	# Check if we're selecting a target for a spell
	if awaiting_spell_target and spell_waiting_for_target:
		if spell_waiting_for_target is BitMeseri:
			if target_card.card_type == Card.CardType.CREATURE or target_card.card_type == Card.CardType.STRUCTURE:
				if game_manager.can_play_card(game_manager.current_player, spell_waiting_for_target, null):
					# Cast the spell with the target
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
				action_label.text = "BitMeseri can only target creatures or structures!"
		return
	
	if game_manager.attack_restrictions.has(selected_attacker.card_owner):
		action_label.text = "Cannot attack! Restricted for " + str(game_manager.attack_restrictions[selected_attacker.card_owner]) + " more turns"
	return

# In _on_attack_followers_pressed, add at the start:
	if selected_attacker:
		if game_manager.attack_restrictions.has(selected_attacker.card_owner):
			action_label.text = "Cannot attack! Restricted for " + str(game_manager.attack_restrictions[selected_attacker.card_owner]) + " more turns"
		return
	if pending_attack_target != null:
		# Since Structures cannot intercept, this check remains on CREATUREs
		if target_card.card_owner == player2 and can_intercept(target_card, selected_attacker):
			selected_interceptor = target_card
			action_label.text = target_card.card_name + " will intercept! Resolving combat..."
			resolve_pending_attack()
		else:
			action_label.text = "This card cannot intercept"
		return
	
	if selected_attacker:
		if target_card.card_type == Card.CardType.CREATURE or target_card.card_type == Card.CardType.STRUCTURE: # Attack targets can be Structures
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
	
	if selected_interceptor:
		game_manager.resolve_combat(selected_attacker, selected_interceptor)
		action_label.text = selected_attacker.card_name + " fought " + selected_interceptor.card_name + "!"
	else:
		if pending_attack_target is Player:
			pending_attack_target.lose_followers(selected_attacker.get_effective_strength())
			action_label.text = selected_attacker.card_name + " dealt " + str(selected_attacker.get_effective_strength()) + " damage to followers!"
		elif pending_attack_target is Card:
			game_manager.resolve_combat(selected_attacker, pending_attack_target)
			action_label.text = selected_attacker.card_name + " attacked " + pending_attack_target.card_name + "!"
	
	selected_attacker.has_acted_this_turn = true
	selected_attacker = null
	selected_interceptor = null
	pending_attack_target = null
	update_ui()

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

func cleanup() -> void:
	if game_manager:
		game_manager.queue_free()
