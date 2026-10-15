# Town bell — quarantined

Status: inactive. The user reported that the end-turn bell did not work in play
and requested restoring the original End Turn button.

The original button is active again. The later native 3D mechanical tower is also
archived separately in `../mechanical_turn_tower`. Active game scenes and
controllers do not reference either archived implementation.

This folder preserves the experimental artwork, controller, scenes, and historical
implementation notes for future repair. Internal resource paths point here.
Do not reconnect the bell to matches until the interaction has been repaired and
the user requests reactivation. The earlier headless smoke passing did not prove
that the rope interaction worked in the real UI. No sound recording was supplied.

- `scenes/town_bell.tscn`: standalone experimental prop.
- `scenes/end_turn_bell.tscn`: former match-sized variant.
- `scripts/TownBell.gd`: input, drawing, animation, and audio slot.
- `art/town_bell.png`: generated transparent bronze artwork.
- `implementation-notes.md`: previous setup notes and generation prompt.
