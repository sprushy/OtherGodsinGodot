extends "res://scripts/bots/ThorPracticeBot.gd"

func _choose_upkeep_option() -> String:
	return "draw"

func _try_attack() -> bool:
	var attackers := _get_attack_ready_creatures()
	var targets := _get_board_creatures(opponent)
	var attack := _get_best_standard_attack(attackers, targets)
	if attack.is_empty():
		attack = _get_best_stealth_attack(attackers, targets)
	if attack.is_empty():
		return false
	return _submit_attack(attack.get("attacker", null), attack.get("target", null))

func _submit_attack(attacker: Card, target) -> bool:
	if not target is Card or target.card_type != Card.CardType.CREATURE:
		return false
	return super._submit_attack(attacker, target)

func _on_match_ui_interaction(prompt_player_index: int, type: String, data: Dictionary) -> void:
	if prompt_player_index == player_index and type == "wolf_adolescent_maturation":
		_submit_action({
			"type": "wolf_adolescent_maturation_choice",
			"source_uid": str(data.get("source_uid", "")),
			"target_uid": "",
		})
		return
	super._on_match_ui_interaction(prompt_player_index, type, data)
