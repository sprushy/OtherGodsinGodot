extends CreatureCard
class_name StoneMonkey

const ART_PATH := "res://images/card_art/creatures/StoneMonkeyArt.png"
const ALT_ART_PATH := "res://images/card_art/creatures/stone_monkey_alt.png"

func _init() -> void:
	super._init()
	card_name = "Stone Monkey"
	card_types = ["Warrior", "Animal", "Simian", "Tian Creature"]
	level = 4
	mana_cost = 2
	sacrifice_cost = 0
	speed = 3
	resilience = 15
	strength = 15
	ability_text = "[b]Stone Skin[/b] ([b]Passive[/b]): Cannot be destroyed in battle."
	flavor_text = ""
	culture = "Tian"
	artist = ""
	art_path = ART_PATH
	art_variants = [ART_PATH, ALT_ART_PATH]

func get_self_graveyard_replacement_zone(
	_game_manager: GameManager,
	combat_death: bool,
	_destruction: bool,
	send_to_abyss: bool
) -> Zone:
	if not combat_death or send_to_abyss:
		return null
	if abilities_suppressed():
		return null
	if current_zone == null or not current_zone.is_board_zone():
		return null
	return current_zone
