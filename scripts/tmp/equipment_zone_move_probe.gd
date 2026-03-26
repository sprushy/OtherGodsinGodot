extends SceneTree

const PlayerScript = preload("res://scripts/Other/player.gd")
const ZoneScript = preload("res://scripts/Other/Zone.gd")
const BrownBearScript = preload("res://scripts/cards/Creatures/BrownBear.gd")
const BeardedAxeScript = preload("res://scripts/cards/Equipment/BeardedAxe.gd")

func _initialize_player(player) -> void:
	player._initialize_zones()

func _assert_state(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)

func _init() -> void:
	var player = PlayerScript.new()
	_initialize_player(player)

	var creature = BrownBearScript.new()
	creature.card_owner = player
	player.frontline_zones[0].add_card(creature)

	var equipment = BeardedAxeScript.new()
	equipment.card_owner = player
	player.frontline_zones[0].add_card(equipment)
	equipment.equip_to(creature)

	player.move_card(creature, player.reserve_zones[0])
	_assert_state(creature.current_zone == player.reserve_zones[0], "Creature did not move to reserve.")
	_assert_state(equipment.current_zone == player.reserve_zones[0], "Equipment did not follow creature to reserve.")
	_assert_state(equipment.equipped_on == creature, "Equipment lost attachment during board move.")
	_assert_state(creature.equipment.has(equipment), "Creature lost equipment reference during board move.")

	player.move_card(creature, player.graveyard_zone)
	_assert_state(creature.current_zone == player.graveyard_zone, "Creature did not move to graveyard.")
	_assert_state(equipment.current_zone == player.reserve_zones[0], "Equipment should stay in its last board zone when creature leaves the board.")
	_assert_state(equipment.equipped_on == null, "Equipment should unequip when creature leaves the board.")
	_assert_state(not creature.equipment.has(equipment), "Creature should lose equipment reference when leaving the board.")

	print("equipment_zone_move_probe: PASS")
	quit()
