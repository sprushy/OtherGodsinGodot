extends StructureCard
class_name AncientPyre

func _init() -> void:
	super._init()
	card_name = "Ancient Pyre"
	card_types = ["Ancient", "Altar"]
	level = 2
	mana_cost = 0
	resilience = 20
	speed = 0
	strength = 0
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	ability_text = "Ritual Flame (Activate, Cost 2): [b]Convert[/b] 5. Frontlined: May reduce a creature's Res by 5 instead; reducing to 0 destroys it."
	culture = "Ancient"
	art_path = "res://images/card_art/ancient_pyre.jpg"

func is_frontline() -> bool:
	return current_zone != null and current_zone.zone_type == Zone.ZoneType.FRONTLINE

func can_activate(game_manager: GameManager) -> bool:
	if card_owner != game_manager.current_player:
		return false
	if card_owner.mana < 2:
		return false
	if is_frontline():
		return true
	return game_manager.get_opponent(card_owner).followers > 0

# target is required when on the frontline; caller is responsible for prompting the player.
func activate(game_manager: GameManager, target: Card = null) -> void:
	card_owner.spend_mana(2)
	var opponent := game_manager.get_opponent(card_owner)
	if not is_frontline() or (target != null and target.is_god):
		game_manager.convert_followers(opponent, card_owner, 5)
		print("Ancient Pyre: Ritual Flame converts 5 followers from " + opponent.player_name + ".")
		return
	if target == null:
		print("Ancient Pyre: No target selected.")
		card_owner.gain_mana(2)
		return
	target.add_buff("Ancient Pyre", 0, -5, 0, self, card_owner, "structure_debuff")
	print("Ancient Pyre: " + target.card_name + " Res reduced by 5 (now " + str(target.get_effective_resilience()) + ").")
	if target.get_effective_resilience() <= 0:
		print(target.card_name + " is destroyed by Ancient Pyre!")
		game_manager._send_to_graveyard_with_hook(target)
