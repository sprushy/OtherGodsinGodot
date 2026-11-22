# Mechanical turn tower — quarantined

Status: inactive at the user's request. The original End Turn button is restored
across match, practice, card-test, and story modes. No active scene or controller
references this folder.

This archive preserves the 3D tower, rotating casing, bell, rope interaction,
aged materials, and historical implementation notes. Resource paths point to
this folder. The earlier sprite bell is archived separately in `../town_bell`.

- `scenes/end_turn_tower.tscn`: standalone tower and audio settings.
- `scripts/EndTurnTower.gd`: input, viewport, camera, and turn presentation.
- `scripts/TurnBellMechanism.gd`: geometry, materials, and bell animation.
- `shaders/ancient_tower_surface.gdshader`: bronze, iron, stone, hemp, and wood.
- `implementation-notes.md`: historical design and setup notes.
- `integration.patch`: removed controller wiring and smoke coverage, preserved
  for reference. Review before applying; surrounding game code may change.

Keep the tower disconnected until the user explicitly asks to resume it.
