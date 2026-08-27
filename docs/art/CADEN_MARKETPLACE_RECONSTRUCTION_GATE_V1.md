# Caden Marketplace Reconstruction Gate v1

## Scope

This gate follows approval of the Wayfarer's Approach v5 structural recomposition. It reconstructs the live Marketplace contract and presents a composition plan and candidate shortlist for visual approval. It does not modify `Marketplace.tscn`, normalize a library source, or import a new asset into Godot.

The external package path is reported at handoff so its large review images and source-library metadata remain outside `res://`.

## Live contract

- Scene: `res://scenes/world/caden/Marketplace.tscn`
- Bounds: `896 x 640`
- Ground inset: `(96, 64)` through `(800, 576)`
- Eight authoritative stall bodies: `96 x 48` at `(208,160)`, `(336,160)`, `(560,160)`, `(688,160)`, `(208,464)`, `(336,464)`, `(560,464)`, and `(688,464)`
- Protected central aisle: `128` pixels wide
- West transition: Wayfarer's Approach, entry marker `(128,320)`
- South transition: Town Square, entry marker `(448,512)`
- Existing NPCs and dialogue: stall attendant, market shopper, and supply traveler
- Camera bounds, transition nodes, collisions, entry markers, NPC placement, dialogue, and gameplay behavior remain authoritative.

## Composition plan

The primary circulation spine runs from the west arrival through the central crossroads and south to Town Square. The eight stall footprints become four paired vendor districts: northwest food and daily goods, northeast cloth and household goods, southwest local goods, and southeast supply and backstock. Customer fronts face the protected lanes; storage stays behind or outside them. The north edge is reserved for service support and planting, while the south forecourt remains open.

## Candidate disposition

Recommended shortlist: `caden_sp_mkt_01`, `03`, `04`, `06`, `07`, `13`, and `14`.

Scale-compatible alternates: `02`, `08`, and `11`.

Deferred: `05`, `16`, and `caden_mega_mkt_02`. The travel display overlaps Wayfarer's identity, the notice cluster risks unapproved signage, and the mega-set's locked geometry does not fit the authoritative stall grid.

All fourteen Marketplace structure masters remain rejected under the v1.1 audit. Set pieces `09`, `10`, `12`, `15`, and mega-set `01` also remain rejected. They are not eligible for this gate.

## Tooling and evidence

`render_caden_marketplace_baseline_v1.gd` instantiates the untouched live scene and captures the full zone, west arrival, central aisle, south transition, candidate stage, and exact `1280 x 720` nearest-neighbor proof outside `res://`.

`build_caden_marketplace_reconstruction_gate_v1.py` verifies the 222-row v1.1 manifest and each shown candidate hash, builds the full-zone composition plan and native-scale candidate board, records scale family, target dimensions, pivot, footprint, audit state, intended placement, approval state, and provenance, and checksums the complete gate package.

## Approval boundary

This gate requests approval of the Marketplace composition and an explicit asset selection. Approval authorizes offline normalization and manual cleanup only for selected candidates, followed by one-zone integration and runtime comparison. It does not authorize alternates, deferred or rejected assets, lore-bearing signs, new NPCs, another zone, or changes to the established gameplay contract.
