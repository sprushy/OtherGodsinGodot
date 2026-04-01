extends CreatureCard
class_name Lugalbanda

const ART_PATH := "res://images/card_art/creatures/LugalbandaEdit.png"

func _init() -> void:
	super._init()
	card_name = "Lugalbanda"
	card_types = ["Human", "Warrior", "Ancient Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 16
	strength = 18
	flavor_text = ""
	ability_text = "[b]Reflex[/b]: May pick up or destroy any unequipped equipment on the field. If the equipment is on your opponent's side of the field, this is interceptable."
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func can_use_equipment_action(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if not _has_active_reflex():
		return (
			card_type == Card.CardType.CREATURE
			and (can_take_major_creature_action() or can_take_minor_creature_action())
			and not is_sleeping
			and game_manager.turn_number > 0
			and get_controller() == game_manager.current_player
			and current_zone != null
			and current_zone.is_board_zone()
		)
	return (
		card_type == Card.CardType.CREATURE
		and not is_sleeping
		and game_manager.turn_number > 0
		and get_controller() == game_manager.current_player
		and current_zone != null
		and current_zone.is_board_zone()
	)

func can_pick_up_equipment_action(_game_manager: GameManager, is_enemy: bool) -> bool:
	if _has_active_reflex():
		return can_receive_equipment()
	return can_take_major_creature_action() if is_enemy else can_take_minor_creature_action()

func can_destroy_equipment_action(_game_manager: GameManager, _is_enemy: bool) -> bool:
	if _has_active_reflex():
		return true
	return can_take_major_creature_action()

func get_equipment_action_entries(game_manager: GameManager) -> Array[Dictionary]:
	if abilities_suppressed() or is_face_down or is_stealth or is_prepared:
		return _get_default_equipment_action_entries(game_manager)
	var result: Array[Dictionary] = []
	var controller := get_controller()
	if game_manager == null or controller == null:
		return result
	var reachable := game_manager.get_reachable_board_zones(self)
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for equip in zone.get_equipment():
				result.append({
					"equipment": equip,
					"is_enemy": zone.zone_owner != controller,
					"in_range": zone in reachable
				})
	return result

func resolve_equipment_action(game_manager: GameManager, equipment_card: Card, action: String) -> bool:
	if game_manager == null:
		return false
	if not can_use_equipment_action(game_manager):
		return false
	if not _has_active_reflex():
		match action:
			"pick_up", "steal":
				return game_manager.creature_pick_up_equipment(self, equipment_card)
			"destroy":
				return game_manager.creature_destroy_equipment(self, equipment_card)
		return false
	if equipment_card == null or equipment_card.card_type != Card.CardType.EQUIPMENT or equipment_card.equipped_on != null:
		return false
	var equip_zone := equipment_card.current_zone
	if equip_zone == null or not equip_zone.is_board_zone():
		return false
	var controller := get_controller()
	if controller == null or current_zone == null or not current_zone.is_board_zone():
		return false

	match action:
		"pick_up", "steal":
			if not can_receive_equipment():
				return false
			if not equipment_card.can_equip_to(self):
				return false
			equip_zone.remove_card(equipment_card)
			current_zone.add_card(equipment_card)
			equipment_card.equip_to(self)
			return true
		"destroy":
			game_manager._send_to_graveyard_with_hook(equipment_card, false, true)
			return true
	return false

func _get_default_equipment_action_entries(game_manager: GameManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var controller := get_controller()
	if game_manager == null or controller == null or current_zone == null:
		return result
	var reachable := game_manager.get_reachable_board_zones(self)
	var seen: Array[Card] = []

	for zone in reachable:
		for equip in zone.get_equipment():
			if equip in seen:
				continue
			seen.append(equip)
			result.append({
				"equipment": equip,
				"is_enemy": zone.zone_owner != controller,
				"in_range": true
			})

	if current_zone.zone_type == Zone.ZoneType.FRONTLINE:
		var opponent := game_manager.get_opponent(controller)
		if opponent != null:
			for zone in opponent.frontline_zones + opponent.reserve_zones:
				for equip in zone.get_equipment():
					if equip in seen:
						continue
					seen.append(equip)
					result.append({
						"equipment": equip,
						"is_enemy": true,
						"in_range": false
					})

	return result

func _has_active_reflex() -> bool:
	return not abilities_suppressed() and not is_face_down and not is_stealth and not is_prepared
