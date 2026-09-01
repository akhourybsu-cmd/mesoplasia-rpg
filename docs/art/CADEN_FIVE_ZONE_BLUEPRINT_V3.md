# Caden Five-Zone Detailed Placement Blueprint v3

## Result

This pass implements the blueprint's constrained rollout without broadening its approval scope.

| Zone | Final state | Result |
| --- | --- | --- |
| Wayfarer's Approach | Protected | v5 retained byte-for-byte; no new identity asset or scene reference. |
| Marketplace | Active blueprint v3 | Paving softened with 24 restrained grass cut-ins; fixed stall bays read as two vendor streets; service stock moved behind the south vendors; the 128-pixel spine and both entries remain open. |
| Town Square | Active blueprint v3, user approved | The versioned civic-garden assembly is referenced once at the northeast plaza edge. Architecture, terrain, plaza, roads, NPCs, reserved center, and existing collisions remain unchanged. |
| Residential | Active blueprint v3 | Ten fixed homes now read as property groups through three L-return fence corners, wider gates, clustered edge planting, eight trees, and a route-safe domestic utility yard. |
| Commons | Active blueprint v3 | Planting is consolidated into four boundary masses around a broad central lawn; six perimeter trees and exactly two rest pockets preserve the L-route. |

All new or moved scene positions use integer coordinates. New placements use scale `1.0`, no rotation, no mirroring, nearest-neighbor pixel display, bottom-contact depth sorting where appropriate, and object-specific base collisions.

## Protected geometry and transitions

| Zone | Camera bounds | Protected entries | Protected exits |
| --- | --- | --- | --- |
| Wayfarer's Approach | `1024x640` | `arrival (128,320)`; `from_town_square (864,320)`; `from_marketplace (512,128)` | `ToTownSquare (960,320)`; `ToMarketplace (512,64)` |
| Marketplace | `896x640` | `from_wayfarers_approach (128,320)`; `from_town_square (448,512)` | `ToWayfarersApproach (64,320)`; `ToTownSquare (448,576)` |
| Town Square | `960x704` | `from_wayfarers_approach (160,352)`; `from_residential (800,352)`; `from_marketplace (480,160)`; `from_commons (480,544)` | `ToWayfarersApproach (64,352)`; `ToResidential (896,352)`; `ToMarketplace (480,64)`; `ToCommons (480,640)` |
| Residential | `1152x768` | `from_town_square (128,384)`; `from_commons (576,640)` | `ToTownSquare (64,384)`; `ToCommons (576,704)` |
| Commons | `1024x704` | `from_town_square (128,352)`; `from_residential (512,128)` | `ToTownSquare (64,352)`; `ToResidential (512,64)` |

The twelve exact arrival markers above form six bidirectional seams. Runtime tests preserve the paired destination IDs, entry IDs, camera bounds, and persistent Player behavior. Final Compatibility captures cover both arrival sides of every pair.

## Marketplace placement manifest

### Terrain and routes

- Active terrain: `marketplace_terrain_runtime_v1_3.png`, SHA-256 `b38224635d629980cd342d13a8ed50238224edfdaf9ae378ff91d8eb5a805e33`.
- Composition: native `28x20` grid of `32x32` cells sampled from approved v1.2 with no scaling, rotation, mirroring, or interpolation.
- Maintained footprint: 348 cells; 24 asymmetrical grass cut-ins; 132 protected route cells retained.
- Authoritative clear routes: west lane `Rect2(0,256,288,128)`, cross lane `Rect2(96,288,704,64)`, and central spine `Rect2(384,64,128,576)`.
- The exact cut-in cells, rollback hash, generator hash, pixel audit, and rights status are recorded in `marketplace_terrain_runtime_v1_3.json`.

### Fixed stalls and blueprint organization

All stalls remain at the eight authoritative centers. `Visual` uses the listed bottom-center offset, `scale=(1,1)`, `centered=false`, and `depth_sorted_static_prop.gd`.

| Node | Runtime asset ID | Position | Visual offset | Collision offset / size | Role |
| --- | --- | --- | --- | --- | --- |
| `Stalls/Stall01` | `01` produce | `(208,184)` | `(-54,-61)` | `(0,-8) / 56x16` | North-west vendor street |
| `Stalls/Stall02` | `07` vendor counter | `(336,184)` | `(-60,-90)` | `(0,-12) / 64x24` | North-west vendor street |
| `Stalls/Stall03` | `03` folded cloth | `(560,184)` | `(-46,-54)` | `(0,-8) / 48x16` | North-east vendor street |
| `Stalls/Stall04` | `04` pottery | `(688,184)` | `(-47,-59)` | `(0,-8) / 56x16` | North-east vendor street |
| `Stalls/Stall05` | `07` vendor counter | `(208,488)` | `(-61,-90)` | `(0,-12) / 64x24` | South-west vendor street; inherited mirroring removed |
| `Stalls/Stall06` | `01` produce | `(336,488)` | `(-54,-61)` | `(0,-8) / 56x16` | South-west vendor street |
| `Stalls/Stall07` | `07` vendor counter | `(560,488)` | `(-60,-90)` | `(0,-8) / 56x16` | South-east vendor street |
| `Stalls/Stall08` | `14` supply cluster | `(688,488)` | `(-50,-57)` | `(0,-8) / 56x16` | South-east vendor street |
| `VendorBackstock/SouthwestDeliveryStock` | `06` barrel/sack stock | `(288,552)` | `(-53,-72)` | `(0,-8) / 56x16` | Backstock behind south-west vendors |
| `VendorBackstock/SoutheastDeliveryStock` | `13` empty crates/barrels | `(608,552)` | `(-48,-74)` | `(0,-8) / 56x16` | Backstock behind south-east vendors |
| `SpineEdgePlanters/NorthwestPlanter` | `caden_planter_box_01_v1` | `(352,256)` | sprite offset `(0,-32)` | `(0,-6) / 60x12` | Asymmetrical spine edge, outside the route |
| `SpineEdgePlanters/SoutheastPlanter` | `caden_planter_box_02_v1` | `(544,384)` | sprite offset `(0,-32)` | `(0,-6) / 60x12` | Opposing spine edge, outside the route |

The perimeter tree contacts are restricted to six anchors: `(64,120)`, `(832,120)`, `(48,512)`, `(848,208)`, `(112,608)`, and `(784,608)`. Each uses a `(0,-48)` sprite offset and `(0,-9) / 24x18` base collision. Existing four district planters, four lanterns, perimeter openings, three dialogue NPCs, and four bounded walkers remain intact.

`CAD-COMP-10` is explicitly rejected and has zero active references. Its proposed `(448,608)` placement and post collisions intersect the south transition rectangle plus the required 32-pixel safety ring.

## Residential placement manifest

### Protected home and lane anchors

The ten cabin centers and their collisions remain unchanged:

`Cabin01 (160,128)`, `Cabin02 (384,160)`, `Cabin03 (608,128)`, `Cabin04 (800,176)`, `Cabin05 (1024,128)`, `Cabin06 (160,592)`, `Cabin07 (400,624)`, `Cabin08 (752,608)`, `Cabin09 (992,576)`, and `Cabin10 (1024,256)`.

The existing domestic set pieces and residents remain data-backed and retain their scene references. No house, NPC, entry, exit, or branch-lane center moved.

### Property boundaries

| Node | Asset | Position | Sprite offset | Collision offset / size | Decision |
| --- | --- | --- | --- | --- | --- |
| `YardFences/Fence01` | straight fence | `(160,240)` | `FenceWest (-48,-32)` | `(-48,0) / 96x24` | Fixed center; east half removed to create a wide gate |
| `YardFences/Fence02` | straight fence | `(784,272)` | `FenceWest (-48,-32)` | `(-48,0) / 96x24` | Fixed center; east half removed to create a wide gate |
| `YardFences/Fence03` | straight fence | `(240,512)` | `FenceWest (-48,-32)` | `(-48,0) / 96x24` | Fixed center; east half removed to create a wide gate |
| `PropertyReturns/NorthwestReturn` | fence corner | `(64,240)` | `(0,-32)` | `(0,-6) / 24x12` | L-return for the north-west property |
| `PropertyReturns/NortheastReturn` | fence corner | `(688,272)` | `(0,-32)` | `(0,-6) / 24x12` | L-return for the north-east property |
| `PropertyReturns/SouthwestReturn` | fence corner | `(144,512)` | `(0,-32)` | `(0,-6) / 24x12` | L-return for the south-west property |

Each gate retains at least a 64-pixel approach. The authoritative fence-body centers remain unchanged, while the shorter structural collision expresses property ownership without closing travel lanes.

### Domestic identity and vegetation masses

| Node | Asset ID | Position | Pivot / sprite offset | Collision offset / size | Layer and cleanup |
| --- | --- | --- | --- | --- | --- |
| `ZoneIdentityV1/DomesticUtilityYard` | `CAD-YARD-35` | `(320,704)` | pivot `(61,106)` / sprite `(-61,-106)` | storage `(-18,-12) / 46x24`; fence return `(34,-8) / 24x12` | Depth-sorted solid; binary alpha; zero partial-alpha, transparent-RGB, edge, and contamination pixels; scale `1.0` |

The utility yard was moved below the protected south-west branch lane (`y=448..672`) instead of occupying it.

The eight tree contacts are grouped rather than evenly distributed: west `(80,96)`, `(304,96)`, `(80,704)`, `(336,704)`; east `(848,96)`, `(1072,96)`, `(816,704)`, `(1072,704)`. Each has a `(0,-48)` sprite offset and `(0,-9) / 24x18` base collision.

The twelve non-solid low plantings form three paired property-edge masses:

- North-west: `(112,80)`, `(144,96)`.
- North-east: `(816,80)`, `(848,96)`, `(1040,80)`, `(1072,112)`.
- South-west: `(80,672)`, `(112,688)`, `(304,672)`, `(336,688)`.
- South-east: `(1040,672)`, `(1072,688)`.

## Commons placement manifest

### Protected anchors and lawn

The L-shaped maintained route, entries, exits, NPCs, and fixed solid anchors remain unchanged:

`TreeCluster01 (192,160)`, `TreeCluster02 (800,224)`, `TreeCluster03 (768,512)`, and `RockCluster (288,544)`.

The broad central Quiet Green remains open. `WildflowerMeadow` is a non-solid visual at `(816,448)`, moved into the south-east mass rather than floating in the center.

### Boundary masses and rest pockets

| Node or group | Asset | Position(s) | Collision | Role |
| --- | --- | --- | --- | --- |
| `ZoneIdentityV1/NaturalBoundaryMass` | `CAD-LAND-33` | `(160,576)` | core `(2,-9) / 38x18` | South-west natural bank; pivot `(70,113)`, binary-alpha cleanup pass, depth sorted |
| `CommonsComposition/BoundaryUndergrowth` | `COM-14` | `(896,624)` | `(0,-8) / 56x16` | South-east boundary mass |
| `CommonsComposition/QuietRestPocket` | `COM-20` | `(640,480)` | bench `(21,-7) / 52x14`; rock `(-18,-9) / 20x18` | Existing south rest pocket |
| `CommonsComposition/NorthShadeRestPocket` | `caden_bench_02_v1` | `(640,208)` | `(0,-7) / 52x14` | Second and final rest pocket |
| Perimeter trees | two native tree silhouettes | `(96,128)`, `(320,128)`, `(704,128)`, `(928,160)`, `(96,576)`, `(928,576)` | each `(0,-9) / 24x18` | Six anchors supporting four unequal vegetation masses |

Seventeen non-solid boundary shrubs are regrouped into north-west, north-east, south-west, and south-east masses at integer coordinates. Their exact nodes and coordinates are serialized in `Commons.tscn`; the active test fixes the solid-tree count at six and keeps all solid contacts outside the protected route rectangles.

## Town Square approved activation

The active `TownSquare.tscn` references `TownSquareBlueprintV3Overlay.tscn` exactly once as `BlueprintV3CivicGarden`. The protected five building centers remain NW `(144,112)`, SW `(144,560)`, NE `(832,208)`, SE `(816,560)`, and S `(352,624)`; the central civic space and four roads remain unchanged.

The approved assembly contains one composition:

| Node | Asset ID | Position | Pivot / sprite offset | Collision offset / size | State |
| --- | --- | --- | --- | --- | --- |
| `BlueprintV3CivicGarden/CivicGardenEdge` | `CAD-COMP-13` | `(700,288)` | pivot `(56,103)` / sprite `(-56,-103)` | wall `(-4,-18) / 62x12`; lantern `(36,-22) / 10x14` | Active once by explicit user approval on 2026-08-30 |

## Wayfarer protection

`WayfarersApproach.tscn` remains SHA-256 `9c247c02e526f70a0e5ea1b5f927d9b3dee3f82bb948541dce522ce6e3b79613`. It has no Zone Identity reference. Its terrain, roads, buildings, wagons, props, collision, NPCs, dialogue, entries, exits, and rustic open composition are unchanged.

## Source cleanup, provenance, and shipping gate

- Active `CAD-YARD-35`, `CAD-LAND-33`, and `CAD-COMP-13` retain audited binary alpha, transparent safety padding, one connected runtime composition, zero partial-alpha pixels, zero transparent-RGB pixels, zero canvas-edge pixels, and zero boundary contamination. Their source crops, hashes, normalization factors, and cleanup counts are in `caden_zone_identity_runtime_v1.json`.
- Marketplace terrain v1.3 is fully opaque with zero partial-alpha and transparent-RGB pixels. It is a cell-preserving derivative of approved terrain v1.2.
- Zone Identity source art is recorded as created for Mesoplasia RPG / Caden under applicable OpenAI terms and project policy.
- Marketplace source-package status is `openai_output_provenance_verified` under the scoped operational record `assets/environments/caden/marketplace/caden_marketplace_source_rights_v1.json`. Project distribution is allowed subject to applicable law and third-party rights; this is not a non-infringement warranty.

## Validation and evidence

- Focused Marketplace, Residential, Commons, Commons contract, Zone Identity decision, Town Square, Wayfarer, and transition tests: PASS.
- Complete executable Godot regression suite: PASS, 26 of 26 scripts, including real-Player structural collision, adjacent-bypass probes, and the Marketplace source-rights binding.
- Final Compatibility renderer: PASS through ANGLE on Intel HD Graphics 630.
- Approved five-zone review: 17 pre-approval captures, 17 approved captures, three boards, and checksummed ZIP SHA-256 `be6817c7be36fc6a78571c83c06b2e4be841287e093427481944d231b04b1857`.
- Approved seam audit: 12 native `640x360` captures covering both sides of six live connections; checksummed ZIP SHA-256 `b3077b25d672710ca7141525204d796d3a7c7b6775cd7024860b6dc71f03aba4`.
- Authoritative acceptance proof: 22 hidden/active, depth-order, collision-clearance, and display captures; 12 seam captures; and the real-Player physics smoke test; checksummed ZIP SHA-256 `4830f409dfb6e3484c12b20b7c2de59233d23a0d6659c71e55538111ae473f52`.
- Release-clearance proof: the full acceptance evidence plus the scoped Marketplace provenance record, rights test, and disclosed corrected-source exceptions; checksummed ZIP SHA-256 `f044224797d4a9d51b0a7f9ce0c12ce580f5dd6eaf2082e6366f3a6afb2acd0b`.
- Known sandbox-only notices are limited to blocked `user://` log writes and Windows certificate-store access during headless tests. They do not affect scene loading or test outcomes.

## Rollback

- Marketplace: restore `TerrainRuntime` to v1.2; remove `VendorBackstock` and `SpineEdgePlanters`; restore the prior Stall06/07 visuals and prior perimeter-tree population.
- Residential: remove `PropertyReturns`; restore full-width fence visuals/collisions and prior landscaping positions; restore or remove `CAD-YARD-35` per its prior gate.
- Commons: remove `NorthShadeRestPocket`; restore prior meadow, shrub, and perimeter-tree positions; restore or remove `CAD-LAND-33` per its prior gate.
- Town Square: remove the single `BlueprintV3CivicGarden` scene instance from `TownSquare.tscn`; keep or remove the versioned assembly scene independently.
- Wayfarer: no rollback is required because it was not changed.
