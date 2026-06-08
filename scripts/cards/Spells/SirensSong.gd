extends SpellCard
class_name SirensSong

const ART_PATH := "res://images/card_art/spells/SirensSong.png"

func _init() -> void:
	super._init()
	card_name = "Siren's Song"
	culture = "Olympic"
	card_types = ["Control", "Targeting"]
	level = 2
	mana_cost = 3
	speed = 1
	is_legendary = false
	sacrifice_cost = 0
	targets = true
	flavor_text = ""
	artist = "User provided"
	art_path = ART_PATH
	ability_text = "Take control of an opposing creature until end of turn."

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or card_owner == null:
		return valid_targets
	var opponent := game_manager.get_opponent(card_owner)
	if opponent == null:
		return valid_targets
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if is_valid_target(card, game_manager):
				valid_targets.append(card)
	return valid_targets

func is_valid_target(target: Card, game_manager: GameManager = null) -> bool:
	if target == null or card_owner == null:
		return false
	if target.card_type != Card.CardType.CREATURE or target.is_god:
		return false
	if target.current_zone == null or not target.current_zone.is_board_zone():
		return false
	if target.is_face_down or target.is_stealth:
		return false
	if target.get_controller() == card_owner:
		return false
	return game_manager == null or game_manager.can_enslave_creature(target, card_owner)

func resolve(game_manager: GameManager, target = null) -> void:
	if game_manager == null:
		return
	var target_card := target as Card
	if not is_valid_target(target_card, game_manager):
		game_manager.note_player_feedback("Siren's Song fizzles: choose an opposing creature.")
		return
	if game_manager.is_immune_to_source(target_card, self):
		game_manager.note_player_feedback("Siren's Song fizzles: %s is immune to spells." % target_card.card_name)
		return
	if not game_manager.grant_temporary_control_of_creature(target_card, card_owner, self):
		var failure_reason := game_manager.get_enslave_failure_reason(target_card, card_owner)
		if failure_reason.is_empty():
			failure_reason = "no open zone is available."
		game_manager.note_player_feedback("Siren's Song fizzles: " + failure_reason)
		return
	game_manager.note_player_feedback("Siren's Song steals %s until end of turn." % target_card.card_name)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	var base_reason := super.get_play_failure_reason(game_manager, player)
	if not base_reason.is_empty():
		return base_reason
	if get_valid_targets(game_manager).is_empty():
		return card_name + " has no valid opposing creature targets."
	return ""
