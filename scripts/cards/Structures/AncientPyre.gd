extends StructureCard
class_name AncientPyre

func _init() -> void:
	super._init()
	card_name = "Ancient Pyre"
	card_types = ["Ancient", "Altar"]
	level = 2
	mana_cost = 0
	resilience = 20
	speed = 0
	strength = 0
	sacrifice_cost = 0
	ability_text = "Ritual Flame ([b]Activate[/b], Cost 2): [b]Convert[/b] 5. [b]Frontlined[/b]: You may instead reduce a creature's Res by 5; if it reaches 0, destroy it."
	culture = "Ancient"
	art_path = "res://images/card_art/structures/ancient_pyre.jpg"

func is_frontline() -> bool:
	return current_zone != null and current_zone.zone_type == Zone.ZoneType.FRONTLINE

func can_activate(game_manager: GameManager) -> bool:
	if card_owner != game_manager.current_player:
		return false
	if card_owner.mana < 2:
		return false
	var opponent := game_manager.get_opponent(card_owner)
	if is_frontline():
		return not get_valid_targets(game_manager).is_empty() or (opponent != null and opponent.followers > 0)
	return opponent != null and opponent.followers > 0

# target is required when on the frontline unless the caller explicitly chooses Convert.
func activate(game_manager: GameManager, target = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("Ancient Pyre cannot activate right now.")
		return
	var force_convert := false
	var target_card: Card = null
	if target is Dictionary:
		force_convert = str((target as Dictionary).get("mode", "")).strip_edges() == "convert"
	elif target is Card:
		target_card = target as Card
	card_owner.spend_mana(2)
	var opponent := game_manager.get_opponent(card_owner)
	if force_convert or not is_frontline() or (target_card != null and target_card.is_god):
		game_manager.convert_followers(opponent, card_owner, 5)
		print("Ancient Pyre: Ritual Flame converts 5 followers from " + opponent.player_name + ".")
		return
	if target_card == null:
		print("Ancient Pyre: No target selected.")
		card_owner.gain_mana(2)
		return
	if not is_valid_activation_target(target_card):
		print("Ancient Pyre: Invalid target.")
		card_owner.gain_mana(2)
		return
	target_card.add_buff("Ancient Pyre", 0, -5, 0, self, card_owner, "structure_debuff")
	print("Ancient Pyre: " + target_card.card_name + " Res reduced by 5 (now " + str(target_card.get_effective_resilience()) + ").")
	if target_card.get_effective_resilience() <= 0:
		print(target_card.card_name + " is destroyed by Ancient Pyre!")
		game_manager.request_send_to_graveyard(target_card, Callable(), false, true)

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if is_valid_activation_target(card):
					valid_targets.append(card)
	return valid_targets

func is_valid_activation_target(target: Card) -> bool:
	return target != null \
		and target.card_type == Card.CardType.CREATURE \
		and not target.is_god \
		and target.current_zone != null \
		and target.current_zone.is_board_zone()
