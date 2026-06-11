extends HexCard
class_name VisionOfOdin

const ART_PATH := "res://images/card_art/hexes/VisionofOdinEdit.png"
const STR_SWING := 7
const SPEED_SWING := 1
const EFFECT_SOURCE := "Vision of Odin"
const EFFECT_TYPE := "vision_of_odin_modifier"

func _init() -> void:
	super._init()
	card_name = "Vision of Odin"
	level = 3
	mana_cost = 0
	speed = 2
	culture = "Norse"
	card_types = ["Hex", "Battle Modifier"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	ability_text = "Choose a creature. It gets -7 Str and -1 Spd until end of turn; if it is a Norse creature, it gets +7 Str and +1 Spd instead."
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = ART_PATH
	targets = true

func can_respond_to_action(_action: CardAction) -> bool:
	return true

func get_priority_targets(game_manager: GameManager, _action: CardAction) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if is_valid_target(game_manager, card):
					valid_targets.append(card)
	return valid_targets

func on_activate_action(game_manager: GameManager, action: CardAction) -> void:
	var target := action.target as Card
	if not is_valid_target(game_manager, target):
		if game_manager != null:
			game_manager.note_player_feedback("%s fizzles: choose a creature." % card_name)
		if card_owner != null:
			card_owner.move_card(self, card_owner.graveyard_zone)
		return

	var viewer := game_manager.get_feedback_viewer()
	var target_name := target.get_target_log_display_name(viewer)
	var is_norse_target := _is_norse_creature(target)
	var str_delta := STR_SWING if is_norse_target else -STR_SWING
	var spd_delta := SPEED_SWING if is_norse_target else -SPEED_SWING

	target.add_buff(
		EFFECT_SOURCE,
		str_delta,
		0,
		spd_delta,
		self,
		card_owner,
		EFFECT_TYPE,
		{"expires_turn": game_manager.turn_number}
	)

	if is_norse_target:
		game_manager.note_player_feedback(
			"%s grants %s +%d Str and +%d Spd until end of turn." % [
				card_name,
				target_name,
				STR_SWING,
				SPEED_SWING
			]
		)
	else:
		game_manager.note_player_feedback(
			"%s gives %s -%d Str and -%d Spd until end of turn." % [
				card_name,
				target_name,
				STR_SWING,
				SPEED_SWING
			]
		)

	card_owner.move_card(self, card_owner.graveyard_zone)

func is_valid_target(game_manager: GameManager, target: Card) -> bool:
	if game_manager == null or target == null:
		return false
	if target.card_type != Card.CardType.CREATURE:
		return false
	if target.current_zone == null or not target.current_zone.is_board_zone():
		return false
	if game_manager.is_immune_to_source(target, self):
		return false
	return true

func _is_norse_creature(target: Card) -> bool:
	return target != null and target.culture == "Norse"
