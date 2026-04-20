extends PowerCard
class_name HuntingTactics

const UNLOCK_COST := 5
const ATTACK_BUFF_SOURCE := "Hunting Tactics"
const ATTACK_BUFF_EFFECT_TYPE := "hunting_tactics_attack_buff"
const CANNOT_ATTACK_STATUS := "cannot_attack"
const ART_PATH := "res://images/card_art/HuntingTacticsEdit.png"

func _init() -> void:
	super._init()
	card_name = "Hunting Tactics"
	culture = "Norse"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Battle Modifier"]
	ability_text = "If a friendly Lupine or Norse Human Warrior attacks, you may increase its Spd and Str by those of friendly Ravens; a Norse Human Warrior may also increase its Str by those of friendly Lupines. Creatures selected by these effects cannot attack this turn."
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func on_creature_enters_combat(game_manager: GameManager, attacker: Card, _defender: Card) -> void:
	if game_manager == null or attacker == null:
		return
	if not is_effectively_active():
		return
	if attacker.get_controller() != card_owner:
		return
	if not _is_hunting_tactics_attacker(attacker):
		return

	var default_supporters := get_support_choices(attacker)
	if default_supporters.is_empty():
		return
	var supporter_uids: Array[String] = []
	for supporter in default_supporters:
		if supporter != null:
			supporter_uids.append(supporter.uid)
	game_manager.decision_requested.emit(card_owner, "hunting_tactics", {
		source_uid = uid,
		attacker_uid = attacker.uid,
		target_uids = supporter_uids,
	})

func get_support_choices(attacker: Card) -> Array[Card]:
	var supporters: Array[Card] = []
	if attacker == null:
		return supporters
	for supporter in _get_friendly_ravens(attacker):
		if supporter not in supporters:
			supporters.append(supporter)
	if _is_norse_human_warrior(attacker):
		for supporter in _get_friendly_lupines(attacker):
			if supporter not in supporters:
				supporters.append(supporter)
	return supporters

func resolve_combat_support_choice(game_manager: GameManager, attacker: Card, chosen_supporters: Array[Card]) -> String:
	if game_manager == null:
		return card_name + " cannot resolve right now."
	if attacker == null:
		return card_name + " fizzles: the attacker is gone."
	if attacker.current_zone == null or not attacker.current_zone.is_board_zone():
		return "%s fizzles: %s is no longer on the field." % [card_name, attacker.card_name]
	if attacker.get_controller() != card_owner:
		return "%s fizzles: %s is no longer controlled by %s." % [card_name, attacker.card_name, card_owner.player_name if card_owner != null else "its owner"]

	var current_supporters := get_support_choices(attacker)
	var selected_supporters: Array[Card] = []
	for supporter in chosen_supporters:
		if supporter != null and supporter in current_supporters and supporter not in selected_supporters:
			selected_supporters.append(supporter)

	attacker.remove_buffs_from_source_card(self, ATTACK_BUFF_EFFECT_TYPE)

	if selected_supporters.is_empty():
		return "%s declined to support %s." % [card_name, attacker.get_target_log_display_name(game_manager.get_feedback_viewer())]

	var str_bonus := 0
	var spd_bonus := 0
	for supporter in selected_supporters:
		if supporter.has_type("Raven"):
			str_bonus += supporter.get_effective_strength()
			spd_bonus += supporter.get_effective_speed()
		elif supporter.has_type("Lupine") and _is_norse_human_warrior(attacker):
			str_bonus += supporter.get_effective_strength()

	if str_bonus == 0 and spd_bonus == 0:
		return "%s found no useful support for %s." % [card_name, attacker.get_target_log_display_name(game_manager.get_feedback_viewer())]

	attacker.add_buff(
		ATTACK_BUFF_SOURCE,
		str_bonus,
		0,
		spd_bonus,
		self,
		card_owner,
		ATTACK_BUFF_EFFECT_TYPE,
		{"expires_after_combat": true}
	)

	for supporter in selected_supporters:
		supporter.remove_status_effects_from_source_card(self, CANNOT_ATTACK_STATUS)
		supporter.add_status_effect(
			CANNOT_ATTACK_STATUS,
			card_name,
			self,
			card_owner,
			{"expires_turn": game_manager.turn_number}
		)

	var parts: Array[String] = []
	if str_bonus != 0:
		parts.append("STR %+d" % str_bonus)
	if spd_bonus != 0:
		parts.append("SPD %+d" % spd_bonus)
	var supporter_names: Array[String] = []
	for supporter in selected_supporters:
		supporter_names.append(supporter.get_target_log_display_name(game_manager.get_feedback_viewer()))
	return "%s grants %s %s using %s. Selected supporters cannot attack this turn." % [
		card_name,
		attacker.get_target_log_display_name(game_manager.get_feedback_viewer()),
		", ".join(parts),
		", ".join(supporter_names)
	]

func _is_hunting_tactics_attacker(card: Card) -> bool:
	return card != null and (_is_friendly_lupine(card) or _is_norse_human_warrior(card))

func _is_friendly_lupine(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.get_controller() == card_owner \
		and card.has_type("Lupine")

func _is_norse_human_warrior(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.get_controller() == card_owner \
		and card.has_type("Human") \
		and card.has_type("Warrior") \
		and (card.has_type("Norse Creature") or card.culture == "Norse")

func _get_friendly_ravens(attacker: Card) -> Array[Card]:
	var supporters: Array[Card] = []
	if card_owner == null:
		return supporters
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if card == null or card == attacker:
				continue
			if card.card_type != Card.CardType.CREATURE:
				continue
			if card.get_controller() != card_owner:
				continue
			if not card.has_type("Raven"):
				continue
			supporters.append(card)
	return supporters

func _get_friendly_lupines(attacker: Card) -> Array[Card]:
	var supporters: Array[Card] = []
	if card_owner == null:
		return supporters
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if card == null or card == attacker:
				continue
			if not _is_friendly_lupine(card):
				continue
			supporters.append(card)
	return supporters

