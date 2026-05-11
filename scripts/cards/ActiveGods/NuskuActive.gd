extends ActiveGodCard
class_name NuskuActive

const LINKED_GOD_NAME := "Nusku, Firebearer"
const MILL_COUNT := 7
const ART_PATH := "res://images/card_art/gods/NuskuEdit2.png"
const CORE_FLAME_INITIAL_PROMPT_PENDING_META := "core_flame_initial_prompt_pending"
const CORE_FLAME_PENDING_CHOICE_UIDS_META := "core_flame_pending_choice_uids"
const CORE_FLAME_PENDING_MILL_COUNT_META := "core_flame_pending_mill_count"

var _declined_core_flame: bool = false

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Nusku, Active God"
	card_types = ["Active God", "Divine Manifestation", "God"]
	level = 7
	mana_cost = 12
	speed = 2
	resilience = 30
	strength = 33
	culture = "Ancient"
	# flavor_text = "Nusku's fire offers revelation now or judgment later."
	flavor_text = ""
	ability_text = "Core Flame ([b]Impact[/b]): You may [b]Mill[/b] 7. Add a magical card milled this way to your hand.\nCelestial Light ([b]Fatality[/b]): If you declined Core Flame, [b]Convert[/b] followers equal to your graveyard size."
	art_path = ART_PATH
	name_at_bottom = true
	artist = "Ricardo Zoppello"

func on_summon(_game_manager: GameManager) -> void:
	_declined_core_flame = false
	_clear_pending_core_flame_initial_prompt()
	_clear_pending_core_flame_choice()

func on_impact(game_manager: GameManager) -> void:
	if game_manager == null or card_owner == null or card_owner.deck_zone == null:
		return
	var mill_count := mini(MILL_COUNT, card_owner.deck_zone.cards.size())
	if mill_count <= 0:
		game_manager.note_player_feedback(resolve_core_flame(game_manager))
		return
	var prompt_player := get_controller()
	if prompt_player == null:
		prompt_player = card_owner
	if prompt_player == null:
		game_manager.note_player_feedback(resolve_core_flame(game_manager))
		return
	set_meta(CORE_FLAME_INITIAL_PROMPT_PENDING_META, true)
	game_manager.decision_requested.emit(prompt_player, "nusku_active_core_flame", {
		"source_uid": uid,
		"mill_count": mill_count,
	})

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> String:
	if game_manager == null:
		return ""
	var decline := bool(command.get("decline", false))
	var chosen_uid := str(command.get("chosen_uid", command.get("target_uid", ""))).strip_edges()
	var feedback := ""
	if decline:
		if not _consume_pending_core_flame_initial_prompt():
			return _note_core_flame_feedback(game_manager, "Core Flame choice is no longer available.")
		_clear_pending_core_flame_choice()
		feedback = resolve_core_flame(game_manager, null, true)
	elif chosen_uid != "":
		feedback = _complete_pending_core_flame_choice(game_manager, chosen_uid)
	else:
		if not _consume_pending_core_flame_initial_prompt():
			return _note_core_flame_feedback(game_manager, "Core Flame choice is no longer available.")
		feedback = _resolve_core_flame_after_mill(game_manager)
	if feedback.strip_edges() != "":
		game_manager.note_player_feedback(feedback)
	return feedback

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

func is_pending_core_flame_choice_uid(chosen_uid: String) -> bool:
	var pending_choice_uids: Array = get_meta(CORE_FLAME_PENDING_CHOICE_UIDS_META, [])
	return chosen_uid in pending_choice_uids

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

func _resolve_core_flame_after_mill(game_manager: GameManager) -> String:
	if game_manager == null or card_owner == null or card_owner.deck_zone == null or card_owner.graveyard_zone == null:
		_clear_pending_core_flame_choice()
		return card_name + " cannot resolve Core Flame right now."
	if card_owner.deck_zone.cards.is_empty():
		_declined_core_flame = false
		_clear_pending_core_flame_choice()
		return "%s cannot mill because the deck is empty." % card_name

	var milled_cards := _mill_cards()
	var eligible_cards := _get_eligible_milled_magical_cards(milled_cards)
	_declined_core_flame = false

	if eligible_cards.size() > 1:
		_request_core_flame_milled_choice(game_manager, eligible_cards, milled_cards.size())
		return "%s milled %d card(s). Choose a magical card to add to %s's hand." % [
			card_name,
			milled_cards.size(),
			card_owner.player_name,
		]
	if eligible_cards.size() == 1:
		return _complete_core_flame_choice(game_manager, eligible_cards[0], milled_cards.size())
	return "%s milled %d card(s). No magical card was milled." % [card_name, milled_cards.size()]

func _request_core_flame_milled_choice(game_manager: GameManager, eligible_cards: Array[Card], mill_count: int) -> void:
	var choice_uids: Array[String] = []
	for card in eligible_cards:
		if card != null:
			choice_uids.append(card.uid)
	set_meta(CORE_FLAME_PENDING_CHOICE_UIDS_META, choice_uids)
	set_meta(CORE_FLAME_PENDING_MILL_COUNT_META, mill_count)
	var prompt_player := get_controller()
	if prompt_player == null:
		prompt_player = card_owner
	if prompt_player == null:
		return
	game_manager.decision_requested.emit(prompt_player, "nusku_active_core_flame", {
		"source_uid": uid,
		"target_uids": choice_uids,
		"mill_count": mill_count,
		"stage": "choose",
	})

func _complete_pending_core_flame_choice(game_manager: GameManager, chosen_uid: String) -> String:
	var pending_choice_uids: Array = get_meta(CORE_FLAME_PENDING_CHOICE_UIDS_META, [])
	if chosen_uid == "" or chosen_uid not in pending_choice_uids:
		return "Core Flame choice is no longer available."
	var chosen_card := game_manager.get_card_by_uid(chosen_uid)
	if chosen_card == null or chosen_card.current_zone != card_owner.graveyard_zone or not chosen_card.is_magical_card():
		return "Core Flame choice is no longer available."
	var mill_count := int(get_meta(CORE_FLAME_PENDING_MILL_COUNT_META, MILL_COUNT))
	return _complete_core_flame_choice(game_manager, chosen_card, mill_count)

func _complete_core_flame_choice(game_manager: GameManager, chosen_card: Card, mill_count: int) -> String:
	_clear_pending_core_flame_choice()
	_clear_pending_core_flame_initial_prompt()
	_declined_core_flame = false
	var feedback := "%s milled %d card(s)." % [card_name, mill_count]
	if chosen_card != null:
		card_owner.move_card(chosen_card, card_owner.hand_zone)
		feedback += " %s was added to %s's hand." % [
			chosen_card.get_target_log_display_name(game_manager.get_feedback_viewer()),
			card_owner.player_name
		]
	else:
		feedback += " No magical card was milled."
	return feedback

func _clear_pending_core_flame_choice() -> void:
	remove_meta(CORE_FLAME_PENDING_CHOICE_UIDS_META)
	remove_meta(CORE_FLAME_PENDING_MILL_COUNT_META)

func _consume_pending_core_flame_initial_prompt() -> bool:
	if not bool(get_meta(CORE_FLAME_INITIAL_PROMPT_PENDING_META, false)):
		return false
	_clear_pending_core_flame_initial_prompt()
	return true

func _clear_pending_core_flame_initial_prompt() -> void:
	remove_meta(CORE_FLAME_INITIAL_PROMPT_PENDING_META)

func _note_core_flame_feedback(game_manager: GameManager, feedback: String) -> String:
	if game_manager != null and feedback.strip_edges() != "":
		game_manager.note_player_feedback(feedback)
	return feedback

