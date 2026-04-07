extends HexCard
class_name ShroudOfTheAncients

const STEALTH_MODE := Card.CreatureMode.DEFENSIVE

func _init() -> void:
	super._init()
	card_name = "Shroud of the Ancients"
	level = 3
	mana_cost = 2
	speed = 4
	culture = "Ancient"
	card_types = ["Cloak", "Stealth"]
	ability_text = "Change all creatures to stealth stance."
	flavor_text = ""
	artist = ""
	art_path = "res://images/card_art/hexes/ShroudoftheAncientsArt.jpg"
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

	var affected_count := 0
	var immune_count := 0
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for creature in zone.cards:
				if not _is_valid_creature(creature):
					continue
				if game_manager.is_immune_to_source(creature, self):
					immune_count += 1
					continue
				_apply_stealth_stance(creature)
				affected_count += 1

	if affected_count <= 0:
		var no_effect_feedback := "%s settled over the field, but no creatures were changed to stealth stance." % card_name
		if immune_count > 0:
			no_effect_feedback += " %d creature(s) were immune." % immune_count
		game_manager.note_player_feedback(no_effect_feedback)
	else:
		var feedback := "%s changed %d creature(s) to stealth stance." % [card_name, affected_count]
		if immune_count > 0:
			feedback += " %d creature(s) were immune." % immune_count
		game_manager.note_player_feedback(feedback)

	if card_owner != null:
		card_owner.move_card(self, card_owner.graveyard_zone)

func _is_valid_creature(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.current_zone != null \
		and card.current_zone.is_board_zone()

func _apply_stealth_stance(creature: Card) -> void:
	creature.is_face_down = true
	creature.is_stealth = true
	creature.creature_mode = STEALTH_MODE
