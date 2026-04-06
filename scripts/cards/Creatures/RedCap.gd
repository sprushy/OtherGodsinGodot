extends CreatureCard
class_name RedCap

const ART_PATH := "res://images/card_art/creatures/RedCapEdit.png"
const FRESH_BLOOD_ABILITY := "Fresh Blood!"

var _resolved_attack_this_turn: bool = false

func _init() -> void:
	super._init()
	card_name = "Red Cap"
	card_types = ["Fairy", "Warrior", "Triskelion Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 3
	resilience = 16
	strength = 20
	ability_text = "[b]Fresh Blood![/b] ([b]Passive[/b]): At the end of any of your turns, if this card did not resolve an attack, destroy it."
	flavor_text = ""
	culture = "Triskelion"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func on_turn_start(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	if get_controller() != game_manager.current_player:
		return
	_resolved_attack_this_turn = false

func on_attack(_game_manager: GameManager, _target) -> void:
	_resolved_attack_this_turn = true

func on_turn_end(game_manager: GameManager) -> void:
	if game_manager == null or abilities_suppressed():
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	if get_controller() != game_manager.current_player:
		return
	if _resolved_attack_this_turn:
		return
	game_manager.note_player_feedback("%s is destroyed by %s." % [card_name, FRESH_BLOOD_ABILITY])
	game_manager.request_send_to_graveyard(self, Callable(), false, true)

func on_removed(_game_manager: GameManager) -> void:
	_resolved_attack_this_turn = false
