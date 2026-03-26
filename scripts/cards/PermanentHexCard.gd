extends HexCard
class_name PermanentHexCard

var attached_target: Card = null
var _pending_attach_target: Card = null

func _init() -> void:
	super._init()
	targets = true

func can_attach_to_target(_game_manager: GameManager, _target: Card) -> bool:
	return false

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			var creature := zone.get_creature()
			if creature != null and can_play_to_target(game_manager, creature):
				valid_targets.append(creature)
	return valid_targets

func can_play_to_target(game_manager: GameManager, target: Card) -> bool:
	if game_manager == null or card_owner == null or target == null:
		return false
	if current_zone != card_owner.hand_zone:
		return false
	if card_owner != game_manager.current_player:
		return false
	if not can_be_played(game_manager, card_owner):
		return false
	if not can_attach_to_target(game_manager, target):
		return false
	var target_zone := target.current_zone
	if target_zone == null or not target_zone.is_board_zone():
		return false
	if game_manager.is_guardian_protected(target, self):
		return false
	if game_manager.is_immune_to_source(target, self):
		return false
	return target_zone.get_equipment().is_empty()

func can_activate_on_target(game_manager: GameManager, target: Card) -> bool:
	if game_manager == null or card_owner == null or target == null:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if not can_attach_to_target(game_manager, target):
		return false
	var target_zone := target.current_zone
	if target_zone == null or not target_zone.is_board_zone():
		return false
	if game_manager.is_guardian_protected(target, self):
		return false
	if game_manager.is_immune_to_source(target, self):
		return false
	return target_zone.get_equipment().is_empty()

func play_to_target(game_manager: GameManager, target: Card) -> bool:
	if not can_play_to_target(game_manager, target):
		return false
	var target_zone := target.current_zone
	_pending_attach_target = target
	if not pay_costs(card_owner, game_manager):
		_pending_attach_target = null
		return false
	card_owner.move_card(self, target_zone)
	is_prepared = false
	is_face_down = false
	on_impact(game_manager)
	var attached_successfully := attached_target == target and current_zone == target_zone
	if not attached_successfully:
		_pending_attach_target = null
	return attached_successfully

func activate_on_target(game_manager: GameManager, target: Card) -> bool:
	if not can_activate_on_target(game_manager, target):
		return false
	_pending_attach_target = target
	is_prepared = false
	is_face_down = false
	on_impact(game_manager)
	var attached_successfully := attached_target == target and current_zone != null and current_zone.is_board_zone()
	if not attached_successfully:
		_pending_attach_target = null
	return attached_successfully

func on_impact(game_manager: GameManager) -> void:
	if _pending_attach_target == null:
		return
	var target := _pending_attach_target
	_pending_attach_target = null
	if not can_attach_to_target(game_manager, target):
		if current_zone != null:
			card_owner.move_card(self, card_owner.graveyard_zone)
		return
	attached_target = target
	on_attached(game_manager, target)

func on_attached(_game_manager: GameManager, _target: Card) -> void:
	pass

func on_removed(_game_manager: GameManager) -> void:
	pass
