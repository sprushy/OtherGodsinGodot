# Activated snowy mana well with attached hatch

Asset: `res://images/ui/zones/mana_well_story_snow_activated_hatch.png`

Generated with the built-in ImageGen tool on 2026-10-08 from `mana_well_story_snow_hatch_open_v2.png`. The attached hatch remains folded fully back. The liquid is ice-free and swirling; rising steam is added by `res://shaders/ui/mana_well.gdshader`, not baked into this texture. The reusable scene is `res://scenes/ui/mana_well_visual.tscn`.

## Final prompt

```text
Use case: precise-object-edit
Asset type: transparent PNG activated texture for an animated Godot mana-well scene.
Input image: EDIT TARGET, the snowy well WITH its wooden hatch attached and folded fully back.
Primary request: preserve this exact uncovered/open-hatch state, remove the water's ice, and activate the liquid mana.
THE HATCH MUST STAY: retain the entire folded-back snow-covered wooden hatch at the TOP of the image, its weathered planks, straight rusty iron strap and its two hinges connecting to the far rim. Do not remove, close, resize, move, crop or redesign it. Uncovered means this attached hatch is open, not absent.
LOCAL POOL EDIT: remove ALL ice from the water: no frozen slabs, patchwork ice surface, crystalline crust, floes or icy/slushy edge. Replace the pool with fully liquid cobalt-blue mana containing clear luminous cyan-blue swirling currents and a central spiral. Convincing fluid depth, vivid but controlled highlights. This is the activated water texture which will actually rotate and ripple in a Godot shader.
Do NOT bake rising steam or wisps into this image: the scene will add animated rising steam as a separate procedural effect, so this asset should contain the well and liquid surface only. Keep glow contained within the pool, with restrained reflected light on its inner wall.
CRITICAL: keep all other source pixels and composition unchanged: exact snowy well body, stone-block layout, weathered wood rim, iron plates, moss, granular natural story-board snow, bucket and attached rope at lower-right, hatch at the top, same apparent size and precise position, same subtly tilted near-overhead camera. Same full square canvas and transparent padding. No zoom, crop, reframing, recentering, changes to snow coverage or new architecture. This is a matching state of the same well.
Preserve genuine transparent alpha outside and between the well, hatch, bucket and rope. No floor, scenery, text, watermark, UI or matte.
Avoid: missing or detached hatch, hatch closed, ice in or around the liquid, steam baked into the texture, magic covering the hatch, changed well, cartoon snow, active particles baked outside the pool, extra objects or decorations. Change only the water and immediately adjacent inner-wall reflections.
```
