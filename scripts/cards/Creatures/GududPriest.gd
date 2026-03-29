extends CreatureCard
class_name GududPriest

const WARD_STATUS := "blessed_ward"
const WARD_KIND := "creature_abilities"
const WARD_SOURCE := "Gudu Priest Faction Ward"

func _init() -> void:
	super._init()
	card_name = "Gudu Priest"
	card_types = ["Human", "Mage", "Priest", "Ancient Creature"]
	level = 2
	mana_cost = 2
	sacrifice_cost = 0
	speed = 2
	resilience = 9
	strength = 1
	ability_text = "Faction Ward Creature ([b]Activate[/b], Spd3): Once per turn, choose a creature. For the remainder of the turn it is unaffected by creature abilities."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricarrdo Zoppello"
	art_path = "res://images/card_art/creatures/gudu_priest.jpg"

func get_activation_label() -> String:
	return "Faction Ward Creature"

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
	if creature_major_action_used:
		return false
	return not _get_valid_targets(game_manager).is_empty()

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("Faction Ward Creature fizzles: cannot activate right now.")
		return
	if not _is_valid_ward_target(target):
		if game_manager != null:
			game_manager.note_player_feedback("Faction Ward Creature fizzles: invalid target.")
		return

	target.remove_status_effects_from_source_card(self, WARD_STATUS)
	target.add_status_effect(
		WARD_STATUS,
		WARD_SOURCE,
		self,
		get_controller(),
		{
			"ward_kind": WARD_KIND,
			"expires_turn": game_manager.turn_number,
			"display_name": "Faction Ward (creature abilities)",
		}
	)
	spend_major_creature_action()
	game_manager.note_player_feedback(
		"Faction Ward Creature: %s is unaffected by creature abilities this turn." % target.card_name
	)

func on_removed(game_manager: GameManager) -> void:
	_clear_wards(game_manager)

func on_muted(game_manager: GameManager) -> void:
	_clear_wards(game_manager)

func _get_valid_targets(game_manager: GameManager) -> Array[Card]:
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

func _clear_wards(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				card.remove_status_effects_from_source_card(self, WARD_STATUS)
