> QUARANTINED: historical implementation notes. The original End Turn button is active again. See README.md.

# Mechanical turn tower

The active end-turn control is a real 3D mechanism rendered into a transparent
UI viewport. A fixed base and bell sit inside an aged bronze sleeve. Its large slot
extends into the roof so the bell and rope remain visible from above.

The tower uses patinated cast bronze, oxidized iron, raised interlaced bands,
scroll reliefs, and an uneven octagonal stone plinth. Procedural surface shading
adds metal pitting, verdigris, worn highlights, mineral fissures, hemp fibers,
and wood grain on the grip. Its caption uses the game's UI font. The reliefs
stay outside the slot and leave the grip and its pull travel unobstructed.

Pull the rope downward and release to request ending the turn. A short pull
returns without ending it. Mouse, touch, and focused Space/Enter are supported.
The pull area follows the projected 3D grip and has a larger touch target. The
whole tower is clamped inside the game view, including its rope.

The sleeve and its internal rope guide turn 180 degrees when the authoritative
active turn changes. The old player's side then shows the solid casing; the new
player sees the slot. Pulling does not rotate it early while discard choices,
card effects, priority, or server confirmation remain pending. Upkeep and stack
locks disable input without making the tower disappear. Timeouts and bot turns
also rotate the tower through the same turn-state update.

The existing EndTurnButton remains an invisible availability and command bridge.
Its established validation, discard prompts, GameInput submission, and network
flow are preserved. The tower is a separate presentation node so it remains
visible when that button's availability hides it.

- `res://quarantine/mechanical_turn_tower/scenes/end_turn_tower.tscn`: reusable control and audio settings.
- `res://quarantine/mechanical_turn_tower/scripts/EndTurnTower.gd`: camera, turn-state presentation, and input.
- `res://quarantine/mechanical_turn_tower/scripts/TurnBellMechanism.gd`: native 3D meshes and materials.
- `res://quarantine/mechanical_turn_tower/shaders/ancient_tower_surface.gdshader`: shared aged surface shading.

Assign the supplied bell recording to **Ring Sound** on the scene root. Audio
defaults to the SFX bus, falling back to Master. No placeholder sound is used.

The earlier sprite experiment stays disconnected in
[`quarantine/town_bell`](../town_bell/README.md). The new tower does not
load its script, scenes, or artwork.

The maintained `card_test_turn2` headless smoke exercises mouse and touch drags,
short-pull cancellation, upkeep locking, two half-turns, and the closed opponent
side. It checks interaction and state; visual appearance still needs manual QA.
