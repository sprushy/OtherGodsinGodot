extends SceneTree

func _initialize() -> void:
	var game := preload("res://scripts/Other/CardTestGame.gd").new()
	root.add_child(game)
	await game.ready
	await game.start_game()
	await process_frame

	var fenrir: Card = null
	for card in game.player1.hand_zone.cards:
		if card is Fenrir:
			fenrir = card
			break

	if fenrir == null:
		print("PROBE: fenrir_not_found")
		quit()
		return

	game.selected_card = fenrir
	game.placement_mode = "aggressive"
	game._try_play_selected_creature_to_zone(game.player1.reserve_zones[2])
	await process_frame
	await process_frame

	var stack_names: Array[String] = []
	for action in game.game_manager.action_stack:
		if action == null:
			continue
		if action.event_name != "":
			stack_names.append(action.event_name)
		elif action.card != null:
			stack_names.append(action.card.card_name)
		else:
			stack_names.append("unknown")

	print("PROBE: action_label=", game.action_label.text)
	print("PROBE: stack=", ",".join(stack_names))
	print("PROBE: selected=", game.selected_card)
	print("PROBE: awaiting_sacrifice=", game._awaiting_creature_sacrifice)
	print("PROBE: summon_pending=", game._pending_summon_priority_events.size())
	quit()
