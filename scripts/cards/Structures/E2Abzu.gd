extends StructureCard
class_name E2Abzu

const RETURN_TO_HAND_COST := 3
const VOID_AND_RETURN_COST := 2
const VOID_RESPONSE_SPEED := 3
const ART_PATH := "res://images/card_art/structures/E2-abzu(web).jpg"

var _temporarily_voided_creatures: Array[Dictionary] = []

func _init() -> void:
	super._init()
	card_name = "E2-abzu"
	card_types = ["Temple", "Dwelling", "Targeting"]
	targets = true
	level = 2
	mana_cost = 0
	resilience = 22
	speed = 0
	strength = 0
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	name_at_bottom = true
	art_path = ART_PATH
	ability_text = "([b]Activate[/b], 3 mana): Add a Mer Mage from your [b]Void[/b] to your hand with level less than your mana count.\n([b]Activate[/b], 2 mana, [b]Spd[/b] 3): [b]Void[/b] a friendly Mer Mage from the field until end of turn."

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if is_muted or is_activation_locked(game_manager):
		return false
	if card_owner != game_manager.current_player:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or card_owner == null:
		return valid_targets

	for card in get_valid_void_targets(game_manager):
		valid_targets.append(card)
	for card in get_valid_field_targets(game_manager):
		if card not in valid_targets:
			valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if game_manager == null:
		return

	var valid_void_targets := get_valid_void_targets(game_manager)
	if target != null and target in valid_void_targets:
		if not card_owner.spend_mana(RETURN_TO_HAND_COST):
			game_manager.note_player_feedback("%s needs %d mana." % [card_name, RETURN_TO_HAND_COST])
			return
		card_owner.move_card(target, card_owner.hand_zone)
		game_manager.note_player_feedback("%s returns %s from the Void to hand." % [card_name, target.card_name])
		return

	var valid_field_targets := get_valid_field_targets(game_manager)
	if target != null and target in valid_field_targets:
		if not card_owner.spend_mana(VOID_AND_RETURN_COST):
			game_manager.note_player_feedback("%s needs %d mana." % [card_name, VOID_AND_RETURN_COST])
			return
		_store_temporary_return(target, game_manager)
		game_manager.banish_card_with_hook(target)
		game_manager.note_player_feedback("%s sends %s to the Void until end of turn." % [card_name, target.card_name])
		return

	game_manager.note_player_feedback("%s fizzles: choose a friendly Mer Mage on the field or one in your Void." % card_name)

func on_turn_end(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	_return_due_voided_creatures(game_manager)

func on_global_turn_end(game_manager: GameManager, ending_player: Player) -> void:
	if game_manager == null or ending_player == null:
		return
	_return_due_voided_creatures(game_manager, ending_player)

func on_removed(_game_manager: GameManager) -> void:
	if _temporarily_voided_creatures.is_empty():
		return

	var pending_returns := _temporarily_voided_creatures.duplicate()
	_temporarily_voided_creatures.clear()

	for entry in pending_returns:
		var creature := entry.get("creature") as Card
		if creature == null or not is_instance_valid(creature):
			continue
		if creature.current_zone != creature.card_owner.abyss_zone:
			continue

		var return_zone := _get_best_return_zone(creature, entry)
		if return_zone == null:
			creature.card_owner.move_card(creature, creature.card_owner.hand_zone)
			continue
		creature.card_owner.move_card(creature, return_zone)

func _return_due_voided_creatures(game_manager: GameManager, ending_player: Player = null) -> void:
	if _temporarily_voided_creatures.is_empty():
		return

	var resolved_ending_player := ending_player if ending_player != null else game_manager.current_player
	var remaining_entries: Array[Dictionary] = []

	for entry in _temporarily_voided_creatures:
		if int(entry.get("return_turn_number", -1)) != game_manager.turn_number:
			remaining_entries.append(entry)
			continue
		if entry.get("ending_player") != resolved_ending_player:
			remaining_entries.append(entry)
			continue
		var creature := entry.get("creature") as Card
		if creature == null or not is_instance_valid(creature):
			continue
		if creature.current_zone != creature.card_owner.abyss_zone:
			continue

		var return_zone := _get_best_return_zone(creature, entry)
		if return_zone == null:
			creature.card_owner.move_card(creature, creature.card_owner.hand_zone)
			print("%s: No open lane for %s, returned it to hand instead." % [card_name, creature.card_name])
			continue

		creature.card_owner.move_card(creature, return_zone)
		print("%s: %s returns from the Void to the field." % [card_name, creature.card_name])
	_temporarily_voided_creatures = remaining_entries

func get_valid_void_targets(_game_manager: GameManager = null) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null:
		return valid_targets
	for card in card_owner.abyss_zone.cards:
		if _can_return_void_target(card):
			valid_targets.append(card)
	return valid_targets

func get_valid_field_targets(_game_manager: GameManager = null) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null or card_owner.mana < VOID_AND_RETURN_COST:
		return valid_targets
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if _is_mer_mage(card):
				valid_targets.append(card)
	return valid_targets

func can_respond_to_priority_action(_action: CardAction, game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if is_muted or is_activation_locked(game_manager):
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if card_owner != game_manager.priority_player:
		return false
	return not get_priority_field_targets(game_manager, _action).is_empty()

func get_priority_field_targets(game_manager: GameManager, _action: CardAction = null) -> Array[Card]:
	return get_valid_field_targets(game_manager)

func get_priority_response_speed() -> int:
	return VOID_RESPONSE_SPEED

func _is_mer_mage(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.has_type("Mer") \
		and card.has_type("Mage")

func _can_return_void_target(card: Card) -> bool:
	if card_owner == null or card_owner.mana < RETURN_TO_HAND_COST:
		return false
	if not _is_mer_mage(card):
		return false
	var remaining_mana := card_owner.mana - RETURN_TO_HAND_COST
	return card.level < remaining_mana

func _store_temporary_return(creature: Card, game_manager: GameManager) -> void:
	_temporarily_voided_creatures = _temporarily_voided_creatures.filter(func(entry: Dictionary) -> bool:
		return entry.get("creature") != creature
	)
	_temporarily_voided_creatures.append({
		"creature": creature,
		"zone_type": creature.current_zone.zone_type if creature.current_zone != null else -1,
		"zone_index": creature.current_zone.zone_index if creature.current_zone != null else -1,
		"return_turn_number": game_manager.turn_number if game_manager != null else -1,
		"ending_player": game_manager.current_player if game_manager != null else null,
	})

func _get_best_return_zone(creature: Card, entry: Dictionary) -> Zone:
	var preferred_zone := _get_zone_from_entry(creature.card_owner, entry)
	if preferred_zone != null and preferred_zone.cards.is_empty():
		return preferred_zone

	var origin_type := int(entry.get("zone_type", -1))
	var primary_zones := creature.card_owner.frontline_zones if origin_type == Zone.ZoneType.FRONTLINE else creature.card_owner.reserve_zones
	var secondary_zones := creature.card_owner.reserve_zones if origin_type == Zone.ZoneType.FRONTLINE else creature.card_owner.frontline_zones

	for zone in primary_zones:
		if zone.cards.is_empty():
			return zone
	for zone in secondary_zones:
		if zone.cards.is_empty():
			return zone
	return null

func _get_zone_from_entry(player: Player, entry: Dictionary) -> Zone:
	if player == null:
		return null
	var zone_type := int(entry.get("zone_type", -1))
	var zone_index := int(entry.get("zone_index", -1))
	var zones: Array[Zone] = []
	if zone_type == Zone.ZoneType.FRONTLINE:
		zones.assign(player.frontline_zones)
	elif zone_type == Zone.ZoneType.RESERVE:
		zones.assign(player.reserve_zones)
	if zone_index < 0 or zone_index >= zones.size():
		return null
	return zones[zone_index]
