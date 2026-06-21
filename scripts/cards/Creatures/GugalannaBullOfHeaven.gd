extends CreatureCard
class_name GugalannaBullOfHeaven

const MIN_RES_TARGET := 30

func _init() -> void:
	super._init()
	card_name = "Gugalanna, Bull of Heaven"
	card_types = ["Divine Manifestation", "Animal", "Taurine", "Ancient Creature", "Targeting"]
	level = 4
	mana_cost = 3
	sacrifice_cost = 0
	speed = 3
	resilience = 25
	strength = 25
	ability_text = "Celestial Charge ([b]Impact[/b]): You may destroy a slower creature or structure with 30+ RES. If you do, your opponent may activate hexes that normally require an attack in response. Return this to your hand."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricarrdo Zoppello"
	art_path = "res://images/card_art/creatures/gugalanna_bull_of_heaven.png"

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_impact_targets(game_manager)
	if valid_targets.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("%s: no valid targets for Celestial Charge. %s stays on field." % [card_name, card_name])
		return
	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(get_controller(), "gugalanna_celestial_charge", {
		"source_uid": uid,
		"target_uids": target_uids,
		"queue_with_priority": true,
		"event_name": "gugalanna_celestial_charge",
	})

# Called by the prompt host after the player makes their choice.
# Pass null as target if the player declines to destroy anything.
func apply_celestial_charge(game_manager: GameManager, target: Card) -> void:
	if game_manager == null:
		return

	if target != null and _is_valid_target(target):
		# Allow attack hexes to trigger with Gugalanna as the "attacker".
		game_manager.check_and_trigger_hexes(self, target)

		# Destroy target if still on the board.
		if target.current_zone != null and target.current_zone.is_board_zone():
			game_manager.request_send_to_graveyard(target, Callable(), false, true)
			game_manager.note_player_feedback(
				"Celestial Charge: %s destroys %s." % [card_name, target.card_name]
			)
	else:
		game_manager.note_player_feedback("%s: Celestial Charge skipped." % card_name)
		return

	# Return to hand after destroying a target.
	_return_to_hand(game_manager)

func get_valid_impact_targets(game_manager: GameManager) -> Array[Card]:
	var valid: Array[Card] = []
	if game_manager == null:
		return valid
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _is_valid_target(card):
					valid.append(card)
	return valid

func _is_valid_target(target: Card) -> bool:
	return target != null \
		and (target.card_type == Card.CardType.CREATURE or target.card_type == Card.CardType.STRUCTURE) \
		and target.get_effective_resilience() >= MIN_RES_TARGET \
		and target.get_effective_speed() < get_effective_speed() \
		and target.current_zone != null \
		and target.current_zone.is_board_zone()

func _return_to_hand(game_manager: GameManager) -> void:
	if current_zone == null or not current_zone.is_board_zone():
		return
	var owner := card_owner
	if owner == null:
		return
	if game_manager != null:
		game_manager.note_player_feedback("%s returns to hand." % card_name)
	owner.move_card(self, owner.hand_zone)

