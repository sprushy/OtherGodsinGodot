# DeckBuilder.gd
extends RefCounted
class_name DeckBuilder

func build_deck(player: Player, selected_cards: Array[Card]) -> bool:
	if player.validate_deck(selected_cards):
		var unique_cards: Array[Card] = []
		for card in selected_cards:
			unique_cards.append(card.duplicate(true))
			
		player.current_deck = unique_cards.duplicate()
		
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
		
		return true
	return false
