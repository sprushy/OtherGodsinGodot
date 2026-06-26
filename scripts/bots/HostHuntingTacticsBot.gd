extends PracticeFuzzPlayerBot
class_name HostHuntingTacticsBot

# Drives one seat of the hunting_tactics dedicated-server smoke. It reuses the
# full ThorPracticeBot main-phase / attack decision loop (summon creatures,
# declare attacks) but answers the "hunting_tactics" prompt through the network
# event path, since on a dedicated-server client match_manager.request_ui_interaction
# never fires for these prompts (they arrive via match_client.game_event_received).

var match_client = null
# Outcome tracking read by the smoke driver: did this bot answer a hunting_tactics
# prompt, and did the game progress (state changed) afterwards?
var hunting_tactics_answered: bool = false
var hunting_tactics_answer_turn: int = -1
var last_observed_turn: int = -1
var progressed_after_hunting_tactics: bool = false

func attach_networked(
	p_game_manager: GameManager,
	p_match_manager: MatchManager,
	p_game_input: GameInput,
	p_player_index: int,
	p_match_client
) -> void:
	attach(p_game_manager, p_match_manager, p_game_input, p_player_index)
	match_client = p_match_client
	if match_client != null and match_client.has_signal("game_event_received"):
		if not match_client.game_event_received.is_connected(_on_network_game_event):
			match_client.game_event_received.connect(_on_network_game_event)

func detach() -> void:
	if match_client != null and is_instance_valid(match_client) \
			and match_client.has_signal("game_event_received") \
			and match_client.game_event_received.is_connected(_on_network_game_event):
		match_client.game_event_received.disconnect(_on_network_game_event)
	match_client = null
	super.detach()

func _on_network_game_event(event_type: String, data: Dictionary) -> void:
	if event_type != "ui_interaction":
		return
	var type: String = data.get("type", "")
	var prompt_player_index := int(data.get("player_index", player_index))
	if prompt_player_index != player_index:
		return
	var payload: Dictionary = data.get("data", {})
	match type:
		"hunting_tactics":
			_submit_hunting_tactics_choice(payload)
		"intercept":
			game_input.submit_action({"type": "intercept_decision", "interceptor_uid": ""})
		"priority":
			# Hand off to the standard priority handling (pass) via the parent poll loop.
			poll()

func _on_match_ui_interaction(prompt_player_index: int, type: String, data: Dictionary) -> void:
	# In-process fallback (used if this bot ever runs against an authoritative
	# in-process MatchManager). Mirrors the network handler.
	if prompt_player_index != player_index:
		return
	match type:
		"hunting_tactics":
			_submit_hunting_tactics_choice(data)
		_:
			super._on_match_ui_interaction(prompt_player_index, type, data)

func _submit_hunting_tactics_choice(data: Dictionary) -> void:
	var source_uid := str(data.get("source_uid", "")).strip_edges()
	var attacker_uid := str(data.get("attacker_uid", "")).strip_edges()
	# Pick the first supporter offered (a Raven) so the buff actually applies.
	# If none were offered, decline with an empty list so the attack still resumes.
	var chosen_uids: Array[String] = []
	for raw_uid in data.get("target_uids", []):
		var uid := str(raw_uid).strip_edges()
		if not uid.is_empty():
			chosen_uids.append(uid)
			break
	hunting_tactics_answered = true
	if game_manager != null:
		hunting_tactics_answer_turn = game_manager.turn_number
	_submit_action({
		"type": "hunting_tactics_choice",
		"source_uid": source_uid,
		"attacker_uid": attacker_uid,
		"chosen_uids": chosen_uids,
	})

func poll() -> void:
	super.poll()
	if hunting_tactics_answered and not progressed_after_hunting_tactics and game_manager != null:
		# Progress = the game state moved on after the hunting_tactics answer,
		# i.e. turn advanced or the action stack cleared (combat resolved).
		if game_manager.turn_number > hunting_tactics_answer_turn \
				or (game_manager.action_stack != null and game_manager.action_stack.is_empty()):
			progressed_after_hunting_tactics = true
