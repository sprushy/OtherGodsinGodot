extends CreatureCard
class_name MinotaurFootsoldier

const ART_PATH := "res://images/card_art/creatures/MinotaurFootsoldierEdit.png"
const STUN_SOURCE := "Minotaur Footsoldier Stun"
const DEFENDER_WAS_STEALTH_META := "combat_was_stealth_when_engaged"
const DEFENDER_WAS_SLEEPING_META := "combat_was_sleeping_when_engaged"

func _init() -> void:
	super._init()
	card_name = "Minotaur Footsoldier"
	card_types = ["Monster", "Animal", "Bovine", "Warrior", "Olympic Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 20
	strength = 19
	ability_text = "[b]Stun[/b] ([b]Passive[/b]): If a friendly Bovine attacks a sleeping or stealthed creature, that creature's abilities are negated until end of turn."
	flavor_text = ""
	culture = "Olympic"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func on_creature_enters_combat(game_manager: GameManager, attacker: Card, defender: Card) -> void:
	if not _can_apply_stun(attacker, defender):
		return
	if game_manager != null and game_manager.is_immune_to_source(defender, self):
		return
	if defender.has_status_effect(Card.ABILITY_NEGATED_STATUS):
		return
	defender.remove_status_effects_from_source_card(self, Card.ABILITY_NEGATED_STATUS)
	defender.add_status_effect(
		Card.ABILITY_NEGATED_STATUS,
		STUN_SOURCE,
		self,
		get_controller(),
		{
			"display_name": "Abilities negated (Stun)",
			"expires_turn": game_manager.turn_number,
		}
	)
	if game_manager != null:
		game_manager.note_player_feedback(
			"%s stuns %s, negating its abilities until end of turn." % [
				card_name,
				defender.get_target_log_display_name(game_manager.get_feedback_viewer())
			]
		)

func _can_apply_stun(attacker: Card, defender: Card) -> bool:
	if attacker == null or defender == null:
		return false
	if abilities_suppressed():
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if attacker.card_type != Card.CardType.CREATURE or defender.card_type != Card.CardType.CREATURE:
		return false
	if attacker.get_controller() != get_controller():
		return false
	if not attacker.has_type("Bovine"):
		return false
	if defender.current_zone == null or not defender.current_zone.is_board_zone():
		return false
	return _defender_was_hidden_or_sleeping(defender)

func _defender_was_hidden_or_sleeping(defender: Card) -> bool:
	if defender == null:
		return false
	return bool(defender.get_meta(DEFENDER_WAS_STEALTH_META, false)) \
		or bool(defender.get_meta(DEFENDER_WAS_SLEEPING_META, defender.is_sleeping)) \
		or defender.is_sleeping
