extends SceneTree

const MAIN_SCENE := preload("res://scenes/mainfork.tscn")

func _assert_state(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var scene: Node = MAIN_SCENE.instantiate()
	root.add_child(scene)

	var card_test: CardTestGame = scene.get_node("Control/GameContainer/CardTest")
	await card_test.start_game()
	await process_frame
	await process_frame

	var player1: Player = card_test.player1
	_assert_state(player1 != null, "Expected player 1 test state.")

	card_test._clear_zone(player1.frontline_zones[0])
	card_test._clear_zone(player1.reserve_zones[0])
	card_test._clear_zone(player1.reserve_zones[1])

	var skoll: Skoll = null
	var fenrir: Fenrir = null
	for card in player1.hand_zone.cards:
		if card is Skoll and skoll == null:
			skoll = card
		elif card is Fenrir and fenrir == null:
			fenrir = card
	_assert_state(skoll != null, "Expected Skoll in player 1 hand.")
	_assert_state(fenrir != null, "Expected Fenrir in player 1 hand.")

	var warding_stone := WardingStone.new()
	card_test._add_test_hand_card(player1, warding_stone)
	player1.spend_mana(player1.mana)
	player1.gain_mana(10)
	card_test.update_ui()
	await process_frame

	card_test._resolve_skoll_upkeep_creature_play(skoll, player1.reserve_zones[0], "aggressive")
	await process_frame

	_assert_state(skoll.current_zone == player1.reserve_zones[0], "Sun Hunt should summon Skoll into the chosen zone.")
	_assert_state(card_test.game_manager.get_card_summon_mana_cost(player1, fenrir) == fenrir.mana_cost + 2, "Fenrir should cost 2 extra mana after Sun Hunt.")
	_assert_state(card_test.game_manager.get_card_summon_mana_cost(player1, warding_stone) == warding_stone.mana_cost + 2, "Structures should also pick up Skoll's summon tax.")

	player1.spend_mana(player1.mana)
	player1.gain_mana(1)
	_assert_state(not card_test.game_manager.can_play_card(player1, warding_stone, player1.reserve_zones[1]), "A taxed structure should be unaffordable with only 1 mana.")

	player1.spend_mana(player1.mana)
	player1.gain_mana(10)
	card_test.update_ui()
	await process_frame

	_assert_state(_get_hand_mana_label(card_test, "Fenrir") == "2M", "Fenrir's hand label should show the taxed mana cost.")
	_assert_state(_get_hand_mana_label(card_test, "Warding Stone") == "2M", "Warding Stone's hand label should show the taxed mana cost.")

	var mana_before_structure := player1.mana
	card_test.game_manager.play_card(player1, warding_stone, player1.reserve_zones[1])
	_assert_state(warding_stone.current_zone == player1.reserve_zones[1], "Warding Stone should be played to the board.")
	_assert_state(player1.mana == mana_before_structure - 2, "Playing a taxed structure should spend the additional 2 mana.")

	var mana_before_fenrir := player1.mana
	card_test.game_manager.play_card(player1, fenrir, player1.frontline_zones[0])
	_assert_state(fenrir.current_zone == player1.frontline_zones[0], "Fenrir should still be summonable after Sun Hunt.")
	_assert_state(player1.mana == mana_before_fenrir - 2, "A normal creature summon after Sun Hunt should spend the additional 2 mana.")

	scene.queue_free()
	print("cardtest_endturn_probe: PASS")
	quit()

func _get_hand_mana_label(card_test: CardTestGame, card_name: String) -> String:
	for vc in card_test._hand_visual_cards:
		if vc == null or vc.card_data == null or vc.card_data.card_name != card_name:
			continue
		var inner: Control = vc.get_child(0) as Control
		var vbox: VBoxContainer = inner.get_child(0) as VBoxContainer
		var top_row := vbox.get_child(0) as HBoxContainer
		var mana_label := top_row.get_child(top_row.get_child_count() - 1) as Label
		if mana_label != null:
			return mana_label.text
	return ""
