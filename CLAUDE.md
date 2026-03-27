# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ClaudeOtherGods** is a turn-based collectible card game (CCG) built in Godot 4.6, themed around mythological creatures and spells from Sumerian, Norse, Egyptian, and other ancient cultures. All scripting is in GDScript.

## Running the Game

There is no build script. Open `project.godot` in the Godot 4.6 editor, or from the command line:

```bash
godot --path .
```

The main scene is `res://scenes/mainfork.tscn`. The entry point is `MainMenu.gd`, which navigates to either the Mock Game (playable demo via `CombatMockGame.gd`) or the Deck Builder.

## Architecture

### Card Class Hierarchy

All cards extend from a chain of base classes:

```
Card (Resource)           # Stats, costs, state flags
└── BaseCard              # Hook interface (on_play, on_enter_zone, etc.)
    ├── CreatureCard      # Adds on_attack, on_defend, on_summon, on_death, on_move, etc.
    │   └── [specific creatures: Anzu.gd, AsagTheDestroyer.gd, ...]
    ├── SpellCard         # Must override resolve(); optionally override should_go_to_graveyard()
    │   └── [specific spells: BitMeseri.gd, CircleofRebirth.gd, ...]
    └── StructureCard     # Adds on_summon, on_removed, on_attacked
        └── [specific structures: WardingStone.gd, ...]
```

- `scripts/cards/card.gd` — base Resource with all shared fields (mana_cost, discard_cost, sacrifice_cost, shelve_cost, banish_cost, strength, resilience, speed, card_type enum, state flags)
- `scripts/cards/BaseCard.gd` — defines the hook interface overridden by specific cards
- Equipment cards attach to creatures and modify their effective stats via `get_effective_strength/resilience/speed()`

### Core Systems

- **`scripts/Other/game_manager.gd`** — Orchestrates all game logic: turn phases (MULLIGAN → MAIN → COMBAT → END), `play_card()`, `creature_attack()`, `resolve_combat()`, `end_turn()`. Central authority for all game state changes.
- **`scripts/Other/player.gd`** — Player state: mana, followers (100 = health), zones, deck. Each player has 27 zones.
- **`scripts/Other/Zone.gd`** — Generic card container used for all zones: hand, deck, graveyard, abyss, god slot, 3 power slots, 7 frontline slots, 7 reserve slots.
- **`scripts/Other/CardAction.gd`** — Action stack: cards push `CardAction` objects for deferred resolution.
- **`scripts/Other/CombatMockGame.gd`** — Test harness with pre-built decks for development/demo.

### Combat System

- **Attacker vs Attacker:** Higher strength wins; loser is sent to graveyard and its owner loses followers equal to the strength difference. Tie = both die.
- **Strength vs Resilience:** Strength > Resilience → defender dies; Resilience ≥ Strength → followers convert to attacker.
- **Speed:** Determines intercept priority. Higher speed intercepts lower-speed attackers automatically.
- **Frontline/Reserve:** Only frontline creatures can attack or be directly targeted.

### Key Patterns

**Adding a new card:** Create a `.gd` file in the appropriate subdirectory (`Creatures/`, `Spells/`, or `Structures/`), extend the relevant base class, and override hooks as needed.

**Card removal with hooks:** Always use `_send_to_graveyard_with_hook(card)` or `_send_to_abyss_with_hook(card)` (in `game_manager.gd`) instead of moving cards directly — these call `on_removed()` before the zone transition (critical for effects like WardingStone clearing attack restrictions).

**Attack restrictions:** Stored as `attack_restrictions` dict in `game_manager.gd` (player → turns remaining). WardingStone adds restrictions on summon and removes them in `on_removed()`.

### Zone Layout (per player)

| Zone | Count |
|------|-------|
| Hand | 1 |
| Deck | 1 |
| Graveyard | 1 |
| Abyss (banished) | 1 |
| God Slot | 1 |
| Power Slots | 3 |
| Frontline | 7 |
| Reserve | 7 |

### Deck Construction Rules

- Exactly 1 God card required
- Max 3 Power cards
- Legendaries: max 1 per 10 regular cards
