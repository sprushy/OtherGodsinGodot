# Stealth Fog Asset Intake

This folder contains runtime textures and source-pack intake for stealth fog experiments.

## Runtime-Referenced Textures

These are currently loaded by `scripts/three_d/Main3D.gd`:

- `lelu_smoke_b7.png` - soft smoke silhouette mask.
- `lelu_cloud_noise_tiled.png` - broad moving cloud density.
- `seamless_noise_02.png` - fine seamless breakup/detail.

The older shadow-fog sprites remain here as fallback/reference material:

- `shadow_fog_03.png`
- `shadow_fog_05.png`
- `shadow_fog_08.png`
- `shadow_fog_09.png`
- `shadow_fog_10.png`
- `shadow_fog_15.png`

## Source Asset Packs

Raw packs copied in for later selection live under `asset_packs/`.

- `asset_packs/lelu_noise_pack/` - assorted smoke, noise, wind, flare, wave, and flipbook VFX textures.
- `asset_packs/seamless_noise_texture_pack/` - seamless shader noise tiles.
- `asset_packs/fog_atmosphere_gradient_pack/` - fog/depth color ramps and gradients.
- `asset_packs/smoke_puff_fx_pack/` - 14 simple white recolorable smoke puff sprites.
- `asset_packs/radial_glow_background_pack/` - colored radial glow backgrounds.
- `asset_packs/loose_flipbooks/T_smoke_flipbook.png` - standalone smoke flipbook sheet.

## Notes

- Source-pack images are intentionally not all wired into the shader. They are intake material for future fog/particle passes.
- Godot companion `.import` files may only appear for assets that the editor imports or that runtime code references directly.
- Preserve each pack's README/source files when moving or pruning assets so provenance is not lost.
