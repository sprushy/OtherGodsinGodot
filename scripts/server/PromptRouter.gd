extends RefCounted
class_name PromptRouter

## Converts server-side prompt payloads into serializable dictionaries.
## This is the first step toward decoupling authoritative match logic from UI scenes.

var game_manager: GameManager = null

func _init(p_game_manager: GameManager = null) -> void:
	game_manager = p_game_manager

func serialize_prompt_data(data: Dictionary) -> Dictionary:
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
	return serialized

func build_prompt_envelope(player_index: int, prompt_type: String, data: Dictionary) -> Dictionary:
	return {
		"type": prompt_type,
		"data": serialize_prompt_data(data),
		"player_index": player_index,
	}
