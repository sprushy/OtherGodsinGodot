# Gravesite at the board props' high viewing angle

Asset: `res://images/ui/zones/gravesite_shovel_high_angle.png`

Generated using built-in ImageGen on 2026-10-08. Separate transparent near-overhead variant, matching the camera elevation described for `mana_well_ancient_high_angle.png`. Current grave button still uses the original asset.

## Initial overhead prompt

```text
Use case: precise-object-edit
Asset type: transparent PNG top-down gravesite prop for the clickable graveyard in Other Gods.
Input image: edit target and style reference, the existing gravesite with shovel.
Primary request: create a second version viewed straight down from overhead. Change the camera to a true top-down orthographic view, looking vertically down at 90 degrees toward the ground, with no horizon and no oblique camera perspective.
Subject: preserve the same freshly turned elongated mound of dark earth, weathered gray stone grave marker at its head, sparse grass and small earth clods along the edge, and aged wooden D-grip iron shovel planted blade-first in the mound. The shovel may lean enough that its shaft and D-grip remain recognizable from directly above, while staying stuck in the earth. Show the marker's top edge as it would actually appear from overhead, rather than showing a large upright front face.
Composition: grave's long axis runs vertically up the square canvas, headstone at the upper end. All parts contained within the frame with comfortable transparent padding. Compact cohesive silhouette, readable at small UI sizes.
Invariants: same painterly realism, natural dark soil, gray stone, aged brown wood and dark iron; one grave, one grave marker, one shovel; soft natural upper-left lighting. Preserve genuine transparent background and clean alpha edges.
Avoid: three-quarter view, isometric view, frontal view, horizon, scenery, ground plane beyond the mound, lettering, religious symbols, bones, skulls, characters, glow, border, UI, watermark, baked checkerboard.
```

## Final adjustment prompt

```text
Edit this isolated gravesite game asset. Make only a tiny camera-angle adjustment: tilt the camera 12 degrees from straight overhead, maintaining orthographic projection, matching near-overhead props viewed at 78 degrees elevation. Keep the long grave mound aligned vertically in the square image, and keep the stone marker small and very strongly foreshortened at its top end. The overhead earth surface should dominate. Preserve the planted shovel, wood grip, soil clods, stone materials, sparse grass, painterly realism, lighting and all proportions. Do not enlarge the headstone or show a tall frontal face. Keep every part fully visible.
The background MUST remain genuinely TRANSPARENT with alpha zero everywhere outside the isolated grave mound, marker and shovel. No gradient, brown haze, glow, vignette, shadow halo, scenery, floor plane or backdrop. Preserve clean cutout edges. No text, no additional objects.
```
