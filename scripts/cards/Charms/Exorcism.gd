extends CharmCard
class_name Exorcism

const EFFECT_SOURCE := "Exorcism"
const ART_PATH := "res://images/card_art/charms/Exorcism.jpg"

func _init() -> void:
	super._init()
	card_name = "Exorcism"
	culture = "Ancient"
	card_types = ["Charm", "Healing"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 3
	mana_cost = 0
	speed = 3
	targets = true
	ability_text = "Cannot be negated. Choose a friendly creature. Until end of turn, negate all effects on it other than ones it put on itself, and destroy any enemy cards still targeting it."
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

func can_be_negated(_action: CardAction = null) -> bool:
	return false

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or card_owner == null:
		return valid_targets
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		var creature := zone.get_creature()
		if is_valid_target(creature):
			valid_targets.append(creature)
	return valid_targets

func is_valid_target(target: Card) -> bool:
	return target != null \
		and target.card_type == Card.CardType.CREATURE \
		and not target.is_god \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.get_controller() == card_owner

func resolve(game_manager: GameManager, target = null) -> void:
	if not is_valid_target(target):
		print(card_name + " requires a friendly creature.")
		return
	if game_manager == null:
		return

	target.remove_status_effects_from_source_card(self, Card.EXTERNAL_EFFECT_NEGATION_STATUS)
	target.add_status_effect(
		Card.EXTERNAL_EFFECT_NEGATION_STATUS,
		EFFECT_SOURCE,
		self,
		card_owner,
		{
			"expires_turn": game_manager.turn_number,
			"allow_while_negated": true,
		}
	)

	var destroyed_cards := _destroy_opponent_targeters(game_manager, target)
	var viewer: Player = game_manager.get_feedback_viewer()
	var target_name: String = target.get_target_log_display_name(viewer)
	var feedback: String = "%s exorcised %s, negating outside effects until end of turn." % [card_name, target_name]
	if not destroyed_cards.is_empty():
		var names: Array[String] = []
		for destroyed_card in destroyed_cards:
			if destroyed_card != null:
				names.append(destroyed_card.get_target_log_display_name(viewer))
		if not names.is_empty():
			feedback += " Destroyed: " + ", ".join(names) + "."
	game_manager.note_player_feedback(feedback)
	print(feedback)

func _destroy_opponent_targeters(game_manager: GameManager, target: Card) -> Array[Card]:
	var destroyed: Array[Card] = []
	var opponent := game_manager.get_opponent(card_owner)
	if opponent == null:
		return destroyed

	for action in game_manager.action_stack.duplicate():
		var source_card = action.card
		if source_card == null or source_card == self:
			continue
		if source_card.card_owner != opponent:
			continue
		if not _action_targets_card(action, target):
			continue
		if action in game_manager.action_stack:
			game_manager.action_stack.erase(action)
		if source_card.current_zone != null and source_card.current_zone != source_card.card_owner.graveyard_zone:
			if game_manager.request_send_to_graveyard(source_card, Callable(), false, true):
				if source_card not in destroyed:
					destroyed.append(source_card)

	for zone in opponent.frontline_zones + opponent.reserve_zones + opponent.power_zones:
		for card in zone.cards.duplicate():
			if not (card is PermanentHexCard):
				continue
			var attached_hex := card as PermanentHexCard
			if attached_hex.attached_target != target:
				continue
			if game_manager.request_send_to_graveyard(attached_hex, Callable(), false, true):
				if attached_hex not in destroyed:
					destroyed.append(attached_hex)

	return destroyed

func _action_targets_card(action: CardAction, target: Card) -> bool:
	if action == null or target == null:
		return false
	if action.target == target:
		return true
	if action.interceptor == target:
		return true
	return false
