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
