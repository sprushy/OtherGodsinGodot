extends "res://scripts/Other/CombatMockGame.gd"
class_name PracticeThorGame

const PracticeMatchSetupScript = preload("res://scripts/server/PracticeMatchSetup.gd")
const ThorPracticeBotScript = preload("res://scripts/bots/ThorPracticeBot.gd")
const BotGameInputScript = preload("res://scripts/bots/BotGameInput.gd")
const PRACTICE_AUTHORITY_PORT := 0

var _player_practice_deck: Dictionary = {}
var _thor_practice_deck: Dictionary = {}
var _practice_match_setup = PracticeMatchSetupScript.new()
var _thor_bot = null
var _practice_deck_name: String = ""

func set_player_practice_deck(saved_deck: Dictionary) -> void:
	_player_practice_deck = saved_deck.duplicate(true)

func set_thor_practice_deck(saved_deck: Dictionary) -> void:
	_thor_practice_deck = saved_deck.duplicate(true)

func start_game(
	_is_host: bool = false,
	_is_client: bool = false,
	server_ip: String = "127.0.0.1",
	_server_port: int = 12345,
	match_info: Dictionary = {},
	_server_match_session = null
) -> void:
	_shutdown_thor_bot()
	_practice_deck_name = ""
	var practice_info := match_info.duplicate(true)
	_add_selected_deck_info(practice_info)
	await super.start_game(true, false, server_ip, PRACTICE_AUTHORITY_PORT, practice_info, null)
	if match_manager != null:
		# Keep nonvisual local bookkeeping immediate; visible stack actions still linger.
		match_manager.allow_immediate_local_authoritative_stack_resolution = true
	_attach_thor_bot()
	_show_practice_intro()
	if _thor_bot != null:
		_thor_bot.poll()

func _build_initial_match_players(_default_match_setup, _server_match_session = null, _match_info: Dictionary = {}) -> Dictionary:
	var result := _practice_match_setup.build_thor_practice_match(game_manager, _player_practice_deck, _thor_practice_deck)
	_practice_deck_name = str(result.get("player_deck_name", ""))
	if match_manager != null:
		match_manager.allow_immediate_local_authoritative_stack_resolution = true
	_attach_thor_bot(result.get("player2", null) as Player)
	return result

func uses_authoritative_match_flow() -> bool:
	return true

func has_thor_bot() -> bool:
	return _thor_bot != null

func get_thor_bot():
	return _thor_bot

func find_thor_hand_divine_lightning() -> Card:
	if _thor_bot == null:
		return null
	return _thor_bot._find_hand_divine_lightning()

func submit_thor_priority_response(card: Card) -> bool:
	if _thor_bot == null or card == null:
		return false
	return bool(_thor_bot._submit_priority_response(card))

func cleanup() -> void:
	_shutdown_thor_bot()
	super.cleanup()

func _exit_tree() -> void:
	super._exit_tree()

func _on_forfeit_button_pressed() -> void:
	if _game_finished:
		super._on_forfeit_button_pressed()
		return
	_shutdown_thor_bot()
	_pending_forfeit_return_to_menu = false
	_pending_post_game_return_to_menu = false
	_set_match_reconnect_wait(false)
	_dismiss_transient_prompts()
	_hide_game_result_overlay()
	_hide_corner_action_button()
	_emit_forfeit_requested()

func _add_selected_deck_info(practice_info: Dictionary) -> void:
	var saved_cards = _player_practice_deck.get("cards", {})
	if saved_cards is Dictionary and not (saved_cards as Dictionary).is_empty():
		practice_info["selected_deck_cards"] = saved_cards
	var selected_name := str(_player_practice_deck.get("name", _player_practice_deck.get("deck_name", ""))).strip_edges()
	if not selected_name.is_empty():
		practice_info["selected_deck_name"] = selected_name

func _attach_thor_bot(thor_player: Player = null) -> void:
	if _thor_bot != null:
		return
	var resolved_thor_player := thor_player if thor_player != null else player2
	if game_manager == null or match_manager == null or resolved_thor_player == null:
		return
	var thor_index := game_manager.players.find(resolved_thor_player)
	if thor_index < 0:
		return
	var bot_input := BotGameInputScript.new(match_manager, thor_index)
	_thor_bot = ThorPracticeBotScript.new()
	_thor_bot.attach(game_manager, match_manager, bot_input, thor_index)

func _shutdown_thor_bot() -> void:
	if _thor_bot != null:
		_thor_bot.detach()
		_thor_bot = null

func _show_practice_intro() -> void:
	if _practice_deck_name.is_empty():
		_set_action_label_text("Practice vs Thor: Thor is running as an authoritative bot.")
	else:
		_set_action_label_text("Practice vs Thor: using %s. Thor is running as an authoritative bot." % _practice_deck_name)
