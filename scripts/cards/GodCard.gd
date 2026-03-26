extends BaseCard
class_name GodCard

func _init() -> void:
	super._init()
	card_type = Card.CardType.CREATURE
	is_god = true
	is_power = true
	ability_immunity_tag = "powers"

func is_effectively_active() -> bool:
	return not is_muted

func on_muted(_game_manager: GameManager) -> void:
	pass

func on_unmuted(_game_manager: GameManager) -> void:
	pass
