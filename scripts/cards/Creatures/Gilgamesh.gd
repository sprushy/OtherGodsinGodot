extends CreatureCard
class_name Gilgamesh

const ART_PATH := "res://images/card_art/creatures/gilgamesh - Copy.png"
const INSPIRED_SOURCE := "Gilgamesh Inspired Strength"
const STR_PER_LEVEL := 7

func _init() -> void:
	super._init()
	card_name = "Gilgamesh"
	card_types = ["Human", "Warrior", "Ancient Creature"]
	level = 3
	is_legendary = true
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 19
	strength = 21
	ability_text = "[b]Inspired Strength[/b] ([b]Passive[/b]): Gain %d Str per level difference when in combat with a creature of higher level." % STR_PER_LEVEL
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricarrdo Zoppello"
	art_path = ART_PATH

func on_attack(game_manager: GameManager, target: Card) -> void:
	_apply_inspired_strength(game_manager, target)

func on_defend(game_manager: GameManager, attacker: Card) -> void:
	_apply_inspired_strength(game_manager, attacker)

func on_after_combat(_game_manager: GameManager, _opposing_card: Card) -> void:
	_remove_inspired_strength()

func on_removed(_game_manager: GameManager) -> void:
	_remove_inspired_strength()

func on_muted(_game_manager: GameManager) -> void:
	_remove_inspired_strength()

func _apply_inspired_strength(game_manager: GameManager, opponent: Card) -> void:
	_remove_inspired_strength()
	if abilities_suppressed():
		return
	if opponent == null or opponent.card_type != Card.CardType.CREATURE:
		return
	var diff := opponent.get_effective_level() - get_effective_level()
	if diff <= 0:
		return
	var bonus := STR_PER_LEVEL * diff
	add_buff(
		INSPIRED_SOURCE,
		bonus,
		0,
		0,
		self,
		card_owner,
		"inspired_strength",
		{"expires_after_combat": true}
	)
	if game_manager != null:
		game_manager.note_player_feedback(
			"%s gains +%d Str (Inspired Strength: %d level difference)." % [
				card_name, bonus, diff
			]
		)

func _remove_inspired_strength() -> void:
	clear_buffs_from(INSPIRED_SOURCE)
