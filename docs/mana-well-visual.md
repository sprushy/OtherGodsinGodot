# Animated snowy mana well

The turn-start mana option uses `res://scripts/ui/ManaWellButton.gd` in matches, card tests, practice and Story. The well stays visible with its hatch closed outside the local player's available upkeep window. It opens when the mana choice is available, and switches to the animated magic and steam when hovered. Clicking submits the existing `upkeep_choice` / `mana` command through `GameInput`; consuming either upkeep choice closes the well. Pending choices and turn-start prompts keep it disabled.

The button reserves the same 196 × 216 layout area as the draw deck. Match logs and player info panels are temporarily hidden via `CombatMockGame.SHOW_MATCH_INFO_PANELS`; their data and upkeep behavior remain intact.

Both decks are permanent table props, independent of the choice prompt. The opponent's deck sits above the well and the local deck below, with the well centered at the board separator's vertical midpoint. The whole prop column is centered on the board separator, keeping it clear of the side panels. All three use the same bounds and scale, fitting smaller windows together. The local gargoyle covers the deck when drawing is unavailable; the opponent has the same gargoyle facing lower right at 45 degrees, with backward-swept wings and its tail tucked behind the body. Its final texture is `images/ui/zones/snow_gargoyle_card_protector_opponent_v7.png`; the runtime protector scale compensates for its tighter framing so the two visible gargoyles match. The opponent deck is display-only and uses public deck counts. Its protector moves aside during the opponent's upkeep window.

Story uses the same arrangement and enables normal upkeep mana gains. Base gains are 4 mana on the first game turn and 5 afterward; the draw option gains 0 then 1 plus a card. Tooltips use the actual gain after applicable modifiers, including God Death.

For other decorations, instance `res://scenes/ui/mana_well_visual.tscn` and resize its `TextureRect` to the desired square bounds.

The `state` property chooses these matching textures:

| State | Appearance |
| --- | --- |
| `ManaWellVisual.WellState.CLOSED` | Snow-covered hatch covering the well. |
| `ManaWellVisual.WellState.OPEN` | Uncovered icy pool, with the hatch still attached and folded fully back. |
| `ManaWellVisual.WellState.ACTIVATED` | The same folded-back hatch and snowy well, ice-free swirling mana and moving rising steam. |

`set_activated(true)` activates the effect; `set_activated(false)` returns to the open resting state. Choose `CLOSED` explicitly to close the hatch. State changes swap artwork; the hinge movement itself is not animated.

The shader rotates and ripples only an ellipse inside the liquid, leaving the snow, stone, hatch, bucket and rope stationary. Steam is procedural noise advected upward and faded out; it is not baked into the PNG. Each scene instance owns its material and animation clock.

The Inspector exposes `animation_speed`, `swirl_speed` (negative reverses rotation), and `steam_strength`. Setting `animation_speed` to zero pauses both effects. The shader's `pool_center` and `pool_radius` use coordinates on the full image canvas and should only need adjustment if the art is reframed. Preserve the square aspect ratio and transparent space around the hatch when using the textures together.

Snow uses the story map at `res://images/story/snow_forest/albedo.png` as its art reference. The activated texture is `res://images/ui/zones/mana_well_story_snow_activated_hatch.png`. The older `mana_well_story_snow_v2.png` and `mana_well_story_snow_activated.png` omit the hatch and are not used by this scene.
