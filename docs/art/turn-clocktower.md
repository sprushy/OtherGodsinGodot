# Turn clocktower art

Generated with the built-in image_gen tool, with transparent_background enabled. Original PNG alpha is preserved.

- `res://images/ui/clocktower/turn_clocktower.png` — stone tower and empty dial/belfry.
- `res://images/ui/clocktower/end_turn_bell.png` — separate bronze bell for interaction feedback.
- `res://images/ui/clocktower/stone_plaque.png` — shared limestone inset plaque with worn chiseled edges, generated from the tower art as a material reference.
- `res://scripts/ui/TurnClocktower.gd` — live countdown, remaining-time ring, bell hover/focus and swing animation.
- `res://audio/turn_bell.mp3` — user-provided `stu9-big-blrng-356829.mp3`, played on the SFX bus when the bell is clicked.

The active player's name sits on a plaque between the roof and clock, with a short added stone band for space. Both labels use the limestone texture, cropped to its solid stone bounds through an AtlasTexture (excluding faint alpha noise in the padding), with inset lettering shadows and padding inside the bevels. Text changes from gold to silver for the opponent's turn. A matching End Turn plaque sits at the bell's base; both the bell and this plaque share the existing end-turn button's hit area, sound, and swing animation. Match graves and abyss gates are spaced above/below the tower using their full art bounds, with gateways reduced by 10%.

The existing move timer supplies the countdown; no second timer is created. Opponent turns and spectators display an unavailable dial because the current protocol does not share the opponent’s move timer. The existing end-turn Button is reused, preserving its visibility, disabled state, signals, and command path.

## Stone plaque generation prompt

Use case: stylized-concept
Asset type: production UI texture for two small label plaques built into an existing mythic stone clocktower.
Input image 1: reference only, the existing clocktower artwork; match its weathered limestone material and painterly realistic rendering. Create a NEW isolated plaque, not another tower.
Subject: a SINGLE shallow horizontal rectangular carved limestone nameplate, exactly front-on orthographic, aspect ratio 4:1. Warm grey-beige weathered limestone with fine natural grain and a few restrained tiny cracks. A shallow inset central lettering bed in slightly darker medium stone, still visibly STONE rather than black. Broad clean empty center for dynamic text. Thin chiseled raised stone edge with worn square corners, subtle chipped bevel and light on upper-left edge, recessed darker contact seam around perimeter so it appears mortared directly into tower masonry. No metal frame, no gold border, no rivets, no hanging sign, no stand, no props, no decorative scrolls, no moss covering text area. Match the reference's old warm-grey stone surfaces. The plaque fills nearly the entire canvas, with minimal transparent padding. Isolated on genuinely transparent background, straight horizontal edges, no perspective. NO LETTERS, NO WORDS, NO NUMERALS: live text is supplied by the game. Crisp material details that read well at 72x18 game pixels.

## Tower generation prompt

Use case: stylized-concept
Asset type: production transparent game UI sprite for Other Gods, mythic strategy card game.
Primary request: a beautiful relatively small ancient stone clocktower, a collectible tabletop architectural miniature. FRONT ELEVATION, almost orthographic, symmetrical, tall slender silhouette, whole tower visible. Weathered warm grey limestone blocks, restrained moss in cracks, aged bronze Norse knotwork trim, dark slate pointed roof, subdued amber light. Painterly realistic high-end dark mythic boardgame art, tactile hand-carved materials, no cartoon style. Upper-middle tower has a large perfectly circular EMPTY dark charcoal clock dial with an elegant antique bronze rim and small gold hour ticks; NO HANDS, NO NUMERALS, NO TEXT, leaving the dial center clear for a live countdown. Directly BELOW the dial is an open belfry arch with a plain very dark interior, EMPTY (a separate clickable bell sprite will be inserted). Short stone foot/pedestal. Compact proportions, no sprawling scene or side buildings, no banners, no candles outside tower. Sprite fills centered 80% width and 94% height of portrait 2:3 canvas. Clock dial center at normalized (0.50, 0.38), outer radius 0.18 of canvas width. Empty belfry arch between normalized y 0.55 and 0.79, x 0.28 and 0.72. Soft light from upper left. Isolated on genuinely transparent background, no ground plane, no background, no cast shadow extending outside base. Clean alpha edges. Readable at 160x240 game pixels.

## Bell generation prompt

Use case: stylized-concept
Asset type: transparent game UI sprite, a clickable end-turn bell inside a small stone clocktower for Other Gods, mythic strategy card game.
Primary request: one beautiful antique BRONZE hanging temple bell, front elevation orthographic, perfectly centered entire bell visible. Narrow dark forged-iron hanging loop at top, flared bronze lip at bottom, visible bronze clapper, fine restrained Norse knotwork relief in a band around body, warm rubbed gold highlights along edges, subtle aged green patina in crevices. Painterly realistic premium mythic boardgame miniature, tactile hand-crafted metal, dark atmospheric mood but clearly readable at 54x66 pixels. Soft warm light from upper left. Bell silhouette occupies 82% canvas width and 90% height; no yoke beam, no stone arch, no tower, no stand, no background, no text, no runic lettering, no glow cloud. Isolated on genuinely transparent background with crisp clean alpha edges. Portrait 4:5 canvas. It should nest naturally into an empty dark belfry in a weathered limestone tower.
