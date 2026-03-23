extends CreatureCard
class_name AnkouServantToTheReaper

func _init() -> void:
	super._init()
	card_name = "Ankou, Servant to the Reaper"
	card_types = ["Monster", "Ghoul", "Triskelion", "Creature"]
	level = 4
	mana_cost = 4
	sacrifice_cost = 0
	speed = 2
	resilience = 17
	strength = 24
	flavor_text = "Where Ankou walks, the dead are counted."
	ability_text = "Reap (passive): When this card destroys another in combat, draw a card."
	culture = "Triskelion"
	art_path = "res://images/card_art/ankou_servant_to_the_reaper.jpg"


func on_destroyed_creature_in_combat(destroyed_card: Card, game_manager: GameManager) -> void:
	if game_manager == null:
		return

	var owner = card_owner
	if owner == null:
		return

	print(card_name + " reaped " + destroyed_card.card_name + " in combat. Drawing a card.")

	if owner.has_method("draw_card"):
		owner.draw_card()
	elif game_manager.has_method("draw_card_for_player"):
		game_manager.draw_card_for_player(owner)
