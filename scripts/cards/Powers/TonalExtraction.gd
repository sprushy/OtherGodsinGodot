extends PowerCard
class_name TonalExtraction

const UNLOCK_COST := 5
const SHAPESHIFT_LOCK_STATUS := "tonal_extraction_no_shift"
const ART_PATH := "res://images/card_art/powers/TonalExtractionEdit.png"

var _pending_unlock_resolution: bool = false
var _pending_unlock_target_uid: String = ""
var _bound_shapeshifter: Card = null
var _spirit_token: Card = null
var _is_cleaning_up: bool = false

func _init() -> void:
	super._init()
	card_name = "Tonal Extraction"
	culture = "Nahuatl"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Summon Creature", "Spirit", "Shapeshifter"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	targets = true
	ability_text = "[b]Unlock[/b] (5): Choose a friendly [b]Shapeshifter[/b]. It loses shapeshift. Summon a [b]Spirit[/b] token with its alternate form's stats and classes. That Spirit cannot be sacrificed. When that Spirit leaves the field, [b]Relock[/b] this card."
	artist = "Trent Nguyen"
	art_path = ART_PATH

func can_unlock(game_manager: GameManager) -> bool:
	return super.can_unlock(game_manager) \
		and _find_open_summon_zone() != null \
		and not get_valid_targets(game_manager).is_empty()

func get_unlock_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot unlock right now."
	if not is_face_down:
		return card_name + " is already unlocked."
	if is_muted:
		return card_name + " is muted."
	if is_activation_locked(game_manager):
		return card_name + " cannot be unlocked this turn."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to unlock."
	if _find_open_summon_zone() == null:
		return card_name + " needs an open zone for the Spirit."
	if get_valid_targets(game_manager).is_empty():
		return card_name + " needs a friendly Shapeshifter on the field."
	return super.get_unlock_failure_reason(game_manager)

func on_unlock(game_manager: GameManager) -> void:
	_pending_unlock_resolution = true
	if game_manager == null:
		return
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		game_manager.note_player_feedback(card_name + " found no friendly Shapeshifter to extract.")
		relock()
		return
	if card_owner == null:
		return
	var queued_target := _consume_pending_unlock_target(valid_targets)
	if queued_target != null:
		game_manager.run_with_effect_source(
			self,
			func() -> void:
				activate(game_manager, queued_target)
		)
		return
	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(card_owner, "tonal_extraction", {
		"source_uid": uid,
		"target_uids": target_uids,
	})

func set_pending_unlock_target_uid(target_uid: String) -> void:
	_pending_unlock_target_uid = target_uid.strip_edges()

func can_activate(game_manager: GameManager) -> bool:
	return super.can_activate(game_manager) \
		and _pending_unlock_resolution \
		and _bound_shapeshifter == null \
		and _spirit_token == null \
		and _find_open_summon_zone() != null \
		and not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if not _pending_unlock_resolution:
		return card_name + " has no extraction choice pending."
	if _find_open_summon_zone() == null:
		return card_name + " needs an open zone for the Spirit."
	if get_valid_targets(game_manager).is_empty():
		return card_name + " found no friendly Shapeshifter to extract."
	return super.get_activation_failure_reason(game_manager)

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null:
		return valid_targets
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if _is_valid_target(card):
				valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	if target == null or target not in get_valid_targets(game_manager):
		game_manager.note_player_feedback(card_name + " fizzles: choose a friendly Shapeshifter.")
		return
	var summon_zone := _find_open_summon_zone()
	if summon_zone == null:
		game_manager.note_player_feedback(card_name + " needs an open zone for the Spirit.")
		return
	var profile := _build_spirit_profile(target)
	if profile.is_empty():
		game_manager.note_player_feedback(card_name + " could not read " + target.card_name + "'s alternate form.")
		_pending_unlock_resolution = false
		relock()
		return

	target.add_status_effect(SHAPESHIFT_LOCK_STATUS, card_name, self, card_owner)
	var spirit := TonalExtractionSpiritToken.new()
	spirit.configure_from_profile(profile)
	spirit.card_owner = card_owner
	var summoned := game_manager.summon_creature_by_effect(
		card_owner,
		spirit,
		summon_zone,
		Card.CreatureMode.AGGRESSIVE,
		false,
		false,
		self,
		false,
		false,
		false
	)
	if not summoned:
		target.remove_status_effects_from_source_card(self, SHAPESHIFT_LOCK_STATUS)
		game_manager.note_player_feedback(card_name + " could not summon the extracted Spirit.")
		_pending_unlock_resolution = false
		relock()
		return

	_bound_shapeshifter = target
	_spirit_token = spirit
	_pending_unlock_resolution = false
	game_manager.note_player_feedback(
		"%s extracts %s's alternate form into %s." % [
			card_name,
			target.get_target_log_display_name(game_manager.get_feedback_viewer()),
			spirit.get_target_log_display_name(game_manager.get_feedback_viewer())
		]
	)

func on_any_card_moved(game_manager: GameManager, moved_card: Card, from_zone: Zone, to_zone: Zone) -> void:
	if _is_cleaning_up or moved_card == null or from_zone == null:
		return
	if from_zone.is_board_zone() and (to_zone == null or not to_zone.is_board_zone()):
		if moved_card == _spirit_token:
			_cleanup_and_relock(game_manager, false)
		elif moved_card == _bound_shapeshifter:
			_clear_bound_shapeshifter()

func on_removed(game_manager: GameManager) -> void:
	_cleanup_effect(game_manager, true)

func on_muted(game_manager: GameManager) -> void:
	_cleanup_effect(game_manager, true)

func relock() -> void:
	_cleanup_effect(null, true)
	super.relock()

func _cleanup_and_relock(game_manager: GameManager, remove_spirit: bool) -> void:
	_cleanup_effect(game_manager, remove_spirit)
	super.relock()

func _cleanup_effect(game_manager: GameManager, remove_spirit: bool) -> void:
	if _is_cleaning_up:
		return
	_is_cleaning_up = true
	_pending_unlock_resolution = false
	_clear_bound_shapeshifter()
	if remove_spirit and _spirit_token != null and is_instance_valid(_spirit_token):
		if _spirit_token.current_zone != null and _spirit_token.current_zone.is_board_zone() and _spirit_token.card_owner != null:
			if game_manager != null:
				game_manager.request_send_to_graveyard(_spirit_token, Callable(), false, true)
			else:
				_spirit_token.card_owner.move_card(_spirit_token, _spirit_token.card_owner.graveyard_zone)
	_bound_shapeshifter = null
	_spirit_token = null
	_is_cleaning_up = false

func _clear_bound_shapeshifter() -> void:
	if _bound_shapeshifter != null and is_instance_valid(_bound_shapeshifter):
		_bound_shapeshifter.remove_status_effects_from_source_card(self, SHAPESHIFT_LOCK_STATUS)
	_bound_shapeshifter = null

func _is_valid_target(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and card.get_controller() == card_owner \
		and card.has_type("Shapeshifter") \
		and not card.is_shapeshift_locked() \
		and card.has_method("get_tonal_extraction_spirit_profile")

func _build_spirit_profile(target: Card) -> Dictionary:
	if target == null or not target.has_method("get_tonal_extraction_spirit_profile"):
		return {}
	var profile := target.get_tonal_extraction_spirit_profile()
	if profile.is_empty():
		return {}
	var types: Array[String] = []
	for raw_type in profile.get("card_types", []):
		var type_name := str(raw_type).strip_edges()
		if type_name != "" and type_name not in types:
			types.append(type_name)
	if "Spirit" not in types:
		types.append("Spirit")
	profile["card_types"] = types
	return profile

func _consume_pending_unlock_target(valid_targets: Array[Card]) -> Card:
	var target_uid := _pending_unlock_target_uid
	_pending_unlock_target_uid = ""
	if target_uid.is_empty():
		return null
	for target in valid_targets:
		if target != null and target.uid == target_uid:
			return target
	return null

func _find_open_summon_zone() -> Zone:
	if card_owner == null:
		return null
	for zone in card_owner.frontline_zones:
		if zone.cards.is_empty():
			return zone
	for zone in card_owner.reserve_zones:
		if zone.cards.is_empty():
			return zone
	return null
