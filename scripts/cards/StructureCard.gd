# StructureCard.gd
extends BaseCard
class_name StructureCard

func _init() -> void:
	super._init()
	card_type = CardType.STRUCTURE

# Structure-specific hooks
func on_summon(game_manager: GameManager) -> void:
	# Override in specific structures
	pass

func on_impact(game_manager: GameManager) -> void:
	# Called when this card enters the field from hand face-up.
	on_summon(game_manager)

func on_removed(game_manager: GameManager) -> void:
	# Override when structure leaves the board
	pass

func on_attacked(game_manager: GameManager, attacker: Card) -> void:
	# Override to add effects when attacked
	pass

func on_turn_start(game_manager: GameManager) -> void:
	# Called at start of owner's turn
	pass

func on_turn_end(game_manager: GameManager) -> void:
	# Called at end of owner's turn
	pass

func replaces_graveyard_send(_card: Card, _game_manager: GameManager) -> bool:
	return false
