# MainMenu.gd
extends Control

@onready var menu_container = $MenuContainer
@onready var game_container = $GameContainer

func _ready() -> void:
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)

	get_node("GameContainer/MockGame").visible = false
	get_node("GameContainer/CardTest").visible = false

	var mock_btn = $MenuContainer/MockGameButton
	var deck_btn = $MenuContainer/DeckBuilderButton
	var card_test_btn = $MenuContainer/CardTestButton

	if mock_btn:
		mock_btn.pressed.connect(_on_mock_game_pressed)
	if deck_btn:
		deck_btn.pressed.connect(_on_deck_builder_pressed)
	if card_test_btn:
		card_test_btn.pressed.connect(_on_card_test_pressed)

	show_menu()

func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size

func show_menu() -> void:
	menu_container.visible = true
	game_container.visible = false

func show_game() -> void:
	menu_container.visible = false
	game_container.visible = true

func _on_deck_builder_pressed() -> void:
	# Clean up any previous deck builder instance
	var existing := game_container.get_node_or_null("DeckBuilder")
	if existing:
		existing.queue_free()

	var db := DeckBuilderUI.new()
	db.name = "DeckBuilder"
	db.back_pressed.connect(func() -> void:
		db.queue_free()
		show_menu()
	)
	get_node("GameContainer/MockGame").visible = false
	get_node("GameContainer/CardTest").visible = false
	game_container.add_child(db)
	show_game()

func _on_mock_game_pressed() -> void:
	get_node("GameContainer/MockGame").visible = true
	get_node("GameContainer/CardTest").visible = false
	show_game()
	get_node("GameContainer/MockGame").start_game()

func _on_card_test_pressed() -> void:
	get_node("GameContainer/CardTest").visible = true
	get_node("GameContainer/MockGame").visible = false
	show_game()
	get_node("GameContainer/CardTest").start_game()

func _on_back_to_menu_pressed() -> void:
	show_menu()
	for node_name in ["MockGame", "CardTest"]:
		var game = get_node_or_null("GameContainer/" + node_name)
		if game and game.has_method("cleanup"):
			game.cleanup()
	var db := game_container.get_node_or_null("DeckBuilder")
	if db:
		db.queue_free()


func _on_attack_mode_btn_pressed() -> void:
	pass # Replace with function body.


func _on_defense_mode_btn_pressed() -> void:
	pass # Replace with function body.


func _on_stealth_mode_btn_pressed() -> void:
	pass # Replace with function body.


func _on_toggle_mode_button_pressed() -> void:
	pass # Replace with function body.
