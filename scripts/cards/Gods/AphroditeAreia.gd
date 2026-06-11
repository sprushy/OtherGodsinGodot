extends GodCard
class_name AphroditeAreia

const ACTIVATION_COST := 5
const ART_PATH := "res://images/card_art/gods/aphrodite_areia.png"

func _init() -> void:
	super._init()
	card_name = "Aphrodite Areia"
	card_types = ["Love", "Sex", "War"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	mana_cost = 0
	culture = "Olympic"
	targets = true
	# flavor_text = "Love and slaughter walk hand in hand."
	flavor_text = ""
	ability_text = "Violent Delights (%d mana): If you destroyed an opponent's creature in combat this turn, [b]Enslave[/b] a creature." % ACTIVATION_COST
	art_path = ART_PATH
	artist = "Ricarrdo Zoppello"
	name_at_bottom = true

func can_activate(game_manager: GameManager) -> bool:
	if not can_use_god_power(game_manager):
		return false
	if card_owner.mana < ACTIVATION_COST:
		return false
	if not _has_destroyed_enemy_by_combat_this_turn(game_manager):
		return false
	return not get_valid_enslave_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if is_muted:
		return card_name + " is muted."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if card_owner.mana < ACTIVATION_COST:
		return card_name + " needs " + str(ACTIVATION_COST) + " mana."
	if not _has_destroyed_enemy_by_combat_this_turn(game_manager):
		return "Violent Delights needs an enemy creature destroyed in combat this turn."
	if not get_valid_enslave_targets(game_manager).is_empty():
		return ""
	var opponent := game_manager.get_opponent(card_owner)
	if opponent != null:
		for zone in opponent.frontline_zones + opponent.reserve_zones:
			for card in zone.cards:
				if not is_valid_activation_target(card):
					continue
				var failure_reason := game_manager.get_enslave_failure_reason(card, card_owner)
				if failure_reason != "":
					return "Violent Delights has no valid targets: " + failure_reason
	return "Violent Delights has no valid targets right now."

func is_valid_activation_target(target: Card) -> bool:
	if target == null:
		return false
	if target.card_type != Card.CardType.CREATURE:
		return false
	if target.is_god or target.is_face_down:
		return false
	return target.get_controller() != card_owner

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	if not is_valid_activation_target(target):
		game_manager.note_player_feedback("Violent Delights fizzles: invalid target.")
		return
	if game_manager != null and game_manager.is_immune_to_source(target, self):
		game_manager.note_player_feedback("Violent Delights fizzles: " + target.card_name + " is immune to powers.")
		return
	if game_manager != null and not game_manager.can_enslave_creature(target, card_owner):
		game_manager.note_player_feedback("Violent Delights fizzles: " + game_manager.get_enslave_failure_reason(target, card_owner))
		return
	card_owner.spend_mana(ACTIVATION_COST)
	if game_manager.enslave_creature(target, card_owner):
		game_manager.note_player_feedback("Violent Delights enslaved " + target.card_name + ".")
		notify_power_activated(game_manager, target)
	else:
		card_owner.gain_mana(ACTIVATION_COST)
		game_manager.note_player_feedback("Violent Delights fizzles: " + game_manager.get_enslave_failure_reason(target, card_owner))

func get_valid_enslave_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	var opponent := game_manager.get_opponent(card_owner)
	if opponent == null:
		return valid_targets
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if is_valid_activation_target(card) and game_manager.can_enslave_creature(card, card_owner):
				valid_targets.append(card)
	return valid_targets

func _has_destroyed_enemy_by_combat_this_turn(game_manager: GameManager) -> bool:
	if game_manager.has_method("player_destroyed_creature_by_combat_this_turn"):
		return game_manager.player_destroyed_creature_by_combat_this_turn(card_owner)
	return false

func on_turn_end(game_manager: GameManager) -> void:
	super.on_turn_end(game_manager)
