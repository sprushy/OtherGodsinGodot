extends CreatureCard
class_name HelBlarDraug

const GROUNDBOUND_SOURCE := "Groundbound"
const GROUNDBOUND_EFFECT_TYPE := "hel_blar_draug_groundbound"
const AERIAL_TYPE := "Aerial"
const ART_PATH := "res://images/card_art/Hel-BlarDraugEdit.png"

func _init() -> void:
	super._init()
	card_name = "Hel-blar Draug"
	card_types = ["Undead", "Draug", "Mage", "Battlemage", "Norse Creature"]
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 17
	strength = 21
	flavor_text = ""
	ability_text = "[b]Groundbound[/b] ([b]Impact[/b]): All enemy creatures lose the classification Aerial and, if they were Aerial, lose 1 Spd, 6 Res, and 6 Str."
	culture = "Norse"
	artist = "Tim Nguyen"
	art_path = ART_PATH

func on_impact(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	var affected_creatures: Array[String] = []
	for player in game_manager.players:
		if player == null or player == get_controller():
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				var creature := card as Card
				if creature == null or creature.card_type != Card.CardType.CREATURE:
					continue
				var was_aerial := creature.has_type(AERIAL_TYPE)
				_apply_groundbound(creature)
				if was_aerial:
					affected_creatures.append(creature.get_target_log_display_name(game_manager.get_feedback_viewer()))
	if affected_creatures.is_empty():
		game_manager.note_player_feedback("%s grounded no aerial enemies." % card_name)
	else:
		game_manager.note_player_feedback("%s grounded %s." % [card_name, ", ".join(affected_creatures)])

func _apply_groundbound(creature: Card) -> void:
	if creature == null:
		return
	if not creature.has_type(AERIAL_TYPE):
		return
	var next_types := creature.card_types.duplicate()
	next_types.erase(AERIAL_TYPE)
	creature.card_types = next_types
	creature.remove_buffs_from_source_card(self, GROUNDBOUND_EFFECT_TYPE)
	creature.add_buff(GROUNDBOUND_SOURCE, -6, -6, -1, self, card_owner, GROUNDBOUND_EFFECT_TYPE)
