extends RefCounted
class_name PracticeAutofillDeckFactory

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const BotCardStrategyScript = preload("res://scripts/bots/BotCardStrategy.gd")
const BotSideboardPolicyScript = preload("res://scripts/bots/BotSideboardPolicy.gd")
const BotSideboardRatingsScript = preload("res://scripts/bots/BotSideboardRatings.gd")

const DEFAULT_REGULAR_CARD_COUNT := 40
const LEGENDARY_DECK_TARGET := 4 # DEFAULT_REGULAR_CARD_COUNT / 10, matches DeckValidator
const MAX_POWERS := 3
const MAX_BUILD_ATTEMPTS := 32
const MAX_RANDOM_PICK_ATTEMPTS := 256
const HERMES_PSYCHOPOMPUS_MIN_GHOSTS := 4
const NUSKU_MIN_ANCIENT_MAGICAL := 6
const MANANNAN_MAC_LIR_MIN_TRISKELION_CREATURES := 5
const ODIN_MIN_RUNIC_ACTIVATORS := 4
const CERNUNNOS_MIN_LEVEL_5_ANIMALS := 3
const KEY_OF_SOLOMON_MIN_SOURCES := 2
const KEY_OF_SOLOMON_MIN_TARGETS := 4
const VISION_OF_TARTARUS_MIN_VOID_SOURCES := 3
const TABLET_OF_LIFE_CARD_NAME := "Tablet of Life"
const TABLET_OF_LIFE_MIN_ANCIENT_CREATURES := 6
# Ranked bot decks pick one of four fill rubrics: 10% the old mixed fill,
# 30% an even Creature/non-Creature split, 30% a deck heavily weighted toward
# one random non-Creature category, and 30% a support package (support card at
# max copies plus 2.5x its required targets) before re-rolling for the rest.
const RUBRIC_LEGACY := 0
const RUBRIC_BALANCED := 1
const RUBRIC_CATEGORY := 2
const RUBRIC_SUPPORT_PACKAGE := 3
const RUBRIC_LEGACY_WEIGHT := 0.10
const RUBRIC_BALANCED_WEIGHT := 0.30
const RUBRIC_CATEGORY_WEIGHT := 0.30
const RUBRIC_CATEGORY_BIAS := 0.75
const SUPPORT_TARGET_MULTIPLIER := 2.5
const MAX_PACKAGE_COMMITS := 3
const RANKED_SUPPORT_CAP := 10
const NON_CREATURE_CATEGORIES := [
	Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM,
	Card.CardType.EQUIPMENT, Card.CardType.STRUCTURE,
]
const VOID_SOURCE_CARD_NAMES := [
	"Bit Meseri",
	"Void Shield",
	"Wheel of Fire",
	"Asag the Destroyer",
	"Doorway to the Void",
	"Walk of the Sage",
	"Sixth Sage An-Enlilda",
	"E2-abzu",
]
var _validator := DeckValidatorScript.new()
var _all_cards: Array[Card] = []
var _gods: Array[GodCard] = []
var _cards_by_name: Dictionary = {}
var _restricted_equipment_lookup: Dictionary = {}
# {card, required, exclude, matches: Callable(Card)->bool}
# Built once at init so the package pool can be filtered per god at roll time.
var _support_packages: Array[Dictionary] = []

func _init() -> void:
	_all_cards = CardCatalogScript.make_all_cards()
	for card in _all_cards:
		if card == null:
			continue
		_cards_by_name[str(card.card_name)] = card
		if card is GodCard:
			_gods.append(card as GodCard)
	_build_restricted_equipment_lookup()
	_build_support_packages()

func get_ranked_god_names() -> Array[String]:
	var names: Array[String] = []
	for god in _gods:
		if not names.has(god.card_name):
			names.append(god.card_name)
	return names

func build_random_deck(seed_value: int, forced_god_name: String = "", ranked: bool = false) -> Dictionary:
	if _gods.is_empty():
		return {}
	for attempt in range(MAX_BUILD_ATTEMPTS):
		var deck_seed := seed_value + attempt
		var rng := RandomNumberGenerator.new()
		rng.seed = deck_seed
		var god := _choose_god_template(rng, forced_god_name, ranked)
		if god == null:
			continue
		var deck_cards: Dictionary = {}
		deck_cards[god.card_name] = 1
		var preloaded_regular_count := 0
		if god is HermesPsychopompus:
			_seed_psychopompus_ghosts(deck_cards, god, rng, ranked)
			preloaded_regular_count = _count_regular_cards(deck_cards)
		if not _fill_regular_cards_for_god(deck_cards, god, rng, ranked, preloaded_regular_count):
			continue
		if god is Cernunnos:
			_enforce_god_specific_regular_minimums(deck_cards, god, rng, ranked)
		var special_setup := {}
		if TiamatThePrimordial.is_tiamat_god(god):
			var brood_count := rng.randi_range(1, TiamatThePrimordial.POWER_SLOT_COUNT)
			special_setup = _build_tiamat_brood_setup(rng, brood_count)
			if not _fill_safe_powers_for_god(
				deck_cards, god, rng, ranked,
				TiamatThePrimordial.POWER_SLOT_COUNT - brood_count
			):
				continue
		else:
			if not _fill_safe_powers_for_god(deck_cards, god, rng, ranked):
				continue
		var validation := _validator.validate_deck(deck_cards, special_setup)
		if bool(validation.get("is_valid", false)):
			var validated_cards: Dictionary = (validation.get("cards", {}) as Dictionary).duplicate(true)
			var reinforcements := build_reinforcements_for_deck(
				validated_cards,
				god.card_name,
				validation.get("special_setup", {}),
				deck_seed
			)
			var built := {
				"name": "%s Autofill %d" % [god.card_name, seed_value],
				"deck_name": "%s Autofill %d" % [god.card_name, seed_value],
				"cards": validated_cards,
				"reinforcements": reinforcements,
				"special_setup": validation.get("special_setup", {}),
				"seed": deck_seed,
				"god_name": god.card_name,
			}
			return audit_ranked_bot_deck(built) if ranked else built
	return {}

# Builds a deterministic, deck-validator-legal Thor deck that contains the
# pieces needed to exercise the Hunting Tactics power: the power itself, a
# Norse Human Warrior attacker (Harii Warrior), and a Raven supporter (Huginn).
# Used by the two-process hunting_tactics smoke roles.
const HUNTING_TACTICS_DECK_FORCED_CARDS := {
	"Hunting Tactics": 1,
	"Harii Warrior": 3,
	"Huginn": 3,
}
const HUNTING_TACTICS_DECK_GOD := "Thor"

func build_hunting_tactics_deck() -> Dictionary:
	var god := _cards_by_name.get(HUNTING_TACTICS_DECK_GOD, null) as GodCard
	if god == null:
		return {}
	for attempt in range(MAX_BUILD_ATTEMPTS):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + attempt
		var deck_cards: Dictionary = {}
		deck_cards[god.card_name] = 1
		# Seed the deck with the forced cards first so the filler never starves
		# the regular-card count below the minimum, then top up as usual.
		for forced_name in HUNTING_TACTICS_DECK_FORCED_CARDS.keys():
			deck_cards[forced_name] = int(HUNTING_TACTICS_DECK_FORCED_CARDS[forced_name])
		if not _fill_regular_cards_for_god(deck_cards, god, rng):
			continue
		# Hunting Tactics is seeded above so this smoke deck always exercises
		# that power regardless of how the filler would otherwise roll.
		var validation := _validator.validate_deck(deck_cards)
		if bool(validation.get("is_valid", false)):
			return {
				"name": "Hunting Tactics Smoke",
				"deck_name": "Hunting Tactics Smoke",
				"cards": (validation.get("cards", {}) as Dictionary).duplicate(true),
				"special_setup": validation.get("special_setup", {}),
				"god_name": god.card_name,
			}
	return {}

# Builds a PURPOSE deck that is allowed to violate normal construction rules
# (1 god not required, copy limits ignored, below the 35-card minimum, all the
# same card, etc.). Intended for campaign scenarios, scripted tests, and smoke
# runs that need a guaranteed board state - never for normal bot matchmaking.
#
# `god_name` selects the god slot (may be empty for a godless deck).
# `card_counts` is a {card_name: count} dict of exactly what to include; counts
# are not clamped to copy/legendary limits. The deck is NOT run through the
# validator, so callers must ensure the cards exist in the catalog.
func build_purpose_deck(deck_name: String, god_name: String, card_counts: Dictionary) -> Dictionary:
	var resolved_cards: Dictionary = {}
	for card_name in card_counts.keys():
		var resolved_name := str(card_name).strip_edges()
		if resolved_name.is_empty():
			continue
		var count := int(card_counts[card_name])
		if count <= 0:
			continue
		if _cards_by_name.get(resolved_name, null) == null:
			push_warning("[PracticeAutofillDeckFactory] purpose deck references unknown card: %s" % resolved_name)
			continue
		resolved_cards[resolved_name] = count
	var god_card = null
	var resolved_god := str(god_name).strip_edges()
	if not resolved_god.is_empty():
		god_card = _cards_by_name.get(resolved_god, null) as GodCard
	var result := {
		"name": deck_name,
		"deck_name": deck_name,
		"cards": resolved_cards.duplicate(true),
		"special_setup": {},
		"god_name": god_card.card_name if god_card != null else "",
		"is_purpose_deck": true,
	}
	return result

func _choose_god_template(rng: RandomNumberGenerator, forced_god_name: String, ranked: bool) -> GodCard:
	var resolved_forced_name := forced_god_name.strip_edges()
	if not resolved_forced_name.is_empty():
		var forced_card = _cards_by_name.get(resolved_forced_name, null)
		return forced_card as GodCard if forced_card in _gods else null
	var candidates := _gods if ranked else _gods.filter(func(god: GodCard) -> bool:
		return not TiamatThePrimordial.is_tiamat_god(god)
	)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _seed_psychopompus_ghosts(
	deck_cards: Dictionary,
	god: GodCard,
	rng: RandomNumberGenerator,
	ranked: bool
) -> int:
	var seeded := 0
	while seeded < HERMES_PSYCHOPOMPUS_MIN_GHOSTS:
		var candidates: Array[Card] = []
		for template in _all_cards:
			if template == null or template.card_type != Card.CardType.CREATURE or template.is_god:
				continue
			if not template.has_type("Ghost"):
				continue
			if not _is_safe_regular_card(template, god, deck_cards, false, ranked):
				continue
			candidates.append(template)
		if candidates.is_empty():
			break
		var chosen: Card = candidates[rng.randi_range(0, candidates.size() - 1)]
		deck_cards[chosen.card_name] = int(deck_cards.get(chosen.card_name, 0)) + 1
		seeded += 1
	if seeded < HERMES_PSYCHOPOMPUS_MIN_GHOSTS:
		push_warning("[PracticeAutofillDeckFactory] Psychopompus autofill seeded only %d Ghosts" % seeded)
	return seeded

# Repairs god-specific ranked deck minimums by swapping the worst
# survey-rated non-required regular cards for randomly chosen cards that
# support the god's core ability. The deck size is preserved for full lists.
func _enforce_god_specific_regular_minimums(
	cards: Dictionary,
	god: GodCard,
	rng: RandomNumberGenerator,
	ranked: bool = true,
	sideboard: Dictionary = {}
) -> void:
	var attempts := 0
	while attempts < MAX_RANDOM_PICK_ATTEMPTS:
		attempts += 1
		if _god_specific_regular_deficit(god, cards) <= 0:
			return
		var needs_swap := _count_regular_cards(cards) >= DEFAULT_REGULAR_CARD_COUNT
		var victim_name := ""
		var victim_count := 0
		if needs_swap:
			victim_name = _choose_god_specific_swap_victim(cards, god)
			if victim_name.is_empty():
				return
			victim_count = int(cards.get(victim_name, 0))
			if victim_count <= 0:
				return
			if victim_count <= 1:
				cards.erase(victim_name)
			else:
				cards[victim_name] = victim_count - 1
		var candidates := _get_regular_candidates(god, cards, false, ranked).filter(
			func(card: Card) -> bool: return _matches_god_specific_regular_requirement(god, card) \
				and _combined_copy_room(card, cards, sideboard) > 0
		)
		if candidates.is_empty():
			if needs_swap and victim_count > 0:
				cards[victim_name] = victim_count
			return
		var chosen: Card = candidates[rng.randi_range(0, candidates.size() - 1)]
		cards[chosen.card_name] = int(cards.get(chosen.card_name, 0)) + 1

# The 12% legendary sprinkle is stochastic, so top up best-effort after the
# main fill and during ranked audits instead of settling for fewer than the
# validator's four-legendary allowance.
func _enforce_legendary_minimum(
	cards: Dictionary,
	god: GodCard,
	rng: RandomNumberGenerator,
	ranked: bool = true,
	sideboard: Dictionary = {}
) -> void:
	var attempts := 0
	while attempts < MAX_RANDOM_PICK_ATTEMPTS:
		attempts += 1
		if _count_regular_legendary_cards(cards) >= LEGENDARY_DECK_TARGET:
			return
		var needs_swap := _count_regular_cards(cards) >= DEFAULT_REGULAR_CARD_COUNT
		var victim_name := ""
		var victim_count := 0
		if needs_swap:
			victim_name = _choose_legendary_swap_victim(cards, god)
			if victim_name.is_empty():
				return
			victim_count = int(cards.get(victim_name, 0))
			if victim_count <= 0:
				return
			if victim_count <= 1:
				cards.erase(victim_name)
			else:
				cards[victim_name] = victim_count - 1
		var candidates := _get_regular_candidates(god, cards, true, ranked).filter(
			func(card: Card) -> bool: return _has_deckbuilding_requirements(card, cards, god) \
				and _combined_copy_room(card, cards, sideboard) > 0
		)
		if candidates.is_empty():
			if needs_swap and victim_count > 0:
				cards[victim_name] = victim_count
			return
		var chosen: Card = candidates[rng.randi_range(0, candidates.size() - 1)]
		cards[chosen.card_name] = int(cards.get(chosen.card_name, 0)) + 1

func _god_specific_regular_deficit(god: GodCard, cards: Dictionary) -> int:
	var required_count := 0
	if god is NuskuFirebearer:
		required_count = NUSKU_MIN_ANCIENT_MAGICAL
	elif god is ManannanMacLir:
		required_count = MANANNAN_MAC_LIR_MIN_TRISKELION_CREATURES
	elif god is Odin:
		required_count = ODIN_MIN_RUNIC_ACTIVATORS
	elif god is Cernunnos:
		required_count = CERNUNNOS_MIN_LEVEL_5_ANIMALS
	else:
		return 0
	var current_count := 0
	for raw_name in cards:
		var template: Card = _cards_by_name.get(str(raw_name), null)
		if template == null or template.is_god or template.is_power:
			continue
		if _matches_god_specific_regular_requirement(god, template):
			current_count += int(cards[raw_name])
	return maxi(0, required_count - current_count)

func _matches_god_specific_regular_requirement(god: GodCard, card: Card) -> bool:
	if god is NuskuFirebearer:
		return _is_ancient_spell_or_charm(card)
	if god is ManannanMacLir:
		return _is_triskelion_creature(card)
	if god is Odin:
		return _is_odin_runic_activator(card)
	if god is Cernunnos:
		return _is_level_5_or_higher_animal(card)
	return false

func _is_ancient_spell_or_charm(card: Card) -> bool:
	return card != null \
		and str(card.culture).strip_edges().nocasecmp_to("Ancient") == 0 \
		and (card.card_type == Card.CardType.SPELL or card.card_type == Card.CardType.CHARM)

func _is_triskelion_creature(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and str(card.culture).strip_edges() == "Triskelion"

func _is_odin_runic_activator(card: Card) -> bool:
	return card != null \
		and (card.has_type("Runic") or str(card.card_name).to_lower().contains("of odin"))

func _is_level_5_or_higher_animal(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and not card.is_power \
		and not (card is ActiveGodCard) \
		and card.has_type("Animal") \
		and card.level >= 5

# Chooses the lowest-survey-rated regular card that does not already satisfy
# the god-specific requirement. Ratings come from the ladder card audit, and
# name order is only a deterministic tie-breaker.
func _choose_god_specific_swap_victim(cards: Dictionary, god: GodCard) -> String:
	return _choose_swap_victim(cards, god, false)

func _choose_legendary_swap_victim(cards: Dictionary, god: GodCard) -> String:
	return _choose_swap_victim(cards, god, true)

func _choose_swap_victim(cards: Dictionary, god: GodCard, exclude_legendary: bool) -> String:
	var victims: Array[Dictionary] = []
	for raw_name in cards:
		var card_name := str(raw_name)
		var template: Card = _cards_by_name.get(card_name, null)
		if template == null or template.is_god or template.is_power:
			continue
		if exclude_legendary and template.is_legendary:
			continue
		if _matches_god_specific_regular_requirement(god, template):
			continue
		if not _removing_card_preserves_support(cards, card_name, god):
			continue
		victims.append({
			"name": card_name,
			"rating": BotSideboardRatingsScript.rating_for(card_name),
		})
	if victims.is_empty():
		return ""
	victims.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if int(first["rating"]) != int(second["rating"]):
			return int(first["rating"]) < int(second["rating"])
		return str(first["name"]).naturalnocasecmp_to(str(second["name"])) < 0
	)
	return str(victims[0]["name"])

func _removing_card_preserves_support(cards: Dictionary, victim_name: String, god: GodCard) -> bool:
	var trial_cards: Dictionary = cards.duplicate(true)
	var victim_count := int(trial_cards.get(victim_name, 0))
	if victim_count <= 0:
		return false
	if victim_count <= 1:
		trial_cards.erase(victim_name)
	else:
		trial_cards[victim_name] = victim_count - 1
	for raw_name in trial_cards:
		var card_name := str(raw_name)
		if card_name == god.card_name:
			continue
		var template: Card = _cards_by_name.get(card_name, null)
		if template != null and not _has_deckbuilding_requirements(template, trial_cards, god):
			return false
	return true

# Fires of Judgment moving to Ancient is the live example: a stale Patriarch
# list can contain cards that are no longer culture-legal. Drop them before
# support pruning and quota repair so the auditor can rebuild a legal list.
func _remove_culture_incompatible_cards(cards: Dictionary, god: GodCard) -> void:
	if god == null or not god.uses_culture_locked_deckbuilding():
		return
	var names_to_remove: Array[String] = []
	for raw_name in cards:
		var card_name := str(raw_name)
		if card_name == god.card_name:
			continue
		var template: Card = _cards_by_name.get(card_name, null)
		if template != null and not _is_card_compatible_with_god(template, god):
			names_to_remove.append(card_name)
	for card_name in names_to_remove:
		cards.erase(card_name)

# --- Ranked bot deck rubrics ------------------------------------------------
# Each support package names one payoff card and the target shape its deckbuilding
# rule counts. Committing a package puts roughly 2.5x the rule's required targets
# in the deck, then the payoff itself at its maximum copy count.

func _build_support_packages() -> void:
	_add_support_package("Durinn Secondborn", 3, _card_type_matcher([Card.CardType.EQUIPMENT]))
	_add_support_package("Circle of Rebirth", 5, _any_type_matcher(["Animal", "Plant"]))
	_add_support_package(TABLET_OF_LIFE_CARD_NAME, TABLET_OF_LIFE_MIN_ANCIENT_CREATURES, _culture_creature_matcher("Ancient"))
	_add_support_package("Key of Solomon", KEY_OF_SOLOMON_MIN_TARGETS, _type_matcher(["Demon"]))
	_add_support_package("Key of Solomon", KEY_OF_SOLOMON_MIN_SOURCES, _type_matcher(["Animal"]))
	_add_support_package("Apollyon's Demiurge", 3, _type_matcher(["Demon"]))
	_add_support_package("Eridu, City of Sages", 3, _type_matcher(["Mage"]))
	_add_support_package("Advanced Building Techniques", 2, _card_type_matcher([Card.CardType.STRUCTURE]))
	_add_support_package("Myrkwood", 2, _type_matcher(["Animal"]))
	_add_support_package("Isimud", 3, _type_matcher(["Divine Manifestation"]))
	_add_support_package("Fourth Sage Enmegalamma", 3, _type_matcher(["Mer", "Sage"]))
	_add_support_package("Sixth Sage An-Enlilda", 2, Callable(self, "_match_ancient_dwelling"))
	_add_support_package("Robotic Footsoldier", 2, _type_matcher(["Machine"]))
	_add_support_package("Beyla", 3, _named_matcher(["Berserker", "Gidim Ensi"]))
	_add_support_package("Caleuche, the Ghost Ship", 2, _type_matcher(["Spirit"]))
	_add_support_package("E2-abzu", 2, _type_matcher(["Mer"]))
	_add_support_package("Vision of Tartarus", VISION_OF_TARTARUS_MIN_VOID_SOURCES, _named_matcher(VOID_SOURCE_CARD_NAMES))
	_add_support_package("Huginn", 1, _type_matcher(["Hex"], false))
	_add_support_package("Muninn", 1, _type_matcher(["Charm"], false))
	_add_support_package("Wild Magic", 1, _card_type_matcher([Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM]))

func _add_support_package(card_name: String, required: int, matcher: Callable) -> void:
	var card: Card = _cards_by_name.get(card_name, null) as Card
	if card == null:
		push_warning("[PracticeAutofillDeckFactory] support package references unknown card: %s" % card_name)
		return
	_support_packages.append({
		"card": card,
		"required": required,
		"exclude": card_name,
		"matches": matcher,
	})

func _make_god_autofill_package(required: int, matcher: Callable) -> Dictionary:
	return {"card": null, "required": required, "exclude": "", "matches": matcher}

func _eligible_support_packages(god: GodCard) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for package in _support_packages:
		var card: Card = package.get("card", null)
		if card == null or _is_card_compatible_with_god(card, god):
			eligible.append(package)
	# The god's own autofill rules count as support packages too, e.g. Freyja's
	# Norse Warrior requirement rather than a single named payoff card.
	var rules: Array[Dictionary] = []
	if god is Thor or god is Freyja:
		rules.append(_make_god_autofill_package(6, _type_matcher(["Norse", "Warrior"])))
	elif god is TezcatlipocaTheSmokingMirror:
		rules.append(_make_god_autofill_package(4, _type_matcher(["Shapeshifter"])))
	elif god is NuskuFirebearer:
		rules.append(_make_god_autofill_package(NUSKU_MIN_ANCIENT_MAGICAL, Callable(self, "_is_ancient_spell_or_charm")))
	elif god is ManannanMacLir:
		rules.append(_make_god_autofill_package(MANANNAN_MAC_LIR_MIN_TRISKELION_CREATURES, _culture_creature_matcher("Triskelion")))
	elif god is Odin:
		rules.append(_make_god_autofill_package(ODIN_MIN_RUNIC_ACTIVATORS, Callable(self, "_is_odin_runic_activator")))
	elif god is Cernunnos:
		rules.append(_make_god_autofill_package(CERNUNNOS_MIN_LEVEL_5_ANIMALS, Callable(self, "_is_level_5_or_higher_animal")))
	elif god is HermesPsychopompus:
		rules.append(_make_god_autofill_package(HERMES_PSYCHOPOMPUS_MIN_GHOSTS, _type_matcher(["Ghost"])))
	eligible.append_array(rules)
	return eligible

func _roll_fill_rubric(rng: RandomNumberGenerator, allow_package: bool = true) -> int:
	# Disabling the package rubric renormalizes the remaining three so a
	# package re-roll keeps the same relative 10/30/30 weights.
	var span := RUBRIC_LEGACY_WEIGHT + RUBRIC_BALANCED_WEIGHT + RUBRIC_CATEGORY_WEIGHT
	if allow_package:
		span += RUBRIC_CATEGORY_WEIGHT
	var roll := rng.randf() * span
	if roll < RUBRIC_LEGACY_WEIGHT:
		return RUBRIC_LEGACY
	if roll < RUBRIC_LEGACY_WEIGHT + RUBRIC_BALANCED_WEIGHT:
		return RUBRIC_BALANCED
	if roll < RUBRIC_LEGACY_WEIGHT + RUBRIC_BALANCED_WEIGHT + RUBRIC_CATEGORY_WEIGHT:
		return RUBRIC_CATEGORY
	return RUBRIC_SUPPORT_PACKAGE

func _package_target_count(package: Dictionary, cards: Dictionary) -> int:
	var matcher: Callable = package["matches"]
	var exclude := str(package.get("exclude", ""))
	var total := 0
	for name in cards:
		var card_name := str(name)
		if card_name == exclude:
			continue
		var template: Card = _cards_by_name.get(card_name, null)
		if template != null and bool(matcher.call(template)):
			total += int(cards[name])
	return total

func _package_target_candidates(package: Dictionary, god: GodCard, deck_cards: Dictionary) -> Array[Card]:
	var matcher: Callable = package["matches"]
	var exclude := str(package.get("exclude", ""))
	var result: Array[Card] = []
	for template in _all_cards:
		if not _is_safe_regular_card(template, god, deck_cards, false, true):
			continue
		if str(template.card_name) == exclude:
			continue
		if bool(matcher.call(template)):
			result.append(template)
	return result

func _commit_support_package(deck_cards: Dictionary, god: GodCard, rng: RandomNumberGenerator) -> Dictionary:
	var pool := _eligible_support_packages(god)
	var result := {"regular": 0, "support": 0, "legendary": 0}
	if pool.is_empty():
		return result
	var package: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var target_total := int(floor(float(int(package["required"])) * SUPPORT_TARGET_MULTIPLIER))
	var attempts := 0
	while attempts < MAX_RANDOM_PICK_ATTEMPTS \
			and _package_target_count(package, deck_cards) < target_total \
			and _count_regular_cards(deck_cards) < DEFAULT_REGULAR_CARD_COUNT:
		attempts += 1
		var candidates := _package_target_candidates(package, god, deck_cards)
		if candidates.is_empty():
			break
		var chosen: Card = candidates[rng.randi_range(0, candidates.size() - 1)]
		deck_cards[chosen.card_name] = int(deck_cards.get(chosen.card_name, 0)) + 1
		result["regular"] = int(result["regular"]) + 1
		if chosen.card_type != Card.CardType.CREATURE:
			result["support"] = int(result["support"]) + 1
		if chosen.is_legendary:
			result["legendary"] = int(result["legendary"]) + 1
	var support_card: Card = package.get("card", null)
	if support_card != null and _is_safe_regular_card(support_card, god, deck_cards, support_card.is_legendary, true):
		var copies := mini(_max_copies(support_card), DEFAULT_REGULAR_CARD_COUNT - _count_regular_cards(deck_cards))
		if support_card.is_legendary:
			copies = mini(copies, LEGENDARY_DECK_TARGET - _count_regular_legendary_cards(deck_cards))
		for _copy in range(maxi(0, copies)):
			deck_cards[support_card.card_name] = int(deck_cards.get(support_card.card_name, 0)) + 1
			result["regular"] = int(result["regular"]) + 1
			if support_card.card_type != Card.CardType.CREATURE:
				result["support"] = int(result["support"]) + 1
			if support_card.is_legendary:
				result["legendary"] = int(result["legendary"]) + 1
	return result

func _card_type_matcher(types: Array) -> Callable:
	return func(card: Card) -> bool:
		return card != null and not card.is_god and int(card.card_type) in types

func _type_matcher(tags: Array, require_creature: bool = true) -> Callable:
	return func(card: Card) -> bool:
		if card == null or card.is_god:
			return false
		if require_creature and card.card_type != Card.CardType.CREATURE:
			return false
		for tag in tags:
			if not card.has_type(str(tag)):
				return false
		return true

func _any_type_matcher(tags: Array) -> Callable:
	return func(card: Card) -> bool:
		if card == null or card.is_god or card.card_type != Card.CardType.CREATURE:
			return false
		for tag in tags:
			if card.has_type(str(tag)):
				return true
		return false

func _culture_creature_matcher(culture: String) -> Callable:
	return func(card: Card) -> bool:
		return card != null and not card.is_god and card.card_type == Card.CardType.CREATURE \
			and str(card.culture).strip_edges() == culture

func _named_matcher(names: Array) -> Callable:
	return func(card: Card) -> bool:
		return card != null and str(card.card_name) in names

func _match_ancient_dwelling(card: Card) -> bool:
	return card != null and card.card_type == Card.CardType.STRUCTURE \
		and card.has_type("Dwelling") and str(card.culture).strip_edges() == "Ancient"

func _fill_regular_cards_for_god(
	deck_cards: Dictionary,
	god: GodCard,
	rng: RandomNumberGenerator,
	ranked: bool = false,
	preloaded_regular_count: int = 0
) -> bool:
	# Ranked bot decks commit to one of the four archetype rubrics. A support
	# package rubric re-rolls until it finds a fill plan for the remaining slots;
	# every later quota is relative to those slots, not a fresh 40-card deck.
	var rubric := RUBRIC_LEGACY
	var focus_category := -1
	var support_target := RANKED_SUPPORT_CAP
	var committed := {"regular": 0, "support": 0, "legendary": 0}
	if ranked:
		rubric = _roll_fill_rubric(rng)
		var package_commits := 0
		while rubric == RUBRIC_SUPPORT_PACKAGE and package_commits < MAX_PACKAGE_COMMITS:
			committed = _commit_support_package(deck_cards, god, rng)
			package_commits += 1
			if int(committed["regular"]) <= 0:
				rubric = _roll_fill_rubric(rng, false)
				break
			rubric = _roll_fill_rubric(rng)
		if rubric == RUBRIC_SUPPORT_PACKAGE:
			rubric = _roll_fill_rubric(rng, false)
		if rubric == RUBRIC_CATEGORY:
			focus_category = NON_CREATURE_CATEGORIES[rng.randi_range(0, NON_CREATURE_CATEGORIES.size() - 1)]
		if rubric == RUBRIC_BALANCED or rubric == RUBRIC_CATEGORY:
			var remaining := DEFAULT_REGULAR_CARD_COUNT - preloaded_regular_count - int(committed["regular"])
			support_target = int(committed["support"]) + remaining / 2
	var regular_count := preloaded_regular_count + int(committed["regular"])
	var legendary_count := int(committed["legendary"])
	var preferred_added := 0
	var support_added := int(committed["support"])
	while regular_count < DEFAULT_REGULAR_CARD_COUNT:
		var only_legendary := legendary_count < LEGENDARY_DECK_TARGET and rng.randf() < 0.12
		var candidates := _get_regular_candidates(god, deck_cards, only_legendary, ranked)
		if candidates.is_empty():
			if only_legendary:
				candidates = _get_regular_candidates(god, deck_cards, false, ranked)
			if candidates.is_empty():
				return false
		var wants_support := false
		if ranked:
			if rubric == RUBRIC_LEGACY:
				wants_support = support_added < RANKED_SUPPORT_CAP \
					and (support_added < 4 or rng.randf() < 0.25)
			else:
				wants_support = support_added < support_target
		var preferred_candidates := _get_preferred_regular_candidates(god, deck_cards, ranked)
		if wants_support:
			var support := candidates.filter(func(card: Card) -> bool: return card.card_type != Card.CardType.CREATURE)
			if not support.is_empty():
				if rubric == RUBRIC_CATEGORY and rng.randf() < RUBRIC_CATEGORY_BIAS:
					var focused := support.filter(func(card: Card) -> bool: return card.card_type == focus_category)
					if not focused.is_empty():
						support = focused
				candidates = support
		elif ranked:
			candidates = candidates.filter(func(card: Card) -> bool: return card.card_type == Card.CardType.CREATURE)
			if candidates.is_empty():
				candidates = _get_regular_candidates(god, deck_cards, false, ranked)
		var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
		if preferred_added < 7 and not preferred_candidates.is_empty() and rng.randf() < 0.35 \
				and (not ranked or rubric == RUBRIC_LEGACY or chosen.card_type == Card.CardType.CREATURE):
			chosen = preferred_candidates[rng.randi_range(0, preferred_candidates.size() - 1)]
			preferred_added += 1
		var copies_to_add := _get_copy_count_to_add(chosen, deck_cards)
		if copies_to_add <= 0:
			return false
		if chosen.is_legendary:
			copies_to_add = 1
		if ranked and chosen.card_type != Card.CardType.CREATURE:
			var cap := RANKED_SUPPORT_CAP if rubric == RUBRIC_LEGACY else support_target
			copies_to_add = mini(copies_to_add, maxi(1, cap - support_added))
		copies_to_add = mini(copies_to_add, DEFAULT_REGULAR_CARD_COUNT - regular_count)
		if chosen.is_legendary and legendary_count + copies_to_add > LEGENDARY_DECK_TARGET:
			continue
		deck_cards[chosen.card_name] = int(deck_cards.get(chosen.card_name, 0)) + copies_to_add
		regular_count += copies_to_add
		if chosen.card_type != Card.CardType.CREATURE:
			support_added += copies_to_add
		if chosen.is_legendary:
			legendary_count += copies_to_add
	_enforce_legendary_minimum(deck_cards, god, rng, ranked)
	return true

func _build_tiamat_brood_setup(rng: RandomNumberGenerator, brood_count: int) -> Dictionary:
	var candidates := _all_cards.filter(func(card: Card) -> bool:
		return TiamatThePrimordial.is_valid_slot_creature(card) and not card.is_single_player_card
	)
	var opening_creatures := candidates.filter(func(card: Card) -> bool:
		return card.level <= TiamatThePrimordial.MAX_SLOT_LEVEL_TOTAL and card.mana_cost == 0 \
			and card.sacrifice_cost == 0 and card.discard_cost == 0 and card.shelve_cost == 0 and card.banish_cost == 0
	)
	var slots: Array = []
	for slot_index in range(brood_count):
		var slot: Array[String] = []
		var remaining_levels := TiamatThePrimordial.MAX_SLOT_LEVEL_TOTAL
		# Give Tiamat at least one creature she can take and summon at zero mana.
		if slot_index == 0 and not opening_creatures.is_empty():
			var opener: Card = opening_creatures[rng.randi_range(0, opening_creatures.size() - 1)]
			candidates.erase(opener)
			slot.append(opener.card_name)
			remaining_levels -= opener.level
		while remaining_levels > 0:
			var fitting := candidates.filter(func(card: Card) -> bool: return card.level <= remaining_levels)
			if fitting.is_empty():
				break
			var chosen: Card = fitting[rng.randi_range(0, fitting.size() - 1)]
			candidates.erase(chosen)
			slot.append(chosen.card_name)
			remaining_levels -= chosen.level
		slots.append(slot)
	return TiamatThePrimordial.build_special_setup(slots)

func _fill_safe_powers_for_god(
	deck_cards: Dictionary,
	god: GodCard,
	rng: RandomNumberGenerator,
	ranked: bool = false,
	requested_power_count: int = -1
) -> bool:
	var desired_powers := rng.randi_range(0, MAX_POWERS) if requested_power_count < 0 else requested_power_count
	if ranked and requested_power_count < 0:
		# Ranked bot decks use every available power slot. The old minimum of two
		# made half of generated ranked decks stop at exactly two powers.
		desired_powers = MAX_POWERS
	desired_powers = clampi(desired_powers, 0, MAX_POWERS)
	var power_count := _count_power_cards(deck_cards)
	while power_count < desired_powers:
		var candidates := _get_power_candidates(god, deck_cards, ranked)
		if candidates.is_empty():
			return not ranked
		var chosen := _choose_power_for_god(candidates, god, rng)
		deck_cards[chosen.card_name] = int(deck_cards.get(chosen.card_name, 0)) + 1
		power_count += 1
	return true

func complete_ranked_power_slots(deck: Dictionary) -> Dictionary:
	if deck.is_empty():
		return deck.duplicate(true)
	var completed := audit_ranked_bot_deck(deck)
	if completed.is_empty():
		return {}
	var deck_cards: Dictionary = completed.get("cards", {}).duplicate(true)
	var god := _cards_by_name.get(str(completed.get("god_name", "")), null) as GodCard
	if god == null:
		return {}
	if TiamatThePrimordial.is_tiamat_god(god):
		return completed
	var power_count := 0
	for card_name in deck_cards:
		var template: Card = _cards_by_name.get(str(card_name), null)
		if template != null and template.is_power and not template.is_god:
			power_count += int(deck_cards[card_name])
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(str(completed.get("list_id", "")) + JSON.stringify(deck_cards)))
	while power_count < MAX_POWERS:
		var candidates := _get_power_candidates(god, deck_cards, true)
		if candidates.is_empty():
			return {}
		var chosen := _choose_power_for_god(candidates, god, rng)
		deck_cards[chosen.card_name] = int(deck_cards.get(chosen.card_name, 0)) + 1
		power_count += 1
	var validation := _validator.validate_deck(
		deck_cards,
		completed.get("special_setup", {}),
		completed.get("reinforcements", {})
	)
	if not bool(validation.get("is_valid", false)):
		return {}
	completed["cards"] = validation.get("cards", {}).duplicate(true)
	completed["special_setup"] = validation.get("special_setup", {}).duplicate(true)
	completed["reinforcements"] = validation.get("reinforcements", {}).duplicate(true)
	return completed

# Repairs historical ranked lists as well as newly built ranked decks. The
# method is deterministic for a given list/deck identity, so replaying match
# history produces the same audited list every time.
func audit_ranked_bot_deck(deck: Dictionary) -> Dictionary:
	if deck.is_empty():
		return {}
	var audited := deck.duplicate(true)
	var god := _cards_by_name.get(str(audited.get("god_name", "")), null) as GodCard
	if god == null:
		return {}
	var cards: Dictionary = audited.get("cards", {}).duplicate(true)
	if cards.is_empty():
		return {}
	_remove_culture_incompatible_cards(cards, god)
	var reinforcements: Dictionary = audited.get("reinforcements", {}).duplicate(true)
	_remove_culture_incompatible_cards(reinforcements, god)
	audited["reinforcements"] = reinforcements
	_repair_tablet_of_life_support(cards, reinforcements, god)
	# Remove ineligible cards until the remaining deck no longer has dangling
	# support relationships (e.g. a payoff removed with its last enabler).
	for _pass in range(6):
		var removed := false
		for raw_name in cards.keys():
			var card_name := str(raw_name)
			var template: Card = _cards_by_name.get(card_name, null)
			if template == null or card_name == god.card_name:
				continue
			if not _has_deckbuilding_requirements(template, cards, god):
				cards.erase(card_name)
				removed = true
		if not removed:
			break
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(str(audited.get("god_name", "")) + JSON.stringify(audited.get("cards", {}))))
	_enforce_god_specific_regular_minimums(cards, god, rng, true, reinforcements)
	_enforce_legendary_minimum(cards, god, rng, true, reinforcements)
	# Restore the standard forty-card non-power portion after pruning.
	var regular_count := _count_regular_cards(cards)
	var legendary_count := _count_regular_legendary_cards(cards)
	var attempts := 0
	while regular_count < DEFAULT_REGULAR_CARD_COUNT and attempts < MAX_RANDOM_PICK_ATTEMPTS:
		attempts += 1
		var candidates: Array[Card] = []
		for candidate in _get_regular_candidates(god, cards, false, true):
			if _has_deckbuilding_requirements(candidate, cards, god) \
					and _combined_copy_room(candidate, cards, reinforcements) > 0:
				candidates.append(candidate)
		if candidates.is_empty() and legendary_count < LEGENDARY_DECK_TARGET:
			for candidate in _get_regular_candidates(god, cards, true, true):
				if _has_deckbuilding_requirements(candidate, cards, god) \
						and _combined_copy_room(candidate, cards, reinforcements) > 0:
					candidates.append(candidate)
		if candidates.is_empty():
			return {}
		var chosen: Card = candidates[rng.randi_range(0, candidates.size() - 1)]
		var added := mini(
			_get_copy_count_to_add(chosen, cards),
			_combined_copy_room(chosen, cards, reinforcements)
		)
		added = mini(added, DEFAULT_REGULAR_CARD_COUNT - regular_count)
		if chosen.is_legendary:
			added = 1
			if legendary_count + added > LEGENDARY_DECK_TARGET:
				continue
		cards[chosen.card_name] = int(cards.get(chosen.card_name, 0)) + added
		regular_count += added
		if chosen.is_legendary:
			legendary_count += added
	# Tiamat shares the three power slots between powers and brood slots. Repair
	# historical lists to that combined limit before filling any remaining slots.
	var power_slot_capacity := MAX_POWERS
	if TiamatThePrimordial.is_tiamat_god(god):
		power_slot_capacity -= _get_tiamat_occupied_slot_count(audited.get("special_setup", {}))
	var power_count := _count_power_cards(cards)
	var excess_power_names: Array[String] = []
	for raw_name in cards.keys():
		var template: Card = _cards_by_name.get(str(raw_name), null)
		if template != null and template.is_power and not template.is_god:
			excess_power_names.append(str(raw_name))
	while power_count > power_slot_capacity and not excess_power_names.is_empty():
		var remove_index := rng.randi_range(0, excess_power_names.size() - 1)
		var remove_name := excess_power_names[remove_index]
		var remove_count := int(cards.get(remove_name, 0))
		if remove_count <= 1:
			cards.erase(remove_name)
			excess_power_names.remove_at(remove_index)
		else:
			cards[remove_name] = remove_count - 1
		power_count -= 1
	while power_count < power_slot_capacity:
		var power_candidates := _get_power_candidates(god, cards, true)
		if power_candidates.is_empty():
			break
		var chosen_power: Card = power_candidates[rng.randi_range(0, power_candidates.size() - 1)]
		cards[chosen_power.card_name] = 1
		power_count += 1
	var validation := _validator.validate_deck(
		cards,
		audited.get("special_setup", {}),
		audited.get("reinforcements", {})
	)
	if not bool(validation.get("is_valid", false)):
		return {}
	audited["cards"] = (validation.get("cards", {}) as Dictionary).duplicate(true)
	audited["special_setup"] = (validation.get("special_setup", {}) as Dictionary).duplicate(true)
	audited["reinforcements"] = (validation.get("reinforcements", {}) as Dictionary).duplicate(true)
	if audited["reinforcements"].is_empty():
		# Existing ladder lists and community submissions predate bot
		# sideboards. Derive a deterministic Reinforcement pool from the final
		# audited deck so every ranked bot — not just newly built ones — enters
		# best-of-three series with a sideboard. Same deck + god always yields
		# the same pool, keeping pool replays and fingerprints stable.
		var side_seed := absi(hash(str(audited.get("god_name", "")) + JSON.stringify(audited["cards"])))
		audited["reinforcements"] = build_reinforcements_for_deck(
			audited["cards"],
			str(audited.get("god_name", "")),
			audited["special_setup"],
			side_seed
		)
	return audited

# Tablet of Life only pays off behind a six-Ancient-creature core. Historical
# ranked lists that predate the support rule are repaired deterministically:
# the worst survey-rated regulars are swapped for the best available Ancient
# creatures, and tablets are dropped only when no legal swap remains. The
# combined main-deck and Reinforcement pool is what the support rule counts,
# so a tablet sideboarded by an existing list is repaired by the same swap.
func _repair_tablet_of_life_support(cards: Dictionary, reinforcements: Dictionary, god: GodCard) -> void:
	var tablet_count := int(cards.get(TABLET_OF_LIFE_CARD_NAME, 0)) \
		+ int(reinforcements.get(TABLET_OF_LIFE_CARD_NAME, 0))
	if tablet_count <= 0:
		return
	var combined := cards.duplicate(true)
	for side_name in reinforcements.keys():
		combined[str(side_name)] = int(combined.get(str(side_name), 0)) + int(reinforcements[side_name])
	var deficit := TABLET_OF_LIFE_MIN_ANCIENT_CREATURES - _count_ancient_creatures(combined)
	if deficit <= 0:
		return
	var cut_order := _tablet_repair_cut_order(cards)
	var add_order := _ancient_repair_add_order(god, combined)
	for _swap in range(deficit):
		var placed := false
		for add_name in add_order:
			var add_card: Card = _cards_by_name.get(add_name, null)
			if add_card == null or int(combined.get(add_name, 0)) >= _max_copies(add_card):
				continue
			for cut_name in cut_order:
				if not _tablet_swap_preserves_support(cards, cut_name, add_name, god):
					continue
				cards[cut_name] = int(cards.get(cut_name, 0)) - 1
				if int(cards[cut_name]) <= 0:
					cards.erase(cut_name)
				cards[add_name] = int(cards.get(add_name, 0)) + 1
				combined[cut_name] = int(combined.get(cut_name, 0)) - 1
				combined[add_name] = int(combined.get(add_name, 0)) + 1
				placed = true
				break
			if placed:
				break
		if not placed:
			break
	if TABLET_OF_LIFE_MIN_ANCIENT_CREATURES - _count_ancient_creatures(_combined_main_and_side_counts(cards, reinforcements)) > 0:
		cards.erase(TABLET_OF_LIFE_CARD_NAME)
		reinforcements.erase(TABLET_OF_LIFE_CARD_NAME)

# Cut order for tablet support repair: lowest survey rating first, extra
# copies of a rated card before lone copies, then name order for determinism.
# Ancient creatures are never cut (they are the support being added), and
# powers are kept out of the cut pool entirely.
func _tablet_repair_cut_order(cards: Dictionary) -> Array[String]:
	var cut_candidates: Array[Dictionary] = []
	for raw_name in cards.keys():
		var card_name := str(raw_name)
		var template: Card = _cards_by_name.get(card_name, null)
		if template == null or template.is_god or template.is_power:
			continue
		if card_name == TABLET_OF_LIFE_CARD_NAME:
			continue
		if template.card_type == Card.CardType.CREATURE and str(template.culture).strip_edges() == "Ancient":
			continue
		cut_candidates.append({
			"name": card_name,
			"copies": int(cards[card_name]),
			"rating": BotSideboardRatingsScript.rating_for(card_name),
		})
	cut_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["rating"]) != int(b["rating"]):
			return int(a["rating"]) < int(b["rating"])
		if int(a["copies"]) != int(b["copies"]):
			return int(a["copies"]) > int(b["copies"])
		return str(a["name"]) < str(b["name"]))
	var order: Array[String] = []
	for entry in cut_candidates:
		order.append(str(entry["name"]))
	return order

# Add order for tablet support repair: best-ranked ranked-legal Ancient
# creature first, with more copy room and then name order as tiebreakers so
# the same list always audits to the same result.
func _ancient_repair_add_order(god: GodCard, combined: Dictionary) -> Array[String]:
	var add_candidates: Array[Dictionary] = []
	for template in _all_cards:
		if template == null or template.is_god or template.is_power or template.is_token:
			continue
		if template.is_legendary or template.is_single_player_card:
			continue
		if template.card_type != Card.CardType.CREATURE or str(template.culture).strip_edges() != "Ancient":
			continue
		if not _is_card_compatible_with_god(template, god):
			continue
		add_candidates.append({
			"name": str(template.card_name),
			"rating": BotSideboardRatingsScript.rating_for(str(template.card_name)),
			"room": maxi(0, _max_copies(template) - int(combined.get(str(template.card_name), 0))),
		})
	add_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["rating"]) != int(b["rating"]):
			return int(a["rating"]) > int(b["rating"])
		if int(a["room"]) != int(b["room"]):
			return int(a["room"]) > int(b["room"])
		return str(a["name"]) < str(b["name"]))
	var order: Array[String] = []
	for entry in add_candidates:
		order.append(str(entry["name"]))
	return order

# A repair swap must not strand any other card's support requirement. Tablet
# of Life itself is skipped here because the repair's whole point is to bring
# its support up to threshold across several swaps.
func _tablet_swap_preserves_support(cards: Dictionary, victim_name: String, add_name: String, god: GodCard) -> bool:
	var victim_count := int(cards.get(victim_name, 0))
	if victim_count <= 0:
		return false
	var trial_cards: Dictionary = cards.duplicate(true)
	if victim_count <= 1:
		trial_cards.erase(victim_name)
	else:
		trial_cards[victim_name] = victim_count - 1
	trial_cards[add_name] = int(trial_cards.get(add_name, 0)) + 1
	for raw_name in trial_cards:
		var card_name := str(raw_name)
		if card_name == god.card_name or card_name == TABLET_OF_LIFE_CARD_NAME:
			continue
		var template: Card = _cards_by_name.get(card_name, null)
		if template != null and not _has_deckbuilding_requirements(template, trial_cards, god):
			return false
	return true

func _combined_main_and_side_counts(cards: Dictionary, side: Dictionary) -> Dictionary:
	var combined := cards.duplicate(true)
	for side_name in side.keys():
		combined[str(side_name)] = int(combined.get(str(side_name), 0)) + int(side[side_name])
	return combined

## Deterministically builds a Reinforcement (sideboard) pool for a finished
## deck. Fills up to the validator's reinforcement limit with ranked-legal
## candidates, weighting picks toward matchup hate tags the main deck does not
## already cover, while still randomizing through the seed so two similar decks
## sideboard differently.
func build_reinforcements_for_deck(
	cards: Dictionary,
	god_name: String,
	special_setup: Dictionary = {},
	seed_value: int = 0
) -> Dictionary:
	var god := _cards_by_name.get(str(god_name), null) as GodCard
	if god == null or cards.is_empty():
		return {}
	var regular_count := _count_regular_cards(cards)
	var power_count := _count_power_cards(cards)
	var limit := DeckValidatorScript.get_reinforcement_limit(regular_count, power_count)
	if limit <= 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_value) if seed_value != 0 else absi(hash(str(god_name) + JSON.stringify(cards)))
	var coverage := BotSideboardPolicyScript.main_deck_tag_coverage(cards)
	var knowledge_sources := BotSideboardPolicyScript.count_hand_knowledge_sources(cards)
	var combined: Dictionary = cards.duplicate(true)
	var reinforcements: Dictionary = {}
	var order: Array = []
	var total := 0
	var attempts := 0
	while total < limit and attempts < limit * 12:
		attempts += 1
		var candidates: Array[Card] = []
		var weights: Array[float] = []
		for template in _all_cards:
			if not _is_sideboard_candidate(template, god, combined):
				continue
			candidates.append(template)
			weights.append(_sideboard_pick_weight(template, coverage, rng, knowledge_sources))
		if candidates.is_empty():
			break
		var chosen := _weighted_pick_index(weights, rng)
		var chosen_card := candidates[chosen]
		var name := str(chosen_card.card_name)
		reinforcements[name] = int(reinforcements.get(name, 0)) + 1
		combined[name] = int(combined.get(name, 0)) + 1
		if not order.has(name):
			order.append(name)
		total += 1
	if reinforcements.is_empty():
		return {}
	# The validator is the last word on legality. If a combination trips a
	# support or culture rule, drop the most recently added entry and retry.
	for _trim in range(order.size()):
		var validation := _validator.validate_deck(cards, special_setup, reinforcements)
		if bool(validation.get("is_valid", false)):
			return (validation.get("reinforcements", {}) as Dictionary).duplicate(true)
		var last_name := str(order.back())
		order.pop_back()
		var remaining := int(reinforcements.get(last_name, 0)) - 1
		if remaining <= 0:
			reinforcements.erase(last_name)
		else:
			reinforcements[last_name] = remaining
		if reinforcements.is_empty():
			return {}
	return {}

func _is_sideboard_candidate(card: Card, god: GodCard, combined: Dictionary) -> bool:
	if card == null or card.is_god or card.is_power or card.is_single_player_card or card.is_token:
		return false
	# Legendary sideboard copies would fail the main-deck legendary cap the
	# moment a swap brings them in, so bots keep them out entirely.
	if card.is_legendary:
		return false
	if int(combined.get(card.card_name, 0)) >= _max_copies(card):
		return false
	if not _is_card_compatible_with_god(card, god):
		return false
	return _has_deckbuilding_requirements(card, combined, god)

func _sideboard_pick_weight(card: Card, coverage: Dictionary, rng: RandomNumberGenerator, knowledge_sources: int = 0) -> float:
	var weight := 1.0
	var tags := BotSideboardPolicyScript.hate_tags_for_card(card)
	if not tags.is_empty():
		var uncovered := false
		for tag in tags:
			if int(coverage.get(tag, 0)) < BotSideboardPolicyScript.MAIN_DECK_COVERED_THRESHOLD:
				uncovered = true
				break
		weight = 2.5 if uncovered else 0.4
		if str(card.card_name).strip_edges() == "Compelled by the Secret Name" \
				and knowledge_sources >= 2:
			# Multiple ways to know the opponent's hand guarantee
			# declarations, so the charm stays on-plan even when the deck
			# already covers its tag.
			weight = 2.5
	return weight * (0.5 + rng.randf())

func _weighted_pick_index(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for weight in weights:
		total += maxf(0.0, weight)
	if total <= 0.0:
		return rng.randi_range(0, weights.size() - 1)
	var roll := rng.randf() * total
	for index in range(weights.size()):
		roll -= maxf(0.0, weights[index])
		if roll <= 0.0:
			return index
	return weights.size() - 1

func _get_tiamat_occupied_slot_count(special_setup) -> int:
	var occupied := 0
	for slot_cards in TiamatThePrimordial.get_slot_card_names_from_setup(special_setup):
		if slot_cards is Array and not slot_cards.is_empty():
			occupied += 1
	return occupied

func _count_regular_cards(cards: Dictionary) -> int:
	var total := 0
	for name in cards:
		var card: Card = _cards_by_name.get(str(name), null)
		if card != null and not card.is_god and not card.is_power:
			total += int(cards[name])
	return total

# DeckValidator counts only regular cards toward the legendary cap, so powers
# such as Ragnarok must not consume one of the four regular-card slots.
func _count_regular_legendary_cards(cards: Dictionary) -> int:
	var total := 0
	for name in cards:
		var card: Card = _cards_by_name.get(str(name), null)
		if card != null and card.is_legendary and not card.is_god and not card.is_power:
			total += int(cards[name])
	return total

func _count_power_cards(cards: Dictionary) -> int:
	var total := 0
	for name in cards:
		var card: Card = _cards_by_name.get(str(name), null)
		if card != null and card.is_power and not card.is_god:
			total += int(cards[name])
	return total

func _has_deckbuilding_requirements(card: Card, cards: Dictionary, god: GodCard) -> bool:
	if card == null:
		return false
	var name := card.card_name
	match name:
		"Durinn Secondborn":
			return _count_card_type(cards, Card.CardType.EQUIPMENT) >= 3
		"Circle of Rebirth":
			return _count_matching_any(cards, ["Animal", "Plant"]) >= 5
		"Tablet of Life":
			return _count_ancient_creatures(cards) >= TABLET_OF_LIFE_MIN_ANCIENT_CREATURES
		"Sixth Sage An-Enlilda":
			return _count_ancient_dwelling_targets(cards) >= 2
		"Robotic Footsoldier":
			return _count_other_matching(cards, card, ["Machine"]) >= 2
		"Isimud":
			return _count_other_matching(cards, card, ["Divine Manifestation"]) >= 3
		"Fourth Sage Enmegalamma":
			return _count_other_matching(cards, card, ["Mer", "Sage"]) >= 3
		"Beyla":
			return _count_named(cards, ["Berserker", "Gidim Ensi"]) >= 3 or int(cards.get("Berserker Mead", 0)) > 0
		"Byggvir":
			return _count_tagged(cards, "Mead") > 0
		"Tatzelwurm":
			return _count_other_matching(cards, card, ["Dragon"]) > 0
		"Caleuche, the Ghost Ship":
			return _count_other_matching(cards, card, ["Spirit"]) >= 2 or (god.card_name == "Freyja" and _count_matching(cards, ["Norse", "Warrior"]) >= 2)
		"E2-abzu":
			return _count_matching(cards, ["Mer"]) >= 2
		"Walk of the Sage":
			return _walk_of_the_sage_has_payoff(cards)
		"Huginn": return _count_tagged(cards, "Hex") > 0
		"Muninn": return _count_tagged(cards, "Charm") > 0
		"Wild Magic":
			return _count_card_type(cards, Card.CardType.SPELL) + _count_card_type(cards, Card.CardType.HEX) \
				+ _count_card_type(cards, Card.CardType.CHARM) > int(cards.get(name, 0))
		"Apollyon's Demiurge": return _count_matching(cards, ["Demon"]) >= 3
		"Key of Solomon": return _key_of_solomon_has_support(cards)
		"Eridu, City of Sages": return _count_matching(cards, ["Mage"]) >= 3
		"Advanced Building Techniques": return _count_card_type(cards, Card.CardType.STRUCTURE) >= 2
		"Immortal Techniques":
			return _count_matching(cards, ["Mage"]) > 0 \
				and _count_card_type(cards, Card.CardType.SPELL) + _count_card_type(cards, Card.CardType.HEX) > 0
		"A Cost to Walk the Worlds": return _count_named(cards, VOID_SOURCE_CARD_NAMES) > 0
		"Vision of Tartarus": return _vision_of_tartarus_has_void_sources(cards)
		"Allfather's Sacrifice": return _count_tagged(cards, "Spell") > 0
		"Giant Master Architect": return _count_tagged(cards, "Structure") > 0
		"Wolf Cub": return _count_other_matching(cards, card, ["Lupine"], 4) > 0
		"Wolf Adolescent": return _count_other_matching(cards, card, ["Lupine"], 5) > 0
		"Hringhorni": return _count_other_matching(cards, card, ["Norse", "Warrior"]) > 0
		"Harii Jarl": return _count_other_matching(cards, card, ["Harii"]) > 0
		"Harii Shaman": return _count_matching(cards, ["Norse", "Warrior"]) + _count_matching(cards, ["Animal"]) > 0
		"Gungnir, the Spear of Odin": return _count_matching(cards, ["Norse", "Warrior"]) > 0
		"Gambanteinn": return _restricted_equipment_has_bearers(card, cards)
		"Breidablik": return _count_matching(cards, ["Priest"]) > 0
		"Tonal Extraction":
			for name_in_deck in cards:
				var target := _cards_by_name.get(name_in_deck) as Card
				if int(cards[name_in_deck]) > 0 and target != null and target.card_type == Card.CardType.CREATURE \
						and not target.is_god and target.has_type("Shapeshifter") \
						and not target.get_tonal_extraction_spirit_profile().is_empty():
					return true
			return false
		"Fire and Gold": return _count_matching(cards, ["Tian", "Dragon"]) > 0
		"Call of the Valkyrie": return _count_matching(cards, ["Norse", "Warrior"]) > 0
		"Myrkwood": return _count_matching(cards, ["Animal"]) >= 2
		"Hunting Tactics": return _has_hunting_tactics_pair(cards)
		"Norse Bloodlust": return _count_matching(cards, ["Norse", "Warrior"]) > 0 and _count_matching(cards, ["Lupine"]) > 0
		"Rally the Troops": return _count_matching(cards, ["Warrior"]) >= 6 and _count_matching(cards, ["Warrior"], 5) > 0
		"Raven Storm": return _count_matching(cards, ["Norse", "Warrior"]) + _count_matching(cards, ["Lupine"]) > 0
		"Fifa the Magical Arrow": return _count_matching(cards, ["Warrior"]) > 0
	# Equipment that restricts which creatures can bear it (e.g. Gambanteinn,
	# Sharur) is only worth adding with enough legal bearers in the deck.
	if not _restricted_equipment_has_bearers(card, cards):
		return false
	if card.is_power and BotCardStrategyScript.PASSIVE_TYPES.has(BotCardStrategyScript.key(card)) \
			and name not in ["Rally the Troops", "Norse Bloodlust", "Hunting Tactics", "Myrkwood"]:
		var matching_creatures := 0
		for candidate_name in cards:
			var candidate: Card = _cards_by_name.get(str(candidate_name), null)
			if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god:
				continue
			for type in BotCardStrategyScript.PASSIVE_TYPES[BotCardStrategyScript.key(card)]:
				if candidate.has_type(str(type)):
					matching_creatures += int(cards[candidate_name])
					break
		if matching_creatures < 6:
			return false
	return true

func _count_tagged(cards: Dictionary, tag: String) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate != null and not candidate.is_god and candidate.has_type(tag):
			total += int(cards[name])
	return total

func _count_card_type(cards: Dictionary, card_type: Card.CardType) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate != null and not candidate.is_god and candidate.card_type == card_type:
			total += int(cards[name])
	return total

func _count_named(cards: Dictionary, names: Array) -> int:
	var total := 0
	for name in names:
		total += int(cards.get(name, 0))
	return total

func _count_matching(cards: Dictionary, tags: Array, minimum_level: int = 0) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god or candidate.level < minimum_level:
			continue
		var matches := true
		for tag in tags:
			if not candidate.has_type(str(tag)):
				matches = false
				break
		if matches:
			total += int(cards[name])
	return total

func _count_other_matching(cards: Dictionary, source: Card, tags: Array, maximum_level: int = 0) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god or candidate == source:
			continue
		if maximum_level > 0 and candidate.level > maximum_level:
			continue
		var matches := true
		for tag in tags:
			if not candidate.has_type(str(tag)):
				matches = false
				break
		if matches:
			total += int(cards[name])
	return total

func _count_matching_any(cards: Dictionary, tags: Array) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god:
			continue
		for tag in tags:
			if candidate.has_type(str(tag)):
				total += int(cards[name])
				break
	return total

# Ancient-culture creatures (Tablet of Life's resurrection pool).
func _count_ancient_creatures(cards: Dictionary) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god:
			continue
		if str(candidate.culture).strip_edges() != "Ancient":
			continue
		total += int(cards[name])
	return total

# Key of Solomon needs Animals to sacrifice and Demons in the grave/abyss to
# return, so only add it once the deck has enough of both.
func _key_of_solomon_has_support(cards: Dictionary) -> bool:
	return _count_matching(cards, ["Animal"]) >= KEY_OF_SOLOMON_MIN_SOURCES \
		and _count_matching(cards, ["Demon"]) >= KEY_OF_SOLOMON_MIN_TARGETS

# Vision of Tartarus needs creatures in either Void to matter, so only add it
# once the deck has enough cards that send creatures there.
func _vision_of_tartarus_has_void_sources(cards: Dictionary) -> bool:
	return _count_named(cards, VOID_SOURCE_CARD_NAMES) >= VISION_OF_TARTARUS_MIN_VOID_SOURCES

# Mirrors SixthSageAnEnlilda's Ancient Dwelling target rule for deck templates.
func _count_ancient_dwelling_targets(cards: Dictionary) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.STRUCTURE or not candidate.has_type("Dwelling"):
			continue
		if candidate.culture.strip_edges() == "Ancient":
			total += int(cards[name])
	return total

# Equipment counts as bearer-restricted when it refuses at least one creature
# that could otherwise receive equipment. Template can_equip_to calls are pure
# type checks, so this is safe to run once against the catalog at init.
func _build_restricted_equipment_lookup() -> void:
	for equipment in _all_cards:
		if equipment == null or equipment.card_type != Card.CardType.EQUIPMENT:
			continue
		for candidate in _all_cards:
			if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god:
				continue
			if not candidate.can_receive_equipment():
				continue
			if not equipment.can_equip_to(candidate):
				_restricted_equipment_lookup[equipment.card_name] = true
				break

func _restricted_equipment_has_bearers(card: Card, cards: Dictionary) -> bool:
	if card == null or card.card_type != Card.CardType.EQUIPMENT:
		return true
	if not _restricted_equipment_lookup.has(card.card_name):
		return true
	var bearers := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god:
			continue
		if card.can_equip_to(candidate):
			bearers += int(cards[name])
	return bearers >= 4

func _walk_of_the_sage_has_payoff(cards: Dictionary) -> bool:
	var has_mage := _count_matching(cards, ["Mage"]) > 0
	if not has_mage:
		return false
	var has_abzu_payoff := int(cards.get("E2-abzu", 0)) > 0 and _deck_has_mer_mage(cards)
	var has_sage_payoff := int(cards.get("Seventh Sage Utuabzu", 0)) > 0 and _count_matching(cards, ["Ancient", "Mage", "Sage"]) > 1
	var has_vision_payoff := int(cards.get("Vision of Tartarus", 0)) > 0 and _count_matching(cards, ["Mage"]) > 0
	return has_abzu_payoff or has_sage_payoff or has_vision_payoff

func _has_hunting_tactics_pair(cards: Dictionary) -> bool:
	var attackers := 0
	var supporters := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god:
			continue
		var count := int(cards[name])
		if candidate.has_type("Lupine") or (candidate.culture == "Norse" and candidate.has_type("Human") and candidate.has_type("Warrior")):
			attackers += count
		if candidate.card_name == "Huginn" or candidate.card_name == "Muninn" or candidate.has_type("Lupine"):
			supporters += count
	return attackers > 0 and supporters > 0 and (attackers > 1 or supporters > 1)

func _get_regular_candidates(god: GodCard, deck_cards: Dictionary, legendary_only: bool, ranked: bool = false) -> Array[Card]:
	var candidates: Array[Card] = []
	for template in _all_cards:
		if not _is_safe_regular_card(template, god, deck_cards, legendary_only, ranked):
			continue
		candidates.append(template)
	return candidates

func _get_preferred_regular_candidates(god: GodCard, deck_cards: Dictionary, ranked: bool = false) -> Array[Card]:
	var candidates: Array[Card] = []
	if god == null:
		return candidates
	for template in _all_cards:
		if not _is_safe_regular_card(template, god, deck_cards, false, ranked):
			continue
		if _is_preferred_card_for_god(template, god):
			candidates.append(template)
	return candidates

func _get_power_candidates(god: GodCard, deck_cards: Dictionary, ranked: bool = false) -> Array[Card]:
	var candidates: Array[Card] = []
	for template in _all_cards:
		if template == null or not template.is_power or template.is_god:
			continue
		var aphrodite_shift := template is AspectShift and god is AphroditeAreia
		if int(deck_cards.get(template.card_name, 0)) >= 1:
			continue
		if not _is_card_compatible_with_god(template, god):
			continue
		if template is TakeTheField and not _can_use_take_the_field(god):
			continue
		if template is AspectShift and not aphrodite_shift \
				and (not god is Hermes or _count_matching(deck_cards, ["Ghost"]) == 0):
			continue
		if (ranked or template is TonalExtraction) and not _has_deckbuilding_requirements(template, deck_cards, god):
			continue
		candidates.append(template)
	return candidates

func _choose_power_for_god(candidates: Array[Card], god: GodCard, rng: RandomNumberGenerator) -> Card:
	if god is TezcatlipocaTheSmokingMirror:
		for power in candidates:
			if power is TonalExtraction:
				return power
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _is_safe_regular_card(card: Card, god: GodCard, deck_cards: Dictionary, legendary_only: bool, ranked: bool = false) -> bool:
	if card == null or card.is_god or card.is_power or card.is_single_player_card:
		return false
	if legendary_only and not card.is_legendary:
		return false
	if not legendary_only and card.is_legendary:
		return false
	if int(deck_cards.get(card.card_name, 0)) >= _max_copies(card):
		return false
	if card.card_name == "Key of Solomon" and not _key_of_solomon_has_support(deck_cards):
		return false
	if card.card_name == "Vision of Tartarus" and not _vision_of_tartarus_has_void_sources(deck_cards):
		return false
	if ranked and not _has_deckbuilding_requirements(card, deck_cards, god):
		return false
	return _is_card_compatible_with_god(card, god)

func _deck_has_mer_mage(deck_cards: Dictionary) -> bool:
	for card_name in deck_cards:
		if int(deck_cards[card_name]) <= 0:
			continue
		var card: Card = _cards_by_name.get(str(card_name))
		if card != null and card.card_type == Card.CardType.CREATURE \
				and card.has_type("Mer") and card.has_type("Mage"):
			return true
	return false

func _is_card_compatible_with_god(card: Card, god: GodCard) -> bool:
	if card == null or god == null or card.is_god:
		return true
	if card is ActiveGodCard:
		return god.get_active_god_deck_role(card as ActiveGodCard) == GodCard.ACTIVE_GOD_DECK_ROLE_ALLOWED
	if god.uses_culture_locked_deckbuilding():
		return god.can_include_card_in_culture_locked_deck(card)
	if card.is_power and not card.is_god:
		return str(card.culture).strip_edges() == "Neutral" or str(card.culture).strip_edges() == str(god.culture).strip_edges()
	return true

func _can_use_take_the_field(god: GodCard) -> bool:
	# Tezcatlipoca's own summon also transfers the sacrifices to Titlacauan.
	if god is TezcatlipocaTheSmokingMirror or not god.can_autofill_take_the_field():
		return false
	return _all_cards.any(func(card: Card) -> bool:
		return card is ActiveGodCard and god.is_own_active_god_card(card)
	)

func _is_preferred_card_for_god(card: Card, god: GodCard) -> bool:
	if card == null or god == null:
		return false
	match god.card_name:
		"Thor", "Freyja":
			return card.has_type("Warrior") and card.culture == "Norse"
		"Tezcatlipoca, the Smoking Mirror":
			return card.has_type("Shapeshifter")
		"Cernunnos":
			return _is_level_5_or_higher_animal(card)
		_:
			return false

func _get_copy_count_to_add(card: Card, deck_cards: Dictionary) -> int:
	if card == null:
		return 0
	var current_count := int(deck_cards.get(card.card_name, 0))
	var remaining_copies := maxi(0, _max_copies(card) - current_count)
	if remaining_copies <= 0:
		return 0
	if card.card_name == "Hyena Pack":
		return remaining_copies
	return 1

# Reinforcements share the main deck's copy limit. Audit repairs must not add
# a third/fourth main-deck copy when the sideboard already holds the remainder.
func _combined_copy_room(card: Card, deck_cards: Dictionary, sideboard: Dictionary) -> int:
	if card == null:
		return 0
	var combined_count := int(deck_cards.get(card.card_name, 0)) \
		+ int(sideboard.get(card.card_name, 0))
	return maxi(0, _max_copies(card) - combined_count)

func _max_copies(card: Card) -> int:
	if card == null:
		return 0
	if card.is_god or card.is_power or card is ActiveGodCard or card.is_legendary:
		return 1
	return 3
