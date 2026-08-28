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

## 2026-08-27 - Marketplace selective integration runtime v1

### Scope

- Implemented the approved Marketplace shortlist `01`, `03`, `04`, `06`, `07`, `13`, and `14`; retained every alternate, deferred, and rejected disposition.
- Verified each source against the external Caden Mega Asset Library v1.1 manifest, normalized at exact `0.1875` nearest-neighbor scale, and imported only cleaned runtime PNGs at scale `1.0`.
- Removed broad presentation shadows, bright boundary fringe, partial alpha, detached fragments, transparent RGB, and canvas-edge pixels without repainting source structures.
- Replaced the flat Marketplace ground with a deterministic `896 x 640` terrain composition derived exclusively from exact cells in the approved Caden Terrain Runtime v1.1 atlas.
- Rebuilt the eight fixed vendor bays as four paired commercial districts while preserving their centers and all primary circulation, transition, camera, NPC, dialogue, and interaction contracts.
- Added structural bottom-center pivots, solid-only collision footprints, and player-relative depth sorting to every selected runtime prop.
- Grouped approved repository trees, shrubs, planters, and lanterns around the perimeter and district edges while retaining open west, cross, central, and south corridors.
- Replaced the three Marketplace placeholder polygons with existing approved Caden NPC visuals without changing identities, positions, dialogue, or behavior.
- Produced a full-zone-first external before/after package and stopped at the Marketplace in-engine visual gate.

### Files and systems changed

- `scenes/world/caden/Marketplace.tscn`
- `assets/environments/caden/marketplace/props/runtime_v1/`
- `assets/environments/caden/marketplace/marketplace_runtime_manifest_v1.json`
- `assets/environments/caden/marketplace/terrain/`
- `tools/art/prepare_caden_marketplace_runtime_v1.py`
- `tools/art/build_caden_marketplace_terrain_v1.py`
- `tools/art/render_caden_marketplace_runtime_v1.gd`
- `tools/art/build_caden_marketplace_runtime_review_v1.py`
- `tests/caden_marketplace_runtime_test.gd`
- `docs/art/CADEN_MARKETPLACE_RECONSTRUCTION_GATE_V1.md`
- `docs/art/CADEN_MARKETPLACE_RUNTIME_V1.md`
- `docs/CHANGELOG.md`
- Generated the external `caden_marketplace_runtime_v1_render` evidence directory and `caden_marketplace_runtime_review_v1` visual-approval package reported at handoff.

### Validation

- Marketplace source normalization and post-clean audit: PASS for all seven selected assets; exact target dimensions, binary alpha, zero transparent RGB, zero canvas-edge pixels, zero bright boundary halo candidates, zero tiny detached components, and one connected component each.
- Marketplace terrain generator: PASS; protected atlas hash, exact `896 x 640` dimensions, full opacity, exact `32 x 32` cell derivation, scale `1.0`, and collision-free output verified.
- `res://tests/caden_marketplace_runtime_test.gd`: PASS; source/runtime metadata, terrain, selections, pivots, scale, collision, sorting, route clearance, NPC visuals/dialogue, entries, exits, and camera contract verified.
- `res://tests/caden_zone_transition_test.gd`: PASS; every Caden transition, arrival position, persistent Player instance, and camera limit remains valid.
- `res://tests/caden_wayfarers_approach_runtime_test.gd`: PASS; the approved Wayfarer scene and two-asset pilot remain unchanged and valid.
- `res://tests/caden_town_square_environmental_dressing_test.gd`: PASS; the validated Town Square contract remains intact.
- Godot 4.7.2 headless editor import and main-scene launch: PASS; no project parser, resource, UID, or runtime failure.
- Compatibility visual evidence: PASS; native full-zone and route/district frames, vendor and tree front/behind pairs, and exact byte-matched `1280 x 720` nearest-neighbor proof generated.
- External review-package verification: PASS; all 24 packaged files match `SHA256SUMS.txt`.

### Remaining approval item

- Marketplace Runtime v1 is the active in-engine visual gate. Town Square, Residential Quarter, Commons, and all unselected library candidates remain unauthorized until this Marketplace comparison receives explicit visual approval.

## 2026-08-27 - Marketplace lively perimeter refinement

### Scope

- Added four non-interactive ambient shoppers using the established Caden `PatrolNpc` component, with one bounded horizontal route in each vendor district.
- Expanded the Marketplace edge from ten to sixteen trees and moved every structural tree contact onto the outer grass.
- Added layered shrub understory around the north, west, east, and south planting frame.
- Added 22 collidable fence segments along the grass side of the market boundary, including closed north and east service gates.
- Preserved deliberate openings for the west Wayfarer's Approach route and south Town Square route, plus all vendor bays, central circulation, transitions, static NPC dialogue, and selected library assets.
- Rendered the live Compatibility scene outside `res://` for the next Marketplace visual approval pass.

### Files and systems changed

- `scenes/world/caden/Marketplace.tscn`
- `tests/caden_marketplace_runtime_test.gd`
- `tools/art/build_caden_marketplace_lively_perimeter_review_v2.py`
- `docs/art/CADEN_MARKETPLACE_RUNTIME_V1.md`
- `docs/art/CADEN_MARKETPLACE_RECONSTRUCTION_GATE_V1.md`
- `docs/CHANGELOG.md`
- Generated external visual evidence under `caden_marketplace_lively_perimeter_review_v2`.

### Validation

- `res://tests/caden_marketplace_runtime_test.gd`: PASS; sixteen grass-grounded trees, 22 narrow fence collisions, both travel openings, four bounded walkers, selected assets, sorting, routes, entries, and exits validate.
- `res://tests/caden_npc_variants_patrol_runtime_test.gd`: PASS; the reusable patrol animation and bounded-movement contract remains valid.
- `res://tests/caden_zone_transition_test.gd`: PASS; every Caden connection, entry placement, persistent Player instance, and camera limit remains valid.
- `res://tests/caden_wayfarers_approach_runtime_test.gd`: PASS; the approved two-prop Wayfarer pilot remains unchanged.
- `res://tests/caden_town_square_environmental_dressing_test.gd`: PASS; the established Town Square composition remains unchanged.
- Godot 4.7.2 headless main-scene launch: PASS; no project parser, resource, or runtime error.
- Godot 4.7.2 Compatibility capture: PASS; full-zone, route, district, overlap, and exact 2x frames generated outside `res://`.
- External v1/v2 comparison package: PASS; prior runtime and current landscaped captures, full-zone-first board, tool hashes, and package checksums generated outside `res://`.
- Known sandbox-only notices remain limited to Godot user-log writes and Windows certificate-store access.

### Remaining approval item

- The landscaped Marketplace perimeter and four ambient shoppers are the active visual gate. No additional library asset or later-zone integration is authorized by this pass.

## 2026-08-27 - Marketplace approval and Residential reconstruction gate v1

### Scope

- Recorded visual approval of Marketplace Runtime v1 and its lively-perimeter refinement, allowing the ordered five-zone workflow to continue.
- Audited the already validated Town Square against the master prompt and left its scene unchanged; its open octagonal plaza, reserved community space, four exits, ambient population, perimeter dressing, and Terrebonne closure already satisfy the restrained-refinement brief.
- Reconstructed the untouched `1152 x 768` Residential contract: ten fixed cabin bodies, three fixed yard fences, six road/lane rectangles, two transitions, two entry markers, two interactive NPCs, camera bounds, and boundary collision.
- Captured deterministic Residential baseline evidence outside `res://` at full-zone, gameplay, route, home-district, transition, and exact 2x display resolutions.
- Verified all 222 Caden v1.1 catalog rows and all 297 package checksums.
- Re-audited and displayed all 18 viable Residential set-piece and mega candidates at proposed runtime scale beside the approved `40 x 56` player.
- Preserved rejection of all 24 Residential/townwide house masters for unsuitable baked shadows.
- Recommended set pieces `01`, `04`, `05`, `06`, `08`, `09`, and `11`; retained `02`, `03`, `10`, `13`, `14`, and `15` as alternates; deferred `07`, `12`, `16`, and mega composites `01` and `02`.
- Stopped before Residential normalization, import, or scene modification.

### Files and systems changed

- `assets/environments/caden/marketplace/marketplace_runtime_manifest_v1.json`
- `tools/art/prepare_caden_marketplace_runtime_v1.py`
- `tools/art/build_caden_marketplace_runtime_review_v1.py`
- `tests/caden_marketplace_runtime_test.gd`
- `docs/art/CADEN_MARKETPLACE_RUNTIME_V1.md`
- `tools/art/render_caden_residential_baseline_v1.gd`
- `tools/art/build_caden_residential_reconstruction_gate_v1.py`
- `docs/art/CADEN_RESIDENTIAL_RECONSTRUCTION_GATE_V1.md`
- `docs/CHANGELOG.md`
- Generated external `caden_residential_baseline_v1_render` evidence and `caden_residential_reconstruction_gate_v1` approval materials.

### Validation

- Residential Compatibility baseline renderer: PASS; seven deterministic captures generated outside `res://`.
- Residential gate builder: PASS; 222 catalog rows, 297 source-package checksums, 18 candidate hashes, source binary alpha, canvas-edge clearance, all candidate dispositions, and 24 preserved building rejections verified.
- Exact 2x presentation proof: PASS; the `1280 x 720` primary frame byte-matches nearest-neighbor enlargement of the `640 x 360` source.
- External gate-package verification: PASS; all 13 packaged files match `SHA256SUMS.txt`.
- `res://tests/caden_marketplace_runtime_test.gd`: PASS with the approved Marketplace gate state and all scene contracts.
- `res://tests/caden_town_square_environmental_dressing_test.gd`: PASS; Town Square remains unchanged and valid.
- `res://tests/caden_zone_transition_test.gd`: PASS; every Caden connection, arrival placement, persistent Player instance, and camera limit remains valid.
- Godot 4.7.2 headless main-scene launch: PASS; no project parser, resource, or runtime error.
- Known sandbox-only notices remain limited to Godot user-log writes and Windows certificate-store access.

### Remaining approval item

- Residential candidate selection is the active visual gate. No Residential source may be normalized or imported, and Commons remains untouched, until the shortlist receives explicit approval.

## 2026-08-27 - Residential Runtime v1 visual gate

### Scope

- Recorded approval of Residential candidates `01`, `04`, `05`, `06`, `08`, `09`, and `11` and normalized only those sources at exact `0.1875` nearest-neighbor scale.
- Removed presentation shadows, bright fringes, partial alpha, detached fragments, edge-touching pixels, and transparent RGB from the selected runtime PNGs; retained structural bottom-center pivots and scale `1.0` imports.
- Replaced the Residential greybox terrain with an exact `32 x 32` atlas-cell composition while preserving the full `1152 x 768` bounds, west-east road, Commons branch, and four household lanes.
- Preserved all ten home centers and `128 x 96` collision bodies and reused already approved Caden runtime v2 building art; none of the 24 rejected baked-shadow building masters was imported.
- Preserved all three fence centers and `192 x 24` collision bodies and aligned existing approved fence art to their fixed geometry.
- Grouped the seven selected set pieces into household thresholds, maintained gardens, laundry, and storage yards with object-specific collision and player-relative depth sorting.
- Added twelve grass-grounded perimeter trees, sixteen low plantings, and four lane lanterns while keeping both transitions and all protected roads clear.
- Replaced the two existing NPC placeholders with approved character visuals without changing identity, dialogue, position, or facing.
- Added five non-interactive neighbors on short bounded patrols, producing seven visible Residential NPCs without new dialogue, lore, persistence, or gameplay systems.
- Rendered and packaged the pending Residential in-engine visual gate outside `res://`; Commons remains untouched.

### Files and systems changed

- `scenes/world/caden/Residential.tscn`
- `assets/environments/caden/residential/residential_runtime_manifest_v1.json`
- `assets/environments/caden/residential/props/runtime_v1/*.png`
- `assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.png`
- `assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.json`
- `tools/art/prepare_caden_residential_runtime_v1.py`
- `tools/art/build_caden_residential_terrain_v1.py`
- `tools/art/render_caden_residential_runtime_v1.gd`
- `tools/art/build_caden_residential_runtime_review_v1.py`
- `tests/caden_residential_runtime_test.gd`
- `docs/art/CADEN_RESIDENTIAL_RECONSTRUCTION_GATE_V1.md`
- `docs/art/CADEN_RESIDENTIAL_RUNTIME_V1.md`
- `docs/CHANGELOG.md`
- Generated external render evidence under `caden_residential_runtime_v1_render` and review materials under `caden_residential_runtime_review_v1`.

### Validation

- `res://tests/caden_residential_runtime_test.gd`: PASS; all 222 catalog rows, seven cleaned runtime hashes, terrain hash, ten homes, three fences, selected pivots, object-specific collisions, twelve trees, sixteen low plantings, four lanterns, seven residents, protected roads, sorting, entries, and exits validate.
- `res://tests/caden_zone_transition_test.gd`: PASS; every Caden connection, entry placement, persistent Player instance, and camera limit remains valid.
- `res://tests/caden_marketplace_runtime_test.gd`: PASS; the approved Marketplace runtime remains unchanged and valid.
- `res://tests/caden_town_square_environmental_dressing_test.gd`: PASS; the established Town Square composition remains unchanged and valid.
- `res://tests/caden_wayfarers_approach_runtime_test.gd`: PASS; the approved Wayfarer pilot remains unchanged and valid.
- `res://tests/caden_npc_variants_patrol_runtime_test.gd`: PASS; approved character variants and bounded patrol behavior remain valid.
- Godot 4.7.2 headless main-scene launch: PASS; no project parser, resource, UID, or runtime failure.
- Compatibility visual evidence: PASS; eleven deterministic native captures include full-zone, route, household, transition, two front/behind sorting pairs, and exact byte-matched `1280 x 720` nearest-neighbor proof.
- External review-package verification: PASS; all 24 packaged files match `SHA256SUMS.txt`, tooling is checksummed, and no hidden build artifact remains.
- Known sandbox-only notices remain limited to Godot user-log writes and Windows certificate-store access.

### Remaining approval item

- Residential Runtime v1 is the active in-engine visual gate. Commons and all alternate, deferred, rejected, and mega assets remain unauthorized until this comparison receives explicit visual approval.

## 2026-08-27 - Residential approval and Commons reconstruction gate v1

### Scope

- Recorded visual approval of Residential Runtime v1 and updated its runtime manifest and validation state accordingly.
- Left the approved Residential scene and all integrated assets unchanged while advancing the ordered five-zone workflow.
- Reconstructed the untouched `1024 x 704` Commons contract: two protected `128`-pixel approach routes, two transitions, two entry markers, three fixed `96 x 96` tree bodies, one fixed `64 x 48` rock body, one interactive resident, the eastern Quiet Green, camera bounds, and boundary collision.
- Captured deterministic Commons baseline evidence outside `res://` at native full-zone, route, reserved-green, boundary, and exact 2x display resolutions.
- Verified all 222 Caden v1.1 catalog rows and all 297 package checksums.
- Audited 24 viable Commons set-piece, seam, and mega candidates at proposed runtime scale beside the approved `40 x 56` player.
- Recommended Commons sources `01`, `04`, `09`, `11`, `14`, and `20`; retained `02`, `03`, `05`, `08`, `10`, `12`, `13`, `15`, and `18` as alternates.
- Deferred `06`, `07`, `16`, `17`, `19`, both Town Square/Commons seam candidates, and both Commons mega composites.
- Preserved rejection of both Residential/Commons seam sources for boundary fringe.
- Defined the open Quiet Green as the dominant anchor, with natural density restricted to the northwest grove, southwest edge, southeast boundary, and at most one path-edge rest pocket.
- Stopped before Commons normalization, import, or scene modification.

### Files and systems changed

- `assets/environments/caden/residential/residential_runtime_manifest_v1.json`
- `tests/caden_residential_runtime_test.gd`
- `docs/art/CADEN_RESIDENTIAL_RUNTIME_V1.md`
- `tools/art/render_caden_commons_baseline_v1.gd`
- `tools/art/build_caden_commons_reconstruction_gate_v1.py`
- `tests/caden_commons_contract_test.gd`
- `docs/art/CADEN_COMMONS_RECONSTRUCTION_GATE_V1.md`
- `docs/CHANGELOG.md`
- Generated external `caden_commons_baseline_v1_render` evidence and `caden_commons_reconstruction_gate_v1` approval materials.

### Validation

- Commons Compatibility baseline renderer: PASS; seven deterministic captures generated outside `res://`.
- Commons gate builder: PASS; 222 catalog rows, 297 source-package checksums, 24 viable candidate hashes, hard alpha, source-edge clearance, two preserved seam rejections, all dispositions, and provenance metadata verified.
- `res://tests/caden_commons_contract_test.gd`: PASS; bounds, protected routes, Quiet Green, fixed obstacles, resident, entries, exits, and transition collision validate.
- Exact 2x presentation proof: PASS; the `1280 x 720` route frame byte-matches nearest-neighbor enlargement of the `640 x 360` source.
- External gate-package verification: PASS; all packaged files match `SHA256SUMS.txt`, tools and tests are checksummed, and no Commons source enters `res://`.
- Known sandbox-only notices remain limited to Godot user-log writes and Windows certificate-store access.

### Remaining approval item

- Commons candidate selection is the active visual gate. No Commons source may be normalized or imported until the recommended shortlist receives explicit visual approval.

## 2026-08-27 - Commons Runtime v1 visual gate

### Scope

- Recorded approval of Commons candidates `01`, `04`, `09`, `11`, `14`, and `20` and normalized only those sources at exact `0.1875` nearest-neighbor scale.
- Removed presentation shadows, bright fringes, partial alpha, detached fragments, edge-touching pixels, and transparent RGB from the selected runtime PNGs; retained structural bottom-center pivots and scale `1.0` imports.
- Replaced Commons placeholder terrain with an exact `32 x 32` atlas-cell composition while preserving the `1024 x 704` bounds and the Town Square and Residential route polygons.
- Preserved the three authored tree centers and southwest rock center while replacing oversized placeholder canopy collisions with trunk- and object-specific shapes.
- Integrated one maintained grove, one shade-tree anchor, one walkable meadow, one natural rock mass, one boundary undergrowth mass, and one quiet path-edge rest pocket.
- Kept the eastern Quiet Green mostly open and used it as the dominant visual anchor through negative space rather than a building, monument, shelter, or mega composite.
- Added sixteen approved repository trees and seventeen low plantings around the outer grass without entering either protected route or transition corridor.
- Replaced the existing Commons resident placeholder with approved character art without changing identity, dialogue, position, interaction, or facing.
- Added two non-interactive residents on short bounded patrols, producing three visible Commons NPCs without new dialogue, lore, persistence, or gameplay systems.
- Rendered and packaged the pending Commons in-engine visual gate outside `res://`.

### Files and systems changed

- `scenes/world/caden/Commons.tscn`
- `assets/environments/caden/commons/commons_runtime_manifest_v1.json`
- `assets/environments/caden/commons/props/runtime_v1/*.png`
- `assets/environments/caden/commons/terrain/commons_terrain_runtime_v1.png`
- `assets/environments/caden/commons/terrain/commons_terrain_runtime_v1.json`
- `tools/art/prepare_caden_commons_runtime_v1.py`
- `tools/art/build_caden_commons_terrain_v1.py`
- `tools/art/render_caden_commons_runtime_v1.gd`
- `tools/art/build_caden_commons_runtime_review_v1.py`
- `tests/caden_commons_contract_test.gd`
- `tests/caden_commons_runtime_test.gd`
- `docs/art/CADEN_COMMONS_RECONSTRUCTION_GATE_V1.md`
- `docs/art/CADEN_COMMONS_RUNTIME_V1.md`
- `docs/CHANGELOG.md`
- Generated external render evidence under `caden_commons_runtime_v1_render` and review materials under `caden_commons_runtime_review_v1`.

### Validation

- `res://tests/caden_commons_contract_test.gd`: PASS; bounds, route polygons, Quiet Green, authored anchor centers, precise collision, resident, entries, exits, and transition collision validate.
- `res://tests/caden_commons_runtime_test.gd`: PASS; all 222 catalog rows, six cleaned runtime hashes, terrain hash, selected pivots, object-specific collision, sixteen trees, seventeen plantings, protected routes, sorting, three residents, entries, and exits validate.
- `res://tests/caden_zone_transition_test.gd`: PASS after the normal Godot import; every Caden connection, entry placement, persistent Player instance, and camera limit remains valid.
- `res://tests/caden_marketplace_runtime_test.gd`: PASS; the approved Marketplace runtime remains unchanged and valid.
- `res://tests/caden_town_square_environmental_dressing_test.gd`: PASS; the established Town Square composition remains unchanged and valid.
- `res://tests/caden_residential_runtime_test.gd`: PASS; the approved Residential runtime remains unchanged and valid.
- `res://tests/caden_wayfarers_approach_runtime_test.gd`: PASS; the approved Wayfarer pilot remains unchanged and valid.
- `res://tests/caden_npc_variants_patrol_runtime_test.gd`: PASS; approved character variants and bounded patrol behavior remain valid.
- Godot 4.7.2 headless asset import: PASS; all seven new PNGs imported through the normal editor workflow.
- Compatibility visual evidence: PASS; eleven deterministic native captures include full-zone, routes, reserved green, southern boundary, bench and tree front/behind sorting pairs, and exact byte-matched `1280 x 720` nearest-neighbor proof.
- External review-package verification: PASS; all packaged files match `SHA256SUMS.txt`, tooling and tests are checksummed, and no hidden build artifact remains.
- Known sandbox-only notices remain limited to Godot user-log writes, editor-settings writes, and Windows certificate-store access.

### Remaining approval item

- Commons Runtime v1 is the final in-engine visual gate for the ordered five-zone Caden pass. Alternate, deferred, rejected, seam, and mega sources remain unauthorized.
