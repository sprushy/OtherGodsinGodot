extends CreatureCard
class_name RavenStorm

const ART_PATH := "res://images/card_art/creatures/RavenStormEdit.png"

func _init() -> void:
	super._init()
	card_name = "Raven Storm"
	card_types = ["Animal", "Avian", "Raven", "Aerial", "Norse Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 3
	resilience = 7
	strength = 5
	ability_text = "[b]Sighting[/b] ([b]Spd[/b] 3): When a friendly Norse Human Warrior or Lupine attacks, you may summon this creature from your hand."
	culture = "Norse"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func get_priority_field_targets(game_manager: GameManager, action: CardAction = null) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or card_owner == null:
		return valid_targets
	if current_zone != card_owner.hand_zone:
		return valid_targets
	if _get_open_summon_zones().is_empty():
		return valid_targets

	var attack_action := _get_triggering_attack_action(action)
	if attack_action == null:
		return valid_targets

	for attacker in [attack_action.attacker, attack_action.united_front_partner]:
		if _is_valid_sighting_attacker(attacker) and attacker not in valid_targets:
			valid_targets.append(attacker)
	return valid_targets

func can_respond_to_priority_action(action: CardAction, game_manager: GameManager) -> bool:
	if game_manager == null or card_owner == null:
		return false
	if card_owner != game_manager.priority_player:
		return false
	return not get_priority_field_targets(game_manager, action).is_empty()

func activate(game_manager: GameManager, activation_data = null) -> void:
	if game_manager == null or card_owner == null:
		return
	if current_zone != card_owner.hand_zone:
		game_manager.note_player_feedback("%s must still be in hand to swoop in." % card_name)
		return

	var resolved_attacker: Card = null
	var summon_zone: Zone = null
	var summon_mode: Card.CreatureMode = Card.CreatureMode.DEFENSIVE
	if activation_data is Dictionary:
		var activation_dict := activation_data as Dictionary
		var requested_attacker = activation_dict.get("triggering_attacker", null)
		if _is_valid_sighting_attacker(requested_attacker):
			resolved_attacker = requested_attacker
		var requested_zone = activation_dict.get("summon_zone", null)
		if requested_zone is Zone:
			summon_zone = requested_zone as Zone
		var requested_mode := int(activation_dict.get("summon_mode", Card.CreatureMode.DEFENSIVE))
		if requested_mode == Card.CreatureMode.AGGRESSIVE:
			summon_mode = Card.CreatureMode.AGGRESSIVE
	elif _is_valid_sighting_attacker(activation_data):
		resolved_attacker = activation_data

	if resolved_attacker == null:
		var attack_action := _find_active_sighting_attack(game_manager)
		if attack_action != null:
			for attacker in [attack_action.attacker, attack_action.united_front_partner]:
				if _is_valid_sighting_attacker(attacker):
					resolved_attacker = attacker
					break
	if resolved_attacker == null:
		game_manager.note_player_feedback("%s found no valid Sighting trigger." % card_name)
		return

	var open_zones := _get_open_summon_zones()
	if summon_zone != null and summon_zone not in open_zones:
		game_manager.note_player_feedback("%s can no longer enter that position." % card_name)
		return
	if summon_zone == null:
		summon_zone = open_zones[0] as Zone if not open_zones.is_empty() else null
	if summon_zone == null:
		game_manager.note_player_feedback("%s has no open zone to swoop into." % card_name)
		return

	var summoned := game_manager.summon_creature_by_effect(
		card_owner,
		self,
		summon_zone,
		summon_mode,
		false,
		false,
		self,
		false,
		false,
		true
	)
	if summoned:
		var stance_text := "aggressive" if summon_mode == Card.CreatureMode.AGGRESSIVE else "defensive"
		game_manager.note_player_feedback(
			"%s swoops in (%s stance) as %s attacks." % [
				card_name,
				stance_text,
				resolved_attacker.get_target_log_display_name(game_manager.get_feedback_viewer())
			]
		)
	else:
		game_manager.note_player_feedback("%s could not be summoned by Sighting." % card_name)

func _get_triggering_attack_action(action: CardAction) -> CardAction:
	var current_action := action
	while current_action != null:
		if current_action.type == CardAction.Type.ATTACK:
			return current_action
		current_action = current_action.response_to
	return null

func _find_active_sighting_attack(game_manager: GameManager) -> CardAction:
	if game_manager == null:
		return null
	if not game_manager.action_stack.is_empty():
		var chained_attack := _get_triggering_attack_action(game_manager.action_stack.back())
		if chained_attack != null:
			return chained_attack
	for action_index in range(game_manager.action_stack.size() - 1, -1, -1):
		var action := game_manager.action_stack[action_index] as CardAction
		if action != null and action.type == CardAction.Type.ATTACK:
			return action
	return null

func _is_valid_sighting_attacker(card: Card) -> bool:
	if card == null or card.card_type != Card.CardType.CREATURE:
		return false
	if card.get_controller() != card_owner:
		return false
	if card.has_type("Lupine"):
		return true
	return card.has_type("Human") \
		and card.has_type("Warrior") \
		and (card.has_type("Norse Creature") or card.culture == "Norse")

func _get_open_summon_zones() -> Array[Zone]:
	var open_zones: Array[Zone] = []
	if card_owner == null:
		return open_zones
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		if zone.cards.is_empty():
			open_zones.append(zone)
	return open_zones
