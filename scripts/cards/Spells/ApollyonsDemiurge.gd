extends SpellCard
class_name ApollyonsDemiurge

const ART_PATH := "res://images/card_art/spells/apollyons_demiurge.png"
const PENDING_CHOICE_UIDS_META := "demiurge_pending_choice_uids"
const PENDING_MILL_COUNT_META := "demiurge_pending_mill_count"

func _init() -> void:
	super._init()
	card_name = "Apollyon's Demiurge"
	culture = "Olympic"
	card_types = ["Summon", "Demon", "Grave"]
	level = 2
	mana_cost = 0
	speed = 1
	is_legendary = false
	sacrifice_cost = 0
	# flavor_text = "From ruin and flame, the demon rises."
	flavor_text = ""
	art_path = ART_PATH
	ability_text = "Pay X mana and [b]Mill[/b] X cards; summon one Demon milled this way."

func can_cast_with_x(game_manager: GameManager, x_value: int) -> bool:
	if game_manager == null or card_owner == null:
		return false
	if x_value <= 0:
		return false
	if card_owner.mana < x_value:
		return false
	return card_owner.deck_zone.cards.size() >= x_value

func get_max_x_value() -> int:
	if card_owner == null:
		return 0
	return mini(card_owner.mana, card_owner.deck_zone.cards.size())

func pay_x_cost(game_manager: GameManager, x_value: int) -> bool:
	if not can_cast_with_x(game_manager, x_value):
		return false
	return card_owner.spend_mana(x_value)

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	var x_value: int = command.get("x_value", 0)
	# resolve_with_x pays x_cost when x_cost_already_paid=false
	var demon_choices := resolve_with_x(game_manager, x_value, false)
	var viable_choices := get_viable_milled_demon_choices(demon_choices)
	if not viable_choices.is_empty():
		_request_milled_demon_choice(game_manager, viable_choices, x_value)
		if game_manager != null:
			game_manager.note_player_feedback("Apollyon's Demiurge milled %d card(s). Choose a Demon to summon." % x_value)
		return
	if game_manager != null:
		if demon_choices.is_empty():
			game_manager.note_player_feedback("Apollyon's Demiurge milled %d card(s), but no Demon was milled." % x_value)
		else:
			game_manager.note_player_feedback("Apollyon's Demiurge found no open zone to summon into.")

func resolve_with_x(game_manager: GameManager, x_value: int, x_cost_already_paid: bool = false) -> Array[Card]:
	var demon_choices: Array[Card] = []
	if game_manager == null or card_owner == null or x_value <= 0:
		print("Apollyon's Demiurge: invalid X cost.")
		return demon_choices
	if card_owner.deck_zone.cards.size() < x_value:
		print("Apollyon's Demiurge: invalid X cost.")
		return demon_choices
	if not x_cost_already_paid:
		if not pay_x_cost(game_manager, x_value):
			print("Apollyon's Demiurge: invalid X cost.")
			return demon_choices
	var milled_cards := _mill_cards(x_value)
	for card in milled_cards:
		if _is_demon(card):
			demon_choices.append(card)
	return demon_choices

func summon_milled_demon(game_manager: GameManager, demon_card: Card) -> bool:
	if demon_card == null or card_owner == null or game_manager == null:
		return false
	if demon_card.current_zone != card_owner.graveyard_zone:
		return false
	var summon_zone := _find_summon_zone()
	if summon_zone == null:
		print("Apollyon's Demiurge: no open zone to summon into.")
		return false
	if not game_manager.summon_creature_by_effect(
		card_owner,
		demon_card,
		summon_zone,
		Card.CreatureMode.AGGRESSIVE,
		false,
		false,
		self,
		false,
		false,
		false
	):
		print("Apollyon's Demiurge: could not pay summon costs for " + demon_card.card_name + ".")
		return false
	print("Apollyon's Demiurge summons " + demon_card.card_name + ".")
	return true

func get_viable_milled_demon_choices(demon_choices: Array) -> Array[Card]:
	var viable_choices: Array[Card] = []
	if _find_summon_zone() == null:
		return viable_choices
	for choice in demon_choices:
		var demon_card := choice as Card
		if demon_card != null and _is_viable_milled_demon_choice(demon_card):
			viable_choices.append(demon_card)
	return viable_choices

func is_pending_demiurge_choice_uid(chosen_uid: String) -> bool:
	var pending_choice_uids: Array = get_meta(PENDING_CHOICE_UIDS_META, [])
	return chosen_uid in pending_choice_uids

func resolve_demiurge_choice(game_manager: GameManager, chosen_uid: String) -> String:
	if game_manager == null:
		_clear_pending_demiurge_choice()
		return "Apollyon's Demiurge choice is no longer available."
	var pending_choice_uids: Array = get_meta(PENDING_CHOICE_UIDS_META, [])
	if chosen_uid == "" or chosen_uid not in pending_choice_uids:
		return "Apollyon's Demiurge choice is no longer available."
	var chosen_card := game_manager.get_card_by_uid(chosen_uid)
	if chosen_card == null or not _is_viable_milled_demon_choice(chosen_card):
		_clear_pending_demiurge_choice()
		return "Apollyon's Demiurge choice is no longer available."
	var mill_count := int(get_meta(PENDING_MILL_COUNT_META, 0))
	return _complete_demiurge_choice(game_manager, chosen_card, mill_count)

func _mill_cards(amount: int) -> Array[Card]:
	var milled: Array[Card] = []
	for i in range(amount):
		if card_owner.deck_zone.cards.is_empty():
			break
		var milled_card := card_owner.deck_zone.cards[0]
		card_owner.move_card(milled_card, card_owner.graveyard_zone)
		milled.append(milled_card)
		print("Milled: " + milled_card.card_name)
	return milled

func _is_demon(card: Card) -> bool:
	return card != null and card.card_type == Card.CardType.CREATURE and card.has_type("Demon")

func _is_viable_milled_demon_choice(card: Card) -> bool:
	return _is_demon(card) and card_owner != null and card.current_zone == card_owner.graveyard_zone

func _request_milled_demon_choice(game_manager: GameManager, demon_choices: Array[Card], mill_count: int) -> void:
	if game_manager == null:
		return
	var choice_uids: Array[String] = []
	for demon_card in demon_choices:
		if demon_card != null:
			choice_uids.append(demon_card.uid)
	set_meta(PENDING_CHOICE_UIDS_META, choice_uids)
	set_meta(PENDING_MILL_COUNT_META, mill_count)
	var prompt_player := get_controller()
	if prompt_player == null:
		prompt_player = card_owner
	if prompt_player == null:
		return
	game_manager.decision_requested.emit(prompt_player, "apollyons_demiurge", {
		"source_uid": uid,
		"target_uids": choice_uids,
		"mill_count": mill_count,
	})

func _complete_demiurge_choice(game_manager: GameManager, demon_card: Card, mill_count: int) -> String:
	_clear_pending_demiurge_choice()
	var summoned := summon_milled_demon(game_manager, demon_card)
	if summoned:
		return "Apollyon's Demiurge milled %d card(s) and summoned %s." % [mill_count, demon_card.card_name]
	return "Apollyon's Demiurge found no open zone to summon into."

func _clear_pending_demiurge_choice() -> void:
	remove_meta(PENDING_CHOICE_UIDS_META)
	remove_meta(PENDING_MILL_COUNT_META)

func _find_summon_zone() -> Zone:
	for zone in card_owner.frontline_zones:
		if zone.cards.is_empty():
			return zone
	for zone in card_owner.reserve_zones:
		if zone.cards.is_empty():
			return zone
	return null
