# GameState.gd
extends RefCounted
class_name GameState

const HIDDEN_MODE_NONE := 0
const HIDDEN_MODE_HAND := 1
const HIDDEN_MODE_BOARD := 2
const SPECTATOR_VIEWER_INDEX := -2

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
	if viewer_player_index == SPECTATOR_VIEWER_INDEX:
		viewer = Player.new()
	elif viewer_player_index >= 0 and viewer_player_index < gm.players.size():
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
		var deck_cards := _serialize_zone_cards(player.deck_zone, viewer, false)
		if hide_deck:
			deck_cards = _serialize_visible_opponent_deck_cards_for_viewer(gm, player, viewer)
		var pdata := {
			player_name = player.player_name,
			mana = player.mana,
			followers = player.followers,
			deck_count = player.deck_zone.cards.size(),
			deck         = deck_cards,
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

static func _serialize_visible_opponent_deck_cards_for_viewer(gm: GameManager, deck_owner: Player, viewer: Player) -> Array:
	var visible_cards := []
	if gm == null or deck_owner == null or viewer == null or deck_owner == viewer:
		return visible_cards
	if not _viewer_can_read_opponent_deck_with_hildskjalf(gm, viewer):
		return visible_cards
	var reveal_count := mini(HildskjalfThroneOfOdin.LOOK_COUNT, deck_owner.deck_zone.cards.size())
	for i in range(reveal_count):
		var card := deck_owner.deck_zone.cards[i] as Card
		if card != null:
			visible_cards.append(_serialize_card(card, HIDDEN_MODE_NONE))
	return visible_cards

static func _viewer_can_read_opponent_deck_with_hildskjalf(gm: GameManager, viewer: Player) -> bool:
	if gm == null or viewer == null:
		return false
	if gm.current_player != viewer:
		return false
	var zones: Array = []
	zones.append_array(viewer.frontline_zones)
	zones.append_array(viewer.reserve_zones)
	zones.append_array(viewer.power_zones)
	zones.append(viewer.god_zone)
	for zone in zones:
		if zone == null:
			continue
		for card in zone.cards:
			var throne := card as HildskjalfThroneOfOdin
			if throne != null and throne.can_activate(gm):
				return true
	return false

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

static func serialize_embedded_card(card: Card) -> Dictionary:
	if card == null:
		return {}
	return _serialize_card(card, HIDDEN_MODE_NONE)

static func sanitize_network_value(value, game_manager: GameManager = null):
	if value == null:
		return null
	if value is bool or value is int or value is float or value is String:
		return value
	if value is Card:
		return {
			"kind": "card_ref",
			"uid": value.get("uid") if "uid" in value else "",
		}
	if value is Player:
		return {
			"kind": "player_ref",
			"player_index": value.get_index(game_manager) if game_manager != null else -1,
		}
	if value is Zone:
		return {
			"kind": "zone_ref",
			"zone": CardAction._zone_to_dict(value as Zone, game_manager),
		}
	if value is CardAction:
		return (value as CardAction).to_dict(game_manager)
	if value is Array:
		var sanitized_items: Array = []
		for entry in value:
			sanitized_items.append(sanitize_network_value(entry, game_manager))
		return sanitized_items
	if value is Dictionary:
		var sanitized_dict := {}
		for key in value.keys():
			sanitized_dict[key] = sanitize_network_value(value[key], game_manager)
		return sanitized_dict
	if value is Object:
		return null
	return value

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
	var attached_target_uid := ""
	if card is PermanentHexCard:
		var attached_target := (card as PermanentHexCard).attached_target
		if attached_target != null and "uid" in attached_target:
			attached_target_uid = attached_target.uid

	return {
		uid                       = uid,
		script_path               = script_path,
		card_name                 = card.card_name,
		card_type                 = card.card_type,
		level                     = card.level,
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
		is_publicly_revealed      = card is PowerCard and (card as PowerCard).is_publicly_revealed,
		is_legendary              = card.is_legendary,
		is_token                  = card.is_token,
		art_path                  = card.art_path,
		ability_text              = card.ability_text,
		card_types                = card.card_types.duplicate(),
		culture                   = card.culture,
		equipped_on_uid           = equipped_on_uid,
		attached_target_uid       = attached_target_uid,
		active_buffs             = _serialize_card_buffs(card),
		active_statuses           = _serialize_card_statuses(card),
		serialized_state          = sanitize_network_value(card.get_serialized_state(), null),
	}

static func _serialize_card_buffs(card: Card) -> Array:
	var result := []
	for buff in card.active_buffs:
		var b := {}
		for key in buff.keys():
			var val = buff[key]
			if val is Card:
				b[key + "_uid"] = (val as Card).uid if "uid" in val else ""
			elif val is Object:
				pass  # Skip Player and other node refs; scalar metadata is enough for client rendering.
			else:
				b[key] = val
		result.append(b)
	return result

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
		if gm != null and action in gm.resolving_stack_actions:
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
	gm.resolving_stack_actions.clear()

	var players_data: Array = data.get("players", [])
	for i in mini(players_data.size(), gm.players.size()):
		var player := gm.players[i]
		var pdata: Dictionary = players_data[i]
		var player_name := str(pdata.get("player_name", player.player_name)).strip_edges()
		if not player_name.is_empty():
			player.player_name = player_name
		player.reserved_active_god = null
		player.mana = pdata.get("mana", 0)
		player.followers = pdata.get("followers", 100)
		player.has_summoned_this_turn = pdata.get("has_summoned_this_turn", false)

		var dk_cards: Array = pdata.get("deck", [])
		var dk_count: int = pdata.get("deck_count", -1)
		player.deck_zone.cards.clear()
		if not dk_cards.is_empty():
			_apply_zone_cards(player.deck_zone, dk_cards)
			if dk_count > player.deck_zone.cards.size():
				for _k in range(dk_count - player.deck_zone.cards.size()):
					var ph := BaseCard.new()
					ph.is_face_down = true
					ph.current_zone = player.deck_zone
					ph.card_owner = player
					player.deck_zone.cards.append(ph)
		elif dk_count >= 0:
			for _k in range(dk_count):
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

	_restore_card_uid_references(gm)
	_restore_prepared_cards(data.get("prepared_hexes", []), gm.prepared_hexes, gm)
	_restore_prepared_cards(data.get("prepared_charms", []), gm.prepared_charms, gm)
	_restore_combat_destroy_events(data.get("combat_destroy_events_this_turn", []), gm)
	for action_data in data.get("action_stack", []):
		if not (action_data is Dictionary):
			continue
		gm.action_stack.append(CardAction.from_dict(action_data, gm))
	gm.prune_stale_stack_actions()

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

static func _restore_card_uid_references(gm: GameManager) -> void:
	var uid_map := _build_card_uid_map(gm)
	for card_value in uid_map.values():
		var card := card_value as Card
		if card == null:
			continue
		_restore_effect_uid_references(card.active_buffs, uid_map)
		_restore_effect_uid_references(card.active_statuses, uid_map)
		if card is PermanentHexCard and card.has_meta("_attached_target_uid"):
			var target_uid := str(card.get_meta("_attached_target_uid")).strip_edges()
			card.remove_meta("_attached_target_uid")
			if uid_map.has(target_uid):
				(card as PermanentHexCard).attached_target = uid_map[target_uid] as Card
		if card.card_type == Card.CardType.EQUIPMENT and card.has_meta("_equipped_on_uid"):
			var equipped_uid := str(card.get_meta("_equipped_on_uid")).strip_edges()
			card.remove_meta("_equipped_on_uid")
			if uid_map.has(equipped_uid):
				var creature := uid_map[equipped_uid] as Card
				card.equipped_on = creature
				if creature != null and card not in creature.equipment:
					creature.equipment.append(card)
		card._sync_status_flags()

static func _restore_effect_uid_references(entries: Array, uid_map: Dictionary) -> void:
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var effect := entry as Dictionary
		for key in effect.keys():
			var key_name := str(key)
			if not key_name.ends_with("_uid"):
				continue
			var uid := str(effect.get(key, "")).strip_edges()
			if uid == "" or not uid_map.has(uid):
				continue
			var ref_key := key_name.substr(0, key_name.length() - 4)
			if not effect.has(ref_key) or effect.get(ref_key, null) == null:
				effect[ref_key] = uid_map[uid]

static func _build_card_uid_map(gm: GameManager) -> Dictionary:
	var uid_map := {}
	for player in gm.players:
		if player == null:
			continue
		for zone in _get_player_card_zones(player):
			if zone == null:
				continue
			for card in zone.cards:
				_collect_card_uid_map_entry(card, uid_map)
	return uid_map

static func _collect_card_uid_map_entry(card: Card, uid_map: Dictionary) -> void:
	if card == null:
		return
	if "uid" in card and card.uid != "":
		uid_map[card.uid] = card
	for nested_value in card.get_hover_stored_cards():
		var nested_card := nested_value as Card
		if nested_card == null:
			continue
		_collect_card_uid_map_entry(nested_card, uid_map)

static func _get_player_card_zones(player: Player) -> Array:
	var zones: Array = [
		player.hand_zone,
		player.deck_zone,
		player.god_zone,
		player.graveyard_zone,
		player.abyss_zone,
	]
	zones.append_array(player.power_zones)
	zones.append_array(player.frontline_zones)
	zones.append_array(player.reserve_zones)
	return zones

static func _deserialize_card(cdata: Dictionary) -> Card:
	if cdata.get("hidden", false):
		var placeholder := BaseCard.new()
		placeholder.uid = cdata.get("uid", "")
		placeholder.card_name = "Hidden card"
		placeholder.card_type = int(cdata.get("card_type", placeholder.card_type)) as Card.CardType
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
	card.level                     = cdata.get("level", card.level)
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
	if card is PowerCard:
		(card as PowerCard).is_publicly_revealed = cdata.get("is_publicly_revealed", false)
	card.is_legendary              = cdata.get("is_legendary", false)
	card.is_token                  = cdata.get("is_token", false)
	card.art_path                  = cdata.get("art_path", card.art_path)
	card.ability_text              = cdata.get("ability_text", card.ability_text)
	card.culture                   = cdata.get("culture", card.culture)
	var ct = cdata.get("card_types", null)
	if ct is Array:
		card.card_types.clear()
		for type_name in ct:
			card.card_types.append(str(type_name))

	# Store equipped_on_uid in meta for the second-pass linking step
	var equipped_uid: String = cdata.get("equipped_on_uid", "")
	if equipped_uid != "":
		card.set_meta("_equipped_on_uid", equipped_uid)
	var attached_target_uid: String = cdata.get("attached_target_uid", "")
	if attached_target_uid != "":
		card.set_meta("_attached_target_uid", attached_target_uid)

	card.active_buffs.clear()
	for bdata in cdata.get("active_buffs", []):
		card.active_buffs.append((bdata as Dictionary).duplicate())

	# Restore status effects (Card/Player refs will be absent on client; name+metadata is enough)
	card.active_statuses.clear()
	for sdata in cdata.get("active_statuses", []):
		card.active_statuses.append((sdata as Dictionary).duplicate())
	card._sync_status_flags()
	card.apply_serialized_state(cdata.get("serialized_state", {}))

	return card

static func deserialize_embedded_card(cdata: Dictionary) -> Card:
	if cdata.is_empty():
		return null
	return _deserialize_card(cdata)

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
