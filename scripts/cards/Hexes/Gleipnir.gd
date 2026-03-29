extends PermanentHexCard
class_name Gleipnir

const ART_PATH := "res://images/card_art/hexes/gleipnir.jpg"
const ATTACK_LOCK_STATUS := "cannot_attack"
const INTERCEPT_LOCK_STATUS := "cannot_intercept"
const STATUS_SOURCE := "Gleipnir"

func _init() -> void:
	super._init()
	card_name = "Gleipnir"
	is_legendary = true
	level = 4
	mana_cost = 1
	speed = 4
	culture = "Norse"
	card_types = ["Hex", "Permanent", "Binding", "Legendary", "Targeting"]
	ability_text = "Choose a creature; it cannot attack or intercept and its abilities are negated. This card remains on the field for as long as its target does."
	art_path = ART_PATH
	artist = "Lorinda Tomko"

func can_attach_to_target(_game_manager: GameManager, target: Card) -> bool:
	if target == null:
		return false
	if target.card_type != Card.CardType.CREATURE:
		return false
	if target.is_god:
		return false
	return target.current_zone != null and target.current_zone.is_board_zone()

func can_respond_to_action(_action: CardAction) -> bool:
	return true

func get_priority_targets(game_manager: GameManager, _action: CardAction) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
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
		game_manager.note_player_feedback(
			"%s binds %s. It cannot attack, intercept, or use abilities while Gleipnir remains attached."
			% [card_name, target.get_target_log_display_name(game_manager.get_feedback_viewer())]
		)

func on_attached(game_manager: GameManager, target: Card) -> void:
	_apply_binding_to_target(game_manager, target)
	print("%s binds %s." % [card_name, target.card_name])

func on_turn_start(game_manager: GameManager) -> void:
	if not _is_target_still_bound():
		_release_self(game_manager)

func on_any_card_moved(game_manager: GameManager, moved_card: Card, _from_zone: Zone, _to_zone: Zone) -> void:
	if moved_card != attached_target:
		return
	if not _is_target_still_bound():
		_release_self(game_manager)

func on_removed(game_manager: GameManager) -> void:
	if attached_target != null:
		attached_target.remove_status_effects_from_source_card(self, ATTACK_LOCK_STATUS)
		attached_target.remove_status_effects_from_source_card(self, INTERCEPT_LOCK_STATUS)
		# Unmute only if we were the one who muted it.
		if attached_target.is_muted and attached_target.mute_turns_remaining == -1:
			attached_target.is_muted = false
			attached_target.mute_turns_remaining = 0
			if attached_target.has_method("on_unmuted"):
				attached_target.on_unmuted(game_manager)
	attached_target = null
	_pending_attach_target = null

func _apply_binding_to_target(game_manager: GameManager, target: Card) -> void:
	target.remove_status_effects_from_source_card(self, ATTACK_LOCK_STATUS)
	target.add_status_effect(
		ATTACK_LOCK_STATUS,
		STATUS_SOURCE,
		self,
		card_owner,
		{"display_name": "Cannot attack (Gleipnir)"}
	)
	target.remove_status_effects_from_source_card(self, INTERCEPT_LOCK_STATUS)
	target.add_status_effect(
		INTERCEPT_LOCK_STATUS,
		STATUS_SOURCE,
		self,
		card_owner,
		{"display_name": "Cannot intercept (Gleipnir)"}
	)
	target.mute_permanently(game_manager)

func _is_target_still_bound() -> bool:
	return attached_target != null \
		and is_instance_valid(attached_target) \
		and attached_target.current_zone != null \
		and attached_target.current_zone.is_board_zone()

func _release_self(game_manager: GameManager) -> void:
	if current_zone == null or game_manager == null:
		on_removed(game_manager)
		return
	game_manager.request_send_to_graveyard(self)
