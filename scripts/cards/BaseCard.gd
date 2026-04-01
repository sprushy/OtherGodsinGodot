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

# Keyword definitions - displayed as hover tooltips in ability text.
const KEYWORD_HINTS = {
	"Void": "Send this card to the Abyss - removed from the game.",
	"Immortal": "This card cannot be destroyed.",
	"Sleep": "This creature cannot take any actions while asleep.",
	"Mute": "A muted power cannot be unlocked or activated until the mute expires.",
	"Shelve": "Send this card to the bottom of its owner's deck.",
	"Convert": "Move followers from the opponent to you - they switch sides.",
	"Enslave": "Take control of an opposing creature. It cannot use its abilities, but it can still attack and intercept.",
	"Mill": "Put a card from the top of a deck into the graveyard.",
	"Reach": "This creature can intercept for targets one row further forward than normal.",
	"Passive": "This effect is always active while this card remains in play.",
	"Impact": "This effect triggers when this card enters the field.",
	"Reveal": "This effect triggers when this card is revealed.",
	"Destroyed": "This effect triggers when this creature is destroyed.",
	"Unlock": "This card must be unlocked before its unlocked ability can be used.",
	"Activate": "Use this card's activated ability.",
	"Relock": "Turn an unlocked power face-down again.",
	"Resurrect": "Return a destroyed card from the graveyard to the field.",
	"Wake": "Remove Sleep from a creature.",
	"Returns": "This card enters the field from the Abyss.",
	"Search": "Look through your deck for a card, then shuffle.",
	"Shuffle": "Return this card to its owner's deck, then shuffle that deck.",
	"Prime": "Put a card on top of your deck.",
	"Perish": "This card died in any way and was sent to the graveyard.",
	"Silence": "Remove this card's abilities.",
	"Frontlined": "This effect applies while this card is in the frontline.",
	"Upkeep": "This effect happens during upkeep at the beginning of your turn.",
	"Incorporeal": "Can only be engaged by Spirits or faster Mages. Can only engage Spirits or slower Mages.",
	"Slay": "This effect triggers when this card destroys another creature in combat.",
	"Slain": "This card was destroyed in combat.",
	"Trollskap": "If this card is destroyed by an effect, return it to your hand instead.",
	"Stone Infant": "Token creature with 17 STR, 17 RES, 1 SPD, and the types Token, Human, Stone, and Golem.",
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

# Common hooks all cards can use
func on_play(_game_manager: GameManager, _target = null) -> void:
	pass

func can_be_played(_game_manager: GameManager, player: Player) -> bool:
	if _game_manager == null:
		return can_pay_costs(player)
	var mana_required := mana_cost
	if _game_manager.has_method("get_card_play_mana_cost"):
		mana_required = _game_manager.get_card_play_mana_cost(player, self, false)
	return can_pay_costs_with_mana_cost(player, mana_required)

func on_enter_zone(_zone: Zone) -> void:
	pass

func on_leave_zone(_zone: Zone) -> void:
	pass

func get_self_graveyard_replacement_zone(
	_game_manager: GameManager,
	_combat_death: bool,
	_destruction: bool,
	_send_to_abyss: bool
) -> Zone:
	return null
