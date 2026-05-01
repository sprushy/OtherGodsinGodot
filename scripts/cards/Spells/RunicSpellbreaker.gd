extends SpellCard
class_name RunicSpellbreaker

const ART_PATH := "res://images/card_art/spells/RunicStoneBreakerEdit.jpg"

func _init() -> void:
	super._init()
	card_name = "Runic Spellbreaker"
	culture = "Norse"
	card_types = ["Runic", "Destruction"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 2
	mana_cost = 0
	speed = 1
	is_legendary = false
	targets = true
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = ART_PATH
	ability_text = "Destroy one face-up or revealed magical card and send any copies of it from your opponent's deck to the graveyard."

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets

	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones + player.power_zones:
			for card in zone.cards:
				if is_valid_target(card):
					valid_targets.append(card)
	return valid_targets

func is_valid_target(target: Card) -> bool:
	return target != null \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.is_magical_card() \
		and _is_face_up_or_revealed(target)

func resolve(game_manager: GameManager, target = null) -> void:
	if game_manager == null:
		return
	if not is_valid_target(target):
		game_manager.note_player_feedback(card_name + " requires a face-up or revealed magical card.")
		print(card_name + " requires a face-up or revealed magical card.")
		return

	var target_card := target as Card
	var viewer := game_manager.get_feedback_viewer()
	var target_name := target_card.get_target_log_display_name(viewer)
	var target_lookup_key := CardCatalog.to_lookup_key(_get_card_lookup_name(target_card))
	var on_destroy_complete := func() -> void:
		var destroyed := target_card.current_zone == null or not target_card.current_zone.is_board_zone()
		if not destroyed:
			var failed_text := "%s failed to destroy %s." % [card_name, target_name]
			game_manager.note_player_feedback(failed_text)
			print(failed_text)
			return

		var milled_count := _send_matching_copies_from_opponent_deck_to_graveyard(game_manager, target_lookup_key)
		var feedback := "%s destroyed %s." % [card_name, target_name]
		if milled_count > 0:
			feedback += " Sent %d copy(ies) from your opponent's deck to the graveyard." % milled_count
		else:
			feedback += " No matching copies were found in your opponent's deck."
		game_manager.note_player_feedback(feedback)
		print(feedback)

	game_manager.request_send_to_graveyard(target_card, on_destroy_complete, false, true)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	if get_valid_targets(game_manager).is_empty():
		print(card_name + " has no valid targets.")
		return false
	return true

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	var base_reason := super.get_play_failure_reason(game_manager, player)
	if not base_reason.is_empty():
		return base_reason
	if get_valid_targets(game_manager).is_empty():
		return card_name + " requires a face-up or revealed magical card."
	return ""

func _is_face_up_or_revealed(card: Card) -> bool:
	if card == null:
		return false
	if card.is_temporarily_revealed():
		return true
	return not card.is_face_down and not card.is_prepared and not card.is_stealth

func _send_matching_copies_from_opponent_deck_to_graveyard(game_manager: GameManager, target_lookup_key: String) -> int:
	if game_manager == null or card_owner == null or target_lookup_key == "":
		return 0

	var opponent := game_manager.get_opponent(card_owner)
	if opponent == null or opponent.deck_zone == null:
		return 0

	var matching_cards: Array[Card] = []
	for deck_card in opponent.deck_zone.cards.duplicate():
		if deck_card == null or deck_card.current_zone != opponent.deck_zone:
			continue
		if CardCatalog.to_lookup_key(_get_card_lookup_name(deck_card)) != target_lookup_key:
			continue
		matching_cards.append(deck_card)

	for matching_card in matching_cards:
		opponent.move_card(matching_card, opponent.graveyard_zone)

	return matching_cards.size()

func _get_card_lookup_name(card: Card) -> String:
	if card == null:
		return ""
	if card.has_method("get_normalized_card_name"):
		return str(card.get_normalized_card_name())
	return str(card.card_name)
