# StructureCard.gd
extends BaseCard
class_name StructureCard

func _init() -> void:
	super._init()
	card_type = CardType.STRUCTURE

# Structure-specific hooks
func on_summon(_game_manager: GameManager) -> void:
	# Called whenever this structure is summoned onto the board.
	pass

func on_impact(_game_manager: GameManager) -> void:
	# Called when this structure is summoned face-up and its impact should resolve.
	pass

func on_removed(_game_manager: GameManager) -> void:
	# Override when structure leaves the board
	pass

func on_attacked(_game_manager: GameManager, _attacker: Card) -> void:
	# Override to add effects when attacked
	pass

func on_turn_start(_game_manager: GameManager) -> void:
	# Called at start of owner's turn
	pass

func on_turn_end(_game_manager: GameManager) -> void:
	# Called at end of owner's turn
	pass

func replaces_graveyard_send(_card: Card, _game_manager: GameManager) -> bool:
	return false
