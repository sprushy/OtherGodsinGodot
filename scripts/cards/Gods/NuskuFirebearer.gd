extends GodCard
class_name NuskuFirebearer

const ACTIVATION_COST := 4
const MILL_COUNT := 7
const ART_PATH := "res://scripts/cards/Charms/NuskuEdit2.png"

func _init() -> void:
	super._init()
	card_name = "Nusku, Firebearer"
	card_types = ["Fire", "Wisdom", "Artisan", "Patron"]
	mana_cost = 0
	culture = "Ancient"
	targets = false
	flavor_text = ""
	ability_text = "Well of Fire (%d mana, [b]Activate[/b]): [b]Mill[/b] 7 cards; if there are Ancient Charms or Spells among them, your opponent chooses one and adds it to your hand." % ACTIVATION_COST
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	name_at_bottom = true
	paragon_of_champions = "Fire, Wisdom"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if is_muted:
		return false
	if card_owner != game_manager.current_player:
		return false
	if card_owner == null or card_owner.mana < ACTIVATION_COST:
		return false
	return card_owner.deck_zone != null and not card_owner.deck_zone.cards.is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if is_muted:
		return card_name + " is muted."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if card_owner == null or card_owner.mana < ACTIVATION_COST:
		return card_name + " needs " + str(ACTIVATION_COST) + " mana."
	if card_owner.deck_zone == null or card_owner.deck_zone.cards.is_empty():
		return "Well of Fire needs cards in your deck to mill."
	return ""

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	if not card_owner.spend_mana(ACTIVATION_COST):
		game_manager.note_player_feedback(card_name + " needs " + str(ACTIVATION_COST) + " mana.")
		return

	var milled_cards := _mill_cards()
	var eligible_choices := get_eligible_well_of_fire_choices(milled_cards)

	if not eligible_choices.is_empty() and game_manager != null:
		var host: Node = game_manager.get_interaction_host() as Node
		if host != null and is_instance_valid(host) and host.has_method("_show_nusku_well_of_fire_prompt"):
			host.call("_show_nusku_well_of_fire_prompt", self, eligible_choices, milled_cards.size())
			return

	_complete_well_of_fire(game_manager, choose_opponent_pick(eligible_choices), milled_cards.size())

func _complete_well_of_fire(game_manager: GameManager, chosen_card: Card, mill_count: int) -> void:
	var feedback := "Well of Fire milled %d card(s)." % mill_count
	if chosen_card != null:
		card_owner.move_card(chosen_card, card_owner.hand_zone)
		var opp: Player = game_manager.get_opponent(card_owner) if game_manager != null else null
		feedback += " %s chose %s to return to %s's hand." % [
			opp.player_name if opp != null else "Opponent",
			chosen_card.card_name,
			card_owner.player_name,
		]
	else:
		feedback += " No Ancient Charm or Spell was milled."
	if game_manager != null:
		game_manager.note_player_feedback(feedback)
		notify_power_activated(game_manager, chosen_card)

func get_eligible_well_of_fire_choices(milled_cards: Array[Card]) -> Array[Card]:
	var eligible: Array[Card] = []
	for card in milled_cards:
		if _is_eligible_well_of_fire_card(card):
			eligible.append(card)
	return eligible

func choose_opponent_pick(candidates: Array[Card]) -> Card:
	if candidates.is_empty():
		return null
	var chosen := candidates[0]
	for candidate in candidates:
		if _candidate_is_worse_for_controller(candidate, chosen):
			chosen = candidate
	return chosen

func _mill_cards() -> Array[Card]:
	var milled: Array[Card] = []
	if card_owner == null or card_owner.deck_zone == null or card_owner.graveyard_zone == null:
		return milled
	for _i in range(MILL_COUNT):
		if card_owner.deck_zone.cards.is_empty():
			break
		var milled_card := card_owner.deck_zone.cards[0] as Card
		card_owner.move_card(milled_card, card_owner.graveyard_zone)
		milled.append(milled_card)
	return milled

func _is_eligible_well_of_fire_card(card: Card) -> bool:
	if card == null:
		return false
	if card.current_zone != card_owner.graveyard_zone:
		return false
	if card.culture != "Ancient":
		return false
	return card.card_type == Card.CardType.CHARM or card.card_type == Card.CardType.SPELL

func _candidate_is_worse_for_controller(candidate: Card, current_choice: Card) -> bool:
	if current_choice == null:
		return true
	if candidate == null:
		return false
	if candidate.mana_cost != current_choice.mana_cost:
		return candidate.mana_cost < current_choice.mana_cost
	if candidate.level != current_choice.level:
		return candidate.level < current_choice.level
	return candidate.card_name.naturalnocasecmp_to(current_choice.card_name) < 0
