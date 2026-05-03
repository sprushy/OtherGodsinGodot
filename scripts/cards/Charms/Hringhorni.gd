extends CharmCard
class_name Hringhorni

func _init() -> void:
	super._init()
	card_name = "Hringhorni"
	culture = "Norse"
	card_types = ["Charm", "Recruitment"]
	level = 3
	mana_cost = 0
	speed = 3
	flavor_text = ""
	ability_text = "Activate when one of your Norse Warriors is destroyed; summon a Norse Warrior of the same level or lower from your deck."
	artist = "Tim Nguyen"
	art_path = "res://images/card_art/charms/HringhorniEdit.png"

func can_activate_from_hand(game_manager: GameManager, triggering_action: CardAction = null) -> bool:
	if not super.can_activate_from_hand(game_manager, triggering_action):
		return false
	return _has_destroyed_friendly_norse_warrior(game_manager)

func can_activate_prepared(game_manager: GameManager, triggering_action: CardAction = null) -> bool:
	if not super.can_activate_prepared(game_manager, triggering_action):
		return false
	return _has_destroyed_friendly_norse_warrior(game_manager)

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null or card_owner == null:
		return
	var valid_recruits := get_valid_recruits(game_manager)
	if valid_recruits.is_empty():
		game_manager.note_player_feedback(card_name + " fizzles: no valid Norse Warrior to recruit.")
		return
	var summon_zone := _find_open_summon_zone()
	if summon_zone == null:
		game_manager.note_player_feedback(card_name + " fizzles: no open summon lane.")
		return
	var recruit := valid_recruits[0]
	if not game_manager.summon_creature_by_effect(
		card_owner,
		recruit,
		summon_zone,
		Card.CreatureMode.AGGRESSIVE,
		false,
		false,
		self,
		false,
		false,
		true
	):
		game_manager.note_player_feedback("%s fizzles: %s could not be summoned." % [card_name, recruit.card_name])
		return
	game_manager.note_player_feedback("%s recruited %s from the deck." % [card_name, recruit.card_name])

func get_valid_recruits(game_manager: GameManager) -> Array[Card]:
	var valid_recruits: Array[Card] = []
	if game_manager == null or card_owner == null or card_owner.deck_zone == null:
		return valid_recruits
	var max_level := get_destroyed_warrior_level_cap(game_manager)
	if max_level < 0:
		return valid_recruits
	if _find_open_summon_zone() == null:
		return valid_recruits
	for card in card_owner.deck_zone.cards:
		if _is_valid_recruit(card, max_level):
			valid_recruits.append(card)
	return valid_recruits

func get_destroyed_warrior_level_cap(game_manager: GameManager) -> int:
	if game_manager == null or card_owner == null:
		return -1
	var max_level := -1
	for card in game_manager.destroyed_this_turn:
		if _is_valid_destroyed_warrior(card):
			max_level = maxi(max_level, card.get_effective_level())
	return max_level

func _is_valid_destroyed_warrior(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.card_owner == card_owner \
		and card.has_type("Warrior") \
		and (card.has_type("Norse Creature") or card.culture == "Norse")

func _has_destroyed_friendly_norse_warrior(game_manager: GameManager) -> bool:
	return get_destroyed_warrior_level_cap(game_manager) >= 0

func _is_valid_recruit(card: Card, max_level: int) -> bool:
	return card != null \
		and card.current_zone == card_owner.deck_zone \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.has_type("Warrior") \
		and (card.has_type("Norse Creature") or card.culture == "Norse") \
		and card.get_effective_level() <= max_level

func _find_open_summon_zone() -> Zone:
	if card_owner == null:
		return null
	for zone in card_owner.frontline_zones:
		if zone.cards.is_empty():
			return zone
	for zone in card_owner.reserve_zones:
		if zone.cards.is_empty():
			return zone
	return null
