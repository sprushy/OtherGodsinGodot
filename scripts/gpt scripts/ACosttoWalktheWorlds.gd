extends PowerCard
class_name ACostToWalkTheWorlds

const UNLOCK_COST := 4
const LOSS_AMOUNT := 7
const GAIN_AMOUNT := 4

func _init() -> void:
	super._init()
	card_name = "A Cost to Walk the Worlds"
	mana_cost = UNLOCK_COST
	culture = "Ancient"
	# Card can be referenced as both types
	card_types = ["Worship", "Blasphemy"]
	
	ability_text = "Unlock (4): Worship/Blasphemy — When a creature is sent to the void its owner loses 7 followers; when a creature returns to the field from the void the owner gains 4 followers."
	art_path = "res://images/card_art/a_cost_to_walk_the_worlds.png"


func on_unlock(game_manager: GameManager) -> void:
	print(card_name + " unlocked.")


func on_creature_sent_to_void(creature: Card, game_manager: GameManager) -> void:
	var owner = creature.card_owner
	owner.lose_followers(LOSS_AMOUNT)
	print(card_name + ": " + owner.name + " loses " + str(LOSS_AMOUNT) + " followers.")


func on_creature_returned_from_void(creature: Card, game_manager: GameManager) -> void:
	var owner = creature.card_owner
	owner.gain_followers(GAIN_AMOUNT)
	print(card_name + ": " + owner.name + " gains " + str(GAIN_AMOUNT) + " followers.")
