extends CreatureCard
class_name RoboticFootsoldier

var united_front_partner: Card = null

func _init() -> void:
	super._init()
	card_name = "Robotic Footsoldier"
	card_types = ["Machine", "Robot", "Atlanitan Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	speed = 1
	resilience = 1
	strength = 6
	ability_text = "United Front: Can attack with another Machine, using their combined STR at the lower SPD."
	flavor_text = ""
	culture = "Atlanitan"
	artist = "Stanley Vay"
	art_path = "res://images/card_art/creatures/Robot_Soldier_V2.jpg"
	targets = true

func get_activation_label() -> String:
	return "United Front"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		return false
	if abilities_suppressed():
		return false
	if is_sleeping:
		return false
	if creature_mode != Card.CreatureMode.AGGRESSIVE:
		return false
	if not can_take_major_creature_action():
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null:
		return valid_targets
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if _can_join_united_front(card):
				valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	if target == null or target not in get_valid_targets(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("%s fizzles: choose another friendly Machine." % card_name)
		return
	united_front_partner = target
	if game_manager != null:
		game_manager.note_player_feedback("%s joins forces with %s for its next attack." % [card_name, target.card_name])

func get_united_front_partner_for_attack(game_manager: GameManager) -> Card:
	if united_front_partner == null:
		return null
	if not _can_join_united_front(united_front_partner):
		_clear_united_front_state()
		if game_manager != null:
			game_manager.note_player_feedback("%s lost its United Front partner before it could attack." % card_name)
		return null
	return united_front_partner

func get_united_front_attack_speed(game_manager: GameManager) -> int:
	var partner := get_united_front_partner_for_attack(game_manager)
	if partner == null:
		return get_effective_speed()
	return mini(get_effective_speed(), partner.get_effective_speed())

func on_after_combat(_game_manager: GameManager, _opposing_card: Card) -> void:
	_clear_united_front_state()

func on_turn_end(_game_manager: GameManager) -> void:
	_clear_united_front_state()

func on_removed(_game_manager: GameManager) -> void:
	_clear_united_front_state()

func _can_join_united_front(card: Card) -> bool:
	if card == null or card == self:
		return false
	if card.card_type != Card.CardType.CREATURE:
		return false
	if not card.has_type("Machine"):
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	if card.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		return false
	if card.get_controller() != get_controller():
		return false
	if card.is_sleeping:
		return false
	if card.creature_mode != Card.CreatureMode.AGGRESSIVE:
		return false
	if not card.can_take_major_creature_action():
		return false
	return true

func _clear_united_front_state() -> void:
	united_front_partner = null
