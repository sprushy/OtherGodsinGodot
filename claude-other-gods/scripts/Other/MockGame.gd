# MockGame.gd
extends Control

var game_manager: GameManager
var player1: Player
var player2: Player

@onready var mana_label = $VBoxContainer/StatsContainer/ManaLabel
@onready var followers_label = $VBoxContainer/StatsContainer/FollowersLabel
@onready var choice_container = $VBoxContainer/ChoiceContainer
@onready var draw_button = $VBoxContainer/ChoiceContainer/DrawButton
@onready var mana_button = $VBoxContainer/ChoiceContainer/ManaButton
@onready var end_turn_button = $VBoxContainer/EndTurnButton
@onready var turn_label = $VBoxContainer/TurnLabel

func _ready() -> void:
	choice_container.visible = false
	end_turn_button.visible = false

func start_game() -> void:
	# Create game manager
	game_manager = GameManager.new()
	add_child(game_manager)
	
	# Create players
	player1 = Player.new()
	player1.player_name = "Player 1"
	game_manager.add_child(player1)
	
	player2 = Player.new()
	player2.player_name = "Player 2"
	game_manager.add_child(player2)
	
	# Wait for zones to initialize
	await get_tree().process_frame
	
	# Create mock decks
	create_mock_deck(player1)
	create_mock_deck(player2)
	
	# Setup game
	game_manager.setup_game()
	
	# Connect signals
	player1.mana_changed.connect(_on_player1_mana_changed)
	player1.followers_changed.connect(_on_player1_followers_changed)
	
	# Start first turn
	game_manager.turn_number = 0
	update_ui()
	show_turn_choice()

func create_mock_deck(player: Player) -> void:
	var deck: Array[Card] = []
	
	# Create god card
	var god = Card.new()
	god.card_name = "Mock God"
	god.is_god = true
	god.card_owner = player
	deck.append(god)
	
	# Create power cards
	for i in range(3):
		var power = Card.new()
		power.card_name = "Power " + str(i + 1)
		power.is_power = true
		power.card_owner = player
		deck.append(power)
	
	# Create regular cards
	for i in range(20):
		var card = Card.new()
		card.card_name = "Card " + str(i + 1)
		card.card_type = Card.CardType.CREATURE
		card.strength = randi_range(2, 5)
		card.resilience = randi_range(2, 5)
		card.speed = randi_range(1, 3)
		card.card_owner = player
		deck.append(card)
	
	# Build deck
	var builder = DeckBuilder.new()
	builder.build_deck(player, deck)

func show_turn_choice() -> void:
	choice_container.visible = true
	end_turn_button.visible = false
	draw_button.disabled = false
	mana_button.disabled = false

func hide_turn_choice() -> void:
	choice_container.visible = false
	end_turn_button.visible = true

func update_ui() -> void:
	var current = game_manager.current_player
	mana_label.text = "Mana: " + str(current.mana)
	followers_label.text = "Followers: " + str(current.followers)
	turn_label.text = "Turn " + str(game_manager.turn_number) + " - " + current.player_name

func _on_draw_button_pressed() -> void:
	game_manager.player_chooses_draw()
	update_ui()
	hide_turn_choice()
	print(game_manager.current_player.player_name + " drew a card")

func _on_mana_button_pressed() -> void:
	game_manager.player_chooses_mana()
	update_ui()
	hide_turn_choice()
	print(game_manager.current_player.player_name + " gained 4 mana")

func _on_end_turn_button_pressed() -> void:
	print("Ending turn for " + game_manager.current_player.player_name)
	game_manager.end_turn()
	update_ui()
	show_turn_choice()

func _on_player1_mana_changed(new_mana: int) -> void:
	if game_manager.current_player == player1:
		update_ui()

func _on_player1_followers_changed(new_followers: int) -> void:
	if game_manager.current_player == player1:
		update_ui()

func cleanup() -> void:
	if game_manager:
		game_manager.queue_free()
