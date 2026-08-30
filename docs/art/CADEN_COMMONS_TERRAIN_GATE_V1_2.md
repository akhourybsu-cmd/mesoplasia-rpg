# Caden Commons Terrain Gate v1.2

## Decision state

The inactive terrain comparison was approved and the matched active pilot was verified on 2026-08-30. `Commons.tscn` now references `commons_terrain_runtime_v1_2.png` exactly once; collision, routes, scenery, population, and transitions remain unchanged.

The supplied replacement prompt predates the current Commons reconstruction. The live scene already has its Quiet Green, selected environmental art, layered perimeter, precise collision, depth sorting, and three visible residents. This gate therefore proposes only a source-derived material improvement; no building replacement applies to the Commons.

## Terrain candidate

- Candidate SHA-256: `d3e07ee474f9ebc6f40df4d5074f82768e597ac25da8c79efbc5c0f6ebc27c48`
- Dimensions: `1024 x 704`
- Grid: `32 x 22` exact `32 x 32` cells
- Materials: nine calm-grass variants, nine warm-stone variants, and eight transition cells
- Footprint: exact existing 108 route cells and 596 grass cells
- Quiet Green: exact existing `608,128,320,448` bounds
- Collision: none; all scene collision remains separate and unchanged

The candidate limits warm stone to the existing Town Square and Residential route bands. It adds no patio, plaza, landmark, or decorative path, keeping the Commons visibly quieter and more rural than the Marketplace and Town Square.

## Evidence and boundary

The Compatibility renderer instantiates the live Commons scene and swaps only the transient `TerrainRuntime` texture in candidate instances. Six matched pairs cover the full zone, both arrivals, route junction and Player, Quiet Green, and southern planted boundary. The separate `1280 x 720` frame is an exact nearest-neighbor enlargement of its `640 x 360` source.

The original source master, approved harmonized atlas, and preparation workspace remain outside `res://`. Rights remain `project_internal_rights_unverified`; do not publish or ship the derivative until creator, license, and derivative-use permission are documented.

## Approval options

1. Accept for a limited Commons terrain pilot.
2. Request targeted palette, contrast, route-edge, or material-hierarchy corrections.
3. Retain Commons Runtime v1 terrain.

Decision recorded: `APPROVED ACTIVE COMMONS TERRAIN RUNTIME v1.2`. The approval is bound to active evidence ZIP SHA-256 `6fc8c71f7217e05e14a26a40daf9746e6da3850359d3ca6fae60757b8cfffe92`.
