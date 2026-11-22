extends RefCounted
class_name PromptRouter

## Converts server-side prompt payloads into serializable dictionaries.
## This is the first step toward decoupling authoritative match logic from UI scenes.

var game_manager: GameManager = null

func _init(p_game_manager: GameManager = null) -> void:
	game_manager = p_game_manager

func serialize_prompt_data(data: Dictionary, prompt_type: String = "") -> Dictionary:
	var serialized := data.duplicate()
	for key in serialized.keys():
		var value = serialized[key]
		if value is Card:
			serialized[key + "_uid"] = value.uid
			serialized.erase(key)
		elif value is Player:
			var player_index := -1
			if game_manager != null:
				player_index = game_manager.players.find(value)
			serialized[key + "_player_index"] = player_index
			serialized.erase(key)
		else:
			serialized[key] = GameState.sanitize_network_value(value, game_manager)
	if prompt_type in ["huginn_perish_prime", "muninn_perish_prime"]:
		_add_serialized_target_cards(serialized)
	return serialized

func _add_serialized_target_cards(serialized: Dictionary) -> void:
	if game_manager == null or serialized.has("target_cards"):
		return
	var raw_target_uids = serialized.get("target_uids", [])
	if not (raw_target_uids is Array):
		return
	var target_cards := []
	for raw_uid in raw_target_uids:
		var uid := str(raw_uid).strip_edges()
		if uid.is_empty():
			continue
		var card := game_manager.get_card_by_uid(uid)
		if card != null:
			target_cards.append(GameState.serialize_embedded_card(card))
	serialized["target_cards"] = target_cards

func build_prompt_envelope(player_index: int, prompt_type: String, data: Dictionary) -> Dictionary:
	return {
		"type": prompt_type,
		"data": serialize_prompt_data(data, prompt_type),
		"player_index": player_index,
	}
