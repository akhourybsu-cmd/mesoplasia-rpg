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

## Validation

Commands are run with Godot 4.7.2 Compatibility rendering.

- `--script res://tests/caden_wayfarers_approach_runtime_test.gd`
  - PASS: 75 manifest entries, TileSet population, unchanged zone contracts, active solid collisions, import settings, blocked map bounds, and clear 24 x 24 footprint sweeps on the main east-west road, north road, and lower-right lawn.
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

## Remaining approval item

Provide the original transparent PNG sheets or the named ZIP if lossless source fidelity is required. The deterministic crop manifest and tools can then regenerate the same library without changing scene layout, collisions, or gameplay contracts.
