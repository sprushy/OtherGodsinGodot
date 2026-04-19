extends SceneTree

const PlayerScript = preload("res://scripts/Other/player.gd")
const BrownBearScript = preload("res://scripts/cards/Creatures/BrownBear.gd")
const BeardedAxeScript = preload("res://scripts/cards/Equipment/BeardedAxe.gd")

func _assert_state(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)

func _init() -> void:
	var player = PlayerScript.new()

	var creature = BrownBearScript.new()
	creature.card_owner = player
	player.frontline_zones[0].add_card(creature)

	var equipment = BeardedAxeScript.new()
	equipment.card_owner = player
	player.frontline_zones[0].add_card(equipment)
	equipment.equip_to(creature)

	var second_equipment = BeardedAxeScript.new()
	second_equipment.card_owner = player
	player.frontline_zones[0].add_card(second_equipment)
	second_equipment.equip_to(creature)

	var third_equipment = BeardedAxeScript.new()
	third_equipment.card_owner = player
	player.frontline_zones[0].add_card(third_equipment)
	third_equipment.equip_to(creature)

	player.move_card(creature, player.reserve_zones[0])
	_assert_state(creature.current_zone == player.reserve_zones[0], "Creature did not move to reserve.")
	_assert_state(equipment.current_zone == player.reserve_zones[0], "Equipment did not follow creature to reserve.")
	_assert_state(equipment.equipped_on == creature, "Equipment lost attachment during board move.")
	_assert_state(creature.equipment.has(equipment), "Creature lost equipment reference during board move.")

	player.move_card(creature, player.graveyard_zone)
	_assert_state(creature.current_zone == player.graveyard_zone, "Creature did not move to graveyard.")
	_assert_state(equipment.current_zone == player.reserve_zones[0], "First equipment should stay in the creature's last board zone when it leaves the board.")
	_assert_state(second_equipment.current_zone == player.reserve_zones[1], "Second equipment should move to the nearest available zone on the same row.")
	_assert_state(third_equipment.current_zone == player.reserve_zones[2], "Third equipment should continue filling the next nearest available zone on the same row.")
	_assert_state(equipment.equipped_on == null, "Equipment should unequip when creature leaves the board.")
	_assert_state(second_equipment.equipped_on == null, "Second equipment should unequip when creature leaves the board.")
	_assert_state(third_equipment.equipped_on == null, "Third equipment should unequip when creature leaves the board.")
	_assert_state(not creature.equipment.has(equipment), "Creature should lose equipment reference when leaving the board.")
	_assert_state(not creature.equipment.has(second_equipment), "Creature should lose the second equipment reference when leaving the board.")
	_assert_state(not creature.equipment.has(third_equipment), "Creature should lose the third equipment reference when leaving the board.")

	print("equipment_zone_move_probe: PASS")
	quit()
