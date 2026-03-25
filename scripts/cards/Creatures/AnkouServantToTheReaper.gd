extends CreatureCard
class_name AnkouServantToTheReaper

const ART_PATH := "res://images/card_art/creatures/ankou_servant_to_the_reaper.png"

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
	art_path = ART_PATH

func on_kill(_game_manager: GameManager, victim: Card) -> void:
	if card_owner == null:
		return
	print("%s reaped %s in combat. Drawing a card." % [card_name, victim.card_name])
	card_owner.draw_card()
