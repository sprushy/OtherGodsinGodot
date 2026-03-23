extends BaseCard
class_name HexCard

func _init() -> void:
	card_type = Card.CardType.HEX

# Override to define when this hex can activate.
# attacker: the creature initiating the attack
# defender: the creature or card being attacked
func can_activate(attacker: Card, defender: Card) -> bool:
	return false

func get_affected_cards(attacker: Card, defender: Card) -> Array[Card]:
	var affected: Array[Card] = []
	if defender != null:
		affected.append(defender)
	return affected

func on_immune_activate(game_manager: GameManager, _attacker: Card, _defender: Card) -> void:
	card_owner.move_card(self, card_owner.graveyard_zone)

# Override to define what happens when this hex activates.
# The hex is responsible for sending itself to the graveyard.
func on_activate(game_manager: GameManager, attacker: Card, defender: Card) -> void:
	pass
