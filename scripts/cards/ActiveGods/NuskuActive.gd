extends ActiveGodCard
class_name NuskuActive

const LINKED_GOD_NAME := "Nusku, Firebearer"
const MILL_COUNT := 7
const ART_PATH := "res://images/card_art/gods/NuskuEdit2.png"

var _declined_core_flame: bool = false

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Nusku, Active God"
	card_types = ["Active God", "Divine Manifestation", "God"]
	level = 12
	mana_cost = 12
	speed = 2
	resilience = 30
	strength = 33
	culture = "Ancient"
	flavor_text = "Nusku's fire offers revelation now or judgment later."
	ability_text = "Core Flame ([b]Impact[/b]): You may [b]Mill[/b] 7. Add a magical card milled this way to your hand.\nCelestial Light ([b]Fatality[/b]): If you declined Core Flame, [b]Convert[/b] followers equal to your graveyard size."
	art_path = ART_PATH
	name_at_bottom = true
	artist = "Ricardo Zoppello"

func on_summon(_game_manager: GameManager) -> void:
	_declined_core_flame = false

func on_impact(game_manager: GameManager) -> void:
	if game_manager == null or card_owner == null or card_owner.deck_zone == null:
		return
	var preview_cards := get_core_flame_preview_cards()
	if preview_cards.is_empty():
		game_manager.note_player_feedback(resolve_core_flame(game_manager))
		return
	var prompt_player := get_controller()
	if prompt_player == null:
		prompt_player = card_owner
	if prompt_player == null:
		game_manager.note_player_feedback(resolve_core_flame(game_manager))
		return
	var preview_uids: Array[String] = []
	for card in preview_cards:
		if card != null:
			preview_uids.append(card.uid)
	var recoverable_uids: Array[String] = []
	for card in get_core_flame_recoverable_cards():
		if card != null:
			recoverable_uids.append(card.uid)
	game_manager.decision_requested.emit(prompt_player, "nusku_active_core_flame", {
		"source_uid": uid,
		"preview_uids": preview_uids,
		"recoverable_uids": recoverable_uids,
		"mill_count": preview_cards.size(),
	})

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var decline := bool(command.get("decline", false))
	var chosen_uid := str(command.get("chosen_uid", command.get("target_uid", "")))
	var chosen_card: Card = game_manager.get_card_by_uid(chosen_uid) if chosen_uid != "" else null
	game_manager.note_player_feedback(resolve_core_flame(game_manager, chosen_card, decline))

func resolve_core_flame(game_manager: GameManager, chosen_card: Card = null, decline: bool = false) -> String:
	if game_manager == null or card_owner == null or card_owner.deck_zone == null or card_owner.graveyard_zone == null:
		return card_name + " cannot resolve Core Flame right now."
	if decline:
		_declined_core_flame = true
		return "%s declines Core Flame." % card_name
	if card_owner.deck_zone.cards.is_empty():
		_declined_core_flame = false
		return "%s cannot mill because the deck is empty." % card_name

	var milled_cards := _mill_cards()
	var eligible_cards := _get_eligible_milled_magical_cards(milled_cards)
	var resolved_choice := chosen_card if chosen_card != null and chosen_card in eligible_cards else null
	if resolved_choice == null and not eligible_cards.is_empty():
		resolved_choice = eligible_cards[0]

	_declined_core_flame = false

	var feedback := "%s milled %d card(s)." % [card_name, milled_cards.size()]
	if resolved_choice != null:
		card_owner.move_card(resolved_choice, card_owner.hand_zone)
		feedback += " %s was added to %s's hand." % [
			resolved_choice.get_target_log_display_name(game_manager.get_feedback_viewer()),
			card_owner.player_name
		]
	else:
		feedback += " No magical card was milled."
	return feedback

func get_core_flame_preview_cards() -> Array[Card]:
	var preview: Array[Card] = []
	if card_owner == null or card_owner.deck_zone == null:
		return preview
	var limit := mini(MILL_COUNT, card_owner.deck_zone.cards.size())
	for i in range(limit):
		var deck_card := card_owner.deck_zone.cards[i] as Card
		if deck_card != null:
			preview.append(deck_card)
	return preview

func get_core_flame_recoverable_cards() -> Array[Card]:
	var eligible: Array[Card] = []
	for card in get_core_flame_preview_cards():
		if card != null and card.is_magical_card():
			eligible.append(card)
	return eligible

func on_death(game_manager: GameManager) -> void:
	if game_manager == null or not _declined_core_flame:
		return
	var controller := get_controller()
	if controller == null:
		controller = card_owner
	var opponent := game_manager.get_opponent(controller)
	if opponent == null:
		return
	var grave_count := 0
	if controller != null and controller.graveyard_zone != null:
		grave_count = controller.graveyard_zone.cards.size()
	_declined_core_flame = false
	if grave_count <= 0:
		return
	var converted := game_manager.convert_followers(opponent, controller, grave_count)
	if converted <= 0:
		return
	game_manager.note_player_feedback("%s's Celestial Light converts %d followers." % [card_name, converted])

func _mill_cards() -> Array[Card]:
	var milled: Array[Card] = []
	for _i in range(MILL_COUNT):
		if card_owner.deck_zone.cards.is_empty():
			break
		var milled_card := card_owner.deck_zone.cards[0] as Card
		card_owner.move_card(milled_card, card_owner.graveyard_zone)
		milled.append(milled_card)
	return milled

func _get_eligible_milled_magical_cards(milled_cards: Array[Card]) -> Array[Card]:
	var eligible: Array[Card] = []
	for card in milled_cards:
		if card != null and card.current_zone == card_owner.graveyard_zone and card.is_magical_card():
			eligible.append(card)
	return eligible

