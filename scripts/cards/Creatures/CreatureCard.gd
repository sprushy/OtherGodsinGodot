# CreatureCard.gd
extends BaseCard
class_name CreatureCard

func _init() -> void:
	card_type = CardType.CREATURE

# Creature-specific hooks
func on_attack(game_manager: GameManager, target) -> void:
	# Override in specific creature cards to add attack effects
	pass

func on_defend(game_manager: GameManager, attacker: Card) -> void:
	# Override to add effects when this creature is attacked
	pass

func on_summon(game_manager: GameManager) -> void:
	# Called when creature enters the board from hand
	pass

func on_impact(game_manager: GameManager) -> void:
	# Called when this card enters the field from hand face-up.
	on_summon(game_manager)

func on_reveal(game_manager: GameManager) -> void:
	# Called when this face-down creature is revealed on the field.
	pass

func on_death(game_manager: GameManager) -> void:
	# Called when creature is destroyed by combat during kill resolution.
	pass

func on_equip(equipment: Card) -> void:
	# Called when equipment is attached to this creature
	pass

func on_mode_change(game_manager: GameManager, old_mode: CreatureMode) -> void:
	# Called when switching between aggressive and defensive stances
	pass

func on_move(game_manager: GameManager, from_zone: Zone, to_zone: Zone) -> void:
	# Called when creature moves between board positions
	pass

func on_turn_start(game_manager: GameManager) -> void:
	# Called at the start of the owner's turn
	pass

func on_turn_end(game_manager: GameManager) -> void:
	# Called at the end of the owner's turn
	pass

func on_kill(game_manager: GameManager, victim: Card) -> void:
	# Called when this creature destroys another in combat
	pass

func on_ally_kill(game_manager: GameManager, killer: Card, victim: Card) -> void:
	# Called on every friendly board creature when any ally destroys an enemy in combat
	pass

func on_after_combat(game_manager: GameManager, opposing_card: Card) -> void:
	# Called after this creature is involved in combat and survives long enough to receive hooks.
	pass

func on_sacrificed_for_summon(game_manager: GameManager, summoned_card: Card) -> void:
	# Called when this creature is sacrificed to pay another creature's summon cost.
	pass
