extends CreatureCard
class_name GidimEnsi

const ART_PATH := "res://images/card_art/creatures/gidim_ensi.png"
const GUARDIAN_SLEEP_SOURCE := "Gidim Ensi Guardian"

func _init() -> void:
	super._init()
	card_name = "Gidim Ensi"
	card_types = ["Spirit", "Ghost", "Mage", "Priest", "Ancient Creature"]
	level = 4
	mana_cost = 2
	sacrifice_cost = 0
	speed = 1
	resilience = 22
	strength = 18
	incorporeal = true
	ability_text = "[b]Incorporeal[/b] ([b]Passive[/b]): Can only be engaged by Spirits or faster Mages. Can only engage Spirits or slower Mages.\n[b]Guardian[/b] ([b]Passive[/b]): Any creature that attacks your followers sleeps until the end of their owner's next turn. This card cannot attack."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricarrdo Zoppello"
	art_path = ART_PATH

func on_summon(_game_manager: GameManager) -> void:
	_apply_cannot_attack()

func on_reveal(_game_manager: GameManager) -> void:
	_apply_cannot_attack()

func on_turn_start(_game_manager: GameManager) -> void:
	_apply_cannot_attack()

func on_removed(_game_manager: GameManager) -> void:
	remove_status_effects_by_name("cannot_attack")

func on_opponent_attacks_followers(game_manager: GameManager, attacker: Card) -> void:
	if game_manager == null or attacker == null:
		return
	if abilities_suppressed():
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	# Only trigger for opponents attacking this card's controller's followers.
	if attacker.get_controller() == get_controller():
		return
	attacker.remove_status_effects_by_name("sleep")
	attacker.add_status_effect(
		"sleep",
		GUARDIAN_SLEEP_SOURCE,
		self,
		card_owner,
		{"expires_turn": game_manager.turn_number + 2}
	)
	game_manager.note_player_feedback(
		"%s: %s falls asleep until the end of their owner's next turn." % [
			card_name,
			attacker.card_name
		]
	)

func _apply_cannot_attack() -> void:
	remove_status_effects_by_name("cannot_attack")
	add_status_effect("cannot_attack", card_name, self, card_owner)
