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
	ability_text = "[b]Shelve[/b] cards off the top of your deck until you draw a magical card, prepare that card revealed."
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
			game_manager.note_player_feedback("%s found no magical card to prepare." % card_name)
			return
		game_manager.note_player_feedback("%s shelved %s and found no magical card." % [
			card_name,
			_join_card_names(shelved_cards, viewer)
		])
		return

	var prepare_zone := _find_prepare_zone(controller)
	if prepare_zone == null:
		game_manager.note_player_feedback("%s found a magical card, but %s had no open zone to prepare it." % [
			card_name,
			controller.player_name
		])
		return

	found_card.card_owner = controller
	found_card.is_prepared = true
	found_card.is_face_down = true
	found_card.is_stealth = false
	found_card.remove_status_effects_by_name("temporarily_revealed")
	found_card.add_status_effect(
		"temporarily_revealed",
		card_name,
		self,
		controller,
		{
			"clear_when_hidden_state_ends": true,
		}
	)
	controller.move_card(found_card, prepare_zone)
	if found_card.current_zone != prepare_zone:
		found_card.is_prepared = false
		found_card.is_face_down = false
		found_card.is_stealth = false
		found_card.remove_status_effects_by_name("temporarily_revealed")
		game_manager.note_player_feedback("%s found a magical card, but it could not be prepared." % card_name)
		return

	if found_card.card_type == Card.CardType.HEX:
		game_manager.prepared_hexes[found_card] = game_manager.turn_number
	elif found_card is CharmCard:
		game_manager.prepared_charms[found_card] = game_manager.turn_number

	if shelved_cards.is_empty():
		game_manager.note_player_feedback("%s prepared %s revealed in %s." % [
			card_name,
			found_card.card_name,
			_target_zone_label(prepare_zone, controller)
		])
		return

	game_manager.note_player_feedback("%s shelved %s, then prepared %s revealed in %s." % [
		card_name,
		_join_card_names(shelved_cards, viewer),
		found_card.card_name,
		_target_zone_label(prepare_zone, controller)
	])

func _join_card_names(cards: Array[Card], viewer: Player = null) -> String:
	var names: Array[String] = []
	for card in cards:
		if card != null:
			names.append(card.get_target_log_display_name(viewer))
	return ", ".join(names)

func _find_prepare_zone(controller: Player) -> Zone:
	if controller == null:
		return null
	for zone in controller.reserve_zones:
		if _can_prepare_into_zone(zone):
			return zone
	for zone in controller.frontline_zones:
		if _can_prepare_into_zone(zone):
			return zone
	return null

func _can_prepare_into_zone(zone: Zone) -> bool:
	return zone != null and zone.cards.is_empty() and zone.get_equipment().is_empty()

func _target_zone_label(zone: Zone, controller: Player) -> String:
	if zone == null or controller == null:
		return "the field"
	var lane_number := zone.zone_index + 1
	if zone in controller.frontline_zones:
		return "%s's Front Line %d" % [controller.player_name, lane_number]
	if zone in controller.reserve_zones:
		return "%s's Reserve %d" % [controller.player_name, lane_number]
	return "the field"
