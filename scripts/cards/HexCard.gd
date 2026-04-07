extends BaseCard
class_name HexCard

func _init() -> void:
	super._init()
	card_type = Card.CardType.HEX

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
	if is_activation_locked(game_manager):
		return false
	return false

# Override to define when this hex can activate.
# attacker: the creature initiating the attack
# defender: the creature or card being attacked
func can_activate(_attacker: Card, _defender: Card) -> bool:
	return false

func get_affected_cards(_attacker: Card, defender: Card) -> Array[Card]:
	var affected: Array[Card] = []
	if defender != null:
		affected.append(defender)
	return affected

func on_immune_activate(_game_manager: GameManager, _attacker: Card, _defender: Card) -> void:
	card_owner.move_card(self, card_owner.graveyard_zone)

# Override to define what happens when this hex activates.
# The hex is responsible for sending itself to the graveyard.
func on_activate(_game_manager: GameManager, _attacker: Card, _defender: Card) -> void:
	pass
