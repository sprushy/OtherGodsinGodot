extends SpellCard
class_name WildMagic

const ART_PATH := "res://images/card_art/spells/WildMagicArt.jpg"

func _init() -> void:
	super._init()
	card_name = "Wild Magic"
	culture = "Neutral"
	card_types = ["Search", "Magical"]
	level = 2
	mana_cost = 0
	speed = 1
	flavor_text = ""
	ability_text = "[b]Shelve[/b] cards off the top of your deck until you draw a magical card, add that card to your hand."
	artist = "CC0"
	art_path = ART_PATH
	targets = false

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null or card_owner == null or card_owner.deck_zone == null:
		return

	var controller := card_owner
	if controller.deck_zone.cards.is_empty():
		game_manager.note_player_feedback("%s fizzles: %s's deck is empty." % [card_name, controller.player_name])
		return

	var viewer := game_manager.get_feedback_viewer()
	var cards_to_scan := controller.deck_zone.cards.size()
	var shelved_cards: Array[Card] = []
	var found_card: Card = null

	for _scan_index in range(cards_to_scan):
		if controller.deck_zone.cards.is_empty():
			break
		var top_card := controller.deck_zone.cards[0] as Card
		if top_card == null:
			break
		if top_card.is_magical_card():
			found_card = top_card
			break
		controller.deck_zone.cards.erase(top_card)
		controller.deck_zone.cards.append(top_card)
		shelved_cards.append(top_card)

	if found_card == null:
		if shelved_cards.is_empty():
			game_manager.note_player_feedback("%s found no magical card to draw." % card_name)
			return
		game_manager.note_player_feedback("%s shelved %s and found no magical card." % [
			card_name,
			_join_card_names(shelved_cards, viewer)
		])
		return

	controller.move_card(found_card, controller.hand_zone)
	if found_card.current_zone != controller.hand_zone:
		game_manager.note_player_feedback("%s found %s, but it could not be added to hand." % [
			card_name,
			found_card.get_target_log_display_name(viewer)
		])
		return
	found_card.card_owner = controller

	if shelved_cards.is_empty():
		game_manager.note_player_feedback("%s added %s from the top of the deck to %s's hand." % [
			card_name,
			found_card.get_target_log_display_name(viewer),
			controller.player_name
		])
		return

	game_manager.note_player_feedback("%s shelved %s, then added %s to %s's hand." % [
		card_name,
		_join_card_names(shelved_cards, viewer),
		found_card.get_target_log_display_name(viewer),
		controller.player_name
	])

func _join_card_names(cards: Array[Card], viewer: Player = null) -> String:
	var names: Array[String] = []
	for card in cards:
		if card != null:
			names.append(card.get_target_log_display_name(viewer))
	return ", ".join(names)
