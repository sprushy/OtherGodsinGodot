# Other Gods card effect text survey

The quickest improvements are to put each trigger on its own line, use the same names for zones and stats across cards, and keep target restrictions beside the effects they qualify. Some cards need a wording correction first because their text gives players the wrong expectation about costs, targets or timing.

The survey covers all 236 scripts listed in [CardCatalog.gd](../scripts/cards/CardCatalog.gd), including two token scripts filtered out of the deck catalog. Of those entries, 218 have fixed effect text and 18 have an empty effect field. The review also covers the story card, generated cards outside that list and the three bespoke Ascend text variants.

## Highest priority wording corrections

| Card | What the wording should make clear |
| --- | --- |
| Fifa the Magical Arrow | A friendly Warrior receives the bonus. Buyback is available if it was an Archer and destroys its attack target that turn. The 4 mana comes from the player’s mana pool. |
| Guan Yu, Active God | Manoeuvre can move a counter only to another Guan Yu or Guan Yu, Active God you control. |
| Asag the Destroyer and Stone Monkey | Class Rend applies to combat destruction and sends the victim to the Abyss. Stone Skin prevents a creature from being Slain, which specifically requires arrival in the Graveyard. |
| Pictish Beast | Count face-up copies on your field **and** copies in your Graveyard together. |
| Key of Solomon | Return up to 2 Demons. Both the Graveyard and Abyss contribute to the same selection pool. |
| Summoned Sap | The stance change spends a Major Action. The aura affects creatures outside the listed types on both sides. |
| Palisade | A Frontline Palisade protects the entire friendly Reserve row. It also protects your Followers from either row. Every attacker must be Aerial to bypass it. |
| E2-abzu | Compare the target’s LVL to the mana remaining after the activation cost. |
| Wheel of Fire | The first advance is free. Each optional Upkeep advance costs 1 mana, including the steps into the Graveyard and Abyss. |

## Wording conventions

- Put the trigger, speed, cost and use limit in a consistent ability header. Give recurring triggers, optional choices and delayed effects separate lines when they have different timing.
- Use STR, RES, SPD and LVL consistently. Use Frontline, Reserve, Graveyard and Abyss for zones. Use Void as the action that sends a card to the Abyss.
- Lead with the choice and its target. Keep “may,” “up to,” “instead,” zone ownership, visibility, duration and the exact event that triggers the effect where they affect play.
- Reuse exact keyword hints for recurring rules such as Incorporeal, Trollskap and Fractions where players can access them. Keep meaningful exceptions visible. A keyword replacement should preserve the same trigger, target and outcome.
- Preserve the parenthesized Impact marker and the recognized cost and BBCode forms when applying these edits. Impact detection reads the printed marker, bold keyword tags drive hints, and Freyja and Powers rewrite selected cost patterns at display time. Compare the in-game cost and trigger text when changing those patterns. [BaseCard](../scripts/cards/BaseCard.gd), [PowerCard](../scripts/cards/PowerCard.gd), [Freyja](../scripts/cards/Gods/Freyja.gd), [card details](../scripts/ui/CardDetailContentBuilder.gd), [rules glossary](new-player-rules.md#28-keywords-and-status-effects)

## Card by card recommendations

Each entry gives proposed wording, an edit to make, or a reason to retain the existing line. Items that call for verification depend on the exact rule or implementation cited in that row.

### Gods

| Card | Recommendation |
| --- | --- |
| [Aphrodite Areia](../scripts/cards/Gods/AphroditeAreia.gd) | Lead with the combat destruction prerequisite. Keep “destroyed … in combat” so the condition retains its current scope. |
| [Aphrodite Skotia](../scripts/cards/Gods/AphroditeSkotia.gd) | “Your hidden creatures keep their full SPD and stay hidden in combat.” |
| [Baldr](../scripts/cards/Gods/Baldr.gd) | “Blessed One (Upkeep): Gain 5 Followers.” Upkeep already supplies the timing. |
| [Cernunnos](../scripts/cards/Gods/Cernunnos.gd) | “Animals of level 5 or higher get +2 STR and +2 SPD. Triskelion Animals can’t be Enslaved.” Keep the two groups explicit. |
| [Dellingr, the Dayspring](../scripts/cards/Gods/DellingrTheDayspring.gd) | “Reveal an opposing card until end of turn. If it’s magical, it can’t activate this turn.” Keep the two time clauses adjacent. |
| [Freyja](../scripts/cards/Gods/Freyja.gd) | “Summon a Norse Warrior from your Graveyard. It gains Spirit. Destroy it at the start of your next turn. Costs 1 mana less per Valkyrie you have in play.” Preserve the cost header used for live cost display and confirm the discount counts the same card types before replacing “Valkyrie card.” |
| [Guan Yu](../scripts/cards/Gods/GuanYu.gd) | Give the Upkeep counter gain and paid destruction their own lines. Match Thor’s Champion’s Call wording. Keep the halved damage visible until every card view reliably exposes the hint. |
| [Hermes](../scripts/cards/Gods/Hermes.gd) | Move “once per turn” to the header. “Give a creature +[bonus] SPD until end of turn.” |
| [Hermes Psychopompus](../scripts/cards/Gods/HermesPsychopompus.gd) | Keep both ability lines. “2 mana per LVL” belongs with Call of the Crossing. For Wings of the Departed, keep the Graveyard Ghost count as a mana cap and show the +1 SPD-per-mana rate next to it. |
| [Manannán mac Lir](../scripts/cards/Gods/ManannanMacLir.gd) | “Put all your Triskelion creatures in Stealth.” |
| [Mummu, The One Who Has Awoken](../scripts/cards/Gods/Mummu.gd) | “Shelve a face-up card you control. Gain mana equal to its LVL minus 1.” Use SPD 1 in the activation header. |
| [Nusku, Firebearer](../scripts/cards/Gods/NuskuFirebearer.gd) | “Mill 7. Your opponent chooses an Ancient Charm or Spell milled this way, if any, and adds it to your hand.” |
| [Odin, the Allfather](../scripts/cards/Gods/Odin.gd) | Define or verify “Patriarch Rule” before treating it as self-explanatory. Under Runic Knowledge, give correct and incorrect guesses separate sentences and retain all three cost zones. |
| [Tezcatlipoca, the Smoking Mirror](../scripts/cards/Gods/TezcatlipocaTheSmokingMirror.gd) | Split the Tonal Mastery trigger from the three-token payout. Use “On the fourth sacrifice, summon Tezcatlipoca, Active God” for Necoc Yaotl. |
| [Thor](../scripts/cards/Gods/Thor.gd) | Keep the Human Warrior aura on its own line. Give Champion’s Call the same three sentences as Guan Yu, with the matching Active God name, mana per Shelved card and halved Follower damage. |
| [Tiamat, the Primordial](../scripts/cards/Gods/TiamatThePrimordial.gd) | Say explicitly that the LVL cap applies per Brood Slot. Keep Matriarch Rule separate and specify that the choice competes with drawing at Upkeep. |

### Active Gods

| Card | Recommendation |
| --- | --- |
| [Baldr, Active God](../scripts/cards/ActiveGods/BaldrActive.gd) | Keep Divine Resilience’s three protections as short sentences. In Radiant Wisdom, use “Convert those Followers instead of dealing Follower damage” and preserve the player-wide scope of “you.” |
| [Dellingr, Active God](../scripts/cards/ActiveGods/DellingrActive.gd) | “Reveal every face-down card your opponent controls and every card in their hand.” Follow with separate sentences for magical activation lockout and optional Reveal resolution. |
| [Freyja, Active God](../scripts/cards/ActiveGods/FreyjaActive.gd) | “Summon up to half the Norse Warriors in your Graveyard. They gain Spirit. Destroy them at the start of your next turn.” Keep the rounding in the Fractions hint. |
| [Guan Yu, Active God](../scripts/cards/ActiveGods/GuanYuActive.gd) | Separate the opening seven counters from the recurring Warrior trigger. Manoeuvre’s target filter accepts only another Guan Yu or Guan Yu, Active God you control, so replace “another tactic-counter card” with those names. |
| [Hermes, Active God](../scripts/cards/ActiveGods/HermesActive.gd) | “Wingfoot (Passive): Creatures with lower SPD than Hermes can’t attack him.” |
| [Mummu, Active God](../scripts/cards/ActiveGods/MummuActive.gd) | Lead with the choice to Prime or Shelve a card Mummu destroys. Put your God’s reactivation on a separate line with its own leave-field trigger. |
| [Nusku, Active God](../scripts/cards/ActiveGods/NuskuActive.gd) | Keep the two triggers separate. Start Celestial Light with “If you declined Core Flame” and use “the number of cards in your Graveyard” for the count. |
| [Tezcatlipoca, Active God](../scripts/cards/ActiveGods/TezcatlipocaActive.gd) | Keep four ability lines. For Shift, list the types common to both forms once and list Animal, Feline and Jaguar under Jaguar Form. For Titlacauan, say “with a combined LVL no greater than the total LVL sacrificed for Necoc Yaotl.” |
| [Thor, Active God](../scripts/cards/ActiveGods/ThorActive.gd) | Put interception, Warrior buffs and halved Follower damage in separate sentences. Keep “other” on the Warrior buff and retain both protected target classes. |
| [Tiamat, Active God](../scripts/cards/ActiveGods/TiamatActive.gd) | Keep separate Impact and Fatality lines. Their different LVL caps and identical hand source make them easy to compare. |

### Creatures

| Card | Recommendation |
| --- | --- |
| [Afanc](../scripts/cards/Creatures/Afanc.gd) | Keep the one-line Reveal effect. The Poison hint explains the status. |
| [Again-Walker](../scripts/cards/Creatures/AgainWalker.gd) | “Again (End of turn): If this was Slain this turn, you may pay [cost] mana to Resurrect it face-up in your Reserve in Aggressive stance.” |
| [Alu](../scripts/cards/Creatures/Alu.gd) | “Stupefy (Major Action): Give a creature Sleep while Alu remains on the field.” |
| [Ankou, Servant to the Reaper](../scripts/cards/Creatures/AnkouServantToTheReaper.gd) | Use “Reap (Slay): Draw a card.” |
| [Anzû](../scripts/cards/Creatures/Anzu.gd) | Leave the effect field empty. |
| [Asag the Destroyer](../scripts/cards/Creatures/AsagTheDestroyer.gd) | Say “When a friendly Demon destroys a creature in combat, Void that creature and its Equipment.” Class Rend runs through combat destruction, and “Slay” would change the meaning. |
| [Asakku](../scripts/cards/Creatures/Asakku.gd) | Keep “destroy in combat.” Use the same “When you destroy an enemy creature in combat” template wherever the event has those requirements. |
| [Asaruludu](../scripts/cards/Creatures/Asaruludu.gd) | “Friendly Ancient creatures can’t be targeted by effects during your turn or during combat.” Use “or” to make either window sufficient. |
| [Askelladen](../scripts/cards/Creatures/Askelladen.gd) | “When this face-up creature attacks or is attacked by a creature with equal or lower SPD, you may Shelve both.” Check the legal attacker and defender types before replacing the current “card” with “creature.” |
| [Aurboða](../scripts/cards/Creatures/Aurboda.gd) | Use “Pierce (Slay): Convert 7 Followers.” |
| [Berserker](../scripts/cards/Creatures/Berserker.gd) | Lead with “This turn, this gains +[bonus] STR and Immortal.” Spell out whose attack causes Sleep and preserve the start-of-your-next-turn wake timing. |
| [Beyla](../scripts/cards/Creatures/Beyla.gd) | Keep separate Revive lines. The contrast players need is “all Norse creatures” for Impact and “all friendly creatures” for the paid ability. |
| [Blessed Knights](../scripts/cards/Creatures/BlessedKnights.gd) | Use “Blessed Ward (Impact): Choose Hexes, creature abilities or Powers. This card and all cards with its name are immune to the chosen category this turn.” |
| [Brown Bear](../scripts/cards/Creatures/BrownBear.gd) | Leave the effect field empty. |
| [Byggvir](../scripts/cards/Creatures/Byggvir.gd) | Use “Brewing (Reveal): Choose one” followed by the two Mead Power options and the Mead card recovery. “Graveyard” is the only zone name needed. |
| [Caleuche, the Ghost Ship](../scripts/cards/Creatures/Caleuche.gd) | “This gains +10 STR and +1 SPD for each other friendly Spirit on the field.” |
| [Capricorn](../scripts/cards/Creatures/Capricorn.gd) | “When you sacrifice this to pay for another creature’s summon, gain 2 mana and return it from your Graveyard to your hand.” |
| [Clay-Eaters](../scripts/cards/Creatures/ClayEaters.gd) | “Choose a Structure or Stone creature. Destroy it at the end of your turn if Clay Eaters is still on the field.” Keep the activation cost in the header. |
| [Combat Mech](../scripts/cards/Creatures/CombatMech.gd) | Leave the effect field empty. The token’s creation and restrictions are described on its source card. |
| [Devastator Mech](../scripts/cards/Creatures/DevastatorMech.gd) | Leave the effect field empty. |
| [Draug Revenant](../scripts/cards/Creatures/DraugRevenant.gd) | Use “Trollskap” alone if its existing hint stays accessible in the card’s detail and list views. The current sentence is already the keyword definition. |
| [Durinn Secondborn](../scripts/cards/Creatures/DurinnSecondborn.gd) | “Add a Weapon from either Graveyard to your hand.” Keep the paid Impact header. |
| [Edimmu](../scripts/cards/Creatures/Edimmu.gd) | Use “Incorporeal (Passive)” with the existing hint for both engagement directions and Sleep and Poison Immunity. Check the views that show plain text before dropping the reminder. |
| [En-hedu-anna](../scripts/cards/Creatures/EnHeduAnna.gd) | Separate the God-power prerequisite, the three stat choices and the protection window. Clarify whose “next turn” ends the protection before rewording it. |
| [Enki, Lord of Eridu](../scripts/cards/Creatures/EnkiLordOfEridu.gd) | Keep. “Friendly Mages are immune to Hexes” is already direct. |
| [Enkidu](../scripts/cards/Creatures/Enkidu.gd) | Leave the effect field empty. |
| [Erlqueen's Nightingale](../scripts/cards/Creatures/ErlqueensNightingale.gd) | Put the free Shift and optional return to hand in the Shift line if the free-cost exception remains explicit. Present Human and Animal types as two labeled forms. |
| [Fenrir](../scripts/cards/Creatures/Fenrir.gd) | Lead with “Shuffle Fenrir from your hand into your deck.” Keep the normal summon and its cost in that ability. Under Devour, use “at least 2 levels lower” and name the two stats gained. |
| [First Sage Adapa](../scripts/cards/Creatures/FirstSageAdapa.gd) | Keep the opposing Power/God ability choice and “2 of its owner’s turns.” Expand the Mute hint if it should explain suppression of God abilities too. |
| [Fourth Sage Enmegalamma](../scripts/cards/Creatures/FourthSageEnmegalamma.gd) | “You may pay mana equal to half a Mer Sage’s LVL to Acquire it, except a copy of this card.” Keep the self-copy exception with the target. |
| [Gala-Tura](../scripts/cards/Creatures/GalaTura.gd) | Keep immunity and Destroyed as separate lines. Replace “return … to the bottom of your deck” with “Shelve up to 3 other creatures from your Graveyard.” |
| [Gallu](../scripts/cards/Creatures/Gallu.gd) | Leave the effect field empty. |
| [Garm, Watchdog of Hel](../scripts/cards/Creatures/Garm.gd) | “While Garm is in play, players can’t activate effects in the Graveyard or effects that affect cards there.” |
| [Gawain](../scripts/cards/Creatures/Gawain.gd) | “On your turn, triple this creature’s base STR and RES until your first attack resolves or your turn ends.” Keep “base” and “first.” Leave Healing Hands separate. |
| [Giant Master Architect](../scripts/cards/Creatures/GiantMasterArchitect.gd) | Keep “Master Plan (Impact): Acquire a Structure.” |
| [Gidim Ensi](../scripts/cards/Creatures/GidimEnsi.gd) | Use the Incorporeal hint for its shared rules. Under Guardian, put the attack prohibition on its own sentence and retain the attacker’s controller as the clock for Sleep. |
| [Gilgamesh](../scripts/cards/Creatures/Gilgamesh.gd) | “In combat against a higher-level creature, this gains +[bonus] STR per level of difference.” |
| [Grindylow](../scripts/cards/Creatures/Grindylow.gd) | “Drown Below (Reveal): Destroy a creature.” The trigger and verb already carry the effect. |
| [Gudu Priest](../scripts/cards/Creatures/GududPriest.gd) | Use “SPD 3” in the header and “once per turn” in the same place as other activated abilities. Keep both removal of existing effects and immunity for the rest of the turn. |
| [Gugalanna, Bull of Heaven](../scripts/cards/Creatures/GugalannaBullOfHeaven.gd) | Keep the optional target, lower SPD and 30+ RES together. State that the opponent may answer with attack-triggered Hexes. Tie the return to hand to resolving Celestial Charge against a legal target. |
| [Gullinbursti](../scripts/cards/Creatures/Gullinbursti.gd) | Keep “Dodge (Passive)” with its hint, or retain the current short reminder for views that lack hints. |
| [Habrok, Paragon of Hawks](../scripts/cards/Creatures/HabrokParagonOfHawks.gd) | Lead with “At the end of your opponent’s turn.” Keep the sole-creature condition and make the return-to-hand step part of the optional instruction. |
| [Harii Fransiscan](../scripts/cards/Creatures/HariiFransiscan.gd) | “Restless Tempo: Has 1 extra Minor Action each turn.” |
| [Harii Jarl](../scripts/cards/Creatures/HariiJarl.gd) | “Summon up to 2 other Harii creatures from your hand, paying their summon costs.” |
| [Harii Shaman](../scripts/cards/Creatures/HariiShaman.gd) | Use two choice lines under a shared twice-per-turn header. Verify how the Animal subtype is chosen and which existing types are replaced before tightening the first choice. |
| [Harii Warrior](../scripts/cards/Creatures/HariiWarrior.gd) | Leave the effect field empty. |
| [Hati](../scripts/cards/Creatures/Hati.gd) | “At the end of your turn, you may sacrifice a creature to summon Hati. If you already used your normal summon, also pay [cost] mana.” |
| [Hel-blar Draug](../scripts/cards/Creatures/HelBlarDraug.gd) | “Enemy Aerial creatures lose Aerial and get −6 STR, −6 RES and −1 SPD.” The explicit target group makes the redundant qualifier unnecessary. |
| [Hrimgrimmnir](../scripts/cards/Creatures/Hrimgrimmnir.gd) | Leave the effect field empty. |
| [Huginn](../scripts/cards/Creatures/Huginn.gd) | “Hex Search (Perish): Prime a Hex.” Drop the duplicated Prime label in the header and specify the deck source if the hint leaves it unclear. |
| [Humbaba the Terrible](../scripts/cards/Creatures/HumbabaTheTerrible.gd) | “Whenever this enters combat, your opponent looks at the top 3 cards of their deck. They Prime one and Shelve the rest.” |
| [Hyena Pack](../scripts/cards/Creatures/HyenaPack.gd) | “Scavenge (Slay): Summon every Hyena Pack from your deck.” |
| [Isimud](../scripts/cards/Creatures/Isimud.gd) | Keep the discount and summon ability on different lines. Put “Major Action” in Revelation’s header and say “Pay 2 extra mana for that summon.” |
| [Jiang Ziya, Fisher of Kings](../scripts/cards/Creatures/JiangZiyaFisherOfKings.gd) | Use three separate ability lines. Spell out which source Counterstroke destroys for attacks versus effects. Keep the exact “Summon” trigger until its scope is checked against Impact. |
| [Jiaolong](../scripts/cards/Creatures/Jiaolong.gd) | Use two labeled forms and put the once-per-turn Minor Action in the header. List the exact types in each form, including Shapeshifter only where present. |
| [Kur-Jara](../scripts/cards/Creatures/KurJara.gd) | Use three steps with time markers for selection, resurrection and destruction. Specify “for each level by which that card exceeds Kur Jara” in the last step. |
| [Lailoken](../scripts/cards/Creatures/Lailoken.gd) | “Destroy a prepared magical card. If you do, this gains +5 STR.” |
| [Lamashatu](../scripts/cards/Creatures/Lamashatu.gd) | Place “once per turn” in the activation header. Keep “another friendly Demon or Animal” and list LVL, STR, RES and SPD in a consistent order. |
| [Lesser Mushussu](../scripts/cards/Creatures/LesserMushussu.gd) | Leave the effect field empty. |
| [Lindwyrm](../scripts/cards/Creatures/Lindwyrm.gd) | “Destroy a creature at least 2 levels below this one. If you do, this gains +1 LVL, +5 STR, +5 RES and +1 SPD.” |
| [Low-Light Troll](../scripts/cards/Creatures/LowLightTroll.gd) | “Whenever a magical or Power effect reveals a card, this gets −5 STR and +5 RES.” |
| [Lugalbanda](../scripts/cards/Creatures/Lugalbanda.gd) | “Pick up or destroy unequipped Equipment anywhere on the field. Your opponent may intercept this action if the Equipment is on their side.” |
| [Malinalxochitl Acolyte](../scripts/cards/Creatures/MalinalxochitlAcolyte.gd) | “After a friendly Insect fights another creature, give that other creature Poison.” |
| [Malinalxochitl Thrall](../scripts/cards/Creatures/MalinalxochitlThrall.gd) | Leave the effect field empty. |
| [Mašmaššu Priest](../scripts/cards/Creatures/MasmassuPriest.gd) | “Destroy a creature. If it’s a Demon or Spirit, gain 1 mana.” Check whether the mana depends on selecting the target or actually destroying it before using “If you destroy.” |
| [Minotaur Footsoldier](../scripts/cards/Creatures/MinotaurFootsoldier.gd) | Lead with the attack trigger. Keep both sleeping and Stealthed targets and keep the end-of-turn duration explicit. |
| [Mopsus](../scripts/cards/Creatures/Mopsus.gd) | “Reveal 1 card in your opponent’s hand, plus 1 per friendly Avian on the field. Those cards stay revealed while in hand.” |
| [Muninn](../scripts/cards/Creatures/Muninn.gd) | Keep “Charm Search (Perish): Prime a Charm.” Specify the deck source if players confuse it with Graveyard recovery. |
| [Nagual](../scripts/cards/Creatures/Nagual.gd) | Group the shared Mage, Shaman and Shapeshifter types once. List the Human and Animal/Feline types and the bonuses by form. |
| [Nergal Lion](../scripts/cards/Creatures/NergalLion.gd) | “Prepare a Destruction card from your Graveyard that can destroy a physical card. It costs no mana to activate.” Confirm whether the waiver covers costs besides mana before using that last sentence. |
| [Nimue](../scripts/cards/Creatures/Nimue.gd) | Keep two Major Action lines. Under Entomb, place the LVL-based mana cost beside Shelve. Under Present, say “Put Equipment from your Graveyard onto the field.” |
| [Pai Long, Autumn King](../scripts/cards/Creatures/PaiLongAutumnKing.gd) | Keep Stormcloud short. “This is immune to Weather effects unless they raise its stats” preserves Weather King’s exception. |
| [Pazuzu](../scripts/cards/Creatures/Pazuzu.gd) | Keep Impact and recurring drain on separate lines. Use an Upkeep label only if it matches the start-of-turn timing used by the effect. |
| [Pegasus](../scripts/cards/Creatures/Pegasus.gd) | Keep Evasive and Steed separate. “A Human or Active God can equip Pegasus after it is summoned. The equipped creature’s SPD becomes 5 and it gains Aerial and Evasive.” |
| [Pictish Beast](../scripts/cards/Creatures/PictishBeast.gd) | “Gain 2 mana for each face-up Pictish Beast you control and each Pictish Beast in your Graveyard.” The implementation adds the two counts. |
| [Rabid Wolf](../scripts/cards/Creatures/RabidWolf.gd) | “After combat, each surviving creature that fought this loses STR equal to Rabid Wolf’s STR. Destroy any creature whose STR drops below 0 this way.” Preserve the strict threshold. |
| [Rabisu](../scripts/cards/Creatures/Rabisu.gd) | “Leech 3 STR and 3 RES from each sleeping creature.” Keep Sleep Immunity separate. |
| [Raven Storm](../scripts/cards/Creatures/RavenStorm.gd) | Keep “from your hand” and “may.” Format SPD 3 in the header and preserve “Norse Human Warrior or Lupine” as the two groups. |
| [Red Cap](../scripts/cards/Creatures/RedCap.gd) | “At the end of your turn, destroy this if it resolved no attacks this turn.” Keep “resolved” because declaring an attack is a different event. |
| [Robotic Footsoldier](../scripts/cards/Creatures/RoboticFootsoldier.gd) | “Can form a United Front with another Machine. Use their combined STR and lower SPD.” |
| [Scorpion-Man Archer](../scripts/cards/Creatures/ScorpionManArcher.gd) | Leave the effect field empty. |
| [Scorpion-Man Warrior](../scripts/cards/Creatures/ScorpionManWarrior.gd) | Leave the effect field empty. |
| [Seven-Headed Serpent](../scripts/cards/Creatures/SevenHeadedSerpent.gd) | “Its attacks can’t be intercepted. It can intercept regardless of SPD.” Name the subject because intercepting and being intercepted are distinct here. |
| [Seventh Sage Utuabzu](../scripts/cards/Creatures/SeventhSageUtuabzu.gd) | Use two lines with the same “resolve its Impact” wording. Preserve the different zones and the once-per-turn check on the paid option. |
| [Sixth Sage An-Enlilda](../scripts/cards/Creatures/SixthSageAnEnlilda.gd) | Keep the optional Void as a condition for acquiring the Ancient Dwelling. The existing two sentences are easy to scan. |
| [Skoll](../scripts/cards/Creatures/Skoll.gd) | “After turn 1, you may take this instead of your other Upkeep options: summon Skoll from your hand for free. Other summons cost 2 more mana this turn.” |
| [Soldier of the Black Emperor](../scripts/cards/Creatures/SoldierOfTheBlackEmperor.gd) | Leave the effect field empty. |
| [Stone Infant](../scripts/cards/Creatures/StoneInfant.gd) | Leave the effect field empty. The token’s creation and restrictions are described on its source card. |
| [Stone Monkey](../scripts/cards/Creatures/StoneMonkey.gd) | Keep “Stone Skin (Passive): Cannot be Slain.” It describes Graveyard-bound combat destruction and preserves the interaction with Class Rend. |
| [Sulak the Unclean](../scripts/cards/Creatures/SulakTheUnclean.gd) | “Surprise! (Reveal): Double Sulak’s STR until end of turn.” |
| [Tatzelwurm](../scripts/cards/Creatures/Tatzelwurm.gd) | “Dragon Heart (Slay): Acquire a Dragon.” |
| [Telchine Apprentice](../scripts/cards/Creatures/TelchineApprentice.gd) | Lead with “Weapons equipped from your hand gain the following effect.” Use two short granted clauses, one for legal attack targets and one for combat destruction protection. Preserve “destroyed in combat.” |
| [Tezcatlipoca Blasphemer](../scripts/cards/Creatures/TezcatlipocaBlasphemer.gd) | Keep the sacrifice in the activation header and the effect as “Destroy a magical card.” |
| [The Chained Ghost of Athens](../scripts/cards/Creatures/TheChainedGhostOfAthens.gd) | Keep “while this is face-up.” It identifies the visibility condition for disabling enemy creature activations. |
| [The White Serpent](../scripts/cards/Creatures/TheWhiteSerpent.gd) | Put the two forms on separate labeled lines or list the shared Shapeshifter type once. Keep Medicine’s SPD 2 and end-of-turn protection on its own line. |
| [Thiazi](../scripts/cards/Creatures/Thiazi.gd) | Use labeled forms and keep the exact type lists. Display the Animal form’s STR, RES and SPD in card-stat order. |
| [Third Sage Enmedugga](../scripts/cards/Creatures/ThirdSageEnmedugga.gd) | “Choose a Mer Sage. Spells and creature abilities can’t target it while this remains face-up on the field.” |
| [Tianlong, Holy Dragon](../scripts/cards/Creatures/TianlongHolyDragon.gd) | “When intercepting for your God or a friendly Dragon with higher LVL than this, it has Reach and ignores SPD.” |
| [Titanic Mech](../scripts/cards/Creatures/TitanicMech.gd) | Leave the effect field empty. |
| [Urisk Grovekeepers](../scripts/cards/Creatures/UriskGrovekeepers.gd) | “When intercepting for your Animal, Plant or Nature cards, this has Reach and ignores SPD.” |
| [Valkyrie Warrior](../scripts/cards/Creatures/ValkyrieWarrior.gd) | Leave the effect field empty. |
| [Warrior Dragon](../scripts/cards/Creatures/WarriorDragon.gd) | Leave the effect field empty. |
| [White Stag](../scripts/cards/Creatures/WhiteStag.gd) | Keep “Hunter’s Mark (Fatality): Your opponent gains 2 mana.” |
| [Winged Lion](../scripts/cards/Creatures/WingedLion.gd) | Move “once per turn” into the activation header. Say “Move Winged Lion and another friendly creature to friendly slots of your choice.” |
| [Wolf Adolescent](../scripts/cards/Creatures/WolfAdolescent.gd) | Match Wolf Cub’s sentence with the level 5 cap. Keep the Slay prerequisite and clarify its timing if it can carry over across turns. |
| [Wolf Cub](../scripts/cards/Creatures/WolfCub.gd) | “You may send this to the Graveyard to summon a level 4 or lower Lupine from your deck.” The summon verb supplies the destination. |
| [Án the Bowbender](../scripts/cards/Creatures/AnTheBowbender.gd) | Leave the effect field empty. |

### Powers

| Card | Recommendation |
| --- | --- |
| [A Cost to Walk the Worlds](../scripts/cards/Powers/ACostToWalkTheWorlds.gd) | Keep two trigger sentences. Use “When a creature is sent to the Abyss” only if it matches every Void event the Power tracks. Keep or expose the Returns hint for the second trigger. |
| [Accelerated Fate](../scripts/cards/Powers/AcceleratedFate.gd) | Put the dynamic Unlock cost on a line by itself. “Activate ([cost] mana): Draw a card.” Preserve the existing cost patterns used by the display. |
| [Advanced Building Techniques](../scripts/cards/Powers/AdvancedBuildingTechniques.gd) | “When you play a Structure, you may pay mana. It gets +6 RES per mana paid.” Keep optional payment and the ratio in adjacent sentences. |
| [Allfather's Sacrifice](../scripts/cards/Powers/AllfathersSacrifice.gd) | Put the activation’s real timing in the header in place of the “Searching – Spells” label. “Lose 12 Followers. Search your deck for a Spell, then Prime it.” Preserve the distinction between unlocking and activating if both exist. |
| [Altar of Dreams](../scripts/cards/Powers/AltarOfDreams.gd) | “You may Void sleeping creatures on either side of the field to pay Demon and Spirit summon sacrifice costs.” Keep “sleeping” and both sides. |
| [Ananke's Binding](../scripts/cards/Powers/AnankesBinding.gd) | “Pay [cost] mana. Search for a card and place it under this Power. Prime it at the end of your second turn after activation.” |
| [Ancient Wisdom](../scripts/cards/Powers/AncientWisdom.gd) | “When you play a Spell, friendly Mages get +5 STR until the end of your next turn.” |
| [Aspect Shift](../scripts/cards/Powers/AspectShift.gd) | List the two specific aspect pairs once using arrows. Keep the Unlock and Return to Form costs separate and retain Relock. |
| [Berserker Mead](../scripts/cards/Powers/BerserkerMead.gd) | “Choose a Norse creature below level 5. This turn, it gains +7 STR and Immortal against enemy creatures and effects. After combat this turn, it gains Sleep through the end of your next turn.” |
| [Breidablik](../scripts/cards/Powers/Breidablik.gd) | Use four timing lines for Harbor, the end-of-turn payout, paid Upkeep returns and returns when flipped. Spell the payout as “[multiplier] Followers per combined LVL of harbored Priests” and keep the repeated payment visible. |
| [Call of the Valkyrie](../scripts/cards/Powers/CallOfTheValkyrie.gd) | Separate Unlock from the paid activation. “Prime a Norse Warrior from your Graveyard.” |
| [Divine Caprice](../scripts/cards/Powers/DivineCaprice.gd) | Separate Unlock and paid activation. “Move cards you control to different legal slots.” |
| [Feast of Ambrosia and Nectar](../scripts/cards/Powers/FeastOfAmbrosiaAndNectar.gd) | “Once per turn, an Olympic Power’s unlock and activation costs decrease by 1 mana.” Verify how long the discount lasts and add the duration if it can be misread. |
| [Ferocious Defence](../scripts/cards/Powers/FerociousDefence.gd) | “A friendly Defensive creature destroys its combat opponent if its RES is at least that opponent’s STR.” Keep equality in the comparison. |
| [Fire and Gold](../scripts/cards/Powers/FireAndGold.gd) | Move “Discard 1 card” into the activation cost if it is paid up front. Then state the Tian Dragon condition and Structure destruction together. |
| [Giant's Disdain](../scripts/cards/Powers/GiantsDisdain.gd) | Keep the Follower damage calculation separate from interception. Use “For Follower damage calculations, halve the stats of non-Giants fighting your Giants.” Keep explicit rounding until confirmed equivalent to the standard Fractions rule for this calculation. |
| [Hunting Tactics](../scripts/cards/Powers/HuntingTactics.gd) | List the Raven bonus and the additional Lupine bonus as two choices under the attack trigger. Say explicitly that the creatures lending stats lose the ability to attack that turn. |
| [Immortal Techniques](../scripts/cards/Powers/ImmortalTechniques.gd) | “While you control a Mage, gain 1 mana whenever you play a Spell or an Ancient Hex.” Keep Ancient attached to Hex. |
| [Kurnugia, The Beginning of the End](../scripts/cards/Powers/Kurnugia.gd) | Split the replacement trigger from the rules for the card underneath. Preserve that it counts as on the field, retains Passives and can still use field-affecting abilities. The Harbor hint would describe different behavior. |
| [Laws of Civilization](../scripts/cards/Powers/LawsOfCivilization.gd) | “Players can add cards to hand or gain mana only during their own Upkeep.” |
| [Mana Guard](../scripts/cards/Powers/ManaGuard.gd) | “On your turn, gain 5 Guard per mana spent.” Keep the damage explanation until a Guard hint is available in card detail. Keep Unlock separate from the paid action. |
| [Mech Factory](../scripts/cards/Powers/MechFactory.gd) | “Summon a level 2 Combat Mech token (18 STR, 18 RES, 1 SPD). It can’t be sacrificed.” Keep the twice-per-turn limit and cost in the activation header. |
| [Myrkwood](../scripts/cards/Powers/Myrkwood.gd) | Lead with “You may normal summon another Animal to your Reserve.” Keep both requirements, including the face-up card count. |
| [Norse Bloodlust](../scripts/cards/Powers/NorseBloodlust.gd) | Move “once per turn” into the Swarm label. Keep combat destruction, the hand source and paying the summon cost. |
| [Oracle's Sight](../scripts/cards/Powers/OraclesSight.gd) | Separate Unlock and paid activation. “Look at the top [count] cards of your deck. Prime one and Shelve the rest.” |
| [Palisade](../scripts/cards/Powers/Palisade.gd) | Keep the cost and the Palisade’s LVL and RES. Use the same protection text as the generated Structure, including the entire Reserve row and the requirement that all attackers be Aerial. |
| [Ragnarok](../scripts/cards/Powers/Ragnarok.gd) | Use “On Unlock” in place of the sentence about activating only when unlocked. Keep the sweep, discard threshold, no-attack turn and Relock clock as separate sentences. |
| [Rally the Troops](../scripts/cards/Powers/RallyTheTroops.gd) | Use “add a Warrior from among them to your hand” in place of Acquire, whose generic hint describes the whole deck. Keep the level, hand summon trigger and Shelve instruction. |
| [Saving Grace](../scripts/cards/Powers/SavingGrace.gd) | Lead with the attack on your Followers, then the empty-board eligibility and optional flip. Keep both SPD rates and the extra mana together in the response header. |
| [Summoned Sap](../scripts/cards/Powers/SummonedSap.gd) | “While you control a Plant, Animal or Hybrid, all creatures outside those types get −1 SPD and spend a Major Action when they change stance.” The implementation keys off types on both sides and spends a Major Action. |
| [Take the Field](../scripts/cards/Powers/TakeTheField.gd) | Keep the summon and normal God leaving together. Use a named God Death line with its existing hint. Keep the condition and consequences in text wherever the hint is unavailable. |
| [Terror](../scripts/cards/Powers/Terror.gd) | “Your Demons gain Terror (Impact): Return an enemy creature with lower LVL than that Demon to its owner’s hand.” |
| [Tonal Extraction](../scripts/cards/Powers/TonalExtraction.gd) | Use “types” consistently and say the chosen creature loses Shift if that term covers the lockout. Keep the token’s alternate-form stats and types, the sacrifice prohibition and the Relock trigger. |
| [Walk of the Sage](../scripts/cards/Powers/WalkOfTheSage.gd) | Separate Unlock and paid activation. “Void a Mage from your deck.” |

### Spells

| Card | Recommendation |
| --- | --- |
| [Absence](../scripts/cards/Spells/Absence.gd) | “Choose a Power. Reveal it if face-down, then Relock it or Mute it for 4 of its owner’s turns.” |
| [Apollyon's Demiurge](../scripts/cards/Spells/ApollyonsDemiurge.gd) | “Pay X mana. Mill X, then summon a Demon milled this way.” |
| [Apotheosis](../scripts/cards/Spells/Apotheosis.gd) | “Give a creature you control +1 LVL, +4 STR, +4 RES and +1 SPD. If it reaches level 7, Ascend it.” |
| [Bane of the Svartalfar](../scripts/cards/Spells/BaneOfTheSvartalfar.gd) | Keep “Dwarves and face-up creatures below level 3” as two qualifying groups. Check the implementation before moving “face-up” to a position where it could qualify Dwarves too. |
| [BitMeseri](../scripts/cards/Spells/BitMeseri.gd) | Keep “Void a physical card.” The Void hint can carry the destination. |
| [Blot Sacrifice](../scripts/cards/Spells/BlotSacrifice.gd) | “Summon creatures from your hand with a combined LVL of 7 or less without paying their summon costs.” |
| [Book of Life](../scripts/cards/Spells/BookOfLife.gd) | Keep “Gain 10 Followers” separate. “Summon a non-Machine creature from your hand and Silence it.” |
| [Circle of Rebirth](../scripts/cards/Spells/CircleofRebirth.gd) | “Resurrect all creatures of either player that were destroyed this turn and have the Animal or Plant type.” Either type qualifies. |
| [Conjure Eidolon](../scripts/cards/Spells/ConjureEidolon.gd) | “Summon a token copy of a non-Spirit creature you control. Silence it and give it the Spirit type. Destroy it after it participates in combat.” This follows the current worktree wording with the name change already omitted. |
| [Deucalion's Infants](../scripts/cards/Spells/DeucalionsInfants.gd) | Use three steps. You may destroy any number of your Structures or Golems. Your opponent chooses one of theirs to destroy if able, even if you chose zero. Summon one Stone Infant per Structure or Golem destroyed this turn, including earlier destruction. |
| [Drought](../scripts/cards/Spells/Drought.gd) | “Destroy all other face-up Weather Spells. While Drought is face-up, players can only cast Spells that were prepared.” This makes the permanent lockout and self-exclusion clear. |
| [Earthquake](../scripts/cards/Spells/Earthquake.gd) | “Destroy all Structures and all face-up non-Aerial Machines on the field.” Repeat “all” to make the face-up qualifier’s scope clear. |
| [Fairy Blast](../scripts/cards/Spells/FairyBlast.gd) | “Halve a creature’s STR and SPD. Give it Paralyze.” The Fractions hint covers rounding. |
| [Fall of the Mighty](../scripts/cards/Spells/FalloftheMighty.gd) | “Among creatures on the field outside Stealth, destroy every creature tied for highest STR.” Keep ties and the Stealth filter. |
| [Famine](../scripts/cards/Spells/Famine.gd) | “Reveal all face-down creatures, then destroy all non-Spirit creatures on the field.” Keep the order. |
| [Fires of Judgment](../scripts/cards/Spells/FiresOfJudgment.gd) | “Destroy all face-up creatures, Structures and Equipment your opponent controls.” |
| [Foolish Optimism](../scripts/cards/Spells/FoolishOptimism.gd) | “Force your opponent’s face-up creature with the lowest LVL to attack your face-up creature with the highest LVL.” Verify who chooses among ties if the card needs that detail. |
| [Key of Solomon](../scripts/cards/Spells/KeyOfSolomon.gd) | “Sacrifice an Animal. Add up to 2 Demons from your Graveyard and/or Abyss to your hand.” The selection pools both zones and the resolver caps returns at two. Keep the sacrifice recognizable as a cost. |
| [Light of Morning's Doors](../scripts/cards/Spells/LightOfMorningsDoors.gd) | Keep “Reveal all of your opponent’s face-down cards.” |
| [Occult Singularity](../scripts/cards/Spells/OccultSingularity.gd) | Keep “Destroy all magical cards on the field.” |
| [Runic Spellbreaker](../scripts/cards/Spells/RunicSpellbreaker.gd) | “Destroy a face-up or revealed magical card. Send copies of it from your opponent’s deck to their Graveyard.” Keep “or revealed” to cover the additional target state. |
| [Siren's Song](../scripts/cards/Spells/SirensSong.gd) | Keep “Take control of an opposing face-up creature until end of turn.” |
| [Snowball](../scripts/cards/Spells/Snowball.gd) | “A creature gets −2 STR until end of turn.” |
| [Tablet of Life](../scripts/cards/Spells/TabletOfLife.gd) | “Resurrect one of your Ancient creatures. Silence it and give it Undead. If it’s level 3 or higher, destroy it at end of turn.” Use Silence only if it matches the implemented suppression. |
| [The Changeling Exchange](../scripts/cards/Spells/TheChangelingExchange.gd) | Keep both sentences in controller order. Use “Exchange control” only if the game requires both transfers to succeed together. |
| [Wild Magic](../scripts/cards/Spells/WildMagic.gd) | “Shelve cards from the top of your deck until you find a magical card. Prepare that card revealed.” Verify that “find” preserves any actual draw interaction. |

### Hexes

| Card | Recommendation |
| --- | --- |
| [Banishment](../scripts/cards/Hexes/Banishment.gd) | “Negate a magical card’s activation and Void that card.” Use Void as the action and Abyss as the zone. |
| [Dromi](../scripts/cards/Hexes/Dromi.gd) | “Bind a face-up creature. It can’t attack. At the start of each of its controller’s turns, they lose 7 Followers.” Keep the link’s end condition explicit. |
| [Gleipnir](../scripts/cards/Hexes/Gleipnir.gd) | “Bind a face-up creature. It can’t attack or intercept, and its abilities are suppressed.” Keep the sentence describing how long the Hex stays in play. |
| [Obsidian Reflection](../scripts/cards/Hexes/ObsidianReflection.gd) | “When a creature attacks, reverse that attack’s Follower damage.” Define what “reverse” does if the current hint or prompt leaves the recipient unclear. |
| [Sap](../scripts/cards/Hexes/Sap.gd) | “When cards enter the Frontline, destroy those cards.” Keep the possibility of several cards entering together and verify that “enter” captures every placement path. |
| [Sap Strength](../scripts/cards/Hexes/SapStrength.gd) | “A creature gets −10 STR until end of turn.” |
| [Sep Lemutti](../scripts/cards/Hexes/SepLemutti.gd) | “When a Spirit, Monster, Undead or Demon is summoned, Shelve it.” |
| [Shroud of the Ancients](../scripts/cards/Hexes/ShroudOfTheAncients.gd) | “Put all creatures in Stealth.” |
| [Smite](../scripts/cards/Hexes/Smite.gd) | Keep. “Declares an attack” is the operative event. |
| [Spell Demolition](../scripts/cards/Hexes/SpellDemolition.gd) | Keep both verbs in “Silence and destroy a Spell.” |
| [The Deluge](../scripts/cards/Hexes/TheDeluge.gd) | Keep the one-line trigger and “all physical cards.” The physical-card category determines the scope. |
| [The Inferno](../scripts/cards/Hexes/TheInferno.gd) | Keep the enemy attack trigger and “all cards in their Frontline.” |
| [Vision of Odin](../scripts/cards/Hexes/VisionOfOdin.gd) | Use one duration for both outcomes. “Until end of turn, a creature gets −7 STR and −1 SPD, or +7 STR and +1 SPD if it’s Norse.” |
| [Vision of Tartarus](../scripts/cards/Hexes/VisionOfTartarus.gd) | “Until end of turn, a creature gets −3 STR and −3 RES for each creature in either player’s Abyss.” The count pools both players’ Abyss zones. |
| [Void Shield](../scripts/cards/Hexes/VoidShield.gd) | “When an enemy creature attacks one of your creatures, Void the attacker.” Name the outgoing card directly. |
| [Wheel of Fire](../scripts/cards/Hexes/WheelOfFire.gd) | Show the progression as Frontline → Reserve → Graveyard → Abyss. The first advance is free on resolution. Each optional Upkeep advance costs 1 mana. Keep the action tax and the condition that destroys the Hex on separate lines. |

### Charms

| Card | Recommendation |
| --- | --- |
| [Divine Lightning](../scripts/cards/Charms/DivineLightning.gd) | Keep. The field restriction is useful and the effect already fits in one sentence. |
| [Exorcism](../scripts/cards/Charms/Exorcism.gd) | “Cannot be negated. Choose a friendly creature. Negate all effects on it except its own until the end of your next turn. As this resolves, also destroy enemy cards still targeting it.” The destruction happens when Exorcism resolves. |
| [Fifa the Magical Arrow](../scripts/cards/Charms/FifaTheMagicalArrow.gd) | “Give a friendly Warrior +5 STR through its next combat. If it was an Archer and destroys its attack target this turn, you may pay 4 mana to return Fifa from your Graveyard to your hand.” The activation spends ordinary mana. |
| [Gungnir, the Spear of Odin](../scripts/cards/Charms/GungnirTheSpearOfOdin.gd) | Keep the attack trigger and target together. Preserve “attack target,” which is broader than creature. |
| [Heavy Snow](../scripts/cards/Charms/HeavySnow.gd) | Put the Weather sweep on its own line. Group the Anguine/Amphibious penalties together, then give the attack restriction a separate “While face-up” clause so it clearly applies to all creatures. |
| [Heroic Stand](../scripts/cards/Charms/HeroicStand.gd) | “If a creature you control has intercepted at least twice this turn, gain 7 mana.” Keep the count tied to a single creature. |
| [Hringhorni](../scripts/cards/Charms/Hringhorni.gd) | Lead with “When a Norse Warrior you control is destroyed.” Keep the deck source and the destroyed Warrior’s level as the cap. |
| [Mead of Poetry](../scripts/cards/Charms/MeadOfPoetry.gd) | Keep both short sentences. The preparation requirement is the important exception. |
| [Namburbi Apotropaeon](../scripts/cards/Charms/NamburbiApotropaeon.gd) | “This turn, combat and enemy card effects can’t destroy your creatures. You lose no Followers from combat.” Keep combat destruction broad enough to include Abyss replacement effects. |
| [Storm](../scripts/cards/Charms/Storm.gd) | Separate the Weather sweep from the recurring aura. Group loss of Aerial with its STR/SPD penalties and give the non-passive ability restriction its own sentence. |

### Equipment

| Card | Recommendation |
| --- | --- |
| [Bearded Axe](../scripts/cards/Equipment/BeardedAxe.gd) | “Equipped creature gets +5 STR. If it’s a Norse Warrior, it gets another +8 STR when attacking a Defensive creature.” |
| [Draupnir the Multiplying](../scripts/cards/Equipment/DraupnirTheMultiplying.gd) | “While equipped, gain 2 mana at the end of each of your turns. Send this to the Graveyard after the third payout.” |
| [Gambanteinn](../scripts/cards/Equipment/Gambanteinn.gd) | Lead with “Mages and Shamans only.” Put each equip-dependent mode on its own line beneath the shared mana cost. Preserve the end-of-turn duration on both. |
| [Reed Bow](../scripts/cards/Equipment/ReedBow.gd) | “Equipped creature gets +4 STR and gains Archer.” |
| [Runic Shortsword](../scripts/cards/Equipment/RunicShortsword.gd) | “+8 STR. Once per turn, a Norse Warrior can pick this up without spending an action.” |
| [Seven-League Boots](../scripts/cards/Equipment/SevenLeagueBoots.gd) | “Equipped creature’s SPD becomes 7.” Keep “becomes” to distinguish replacement from a bonus. |
| [Sharur, the Flying Mace](../scripts/cards/Equipment/SharurTheFlyingMace.gd) | Use three lines for equip eligibility and STR bonus, the SPD-rated equip action, and the SPD-rated hand-return response. Keep the broader equip eligibility distinct from the narrower effect target. Check the exact type grouping before recasting either list. |

### Structures

| Card | Recommendation |
| --- | --- |
| [Ancient Pyre](../scripts/cards/Structures/AncientPyre.gd) | Put the cost and uses-per-turn limit in the activation header. Give Convert and the Frontlined alternative separate lines. Keep the 0 RES destruction condition. |
| [Anointing Statue](../scripts/cards/Structures/AnointingStatue.gd) | Keep the once-per-turn sentence. Use the Status hint to explain what can be removed. |
| [Doorway to the Void](../scripts/cards/Structures/DoorwayToTheVoid.gd) | “If a creature on either side would go to the Graveyard, you may Void it instead.” Keep “instead” for the replacement timing. |
| [E2-abzu](../scripts/cards/Structures/E2Abzu.gd) | “Add a Mer Mage from your Abyss to your hand if its LVL is lower than your remaining mana after paying this ability’s cost.” Keep the temporary Void on its own SPD-rated line. |
| [Eridu, City of Sages](../scripts/cards/Structures/EriduCityOfSages.gd) | “To play this, discard a card. At Upkeep, gain 2 mana per Mage you control on the field.” Preserve the discard as an additional cost. |
| [Glitnir the Peaceful](../scripts/cards/Structures/GlitnirThePeaceful.gd) | Keep “All creatures must be summoned in Defensive stance.” |
| [Hildskjalf: Throne of Odin](../scripts/cards/Structures/HildskjalfThroneOfOdin.gd) | “Once per turn, look at the top 3 cards of either deck. Prime one to that deck and Shelve the rest.” The chosen card stays with the selected deck’s player. |
| [Sleep of the Duat](../scripts/cards/Structures/SleepOfTheDuat.gd) | Put the discard cost on its own line. Keep the first-turn threshold and name both sides of the field in the Divine Manifestation exception. Preserve the wake-on-entry behavior if it is separate from the ongoing Sleep condition. |
| [Warding Stone](../scripts/cards/Structures/WardingStone.gd) | “While this remains on the field, your opponent can’t attack during their next two turns.” Check when the turn count starts if this can enter during an opponent’s turn. |
| [Watchtower](../scripts/cards/Structures/Watchtower.gd) | Keep counter gain and Scout separate. “Scout (Activate): Remove 1 tactic counter to reveal an opposing hidden card on the field.” |

## Story and generated cards

| Card or variant | Recommendation |
| --- | --- |
| [Arnbjørn](../scripts/story/StoryArnbjorn.gd) | Leave the effect field empty. The story card has no printed ability text. |
| [Eidolon](../scripts/cards/Spells/ConjureEidolon.gd) | The token copies the source card’s effect text, then receives Silence, Spirit and the combat destruction rule. In token detail, show the silence state and the combat expiry so the inherited text cannot be mistaken for an available ability. |
| [Enki after Ascend](../scripts/Other/game_manager.gd#L3936) | Keep “Your creatures are immune to Hexes.” This version applies to all your creatures. |
| [Fenrir after Ascend](../scripts/Other/game_manager.gd#L3939) | Check the printed once-per-turn limit against the activation path, which checks whose turn it is and the 5 mana cost. Describe the actual target as a creature on either side of the field at least 2 levels below Fenrir. |
| [Pai Long after Ascend](../scripts/Other/game_manager.gd#L3942) | “Discard a Weather Spell to add a card from your deck to your hand.” Keep the discard tied to the deck selection. |
| [Palisade](../scripts/cards/Structures/PalisadeBarrier.gd) | “Only Aerial creatures can attack your Followers. If this is in your Frontline, only Aerial creatures can attack cards in your Reserve.” Both clauses apply while the barrier is active. For United Front, every attacker must be Aerial. |
| [Tonal Spirit](../scripts/cards/Creatures/TonalExtractionSpiritToken.gd) | Tonal Spirit’s text comes from an optional alternate-form profile field. The current profiles supply stats and types, so a further fixed effect line would duplicate the Power’s instructions. |
