extends SpellCard
class_name TheChangelingExchange

const ART_PATH := "res://images/card_art/spells/TheChangelingExchange.png"

func _init() -> void:
	super._init()
	card_name = "The Changeling Exchange"
	culture = "Triskelion"
	card_types = ["Fairy", "Targeting"]
	level = 3
	mana_cost = 2
	speed = 1
	is_legendary = false
	sacrifice_cost = 0
	targets = true
	flavor_text = ""
	artist = "User provided"
	art_path = ART_PATH
	ability_text = "Give your opponent control of one of your creatures, then take control of one of theirs."

func get_opponent(game_manager: GameManager) -> Player:
	if game_manager == null or card_owner == null:
		return null
	return game_manager.get_opponent(card_owner)

func get_friendly_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or card_owner == null:
		return valid_targets
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if is_valid_friendly_target(card, game_manager):
				valid_targets.append(card)
	return valid_targets

func get_enemy_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or card_owner == null:
		return valid_targets
	var opponent := get_opponent(game_manager)
	if opponent == null:
		return valid_targets
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if is_valid_enemy_target(card, game_manager):
				valid_targets.append(card)
	return valid_targets

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	return get_enemy_targets(game_manager)

func is_valid_friendly_target(card: Card, game_manager: GameManager = null) -> bool:
	if card == null or card_owner == null:
		return false
	if card.card_type != Card.CardType.CREATURE or card.is_god:
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	if card.get_controller() != card_owner:
		return false
	if game_manager != null and game_manager.is_immune_to_source(card, self):
		return false
	return true

func is_valid_enemy_target(card: Card, game_manager: GameManager = null) -> bool:
	if card == null or card_owner == null:
		return false
	var opponent := get_opponent(game_manager) if game_manager != null else null
	if opponent == null:
		return false
	if card.card_type != Card.CardType.CREATURE or card.is_god:
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	if card.get_controller() != opponent:
		return false
	if game_manager != null and game_manager.is_immune_to_source(card, self):
		return false
	return true

func _resolve_targets(game_manager: GameManager, command: Dictionary) -> Array:
	var friendly_uid: String = str(command.get("friendly_target_uid", "")).strip_edges()
	var enemy_uid: String = str(command.get("enemy_target_uid", command.get("target_uid", command.get("secondary_target_uid", "")))).strip_edges()
	var target_uids: Array = command.get("target_uids", [])
	if target_uids is Array:
		if target_uids.size() >= 2:
			if friendly_uid == "":
				friendly_uid = str(target_uids[0]).strip_edges()
			if enemy_uid == "":
				enemy_uid = str(target_uids[1]).strip_edges()
		elif target_uids.size() == 1 and enemy_uid == "":
			enemy_uid = str(target_uids[0]).strip_edges()
	var friendly: Card = game_manager.get_card_by_uid(friendly_uid) if (game_manager != null and friendly_uid != "") else null
	var enemy: Card = game_manager.get_card_by_uid(enemy_uid) if (game_manager != null and enemy_uid != "") else null
	return [friendly, enemy]

func resolve(game_manager: GameManager, target = null) -> void:
	if game_manager == null:
		return
	var friendly: Card = null
	var enemy: Card = null
	if target is Dictionary:
		var friendly_raw = target.get("friendly_target", target.get("friendly", null))
		var enemy_raw = target.get("enemy_target", target.get("enemy", target.get("target", null)))
		if friendly_raw is Card:
			friendly = friendly_raw as Card
		if enemy_raw is Card:
			enemy = enemy_raw as Card
	elif target is Card:
		enemy = target as Card
	_resolve_with_cards(game_manager, friendly, enemy)

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var targets: Array = _resolve_targets(game_manager, command)
	var friendly: Card = targets[0] as Card
	var enemy: Card = targets[1] as Card
	_resolve_with_cards(game_manager, friendly, enemy)

func _resolve_with_cards(game_manager: GameManager, friendly: Card, enemy: Card) -> void:
	if game_manager == null or card_owner == null:
		return
	var opponent := get_opponent(game_manager)
	if opponent == null:
		game_manager.note_player_feedback("The Changeling Exchange fizzles: no opponent.")
		return
	if not is_valid_friendly_target(friendly, game_manager):
		game_manager.note_player_feedback("The Changeling Exchange fizzles: choose one of your creatures.")
		return
	if not is_valid_enemy_target(enemy, game_manager):
		game_manager.note_player_feedback("The Changeling Exchange fizzles: choose one of your opponent's creatures.")
		return
	if friendly == enemy:
		game_manager.note_player_feedback("The Changeling Exchange fizzles: choose two different creatures.")
		return
	# First part: give opponent control of your creature.
	if not game_manager.grant_control_of_creature(friendly, opponent):
		game_manager.note_player_feedback("The Changeling Exchange fizzles: no open zone for %s." % friendly.card_name)
		return
	# Then: take control of opponent's creature.
	if not game_manager.grant_control_of_creature(enemy, card_owner):
		game_manager.note_player_feedback("The Changeling Exchange gave %s to %s, but could not take %s." % [friendly.card_name, opponent.player_name, enemy.card_name])
		return
	game_manager.note_player_feedback("The Changeling Exchange swapped control of %s and %s." % [friendly.card_name, enemy.card_name])

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	if game_manager == null or player == null or card_owner != player:
		return false
	return not get_friendly_targets(game_manager).is_empty() and not get_enemy_targets(game_manager).is_empty()

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	var base_reason := super.get_play_failure_reason(game_manager, player)
	if not base_reason.is_empty():
		return base_reason
	if game_manager == null or player == null:
		return card_name + " cannot be cast right now."
	if get_friendly_targets(game_manager).is_empty():
		return card_name + " has no valid friendly creature targets."
	if get_enemy_targets(game_manager).is_empty():
		return card_name + " has no valid opposing creature targets."
	return ""