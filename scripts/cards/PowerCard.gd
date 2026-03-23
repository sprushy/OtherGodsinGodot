# PowerCard.gd
# Base class for all power cards.
#
# Powers are selected before the game and live in the player's power_zones.
# They start face-down (locked). The player pays mana_cost to unlock (flip face-up).
# Once unlocked, the power's passive applies and/or its activatable ability becomes usable.
extends BaseCard
class_name PowerCard

func _init() -> void:
	card_type = CardType.POWER
	is_power = true
	is_face_down = true   # locked until the player pays mana_cost to unlock

# ── Unlock (flip) ─────────────────────────────────────────────────────────────

func can_unlock(game_manager: GameManager) -> bool:
	if not is_face_down:
		return false
	if card_owner != game_manager.current_player:
		return false
	return card_owner.mana >= mana_cost

func unlock(game_manager: GameManager) -> void:
	card_owner.spend_mana(mana_cost)
	is_face_down = false
	on_unlock(game_manager)

# Called immediately when the power is flipped face-up.
# Override for passive or immediate on-unlock effects.
func on_unlock(game_manager: GameManager) -> void:
	pass

# ── Activatable ability ────────────────────────────────────────────────────────

# Override to add conditions (mana check, once-per-turn, etc.)
func can_activate(game_manager: GameManager) -> bool:
	if is_face_down:
		return false
	if card_owner != game_manager.current_player:
		return false
	return true

# Override to implement the ability. target is null for untargeted abilities.
func activate(game_manager: GameManager, target: Card = null) -> void:
	pass
