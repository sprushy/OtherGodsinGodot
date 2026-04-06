extends GodCard
class_name Odin

const FOLLOWER_PENALTY := 15
const ART_PATH := "res://images/card_art/gods/OdinEdit.png"

func _init() -> void:
	super._init()
	card_name = "Odin, the Allfather"
	card_types = ["Patriarch", "Ecstasy", "Wisdom", "Sorcery", "Death"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	mana_cost = 0
	culture = "Norse"
	targets = true
	flavor_text = ""
	ability_text = "Patriarch Rule\nRunic Knowledge ([b]Activate[/b]): [b]Void[/b] a Runic or an \"of Odin\" card from your hand, field, or grave. Name the top card of your deck and reveal it; if you are correct, draw it. If not, lose 15 followers and [b]Shelve[/b] it."
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	paragon_of_champions = "Ecstasy, Death"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if is_muted:
		return false
	if card_owner != game_manager.current_player:
		return false
	if card_owner == null or card_owner.deck_zone == null or card_owner.deck_zone.cards.is_empty():
		return false
	return not get_valid_runic_knowledge_offerings().is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if is_muted:
		return card_name + " is muted."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if card_owner == null or card_owner.deck_zone == null or card_owner.deck_zone.cards.is_empty():
		return "Runic Knowledge needs a card on top of your deck."
	if get_valid_runic_knowledge_offerings().is_empty():
		return "Runic Knowledge needs a Runic or \"of Odin\" card in your hand, field, or grave."
	return ""

func get_valid_runic_knowledge_offerings() -> Array[Card]:
	var valid_cards: Array[Card] = []
	if card_owner == null:
		return valid_cards

	for card in card_owner.hand_zone.cards:
		if is_valid_runic_knowledge_offering(card):
			valid_cards.append(card)
	for card in card_owner.graveyard_zone.cards:
		if is_valid_runic_knowledge_offering(card):
			valid_cards.append(card)
	for zone in _get_field_zones():
		for card in zone.cards:
			if is_valid_runic_knowledge_offering(card):
				valid_cards.append(card)
	return valid_cards

func is_valid_runic_knowledge_offering(card: Card) -> bool:
	if card == null or card == self or card_owner == null:
		return false
	if not _matches_runic_knowledge_cost(card):
		return false
	if card.current_zone == card_owner.hand_zone:
		return true
	if card.current_zone == card_owner.graveyard_zone:
		return true
	return card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and card.get_controller() == card_owner

func activate(game_manager: GameManager, target = null) -> void:
	var activation_data := _parse_activation_input(target)
	activate_with_data(
		game_manager,
		activation_data.get("offering_card", null) as Card,
		str(activation_data.get("named_card_name", ""))
	)

func activate_with_data(game_manager: GameManager, offering_card: Card, named_card_name: String) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	if not is_valid_runic_knowledge_offering(offering_card):
		game_manager.note_player_feedback("Runic Knowledge fizzles: choose a Runic or \"of Odin\" card from your hand, field, or grave.")
		return

	var guessed_name := str(named_card_name).strip_edges()
	if guessed_name.is_empty():
		game_manager.note_player_feedback("Runic Knowledge fizzles: name the top card of your deck.")
		return
	if not _void_offering_card(game_manager, offering_card):
		game_manager.note_player_feedback("Runic Knowledge fizzles: %s could not be voided." % offering_card.card_name)
		return

	var top_card := _get_top_deck_card()
	if top_card == null:
		game_manager.note_player_feedback("Runic Knowledge resolves, but your deck has no card to reveal.")
		return

	var revealed_name := top_card.card_name
	var guessed_correctly := _guess_matches_top_card(guessed_name, top_card)
	var feedback := "Runic Knowledge voided %s and revealed %s." % [
		offering_card.card_name,
		revealed_name
	]
	if guessed_correctly:
		card_owner.move_card(top_card, card_owner.hand_zone)
		if top_card.current_zone == card_owner.hand_zone:
			feedback += " The guess was correct, so you draw it."
		else:
			feedback += " The guess was correct, but it could not be drawn."
	else:
		card_owner.lose_followers(FOLLOWER_PENALTY)
		game_manager.send_to_deck_bottom_with_hook(top_card)
		feedback += " The guess \"%s\" was wrong, so you lose %d followers and shelve it." % [
			guessed_name,
			FOLLOWER_PENALTY
		]

	game_manager.note_player_feedback(feedback)
	notify_power_activated(game_manager, top_card)

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var offering_uid := str(command.get("offering_uid", ""))
	var offering_card: Card = game_manager.get_card_by_uid(offering_uid) if offering_uid != "" else null
	var guessed_name := str(command.get("named_card_name", command.get("guess_name", "")))
	activate_with_data(game_manager, offering_card, guessed_name)

func _parse_activation_input(target) -> Dictionary:
	var parsed := {
		"offering_card": null,
		"named_card_name": "",
	}
	if target is Dictionary:
		var target_dict := target as Dictionary
		parsed["offering_card"] = target_dict.get("offering_card", target_dict.get("void_card", target_dict.get("tribute_card", null)))
		parsed["named_card_name"] = str(target_dict.get("named_card_name", target_dict.get("guess_name", target_dict.get("card_name", ""))))
	return parsed

func _matches_runic_knowledge_cost(card: Card) -> bool:
	if card == null:
		return false
	if card.has_type("Runic"):
		return true
	return card.card_name.to_lower().contains("of odin")

func _guess_matches_top_card(guess_name: String, top_card: Card) -> bool:
	if top_card == null:
		return false
	var guess_key := CardCatalog.to_lookup_key(guess_name)
	if guess_key == CardCatalog.to_lookup_key(top_card.card_name):
		return true
	if top_card.has_method("get_normalized_card_name") and guess_key == CardCatalog.to_lookup_key(str(top_card.get_normalized_card_name())):
		return true
	if top_card.has_method("get_ascii_card_name") and guess_key == CardCatalog.to_lookup_key(str(top_card.get_ascii_card_name())):
		return true
	return false

func _void_offering_card(game_manager: GameManager, offering_card: Card) -> bool:
	if offering_card == null:
		return false
	if offering_card.current_zone != null and offering_card.current_zone.is_board_zone():
		game_manager._send_to_abyss_with_hook(offering_card)
	else:
		offering_card.card_owner.move_card(offering_card, offering_card.card_owner.abyss_zone)
	return offering_card.current_zone == offering_card.card_owner.abyss_zone

func _get_top_deck_card() -> Card:
	if card_owner == null or card_owner.deck_zone == null or card_owner.deck_zone.cards.is_empty():
		return null
	return card_owner.deck_zone.cards[0] as Card

func _get_field_zones() -> Array[Zone]:
	if card_owner == null:
		return []
	var zones: Array[Zone] = []
	zones.append_array(card_owner.frontline_zones)
	zones.append_array(card_owner.reserve_zones)
	return zones
