extends EquipmentCard
class_name SharurTheFlyingMace

const RETURN_TO_HAND_COST := 4
const ART_PATH := "res://images/card_art/equipment/SharurEdit.png"

func _init() -> void:
	super._init()
	card_name = "Sharur, the Flying Mace"
	culture = "Ancient"
	card_types = ["Weapon", "Mace"]
	level = 4
	mana_cost = 2
	speed = 3
	strength_modifier = 9
	is_legendary = true
	ability_text = "Can be equipped to Ancient creatures, Warriors, and Demons. Gain 9 Str. If this unequipped card is on the field, equip it to a friendly Ancient Warrior or Demon when available (Spd 3). If this card would be destroyed or dragged you may pay 4 mana and return it to your hand instead (Spd 3)."
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func can_equip_to(creature: Card) -> bool:
	return super.can_equip_to(creature) and _is_valid_bearer(creature)

func on_any_card_moved(game_manager: GameManager, moved_card: Card, from_zone: Zone, to_zone: Zone) -> void:
	if moved_card == null:
		return
	_try_auto_equip(game_manager)

func get_self_graveyard_replacement_zone(
	game_manager: GameManager,
	combat_death: bool,
	_destruction: bool,
	send_to_abyss: bool
) -> Zone:
	if card_owner == null:
		return null
	if combat_death or send_to_abyss:
		return null
	if current_zone == null or not current_zone.is_board_zone():
		return null
	if game_manager != null and not game_manager.can_player_add_to_hand_now(card_owner):
		return null
	if card_owner.mana < RETURN_TO_HAND_COST:
		return null

	card_owner.spend_mana(RETURN_TO_HAND_COST)
	if game_manager != null:
		game_manager.note_player_feedback(
			"%s pays %d mana to return %s to hand instead." % [
				card_owner.player_name,
				RETURN_TO_HAND_COST,
				card_name
			]
		)
	return card_owner.hand_zone

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	lines.append("Unequipped on field: auto-equips to a friendly Ancient Warrior or Demon")
	lines.append("If it would leave the field for graveyard, pay %d to return it to hand instead" % RETURN_TO_HAND_COST)
	return lines

func _try_auto_equip(game_manager: GameManager) -> void:
	if abilities_suppressed():
		return
	if equipped_on != null:
		return
	if current_zone == null or not current_zone.is_board_zone():
		return

	var bearer := _find_available_auto_bearer()
	if not _is_valid_auto_bearer(bearer):
		return
	if bearer.current_zone == null or not bearer.current_zone.is_board_zone():
		return
	if current_zone != bearer.current_zone:
		card_owner.move_card(self, bearer.current_zone)
	if not equip_to(bearer):
		return
	if game_manager != null:
		game_manager.note_player_feedback("%s auto-equips to %s." % [card_name, bearer.card_name])

func _is_valid_bearer(creature: Card) -> bool:
	return creature != null and (
		creature.has_type("Ancient Creature")
		or creature.has_type("Warrior")
		or creature.has_type("Demon")
	)

func _is_valid_auto_bearer(creature: Card) -> bool:
	if creature == null:
		return false
	if creature.get_controller() != get_controller():
		return false
	if creature.has_type("Demon"):
		return true
	return creature.has_type("Ancient Creature") and creature.has_type("Warrior")

func _find_available_auto_bearer() -> Card:
	if card_owner == null:
		return null
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		var creature := zone.get_creature()
		if _is_valid_auto_bearer(creature) and can_equip_to(creature):
			return creature
	return null
