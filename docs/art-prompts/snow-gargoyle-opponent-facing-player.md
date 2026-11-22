# Opponent deck gargoyle

Final wing-rake edit prompt:

```text
Use case: precise-object-edit. Transparent opponent gargoyle sprite.
Image 1 is the original gargoyle seen from BEHIND. Image 2 is the current FRONT-view edit target. It is supposed to be the SAME statue viewed from 180 degrees opposite azimuth. The front-view wings in image 2 are still WRONG: their rake was not reversed with the viewpoint and the long wing tips point forward toward the viewer/front paws. Correct the wing rake, not merely symmetry.
PHYSICAL GEOMETRY: In the original back view, both bat wings sweep BACKWARD along the creature's back, and their trailing outer tips project toward the viewer because we are behind it. In this new front view, that SAME backward sweep must project AWAY from the viewer. Reconstruct the wings pointing toward the REAR / UPPER area of the image, behind the shoulders and behind the torso. Both long outer wing tips must recede toward the upper-left and upper-right rear of the plinth, never droop forward toward the front paws or lower-left foreground. Reverse the front target's forward-pointing wing rake by about 180 degrees in the horizontal plane. Use foreshortening to show these rearward swept wings, with the membrane planes turned consistently with the original geometry. Their lower roots remain attached to the upper back, their long trailing tips lead backward/up-screen. This is a 3D change of wing perspective/rake, NOT flipping the whole sprite or its face.
Keep the FRONT face looking diagonally down-left toward us, same two horns (no third curled piece behind the head), same crouching body, paws and claws, same tail at the REAR behind the body, same round low plinth. Preserve original wing design, ribs and shape but reverse how their backward sweep appears from the opposite viewpoint. Same near-overhead camera and realistic weathered stone and snow, same identity, lighting, scale and framing. One isolated full statue with genuine transparent alpha, no background, no scenery, no text.
```

Generated with the built-in image_gen tool from `images/ui/zones/snow_gargoyle_card_protector_cw45.png`.

Output: `images/ui/zones/snow_gargoyle_card_protector_opponent_v7.png`.

Final direction corrected by user: lower right, 45 degrees. Built-in image_gen edit prompt:

```text
Use case: precise-object-edit. Transparent opponent deck gargoyle sprite.
Reorient the ENTIRE statue in the reference image to face diagonally toward the LOWER RIGHT corner (southeast) at exactly 45 degrees in the ground plane. The user's corrected direction is LOWER RIGHT, not lower left. Turn the whole statue consistently: head, face, chest, front paws, pelvis, wings and tail all share this new yaw. Its front paws and face point into the lower-right quadrant of the round plinth. Its rear pelvis and curled tail lie behind it toward the upper left. Maintain a high near-overhead camera and a clear three-quarter front view. Do not merely turn its head.
Keep this exact same gargoyle: two curved horns and pointed ears, carved face, crouching proportions, claws, two ribbed bat wings, curled tail, low ROUND plinth, weathered gray stone, fine realistic snow, photoreal rendering, same camera elevation and soft cold lighting. The wings keep their corrected BACKWARD sweep, now receding toward the upper-left rear relative to the new lower-right facing axis. The tail remains behind the body and never crosses in front of the front paws. No third horn or extra hook behind the head. Preserve coherent wing attachments and foreshortening. Keep the full statue visible at similar size on a square canvas. Actual alpha transparency, no background, no scenery, no text, no new decoration.
```

```text
Use case: precise-object-edit.
Asset type: transparent game sprite, opponent deck's stone gargoyle card protector.
Input image 1 is the edit target and exact identity/style reference. Render this SAME gargoyle from the opposite side, physically turned 180 degrees around its vertical axis while the overhead camera stays fixed. Our existing gargoyle looks away toward the upper right; this opponent variant must look TOWARD US, diagonally toward the lower left, with its face and chest visible. Keep the same high, near-top-down camera angle and foreshortening as the reference, suitable for the upper player's deck on a top-down game board.
Preserve identity: same ancient weathered gray stone, same pair of curved horns and pointed ears, same crouching proportions and clawed feet, same large ribbed bat wings, same ridged spine and curled tail, and exactly the same low ROUND stone plinth (not a square pedestal). Reconstruct the hidden face as a restrained carved gargoyle matching this creature, not a cute cartoon. Same fine realistic cold snow accumulated on upward-facing surfaces; realistic stone texture, wear, and cracks. Same soft cool lighting and rendering fidelity.
Composition: one isolated statue, fully visible including wings, feet, curled tail, and circular plinth; centered on square canvas with modest transparent margins. Keep its apparent scale comparable to the source. Actual alpha transparency with no background, no ground scenery, no text, no labels, no watermark. Change only orientation/view of the statue; no redesign, no decorative pedestal, no additional objects.
```

Tail correction (built-in image_gen edit, original identity reference plus first facing-player variant):

```text
Use case: precise-object-edit. Transparent opponent deck gargoyle game sprite.
Image 1 is the original gargoyle identity reference seen from behind. Image 2 is the edit target, the same gargoyle seen from the opposite side facing diagonally toward the lower left. Correct ONLY the tail's physical position in image 2: its tail grows from the back of its pelvis, so viewed from the front it must pass BEHIND the crouched body and wings, with any remaining curl along the REAR of the round plinth. Remove the long curling tail from the front of the plinth and from around/in front of the paws. The front paws should sit directly on the bare snowy stone base, no tail in front of them. Most of the tail should now be occluded by the gargoyle's body; at most a small rear arc is visible behind its flank. This must be anatomically the SAME statue as image 1, simply viewed from 180 degrees opposite azimuth with the same near-top-down camera angle. Do not relocate its anatomy to the viewer-facing side.
Keep image 2's face, horn shapes, ears, wings, crouching pose, claws, round plinth, snowy weathered gray stone, realistic rendering, scale, framing, lighting and transparent alpha background unchanged. No new body parts, no square pedestal, no scenery, no text. One isolated full statue with a genuinely transparent background.
```

Wings / extra protrusion correction (built-in image_gen):

```text
Remove the extra hook behind the two horns. Attach both wings evenly to the upper back with matching angles and consistent overhead perspective. Preserve the same gargoyle, front-facing lower-left orientation, tucked rear tail, round plinth, weathered stone, realistic snow, lighting, framing, and transparent alpha.
```

Wing rake correction (built-in image_gen):

```text
Reconstruct the same backward-swept wings from the opposite azimuth. Their long trailing tips now recede toward the rear / upper corners, away from the front paws and viewer, instead of pointing into the foreground. Preserve the face, two horns, crouching body, rear tail, round base, overhead camera, realistic stone and snow, and transparent alpha.
```
