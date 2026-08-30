# Caden Town Square Runtime v3 and Terrain v1.3

## Decision

The five fixed-footprint Town Square facades are active as Architecture Runtime v3. The fine-brick Town Square atlas is active as Terrain Runtime v1.3 after a restrained tonal correction. The earlier coarse replacement-terrain candidate is rejected and was not imported.

The Town Square concept is authoritative only for palette, materials, lighting, architectural language, and density. Its signs, emblems, central monument, and exact geometry are not authoritative.

## Architecture

Five supplied building candidates were cleaned and normalized for the existing structural footprints. Binary alpha, transparent RGB, canvas-edge contact, bright fringe, broad neutral shadow, and detached-component checks pass for every runtime PNG. Bottom-center pivots use structural ground contact. The existing `StaticBody2D` centers and collision rectangles remain unchanged.

The active manifest is `assets/environments/caden/architecture/town_square/caden_architecture_runtime_v3_manifest.json`. It records source identity, scale family, normalization factor, runtime dimensions, pivot, collision footprint, status, intended placement, cleanup counts, pixel audit, and rollback data for every facade.

## Terrain

Terrain Runtime v1.3 preserves the exact v1.1 atlas dimensions, `32 x 32` cell grid, alpha topology, 58 documented tile coordinates, all dirt rows, TileMap cell data, and zero terrain collision. Only the grass and stone palette is harmonized to the approved maintained-zone material family. The stone correction is intentionally subtle so Town Square retains its formal fine-brick hierarchy.

The active terrain manifest is `assets/tilesets/caden/terrain/caden_terrain_runtime_v1_3.json`. Rollback remains a one-reference restoration to Runtime v1.1.

## Protected Contracts

- Five building centers and collision rectangles.
- Octagonal plaza, maintained corridors, distinct dirt roads, and blocked Terrebonne branch.
- Entries, exits, NPCs, interactions, reserved community space, and camera bounds.
- Nearest-neighbor display and Compatibility renderer.

## Evidence

- Architecture authorization ZIP SHA-256: `7ce5860927274ec7bfb8b3beb7247a5d32e81f737f5015742a1dc45234f675cd`.
- Tonal terrain authorization ZIP SHA-256: `e580e4582b6be79a937912a6f75b197b7a8a608da1803415d0235fb36411c771`.
- Active architecture assets pixel-match the approved architecture comparison.
- Active terrain captures pixel-match the approved tonal candidate across the full zone and five gameplay views.
- The `1280 x 720` plaza proof is an exact nearest-neighbor enlargement of the `640 x 360` capture.

## Licensing

The source art was provided by the project owner. Creator and generation-tool details were not supplied. Rights remain `project_internal_rights_unverified`; do not publish or ship these assets until rights are verified.
