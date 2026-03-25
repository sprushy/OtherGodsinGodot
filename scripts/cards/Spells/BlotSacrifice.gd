extends SpellCard
class_name BlotSacrifice

const MAX_SUMMON_LEVELS := 7

func _init() -> void:
	super._init()
	card_name = "Blot Sacrifice"
	culture = "Norse"
	card_types = ["Summon", "Creature"]
	level = 1
	mana_cost = 1
	speed = 1
	is_legendary = false
	sacrifice_cost = 0
	creature_sacrifice_cost = 1
	flavor_text = ""
	art_path = "res://images/card_art/spells/Blot Sacrifice(web).jpg"
	artist = "Ricardo Zoppello"
	ability_text = "Summon up to 7 levels of creatures from your hand, disregarding summon cost."

func resolve(game_manager: GameManager, target = null) -> void:
	pass

func get_available_summon_zones() -> Array[Zone]:
	var zones: Array[Zone] = []
	if card_owner == null:
		return zones
	for zone in card_owner.frontline_zones:
		if zone.cards.is_empty():
			zones.append(zone)
	for zone in card_owner.reserve_zones:
		if zone.cards.is_empty():
			zones.append(zone)
	return zones

func get_valid_hand_creatures(max_total_levels: int = MAX_SUMMON_LEVELS, excluded: Array = []) -> Array[Card]:
	var cards: Array[Card] = []
	if card_owner == null:
		return cards
	for card in card_owner.hand_zone.cards:
		if card == self:
			continue
		if card in excluded:
			continue
		if card.card_type != Card.CardType.CREATURE:
			continue
		if card.is_god:
			continue
		if card.level > max_total_levels:
			continue
		cards.append(card)
	return cards

func summon_selected_creatures(game_manager: GameManager, creatures: Array) -> Array[Card]:
	var summoned: Array[Card] = []
	var open_zones := get_available_summon_zones()
	for creature in creatures:
		if open_zones.is_empty():
			break
		if creature == null or (creature.current_zone != card_owner.hand_zone and creature not in card_owner.hand_zone.cards):
			continue
		var zone: Zone = open_zones.pop_front() as Zone
		card_owner.move_card(creature, zone)
		creature.creature_mode = Card.CreatureMode.AGGRESSIVE
		creature.reset_creature_action_state()
		creature.summoned_this_turn = true
		creature.is_face_down = false
		creature.is_stealth = false
		creature.wake_up()
		if game_manager != null and game_manager.has_method("_apply_god_passives_to_card"):
			game_manager._apply_god_passives_to_card(card_owner, creature)
		if creature.has_method("on_impact"):
			creature.on_impact(game_manager)
		summoned.append(creature)
	return summoned
