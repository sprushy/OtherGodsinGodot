# Bot card prompt audit

Audited against the current card scripts, GameManager emissions, MatchManager
command handlers, MatchCommandRegistry, and local/network bot prompt entry points.
There are 45 emitted card-decision types, plus priority and intercept controls.
Each card-decision type has an answer in BotCardPromptPolicy or ThorPracticeBot.
PracticeFuzzPlayerBot and HostHuntingTacticsBot inherit those answers; the remote
NetworkClientSmokeBot delegates card decisions to the same implementation.

This is source and command-contract coverage. The maintained smoke matches do
not exercise every individual card, so the table is not a claim of exhaustive
runtime validation or optimal bot strategy.

## Card decisions

| Card(s) | Prompt type | Bot answer |
| --- | --- | --- |
| Advanced Building Techniques | `advanced_building_techniques` | Spend up to one available bonus mana |
| Apollyon's Demiurge | `apollyons_demiurge` | Choose an offered target; retain the summoned card identifier |
| Askelladen | `combat_retreat` | Compare retreat and combat outcomes; accept live or serialized actions |
| Blessed Knights | `blessed_knights_ward` | Choose the creature-ability ward |
| Blot Sacrifice | `blot_sacrifice` | Choose hand creatures within the seven-level budget and open zones |
| Breidablik | `breidablik_turn_start` | Return an offered priest when possible |
| Byggvir | `byggvir_reveal` | Submit an offered option dictionary |
| Doorway graveyard replacements | `doorway_choice` | Banish an enemy card; decline for an owned card |
| Durinn Secondborn | `durinn_secondborn_impact` | Choose an offered target |
| Fenrir | `fenrir_devour_impact` | Choose an offered devour target |
| First Sage Adapa | `first_sage_adapa_impact` | Choose an offered target |
| Foolish Optimism | `foolish_optimism` | Choose both an offered attacker and defender |
| Fourth Sage Enmegalamma | `fourth_sage_enmegalamma_impact` | Choose an offered target |
| Freyja, active | `freyja_active_open_sessrumnir` | Choose creatures up to the current summon limit, or skip |
| Gala-Tura | `gala_tura_destroyed` | Choose up to three offered cards |
| Gawain | `gawain_healing_hands` | Submit the offered status index and target |
| Giant Master Architect | `giant_master_architect_impact` | Choose an offered target |
| Gugalanna Bull of Heaven | `gugalanna_celestial_charge` | Choose an offered target |
| Harii Jarl | `harii_jarl_impact` | Choose a summon the bot can pay for |
| Huginn | `huginn_perish_prime` | Choose an offered prime target |
| Humbaba the Terrible | `humbaba_augury` | Choose an offered target |
| Hunting Tactics | `hunting_tactics` | Choose an offered supporter; retain the attacker identifier |
| Kur-Jara | `kur_jara_tree_of_life` | Choose low-value friendly creatures up to the required sacrifice count |
| Lailoken | `lailoken_reveal` | Choose an offered target |
| Masmassu Priest, Grindylow | `masmassu_priest_reveal` | Choose an offered target |
| Mummu, active | `mummu_entropy` | Prime an owned victim or shelve an enemy victim |
| Muninn | `muninn_perish_prime` | Choose an offered prime target |
| Nergal Lion | `nergal_lion_impact` | Choose an offered target; retain the demon identifier |
| Nusku, active | `nusku_active_core_flame` | Accept the initial stage, then choose an offered card |
| Nusku Firebearer | `nusku_well_of_fire` | Choose from the offered milled cards |
| Pai Long Autumn King | `pai_long_autumn_king_impact` | Choose an offered target |
| Ragnarok | `ragnarok_discard` | Discard an offered card |
| Rally the Troops | `rally_the_troops` | Choose an offered target |
| Again Walker | `resurrection` | Resurrect when mana and reserve space permit |
| Sharur's return replacement | `return_to_hand_choice` | Submit the dying card identifier and pay when eligible |
| Seventh Sage Utuabzu | `seventh_sage_utuabzu_impact` | Choose an offered target |
| Sixth Sage An-Enlilda | `sixth_sage_an_enlilda_impact` | Choose an offered target |
| Tatzelwurm | `tatzelwurm_dragon_heart` | Choose an offered target |
| Terror | `terror_impact` | Choose an offered target |
| Tezcatlipoca, active | `tezcatlipoca_active_titlacauan` | Choose up to two targets within the stored level budget, or skip |
| Third Sage Enmedugga | `third_sage_enmedugga_impact` | Choose an offered target |
| Tiamat, active | `tiamat_active_summon` | Choose an offered summon target |
| Tonal Extraction | `tonal_extraction` | Choose an offered target |
| Wheel of Fire | `wheel_of_fire_turn_start` | Pay an eligible advance against an enemy attachment |
| Wolf Cub, Wolf Adolescent | `wolf_adolescent_maturation` | Choose an offered evolution target |

Target selectors preserve offered UIDs even when a remote client's masked state
does not contain the card. Known cards are ranked by value and whether the effect
helps or harms their controller; unknown cards retain the authority's order.
Optional multi-card answers respect the card's count, level, and space limits.

## Other paths

- Afanc and Pictish Beast emit `reveal_effect` with a resolver method. MatchManager
  executes these through priority events; neither requires a card-choice answer.
- Priority and intercept retain their bot command paths. Practice bots use the
  shared response strategy; the minimal network smoke bot passes priority and
  declines interception to cooperate with its host-side test.
- Legacy UI prompt names for Book of Life, Oracle's Sight, En-Hedu-Anna, Habrok,
  and Aphrodite also have fallback command builders. They are not counted among
  the 45 authoritative card-decision types above.

## Gaps corrected

- Shared previously missing card decisions across the bot variants.
- Fixed comparing an array-valued action target to a Card in priority responses.
- Accepted serialized Askelladen retreat actions and target UIDs on remote bots.
- Corrected the return-to-hand command's fields.
- Routed Doorway choices through MatchManager's serialized prompt queue, including
  personalized network state delivery and declining through multiple gateways.
- Allowed matching turn-start prompt answers before upkeep finishes.
- Included Kur-Jara's required sacrifice count in the authoritative prompt.
- Carried prompt IDs on bot answers, suppressed repeated prompt delivery, and
  released rejected answer IDs so reissued prompts can be answered again.

## Verification

- Godot 4.7 `--check-only` passed for all affected bot variants, MatchManager,
  GameEventBroadcaster, CombatMockGame, and Kur-Jara.
- Maintained `practice_thor_summon` passed after the original crash fix.
- Maintained `practice_thor_fuzz`, two games with seed 1337, passed without script
  errors or missing-handler warnings.
- Maintained `practice_thor_intercept` passed, including duplicate prompt
  suppression and attack resolution, without script errors.
- Network Hunting Tactics smoke stopped during lobby authentication with
  `That account was not found`; it did not reach gameplay.
- Individual card interactions still need manual play checks. No visual QA or
  new gameplay probe scripts were used.
