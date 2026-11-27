extends HexCard
class_name GorgonsGaze

const ART_PATH := "res://images/card_art/hexes/GorgonsStare.png"
const STONE_TYPE := "Stone"
const PETRIFIED_STATUS := "petrified"

func _init() -> void:
	super._init()
	card_name = "Gorgon's Gaze"
	level = 4
	mana_cost = 1
	speed = 4
	is_legendary = true
	culture = "Olympic"
	card_types = ["Legendary Destruction", "Petrification"]
	ability_text = "Reveal all opposing face-down creatures, then [b]Petrify[/b] all opposing creatures."
	flavor_text = ""
	artist = ""
	art_path = ART_PATH
	targets = false

func can_respond_to_action(action: CardAction) -> bool:
	return action != null

func can_activate_prepared(game_manager: GameManager, player: Player) -> bool:
	if game_manager == null or player == null:
		return false
	if player != game_manager.current_player:
		return false
	if card_owner != null and player != card_owner:
		return false
	if not is_prepared:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if not game_manager.action_stack.is_empty():
		return false
	if game_manager.prepared_hexes.get(self, game_manager.turn_number) >= game_manager.turn_number:
		return false
	if is_activation_locked(game_manager):
		return false
	if not game_manager.can_pay_prepared_card_activation_cost(self, player):
		return false
	return true

func on_activate_action(game_manager: GameManager, _action: CardAction) -> void:
	if game_manager == null:
		if card_owner != null:
			card_owner.move_card(self, card_owner.graveyard_zone)
		return

	var opposing_creatures := _get_opposing_board_creatures(game_manager)

	# Reveal first so hidden creatures cannot escape the gaze, and so
	# reveal-trigger payoffs fire before the petrification pass.
	var revealed_count := 0
	for creature in opposing_creatures:
		if not _is_revealable_creature(creature):
			continue
		creature.reveal(game_manager)
		if game_manager.has_method("notify_card_revealed_by_effect"):
			game_manager.notify_card_revealed_by_effect(creature, self)
		revealed_count += 1

	var petrified_count := 0
	var immune_count := 0
	for creature in opposing_creatures:
		if not _should_petrify(creature):
			continue
		if game_manager._is_hex_immune(creature, self):
			immune_count += 1
			continue
		_apply_petrification(creature, game_manager)
		petrified_count += 1

	var feedback := "%s revealed %d face-down creature(s) and petrified %d creature(s)." % [
		card_name,
		revealed_count,
		petrified_count,
	]
	if immune_count > 0:
		feedback += " %d creature(s) were immune to hexes." % immune_count
	game_manager.note_player_feedback(feedback)

	if card_owner != null:
		card_owner.move_card(self, card_owner.graveyard_zone)

func _get_opposing_board_creatures(game_manager: GameManager) -> Array[Card]:
	var creatures: Array[Card] = []
	if game_manager == null:
		return creatures
	var owner_side := get_controller()
	if owner_side == null:
		return creatures
	for player in game_manager.players:
		if player == null or player == owner_side:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			if zone == null:
				continue
			for card in zone.cards:
				if card != null and card.card_type == Card.CardType.CREATURE:
					creatures.append(card)
	return creatures

func _is_revealable_creature(card: Card) -> bool:
	if card == null:
		return false
	if card.is_god:
		return false
	if not card.is_creature_card():
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	return card.is_face_down or card.is_stealth

func _should_petrify(card: Card) -> bool:
	if card == null:
		return false
	if card.is_god:
		return false
	if not card.is_creature_card():
		return false
	if card.is_petrified():
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	return true

func _apply_petrification(card: Card, game_manager: GameManager) -> void:
	var was_hidden := card.is_face_down or card.is_stealth
	var original_card_type := card.card_type
	var original_strength := card.strength
	var original_speed := card.speed
	var original_card_types := card.card_types.duplicate()
	card.reveal(game_manager)
	if was_hidden and game_manager != null and game_manager.has_method("notify_card_revealed_by_effect"):
		game_manager.notify_card_revealed_by_effect(card, self)
	card.card_type = Card.CardType.STRUCTURE
	card.strength = 0
	card.speed = 0
	if not card.has_type(STONE_TYPE):
		card.card_types.append(STONE_TYPE)
	card.add_status_effect(
		PETRIFIED_STATUS,
		card_name,
		self,
		card_owner,
		{
			"restore_base_state_on_remove": true,
			"original_card_type": original_card_type,
			"original_strength": original_strength,
			"original_speed": original_speed,
			"original_card_types": original_card_types,
		}
	)
