extends RefCounted
class_name BotCardPromptPolicy

const Strategy = preload("res://scripts/bots/BotCardStrategy.gd")

# Commands for card selectors shared by local, server, and network bots.
# Keep choices inside the offered UID lists, including cards absent from a
# client's masked deck. The authoritative MatchManager validates every answer.
const TARGET_COMMANDS := {
	"first_sage_adapa_impact": "first_sage_adapa_choice",
	"third_sage_enmedugga_impact": "third_sage_enmedugga_choice",
	"fourth_sage_enmegalamma_impact": "fourth_sage_enmegalamma_choice",
	"sixth_sage_an_enlilda_impact": "sixth_sage_an_enlilda_choice",
	"seventh_sage_utuabzu_impact": "seventh_sage_utuabzu_choice",
	"lailoken_reveal": "lailoken_reveal_choice",
	"masmassu_priest_reveal": "masmassu_priest_reveal_choice",
	"rally_the_troops": "rally_the_troops_choice",
	"terror_impact": "terror_impact_choice",
	"huginn_perish_prime": "huginn_perish_prime_choice",
	"muninn_perish_prime": "muninn_perish_prime_choice",
	"fenrir_devour_impact": "fenrir_devour_choice",
	"durinn_secondborn_impact": "durinn_secondborn_choice",
	"gugalanna_celestial_charge": "gugalanna_celestial_charge_choice",
	"tiamat_active_summon": "tiamat_active_summon_choice",
	"giant_master_architect_impact": "giant_master_architect_choice",
	"pai_long_autumn_king_impact": "pai_long_autumn_king_choice",
	"nergal_lion_impact": "nergal_lion_choice",
	"tatzelwurm_dragon_heart": "tatzelwurm_dragon_heart_choice",
	"apollyons_demiurge": "apollyons_demiurge_choice",
	"wolf_adolescent_maturation": "wolf_adolescent_maturation_choice",
	"humbaba_augury": "humbaba_augury_choice",
	"tonal_extraction": "tonal_extraction_choice",
}
const HARMFUL_TARGET_PROMPTS := [
	"first_sage_adapa_impact", "lailoken_reveal", "masmassu_priest_reveal",
	"terror_impact", "fenrir_devour_impact", "gugalanna_celestial_charge",
]

static func build_command(bot, type: String, data: Dictionary) -> Dictionary:
	if bot.game_manager == null or bot.bot_player == null:
		return {}
	var source: Card = bot.game_manager.get_card_by_uid(str(data.get("source_uid", "")))
	var command := {"source_uid": str(data.get("source_uid", ""))}
	# These identify the particular trigger, rather than the selected target.
	for key in ["demon_uid", "summoned_uid", "label"]:
		if data.has(key):
			command[key] = data[key]
	if TARGET_COMMANDS.has(type):
		command["type"] = TARGET_COMMANDS[type]
		command["target_uid"] = _best_uid(bot, data, "target_uids", type in HARMFUL_TARGET_PROMPTS)
		return command
	match type:
		"blessed_knights_ward":
			command.merge({"type": "blessed_knights_choice", "ward_kind": "creature_abilities"})
		"byggvir_reveal":
			var options: Array = data.get("options", [])
			if options.is_empty():
				return {}
			var best_option: Dictionary = options[0]
			var best_score := Strategy.BAD
			for option in options:
				var power: PowerCard = bot.game_manager.get_card_by_uid(str(option.get("power_uid", ""))) as PowerCard
				var target: Card = bot.game_manager.get_card_by_uid(str(option.get("target_uid", "")))
				var returned: Card = bot.game_manager.get_card_by_uid(str(option.get("card_uid", "")))
				var score := Strategy.BAD
				match str(option.get("kind", "")):
					"return": score = Strategy.value(bot, returned)
					"flip": score = Strategy.unlock_score(bot, power) + Strategy.mana_penalty(bot, power.get_unlock_mana_cost(bot.game_manager)) if power != null else Strategy.BAD
					"activate", "activate_targeted": score = Strategy.power_score(bot, power, target) if power != null else Strategy.BAD
				if score > best_score:
					best_score = score
					best_option = option
			command.merge({"type": "byggvir_reveal_choice", "choice": best_option})
		"gawain_healing_hands":
			var statuses: Array = data.get("statuses", [])
			if statuses.is_empty():
				return {}
			var target: Card = bot.game_manager.get_card_by_uid(str(data.get("target_uid", "")))
			var best_index := int(statuses[0].get("index", 0))
			var best_score := -1
			if source is Gawain and target != null:
				var removable: Array = source.get_removable_statuses(target)
				for offered in statuses:
					var index := int(offered.get("index", -1))
					if index < 0 or index >= removable.size():
						continue
					var score := Strategy.healing_score(bot, target, removable[index])
					if score > best_score:
						best_score = score
						best_index = index
			command.merge({
				"type": "gawain_healing_hands_choice",
				"target_uid": str(data.get("target_uid", "")),
				"status_index": best_index,
			})
		"foolish_optimism":
			command.merge({
				"type": "foolish_optimism_choice",
				"attacker_uid": _best_uid(bot, data, "attacker_uids", true),
				"defender_uid": _best_uid(bot, data, "defender_uids", false),
			})
			if source is FoolishOptimism:
				var attackers: Array = []
				var defenders: Array = []
				for uid in data.get("attacker_uids", []):
					var card: Card = bot.game_manager.get_card_by_uid(str(uid))
					if card != null:
						attackers.append(card)
				for uid in data.get("defender_uids", []):
					var card: Card = bot.game_manager.get_card_by_uid(str(uid))
					if card != null:
						defenders.append(card)
				var choice := Strategy.forced_combat_choice(bot, source, attackers, defenders)
				if int(choice.get("score", Strategy.BAD)) > Strategy.BAD:
					command["attacker_uid"] = choice["attacker_uid"]
					command["defender_uid"] = choice["defender_uid"]
		"mummu_entropy":
			var victim_uid := str(data.get("victim_uid", ""))
			var victim: Card = bot.game_manager.get_card_by_uid(victim_uid)
			command.merge({
				"type": "mummu_entropy_choice", "chosen_uid": victim_uid,
				"placement": "prime" if victim != null and victim.card_owner == bot.bot_player else "shelve",
			})
		"nusku_active_core_flame":
			command.merge({"type": "nusku_active_core_flame_choice", "decline": false})
			if str(data.get("stage", "")) == "choose":
				command["chosen_uid"] = _best_uid(bot, data, "target_uids", false)
		"gala_tura_destroyed":
			command.merge({
				"type": "gala_tura_destroyed_choice",
				"chosen_uids": _select_uids(bot, data, GalaTura.MAX_RETURN_COUNT),
			})
		"kur_jara_tree_of_life":
			if not data.has("required_count") and not (source is KurJara):
				return {}
			var required_count := int(data.get("required_count", 0))
			if not data.has("required_count"):
				required_count = source.get_tree_of_life_pending_destroy_count()
			command.merge({
				"type": "kur_jara_tree_of_life_choice",
				"chosen_uids": _select_uids(bot, data, required_count, true),
			})
		"freyja_active_open_sessrumnir":
			var limit := int(data.get("summon_limit", 0))
			if source is FreyjaActive:
				limit = mini(limit, source.get_open_sessrumnir_summon_limit(bot.game_manager))
			var selected := _select_uids(bot, data, limit)
			command.merge({"type": "freyja_active_open_sessrumnir_choice", "target_uids": selected, "skip": selected.is_empty()})
		"tezcatlipoca_active_titlacauan":
			if not (source is TezcatlipocaActive):
				return {}
			var budget: int = source.get_titlacauan_level_budget()
			var selected := Strategy.budget_choices(bot, data.get("target_uids", []), budget, TezcatlipocaActive.MAX_TITLACAUAN_TARGETS, true)
			command.merge({"type": "tezcatlipoca_active_titlacauan_choice", "target_uids": selected, "skip": selected.is_empty()})
		"hunting_tactics":
			command.merge({
				"type": "hunting_tactics_choice",
				"attacker_uid": str(data.get("attacker_uid", "")),
				"chosen_uids": _select_uids(bot, data, 1),
			})
		"blot_sacrifice":
			if not (source is BlotSacrifice):
				return {}
			var budget := BlotSacrifice.MAX_SUMMON_LEVELS
			var zones: Array = source.get_available_summon_zones()
			var candidates := {"target_uids": []}
			for target in source.get_valid_hand_creatures():
				candidates["target_uids"].append(target.uid)
			var selected := Strategy.budget_choices(bot, candidates["target_uids"], budget, zones.size())
			command.merge({"type": "blot_sacrifice_choice", "choices": selected})
		"return_to_hand_choice":
			var card_uid := str(data.get("card_uid", ""))
			var card: Card = bot.game_manager.get_card_by_uid(card_uid)
			var pay_cost: bool = card != null and card.has_method("can_offer_return_to_hand_replacement") and card.can_offer_return_to_hand_replacement(bot.game_manager)
			command = {"type": "return_to_hand_choice", "card_uid": card_uid, "pay_cost": pay_cost}
		"resurrection":
			var has_reserve_space := false
			for zone in bot.bot_player.reserve_zones:
				if zone.cards.is_empty():
					has_reserve_space = true
					break
			command = {
				"type": "resurrection_choice", "card_uid": str(data.get("card_uid", "")),
				"confirm": has_reserve_space and bot.bot_player.mana >= AgainWalker.RESURRECTION_COST,
			}
		"doorway_choice":
			var card_uid := str(data.get("card_uid", ""))
			var card: Card = bot.game_manager.get_card_by_uid(card_uid)
			command = {
				"type": "doorway_choice", "structure_uid": str(data.get("structure_uid", "")),
				"card_uid": card_uid, "send_to_abyss": card != null and card.card_owner != bot.bot_player,
			}
		"wheel_of_fire_turn_start":
			var pay_cost: bool = source is WheelOfFire and bot._should_pay_wheel_of_fire_upkeep(source as WheelOfFire)
			command.merge({"type": "wheel_of_fire_turn_start_choice", "pay_cost": pay_cost})
		"breidablik_turn_start":
			var target_uid := _best_uid(bot, data, "target_uids", false)
			command.merge({"type": "breidablik_turn_start_choice", "return_priest": not target_uid.is_empty(), "target_uid": target_uid})
		"advanced_building_techniques":
			var power: Card = bot.game_manager.get_card_by_uid(str(data.get("power_uid", "")))
			var structure: Card = bot.game_manager.get_card_by_uid(str(data.get("structure_uid", "")))
			var mana_to_spend := 0
			if power is AdvancedBuildingTechniques:
				mana_to_spend = mini(1, power.get_max_structure_bonus_mana(structure, bot.game_manager))
			command = {
				"type": "apply_advanced_building_techniques", "power_uid": str(data.get("power_uid", "")),
				"structure_uid": str(data.get("structure_uid", "")), "mana_to_spend": mana_to_spend,
			}
		"aphrodite_enslave":
			command.merge({"type": "aphrodite_enslave_choice", "confirm": false})
		"habrok_breakout":
			command.merge({"type": "habrok_breakout_choice", "do_breakout": true})
		"en_hedu_anna_exaltation":
			if not (source is EnHeduAnna):
				return {}
			command.merge({"type": "en_hedu_anna_exaltation", "option": source.get_exaltation_options()[1]})
		"oracles_sight":
			command = {"type": "activate_power", "power_uid": str(data.get("source_uid", "")), "target_uid": _best_uid(bot, data, "target_uids", false)}
		"book_of_life":
			if not (source is BookOfLife):
				return {}
			var candidates := {"target_uids": []}
			for target in source.get_valid_hand_creatures():
				candidates["target_uids"].append(target.uid)
			command = {"type": "cast_spell", "spell_uid": source.uid, "target_uid": _best_uid(bot, candidates, "target_uids", false)}
		_:
			return {}
	return command

static func _best_uid(bot, data: Dictionary, key: String, harmful: bool) -> String:
	var ranked := _ranked_uids(bot, data, key, harmful)
	return ranked[0] if not ranked.is_empty() else ""

static func _select_uids(bot, data: Dictionary, limit: int, lowest: bool = false) -> Array[String]:
	var ranked := _ranked_uids(bot, data, "target_uids", false, lowest)
	var selected: Array[String] = []
	for target_uid in ranked:
		if selected.size() >= maxi(0, limit):
			break
		selected.append(target_uid)
	return selected

static func _ranked_uids(bot, data: Dictionary, key: String, harmful: bool, lowest: bool = false) -> Array[String]:
	var ranked: Array[Dictionary] = []
	var seen := {}
	for raw_uid in data.get(key, []):
		var target_uid := str(raw_uid).strip_edges()
		if target_uid.is_empty() or seen.has(target_uid):
			continue
		seen[target_uid] = true
		var card: Card = bot.game_manager.get_card_by_uid(target_uid)
		var score := 0
		if card != null:
			score = Strategy.value(bot, card)
			if harmful and card.get_controller() == bot.bot_player:
				score = -score
			elif not harmful and card.get_controller() != bot.bot_player:
				score = -score
		ranked.append({"uid": target_uid, "score": -score if lowest else score})
	# Stable ties preserve the order offered by the authority.
	var result: Array[String] = []
	while not ranked.is_empty():
		var best_index := 0
		for index in range(1, ranked.size()):
			if int(ranked[index]["score"]) > int(ranked[best_index]["score"]):
				best_index = index
		result.append(str(ranked[best_index]["uid"]))
		ranked.remove_at(best_index)
	return result
