extends PowerCard
class_name RallyTheTroops

const UNLOCK_COST := 6
const LOOK_COUNT := 3
const MIN_TRIGGER_LEVEL := 5
const ART_PATH := "res://images/card_art/powers/RallyTheTroopsEdit.png"

func _init() -> void:
	super._init()
	card_name = "Rally the Troops"
	culture = "Neutral"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Aura", "Warrior", "Search"]
	ability_text = "Aura ([b]Passive[/b]): When you summon a Lvl 5 or higher Warrior from your hand, you may look at the top 3 cards of your deck and add a Warrior from among them to your hand. [b]Shelve[/b] the rest."
	artist = "Mike Caprotti"
	art_path = ART_PATH

func on_creature_summoned(
	player: Player,
	card: Card,
	from_zone: Zone,
	_to_zone: Zone,
	_summon_source: Card,
	_face_down: bool,
	_stealth: bool,
	game_manager: GameManager
) -> void:
	if not _can_trigger_rally(player, card, from_zone, game_manager):
		return

	var revealed_cards := get_rally_cards()
	if revealed_cards.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("%s triggered, but there were no cards to inspect." % card_name)
		return

	var valid_targets := get_valid_rally_targets(game_manager)
	if game_manager != null and card_owner != null:
		var reveal_uids: Array[String] = []
		for revealed in revealed_cards:
			if revealed != null:
				reveal_uids.append(revealed.uid)
		var target_uids: Array[String] = []
		for target in valid_targets:
			if target != null:
				target_uids.append(target.uid)
		game_manager.decision_requested.emit(card_owner, "rally_the_troops", {
			"source_uid": uid,
			"summoned_uid": card.uid,
			"reveal_uids": reveal_uids,
			"target_uids": target_uids,
			"queue_with_priority": true,
			"event_name": "rally_the_troops",
		})
		return

	if game_manager != null:
		game_manager.note_player_feedback(resolve_rally_choice(game_manager, null, card))

func get_rally_cards() -> Array[Card]:
	var cards: Array[Card] = []
	if card_owner == null or card_owner.deck_zone == null:
		return cards
	var limit := mini(LOOK_COUNT, card_owner.deck_zone.cards.size())
	for i in range(limit):
		var card := card_owner.deck_zone.cards[i] as Card
		if card != null:
			cards.append(card)
	return cards

func get_valid_rally_targets(_game_manager: GameManager = null) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.deck_zone == null:
		return valid_targets
	for card in get_rally_cards():
		if _is_valid_rally_target(card, controller):
			valid_targets.append(card)
	return valid_targets

func get_rally_reveal_summary(viewer: Player = null) -> String:
	var revealed_names: Array[String] = []
	for card in get_rally_cards():
		revealed_names.append(card.get_target_log_display_name(viewer))
	if revealed_names.is_empty():
		return "no cards"
	return ", ".join(revealed_names)

func resolve_rally_choice(game_manager: GameManager, chosen_card: Card = null, summoned_card: Card = null) -> String:
	var controller := get_controller()
	if controller == null or controller.deck_zone == null:
		return card_name + " has no deck to rally from."

	var top_cards := get_rally_cards()
	if top_cards.is_empty():
		return "%s found no cards to inspect." % card_name

	var valid_targets := get_valid_rally_targets(game_manager)
	var viewer := game_manager.get_feedback_viewer() if game_manager != null else null
	var revealed_names: Array[String] = []
	for card in top_cards:
		revealed_names.append(card.get_target_log_display_name(viewer))
	var reveal_summary := ", ".join(revealed_names) if not revealed_names.is_empty() else "no cards"
	var recruited_card: Card = chosen_card if chosen_card != null and chosen_card in valid_targets else null
	var shelved_cards: Array[Card] = []
	for card in top_cards:
		if card == recruited_card:
			controller.move_card(card, controller.hand_zone)
			card.card_owner = controller
			continue
		if card.current_zone == controller.deck_zone:
			controller.deck_zone.cards.erase(card)
			controller.deck_zone.cards.append(card)
		shelved_cards.append(card)

	var summon_text := ""
	if summoned_card != null:
		summon_text = " after %s was summoned" % summoned_card.get_target_log_display_name(viewer)

	if recruited_card == null:
		var shelved_only_names: Array[String] = []
		for card in shelved_cards:
			shelved_only_names.append(card.get_target_log_display_name(viewer))
		return "%s revealed %s%s and shelved them all." % [
			card_name,
			reveal_summary,
			summon_text
		]

	var recruited_name := recruited_card.get_target_log_display_name(viewer)
	if shelved_cards.is_empty():
		return "%s revealed %s%s and added %s to %s's hand." % [
			card_name,
			reveal_summary,
			summon_text,
			recruited_name,
			controller.player_name
		]

	var shelved_names: Array[String] = []
	for card in shelved_cards:
		shelved_names.append(card.get_target_log_display_name(viewer))
	return "%s revealed %s%s and added %s to %s's hand, shelving %s." % [
		card_name,
		reveal_summary,
		summon_text,
		recruited_name,
		controller.player_name,
		", ".join(shelved_names)
	]

func _can_trigger_rally(player: Player, card: Card, from_zone: Zone, game_manager: GameManager) -> bool:
	return is_effectively_active() \
		and game_manager != null \
		and player != null \
		and player == card_owner \
		and game_manager.current_player == card_owner \
		and card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.level >= MIN_TRIGGER_LEVEL \
		and card.has_type("Warrior") \
		and from_zone == card_owner.hand_zone

func _is_valid_rally_target(card: Card, controller: Player) -> bool:
	return card != null \
		and controller != null \
		and card.current_zone == controller.deck_zone \
		and card.has_type("Warrior")
