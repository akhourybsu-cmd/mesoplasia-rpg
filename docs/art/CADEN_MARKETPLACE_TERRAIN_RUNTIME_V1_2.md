# Caden Marketplace Terrain Runtime v1.2

## Decision state

The user approved the inactive Marketplace v1.2 comparison and then approved the active in-engine pilot on 2026-08-29. `Marketplace.tscn` references `res://assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1_2.png` exactly once, and the runtime is now the approved Marketplace baseline.

This approval does not authorize storefront replacement, new market assets, collision changes, route changes, active Commons terrain changes, or changes to Town Square and Wayfarer's Approach.

## Runtime contract

- Runtime SHA-256: `99757fe28552111674322d9574f7e355ba4b8ee0c5dcc28c8d30f49cf0d9b385`
- Dimensions: `896 x 640`
- Grid: `28 x 20` exact `32 x 32` cells
- Materials: nine grass variants, nine warm-stone variants, and eight transitions
- Footprint: exact 372 maintained-ground cells and 188 perimeter-grass cells
- Import: nearest-neighbor, scale `1.0`
- Alpha: fully opaque, with no partial-alpha or transparent-RGB pixels
- Collision: none; authoritative scene collision remains separate and unchanged

Only the approved composed runtime PNG entered `res://`. The original masters, harmonized atlas, preparation workspace, and large comparison evidence remain external. All twelve building-sheet storefronts remain deferred for vendor-bay footprint mismatch.

## Compatibility evidence

The active renderer instantiates the serialized scene for every after frame and uses the verified v1 terrain only as a transient override for matched before frames. Six pairs cover the full market, primary aisle and Player, north districts, south districts, Wayfarer arrival, and Town Square transition. A `1280 x 720` after frame is an exact nearest-neighbor enlargement of its `640 x 360` source.

## Rollback and approval

To restore v1, change only the `TerrainRuntime` ext-resource path in `Marketplace.tscn` to `res://assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1.png`. Do not modify route or collision nodes.

The approval is bound to active evidence ZIP SHA-256 `f013205e480e1fed8283772482a8cf0834aa300899e99a559db1985bf5d90f08`. The next authorized step is an inactive Commons terrain comparison against its approved Runtime v1; no Commons reference changes are implied.

## Current provenance status

The historical unverified-rights state is superseded by `assets/environments/caden/marketplace/caden_marketplace_source_rights_v1.json`. ChatGPT delivery provenance, the official OpenAI output-ownership terms, and a third-party-mark visual review support limited project distribution clearance. The user remains responsible for applicable law, authorized source inputs, and third-party rights.
