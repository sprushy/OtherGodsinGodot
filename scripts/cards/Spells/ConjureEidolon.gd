extends SpellCard
class_name ConjureEidolon

func _init() -> void:
	super._init()
	card_name = "Conjure Eidolon"
	culture = "Olympic"
	card_types = ["Summon Creature", "Targeting"]
	level = 3
	mana_cost = 1
	targets = true
	artist = "User provided"
	art_path = "res://images/card_art/spells/conjure_eidolon.png"
	ability_text = "Summon a token copy of a non-Spirit creature you control. [b]Silence[/b] it, add [b]Spirit[/b] to its types, and append Eidolon to its name. Destroy it after it participates in combat."

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if get_open_summon_zone() == null:
		return valid_targets
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if is_valid_target(card, game_manager):
				valid_targets.append(card)
	return valid_targets

func is_valid_target(target: Card, game_manager: GameManager) -> bool:
	return target != null \
		and card_owner != null \
		and target.card_type == Card.CardType.CREATURE \
		and not target.is_god \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.get_controller() == card_owner \
		and not target.has_type("Spirit") \
		and not game_manager.is_immune_to_source(target, self)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	return super.can_be_played(game_manager, player) and not get_valid_targets(game_manager).is_empty()

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	var base_reason := super.get_play_failure_reason(game_manager, player)
	if not base_reason.is_empty():
		return base_reason
	if get_open_summon_zone() == null:
		return card_name + " needs an open zone for the Eidolon."
	if get_valid_targets(game_manager).is_empty():
		return card_name + " needs a non-Spirit creature you control."
	return ""

func resolve(game_manager: GameManager, target = null) -> void:
	if game_manager == null:
		return
	var creature := target as Card
	if not is_valid_target(creature, game_manager):
		game_manager.note_player_feedback("Conjure Eidolon fizzles because its target is no longer valid.")
		return
	var summon_zone := get_open_summon_zone()
	if summon_zone == null:
		game_manager.note_player_feedback("Conjure Eidolon fizzles because there is no open summon zone.")
		return

	var eidolon := create_eidolon(creature)
	if game_manager.summon_creature_by_effect(
		card_owner, eidolon, summon_zone, Card.CreatureMode.AGGRESSIVE,
		false, false, self, false, false, false
	):
		game_manager.note_player_feedback("Conjure Eidolon summons %s." % eidolon.card_name)
	else:
		game_manager.note_player_feedback("Conjure Eidolon could not summon the token.")

func create_eidolon(creature: Card) -> CreatureCard:
	var eidolon := CreatureCard.new()
	eidolon.card_owner = card_owner
	eidolon.card_name = creature.card_name + " Eidolon"
	eidolon.card_types = creature.card_types.duplicate()
	for type_name in ["Spirit", "Token"]:
		if type_name not in eidolon.card_types:
			eidolon.card_types.append(type_name)
	eidolon.is_token = true
	eidolon.is_legendary = creature.is_legendary
	eidolon.culture = creature.culture
	eidolon.level = creature.level
	eidolon.mana_cost = creature.mana_cost
	eidolon.sacrifice_cost = creature.sacrifice_cost
	eidolon.can_be_used_for_creature_sacrifice = creature.can_be_used_for_creature_sacrifice
	eidolon.strength = creature.strength
	eidolon.resilience = creature.resilience
	eidolon.speed = creature.speed
	eidolon.art_path = creature.art_path
	eidolon.artist = creature.artist
	eidolon.ability_text = creature.ability_text
	eidolon.flavor_text = creature.flavor_text
	eidolon.mute_permanently()
	eidolon.add_status_effect(Card.DESTROY_AFTER_COMBAT_STATUS, card_name, self, card_owner, {"allow_while_negated": true})
	return eidolon

func get_open_summon_zone() -> Zone:
	if card_owner != null:
		for zone in card_owner.frontline_zones + card_owner.reserve_zones:
			if zone.cards.is_empty():
				return zone
	return null
