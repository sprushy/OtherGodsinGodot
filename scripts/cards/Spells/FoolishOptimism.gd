extends SpellCard
class_name FoolishOptimism

func _init() -> void:
	super._init()
	card_name = "Foolish Optimism"
	culture = "Neutral"
	card_types = ["Compulsion", "Attack"]
	level = 1
	mana_cost = 0
	speed = 1
	is_legendary = false
	sacrifice_cost = 0
	flavor_text = ""
	artist = "David Revoy"
	art_path = "res://images/card_art/hexes/foolish_optimism_crop.jpg"
	ability_text = "Force your opponent's lowest lvl face-up creature to attack your highest lvl face-up creature. Halve follower damage from that combat."

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null:
		return
	var resolution_text := _begin_resolution(game_manager)
	if resolution_text == "":
		return
	print(resolution_text)

func resolve_with_choices(game_manager: GameManager, attacker: Card, defender: Card) -> String:
	if game_manager == null:
		return card_name + " fizzles."
	if attacker == null:
		return "%s fizzles: no opposing creature to compel when it resolves." % card_name
	if defender == null:
		return "%s fizzles: no friendly creature to attack when it resolves." % card_name
	if attacker.current_zone == null or not attacker.current_zone.is_board_zone():
		return "%s fizzles: the chosen attacker is no longer on the field." % card_name
	if defender.current_zone == null or not defender.current_zone.is_board_zone():
		return "%s fizzles: the chosen defender is no longer on the field." % card_name
	if not _is_face_up_board_creature(attacker):
		return "%s fizzles: the chosen attacker is no longer a face-up creature on the field." % card_name
	if not _is_face_up_board_creature(defender):
		return "%s fizzles: the chosen defender is no longer a face-up creature on the field." % card_name
	if not _can_force_attack(game_manager, attacker, defender):
		return "%s fizzles: %s cannot legally attack %s." % [card_name, attacker.card_name, defender.card_name]

	var feedback := "%s compels %s to attack %s." % [card_name, attacker.card_name, defender.card_name]
	print(feedback)
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.source_player = attacker.get_controller()
	action.card = self
	action.attacker = attacker
	if attacker.has_method("get_united_front_partner_for_attack"):
		action.united_front_partner = attacker.get_united_front_partner_for_attack(game_manager)
	if attacker.has_method("get_united_front_attack_speed"):
		action.attack_speed_override = attacker.get_united_front_attack_speed(game_manager)
	action.target = defender
	action.halve_follower_damage = true
	game_manager.push_to_stack(action)
	return feedback

func finish_prompt_resolution(game_manager: GameManager, attacker: Card, defender: Card) -> String:
	var feedback := resolve_with_choices(game_manager, attacker, defender)
	send_to_graveyard_if_needed()
	return feedback

func send_to_graveyard_if_needed() -> void:
	if card_owner == null or current_zone == null:
		return
	if current_zone == card_owner.graveyard_zone:
		return
	card_owner.move_card(self, card_owner.graveyard_zone)

func get_forced_attacker_candidates(game_manager: GameManager) -> Array[Card]:
	var controller := _get_spell_controller(game_manager)
	var opponent := game_manager.get_opponent(controller) if game_manager != null and controller != null else null
	return _get_board_creatures(opponent)

func get_forced_defender_candidates(game_manager: GameManager) -> Array[Card]:
	var controller := _get_spell_controller(game_manager)
	return _get_board_creatures(controller)

func get_lowest_level_attacker_choices(game_manager: GameManager) -> Array[Card]:
	var candidates := get_forced_attacker_candidates(game_manager)
	if candidates.is_empty():
		return []
	var lowest_level := candidates[0].get_effective_level()
	for creature in candidates:
		lowest_level = mini(lowest_level, creature.get_effective_level())
	var ties: Array[Card] = []
	for creature in candidates:
		if creature.get_effective_level() == lowest_level:
			ties.append(creature)
	return ties

func get_highest_level_defender_choices(game_manager: GameManager) -> Array[Card]:
	var candidates := get_forced_defender_candidates(game_manager)
	if candidates.is_empty():
		return []
	var highest_level := candidates[0].get_effective_level()
	for creature in candidates:
		highest_level = maxi(highest_level, creature.get_effective_level())
	var ties: Array[Card] = []
	for creature in candidates:
		if creature.get_effective_level() == highest_level:
			ties.append(creature)
	return ties

func get_forced_attacker(game_manager: GameManager) -> Card:
	var choices := get_lowest_level_attacker_choices(game_manager)
	if choices.is_empty():
		return null
	return choices[0]

func get_forced_defender(game_manager: GameManager) -> Card:
	var choices := get_highest_level_defender_choices(game_manager)
	if choices.is_empty():
		return null
	return choices[0]

func _get_spell_controller(game_manager: GameManager) -> Player:
	if card_owner != null:
		return card_owner
	if game_manager != null:
		return game_manager.current_player
	return null

func _get_board_creatures(player: Player) -> Array[Card]:
	var creatures: Array[Card] = []
	if player == null:
		return creatures
	for zone in player.frontline_zones + player.reserve_zones:
		for card in zone.cards:
			if _is_face_up_board_creature(card):
				creatures.append(card)
	return creatures

func _is_face_up_board_creature(card: Card) -> bool:
	if card == null:
		return false
	if card.card_type != Card.CardType.CREATURE or card.is_god:
		return false
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return false
	if card.is_face_down or card.is_prepared or card.is_stealth:
		return false
	return true

func _pick_lowest_level_creature(candidates: Array[Card]) -> Card:
	var chosen: Card = null
	for creature in candidates:
		if chosen == null or creature.get_effective_level() < chosen.get_effective_level():
			chosen = creature
	return chosen

func _pick_highest_level_creature(candidates: Array[Card]) -> Card:
	var chosen: Card = null
	for creature in candidates:
		if chosen == null or creature.get_effective_level() > chosen.get_effective_level():
			chosen = creature
	return chosen

func _begin_resolution(game_manager: GameManager) -> String:
	var attacker_choices := get_lowest_level_attacker_choices(game_manager)
	if attacker_choices.is_empty():
		return "%s fizzles: no opposing creature to compel when it resolves." % card_name
	var defender_choices := get_highest_level_defender_choices(game_manager)
	if defender_choices.is_empty():
		return "%s fizzles: no friendly creature to attack when it resolves." % card_name

	if attacker_choices.size() > 1 or defender_choices.size() > 1:
		var attacker_uids: Array[String] = []
		for attacker in attacker_choices:
			if attacker != null:
				attacker_uids.append(attacker.uid)
		var defender_uids: Array[String] = []
		for defender in defender_choices:
			if defender != null:
				defender_uids.append(defender.uid)
		game_manager.decision_requested.emit(_get_spell_controller(game_manager), "foolish_optimism", {
			source_uid = uid,
			attacker_uids = attacker_uids,
			defender_uids = defender_uids,
		})
		return ""

	return resolve_with_choices(game_manager, attacker_choices[0], defender_choices[0])

func _can_force_attack(game_manager: GameManager, attacker: Card, defender: Card) -> bool:
	if game_manager == null or attacker == null or defender == null:
		return false
	var attacker_controller := attacker.get_controller()
	if attacker_controller == null:
		return false
	if game_manager.attack_restrictions.has(attacker_controller):
		return false
	if attacker.is_sleeping:
		return false
	if not attacker.get_status_effect("cannot_attack").is_empty():
		return false
	if attacker.current_zone == null or attacker.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		return false
	if attacker.has_method("can_engage") and not attacker.can_engage(defender):
		return false
	if defender.has_method("can_be_engaged_by") and not defender.can_be_engaged_by(attacker):
		return false
	return true

