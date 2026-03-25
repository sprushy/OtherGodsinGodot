extends SpellCard
class_name DeucalionsInfants

const STONE_INFANT_ART_USAGE_META_KEY := "stone_infant_art_usage"

func _init() -> void:
	super._init()
	card_name = "Deucalion's Infants"
	culture = "Olympic"
	card_types = ["Destruction", "Structure", "Summon Creature"]
	level = 1
	mana_cost = 2
	speed = 1
	is_legendary = false
	flavor_text = ""
	artist = ""
	art_path = "res://images/card_art/DeucalionsInfants.png"
	ability_text = "Children of the Earth: You may destroy your structures and golems and your opponent must destroy 1 of theirs. For every structure or golem destroyed this turn, summon 1 [b]Stone Infant[/b] token."

func resolve(game_manager: GameManager, target = null) -> void:
	if target is Dictionary:
		var friendly_targets: Array[Card] = []
		for card in target.get("friendly_targets", []):
			if card is Card:
				friendly_targets.append(card as Card)
		resolve_with_choices(
			game_manager,
			friendly_targets,
			target.get("enemy_target", null) as Card
		)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	if game_manager == null or player == null:
		return false
	return not get_destroyable_friendly_cards(game_manager).is_empty() \
		or not get_destroyable_enemy_cards(game_manager).is_empty() \
		or get_destroyed_structure_or_golem_count_this_turn(game_manager) > 0

func get_destroyable_friendly_cards(game_manager: GameManager) -> Array[Card]:
	var cards: Array[Card] = []
	if game_manager == null or card_owner == null:
		return cards
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if _is_destroyable_structure_or_golem(card) and card.get_controller() == card_owner:
				cards.append(card)
	return cards

func get_destroyable_enemy_cards(game_manager: GameManager) -> Array[Card]:
	var cards: Array[Card] = []
	if game_manager == null or card_owner == null:
		return cards
	var opponent := game_manager.get_opponent(card_owner)
	if opponent == null:
		return cards
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if _is_destroyable_structure_or_golem(card) and card.get_controller() == opponent:
				cards.append(card)
	return cards

func resolve_with_choices(game_manager: GameManager, friendly_targets: Array[Card], enemy_target: Card = null) -> Array[Card]:
	var summoned_tokens: Array[Card] = []
	if game_manager == null or card_owner == null:
		return summoned_tokens

	var destroyed_count_before := get_destroyed_structure_or_golem_count_this_turn(game_manager)
	var valid_friendly_targets := get_destroyable_friendly_cards(game_manager)
	var valid_enemy_targets := get_destroyable_enemy_cards(game_manager)
	var sanitized_friendly_targets: Array[Card] = []
	for card in friendly_targets:
		if card != null and card in valid_friendly_targets and card not in sanitized_friendly_targets:
			sanitized_friendly_targets.append(card)

	var sanitized_enemy_target: Card = enemy_target if enemy_target != null and enemy_target in valid_enemy_targets else null
	if sanitized_enemy_target == null and not valid_enemy_targets.is_empty():
		game_manager.note_player_feedback("Children of the Earth fizzles: an enemy structure or golem must be chosen.")
		return summoned_tokens

	var destroyed_now := 0
	for target in sanitized_friendly_targets:
		if game_manager._send_to_graveyard_with_hook(target, false, true):
			destroyed_now += 1
	if sanitized_enemy_target != null and game_manager._send_to_graveyard_with_hook(sanitized_enemy_target, false, true):
		destroyed_now += 1

	var destroyed_count := maxi(
		get_destroyed_structure_or_golem_count_this_turn(game_manager),
		destroyed_count_before + destroyed_now
	)
	summoned_tokens = summon_stone_infants(game_manager, destroyed_count)
	game_manager.note_player_feedback(
		"Children of the Earth destroyed %d card(s) and summoned %d Stone Infant token(s)." % [
			destroyed_now,
			summoned_tokens.size()
		]
	)
	return summoned_tokens

func get_destroyed_structure_or_golem_count_this_turn(game_manager: GameManager) -> int:
	if game_manager == null:
		return 0
	var count := 0
	for card in game_manager.died_this_turn:
		if _counts_as_structure_or_golem(card):
			count += 1
	return count

func summon_stone_infants(game_manager: GameManager, amount: int) -> Array[Card]:
	var summoned_tokens: Array[Card] = []
	if game_manager == null or card_owner == null or amount <= 0:
		return summoned_tokens
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(amount):
		var summon_zone := _find_open_summon_zone()
		if summon_zone == null:
			break
		var token := StoneInfant.new()
		token.card_owner = card_owner
		token.creature_mode = Card.CreatureMode.AGGRESSIVE
		token.reset_creature_action_state()
		token.summoned_this_turn = true
		token.is_face_down = false
		token.is_stealth = false
		token.art_path = _choose_stone_infant_art_path(game_manager, rng)
		token.wake_up()
		summon_zone.add_card(token)
		if game_manager.has_method("_apply_god_passives_to_card"):
			game_manager._apply_god_passives_to_card(card_owner, token)
		summoned_tokens.append(token)
	return summoned_tokens

func _choose_stone_infant_art_path(game_manager: GameManager, rng: RandomNumberGenerator) -> String:
	var usage: Dictionary = game_manager.get_meta(STONE_INFANT_ART_USAGE_META_KEY, {})
	var unused_paths: Array[String] = []
	for art_path in StoneInfant.TOKEN_ART_PATHS:
		if int(usage.get(art_path, 0)) <= 0:
			unused_paths.append(art_path)

	var candidate_paths: Array[String] = []
	if not unused_paths.is_empty():
		candidate_paths = unused_paths
	else:
		for art_path in StoneInfant.TOKEN_ART_PATHS:
			candidate_paths.append(art_path)

	if candidate_paths.is_empty():
		return ""

	var chosen_path: String = candidate_paths[rng.randi_range(0, candidate_paths.size() - 1)]
	usage[chosen_path] = int(usage.get(chosen_path, 0)) + 1
	game_manager.set_meta(STONE_INFANT_ART_USAGE_META_KEY, usage)
	return chosen_path

func _find_open_summon_zone() -> Zone:
	if card_owner == null:
		return null
	for zone in card_owner.frontline_zones:
		if zone.cards.is_empty():
			return zone
	for zone in card_owner.reserve_zones:
		if zone.cards.is_empty():
			return zone
	return null

func _is_destroyable_structure_or_golem(card: Card) -> bool:
	return card != null \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and not card.is_face_down \
		and _counts_as_structure_or_golem(card)

func _counts_as_structure_or_golem(card: Card) -> bool:
	return card != null \
		and (card.card_type == Card.CardType.STRUCTURE or card.has_type("Golem"))
