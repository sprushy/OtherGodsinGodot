extends PracticeFuzzPlayerBot
class_name HostHuntingTacticsBot

# Drives one seat of the hunting_tactics dedicated-server smoke. It reuses the
# full ThorPracticeBot main-phase / attack decision loop (summon creatures,
# declare attacks) but answers the "hunting_tactics" prompt through the network
# event path, since on a dedicated-server client match_manager.request_ui_interaction
# never fires for these prompts (they arrive via match_client.game_event_received).

# Outcome tracking read by the smoke driver: did this bot answer a hunting_tactics
# prompt, and did the game progress (state changed) afterwards?
var hunting_tactics_answered: bool = false
var hunting_tactics_answer_turn: int = -1
var last_observed_turn: int = -1
var progressed_after_hunting_tactics: bool = false
var huginn_prime_observed: bool = false
var muninn_prime_observed: bool = false

func attach_networked(
	p_game_manager: GameManager,
	p_match_manager: MatchManager,
	p_game_input: GameInput,
	p_player_index: int,
	p_match_client
) -> void:
	super.attach_networked(
		p_game_manager,
		p_match_manager,
		p_game_input,
		p_player_index,
		p_match_client
	)

func detach() -> void:
	super.detach()

func _on_network_game_event(event_type: String, data: Dictionary) -> void:
	if event_type == "full_state":
		_record_raven_prime_message(str(data.get("action_message", "")))
		super._on_network_game_event(event_type, data)
		return
	if event_type != "ui_interaction":
		super._on_network_game_event(event_type, data)
		return
	var type := str(data.get("type", ""))
	var prompt_player_index := int(data.get("player_index", player_index))
	if prompt_player_index != player_index:
		super._on_network_game_event(event_type, data)
		return
	var payload: Dictionary = {}
	var raw_payload = data.get("data", {})
	if raw_payload is Dictionary:
		payload = (raw_payload as Dictionary).duplicate(true)
	match type:
		"hunting_tactics":
			_submit_hunting_tactics_choice(payload)
		_:
			super._on_network_game_event(event_type, data)

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
	if not _mark_prompt_answered(data):
		return
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

func _record_raven_prime_message(message: String) -> void:
	if message.find("Huginn primes") >= 0 or message.find("Huginn perished and primed") >= 0:
		huginn_prime_observed = true
	if message.find("Muninn primes") >= 0 or message.find("Muninn perished and primed") >= 0:
		muninn_prime_observed = true

func poll() -> void:
	super.poll()
	if hunting_tactics_answered and not progressed_after_hunting_tactics and game_manager != null:
		# Progress = the game state moved on after the hunting_tactics answer,
		# i.e. turn advanced or the action stack cleared (combat resolved).
		if game_manager.turn_number > hunting_tactics_answer_turn \
				or (game_manager.action_stack != null and game_manager.action_stack.is_empty()):
			progressed_after_hunting_tactics = true
