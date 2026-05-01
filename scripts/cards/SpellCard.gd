# SpellCard.gd
extends BaseCard
class_name SpellCard

func _init() -> void:
	super._init()
	card_type = Card.CardType.SPELL
	speed = 1  # All spells are speed 1 by default

# Override this in specific spell cards to define what the spell does
func resolve(_game_manager: GameManager, _target = null) -> void:
	push_error("SpellCard.resolve() must be overridden in " + card_name + "!")

# Called when the spell is played
func on_play(game_manager: GameManager, target = null) -> void:
	print("Casting " + card_name + "...")
	resolve(game_manager, target)
	
	# Spell goes to graveyard after resolving (unless overridden)
	if should_go_to_graveyard():
		card_owner.move_card(self, card_owner.graveyard_zone)
		print(card_name + " sent to graveyard")

# Override this if your spell should NOT go to graveyard
func should_go_to_graveyard() -> bool:
	return true

## Server-side resolution driven by a network command dict.
## Default: resolves with the card identified by "target_uid" (or null).
## Override in spells that need additional data (choices, x_value, mode, etc.).
func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	var target_uid: String = command.get("target_uid", "")
	var target: Card = null
	if target_uid != "":
		target = game_manager.get_card_by_uid(target_uid)
	resolve(game_manager, target)

# Spells can only be played on your turn (speed 1)
func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if player != game_manager.current_player:
		print("Spells can only be cast on your turn")
		return false
	return super.can_be_played(game_manager, player)

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	if game_manager == null:
		return super.get_play_failure_reason(game_manager, player)
	if player != game_manager.current_player:
		return "Spells can only be cast on your turn."
	return super.get_play_failure_reason(game_manager, player)

func can_activate_prepared(game_manager: GameManager, player: Player) -> bool:
	if game_manager == null or player == null:
		return false
	if player != game_manager.current_player:
		return false
	if card_owner != null and player != card_owner:
		return false
	if not is_prepared:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	return can_be_played(game_manager, player)
