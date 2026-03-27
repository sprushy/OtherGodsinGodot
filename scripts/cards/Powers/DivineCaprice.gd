extends PowerCard
class_name DivineCaprice

const UNLOCK_COST := 1
const ACTIVATION_COST := 2
const SLOT_GROUP_BOARD := "board"

func _init() -> void:
	super._init()
	card_name = "Divine Caprice"
	culture = "Neutral"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Repositioning"]
	ability_text = "[b]Unlock[/b] (1): [b]Activate[/b] - Move your cards to different legal slots."
	artist = "Riccardo Zoppello"
	art_path = "res://images/card_art/powers/DivineCapriceAIEdit.png"

func on_unlock(_game_manager: GameManager) -> void:
	print(card_name + " unlocked.")

func can_activate(game_manager: GameManager) -> bool:
	if not super.can_activate(game_manager):
		return false
	if card_owner == null or card_owner.mana < get_activation_mana_cost(ACTIVATION_COST, game_manager):
		return false
	return has_reposition_targets()

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
	var activation_cost := get_activation_mana_cost(ACTIVATION_COST, game_manager)
	if card_owner == null or card_owner.mana < activation_cost:
		return card_name + " needs " + str(activation_cost) + " mana."
	if not has_reposition_targets():
		return card_name + " has no legal friendly slots to rearrange."
	return ""

func pay_activation_cost(game_manager: GameManager) -> bool:
	return spend_activation_mana(ACTIVATION_COST, game_manager)

func activate(game_manager: GameManager, target = null) -> void:
	if not can_activate(game_manager):
		return
	if target is not Array:
		return
	var plan: Array = target as Array
	if plan.is_empty():
		return
	if not pay_activation_cost(game_manager):
		return
	var moved_steps := apply_reposition_plan(plan)
	if game_manager == null:
		return
	if moved_steps > 0:
		game_manager.note_player_feedback(card_name + " rearranged your slots.")
	else:
		game_manager.note_player_feedback(card_name + " fizzles: the planned slots are no longer legal.")

func get_reposition_zones() -> Array[Zone]:
	var zones: Array[Zone] = []
	if card_owner == null:
		return zones
	for zone in card_owner.frontline_zones:
		zones.append(zone)
	for zone in card_owner.reserve_zones:
		zones.append(zone)
	return zones

func get_slot_group(zone: Zone) -> String:
	if zone == null:
		return ""
	if zone in card_owner.frontline_zones or zone in card_owner.reserve_zones:
		return SLOT_GROUP_BOARD
	return ""

func can_reposition_between(source_zone: Zone, target_zone: Zone) -> bool:
	if card_owner == null or source_zone == null or target_zone == null:
		return false
	if source_zone == target_zone:
		return false
	if source_zone.zone_owner != card_owner or target_zone.zone_owner != card_owner:
		return false
	if source_zone.cards.is_empty():
		return false
	var source_group := get_slot_group(source_zone)
	var target_group := get_slot_group(target_zone)
	if source_group == "" or source_group != target_group:
		return false
	return true

func has_reposition_targets() -> bool:
	var zones := get_reposition_zones()
	for source_zone in zones:
		if source_zone == null or source_zone.cards.is_empty():
			continue
		for target_zone in zones:
			if can_reposition_between(source_zone, target_zone):
				return true
	return false

func apply_reposition_plan(plan: Array) -> int:
	var moved_steps := 0
	if card_owner == null:
		return moved_steps
	for step in plan:
		if not (step is Dictionary):
			continue
		var source_zone: Zone = step.get("source_zone", null) as Zone
		var target_zone: Zone = step.get("target_zone", null) as Zone
		if not can_reposition_between(source_zone, target_zone):
			continue
		_swap_zone_contents(source_zone, target_zone)
		moved_steps += 1
	return moved_steps

func _swap_zone_contents(source_zone: Zone, target_zone: Zone) -> void:
	var source_cards: Array[Card] = []
	for card in source_zone.cards:
		if card is Card:
			source_cards.append(card as Card)
	var target_cards: Array[Card] = []
	for card in target_zone.cards:
		if card is Card:
			target_cards.append(card as Card)

	source_zone.cards.clear()
	target_zone.cards.clear()

	for card in target_cards:
		source_zone.add_card(card)
		card.card_owner.card_moved.emit(card, target_zone, source_zone)
	for card in source_cards:
		target_zone.add_card(card)
		card.card_owner.card_moved.emit(card, source_zone, target_zone)
