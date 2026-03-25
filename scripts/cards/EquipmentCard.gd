extends BaseCard
class_name EquipmentCard

func _init() -> void:
	card_type = CardType.EQUIPMENT

# Called when this equipment is attached to a creature
func on_equip(_creature: Card) -> void:
	pass

# Return extra STR when the equipped creature attacks a DEFENSE-mode defender.
# Override in specific equipment cards for conditional bonuses.
func get_bonus_strength_vs_defense(_attacker: Card) -> int:
	return 0
