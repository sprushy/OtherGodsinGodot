extends PermanentHexCard
class_name WheelOfFire

const ART_PATH := "res://images/card_art/hexes/WheelofFireEdit.png"
const ACTION_TAX_AMOUNT := 1
const ADVANCE_COST := 1
var _turn_start_advance_window_open: bool = false

func _init() -> void:
	super._init()
	card_name = "Wheel of Fire"
	level = 2
	mana_cost = 0
	speed = 2
	culture = "Olympic"
	card_types = ["Hex", "Permanent", "Binding", "Lasting", "Targeting"]
	ability_text = "Bind a creature. Move it back 1 row. All its actions cost 1 more mana.\n[b]Upkeep[/b]: You may pay 1 mana to move the bound card back 1 row. From the reserve line you may send it to the grave; from the grave you may [b]Void[/b] it. If the bound creature leaves the field or grave, destroy this card."
	flavor_text = ""
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func can_attach_to_target(_game_manager: GameManager, target: Card) -> bool:
	if target == null:
		return false
	if target.card_type != Card.CardType.CREATURE:
		return false
	if target.is_god:
		return false
	return target.current_zone != null and (
		target.current_zone.is_board_zone()
		or target.current_zone == target.card_owner.graveyard_zone
	)

func can_respond_to_action(action: CardAction) -> bool:
	return action != null

func get_priority_targets(game_manager: GameManager, _action: CardAction) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			var creature := zone.get_creature()
			if creature != null and can_activate_on_target(game_manager, creature):
				valid_targets.append(creature)
	return valid_targets

func on_activate_action(game_manager: GameManager, action: CardAction) -> void:
	var target := action.target as Card
	if not activate_on_target(game_manager, target):
		if game_manager != null:
			game_manager.note_player_feedback("%s fizzles: choose a creature." % card_name)
			game_manager.request_send_to_graveyard(self)
		elif card_owner != null:
			card_owner.move_card(self, card_owner.graveyard_zone)
		return

	if game_manager != null and target != null:
		var target_name := target.get_target_log_display_name(game_manager.get_feedback_viewer())
		game_manager.note_player_feedback(
			"%s binds %s. Its actions cost %d mana while the binding lasts." % [
				card_name,
				target_name,
				ACTION_TAX_AMOUNT
			]
		)

func on_attached(game_manager: GameManager, target: Card) -> void:
	_advance_target_step(game_manager, false)
	print("%s binds %s." % [card_name, target.card_name])

func on_turn_start(_game_manager: GameManager) -> void:
	pass

func on_global_turn_start(game_manager: GameManager, starting_player: Player) -> void:
	_turn_start_advance_window_open = false
	if game_manager == null or card_owner == null:
		return
	if is_prepared or is_face_down:
		return
	if get_controller() != starting_player:
		return
	if not _is_binding_active():
		_release_self(game_manager)
		return
	if not _is_active():
		return
	if _get_next_zone_for_target(attached_target) == null:
		return
	if card_owner.mana < ADVANCE_COST:
		return
	_turn_start_advance_window_open = true

func on_any_card_moved(game_manager: GameManager, moved_card: Card, _from_zone: Zone, _to_zone: Zone) -> void:
	if moved_card != attached_target:
		return
	if attached_target == null or not is_instance_valid(attached_target):
		_release_self(game_manager)
		return
	if not _is_trackable_zone(attached_target.current_zone):
		_release_self(game_manager)

func on_removed(_game_manager: GameManager) -> void:
	_turn_start_advance_window_open = false
	attached_target = null
	_pending_attach_target = null

func on_turn_end(_game_manager: GameManager) -> void:
	super.on_turn_end(_game_manager)
	_turn_start_advance_window_open = false

func on_global_turn_end(_game_manager: GameManager, _ending_player: Player) -> void:
	_turn_start_advance_window_open = false

func close_turn_start_window() -> void:
	_turn_start_advance_window_open = false

func can_offer_turn_start_advance(game_manager: GameManager) -> bool:
	if not _turn_start_advance_window_open:
		return false
	if game_manager == null or card_owner == null:
		return false
	if not _is_binding_active() or not _is_active():
		return false
	if card_owner.mana < ADVANCE_COST:
		return false
	return _get_next_zone_for_target(attached_target) != null

func get_turn_start_advance_prompt_text(game_manager: GameManager = null) -> String:
	if attached_target == null or not is_instance_valid(attached_target):
		return "Pay %d mana to move Wheel of Fire's target back again?" % ADVANCE_COST
	var target_name := attached_target.card_name
	if game_manager != null:
		target_name = attached_target.get_target_log_display_name(game_manager.get_feedback_viewer())
	var next_zone := _get_next_zone_for_target(attached_target)
	if next_zone == null:
		return "Pay %d mana to move %s back again?" % [ADVANCE_COST, target_name]
	return "Pay %d mana to %s?" % [ADVANCE_COST, _get_prompt_movement_text(attached_target.current_zone, next_zone, target_name)]

func resolve_turn_start_advance_choice(game_manager: GameManager, pay_cost: bool) -> String:
	if game_manager == null:
		_turn_start_advance_window_open = false
		return card_name + " cannot advance right now."
	var target_name := attached_target.get_target_log_display_name(game_manager.get_feedback_viewer()) \
		if attached_target != null and is_instance_valid(attached_target) \
		else "its target"
	if not can_offer_turn_start_advance(game_manager):
		_turn_start_advance_window_open = false
		return card_name + " can no longer move its target."
	_turn_start_advance_window_open = false
	if not pay_cost:
		return "%s stays bound to %s." % [card_name, target_name]
	var feedback := _advance_target_step(game_manager, true, false)
	if feedback.strip_edges() != "":
		return feedback
	return "%s can no longer move %s." % [card_name, target_name]

func get_creature_action_tax_amount(creature: Card, _game_manager: GameManager = null) -> int:
	if creature == null or creature != attached_target:
		return 0
	if creature.current_zone == null or not creature.current_zone.is_board_zone():
		return 0
	return ACTION_TAX_AMOUNT if _is_active() else 0

func _advance_target_step(game_manager: GameManager, pay_cost: bool, emit_feedback: bool = true) -> String:
	if game_manager == null or attached_target == null or not is_instance_valid(attached_target):
		return ""

	var next_zone := _get_next_zone_for_target(attached_target)
	if next_zone == null:
		return ""
	if pay_cost and (card_owner == null or not card_owner.spend_mana(ADVANCE_COST)):
		return ""

	var target_name := attached_target.get_target_log_display_name(game_manager.get_feedback_viewer())
	var from_zone := attached_target.current_zone
	if from_zone != null and from_zone.is_board_zone():
		attached_target.reveal_from_stealth(game_manager)
	attached_target.card_owner.move_card(attached_target, next_zone)

	var movement_text := _get_movement_text(from_zone, next_zone)
	var feedback := ""
	if pay_cost:
		feedback = "%s pays %d mana to %s %s." % [card_owner.player_name, ADVANCE_COST, movement_text, target_name]
	else:
		feedback = "%s %s %s." % [card_name, movement_text, target_name]
	if emit_feedback:
		game_manager.note_player_feedback(feedback)
	return feedback

func _get_next_zone_for_target(target: Card) -> Zone:
	if target == null or target.current_zone == null:
		return null
	var current_zone := target.current_zone
	if current_zone.zone_type == Zone.ZoneType.FRONTLINE:
		var controller := target.get_controller()
		if controller == null:
			return null
		return _get_nearest_legal_reserve_zone(controller, current_zone.zone_index)
	if current_zone.zone_type == Zone.ZoneType.RESERVE:
		return target.card_owner.graveyard_zone
	if current_zone == target.card_owner.graveyard_zone:
		return target.card_owner.abyss_zone
	return null

func _get_nearest_legal_reserve_zone(controller: Player, center_index: int) -> Zone:
	if controller == null or controller.reserve_zones.is_empty():
		return null
	var clamped_center := clampi(center_index, 0, controller.reserve_zones.size() - 1)
	for zone in _reserve_zones_by_distance(controller, clamped_center):
		if zone != null and zone.cards.is_empty():
			return zone
	return null

func _reserve_zones_by_distance(controller: Player, center_index: int) -> Array[Zone]:
	var zones: Array[Zone] = []
	if controller == null:
		return zones
	zones.append(controller.reserve_zones[center_index])
	for distance in range(1, controller.reserve_zones.size()):
		var low := center_index - distance
		var high := center_index + distance
		if low >= 0:
			zones.append(controller.reserve_zones[low])
		if high < controller.reserve_zones.size():
			zones.append(controller.reserve_zones[high])
	return zones

func _get_movement_text(from_zone: Zone, to_zone: Zone) -> String:
	if from_zone == null or to_zone == null:
		return "moves"
	if from_zone.zone_type == Zone.ZoneType.FRONTLINE and to_zone.zone_type == Zone.ZoneType.RESERVE:
		return "moves back to the reserves"
	if from_zone.zone_type == Zone.ZoneType.RESERVE and to_zone.zone_type == Zone.ZoneType.GRAVEYARD:
		return "pulls into the grave"
	if from_zone.zone_type == Zone.ZoneType.GRAVEYARD and to_zone.zone_type == Zone.ZoneType.ABYSS:
		return "casts into the Void"
	return "moves"

func _is_active() -> bool:
	return current_zone != null and current_zone.is_board_zone() and not is_face_down and not abilities_suppressed()

func _is_binding_active() -> bool:
	return attached_target != null \
		and is_instance_valid(attached_target) \
		and attached_target.current_zone != null \
		and _is_trackable_zone(attached_target.current_zone)

func _is_trackable_zone(zone: Zone) -> bool:
	if zone == null:
		return false
	if zone.is_board_zone():
		return true
	return attached_target != null and zone == attached_target.card_owner.graveyard_zone

func _get_prompt_movement_text(from_zone: Zone, to_zone: Zone, target_name: String) -> String:
	if from_zone == null or to_zone == null:
		return "move %s" % target_name
	if from_zone.zone_type == Zone.ZoneType.FRONTLINE and to_zone.zone_type == Zone.ZoneType.RESERVE:
		return "move %s back to the reserves" % target_name
	if from_zone.zone_type == Zone.ZoneType.RESERVE and to_zone.zone_type == Zone.ZoneType.GRAVEYARD:
		return "pull %s into the grave" % target_name
	if from_zone.zone_type == Zone.ZoneType.GRAVEYARD and to_zone.zone_type == Zone.ZoneType.ABYSS:
		return "cast %s into the Void" % target_name
	return "move %s" % target_name

func _release_self(game_manager: GameManager) -> void:
	_turn_start_advance_window_open = false
	if current_zone == null:
		on_removed(game_manager)
		return
	if game_manager != null:
		game_manager.request_send_to_graveyard(self)
	elif card_owner != null:
		card_owner.move_card(self, card_owner.graveyard_zone)
