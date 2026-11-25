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
	"lailoken_reveal", "masmassu_priest_reveal",
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
		if type == "fenrir_devour_impact" or type == "gugalanna_celestial_charge" or type == "terror_impact":
			var demon: Card = bot.game_manager.get_card_by_uid(str(data.get("demon_uid", "")))
			command["target_uid"] = bot._choose_impact_removal_target(source, data.get("target_uids", []), demon)
		elif type == "masmassu_priest_reveal" and (source is MasmassuPriest or source is Grindylow):
			command["target_uid"] = bot._choose_removal_reveal_target_uid(source, data.get("target_uids", []))
		elif type == "lailoken_reveal":
			command["target_uid"] = _best_reveal_target(bot, source, data.get("target_uids", []))
		elif type == "apollyons_demiurge":
			command["target_uid"] = bot._choose_demiurge_summon(data.get("target_uids", []))
		elif type == "third_sage_enmedugga_impact" and source is ThirdSageEnmedugga:
			command["target_uid"] = _best_good_fortune_target(bot, source, data.get("target_uids", []))
		elif type == "first_sage_adapa_impact" and source is FirstSageAdapa:
			command["target_uid"] = _best_silence_target(bot, source, data.get("target_uids", []))
		elif type == "fourth_sage_enmegalamma_impact":
			command["target_uid"] = _best_fourth_sage_target(bot, source, data.get("target_uids", []))
		elif type == "seventh_sage_utuabzu_impact":
			command["target_uid"] = _best_seventh_sage_channel_target(bot, data.get("target_uids", []))
		elif type == "sixth_sage_an_enlilda_impact" and source is SixthSageAnEnlilda:
			command["target_uid"] = _best_conjure_home_target(bot, source, data.get("target_uids", []))
		elif type == "tonal_extraction" and source is TonalExtraction:
			var targets: Array[Card] = []
			for target in source.get_valid_targets(bot.game_manager):
				if target.uid in data.get("target_uids", []):
					targets.append(target)
			var plan: Dictionary = bot._plan_tonal_extraction(source, targets, bot._forecast_incoming_follower_loss())
			var choice: Dictionary = plan.get("command", {})
			command["target_uid"] = choice.get("target_uid", targets[0].uid if not targets.is_empty() else "")
		else:
			command["target_uid"] = _best_uid(bot, data, "target_uids", type in HARMFUL_TARGET_PROMPTS)
		if type == "sixth_sage_an_enlilda_impact" and source is SixthSageAnEnlilda:
			var target: Card = bot.game_manager.get_card_by_uid(str(command.get("target_uid", "")))
			if target != null:
				var danger: int = bot._forecast_incoming_follower_loss()
				# Voiding the Sage is the only way Conjure Home adds the
				# Dwelling, so the fetch is the default: decline only when the
				# hand cannot take it or the body outprices the structure the
				# void would deploy. The Sage voids itself, so it is not on
				# the board the Duat would lock: exclude it from the chain's
				# own-sleeper pricing.
				var gain: int = Strategy.conjure_home_fetch_value(bot, target, danger, [source])
				var loss: int = bot._get_card_economic_value(source)
				if not bot.game_manager.can_player_add_to_hand_now(bot.bot_player) \
						or gain + bot._follower_safety_gain(danger, {"removed": [source]}, bot.bot_player.mana) <= loss:
					command["target_uid"] = ""
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
					"flip": score = Strategy.unlock_score(bot, power, 0) if power != null else Strategy.BAD
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
			# Prime is the default draw-lock; shelve only when the victim
			# would answer Mummu on return. A stolen body we destroyed
			# primes back onto our own deck.
			command.merge({
				"type": "mummu_entropy_choice", "chosen_uid": victim_uid,
				"placement": bot._choose_mummu_entropy_placement(source, victim),
			})
		"nusku_active_core_flame":
			# Accepting mills and banks a magical card in hand; declining banks
			# Celestial Light's grave-sized follower conversion for the perish.
			var nusku_active := source as NuskuActive
			var decline_core_flame: bool = nusku_active != null and bot._should_decline_nusku_core_flame(nusku_active)
			command.merge({"type": "nusku_active_core_flame_choice", "decline": decline_core_flame})
			if str(data.get("stage", "")) == "choose":
				# The mill already resolved, so declining is no longer offered.
				# Re-running the decline analysis here dead-ends the deferred
				# impact event: this mill grew the grave by 7, which can flip
				# _should_decline_nusku_core_flame past its threshold and strand
				# the prompt in a re-emission loop. Always name a milled card.
				command["decline"] = false
				var chosen_uid := _best_uid(bot, data, "target_uids", false)
				if chosen_uid == "":
					var offered_uids: Array = data.get("target_uids", [])
					if not offered_uids.is_empty():
						chosen_uid = str(offered_uids[0])
				command["chosen_uid"] = chosen_uid
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
			var limit := mini(TezcatlipocaActive.MAX_TITLACAUAN_TARGETS, Strategy.open_spaces(bot.bot_player))
			var selected := Strategy.budget_choices(bot, data.get("target_uids", []), budget, limit, true)
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
			var selected := Strategy.budget_choices(bot, candidates["target_uids"], budget, zones.size(), false, true)
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
			var target_uid: String = bot._choose_breidablik_return(source, data.get("target_uids", []))
			command.merge({"type": "breidablik_turn_start_choice", "return_priest": not target_uid.is_empty(), "target_uid": target_uid})
		"advanced_building_techniques":
			var power: Card = bot.game_manager.get_card_by_uid(str(data.get("power_uid", "")))
			var structure: Card = bot.game_manager.get_card_by_uid(str(data.get("structure_uid", "")))
			var mana_to_spend := 0
			if power is AdvancedBuildingTechniques:
				mana_to_spend = bot._choose_structure_ward_mana(power, structure)
			command = {
				"type": "apply_advanced_building_techniques", "power_uid": str(data.get("power_uid", "")),
				"structure_uid": str(data.get("structure_uid", "")), "mana_to_spend": mana_to_spend,
			}
		"habrok_breakout":
			var target_uids: Array = data.get("target_uids", [])
			command.merge({
				"type": "habrok_breakout_choice",
				"do_breakout": true,
				"target_uid": str(target_uids[0]) if not target_uids.is_empty() else "",
			})
		"hati_moon_hunt":
			command.merge(bot._plan_moon_hunt(source as Hati))
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

static func _best_reveal_target(bot, source: Card, target_uids: Array, enemy_only: bool = false) -> String:
	var best_uid := ""
	var best_score := Strategy.BAD
	for raw_uid in target_uids:
		var uid := str(raw_uid)
		var target: Card = bot.game_manager.get_card_by_uid(uid)
		if target == null:
			continue
		var own: bool = target.get_controller() == bot.bot_player
		var score := Strategy.value(bot, target)
		if own:
			score = Strategy.BAD if enemy_only else -score
		else:
			# These reveal abilities destroy their target. Prefer a legal, high
			# value opposing target and avoid wasting the trigger into protection.
			if bot.game_manager.is_immune_to_source(target, source) \
					or bot.game_manager.is_guardian_protected(target, source) \
					or Strategy.destruction_guard(target) \
					or (target.card_type == Card.CardType.CREATURE and bot.game_manager.has_turn_destruction_ward(target.get_controller())):
				score = Strategy.BAD
			else:
				score += 1000
		if score > best_score:
			best_score = score
			best_uid = uid
	return best_uid

static func _best_good_fortune_target(bot, source: ThirdSageEnmedugga, target_uids: Array) -> String:
	var best_uid := ""
	var best_score := 0
	for target in source.get_valid_targets(bot.game_manager):
		if target.get_controller() != bot.bot_player or target.uid not in target_uids:
			continue
		var added_wards := 0
		for ward_kind in ["spells", "creature_abilities"]:
			if not bot.game_manager.has_target_immunity(target, source, ward_kind):
				added_wards += 1
		var score := added_wards * Strategy.value(bot, target)
		if score > best_score or (score == best_score and score > 0 and target.uid < best_uid):
			best_score = score
			best_uid = target.uid
	return best_uid

static func _best_silence_target(bot, source: FirstSageAdapa, target_uids: Array) -> String:
	var best_uid := ""
	var best_score := 0
	for target in source.get_valid_targets(bot.game_manager):
		if target.uid not in target_uids or bot.game_manager.is_immune_to_source(target, source):
			continue
		var score := Strategy.mute_gain(bot, target, FirstSageAdapa.MUTE_DURATION, Strategy.value(bot, target))
		if score > best_score or (score == best_score and score > 0 and target.uid < best_uid):
			best_score = score
			best_uid = target.uid
	return best_uid

# The Fourth Sage acquires its Mer Sage by paying half the target's level, so
# the pick ranks the deck card's value net of that mana — including the
# combo lines the acquisition walks into (the Sixth Sage's Conjure Home
# fetching the Sleep of the Duat, or Enki under a live Duat).
static func _best_fourth_sage_target(bot, source: Card, target_uids: Array) -> String:
	var best_uid := ""
	var best_score := Strategy.BAD
	var danger := -1
	for raw_uid in target_uids:
		var uid := str(raw_uid)
		var target: Card = bot.game_manager.get_card_by_uid(uid)
		if target == null:
			continue
		if danger < 0:
			danger = bot._forecast_incoming_follower_loss()
		var score: int = bot._deck_pick_value(target, bot.bot_player.mana, danger)
		if source.has_method("get_acquisition_cost"):
			score -= Strategy.mana_penalty(bot, source.get_acquisition_cost(target))
		if score > best_score:
			best_score = score
			best_uid = uid
	return best_uid

# Channel Ally picks the Sage whose replayed impact is worth the most right
# now — the Fourth Sage's Search from the Void or the field, the Sixth Sage's
# Conjure Home while it still stands to void itself — rather than the most
# valuable body. Falls back to the first offered target so the mandatory
# choice always resolves.
static func _best_seventh_sage_channel_target(bot, target_uids: Array) -> String:
	var best_uid := ""
	var best_score := 0
	for raw_uid in target_uids:
		var uid := str(raw_uid)
		var target: Card = bot.game_manager.get_card_by_uid(uid)
		if target == null:
			continue
		var score := Strategy.seventh_sage_channel_gain(bot, target)
		if score > best_score:
			best_score = score
			best_uid = uid
	if best_uid.is_empty() and not target_uids.is_empty():
		return str(target_uids[0])
	return best_uid

# Conjure Home prices each offered Ancient Dwelling as the structure the
# void actually deploys (see conjure_home_fetch_value), so an engine
# Dwelling outbids a generic deck pick and the fetch competes with the
# Sage's body on fair terms instead of being declined by default.
static func _best_conjure_home_target(bot, source: Card, target_uids: Array) -> String:
	var best_uid := ""
	var best_score := 0
	var danger := -1
	for raw_uid in target_uids:
		var uid := str(raw_uid)
		var target: Card = bot.game_manager.get_card_by_uid(uid)
		if target == null:
			continue
		if danger < 0:
			danger = bot._forecast_incoming_follower_loss()
		var score: int = Strategy.conjure_home_fetch_value(bot, target, danger, [source])
		if score > best_score or (score == best_score and score > 0 and uid < best_uid):
			best_score = score
			best_uid = uid
	return best_uid

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
	var danger := -1
	for raw_uid in data.get(key, []):
		var target_uid := str(raw_uid).strip_edges()
		if target_uid.is_empty() or seen.has(target_uid):
			continue
		seen[target_uid] = true
		var card: Card = bot.game_manager.get_card_by_uid(target_uid)
		var score := 0
		if card != null:
			if card.current_zone == bot.bot_player.deck_zone:
				if danger < 0:
					danger = bot._forecast_incoming_follower_loss()
				score = bot._deck_pick_value(card, bot.bot_player.mana, danger)
			else:
				score = Strategy.value(bot, card)
			if harmful and card.get_controller() == bot.bot_player:
				score = -score
			elif not harmful and card.get_controller() != bot.bot_player:
				score = -score
		ranked.append({"uid": target_uid, "score": -score if lowest else score})
	# Use the UID as a tie-breaker independent of the offered order.
	var result: Array[String] = []
	while not ranked.is_empty():
		var best_index := 0
		for index in range(1, ranked.size()):
			if int(ranked[index]["score"]) > int(ranked[best_index]["score"]) \
					or (int(ranked[index]["score"]) == int(ranked[best_index]["score"]) and str(ranked[index]["uid"]) < str(ranked[best_index]["uid"])):
				best_index = index
		result.append(str(ranked[best_index]["uid"]))
		ranked.remove_at(best_index)
	return result
