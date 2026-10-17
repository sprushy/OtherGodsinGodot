extends RefCounted
## Match-only telemetry. Never serializes card resources, UIDs, hands or decks.

var player_totals: Dictionary = {}
var card_totals: Dictionary = {}
var lethal_hits: Dictionary = {}
var biggest_hit: Dictionary = {}
var damage_sources: Array[Card] = []
var destruction_totals: Dictionary = {}
var pending_destructions: Dictionary = {}
var _started_msec: int = Time.get_ticks_msec()
var _finished_msec: int = -1

func _totals(index: int) -> Dictionary:
	if not player_totals.has(index):
		player_totals[index] = {"damage": 0, "restored": 0, "summoned": 0}
	return player_totals[index]

func record_summon(index: int) -> void:
	_totals(index)["summoned"] += 1

func record_gain(index: int, amount: int) -> void:
	if amount > 0:
		_totals(index)["restored"] += amount

func expect_destruction(victim: Card, source: Card, players: Array[Player], replace: bool = false, revealed_source: bool = false) -> void:
	if victim == null:
		return
	var victim_id := victim.get_instance_id()
	if pending_destructions.has(victim_id) and not replace:
		return
	pending_destructions.erase(victim_id)
	if source == null or source == victim:
		return
	var portrait := _portrait(source, players, revealed_source)
	if portrait.is_empty():
		return
	pending_destructions[victim_id] = {
		"key": "%d:%d" % [source.get_instance_id(), int(portrait["player_index"])],
		"portrait": portrait,
	}

func cancel_destruction(card: Card) -> void:
	if card != null:
		pending_destructions.erase(card.get_instance_id())

func record_card_move(card: Card, destination: Zone) -> void:
	var victim_id := card.get_instance_id()
	var pending: Dictionary = pending_destructions.get(victim_id, {})
	pending_destructions.erase(victim_id)
	if pending.is_empty():
		return
	var destroyed := destination != null and destination.zone_type in [Zone.ZoneType.GRAVEYARD, Zone.ZoneType.ABYSS]
	if not destroyed and not (card.is_token and destination == null):
		return
	var key := str(pending["key"])
	if not destruction_totals.has(key):
		destruction_totals[key] = (pending["portrait"] as Dictionary).duplicate(true)
		destruction_totals[key]["destroyed"] = 0
	destruction_totals[key]["destroyed"] += 1

func _portrait(card: Card, players: Array[Player], revealed_source: bool = false) -> Dictionary:
	# Hidden sources may contribute to totals, but never reveal their identity.
	if card == null:
		return {}
	if not revealed_source and (card.is_face_down or card.is_stealth or card.is_prepared):
		return {}
	if not revealed_source and card.card_owner != null and card.current_zone != null \
			and card.current_zone in [card.card_owner.hand_zone, card.card_owner.deck_zone]:
		return {}
	return {"name": card.get_display_name(), "art_path": card.art_path,
		"player_index": players.find(card.get_controller())}

func record_loss(victim: Player, amount: int, sources: Array[Card], players: Array[Player]) -> void:
	if amount <= 0:
		return
	var victim_index := players.find(victim)
	var portraits: Array[Dictionary] = []
	var valid_sources: Array[Card] = []
	var weights: Array[int] = []
	var total_weight := 0
	for source in sources:
		if source == null:
			continue
		var index := players.find(source.get_controller())
		if index < 0:
			continue
		portraits.append(_portrait(source, players))
		valid_sources.append(source)
		var weight := maxi(1, source.get_effective_strength())
		weights.append(weight)
		total_weight += weight
	var remaining := amount
	for i in portraits.size():
		var source := valid_sources[i]
		var share := remaining if i == portraits.size() - 1 else int(float(amount * weights[i]) / float(total_weight))
		remaining -= share
		var index := players.find(source.get_controller())
		if source.get_controller() == victim:
			continue
		_totals(index)["damage"] += share
		if portraits[i].is_empty() or share <= 0:
			continue
		# Separate physical copies and changes of controller; stable first-place ties.
		var key := "%d:%d" % [source.get_instance_id(), index]
		if not card_totals.has(key):
			card_totals[key] = portraits[i].duplicate(true)
			card_totals[key]["damage"] = 0
		card_totals[key]["damage"] += share
	var hit: Dictionary = {}
	for portrait in portraits:
		if portrait.is_empty():
			hit = {}
			break
		if hit.is_empty():
			hit = portrait.duplicate(true)
		else:
			hit["name"] += " + " + str(portrait["name"])
	if not hit.is_empty():
		hit["damage"] = amount
		if int(hit.get("player_index", -1)) != victim_index and amount > int(biggest_hit.get("damage", 0)):
			biggest_hit = hit.duplicate(true)
	# An unattributed lethal loss must clear an older candidate as well.
	if victim.followers - amount <= 0:
		lethal_hits[victim_index] = hit

func finish() -> void:
	if _finished_msec < 0:
		_finished_msec = Time.get_ticks_msec()

func summary(players: Array[Player], turn_number: int, loser: Player, reason: String) -> Dictionary:
	var mvp: Dictionary = {}
	var cataclysmic: Dictionary = {}
	for entry: Dictionary in destruction_totals.values():
		if int(entry["destroyed"]) > int(cataclysmic.get("destroyed", 0)):
			cataclysmic = entry.duplicate(true)
	for entry: Dictionary in card_totals.values():
		if int(entry["damage"]) > int(mvp.get("damage", 0)):
			mvp = entry.duplicate(true)
	var totals: Array[Dictionary] = []
	for i in players.size():
		var total := _totals(i).duplicate(true)
		total["name"] = players[i].player_name
		total["followers"] = players[i].followers
		totals.append(total)
	var end_msec := _finished_msec if _finished_msec >= 0 else Time.get_ticks_msec()
	return {"turns": turn_number, "duration_seconds": maxi(0, int((end_msec - _started_msec) / 1000.0)),
		"players": totals, "mvp": mvp, "biggest_hit": biggest_hit.duplicate(true), "cataclysmic": cataclysmic,
		"killing_blow": lethal_hits.get(players.find(loser), {}).duplicate(true) if reason == "defeat" else {}}
