extends CreatureCard
class_name Byggvir

var brewing_reveal_pending: bool = false

func _init() -> void:
	super._init()
	card_name = "Byggvir"
	card_types = ["Human", "Servant"]
	level = 2
	mana_cost = 0
	speed = 2
	resilience = 10
	strength = 10
	sacrifice_cost = 0
	ability_text = "Brewing (reveal): Flip over a Mead power, activate a Mead power, or return a Mead card from your graveyard to your hand."
	flavor_text = ""
	culture = "Norse"
	artist = "Tim Nguyen"
	art_path = "res://images/card_art/creatures/byggvir.png"

func on_reveal(game_manager: GameManager) -> void:
	brewing_reveal_pending = false
	if game_manager == null or get_controller() == null:
		return
	var options: Array[Dictionary] = get_brewing_options(game_manager)
	if options.size() == 1:
		var feedback := resolve_brewing_option(game_manager, options[0])
		if feedback.strip_edges() != "":
			game_manager.note_player_feedback(feedback)
		return
	if options.is_empty():
		game_manager.note_player_feedback("%s found no Brewing option to reveal." % card_name)
		return
	brewing_reveal_pending = true
	game_manager.decision_requested.emit(get_controller(), "byggvir_reveal", {
		"source_uid": uid,
		"options": serialize_brewing_options(game_manager),
	})

func get_brewing_options(game_manager: GameManager) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var controller: Player = get_controller()
	if controller == null or game_manager == null:
		return options

	for zone in controller.power_zones:
		if zone.cards.is_empty():
			continue
		var card: Card = zone.cards[0]
		if not _is_mead_card(card) or card is not PowerCard:
			continue
		var power: PowerCard = card as PowerCard
		if not power.is_face_down and not power.is_muted and power.can_activate(game_manager):
			if power.has_method("get_valid_targets"):
				var valid_targets: Array = power.get_valid_targets(game_manager)
				for target in valid_targets:
					if target is Card:
						options.append({
							"kind": "activate_targeted",
							"power": power,
							"target": target
						})
				if not valid_targets.is_empty():
					continue
			options.append({
				"kind": "activate",
				"power": power
			})
		if power.is_face_down and not power.is_muted:
			options.append({
				"kind": "flip",
				"power": power
			})

	for card in controller.graveyard_zone.cards:
		if _is_mead_card(card):
			options.append({
				"kind": "return",
				"card": card
			})
	return options

func get_brewing_option_label(option: Dictionary) -> String:
	var kind: String = option.get("kind", "")
	match kind:
		"flip":
			var power: Card = option.get("power", null) as Card
			return "Flip %s face up" % (power.card_name if power != null else "Mead power")
		"activate":
			var power: Card = option.get("power", null) as Card
			return "Activate %s" % (power.card_name if power != null else "Mead power")
		"activate_targeted":
			var power: Card = option.get("power", null) as Card
			var target: Card = option.get("target", null) as Card
			return "Activate %s on %s" % [
				power.card_name if power != null else "Mead power",
				target.card_name if target != null else "target"
			]
		"return":
			var mead_card: Card = option.get("card", null) as Card
			return "Return %s to hand" % (mead_card.card_name if mead_card != null else "Mead card")
	return "Use Brewing"

func resolve_brewing_option(game_manager: GameManager, option: Dictionary) -> String:
	brewing_reveal_pending = false
	var kind: String = option.get("kind", "")
	match kind:
		"flip":
			var power: PowerCard = option.get("power", null) as PowerCard
			if power == null:
				return card_name + " had no Mead power to flip."
			power.is_face_down = false
			power.is_publicly_revealed = false
			power.is_muted = false
			power.mute_turns_remaining = 0
			power.on_unlock(game_manager)
			return "%s reveals and flips %s face up." % [card_name, power.card_name]
		"activate":
			var power: PowerCard = option.get("power", null) as PowerCard
			if power == null:
				return card_name + " had no Mead power to activate."
			power.activate(game_manager)
			return "%s reveals and activates %s." % [card_name, power.card_name]
		"activate_targeted":
			var power: PowerCard = option.get("power", null) as PowerCard
			var target: Card = option.get("target", null) as Card
			if power == null or target == null:
				return card_name + " had no valid Mead activation target."
			power.activate(game_manager, target)
			return "%s reveals and activates %s on %s." % [card_name, power.card_name, target.card_name]
		"return":
			var mead_card: Card = option.get("card", null) as Card
			if mead_card == null:
				return card_name + " had no Mead card to return."
			get_controller().move_card(mead_card, get_controller().hand_zone)
			return "%s reveals and returns %s from the graveyard to hand." % [card_name, mead_card.card_name]
	return card_name + " had no Brewing option."

func resolve_brewing_option_from_payload(game_manager: GameManager, payload: Dictionary) -> String:
	var option := find_matching_brewing_option(game_manager, payload)
	if option.is_empty():
		return card_name + " had no valid Brewing option."
	return resolve_brewing_option(game_manager, option)

func serialize_brewing_options(game_manager: GameManager) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for option in get_brewing_options(game_manager):
		serialized.append(serialize_brewing_option(option))
	return serialized

func serialize_brewing_option(option: Dictionary) -> Dictionary:
	var serialized := {
		"kind": str(option.get("kind", "")),
		"label": get_brewing_option_label(option),
	}
	var power := option.get("power", null) as Card
	if power != null:
		serialized["power_uid"] = power.uid
	var target := option.get("target", null) as Card
	if target != null:
		serialized["target_uid"] = target.uid
	var card := option.get("card", null) as Card
	if card != null:
		serialized["card_uid"] = card.uid
	return serialized

func find_matching_brewing_option(game_manager: GameManager, payload: Dictionary) -> Dictionary:
	for option in get_brewing_options(game_manager):
		if _brewing_option_matches_payload(option, payload):
			return option
	return {}

func _brewing_option_matches_payload(option: Dictionary, payload: Dictionary) -> bool:
	if str(option.get("kind", "")) != str(payload.get("kind", "")):
		return false
	var power := option.get("power", null) as Card
	var power_uid: String = str(payload.get("power_uid", ""))
	if power_uid != "":
		if power == null or power.uid != power_uid:
			return false
	elif power != null:
		return false
	var target := option.get("target", null) as Card
	var target_uid: String = str(payload.get("target_uid", ""))
	if target_uid != "":
		if target == null or target.uid != target_uid:
			return false
	elif target != null:
		return false
	var card := option.get("card", null) as Card
	var card_uid: String = str(payload.get("card_uid", ""))
	if card_uid != "":
		if card == null or card.uid != card_uid:
			return false
	elif card != null:
		return false
	return true

func _flip_mead_power(game_manager: GameManager) -> bool:
	for zone in get_controller().power_zones:
		if zone.cards.is_empty():
			continue
		var card: Card = zone.cards[0]
		if not _is_mead_card(card):
			continue
		if card is not PowerCard:
			continue
		var power := card as PowerCard
		if not power.is_face_down or power.is_muted:
			continue
		power.is_face_down = false
		power.is_publicly_revealed = false
		power.is_muted = false
		power.mute_turns_remaining = 0
		power.on_unlock(game_manager)
		return true
	return false

func _activate_mead_power(game_manager: GameManager) -> bool:
	for zone in get_controller().power_zones:
		if zone.cards.is_empty():
			continue
		var card: Card = zone.cards[0]
		if not _is_mead_card(card):
			continue
		if card is not PowerCard:
			continue
		var power := card as PowerCard
		if power.is_face_down or power.is_muted or not power.can_activate(game_manager):
			continue
		if power.has_method("get_valid_targets"):
			var valid_targets: Array = power.get_valid_targets(game_manager)
			if not valid_targets.is_empty():
				power.activate(game_manager, valid_targets[0] as Card)
				return true
		power.activate(game_manager)
		return true
	return false

func _return_mead_from_grave() -> bool:
	var controller := get_controller()
	if controller == null:
		return false
	for card in controller.graveyard_zone.cards:
		if not _is_mead_card(card):
			continue
		controller.move_card(card, controller.hand_zone)
		return true
	return false

func _is_mead_card(card: Card) -> bool:
	return card != null and card.has_type("Mead")

func has_pending_brewing_reveal() -> bool:
	return brewing_reveal_pending

func consume_brewing_reveal_pending() -> bool:
	var was_pending: bool = brewing_reveal_pending
	brewing_reveal_pending = false
	return was_pending

