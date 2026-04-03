extends CreatureCard
class_name Pazuzu

const ART_PATH := "res://images/card_art/creatures/PazuzuEdit.png"
const MANA_DRAIN := 2

func _init() -> void:
	super._init()
	card_name = "Pazuzu"
	card_types = ["Demon", "Aerial", "Ancient Creature"]
	level = 5
	mana_cost = 0
	sacrifice_cost = 1
	speed = 2
	resilience = 15
	strength = 28
	ability_text = "[b]Locust Swarm[/b] ([b]Impact[/b]): Reduce your opponent's mana by 2.\n[b]Locust Plague[/b] ([b]Passive[/b]): At the beginning of your turn, reduce your opponent's mana by 2."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func on_impact(game_manager: GameManager) -> void:
	if game_manager == null or abilities_suppressed():
		return
	var feedback := _drain_opponent_mana(game_manager, "Locust Swarm")
	if feedback != "":
		game_manager.note_player_feedback(feedback)

func on_turn_start(game_manager: GameManager) -> void:
	if game_manager == null or abilities_suppressed():
		return
	if current_zone == null or not current_zone.is_board_zone() or is_face_down:
		return
	var controller := get_controller()
	if controller == null or controller != game_manager.current_player:
		return
	var feedback := _drain_opponent_mana(game_manager, "Locust Plague")
	if feedback != "":
		game_manager.note_player_feedback(feedback)

func _drain_opponent_mana(game_manager: GameManager, ability_name: String) -> String:
	var controller := get_controller()
	if game_manager == null or controller == null:
		return ""
	var opponent := game_manager.get_opponent(controller)
	if opponent == null:
		return ""
	var drained = opponent.lose_mana(MANA_DRAIN)
	if drained <= 0:
		return "%s triggers %s, but %s has no mana to lose." % [
			card_name,
			ability_name,
			opponent.player_name
		]
	return "%s triggers %s and reduces %s's mana by %d." % [
		card_name,
		ability_name,
		opponent.player_name,
		drained
	]
