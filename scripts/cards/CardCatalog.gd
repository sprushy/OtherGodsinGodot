extends RefCounted
class_name CardCatalog

const CARDS_DIR := "res://scripts/cards/"
const EXCLUDED_FILENAMES := [
	"BaseCard.gd",
	"ActiveGodCard.gd",
	"card.gd",
	"CardCatalog.gd",
	"CharmCard.gd",
	"CreatureCard.gd",
	"Deck.gd",
	"EquipmentCard.gd",
	"GenericCreature.gd",
	"GodCard.gd",
	"HexCard.gd",
	"PermanentHexCard.gd",
	"PowerCard.gd",
	"SpellCard.gd",
	"StructureCard.gd"
]
const CARD_SCRIPT_PATHS := [
	"res://scripts/cards/Charms/DivineLightning.gd",
	"res://scripts/cards/Charms/Exorcism.gd",
	"res://scripts/cards/Charms/FifaTheMagicalArrow.gd",
	"res://scripts/cards/Charms/GungnirTheSpearOfOdin.gd",
	"res://scripts/cards/Charms/HeavySnow.gd",
	"res://scripts/cards/Charms/HeroicStand.gd",
	"res://scripts/cards/Charms/Hringhorni.gd",
	"res://scripts/cards/Charms/MeadOfPoetry.gd",
	"res://scripts/cards/Charms/NamburbiApotropaeon.gd",
	"res://scripts/cards/Charms/Storm.gd",
	"res://scripts/cards/ActiveGods/BaldrActive.gd",
	"res://scripts/cards/ActiveGods/DellingrActive.gd",
	"res://scripts/cards/ActiveGods/FreyjaActive.gd",
	"res://scripts/cards/ActiveGods/GuanYuActive.gd",
	"res://scripts/cards/ActiveGods/HermesActive.gd",
	"res://scripts/cards/ActiveGods/MummuActive.gd",
	"res://scripts/cards/ActiveGods/NuskuActive.gd",
	"res://scripts/cards/ActiveGods/TezcatlipocaActive.gd",
	"res://scripts/cards/ActiveGods/ThorActive.gd",
	"res://scripts/cards/ActiveGods/TiamatActive.gd",
	"res://scripts/cards/Creatures/AgainWalker.gd",
	"res://scripts/cards/Creatures/Afanc.gd",
	"res://scripts/cards/Creatures/Alu.gd",
	"res://scripts/cards/Creatures/AnkouServantToTheReaper.gd",
	"res://scripts/cards/Creatures/AnTheBowbender.gd",
	"res://scripts/cards/Creatures/Anzu.gd",
	"res://scripts/cards/Creatures/AsagTheDestroyer.gd",
	"res://scripts/cards/Creatures/Asakku.gd",
	"res://scripts/cards/Creatures/Asaruludu.gd",
	"res://scripts/cards/Creatures/Askelladen.gd",
	"res://scripts/cards/Creatures/Aurboda.gd",
	"res://scripts/cards/Creatures/Berserker.gd",
	"res://scripts/cards/Creatures/Beyla.gd",
	"res://scripts/cards/Creatures/BlessedKnights.gd",
	"res://scripts/cards/Creatures/BrownBear.gd",
	"res://scripts/cards/Creatures/Byggvir.gd",
	"res://scripts/cards/Creatures/Caleuche.gd",
	"res://scripts/cards/Creatures/Capricorn.gd",
	"res://scripts/cards/Creatures/ClayEaters.gd",
	"res://scripts/cards/Creatures/CombatMech.gd",
	"res://scripts/cards/Creatures/DevastatorMech.gd",
	"res://scripts/cards/Creatures/DraugRevenant.gd",
	"res://scripts/cards/Creatures/DurinnSecondborn.gd",
	"res://scripts/cards/Creatures/Edimmu.gd",
	"res://scripts/cards/Creatures/EnHeduAnna.gd",
	"res://scripts/cards/Creatures/Enkidu.gd",
	"res://scripts/cards/Creatures/EnkiLordOfEridu.gd",
	"res://scripts/cards/Creatures/ErlqueensNightingale.gd",
	"res://scripts/cards/Creatures/Fenrir.gd",
	"res://scripts/cards/Creatures/FirstSageAdapa.gd",
	"res://scripts/cards/Creatures/FourthSageEnmegalamma.gd",
	"res://scripts/cards/Creatures/GalaTura.gd",
	"res://scripts/cards/Creatures/Gallu.gd",
	"res://scripts/cards/Creatures/Garm.gd",
	"res://scripts/cards/Creatures/Gawain.gd",
	"res://scripts/cards/Creatures/GiantMasterArchitect.gd",
	"res://scripts/cards/Creatures/GidimEnsi.gd",
	"res://scripts/cards/Creatures/Gilgamesh.gd",
	"res://scripts/cards/Creatures/Grindylow.gd",
	"res://scripts/cards/Creatures/GududPriest.gd",
	"res://scripts/cards/Creatures/GugalannaBullOfHeaven.gd",
	"res://scripts/cards/Creatures/Gullinbursti.gd",
	"res://scripts/cards/Creatures/HabrokParagonOfHawks.gd",
	"res://scripts/cards/Creatures/HariiFransiscan.gd",
	"res://scripts/cards/Creatures/HariiJarl.gd",
	"res://scripts/cards/Creatures/HariiShaman.gd",
	"res://scripts/cards/Creatures/HariiWarrior.gd",
	"res://scripts/cards/Creatures/ValkyrieWarrior.gd",
	"res://scripts/cards/Creatures/Hati.gd",
	"res://scripts/cards/Creatures/HelBlarDraug.gd",
	"res://scripts/cards/Creatures/Hrimgrimmnir.gd",
	"res://scripts/cards/Creatures/Huginn.gd",
	"res://scripts/cards/Creatures/HumbabaTheTerrible.gd",
	"res://scripts/cards/Creatures/HyenaPack.gd",
	"res://scripts/cards/Creatures/Isimud.gd",
	"res://scripts/cards/Creatures/JiangZiyaFisherOfKings.gd",
	"res://scripts/cards/Creatures/Jiaolong.gd",
	"res://scripts/cards/Creatures/TianlongHolyDragon.gd",
	"res://scripts/cards/Creatures/PaiLongAutumnKing.gd",
	"res://scripts/cards/Creatures/KurJara.gd",
	"res://scripts/cards/Creatures/Lailoken.gd",
	"res://scripts/cards/Creatures/Lamashatu.gd",
	"res://scripts/cards/Creatures/LesserMushussu.gd",
	"res://scripts/cards/Creatures/Lindwyrm.gd",
	"res://scripts/cards/Creatures/LowLightTroll.gd",
	"res://scripts/cards/Creatures/Lugalbanda.gd",
	"res://scripts/cards/Creatures/MalinalxochitlAcolyte.gd",
	"res://scripts/cards/Creatures/MalinalxochitlThrall.gd",
	"res://scripts/cards/Creatures/MasmassuPriest.gd",
	"res://scripts/cards/Creatures/MinotaurFootsoldier.gd",
	"res://scripts/cards/Creatures/Mopsus.gd",
	"res://scripts/cards/Creatures/Muninn.gd",
	"res://scripts/cards/Creatures/NergalLion.gd",
	"res://scripts/cards/Creatures/Nagual.gd",
	"res://scripts/cards/Creatures/Nimue.gd",
	"res://scripts/cards/Creatures/Pegasus.gd",
	"res://scripts/cards/Creatures/PictishBeast.gd",
	"res://scripts/cards/Creatures/Pazuzu.gd",
	"res://scripts/cards/Creatures/RedCap.gd",
	"res://scripts/cards/Creatures/RabidWolf.gd",
	"res://scripts/cards/Creatures/Rabisu.gd",
	"res://scripts/cards/Creatures/RavenStorm.gd",
	"res://scripts/cards/Creatures/RoboticFootsoldier.gd",
	"res://scripts/cards/Creatures/ScorpionManArcher.gd",
	"res://scripts/cards/Creatures/ScorpionManWarrior.gd",
	"res://scripts/cards/Creatures/SevenHeadedSerpent.gd",
	"res://scripts/cards/Creatures/SeventhSageUtuabzu.gd",
	"res://scripts/cards/Creatures/SixthSageAnEnlilda.gd",
	"res://scripts/cards/Creatures/Skoll.gd",
	"res://scripts/cards/Creatures/SoldierOfTheBlackEmperor.gd",
	"res://scripts/cards/Creatures/StoneInfant.gd",
	"res://scripts/cards/Creatures/StoneMonkey.gd",
	"res://scripts/cards/Creatures/SulakTheUnclean.gd",
	"res://scripts/cards/Creatures/Tatzelwurm.gd",
	"res://scripts/cards/Creatures/TelchineApprentice.gd",
	"res://scripts/cards/Creatures/TezcatlipocaBlasphemer.gd",
	"res://scripts/cards/Creatures/TheWhiteSerpent.gd",
	"res://scripts/cards/Creatures/Thiazi.gd",
	"res://scripts/cards/Creatures/ThirdSageEnmedugga.gd",
	"res://scripts/cards/Creatures/TitanicMech.gd",
	"res://scripts/cards/Creatures/UriskGrovekeepers.gd",
	"res://scripts/cards/Creatures/WarriorDragon.gd",
	"res://scripts/cards/Creatures/WhiteStag.gd",
	"res://scripts/cards/Creatures/WingedLion.gd",
	"res://scripts/cards/Creatures/WolfCub.gd",
	"res://scripts/cards/Creatures/WolfAdolescent.gd",
	"res://scripts/cards/Equipment/BeardedAxe.gd",
	"res://scripts/cards/Equipment/DraupnirTheMultiplying.gd",
	"res://scripts/cards/Equipment/Gambanteinn.gd",
	"res://scripts/cards/Equipment/ReedBow.gd",
	"res://scripts/cards/Equipment/SevenLeagueBoots.gd",
	"res://scripts/cards/Equipment/RunicShortsword.gd",
	"res://scripts/cards/Equipment/SharurTheFlyingMace.gd",
	"res://scripts/cards/Gods/AphroditeAreia.gd",
	"res://scripts/cards/Gods/Baldr.gd",
	"res://scripts/cards/Gods/Cernunnos.gd",
	"res://scripts/cards/Gods/DellingrTheDayspring.gd",
	"res://scripts/cards/Gods/Freyja.gd",
	"res://scripts/cards/Gods/GuanYu.gd",
	"res://scripts/cards/Gods/Hermes.gd",
	"res://scripts/cards/Gods/ManannanMacLir.gd",
	"res://scripts/cards/Gods/Mummu.gd",
	"res://scripts/cards/Gods/NuskuFirebearer.gd",
	"res://scripts/cards/Gods/Odin.gd",
	"res://scripts/cards/Gods/TiamatThePrimordial.gd",
	"res://scripts/cards/Gods/TezcatlipocaTheSmokingMirror.gd",
	"res://scripts/cards/Gods/Thor.gd",
	"res://scripts/cards/Hexes/Banishment.gd",
	"res://scripts/cards/Hexes/Dromi.gd",
	"res://scripts/cards/Hexes/Gleipnir.gd",
	"res://scripts/cards/Hexes/SepLemutti.gd",
	"res://scripts/cards/Hexes/Sap.gd",
	"res://scripts/cards/Hexes/SapStrength.gd",
	"res://scripts/cards/Hexes/ShroudOfTheAncients.gd",
	"res://scripts/cards/Hexes/Smite.gd",
	"res://scripts/cards/Hexes/SpellDemolition.gd",
	"res://scripts/cards/Hexes/TheInferno.gd",
	"res://scripts/cards/Hexes/TheDeluge.gd",
	"res://scripts/cards/Hexes/WheelOfFire.gd",
	"res://scripts/cards/Hexes/VisionOfTartarus.gd",
	"res://scripts/cards/Hexes/VisionOfOdin.gd",
	"res://scripts/cards/Hexes/VoidShield.gd",
	"res://scripts/cards/Powers/AcceleratedFate.gd",
	"res://scripts/cards/Powers/ACostToWalkTheWorlds.gd",
	"res://scripts/cards/Powers/AdvancedBuildingTechniques.gd",
	"res://scripts/cards/Powers/AllfathersSacrifice.gd",
	"res://scripts/cards/Powers/AltarOfDreams.gd",
	"res://scripts/cards/Powers/AnankesBinding.gd",
	"res://scripts/cards/Powers/AncientWisdom.gd",
	"res://scripts/cards/Powers/BerserkerMead.gd",
	"res://scripts/cards/Powers/Breidablik.gd",
	"res://scripts/cards/Powers/CallOfTheValkyrie.gd",
	"res://scripts/cards/Powers/NorseBloodlust.gd",
	"res://scripts/cards/Powers/OraclesSight.gd",
	"res://scripts/cards/Powers/Palisade.gd",
	"res://scripts/cards/Powers/Ragnarok.gd",
	"res://scripts/cards/Powers/RallyTheTroops.gd",
	"res://scripts/cards/Powers/SavingGrace.gd",
	"res://scripts/cards/Powers/SummonedSap.gd",
	"res://scripts/cards/Powers/TakeTheField.gd",
	"res://scripts/cards/Powers/Terror.gd",
	"res://scripts/cards/Powers/TonalExtraction.gd",
	"res://scripts/cards/Powers/WalkOfTheSage.gd",
	"res://scripts/cards/Powers/DivineCaprice.gd",
	"res://scripts/cards/Powers/FeastOfAmbrosiaAndNectar.gd",
	"res://scripts/cards/Powers/FerociousDefence.gd",
	"res://scripts/cards/Powers/FireAndGold.gd",
	"res://scripts/cards/Powers/GiantsDisdain.gd",
	"res://scripts/cards/Powers/HuntingTactics.gd",
	"res://scripts/cards/Powers/ImmortalTechniques.gd",
	"res://scripts/cards/Powers/Kurnugia.gd",
	"res://scripts/cards/Powers/LawsOfCivilization.gd",
	"res://scripts/cards/Powers/ManaGuard.gd",
	"res://scripts/cards/Powers/MechFactory.gd",
	"res://scripts/cards/Powers/Myrkwood.gd",
	"res://scripts/cards/Spells/Absence.gd",
	"res://scripts/cards/Spells/ApollyonsDemiurge.gd",
	"res://scripts/cards/Spells/BaneOfTheSvartalfar.gd",
	"res://scripts/cards/Spells/BitMeseri.gd",
	"res://scripts/cards/Spells/BlotSacrifice.gd",
	"res://scripts/cards/Spells/BookOfLife.gd",
	"res://scripts/cards/Spells/CircleofRebirth.gd",
	"res://scripts/cards/Spells/DeucalionsInfants.gd",
	"res://scripts/cards/Spells/Earthquake.gd",
	"res://scripts/cards/Spells/FalloftheMighty.gd",
	"res://scripts/cards/Spells/Famine.gd",
	"res://scripts/cards/Spells/FiresOfJudgment.gd",
	"res://scripts/cards/Spells/FoolishOptimism.gd",
	"res://scripts/cards/Spells/KeyOfSolomon.gd",
	"res://scripts/cards/Spells/LightOfMorningsDoors.gd",
	"res://scripts/cards/Spells/OccultSingularity.gd",
	"res://scripts/cards/Spells/TabletOfLife.gd",
	"res://scripts/cards/Spells/RunicSpellbreaker.gd",
	"res://scripts/cards/Spells/SirensSong.gd",
	"res://scripts/cards/Spells/WildMagic.gd",
	"res://scripts/cards/Structures/AncientPyre.gd",
	"res://scripts/cards/Structures/AnointingStatue.gd",
	"res://scripts/cards/Structures/DoorwayToTheVoid.gd",
	"res://scripts/cards/Structures/E2Abzu.gd",
	"res://scripts/cards/Structures/EriduCityOfSages.gd",
	"res://scripts/cards/Structures/GlitnirThePeaceful.gd",
	"res://scripts/cards/Structures/HildskjalfThroneOfOdin.gd",
	"res://scripts/cards/Structures/Watchtower.gd",
	"res://scripts/cards/Structures/WardingStone.gd",
]

static var _cached_all_cards: Array[Card] = []
static var _cached_card_templates_by_alias: Dictionary = {}

static func make_all_cards() -> Array[Card]:
	if not _cached_all_cards.is_empty():
		return _duplicate_cached_cards()
	
	var discovered_cards: Array[Card] = []
	_discover_cards_from_registry(discovered_cards)
	
	_cached_all_cards = discovered_cards
	_rebuild_card_alias_cache()
	
	return _duplicate_cached_cards()

static func _duplicate_cached_cards() -> Array[Card]:
	var duplicates: Array[Card] = []
	for card in _cached_all_cards:
		duplicates.append(_duplicate_card_with_fresh_uid(card))
	return duplicates

static func _duplicate_card_with_fresh_uid(template: Card) -> Card:
	if template == null:
		return null
	var duplicated := template.duplicate(true) as Card
	if duplicated is BaseCard:
		(duplicated as BaseCard).assign_fresh_uid()
	return duplicated

static func _discover_cards_from_registry(out_cards: Array[Card]) -> void:
	for full_path in CARD_SCRIPT_PATHS:
		var script: GDScript = load(full_path)
		if script == null:
			push_warning("CardCatalog: Failed to load card script %s" % full_path)
			continue
		var inst = script.new()
		if inst is Card:
			var is_valid_for_catalog := true
			if inst.is_token or inst.card_types.has("Token"):
				is_valid_for_catalog = false
			elif inst.card_name == "" or inst.card_name == "Unnamed" or inst.card_name == "Card":
				is_valid_for_catalog = false
			if is_valid_for_catalog:
				out_cards.append(inst)
			elif inst is Object and not inst is RefCounted:
				inst.free()
		elif inst is Object and not inst is RefCounted:
			inst.free()

# Returns the shared cached card templates WITHOUT duplicating them or
# assigning fresh UIDs. Use this for read-only lookups (e.g. resolving card
# art/names for UI lists) where you do not mutate the card or hand it to match
# play. This skips the 225x duplicate(true) cost that make_all_cards() pays to
# give every match instance its own UID. The returned array references the
# internal cache directly and must not be mutated.
static func get_cached_card_templates() -> Array[Card]:
	if _cached_all_cards.is_empty():
		var discovered_cards: Array[Card] = []
		_discover_cards_from_registry(discovered_cards)
		_cached_all_cards = discovered_cards
		_rebuild_card_alias_cache()
	return _cached_all_cards

static func instantiate_card_by_name(card_name: String) -> Card:
	var requested_name := str(card_name).strip_edges()
	if requested_name.is_empty():
		return null
	
	# Ensure cache is populated
	if _cached_all_cards.is_empty():
		make_all_cards()
	if _cached_card_templates_by_alias.is_empty():
		_rebuild_card_alias_cache()

	var template = _cached_card_templates_by_alias.get(requested_name, null)
	if template == null:
		template = _cached_card_templates_by_alias.get(to_lookup_key(requested_name), null)
	if template is Card:
		return _duplicate_card_with_fresh_uid(template as Card)
	return null

static func make_cards_from_counts(card_counts: Dictionary) -> Array[Card]:
	var cards: Array[Card] = []
	for raw_card_name in card_counts.keys():
		var card_name := str(raw_card_name).strip_edges()
		var count := int(card_counts[raw_card_name])
		if card_name.is_empty() or count <= 0:
			continue
		for _copy_index in range(count):
			var card := instantiate_card_by_name(card_name)
			if card != null:
				cards.append(card)
	return cards

static func _rebuild_card_alias_cache() -> void:
	_cached_card_templates_by_alias.clear()
	for template in _cached_all_cards:
		if template == null:
			continue
		for alias in _get_card_name_aliases(template):
			_register_card_alias(alias, template)
			_register_card_alias(to_lookup_key(alias), template)

static func _get_card_name_aliases(card: Card) -> Array[String]:
	var aliases: Array[String] = []
	if card == null:
		return aliases
	aliases.append(str(card.card_name))
	if card.has_method("get_normalized_card_name"):
		aliases.append(str(card.get_normalized_card_name()))
	if card.has_method("get_ascii_card_name"):
		aliases.append(str(card.get_ascii_card_name()))
	return aliases

static func _register_card_alias(alias: String, template: Card) -> void:
	var clean_alias := str(alias).strip_edges()
	if clean_alias.is_empty():
		return
	if _cached_card_templates_by_alias.has(clean_alias):
		return
	_cached_card_templates_by_alias[clean_alias] = template

static func to_lookup_key(card_name: String) -> String:
	var normalized_name: String = str(card_name).strip_edges().to_lower()
	var output := ""
	for char_index in range(normalized_name.length()):
		var codepoint := normalized_name.unicode_at(char_index)
		var is_digit := codepoint >= 48 and codepoint <= 57
		var is_upper := codepoint >= 65 and codepoint <= 90
		var is_lower := codepoint >= 97 and codepoint <= 122
		if is_digit or is_upper or is_lower:
			output += normalized_name[char_index]
	return output
