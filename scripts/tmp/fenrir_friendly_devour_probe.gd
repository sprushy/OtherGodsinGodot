extends SceneTree

const BrownBearScript := preload("res://scripts/cards/Creatures/BrownBear.gd")

class TestCombatMockGame extends CombatMockGame:
	var routed_card: Card = null
	var pending_target_selection: bool = false

	func _is_turn_choice_pending() -> bool:
		return false

	func _has_pending_target_selection() -> bool:
		return pending_target_selection

	func _on_board_card_pressed(card: Card) -> void:
		routed_card = card
		pending_target_selection = false

	func _reject_pre_turn_action() -> void:
		pass

func _assert_state(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var player1 := Player.new()
	player1.player_name = "Player 1"

	var friendly_target := BrownBearScript.new()
	friendly_target.card_owner = player1
	player1.frontline_zones[2].add_card(friendly_target)

	var game := TestCombatMockGame.new()
	game.pending_target_selection = true
	game._on_creature_drag_started(friendly_target, friendly_target.current_zone)

	_assert_state(game.routed_card == friendly_target, "Friendly creature clicks should route through board target selection when targeting is active.")
	_assert_state(not game._bdrag_active, "Target selection should not leave board drag active.")

	game.routed_card = null
	game.pending_target_selection = false
	game._on_creature_drag_started(friendly_target, friendly_target.current_zone)

	_assert_state(game._bdrag_active, "Friendly creatures should still start a normal drag when no target selection is active.")
	_assert_state(game._bdrag_card == friendly_target, "Normal board drag should keep the original creature as the dragged card.")

	print("fenrir_friendly_devour_probe: PASS")
	quit()
