extends HexCard
class_name ErisBattleCry

const ART_PATH := "res://images/card_art/hexes/ErisBattleCry.png"

func _init() -> void:
	super._init()
	card_name = "Eris' Battle Cry"
	level = 2
	mana_cost = 0
	speed = 3
	culture = "Olympic"
	card_types = ["Compulsion", "Attack"]
	ability_text = "Switch all of your opponent's face-up creatures to Aggressive stance. They each attack, one at a time starting with the fastest (ties: front line slot 1 first). For each attack, that creature's controller chooses a legal target."
	flavor_text = ""
	artist = ""
	art_path = ART_PATH
	targets = false

func can_respond_to_action(_action: CardAction) -> bool:
	return true

func can_activate_prepared(game_manager: GameManager, player: Player) -> bool:
	if game_manager == null or player == null:
		return false
	if player != game_manager.current_player:
		return false
	if card_owner != null and player != card_owner:
		return false
	if not is_prepared:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if not game_manager.action_stack.is_empty():
		return false
	if game_manager.prepared_hexes.get(self, game_manager.turn_number) >= game_manager.turn_number:
		return false
	if is_activation_locked(game_manager):
		return false
	if not game_manager.can_pay_prepared_card_activation_cost(self, player):
		return false
	return true

func on_activate_action(game_manager: GameManager, _action: CardAction) -> void:
	if game_manager == null:
		if card_owner != null:
			card_owner.move_card(self, card_owner.graveyard_zone)
		return

	var controller := card_owner if card_owner != null else game_manager.current_player
	var opponent := game_manager.get_opponent(controller)
	if opponent == null:
		game_manager.note_player_feedback("%s fizzles: no opponent." % card_name)
		_send_self_to_graveyard(game_manager)
		return

	var switched := _switch_creatures_to_aggressive(game_manager, opponent)
	var attackers := get_compelled_attackers(game_manager, opponent)
	_push_compelled_attacks(game_manager, attackers)

	if attackers.is_empty():
		if switched > 0:
			game_manager.note_player_feedback(
				"%s switches %d creature(s) to Aggressive stance, but none of them can attack." % [card_name, switched]
			)
		else:
			game_manager.note_player_feedback(
				"%s triggers, but %s has no creatures to switch or compel." % [card_name, opponent.player_name]
			)
	else:
		var attacker_names: Array[String] = []
		for attacker in attackers:
			attacker_names.append(attacker.get_target_log_display_name(game_manager.get_feedback_viewer()))
		game_manager.note_player_feedback(
			"%s switches %d creature(s) to Aggressive stance and compels %s to attack, starting with the fastest." % [
				card_name,
				switched,
				", ".join(attacker_names),
			]
		)

	_send_self_to_graveyard(game_manager)

func _switch_creatures_to_aggressive(game_manager: GameManager, opponent: Player) -> int:
	var switched := 0
	if game_manager == null or opponent == null:
		return switched
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		if zone == null:
			continue
		for card in zone.cards:
			if not _is_face_up_creature(card):
				continue
			if card.creature_mode == Card.CreatureMode.AGGRESSIVE:
				continue
			card.creature_mode = Card.CreatureMode.AGGRESSIVE
			card._emit_visual_state_changed()
			switched += 1
	return switched

# Creatures currently able to make a declared attack when the hex resolves.
# The stack re-checks every attacker when each attack actually resolves, so
# responses that move or disable a creature after this still fizzle safely.
func get_compelled_attackers(game_manager: GameManager, opponent: Player) -> Array[Card]:
	var attackers: Array[Card] = []
	if game_manager == null or opponent == null:
		return attackers
	for zone in opponent.frontline_zones:
		if zone == null:
			continue
		for card in zone.cards:
			if _can_compelled_attack_now(game_manager, card):
				attackers.append(card)
	# United Front partners ride along on their partner's attack action, so a
	# creature that would attack twice only keeps its own attack if no partner
	# claims it first.
	var partnered: Array[Card] = []
	for attacker in attackers:
		var partner := _get_united_front_partner(game_manager, attacker)
		if partner != null and partner != attacker and partner in attackers and partner not in partnered:
			partnered.append(partner)
	var final_attackers: Array[Card] = []
	for attacker in attackers:
		if attacker in partnered:
			continue
		final_attackers.append(attacker)
	# Fastest first; ties break toward the lower front line slot (1 before 5).
	final_attackers.sort_custom(func(a: Card, b: Card) -> bool:
		var a_speed := _get_declared_attack_speed(game_manager, a)
		var b_speed := _get_declared_attack_speed(game_manager, b)
		if a_speed != b_speed:
			return a_speed > b_speed
		var a_slot := a.current_zone.zone_index if a.current_zone != null else 0
		var b_slot := b.current_zone.zone_index if b.current_zone != null else 0
		return a_slot < b_slot
	)
	return final_attackers

# One compelled-attack stack action, exactly as the engine resolves it. The
# bot's planning uses the same builder so its projection cannot drift from
# the real speed, partner, and source attribution.
func build_compelled_attack_action(game_manager: GameManager, attacker: Card) -> CardAction:
	if game_manager == null or attacker == null or not is_instance_valid(attacker):
		return null
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.source_player = attacker.get_controller()
	action.card = self
	action.attacker = attacker
	action.united_front_partner = _get_united_front_partner(game_manager, attacker)
	action.attack_speed_override = _get_declared_attack_speed(game_manager, attacker)
	action.target = null
	action.event_data = {"compelled_attack": true}
	return action

func _push_compelled_attacks(game_manager: GameManager, attackers: Array[Card]) -> void:
	if game_manager == null:
		return
	# The stack resolves last-pushed first, so push slowest first to make the
	# fastest compelled attack resolve first.
	var index := attackers.size() - 1
	while index >= 0:
		var attacker := attackers[index]
		index -= 1
		if attacker == null or not is_instance_valid(attacker):
			continue
		var action := build_compelled_attack_action(game_manager, attacker)
		if action != null:
			game_manager.push_to_stack(action)

# Legal targets for one compelled attack at the moment it resolves: enemy
# creatures/structures the attacker can legally engage, plus the defending
# player's followers when no structure blocks that attack.
func get_compelled_attack_target_candidates(game_manager: GameManager, attacker: Card) -> Array:
	var candidates: Array = []
	if game_manager == null or attacker == null or not is_instance_valid(attacker):
		return candidates
	var controller := attacker.get_controller()
	if controller == null:
		return candidates
	var defending_player := game_manager.get_opponent(controller)
	if defending_player == null:
		return candidates
	for zone in defending_player.frontline_zones + defending_player.reserve_zones:
		if zone == null:
			continue
		for card in zone.cards:
			if not _is_direct_attack_target(card):
				continue
			if card.current_zone == null or not card.current_zone.is_board_zone():
				continue
			if game_manager.is_attack_blocked_by_active_structure(attacker, card):
				continue
			if game_manager.can_cards_engage_each_other(attacker, card):
				candidates.append(card)
	if not game_manager.is_followers_attack_blocked_by_active_structure(attacker, defending_player):
		candidates.append(defending_player)
	return candidates

func _can_compelled_attack_now(game_manager: GameManager, creature: Card) -> bool:
	if game_manager == null or creature == null or not is_instance_valid(creature):
		return false
	if creature.card_type != Card.CardType.CREATURE or creature.is_god:
		return false
	if creature.current_zone == null or creature.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		return false
	if creature.is_face_down or creature.is_stealth or creature.is_prepared:
		return false
	if creature.is_sleeping or creature.is_paralyzed():
		return false
	if not creature.get_status_effect("cannot_attack").is_empty():
		return false
	if creature.summoned_after_first_attack_this_turn:
		return false
	if not creature.can_take_major_creature_action():
		return false
	if game_manager.turn_number <= 1:
		return false
	if game_manager.is_first_turn_attack_blocked_by_weather(creature):
		return false
	var controller := creature.get_controller()
	if controller == null or game_manager.attack_restrictions.has(controller):
		return false
	if not game_manager.can_pay_creature_action_mana_cost(creature, "attack"):
		return false
	return true

func _is_face_up_creature(card: Card) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	if card.card_type != Card.CardType.CREATURE:
		return false
	if card.is_face_down or card.is_stealth or card.is_prepared:
		return false
	return card.current_zone != null and card.current_zone.is_board_zone()

func _is_direct_attack_target(card: Card) -> bool:
	if card == null:
		return false
	if card.card_type == Card.CardType.CREATURE or card.card_type == Card.CardType.STRUCTURE:
		return true
	return card.card_type == Card.CardType.EQUIPMENT and card.equipped_on == null

func _get_united_front_partner(game_manager: GameManager, attacker: Card) -> Card:
	if attacker == null or not attacker.has_method("get_united_front_partner_for_attack"):
		return null
	return attacker.get_united_front_partner_for_attack(game_manager)

func _get_declared_attack_speed(game_manager: GameManager, attacker: Card) -> int:
	if attacker == null:
		return 0
	if attacker.has_method("get_united_front_attack_speed"):
		return int(attacker.get_united_front_attack_speed(game_manager))
	return attacker.get_effective_speed()

func _send_self_to_graveyard(game_manager: GameManager) -> void:
	if game_manager != null and card_owner != null:
		game_manager.request_send_to_graveyard(self)
	elif card_owner != null:
		card_owner.move_card(self, card_owner.graveyard_zone)
