extends BaseCard
class_name AphroditeAreia

const ACTIVATION_COST := 5
const ART_PATH := "res://images/card_art/aphrodite_areia.png"

var paragon: String = "Paragon of Love"

func _init() -> void:
	card_name = "Aphrodite Areia"
	card_type = Card.CardType.CREATURE
	is_god = true
	card_types = ["Love", "Sex", "War"]
	mana_cost = 0
	strength = 0
	resilience = 0
	speed = 1
	culture = "Olympic"
	flavor_text = "Love and slaughter walk hand in hand."
	ability_text = "Violent Delights (5 mana): During a turn where you have destroyed an opponent's creature by combat, [b]Enslave[/b] a creature."
	art_path = ART_PATH
	artist = "Ricarrdo Zoppello"
	name_at_bottom = true

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if card_owner != game_manager.current_player:
		return false
	if card_owner.mana < ACTIVATION_COST:
		return false
	if not _has_destroyed_enemy_by_combat_this_turn(game_manager):
		return false
	return not get_valid_enslave_targets(game_manager).is_empty()

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
		print("Violent Delights: conditions not met.")
		return
	if not is_valid_activation_target(target):
		print("Violent Delights: invalid target.")
		return
	card_owner.spend_mana(ACTIVATION_COST)
	if game_manager.enslave_creature(target, card_owner):
		print("Violent Delights: " + target.card_name + " is enslaved by " + card_owner.player_name + ".")
	else:
		card_owner.gain_mana(ACTIVATION_COST)
		print("Violent Delights: no room to enslave " + target.card_name + ".")

func get_valid_enslave_targets(game_manager: GameManager) -> Array[Card]:
	var targets: Array[Card] = []
	if game_manager == null:
		return targets
	var opponent := game_manager.get_opponent(card_owner)
	if opponent == null:
		return targets
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if is_valid_activation_target(card):
				targets.append(card)
	return targets

func _has_destroyed_enemy_by_combat_this_turn(game_manager: GameManager) -> bool:
	if game_manager.has_method("player_destroyed_creature_by_combat_this_turn"):
		return game_manager.player_destroyed_creature_by_combat_this_turn(card_owner)
	return false
