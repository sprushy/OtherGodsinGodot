extends CreatureCard
class_name WhiteStag

const ART_PATH := "res://images/card_art/creatures/WhiteStagEdit.png"
const FATALITY_MANA_GAIN := 2

func _init() -> void:
	super._init()
	card_name = "White Stag"
	card_types = ["Animal", "Elaphine", "Neutral Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 4
	resilience = 17
	strength = 24
	ability_text = "[b]Hunter's Mark[/b] ([b]Fatality[/b]): Your opponent gains 2 mana."
	flavor_text = ""
	culture = "Neutral"
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func on_death(game_manager: GameManager) -> void:
	if game_manager == null:
		return

	var controller := get_controller()
	if controller == null:
		controller = card_owner
	var opponent := game_manager.get_opponent(controller)
	if opponent == null:
		return

	var mana_before := opponent.mana
	opponent.gain_mana(FATALITY_MANA_GAIN)
	var mana_gained := opponent.mana - mana_before
	if mana_gained <= 0:
		return

	game_manager.note_player_feedback(
		"%s's Hunter's Mark grants %s %d mana." % [
			card_name,
			opponent.player_name,
			mana_gained
		]
	)
