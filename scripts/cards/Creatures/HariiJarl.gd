extends CreatureCard
class_name HariiJarl

const MAX_WARBAND_SUMMONS := 2

func _init() -> void:
	super._init()
	card_name = "Harii Jarl"
	card_types = ["Human", "Warrior", "Norse Creature"]
	level = 4
	mana_cost = 4
	speed = 1
	resilience = 18
	strength = 25
	sacrifice_cost = 0
	ability_text = "[b]Warband[/b] ([b]Impact[/b]): Summon up to two other \"Harii\" creatures from your hand and pay their summon costs."
	flavor_text = ""
	culture = "Norse"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/HariiChiefEdit.png"

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_warband_targets(game_manager)
	if valid_targets.is_empty():
		return
	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(get_controller(), "harii_jarl_impact", {
		"source_uid": uid,
		"target_uids": target_uids,
		"queue_with_priority": true,
		"event_name": "harii_jarl_impact",
	})

func get_available_warband_zones() -> Array[Zone]:
	var zones: Array[Zone] = []
	var controller := get_controller()
	if controller == null:
		return zones
	for zone in controller.frontline_zones:
		if zone != null and zone.cards.is_empty():
			zones.append(zone)
	for zone in controller.reserve_zones:
		if zone != null and zone.cards.is_empty():
			zones.append(zone)
	return zones

func get_valid_warband_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.hand_zone == null or game_manager == null:
		return valid_targets
	if get_available_warband_zones().is_empty():
		return valid_targets

	for card in controller.hand_zone.cards:
		if not _is_valid_warband_target(card, controller):
			continue
		if not game_manager.can_pay_creature_summon_cost(controller, card, self, true):
			continue
		valid_targets.append(card)
	return valid_targets

func resolve_warband_impact(game_manager: GameManager, chosen_cards: Array[Card]) -> String:
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller for Warband."
	if game_manager == null:
		return card_name + " cannot resolve Warband right now."
	if chosen_cards.is_empty():
		return "%s chose not to summon any Harii via Warband." % card_name

	var summoned_names: Array[String] = []
	var open_zones := get_available_warband_zones()
	if open_zones.is_empty():
		return card_name + " has no open zones for Warband."

	for chosen_card in chosen_cards:
		if chosen_card == null:
			continue
		if summoned_names.size() >= MAX_WARBAND_SUMMONS:
			break
		if open_zones.is_empty():
			break
		if chosen_card not in get_valid_warband_targets(game_manager):
			continue
		var target_zone: Zone = open_zones.pop_front() as Zone
		if game_manager.summon_creature_by_effect(
			controller,
			chosen_card,
			target_zone,
			Card.CreatureMode.AGGRESSIVE,
			false,
			false,
			self,
			true,
			false,
			true
		):
			summoned_names.append(chosen_card.card_name)

	if summoned_names.is_empty():
		return "%s summoned no Harii from hand." % card_name
	return "%s summoned %s via Warband." % [card_name, ", ".join(summoned_names)]

func _is_valid_warband_target(card: Card, controller: Player) -> bool:
	return card != null \
		and controller != null \
		and card != self \
		and card.current_zone == controller.hand_zone \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.card_name != card_name \
		and _is_harii_card(card)

func _is_harii_card(card: Card) -> bool:
	return card != null and card.card_name.to_lower().contains("harii")
