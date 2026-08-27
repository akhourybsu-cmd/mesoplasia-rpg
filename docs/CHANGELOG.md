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

## 2026-08-26 - Wayfarer Gate 1 evidence v2

### Scope

- Reconciled the existing two-asset Wayfarer pilot with the stricter Caden five-zone mapping prompt without modifying another zone or importing another library asset.
- Expanded the pilot manifest with catalog, placement, scale-family, target-dimension, structural-pivot, footprint, collision, sorting, provenance, licensing-status, and approval-gate metadata.
- Strengthened the deterministic post-cleanup audit for partial alpha, transparent RGB residue, canvas-edge pixels, bright boundary halos, and tiny detached components.
- Added a Compatibility-rendered ten-frame evidence workflow that writes outside `res://`, records deterministic camera/player/UI state, and includes the required exact 2x `1280 x 720` display proof.
- Added a native-scale comparison-board builder and complete artifact/tool checksums for the external Gate 1 review directory.

### Files changed

- `assets/environments/caden/wayfarers_approach/wayfarers_approach_pilot_runtime_v1.json`
- `tools/art/prepare_caden_wayfarer_pilot_runtime_v1.py`
- `tools/art/render_caden_wayfarer_gate1_review_v2.gd`
- `tools/art/build_caden_wayfarer_gate1_review_v2.py`
- `tests/caden_wayfarers_approach_runtime_test.gd`
- `docs/art/CADEN_WAYFARERS_APPROACH_RUNTIME_V1.md`
- `docs/CHANGELOG.md`
- Generated raw captures, manifest, board, and checksums in the external Gate 1 review directory reported at handoff.

### Validation

- Caden Mega Asset Library v1.1 verifier: PASS; expected archive SHA-256, 222 manifest rows, 217 production assets, 5 concepts, 297 checksummed files, no hidden artifacts, and no nested ZIP.
- Pilot normalization and post-cleanup audit: PASS; the two runtime PNG hashes are unchanged and all five rejection-audit counters are zero.
- Godot 4.7.2 Compatibility renderer: PASS; all ten deterministic frames were captured with the required dimensions and no review UI leakage.
- Review-package builder: PASS; all PNG dimensions and hashes match the screenshot manifest, all nine `640 x 360` board images remain native size, and the `1280 x 720` display frame is an exact nearest-neighbor 2x enlargement.
- Godot 4.7.2 headless editor scan and main-scene launch: PASS; no project parser, resource, or runtime error.
- `res://tests/caden_wayfarers_approach_runtime_test.gd`: PASS; preserved contracts, routes, collisions, sorting, runtime hashes, metadata, and cleanup audit.
- `res://tests/caden_zone_transition_test.gd`: PASS; all Caden transitions, arrival placement, persistent Player behavior, and camera limits remain valid.
- Known sandbox-only notices remain limited to Godot user-log/editor-settings writes and Windows certificate-store access.

### Remaining approval item

- Gate 1 remains pending user visual approval. Marketplace, Town Square, Residential Quarter, Commons, `06`, `08`, and every deferred or rejected library source remain untouched.

## 2026-08-26 - Wayfarer landscape revision v3

### Scope

- Revised the two-asset Wayfarer pilot in response to visual feedback that the lawn read as isolated placed objects rather than a landscaped environment.
- Used only approved repository terrain and planting art; no additional asset-library candidate was normalized or integrated.
- Consolidated north-lawn decoration into one meadow island, established a worn and planted rest grove around `05`, and moved `07` to the traveler-yard edge at `(650, 500)`.
- Concentrated repeated planting at landscape edges, retained practical worn ground around the hitching area, and preserved deliberate open lawn and road negative space.
- Kept all new ground planting walkable and added no collision, navigation, interaction, dialogue, or gameplay node.
- Generated an external v3 review package with native-size old-pilot-versus-landscaped comparisons, full-zone and overlap captures, exact 2x proof, metadata, and checksums.

### Files changed

- `scenes/world/caden/WayfarersApproach.tscn`
- `assets/environments/caden/wayfarers_approach/wayfarers_approach_pilot_runtime_v1.json`
- `tools/art/prepare_caden_wayfarer_pilot_runtime_v1.py`
- `tools/art/build_caden_wayfarer_landscape_revision_v3.py`
- `tests/caden_wayfarers_approach_runtime_test.gd`
- `docs/art/CADEN_WAYFARERS_APPROACH_RUNTIME_V1.md`
- `docs/CHANGELOG.md`
- Updated the established full-zone, gameplay, and exact-2x Wayfarer runtime previews.
- Generated the external `caden_wayfarer_landscape_revision_v3` review directory reported at handoff.

### Validation

- Compatibility-rendered full-zone and focused visual review: PASS; `07` reads as part of the traveler yard, `05` reads as a planted rest grove, and the road and open lawn remain legible.
- `res://tests/caden_wayfarers_approach_runtime_test.gd`: PASS; grouped landscape nodes, walkable planting, updated placement/collision probes, preserved contracts, route clearance, and depth sorting all validate.
- `res://tests/caden_zone_transition_test.gd`: PASS; all Caden connections, arrival placement, persistent Player behavior, and camera limits remain valid.
- Godot 4.7.2 headless editor import: PASS; no project parser, resource, UID, or scene error.
- Landscape review builder: PASS; six native `640 x 360` comparison frames, revised overlap/full-zone evidence, artifact hashes, and byte-exact `1280 x 720` nearest-neighbor proof generated.
- Known sandbox-only notices remain limited to Godot user-log/editor-settings writes and Windows certificate-store access.

### Remaining approval item

- The revised Wayfarer landscape remains the active visual gate. No work has begun in Marketplace, Town Square, Residential Quarter, Commons, or any additional library shortlist.

## 2026-08-26 - Wayfarer production landscape pass v4

### Scope

- Reworked Wayfarer's Approach as four legible outdoor rooms without changing gameplay geometry or importing another Caden Mega Asset Library candidate.
- Replaced five circular wear sprites and three translucent grounding stamps with a restrained inn apron, one connected traveler working-yard field, and one subordinate rest-grove surface.
- Generated the three binary-alpha surfaces deterministically from the live grass atlas and approved Wayfarer wear-texture colors, with no rotation, scaling, blur, antialiasing, or collision.
- Reduced unsupported planting scatter, concentrated the retained accents at the inn foundation, north-tree island, and two rest-grove edge masses, and kept the yard center and all roads/exits clear.
- Preserved the live inn, roads, transitions, collision corridors, fences, wagons, NPCs, dialogue, interactions, camera bounds, `05`, `07`, and their object-specific collision/depth behavior.
- Advanced the pilot metadata gate to the Wayfarer production-landscape visual comparison while retaining the prohibition on additional library candidates.

### Files and systems changed

- `scenes/world/caden/WayfarersApproach.tscn`
- `assets/environments/caden/wayfarers_approach/terrain/composed_v1/`
- `assets/environments/caden/wayfarers_approach/wayfarers_approach_pilot_runtime_v1.json`
- `tools/art/build_caden_wayfarer_landscape_surfaces_v1.py`
- `tools/art/render_caden_wayfarer_production_landscape_v4.gd`
- `tools/art/build_caden_wayfarer_production_landscape_review_v4.py`
- `tools/art/prepare_caden_wayfarer_pilot_runtime_v1.py`
- `tests/caden_wayfarers_approach_runtime_test.gd`
- `docs/art/CADEN_WAYFARERS_APPROACH_RUNTIME_V1.md`
- Updated established full-zone, gameplay, and exact-2x Wayfarer preview PNGs.
- Generated the external `caden_wayfarer_production_landscape_review_v4` visual-approval package reported at handoff.

### Validation

- Surface generator: PASS; three connected deterministic PNGs, exact source/output hashes, scale-1 metadata, binary alpha, zero partial-alpha pixels, zero edge-touching pixels, and no collision designation.
- Native-resolution visual inspection: PASS; authored ground fields replace the visible disc treatment, the yard center remains functional, the grove is distinct and subordinate, the north lawn remains intentionally open, and the main road remains dominant.
- Godot 4.7.2 Compatibility evidence renderer: PASS; one full-zone frame, six focused room/circulation frames, four overlap/depth frames, and one exact 2x display frame generated outside `res://` with deterministic state metadata.
- `res://tests/caden_wayfarers_approach_runtime_test.gd`: PASS; authored-surface metadata and imports, preserved routes and contracts, collision, and depth sorting validate.
- `res://tests/caden_zone_transition_test.gd`: PASS; all Caden transitions, arrival placement, persistent Player behavior, and camera limits remain valid.
- Godot 4.7.2 headless import and main-scene launch: PASS; no new project parser, resource, or runtime error.
- Review-package and checksum verification: PASS; native baseline crops, complete before/after evidence, exact nearest-neighbor 2x proof, artifact hashes, and tool hashes validate.
- Known sandbox-only notices remain limited to Godot user-log/editor-settings writes and Windows certificate-store access.

### Remaining approval item

- The v4 Wayfarer's Approach production landscape comparison is the active visual gate. Marketplace, Town Square, Residential Quarter, Commons, and every additional library candidate remain untouched.

## 2026-08-26 - Wayfarer structural recomposition v5

### Scope

- Reworked the v4 landscape at full-zone scale after review found that its technically connected surfaces still read as decorated greybox quadrants.
- Added six deterministic grass-encroachment shoulders that visually narrow and irregularize the road cross without changing any road or transition collision corridor.
- Expanded the inn surface into a continuous precinct and grouped approved repository luggage, storage, lantern, and foundation planting at its edges.
- Preserved the traveler-yard fence and collision geometry while strengthening its reading as one U-shaped, hard-packed working enclosure with a clear southern gate.
- Regrouped the existing north and perimeter vegetation into overlapping masses, promoted both interior sapling-scale canopies to medium trees, and retained an intentional open northeast meadow.
- Built a genuine rest grove around `05` with three medium tree masses, layered shrubs, the connected footpath, two object-sized new trunk collisions, and player-relative tree depth sorting.
- Kept `05` and `07` as the only library-pilot additions and advanced their metadata to the structural-recomposition visual gate.

### Files and systems changed

- `scenes/world/caden/WayfarersApproach.tscn`
- `assets/environments/caden/wayfarers_approach/terrain/composed_v1/`
- `assets/environments/caden/wayfarers_approach/wayfarers_approach_pilot_runtime_v1.json`
- `tools/art/build_caden_wayfarer_landscape_surfaces_v1.py`
- `tools/art/render_caden_wayfarer_structural_recomposition_v5.gd`
- `tools/art/build_caden_wayfarer_structural_recomposition_review_v5.py`
- `tools/art/prepare_caden_wayfarer_pilot_runtime_v1.py`
- `tests/caden_wayfarers_approach_runtime_test.gd`
- `docs/art/CADEN_WAYFARERS_APPROACH_RUNTIME_V1.md`
- Updated the established full-zone, gameplay, and exact-2x Wayfarer preview PNGs.
- Generated the external `caden_wayfarer_structural_recomposition_review_v5` visual-approval package reported at handoff.

### Validation

- Surface generator: PASS; three compacted room surfaces and six grass road shoulders reproduce deterministically with exact hashes, binary alpha, zero transparent-RGB or canvas-edge pixels, one connected component each, scale `1.0`, and no collision.
- Full-zone-first visual inspection: PASS; the road no longer divides four hard lawn rectangles, the inn precinct is continuous, the yard reads as one work enclosure, the meadow remains deliberate open space, the grove shelters `05`, and the perimeter reads as clustered masses.
- Godot 4.7.2 Compatibility renderer: PASS; one full-zone frame, six focused secondary views, six player-overlap/depth frames, and one exact 2x display frame were generated outside `res://` with deterministic state metadata.
- `res://tests/caden_wayfarers_approach_runtime_test.gd`: PASS; nine authored surfaces, lossless imports, preserved contracts and routes, original and new object-sized collisions, and pilot/tree depth sorting validate.
- `res://tests/caden_zone_transition_test.gd`: PASS; all Caden transitions, arrival placement, persistent Player behavior, and camera limits remain valid.
- Godot 4.7.2 headless import and main-scene launch: PASS; no new project parser, resource, or runtime error.
- Review-package validation: PASS; native v4/v5 comparisons, full-zone-first board, exact nearest-neighbor 2x proof, artifact hashes, and tool hashes validate.
- Known sandbox-only notices remain limited to Godot user-log/editor-settings writes and Windows certificate-store access.

### Remaining approval item

- The v5 structural recomposition is the active visual gate. Marketplace, Town Square, Residential Quarter, Commons, and every additional library candidate remain untouched.

## 2026-08-27 - Marketplace reconstruction review gate v1

### Scope

- Recorded user approval of the Wayfarer's Approach v5 structural recomposition and retained `05` and `07` as its only library additions.
- Inspected and locked the live `896 x 640` Marketplace contract: eight fixed stall footprints, protected west/central/south circulation, transitions, entry markers, camera bounds, three NPCs, dialogue, and collision.
- Captured an untouched deterministic Marketplace baseline outside `res://` at native full-zone and gameplay resolutions with exact `1280 x 720` nearest-neighbor proof.
- Built a full-zone composition plan around four paired vendor districts, a protected circulation spine, a north service edge, and an open Town Square forecourt.
- Verified the complete 222-row Caden Mega Asset Library v1.1 manifest and built a native-scale candidate board using actual Marketplace terrain and the approved player reference.
- Recommended set pieces `01`, `03`, `04`, `06`, `07`, `13`, and `14`; marked `02`, `08`, and `11` as alternates; deferred `05`, `16`, and mega-set `02`.
- Preserved every v1.1 Marketplace rejection, including all fourteen structure masters, and stopped before normalization, import, or scene integration.

### Files and systems changed

- `assets/environments/caden/wayfarers_approach/wayfarers_approach_pilot_runtime_v1.json`
- `tools/art/prepare_caden_wayfarer_pilot_runtime_v1.py`
- `tests/caden_wayfarers_approach_runtime_test.gd`
- `docs/art/CADEN_WAYFARERS_APPROACH_RUNTIME_V1.md`
- `tools/art/render_caden_marketplace_baseline_v1.gd`
- `tools/art/build_caden_marketplace_reconstruction_gate_v1.py`
- `docs/art/CADEN_MARKETPLACE_RECONSTRUCTION_GATE_V1.md`
- `docs/CHANGELOG.md`
- Generated the external `caden_marketplace_baseline_v1_render` evidence directory and `caden_marketplace_reconstruction_gate_v1` visual-approval package reported at handoff.

### Validation

- Marketplace Compatibility baseline renderer: PASS; six deterministic captures generated from the untouched live scene outside `res://`.
- Marketplace gate builder: PASS; 222 manifest rows and all displayed candidate hashes verified, native-scale previews generated, and exact `1280 x 720` nearest-neighbor proof confirmed.
- Caden Mega Asset Library v1.1 package verifier: PASS; 222 manifest rows, 217 production assets, five concepts, 297 checksummed files, and all PNG decodes verified.
- External review-package verification: PASS; all 14 packaged files match `SHA256SUMS.txt`.
- `res://tests/caden_wayfarers_approach_runtime_test.gd`: PASS with the v5 approval state and all established Wayfarer runtime contracts.
- `res://tests/caden_zone_transition_test.gd`: PASS; all Caden connections, entry placement, persistent Player behavior, and camera limits remain valid.
- Godot 4.7.2 headless editor import and main-scene launch: PASS; no parser, resource, UID, or runtime failure.
- Repository hygiene: PASS; `git diff --check` is clean and no hidden Python/build artifacts were found outside ignored Godot cache data.
- Scene modification check: PASS; `scenes/world/caden/Marketplace.tscn` remains unchanged and no Marketplace asset was imported into `res://`.

### Remaining approval item

- The Marketplace composition plan and candidate shortlist are the active visual gate. No candidate may be normalized or integrated until the user explicitly selects it, and no later Caden zone is authorized by this gate.
