extends PowerCard
class_name Breidablik

const UNLOCK_COST := 3
const HARBOR_MANA_COST := 1
const RETURN_MANA_COST := 1
const FOLLOWERS_PER_LEVEL := 2

var stored_priests: Array[Card] = []
var stored_priest_origins: Dictionary = {}
var return_window_open: bool = false
var return_used_turn_number: int = -1

func _init() -> void:
	super._init()
	card_name = "Breidablik"
	culture = "Norse"
	mana_cost = UNLOCK_COST
	level = 0
	card_types = ["Power", "Runic Worship"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	targets = true
	ability_text = "Peaceful Runes: Pay %d mana to [b]Harbor[/b] a friendly Priest that hasn't attacked this turn.\nEnd of turn: gain followers equal to %dx the level of the harbored Priests.\n[b]Upkeep[/b]: Pay %d mana to return a harbored Priest to the field.\nIf this card is flipped, return all harbored Priests to the field." % [HARBOR_MANA_COST, FOLLOWERS_PER_LEVEL, RETURN_MANA_COST]
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/powers/breidablik.jpg"

func can_activate(game_manager: GameManager) -> bool:
	if is_face_down or is_muted or is_activation_locked(game_manager) or card_owner != game_manager.current_player:
		return false
	return can_harbor_priest(game_manager) or can_return_priest(game_manager)

func can_harbor_priest(game_manager: GameManager) -> bool:
	return game_manager != null \
		and card_owner != null \
		and card_owner.mana >= get_activation_mana_cost(HARBOR_MANA_COST, game_manager) \
		and not get_valid_field_priests(game_manager).is_empty()

func get_valid_field_priests(_game_manager: GameManager) -> Array[Card]:
	var valid_priests: Array[Card] = []
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if _can_store_priest(card):
				valid_priests.append(card)
	return valid_priests

func get_valid_field_priest_by_uid(priest_uid: String) -> Card:
	var cleaned_uid := str(priest_uid).strip_edges()
	if cleaned_uid == "":
		return null
	for priest in get_valid_field_priests(null):
		if priest != null and str(priest.uid).strip_edges() == cleaned_uid:
			return priest
	return null

func resolve_harbor_target(target: Card) -> Card:
	if target == null:
		return null
	if _can_store_priest(target):
		return target
	return get_valid_field_priest_by_uid(target.uid)

func get_stored_priests() -> Array[Card]:
	var copy: Array[Card] = []
	for priest in stored_priests:
		if priest != null:
			if priest.card_owner == null:
				priest.card_owner = card_owner
			copy.append(priest)
	return copy

func get_hover_stored_cards(_viewer: Player = null) -> Array[Card]:
	return get_stored_priests()

func get_hover_stored_cards_title(_viewer: Player = null) -> String:
	return "Harbored Priests"

func get_serialized_state() -> Dictionary:
	var state := super.get_serialized_state()
	var stored_entries: Array[Dictionary] = []
	for priest in stored_priests:
		if priest == null:
			continue
		stored_entries.append({
			"card": GameState.serialize_embedded_card(priest),
			"origin": stored_priest_origins.get(priest, {}).duplicate(true),
		})
	state["stored_priests"] = stored_entries
	state["return_window_open"] = return_window_open
	state["return_used_turn_number"] = return_used_turn_number
	return state

func apply_serialized_state(state: Dictionary) -> void:
	super.apply_serialized_state(state)
	stored_priests.clear()
	stored_priest_origins.clear()
	return_window_open = bool(state.get("return_window_open", false))
	return_used_turn_number = int(state.get("return_used_turn_number", -1))
	for entry_value in state.get("stored_priests", []):
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		var priest_data = entry.get("card", {})
		if not (priest_data is Dictionary):
			continue
		var priest := GameState.deserialize_embedded_card(priest_data as Dictionary)
		if priest == null:
			continue
		priest.card_owner = card_owner
		priest.current_zone = null
		stored_priests.append(priest)
		stored_priest_origins[priest] = (entry.get("origin", {}) as Dictionary).duplicate(true)

func can_return_priest(game_manager: GameManager) -> bool:
	return return_window_open \
		and game_manager != null \
		and game_manager.has_resolved_turn_upkeep() \
		and return_used_turn_number != game_manager.turn_number \
		and game_manager.current_player == card_owner \
		and card_owner.mana >= get_activation_mana_cost(RETURN_MANA_COST, game_manager) \
		and not stored_priests.is_empty() \
		and not _get_open_field_zones().is_empty()

func get_activation_cost_hover_data(game_manager: GameManager = null) -> Dictionary:
	if can_return_priest(game_manager):
		return {
			"base_cost": RETURN_MANA_COST,
			"cost_kind": Card.COST_KIND_POWER_ACTIVATION,
			"label": "Return Cost",
		}
	if can_harbor_priest(game_manager):
		return {
			"base_cost": HARBOR_MANA_COST,
			"cost_kind": Card.COST_KIND_POWER_ACTIVATION,
			"label": "Harbor Cost",
		}
	return {}

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_harbor_priest(game_manager):
		return
	var resolved_target := resolve_harbor_target(target)
	if resolved_target == null:
		print(card_name + ": Invalid Priest target.")
		return
	if not spend_activation_mana(HARBOR_MANA_COST, game_manager):
		return
	_store_priest(resolved_target)
	print(card_name + ": " + resolved_target.card_name + " was placed under this card.")

func return_priest(game_manager: GameManager, priest: Card) -> bool:
	if not can_return_priest(game_manager):
		return false
	var stored_priest := _resolve_stored_priest_reference(priest)
	if stored_priest == null:
		return false
	var zone: Zone = _get_best_return_zone(stored_priest)
	if zone == null:
		return false
	if not spend_activation_mana(RETURN_MANA_COST, game_manager):
		return false
	stored_priests.erase(stored_priest)
	stored_priest_origins.erase(stored_priest)
	zone.add_card(stored_priest)
	stored_priest.is_face_down = false
	stored_priest.is_stealth = false
	stored_priest.wake_up()
	stored_priest.reset_creature_action_state()
	stored_priest.summoned_this_turn = false
	return_window_open = false
	return_used_turn_number = game_manager.turn_number
	_emit_visual_state_changed()
	return true

func get_stored_priest_index(priest: Card) -> int:
	if priest == null:
		return -1
	for index in range(stored_priests.size()):
		var stored_priest := stored_priests[index]
		if stored_priest == priest or (stored_priest != null and stored_priest.uid == priest.uid):
			return index
	return -1

func get_stored_priest_by_uid_or_index(priest_uid: String, priest_index: int = -1) -> Card:
	var cleaned_uid := priest_uid.strip_edges()
	if cleaned_uid != "":
		for stored_priest in stored_priests:
			if stored_priest != null and stored_priest.uid == cleaned_uid:
				return stored_priest
	if priest_index >= 0 and priest_index < stored_priests.size():
		return stored_priests[priest_index]
	return null

func on_turn_upkeep(_game_manager: GameManager) -> void:
	return_window_open = not stored_priests.is_empty()

func on_turn_end(_game_manager: GameManager) -> void:
	var was_effectively_active := not is_face_down and not abilities_suppressed()
	super.on_turn_end(_game_manager)
	return_window_open = false
	if not was_effectively_active:
		return
	if stored_priests.is_empty():
		return
	var total_levels: int = 0
	for priest in stored_priests:
		if priest != null:
			total_levels += priest.get_effective_level()
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
	_emit_visual_state_changed()

func _return_all_stored_priests() -> void:
	if stored_priests.is_empty():
		return
	var unresolved: Array[Card] = []
	for priest in stored_priests:
		if priest == null:
			continue
		var zone: Zone = _get_best_return_zone(priest)
		if zone == null:
			unresolved.append(priest)
			continue
		stored_priest_origins.erase(priest)
		zone.add_card(priest)
		priest.is_face_down = false
		priest.is_stealth = false
		priest.wake_up()
		priest.reset_creature_action_state()
		priest.summoned_this_turn = false
	stored_priests = unresolved
	return_window_open = false
	_emit_visual_state_changed()

func _resolve_stored_priest_reference(priest: Card) -> Card:
	if priest == null:
		return null
	if priest in stored_priests:
		return priest
	for stored_priest in stored_priests:
		if stored_priest != null and stored_priest.uid == priest.uid:
			return stored_priest
	return null

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
	indices.sort_custom(_compare_nearest_power_index)
	return indices

func _compare_nearest_power_index(a: int, b: int) -> bool:
	var distance_a := a + 1
	var distance_b := b + 1
	if distance_a == distance_b:
		return a < b
	return distance_a < distance_b
