extends PowerCard
class_name FireAndGold

const UNLOCK_COST := 2
const ACTIVATION_DISCARD_COST := 1

func _init() -> void:
	super._init()
	card_name = "Fire and Gold"
	culture = "Tian"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Destruction", "Structure"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	targets = true
	ability_text = "[b]Unlock[/b] (2): [b]Activate[/b] - Discard 1 card. If you have a Tian Dragon on the frontline, destroy one structure."
	artist = "Josh13 via pixabay"
	art_path = "res://images/card_art/powers/FireandGoldAIEdit.png"

func get_activation_discard_cost() -> int:
	return ACTIVATION_DISCARD_COST

func can_activate(game_manager: GameManager) -> bool:
	return super.can_activate(game_manager) \
		and can_pay_activation_costs(0, game_manager) \
		and _has_friendly_tian_dragon_on_frontline() \
		and not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or not _has_friendly_tian_dragon_on_frontline():
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if is_valid_target(card):
					valid_targets.append(card)
	return valid_targets

func is_valid_target(target: Card) -> bool:
	return target != null \
		and target.card_type == Card.CardType.STRUCTURE \
		and target.current_zone != null \
		and target.current_zone.is_board_zone()

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		print(card_name + ": Cannot activate.")
		return
	if not is_valid_target(target):
		print(card_name + ": Invalid structure target.")
		clear_pending_activation_discards()
		return
	if not pay_activation_costs(0, game_manager):
		print(card_name + ": Could not pay activation cost.")
		return
	var viewer := game_manager.get_feedback_viewer()
	var target_name := target.get_target_log_display_name(viewer)
	print("%s destroys %s." % [card_name, target.card_name])
	game_manager.request_send_to_graveyard(target, func() -> void:
		if game_manager.reached_public_destroyed_destination(target):
			var destroyed_name := game_manager.get_resolved_destruction_log_name(target, viewer, target_name)
			game_manager.note_player_feedback("%s destroyed %s." % [card_name, destroyed_name])
		else:
			game_manager.note_player_feedback("%s failed to destroy %s." % [card_name, target_name])
	, false, true)

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if is_face_down:
		return card_name + " must be unlocked first."
	if is_muted:
		return card_name + " is muted."
	if is_activation_locked(game_manager):
		return card_name + " cannot be activated this turn."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if card_owner == null or card_owner.hand_zone.get_card_count() < ACTIVATION_DISCARD_COST:
		return card_name + " needs 1 card in hand to discard."
	if not _has_friendly_tian_dragon_on_frontline():
		return card_name + " needs a Tian Dragon on your frontline."
	if get_valid_targets(game_manager).is_empty():
		return card_name + " has no structure to destroy."
	return ""

func _has_friendly_tian_dragon_on_frontline() -> bool:
	if card_owner == null:
		return false
	for zone in card_owner.frontline_zones:
		var creature := zone.get_creature()
		if creature == null:
			continue
		if creature.culture != "Tian":
			continue
		if not creature.has_type("Dragon"):
			continue
		return true
	return false
