# MainMenu.gd
extends Control

@onready var menu_container = $MenuContainer
@onready var game_container = $GameContainer

func _ready() -> void:
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)

	var mock_btn = $MenuContainer/MockGameButton
	var deck_btn = $MenuContainer/DeckBuilderButton

	if mock_btn:
		mock_btn.pressed.connect(_on_mock_game_pressed)
	if deck_btn:
		deck_btn.pressed.connect(_on_deck_builder_pressed)

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
	print("Deck Builder - Not yet implemented")

func _on_mock_game_pressed() -> void:
	show_game()
	get_node("GameContainer/MockGame").start_game()

func _on_back_to_menu_pressed() -> void:
	show_menu()
	var mock_game = get_node("GameContainer/MockGame")
	if mock_game and mock_game.has_method("cleanup"):
		mock_game.cleanup()


func _on_attack_mode_btn_pressed() -> void:
	pass # Replace with function body.


func _on_defense_mode_btn_pressed() -> void:
	pass # Replace with function body.


func _on_stealth_mode_btn_pressed() -> void:
	pass # Replace with function body.


func _on_toggle_mode_button_pressed() -> void:
	pass # Replace with function body.
