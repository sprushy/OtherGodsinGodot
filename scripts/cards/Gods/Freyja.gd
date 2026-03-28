extends GodCard
class_name Freyja

const BASE_ACTIVATION_COST := 5
const DOOMED_STATUS := "freyja_receiver_of_the_slain"
const SPIRIT_GRANT_STATUS := "freyja_spirit_grant"

func _init() -> void:
	super._init()
	card_name = "Freyja"
	card_types = ["War", "Sex", "Sorcery", "Death"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	mana_cost = 0
	culture = "Norse"
	targets = true
	flavor_text = "The slain do not always stay dead when Freyja calls them back."
	ability_text = "Receiver of the Slain ([b]Activate[/b], 5 mana): Summon a Norse Warrior from your graveyard. It gains Spirit and is destroyed at the start of your next turn. This ability costs 1 less for each Valkyrie card you have in play."
	art_path = "res://images/card_art/gods/FrejyaAndCatsAieditSquare.png"
	artist = "Ricardo Zoppello"
	name_at_bottom = true

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if is_muted:
		return false
	if card_owner != game_manager.current_player:
		return false
	if card_owner == null or card_owner.mana < get_activation_mana_cost(game_manager):
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if is_muted:
		return card_name + " is muted."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	var activation_cost := get_activation_mana_cost(game_manager)
	if card_owner == null or card_owner.mana < activation_cost:
		return card_name + " needs " + str(activation_cost) + " mana."
	if not _has_open_summon_zone():
		return "Receiver of the Slain needs an open summon lane."
	if get_valid_targets(game_manager).is_empty():
		return "Receiver of the Slain has no Norse Warriors in your graveyard."
	return ""

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null or card_owner.graveyard_zone == null:
		return valid_targets
	if not _has_open_summon_zone():
		return valid_targets
	for card in card_owner.graveyard_zone.cards:
		if is_valid_activation_target(card):
			valid_targets.append(card)
	return valid_targets

func is_valid_activation_target(target: Card) -> bool:
	return target != null \
		and card_owner != null \
		and target.current_zone == card_owner.graveyard_zone \
		and target.card_type == Card.CardType.CREATURE \
		and not target.is_god \
		and target.has_type("Warrior") \
		and (target.has_type("Norse Creature") or target.culture == "Norse") \
		and _get_best_summon_zone(target) != null

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	if not is_valid_activation_target(target):
		game_manager.note_player_feedback("Receiver of the Slain fizzles: invalid target.")
		return

	var summon_zone := _get_best_summon_zone(target)
	if summon_zone == null:
		game_manager.note_player_feedback("Receiver of the Slain fizzles: no open summon lane.")
		return

	var activation_cost := get_activation_mana_cost(game_manager)
	if not card_owner.spend_mana(activation_cost):
		game_manager.note_player_feedback(card_name + " needs " + str(activation_cost) + " mana.")
		return

	var summoned := game_manager.summon_creature_by_effect(
		card_owner,
		target,
		summon_zone,
		Card.CreatureMode.AGGRESSIVE,
		false,
		false,
		self,
		false,
		false,
		true
	)
	if not summoned:
		card_owner.gain_mana(activation_cost)
		game_manager.note_player_feedback("Receiver of the Slain fizzles: " + target.card_name + " could not be summoned.")
		return

	_apply_receiver_of_the_slain(target, game_manager)
	game_manager.note_player_feedback(
		"Receiver of the Slain summons %s from the graveyard for %d mana." % [
			target.card_name,
			activation_cost
		]
	)
	notify_power_activated(game_manager, target)

func on_turn_upkeep(game_manager: GameManager) -> void:
	if game_manager == null or game_manager.current_player != card_owner:
		return
	var due_cards := _get_due_returned_cards(game_manager)
	for card in due_cards:
		if card == null or not is_instance_valid(card):
			continue
		card.remove_status_effects_from_source_card(self, DOOMED_STATUS)
		if card.current_zone == null or not card.current_zone.is_board_zone():
			_cleanup_spirit_grant(card)
			continue
		game_manager.request_send_to_graveyard(card, Callable(), false, true)
		if card.current_zone == null or not card.current_zone.is_board_zone():
			_cleanup_spirit_grant(card)

func on_any_card_moved(_game_manager: GameManager, moved_card: Card, from_zone: Zone, to_zone: Zone) -> void:
	if moved_card == null:
		return
	if not _has_status_from_source(moved_card, SPIRIT_GRANT_STATUS) and not _has_status_from_source(moved_card, DOOMED_STATUS):
		return
	if from_zone == null or not from_zone.is_board_zone():
		return
	if to_zone != null and to_zone.is_board_zone():
		return
	moved_card.remove_status_effects_from_source_card(self, DOOMED_STATUS)
	_cleanup_spirit_grant(moved_card)

func get_activation_mana_cost(_game_manager: GameManager = null) -> int:
	return maxi(0, BASE_ACTIVATION_COST - _count_friendly_valkyries_in_play())

func _apply_receiver_of_the_slain(creature: Card, game_manager: GameManager) -> void:
	if creature == null:
		return
	creature.remove_status_effects_from_source_card(self, DOOMED_STATUS)
	creature.add_status_effect(
		DOOMED_STATUS,
		card_name,
		self,
		card_owner,
		{"return_turn_number": game_manager.turn_number}
	)
	var added_spirit := false
	if not creature.has_type("Spirit"):
		creature.card_types.append("Spirit")
		added_spirit = true
	creature.remove_status_effects_from_source_card(self, SPIRIT_GRANT_STATUS)
	creature.add_status_effect(
		SPIRIT_GRANT_STATUS,
		card_name,
		self,
		card_owner,
		{"added_type": added_spirit}
	)

func _cleanup_spirit_grant(creature: Card) -> void:
	if creature == null:
		return
	var spirit_status := _get_status_from_source(creature, SPIRIT_GRANT_STATUS)
	if not spirit_status.is_empty():
		creature.remove_status_effects_from_source_card(self, SPIRIT_GRANT_STATUS)
		if spirit_status.get("added_type", false):
			creature.card_types = creature.card_types.filter(func(type_name: String) -> bool:
				return type_name != "Spirit"
			)

func _get_due_returned_cards(game_manager: GameManager) -> Array[Card]:
	var due_cards: Array[Card] = []
	if game_manager == null:
		return due_cards
	for player in game_manager.players:
		for zone in _get_all_zones_for_player(player):
			for card in zone.cards:
				if card == null or not card.has_status_effect(DOOMED_STATUS):
					continue
				var status := _get_status_from_source(card, DOOMED_STATUS)
				if status.get("source_card", null) != self:
					continue
				if int(status.get("return_turn_number", -1)) >= 0 and int(status.get("return_turn_number", -1)) < game_manager.turn_number:
					due_cards.append(card)
	return due_cards

func _get_status_from_source(card: Card, status_name: String) -> Dictionary:
	if card == null:
		return {}
	for status in card.active_statuses:
		if status.get("name", "") != status_name:
			continue
		if status.get("source_card", null) != self:
			continue
		return status
	return {}

func _has_status_from_source(card: Card, status_name: String) -> bool:
	return not _get_status_from_source(card, status_name).is_empty()

func _count_friendly_valkyries_in_play() -> int:
	if card_owner == null:
		return 0
	var count := 0
	var zones: Array[Zone] = []
	zones.append(card_owner.god_zone)
	zones.append_array(card_owner.power_zones)
	zones.append_array(card_owner.frontline_zones)
	zones.append_array(card_owner.reserve_zones)
	for zone in zones:
		for card in zone.cards:
			if _is_valkyrie_card(card):
				count += 1
	return count

func _is_valkyrie_card(card: Card) -> bool:
	if card == null:
		return false
	if card.has_type("Valkyrie"):
		return true
	return card.card_name.to_lower().contains("valkyrie")

func _has_open_summon_zone() -> bool:
	if card_owner == null:
		return false
	return _find_first_open_zone(card_owner.frontline_zones) != null or _find_first_open_zone(card_owner.reserve_zones) != null

func _get_best_summon_zone(creature: Card) -> Zone:
	if creature == null or card_owner == null:
		return null
	var last_type: int = creature.last_board_zone_type
	var center: int = clampi(creature.last_board_zone_index, 0, Player.BOARD_LANE_COUNT - 1)
	var primary: Array[Zone] = []
	var secondary: Array[Zone] = []
	if last_type == Zone.ZoneType.RESERVE:
		primary.assign(card_owner.reserve_zones)
		secondary.assign(card_owner.frontline_zones)
	else:
		primary.assign(card_owner.frontline_zones)
		secondary.assign(card_owner.reserve_zones)

	for zone in _zones_by_distance(primary, center):
		if zone.cards.is_empty():
			return zone
	for zone in _zones_by_distance(secondary, center):
		if zone.cards.is_empty():
			return zone
	return null

func _zones_by_distance(row: Array[Zone], center: int) -> Array[Zone]:
	var result: Array[Zone] = []
	if row.is_empty():
		return result
	result.append(row[center])
	for distance in range(1, row.size()):
		var low := center - distance
		var high := center + distance
		if low >= 0:
			result.append(row[low])
		if high < row.size():
			result.append(row[high])
	return result

func _find_first_open_zone(zones: Array[Zone]) -> Zone:
	for zone in zones:
		if zone != null and zone.cards.is_empty():
			return zone
	return null

func _get_all_zones_for_player(player: Player) -> Array[Zone]:
	if player == null:
		return []
	var zones: Array[Zone] = []
	zones.append(player.hand_zone)
	zones.append(player.deck_zone)
	zones.append(player.graveyard_zone)
	zones.append(player.abyss_zone)
	zones.append(player.god_zone)
	zones.append_array(player.power_zones)
	zones.append_array(player.frontline_zones)
	zones.append_array(player.reserve_zones)
	return zones
