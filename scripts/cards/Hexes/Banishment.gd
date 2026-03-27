extends HexCard
class_name Banishment

func _init() -> void:
	super._init()
	card_name = "Banishment"
	level = 3
	mana_cost = 5
	speed = 7
	culture = "Ancient"
	card_types = ["Magic Negation"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	ability_text = "Negate the activation of a magical card and send it to the [b]Void[/b]."
	flavor_text = ""
	artist = "Ricarrdo Zoppello"
	art_path = "res://images/card_art/hexes/BanishmentAIEdit.png"
	targets = true

func can_respond_to_action(action: CardAction) -> bool:
	if action == null or action.card == null:
		return false
	if action.card.has_method("can_be_negated") and not action.card.can_be_negated(action):
		return false
	if action.type != CardAction.Type.SPELL and action.type != CardAction.Type.ABILITY:
		return false
	if action.type == CardAction.Type.ABILITY and not _is_magical_ability_source(action.card):
		return false
	return action.card.is_magical_card()

func on_activate_action(game_manager: GameManager, action: CardAction) -> void:
	var negated_action := action.response_to
	if negated_action == null or negated_action.card == null:
		card_owner.move_card(self, card_owner.graveyard_zone)
		return
	print(card_name + " negates " + negated_action.card.card_name + " and sends it to the abyss!")
	if game_manager != null:
		game_manager.note_player_feedback(card_name + " negated " + negated_action.card.card_name + " and sent it to the abyss.")
	if negated_action in game_manager.action_stack:
		game_manager.action_stack.erase(negated_action)
	game_manager.banish_card_with_hook(negated_action.card)
	card_owner.move_card(self, card_owner.graveyard_zone)

func _is_magical_ability_source(card: Card) -> bool:
	if card == null:
		return false
	return card.is_magical_card() and card.card_type != Card.CardType.POWER
