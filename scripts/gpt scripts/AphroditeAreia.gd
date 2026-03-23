extends BaseCard
class_name AphroditeAreia

var paragon: String = "Paragon of Love"
const ACTIVATION_COST := 5

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
	ability_text = "Violent Delights (5 mana): During a turn where you have destroyed an opponent's creature by combat, enslave a creature."
	art_path = "res://images/card_art/AphroditeAreiaAltArt.jpg"
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
	return _has_valid_enslave_target(game_manager)


func activate(game_manager: GameManager, target: Card) -> void:
	if not can_activate(game_manager):
		print("Violent Delights: conditions not met.")
		return

	if target == null:
		print("Violent Delights: no target selected.")
		return

	if not _is_valid_enslave_target(target):
		print("Violent Delights: invalid target.")
		return

	card_owner.spend_mana(ACTIVATION_COST)
	_enslave_target(target, game_manager)
	print("Violent Delights: " + target.card_name + " is enslaved by " + card_owner.player_name + ".")


func _has_destroyed_enemy_by_combat_this_turn(game_manager: GameManager) -> bool:
	if game_manager.has_method("player_destroyed_creature_by_combat_this_turn"):
		return game_manager.player_destroyed_creature_by_combat_this_turn(card_owner)

	if game_manager.has_method("get_combat_destroy_events_this_turn"):
		for event in game_manager.get_combat_destroy_events_this_turn():
			if typeof(event) == TYPE_DICTIONARY:
				if event.get("killer_owner", null) == card_owner and event.get("victim_owner", null) != card_owner:
					return true

	if "combat_destroy_events_this_turn" in game_manager:
		for event in game_manager.combat_destroy_events_this_turn:
			if typeof(event) == TYPE_DICTIONARY:
				if event.get("killer_owner", null) == card_owner and event.get("victim_owner", null) != card_owner:
					return true

	return false


func _has_valid_enslave_target(game_manager: GameManager) -> bool:
	var opponent = null
	if game_manager.has_method("get_opponent"):
		opponent = game_manager.get_opponent(card_owner)

	if opponent == null:
		return false

	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if _is_valid_enslave_target(card):
				return true

	return false


func _is_valid_enslave_target(target: Card) -> bool:
	if target == null:
		return false
	if target.card_owner == card_owner:
		return false
	if target.is_god:
		return false
	if target.is_face_down:
		return false
	return true


func _enslave_target(target: Card, game_manager: GameManager) -> void:
	var old_owner = target.card_owner
	var destination_zone = null

	if card_owner.reserve_zones.size() > 0:
		destination_zone = card_owner.reserve_zones[0]
	elif card_owner.frontline_zones.size() > 0:
		destination_zone = card_owner.frontline_zones[0]

	if game_manager.has_method("enslave_creature"):
		game_manager.enslave_creature(target, card_owner)
		return

	if old_owner != null and old_owner.has_method("remove_card_from_field"):
		old_owner.remove_card_from_field(target)

	target.card_owner = card_owner

	if destination_zone != null:
		if destination_zone.has_method("add_card"):
			destination_zone.add_card(target)
		elif "cards" in destination_zone:
			destination_zone.cards.append(target)

	if target.has_method("clear_damage"):
		target.clear_damage()
