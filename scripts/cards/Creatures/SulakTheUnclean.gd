extends CreatureCard
class_name SulakTheUnclean

const ART_PATH := "res://images/card_art/creatures/Sulak the Unclean(web).jpg"
const SURPRISE_BUFF_SOURCE := "Sulak the Unclean - Surprise!"
const SURPRISE_BUFF_TYPE := "sulak_surprise"

func _init() -> void:
	super._init()
	card_name = "Sulak the Unclean"
	card_types = ["Demon", "Ancient Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 15
	strength = 19
	ability_text = "Surprise! ([b]Reveal[/b]): The turn Sulak is revealed, double his strength."
	flavor_text = "\"Sulak likes to strike when his victims are most vulnerable...\""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func on_reveal(game_manager: GameManager) -> void:
	if game_manager == null or abilities_suppressed():
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	# Clear any stale surprise buff first so repeat reveals (re-stealth, re-reveal)
	# always reflect the current base strength.
	remove_buffs_from_source_card(self, SURPRISE_BUFF_TYPE)
	add_buff(
		SURPRISE_BUFF_SOURCE,
		strength, # double base strength: current base + same amount again
		0,
		0,
		self,
		card_owner,
		SURPRISE_BUFF_TYPE,
		{"expires_turn": game_manager.turn_number}
	)
	game_manager.note_player_feedback(
		"%s is revealed and surprises his enemies, doubling his strength this turn!" % card_name
	)
