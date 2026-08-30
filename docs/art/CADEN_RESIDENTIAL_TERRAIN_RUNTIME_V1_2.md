# Caden Residential Terrain Runtime v1.2

## Decision state

The user approved the inactive v1.2 comparison and then approved the active in-engine pilot on 2026-08-29. `Residential.tscn` references `res://assets/environments/caden/residential/terrain/residential_terrain_runtime_v1_2.png` exactly once, and the runtime is now the approved Residential baseline.

This approval does not authorize Marketplace, Commons, Town Square, Wayfarer's Approach, additional buildings, collision changes, route changes, or broad five-zone terrain integration.

## Runtime contract

- Runtime SHA-256: `828cfd64940b9bdd37fca40bac4d5a091432955d16f8e47b9701bef2028a98a0`
- Dimensions: `1152 x 768`
- Grid: `36 x 24` exact `32 x 32` cells
- Materials: nine grass variants, nine warm-stone variants, and eight transition cells
- Import: nearest-neighbor, scale `1.0`
- Alpha: fully opaque, with no partial-alpha or transparent-RGB pixels
- Geometry: exact v1 route mask; scene collision remains separate and unchanged

Only the approved composed runtime PNG entered `res://`. The original master, Gate 0 atlas, preparation workspace, and large review evidence remain external.

## Compatibility evidence

The active renderer instantiates the serialized scene for every after frame and uses the verified v1 texture only as a transient override for matched before frames. Six pairs cover the full zone, north homes, south homes, primary route and Player, west arrival, and Commons transition. A `1280 x 720` after frame is an exact nearest-neighbor enlargement of its `640 x 360` source.

The active review package binds the decision to the approved inactive review ZIP, records the one reference change, includes source-audit boards and all live captures, checksums its import/render/package tools and Residential test, and excludes hidden Godot/import/cache artifacts.

## Rollback and approval

To restore v1, change only the `TerrainRuntime` ext-resource path in `Residential.tscn` to `res://assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.png`. Do not modify the route mask or collision nodes.

The approval is bound to active evidence ZIP SHA-256 `7ef1484113357070bb867b7a02c3d70a1023798224af0904b17ff09b7bc77736`. The next authorized step is an inactive Marketplace source-fit and terrain comparison against its current approved runtime; no Marketplace reference changes are implied.
