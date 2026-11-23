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
| Blot Sacrifice | `blot_sacrifice` | Maximize the combined creature value within the seven-level budget and open zones |
| Breidablik | `breidablik_turn_start` | Return an offered priest when possible |
| Byggvir | `byggvir_reveal` | Compare a free unlock, useful activation, and returning a Mead card; submit the offered dictionary |
| Doorway graveyard replacements | `doorway_choice` | Banish an enemy card; decline for an owned card |
| Durinn Secondborn | `durinn_secondborn_impact` | Choose an offered target |
| Fenrir | `fenrir_devour_impact` | Choose an offered devour target |
| First Sage Adapa | `first_sage_adapa_impact` | Choose an offered target |
| Foolish Optimism | `foolish_optimism` | Compare legal offered attacker/defender pairs using combat outcomes |
| Fourth Sage Enmegalamma | `fourth_sage_enmegalamma_impact` | Choose an offered target |
| Freyja, active | `freyja_active_open_sessrumnir` | Choose creatures up to the current summon limit, or skip |
| Gala-Tura | `gala_tura_destroyed` | Choose up to three offered cards |
| Gawain | `gawain_healing_hands` | Prioritize harmful removable statuses and submit the corresponding offered index |
| Giant Master Architect | `giant_master_architect_impact` | Choose an offered target |
| Gugalanna Bull of Heaven | `gugalanna_celestial_charge` | Choose an offered target |
| Harii Jarl | `harii_jarl_impact` | Choose a summon the bot can pay for |
| Huginn | `huginn_perish_prime` | Choose an offered prime target |
| Humbaba the Terrible | `humbaba_augury` | Choose an offered target |
| Hunting Tactics | `hunting_tactics` | Choose an offered supporter; retain the attacker identifier |
| Kur-Jara | `kur_jara_tree_of_life` | Choose low-value friendly creatures up to the required sacrifice count; the activation itself is planned as a value engine (see Tree of Life below) |
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
| Sixth Sage An-Enlilda | `sixth_sage_an_enlilda_impact` | Void itself for the Dwelling the fetch deploys; keep the body only when it outprices the structure |
| Tatzelwurm | `tatzelwurm_dragon_heart` | Choose an offered target |
| Terror | `terror_impact` | Choose an offered target |
| Tezcatlipoca, active | `tezcatlipoca_active_titlacauan` | Maximize the combined enemy value within the stored level budget and two-target limit, or skip |
| Third Sage Enmedugga | `third_sage_enmedugga_impact` | Choose an offered target |
| Tiamat, active | `tiamat_active_summon` | Choose an offered summon target |
| Tonal Extraction | `tonal_extraction` | Choose an offered target |
| Wheel of Fire | `wheel_of_fire_turn_start` | Weigh enemy displacement, removal, or Void against mana and a lost summon opportunity |
| Wolf Cub, Wolf Adolescent | `wolf_adolescent_maturation` | Choose an offered evolution target |

Target selectors preserve offered UIDs even when a remote client's masked state
does not contain the card. Known cards are ranked by value and whether the effect
helps or harms their controller; unknown cards retain the authority's order.
Optional multi-card answers respect the card's count, level, and space limits.

## Other paths

`BotCardStrategy.gd` supplies explicit effect scoring to ThorPracticeBot and its
inheriting practice/server/story bots. It compares card investment, mana, the
cost of losing an affordable normal summon, visible board value, immediate
combat outcomes, and follower pressure. Commands still pass through GameInput
and MatchManager; card methods supply legal targets and timing. These are
heuristics, not a search over future game states.

| Effect family | Cards with additional decision logic |
| --- | --- |
| Targeted removal | Divine Lightning, Bit Meseri, Runic Spellbreaker |
| Combat modifiers | Snowball, Sap Strength, Vision of Tartarus, Fifa the Magical Arrow, Berserker Mead |
| Persistent bindings | Dromi, Gleipnir, plus the existing Wheel of Fire strategy |
| Automatic responses | Banishment, Spell Demolition, Sap, Sep Lemutti, Smite, Void Shield, Gungnir |
| Mass effects | Earthquake, Fires of Judgment, Famine, Occult Singularity, Fall of the Mighty, Bane of the Svartalfar, The Inferno, The Deluge |
| Protection and recovery | Exorcism, Namburbi Apotropaeon, Heroic Stand, Hringhorni, Tablet of Life, Book of Life, Circle of Rebirth |
| Control and information | Siren's Song, Absence, Light of Morning's Doors, Foolish Optimism |
| Board abilities | Alu, Lindwyrm, Lamashatu, Clay-Eaters, Ancient Pyre, Watchtower, Gawain |
| Equipment placement | Bearded Axe, Runic Shortsword, Reed Bow, Sharur, Draupnir |
| Structure placement | Ancient Pyre, Watchtower, Warding Stone |
| Active powers | Accelerated Fate, Oracle's Sight, Berserker Mead, Mech Factory, Palisade, Mana Guard; existing Call of the Valkyrie logic retained |
| Passive unlocks | Ancient Wisdom, Giant's Disdain, Summoned Sap, Terror, Rally the Troops, Norse Bloodlust, Hunting Tactics, Altar of Dreams, Myrkwood, Kurnugia, Ferocious Defence, Advanced Building Techniques, Feast of Ambrosia and Nectar |

Removal responses account for the combat that would happen without spending
the response. Cancelling a compelled attack (Foolish Optimism) by destroying
the bot's own attacker is compared as a complete line: the creature is lost
either way, so only combat losses beyond that casualty pay for the response.
Mass effects subtract friendly losses and respect visible
immunities. Conditional wipes do not inspect hidden enemy identities; Fall of
the Mighty is held when hidden field cards make its strongest-card result
uncertain. Temporary control/resurrection is discounted. Combat and removal
losses from a temporary steal are charged to the card's owner, so a borrowed
body dying is the owner's loss and destroying it never counts as gaining a
card. Exorcism counts lost
outside buffs, and Book of Life discounts silencing known utility creatures.

Automatic-response hexes honor `requires_priority_target_selection()` instead
of requiring an irrelevant target UID for counterspells. Passive powers are
never generically activated. Mana Guard submits an explicit amount based on
visible frontline pressure and existing Guard; Oracle's Sight and Mana Guard
are limited to one planned activation per bot turn. Duplicate bindings,
pending Clay-Eaters targets, and existing Lamashatu/Berserker Mead buffs are
avoided. Priority removal responses also skip a body already named by another
removal waiting on the stack, so a second Divine Lightning is not aimed at a
target the first copy is about to destroy. Supported spells may be prepared
when Drought requires it.

Complex random, movement-plan, alternate-form, and some multi-cost effects
retain their existing prompt handling.
Generic power unlocks requiring a discard or sacrifice are skipped because the
current unlock command cannot specify that payment. Tezcatlipoca's alternate-form
ability still requires separate initiation logic. Passive unlock scoring uses relevant
pieces as a conservative estimate of future value, not a full trigger forecast.

Verification: Godot 4.7 headless script checks and maintained interception,
Divine Lightning, Byggvir, and single-game practice fuzz smoke runs (seeds 1337
and 4242) passed during this
change. The maintained fuzz deck's non-creature pool is intentionally small;
these runs are regression checks, not individual gameplay coverage for all
cards in the table. No new probe scripts or visual QA were added.

- Wheel of Fire is prepared when a worthwhile enemy target exists. Priority
  responses rank legal targets by immediate removal, frontline displacement,
  action tax, discounted future removal, clearing interceptors, and preventing a
  losing attack. The bot avoids friendly, protected, already bound, and
  immovable targets, preserves
  profitable combat, and compares Wheel with Vision of Odin. Hidden creatures
  use a generic value rather than their concealed stats.
- Stat effects share explicit strength, resilience, and speed projections for
  buff selection, priority responses, and one-response attack planning. Tactical
  Retreat is forecast only when projected speed, immunity, suppression, and
  Guardian checks allow it; fighting and shelving remain separate choices.
  Vision of Odin, Hermes, existing supported stat effects, and stat equipment
  (including Seven-League Boots) use these projections. Speed forecasts retain
  equipment overrides, shapeshifter forms, and the normal 1–7 cap.
- Before declaring attacks, projected follower damage checks legal interceptors,
  special intercept hooks, Guard, follower-loss prevention, and combined lethal
  from available attackers. Earlier legal response windows can be used to buff
  an upcoming attacker past an equal-speed interceptor. An interception already
  chosen is preserved; a later attack response cannot retroactively evade it.
  Stat-buff projections skip hidden defenders and multi-response combos.
- Afanc and Pictish Beast emit `reveal_effect` with a resolver method. MatchManager
  executes these through priority events; neither requires a card-choice answer.
- Priority and intercept retain their bot command paths. Practice bots use the
  shared response strategy; the minimal network smoke bot passes priority and
  declines interception to cooperate with its host-side test.
- Legacy UI prompt names for Book of Life, Oracle's Sight, En-Hedu-Anna, Habrok,
  and Aphrodite also have fallback command builders. They are not counted among
  the 45 authoritative card-decision types above.
- Kur-Jara's Tree of Life is planned as a repeatable value engine, not only as
  an emergency dodge. A proactive activation gains the resurrected grave
  Divine/Priest (landing in reserve before frontline, discounted by the
  withheld advance turn) and re-arms the ability while more grave fuel remains;
  it pays Kur-Jara's missed fighting turns plus the level-difference friendly
  destructions from the cheapest friendlies, so targets above Kur-Jara's level
  are only chosen when they justify the deaths. With incoming losses the same
  activation doubles as a withdrawal that dodges combat and removal while
  still returning its value later. Face-up Kur-Jara on board also carries an
  engine premium while grave fuel exists: it is protected more, prioritized as
  removal against the opponent, and kept out of sacrifice payments.

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

## Ranked bot play

- Compare development, power use, removal, and combat before spending mana.
  Keep the 25-followers-per-card baseline and give lethal and prevention higher
  priority. Upkeep can choose mana to enable a strong spell or take Skoll's Sun
  Hunt when the free summon compares well with the normal summon.
- Compare up to two attacks, or a setup action followed by the attacks it opens.
  Account for visible interception choices, mana, Guard, and committed attackers.
  Replan after every resolution. Favor single attacks over United Front when the
  extra damage does not justify spending the partner's attack or using lower Speed.
- Give removal extra value when it opens direct attacks. On defense, compare each
  offered interceptor with letting the attack through and spend an interceptor
  only if its projected outcome is better.
- Cast Blot Sacrifice when the best group under seven levels pays for the spell
  and sacrificed creature. Cast Key of Solomon when the returned Demons justify
  the Animal payment. Compare friendly and enemy losses before playing Weather or
  unlocking Ragnarok. Saving Grace, Nimue, Beyla, Jiang Ziya, and Doorway to the
  Void have card-specific rules for when to use their effects.
- New ranked lists draw support cards from the shared strategy rules and select
  type-dependent Powers only when the deck has matching creatures. The practice
  fuzz smoke can exercise this generator with `smoke_ranked_bot_decks=1`.

### Marginal mana model

- Mana is priced at its marginal rate instead of a flat 1000-per-point
  (`CardStrategy.marginal_mana_value`). While the stock is at or below the
  saturation ceiling — the highest cost the remaining deck, hand, prepared
  activations, power unlocks, and god abilities can still reach, plus one
  turn of income — each point is worth full value. Past it the rate decays
  by `MANA_SATURATION_DECAY` per excess point, down to a floor.
- The floor depends on what can still absorb surplus mana
  (`mana_sink_profile`): an unbounded win-condition sink (Ancient Pyre
  conversion) keeps full value because every point converts directly into
  follower swing; defensive sinks (ManaGuard, Advanced Building Techniques)
  keep 45%; otherwise 15% covers action taxes, equipment, and Guard.
- Spending integrates the rate across the paid range (`mana_penalty`), and
  mana production is priced symmetrically (`mana_gain_value`), so ramp and
  upkeep income lose value in saturated positions too.
- The owner reads its own remaining deck composition: its deck cards keep
  their real value in `value()` instead of the generic unknown price.
- Upkeep compares the mana option (best play it enables plus the marginal
  value of the income) against the draw option (best play at the current
  budget plus the expected hand value of the card drawn from the bot's own
  deck, weighted by how thin the hand is).
- Thor practice bot prices one- and two-mana action taxes at the current
  rate (`_mana_rate`) and production triggers (Draupnir, Eridu, Heroic
  Stand, Book of Life, Mummu, Tonal Mastery, Masmassu, Pictish Beast) via
  `mana_gain_value`. The saturation scan is cached per decision tick.
- In a locked board state — neither side can push follower damage through —
  Ancient Pyre's conversion clock becomes the win condition: each conversion
  scores as direct progress toward the opponent's follower loss and the
  structure's value scales with how soon the clock ends the game, so surplus
  mana keeps being pumped into conversions.

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

### Marginal mana model verification (2026-11-15)

- `--check-only` passed for `BotCardStrategy.gd`, `ThorPracticeBot.gd`,
  `BotCardPromptPolicy.gd`, `PracticeFuzzPlayerBot.gd`,
  `HostHuntingTacticsBot.gd`, `ServerBotGameInput.gd`,
  `NetworkClientSmokeBot.gd`, and `BotGameInput.gd`.
- Maintained `practice_thor`, `practice_thor_intercept`, and
  `ranked_timeout_upkeep` passed on the final build.
- `practice_thor_summon` fails: the Thor bot zeroes the scripted player's
  followers by turn 4 through a big-strength rush. This reproduces with the
  mana economics fully neutralized and in a clean HEAD worktree, so it is a
  pre-existing failure, not caused by this change set.
- The `practice_thor_fuzz` timeout (stall with `stack=1 priority_player=-1
  pending_prompts=0`) is flaky and pre-existing: it reproduces at HEAD. A
  seed sweep (seeds 1337/1339/1341/1343, one game each) passed 2/4 at HEAD
  and 1/4 with this change set; the neutralized build also passed 1/2. The
  stall signature is identical across builds and turns, so the change set
  shifts game flow toward the pre-existing wedge but does not introduce it.

### Kur-Jara value-engine model verification (2026-11-16)

- `--check-only` passed for `BotCardStrategy.gd`, `ThorPracticeBot.gd`,
  `BotCardPromptPolicy.gd`, `PracticeFuzzPlayerBot.gd`,
  `HostHuntingTacticsBot.gd`, and `ServerBotGameInput.gd`.
- Maintained `practice_thor` and `practice_thor_intercept` passed.
- `practice_thor_fuzz` seed 1339 (the seed family that stalled in the
  2026-11-15 sweep) completed three matches with winners and no stalls,
  timeouts, or script errors given a larger harness window; the default
  seed-1337 run still stops at its known turn-10 wedge, and that game's log
  contains no Kur-Jara or Tree of Life activity, so the engine model is not
  involved. No new probe scripts or visual QA were used.

### God Death bleed clock and Fenrir/Storm summon-gate verification (2026-11-17)

- `--check-only` passed for `BotCardStrategy.gd`, `ThorPracticeBot.gd`,
  `BotStrategyPosture.gd`, `BotCardPromptPolicy.gd`,
  `PracticeFuzzPlayerBot.gd`, `HostHuntingTacticsBot.gd`,
  `BotGameInput.gd`, `ServerBotGameInput.gd`, and
  `NetworkClientSmokeBot.gd`.
- Maintained `practice_thor` and `practice_thor_intercept` passed.
- The default `practice_thor_fuzz` seed-1337 run stopped at its known
  quiescent wedge (`stack=0 priority_player=-1 pending_prompts=0`) at turn 8
  with no script errors in the run log. A clean HEAD worktree (659685b)
  reproduced the same failure — same seed, turn 8, identical signature — so
  it is the documented pre-existing stall (see `docs/bot-strategy-baseline.md`
  verification notes, which record seed 1337 wedging at index 0 turn 8 at
  true baseline), not caused by this change set.
- `practice_thor_fuzz` seed 1339 with a larger harness window (3 games,
  `smoke_match_frames=6000`, `smoke_stall_frames=720`) passed: three matches
  completed with winners (Thor 2, player 1) and no stalls, timeouts, or
  script errors.
- Individual card interactions (God Death unlock urgency, Fenrir held under a
  live Storm) still need manual play checks. No new probe scripts or visual
  QA were used.
