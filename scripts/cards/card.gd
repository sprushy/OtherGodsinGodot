# Card.gd
extends Resource
class_name Card

enum CardType { CREATURE, SPELL, EQUIPMENT, STRUCTURE, HEX, POWER, CHARM, GOD }
enum CreatureMode { AGGRESSIVE, DEFENSIVE }

@export var card_name: String
@export var card_type: CardType
@export var speed: int = 1
@export var level: int = 1
@export var is_legendary: bool = false
@export var is_god: bool = false
@export var is_power: bool = false
@export var is_token: bool = false
@export var can_be_used_for_creature_sacrifice: bool = true

# Card types (warrior, mage, etc.) - can have multiple
@export var card_types: Array[String] = []

# Lore and background
@export_multiline var flavor_text: String = ""
@export_multiline var ability_text: String = ""
@export var targets: bool = false  # True if this card's effect targets a specific card
@export var culture: String = ""  # e.g., "Sumerian", "Norse", "Egyptian"
@export var art_path: String = "":  # e.g., "res://images/card_art/hexes/VoidShield.jpg"
	set(value):
		_art_path = resolve_art_path(value)
	get:
		return _art_path
@export var art_variants: Array[String] = []
@export var artist: String = ""
@export var paragon_of_champions: String = ""  # Name of the champion type this god is patron of; empty if not a paragon
@export var name_at_bottom: bool = false  # If true, card name is rendered at the bottom instead of the top
@export var exhausted_art_path: String = "":  # Art to switch to when the card's effect is exhausted
	set(value):
		_exhausted_art_path = resolve_art_path(value)
	get:
		return _exhausted_art_path
@export var ability_immunity_tag: String = ""

signal art_updated(new_path: String)
signal visual_state_changed()

var _art_path: String = ""
var _exhausted_art_path: String = ""

func should_show_flavor_text_in_hover() -> bool:
	return flavor_text != "" and ability_text == ""

func get_display_ability_text(_game_manager: GameManager = null) -> String:
	return ability_text

func get_display_ability_bbcode_text(game_manager: GameManager = null) -> String:
	return get_display_ability_text(game_manager)

const CARD_NAME_MOJIBAKE_FIXES := {
	"AurboÃƒÂ°a": "Aurboða",
	"AurboÃ°a": "Aurboða"
}

const CARD_NAME_ASCII_FALLBACKS := {
	"À": "A", "Á": "A", "Â": "A", "Ã": "A", "Ä": "A", "Å": "A",
	"Æ": "Ae", "Ç": "C", "È": "E", "É": "E", "Ê": "E", "Ë": "E",
	"Ì": "I", "Í": "I", "Î": "I", "Ï": "I", "Ð": "D", "Ñ": "N",
	"Ò": "O", "Ó": "O", "Ô": "O", "Õ": "O", "Ö": "O", "Ø": "O",
	"Ù": "U", "Ú": "U", "Û": "U", "Ü": "U", "Ý": "Y", "Þ": "Th",
	"ß": "ss",
	"à": "a", "á": "a", "â": "a", "ã": "a", "ä": "a", "å": "a",
	"æ": "ae", "ç": "c", "è": "e", "é": "e", "ê": "e", "ë": "e",
	"ì": "i", "í": "i", "î": "i", "ï": "i", "ð": "d", "ñ": "n",
	"ò": "o", "ó": "o", "ô": "o", "õ": "o", "ö": "o", "ø": "o",
	"ù": "u", "ú": "u", "û": "u", "ü": "u", "ý": "y", "þ": "th",
	"ÿ": "y", "Œ": "Oe", "œ": "oe", "Š": "S", "š": "s", "Ž": "Z",
	"ž": "z", "Ł": "L", "ł": "l"
}

const ART_PATH_REDIRECTS := {
	"res://images/card_art/DragrRevenantAIEdit.png": "res://images/card_art/creatures/DragrRevenantAIEdit.png",
	"res://images/card_art/DurinnAIEdit.png": "res://images/card_art/creatures/DurinnAIEdit.png",
	"res://images/card_art/FifaAIEdit.png": "res://images/card_art/charms/FifaAIEdit.png",
	"res://images/card_art/FireandGoldAIEdit.png": "res://images/card_art/powers/FireandGoldAIEdit.png",
	"res://images/card_art/FirstSageAdapaAIedit.png": "res://images/card_art/creatures/FirstSageAdapaAIedit.png",
	"res://images/card_art/FourthSageAiEdit2.png": "res://images/card_art/creatures/FourthSageAiEdit2.png",
	"res://images/card_art/creatures/Again-Walker(web).jpg": "res://images/card_art/creatures/Again-Walker(web) - Copy.jpg",
	"res://images/card_art/creatures/enki_lord_of_eridu.jpg": "res://images/card_art/creatures/enki_lord_of_eridu - Copy.jpg",
	"res://images/card_art/creatures/gilgamesh.png": "res://images/card_art/creatures/gilgamesh - Copy.png",
	"res://images/card_art/GleipnirEdit.png": "res://images/card_art/hexes/GleipnirEdit.png",
	"res://images/card_art/HariiShamanEdit.png": "res://images/card_art/creatures/HariiShamanEdit.png",
	"res://images/card_art/HariiWarriorEdit.png": "res://images/card_art/creatures/HariiWarriorEdit.png",
	"res://images/card_art/Hel-BlarDraugEdit.png": "res://images/card_art/creatures/Hel-BlarDraugEdit.png",
	"res://images/card_art/Humbaba(print)Art.jpg": "res://images/card_art/creatures/Humbaba(print)Art.jpg",
	"res://images/card_art/HuntingTacticsEdit.png": "res://images/card_art/powers/HuntingTacticsEdit.png",
	"res://images/card_art/Hyena Pack(print).jpg": "res://images/card_art/creatures/Hyena Pack(print).jpg",
	"res://images/card_art/ImmortalTechniqueEdit.png": "res://images/card_art/powers/ImmortalTechniqueEdit.png",
	"res://images/card_art/InfernoAIEdit.png": "res://images/card_art/spells/InfernoAIEdit.png",
	"res://images/card_art/Isimud(web).jpg": "res://images/card_art/creatures/Isimud(web).jpg",
	"res://images/card_art/KurnugiaArt.jpg": "res://images/card_art/powers/KurnugiaArt.jpg",
	"res://images/card_art/LawsArtEdit.jpg": "res://images/card_art/powers/LawsArtEdit.jpg",
	"res://images/card_art/Lesser Mushussu(print).jpg": "res://images/card_art/creatures/Lesser Mushussu(print).jpg",
	"res://images/card_art/MalinalxochitalAcolyteEdit2.png": "res://images/card_art/creatures/MalinalxochitalAcolyteEdit2.png",
	"res://images/card_art/MeadofPoetryAIEdit.png": "res://images/card_art/charms/MeadofPoetryAIEdit.png",
	"res://images/card_art/SolomonKeyEdit.png": "res://images/card_art/spells/SolomonKeyEdit.png",
	"res://scripts/cards/Charms/NuskuEdit2.png": "res://images/card_art/gods/NuskuEdit2.png",
	"res://scripts/cards/Charms/PalisadeArtEdit.png": "res://images/card_art/structures/PalisadeArtEdit.png",
	"res://scripts/cards/Creatures/kite shield image.png": "res://images/card_art/unused/kite shield image.png",
	"res://scripts/cards/Creatures/NagualEdit.png": "res://images/card_art/creatures/NagualEdit.png",
	"res://scripts/cards/Creatures/NamburbiArt.jpg": "res://images/card_art/charms/NamburbiArt.jpg",
	"res://scripts/cards/Creatures/NergalLionEdit.png": "res://images/card_art/creatures/NergalLionEdit.png",
	"res://scripts/cards/Creatures/NimueEdit.png": "res://images/card_art/creatures/NimueEdit.png",
	"res://scripts/cards/Creatures/NorseBloodlustEdit.png": "res://images/card_art/powers/NorseBloodlustEdit.png",
	"res://scripts/cards/Creatures/NorseShortswordEdit.png": "res://images/card_art/equipment/NorseShortswordEdit.png",
	"res://scripts/cards/Creatures/NuskuEdit.png": "res://images/card_art/gods/NuskuEdit.png",
	"res://scripts/cards/Creatures/OccultSingularityEdit.png": "res://images/card_art/spells/OccultSingularityEdit.png",
	"res://scripts/cards/Creatures/OdinBloodlust.png": "res://images/card_art/gods/OdinBloodlust.png",
	"res://scripts/cards/Creatures/OdinBloodlust2.png": "res://images/card_art/gods/OdinBloodlust2.png",
	"res://scripts/cards/Creatures/OdinEdit.png": "res://images/card_art/gods/OdinEdit.png",
	"res://images/card_art/gods/OdinBloodlust.png": "res://images/card_art/gods/Odin.jpg",
	"res://images/card_art/gods/OdinBloodlust2.png": "res://images/card_art/gods/Odin.jpg",
	"res://images/card_art/gods/OdinEdit.png": "res://images/card_art/gods/Odin.jpg",
	"res://scripts/cards/Creatures/OraclesSightEdit.png": "res://images/card_art/powers/OraclesSightEdit.png",
	"res://scripts/cards/Creatures/RabidWolfEdit.png": "res://images/card_art/creatures/RabidWolfEdit.png",
	"res://scripts/cards/Creatures/RabidWolfEdit2.png": "res://images/card_art/creatures/RabidWolfEdit2.png",
	"res://scripts/cards/Creatures/RabisuEdit.png": "res://images/card_art/creatures/RabisuEdit.png",
	"res://scripts/cards/Creatures/WheelofFireEdit.png": "res://images/card_art/hexes/WheelofFireEdit.png",
	"res://scripts/cards/Creatures/WolfCubEdit.png": "res://images/card_art/creatures/WolfCubEdit.png",
	"res://scripts/cards/Gods/BrownBearEdit2.png": "res://images/card_art/creatures/BrownBearEdit2.png",
	"res://scripts/cards/Gods/CernunnosEdit.png": "res://images/card_art/gods/CernunnosEdit.png",
	"res://scripts/cards/Gods/CernunnosEdit2.png": "res://images/card_art/gods/CernunnosEdit2.png",
	"res://scripts/cards/Gods/PazuzuEdit.png": "res://images/card_art/creatures/PazuzuEdit.png",
	"res://scripts/cards/Gods/PegasusArt.jpg": "res://images/card_art/creatures/PegasusArt.jpg",
	"res://scripts/cards/Gods/Take the Field(web).jpg": "res://images/card_art/powers/Take the Field(web).jpg",
	"res://scripts/cards/Hexes/CernunnodEdit.png": "res://images/card_art/unused/CernunnodEdit.png",
	"res://scripts/cards/Hexes/SapStrengthEdit2.png": "res://images/card_art/hexes/SapStrengthEdit2.png",
	"res://scripts/cards/Powers/inferno(web).jpg": "res://images/card_art/hexes/inferno(web).jpg",
	"res://scripts/cards/Powers/Sulak the Unclean(web).jpg": "res://images/card_art/creatures/Sulak the Unclean(web).jpg",
	"res://scripts/cards/Powers/SummonedSapArt.jpg": "res://images/card_art/powers/SummonedSapArt.jpg",
	"res://scripts/cards/Powers/TabletofLifeEdit.jpg": "res://images/card_art/spells/TabletofLifeEdit.jpg",
	"res://scripts/cards/Powers/TatzelwyrmEdit.png": "res://images/card_art/creatures/TatzelwyrmEdit.png",
	"res://scripts/cards/Powers/TelchineApprenticeEdit.png": "res://images/card_art/creatures/TelchineApprenticeEdit.png",
	"res://scripts/cards/Powers/Terror(web).jpg": "res://images/card_art/powers/Terror(web).jpg",
	"res://scripts/cards/Powers/TezArt.png": "res://images/card_art/gods/TezArt.png",
	"res://scripts/cards/Powers/TezBlasphemerEdit.png": "res://images/card_art/creatures/TezBlasphemerEdit.png",
	"res://scripts/cards/Powers/TheDelugeEdit.png": "res://images/card_art/hexes/TheDelugeEdit.png",
	"res://scripts/cards/Powers/TheDragonKingEdit.png": "res://images/card_art/creatures/TheDragonKingEdit.png",
	"res://scripts/cards/Powers/TheWhiteSerpentEdit.png": "res://images/card_art/creatures/TheWhiteSerpentEdit.png",
	"res://scripts/cards/Powers/ThirdSageEnmeduggaArt.jpg": "res://images/card_art/creatures/ThirdSageEnmeduggaArt.jpg",
	"res://scripts/cards/Powers/ThroneodOdinEdit.png": "res://images/card_art/structures/ThroneodOdinEdit.png",
	"res://scripts/cards/Powers/VisionofOdinEdit.png": "res://images/card_art/hexes/VisionofOdinEdit.png",
	"res://scripts/cards/Powers/Walk of the Sage(web).jpg": "res://images/card_art/powers/Walk of the Sage(web).jpg",
	"res://scripts/cards/Powers/WheelofFireEdit.png": "res://images/card_art/hexes/WheelofFireEdit.png",
	"res://scripts/cards/Powers/WhiteStageEdit.png": "res://images/card_art/unused/WhiteStageEdit.png",
	"res://scripts/cards/Powers/WolfAdolescentArt.jpg": "res://images/card_art/creatures/WolfAdolescentArt.jpg",
	"res://scripts/cards/Structures/TiamatEdit.png": "res://images/card_art/gods/TiamatEdit.png",
	"res://scripts/cards/Structures/TonalExtractionEdit.png": "res://images/card_art/powers/TonalExtractionEdit.png",
	"res://scripts/cards/Structures/UriskGrovekeepersEdit.png": "res://images/card_art/creatures/UriskGrovekeepersEdit.png",
	"res://scripts/cards/Structures/VisionofTarturusEdit.png": "res://images/card_art/hexes/VisionofTarturusEdit.png",
	"res://scripts/cards/ShroudoftheAncientsArt.jpg": "res://images/card_art/hexes/ShroudoftheAncientsArt.jpg",
	"res://scripts/cards/SixthSageEdit.png": "res://images/card_art/creatures/SixthSageEdit.png",
	"res://scripts/cards/SmiteArt.jpg": "res://images/card_art/hexes/SmiteArt.jpg",
	"res://scripts/cards/SpellDemolition.jpg": "res://images/card_art/hexes/SpellDemolition.jpg",
	"res://scripts/cards/SpellDemolitionArt.jpg": "res://images/card_art/hexes/SpellDemolitionArt.jpg",
	"res://scripts/cards/StormEdit.png": "res://images/card_art/charms/StormEdit.png",
	"res://scripts/cards/SummonedSapArt.jpg": "res://images/card_art/powers/SummonedSapArt.jpg",
	"res://scripts/cards/TianLongEdit.png": "res://images/card_art/creatures/TianLongEdit.png",
	"res://scripts/core/RabidWolfEdit2.png": "res://images/card_art/creatures/RabidWolfEdit2.png",
	"res://scripts/Other/Saving GraceArt.jpg": "res://images/card_art/powers/Saving GraceArt.jpg",
	"res://scripts/Other/Scorpion man axe(print)art.jpg": "res://images/card_art/unused/Scorpion man axe(print)art.jpg",
	"res://scripts/Other/SepLemmutiEdit.png": "res://images/card_art/hexes/SepLemmutiEdit.png",
	"res://scripts/Other/Sevenhsart.jpg": "res://images/card_art/unused/Sevenhsart.jpg",
	"res://scripts/Other/SevenLeagueBootsEdit.png": "res://images/card_art/equipment/SevenLeagueBootsEdit.png",
	"res://scripts/Other/SeventhSageEdit.png": "res://images/card_art/creatures/SeventhSageEdit.png",
	"res://scripts/Other/SharurEdit.png": "res://images/card_art/equipment/SharurEdit.png"
}

static func resolve_art_path(raw_path: String) -> String:
	var resolved_path := str(raw_path).strip_edges()
	if resolved_path == "":
		return ""
	var seen: Dictionary = {}
	while ART_PATH_REDIRECTS.has(resolved_path) and not seen.has(resolved_path):
		seen[resolved_path] = true
		resolved_path = str(ART_PATH_REDIRECTS[resolved_path]).strip_edges()
	return resolved_path

func get_art_variant_paths() -> Array[String]:
	var variants: Array[String] = []
	for raw_path in art_variants:
		var resolved_path := resolve_art_path(raw_path)
		if not resolved_path.is_empty() and resolved_path not in variants:
			variants.append(resolved_path)
	if variants.is_empty() and not art_path.is_empty():
		variants.append(art_path)
	return variants

func set_art_variant(variant_index: int) -> bool:
	var variants := get_art_variant_paths()
	if variant_index < 0 or variant_index >= variants.size():
		return false
	art_path = variants[variant_index]
	art_updated.emit(art_path)
	return true

func switch_to_exhausted_art() -> void:
	if exhausted_art_path != "":
		art_path = exhausted_art_path
		art_updated.emit(art_path)

func _emit_visual_state_changed() -> void:
	visual_state_changed.emit()

# Costs
@export var mana_cost: int = 0
@export var discard_cost: int = 0  # Number of cards to discard
@export var sacrifice_cost: int = 0  # Number of creatures to sacrifice from board
@export var banish_cost: int = 0  # Number of cards to banish
@export var shelve_cost: int = 0  # Number of cards to shelve (return to bottom of deck)

func has_additional_costs() -> bool:
	return discard_cost > 0 \
		or sacrifice_cost > 0 \
		or banish_cost > 0 \
		or shelve_cost > 0

func has_listed_play_costs() -> bool:
	return mana_cost > 0 or has_additional_costs()

func get_cost_shorthand_parts(mana_override: int = -1, force_show_mana: bool = false) -> Array[String]:
	var parts: Array[String] = []
	var display_mana_cost := mana_override if mana_override >= 0 else mana_cost
	var show_mana := display_mana_cost > 0 or force_show_mana
	if show_mana:
		parts.append(str(display_mana_cost) + "M")
	if discard_cost > 0:
		parts.append(str(discard_cost) + "D")
	if sacrifice_cost > 0:
		parts.append(str(sacrifice_cost) + "S")
	if banish_cost > 0:
		parts.append(str(banish_cost) + "B")
	if shelve_cost > 0:
		parts.append(str(shelve_cost) + "Sh")
	return parts

func get_cost_shorthand(mana_override: int = -1, force_show_mana: bool = false) -> String:
	return " ".join(get_cost_shorthand_parts(mana_override, force_show_mana))

# Creature stats
@export var strength: int = 0
@export var resilience: int = 0
@export var creature_mode: CreatureMode = CreatureMode.DEFENSIVE:
	set(value):
		if _creature_mode == value:
			return
		_creature_mode = value
		_emit_visual_state_changed()
	get:
		return _creature_mode

# Equipment modifiers
@export var strength_modifier: int = 0
@export var resilience_modifier: int = 0
@export var speed_modifier: int = 0

# Card state - Changed "owner" to "card_owner" to avoid Godot reserved word
var card_owner: Player
var current_zone: Zone
var is_prepared: bool = false
# Tracks the last board position so Circle of Rebirth can auto-resurrect.
var last_board_zone_type: int = -1   # Zone.ZoneType value; -1 = never placed
var last_board_zone_index: int = int(Player.BOARD_LANE_COUNT / 2.0)   # default centre column
var is_face_down: bool = false
var is_stealth: bool = false
var has_acted_this_turn: bool = false
var has_moved_this_turn: bool = false
var has_attacked_this_turn: bool = false
var creature_major_action_used: bool = false
var creature_minor_actions_used: int = 0
var creature_shift_used_this_turn: bool = false
var is_sleeping: bool = false
var sleeping_from: Card = null
var equipped_on: Card = null
var equipment: Array[Card] = []
var summoned_this_turn: bool = false
var summoned_after_first_attack_this_turn: bool = false
var board_entry_order: int = -1
var is_used: bool = false          # for single-use activatable abilities on powers
var incorporeal: bool = false      # Incorporeal keyword: restricted engagement rules
var is_muted: bool = false
var mute_turns_remaining: int = 0
var _mute_applied_owner_turn_number: int = -1

# Runtime stat buffs: Array of {source: String, str: int, res: int, spd: int, lvl: int}
var active_buffs: Array[Dictionary] = []
var active_statuses: Array[Dictionary] = []
var _was_muted_last_check: bool = false
var _pending_chosen_discards: Array[Card] = []
var _pending_chosen_sacrifices: Array[Card] = []
var _pending_action_point_spend_visual_kinds: Array[String] = []
var _creature_mode: CreatureMode = CreatureMode.DEFENSIVE
var _board_leave_hooks_processed: bool = false

const EXTERNAL_EFFECT_NEGATION_STATUS := "external_effect_negation"
const ABILITY_NEGATED_STATUS := "ability_negated"
const COST_KIND_POWER_UNLOCK := "power_unlock"
const COST_KIND_POWER_ACTIVATION := "power_activation"
const COST_KIND_CREATURE_SUMMON := "creature_summon"
const COST_KIND_HAND_PLAY := "hand_play"
const ACTION_COST_NONE := ""
const ACTION_COST_MINOR := "minor"
const ACTION_COST_MAJOR := "major"
const DEFAULT_MINOR_CREATURE_ACTIONS_PER_TURN := 1
const MINOR_ACTION_SYMBOL_PATH := "res://images/ui/MinorActionSymbol.png"
const MAJOR_ACTION_SYMBOL_PATH := "res://images/ui/MajorActionSymbol.png"

func get_controller() -> Player:
	if current_zone != null and current_zone.is_board_zone() and current_zone.zone_owner != null:
		return current_zone.zone_owner
	return card_owner

func get_normalized_card_name() -> String:
	return card_name

func get_ascii_card_name() -> String:
	var normalized := get_normalized_card_name()
	var fallback := ""
	for i in normalized.length():
		var codepoint := normalized.unicode_at(i)
		if codepoint >= 32 and codepoint <= 126:
			fallback += normalized[i]
		else:
			fallback += _get_ascii_fallback_for_codepoint(codepoint)
	return fallback

func _get_ascii_fallback_for_codepoint(codepoint: int) -> String:
	match codepoint:
		192, 193, 194, 195, 196, 197:
			return "A"
		198:
			return "Ae"
		199:
			return "C"
		200, 201, 202, 203:
			return "E"
		204, 205, 206, 207:
			return "I"
		208:
			return "D"
		209:
			return "N"
		210, 211, 212, 213, 214, 216:
			return "O"
		217, 218, 219, 220:
			return "U"
		221:
			return "Y"
		222:
			return "Th"
		223:
			return "ss"
		224, 225, 226, 227, 228, 229:
			return "a"
		230:
			return "ae"
		231:
			return "c"
		232, 233, 234, 235:
			return "e"
		236, 237, 238, 239:
			return "i"
		240:
			return "d"
		241:
			return "n"
		242, 243, 244, 245, 246, 248:
			return "o"
		249, 250, 251, 252:
			return "u"
		253, 255:
			return "y"
		254:
			return "th"
		338:
			return "Oe"
		339:
			return "oe"
		352:
			return "S"
		353:
			return "s"
		381:
			return "Z"
		382:
			return "z"
		321:
			return "L"
		322:
			return "l"
		_:
			return "?"

func get_display_name(prefer_ascii: bool = false, font: Font = null) -> String:
	var normalized := get_normalized_card_name()
	if prefer_ascii:
		return get_ascii_card_name()
	if font != null:
		for i in normalized.length():
			if not font.has_char(normalized.unicode_at(i)):
				return get_ascii_card_name()
	return normalized

func get_display_name_for_control(control: Control = null, prefer_ascii: bool = false) -> String:
	if control == null:
		return get_display_name(prefer_ascii)
	return get_display_name(prefer_ascii, control.get_theme_font("font"))

func is_hidden_from_viewer(viewer: Player = null) -> bool:
	if viewer == null:
		return false
	var owner_game_manager := card_owner.game_manager if card_owner != null else null
	if owner_game_manager != null and is_magical_card() and owner_game_manager._has_pending_stack_action_for_card(self):
		return false
	var controller := get_controller()
	var publicly_revealed_power := self is PowerCard and (self as PowerCard).is_publicly_revealed
	var hidden_face_down := (is_face_down or is_prepared) and not publicly_revealed_power
	return (is_stealth or hidden_face_down) \
		and controller != null \
		and controller != viewer \
		and not is_revealed_to_all()

func get_log_display_name(
	viewer: Player = null,
	hidden_fallback: String = "Hidden card",
	prefer_ascii: bool = false,
	font: Font = null
) -> String:
	if is_hidden_from_viewer(viewer):
		return hidden_fallback
	return get_display_name(prefer_ascii, font)

func get_hidden_log_position_label() -> String:
	var zone := current_zone
	if zone == null:
		return "a hidden card"
	var controller := get_controller()
	if controller == null:
		controller = card_owner
	var owner_prefix := controller.player_name + "'s " if controller != null and controller.player_name != "" else ""
	match zone.zone_type:
		Zone.ZoneType.FRONTLINE:
			return owner_prefix + "Front Line position " + str(zone.zone_index + 1)
		Zone.ZoneType.RESERVE:
			return owner_prefix + "Reserve Line position " + str(zone.zone_index + 1)
		Zone.ZoneType.POWER_SLOT:
			return owner_prefix + "Power slot " + str(zone.zone_index + 1)
		Zone.ZoneType.GOD_SLOT:
			return owner_prefix + "God slot"
	return owner_prefix + "position " + str(zone.zone_index + 1)

func get_target_log_display_name(viewer: Player = null) -> String:
	if current_zone != null and current_zone.zone_type in [Zone.ZoneType.GRAVEYARD, Zone.ZoneType.ABYSS]:
		return get_display_name()
	if is_hidden_from_viewer(viewer):
		return get_hidden_log_position_label()
	return get_display_name()

func is_enslaved() -> bool:
	var controller := get_controller()
	return controller != null and card_owner != null and controller != card_owner

func has_status_effect(status_name: String) -> bool:
	for status in _get_effective_statuses():
		if status.get("name", "") == status_name:
			return true
	return false

func is_shapeshift_locked() -> bool:
	return has_status_effect("tonal_extraction_no_shift")

func get_status_effect(status_name: String) -> Dictionary:
	for status in _get_effective_statuses():
		if status.get("name", "") == status_name:
			return status
	return {}

func is_petrified() -> bool:
	return has_status_effect("petrified")

func is_temporarily_revealed() -> bool:
	return has_status_effect("temporarily_revealed")

func is_revealed_to_all() -> bool:
	return is_temporarily_revealed() or has_status_effect("publicly_revealed")

func is_revealed_in_hand() -> bool:
	return has_status_effect("revealed_in_hand")

func temporarily_reveal_until_end_of_turn(
	current_turn: int,
	source: String,
	source_card: Card = null,
	source_owner: Player = null,
	game_manager: GameManager = null
) -> void:
	var was_visible: bool = is_temporarily_revealed()
	if self is PowerCard and (self as PowerCard).is_publicly_revealed:
		was_visible = true
	var was_hidden: bool = (is_face_down or is_stealth) and not was_visible
	remove_status_effects_by_name("temporarily_revealed")
	add_status_effect(
		"temporarily_revealed",
		source,
		source_card,
		source_owner,
		{"expires_turn": current_turn}
	)
	if was_hidden and game_manager != null:
		on_reveal(game_manager)
		if source_card != null and game_manager.has_method("notify_card_revealed_by_effect"):
			game_manager.notify_card_revealed_by_effect(self, source_card)

func is_activation_locked(game_manager: GameManager = null) -> bool:
	if not has_status_effect("activation_locked"):
		return false
	if game_manager == null:
		return true
	for status in _get_effective_statuses():
		if status.get("name", "") != "activation_locked":
			continue
		var expires_turn = status.get("expires_turn", null)
		if expires_turn == null:
			return true
		return int(expires_turn) >= game_manager.turn_number
	return false

func lock_activation_until_end_of_turn(
	current_turn: int,
	source: String,
	source_card: Card = null,
	source_owner: Player = null
) -> void:
	remove_status_effects_by_name("activation_locked")
	add_status_effect(
		"activation_locked",
		source,
		source_card,
		source_owner,
		{"expires_turn": current_turn}
	)

func is_silenced() -> bool:
	return is_muted and mute_turns_remaining < 0

func abilities_suppressed() -> bool:
	return is_enslaved() \
		or is_petrified() \
		or is_muted \
		or has_status_effect(ABILITY_NEGATED_STATUS) \
		or _abilities_disabled_by_hidden_state()

func post_field_abilities_suppressed() -> bool:
	# Silence and generic ability negation only apply while the card remains in play.
	# Use this gate for hooks that fire as the card leaves the field or from the graveyard.
	return is_enslaved() \
		or is_petrified() \
		or _abilities_disabled_by_hidden_state()

func process_board_leave_hooks(game_manager: GameManager = null) -> void:
	if _board_leave_hooks_processed:
		return
	_board_leave_hooks_processed = true
	if has_method("on_removed") and not post_field_abilities_suppressed():
		call("on_removed", game_manager)

func reset_board_leave_hooks() -> void:
	_board_leave_hooks_processed = false

func _abilities_disabled_by_hidden_state() -> bool:
	return card_type == CardType.CREATURE and is_stealth

func get_controller_passive_cards() -> Array[Card]:
	var passive_cards: Array[Card] = []
	var seen_cards: Dictionary = {}
	var controller := get_controller()
	if controller == null:
		return passive_cards

	for zone in controller.frontline_zones + controller.reserve_zones + controller.power_zones:
		for zone_card in zone.cards:
			_append_unique_passive_card(passive_cards, seen_cards, zone_card)
			if zone_card == null or not zone_card.has_method("get_sheltered_cards_for_passive_effects"):
				continue
			for sheltered_card in zone_card.get_sheltered_cards_for_passive_effects():
				_append_unique_passive_card(passive_cards, seen_cards, sheltered_card)
	return passive_cards

func _append_unique_passive_card(passive_cards: Array[Card], seen_cards: Dictionary, candidate: Card) -> void:
	if candidate == null:
		return
	if candidate.card_type == CardType.CREATURE and candidate.is_stealth:
		return
	var candidate_id := candidate.get_instance_id()
	if seen_cards.has(candidate_id):
		return
	seen_cards[candidate_id] = true
	passive_cards.append(candidate)

func is_creature_card() -> bool:
	return card_type == CardType.CREATURE

func get_effective_speed() -> int:
	var base_speed = speed
	var speed_override: Variant = null
	var equipment_speed_bonus := 0
	if is_stealth:
		base_speed -= 1
	for equip in equipment:
		equipment_speed_bonus += equip.speed_modifier
		if equip != null and equip.has_method("get_speed_override_for_equipped_creature"):
			var override_candidate = equip.get_speed_override_for_equipped_creature(self)
			if override_candidate != null:
				speed_override = int(override_candidate)
	if speed_override != null:
		base_speed = int(speed_override)
	base_speed += equipment_speed_bonus
	for buff in _get_effective_buffs():
		base_speed += buff.get("spd", 0)
	return clampi(base_speed, 1, 7)

func get_effective_level() -> int:
	var total := level
	for buff in _get_effective_buffs():
		total += buff.get("lvl", 0)
	return max(1, total)

func get_effective_strength() -> int:
	var total = strength
	for equip in equipment:
		total += equip.strength_modifier
	for buff in _get_effective_buffs():
		total += buff.get("str", 0)
	return max(0, total)

func get_effective_resilience() -> int:
	var total = resilience
	for equip in equipment:
		total += equip.resilience_modifier
	for buff in _get_effective_buffs():
		total += buff.get("res", 0)
	return max(0, total)

# Returns a human-readable breakdown of all active buffs for a stat ("str", "res", "spd", "lvl")
func get_buff_tooltip(stat: String) -> String:
	var lines: Array[String] = []
	for buff in _get_effective_buffs():
		var v: int = buff.get(stat, 0)
		if v != 0:
			lines.append(("+%d" % v if v > 0 else "%d" % v) + " from " + buff.get("source", "?"))
	return "\n".join(lines)

# Returns a full breakdown including equipment modifiers and buffs, e.g. "21 +5 Bearded Axe"
# Returns empty string if no modifiers are active.
func get_full_stat_breakdown(stat: String) -> String:
	var base: int
	match stat:
		"str": base = strength
		"res": base = resilience
		"spd": base = speed
		"lvl": base = level
		_: return ""
	var lines: Array[String] = []
	for equip in equipment:
		var v: int
		match stat:
			"str": v = equip.strength_modifier
			"res": v = equip.resilience_modifier
			"spd": v = equip.speed_modifier
			_: v = 0
		if v != 0:
			lines.append(("+%d" % v if v > 0 else "%d" % v) + " " + equip.card_name)
	for buff in _get_effective_buffs():
		var v: int = buff.get(stat, 0)
		if v != 0:
			lines.append(("+%d" % v if v > 0 else "%d" % v) + " from " + buff.get("source", "?"))
	if lines.is_empty():
		return ""
	return str(base) + " " + " ".join(lines)

func get_effect_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for buff in _get_effective_buffs():
		var parts: Array[String] = []
		var str_change: int = buff.get("str", 0)
		var res_change: int = buff.get("res", 0)
		var spd_change: int = buff.get("spd", 0)
		var lvl_change: int = buff.get("lvl", 0)
		if str_change != 0:
			parts.append(("STR %+d" % str_change))
		if res_change != 0:
			parts.append(("RES %+d" % res_change))
		if spd_change != 0:
			parts.append(("SPD %+d" % spd_change))
		if lvl_change != 0:
			parts.append(("LVL %+d" % lvl_change))
		if parts.size() == 0:
			continue
		lines.append(", ".join(parts) + " from " + str(buff.get("source", "?")))

	for status in _get_effective_statuses():
		var raw_status_name := str(status.get("name", "Status"))
		if raw_status_name == "blessed_ward":
			var ward_kind := str(status.get("ward_kind", "")).replace("_", " ")
			lines.append("Blessed Ward vs " + ward_kind.capitalize() + " from " + str(status.get("source", "?")))
			continue
		if raw_status_name == "cannot_attack":
			lines.append("Cannot attack from " + str(status.get("source", "?")))
			continue
		if raw_status_name == "temporarily_revealed":
			lines.append("Revealed until end of turn by " + str(status.get("source", "?")))
			continue
		if raw_status_name == "publicly_revealed":
			lines.append("Publicly revealed by " + str(status.get("source", "?")))
			continue
		if raw_status_name == "revealed_in_hand":
			lines.append("Revealed while in hand by " + str(status.get("source", "?")))
			continue
		if raw_status_name == "activation_locked":
			lines.append("Cannot activate this turn from " + str(status.get("source", "?")))
			continue
		if raw_status_name == ABILITY_NEGATED_STATUS:
			lines.append("Abilities negated from " + str(status.get("source", "?")))
			continue
		var status_name := raw_status_name.capitalize()
		lines.append(status_name + " from " + str(status.get("source", "?")))

	return lines

func get_equipment_modifier_summary_parts() -> Array[String]:
	var parts: Array[String] = []
	if strength_modifier != 0:
		parts.append("STR %+d" % strength_modifier)
	if resilience_modifier != 0:
		parts.append("RES %+d" % resilience_modifier)
	if speed_modifier != 0:
		parts.append("SPD %+d" % speed_modifier)
	return parts

func get_equipment_summary_label() -> String:
	var parts := get_equipment_modifier_summary_parts()
	if parts.is_empty():
		return card_name
	return "%s (%s)" % [card_name, ", ".join(parts)]

func get_inline_ability_summary() -> String:
	var summary := ability_text.strip_edges().replace("\n", " ")
	while summary.contains("  "):
		summary = summary.replace("  ", " ")
	return summary

func get_adjusted_mana_cost(
	base_cost: int,
	cost_kind: String,
	game_manager: GameManager = null,
	metadata: Dictionary = {}
) -> int:
	if game_manager == null:
		return maxi(0, base_cost)
	return maxi(0, base_cost + game_manager.get_total_cost_adjustment(self, base_cost, cost_kind, metadata))

func get_cost_adjustment_lines(
	base_cost: int,
	cost_kind: String,
	game_manager: GameManager = null,
	metadata: Dictionary = {}
) -> Array[String]:
	var lines: Array[String] = []
	if game_manager == null:
		return lines
	for entry in game_manager.get_cost_adjustment_entries(self, base_cost, cost_kind, metadata):
		var delta := int(entry.get("delta", 0))
		if delta == 0:
			continue
		lines.append(("%+d" % delta) + " from " + str(entry.get("source", "?")))
	return lines

func get_cost_adjustment_entries(
	_target_card: Card,
	_base_cost: int,
	_cost_kind: String,
	_game_manager: GameManager,
	_metadata: Dictionary = {}
) -> Array[Dictionary]:
	return []

func claim_cost_adjustment(
	_target_card: Card,
	_base_cost: int,
	_cost_kind: String,
	_game_manager: GameManager,
	_metadata: Dictionary = {}
) -> bool:
	return false

func get_hover_detail_lines(_viewer: Player = null) -> Array[String]:
	return []

func get_hover_stored_cards(_viewer: Player = null) -> Array[Card]:
	return []

func get_hover_stored_cards_title(_viewer: Player = null) -> String:
	return "Cards under this card"

func get_hover_stored_cards_total_level(_viewer: Player = null) -> int:
	var total := 0
	for stored_card in get_hover_stored_cards(_viewer):
		if stored_card != null:
			total += stored_card.get_effective_level()
	return total

func get_equipment_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for equip in equipment:
		if equip == null:
			continue
		var line := equip.get_equipment_summary_label()
		var effect_lines := equip.get_effect_summary_lines()
		if effect_lines.is_empty():
			var ability_summary := equip.get_inline_ability_summary()
			if ability_summary != "":
				effect_lines.append(ability_summary)
		if effect_lines.is_empty():
			lines.append(line)
		else:
			lines.append(line + ": " + " | ".join(effect_lines))
	return lines

func clear_buffs_from(source: String) -> void:
	var previous_buff_count := active_buffs.size()
	active_buffs = active_buffs.filter(func(b):
		return b.get("source", "") != source
	)
	if active_buffs.size() != previous_buff_count:
		_emit_visual_state_changed()

func remove_buffs_from_source_card(source_card: Card, effect_type: String = "") -> void:
	var previous_buff_count := active_buffs.size()
	active_buffs = active_buffs.filter(func(b):
		var same_source: bool = b.get("source_card", null) == source_card
		var same_effect_type: bool = effect_type == "" or b.get("effect_type", "") == effect_type
		return not (same_source and same_effect_type)
	)
	if active_buffs.size() != previous_buff_count:
		_emit_visual_state_changed()

func add_buff(
	source: String,
	str_bonus: int,
	res_bonus: int,
	spd_bonus: int,
	source_card: Card = null,
	source_owner: Player = null,
	effect_type: String = "buff",
	extra_metadata: Dictionary = {}
) -> void:
	var buff := {
		"source": source,
		"str": str_bonus,
		"res": res_bonus,
		"spd": spd_bonus,
		"source_card": source_card,
		"source_owner": source_owner,
		"effect_type": effect_type,
	}
	for key in extra_metadata.keys():
		buff[key] = extra_metadata[key]
	active_buffs.append(buff)
	_emit_visual_state_changed()

func add_status_effect(
	status_name: String,
	source: String,
	source_card: Card = null,
	source_owner: Player = null,
	extra_metadata: Dictionary = {}
) -> void:
	var status := {
		"name": status_name,
		"source": source,
		"source_card": source_card,
		"source_owner": source_owner,
	}
	for key in extra_metadata.keys():
		status[key] = extra_metadata[key]
	active_statuses.append(status)
	_sync_status_flags()
	_emit_visual_state_changed()

func remove_status_effects_by_name(status_name: String) -> void:
	var previous_status_count := active_statuses.size()
	active_statuses = active_statuses.filter(func(s):
		return s.get("name", "") != status_name
	)
	_sync_status_flags()
	if active_statuses.size() != previous_status_count:
		_emit_visual_state_changed()

func remove_status_effects_from_source_card(source_card: Card, status_name: String = "") -> void:
	var previous_status_count := active_statuses.size()
	active_statuses = active_statuses.filter(func(s):
		var same_source: bool = s.get("source_card", null) == source_card
		var same_status: bool = status_name == "" or s.get("name", "") == status_name
		return not (same_source and same_status)
	)
	_sync_status_flags()
	if active_statuses.size() != previous_status_count:
		_emit_visual_state_changed()

func remove_expired_buffs(current_turn: int) -> void:
	var previous_buff_count := active_buffs.size()
	active_buffs = active_buffs.filter(func(b):
		var expires_turn = b.get("expires_turn", null)
		return expires_turn == null or int(expires_turn) > current_turn
	)
	if active_buffs.size() != previous_buff_count:
		_emit_visual_state_changed()

func remove_expired_statuses(current_turn: int) -> void:
	var previous_status_count := active_statuses.size()
	active_statuses = active_statuses.filter(func(s):
		var expires_turn = s.get("expires_turn", null)
		return expires_turn == null or int(expires_turn) > current_turn
	)
	_sync_status_flags()
	if active_statuses.size() != previous_status_count:
		_emit_visual_state_changed()

func remove_effects_expiring_after_combat() -> void:
	var previous_buff_count := active_buffs.size()
	var previous_status_count := active_statuses.size()
	active_buffs = active_buffs.filter(func(b):
		return b.get("expires_after_combat", false) != true
	)
	active_statuses = active_statuses.filter(func(s):
		return s.get("expires_after_combat", false) != true
	)
	_sync_status_flags()
	if active_buffs.size() != previous_buff_count or active_statuses.size() != previous_status_count:
		_emit_visual_state_changed()

func has_effects_from_player(player: Player) -> bool:
	for buff in active_buffs:
		if buff.get("source_owner", null) == player:
			return true
	for status in active_statuses:
		if status.get("source_owner", null) == player:
			return true
	return false

func remove_effects_from_player(player: Player) -> void:
	var previous_buff_count := active_buffs.size()
	var previous_status_count := active_statuses.size()
	active_buffs = active_buffs.filter(func(b):
		return b.get("source_owner", null) != player
	)
	active_statuses = active_statuses.filter(func(s):
		return s.get("source_owner", null) != player
	)
	_sync_status_flags()
	if active_buffs.size() != previous_buff_count or active_statuses.size() != previous_status_count:
		_emit_visual_state_changed()

func apply_sleep(source_card: Card) -> void:
	if card_type == CardType.CREATURE and current_zone != null and current_zone.is_board_zone():
		creature_mode = CreatureMode.DEFENSIVE
	remove_status_effects_by_name("sleep")
	add_status_effect("sleep", source_card.card_name if source_card != null else "Sleep", source_card, source_card.card_owner if source_card != null else null)

func wake_up() -> void:
	remove_status_effects_by_name("sleep")

func clear_all_effects() -> void:
	var had_changes := not active_buffs.is_empty() or not active_statuses.is_empty()
	active_buffs.clear()
	active_statuses.clear()
	_sync_status_flags()
	if had_changes:
		_emit_visual_state_changed()

func clear_board_leave_state() -> void:
	clear_all_effects()

func _sync_status_flags() -> void:
	var sleep_status: Dictionary = {}
	for status in _get_effective_statuses():
		if status.get("name", "") == "sleep":
			sleep_status = status
			break
	is_sleeping = not sleep_status.is_empty()
	sleeping_from = sleep_status.get("source_card", null) if is_sleeping else null

func can_respond_to(other_card: Card) -> bool:
	return get_effective_speed() >= 2 and get_effective_speed() >= other_card.get_effective_speed()

func is_permanent() -> bool:
	return has_type("Permanent") or card_type in [CardType.CREATURE, CardType.EQUIPMENT, CardType.STRUCTURE, CardType.POWER, CardType.GOD]

func goes_to_graveyard_after_use() -> bool:
	return not is_permanent() and card_type in [CardType.SPELL, CardType.HEX, CardType.CHARM]

func get_ability_immunity_tag() -> String:
	if ability_immunity_tag != "":
		return ability_immunity_tag
	if is_god:
		return "powers"
	match card_type:
		CardType.CREATURE:
			return "creature_abilities"
		CardType.SPELL:
			return "spells"
		CardType.POWER:
			return "powers"
		CardType.HEX:
			return "hexes"
	return ""

func can_be_negated(_action: CardAction = null) -> bool:
	return true

func negates_external_effects() -> bool:
	for status in active_statuses:
		if status.get("name", "") == EXTERNAL_EFFECT_NEGATION_STATUS:
			return true
	return false

func _get_effective_buffs() -> Array[Dictionary]:
	if not negates_external_effects():
		return active_buffs
	var filtered: Array[Dictionary] = []
	for buff in active_buffs:
		if not _is_external_effect_entry(buff):
			filtered.append(buff)
	return filtered

func _get_effective_statuses() -> Array[Dictionary]:
	if not negates_external_effects():
		var direct_statuses: Array[Dictionary] = []
		for status in active_statuses:
			if _is_blocked_by_source_immunity(status):
				continue
			direct_statuses.append(status)
		return direct_statuses
	var filtered: Array[Dictionary] = []
	for status in active_statuses:
		if _is_external_effect_entry(status):
			continue
		if _is_blocked_by_source_immunity(status):
			continue
		filtered.append(status)
	return filtered

func _is_external_effect_entry(entry: Dictionary) -> bool:
	if entry.get("allow_while_negated", false) == true:
		return false
	return entry.get("source_card", null) != self

func _is_blocked_by_source_immunity(entry: Dictionary) -> bool:
	if entry.get("blocked_by_source_immunity", false) != true:
		return false
	var source_card := entry.get("source_card", null) as Card
	if source_card == null:
		return false
	var immunity_kind := source_card.get_ability_immunity_tag() if source_card.has_method("get_ability_immunity_tag") else ""
	if immunity_kind == "":
		return false
	for status in active_statuses:
		if status.get("name", "") != "blessed_ward":
			continue
		if negates_external_effects() and _is_external_effect_entry(status):
			continue
		if status.get("ward_kind", "") == immunity_kind:
			return true
	if immunity_kind != "hexes":
		return false
	return _has_raw_enki_hex_immunity()

func _has_raw_enki_hex_immunity() -> bool:
	if not is_creature_card():
		return false
	# This is called while filtering effective statuses. Using has_type() here
	# re-enters status filtering and can recurse when a hex status is added.
	if "Mage" not in card_types:
		return false
	var controller := get_controller()
	if controller == null:
		return false
	for passive_card in get_controller_passive_cards():
		if not (passive_card is EnkiLordOfEridu):
			continue
		var enki := passive_card as EnkiLordOfEridu
		if enki == null:
			continue
		if enki.get_controller() != controller:
			continue
		if enki.hex_protection_is_suppressed_raw():
			continue
		return true
	return false

func mute_for_turns(turns: int, game_manager: GameManager = null) -> void:
	var was_muted := is_muted
	is_muted = turns > 0
	mute_turns_remaining = max(0, turns)
	_mute_applied_owner_turn_number = -1
	if game_manager != null and game_manager.current_player == card_owner:
		_mute_applied_owner_turn_number = game_manager.turn_number
	_process_mute_state_change(game_manager, was_muted)

func mute_permanently(game_manager: GameManager = null) -> void:
	var was_muted := is_muted
	is_muted = true
	mute_turns_remaining = -1
	_mute_applied_owner_turn_number = -1
	_process_mute_state_change(game_manager, was_muted)

func on_turn_end(game_manager: GameManager) -> void:
	var was_muted := is_muted
	if not is_muted:
		return
	if mute_turns_remaining < 0:
		return
	if game_manager != null and game_manager.current_player == card_owner and game_manager.turn_number == _mute_applied_owner_turn_number:
		return
	if mute_turns_remaining > 0:
		mute_turns_remaining -= 1
	if mute_turns_remaining <= 0:
		is_muted = false
		mute_turns_remaining = 0
		_mute_applied_owner_turn_number = -1
	_process_mute_state_change(game_manager, was_muted)

# Called for all board/god/power permanents whenever any player's turn begins.
# Use this for effects keyed to "a turn started", not specifically "your turn started".
func on_global_turn_start(_game_manager: GameManager, _starting_player: Player) -> void:
	pass

# Called for all board/god/power permanents whenever any player's turn ends.
# Use this for effects keyed to "end of turn" regardless of controller.
func on_global_turn_end(_game_manager: GameManager, _ending_player: Player) -> void:
	pass

func _process_mute_state_change(game_manager: GameManager, was_muted: bool) -> void:
	if was_muted == is_muted:
		return
	_was_muted_last_check = is_muted
	if is_muted:
		on_muted(game_manager)
	else:
		on_unmuted(game_manager)

func on_muted(_game_manager: GameManager) -> void:
	pass

func on_unmuted(_game_manager: GameManager) -> void:
	pass

func on_reveal(_game_manager: GameManager) -> void:
	pass

func reveal(game_manager: GameManager = null) -> void:
	var was_hidden: bool = is_face_down or is_stealth
	is_face_down = false
	is_stealth = false
	remove_status_effects_with_flag("clear_when_hidden_state_ends")
	# Reveal triggers whenever a card becomes visible from a hidden state,
	# even if that same card was revealed earlier and later became hidden again.
	if was_hidden and game_manager != null and not abilities_suppressed():
		on_reveal(game_manager)

func has_type(type_name: String) -> bool:
	if type_name == "Physical":
		return is_physical_card()
	if type_name == "Magic" or type_name == "Magical":
		return is_magical_card()
	if _has_suppressed_type(type_name):
		return false
	if _has_granted_type(type_name):
		return true
	if type_name in card_types:
		return true
	for equip in equipment:
		if equip == null:
			continue
		if not equip.has_method("grants_type_to_equipped_creature"):
			continue
		if equip.grants_type_to_equipped_creature(self, type_name):
			return true
	return false

func _has_suppressed_type(type_name: String) -> bool:
	for status in _get_effective_statuses():
		var suppressed_types = status.get("suppressed_types", [])
		if suppressed_types is Array and type_name in suppressed_types:
			return true
	return false

func _has_granted_type(type_name: String) -> bool:
	for status in _get_effective_statuses():
		var granted_types = status.get("granted_types", [])
		if granted_types is Array and type_name in granted_types:
			return true
	return false

func remove_status_effects_with_flag(flag_name: String) -> void:
	var previous_status_count := active_statuses.size()
	active_statuses = active_statuses.filter(func(s):
		return s.get(flag_name, false) != true
	)
	_sync_status_flags()
	if active_statuses.size() != previous_status_count:
		_emit_visual_state_changed()

func get_intercept_reach_bonus(
	_game_manager: GameManager = null,
	_attacker: Card = null,
	_protected_target = null
) -> int:
	if card_type != CardType.CREATURE or ability_text == "":
		return 0
	var normalized := " " + ability_text.to_lower() + " "
	for token in ["[b]", "[/b]", "\n", "\t", ",", ".", ":", ";", "!", "?", "(", ")", "[", "]"]:
		normalized = normalized.replace(token, " ")
	if normalized.contains(" reach +1 "):
		return 1
	if normalized.contains(" reach "):
		return 1
	return 0

func get_intercept_speed_bonus_against_attacker(
	_game_manager: GameManager,
	_attacker: Card,
	_protected_target = null
) -> int:
	return 0

func can_special_intercept(_game_manager: GameManager, _attacker: Card, _protected_target) -> bool:
	return false

func halves_follower_damage_inflicted() -> bool:
	return false

func get_tonal_extraction_spirit_profile() -> Dictionary:
	return {}

func get_serialized_state() -> Dictionary:
	return {}

func apply_serialized_state(_state: Dictionary) -> void:
	pass

func is_physical_card() -> bool:
	return card_type in [CardType.CREATURE, CardType.STRUCTURE, CardType.EQUIPMENT]

func is_magical_card() -> bool:
	return card_type in [CardType.SPELL, CardType.HEX, CardType.CHARM]

func can_receive_equipment() -> bool:
	return is_creature_card() \
		and not is_face_down \
		and not is_stealth

func on_equip(_creature: Card) -> void:
	pass

func can_equip_to(creature: Card) -> bool:
	return creature != null and creature.can_receive_equipment()

func get_cannot_equip_reason(creature: Card) -> String:
	if creature == null:
		return "No bearer was selected."
	if not creature.can_receive_equipment():
		if creature.is_face_down or creature.is_stealth:
			return creature.card_name + " is hidden and cannot carry equipment."
		return creature.card_name + " cannot carry equipment right now."
	return card_name + " can't be equipped to " + creature.card_name + "."

func equip_to(creature: Card) -> bool:
	if card_type != CardType.EQUIPMENT or not can_equip_to(creature):
		return false
	
	if equipped_on:
		equipped_on.equipment.erase(self)
		equipped_on._emit_visual_state_changed()
	
	equipped_on = creature
	creature.equipment.append(self)
	on_equip(creature)
	if creature.has_method("on_equip"):
		creature.on_equip(self)
	_emit_visual_state_changed()
	creature._emit_visual_state_changed()
	return true

func unequip() -> void:
	if equipped_on:
		var previous_bearer := equipped_on
		equipped_on.equipment.erase(self)
		equipped_on = null
		_emit_visual_state_changed()
		previous_bearer._emit_visual_state_changed()

# Incorporeal keyword — shared engagement logic.
# Returns false when this card is incorporeal and `source` is not a permitted engager.
func can_be_engaged_by(source: Card) -> bool:
	if _has_equipped_evasive():
		if source == null or not source.is_creature_card():
			return false
		if not (source.has_type("Aerial") or source.has_type("Archer")):
			return false
	if not incorporeal:
		return true
	if source == null or not source.is_creature_card():
		return false
	if source.has_type("Spirit"):
		return true
	return source.has_type("Mage") and source.get_effective_speed() > get_effective_speed()

# Returns false when this card is incorporeal and `target` is not a permitted engage target.
func can_engage(target: Card) -> bool:
	if not incorporeal:
		return true
	if target == null or not target.is_creature_card():
		return false
	if target.has_type("Spirit"):
		return true
	return target.has_type("Mage") and target.get_effective_speed() < get_effective_speed()

func can_ignore_attack_targeting_restrictions(target: Card = null) -> bool:
	for equip in equipment:
		if equip == null:
			continue
		if not equip.has_method("grants_attack_targeting_override_to_equipped_creature"):
			continue
		if equip.grants_attack_targeting_override_to_equipped_creature(self, target):
			return true
	return false

func can_destroy_combat_protected_creatures(target: Card = null) -> bool:
	for equip in equipment:
		if equip == null:
			continue
		if not equip.has_method("grants_battle_destroy_override_to_equipped_creature"):
			continue
		if equip.grants_battle_destroy_override_to_equipped_creature(self, target):
			return true
	return false

func reveal_from_stealth(game_manager: GameManager = null) -> void:
	if is_stealth:
		reveal(game_manager)

func _has_equipped_evasive() -> bool:
	for equip in equipment:
		if equip == null:
			continue
		if not equip.has_method("grants_evasive_to_equipped_creature"):
			continue
		if equip.grants_evasive_to_equipped_creature(self):
			return true
	return false

func reset_creature_action_state() -> void:
	var action_state_changed := has_acted_this_turn \
		or has_moved_this_turn \
		or has_attacked_this_turn \
		or creature_major_action_used \
		or creature_minor_actions_used != 0 \
		or creature_shift_used_this_turn
	has_acted_this_turn = false
	has_moved_this_turn = false
	has_attacked_this_turn = false
	creature_major_action_used = false
	creature_minor_actions_used = 0
	creature_shift_used_this_turn = false
	if action_state_changed:
		_emit_visual_state_changed()

func get_max_minor_creature_actions_per_turn() -> int:
	return DEFAULT_MINOR_CREATURE_ACTIONS_PER_TURN

func get_max_minor_creature_actions_before_major() -> int:
	return get_max_minor_creature_actions_per_turn()

func can_take_minor_creature_action_after_major() -> bool:
	return false

func can_take_major_creature_action() -> bool:
	return not creature_major_action_used

func does_attack_exhaust_minor_creature_actions() -> bool:
	return false

func can_take_minor_creature_action() -> bool:
	return can_take_minor_creature_action_spending_minor() or can_take_minor_creature_action_spending_major()

func can_take_minor_creature_action_spending_minor() -> bool:
	if creature_major_action_used:
		var major_action_was_attack := has_attacked_this_turn and not does_attack_exhaust_minor_creature_actions()
		return (major_action_was_attack or can_take_minor_creature_action_after_major()) \
			and creature_minor_actions_used < get_max_minor_creature_actions_per_turn()
	return creature_minor_actions_used < get_max_minor_creature_actions_per_turn()

func can_take_minor_creature_action_spending_major() -> bool:
	return not creature_major_action_used and creature_minor_actions_used >= get_max_minor_creature_actions_per_turn()

func get_effective_minor_action_cost_kind() -> String:
	if can_take_minor_creature_action_spending_minor():
		return ACTION_COST_MINOR
	if can_take_minor_creature_action_spending_major():
		return ACTION_COST_MAJOR
	return ACTION_COST_MINOR

static func get_creature_summon_action_cost_kinds(stealth: bool = false) -> Array[String]:
	var kinds: Array[String] = [ACTION_COST_MINOR]
	if stealth:
		kinds.append(ACTION_COST_MAJOR)
	return kinds

func spend_major_creature_action() -> void:
	var old_major_used := creature_major_action_used
	var action_state_changed := not creature_major_action_used or not has_acted_this_turn
	creature_major_action_used = true
	has_acted_this_turn = true
	if not old_major_used and creature_major_action_used:
		_note_action_point_spend_visual(ACTION_COST_MAJOR)
	if action_state_changed:
		_emit_visual_state_changed()

func spend_attack_creature_action() -> void:
	var old_attacked := has_attacked_this_turn
	var old_minor_actions := creature_minor_actions_used
	spend_major_creature_action()
	has_attacked_this_turn = true
	if does_attack_exhaust_minor_creature_actions():
		creature_minor_actions_used = maxi(creature_minor_actions_used, get_max_minor_creature_actions_per_turn())
		for _i in range(maxi(0, creature_minor_actions_used - old_minor_actions)):
			_note_action_point_spend_visual(ACTION_COST_MINOR)
	if has_attacked_this_turn != old_attacked or creature_minor_actions_used != old_minor_actions:
		_emit_visual_state_changed()

func spend_minor_creature_action(marked_as_move: bool = false) -> void:
	var old_minor_actions := creature_minor_actions_used
	var old_major_used := creature_major_action_used
	var old_acted := has_acted_this_turn
	var old_moved := has_moved_this_turn
	if can_take_minor_creature_action_spending_minor():
		creature_minor_actions_used += 1
	elif can_take_minor_creature_action_spending_major():
		creature_major_action_used = true
		has_acted_this_turn = true
	if marked_as_move:
		has_moved_this_turn = true
	if creature_minor_actions_used >= get_max_minor_creature_actions_per_turn():
		has_acted_this_turn = true
	if creature_minor_actions_used > old_minor_actions:
		for _i in range(creature_minor_actions_used - old_minor_actions):
			_note_action_point_spend_visual(ACTION_COST_MINOR)
	if not old_major_used and creature_major_action_used:
		_note_action_point_spend_visual(ACTION_COST_MAJOR)
	if creature_minor_actions_used != old_minor_actions \
			or creature_major_action_used != old_major_used \
			or has_acted_this_turn != old_acted \
			or has_moved_this_turn != old_moved:
		_emit_visual_state_changed()

func spend_creature_summon_actions(stealth: bool = false) -> void:
	spend_minor_creature_action()
	if stealth:
		spend_major_creature_action()

func _note_action_point_spend_visual(action_cost_kind: String) -> void:
	if action_cost_kind == ACTION_COST_NONE:
		return
	_pending_action_point_spend_visual_kinds.append(action_cost_kind)

func peek_action_point_spend_visual_kinds() -> Array[String]:
	return _pending_action_point_spend_visual_kinds.duplicate()

func clear_action_point_spend_visual_kinds() -> void:
	_pending_action_point_spend_visual_kinds.clear()

static func get_action_symbol_path(action_cost_kind: String) -> String:
	match action_cost_kind:
		ACTION_COST_MINOR:
			return MINOR_ACTION_SYMBOL_PATH
		ACTION_COST_MAJOR:
			return MAJOR_ACTION_SYMBOL_PATH
	return ""

static func get_action_symbol_bbcode(action_cost_kind: String, size: int = 18) -> String:
	var path := get_action_symbol_path(action_cost_kind)
	if path == "":
		return ""
	return "[img=%dx%d]%s[/img] " % [size, size, path]

func can_use_shift_ability_this_turn() -> bool:
	return not creature_shift_used_this_turn

func spend_shift_ability_use() -> void:
	creature_shift_used_this_turn = true

func mark_attacked_this_turn() -> void:
	has_attacked_this_turn = true

func get_prepare_failure_reason(game_manager: GameManager, player: Player) -> String:
	if game_manager == null:
		return "No game manager is available."
	if player == null:
		return "No acting player was provided."
	if card_owner != null and card_owner != player:
		return "%s belongs to %s." % [card_name, card_owner.player_name]
	if player != game_manager.current_player:
		return "You can only prepare cards during your own turn."
	if player.hand_zone == null or current_zone != player.hand_zone:
		return "%s must be in your hand to be prepared." % card_name
	return ""

func can_prepare(game_manager: GameManager, player: Player) -> bool:
	return get_prepare_failure_reason(game_manager, player).is_empty()

func can_pay_costs(player: Player) -> bool:
	return can_pay_costs_with_mana_cost(player, mana_cost)

func can_pay_costs_with_mana_cost(player: Player, mana_required: int) -> bool:
	# Check if player can afford all costs
	if player.mana < mana_required:
		return false
	if player.hand_zone.get_card_count() < discard_cost:
		return false
	if player.hand_zone.get_card_count() < shelve_cost:
		return false
	
	# Count creatures on board for sacrifice costs, or validate chosen sacrifices.
	if sacrifice_cost > 0:
		if _pending_chosen_sacrifices.size() > 0 and _pending_chosen_sacrifices.size() < sacrifice_cost:
			return false
		if _pending_chosen_sacrifices.size() >= sacrifice_cost:
			var seen_sacrifice_uids := {}
			for i in range(sacrifice_cost):
				var chosen_sacrifice := _pending_chosen_sacrifices[i]
				if not _is_valid_pending_sacrifice_choice(chosen_sacrifice, player):
					return false
				if seen_sacrifice_uids.has(chosen_sacrifice.uid):
					return false
				seen_sacrifice_uids[chosen_sacrifice.uid] = true
		else:
			var creature_count = 0
			for zone in player.frontline_zones + player.reserve_zones:
				for card in zone.cards:
					if card.is_creature_card() and card.can_be_used_for_creature_sacrifice:
						creature_count += 1
			if creature_count < sacrifice_cost:
				return false
	
	# Check cards available to banish (hand + board)
	var banishable = player.hand_zone.get_card_count()
	for zone in player.frontline_zones + player.reserve_zones:
		banishable += zone.get_card_count()
	if banishable < banish_cost:
		return false
	
	return true

func requires_chosen_hand_discards() -> bool:
	return discard_cost > 0

func get_valid_play_discards(player: Player) -> Array[Card]:
	var choices: Array[Card] = []
	if player == null or player.hand_zone == null:
		return choices
	for card in player.hand_zone.cards:
		if card != null and card != self:
			choices.append(card)
	return choices

func set_pending_chosen_discards(cards: Array[Card]) -> void:
	_pending_chosen_discards = cards.duplicate()

func clear_pending_chosen_discards() -> void:
	_pending_chosen_discards.clear()

func set_pending_chosen_sacrifices(cards: Array[Card]) -> void:
	_pending_chosen_sacrifices = cards.duplicate()

func clear_pending_chosen_sacrifices() -> void:
	_pending_chosen_sacrifices.clear()

func _is_valid_pending_sacrifice_choice(card: Card, player: Player) -> bool:
	return card != null \
		and player != null \
		and card != self \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and card.get_controller() == player \
		and card.is_creature_card() \
		and card.can_be_used_for_creature_sacrifice

func has_pending_chosen_discards_for_cost() -> bool:
	if discard_cost <= 0:
		return true
	if _pending_chosen_discards.size() < discard_cost:
		return false
	for i in range(discard_cost):
		var card := _pending_chosen_discards[i]
		if card == null or card == self or card.current_zone != card_owner.hand_zone:
			return false
	return true

func pay_costs(player: Player, game_manager: GameManager = null) -> bool:
	return pay_costs_with_mana_cost(player, mana_cost, game_manager)

func pay_costs_with_mana_cost(player: Player, mana_required: int, game_manager: GameManager = null) -> bool:
	if not can_pay_costs_with_mana_cost(player, mana_required):
		return false
	
	# Pay mana cost
	if mana_required > 0:
		player.spend_mana(mana_required)
	
	# Pay discard cost
	for i in range(discard_cost):
		if _pending_chosen_discards.size() > i:
			var chosen_discard := _pending_chosen_discards[i]
			if chosen_discard != null and chosen_discard.current_zone == player.hand_zone and chosen_discard != self:
				player.discard_card(chosen_discard)
				continue
		if player.hand_zone.get_card_count() > 0:
			var card_to_discard = player.hand_zone.cards[0]
			if card_to_discard == self and player.hand_zone.get_card_count() > 1:
				card_to_discard = player.hand_zone.cards[1]
			if card_to_discard != self:
				player.discard_card(card_to_discard)

	clear_pending_chosen_discards()
	
	# Pay sacrifice cost.
	if sacrifice_cost > 0:
		for i in range(sacrifice_cost):
			if _pending_chosen_sacrifices.size() > i:
				var chosen_sacrifice := _pending_chosen_sacrifices[i]
				if _is_valid_pending_sacrifice_choice(chosen_sacrifice, player):
					if game_manager != null:
						game_manager._send_to_graveyard_with_hook(chosen_sacrifice, false, false)
					else:
						player.move_card(chosen_sacrifice, player.graveyard_zone)
					if chosen_sacrifice.has_method("on_sacrificed_for_summon") and not chosen_sacrifice.post_field_abilities_suppressed():
						chosen_sacrifice.on_sacrificed_for_summon(game_manager, self)
					continue
			var creature_found = false
			for zone in player.frontline_zones + player.reserve_zones:
				if creature_found:
					break
				for card in zone.cards:
					if card.is_creature_card() and card.can_be_used_for_creature_sacrifice:
						if game_manager != null:
							game_manager._send_to_graveyard_with_hook(card, false, false)
						else:
							player.move_card(card, player.graveyard_zone)
						if card.has_method("on_sacrificed_for_summon") and not card.post_field_abilities_suppressed():
							card.on_sacrificed_for_summon(game_manager, self)
						creature_found = true
						break
	clear_pending_chosen_sacrifices()
	
	# Pay shelve cost
	for i in range(shelve_cost):
		if player.hand_zone.get_card_count() > 0:
			var card_to_shelve = player.hand_zone.cards[0]
			player.shelve_card(card_to_shelve)
	
	# Pay banish cost
	for i in range(banish_cost):
		var card_found = false
		# Try hand first
		if player.hand_zone.get_card_count() > 0:
			var card_to_banish = player.hand_zone.cards[0]
			player.banish_card(card_to_banish)
			card_found = true
		# Then board
		if not card_found:
			for zone in player.frontline_zones + player.reserve_zones:
				if zone.get_card_count() > 0:
					var card_to_banish = zone.cards[0]
					if game_manager != null:
						game_manager._send_to_abyss_with_hook(card_to_banish)
					else:
						player.banish_card(card_to_banish)
					break
	
	return true
