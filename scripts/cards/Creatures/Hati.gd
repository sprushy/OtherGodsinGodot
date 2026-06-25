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
	ability_text = "[b]Moon Hunt[/b]: At the end of your turn, you may sacrifice 1 creature to summon this card; if you have already normal summoned, also pay %d mana." % MOON_HUNT_EXTRA_MANA
	culture = "Norse"
	artist = "Unknown"
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
	if get_valid_moon_hunt_sacrifices().is_empty():
		return false
	if not can_pay_moon_hunt_mana_cost(game_manager):
		return false
	return true

func get_moon_hunt_prompt_text(game_manager: GameManager) -> String:
	var total_mana := get_total_moon_hunt_mana_cost(game_manager)
	if total_mana > 0:
		return "Moon Hunt: sacrifice 1 friendly creature and pay %d mana to summon this Hati from your hand." % total_mana
	return "Moon Hunt: sacrifice 1 friendly creature to summon this Hati from your hand."

func get_moon_hunt_mana_cost(game_manager: GameManager) -> int:
	if game_manager == null or card_owner == null:
		return 0
	if card_owner.has_summoned_this_turn:
		return MOON_HUNT_EXTRA_MANA
	return 0

func get_moon_hunt_summon_mana_cost(game_manager: GameManager) -> int:
	if game_manager == null or card_owner == null:
		return 0
	return game_manager.get_creature_summon_mana_cost(card_owner, self, self, true)

func get_total_moon_hunt_mana_cost(game_manager: GameManager) -> int:
	return get_moon_hunt_mana_cost(game_manager) + get_moon_hunt_summon_mana_cost(game_manager)

func can_pay_moon_hunt_mana_cost(game_manager: GameManager) -> bool:
	if game_manager == null or card_owner == null:
		return false
	return card_owner.mana >= get_total_moon_hunt_mana_cost(game_manager)

func get_valid_moon_hunt_sacrifices() -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null:
		return valid_targets
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if is_valid_moon_hunt_sacrifice(card):
				valid_targets.append(card)
	return valid_targets

func is_valid_moon_hunt_sacrifice(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.get_controller() == card_owner \
		and card.can_be_used_for_creature_sacrifice \
		and card.current_zone != null \
		and card.current_zone.is_board_zone()

func resolve_moon_hunt_summon(
	game_manager: GameManager,
	target_zone: Zone,
	sacrificed_card: Card,
	mode: Card.CreatureMode = Card.CreatureMode.DEFENSIVE,
	stealth: bool = false
) -> bool:
	if not can_use_moon_hunt_summon(game_manager):
		return false
	if target_zone == null or target_zone.zone_owner != card_owner:
		return false
	if target_zone.zone_type not in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE]:
		return false
	if not target_zone.cards.is_empty():
		return false
	if not is_valid_moon_hunt_sacrifice(sacrificed_card):
		return false
	if not can_pay_moon_hunt_mana_cost(game_manager):
		return false

	var extra_mana := get_moon_hunt_mana_cost(game_manager)
	if extra_mana > 0 and not card_owner.spend_mana(extra_mana):
		return false

	if game_manager != null:
		game_manager._send_to_graveyard_with_hook(sacrificed_card, false, false)
	else:
		card_owner.move_card(sacrificed_card, card_owner.graveyard_zone)
	if sacrificed_card.has_method("on_sacrificed_for_summon") and not sacrificed_card.post_field_abilities_suppressed():
		sacrificed_card.on_sacrificed_for_summon(game_manager, self)

	return game_manager.summon_creature_by_effect(
		card_owner,
		self,
		target_zone,
		mode,
		stealth,
		stealth,
		self,
		false,
		false,
		true
	)

func _get_open_summon_zones() -> Array[Zone]:
	var open_zones: Array[Zone] = []
	if card_owner == null:
		return open_zones
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		if zone.cards.is_empty():
			open_zones.append(zone)
	return open_zones
