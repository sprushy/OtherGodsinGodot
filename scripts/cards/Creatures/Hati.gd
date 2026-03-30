extends CreatureCard
class_name Hati

const ART_PATH := "res://images/card_art/creatures/hati.jpg"
const MOON_HUNT_EXTRA_MANA := 2

func _init() -> void:
	super._init()
	card_name = "Hati"
	card_types = ["Animal", "Lupine", "Aerial", "Norse Creature"]
	level = 4
	mana_cost = 0
	sacrifice_cost = 1
	speed = 2
	resilience = 27
	strength = 27
	ability_text = "[b]Moon Hunt[/b]: At the end of your turn, you may sacrifice 1 creature to summon this card; if you have already normal summoned, also pay 2 mana."
	culture = "Norse"
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

func can_use_moon_hunt_summon(game_manager: GameManager) -> bool:
	if game_manager == null or card_owner == null:
		return false
	if game_manager.current_player != card_owner:
		return false
	if current_zone != card_owner.hand_zone:
		return false
	if _get_open_summon_zones().is_empty():
		return false
	if not _has_sacrificeable_creature():
		return false
	if get_moon_hunt_mana_cost(game_manager) > card_owner.mana:
		return false
	return true

func get_moon_hunt_mana_cost(game_manager: GameManager) -> int:
	if game_manager == null or card_owner == null:
		return 0
	if card_owner.has_summoned_this_turn:
		return MOON_HUNT_EXTRA_MANA
	return 0

func _get_open_summon_zones() -> Array[Zone]:
	var open_zones: Array[Zone] = []
	if card_owner == null:
		return open_zones
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		if zone.cards.is_empty():
			open_zones.append(zone)
	return open_zones

func _has_sacrificeable_creature() -> bool:
	if card_owner == null:
		return false
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if card.card_type == Card.CardType.CREATURE and card.can_be_used_for_creature_sacrifice:
				return true
	return false
