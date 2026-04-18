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
	art_path = "res://images/card_art/spells/DeucalionsInfants.png"
	ability_text = "Children of the Earth: You may destroy any number of your structures and Golems. Then your opponent destroys 1 of theirs. Summon a [b]Stone Infant[/b] token for each structure or Golem destroyed this turn."

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	var choice_uids: Array = command.get("choices", [])
	var friendly_targets: Array[Card] = []
	for choice_uid in choice_uids:
		var c := game_manager.get_card_by_uid(choice_uid as String)
		if c != null:
			friendly_targets.append(c)
	var enemy_uid: String = command.get("enemy_target_uid", "")
	var enemy_target: Card = game_manager.get_card_by_uid(enemy_uid) if enemy_uid != "" else null
	resolve_with_choices(game_manager, friendly_targets, enemy_target)

func resolve(game_manager: GameManager, target = null) -> void:
	if target is Dictionary:
		var friendly_targets: Array[Card] = []
		var raw_friendly_targets: Array = target.get("friendly_targets", [])
		for card in raw_friendly_targets:
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
	var opponent: Player = game_manager.get_opponent(card_owner)
	if opponent == null:
		return cards
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if _is_destroyable_structure_or_golem(card) and card.get_controller() == opponent:
				cards.append(card)
	return cards

func resolve_with_choices(game_manager: GameManager, friendly_targets: Array[Card], enemy_target: Card = null, continue_callback: Callable = Callable()) -> Array[Card]:
	var summoned_tokens: Array[Card] = []
	if game_manager == null or card_owner == null:
		return summoned_tokens

	var destroyed_count_before: int = get_destroyed_structure_or_golem_count_this_turn(game_manager)
	var valid_friendly_targets: Array[Card] = get_destroyable_friendly_cards(game_manager)
	var valid_enemy_targets: Array[Card] = get_destroyable_enemy_cards(game_manager)
	var sanitized_friendly_targets: Array[Card] = []
	for card: Card in friendly_targets:
		if card != null and card in valid_friendly_targets and card not in sanitized_friendly_targets:
			sanitized_friendly_targets.append(card)

	var sanitized_enemy_target: Card = enemy_target if enemy_target != null and enemy_target in valid_enemy_targets else null
	if sanitized_enemy_target == null and not valid_enemy_targets.is_empty():
		game_manager.note_player_feedback("Children of the Earth fizzles: an enemy structure or golem must be chosen.")
		if continue_callback.is_valid():
			continue_callback.call()
		return summoned_tokens

	var destruction_queue: Array[Card] = sanitized_friendly_targets.duplicate()
	if sanitized_enemy_target != null:
		destruction_queue.append(sanitized_enemy_target)
	_resolve_destruction_queue(game_manager, destruction_queue, destroyed_count_before, 0, continue_callback)
	return summoned_tokens

func _resolve_destruction_queue(game_manager: GameManager, destruction_queue: Array[Card], destroyed_count_before: int, destroyed_now: int = 0, continue_callback: Callable = Callable()) -> void:
	if game_manager == null:
		if continue_callback.is_valid():
			continue_callback.call()
		return
	if destruction_queue.is_empty():
		var destroyed_count: int = maxi(
			get_destroyed_structure_or_golem_count_this_turn(game_manager),
			destroyed_count_before + destroyed_now
		)
		var summoned_tokens: Array[Card] = summon_stone_infants(game_manager, destroyed_count)
		game_manager.note_player_feedback(
			"Children of the Earth destroyed %d card(s) and summoned %d Stone Infant token(s)." % [
				destroyed_now,
				summoned_tokens.size()
			]
		)
		if continue_callback.is_valid():
			continue_callback.call()
		return
	var next_queue: Array[Card] = destruction_queue.duplicate()
	var target: Card = next_queue.pop_front()
	game_manager.request_send_to_graveyard(target, func() -> void:
		var next_destroyed_now: int = destroyed_now
		if target.current_zone == target.card_owner.graveyard_zone or target.current_zone == target.card_owner.abyss_zone:
			next_destroyed_now += 1
		_resolve_destruction_queue(game_manager, next_queue, destroyed_count_before, next_destroyed_now, continue_callback)
	, false, true)

func get_destroyed_structure_or_golem_count_this_turn(game_manager: GameManager) -> int:
	if game_manager == null:
		return 0
	var count: int = 0
	for card: Card in game_manager.died_this_turn:
		if _counts_as_structure_or_golem(card):
			count += 1
	return count

func summon_stone_infants(game_manager: GameManager, amount: int) -> Array[Card]:
	var summoned_tokens: Array[Card] = []
	if game_manager == null or card_owner == null or amount <= 0:
		return summoned_tokens
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(amount):
		var summon_zone: Zone = _find_open_summon_zone()
		if summon_zone == null:
			break
		var token: Card = StoneInfant.new()
		token.card_owner = card_owner
		token.art_path = _choose_stone_infant_art_path(game_manager, rng)
		if game_manager.summon_creature_by_effect(
			card_owner,
			token,
			summon_zone,
			Card.CreatureMode.AGGRESSIVE,
			false,
			false,
			self,
			false,
			false,
			false
		):
			summoned_tokens.append(token)
	return summoned_tokens

func _choose_stone_infant_art_path(game_manager: GameManager, rng: RandomNumberGenerator) -> String:
	var usage: Dictionary = game_manager.get_meta(STONE_INFANT_ART_USAGE_META_KEY, {})
	var unused_paths: Array[String] = []
	for token_art_path: String in StoneInfant.TOKEN_ART_PATHS:
		if int(usage.get(token_art_path, 0)) <= 0:
			unused_paths.append(token_art_path)

	var candidate_paths: Array[String] = []
	if not unused_paths.is_empty():
		candidate_paths = unused_paths
	else:
		for token_art_path: String in StoneInfant.TOKEN_ART_PATHS:
			candidate_paths.append(token_art_path)

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
