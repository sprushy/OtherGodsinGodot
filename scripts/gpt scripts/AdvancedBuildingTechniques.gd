extends PowerCard
class_name AdvancedBuildingTechniques

const UNLOCK_COST := 4
const RES_PER_MANA := 6

func _init() -> void:
	super._init()
	card_name = "Advanced Building Techniques"
	mana_cost = UNLOCK_COST
	
	# Type reference
	card_types = ["Ward", "Followers"]
	culture = "Neutral"
	ability_text = "Unlock (4): Ward – Followers — When you add a structure to the field, you may pay mana to increase its Res by 6 for each mana paid."
	art_path = "res://images/card_art/advanced_building_techniques.png"


func on_unlock(game_manager: GameManager) -> void:
	print(card_name + " unlocked.")


func on_structure_added(structure: Card, game_manager: GameManager) -> void:
	# Only trigger for the owner of this card
	if structure.card_owner != card_owner:
		return
	
	var player = card_owner
	var available_mana = player.mana
	
	if available_mana <= 0:
		return
	
	# This assumes you’ll later replace with a UI prompt
	var mana_to_spend = available_mana  # or prompt player choice
	
	if mana_to_spend > 0:
		player.spend_mana(mana_to_spend)
		var res_gain = mana_to_spend * RES_PER_MANA
		
		if "add_res" in structure:
			structure.add_res(res_gain)
		else:
			structure.res += res_gain
		
		print(card_name + ": Increased Res by " + str(res_gain) + " (spent " + str(mana_to_spend) + " mana).")
