# GameState.gd
extends RefCounted
class_name GameState

const HIDDEN_MODE_NONE := 0
const HIDDEN_MODE_HAND := 1
const HIDDEN_MODE_BOARD := 2

# Serializes and deserializes full game state for network transmission.
# Used by GameEventBroadcaster (server side) and CombatMockGame (client side).

# -------------------------------------------------------------------------
# Serialization (server → dict)
# -------------------------------------------------------------------------

## Produce a full state dict from a live GameManager.
## viewer_player_index: only that player sees their own hand cards;
## the opponent's hand is sent as hidden placeholders, and opponent hidden
## board cards are masked down to public board-facing state only.
## Pass -1 to include all hands unmasked (server-internal use only).
static func serialize(gm: GameManager, viewer_player_index: int = -1) -> Dictionary:
	var viewer: Player = null
	if viewer_player_index >= 0 and viewer_player_index < gm.players.size():
		viewer = gm.players[viewer_player_index]
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
		turn_follower_loss_preventions = _serialize_turn_follower_loss_preventions(gm),
		combat_destroy_events_this_turn = _serialize_combat_destroy_events(gm),
		prepared_hexes = _serialize_prepared_cards(gm.prepared_hexes),
		prepared_charms = _serialize_prepared_cards(gm.prepared_charms),
		action_stack = _serialize_action_stack(gm.action_stack, gm, viewer),
		players = [],
	}
	if gm.winning_player != null:
		data["winner_index"] = gm.players.find(gm.winning_player)

	for i in gm.players.size():
		var player := gm.players[i]
		var hide_hand := viewer != null and i != viewer_player_index
		var hide_deck := viewer != null and i != viewer_player_index
		var pdata := {
			mana = player.mana,
			followers = player.followers,
			deck_count = player.deck_zone.cards.size(),
			deck         = [] if hide_deck else _serialize_zone_cards(player.deck_zone, viewer, false),
			has_summoned_this_turn = player.has_summoned_this_turn,
			hand         = _serialize_zone_cards(player.hand_zone, viewer, hide_hand),
			god_zone     = _serialize_zone_cards(player.god_zone, viewer, false),
			power_zones  = [] as Array,
			frontline_zones = [] as Array,
			reserve_zones   = [] as Array,
			graveyard    = _serialize_zone_cards(player.graveyard_zone, viewer, false),
			abyss        = _serialize_zone_cards(player.abyss_zone, viewer, false),
		}
		for z in player.power_zones:
			pdata.power_zones.append(_serialize_zone_cards(z, viewer, false))
		for z in player.frontline_zones:
			pdata.frontline_zones.append(_serialize_zone_cards(z, viewer, false))
		for z in player.reserve_zones:
			pdata.reserve_zones.append(_serialize_zone_cards(z, viewer, false))
		data.players.append(pdata)

	return data

static func _serialize_zone_cards(zone: Zone, viewer: Player = null, hide_hand: bool = false) -> Array:
	var result := []
	for card in zone.cards:
		var hidden_mode := HIDDEN_MODE_NONE
		if hide_hand:
			hidden_mode = HIDDEN_MODE_HAND
		elif viewer != null and zone.zone_type in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE, Zone.ZoneType.POWER_SLOT, Zone.ZoneType.GOD_SLOT] and card.is_hidden_from_viewer(viewer):
			hidden_mode = HIDDEN_MODE_BOARD
		result.append(_serialize_card(card, hidden_mode))
	return result

static func _serialize_card(card: Card, hidden_mode: int = HIDDEN_MODE_NONE) -> Dictionary:
	var uid: String = card.get("uid") if "uid" in card else ""
	if hidden_mode == HIDDEN_MODE_HAND:
		return {
			uid = uid,
			hidden = true,
			hidden_mode = HIDDEN_MODE_HAND,
			is_face_down = true,
		}
	if hidden_mode == HIDDEN_MODE_BOARD:
		return {
			uid = uid,
			hidden = true,
			hidden_mode = HIDDEN_MODE_BOARD,
			card_type = card.card_type,
			card_types = card.card_types.duplicate(),
			is_face_down = card.is_face_down,
			is_stealth = card.is_stealth,
			is_prepared = card.is_prepared,
			creature_mode = card.creature_mode,
			is_god = card.is_god,
			is_power = card.is_power,
			is_token = card.is_token,
		}

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

static func _serialize_combat_destroy_events(gm: GameManager) -> Array:
	var result := []
	for event in gm.combat_destroy_events_this_turn:
		if not (event is Dictionary):
			continue
		var killer := (event as Dictionary).get("killer", null) as Card
		var victim := (event as Dictionary).get("victim", null) as Card
		var killer_owner := (event as Dictionary).get("killer_owner", null) as Player
		var victim_owner := (event as Dictionary).get("victim_owner", null) as Player
		result.append({
			killer_uid = killer.uid if killer != null and "uid" in killer else "",
			victim_uid = victim.uid if victim != null and "uid" in victim else "",
			killer_owner_index = gm.players.find(killer_owner),
			victim_owner_index = gm.players.find(victim_owner),
		})
	return result

static func _serialize_turn_follower_loss_preventions(gm: GameManager) -> Array:
	var result := []
	for player in gm.turn_follower_loss_preventions:
		var prevention_data: Variant = gm.turn_follower_loss_preventions.get(player, null)
		if not (prevention_data is Dictionary):
			continue
		var source: Card = (prevention_data as Dictionary).get("source_card", null)
		result.append({
			player_index = gm.players.find(player),
			expires_turn = int((prevention_data as Dictionary).get("expires_turn", -1)),
			source_uid = source.uid if source != null and "uid" in source else "",
		})
	return result

static func _serialize_action_stack(action_stack: Array, gm: GameManager, viewer: Player = null) -> Array:
	var result := []
	for action in action_stack:
		if action == null or not (action is CardAction):
			continue
		var serialized := (action as CardAction).to_dict(gm)
		serialized["resolution_text"] = _serialize_action_resolution_text(action as CardAction, viewer)
		result.append(serialized)
	return result

static func _serialize_action_resolution_text(action: CardAction, viewer: Player = null) -> String:
	if action == null:
		return ""
	if viewer == null or not _action_involves_hidden_card(action, viewer):
		return action.resolution_text
	match action.type:
		CardAction.Type.ATTACK:
			if action.target is Player:
				return "%s is attacking %s's followers." % [_card_label_for_viewer(action.attacker, viewer), (action.target as Player).player_name]
			if action.target is Card:
				return "%s is targeting %s." % [_card_label_for_viewer(action.attacker, viewer), _target_label_for_viewer(action.target, viewer)]
			return _card_label_for_viewer(action.attacker, viewer) + " attacks."
		CardAction.Type.EVENT:
			return action.event_name.replace("_", " ").capitalize() + "."
		_:
			if action.target != null:
				return "%s is targeting %s." % [_card_label_for_viewer(action.card, viewer), _target_label_for_viewer(action.target, viewer)]
			return _card_label_for_viewer(action.card, viewer) + " goes on the stack."

static func _card_label_for_viewer(card: Card, viewer: Player = null) -> String:
	if card == null:
		return "Card"
	return card.get_log_display_name(viewer)

static func _target_label_for_viewer(target, viewer: Player = null) -> String:
	if target is Card:
		return (target as Card).get_target_log_display_name(viewer)
	if target is Player:
		return (target as Player).player_name + "'s followers"
	return "target"

static func _action_involves_hidden_card(action: CardAction, viewer: Player) -> bool:
	for maybe_card in [action.card, action.attacker, action.united_front_partner, action.interceptor]:
		if maybe_card != null and (maybe_card as Card).is_hidden_from_viewer(viewer):
			return true
	if action.target is Card and (action.target as Card).is_hidden_from_viewer(viewer):
		return true
	return false

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

	gm.turn_follower_loss_preventions.clear()
	for entry in data.get("turn_follower_loss_preventions", []):
		var p_idx: int = entry.get("player_index", -1)
		if p_idx >= 0 and p_idx < gm.players.size():
			gm.turn_follower_loss_preventions[gm.players[p_idx]] = {
				expires_turn = int(entry.get("expires_turn", -1)),
				source_card = null,
			}

	gm.prepared_hexes.clear()
	gm.prepared_charms.clear()
	gm.combat_destroy_events_this_turn.clear()
	gm.action_stack.clear()

	var players_data: Array = data.get("players", [])
	for i in mini(players_data.size(), gm.players.size()):
		var player := gm.players[i]
		var pdata: Dictionary = players_data[i]
		player.reserved_active_god = null
		player.mana = pdata.get("mana", 0)
		player.followers = pdata.get("followers", 100)
		player.has_summoned_this_turn = pdata.get("has_summoned_this_turn", false)

		var dk_cards: Array = pdata.get("deck", [])
		var dk_count: int = pdata.get("deck_count", -1)
		player.deck_zone.cards.clear()
		if not dk_cards.is_empty():
			_apply_zone_cards(player.deck_zone, dk_cards)
		elif dk_count >= 0:
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
	_restore_combat_destroy_events(data.get("combat_destroy_events_this_turn", []), gm)
	for action_data in data.get("action_stack", []):
		if not (action_data is Dictionary):
			continue
		gm.action_stack.append(CardAction.from_dict(action_data, gm))

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
		placeholder.card_name = "Hidden card"
		placeholder.card_type = int(cdata.get("card_type", placeholder.card_type)) as Card.CardType
		var hidden_card_types = cdata.get("card_types", null)
		if hidden_card_types is Array:
			placeholder.card_types = hidden_card_types
		placeholder.is_face_down = cdata.get("is_face_down", true)
		placeholder.is_stealth = cdata.get("is_stealth", false)
		placeholder.is_prepared = cdata.get("is_prepared", false)
		placeholder.creature_mode = int(cdata.get("creature_mode", placeholder.creature_mode)) as Card.CreatureMode
		placeholder.is_god = cdata.get("is_god", false)
		placeholder.is_power = cdata.get("is_power", false)
		placeholder.is_token = cdata.get("is_token", false)
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

static func _restore_combat_destroy_events(entries: Array, gm: GameManager) -> void:
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var event_dict := entry as Dictionary
		var killer_uid := str(event_dict.get("killer_uid", "")).strip_edges()
		var victim_uid := str(event_dict.get("victim_uid", "")).strip_edges()
		var killer := gm.get_card_by_uid(killer_uid) if not killer_uid.is_empty() else null
		var victim := gm.get_card_by_uid(victim_uid) if not victim_uid.is_empty() else null
		var killer_owner_index := int(event_dict.get("killer_owner_index", -1))
		var victim_owner_index := int(event_dict.get("victim_owner_index", -1))
		var killer_owner := gm.players[killer_owner_index] if killer_owner_index >= 0 and killer_owner_index < gm.players.size() else null
		var victim_owner := gm.players[victim_owner_index] if victim_owner_index >= 0 and victim_owner_index < gm.players.size() else null
		gm.combat_destroy_events_this_turn.append({
			"killer": killer,
			"victim": victim,
			"killer_owner": killer_owner,
			"victim_owner": victim_owner,
		})
