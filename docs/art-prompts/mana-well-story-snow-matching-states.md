# Snowy mana well: matching states

Generated with the built-in ImageGen tool on 2026-10-08.

Final assets (transparent PNGs):

- `res://images/ui/zones/mana_well_story_snow_v2.png` — uncovered.
- `res://images/ui/zones/mana_well_story_snow_hatch_closed_v2.png` — hatch closed.
- `res://images/ui/zones/mana_well_story_snow_hatch_open_v2.png` — hatch folded fully back.

Snow reference: `res://images/story/snow_forest/albedo.png`, the board art used by the story scene. Hatch construction uses the user's photograph as a design reference. The fully open state is the common image reference for the closed and uncovered variants, keeping the well in the lower part of the shared canvas. These assets have no scene or gameplay integration.

## Open hatch, folded fully back

```text
Use case: precise-object-edit
Asset type: master transparent PNG snowy mana well with hatch folded ALL THE WAY BACK, for matching game states.
Input image 1: MASTER WELL REFERENCE. Use exactly this snow-covered ancient well, all stone block shapes, wood rim, iron straps, bucket and attached rope coil. Do not use a different well.
Input image 2: HATCH DESIGN REFERENCE ONLY. Reuse the exact circular hatch construction: broad weathered oak planks, simple long straight rusty iron reinforcing strap and two far-edge hinges. Ignore image 2's well body and framing.
Primary request: show this same well with that same hatch completely open and folded all the way back.
Door pose: the single full-size round hatch is swung back around the hinge at the far rim through a complete opening, approximately 180 degrees. It lies low, almost horizontal, fully behind the well, parallel to the top rim, rather than standing up, hovering above the pool or stopping partly open. The hinge connection remains clearly attached to the far rim. The full opening is unobstructed. The hatch is the same physical diameter needed to cover the entire opening and bear on the outer rim when shut, with its slightly overhanging edge, identical planks and simple straight ironwork. Keep the aged plank and reinforcing-bar construction consistent on the visible exposed face. No extra hatch, no detached lid, no ring-pull redesign.
Snow: both well and open hatch have substantial coverage of the same natural fine-grained off-white settled snow as image 1. Snow is dense granular crust with subtle neutral gray shading, wind-shaped flat accumulation, and occasional weathered wood/iron patches showing through. The exposed upward-facing hatch surface has been snowed on in the open position. No puffy cartoon frosting, marshmallow caps or blue snow. Keep the bucket and rope partly snow-covered.
Camera and well: keep the approved slightly tilted near-overhead orthographic view, almost circular rim, very little front wall visible. Preserve the source's still deep-blue pool, restrained glow, frosted boundary, aged wood and stone, moss and realistic textured finish.
IMPORTANT MATCHING FRAMING: compose a square game-state canvas with enough room for the FULL open hatch behind the well. Reduce the whole assembly proportionally only as necessary. Place the well in the lower part and the folded-back hatch in the upper part, leaving clear transparent safety margins on every side. This becomes the master framing for subsequent closed and uncovered versions, which will keep the well exactly at the same size and position. Show the entire hatch without cropping.
Background: genuine transparent alpha around and between all props. No ground plane, background snow landscape, forest, text, UI, logo, watermark, checkerboard or matte.
Avoid: upright hatch, partially open door, different lid, undersized lid, different well blocks, changed bucket arrangement, camera becoming isometric, new architecture or props.
```

## Closed hatch, same well and framing

```text
Use case: precise-object-edit
Edit target: the provided snowy mana well with its round wooden hatch folded fully back.
Task: create the CLOSED state of exactly this same asset. Make a strictly localized hatch-only edit.
Move the SAME circular planked hatch forward on its existing hinges and lower it completely shut across the well. Keep exactly the same plank layout, worn gray-brown oak, plank edge damage, straight rusty iron reinforcing bar, rivets, two hinges, and granular snow texture as the hatch already in this image. This is a rigid rotation of that same door, not a new door design. Its edge rests ON TOP of the broad outer wooden rim with visible plank thickness and a contact shadow. It overlaps the rim enough to be securely supported; it is not sunk into the pool or supported by an imaginary inner lip. Cover all the water.
CRITICAL: retain the entire well body at EXACTLY its existing pixel location, size, shape and camera angle. Keep every stone block, moss patch, wood segment, snow patch, rusty iron plate, bucket, tied rope and rope coil as in the source. Do not regenerate or redesign the well. Do not reframe, zoom, crop, recenter, enlarge or move it. Keep the same full square canvas, including the large empty transparent area above the well where the open hatch was. After moving the hatch closed, that former upper hatch area becomes transparent. The well must remain in the LOWER part of the canvas at exactly its current scale for switching between game states.
Preserve the same subtly tilted near-top-down view and diffuse winter lighting. Keep the heavy fine-grained subdued natural snow, matching the story board, on the lid and well. No inflated frosting, cartoon snow or new snow patterns.
Genuinely transparent alpha outside and between the objects. No ground, scenery, text, watermark, UI or matte background. Change only the door position and the water it occludes.
```

## Uncovered, same well and framing

```text
Use case: precise-object-edit
Edit target: the provided snow-covered mana well with its round wooden hatch folded fully back.
Task: make an UNCOVERED matching variant by removing ONLY the wooden hatch from the upper part of the image. Replace the removed door with genuinely transparent alpha. Keep the stationary hinge attachment plates on the far rim if present; remove only the moving door and its attached portions.
CRITICAL: the well, still blue pool, bucket, rope, all stone blocks, wood segments, iron plates, moss, snow texture, shadows and material colors must remain EXACTLY the same as the source. Do not regenerate or redesign them. Keep the well at the same size and the same position in the LOWER part of the canvas; no zoom, crop, recentering, shifting or enlargement. Leave the entire former hatch area above empty and transparent. Keep the same square canvas dimensions and margins even though it now has more empty space. This is a matching game-state sprite and must preserve the source well's registration.
Preserve the exact slightly tilted near-overhead camera and diffuse winter lighting. Heavy realistic fine-grained snow matches the source unchanged. Still deep blue pool and its frosted boundary unchanged.
Genuine transparent alpha outside and between objects. No new ground, floor, landscape, scenery, props, snow effects, text, logos, watermark, UI or matte. Remove the hatch only.
```
