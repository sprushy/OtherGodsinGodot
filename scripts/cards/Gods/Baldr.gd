extends GodCard
class_name Baldr

const FOLLOWERS_GAINED_PER_TURN := 5

var paragon: String = "Paragon of Paragons"

func _init() -> void:
	super._init()
	card_name = "Baldr"
	card_types = ["Purity", "Wisdom", "Paragon"]
	mana_cost = 0
	culture = "Norse"
	flavor_text = "Radiance and virtue gather the faithful to his side."
	ability_text = "Blessed One ([b]Passive[/b]): [b]Upkeep[/b]: Gain 5 followers."
	art_path = "res://images/card_art/gods/BaldrAIEdit.png"
	name_at_bottom = true
	artist = "Ricardo Zoppello"

func on_turn_upkeep(game_manager: GameManager) -> void:
	if card_owner == null or is_muted:
		return
	card_owner.gain_followers(FOLLOWERS_GAINED_PER_TURN)
	notify_power_activated(game_manager)
	print("Blessed One: " + card_owner.player_name + " gains " + str(FOLLOWERS_GAINED_PER_TURN) + " followers from Baldr.")
