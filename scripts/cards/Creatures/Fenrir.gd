extends CreatureCard
class_name Fenrir

const ART_PATH := "res://images/card_art/creatures/fenrir.jpg"
const ALT_ART_PATH := "res://images/card_art/creatures/fenrir_alt_art.png"
const DEVOUR_BUFF_SOURCE := "Fenrir Devour"

func _init() -> void:
	super._init()
	card_name = "Fenrir"
	card_types = ["Animal", "Lupine", "Norse Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 6
	is_legendary = true
	mana_cost = 0
	sacrifice_cost = 2
	speed = 2
	resilience = 20
	strength = 20
	targets = true
	ability_text = "[b]Wolf Master[/b]: [b]Shuffle[/b] this card from your hand. For your turn summon, you may summon a Lupine from your deck, paying its summon cost.\n[b]Devour[/b] ([b]Impact[/b]): Destroy a creature at least 2 levels weaker than this card and gain its Str and Res.\n[b]Sleep Immunity[/b]."
	culture = "Norse"
	artist = "Riccardo Zoppello"
	art_path = ART_PATH
	art_variants = [ART_PATH, ALT_ART_PATH]

const GOD_CONSUME_MANA_COST := 5

func is_immune_to_sleep() -> bool:
	return true

func can_activate(game_manager: GameManager) -> bool:
	if not is_god:
		return false
	if card_owner == null:
		return false
	if card_owner != game_manager.current_player:
		return false
	if card_owner.mana < GOD_CONSUME_MANA_COST:
		return false
	return true

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if not is_god:
		return card_name + " cannot activate right now."
	if card_owner == null:
		return card_name + " cannot activate right now."
	if card_owner != game_manager.current_player:
		return "It is not your turn to act."
	if card_owner.mana < GOD_CONSUME_MANA_COST:
		return card_name + " needs " + str(GOD_CONSUME_MANA_COST) + " mana to consume."
	return ""

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	if not card_owner.spend_mana(GOD_CONSUME_MANA_COST):
		game_manager.note_player_feedback(card_name + " needs " + str(GOD_CONSUME_MANA_COST) + " mana to consume.")
		return
	var devour_target: Card = target
	if devour_target == null:
		var valid := get_valid_devour_targets(game_manager)
		if not valid.is_empty():
			devour_target = valid[0]
	if devour_target != null:
		resolve_devour_impact(game_manager, devour_target)

func get_hand_ability_label() -> String:
	return "Wolf Master"

func can_use_hand_ability(game_manager: GameManager) -> bool:
	if game_manager == null or card_owner == null:
		return false
	if current_zone != card_owner.hand_zone:
		return false
	if card_owner != game_manager.current_player:
		return false
	if card_owner.has_summoned_this_turn:
		return false
	if _get_open_summon_zones().is_empty():
		return false
	return not get_valid_wolf_master_summons_after_shuffle(game_manager).is_empty()

func get_hand_ability_unavailable_reason(game_manager: GameManager) -> String:
	if game_manager == null or card_owner == null:
		return "No active game."
	if current_zone != card_owner.hand_zone:
		return card_name + " must be in your hand."
	if card_owner != game_manager.current_player:
		return "Wait for your turn."
	if card_owner.has_summoned_this_turn:
		return "You have already used your normal summon this turn."
	if _get_open_summon_zones().is_empty():
		return "No empty friendly zone available."
	if get_valid_wolf_master_summons_after_shuffle(game_manager).is_empty():
		return "No payable Lupine in your deck."
	return ""

func perform_wolf_master_shuffle() -> bool:
	if card_owner == null:
		return false
	return card_owner.shuffle_card_into_deck(self)

func get_valid_wolf_master_summons(game_manager: GameManager = null) -> Array[Card]:
	var valid_cards: Array[Card] = []
	if card_owner == null:
		return valid_cards
	for card in card_owner.deck_zone.cards:
		if _is_valid_lupine(card) and _can_pay_wolf_master_cost_for(card, game_manager):
			valid_cards.append(card)
	return valid_cards

func get_valid_wolf_master_summons_after_shuffle(game_manager: GameManager = null) -> Array[Card]:
	if card_owner == null:
		return []
	if current_zone == card_owner.deck_zone:
		return get_valid_wolf_master_summons(game_manager)
	var valid_cards := get_valid_wolf_master_summons(game_manager)
	if _is_valid_lupine(self) and current_zone == card_owner.hand_zone and self not in valid_cards and _can_pay_wolf_master_cost_for(self, game_manager):
		valid_cards.append(self)
	return valid_cards

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_devour_targets(game_manager)
	if valid_targets.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("%s found no creature weak enough to devour." % card_name)
		return
	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(get_controller(), "fenrir_devour_impact", {
		"source_uid": uid,
		"target_uids": target_uids,
		"queue_with_priority": true,
		"event_name": "fenrir_devour_impact",
	})

func get_valid_devour_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _is_valid_devour_target(card):
					valid_targets.append(card)
	return valid_targets

func get_devour_target_failure_reason(target: Card) -> String:
	if target == null:
		return card_name + ": click a creature to devour."
	if target == self:
		return card_name + " cannot devour itself."
	if target.card_type != Card.CardType.CREATURE:
		return card_name + " can only devour creatures."
	if target.current_zone == null or not target.current_zone.is_board_zone():
		return target.card_name + " must be on the field to be devoured."
	var max_target_level := get_effective_level() - 2
	if target.get_effective_level() > max_target_level:
		return "%s is level %d. %s can only devour level %d or lower." % [
			target.card_name,
			target.get_effective_level(),
			card_name,
			max_target_level
		]
	return card_name + " cannot devour " + target.card_name + "."

var consumed_cards: Array[Card] = []

func has_sheltered_cards() -> bool:
	return not consumed_cards.is_empty()

func get_sheltered_cards_for_passive_effects() -> Array[Card]:
	return consumed_cards.duplicate()

func resolve_devour_impact(game_manager: GameManager, target: Card, continue_callback: Callable = Callable()) -> void:
	if game_manager == null:
		_emit_devour_result(continue_callback, card_name + " cannot devour right now.")
		return
	var valid_targets := get_valid_devour_targets(game_manager)
	if target == null or target not in valid_targets:
		_emit_devour_result(continue_callback, card_name + " found no creature weak enough to devour.")
		return
	if game_manager.is_guardian_protected(target, self):
		_emit_devour_result(continue_callback, target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is protected by Guardian!")
		return
	if game_manager.is_immune_to_source(target, self):
		_emit_devour_result(continue_callback, target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is immune to " + card_name + "'s creature abilities this turn.")
		return
	if is_god:
		var viewer := game_manager.get_feedback_viewer()
		var devoured_name := target.get_target_log_display_name(viewer)
		consumed_cards.append(target)
		game_manager.remove_card_from_game_with_hook(target)
		_emit_devour_result(continue_callback, "%s consumes %s under him." % [card_name, devoured_name])
		return

	var viewer := game_manager.get_feedback_viewer()
	var devoured_name := target.get_target_log_display_name(viewer)
	var gained_strength := target.get_effective_strength()
	var gained_resilience := target.get_effective_resilience()
	game_manager.request_send_to_graveyard(target, func() -> void:
		var destroyed := game_manager.reached_public_destroyed_destination(target)
		if destroyed:
			var resolved_name := game_manager.get_resolved_destruction_log_name(target, viewer, devoured_name)
			add_buff(DEVOUR_BUFF_SOURCE, gained_strength, gained_resilience, 0, self, card_owner, "fenrir_devour")
			_emit_devour_result(
				continue_callback,
				"%s devoured %s and gained %d Str and %d Res." % [
					card_name,
					resolved_name,
					gained_strength,
					gained_resilience
				]
			)
		else:
			_emit_devour_result(continue_callback, "%s could not devour %s." % [card_name, devoured_name])
	, false, true)

func _is_valid_lupine(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.has_type("Lupine")

func _is_valid_devour_target(card: Card) -> bool:
	return card != null \
		and card != self \
		and card.card_type == Card.CardType.CREATURE \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and (is_god or card.get_effective_level() <= get_effective_level() - 2)

func _get_open_summon_zones() -> Array[Zone]:
	var open_zones: Array[Zone] = []
	if card_owner == null:
		return open_zones
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		if zone.cards.is_empty():
			open_zones.append(zone)
	return open_zones

func _can_pay_wolf_master_cost_for(card: Card, game_manager: GameManager) -> bool:
	if card_owner == null or card == null:
		return false
	if game_manager == null:
		return true
	return game_manager.can_pay_creature_summon_cost(card_owner, card, self, true)

func _emit_devour_result(callback: Callable, feedback: String) -> void:
	if callback.is_valid():
		callback.call(feedback)

func get_hover_detail_lines(viewer: Player = null) -> Array[String]:
	var details := super.get_hover_detail_lines(viewer)
	if consumed_cards.is_empty():
		return details
	details.append("Cards underneath:")
	for c in consumed_cards:
		if c == null:
			continue
		var line := "- " + c.card_name
		var ability_summary := c.get_inline_ability_summary()
		if ability_summary != "":
			line += " - " + ability_summary
		details.append(line)
	return details
