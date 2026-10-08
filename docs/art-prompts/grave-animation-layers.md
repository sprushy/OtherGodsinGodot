# Animated grave layers

Generated using built-in ImageGen on 2026-10-08. Original combined grave images are preserved. The clickable grave uses a static mound layer plus an independently drawn shovel. Every click toggles a six-degree shovel shift and emits dirt particles; per-zone pose is kept in the match controller. Snow/story boards select the snow mound layer.

Assets:

- `res://images/ui/zones/grave_tumulus_base.png`
- `res://images/ui/zones/grave_tumulus_snow_base.png`
- `res://images/ui/zones/grave_tumulus_shovel.png`

## grave_base

```text
Edit this exact game asset. Remove ONLY the entire shovel (wooden handle, shaft, metal blade) from the left side of the burial mound. Fill its former footprint with matching dark disturbed soil, grass and moss. Preserve EVERYTHING ELSE exactly: circular mound shape, every stone, entrance, camera, lighting, colors, scale, placement, square canvas and transparent padding. Keep the small disturbed soil patch where the blade was planted. Genuine transparent background with clean alpha edges. No new props. This is the static background layer for shovel animation.
```

## grave_snow_base

```text
Edit this exact snowy game asset. Remove ONLY the entire shovel (wooden handle, shaft, metal blade) from the left side of the burial mound. Fill its former footprint with matching snow, dark disturbed soil and sparse grass. Preserve EVERYTHING ELSE exactly: snow cover, circular mound shape, every stone, entrance, camera, lighting, colors, scale, placement, square canvas and transparent padding. Keep the small disturbed soil patch where the blade was planted. Genuine transparent background with clean alpha edges. No new props. This is the static background layer for shovel animation.
```

## grave_shovel_layer

```text
Extract ONLY the existing wooden D-grip iron shovel as an isolated transparent animation sprite. Remove the entire burial mound, grass, soil, stones, doorway and all background. Preserve the exact shovel silhouette, perspective, lean, weathered wood and iron, lighting, proportions and blade shape from the source. Include the complete shovel from the D-grip at its upper left to the blade at its lower right. No earth clods attached, no shadow halo. Frame the single diagonal shovel tightly with a little transparent padding. Genuine transparent alpha everywhere outside the shovel and INSIDE the opening of its D-grip. No other objects, no ground, no backdrop, no text.
```
