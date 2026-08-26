# Mesoplasia RPG Running Change Log

This document records implementation changes from August 25, 2026 onward. Add new entries chronologically without removing earlier history.

## 2026-08-25 - Tracking established

### Scope

- Established this project-level running change log at the user's request.
- Added a repository rule requiring future implementation tasks to append their changes, validation, and limitations here.

### Baseline

- The completed Wayfarer's Approach Runtime v1 implementation is the starting baseline.
- Its detailed asset inventory, scene changes, source limitation, and validation are recorded in `docs/art/CADEN_WAYFARERS_APPROACH_RUNTIME_V1.md`.

### Files changed

- `AGENTS.md`
- `docs/CHANGELOG.md`

### Validation

- Documentation-only setup; no runtime behavior changed by this entry.

## 2026-08-25 - Wayfarer's Approach refinement v1.1

### Scope

- Refined the completed Wayfarer's Approach environment without changing its footprint, routes, entry markers, exits, camera bounds, dialogue, or gameplay behavior.
- Replaced the single repeated grass tile with a deterministic 32 x 20 mix of all eight existing shared Caden grass variants.
- Softened the traveler-yard dirt and trampled-grass overlays so the rest area blends into the lawn while remaining readable.
- Strengthened the map edge with restrained undergrowth shading and additional reused trees and shrubs, keeping every transition opening clear.
- Added a few shared ground-detail accents to connect the traveler yard and open lawn to the surrounding environment.
- Assigned distinct existing Caden character SpriteFrames to the three preserved travelers; their positions, conversations, and roles are unchanged.

### Files changed

- `AGENTS.md`
- `docs/CHANGELOG.md`
- `docs/art/CADEN_WAYFARERS_APPROACH_RUNTIME_V1.md`
- `scenes/world/caden/WayfarersApproach.tscn`
- `scenes/world/caden/wayfarers_approach/WayfarersGroundLayer.tscn`
- `tools/art/build_caden_wayfarers_approach_resources_v1.gd`
- `tests/caden_wayfarers_approach_runtime_test.gd`
- Updated runtime preview images under `docs/art/previews/wayfarers_approach/`.

### Validation

- Godot 4.7.2 asset-builder script: PASS; road TileSet, road scene, and varied ground scene regenerated.
- `res://tests/caden_wayfarers_approach_runtime_test.gd`: PASS; now also checks the 640-cell/eight-variant ground mix and distinct character visuals.
- `res://tests/caden_zone_transition_test.gd`: PASS; all Caden connections, entry placement, persistent Player behavior, and camera limits remain valid.
- Compatibility-rendered full-zone and 640 x 360 gameplay previews: visually reviewed; no rectangular edge artifact, clipped landmark, obscured transition, or road seam found.
- Godot 4.7.2 headless editor scan/import: PASS; no missing-resource or scene parser error.
- Godot emitted only the known sandbox notices for user-log writes and Windows certificate-store access; both test processes exited successfully.

### Remaining limitation

- The originally requested transparent PNG masters and ZIP remain unavailable. The supplied JPEG-derived runtime library is unchanged; replacing it with the lossless masters remains the only known source-art fidelity gap.

## 2026-08-26 - Wayfarer limited transparent-source pilot v1

### Scope

- Imported only the approved `sp_way_05_bench_luggage_lantern` and `sp_way_07_hitching_rail_barrels` transparent sources from Caden Mega Asset Library v1.1.
- Normalized both offline at `0.1875` with nearest-neighbor sampling, applied manual halo/shadow/fringe/fragment cleanup, and retained two pixels of transparent safety padding.
- Added the cleaned runtime PNGs at Godot scale `1.0`, structural bottom-center pivots, object-specific collision shapes, and player-relative ground-contact depth sorting.
- Placed `05` in the open right-side rest lawn and `07` beside the traveler yard without altering the inn, roads, exits, collision corridors, NPCs, or camera bounds.
- Kept `06` and `08` unselected, `11` through `15` deferred, and all user-rejected buildings/set pieces out of the runtime pilot.

### Files and systems changed

- Added two selected source PNGs under `assets/source_art/caden/environment/wayfarers_approach/pilot_v1/`.
- Added two cleaned runtime PNGs under `assets/environments/caden/wayfarers_approach/props/pilot_v1/`.
- Added `wayfarers_approach_pilot_runtime_v1.json` with source/runtime hashes, cleanup counts, pivots, scale, and collision metadata.
- Added two reusable pilot prop scenes and `scripts/world/depth_sorted_static_prop.gd`.
- Updated `scenes/world/caden/WayfarersApproach.tscn` and its runtime contract test.
- Added reproducible normalization, render, and comparison-board tools plus eight 640 x 360 review captures and one comparison board.
- Updated `docs/art/CADEN_WAYFARERS_APPROACH_RUNTIME_V1.md`.

### Validation

- Pilot normalization tool: PASS; exactly two outputs, approved source hashes, 0.1875 nearest-neighbor scaling, runtime scale 1.0 metadata, zero edge-touching pixels, and recorded cleanup counts.
- Godot 4.7.2 headless import: PASS; lossless, non-mipmapped runtime imports generated with no missing-resource or scene parser errors.
- `res://tests/caden_wayfarers_approach_runtime_test.gd`: PASS; preserved routes and contracts, exact pilot count, hashes, pivots, object collisions, and both depth-sort states.
- Compatibility renderer: PASS; grass and road-adjacent before/after images plus player-behind/player-in-front captures generated at 640 x 360.
- Visual review: PASS for technical presentation; both pilot assets remain pending the user's two-asset in-engine approval gate.

### Remaining approval item

- Approve, revise, or reject the two pilot placements and their cleanup/depth-sorting results before any additional library asset is integrated.
