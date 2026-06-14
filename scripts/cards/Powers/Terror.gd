extends PowerCard
class_name Terror

const UNLOCK_COST := 6
const ART_PATH := "res://images/card_art/powers/TerrorWeb.jpg"

func _init() -> void:
	super._init()
	card_name = "Terror"
	culture = "Ancient"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Class Buff", "Demon"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	targets = true
	ability_text = "Your Demons gain [b]Terror[/b] ([b]Impact[/b]): Return an opponent's lower-level creature to its owner's hand."
	artist = "Lorinda Tomiko"
	art_path = ART_PATH

func on_any_card_moved(game_manager: GameManager, moved_card: Card, from_zone: Zone, to_zone: Zone) -> void:
	if not _can_trigger_terror(game_manager, moved_card, from_zone, to_zone):
		return

	var valid_targets := get_valid_terror_targets(game_manager, moved_card)
	if valid_targets.is_empty():
		game_manager.note_player_feedback("%s spread terror through %s, but there was no lower-level enemy creature to return." % [
			card_name,
			moved_card.get_target_log_display_name(game_manager.get_feedback_viewer())
		])
		return
	var controller := moved_card.get_controller()
	if game_manager != null and controller != null:
		var target_uids: Array[String] = []
		for target in valid_targets:
			if target != null:
				target_uids.append(target.uid)
		game_manager.decision_requested.emit(controller, "terror_impact", {
			"source_uid": uid,
			"demon_uid": moved_card.uid,
			"target_uids": target_uids,
			"queue_with_priority": true,
			"event_name": "terror_impact",
		})
		return

	game_manager.note_player_feedback("%s could not request a Terror target choice." % card_name)

func get_valid_terror_targets(game_manager: GameManager, demon: Card) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or demon == null:
		return valid_targets
	var controller := demon.get_controller()
	if controller == null:
		return valid_targets
	var opponent := game_manager.get_opponent(controller)
	if opponent == null:
		return valid_targets
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if _is_valid_terror_target(card, demon):
				valid_targets.append(card)
	return valid_targets

func resolve_terror_impact(game_manager: GameManager, demon: Card, target: Card) -> String:
	if game_manager == null or demon == null:
		return card_name + " cannot resolve right now."
	var valid_targets := get_valid_terror_targets(game_manager, demon)
	if target == null or target not in valid_targets:
		return "%s fizzles: there is no valid creature for %s to terrify." % [
			card_name,
			demon.get_target_log_display_name(game_manager.get_feedback_viewer())
		]
	if game_manager.is_immune_to_source(target, demon) or game_manager.is_immune_to_source(target, self):
		return "%s is immune to %s's Terror." % [
			target.get_target_log_display_name(game_manager.get_feedback_viewer()),
			demon.get_target_log_display_name(game_manager.get_feedback_viewer())
		]

	var target_name := target.get_target_log_display_name(game_manager.get_feedback_viewer())
	var demon_name := demon.get_target_log_display_name(game_manager.get_feedback_viewer())
	var owner := target.card_owner
	if owner == null or owner.hand_zone == null:
		return "%s could not return %s." % [card_name, target_name]

	owner.move_card(target, owner.hand_zone)
	if target.current_zone != owner.hand_zone:
		return "%s tried to return %s with %s, but it stayed on the field." % [
			card_name,
			target_name,
			demon_name
		]
	return "%s returns %s to hand through %s's Terror." % [
		card_name,
		target_name,
		demon_name
	]

func _can_trigger_terror(game_manager: GameManager, moved_card: Card, from_zone: Zone, to_zone: Zone) -> bool:
	return is_effectively_active() \
		and game_manager != null \
		and moved_card != null \
		and moved_card.card_type == Card.CardType.CREATURE \
		and moved_card.get_controller() == get_controller() \
		and moved_card.has_type("Demon") \
		and not moved_card.abilities_suppressed() \
		and to_zone != null \
		and to_zone.is_board_zone() \
		and (from_zone == null or not from_zone.is_board_zone()) \
		and not moved_card.is_face_down \
		and not moved_card.is_prepared

func _is_valid_terror_target(card: Card, demon: Card) -> bool:
	return card != null \
		and demon != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and card.get_effective_level() < demon.get_effective_level()
