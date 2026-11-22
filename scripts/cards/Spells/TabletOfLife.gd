extends SpellCard
class_name TabletOfLife

const ART_PATH := "res://images/card_art/spells/TabletofLifeEdit.jpg"
const UNDEAD_GRANT_STATUS := "tablet_of_life_undead"
const DESTROY_AT_TURN_END_STATUS := "destroy_at_turn_end"

func _init() -> void:
	super._init()
	card_name = "Tablet of Life"
	culture = "Ancient"
	card_types = ["Resurrection"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 3
	mana_cost = 1
	speed = 1
	is_legendary = false
	targets = true
	flavor_text = ""
	artist = "Riccardo Zoppello"
	art_path = ART_PATH
	ability_text = "Resurrect one of your Ancient creatures; its abilities are negated and it gains [b]Undead[/b]. If it is level 3 or higher, destroy it at turn's end."

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null or card_owner.graveyard_zone == null:
		return valid_targets
	if not _has_open_summon_zone():
		return valid_targets
	for card in card_owner.graveyard_zone.cards:
		if is_valid_target(card):
			valid_targets.append(card)
	return valid_targets

func is_valid_target(target: Card) -> bool:
	return target != null \
		and card_owner != null \
		and target.current_zone == card_owner.graveyard_zone \
		and target.card_type == Card.CardType.CREATURE \
		and not target.is_god \
		and target.culture == "Ancient" \
		and _get_best_summon_zone(target) != null

func resolve(game_manager: GameManager, target = null) -> void:
	if game_manager == null:
		return
	if not is_valid_target(target):
		game_manager.note_player_feedback(card_name + " fizzles: choose an Ancient creature in your graveyard.")
		return

	var creature := target as Card
	var summon_zone := _get_best_summon_zone(creature)
	if summon_zone == null:
		game_manager.note_player_feedback(card_name + " fizzles: no open summon lane.")
		return

	# Tablet-resurrected creatures enter with negated abilities, so they must not fire Impact.
	var summoned := game_manager.summon_creature_by_effect(
		card_owner,
		creature,
		summon_zone,
		Card.CreatureMode.AGGRESSIVE,
		false,
		false,
		self,
		false,
		false,
		false
	)
	if not summoned:
		game_manager.note_player_feedback(card_name + " fizzles: " + creature.card_name + " could not be resurrected.")
		return

	_apply_tablet_of_life(creature, game_manager)
	var feedback := "%s resurrects %s. Its abilities are negated and it gains Undead." % [
		card_name,
		creature.get_target_log_display_name(game_manager.get_feedback_viewer())
	]
	if creature.get_effective_level() >= 3:
		feedback += " It will be destroyed at turn's end."
	game_manager.note_player_feedback(feedback)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	var base_reason := super.get_play_failure_reason(game_manager, player)
	if not base_reason.is_empty():
		return base_reason
	if get_valid_targets(game_manager).is_empty():
		return card_name + " has no valid targets."
	return ""

func _apply_tablet_of_life(creature: Card, game_manager: GameManager) -> void:
	if creature == null:
		return
	creature.remove_status_effects_from_source_card(self, Card.ABILITY_NEGATED_STATUS)
	creature.add_status_effect(
		Card.ABILITY_NEGATED_STATUS,
		card_name,
		self,
		card_owner,
		{"remove_when_leaves_board": true}
	)
	if not creature.has_type("Undead"):
		creature.remove_status_effects_from_source_card(self, UNDEAD_GRANT_STATUS)
		creature.add_status_effect(
			UNDEAD_GRANT_STATUS,
			card_name,
			self,
			card_owner,
			{
				"granted_types": ["Undead"],
				"remove_when_leaves_board": true
			}
		)
	if creature.get_effective_level() >= 3:
		creature.remove_status_effects_by_name(DESTROY_AT_TURN_END_STATUS)
		creature.add_status_effect(
			DESTROY_AT_TURN_END_STATUS,
			card_name,
			self,
			card_owner,
			{
				"expires_turn": game_manager.turn_number,
				"remove_when_leaves_board": true
			}
		)

func _has_open_summon_zone() -> bool:
	if card_owner == null:
		return false
	return _find_first_open_zone(card_owner.frontline_zones) != null or _find_first_open_zone(card_owner.reserve_zones) != null

func _get_best_summon_zone(creature: Card) -> Zone:
	if creature == null or card_owner == null:
		return null
	var last_type: int = creature.last_board_zone_type
	var center: int = clampi(creature.last_board_zone_index, 0, Player.BOARD_LANE_COUNT - 1)
	var primary: Array[Zone] = []
	var secondary: Array[Zone] = []
	if last_type == Zone.ZoneType.RESERVE:
		primary.assign(card_owner.reserve_zones)
		secondary.assign(card_owner.frontline_zones)
	else:
		primary.assign(card_owner.frontline_zones)
		secondary.assign(card_owner.reserve_zones)

	for zone in _zones_by_distance(primary, center):
		if zone.cards.is_empty():
			return zone
	for zone in _zones_by_distance(secondary, center):
		if zone.cards.is_empty():
			return zone
	return null

func _zones_by_distance(row: Array[Zone], center: int) -> Array[Zone]:
	var result: Array[Zone] = []
	if row.is_empty():
		return result
	result.append(row[center])
	for distance in range(1, row.size()):
		var low := center - distance
		var high := center + distance
		if low >= 0:
			result.append(row[low])
		if high < row.size():
			result.append(row[high])
	return result

func _find_first_open_zone(zones: Array[Zone]) -> Zone:
	for zone in zones:
		if zone != null and zone.cards.is_empty():
			return zone
	return null
