extends CharmCard
class_name NamburbiApotropaeon

const ART_PATH := "res://images/card_art/charms/NamburbiArt.jpg"

func _init() -> void:
	super._init()
	card_name = "Namburbi Apotropaeon"
	culture = "Ancient"
	card_types = ["Charm", "Ward", "Creatures"]
	level = 2
	mana_cost = 1
	speed = 2
	flavor_text = ""
	ability_text = "This turn your creatures cannot be destroyed by your opponent's cards and you do not lose followers from combat."
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null or card_owner == null:
		return
	game_manager.grant_turn_destruction_ward(card_owner, self, game_manager.turn_number)
	game_manager.grant_turn_follower_loss_prevention(card_owner, self, game_manager.turn_number)
	game_manager.note_player_feedback("%s wards %s's creatures from opposing destruction effects this turn and prevents combat follower loss." % [
		card_name,
		card_owner.player_name
	])
