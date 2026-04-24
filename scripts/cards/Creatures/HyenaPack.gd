extends CreatureCard
class_name HyenaPack

const ART_PATH := "res://images/card_art/creatures/Hyena Pack(print).jpg"

func _init() -> void:
	super._init()
	card_name = "Hyena Pack"
	card_types = ["Animal", "Feline", "Pack", "Scavenger", "Ancient Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 13
	strength = 16
	ability_text = "[b]Scavenge[/b]: [b]Slay[/b]: Summon all in-deck \"Hyena Pack\"s."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func on_kill(game_manager: GameManager, _victim: Card) -> void:
	if game_manager == null or card_owner == null or card_owner.deck_zone == null:
		return

	var deck_copies := get_scavenge_targets()
	if deck_copies.is_empty():
		return

	var open_zones := get_available_scavenge_zones()
	if open_zones.is_empty():
		game_manager.note_player_feedback("%s scavenged, but found no open summon lane." % card_name)
		return

	var summoned_names: Array[String] = []
	for recruit in deck_copies:
		if open_zones.is_empty():
			break
		if recruit == null or recruit.current_zone != card_owner.deck_zone:
			continue
		var summon_zone := open_zones.pop_front() as Zone
		if game_manager.summon_creature_without_cost(
			card_owner,
			recruit,
			summon_zone,
			Card.CreatureMode.AGGRESSIVE
		):
			summoned_names.append(recruit.card_name)

	if summoned_names.is_empty():
		game_manager.note_player_feedback("%s scavenged, but could not summon any packmates." % card_name)
		return

	game_manager.note_player_feedback("%s scavenged and summoned %s from the deck." % [
		card_name,
		", ".join(summoned_names)
	])

func get_scavenge_targets() -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null or card_owner.deck_zone == null:
		return valid_targets

	for card in card_owner.deck_zone.cards:
		if _is_valid_scavenge_target(card):
			valid_targets.append(card)
	return valid_targets

func get_available_scavenge_zones() -> Array[Zone]:
	var zones: Array[Zone] = []
	if card_owner == null:
		return zones

	for zone in card_owner.frontline_zones:
		if zone != null and zone.cards.is_empty():
			zones.append(zone)
	for zone in card_owner.reserve_zones:
		if zone != null and zone.cards.is_empty():
			zones.append(zone)
	return zones

func _is_valid_scavenge_target(card: Card) -> bool:
	return card != null \
		and card != self \
		and card.current_zone == card_owner.deck_zone \
		and card.card_type == Card.CardType.CREATURE \
		and card.card_name == card_name
