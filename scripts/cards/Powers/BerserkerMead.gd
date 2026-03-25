extends PowerCard
class_name BerserkerMead

const UNLOCK_COST := 3
const STR_BONUS := 7
const BUFF_SOURCE := "Berserker Mead"

var affected_creatures: Array[Dictionary] = []

func _init() -> void:
	super._init()
	card_name = "Berserker Mead"
	mana_cost = UNLOCK_COST
	level = 2
	culture = "Norse"
	card_types = ["Buff", "Creature", "Mead"]
	ability_text = "Unlock (3): Choose a Norse creature under level 5; this turn it cannot be destroyed by your opponent's effects or creatures and it gains 7 Str. After any combat this turn, including attacks against followers, it falls asleep until the end of your next turn."
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/powers/poetmead.jpg"

func can_activate(game_manager: GameManager) -> bool:
	return not is_face_down \
		and not is_muted \
		and card_owner == game_manager.current_player \
		and not get_valid_targets(game_manager).is_empty()

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var targets: Array[Card] = []
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if card.card_type != Card.CardType.CREATURE:
				continue
			if card.level >= 5:
				continue
			if card.culture != "Norse":
				continue
			targets.append(card)
	return targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		print(card_name + ": Cannot activate.")
		return
	if target == null or target not in get_valid_targets(game_manager):
		print(card_name + ": Invalid target.")
		return

	target.clear_buffs_from(BUFF_SOURCE)
	target.remove_status_effects_by_name("berserker_mead_guard")
	target.add_buff(BUFF_SOURCE, STR_BONUS, 0, 0, self, card_owner, "power_buff")
	target.add_status_effect("berserker_mead_guard", BUFF_SOURCE, self, card_owner)
	_track_target(target)
	print("%s empowers %s with +%d Str and destruction immunity this turn." % [card_name, target.card_name, STR_BONUS])

func on_turn_end(_game_manager: GameManager) -> void:
	super.on_turn_end(_game_manager)
	for i in range(affected_creatures.size() - 1, -1, -1):
		var entry := affected_creatures[i]
		var creature := entry.get("creature") as Card
		var state := str(entry.get("state", ""))
		if creature == null:
			affected_creatures.remove_at(i)
			continue

		if state == "raging":
			creature.clear_buffs_from(BUFF_SOURCE)
			creature.remove_status_effects_by_name("berserker_mead_guard")
			affected_creatures.remove_at(i)
		else:
			var sleep_started_turn := int(entry.get("sleep_started_turn", -1))
			if _game_manager != null and _game_manager.turn_number > sleep_started_turn:
				creature.wake_up()
				affected_creatures.remove_at(i)

func on_creature_after_combat(game_manager: GameManager, attacker: Card, defender: Card) -> void:
	for i in range(affected_creatures.size() - 1, -1, -1):
		var entry := affected_creatures[i]
		if str(entry.get("state", "")) != "raging":
			continue
		var creature := entry.get("creature") as Card
		if creature == null:
			affected_creatures.remove_at(i)
			continue
		if creature != attacker and creature != defender:
			continue
		creature.clear_buffs_from(BUFF_SOURCE)
		creature.remove_status_effects_by_name("berserker_mead_guard")
		if creature.current_zone != null and creature.current_zone.is_board_zone():
			creature.apply_sleep(self)
		entry["state"] = "sleeping"
		entry["sleep_started_turn"] = game_manager.turn_number if game_manager != null else -1
		affected_creatures[i] = entry

func _track_target(target: Card) -> void:
	for i in range(affected_creatures.size() - 1, -1, -1):
		var creature := affected_creatures[i].get("creature") as Card
		if creature == target:
			affected_creatures.remove_at(i)
	affected_creatures.append({
		"creature": target,
		"state": "raging",
	})
