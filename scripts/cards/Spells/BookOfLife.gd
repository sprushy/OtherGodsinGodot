extends SpellCard
class_name BookOfLife

const FOLLOWERS_GAINED := 10

func _init() -> void:
	super._init()
	card_name = "Book of Life"
	culture = "Neutral"
	card_types = ["Summon", "Creature"]
	level = 1
	mana_cost = 0
	speed = 1
	is_legendary = true
	flavor_text = ""
	ability_text = "Gain 10 followers. Summon a non-machine creature from your hand and [b]Silence[/b] it."
	artist = ""
	art_path = "res://images/card_art/spells/BoofofLifeAIedit.png"

func resolve(game_manager: GameManager, target = null) -> void:
	if card_owner == null:
		return
	card_owner.gain_followers(FOLLOWERS_GAINED)
	if target is Card:
		summon_silenced_creature(game_manager, target as Card)

func get_valid_hand_creatures() -> Array[Card]:
	var cards: Array[Card] = []
	if card_owner == null:
		return cards
	for card in card_owner.hand_zone.cards:
		if card == self:
			continue
		if card.card_type != Card.CardType.CREATURE:
			continue
		if card.is_god or card.has_type("Machine"):
			continue
		cards.append(card)
	return cards

func summon_silenced_creature(game_manager: GameManager, creature: Card) -> Card:
	if card_owner == null or creature == null:
		return null
	if creature.current_zone != card_owner.hand_zone:
		return null
	if creature.card_type != Card.CardType.CREATURE or creature.is_god or creature.has_type("Machine"):
		return null

	var open_zone: Zone = null
	for zone in card_owner.frontline_zones:
		if zone.cards.is_empty():
			open_zone = zone
			break
	if open_zone == null:
		for zone in card_owner.reserve_zones:
			if zone.cards.is_empty():
				open_zone = zone
				break
	if open_zone == null:
		return null

	if game_manager == null or not game_manager.summon_creature_by_effect(
		card_owner,
		creature,
		open_zone,
		Card.CreatureMode.AGGRESSIVE,
		false,
		false,
		self,
		false,
		false,
		false
	):
		return null
	creature.mute_permanently(game_manager)
	return creature
