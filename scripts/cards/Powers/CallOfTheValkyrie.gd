extends PowerCard
class_name CallOfTheValkyrie

const UNLOCK_COST := 3
const ACTIVATION_COST := 1
const ART_PATH := "res://images/card_art/powers/CalloftheValkyrieAIEdit.png"

func _init() -> void:
	super._init()
	card_name = "Call of the Valkyrie"
	culture = "Norse"
	level = 3
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Return", "Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	targets = true
	ability_text = "[b]Unlock[/b] (3): [b]Activate[/b] - Pay 1 mana to [b]Prime[/b] a Norse Warrior from your graveyard."
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

func can_activate(game_manager: GameManager) -> bool:
	return not is_face_down \
		and not is_muted \
		and not is_activation_locked(game_manager) \
		and card_owner == game_manager.current_player \
		and card_owner.mana >= ACTIVATION_COST \
		and not get_valid_targets(game_manager).is_empty()

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	for card in card_owner.graveyard_zone.cards:
		if _is_valid_target(card):
			valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	if target == null or target not in get_valid_targets(game_manager):
		print(card_name + ": Invalid graveyard target.")
		return

	if not card_owner.spend_mana(ACTIVATION_COST):
		return

	card_owner.move_card(target, card_owner.deck_zone)
	if card_owner.deck_zone.cards.has(target):
		card_owner.deck_zone.cards.erase(target)
	card_owner.deck_zone.cards.insert(0, target)
	print("%s: Primed %s from the graveyard." % [card_name, target.card_name])

func _is_valid_target(card: Card) -> bool:
	return card != null \
		and card.current_zone == card_owner.graveyard_zone \
		and card.card_type == Card.CardType.CREATURE \
		and card.has_type("Norse Creature") \
		and card.has_type("Warrior")
