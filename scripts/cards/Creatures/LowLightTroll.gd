extends CreatureCard
class_name LowLightTroll

const ART_PATH := "res://images/card_art/creatures/LowLightTrollEdit.png"
const PARTIAL_PETRIFICATION_SOURCE := "Low-Light Troll Partial Petrification"
const PARTIAL_PETRIFICATION_EFFECT_TYPE := "low_light_troll_partial_petrification"
const PARTIAL_PETRIFICATION_STR_DELTA := -5
const PARTIAL_PETRIFICATION_RES_DELTA := 5

func _init() -> void:
	super._init()
	card_name = "Low-Light Troll"
	card_types = ["Monster", "Troll", "Norse Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 23
	strength = 13
	flavor_text = ""
	ability_text = "[b]Partial Petrification[/b] ([b]Passive[/b]): This card loses 5 Str and gains 5 Res any time a Magical or Power effect reveals a card."
	culture = "Norse"
	artist = "CC0"
	art_path = ART_PATH

func on_card_revealed_by_effect(game_manager: GameManager, revealed_card: Card, source_card: Card) -> void:
	if game_manager == null or revealed_card == null or source_card == null:
		return
	if abilities_suppressed():
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	add_buff(
		PARTIAL_PETRIFICATION_SOURCE,
		PARTIAL_PETRIFICATION_STR_DELTA,
		PARTIAL_PETRIFICATION_RES_DELTA,
		0,
		self,
		card_owner,
		PARTIAL_PETRIFICATION_EFFECT_TYPE
	)
	game_manager.note_player_feedback(
		"%s partially petrifies after %s reveals %s, losing 5 Str and gaining 5 Res." % [
			card_name,
			source_card.card_name,
			revealed_card.get_target_log_display_name(game_manager.get_feedback_viewer())
		]
	)
