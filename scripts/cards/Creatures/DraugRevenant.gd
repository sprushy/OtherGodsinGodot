extends CreatureCard
class_name DraugRevenant

func _init() -> void:
	super._init()
	card_name = "Draug Revenant"
	card_types = ["Undead", "Draug", "Mage", "Battlemage", "Norse Creature"]
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 13
	strength = 17
	flavor_text = ""
	ability_text = "[b]Trollskap[/b]: If this card is destroyed by an effect, return it to your hand instead."
	culture = "Norse"
	artist = "Riccardo Zoppello"
	art_path = "res://images/card_art/creatures/DragrRevenantAIEdit.png"

func get_self_graveyard_replacement_zone(
	_game_manager: GameManager,
	combat_death: bool,
	destruction: bool,
	send_to_abyss: bool
) -> Zone:
	if card_owner == null:
		return null
	if send_to_abyss:
		return null
	if combat_death or not destruction:
		return null
	if current_zone == null or not current_zone.is_board_zone():
		return null
	return card_owner.hand_zone
