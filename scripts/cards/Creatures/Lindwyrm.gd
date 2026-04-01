extends CreatureCard
class_name Lindwyrm

const ART_PATH := "res://images/card_art/creatures/LindwyrmArtEdit.png"
const DEVOUR_BUFF_SOURCE := "Lindwyrm Devour"
const DEVOUR_LEVEL_BONUS := 1
const DEVOUR_SPEED_BONUS := 1
const DEVOUR_RESILIENCE_BONUS := 5
const DEVOUR_STRENGTH_BONUS := 5

func _init() -> void:
	super._init()
	card_name = "Lindwyrm"
	card_types = ["Dragon", "Wyvern", "Norse Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 11
	strength = 16
	targets = true
	ability_text = "[b]Devour[/b] ([b]Major Action[/b]): Destroy a creature at least 2 levels lower than this card. If you do, this card gains +1 Lvl, +1 Spd, +5 Res, and +5 Str."
	culture = "Norse"
	artist = "Daniel Decena"
	art_path = ART_PATH

func get_activation_label() -> String:
	return "Devour"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_face_down or is_stealth or is_prepared:
		return false
	if abilities_suppressed() or is_activation_locked(game_manager):
		return false
	if is_sleeping:
		return false
	if not can_take_major_creature_action():
		return false
	return not get_valid_devour_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if get_controller() != game_manager.current_player:
		return "It is not your turn to use " + card_name + "."
	if current_zone == null or not current_zone.is_board_zone():
		return card_name + " must be on the field to devour."
	if is_face_down or is_stealth or is_prepared:
		return card_name + " must be revealed to devour."
	if abilities_suppressed() or is_activation_locked(game_manager):
		return card_name + " cannot activate right now."
	if is_sleeping:
		return card_name + " is Sleeping and cannot devour."
	if not can_take_major_creature_action():
		if creature_major_action_used:
			return card_name + " has already used its major action this turn."
		return card_name + " has already used all of its minor actions this turn."
	return card_name + " has no creature weak enough to devour."

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	return get_valid_devour_targets(game_manager)

func get_valid_devour_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _is_valid_devour_target(card):
					valid_targets.append(card)
	return valid_targets

func get_devour_target_failure_reason(target: Card) -> String:
	if target == null:
		return card_name + ": click a creature to devour."
	if target == self:
		return card_name + " cannot devour itself."
	if target.card_type != Card.CardType.CREATURE:
		return card_name + " can only devour creatures."
	if target.current_zone == null or not target.current_zone.is_board_zone():
		return target.card_name + " must be on the field to be devoured."
	var max_target_level := get_effective_level() - 2
	if target.get_effective_level() > max_target_level:
		return "%s is level %d. %s can only devour level %d or lower." % [
			target.card_name,
			target.get_effective_level(),
			card_name,
			max_target_level
		]
	return card_name + " cannot devour " + target.card_name + "."

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	resolve_devour_activation(game_manager, target, func(feedback: String) -> void:
		if game_manager != null:
			game_manager.note_player_feedback(feedback)
	)

func resolve_devour_activation(game_manager: GameManager, target: Card, continue_callback: Callable = Callable()) -> void:
	if game_manager == null:
		_emit_devour_result(continue_callback, card_name + " cannot devour right now.")
		return
	var valid_targets := get_valid_devour_targets(game_manager)
	if target == null or target not in valid_targets:
		_emit_devour_result(continue_callback, card_name + " found no creature weak enough to devour.")
		return
	if game_manager.is_guardian_protected(target, self):
		_emit_devour_result(continue_callback, target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is protected by Guardian!")
		return
	if game_manager.is_immune_to_source(target, self):
		_emit_devour_result(continue_callback, target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is immune to " + card_name + "'s creature abilities this turn.")
		return

	var devoured_name := target.get_target_log_display_name(game_manager.get_feedback_viewer())
	game_manager.request_send_to_graveyard(target, func() -> void:
		var left_board := target.current_zone == null or not target.current_zone.is_board_zone()
		if left_board:
			add_buff(
				DEVOUR_BUFF_SOURCE,
				DEVOUR_STRENGTH_BONUS,
				DEVOUR_RESILIENCE_BONUS,
				DEVOUR_SPEED_BONUS,
				self,
				card_owner,
				"lindwyrm_devour",
				{"lvl": DEVOUR_LEVEL_BONUS}
			)
			spend_major_creature_action()
			_emit_devour_result(
				continue_callback,
				"%s devoured %s and gained +%d Lvl, +%d Spd, +%d Res, and +%d Str." % [
					card_name,
					devoured_name,
					DEVOUR_LEVEL_BONUS,
					DEVOUR_SPEED_BONUS,
					DEVOUR_RESILIENCE_BONUS,
					DEVOUR_STRENGTH_BONUS
				]
			)
		else:
			_emit_devour_result(continue_callback, "%s could not devour %s." % [card_name, devoured_name])
	, false, true)

func _emit_devour_result(callback: Callable, feedback: String) -> void:
	if callback.is_valid():
		callback.call(feedback)

func _is_valid_devour_target(card: Card) -> bool:
	return card != null \
		and card != self \
		and card.card_type == Card.CardType.CREATURE \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and card.get_effective_level() <= get_effective_level() - 2
