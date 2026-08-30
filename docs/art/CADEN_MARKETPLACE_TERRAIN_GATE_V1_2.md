# Caden Marketplace Terrain Gate v1.2

## Decision state

This inactive Marketplace terrain and source-fit comparison was approved on 2026-08-29 for a limited active pilot. Its decision evidence remains immutable in the external review package. The active implementation and current visual gate are documented in `CADEN_MARKETPLACE_TERRAIN_RUNTIME_V1_2.md`.

The supplied replacement prompt describes Marketplace as a greybox, but that premise is stale relative to the live repository. This gate therefore compares only a source-derived terrain improvement and does not replace the approved market structures by implication.

## Source-fit decision

All twelve storefront rows from building-sheet row 3 retain the Gate 0 status `deferred_marketplace_stall_footprint_mismatch`. A complete storefront would exceed the established shallow vendor-bay role, compete with the protected `128 px` central circulation spine, or require moving an approved stall anchor. The current eight Runtime v1 vendor visuals remain the correct baseline.

## Terrain candidate

- Candidate SHA-256: `99757fe28552111674322d9574f7e355ba4b8ee0c5dcc28c8d30f49cf0d9b385`
- Dimensions: `896 x 640`
- Grid: `28 x 20` exact `32 x 32` cells
- Materials: nine calm-grass variants, nine warm-stone variants, and eight transitions
- Footprint: the exact existing 372 maintained-ground cells and 188 perimeter-grass cells
- Collision: none; all scene collision remains separate and unchanged

The candidate turns the current four paved pads and earth lanes into one continuous maintained warm-stone court. It improves material cohesion and visual fullness, but reduces the existing dirt-versus-paver district distinction. That tradeoff remains a visual decision.

## Evidence and boundary

The Compatibility renderer instantiates the live Marketplace scene and swaps only the transient `TerrainRuntime` texture in candidate instances. Six matched pairs cover the full market, primary aisle and Player, north districts, south districts, west arrival, and Town Square transition. The separate `1280 x 720` frame is an exact nearest-neighbor enlargement of its `640 x 360` source.

The original source masters, harmonized atlas, and preparation workspace remain outside `res://`. Rights remain `project_internal_rights_unverified`; do not publish or ship the derivative until creator, license, and derivative-use permission are documented.

## Approval options

1. Accept for a limited Marketplace terrain pilot.
2. Request targeted palette, contrast, court-boundary, or material-hierarchy corrections.
3. Retain Marketplace Runtime v1 terrain.

Decision recorded: `ACCEPT LIMITED MARKETPLACE TERRAIN PILOT`. Continue only through the separate active in-engine visual gate.
