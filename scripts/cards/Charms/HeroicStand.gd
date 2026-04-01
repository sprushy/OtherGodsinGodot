extends CharmCard
class_name HeroicStand

const INTERCEPT_THRESHOLD := 2
const MANA_GAIN := 7

func _init() -> void:
	super._init()
	card_name = "Heroic Stand"
	culture = "Triskelion"
	card_types = ["Charm", "Resource Gain", "Mana"]
	level = 2
	mana_cost = 0
	speed = 2
	ability_text = "If one of your creatures has intercepted twice or more this turn, gain 7 mana."
	artist = "Mike Capprotti via TgcMaker"
	art_path = "res://images/card_art/charms/HeroicStandArt.jpg"

func can_activate_from_hand(game_manager: GameManager, triggering_action: CardAction = null) -> bool:
	if not super.can_activate_from_hand(game_manager, triggering_action):
		return false
	return _has_qualified_interceptor(game_manager)

func can_activate_prepared(game_manager: GameManager, triggering_action: CardAction = null) -> bool:
	if not super.can_activate_prepared(game_manager, triggering_action):
		return false
	return _has_qualified_interceptor(game_manager)

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null or card_owner == null:
		return
	var qualified_creatures := game_manager.get_creatures_with_intercepts_this_turn(card_owner, INTERCEPT_THRESHOLD)
	if qualified_creatures.is_empty():
		game_manager.note_player_feedback(card_name + " fizzles: none of your creatures intercepted twice this turn.")
		return
	card_owner.gain_mana(MANA_GAIN)
	var viewer := game_manager.get_feedback_viewer()
	var names: Array[String] = []
	for creature in qualified_creatures:
		if creature != null:
			names.append(creature.get_target_log_display_name(viewer))
	var feedback := "%s gains %d mana" % [card_name, MANA_GAIN]
	if not names.is_empty():
		feedback += " thanks to " + ", ".join(names)
	feedback += "."
	game_manager.note_player_feedback(feedback)

func _has_qualified_interceptor(game_manager: GameManager) -> bool:
	return game_manager != null \
		and card_owner != null \
		and not game_manager.get_creatures_with_intercepts_this_turn(card_owner, INTERCEPT_THRESHOLD).is_empty()
