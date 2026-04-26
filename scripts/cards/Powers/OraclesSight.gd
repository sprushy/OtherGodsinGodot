extends PowerCard
class_name OraclesSight

const UNLOCK_COST := 3
const ACTIVATION_COST := 3
const LOOK_COUNT := 5
const ART_PATH := "res://images/card_art/powers/OraclesSightEdit.png"

func _init() -> void:
	super._init()
	card_name = "Oracle's Sight"
	culture = "Neutral"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Foresight"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	targets = true
	ability_text = "[b]Unlock[/b] (3): [b]Activate[/b] - Pay 3 mana: [b]Foresight[/b] - Look at the next 5 cards in your deck; choose one to [b]Prime[/b] and [b]Shelve[/b] the rest."
	artist = "Eliot Chan"
	art_path = ART_PATH

func can_activate(game_manager: GameManager) -> bool:
	return super.can_activate(game_manager) \
		and can_pay_activation_costs(ACTIVATION_COST, game_manager) \
		and not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if is_face_down:
		return card_name + " must be unlocked first."
	if is_muted:
		return card_name + " is muted."
	if is_activation_locked(game_manager):
		return card_name + " cannot be activated this turn."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	var activation_cost := get_activation_mana_cost(ACTIVATION_COST, game_manager)
	if card_owner == null or card_owner.mana < activation_cost:
		return card_name + " needs " + str(activation_cost) + " mana."
	if get_valid_targets(game_manager).is_empty():
		return card_name + " found no cards to read."
	return card_name + " cannot activate right now."

func get_activation_cost_hover_data(_game_manager: GameManager = null) -> Dictionary:
	return {
		"base_cost": ACTIVATION_COST,
		"cost_kind": Card.COST_KIND_POWER_ACTIVATION,
		"label": "Activation Cost",
	}

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	return get_foresight_cards()

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	if not pay_activation_costs(ACTIVATION_COST, game_manager):
		game_manager.note_player_feedback("%s needs %d mana." % [card_name, get_activation_mana_cost(ACTIVATION_COST, game_manager)])
		return
	game_manager.note_player_feedback(resolve_foresight_choice(game_manager, target))

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var chosen_uid := str(command.get("chosen_uid", command.get("target_uid", "")))
	var chosen_card: Card = game_manager.get_card_by_uid(chosen_uid) if chosen_uid != "" else null
	activate(game_manager, chosen_card)

func get_serialized_state() -> Dictionary:
	return {}

func apply_serialized_state(_state: Dictionary) -> void:
	pass

func get_foresight_cards() -> Array[Card]:
	var cards: Array[Card] = []
	if card_owner == null or card_owner.deck_zone == null:
		return cards
	var limit := mini(LOOK_COUNT, card_owner.deck_zone.cards.size())
	for i in range(limit):
		var card := card_owner.deck_zone.cards[i] as Card
		if card != null:
			cards.append(card)
	return cards

func resolve_foresight_choice(game_manager: GameManager, chosen_card: Card = null) -> String:
	var top_cards := get_foresight_cards()
	if game_manager == null or card_owner == null or top_cards.is_empty():
		return "%s found no cards to read." % card_name

	var primed_card := chosen_card if chosen_card != null and chosen_card in top_cards else top_cards[0]
	var shelved_cards: Array[Card] = []
	for card in top_cards:
		card_owner.deck_zone.cards.erase(card)
		if card == primed_card:
			continue
		shelved_cards.append(card)

	card_owner.deck_zone.cards.insert(0, primed_card)
	for card in shelved_cards:
		card_owner.deck_zone.cards.append(card)

	var primed_name := primed_card.get_target_log_display_name(game_manager.get_feedback_viewer())
	if shelved_cards.is_empty():
		return "%s used Foresight and primed %s." % [card_name, primed_name]

	var shelved_names: Array[String] = []
	for card in shelved_cards:
		shelved_names.append(card.get_target_log_display_name(game_manager.get_feedback_viewer()))
	return "%s used Foresight and primed %s while shelving %s." % [
		card_name,
		primed_name,
		", ".join(shelved_names)
	]
