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
	card_types = ["Worship", "Blasphemy"]
	ability_text = "Unlock (4): Whenever a creature is [b]Void[/b]ed, its owner loses 7 followers. Whenever a creature returns to the field from the Abyss, its owner gains 4 followers."
	art_path = "res://images/card_art/powers/ACosttoWalktheWorldsAI1.png"

func on_unlock(_game_manager: GameManager) -> void:
	print(card_name + " unlocked.")

func on_creature_sent_to_void(creature: Card, _game_manager: GameManager) -> void:
	if creature == null or creature.card_owner == null:
		return
	creature.card_owner.lose_followers(LOSS_AMOUNT)
	print("%s: %s loses %d followers." % [card_name, creature.card_owner.player_name, LOSS_AMOUNT])

func on_creature_returned_from_void(creature: Card, _game_manager: GameManager) -> void:
	if creature == null or creature.card_owner == null:
		return
	creature.card_owner.gain_followers(GAIN_AMOUNT)
	print("%s: %s gains %d followers." % [card_name, creature.card_owner.player_name, GAIN_AMOUNT])
