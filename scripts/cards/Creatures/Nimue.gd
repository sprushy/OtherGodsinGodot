extends CreatureCard
class_name Nimue

func _init() -> void:
	super._init()
	card_name = "Nimue"
	card_types = ["Human", "Mage"]
	level = 5
	mana_cost = 5
	sacrifice_cost = 0
	speed = 2
	strength = 5
	resilience = 36
	targets = true
	ability_text = "[b]Entomb[/b] ([b]Major Action[/b]): Pay mana equal to a creature's Lvl to [b]Shelve[/b] it.\n[b]Present[/b] ([b]Major Action[/b]): Put an Equipment card from your graveyard onto the field."
	flavor_text = ""
	culture = "Triskelion"
	artist = ""
	art_path = "res://images/card_art/creatures/NimueEdit.png"

func get_activation_label() -> String:
	return "Abilities"

func can_activate(game_manager: GameManager) -> bool:
	if not _can_activate_base(game_manager):
		return false
	return can_activate_entomb(game_manager) or can_activate_present(game_manager)

func can_activate_entomb(game_manager: GameManager) -> bool:
	if not _can_activate_base(game_manager):
		return false
	return not get_valid_entomb_targets(game_manager).is_empty()

func can_activate_present(game_manager: GameManager) -> bool:
	if not _can_activate_base(game_manager):
		return false
	return not get_valid_present_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	valid_targets.append_array(get_valid_entomb_targets(game_manager))
	valid_targets.append_array(get_valid_present_targets(game_manager))
	return valid_targets

func get_valid_entomb_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	var controller := get_controller()
	if game_manager == null or controller == null:
		return valid_targets

	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _is_valid_entomb_target(card, controller):
					valid_targets.append(card)

	return valid_targets

func get_valid_present_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if game_manager == null or controller == null:
		return valid_targets
	if _get_present_zone(controller) == null:
		return valid_targets

	for card in controller.graveyard_zone.cards:
		if _is_valid_present_target(card, controller):
			valid_targets.append(card)

	return valid_targets

func activate(game_manager: GameManager, selection = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(card_name + " cannot activate right now.")
		return

	var controller := get_controller()
	if controller == null:
		if game_manager != null:
			game_manager.note_player_feedback(card_name + " has no controller.")
		return

	var target: Card = null
	var requested_ability := ""
	if selection is Card:
		target = selection
	elif selection is Dictionary:
		requested_ability = str((selection as Dictionary).get("ability", "")).to_lower()
		var target_uid := str((selection as Dictionary).get("target_uid", ""))
		if target_uid != "" and game_manager != null:
			target = game_manager.get_card_by_uid(target_uid)

	if requested_ability == "" and target != null:
		if _is_valid_present_target(target, controller):
			requested_ability = "present"
		elif _is_valid_entomb_target(target, controller):
			requested_ability = "entomb"

	var result := ""
	if requested_ability == "present":
		if target == null:
			result = "%s: choose an Equipment in your graveyard to Present." % card_name
		else:
			result = resolve_present(game_manager, target)
	elif requested_ability == "entomb":
		if target == null:
			result = "%s: choose a creature to Entomb." % card_name
		else:
			result = resolve_entomb(game_manager, target)
	elif _is_valid_present_target(target, controller):
		result = resolve_present(game_manager, target)
	elif _is_valid_entomb_target(target, controller):
		result = resolve_entomb(game_manager, target)
	else:
		result = "%s: choose a creature to Entomb or an Equipment in your graveyard to Present." % card_name

	if game_manager != null and result.strip_edges() != "":
		game_manager.note_player_feedback(result)

func resolve_entomb(game_manager: GameManager, target: Card) -> String:
	var controller := get_controller()
	if game_manager == null or controller == null:
		return card_name + " cannot Entomb right now."
	if not _is_valid_entomb_target(target, controller):
		return card_name + " fizzles: choose a creature you can afford to Entomb."
	if game_manager.is_guardian_protected(target, self):
		return target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is protected by Guardian!"
	if game_manager.is_immune_to_source(target, self):
		return target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is immune to " + card_name + "'s creature abilities this turn."

	var entomb_cost := target.get_effective_level()
	if not controller.spend_mana(entomb_cost):
		return "%s needs %d mana to Entomb %s." % [card_name, entomb_cost, target.card_name]

	var target_owner := target.card_owner
	if target_owner == null:
		return target.card_name + " has no owner to shelve."

	game_manager.send_to_deck_bottom_with_hook(target)
	if target.current_zone != target_owner.deck_zone:
		return "%s failed to Entomb %s." % [card_name, target.card_name]

	spend_major_creature_action()
	return "%s Entombs %s for %d mana." % [
		card_name,
		target.get_target_log_display_name(game_manager.get_feedback_viewer()),
		entomb_cost
	]

func resolve_present(game_manager: GameManager, target: Card) -> String:
	var controller := get_controller()
	if game_manager == null or controller == null:
		return card_name + " cannot Present right now."
	if not _is_valid_present_target(target, controller):
		return card_name + " fizzles: choose an Equipment card in your graveyard."

	var target_zone := _get_present_zone(controller)
	if target_zone == null:
		return card_name + " has no open friendly zone to Present equipment into."

	target.is_prepared = false
	target.is_face_down = false
	target.is_stealth = false
	controller.move_card(target, target_zone)
	if target.current_zone != target_zone:
		return "%s could not Present %s onto the field." % [card_name, target.card_name]

	spend_major_creature_action()
	return "%s Presents %s onto the field." % [card_name, target.card_name]

func _is_valid_entomb_target(target: Card, controller: Player) -> bool:
	return target != null \
		and controller != null \
		and target.card_type == Card.CardType.CREATURE \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and controller.mana >= target.get_effective_level()

func _is_valid_present_target(target: Card, controller: Player) -> bool:
	return target != null \
		and controller != null \
		and controller.graveyard_zone != null \
		and target.card_type == Card.CardType.EQUIPMENT \
		and target.current_zone == controller.graveyard_zone

func _get_present_zone(controller: Player) -> Zone:
	if controller == null:
		return null
	for zone in controller.frontline_zones:
		if zone != null and zone.cards.is_empty():
			return zone
	for zone in controller.reserve_zones:
		if zone != null and zone.cards.is_empty():
			return zone
	return null

func _can_activate_base(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_face_down or is_stealth or is_prepared:
		return false
	if abilities_suppressed() or is_activation_locked(game_manager):
		return false
	if is_sleeping:
		return false
	if not can_take_major_creature_action():
		return false
	return true
