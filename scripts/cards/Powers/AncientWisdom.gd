extends PowerCard
class_name AncientWisdom

const UNLOCK_COST := 4
const MAGE_STR_BONUS := 5
const BUFF_DURATION_TURNS := 2
const ART_PATH := "res://images/card_art/powers/book_glow_reduced.png"
const BUFF_SOURCE := "Ancient Wisdom"

var tracked_mage_buffs: Array[Dictionary] = []

func _init() -> void:
	super._init()
	card_name = BUFF_SOURCE
	mana_cost = UNLOCK_COST
	culture = "Ancient"
	card_types = ["Power", "Class Buff", "Mage"]
	ability_text = "When you play a spell, friendly Mages gain 5 Str until the end of your next turn."
	art_path = ART_PATH

func on_unlock(_game_manager: GameManager) -> void:
	print(card_name + " unlocked.")

func on_spell_played(player: Player, _spell_card: Card, game_manager: GameManager) -> void:
	if player == null or player != card_owner:
		return

	for mage in _get_friendly_mages(game_manager):
		if mage == null:
			continue
		var source := _make_buff_source(mage)
		mage.clear_buffs_from(source)
		mage.add_buff(source, MAGE_STR_BONUS, 0, 0, self, card_owner, "power_buff")

		var refreshed := false
		for buff in tracked_mage_buffs:
			if buff.get("creature") == mage:
				buff["remaining_turns"] = BUFF_DURATION_TURNS
				buff["source"] = source
				refreshed = true
				break
		if not refreshed:
			tracked_mage_buffs.append({
				"creature": mage,
				"remaining_turns": BUFF_DURATION_TURNS,
				"source": source,
			})

		print("%s: %s gains %d Str until the end of your next turn." % [card_name, mage.card_name, MAGE_STR_BONUS])

func on_turn_end(_game_manager: GameManager) -> void:
	super.on_turn_end(_game_manager)
	if tracked_mage_buffs.is_empty():
		return

	for i in range(tracked_mage_buffs.size() - 1, -1, -1):
		var buff := tracked_mage_buffs[i]
		buff["remaining_turns"] = int(buff.get("remaining_turns", 0)) - 1
		tracked_mage_buffs[i] = buff

		if int(buff.get("remaining_turns", 0)) <= 0:
			var creature := buff.get("creature") as Card
			if creature != null:
				creature.clear_buffs_from(str(buff.get("source", "")))
				print("%s: %s loses %d Str." % [card_name, creature.card_name, MAGE_STR_BONUS])
			tracked_mage_buffs.remove_at(i)

func _get_friendly_mages(game_manager: GameManager) -> Array[Card]:
	var result: Array[Card] = []
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for creature in zone.cards:
			if creature.card_type == Card.CardType.CREATURE and creature.has_type("Mage"):
				result.append(creature)
	return result

func _make_buff_source(creature: Card) -> String:
	return "%s:%s" % [BUFF_SOURCE, creature.card_name]
