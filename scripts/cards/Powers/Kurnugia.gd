extends PowerCard
class_name KurnugiaTheBeginningOfTheEnd

const ART_PATH := "res://images/card_art/powers/KurnugiaArt.jpg"

# Maps card uid -> turn_number when the card was sheltered
var _sheltered_release_turns: Dictionary = {}
# Maps card uid -> "graveyard" or "abyss"
var _sheltered_destinations: Dictionary = {}
var sheltered_cards: Array[Card] = []

func _init() -> void:
	super._init()
	card_name = "Kurnugia, The Beginning of the End"
	culture = "Ancient"
	level = 0
	mana_cost = 5
	card_types = ["Power", "Ancient Power"]
	ability_text = "[b]Alternate State[/b]: When a friendly Ancient Human or Mer is destroyed or voided from the field, you may place it under this card until the end of your next turn instead. While under this card, it counts as on the field for effects and requirements, keeps its passive abilities, and may use abilities that affect the field."
	art_path = ART_PATH

func get_hover_detail_lines(viewer: Player = null) -> Array[String]:
	var lines := super.get_hover_detail_lines(viewer)
	var sheltered := _get_sheltered_cards()
	if sheltered.is_empty():
		return lines

	lines.append("[b]Sheltered creatures:[/b]")
	for card in sheltered:
		var return_destination := "Abyss" if str(_sheltered_destinations.get(card.uid, "graveyard")) == "abyss" else "graveyard"
		lines.append("- %s -> %s" % [card.get_target_log_display_name(viewer), return_destination])
	return lines

func get_hover_stored_cards(_viewer: Player = null) -> Array[Card]:
	return _get_sheltered_cards()

func get_hover_stored_cards_title(_viewer: Player = null) -> String:
	return "Sheltered Creatures"

func get_serialized_state() -> Dictionary:
	var state := super.get_serialized_state()
	var sheltered_entries: Array[Dictionary] = []
	for card in sheltered_cards:
		if card == null:
			continue
		sheltered_entries.append({
			"card": GameState.serialize_embedded_card(card),
			"release_turn": int(_sheltered_release_turns.get(card.uid, -1)),
			"destination": str(_sheltered_destinations.get(card.uid, "graveyard")),
		})
	state["sheltered_cards"] = sheltered_entries
	return state

func apply_serialized_state(state: Dictionary) -> void:
	super.apply_serialized_state(state)
	sheltered_cards.clear()
	_sheltered_release_turns.clear()
	_sheltered_destinations.clear()
	for entry_value in state.get("sheltered_cards", []):
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		var card_data = entry.get("card", {})
		if not (card_data is Dictionary):
			continue
		var sheltered_card := GameState.deserialize_embedded_card(card_data as Dictionary)
		if sheltered_card == null:
			continue
		sheltered_card.card_owner = card_owner
		sheltered_card.current_zone = null
		sheltered_cards.append(sheltered_card)
		_sheltered_release_turns[sheltered_card.uid] = int(entry.get("release_turn", -1))
		_sheltered_destinations[sheltered_card.uid] = str(entry.get("destination", "graveyard"))

func get_sheltered_cards_for_passive_effects() -> Array[Card]:
	if not is_effectively_active():
		return []
	return _get_sheltered_cards()

func get_sheltered_cards_for_field_effects() -> Array[Card]:
	if not is_effectively_active():
		return []
	return _get_sheltered_cards()

func on_any_card_moved(game_manager: GameManager, moved_card: Card, from_zone: Zone, to_zone: Zone) -> void:
	# Forward to sheltered cards so their field-affecting abilities still trigger
	for card in _get_sheltered_cards():
		if card != null and card != moved_card and card.has_method("on_any_card_moved") and not card.abilities_suppressed():
			card.on_any_card_moved(game_manager, moved_card, from_zone, to_zone)

	if not is_effectively_active() or game_manager == null:
		return
	if moved_card == null or to_zone == null or card_owner == null:
		return
	if not _is_qualifying_card(moved_card):
		return
	if moved_card.card_owner != card_owner:
		return
	if moved_card in sheltered_cards:
		if to_zone != null:
			_forget_sheltered_card(moved_card)
		return

	var came_from_field := from_zone != null and from_zone.is_board_zone()
	if not came_from_field:
		return

	var went_to_graveyard := to_zone == card_owner.graveyard_zone
	var went_to_abyss := to_zone == card_owner.abyss_zone
	if not went_to_graveyard and not went_to_abyss:
		return

	_shelter_card(game_manager, moved_card, to_zone, went_to_abyss)

func _shelter_card(game_manager: GameManager, card: Card, holding_zone: Zone, was_voided: bool) -> void:
	# Remove from holding zone and track in limbo
	holding_zone.cards.erase(card)
	card.current_zone = null

	sheltered_cards.append(card)
	_sheltered_destinations[card.uid] = "abyss" if was_voided else "graveyard"
	_sheltered_release_turns[card.uid] = game_manager.turn_number
	_emit_visual_state_changed()

	var origin := "the Abyss" if was_voided else "the graveyard"
	game_manager.note_player_feedback(
		"%s shelters %s from %s under Kurnugia's Alternate State until end of %s's next turn." % [
			card_name, card.card_name, origin, card_owner.player_name
		]
	)

func _forget_sheltered_card(card: Card) -> void:
	if card == null:
		return
	sheltered_cards.erase(card)
	_sheltered_release_turns.erase(card.uid)
	_sheltered_destinations.erase(card.uid)
	_emit_visual_state_changed()

func on_global_turn_start(game_manager: GameManager, starting_player: Player) -> void:
	for card in _get_sheltered_cards():
		if card != null and card.has_method("on_global_turn_start") and not card.abilities_suppressed():
			card.on_global_turn_start(game_manager, starting_player)

func on_global_turn_end(game_manager: GameManager, ending_player: Player) -> void:
	# Forward turn-end field abilities to sheltered cards first
	for card in _get_sheltered_cards():
		if card != null and card.has_method("on_global_turn_end") and not card.abilities_suppressed():
			card.on_global_turn_end(game_manager, ending_player)

	# Release cards when the owner's NEXT turn ends
	if ending_player != card_owner:
		return
	_release_expired_cards(game_manager)

func on_creature_enters_combat(game_manager: GameManager, attacker: Card, defender: Card) -> void:
	for card in _get_sheltered_cards():
		if card != null and card.has_method("on_creature_enters_combat") and not card.abilities_suppressed():
			card.on_creature_enters_combat(game_manager, attacker, defender)

func on_creature_after_combat(game_manager: GameManager, attacker: Card, defender: Card) -> void:
	for card in _get_sheltered_cards():
		if card != null and card.has_method("on_creature_after_combat") and not card.abilities_suppressed():
			card.on_creature_after_combat(game_manager, attacker, defender)

func _release_expired_cards(game_manager: GameManager) -> void:
	if game_manager == null or card_owner == null:
		return

	var to_release: Array[Card] = []
	for card in _get_sheltered_cards():
		if card == null:
			to_release.append(card)
			continue
		var shelter_turn: int = int(_sheltered_release_turns.get(card.uid, -1))
		if game_manager.turn_number > shelter_turn:
			to_release.append(card)

	for card in to_release:
		sheltered_cards.erase(card)
		if card == null:
			continue
		var dest: String = str(_sheltered_destinations.get(card.uid, "graveyard"))
		_sheltered_release_turns.erase(card.uid)
		_sheltered_destinations.erase(card.uid)

		if dest == "abyss":
			card_owner.move_card(card, card_owner.abyss_zone)
		else:
			card_owner.move_card(card, card_owner.graveyard_zone)

		game_manager.note_player_feedback(
			"Kurnugia releases %s — it passes on to %s." % [
				card.card_name, "the Abyss" if dest == "abyss" else "the graveyard"
			]
		)

	_emit_visual_state_changed()

func _get_sheltered_cards() -> Array[Card]:
	var live_cards: Array[Card] = []
	var compacted: Array[Card] = []
	for card in sheltered_cards:
		if card == null:
			continue
		compacted.append(card)
		live_cards.append(card)
	sheltered_cards = compacted
	return live_cards

func _is_qualifying_card(card: Card) -> bool:
	if card == null or card.card_type != Card.CardType.CREATURE:
		return false
	return _is_ancient_human(card) or _is_mer(card)

func _is_ancient_human(card: Card) -> bool:
	return card != null \
		and card.has_type("Human") \
		and card.culture == "Ancient"

func _is_mer(card: Card) -> bool:
	return card != null and card.has_type("Mer")
