extends CreatureCard
class_name DurinnSecondborn

const REFORGE_COST := 2

func _init() -> void:
	super._init()
	card_name = "Durinn Secondborn"
	card_types = ["Dwarf", "Smith", "Norse Creature", "Targeting"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 5
	strength = 14
	ability_text = "Reforge ([b]Impact[/b], 2 mana): Add a Weapon from either graveyard to your hand."
	flavor_text = ""
	culture = "Norse"
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/creatures/DurinnAIEdit.png"
	targets = true

func on_impact(game_manager: GameManager) -> void:
	var controller := get_controller()
	if controller == null or controller.mana < REFORGE_COST:
		if game_manager != null:
			game_manager.note_player_feedback("%s needs %d mana to reforge a weapon." % [card_name, REFORGE_COST])
		return
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("%s found no weapons to reforge." % card_name)
		return

	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(controller, "durinn_secondborn_impact", {
		source_uid = uid,
		target_uids = target_uids,
		queue_with_priority = true,
		event_name = "durinn_secondborn_impact",
	})

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for card in player.graveyard_zone.cards:
			if _is_valid_reforge_target(card):
				valid_targets.append(card)
	return valid_targets

func resolve_reforge_impact(game_manager: GameManager, target: Card) -> String:
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller for Reforge."
	if controller.mana < REFORGE_COST:
		return card_name + " needs %d mana to reforge a weapon." % REFORGE_COST
	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		return card_name + " found no valid weapon to reforge."
	if not controller.spend_mana(REFORGE_COST):
		return card_name + " needs %d mana to reforge a weapon." % REFORGE_COST

	var previous_owner := target.card_owner
	if previous_owner == null:
		previous_owner = controller
	previous_owner.move_card(target, controller.hand_zone)
	if target.current_zone != controller.hand_zone:
		return "%s could not move %s to hand." % [card_name, target.card_name]
	target.card_owner = controller

	var graveyard_label := "your graveyard" if previous_owner == controller else "%s's graveyard" % previous_owner.player_name
	return "%s reforged %s from %s into %s's hand." % [
		card_name,
		target.card_name,
		graveyard_label,
		controller.player_name
	]

func _is_valid_reforge_target(card: Card) -> bool:
	return card != null \
		and card.current_zone != null \
		and card.current_zone.zone_type == Zone.ZoneType.GRAVEYARD \
		and card.card_type == Card.CardType.EQUIPMENT \
		and card.has_type("Weapon")

