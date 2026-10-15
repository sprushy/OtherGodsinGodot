> QUARANTINED: this is a historical implementation description. The bell does not currently replace End Turn. See README.md.

# Reusable town bell

Instance `res://quarantine/town_bell/scenes/town_bell.tscn` under a Control or CanvasLayer. This is a
2.5D UI prop: a transparent, shaded bronze sprite with an independently drawn
rope and animated crown pivot. It has no match or menu dependencies.

The bell now includes an oak yoke, iron supports, and a side pulley so the
mounting and rope have a physical connection.

`res://quarantine/town_bell/scenes/end_turn_bell.tscn` is the compact match version with an End Turn
caption. It replaces the old button in local, practice, card-test, story, and
network match scenes. `CombatMockGame` connects `rang` to its existing end-turn
request flow, which handles discards and card effects before submitting through
`GameInput`. The prop stays visible but dimmed and noninteractive during upkeep,
pending stack actions, card selections, and the opponent's turn. Spectators and
finished matches hide it. Turn timeouts still use the shared request flow.

Assign the match sound on the root of `end_turn_bell.tscn` to share the recording
across all match modes.

- Default size: 320 × 360 canvas pixels; content stays centered at its original aspect ratio.
- Drag the rope or wooden grip downward, then release. A pull of at least 30%
  of its 62-pixel travel rings the bell. Short pulls return quietly.
- Mouse and touch are supported. Tab focuses the prop; Space/Enter rings it.
- The bell swings and the rope returns after release. A 0.65-second cooldown
  limits repeated strikes; hide, disable, or application focus loss cancels a drag.
- Only the lower rope and grip capture pointer input, leaving the bell body
  and transparent space available to the surrounding interface.

Assign your recording to **Ring Sound** on the root node in the Inspector.
The audio player allows four overlapping tails. **Audio Bus** defaults to SFX,
with Master as a fallback. Volume, swing angle, pull threshold, and cooldown are
also exposed. Without a recording, animation and signals still work silently.

Public hooks:

```gdscript
bell.rang.connect(_on_bell_rang) # Receives pull strength, from 0.1 to 1.0.
bell.ring() # Returns true if a strike was accepted.
bell.disabled = true
```

`pull_started` and `pull_released(strength)` are available for later integration.
`rang` fires once per accepted strike; the decaying swing does not produce extra
audio strikes. Attach gameplay behavior to that signal only when placing the prop.

Files:

- Scene: `res://quarantine/town_bell/scenes/town_bell.tscn`
- Controller: `res://quarantine/town_bell/scripts/TownBell.gd`
- Transparent artwork: `res://quarantine/town_bell/art/town_bell.png`

The artwork was generated with the built-in image generation tool. The rope,
grip, interaction, and animation are native Godot code. Generation prompt:

```text
Use case: stylized-concept.
Asset type: transparent game UI sprite for Other Gods, a mythic strategy card game.
Primary request: one beautifully crafted old town bell viewed from above, with convincing sculpted 3D volume, suitable as an interactive game prop.
Reference aesthetic: weathered antique bronze and dark gold, restrained interlaced engraved ornament, aged handworked metal, moody realistic fantasy game interface. Warm upper-left light, cool dark recesses.
Subject: just the BELL itself, broad round flared lip, tapering cast-bronze shoulder and crown, small iron suspension eye at its top. Oxidized recesses, fine hammered imperfections, simple interlaced bands, no writing.
Composition: square transparent canvas, centered upright, crown suspension eye at approximately x=50%, y=15%, broad flared lip at y=78%. High overhead oblique view (about 65 degrees above ground), showing the upper crown, curved shoulder, and thick circular lip with believable depth, no visible underside cavity. Bell occupies central 70% width and 75% height. Entire silhouette fits with clear transparent margins.
Constraints: isolated cutout with real alpha transparency. No rope (animated rope will be supplied by the game), no timber, no stand, no tower, no landscape, no floor, no cast shadow outside the object, no labels, no text, no watermark. This is a tactile realistic mythic game asset, no cartoon outlines, no glowing magic.
```
