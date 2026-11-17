extends StructureCard
class_name SleepOfTheDuat

const ART_PATH := "res://images/card_art/structures/sleep_of_the_duat.png"
const ALT_ART_PATH := "res://images/card_art/structures/sleep_of_the_duat_alt.png"

func _init() -> void:
	super._init()
	card_name = "Sleep of the Duat"
	card_types = ["Dwelling", "Afterlife", "Ancient Structure"]
	level = 4
	mana_cost = 0
	discard_cost = 1
	resilience = 27
	speed = 0
	strength = 0
	sacrifice_cost = 0
	ability_text = "As an additional cost to play this card, choose and discard a card from your hand.\nFrom the end of their first turn on the field, creatures sleep unless there is a Divine Manifestation on the field. (A Divine Manifestation on either side of the field wakes all creatures.)"
	culture = "Ancient"
	artist = "User provided art"
	art_path = ART_PATH
	art_variants = [ART_PATH, ALT_ART_PATH]

func on_global_turn_end(game_manager: GameManager, ending_player: Player) -> void:
	_update_art_variant(game_manager)
	if game_manager == null:
		return
	if not _is_effectively_active():
		return
	if _divine_manifestation_on_field(game_manager):
		_wake_own_sleepers(game_manager)
	else:
		_sleep_all_creatures(game_manager)

func on_creature_summoned(
	player: Player,
	card: Card,
	_from_zone: Zone,
	_to_zone: Zone,
	_summon_source: Card,
	face_down: bool,
	stealth: bool,
	game_manager: GameManager
) -> void:
	if game_manager == null or card == null:
		return
	_update_art_variant(game_manager)
	if face_down or stealth:
		return
	if not card.has_type("Divine Manifestation"):
		return
	if not _is_effectively_active():
		return
	_wake_own_sleepers(game_manager)

func on_removed(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	# Creatures this structure put to sleep wake when it leaves the field.
	for player in game_manager.players:
		for creature in _get_field_creatures(game_manager, player):
			if creature.sleeping_from == self:
				creature.wake_up()

func _is_effectively_active() -> bool:
	return current_zone != null \
		and current_zone.is_board_zone() \
		and not is_face_down \
		and not is_stealth \
		and not abilities_suppressed()

func _sleep_all_creatures(game_manager: GameManager) -> void:
	for player in game_manager.players:
		for creature in _get_field_creatures(game_manager, player):
			if not _is_sleepable_creature(creature):
				continue
			if creature.sleeping_from == self:
				continue
			creature.apply_sleep(self)
			game_manager.note_player_feedback(
				"%s falls asleep under the Sleep of the Duat." % creature.card_name
			)

func _wake_own_sleepers(game_manager: GameManager) -> void:
	for player in game_manager.players:
		for creature in _get_field_creatures(game_manager, player):
			if creature != null and creature.sleeping_from == self:
				creature.wake_up()
				game_manager.note_player_feedback(
					"%s wakes in the light of the Divine Manifestation." % creature.card_name
				)

func _is_sleepable_creature(creature: Card) -> bool:
	if creature == null or creature.card_type != Card.CardType.CREATURE:
		return false
	if creature.current_zone == null or not creature.current_zone.is_board_zone():
		return false
	if creature.is_face_down or creature.is_stealth:
		return false
	if creature.is_immune_to_sleep():
		return false
	return true

func _get_field_creatures(game_manager: GameManager, player: Player) -> Array[Card]:
	var creatures: Array[Card] = []
	if game_manager == null or player == null:
		return creatures
	for zone in player.frontline_zones + player.reserve_zones:
		for card in zone.cards:
			creatures.append(card)
	return creatures

func _divine_manifestation_on_field(game_manager: GameManager) -> bool:
	for player in game_manager.players:
		for card in player.god_zone.cards:
			if card != null and not card.is_face_down and card.has_type("Divine Manifestation"):
				return true
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card != null \
					and not card.is_face_down \
					and not card.is_stealth \
					and card.has_type("Divine Manifestation"):
					return true
	return false

func _update_art_variant(game_manager: GameManager) -> void:
	var variant_index := 1 if (game_manager != null and _divine_manifestation_on_field(game_manager)) else 0
	if not set_art_variant(variant_index):
		set_art_variant(0)
