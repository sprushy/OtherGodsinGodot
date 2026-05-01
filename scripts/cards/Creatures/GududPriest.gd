extends CreatureCard
class_name GududPriest

const WARD_STATUS := "blessed_ward"
const WARD_KIND := "creature_abilities"
const WARD_SOURCE := "Gudu Priest Creature Ward"

func _init() -> void:
	super._init()
	card_name = "Gudu Priest"
	card_types = ["Human", "Mage", "Priest", "Ancient Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 9
	strength = 2
	targets = true
	ability_text = "[b]Creature Ward[/b] ([b]Activate[/b], Spd3): Once per turn, choose a creature. Remove creature-applied effects from it. For the remainder of the turn it is unaffected by creature abilities."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricarrdo Zoppello"
	art_path = "res://images/card_art/creatures/gudu_priest.jpg"

func get_activation_label() -> String:
	return "Creature Ward"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	var controller := get_controller()
	if controller != game_manager.current_player:
		return false
	if abilities_suppressed() or is_activation_locked(game_manager):
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_face_down or is_stealth or is_prepared:
		return false
	if is_sleeping:
		return false
	if is_used:
		return false
	return not get_valid_targets(game_manager).is_empty()

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("Creature Ward fizzles: cannot activate right now.")
		return
	if target == null or target not in get_valid_targets(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("Creature Ward fizzles: invalid target.")
		return

	_clear_creature_applied_effects(target)
	target.remove_status_effects_from_source_card(self, WARD_STATUS)
	target.add_status_effect(
		WARD_STATUS,
		WARD_SOURCE,
		self,
		get_controller(),
		{
			"ward_kind": WARD_KIND,
			"expires_turn": game_manager.turn_number,
			"display_name": "Creature Ward",
		}
	)
	is_used = true
	game_manager.note_player_feedback(
		"Creature Ward: %s shrugs off creature-applied effects and is unaffected by creature abilities this turn." % target.card_name
	)

func on_turn_end(_game_manager: GameManager) -> void:
	is_used = false

func on_removed(game_manager: GameManager) -> void:
	_clear_wards(game_manager)

func on_muted(game_manager: GameManager) -> void:
	_clear_wards(game_manager)

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid: Array[Card] = []
	if game_manager == null:
		return valid
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _is_valid_ward_target(card):
					valid.append(card)
	return valid

func _is_valid_ward_target(target: Card) -> bool:
	return target != null \
		and target.card_type == Card.CardType.CREATURE \
		and target.current_zone != null \
		and target.current_zone.is_board_zone()

func _clear_creature_applied_effects(target: Card) -> void:
	if target == null:
		return
	for status in target.active_statuses.duplicate():
		var status_source_card := status.get("source_card", null) as Card
		if not _is_creature_ability_source(status_source_card):
			continue
		target.remove_status_effects_from_source_card(status_source_card, str(status.get("name", "")))
	for buff in target.active_buffs.duplicate():
		var buff_source_card := buff.get("source_card", null) as Card
		if not _is_creature_ability_source(buff_source_card):
			continue
		target.remove_buffs_from_source_card(buff_source_card, str(buff.get("effect_type", "")))

func _is_creature_ability_source(source_card: Card) -> bool:
	return source_card != null and source_card.card_type == Card.CardType.CREATURE

func _clear_wards(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				card.remove_status_effects_from_source_card(self, WARD_STATUS)
