# Caden Building and Terrain Gate v1.1

## Scope

This gate evaluates the supplied building volumes and grass/stone sheet against the current authored Caden zones. It does not authorize or serialize a scene change. The active Marketplace, Residential, Commons, Town Square, and Wayfarer's Approach resources remain the baseline.

The reproducible preparation tool is `tools/art/prepare_caden_building_terrain_gate_v1_1.py`. The Compatibility renderer is `tools/art/render_caden_building_terrain_gate_v1_1.gd`. Both write only to an absolute package root outside `res://`.

## Verified source intake

| Master | Dimensions | SHA-256 |
| --- | ---: | --- |
| `caden_buildings_volume_1_master.png` | 1535 x 1024 RGB | `1f9bc86b2e91aecd9ad455e6ca768fccb2c8c9699cc653ec695202dd3bbcc8a4` |
| `caden_buildings_volume_2_master.png` | 1535 x 1024 RGB | `d4df1a8fd892cc16153e32aa8b97d7760df4a3d718b01f0c804853a4ad34895f` |
| `caden_grass_stone_terrain_master.png` | 1535 x 1024 RGB | `eaf2dbf53d955e8e92a71c7b04e63b38bcc66710a7e28a06dbfe3956d354508e` |

The `(1)` downloads are byte-identical duplicates and are excluded. All canonical masters remain outside the repository. Their checkerboard is baked RGB data rather than transparency.

## Building shortlist

Gate 0 prepares only these ten Residential candidates:

- `cad_bld_v1_r01_c01`, `cad_bld_v1_r01_c02`, `cad_bld_v1_r01_c04`, `cad_bld_v1_r01_c06`, `cad_bld_v1_r02_c02`
- `cad_bld_v2_r01_c01`, `cad_bld_v2_r01_c02`, `cad_bld_v2_r01_c03`, `cad_bld_v2_r01_c05`, `cad_bld_v2_r02_c05`

Each output uses a spatial crop, border-connected neutral matte reconstruction, binary alpha, bright boundary cleanup, primary-component isolation, broad neutral shadow removal, transparent RGB sanitization, and four pixels of safety padding. Offline nearest-neighbor factors are `0.75`, `0.875`, or `1.0`; external preview textures are shown at scale `1.0`.

Pivots use the bottom-center structural contact inside the central half of each silhouette. Every inactive comparison retains its target Cabin center and authoritative `128 x 96` collision. The renderer loads the preview PNGs from the external package and assigns them only to transient scene instances.

The Marketplace shopfront rows remain deferred because their complete structures cannot fit the protected `96 x 48` stall bodies at correct door/player scale.

## Terrain reconstruction

The terrain comparison uses material references `cad_ter_r01_c02` and `cad_ter_r02_c01`. It extracts nine native `32 x 32` patches per material without resampling, repairs them to common periodic edges, and constructs exact transition cells from the same grass and warm-stone family.

The result is an inactive material comparison, not an approved TileSet. The repetition, density, value contrast, and transition boards must be approved before a zone-specific terrain pilot is proposed. Existing dirt routes remain authoritative.

## Catalog and package

The external package contains an 88-row JSON/CSV source catalog covering 48 buildings and 40 terrain entries. Selected building rows record crop, cleaned bounds, scale family, target dimensions, pivot, fixed footprint, intended Cabin, status, approval state, source/runtime hashes, and cleanup audit. Non-selected rows remain explicitly deferred or incompatible rather than silently approved.

The package also contains:

- Cleaned-alpha, source-edge, and Player-scale building boards.
- Matched current/proposed full-zone and `640 x 360` Residential captures.
- Terrain repetition, transition, and current/candidate material boards.
- A revised v1.1 master prompt reflecting the current repository state.
- Provenance/licensing and tooling requirements.
- Preparation and render manifests, copied tooling, script hashes, and `SHA256SUMS.txt`.

No `.godot`, `.import`, `.uid`, `__pycache__`, hidden OS file, original master, or serialized scene derivative belongs in the package.

## Approval boundary

The package state is `pending_visual_approval_no_live_scene_changes`. Approval must name the accepted building candidates and separately decide whether the terrain material deserves a later zone-specific comparison. It does not authorize Marketplace storefront replacement, Commons buildings, Town Square or Wayfarer replacement, broad terrain rollout, collision changes, or gameplay geometry changes.

Source rights remain `project_internal_rights_unverified`. Do not publish, redistribute, commit as production art, or ship the derivatives until provenance and derivative-use permission are documented.
