extends CreatureCard
class_name AnkouServantToTheReaper

const ART_PATH := "res://images/card_art/creatures/ankou_servant_to_the_reaper.png"

func _init() -> void:
	super._init()
	card_name = "Ankou, Servant to the Reaper"
	card_types = ["Monster", "Ghoul", "Triskelion", "Creature"]
	level = 4
	mana_cost = 0
	sacrifice_cost = 1
	speed = 2
	resilience = 17
	strength = 24
	# flavor_text = "Where Ankou walks, the dead are counted."
	flavor_text = ""
	ability_text = "Reap: [b]Slay[/b]: Draw a card."
	culture = "Triskelion"
	art_path = ART_PATH

func on_kill(game_manager: GameManager, victim: Card) -> void:
	if card_owner == null:
		return
	if game_manager != null and victim != null:
		game_manager.note_player_feedback("%s reaped %s in combat and drew a card." % [card_name, victim.card_name])
	card_owner.draw_card()
