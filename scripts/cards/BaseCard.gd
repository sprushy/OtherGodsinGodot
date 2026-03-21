# BaseCard.gd
extends Card
class_name BaseCard

# Common hooks all cards can use
func on_play(game_manager: GameManager, target = null) -> void:
	pass

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	return can_pay_costs(player)

func on_enter_zone(zone: Zone) -> void:
	pass

func on_leave_zone(zone: Zone) -> void:
	pass
