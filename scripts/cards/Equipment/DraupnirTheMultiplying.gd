extends EquipmentCard
class_name DraupnirTheMultiplying

const MANA_GAIN := 2
const MAX_ACTIVATIONS := 3

var activations_used: int = 0
var _last_trigger_turn: int = -1

func _init() -> void:
	super._init()
	card_name = "Draupnir the Multiplying"
	culture = "Norse"
	card_types = ["Jewelry", "Ring"]
	mana_cost = 0
	ability_text = "While equipped, at the end of each of your turns, gain 2 mana. Send this card to the grave after 3 activations."
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/equipment/draupnir.jpg"

func on_turn_end(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	if not _is_actively_equipped():
		return

	var controller := get_controller()
	if controller == null:
		controller = card_owner
	if controller == null:
		return
	if controller != game_manager.current_player:
		return
	if game_manager.turn_player != null and controller != game_manager.turn_player:
		return
	if _last_trigger_turn == game_manager.turn_number:
		return
	_last_trigger_turn = game_manager.turn_number

	var mana_before := controller.mana
	controller.gain_mana(MANA_GAIN)
	activations_used += 1

	var feedback := "Turn %d end: %s grants %d mana to %s (%d -> %d, %d/%d)." % [
		game_manager.turn_number,
		card_name,
		MANA_GAIN,
		controller.player_name,
		mana_before,
		controller.mana,
		activations_used,
		MAX_ACTIVATIONS
	]
	if activations_used >= MAX_ACTIVATIONS:
		feedback += " It is sent to the grave."
		game_manager.call_deferred("_send_to_graveyard_with_hook", self, false, false)
	game_manager.note_player_feedback(feedback)

func on_removed(_game_manager: GameManager) -> void:
	reset_activation_counter()

func reset_activation_counter() -> void:
	activations_used = 0
	_last_trigger_turn = -1

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	lines.append("While equipped, end of your turn: gain %d mana" % MANA_GAIN)
	lines.append("Activations: %d/%d" % [activations_used, MAX_ACTIVATIONS])
	return lines

func _is_actively_equipped() -> bool:
	return equipped_on != null \
		and equipped_on.current_zone != null \
		and equipped_on.current_zone == current_zone
