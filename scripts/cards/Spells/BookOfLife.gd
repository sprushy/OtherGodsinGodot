extends SpellCard
class_name BookOfLife

const FOLLOWERS_GAINED := 10

func _init() -> void:
	super._init()
	card_name = "Book of Life"
	culture = "Neutral"
	card_types = ["Summon", "Creature"]
	level = 1
	mana_cost = 1
	speed = 1
	is_legendary = true
	flavor_text = ""
	ability_text = "Gain 10 followers; summon a non-machine creature from your hand and silence its effects."
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

	card_owner.move_card(creature, open_zone)
	creature.creature_mode = Card.CreatureMode.ATTACK
	creature.reset_creature_action_state()
	creature.summoned_this_turn = true
	creature.is_face_down = false
	creature.is_stealth = false
	creature.wake_up()
	creature.mute_permanently(game_manager)
	if game_manager != null and game_manager.has_method("_apply_god_passives_to_card"):
		game_manager._apply_god_passives_to_card(card_owner, creature)
	return creature
