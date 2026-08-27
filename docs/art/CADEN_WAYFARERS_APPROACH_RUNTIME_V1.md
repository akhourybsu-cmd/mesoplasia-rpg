# Caden Wayfarer's Approach Runtime v1

## Outcome

Wayfarer's Approach now uses a composed Godot environment instead of development polygons. The 1024 x 640 footprint, 640 x 360 internal presentation, entry markers, exits, NPC positions, camera bounds, 24 x 24 Player collision, and Caden transition contract remain unchanged.

The approved concept is retained as a reference only. It is not loaded as a background or runtime texture.

## Supplied-source limitation

The attachment payload contained four black-matte JPEG renditions named `1-Photo-1.jpg` through `4-Photo-4.jpg`. The named transparent PNG masters and ZIP were not present. Exact byte-for-byte copies are retained under `assets/source_art/caden/environment/wayfarers_approach/` with descriptive JPEG filenames.

The preparation tool reconstructs transparency only from border-connected black matte, then performs nearest-neighbor normalization. This is deterministic and avoids invented or substituted artwork, but the JPEG compression is already baked into the supplied pixels. Re-running from the requested lossless transparent masters remains the only art-quality gap.

## Normalization

- Structures: 0.5 scale. The 38 x 53 runtime door was used as the architectural comparison against the approved 40 x 56 character.
- Traveler props: 1/3 scale. Wagons, carts, hitching rails, supplies, wheels, and fire rings share this scale.
- Terrain: 0.8 scale. This maps the supplied road width to the greybox's 128-pixel carriage lane.
- Resampling: nearest-neighbor only.
- Output: individual transparent PNGs with two pixels of safe runtime padding.
- Imports: lossless texture compression, no mipmaps, global nearest filtering.
- Lighting: supplied upper-left lighting is preserved.

Every source crop, destination, output size, family scale, visible bounds, anchor, and SHA-256 is recorded in `assets/environments/caden/wayfarers_approach/wayfarers_approach_runtime_manifest_v1.json`.

## New runtime assets

### Structures

- `roadside_inn_exterior_v1.png`
- `roadside_inn_rear_v1.png`
- `porch_awning_v1.png`
- `porch_post_v1.png`
- `porch_stairs_v1.png`
- `roof_awning_v1.png`
- `stone_chimney_v1.png`
- `roof_dormer_v1.png`
- `window_box_v1.png`
- `timber_wall_v1.png`
- `stone_foundation_v1.png`
- `roof_strip_v1.png`
- `roof_gable_v1.png`
- `wooden_door_v1.png`
- `blank_hanging_inn_sign_v1.png`
- `edenite_wall_lantern_v1.png`
- `edenite_post_lantern_v1.png`
- `open_wagon_shelter_v1.png`
- `roofed_supply_shelter_v1.png`

### Traveler props

- `covered_wagon_side_v1.png`
- `covered_wagon_rear_v1.png`
- `supply_cart_open_v1.png`
- `handcart_v1.png`
- `hitching_rail_long_v1.png`
- `hitching_rail_short_v1.png`
- `hitching_rail_rope_v1.png`
- `fence_opening_v1.png`
- `wagon_gate_v1.png`
- `fire_ring_unlit_v1.png`
- `fire_ring_lit_v1.png`
- `supply_cluster_green_v1.png`
- `supply_cluster_travel_v1.png`
- `crates_barrels_cluster_v1.png`
- `spare_wagon_wheel_v1.png`
- `spare_wagon_wheels_v1.png`
- `water_supply_station_v1.png`

### Road and terrain

- `road_horizontal_wide_v1.png`
- `road_vertical_wide_v1.png`
- `road_t_junction_v1.png`
- `road_endcap_horizontal_v1.png`
- `road_endcap_vertical_v1.png`
- `road_corner_outer_nw_v1.png`
- `road_corner_inner_ne_v1.png`
- `road_corner_inner_nw_v1.png`
- `road_corner_outer_ne_v1.png`
- `road_corner_split_v1.png`
- `road_corner_outer_sw_v1.png`
- `road_corner_inner_se_v1.png`
- `road_corner_inner_sw_v1.png`
- `road_corner_outer_se_v1.png`
- `road_corner_split_south_v1.png`
- `grass_edge_horizontal_a_v1.png`
- `grass_edge_horizontal_b_v1.png`
- `grass_edge_horizontal_c_v1.png`
- `grass_edge_vertical_a_v1.png`
- `grass_edge_vertical_b_v1.png`
- `wheel_ruts_straight_a_v1.png`
- `wheel_ruts_curve_v1.png`
- `wheel_ruts_straight_b_v1.png`
- `wheel_ruts_straight_c_v1.png`
- `footprints_scatter_v1.png`
- `road_wear_scatter_v1.png`
- `road_wear_patch_v1.png`
- `rest_field_trampled_a_v1.png`
- `rest_field_dirt_a_v1.png`
- `rest_field_trampled_b_v1.png`
- `rest_field_trampled_c_v1.png`
- `rest_field_straw_v1.png`
- `rest_field_mud_v1.png`
- `edge_detail_grass_v1.png`
- `edge_detail_flowers_v1.png`
- `edge_detail_stones_v1.png`
- `road_horizontal_continuous_1024_v1.png` (derived seam-safe placement texture)
- `road_vertical_continuous_256_v1.png` (derived seam-safe placement texture)
- `road_t_junction_overlay_v1.png` (derived seam-safe junction overlay)

## Shared Caden assets reused

- Grass tile: `caden_terrain_runtime_v1_1.png`
- Ground flowers and tufts: `caden_nature_ground_runtime_v1.png`
- Trees: all four `caden_tree_medium_*` and `caden_tree_small_*` variants used by the scene
- Shrubs: the three `caden_bush_medium_*` variants and `caden_shrub_small_01_v1.png`
- Rocks: `caden_rock_cluster_01_v1.png`
- Fences: `caden_fence_straight_01_v1.png` and `caden_fence_end_01_v1.png`
- Seating: `caden_bench_01_v1.png`
- Storage: `caden_crate_01_v1.png` and `caden_barrel_01_v1.png`
- Existing Caden NPC SpriteFrames: the half-elf young nonbinary, human young woman, and human middle man shared variants

## Godot composition

- `scenes/world/caden/WayfarersApproach.tscn` is the rebuilt zone.
- `assets/tilesets/caden/terrain/wayfarers_approach_road_runtime_v1.tres` is the reusable 32-pixel-grid road library.
- `WayfarersRoadLayer.tscn` places the continuous east-west road, north connector, T-junction, and lower yard wear path through `TileMapLayer` nodes.
- `InnExterior.tscn`, `CoveredWagon.tscn`, `CoveredWagonRear.tscn`, `SupplyCart.tscn`, `HitchingRailSection.tscn`, `TravelerRestPropCluster.tscn`, `TravelerSupportShelter.tscn`, and `OpenWagonShelter.tscn` are reusable scene components.
- Solid structures use layer-1 physics bodies. Road, rut, wear, flower, fire-ring, and small luggage details have no collision.
- Player and NPC visuals remain at z-index 10; southern foreground trees use z-index 11.
- The complete inn sprite is the northwest landmark. It carries the supplied blank/festival treatment without a readable name or new entrance. One Edenite-blue lantern is used.

## Runtime v1.1 refinement

- The zone ground now uses a generated `WayfarersGroundLayer.tscn` with a deterministic mix of all eight grass variants from the existing shared Caden terrain TileSet. This removes the single-tile repetition without adding redundant art.
- Traveler-yard wear overlays were reduced and rebalanced for a softer transition into the lawn.
- Restrained perimeter undergrowth, trees, shrubs, flowers, and tufts improve the natural boundary while preserving every road and transition opening.
- The three existing travelers now use distinct shared Caden character variants. Their positions, dialogue resources, and behavior are unchanged.
- The resource builder and runtime test cover the generated ground layer so this refinement remains reproducible.

## Limited transparent-source pilot v1

The Caden Mega Asset Library v1.1 supplied lossless transparent candidates after the original runtime was completed. Visual approval authorized a two-asset Wayfarer pilot only:

- `sp_way_05_bench_luggage_lantern` at `(860, 556)` in the open right-side rest lawn;
- `sp_way_07_hitching_rail_barrels` at `(680, 500)` beside the traveler yard and below the preserved east-west road corridor.

Both source PNGs are retained under `assets/source_art/caden/environment/wayfarers_approach/pilot_v1/`. `prepare_caden_wayfarer_pilot_runtime_v1.py` verifies their approved source hashes, crops the catalog alpha bounds, normalizes offline at `0.1875` with nearest-neighbor sampling, performs explicit halo/shadow/fragment cleanup, and adds two pixels of transparent safety padding. Godot imports the 112 x 70 and 115 x 63 runtime PNGs at scale `1.0`.

The pilot manifest records source and runtime hashes, dimensions, structural pivots, cleanup counts, import scale, and collision definitions. Bottom-center pivots use the bench, luggage, barrels, and rail ground contacts rather than flowers, stones, or shadow pixels.

`PilotBenchLuggageLantern.tscn` uses separate collision shapes for the lantern post, bench, and luggage. `PilotHitchingRailBarrels.tscn` uses separate barrel and rail shapes. Neither blocks the full image rectangle. `DepthSortedStaticProp` moves each pilot prop between z-index 9 and 11 as the Player crosses its ground-contact Y coordinate; the existing Player remains at z-index 10.

No existing inn, vehicle, fence, road, exit, camera, NPC, or route geometry changed. Assets `06` and `08` remain scale-approved alternates but are not selected. Assets `11` through `15` remain deferred, and all seven buildings plus set pieces `01` through `04`, `09`, `10`, and `16` remain rejected as supplied.

## Validation

Commands are run with Godot 4.7.2 Compatibility rendering.

- `--script res://tests/caden_wayfarers_approach_runtime_test.gd`
  - PASS: 75 baseline manifest entries, exactly two pilot entries, source/runtime hashes, 0.1875 normalization, scale-1.0 placement, object-specific collision, front/behind depth sorting, unchanged zone contracts, blocked map bounds, and clear 24 x 24 footprint sweeps on preserved routes.
- `--script res://tests/caden_zone_transition_test.gd`
  - PASS: every Caden connection, persistent Player, entry placement, and camera limit.
- `--script res://tools/art/render_caden_wayfarers_approach_preview.gd` with the Compatibility renderer
  - PASS: full-zone, 640 x 360 gameplay, and nearest-neighbor 1280 x 720 display captures written.
- Godot headless editor import
  - PASS: runtime PNG imports completed with no missing resource or scene parser error.
  - Environment-only notices: the sandbox cannot write the normal per-user Godot editor settings/log locations or read the Windows root certificate store. These did not affect project imports or test exit codes.

## Screenshots

- `docs/art/previews/wayfarers_approach/caden_wayfarers_approach_runtime_v1_full_zone.png`
- `docs/art/previews/wayfarers_approach/caden_wayfarers_approach_runtime_v1_gameplay_640x360.png`
- `docs/art/previews/wayfarers_approach/caden_wayfarers_approach_runtime_v1_display_1280x720.png`
- `docs/art/previews/wayfarers_approach/pilot_v1/grass_before_640x360.png`
- `docs/art/previews/wayfarers_approach/pilot_v1/grass_after_640x360.png`
- `docs/art/previews/wayfarers_approach/pilot_v1/road_before_640x360.png`
- `docs/art/previews/wayfarers_approach/pilot_v1/road_after_640x360.png`
- `docs/art/previews/wayfarers_approach/pilot_v1/bench_player_behind_640x360.png`
- `docs/art/previews/wayfarers_approach/pilot_v1/bench_player_front_640x360.png`
- `docs/art/previews/wayfarers_approach/pilot_v1/rail_player_behind_640x360.png`
- `docs/art/previews/wayfarers_approach/pilot_v1/rail_player_front_640x360.png`
- `docs/art/previews/wayfarers_approach/pilot_v1/wayfarer_pilot_comparison_board_v1.png`

## Gate 1 review evidence v2

The stricter five-zone mapping prompt retains the two-asset pilot as Gate 1 and does not authorize another zone or library asset before visual approval. The pilot metadata schema now also records each selected asset's catalog identity and status, intended zone and placement, scale family, target runtime dimensions, structural pivot, world position, intended solid footprint, passable details, collision strategy, depth-sorting strategy, provenance status, and approval state.

The normalizer now performs and records a post-cleanup audit. Both pilot outputs contain zero partial-alpha pixels, transparent-RGB residue, canvas-edge pixels, bright boundary halo candidates, and detached components at or below two pixels. The runtime PNG hashes remain unchanged.

`render_caden_wayfarer_gate1_review_v2.gd` writes its evidence outside `res://` and produces the complete ten-frame Gate 1 set: matched rest-area and hitching-area baselines/afters, front/behind player-overlap pairs for both assets, one road-readability frame, and one `1280 x 720` display frame. It freezes animated sprites at frame zero, fixes the player to `idle_down`, disables capture-only interaction UI, and records every camera/player position and PNG hash in a screenshot manifest.

`build_caden_wayfarer_gate1_review_v2.py` validates all ten dimensions and hashes, proves the display frame is a byte-exact nearest-neighbor 2x enlargement of the corresponding `640 x 360` frame, builds a native-scale nine-frame comparison board without resampling the source captures, and checksums the review artifacts and all three pilot preparation/review scripts. The external review directory and comparison-board path are reported at handoff rather than stored inside the Godot import tree.

## Landscape revision v3

Visual review requested a fuller, more deliberately landscaped composition rather than additional isolated props. The revision uses only approved repository terrain and planting art and adds no new Caden Mega Asset Library source.

- The former north-lawn scatter is consolidated into one meadow island around the existing small tree.
- `sp_way_07_hitching_rail_barrels` moves from `(680, 500)` to `(650, 500)` so it extends the traveler yard and aligns more naturally with the wagons and supply cart.
- A restrained trampled overlay grounds `07`; the working hitching area remains practical rather than flowered.
- The existing lower-right worn patch now sits beneath `05`, and repeated low planting is grouped along the rest-grove edge to connect the bench, tree, luggage, and lantern as one place.
- Two faint walkable wear cues establish the approach from the road to the rest grove.
- Existing isolated south-lawn accents are folded into the meadow and rest-grove masses while the central lawn and every corridor stay open.

All landscape additions live under `TerrainLayers/LandscapeEnhancement`, contain no collision, and remain independently reviewable. The runtime contract test checks the grouped grounding/planting counts and confirms that no `CollisionObject2D` was introduced there. The v3 external review package compares the prior pilot against this revision at native `640 x 360`, retains full-zone and depth-sorting captures, and verifies exact nearest-neighbor `1280 x 720` presentation.

## Production landscape pass v4

The production pass replaces the v3 terrain-stamp treatment with three connected authored surfaces generated by `build_caden_wayfarer_landscape_surfaces_v1.py`:

- a restrained inn-front apron connecting the unchanged frontage to the road;
- one irregular traveler-yard field connecting the wagons, supplies, fences, water, gate threshold, and `07`;
- a smaller rest-grove pocket with one narrow road approach, irregular edge bays, and stronger wear around `05` and the existing tree.

Each surface is a deterministic scale-1 PNG derived only from the live eight-variant grass atlas and interior color averages from the approved Wayfarer wear textures. The surfaces have binary alpha, zero partial-alpha pixels, zero canvas-edge pixels, no blur or antialiasing, and no collision. The generator records every source hash, output hash, world origin, dimensions, pivot convention, placement intent, and audit result in `terrain/composed_v1/wayfarers_landscape_surfaces_v1.json`.

The former five circular rest-field sprites and three translucent grounding stamps are removed. Planting under `LandscapeEnhancement` is reduced from nine accents to four retained sprites, supplementing the existing ground-detail sprites as two compact rest-grove edge masses and one five-accent north-tree island. The former isolated yard flowers now support the inn foundation, while the practical yard center remains open for vehicle and player circulation.

`render_caden_wayfarer_production_landscape_v4.gd` produces the full `1024 x 640` zone, six matched room/circulation views, both `05` and `07` overlap pairs, and an exact nearest-neighbor `1280 x 720` display frame outside `res://`. `build_caden_wayfarer_production_landscape_review_v4.py` uses the checksummed v3 full-zone frame as the before state, extracts native `640 x 360` crops without resampling, assembles the native-size comparison board, and checksums every artifact and production tool.

## Structural recomposition v5

The v4 technical terrain pass still left the zone reading as four lawn rectangles around a dominant road cross. The structural recomposition therefore works at map scale before local detail:

- Six binary-alpha grass shoulders create irregular encroachment along the horizontal road and northern approach. The underlying road geometry, collision, ruts, transition rectangles, and minimum corridor width are unchanged.
- The inn forecourt expands into one continuous precinct from the unchanged foundation to the road edge. Existing repository luggage, storage, a ground lantern, and foundation planting form two compact service clusters rather than isolated lawn props.
- The traveler yard retains its existing U-shaped collision and southern gate but now reads as one hard-packed work surface joining wagons, supplies, water, fences, and `07`.
- The northeast becomes an intentional open meadow. Existing perimeter trees and shrubs are regrouped into overlapping northwest, north-road, and northeast masses, and the meadow tree is promoted from a small to a medium canopy without moving its trunk collision.
- The rest pocket becomes a three-tree grove. The existing south-lawn trunk remains in place with a medium canopy; two additional medium trees use object-sized trunk collision and player-relative depth sorting. Three medium shrub masses and the retained low planting create a crescent around `05` while keeping its road approach and front/behind circulation open.
- Existing west, east, and south boundary vegetation is concentrated at non-exit edges. Roads and transition openings remain visually and physically unobstructed.

The authored-surface manifest now records nine audited surfaces: three compacted room surfaces and six exact-grass road shoulders. Every output remains scale `1.0`, collision-free, single-component, binary-alpha, free of transparent RGB residue, and clear of canvas edges. No additional Caden Mega Asset Library candidate is present.

`render_caden_wayfarer_structural_recomposition_v5.gd` makes the `1024 x 640` full-zone frame the primary review artifact and adds six secondary room/circulation views, `05` and `07` overlap pairs, a grove-tree depth pair, and exact `1280 x 720` proof. `build_caden_wayfarer_structural_recomposition_review_v5.py` compares those frames against the checksummed v4 after state and checksums the complete external package.

## Visual approval

The Wayfarer's Approach v5 structural-recomposition comparison was approved on 2026-08-27. Its full-zone hierarchy, terrain continuity, road shoulders, room composition, overlap, and depth-sorting evidence are now the accepted Wayfarer baseline. No additional Wayfarer library candidate was authorized; Marketplace composition and candidate review is the next gated phase.
