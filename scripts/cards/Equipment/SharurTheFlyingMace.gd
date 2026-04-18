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
	ability_text = "Can be equipped to Ancient creatures, Warriors, and Demons. Gain 9 Str. If this unequipped card is on the field, equip to a friendly Ancient Warrior or Demon (Spd 3). If Sharur would be destroyed or stolen, you may pay 4 mana and return it to your hand instead (Spd 3)."
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func can_equip_to(creature: Card) -> bool:
	return super.can_equip_to(creature) and _is_valid_bearer(creature)

func get_cannot_equip_reason(creature: Card) -> String:
	if creature == null:
		return super.get_cannot_equip_reason(creature)
	if not creature.can_receive_equipment():
		return super.get_cannot_equip_reason(creature)
	if not _is_valid_bearer(creature):
		return card_name + " can only be equipped to Ancient creatures, Warriors, or Demons."
	return super.get_cannot_equip_reason(creature)

func request_self_graveyard_replacement_choice(
	game_manager: GameManager,
	combat_death: bool,
	destruction: bool,
	send_to_abyss: bool,
	continue_callback: Callable = Callable()
) -> bool:
	if combat_death or not destruction or send_to_abyss:
		return false
	if not can_offer_return_to_hand_replacement(game_manager):
		return false
	return game_manager != null and game_manager.begin_pending_return_to_hand_choice(
		self,
		"destroyed",
		continue_callback
	)

func request_self_steal_replacement_choice(game_manager: GameManager, thief: Card) -> bool:
	if thief == null or thief.get_controller() == get_controller():
		return false
	if not can_offer_return_to_hand_replacement(game_manager):
		return false
	return game_manager != null and game_manager.begin_pending_return_to_hand_choice(
		self,
		"stolen",
		Callable(),
		false,
		thief
	)

func can_offer_return_to_hand_replacement(game_manager: GameManager) -> bool:
	if card_owner == null:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if game_manager != null and not game_manager.can_player_add_to_hand_now(card_owner):
		return false
	return card_owner.mana >= RETURN_TO_HAND_COST

func get_return_to_hand_prompt_text(reason: String = "destroyed") -> String:
	if reason == "stolen":
		return "Pay %d mana to return %s to your hand instead of letting it be stolen?" % [
			RETURN_TO_HAND_COST,
			card_name
		]
	return "Pay %d mana to return %s to your hand instead of letting it be destroyed?" % [
		RETURN_TO_HAND_COST,
		card_name
	]

func resolve_return_to_hand_replacement_choice(
	game_manager: GameManager,
	pay_cost: bool,
	reason: String = "destroyed"
) -> String:
	if not pay_cost:
		if reason == "stolen":
			return "%s stays on the field and can be stolen." % card_name
		return "%s stays on the field and is destroyed." % card_name
	if not can_offer_return_to_hand_replacement(game_manager):
		return "%s can no longer return to hand." % card_name

	card_owner.spend_mana(RETURN_TO_HAND_COST)
	card_owner.move_card(self, card_owner.hand_zone)
	if reason == "stolen":
		return "%s pays %d mana to return %s to hand instead of letting it be stolen." % [
			card_owner.player_name,
			RETURN_TO_HAND_COST,
			card_name
		]
	return "%s pays %d mana to return %s to hand instead of letting it be destroyed." % [
		card_owner.player_name,
		RETURN_TO_HAND_COST,
		card_name
	]

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	lines.append("Unequipped on field: can equip to a friendly Ancient Warrior or Demon")
	lines.append("If it would be destroyed or stolen, you may pay %d to return it to hand instead" % RETURN_TO_HAND_COST)
	return lines

func _is_valid_bearer(creature: Card) -> bool:
	return creature != null and (
		creature.has_type("Ancient Creature")
		or creature.has_type("Warrior")
		or creature.has_type("Demon")
	)

