# BaseCard.gd
extends Card
class_name BaseCard

var uid: String = ""

static var _uid_counter: int = 0

func _init() -> void:
	uid = _generate_uid()

func _generate_uid() -> String:
	_uid_counter += 1
	# In a real multiplayer game, the server should assign these or use a UUID.
	# For now, we'll use a prefix to distinguish local IDs.
	return "card_" + str(Time.get_ticks_msec()) + "_" + str(_uid_counter)

func assign_fresh_uid() -> void:
	uid = _generate_uid()

# Keyword definitions - displayed as hover tooltips in ability text.
const KEYWORD_HINTS = {
	"Void": "Send this card to the Abyss - removed from the game.",
	"Immortal": "This card cannot be destroyed.",
	"Sleep": "This creature cannot take any actions while asleep and is put into defensive stance.",
	"Mute": "A muted power cannot be unlocked or activated until the mute expires.",
	"Shelve": "Send this card to the bottom of its owner's deck.",
	"Convert": "Move followers from the opponent to you - they switch sides.",
	"Enslave": "Take control of an opposing creature. It cannot use its abilities, but it can still attack and intercept.",
	"Mill": "Put a card from the top of a deck into the graveyard.",
	"Reach": "This creature can intercept for targets one row further forward than normal.",
	"Engage": "Enter combat with another card, usually by attacking it or intercepting its attack.",
	"Passive": "This effect is always active while this card remains in play.",
	"Impact": "This effect triggers when this card enters the field from your hand, unless it has Universal Impact.",
	"Universal Impact": "This Impact also triggers when this card enters the field from zones other than your hand.",
	"Imbue": "Weapons equipped from your hand gain an added effect.",
	"Reveal": "This ability activates when this card becomes visible, such as when it exits stealth or is turned face-up.",
	"Destroyed": "This effect triggers when this creature is destroyed.",
	"Fatality": "This effect triggers when this creature is destroyed in combat.",
	"Unlock": "This card must be unlocked before its unlocked ability can be used.",
	"Activate": "Use this card's activated ability.",
	"Relock": "Turn an unlocked power face-down again.",
	"Resurrect": "Return a destroyed card from the graveyard to the field.",
	"Wake": "Remove Sleep from a creature.",
	"Leech": "Steal the listed stats from each affected target, reducing them and increasing this card by the same amount.",
	"Returns": "This card enters the field from the Abyss.",
	"Search": "Look through your deck for a card, then shuffle.",
	"Dodge": "This creature cannot be attacked by creatures with lower speed.",
	"Shuffle": "Return this card to its owner's deck, then shuffle that deck.",
	"Prime": "Put a card on top of your deck.",
	"Perish": "This effect triggers when this card is sent from the field to the graveyard.",
	"Silence": "Remove this card's abilities.",
	"Frontlined": "This effect applies while this card is in the frontline.",
	"Upkeep": "This effect happens during upkeep at the beginning of your turn.",
	"Harbor": "Place a qualifying card under this card. Harbored cards are not on the field until returned.",
	"Shift": "Switch this card between its listed forms.",
	"Incorporeal": "Can only be engaged by Spirits or faster Mages. Can only engage Spirits or slower Mages.",
	"Slay": "This effect triggers when this card destroys another creature in combat.",
	"Slain": "This card was destroyed in combat.",
	"Trollskap": "If this card is destroyed by an effect, return it to your hand instead.",
	"Champion's Call": "Summon this god's matching Active God. You may Shelve cards from your hand to pay 4 mana each toward its summon cost.",
	"Brood Slots": "Instead of powers, these slots can hold face-up Ancient Demons or Dragons up to the listed total level.",
	"Stone Infant": "Token creature with 17 STR, 17 RES, 1 SPD, and the types Token, Human, Stone, and Golem.",
	"Stone Skin": "This creature cannot be destroyed in combat.",
	"Terror": "When this card enters the field, return a lower-level opposing creature to its owner's hand.",
	"God Death": "If you control no face-up, awake God on the field, you gain 1 less upkeep mana, cannot use powers, and lose 7 followers at upkeep.",
	"Status": "A status is an ongoing condition on a card, such as Sleep, Petrified, or Cannot Attack. Removing status changes clears those active statuses.",
}

static func _escape_hint_text(text: String) -> String:
	return text.replace("\"", "&quot;")

# Wraps bold keywords in [hint=...] BBCode so RichTextLabel shows tooltips.
static func apply_keyword_hints(text: String) -> String:
	var result := text
	for keyword in KEYWORD_HINTS:
		var hint_text := _escape_hint_text(KEYWORD_HINTS[keyword])
		result = result.replace("[b]" + keyword + "[/b]",
			"[hint=\"" + hint_text + "\"][b]" + keyword + "[/b][/hint]")
	return result

static func apply_action_cost_symbols(text: String, card = null) -> String:
	if text.strip_edges() == "":
		return text
	var mana_decorated := apply_mana_cost_symbols(text, 14)
	var lines := mana_decorated.split("\n", true)
	var decorated: Array[String] = []
	for raw_line in lines:
		var line := str(raw_line)
		var cost_kind := _get_action_cost_kind_for_ability_line(line, card)
		if cost_kind != "" and not line.begins_with("[img="):
			line = _get_action_symbol_bbcode(cost_kind, 18) + line
		decorated.append(line)
	return "\n".join(decorated)

static func apply_mana_cost_symbols(text: String, icon_size: int = 14) -> String:
	if text.strip_edges() == "":
		return text
	var decorated := _replace_mana_shorthand_symbols(text, icon_size)
	decorated = _replace_pay_mana_phrases(decorated, icon_size)
	decorated = _replace_pay_variable_mana_phrases(decorated, icon_size)
	decorated = _replace_labeled_mana_costs(decorated, icon_size)
	decorated = _replace_numeric_mana_phrases(decorated, icon_size)
	return decorated

static func get_mana_symbol_bbcode(size: int = 14) -> String:
	return "[img=%dx%d]res://images/ui/ManaOrb.png[/img]" % [size, size]

static func _replace_mana_shorthand_symbols(text: String, icon_size: int) -> String:
	var regex := RegEx.new()
	if regex.compile("(^|[^A-Za-z0-9])([0-9]+)M\\b") != OK:
		return text
	var matches := regex.search_all(text)
	if matches.is_empty():
		return text
	var result := ""
	var cursor := 0
	for match_result in matches:
		result += text.substr(cursor, match_result.get_start() - cursor)
		var amount := int(match_result.get_string(2))
		if amount > 0:
			result += match_result.get_string(1) + match_result.get_string(2) + " " + get_mana_symbol_bbcode(icon_size)
		else:
			result += match_result.get_string(0)
		cursor = match_result.get_end()
	result += text.substr(cursor)
	return result

static func _replace_pay_mana_phrases(text: String, icon_size: int) -> String:
	var regex := RegEx.new()
	if regex.compile("(?i)(\\bpay\\s+)([0-9]+|X)(\\s+(?:additional\\s+|graveyard\\s+)?)(mana\\b)") != OK:
		return text
	var matches := regex.search_all(text)
	if matches.is_empty():
		return text
	var result := ""
	var cursor := 0
	for match_result in matches:
		result += text.substr(cursor, match_result.get_start() - cursor)
		result += match_result.get_string(1) \
			+ match_result.get_string(2) \
			+ match_result.get_string(3) \
			+ get_mana_symbol_bbcode(icon_size)
		cursor = match_result.get_end()
	result += text.substr(cursor)
	return result

static func _replace_pay_variable_mana_phrases(text: String, icon_size: int) -> String:
	var regex := RegEx.new()
	if regex.compile("(?i)(\\bpay\\s+)(mana\\b)") != OK:
		return text
	var matches := regex.search_all(text)
	if matches.is_empty():
		return text
	var result := ""
	var cursor := 0
	for match_result in matches:
		result += text.substr(cursor, match_result.get_start() - cursor)
		result += match_result.get_string(1) + get_mana_symbol_bbcode(icon_size)
		cursor = match_result.get_end()
	result += text.substr(cursor)
	return result

static func _replace_labeled_mana_costs(text: String, icon_size: int) -> String:
	var regex := RegEx.new()
	if regex.compile("(?i)(\\b(?:mana|activation cost|unlock cost):\\s*)([0-9]+)\\b") != OK:
		return text
	var matches := regex.search_all(text)
	if matches.is_empty():
		return text
	var result := ""
	var cursor := 0
	for match_result in matches:
		result += text.substr(cursor, match_result.get_start() - cursor)
		var amount := int(match_result.get_string(2))
		if amount > 0:
			result += match_result.get_string(1) + match_result.get_string(2) + " " + get_mana_symbol_bbcode(icon_size)
		else:
			result += match_result.get_string(0)
		cursor = match_result.get_end()
	result += text.substr(cursor)
	return result

static func _replace_numeric_mana_phrases(text: String, icon_size: int) -> String:
	var regex := RegEx.new()
	if regex.compile("(?i)(\\b[0-9]+|\\bX)(\\s+(?:additional\\s+|graveyard\\s+)?)(mana\\b)") != OK:
		return text
	var matches := regex.search_all(text)
	if matches.is_empty():
		return text
	var result := ""
	var cursor := 0
	for match_result in matches:
		result += text.substr(cursor, match_result.get_start() - cursor)
		result += match_result.get_string(1) \
			+ match_result.get_string(2) \
			+ get_mana_symbol_bbcode(icon_size)
		cursor = match_result.get_end()
	result += text.substr(cursor)
	return result

static func _get_action_cost_kind_for_ability_line(line: String, card = null) -> String:
	var lower_line := line.to_lower()
	if _line_declares_action_cost(lower_line, "minor"):
		if card != null and card.has_method("get_effective_minor_action_cost_kind"):
			return card.get_effective_minor_action_cost_kind()
		return "minor"
	if _line_declares_action_cost(lower_line, "major"):
		return "major"
	return ""

static func _line_declares_action_cost(lower_line: String, action_kind: String) -> bool:
	var action_text := action_kind + " action"
	if lower_line.contains("[b]" + action_text + "[/b]"):
		return true
	if lower_line.contains("(" + action_text) or lower_line.contains(", " + action_text):
		return true
	if action_kind == "major" and lower_line.contains("use this card's major action"):
		return true
	return false

static func _get_action_symbol_bbcode(action_cost_kind: String, size: int = 18) -> String:
	var path := ""
	match action_cost_kind:
		"minor":
			path = "res://images/ui/MinorActionSymbol.png"
		"major":
			path = "res://images/ui/MajorActionSymbol.png"
	if path == "":
		return ""
	return "[img=%dx%d]%s[/img] " % [size, size, path]

static func format_shapeshifter_form_summary(active_form_types: Array[String], inactive_form_types: Array[String]) -> String:
	return "[b]Shapeshifter[/b]: [color=#66ff66]%s[/color] / [color=#8a8a8a]%s[/color]" % [
		_format_shapeshifter_form_types(active_form_types),
		_format_shapeshifter_form_types(inactive_form_types)
	]

static func _format_shapeshifter_form_types(form_types: Array[String]) -> String:
	var visible_types: Array[String] = []
	for raw_type in form_types:
		var type_name := str(raw_type)
		if type_name == "" or type_name == "Shapeshifter" or type_name.ends_with(" Creature"):
			continue
		visible_types.append(type_name)
	return ", ".join(visible_types)

# Common hooks all cards can use
func on_play(_game_manager: GameManager, _target = null) -> void:
	pass

func can_be_played(_game_manager: GameManager, player: Player) -> bool:
	if _game_manager == null:
		return can_pay_costs(player)
	var mana_required := mana_cost
	var prepared := is_prepared and current_zone != null and current_zone.is_board_zone()
	if _game_manager.has_method("get_card_play_mana_cost"):
		mana_required = _game_manager.get_card_play_mana_cost(player, self, prepared)
	return can_pay_costs_with_mana_cost(player, mana_required)

func get_play_failure_reason(_game_manager: GameManager, player: Player) -> String:
	if player == null:
		return "No acting player was provided."
	if _game_manager == null:
		return "" if can_pay_costs(player) else get_cost_payment_failure_reason(player, mana_cost)
	var mana_required := mana_cost
	var prepared := is_prepared and current_zone != null and current_zone.is_board_zone()
	if _game_manager.has_method("get_card_play_mana_cost"):
		mana_required = _game_manager.get_card_play_mana_cost(player, self, prepared)
	if not can_pay_costs_with_mana_cost(player, mana_required):
		return get_cost_payment_failure_reason(player, mana_required)
	return ""

func on_enter_zone(_zone: Zone) -> void:
	pass

func on_leave_zone(_zone: Zone) -> void:
	pass

func has_universal_impact() -> bool:
	return false

func should_trigger_impact_from_zone(from_zone: Zone) -> bool:
	if has_universal_impact():
		return true
	return from_zone != null and from_zone.zone_type == Zone.ZoneType.HAND

func get_self_graveyard_replacement_zone(
	_game_manager: GameManager,
	_combat_death: bool,
	_destruction: bool,
	_send_to_abyss: bool
) -> Zone:
	return null
