extends GodCard
class_name DellingrTheDayspring

const ACTIVATION_COST := 2
const REVEAL_SOURCE := "Dellingr's Revealing Light"

var paragon: String = "Paragon of the Sun"

func _init() -> void:
	super._init()
	card_name = "Dellingr, the Dayspring"
	card_types = ["Sun"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	mana_cost = 0
	culture = "Norse"
	targets = true
	flavor_text = ""
	ability_text = "Revealing Light (%d mana, [b]Activate[/b]): Reveal an opponent's card until the end of the turn; if it is magical, it cannot be activated this turn." % ACTIVATION_COST
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/gods/Dellingr(web).jpg"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if is_muted:
		return false
	if card_owner != game_manager.current_player:
		return false
	if card_owner == null or card_owner.mana < ACTIVATION_COST:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var targets_list: Array[Card] = []
	if game_manager == null or card_owner == null:
		return targets_list
	var opponent := game_manager.get_opponent(card_owner)
	if opponent == null:
		return targets_list

	for god in opponent.god_zone.cards:
		if is_valid_activation_target(god):
			targets_list.append(god)
	for zone in opponent.power_zones:
		for card in zone.cards:
			if is_valid_activation_target(card):
				targets_list.append(card)
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if is_valid_activation_target(card):
				targets_list.append(card)
	return targets_list

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if is_muted:
		return card_name + " is muted."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if card_owner == null or card_owner.mana < ACTIVATION_COST:
		return card_name + " needs " + str(ACTIVATION_COST) + " mana."
	if get_valid_targets(game_manager).is_empty():
		return "Revealing Light has no valid targets right now."
	return ""

func is_valid_activation_target(target: Card) -> bool:
	return target != null \
		and target.get_controller() != null \
		and target.get_controller() != card_owner \
		and target.current_zone != null \
		and target.current_zone.is_board_zone()

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	if not is_valid_activation_target(target):
		game_manager.note_player_feedback("Revealing Light fizzles: invalid target.")
		return
	if game_manager != null and game_manager.is_immune_to_source(target, self):
		game_manager.note_player_feedback("Revealing Light fizzles: " + target.card_name + " is immune to powers.")
		return
	if not card_owner.spend_mana(ACTIVATION_COST):
		game_manager.note_player_feedback(card_name + " needs " + str(ACTIVATION_COST) + " mana.")
		return

	target.temporarily_reveal_until_end_of_turn(game_manager.turn_number, REVEAL_SOURCE, self, card_owner, game_manager)
	var locked := _is_magical_target(target)
	if locked:
		target.lock_activation_until_end_of_turn(game_manager.turn_number, REVEAL_SOURCE, self, card_owner)

	var feedback := "Revealing Light reveals %s until end of turn." % target.card_name
	if locked:
		feedback += " It cannot be activated this turn."
	game_manager.note_player_feedback(feedback)

func _is_magical_target(target: Card) -> bool:
	if target == null:
		return false
	return target.is_magical_card()
