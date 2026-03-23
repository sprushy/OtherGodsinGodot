extends SpellCard
class_name ApollyonsDemiurge

const ART_PATH := "res://images/card_art/apollyons_demiurge.png"

func _init() -> void:
	super._init()
	card_name = "Apollyon's Demiurge"
	culture = "Olympic"
	card_types = ["Summon", "Demon", "Grave"]
	level = 2
	mana_cost = 0
	speed = 1
	is_legendary = false
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	flavor_text = "From ruin and flame, the demon rises."
	art_path = ART_PATH
	ability_text = "Pay X mana and [b]Mill[/b] X cards; summon one Demon milled this way."

func can_cast_with_x(game_manager: GameManager, x_value: int) -> bool:
	if game_manager == null or card_owner == null:
		return false
	if x_value <= 0:
		return false
	if card_owner.mana < x_value:
		return false
	return card_owner.deck_zone.cards.size() >= x_value

func get_max_x_value() -> int:
	if card_owner == null:
		return 0
	return mini(card_owner.mana, card_owner.deck_zone.cards.size())

func resolve_with_x(game_manager: GameManager, x_value: int) -> Array[Card]:
	var demon_choices: Array[Card] = []
	if not can_cast_with_x(game_manager, x_value):
		print("Apollyon's Demiurge: invalid X cost.")
		return demon_choices

	card_owner.spend_mana(x_value)
	var milled_cards := _mill_cards(x_value)
	for card in milled_cards:
		if _is_demon(card):
			demon_choices.append(card)
	return demon_choices

func summon_milled_demon(demon_card: Card) -> bool:
	if demon_card == null or card_owner == null:
		return false
	if demon_card.current_zone != card_owner.graveyard_zone:
		return false
	var summon_zone := _find_summon_zone()
	if summon_zone == null:
		print("Apollyon's Demiurge: no open zone to summon into.")
		return false
	card_owner.move_card(demon_card, summon_zone)
	demon_card.creature_mode = Card.CreatureMode.ATTACK
	demon_card.has_acted_this_turn = false
	demon_card.has_moved_this_turn = false
	demon_card.summoned_this_turn = true
	demon_card.is_face_down = false
	demon_card.is_stealth = false
	print("Apollyon's Demiurge summons " + demon_card.card_name + ".")
	return true

func _mill_cards(amount: int) -> Array[Card]:
	var milled: Array[Card] = []
	for i in range(amount):
		if card_owner.deck_zone.cards.is_empty():
			break
		var milled_card := card_owner.deck_zone.cards[0]
		card_owner.move_card(milled_card, card_owner.graveyard_zone)
		milled.append(milled_card)
		print("Milled: " + milled_card.card_name)
	return milled

func _is_demon(card: Card) -> bool:
	return card != null and card.has_type("Demon")

func _find_summon_zone() -> Zone:
	for zone in card_owner.frontline_zones:
		if zone.cards.is_empty():
			return zone
	for zone in card_owner.reserve_zones:
		if zone.cards.is_empty():
			return zone
	return null
