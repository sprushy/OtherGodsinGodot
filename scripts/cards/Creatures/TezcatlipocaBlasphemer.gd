extends CreatureCard
class_name TezcatlipocaBlasphemer

const ART_PATH := "res://images/card_art/creatures/TezBlasphemerEdit.png"

func _init() -> void:
	super._init()
	card_name = "Tezcatlipoca Blasphemer"
	card_types = ["Mage", "Shaman", "Priest", "Nahuatl Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 8
	strength = 12
	targets = true
	ability_text = "[b]Blood Magic[/b] ([b]Activate[/b], sacrifice 1 creature): Destroy a magical card."
	flavor_text = ""
	culture = "Nahuatl"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func get_activation_label() -> String:
	return "Blood Magic"

func can_activate(game_manager: GameManager) -> bool:
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
	if get_valid_blood_magic_sacrifices().is_empty():
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if get_controller() != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if current_zone == null or not current_zone.is_board_zone():
		return card_name + " must be on the field."
	if is_face_down or is_stealth or is_prepared:
		return card_name + " must be face-up on the field."
	if abilities_suppressed():
		return card_name + " is unable to use Blood Magic."
	if is_activation_locked(game_manager):
		return card_name + " cannot activate this turn."
	if is_sleeping:
		return card_name + " is asleep."
	if get_valid_blood_magic_sacrifices().is_empty():
		return card_name + " needs a friendly creature to sacrifice."
	if get_valid_targets(game_manager).is_empty():
		return card_name + " has no magical cards to destroy."
	return card_name + " cannot activate right now."

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _is_valid_blood_magic_target(card):
					valid_targets.append(card)
	return valid_targets

func get_valid_blood_magic_sacrifices() -> Array[Card]:
	var valid_sacrifices: Array[Card] = []
	var controller := get_controller()
	if controller == null:
		return valid_sacrifices
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if _is_valid_blood_magic_sacrifice(card):
				valid_sacrifices.append(card)
	return valid_sacrifices

func activate(game_manager: GameManager, target_data = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return

	var target := _resolve_target_from_activation_data(game_manager, target_data)
	var sacrifice := _resolve_sacrifice_from_activation_data(game_manager, target_data)
	if sacrifice == null:
		var valid_sacrifices := get_valid_blood_magic_sacrifices()
		if valid_sacrifices.size() == 1:
			sacrifice = valid_sacrifices[0]

	var result := begin_blood_magic_activation(game_manager, target, sacrifice)
	if game_manager != null and result.strip_edges() != "":
		game_manager.note_player_feedback(result)

func begin_blood_magic_activation(game_manager: GameManager, target: Card, sacrifice: Card) -> String:
	if game_manager == null:
		return card_name + " cannot resolve Blood Magic right now."
	if sacrifice == null or sacrifice not in get_valid_blood_magic_sacrifices():
		return card_name + " needs a friendly creature to sacrifice for Blood Magic."

	var viewer := game_manager.get_feedback_viewer()
	var sacrifice_name := sacrifice.get_target_log_display_name(viewer)
	var target_name := ""
	if target != null:
		target_name = target.get_target_log_display_name(viewer)

	var continue_callback := Callable(self, "_continue_blood_magic_after_sacrifice").bind(
		game_manager,
		target,
		sacrifice,
		sacrifice_name,
		target_name
	)
	game_manager.request_send_to_graveyard(sacrifice, continue_callback, false, true)
	return ""

func _continue_blood_magic_after_sacrifice(
	game_manager: GameManager,
	target: Card,
	sacrifice: Card,
	sacrifice_name: String,
	target_name: String
) -> void:
	if game_manager == null:
		return

	var paid := sacrifice == null or sacrifice.current_zone == null or not sacrifice.current_zone.is_board_zone()
	if not paid:
		if sacrifice == self:
			game_manager.note_player_feedback("%s could not sacrifice itself for Blood Magic." % card_name)
		else:
			game_manager.note_player_feedback("%s could not sacrifice %s for Blood Magic." % [card_name, sacrifice_name])
		return

	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		game_manager.note_player_feedback(
			"%s sacrificed %s for Blood Magic, but there was no valid magical card to destroy." % [
				card_name,
				sacrifice_name
			]
		)
		return
	if game_manager.is_immune_to_source(target, self):
		game_manager.note_player_feedback(
			"%s sacrificed %s for Blood Magic, but %s is immune to %s." % [
				card_name,
				sacrifice_name,
				target.get_target_log_display_name(game_manager.get_feedback_viewer()),
				card_name
			]
		)
		return

	if target_name == "":
		target_name = target.get_target_log_display_name(game_manager.get_feedback_viewer())
	var finish_callback := Callable(self, "_finish_blood_magic_after_destroy").bind(
		game_manager,
		target,
		sacrifice_name,
		target_name
	)
	game_manager.request_send_to_graveyard(target, finish_callback, false, true)

func _finish_blood_magic_after_destroy(
	game_manager: GameManager,
	target: Card,
	sacrifice_name: String,
	target_name: String
) -> void:
	if game_manager == null:
		return
	var destroyed := target == null or target.current_zone == null or not target.current_zone.is_board_zone()
	if not destroyed:
		game_manager.note_player_feedback("%s sacrificed %s, but failed to destroy %s with Blood Magic." % [
			card_name,
			sacrifice_name,
			target_name
		])
		return
	game_manager.note_player_feedback("%s sacrificed %s to destroy %s with Blood Magic." % [
		card_name,
		sacrifice_name,
		target_name
	])

func _resolve_target_from_activation_data(game_manager: GameManager, target_data) -> Card:
	if target_data is Card:
		return target_data as Card
	if target_data is Dictionary:
		var data := target_data as Dictionary
		if data.get("target", null) is Card:
			return data.get("target", null) as Card
		var target_uid := str(data.get("target_uid", ""))
		if target_uid != "" and game_manager != null:
			return game_manager.get_card_by_uid(target_uid)
	return null

func _resolve_sacrifice_from_activation_data(game_manager: GameManager, target_data) -> Card:
	if target_data is Dictionary:
		var data := target_data as Dictionary
		if data.get("sacrifice", null) is Card:
			return data.get("sacrifice", null) as Card
		var sacrifice_uid := str(data.get("sacrifice_uid", ""))
		if sacrifice_uid != "" and game_manager != null:
			return game_manager.get_card_by_uid(sacrifice_uid)
	return null

func _is_valid_blood_magic_target(target: Card) -> bool:
	return target != null \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.is_magical_card()

func _is_valid_blood_magic_sacrifice(card: Card) -> bool:
	var controller := get_controller()
	return card != null \
		and controller != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.get_controller() == controller \
		and card.can_be_used_for_creature_sacrifice \
		and card.current_zone != null \
		and card.current_zone.is_board_zone()
