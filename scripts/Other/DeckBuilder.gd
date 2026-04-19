# DeckBuilder.gd
extends RefCounted
class_name DeckBuilder

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")

func build_deck(player: Player, selected_cards: Array[Card], special_setup: Dictionary = {}) -> bool:
	if player.validate_deck(selected_cards):
		var unique_cards: Array[Card] = []
		for card in selected_cards:
			unique_cards.append(card.duplicate(true))
			
		player.current_deck = unique_cards.duplicate()
		
		var god_card: Card = null
		var power_cards: Array[Card] = []
		var regular_cards: Array[Card] = []
		var reserved_active_god: ActiveGodCard = null
		
		for card in unique_cards:
			card.card_owner = player
			if card.is_god:
				god_card = card
			elif card.is_power:
				power_cards.append(card)
			else:
				regular_cards.append(card)
		
		if god_card:
			player.god_zone.add_card(god_card)
		
		var god_template := god_card as GodCard
		if god_template != null:
			var drawable_regular_cards: Array[Card] = []
			for card in regular_cards:
				var active_god := card as ActiveGodCard
				if active_god != null and god_template.get_active_god_deck_role(active_god) == GodCard.ACTIVE_GOD_DECK_ROLE_RESERVED:
					if reserved_active_god == null:
						reserved_active_god = active_god
					continue
				drawable_regular_cards.append(card)
			regular_cards = drawable_regular_cards

		for i in range(min(power_cards.size(), 3)):
			player.power_zones[i].add_card(power_cards[i])
		
		regular_cards.shuffle()
		for card in regular_cards:
			player.deck_zone.add_card(card)
		if reserved_active_god != null:
			player.abyss_zone.add_card(reserved_active_god)

		_apply_special_setup(player, special_setup)
		
		return true
	return false

func _apply_special_setup(player: Player, special_setup: Dictionary) -> void:
	if player == null:
		return
	var slot_card_names := TiamatScript.get_slot_card_names_from_setup(special_setup)
	var has_slot_cards := false
	for slot_cards in slot_card_names:
		if not slot_cards.is_empty():
			has_slot_cards = true
			break
	if not has_slot_cards:
		return

	var existing_powers: Array[Card] = []
	for zone in player.power_zones:
		for card in zone.cards.duplicate():
			zone.remove_card(card)
			if card != null and card.is_power and not card.is_god:
				existing_powers.append(card)

	for slot_index in range(min(player.power_zones.size(), slot_card_names.size())):
		var zone := player.power_zones[slot_index]
		var slot_cards: Array[String] = slot_card_names[slot_index]
		if slot_cards.is_empty():
			if not existing_powers.is_empty():
				zone.add_card(existing_powers.pop_front())
			continue
		for card_name in slot_cards:
			var card := CardCatalogScript.instantiate_card_by_name(card_name)
			if card == null:
				continue
			card.card_owner = player
			card.is_face_down = false
			card.is_stealth = false
			card.is_prepared = false
			zone.add_card(card)
