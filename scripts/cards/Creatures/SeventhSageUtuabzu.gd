extends CreatureCard
class_name SeventhSageUtuabzu

const ART_PATH := "res://images/card_art/creatures/seventh_sage_utuabzu.png"
const IMBUE_ALLY_COST := 2
const IMPACT_USED_TURN_META := "utuabzu_last_impact_activation_turn"

func _init() -> void:
	super._init()
	card_name = "Seventh Sage Utuabzu"
	card_types = ["Mer", "Mage", "Priest", "Sage", "Ancient Creature", "Targeting"]
	level = 4
	mana_cost = 2
	sacrifice_cost = 0
	speed = 2
	resilience = 27
	strength = 14
	targets = true
	ability_text = "[b]Channel Ally[/b] ([b]Impact[/b]): Choose another allied Ancient Sage on the field or in the [b]Void[/b] and activate its impact effect.\n[b]Imbue Ally[/b] ([b]Activate[/b], 2 Mana): Choose another allied Ancient Sage on the field and activate its impact effect if it hasn't activated this turn."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Tamoo"
	art_path = ART_PATH

func on_impact(game_manager: GameManager) -> void:
	_mark_impact_activated_this_turn(self, game_manager)
	var valid_targets := get_channel_ally_targets(game_manager)
	if valid_targets.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("%s found no allied Ancient Sage to channel." % card_name)
		return

	var feedback := resolve_channel_ally_impact(game_manager, valid_targets[0])
	if game_manager != null and feedback != "":
		game_manager.note_player_feedback(feedback)

func get_activation_label() -> String:
	return "Imbue Ally"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	var controller := get_controller()
	if controller != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_face_down or is_stealth or is_prepared:
		return false
	if abilities_suppressed() or is_activation_locked(game_manager):
		return false
	if is_sleeping:
		return false
	if controller == null or controller.mana < IMBUE_ALLY_COST:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	return get_imbue_ally_targets(game_manager)

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("%s cannot use Imbue Ally right now." % card_name)
		return
	var valid_targets := get_imbue_ally_targets(game_manager)
	if target == null or target not in valid_targets:
		if game_manager != null:
			game_manager.note_player_feedback("%s fizzles: choose another allied Ancient Sage on the field whose impact has not activated this turn." % card_name)
		return
	var controller := get_controller()
	if controller == null or not controller.spend_mana(IMBUE_ALLY_COST):
		if game_manager != null:
			game_manager.note_player_feedback("%s needs %d mana for Imbue Ally." % [card_name, IMBUE_ALLY_COST])
		return

	var feedback := _activate_target_impact(game_manager, target, "Imbue Ally")
	if game_manager != null and feedback != "":
		game_manager.note_player_feedback(feedback)

func get_channel_ally_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null:
		return valid_targets
	valid_targets.append_array(_get_allied_sages_in_zones(controller.frontline_zones + controller.reserve_zones))
	valid_targets.append_array(_get_allied_sages_in_zone(controller.abyss_zone))
	return valid_targets

func get_imbue_ally_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or game_manager == null:
		return valid_targets
	for target in _get_allied_sages_in_zones(controller.frontline_zones + controller.reserve_zones):
		if _has_impact_activated_this_turn(target, game_manager):
			continue
		valid_targets.append(target)
	return valid_targets

func resolve_channel_ally_impact(game_manager: GameManager, target: Card) -> String:
	if target == null or target not in get_channel_ally_targets(game_manager):
		return "%s found no valid allied Ancient Sage to channel." % card_name
	return _activate_target_impact(game_manager, target, "Channel Ally")

func _activate_target_impact(game_manager: GameManager, target: Card, source_name: String) -> String:
	if game_manager == null or target == null:
		return ""
	if game_manager.is_immune_to_source(target, self):
		return "%s could not affect %s because it is immune to creature abilities this turn." % [
			card_name,
			target.get_target_log_display_name(game_manager.get_feedback_viewer())
		]
	if target.abilities_suppressed():
		return "%s could not activate %s's impact because its abilities are negated." % [
			card_name,
			target.get_target_log_display_name(game_manager.get_feedback_viewer())
		]
	if not target.has_method("on_impact"):
		return "%s has no impact ability to activate." % target.card_name

	_mark_impact_activated_this_turn(target, game_manager)
	target.on_impact(game_manager)
	return "%s uses %s to activate %s's impact effect." % [
		card_name,
		source_name,
		target.get_target_log_display_name(game_manager.get_feedback_viewer())
	]

func _get_allied_sages_in_zones(zones: Array) -> Array[Card]:
	var valid_targets: Array[Card] = []
	for zone in zones:
		valid_targets.append_array(_get_allied_sages_in_zone(zone))
	return valid_targets

func _get_allied_sages_in_zone(zone: Zone) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if zone == null:
		return valid_targets
	for card in zone.cards:
		if _is_valid_allied_sage_target(card):
			valid_targets.append(card)
	return valid_targets

func _is_valid_allied_sage_target(card: Card) -> bool:
	if card == null or card == self:
		return false
	var controller := get_controller()
	if controller == null or card.get_controller() != controller:
		return false
	if card.card_type != Card.CardType.CREATURE:
		return false
	if not card.has_type("Ancient Creature"):
		return false
	if not card.has_type("Sage"):
		return false
	return true

func _has_impact_activated_this_turn(card: Card, game_manager: GameManager) -> bool:
	if card == null or game_manager == null:
		return false
	if bool(card.summoned_this_turn):
		return true
	return int(card.get_meta(IMPACT_USED_TURN_META, -1)) == game_manager.turn_number

func _mark_impact_activated_this_turn(card: Card, game_manager: GameManager) -> void:
	if card == null or game_manager == null:
		return
	card.set_meta(IMPACT_USED_TURN_META, game_manager.turn_number)
