extends PowerCard
class_name FeastOfAmbrosiaAndNectar

const ART_PATH := "res://images/card_art/powers/feast_of_ambrosia_and_nectar.jpg"

var _reduced_power_this_turn: PowerCard = null
var _reduced_turn_number: int = -1

func _init() -> void:
	super._init()
	card_name = "Feast of Ambrosia and Nectar"
	culture = "Olympic"
	card_types = ["Power", "Cost Reduction"]
	mana_cost = 0
	discard_cost = 1
	ability_text = "Once per turn, reduce an Olympic Power's flip cost and activation cost by 1 mana."
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

func on_unlock(_game_manager: GameManager) -> void:
	print(card_name + " unlocked.")

func get_cost_adjustment_entries(
	target_card: Card,
	base_cost: int,
	cost_kind: String,
	game_manager: GameManager,
	_metadata: Dictionary = {}
) -> Array[Dictionary]:
	if not _can_reduce_target_power(target_card, base_cost, cost_kind, game_manager):
		return []
	var target_power := target_card as PowerCard
	if _reduced_turn_number == game_manager.turn_number and _reduced_power_this_turn != null and _reduced_power_this_turn != target_power:
		return []
	return [{
		"source": card_name,
		"source_card": self,
		"delta": -1,
	}]

func claim_cost_adjustment(
	target_card: Card,
	base_cost: int,
	cost_kind: String,
	game_manager: GameManager,
	_metadata: Dictionary = {}
) -> bool:
	if not (target_card is PowerCard):
		return false
	var target_power := target_card as PowerCard
	if get_cost_adjustment_entries(target_card, base_cost, cost_kind, game_manager).is_empty():
		return false
	if _reduced_turn_number != game_manager.turn_number or _reduced_power_this_turn == null:
		_reduced_turn_number = game_manager.turn_number
		_reduced_power_this_turn = target_power
		if game_manager != null:
			var cost_label := "flip" if cost_kind == Card.COST_KIND_POWER_UNLOCK else "activation"
			game_manager.note_player_feedback("%s reduces %s's %s cost by 1 mana this turn." % [
				card_name,
				target_power.card_name,
				cost_label
			])
	return true

func on_turn_end(game_manager: GameManager) -> void:
	super.on_turn_end(game_manager)
	if game_manager != null and game_manager.current_player == card_owner:
		_reduced_power_this_turn = null
		_reduced_turn_number = -1

func get_hover_detail_lines(viewer: Player = null) -> Array[String]:
	var details := super.get_hover_detail_lines(viewer)
	if viewer != null and viewer != card_owner:
		return details
	if _reduced_power_this_turn != null and _reduced_turn_number >= 0:
		details.append("Reduced this turn: " + _reduced_power_this_turn.card_name)
	else:
		details.append("Reduction available this turn.")
	return details

func _can_reduce_target_power(target_card: Card, base_cost: int, cost_kind: String, game_manager: GameManager) -> bool:
	if game_manager == null or not (target_card is PowerCard) or base_cost <= 0:
		return false
	if cost_kind not in [Card.COST_KIND_POWER_UNLOCK, Card.COST_KIND_POWER_ACTIVATION]:
		return false
	var target_power := target_card as PowerCard
	if not is_effectively_active():
		return false
	if card_owner != game_manager.current_player:
		return false
	if target_power.card_owner != card_owner:
		return false
	if target_power.culture != "Olympic":
		return false
	return true
