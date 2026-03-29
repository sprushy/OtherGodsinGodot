extends SceneTree

const GalaTuraScript := preload("res://scripts/cards/Creatures/GalaTura.gd")
const AgainWalkerScript := preload("res://scripts/cards/Creatures/AgainWalker.gd")
const AluScript := preload("res://scripts/cards/Creatures/Alu.gd")
const EnkiduScript := preload("res://scripts/cards/Creatures/Enkidu.gd")
const ClayEatersScript := preload("res://scripts/cards/Creatures/ClayEaters.gd")

func _assert_state(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var game_manager := GameManager.new()
	var player1 := Player.new()
	player1.player_name = "Player 1"
	var player2 := Player.new()
	player2.player_name = "Player 2"

	game_manager.players = [player1, player2]
	game_manager.setup_game()
	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.turn_player = player1
	game_manager.turn_number = 1
	game_manager.feedback_viewer = player1

	var gala := GalaTuraScript.new()
	gala.card_owner = player1
	player1.frontline_zones[0].add_card(gala)
	gala.on_summon(game_manager)

	var grave_creature_a := AgainWalkerScript.new()
	grave_creature_a.card_owner = player1
	player1.graveyard_zone.add_card(grave_creature_a)

	var grave_creature_b := AluScript.new()
	grave_creature_b.card_owner = player1
	player1.graveyard_zone.add_card(grave_creature_b)

	var grave_creature_c := EnkiduScript.new()
	grave_creature_c.card_owner = player1
	player1.graveyard_zone.add_card(grave_creature_c)

	game_manager._on_player_card_moved(grave_creature_c, player1.hand_zone, player1.graveyard_zone)
	_assert_state(grave_creature_a.has_status_effect("gala_tura_graveward"), "Gala-Tura should apply graveward to friendly graveyard creatures.")

	var enemy_source := ClayEatersScript.new()
	enemy_source.card_owner = player2
	player2.frontline_zones[1].add_card(enemy_source)
	_assert_state(game_manager.is_immune_to_source(grave_creature_a, enemy_source), "Enemy effects should be blocked by Gala-Tura's graveward.")
	_assert_state(not game_manager.is_immune_to_source(grave_creature_a, gala), "Friendly effects should still be allowed through Gala-Tura's graveward.")

	var destroyed := game_manager.request_send_to_graveyard(gala, Callable(), false, true)
	_assert_state(destroyed, "Gala-Tura should be destroyable for the probe.")
	_assert_state(gala.current_zone == player1.graveyard_zone, "Gala-Tura should move to the graveyard after being destroyed.")
	_assert_state(not grave_creature_a.has_status_effect("gala_tura_graveward"), "Graveward should be removed after Gala-Tura leaves the field.")

	await process_frame
	await process_frame

	_assert_state(grave_creature_a.current_zone == player1.deck_zone, "The first graveyard creature should return to the deck.")
	_assert_state(grave_creature_b.current_zone == player1.deck_zone, "The second graveyard creature should return to the deck.")
	_assert_state(grave_creature_c.current_zone == player1.deck_zone, "The third graveyard creature should return to the deck.")
	_assert_state(gala.current_zone == player1.graveyard_zone, "Fallback resolution should leave Gala-Tura in the graveyard after returning the first three creatures.")
	_assert_state(player1.deck_zone.cards.size() >= 3, "The returned creatures should be added to the deck.")
	_assert_state(player1.deck_zone.cards[player1.deck_zone.cards.size() - 3] == grave_creature_a, "The first returned creature should be placed first among the new bottom cards.")
	_assert_state(player1.deck_zone.cards[player1.deck_zone.cards.size() - 2] == grave_creature_b, "The second returned creature should be placed second among the new bottom cards.")
	_assert_state(player1.deck_zone.cards[player1.deck_zone.cards.size() - 1] == grave_creature_c, "The third returned creature should be placed third among the new bottom cards.")

	var moved_callback := Callable(game_manager, "_on_player_card_moved")
	var defeated_callback := Callable(game_manager, "_on_player_defeated")
	for player in game_manager.players:
		if player.card_moved.is_connected(moved_callback):
			player.card_moved.disconnect(moved_callback)
		if player.defeated.is_connected(defeated_callback):
			player.defeated.disconnect(defeated_callback)

	print("gala_tura_probe: PASS")
	quit()
