extends CreatureCard
class_name FirstSageAdapa

const MUTE_DURATION := 2

func _init() -> void:
	super._init()
	card_name = "First Sage Adapa"
	card_types = ["Mer", "Mage", "Priest", "Sage", "Ancient Creature", "Targeting"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 23
	strength = 15
	targets = true
	ability_text = "Silence Divine ([b]Impact[/b]): Choose an opposing power or God ability. [b]Mute[/b] it for 2 of its owner's turns."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/FirstSageAdapaAIedit.png"

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("%s found no opposing powers or God abilities to silence." % card_name)
		return
	var controller := get_controller()
	if game_manager == null or controller == null:
		return
	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(controller, "first_sage_adapa_impact", {
		"source_uid": uid,
		"target_uids": target_uids,
		"queue_with_priority": true,
		"event_name": "first_sage_adapa_impact",
	})

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	var controller := get_controller()
	if controller == null:
		return valid_targets
	var opponent := game_manager.get_opponent(controller)
	if opponent == null:
		return valid_targets
	for god in opponent.god_zone.cards:
		if _is_valid_silence_target(god):
			valid_targets.append(god)
	for zone in opponent.power_zones:
		if zone == null or zone.cards.is_empty():
			continue
		var power := zone.cards[0]
		if _is_valid_silence_target(power):
			valid_targets.append(power)
	return valid_targets

func resolve_silence_divine_impact(game_manager: GameManager, target: Card) -> String:
	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		return card_name + " found no valid opposing power or God ability to silence."
	if game_manager != null and game_manager.is_immune_to_source(target, self):
		return target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is immune to " + card_name + "'s creature abilities this turn."

	target.mute_for_turns(MUTE_DURATION, game_manager)
	return "%s silences %s for %d of its owner's turns." % [
		card_name,
		target.get_target_log_display_name(game_manager.get_feedback_viewer()),
		MUTE_DURATION
	]

func _is_valid_silence_target(card: Card) -> bool:
	return card is PowerCard or (card != null and card.is_god)
