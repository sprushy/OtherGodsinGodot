extends CreatureCard
class_name Grindylow

const ART_PATH := "res://images/card_art/creatures/grindylow.png"

func _init() -> void:
	super._init()
	card_name = "Grindylow"
	card_types = ["Aqueous", "Fairy", "Triskelion Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 12
	strength = 15
	ability_text = "Drown Below ([b]Reveal[/b]): Destroy any creature."
	flavor_text = ""
	culture = "Triskelion"
	artist = "User provided art"
	art_path = ART_PATH

func on_reveal(game_manager: GameManager) -> void:
	if game_manager == null or abilities_suppressed():
		return
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		game_manager.note_player_feedback("%s found no creatures to drown." % card_name)
		return
	var controller := get_controller()
	if controller == null:
		return
	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(controller, "masmassu_priest_reveal", {
		"source_uid": uid,
		"target_uids": target_uids,
		"queue_with_priority": true,
		"event_name": "masmassu_priest_reveal",
		"completion_command_type": "masmassu_priest_reveal_choice",
	})

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _is_valid_drown_below_target(card):
					valid_targets.append(card)
	return valid_targets

func begin_dalkhu_break_reveal(
	game_manager: GameManager,
	target: Card,
	completion: Callable = Callable()
) -> void:
	var finish := func(result_text: String) -> void:
		if completion.is_valid():
			completion.call(result_text)
		elif game_manager != null and result_text.strip_edges() != "":
			game_manager.note_player_feedback(result_text)

	if game_manager == null:
		finish.call(card_name + " cannot resolve Drown Below right now.")
		return

	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		finish.call(card_name + " found no valid creature to destroy.")
		return
	if game_manager.is_immune_to_source(target, self):
		finish.call(
			"%s is immune to %s's creature abilities this turn." % [
				target.get_target_log_display_name(game_manager.get_feedback_viewer()),
				card_name
			]
		)
		return

	var viewer := game_manager.get_feedback_viewer()
	var target_name := target.get_target_log_display_name(viewer)
	var on_destroy_complete := func() -> void:
		var destroyed := target.current_zone == null or not target.current_zone.is_board_zone()
		if not destroyed:
			finish.call("%s failed to destroy %s with Drown Below." % [card_name, target_name])
			return
		finish.call("%s destroyed %s with Drown Below." % [card_name, target_name])
	game_manager.request_send_to_graveyard(
		target,
		on_destroy_complete,
		false,
		true
	)

func _is_valid_drown_below_target(target: Card) -> bool:
	return target != null \
		and target.card_type == Card.CardType.CREATURE \
		and not target.is_god \
		and target.current_zone != null \
		and target.current_zone.is_board_zone()
