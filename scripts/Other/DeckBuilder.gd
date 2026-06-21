# DeckBuilder.gd
extends RefCounted
class_name DeckBuilder

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")
const CardArtVariantsScript = preload("res://scripts/core/CardArtVariants.gd")

func build_deck(player: Player, selected_cards: Array[Card], special_setup: Dictionary = {}) -> bool:
	var validation := player.get_deck_validation(selected_cards, special_setup)
	if bool(validation.get("is_valid", false)):
		var validated_special_setup: Dictionary = validation.get("special_setup", special_setup)
		var unique_cards: Array[Card] = []
		for card in selected_cards:
			var deck_card := card.duplicate(true)
			if deck_card is BaseCard:
				(deck_card as BaseCard).assign_fresh_uid()
			CardArtVariantsScript.apply_to_card(deck_card, validated_special_setup)
			unique_cards.append(deck_card)
			
		player.current_deck = unique_cards.duplicate()
		player.reserved_active_god = null
		
		var god_card: Card = null
		var power_cards: Array[Card] = []
		var regular_cards: Array[Card] = []
		
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

		for i in range(min(power_cards.size(), 3)):
			player.power_zones[i].add_card(power_cards[i])
		
		regular_cards.shuffle()
		for card in regular_cards:
			player.deck_zone.add_card(card)

		_apply_special_setup(player, validated_special_setup)
		
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
			CardArtVariantsScript.apply_to_card(card, special_setup)
			card.card_owner = player
			card.is_face_down = false
			card.is_stealth = false
			card.is_prepared = false
			zone.add_card(card)
