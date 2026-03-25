extends PowerCard
class_name Breidablik

const UNLOCK_COST := 3
const RETURN_MANA_COST := 1
const FOLLOWERS_PER_LEVEL := 3

var stored_priests: Array[Card] = []
var stored_priest_origins: Dictionary = {}
var return_window_open: bool = false

func _init() -> void:
	super._init()
	card_name = "Breidablik"
	culture = "Norse"
	mana_cost = UNLOCK_COST
	level = 3
	card_types = ["Power", "Runic Worship"]
	ability_text = "Peaceful Runes: You may place a friendly Priest that attacked this turn under this card. End of turn: gain followers equal to 3 times the total level of Priests under it. [b]Upkeep[/b]: You may pay 1 mana to return a Priest to the field. If this card is flipped, return all cards under it to the field."
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/powers/breidablik.jpg"

func can_activate(game_manager: GameManager) -> bool:
	if is_face_down or is_muted or is_activation_locked(game_manager) or card_owner != game_manager.current_player:
		return false
	return not get_valid_field_priests(game_manager).is_empty() or can_return_priest(game_manager)

func get_valid_field_priests(_game_manager: GameManager) -> Array[Card]:
	var valid_priests: Array[Card] = []
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if _can_store_priest(card):
				valid_priests.append(card)
	return valid_priests

func get_stored_priests() -> Array[Card]:
	var copy: Array[Card] = []
	for priest in stored_priests:
		copy.append(priest)
	return copy

func can_return_priest(game_manager: GameManager) -> bool:
	return return_window_open \
		and game_manager != null \
		and game_manager.current_player == card_owner \
		and card_owner.mana >= RETURN_MANA_COST \
		and not stored_priests.is_empty() \
		and not _get_open_field_zones().is_empty()

func activate(game_manager: GameManager, target: Card = null) -> void:
	if target == null or target not in get_valid_field_priests(game_manager):
		print(card_name + ": Invalid Priest target.")
		return
	_store_priest(target)
	print(card_name + ": " + target.card_name + " was placed under this card.")

func return_priest(game_manager: GameManager, priest: Card) -> bool:
	if not can_return_priest(game_manager):
		return false
	if priest == null or priest not in stored_priests:
		return false
	var zone: Zone = _get_best_return_zone(priest)
	if zone == null:
		return false
	if not card_owner.spend_mana(RETURN_MANA_COST):
		return false
	stored_priests.erase(priest)
	stored_priest_origins.erase(priest)
	zone.add_card(priest)
	priest.is_face_down = false
	priest.is_stealth = false
	priest.wake_up()
	priest.reset_creature_action_state()
	priest.summoned_this_turn = false
	return_window_open = false
	return true

func on_turn_start(_game_manager: GameManager) -> void:
	return_window_open = not stored_priests.is_empty()

func on_turn_end(_game_manager: GameManager) -> void:
	super.on_turn_end(_game_manager)
	return_window_open = false
	if stored_priests.is_empty():
		return
	var total_levels: int = 0
	for priest in stored_priests:
		if priest != null:
			total_levels += priest.level
	if total_levels > 0:
		card_owner.gain_followers(total_levels * FOLLOWERS_PER_LEVEL)

func relock() -> void:
	super.relock()
	_return_all_stored_priests()

func close_turn_start_window() -> void:
	return_window_open = false

func _can_store_priest(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.has_type("Priest") \
		and card.get_controller() == card_owner \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and not card.has_attacked_this_turn

func _store_priest(priest: Card) -> void:
	if priest == null or priest.current_zone == null:
		return
	stored_priest_origins[priest] = {
		"zone_type": priest.current_zone.zone_type,
		"zone_index": priest.current_zone.zone_index,
	}
	for equipment_card in priest.equipment.duplicate():
		equipment_card.unequip()
	priest.current_zone.remove_card(priest)
	stored_priests.append(priest)

func _return_all_stored_priests() -> void:
	if stored_priests.is_empty():
		return
	var remaining: Array[Card] = []
	for priest in stored_priests:
		remaining.append(priest)
	stored_priests.clear()
	for priest in remaining:
		if priest == null:
			continue
		var zone: Zone = _get_best_return_zone(priest)
		if zone == null:
			stored_priest_origins.erase(priest)
			card_owner.hand_zone.add_card(priest)
			continue
		stored_priest_origins.erase(priest)
		zone.add_card(priest)
		priest.is_face_down = false
		priest.is_stealth = false
		priest.wake_up()
		priest.reset_creature_action_state()
		priest.summoned_this_turn = false
	return_window_open = false

func _get_open_field_zones() -> Array[Zone]:
	var open_zones: Array[Zone] = []
	for zone in card_owner.frontline_zones:
		if zone.cards.is_empty():
			open_zones.append(zone)
	for zone in card_owner.reserve_zones:
		if zone.cards.is_empty():
			open_zones.append(zone)
	return open_zones

func _get_best_return_zone(priest: Card) -> Zone:
	for zone in _get_return_zone_preferences(priest):
		if zone != null and zone.cards.is_empty():
			return zone
	return null

func _get_return_zone_preferences(priest: Card) -> Array[Zone]:
	var preferred: Array[Zone] = []
	var origin: Dictionary = stored_priest_origins.get(priest, {})
	var origin_type: int = int(origin.get("zone_type", -1))

	if origin_type == Zone.ZoneType.FRONTLINE:
		_append_power_ordered_zones(preferred, card_owner.frontline_zones)
		_append_power_ordered_zones(preferred, card_owner.reserve_zones)
	elif origin_type == Zone.ZoneType.RESERVE:
		_append_power_ordered_zones(preferred, card_owner.reserve_zones)
		_append_power_ordered_zones(preferred, card_owner.frontline_zones)
	else:
		_append_power_ordered_zones(preferred, card_owner.frontline_zones)
		_append_power_ordered_zones(preferred, card_owner.reserve_zones)

	return preferred

func _append_power_ordered_zones(target: Array[Zone], source: Array[Zone]) -> void:
	for zone_index in _get_indices_nearest_power(source.size()):
		if zone_index < 0 or zone_index >= source.size():
			continue
		var zone: Zone = source[zone_index]
		if zone not in target:
			target.append(zone)

func _get_indices_nearest_power(count: int) -> Array[int]:
	var indices: Array[int] = []
	for index in range(count):
		indices.append(index)
	# Power slots render to the left of the board lanes, so lower indexes are closest.
	indices.sort_custom(func(a: int, b: int) -> bool:
		var distance_a := a + 1
		var distance_b := b + 1
		if distance_a == distance_b:
			return a < b
		return distance_a < distance_b
	)
	return indices
