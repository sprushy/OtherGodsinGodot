# GameState.gd
extends RefCounted
class_name GameState

# Serializes and deserializes full game state for network transmission.
# Used by GameEventBroadcaster (server side) and CombatMockGame (client side).

# -------------------------------------------------------------------------
# Serialization (server → dict)
# -------------------------------------------------------------------------

## Produce a full state dict from a live GameManager.
## viewer_player_index: only that player sees their own hand cards;
## the opponent's hand is sent as hidden placeholders.
## Pass -1 to include all hands unmasked (server-internal use only).
static func serialize(gm: GameManager, viewer_player_index: int = -1) -> Dictionary:
	var data := {
		turn_number = gm.turn_number,
		current_player_index = gm.players.find(gm.current_player),
		phase = gm.current_phase,
		is_game_over = gm.is_game_over,
		upkeep_resolved_turn = gm._upkeep_resolved_turn,
		upkeep_started_turn = gm._upkeep_started_turn,
		priority_player_index = gm.players.find(gm.priority_player),
		consecutive_passes = gm.consecutive_passes,
		attack_restrictions = _serialize_attack_restrictions(gm),
		prepared_hexes = _serialize_prepared_cards(gm.prepared_hexes),
		prepared_charms = _serialize_prepared_cards(gm.prepared_charms),
		players = [],
	}
	if gm.winning_player != null:
		data["winner_index"] = gm.players.find(gm.winning_player)

	for i in gm.players.size():
		var player := gm.players[i]
		var hide_hand := viewer_player_index >= 0 and i != viewer_player_index
		var pdata := {
			mana = player.mana,
			followers = player.followers,
			deck_count = player.deck_zone.cards.size(),
			has_summoned_this_turn = player.has_summoned_this_turn,
			hand         = _serialize_zone_cards(player.hand_zone, hide_hand),
			god_zone     = _serialize_zone_cards(player.god_zone, false),
			power_zones  = [] as Array,
			frontline_zones = [] as Array,
			reserve_zones   = [] as Array,
			graveyard    = _serialize_zone_cards(player.graveyard_zone, false),
			abyss        = _serialize_zone_cards(player.abyss_zone, false),
		}
		for z in player.power_zones:
			pdata.power_zones.append(_serialize_zone_cards(z, false))
		for z in player.frontline_zones:
			pdata.frontline_zones.append(_serialize_zone_cards(z, false))
		for z in player.reserve_zones:
			pdata.reserve_zones.append(_serialize_zone_cards(z, false))
		data.players.append(pdata)

	return data

static func _serialize_zone_cards(zone: Zone, hidden: bool) -> Array:
	var result := []
	for card in zone.cards:
		result.append(_serialize_card(card, hidden))
	return result

static func _serialize_card(card: Card, hidden: bool) -> Dictionary:
	var uid: String = card.get("uid") if "uid" in card else ""
	# Hidden = opponent's hand card that hasn't been revealed
	if hidden and not card.is_face_down:
		return {uid = uid, hidden = true}

	var script_path := ""
	var script = card.get_script()
	if script != null:
		script_path = script.resource_path

	var equipped_on_uid := ""
	if card.equipped_on != null and "uid" in card.equipped_on:
		equipped_on_uid = card.equipped_on.uid

	return {
		uid                       = uid,
		script_path               = script_path,
		card_name                 = card.card_name,
		card_type                 = card.card_type,
		strength                  = card.strength,
		resilience                = card.resilience,
		speed                     = card.speed,
		mana_cost                 = card.mana_cost,
		is_face_down              = card.is_face_down,
		is_stealth                = card.is_stealth,
		creature_mode             = card.creature_mode,
		is_sleeping               = card.is_sleeping,
		is_prepared               = card.is_prepared,
		summoned_this_turn        = card.summoned_this_turn,
		creature_major_action_used   = card.creature_major_action_used,
		creature_minor_actions_used  = card.creature_minor_actions_used,
		is_used                   = card.is_used,
		is_muted                  = card.is_muted,
		mute_turns_remaining      = card.mute_turns_remaining,
		board_entry_order         = card.board_entry_order,
		is_god                    = card.is_god,
		is_power                  = card.is_power,
		is_legendary              = card.is_legendary,
		is_token                  = card.is_token,
		art_path                  = card.art_path,
		ability_text              = card.ability_text,
		card_types                = card.card_types.duplicate(),
		culture                   = card.culture,
		equipped_on_uid           = equipped_on_uid,
		active_statuses           = _serialize_card_statuses(card),
	}

static func _serialize_card_statuses(card: Card) -> Array:
	var result := []
	for status in card.active_statuses:
		var s := {}
		for key in status.keys():
			var val = status[key]
			if val is Card:
				s[key + "_uid"] = (val as Card).uid if "uid" in val else ""
			elif val is Object:
				pass  # Skip Player and other node refs — name/metadata sufficient on client
			else:
				s[key] = val
		result.append(s)
	return result

static func _serialize_attack_restrictions(gm: GameManager) -> Array:
	var result := []
	for player in gm.attack_restrictions:
		var val: Dictionary = gm.attack_restrictions[player]
		var source: Card = val.get("source", null)
		result.append({
			player_index = gm.players.find(player),
			turns = val.get("turns", 0),
			source_uid = source.uid if source != null and "uid" in source else "",
		})
	return result

static func _serialize_prepared_cards(prepared_map: Dictionary) -> Array:
	var result := []
	for card in prepared_map.keys():
		if card == null:
			continue
		result.append({
			uid = card.uid,
			prepared_turn = int(prepared_map.get(card, 0)),
		})
	return result

# -------------------------------------------------------------------------
# Deserialization (dict → ghost GameManager)
# -------------------------------------------------------------------------

## Apply serialized state to an existing GameManager (client ghost GM).
## Clears and repopulates all zones with freshly-instantiated card objects.
## After calling this, clear any card references held by the UI.
static func apply_to_manager(data: Dictionary, gm: GameManager) -> void:
	gm.turn_number = data.get("turn_number", 0)
	var cp_idx: int = data.get("current_player_index", 0)
	if cp_idx >= 0 and cp_idx < gm.players.size():
		gm.current_player = gm.players[cp_idx]
		gm.other_player = gm.players[1 - cp_idx]
		gm.turn_player = gm.current_player
	gm.current_phase = int(data.get("phase", GameManager.GamePhase.MULLIGAN)) as GameManager.GamePhase
	gm.is_game_over = data.get("is_game_over", false)
	gm._upkeep_resolved_turn = data.get("upkeep_resolved_turn", -1)
	gm._upkeep_started_turn = data.get("upkeep_started_turn", -1)
	gm.consecutive_passes = data.get("consecutive_passes", 0)

	var pp_idx: int = data.get("priority_player_index", -1)
	gm.priority_player = gm.players[pp_idx] if pp_idx >= 0 and pp_idx < gm.players.size() else null

	gm.attack_restrictions.clear()
	for entry in data.get("attack_restrictions", []):
		var p_idx: int = entry.get("player_index", -1)
		if p_idx >= 0 and p_idx < gm.players.size():
			gm.attack_restrictions[gm.players[p_idx]] = {
				turns = entry.get("turns", 0),
				source = null,
			}

	gm.prepared_hexes.clear()
	gm.prepared_charms.clear()

	var players_data: Array = data.get("players", [])
	for i in mini(players_data.size(), gm.players.size()):
		var player := gm.players[i]
		var pdata: Dictionary = players_data[i]
		player.mana = pdata.get("mana", 0)
		player.followers = pdata.get("followers", 100)
		player.has_summoned_this_turn = pdata.get("has_summoned_this_turn", false)

		# Populate deck zone with placeholders so get_card_count() is accurate on clients
		var dk_count: int = pdata.get("deck_count", -1)
		if dk_count >= 0:
			player.deck_zone.cards.clear()
			for _k in dk_count:
				var ph := BaseCard.new()
				ph.is_face_down = true
				ph.current_zone = player.deck_zone
				ph.card_owner = player
				player.deck_zone.cards.append(ph)

		_apply_zone_cards(player.hand_zone,     pdata.get("hand", []))
		_apply_zone_cards(player.god_zone,      pdata.get("god_zone", []))
		_apply_zone_cards(player.graveyard_zone, pdata.get("graveyard", []))
		_apply_zone_cards(player.abyss_zone,    pdata.get("abyss", []))

		var power_data: Array = pdata.get("power_zones", [])
		for j in mini(power_data.size(), player.power_zones.size()):
			_apply_zone_cards(player.power_zones[j], power_data[j])

		var fl_data: Array = pdata.get("frontline_zones", [])
		for j in mini(fl_data.size(), player.frontline_zones.size()):
			_apply_zone_cards(player.frontline_zones[j], fl_data[j])

		var res_data: Array = pdata.get("reserve_zones", [])
		for j in mini(res_data.size(), player.reserve_zones.size()):
			_apply_zone_cards(player.reserve_zones[j], res_data[j])

	_restore_prepared_cards(data.get("prepared_hexes", []), gm.prepared_hexes, gm)
	_restore_prepared_cards(data.get("prepared_charms", []), gm.prepared_charms, gm)

static func _apply_zone_cards(zone: Zone, cards_data: Array) -> void:
	zone.cards.clear()
	for cdata in cards_data:
		var card := _deserialize_card(cdata)
		if card != null:
			card.card_owner = zone.zone_owner
			card.current_zone = zone
			zone.cards.append(card)
	# Second pass: restore equipment → creature links using stored meta
	_link_equipment_in_zone(zone)

static func _link_equipment_in_zone(zone: Zone) -> void:
	var uid_map := {}
	for card in zone.cards:
		if "uid" in card and card.uid != "":
			uid_map[card.uid] = card
	for card in zone.cards:
		if card.card_type == Card.CardType.EQUIPMENT and card.has_meta("_equipped_on_uid"):
			var target_uid: String = card.get_meta("_equipped_on_uid")
			card.remove_meta("_equipped_on_uid")
			if uid_map.has(target_uid):
				var creature: Card = uid_map[target_uid]
				card.equipped_on = creature
				if card not in creature.equipment:
					creature.equipment.append(card)

static func _deserialize_card(cdata: Dictionary) -> Card:
	if cdata.get("hidden", false):
		var placeholder := BaseCard.new()
		placeholder.uid = cdata.get("uid", "")
		placeholder.card_name = "???"
		placeholder.is_face_down = true
		return placeholder

	var script_path: String = cdata.get("script_path", "")
	var card: Card
	if script_path != "" and ResourceLoader.exists(script_path):
		var script = load(script_path)
		if script != null:
			card = script.new()
		else:
			card = BaseCard.new()
	else:
		card = BaseCard.new()

	# Server-assigned uid overrides the auto-generated one from _init()
	if "uid" in card:
		card.uid = cdata.get("uid", "")

	card.card_name                 = cdata.get("card_name", card.card_name)
	card.card_type                 = int(cdata.get("card_type", card.card_type)) as Card.CardType
	card.strength                  = cdata.get("strength", card.strength)
	card.resilience                = cdata.get("resilience", card.resilience)
	card.speed                     = cdata.get("speed", card.speed)
	card.mana_cost                 = cdata.get("mana_cost", card.mana_cost)
	card.is_face_down              = cdata.get("is_face_down", false)
	card.is_stealth                = cdata.get("is_stealth", false)
	card.creature_mode             = int(cdata.get("creature_mode", card.creature_mode)) as Card.CreatureMode
	card.is_sleeping               = cdata.get("is_sleeping", false)
	card.is_prepared               = cdata.get("is_prepared", false)
	card.summoned_this_turn        = cdata.get("summoned_this_turn", false)
	card.creature_major_action_used   = cdata.get("creature_major_action_used", false)
	card.creature_minor_actions_used  = cdata.get("creature_minor_actions_used", 0)
	card.is_used                   = cdata.get("is_used", false)
	card.is_muted                  = cdata.get("is_muted", false)
	card.mute_turns_remaining      = cdata.get("mute_turns_remaining", 0)
	card.board_entry_order         = cdata.get("board_entry_order", -1)
	card.is_god                    = cdata.get("is_god", false)
	card.is_power                  = cdata.get("is_power", false)
	card.is_legendary              = cdata.get("is_legendary", false)
	card.is_token                  = cdata.get("is_token", false)
	card.art_path                  = cdata.get("art_path", card.art_path)
	card.ability_text              = cdata.get("ability_text", card.ability_text)
	card.culture                   = cdata.get("culture", card.culture)
	var ct = cdata.get("card_types", null)
	if ct is Array:
		card.card_types = ct

	# Store equipped_on_uid in meta for the second-pass linking step
	var equipped_uid: String = cdata.get("equipped_on_uid", "")
	if equipped_uid != "":
		card.set_meta("_equipped_on_uid", equipped_uid)

	# Restore status effects (Card/Player refs will be absent on client; name+metadata is enough)
	card.active_statuses.clear()
	for sdata in cdata.get("active_statuses", []):
		card.active_statuses.append((sdata as Dictionary).duplicate())
	card._sync_status_flags()

	return card

static func _restore_prepared_cards(entries: Array, target_map: Dictionary, gm: GameManager) -> void:
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var uid := str((entry as Dictionary).get("uid", "")).strip_edges()
		if uid.is_empty():
			continue
		var card := gm.get_card_by_uid(uid)
		if card == null:
			continue
		target_map[card] = int((entry as Dictionary).get("prepared_turn", gm.turn_number))
