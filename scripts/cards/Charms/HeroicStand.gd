extends CharmCard
class_name HeroicStand

const COMBAT_THRESHOLD := 3
const MANA_GAIN := 7

func _init() -> void:
	super._init()
	card_name = "Heroic Stand"
	culture = "Triskelion"
	card_types = ["Charm", "Resource Gain", "Mana"]
	level = 2
	mana_cost = 0
	speed = 2
	ability_text = "If you control a creature that has been in at least %d combats this game, gain %d mana." % [COMBAT_THRESHOLD, MANA_GAIN]
	artist = "Mike Capprotti via TgcMaker"
	art_path = "res://images/card_art/charms/HeroicStandArt.jpg"

func can_activate_from_hand(game_manager: GameManager, triggering_action: CardAction = null) -> bool:
	if not super.can_activate_from_hand(game_manager, triggering_action):
		return false
	return not _get_qualified_creatures(game_manager).is_empty()

func can_activate_prepared(game_manager: GameManager, triggering_action: CardAction = null) -> bool:
	if not super.can_activate_prepared(game_manager, triggering_action):
		return false
	return not _get_qualified_creatures(game_manager).is_empty()

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null or card_owner == null:
		return
	var qualified_creatures := _get_qualified_creatures(game_manager)
	if qualified_creatures.is_empty():
		game_manager.note_player_feedback("%s fizzles: none of your creatures has been in %d combats." % [card_name, COMBAT_THRESHOLD])
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

func _get_qualified_creatures(game_manager: GameManager) -> Array[Card]:
	if game_manager == null or card_owner == null:
		return []
	return game_manager.get_field_cards(card_owner).filter(func(card: Card) -> bool:
		return card.is_creature_card() and card.get_controller() == card_owner \
			and card.combats_this_game >= COMBAT_THRESHOLD
	)
