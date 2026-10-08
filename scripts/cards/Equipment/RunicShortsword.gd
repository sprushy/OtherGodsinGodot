extends EquipmentCard
class_name RunicShortsword

const ART_PATH := "res://images/card_art/equipment/NorseShortswordEdit.png"
const ALT_ART_PATH := "res://images/card_art/equipment/NorseShortswordAlt.png"

var _last_free_pickup_turn: int = -1

func _init() -> void:
	super._init()
	card_name = "Runic Shortsword"
	culture = "Norse"
	card_types = ["Weapon", "Sword", "Runic"]
	level = 1
	mana_cost = 0
	strength_modifier = 8
	ability_text = "+8 Str. Once per turn a Norse Warrior may pick this up as a free action"
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = ART_PATH
	art_variants = [ART_PATH, ALT_ART_PATH]

func can_pick_up_as_free_action(creature: Card, turn_number: int) -> bool:
	return creature != null \
		and creature.culture == "Norse" \
		and creature.has_type("Warrior") \
		and _last_free_pickup_turn != turn_number

func record_free_pickup(turn_number: int) -> void:
	_last_free_pickup_turn = turn_number

func get_serialized_state() -> Dictionary:
	var state := super.get_serialized_state()
	state["last_free_pickup_turn"] = _last_free_pickup_turn
	return state

func apply_serialized_state(state: Dictionary) -> void:
	super.apply_serialized_state(state)
	_last_free_pickup_turn = int(state.get("last_free_pickup_turn", -1))
