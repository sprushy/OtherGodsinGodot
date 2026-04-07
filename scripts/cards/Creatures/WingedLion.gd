extends CreatureCard
class_name WingedLion

const ART_PATH := "res://images/card_art/creatures/WingedLionEdit.png"

func _init() -> void:
	super._init()
	card_name = "Winged Lion"
	card_types = ["Animal", "Feline", "Aerial", "Ancient Creature", "Targeting"]
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 10
	strength = 13
	targets = true
	ability_text = "[b]Flank[/b] ([b]Activate[/b]): Once per turn, move Winged Lion and another friendly Animal to friendly slots of your choice."
	flavor_text = ""
	culture = "Ancient"
	artist = "Putra Kamajaya"
	art_path = ART_PATH

func get_activation_label() -> String:
	return "Flank"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_face_down or is_stealth or is_prepared:
		return false
	if abilities_suppressed() or is_sleeping or is_used:
		return false
	if not get_status_effect("cannot_move").is_empty():
		return false
	if game_manager.is_immune_to_source(self, self):
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if get_controller() != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if current_zone == null or not current_zone.is_board_zone():
		return card_name + " must be on the field."
	if is_face_down or is_stealth or is_prepared:
		return card_name + " must be face-up to flank."
	if abilities_suppressed():
		return card_name + " cannot use Flank right now."
	if is_sleeping:
		return card_name + " is asleep."
	if not get_status_effect("cannot_move").is_empty():
		return card_name + " cannot move right now."
	if game_manager.is_immune_to_source(self, self):
		return card_name + " is immune to creature abilities right now."
	if is_used:
		return card_name + " has already used Flank this turn."
	if get_valid_targets(game_manager).is_empty():
		return card_name + " has no other friendly Animal to flank with."
	return card_name + " cannot flank right now."

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if game_manager == null or controller == null:
		return valid_targets
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if _is_valid_partner_target(game_manager, card):
				valid_targets.append(card)
	return valid_targets

func get_valid_self_zones(game_manager: GameManager, partner: Card) -> Array[Zone]:
	var valid_zones: Array[Zone] = []
	if not _is_valid_partner_target_without_plan_check(game_manager, partner):
		return valid_zones
	for zone in _get_friendly_board_zones():
		if _zone_can_host_moved_creature(zone, self, partner):
			valid_zones.append(zone)
	return valid_zones

func get_valid_partner_zones(game_manager: GameManager, partner: Card, self_zone: Zone) -> Array[Zone]:
	var valid_zones: Array[Zone] = []
	if not _is_valid_partner_target_without_plan_check(game_manager, partner):
		return valid_zones
	if self_zone == null or self_zone not in get_valid_self_zones(game_manager, partner):
		return valid_zones
	for zone in _get_friendly_board_zones():
		if zone == self_zone:
			continue
		if self_zone == current_zone and zone == partner.current_zone:
			continue
		if _zone_can_host_moved_creature(zone, self, partner):
			valid_zones.append(zone)
	return valid_zones

func activate(game_manager: GameManager, target_data = null) -> void:
	var partner := _resolve_partner_from_activation_data(game_manager, target_data)
	var self_zone := _resolve_zone_from_activation_data(game_manager, target_data, "self_zone")
	var partner_zone := _resolve_zone_from_activation_data(game_manager, target_data, "partner_zone")

	if partner != null and (self_zone == null or partner_zone == null):
		var auto_plan := _get_first_auto_plan(game_manager, partner)
		if not auto_plan.is_empty():
			self_zone = auto_plan.get("self_zone", null) as Zone
			partner_zone = auto_plan.get("partner_zone", null) as Zone

	var feedback := resolve_flank(game_manager, partner, self_zone, partner_zone)
	if game_manager != null and feedback != "":
		game_manager.note_player_feedback(feedback)

func resolve_flank(game_manager: GameManager, partner: Card, self_zone: Zone, partner_zone: Zone) -> String:
	if not can_activate(game_manager):
		return get_activation_failure_reason(game_manager)
	if not _is_valid_partner_target(game_manager, partner):
		return card_name + " needs another friendly Animal to flank with."
	if self_zone == null or partner_zone == null:
		return card_name + " needs two legal destination slots."
	if self_zone == partner_zone:
		return card_name + " needs different destination slots."
	if self_zone not in get_valid_self_zones(game_manager, partner):
		return card_name + " cannot move to that slot."
	if partner_zone not in get_valid_partner_zones(game_manager, partner, self_zone):
		return partner.card_name + " cannot move to that slot."
	if self_zone == current_zone and partner_zone == partner.current_zone:
		return card_name + " needs at least one creature to change slots."

	is_used = true
	_move_pair(self, self_zone, partner, partner_zone)

	var viewer := game_manager.get_feedback_viewer() if game_manager != null else null
	return "%s flanks with %s, moving to %s and %s." % [
		card_name,
		partner.get_target_log_display_name(viewer),
		_zone_label(self_zone, get_controller()),
		_zone_label(partner_zone, get_controller()),
	]

func on_turn_start(_game_manager: GameManager) -> void:
	is_used = false

func on_turn_end(_game_manager: GameManager) -> void:
	is_used = false

func _is_valid_partner_target(game_manager: GameManager, card: Card) -> bool:
	return _is_valid_partner_target_without_plan_check(game_manager, card) \
		and not _get_first_auto_plan(game_manager, card).is_empty()

func _is_valid_partner_target_without_plan_check(game_manager: GameManager, card: Card) -> bool:
	if card == null or card == self:
		return false
	if card.card_type != Card.CardType.CREATURE or card.is_god:
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	if card.get_controller() != get_controller():
		return false
	if not card.has_type("Animal"):
		return false
	if not card.get_status_effect("cannot_move").is_empty():
		return false
	if game_manager != null and game_manager.is_immune_to_source(card, self):
		return false
	return true

func _get_friendly_board_zones() -> Array[Zone]:
	var zones: Array[Zone] = []
	var controller := get_controller()
	if controller == null:
		return zones
	for zone in controller.frontline_zones + controller.reserve_zones:
		zones.append(zone)
	return zones

func _zone_can_host_moved_creature(zone: Zone, first_card: Card, second_card: Card) -> bool:
	if zone == null or not zone.is_board_zone():
		return false
	if zone.zone_owner != get_controller():
		return false
	for zone_card in zone.cards:
		if zone_card == first_card or zone_card == second_card:
			continue
		if zone_card.card_type == Card.CardType.EQUIPMENT and zone_card.equipped_on in [first_card, second_card]:
			continue
		return false
	return zone.get_equipment().is_empty()

func _get_first_auto_plan(game_manager: GameManager, partner: Card) -> Dictionary:
	if not _is_valid_partner_target_without_plan_check(game_manager, partner):
		return {}
	for candidate_self_zone in get_valid_self_zones(game_manager, partner):
		for candidate_partner_zone in get_valid_partner_zones(game_manager, partner, candidate_self_zone):
			if candidate_self_zone == current_zone and candidate_partner_zone == partner.current_zone:
				continue
			return {
				"self_zone": candidate_self_zone,
				"partner_zone": candidate_partner_zone,
			}
	return {}

func _resolve_partner_from_activation_data(game_manager: GameManager, target_data) -> Card:
	if target_data is Card:
		return target_data as Card
	if target_data is Dictionary:
		var data := target_data as Dictionary
		if data.get("target", null) is Card:
			return data.get("target", null) as Card
		var target_uid := str(data.get("target_uid", ""))
		if target_uid != "" and game_manager != null:
			return game_manager.get_card_by_uid(target_uid)
	return null

func _resolve_zone_from_activation_data(game_manager: GameManager, target_data, key: String) -> Zone:
	if target_data is Dictionary:
		var data := target_data as Dictionary
		var raw_zone = data.get(key, null)
		if raw_zone is Zone:
			return raw_zone as Zone
		if raw_zone is Dictionary:
			return _resolve_zone_from_dict(game_manager, raw_zone as Dictionary)
	return null

func _resolve_zone_from_dict(game_manager: GameManager, zone_dict: Dictionary) -> Zone:
	if game_manager == null:
		return null
	var player_index := int(zone_dict.get("player_index", -1))
	if player_index < 0 or player_index >= game_manager.players.size():
		return null
	var player := game_manager.players[player_index]
	var zone_index := int(zone_dict.get("zone_index", -1))
	match int(zone_dict.get("zone_type", -1)):
		Zone.ZoneType.FRONTLINE:
			if zone_index >= 0 and zone_index < player.frontline_zones.size():
				return player.frontline_zones[zone_index]
		Zone.ZoneType.RESERVE:
			if zone_index >= 0 and zone_index < player.reserve_zones.size():
				return player.reserve_zones[zone_index]
	return null

func _move_pair(first_card: Card, first_zone: Zone, second_card: Card, second_zone: Zone) -> void:
	var first_from := first_card.current_zone
	var second_from := second_card.current_zone
	if first_from == null or second_from == null:
		return

	if first_zone != first_from:
		first_card.reveal_from_stealth()
	if second_zone != second_from:
		second_card.reveal_from_stealth()

	first_from.remove_card(first_card)
	second_from.remove_card(second_card)
	first_zone.add_card(first_card)
	second_zone.add_card(second_card)

	first_card.card_owner.card_moved.emit(first_card, first_from, first_zone)
	second_card.card_owner.card_moved.emit(second_card, second_from, second_zone)

	_sync_equipment_zone(first_card, first_zone)
	_sync_equipment_zone(second_card, second_zone)

func _sync_equipment_zone(creature: Card, destination_zone: Zone) -> void:
	if creature == null or destination_zone == null:
		return
	for equip in creature.equipment.duplicate():
		if equip == null or equip.current_zone == destination_zone:
			continue
		equip.card_owner.move_card(equip, destination_zone)

func _zone_label(zone: Zone, controller: Player) -> String:
	if zone == null or controller == null:
		return "the field"
	if zone in controller.frontline_zones:
		return "Front %d" % (zone.zone_index + 1)
	if zone in controller.reserve_zones:
		return "Reserve %d" % (zone.zone_index + 1)
	return "the field"
