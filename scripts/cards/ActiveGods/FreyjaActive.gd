extends ActiveGodCard
class_name FreyjaActive

const LINKED_GOD_NAME := "Freyja"
const ART_PATH := "res://images/card_art/gods/FrejyaAndCatsAieditSquare.png"
const DOOMED_STATUS := "freyja_active_open_sessrumnir"

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Freyja, Active God"
	card_types = ["Active God", "Divine Manifestation", "God"]
	level = 7
	mana_cost = 11
	speed = 3
	resilience = 25
	strength = 28
	culture = "Norse"
	flavor_text = "Sessrumnir opens and the fallen march once more, but only until dawn returns."
	ability_text = "[b]Open Sessrumnir[/b] ([b]Impact[/b]): Summon up to half the Norse Warriors in your grave; they are destroyed at the start of your next turn."
	art_path = ART_PATH
	name_at_bottom = true
	artist = "Ricardo Zoppello"

func on_impact(game_manager: GameManager) -> void:
	if game_manager == null or card_owner == null or card_owner.graveyard_zone == null:
		return
	var valid_targets := _get_valid_graveyard_targets()
	if valid_targets.is_empty():
		game_manager.note_player_feedback("%s finds no Norse Warriors to call from the graveyard." % card_name)
		return

	var summon_limit := mini(_get_open_summon_zone_count(), int(floor(float(valid_targets.size()) / 2.0)))
	if summon_limit <= 0:
		game_manager.note_player_feedback("%s needs open summon lanes to call the slain." % card_name)
		return

	var summoned_names: Array[String] = []
	for i in range(summon_limit):
		var target := valid_targets[i]
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
		game_manager.note_player_feedback("%s could not summon any Norse Warriors." % card_name)
		return

	game_manager.note_player_feedback(
		"%s summons %s from the graveyard. They will be destroyed at the start of your next turn." % [
			card_name,
			", ".join(summoned_names)
		]
	)

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
