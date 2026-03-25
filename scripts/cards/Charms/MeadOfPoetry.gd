extends CharmCard
class_name MeadOfPoetry

const MANA_GAIN := 4

func _init() -> void:
	super._init()
	card_name = "Mead of Poetry"
	culture = "Norse"
	card_types = ["Charm", "Mead", "Resource Gain", "Mana"]
	level = 2
	speed = 2
	mana_cost = 0
	is_legendary = false
	must_be_prepared_to_activate = true
	flavor_text = ""
	ability_text = "Must be prepared. Gain 4 mana."
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/charms/meadofpoetry.jpg"

func resolve(game_manager: GameManager, _target = null) -> void:
	if card_owner == null:
		return
	card_owner.gain_mana(MANA_GAIN)
	print("%s grants %d mana." % [card_name, MANA_GAIN])
