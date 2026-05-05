extends ActiveGodCard
class_name FreyjaActive

const LINKED_GOD_NAME := "Freyja"
const ART_PATH := "res://images/card_art/gods/FrejyaAndCatsAieditSquare.png"
const DOOMED_STATUS := "freyja_active_open_sessrumnir"

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Freyja, Active God"
	card_types = ["Active God", "Divine Manifestation", "God", "Targeting"]
	level = 7
	mana_cost = 11
	speed = 3
	resilience = 25
	strength = 28
	culture = "Norse"
	flavor_text = "Sessrumnir opens and the fallen march once more, but only until dawn returns."
	ability_text = "[b]Open Sessrumnir[/b] ([b]Impact[/b]): Summon a minimum of 1, up to half the Norse Warriors in your grave; they are destroyed at the start of your next turn."
	art_path = ART_PATH
	name_at_bottom = true
	artist = "Ricardo Zoppello"

func on_impact(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	var controller := get_controller()
	if controller == null:
		game_manager.note_player_feedback(resolve_open_sessrumnir_choice(game_manager))
		return
	var valid_targets := get_valid_open_sessrumnir_targets(game_manager)
	var summon_limit := get_open_sessrumnir_summon_limit(game_manager)
	if valid_targets.is_empty() or summon_limit <= 0:
		game_manager.note_player_feedback(resolve_open_sessrumnir_choice(game_manager))
		return
	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(controller, "freyja_active_open_sessrumnir", {
		"source_uid": uid,
		"target_uids": target_uids,
		"summon_limit": summon_limit,
		"queue_with_priority": true,
		"event_name": "freyja_active_open_sessrumnir_impact",
	})

func on_turn_start(game_manager: GameManager) -> void:
	if game_manager == null or game_manager.current_player != card_owner:
		return
	for card in _get_due_cards(game_manager):
		if card == null or not is_instance_valid(card):
			continue
		card.remove_status_effects_from_source_card(self, DOOMED_STATUS)
		if card.current_zone == null or not card.current_zone.is_board_zone():
			continue
		game_manager.request_send_to_graveyard(card, Callable(), false, true)

func on_any_card_moved(_game_manager: GameManager, moved_card: Card, from_zone: Zone, to_zone: Zone) -> void:
	if moved_card == null or not _has_status_from_source(moved_card, DOOMED_STATUS):
		return
	if from_zone == null or not from_zone.is_board_zone():
		return
	if to_zone != null and to_zone.is_board_zone():
		return
	moved_card.remove_status_effects_from_source_card(self, DOOMED_STATUS)

func _get_valid_graveyard_targets() -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null or card_owner.graveyard_zone == null:
		return valid_targets
	for card in card_owner.graveyard_zone.cards:
		if _is_valid_target(card):
			valid_targets.append(card)
	return valid_targets

func get_valid_open_sessrumnir_targets(_game_manager: GameManager = null) -> Array[Card]:
	return _get_valid_graveyard_targets()

func get_open_sessrumnir_summon_limit(_game_manager: GameManager = null) -> int:
	var valid_targets := _get_valid_graveyard_targets()
	if valid_targets.is_empty():
		return 0
	var desired_count := maxi(1, int(floor(float(valid_targets.size()) / 2.0)))
	return mini(_get_open_summon_zone_count(), mini(valid_targets.size(), desired_count))

func get_selected_open_sessrumnir_targets(game_manager: GameManager, target_data) -> Array[Card]:
	var selected: Array[Card] = []
	var raw_choices: Array = []
	if target_data is Array:
		raw_choices = target_data
	elif target_data is Dictionary:
		raw_choices = target_data.get("target_uids", [])
	var valid_targets := get_valid_open_sessrumnir_targets(game_manager)
	for entry in raw_choices:
		var card: Card = null
		if entry is Card:
			card = entry as Card
		elif game_manager != null:
			card = game_manager.get_card_by_uid(str(entry))
		if card == null or card in selected or card not in valid_targets:
			continue
		selected.append(card)
	return selected

func is_valid_open_sessrumnir_selection(game_manager: GameManager, chosen_targets: Array[Card]) -> bool:
	var summon_limit := get_open_sessrumnir_summon_limit(game_manager)
	if chosen_targets.size() > summon_limit:
		return false
	var valid_targets := get_valid_open_sessrumnir_targets(game_manager)
	var seen: Dictionary = {}
	for target in chosen_targets:
		if target == null or target not in valid_targets:
			return false
		if seen.has(target.uid):
			return false
		seen[target.uid] = true
	return true

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var option: Dictionary = command.get("option", {})
	var skip_choice := bool(option.get("skip", command.get("skip", false)))
	var chosen_targets := get_selected_open_sessrumnir_targets(game_manager, option if not option.is_empty() else command)
	game_manager.note_player_feedback(resolve_open_sessrumnir_choice(game_manager, chosen_targets, not skip_choice))

func resolve_open_sessrumnir_choice(
		game_manager: GameManager,
		chosen_targets: Array[Card] = [],
		auto_select_if_empty: bool = true
) -> String:
	if game_manager == null:
		return card_name + " cannot open Sessrumnir right now."
	if card_owner == null or card_owner.graveyard_zone == null:
		return card_name + " has no graveyard to call from."
	var valid_targets := get_valid_open_sessrumnir_targets(game_manager)
	if valid_targets.is_empty():
		return "%s finds no Norse Warriors to call from the graveyard." % card_name
	var summon_limit := get_open_sessrumnir_summon_limit(game_manager)
	if summon_limit <= 0:
		return "%s needs open summon lanes to call the slain." % card_name

	var resolved_targets := chosen_targets.duplicate()
	if resolved_targets.is_empty():
		if auto_select_if_empty:
			for i in range(mini(summon_limit, valid_targets.size())):
				resolved_targets.append(valid_targets[i])
	elif not is_valid_open_sessrumnir_selection(game_manager, resolved_targets):
		return "%s needs a valid Open Sessrumnir selection." % card_name

	if resolved_targets.is_empty():
		return "%s chooses no targets for Open Sessrumnir." % card_name

	var summoned_names: Array[String] = []
	for target in resolved_targets:
		if target == null or target.current_zone != card_owner.graveyard_zone:
			continue
		var summon_zone := _get_best_summon_zone(target)
		if summon_zone == null:
			continue
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
			continue
		_mark_for_next_turn_destruction(target, game_manager)
		summoned_names.append(target.card_name)

	if summoned_names.is_empty():
		return "%s could not summon any chosen Norse Warriors." % card_name
	return "%s summons %s from the graveyard. They will be destroyed at the start of your next turn." % [
		card_name,
		", ".join(summoned_names)
	]

func _is_valid_target(target: Card) -> bool:
	return target != null \
		and target.current_zone == card_owner.graveyard_zone \
		and target.card_type == Card.CardType.CREATURE \
		and not target.is_god \
		and target.has_type("Warrior") \
		and (target.has_type("Norse Creature") or target.culture == "Norse") \
		and _get_best_summon_zone(target) != null

func _mark_for_next_turn_destruction(creature: Card, game_manager: GameManager) -> void:
	if creature == null or game_manager == null:
		return
	creature.remove_status_effects_from_source_card(self, DOOMED_STATUS)
	creature.add_status_effect(
		DOOMED_STATUS,
		card_name,
		self,
		card_owner,
		{"return_turn_number": game_manager.turn_number}
	)

func _get_due_cards(game_manager: GameManager) -> Array[Card]:
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

func _get_open_summon_zone_count() -> int:
	return _count_open_zones(card_owner.frontline_zones) + _count_open_zones(card_owner.reserve_zones)

func _count_open_zones(zones: Array[Zone]) -> int:
	var count := 0
	for zone in zones:
		if zone != null and zone.cards.is_empty():
			count += 1
	return count

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

func _get_all_zones_for_player(player: Player) -> Array[Zone]:
	if player == null:
		return []
	return [player.hand_zone, player.deck_zone, player.graveyard_zone, player.abyss_zone, player.god_zone] \
		+ player.power_zones \
		+ player.frontline_zones \
		+ player.reserve_zones
