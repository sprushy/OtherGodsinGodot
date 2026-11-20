extends SpellCard
class_name Apotheosis

const ART_PATH := "res://images/card_art/spells/Apotheosis.png"

func _init() -> void:
	super._init()
	card_name = "Apotheosis"
	culture = "Neutral"
	card_types = ["Targeting", "Buff"]
	level = 3
	mana_cost = 0
	speed = 1
	is_legendary = false
	sacrifice_cost = 0
	targets = true
	flavor_text = ""
	artist = "User provided"
	art_path = ART_PATH
	ability_text = "+1 level, +4 Str, +4 Res, and +1 Spd to a creature you control. If it reaches level 7, [b]Ascend[/b] it."

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or card_owner == null:
		return valid_targets
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if is_valid_target(card, game_manager):
				valid_targets.append(card)
	return valid_targets

func is_valid_target(target: Card, game_manager: GameManager = null) -> bool:
	if target == null or card_owner == null:
		return false
	if target.card_type != Card.CardType.CREATURE or target.is_god:
		return false
	if target.current_zone == null or not target.current_zone.is_board_zone():
		return false
	if target.get_controller() != card_owner:
		return false
	if game_manager != null and game_manager.is_immune_to_source(target, self):
		return false
	return true

func resolve(game_manager: GameManager, target = null) -> void:
	if game_manager == null:
		return
	var creature := target as Card
	if not is_valid_target(creature, game_manager):
		game_manager.note_player_feedback("Apotheosis fizzles: choose a creature you control on the field.")
		return
	creature.level += 1
	creature.add_buff(card_name, 4, 4, 1, self, card_owner, "apotheosis")
	var viewer := game_manager.get_feedback_viewer()
	var target_name := creature.get_target_log_display_name(viewer)
	game_manager.note_player_feedback("Apotheosis raised %s to level %d." % [target_name, creature.level])

	if _is_natural_level_six_creature(creature) and creature.level >= 7:
		game_manager.offer_ascension(creature, card_owner)

func _is_natural_level_six_creature(creature: Card) -> bool:
	if creature == null:
		return false
	var key: String = creature.get_script().resource_path.get_file().get_basename()
	return key in ["EnkiLordOfEridu", "Fenrir", "PaiLongAutumnKing"]

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var target_uid: String = command.get("target_uid", "")
	var target: Card = game_manager.get_card_by_uid(target_uid) if target_uid != "" else null
	resolve(game_manager, target)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	var base_reason := super.get_play_failure_reason(game_manager, player)
	if not base_reason.is_empty():
		return base_reason
	if get_valid_targets(game_manager).is_empty():
		return card_name + " has no valid creature targets you control."
	return ""