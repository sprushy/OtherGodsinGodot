extends CreatureCard
class_name Berserker

const RAGE_STR_BONUS := 10
const RAGE_SOURCE := "Berserker Rage"

var rage_active_this_turn: bool = false

func _init() -> void:
	super._init()
	card_name = "Berserker"
	card_types = ["Human", "Warrior"]
	level = 3
	mana_cost = 1
	speed = 1
	resilience = 10
	strength = 17
	sacrifice_cost = 0
	ability_text = "[b]Berserker Rage[/b] (Once per turn): This turn gain 10 Str and [b]Immortal[/b]. After any attack, sleep in defensive stance until the start of your next turn."
	culture = "Norse"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/Berserker's Steele(web).jpg"

func get_activation_label() -> String:
	return "Berserker Rage"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if abilities_suppressed():
		return false
	if is_sleeping:
		return false
	return not is_used

func get_activation_failure_reason(game_manager: GameManager) -> String:
	return card_name + " cannot activate right now."

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	if game_manager != null and game_manager.is_immune_to_source(self, self):
		is_used = true
		game_manager.note_player_feedback("%s activates Berserker Rage, but Creature Ward prevents any effect." % card_name)
		return
	is_used = true
	rage_active_this_turn = true
	clear_buffs_from(RAGE_SOURCE)
	remove_status_effects_by_name("berserker_rage_guard")
	add_buff(RAGE_SOURCE, RAGE_STR_BONUS, 0, 0, self, card_owner, "rage_buff")
	add_status_effect("berserker_rage_guard", RAGE_SOURCE, self, card_owner)
	print("%s uses Berserker Rage and gains %d Str until end of turn." % [card_name, RAGE_STR_BONUS])

func on_turn_end(_game_manager: GameManager) -> void:
	if rage_active_this_turn:
		rage_active_this_turn = false
		clear_buffs_from(RAGE_SOURCE)
		remove_status_effects_by_name("berserker_rage_guard")
	is_used = false

func on_turn_start(game_manager: GameManager) -> void:
	if game_manager != null and get_controller() == game_manager.current_player and is_sleeping and not rage_active_this_turn:
		wake_up()

func on_after_combat(_game_manager: GameManager, _opposing_card: Card) -> void:
	if not rage_active_this_turn:
		return
	rage_active_this_turn = false
	clear_buffs_from(RAGE_SOURCE)
	remove_status_effects_by_name("berserker_rage_guard")
	if current_zone != null and current_zone.is_board_zone():
		creature_mode = Card.CreatureMode.DEFENSIVE
		apply_sleep(self)
