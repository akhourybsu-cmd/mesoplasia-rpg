# Caden Zone Identity Runtime v1

## Blueprint v3 follow-up

The limited four-asset comparison below is historical. The detailed placement blueprint v3 decision activates Residential `CAD-YARD-35` at `(320,704)`, Commons `CAD-LAND-33` at `(160,576)`, and—following explicit user approval on 2026-08-30—Town Square `CAD-COMP-13` at `(700,288)`. Marketplace `CAD-COMP-10` remains rejected because it violates the live south-transition safety ring. See `CADEN_FIVE_ZONE_BLUEPRINT_V3.md` and `caden_zone_identity_blueprint_v3.json` for the authoritative current gate.

## Status

Blueprint v3 decision complete. Town Square `CAD-COMP-13`, Residential `CAD-YARD-35`, and Commons `CAD-LAND-33` are active; Marketplace `CAD-COMP-10` is rejected and unreferenced. This is not authorization for broader modular-library integration.

## Purpose

Use a small number of cleaned assets from the modular expansion library to make Caden's maintained zones more distinct without replacing their authoritative terrain, buildings, roads, collision, exits, NPC systems, or established composition.

## Selected Assets

| Zone | Source ID | Runtime role | Offline factor | Runtime dimensions | Pivot | Structural footprint | Final placement | State |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| Marketplace | `CAD-COMP-10` | South market entry | `0.60` | `124x103` | `(62, 99)` | `124x29` | Proposed `(448,608)` | Rejected; transition safety-ring conflict |
| Town Square | `CAD-COMP-13` | Northeast civic garden edge | `0.56` | `113x107` | `(56, 103)` | `113x30` | `(700,288)` | Active; user approved |
| Residential | `CAD-YARD-35` | Southwest domestic utility yard | `0.58` | `122x110` | `(61, 106)` | `122x31` | `(320,704)` | Active; moved below protected branch lane |
| Commons | `CAD-LAND-33` | Southwest natural boundary mass | `0.62` | `140x117` | `(70, 113)` | `140x27` | `(160,576)` | Active |

Wayfarer's Approach intentionally remains on v5 with no additional modular asset. Its open, rustic roadside character is part of the five-zone differentiation.

## Cleanup Contract

Each selected source cell is cropped and staged outside `res://`, converted to binary alpha, stripped of boundary red/yellow/green contamination, cleared of tiny detached components, padded by four transparent pixels, and resized once with nearest-neighbor interpolation. Runtime PNGs import at Godot scale `1.0`.

All four runtime audits require:

- no partial-alpha pixels;
- no RGB data under transparent pixels;
- no opaque canvas-edge pixels;
- no boundary-contamination pixels;
- one connected retained composition.

## Integration Contract

Residential and Commons live below dedicated `ZoneIdentityV1` nodes. Town Square instances the approved `TownSquareBlueprintV3Overlay.tscn` assembly once as `BlueprintV3CivicGarden`. Every active composition uses a bottom-center structural pivot. Collision covers only structural ground contacts such as a low wall, lantern post, storage, fence return, or rock-and-wood core. Existing authoritative zone nodes were not moved or replaced.

The protected contracts include every existing building, terrain mask, road and travel corridor, entry and exit, camera bound, dialogue NPC, ambient walker, interaction, and reserved Town Square center.

## Approval Gate

The visual gate is closed for the three active placements. The authoritative proof contains matched hidden/active views, both player depth orders, explicit collision/clearance overlays, full-zone captures, and twelve current arrival views. Marketplace remains rejected.

The proof does not authorize any additional modular-library asset.

## Provenance And Tooling

The source library was created for this project using OpenAI image generation and remains subject to the library's `PROVENANCE_AND_USAGE.md`, OpenAI terms, and project policy. The review package carries those notes and the original source catalog.

Required tooling is Python 3 with Pillow plus Godot 4.7 Compatibility rendering. The reproducible pipeline is:

1. `tools/art/prepare_caden_zone_identity_gate_v1.py`
2. `tools/art/import_caden_zone_identity_runtime_v1.py`
3. `tools/art/render_caden_zone_identity_runtime_v1.gd` — approved three-asset hidden/active, depth, and collision proof
4. `tests/caden_zone_identity_runtime_v1_test.gd` — active decisions, exact placement, cleanup, collision, trigger rings, reserved civic center, and Wayfarer retention
5. `tests/caden_blueprint_v3_physics_smoke_test.gd` — real 24x24 Player blocking, adjacent bypass, and both depth states for all three active compositions
6. `tests/caden_marketplace_rights_clearance_test.gd` — Marketplace ChatGPT-delivery provenance, source-hash exceptions, official-terms basis, and runtime-manifest binding
7. `tools/art/build_caden_zone_identity_runtime_review_v1.py` — checksummed approved proof and release-clearance package

Every delivered file and script is covered by the package `SHA256SUMS.txt`.
