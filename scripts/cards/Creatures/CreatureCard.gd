# CreatureCard.gd
extends BaseCard
class_name CreatureCard

func _init() -> void:
	super._init()
	card_type = CardType.CREATURE
	ability_immunity_tag = "creature_abilities"

# Creature-specific hooks
func on_attack(_game_manager: GameManager, _target) -> void:
	# Override in specific creature cards to add attack effects
	pass

func on_defend(_game_manager: GameManager, _attacker: Card) -> void:
	# Override to add effects when this creature is attacked
	pass

func on_summon(_game_manager: GameManager) -> void:
	# Called whenever this creature is summoned onto the board.
	pass

func on_impact(_game_manager: GameManager) -> void:
	# Called when this creature is summoned face-up and its impact should resolve.
	pass

func on_reveal(_game_manager: GameManager) -> void:
	# Called when this face-down creature is revealed on the field.
	pass

func on_death(_game_manager: GameManager) -> void:
	# Called when creature is destroyed by combat during kill resolution.
	pass

func on_equip(_equipment: Card) -> void:
	# Called when equipment is attached to this creature
	pass

func on_mode_change(_game_manager: GameManager, _old_mode: CreatureMode) -> void:
	# Called when switching between aggressive and defensive stances
	pass

func on_move(_game_manager: GameManager, _from_zone: Zone, _to_zone: Zone) -> void:
	# Called when creature moves between board positions
	pass

func on_turn_start(_game_manager: GameManager) -> void:
	# Called at the start of the owner's turn
	pass

func on_turn_end(_game_manager: GameManager) -> void:
	# Called at the end of the owner's turn
	pass

func on_kill(_game_manager: GameManager, _victim: Card) -> void:
	# Called when this creature destroys another in combat
	pass

func on_ally_kill(_game_manager: GameManager, _killer: Card, _victim: Card) -> void:
	# Called on every friendly board creature when any ally destroys an enemy in combat
	pass

func on_after_combat(_game_manager: GameManager, _opposing_card: Card) -> void:
	# Called after this creature is involved in combat and survives long enough to receive hooks.
	pass

func on_sacrificed_for_summon(_game_manager: GameManager, _summoned_card: Card) -> void:
	# Called when this creature is sacrificed to pay another creature's summon cost.
	pass

func on_opponent_attacks_followers(_game_manager: GameManager, _attacker: Card) -> void:
	# Called on every friendly board creature when an opponent's creature attacks
	# this card's controller's followers directly (no intercept).
	pass

func on_friendly_god_power_activated(_game_manager: GameManager, _god: Card, _target: Card = null) -> void:
	# Called after this creature's controller successfully activates their god's power.
	pass
