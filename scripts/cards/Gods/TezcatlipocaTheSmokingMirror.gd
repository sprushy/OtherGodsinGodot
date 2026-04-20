extends GodCard
class_name TezcatlipocaTheSmokingMirror

const MANA_GAIN := 1
const ART_PATH := "res://images/card_art/gods/TezArt.png"
const REQUIRED_NECOC_YAOTL_SACRIFICES := 4
const TEZCATLIPOCA_ACTIVE_SCRIPT := preload("res://scripts/cards/ActiveGods/TezcatlipocaActive.gd")

var necoc_yaotl_sacrifices: Array[Card] = []

func _init() -> void:
	super._init()
	card_name = "Tezcatlipoca, the Smoking Mirror"
	card_types = ["Weather", "Sorcery", "War", "Night", "Dominion"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	mana_cost = 0
	culture = "Nahuatl"
	targets = true
	flavor_text = ""
	ability_text = "Tonal Mastery ([b]Passive[/b]): Every time a creature shapeshifts, gain 1 mana.\nNecoc Yaotl ([b]Activate[/b]): Sacrifice a friendly creature and place it under this card. Once you have done this 4 times, summon Tezcatlipoca, Active God."
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	name_at_bottom = true
	paragon_of_champions = "Weather, Dominion"

func can_activate(game_manager: GameManager) -> bool:
	if not can_use_god_power(game_manager):
		return false
	if can_resolve_necoc_yaotl_summon(game_manager):
		return true
	return not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if not can_use_god_power(game_manager):
		if is_muted:
			return card_name + " is muted."
		if card_owner != game_manager.current_player:
			return "It is not " + card_name + "'s turn to act."
		return card_name + " cannot activate right now."
	if _has_completed_necoc_yaotl():
		return get_necoc_yaotl_summon_failure_reason(game_manager)
	if get_valid_targets(game_manager).is_empty():
		return "Necoc Yaotl needs a friendly creature to sacrifice."
	return ""

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null or _has_completed_necoc_yaotl():
		return valid_targets
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if _is_valid_necoc_yaotl_sacrifice(card):
				valid_targets.append(card)
	return valid_targets

func is_valid_activation_target(target: Card) -> bool:
	return target != null and target in get_valid_targets(null)

func activate(game_manager: GameManager, target: Card = null) -> void:
	var feedback := resolve_necoc_yaotl_sacrifice(game_manager, target) if target != null else resolve_necoc_yaotl_summon(game_manager)
	if game_manager != null and feedback.strip_edges() != "":
		game_manager.note_player_feedback(feedback)
	if current_zone != card_owner.god_zone:
		notify_power_activated(game_manager, target)

func activate_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var target_uid := str(command.get("target_uid", ""))
	var target := game_manager.get_card_by_uid(target_uid) if not target_uid.is_empty() else null
	activate(game_manager, target)

func get_necoc_yaotl_sacrifices() -> Array[Card]:
	var stored: Array[Card] = []
	for card in necoc_yaotl_sacrifices:
		if card != null:
			stored.append(card)
	return stored

func get_necoc_yaotl_total_level() -> int:
	var total := 0
	for card in necoc_yaotl_sacrifices:
		if card != null:
			total += card.get_effective_level()
	return total

func can_resolve_necoc_yaotl_summon(game_manager: GameManager) -> bool:
	if not can_use_god_power(game_manager):
		return false
	if not _has_completed_necoc_yaotl():
		return false
	return get_necoc_yaotl_summon_failure_reason(game_manager) == ""

func get_necoc_yaotl_summon_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot summon its Active God right now."
	if not _has_completed_necoc_yaotl():
		return "Necoc Yaotl needs %d sacrifices (have %d)." % [REQUIRED_NECOC_YAOTL_SACRIFICES, necoc_yaotl_sacrifices.size()]
	var manifestation := _get_necoc_yaotl_candidate(true)
	if manifestation == null:
		return card_name + " found no Active God to summon."
	if _get_champions_call_open_zone() == null:
		return card_name + " needs an open lane for its Active God."
	return ""

func resolve_necoc_yaotl_sacrifice(game_manager: GameManager, target: Card) -> String:
	if game_manager == null:
		return card_name + " cannot use Necoc Yaotl right now."
	if not can_use_god_power(game_manager):
		return get_activation_failure_reason(game_manager)
	if _has_completed_necoc_yaotl():
		return "Necoc Yaotl is complete. Summon Tezcatlipoca, Active God instead."
	if not _is_valid_necoc_yaotl_sacrifice(target):
		return "Necoc Yaotl needs a valid friendly creature to sacrifice."

	for equipment_card in target.equipment.duplicate():
		equipment_card.unequip()
	if target.current_zone != null:
		target.current_zone.remove_card(target)
	target.current_zone = null
	necoc_yaotl_sacrifices.append(target)

	return "%s places %s under itself for Necoc Yaotl. (%d/%d)" % [
		card_name,
		target.get_target_log_display_name(game_manager.get_feedback_viewer()),
		necoc_yaotl_sacrifices.size(),
		REQUIRED_NECOC_YAOTL_SACRIFICES
	]

func resolve_necoc_yaotl_summon(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot summon its Active God right now."
	var failure_reason := get_necoc_yaotl_summon_failure_reason(game_manager)
	if failure_reason != "":
		return failure_reason

	var manifestation := _get_necoc_yaotl_candidate(true)
	var summon_zone := _get_champions_call_open_zone()
	var active_god := manifestation as ActiveGodCard
	if active_god != null:
		active_god.set_stored_normal_god(self)
		if active_god.has_method("receive_necoc_yaotl_sacrifices"):
			active_god.call("receive_necoc_yaotl_sacrifices", get_necoc_yaotl_sacrifices())

	var summoned := game_manager.summon_creature_by_effect(
		card_owner,
		manifestation,
		summon_zone,
		Card.CreatureMode.AGGRESSIVE,
		false,
		false,
		self,
		false,
		false,
		true
	)
	if not summoned:
		return card_name + " could not summon its Active God."

	necoc_yaotl_sacrifices.clear()
	game_manager.remove_card_from_game_with_hook(self)
	return "%s summons Tezcatlipoca, Active God through Necoc Yaotl." % card_name

func get_effect_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("Necoc Yaotl sacrifices: %d / %d" % [necoc_yaotl_sacrifices.size(), REQUIRED_NECOC_YAOTL_SACRIFICES])
	lines.append("Stored levels: %d" % get_necoc_yaotl_total_level())
	return lines

func on_creature_shapeshifted(game_manager: GameManager, creature: Card, _source_card: Card = null) -> void:
	if game_manager == null or creature == null or card_owner == null or is_muted:
		return

	var mana_before := card_owner.mana
	card_owner.gain_mana(MANA_GAIN)
	var mana_gained := card_owner.mana - mana_before
	if mana_gained <= 0:
		return

	game_manager.note_player_feedback(
		"%s gains %d mana from Tonal Mastery after %s shapeshifts." % [
			card_name,
			mana_gained,
			creature.get_target_log_display_name(game_manager.get_feedback_viewer())
		]
	)
	notify_power_activated(game_manager, creature)

func _has_completed_necoc_yaotl() -> bool:
	return necoc_yaotl_sacrifices.size() >= REQUIRED_NECOC_YAOTL_SACRIFICES

func _is_valid_necoc_yaotl_sacrifice(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.get_controller() == card_owner \
		and card.can_be_used_for_creature_sacrifice \
		and card.current_zone != null \
		and card.current_zone.is_board_zone()

func _get_necoc_yaotl_candidate(allow_fallback: bool = true) -> Card:
	if card_owner == null:
		return null
	var reserved_manifestation := get_reserved_active_god_candidate()
	if reserved_manifestation != null:
		return reserved_manifestation
	for zone in [
		card_owner.hand_zone,
		card_owner.deck_zone,
		card_owner.graveyard_zone,
	] + card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			var active_god := card as ActiveGodCard
			if active_god == null or active_god.get_linked_god_name() != card_name:
				continue
			if card.current_zone != null and card.current_zone.is_board_zone():
				return null
			return card
	if allow_fallback:
		var manifestation := TEZCATLIPOCA_ACTIVE_SCRIPT.new()
		manifestation.card_owner = card_owner
		return manifestation
	return null
