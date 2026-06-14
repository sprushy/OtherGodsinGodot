extends StructureCard
class_name HildskjalfThroneOfOdin

const ART_PATH := "res://images/card_art/structures/ThroneodOdinEdit.png"
const LOOK_COUNT := 3
const USES_PER_TURN := 1

var uses_this_turn := 0

func _init() -> void:
	super._init()
	card_name = "Hildskjalf: Throne of Odin"
	card_types = ["Seat", "Throne"]
	level = 2
	mana_cost = 0
	resilience = 15
	speed = 0
	strength = 0
	sacrifice_cost = 0
	targets = true
	ability_text = "Once per turn, look at the top 3 cards of either deck, choose one to [b]Prime[/b], then [b]Shelve[/b] the rest."
	flavor_text = ""
	culture = "Norse"
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func get_activation_label() -> String:
	return "High Seat"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if card_owner != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_face_down or is_stealth:
		return false
	if abilities_suppressed() or is_activation_locked(game_manager):
		return false
	if uses_this_turn >= USES_PER_TURN:
		return false
	return not get_readable_deck_owners(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if current_zone == null or not current_zone.is_board_zone():
		return card_name + " must be on the field."
	if is_face_down or is_stealth:
		return card_name + " must be revealed first."
	if abilities_suppressed():
		return card_name + " has no active abilities right now."
	if is_activation_locked(game_manager):
		return card_name + " cannot activate this turn."
	if uses_this_turn >= USES_PER_TURN:
		return card_name + " has already been used this turn."
	if get_readable_deck_owners(game_manager).is_empty():
		return card_name + " found no cards to read."
	return card_name + " cannot activate right now."

func get_readable_deck_owners(game_manager: GameManager) -> Array[Player]:
	var readable_players: Array[Player] = []
	if game_manager == null:
		return readable_players
	for player in [card_owner, game_manager.get_opponent(card_owner)]:
		if player != null and not _get_top_cards_for_player(player).is_empty():
			readable_players.append(player)
	return readable_players

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets

	for player in get_readable_deck_owners(game_manager):
		valid_targets.append_array(_get_top_cards_for_player(player))
	return valid_targets

func get_top_cards_for_deck_owner(game_manager: GameManager, deck_owner: Player) -> Array[Card]:
	if game_manager == null or deck_owner == null:
		return []
	if deck_owner not in get_readable_deck_owners(game_manager):
		return []
	return _get_top_cards_for_player(deck_owner)

func activate(game_manager: GameManager, target = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return

	var chosen_card := _parse_target(game_manager, target)
	var deck_owner := _parse_deck_owner(game_manager, target)
	var valid_targets := get_top_cards_for_deck_owner(game_manager, deck_owner) if deck_owner != null else get_valid_targets(game_manager)
	if chosen_card == null:
		game_manager.note_player_feedback("%s fizzles: choose a card from the selected deck." % card_name)
		return
	elif chosen_card not in valid_targets:
		game_manager.note_player_feedback("%s fizzles: that card is no longer a valid choice." % card_name)
		return

	game_manager.note_player_feedback(resolve_high_seat_choice(game_manager, chosen_card))

func resolve_high_seat_choice(game_manager: GameManager, chosen_card: Card) -> String:
	if game_manager == null or chosen_card == null:
		return card_name + " found no card to prime."

	var deck_owner := chosen_card.card_owner
	if chosen_card.current_zone != null and chosen_card.current_zone.zone_owner != null:
		deck_owner = chosen_card.current_zone.zone_owner
	if deck_owner == null or deck_owner.deck_zone == null:
		return card_name + " found no deck to read."

	var top_cards := _get_top_cards_for_player(deck_owner)
	if chosen_card not in top_cards:
		return "%s fizzles: %s is no longer among the top cards." % [card_name, chosen_card.card_name]

	var shelved_cards: Array[Card] = []
	for card in top_cards:
		deck_owner.deck_zone.cards.erase(card)
		if card == chosen_card:
			continue
		shelved_cards.append(card)

	deck_owner.deck_zone.cards.insert(0, chosen_card)
	for card in shelved_cards:
		deck_owner.deck_zone.cards.append(card)

	uses_this_turn += 1

	var viewer := game_manager.get_feedback_viewer()
	var deck_label := "%s's deck" % deck_owner.player_name
	var primed_name := chosen_card.get_target_log_display_name(viewer)
	if shelved_cards.is_empty():
		return "%s read %s and primed %s." % [card_name, deck_label, primed_name]

	var shelved_names: Array[String] = []
	for card in shelved_cards:
		shelved_names.append(card.get_target_log_display_name(viewer))
	return "%s read %s, primed %s, and shelved %s." % [
		card_name,
		deck_label,
		primed_name,
		", ".join(shelved_names)
	]

func on_turn_upkeep(_game_manager: GameManager) -> void:
	uses_this_turn = 0

func _parse_target(game_manager: GameManager, target) -> Card:
	if target is Card:
		return target
	if target is Dictionary:
		var option := target as Dictionary
		var chosen_uid := str(option.get("chosen_uid", option.get("target_uid", "")))
		if chosen_uid != "" and game_manager != null:
			return game_manager.get_card_by_uid(chosen_uid)
	return null

func _parse_deck_owner(game_manager: GameManager, target) -> Player:
	if game_manager == null or not (target is Dictionary):
		return null
	var option := target as Dictionary
	var player_index := int(option.get("deck_owner_player_index", -1))
	if player_index >= 0 and player_index < game_manager.players.size():
		return game_manager.players[player_index]
	return null

func _get_top_cards_for_player(player: Player) -> Array[Card]:
	var cards: Array[Card] = []
	if player == null or player.deck_zone == null:
		return cards
	var limit := mini(LOOK_COUNT, player.deck_zone.cards.size())
	for i in range(limit):
		var card := player.deck_zone.cards[i] as Card
		if card != null:
			cards.append(card)
	return cards
