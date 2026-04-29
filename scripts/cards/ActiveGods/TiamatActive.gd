extends ActiveGodCard
class_name TiamatActive

const LINKED_GOD_NAME := "Tiamat"
const ART_PATH := "res://images/card_art/gods/TiamatEdit.png"
const BIRTH_MAX_LEVEL := 4
const DEATH_MAX_LEVEL := 6

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Tiamat, Active God"
	card_types = ["Active God", "Divine Manifestation", "God"]
	level = 7
	mana_cost = 13
	speed = 1
	resilience = 38
	strength = 37
	culture = "Ancient"
	flavor_text = "Tiamat births horrors at her arrival and again at her fall."
	ability_text = "[b]Birth[/b] ([b]Impact[/b]): Summon a level 4 or lower Demon or Dragon from your hand.\n[b]Death[/b] ([b]Fatality[/b]): Summon a level 6 or lower Demon or Dragon from your hand."
	art_path = ART_PATH
	name_at_bottom = true
	artist = "Ricardo Zoppello"

func on_impact(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	game_manager.note_player_feedback(resolve_birth(game_manager))

func on_death(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	game_manager.note_player_feedback(resolve_death(game_manager))

func resolve_birth(game_manager: GameManager, chosen_card: Card = null) -> String:
	return _resolve_tiamat_summon(game_manager, chosen_card, BIRTH_MAX_LEVEL, "Birth")

func resolve_death(game_manager: GameManager, chosen_card: Card = null) -> String:
	return _resolve_tiamat_summon(game_manager, chosen_card, DEATH_MAX_LEVEL, "Death")

func _resolve_tiamat_summon(game_manager: GameManager, chosen_card: Card, max_level: int, label: String) -> String:
	if game_manager == null:
		return card_name + " cannot resolve " + label + " right now."
	var valid_targets := _get_valid_targets(game_manager, max_level)
	if valid_targets.is_empty():
		return "%s found no level %d or lower Demon or Dragon in hand for %s." % [card_name, max_level, label]
	var open_zones := _get_open_zones()
	if open_zones.is_empty():
		return "%s has no open lane for %s." % [card_name, label]

	var resolved_card := chosen_card if chosen_card != null and chosen_card in valid_targets else valid_targets[0]
	var target_zone := open_zones[0] as Zone
	if target_zone == null:
		return "%s has no open lane for %s." % [card_name, label]

	var summoned := game_manager.summon_creature_by_effect(
		card_owner,
		resolved_card,
		target_zone,
		Card.CreatureMode.AGGRESSIVE,
		false,
		false,
		self,
		true,
		false,
		true
	)
	if not summoned:
		return "%s could not summon %s for %s." % [card_name, resolved_card.card_name, label]
	return "%s summons %s from hand via %s." % [card_name, resolved_card.card_name, label]

func _get_valid_targets(game_manager: GameManager, max_level: int) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null or card_owner.hand_zone == null or game_manager == null:
		return valid_targets
	if _get_open_zones().is_empty():
		return valid_targets
	for card in card_owner.hand_zone.cards:
		if not _is_valid_tiamat_target(card, max_level):
			continue
		if not game_manager.can_pay_creature_summon_cost(card_owner, card, self, true):
			continue
		valid_targets.append(card)
	return valid_targets

func _is_valid_tiamat_target(card: Card, max_level: int) -> bool:
	return card != null \
		and card.current_zone == card_owner.hand_zone \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.get_effective_level() <= max_level \
		and (card.has_type("Demon") or card.has_type("Dragon"))

func _get_open_zones() -> Array[Zone]:
	var open_zones: Array[Zone] = []
	if card_owner == null:
		return open_zones
	for zone in card_owner.frontline_zones:
		if zone != null and zone.cards.is_empty():
			open_zones.append(zone)
	for zone in card_owner.reserve_zones:
		if zone != null and zone.cards.is_empty():
			open_zones.append(zone)
	return open_zones
