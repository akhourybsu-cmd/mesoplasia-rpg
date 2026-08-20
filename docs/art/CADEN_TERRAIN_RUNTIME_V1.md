# Caden Terrain Runtime v1

## Purpose and Scope

This document is the preparation manifest and usage guide for the first runtime-ready Caden terrain prototype. The atlas is limited to grass, earth roads, plaza paving, their edges, and the minimum transitions needed by the locked Town Square layout.

It does not authorize architecture, nature, props, Edenite, Festival decoration, character art, or changes to another Caden zone.

## Source Protection Record

- Source master: `assets/source_art/caden/terrain/caden_terrain_master_v1.png`
- Source dimensions: `1448 x 1086` pixels
- SHA-256 before preparation: `36308c3fe4eb1bda2cca61c7778583440c07b8b859c2f597185f180ebdcb3b4c`
- SHA-256 after preparation and Town Square integration: `36308c3fe4eb1bda2cca61c7778583440c07b8b859c2f597185f180ebdcb3b4c`
- Preparation script: `tools/art/prepare_caden_terrain_runtime_v1.py`

The preparation script refuses to run when the source hash or dimensions differ from this record. It never writes beneath `assets/source_art/caden/`.

## Runtime Outputs

- Runtime atlas: `assets/tilesets/caden/terrain/caden_terrain_runtime_v1.png`
- Godot TileSet: `assets/tilesets/caden/terrain/caden_terrain_runtime_v1.tres`
- Validation preview: `docs/art/previews/caden_terrain_runtime_v1_validation.png`
- Town Square terrain preview: `docs/art/previews/caden_terrain_runtime_v1_town_square_preview.png`
- Atlas dimensions: `256 x 192` pixels
- Atlas grid: 8 columns by 6 rows
- Tile size: exact `32 x 32` pixels
- Included tiles: 47
- Unused atlas cells: one, at `(7, 0)`

## Preparation Method

1. Select exact `96 x 96` regions from the master sheet's stable visual grid.
2. Reduce each selected region by an exact 3:1 integer factor using nearest-neighbor resampling.
3. Normalize source alpha to fully opaque for complete ground-material cells, preventing partial-alpha fringe and matte contamination.
4. Build seamless fills from periodic center patches where whole generated cells reveal strong edge lighting gradients.
5. Preserve a shared grass border across sparse variants so alternating tiles do not create unmatched exterior edges.
6. Recompose wide road fill, inner corners, plaza edges, clipped corners, and road-to-plaza transitions using only already-reduced source pixels and hard pixel masks.
7. Do not use bilinear, bicubic, antialiasing, blur, or other smoothing.
8. Leave all source masters unchanged.

The recomposition step is necessary because the source master supplies narrow path demonstrations and reference transitions, but not a clean full-cell dirt fill or exact one-cell clipped corners matching the locked Town Square octagon.

## Source Grid References

Stable source columns begin at `x = 13, 119, 225, 332, 438, 544, 652, 758, 866, 973, 1079, 1186, 1293`.

Relevant source rows begin at `y = 11, 122, 228, 338`. Every direct cell reference below uses a `96 x 96` crop from its listed origin before exact 3:1 reduction.

## Included-Tile Manifest

| Identifier | Atlas coordinate | Intended use | Source crop or composition reference |
| --- | ---: | --- | --- |
| `grass_base` | `(0, 0)` | Primary calm grass | Cell `c0,r0`, rectangle `(13,11,96,96)`; periodic center patch |
| `grass_variant_01` | `(1, 0)` | Restrained grass variation | `grass_base` plus center pixels from `c1,r0`, `(119,11,96,96)` |
| `grass_variant_02` | `(2, 0)` | Restrained grass variation | `grass_base` plus center pixels from `c3,r0`, `(332,11,96,96)` |
| `grass_variant_03` | `(3, 0)` | Restrained grass variation | `grass_base` plus center pixels from `c5,r0`, `(544,11,96,96)` |
| `grass_variant_04` | `(4, 0)` | Sparse quiet detail | `grass_base` plus center pixels from `c10,r1`, `(1079,122,96,96)` |
| `grass_worn_01` | `(5, 0)` | Lightly worn grass | `grass_base` plus center pixels from `c11,r1`, `(1186,122,96,96)` |
| `grass_worn_02` | `(6, 0)` | Lightly worn grass | `grass_base` plus center pixels from `c12,r1`, `(1293,122,96,96)` |
| `road_fill` | `(0, 1)` | Primary full-width earth road | Periodic center patch from road cross `c9,r2`, `(973,228,96,96)` |
| `road_fill_variant_01` | `(1, 1)` | Restrained road variation | `road_fill` plus center pixels from `c3,r2`, `(332,228,96,96)` |
| `road_edge_north` | `(2, 1)` | Grass north of road | North half of `c0,r2`, `(13,228,96,96)`, completed with `road_fill` |
| `road_edge_south` | `(3, 1)` | Grass south of road | South half of `c0,r2`, `(13,228,96,96)`, completed with `road_fill` |
| `road_edge_west` | `(4, 1)` | Grass west of road | West half of `c1,r2`, `(119,228,96,96)`, completed with `road_fill` |
| `road_edge_east` | `(5, 1)` | Grass east of road | East half of `c1,r2`, `(119,228,96,96)`, completed with `road_fill` |
| `road_straight_horizontal` | `(6, 1)` | Narrow horizontal-path reference or minor path | Direct `c0,r2`, `(13,228,96,96)` |
| `road_straight_vertical` | `(7, 1)` | Narrow vertical-path reference or minor path | Direct `c1,r2`, `(119,228,96,96)` |
| `road_outer_corner_nw` | `(0, 2)` | Road turns east and south around northwest exterior | Direct `c6,r2`, `(652,228,96,96)` |
| `road_outer_corner_ne` | `(1, 2)` | Road turns west and south around northeast exterior | Direct `c10,r2`, `(1079,228,96,96)` |
| `road_outer_corner_sw` | `(2, 2)` | Road turns north and east around southwest exterior | Direct `c8,r2`, `(866,228,96,96)` |
| `road_outer_corner_se` | `(3, 2)` | Road turns north and west around southeast exterior | Direct `c7,r2`, `(758,228,96,96)` |
| `road_inner_corner_nw` | `(4, 2)` | Concave northwest grass cutout | Composed from `road_fill` and `grass_base` |
| `road_inner_corner_ne` | `(5, 2)` | Concave northeast grass cutout | Composed from `road_fill` and `grass_base` |
| `road_inner_corner_sw` | `(6, 2)` | Concave southwest grass cutout | Composed from `road_fill` and `grass_base` |
| `road_inner_corner_se` | `(7, 2)` | Concave southeast grass cutout | Composed from `road_fill` and `grass_base` |
| `road_cross` | `(0, 3)` | Four-way road intersection | Direct `c9,r2`, `(973,228,96,96)` |
| `road_junction_n_e_w` | `(1, 3)` | North/east/west junction | Direct `c3,r2`, `(332,228,96,96)` |
| `road_junction_n_s_w` | `(2, 3)` | North/south/west junction | Direct `c5,r2`, `(544,228,96,96)` |
| `road_straight_horizontal_worn` | `(3, 3)` | Worn horizontal minor-road variation | Direct `c2,r2`, `(225,228,96,96)` |
| `road_to_plaza_north` | `(4, 3)` | Road enters plaza from north | Hard half-cell composition of `road_fill` and `plaza_fill` |
| `road_to_plaza_south` | `(5, 3)` | Road enters plaza from south | Hard half-cell composition of `road_fill` and `plaza_fill` |
| `road_to_plaza_west` | `(6, 3)` | Road enters plaza from west | Hard half-cell composition of `road_fill` and `plaza_fill` |
| `road_to_plaza_east` | `(7, 3)` | Road enters plaza from east | Hard half-cell composition of `road_fill` and `plaza_fill` |
| `plaza_fill` | `(0, 4)` | Primary rustic plaza paving | Cell `c0,r3`, `(13,338,96,96)`; periodic center patch |
| `plaza_variant_01` | `(1, 4)` | Subtle paving variation | `plaza_fill` plus center pixels from `c1,r3`, `(119,338,96,96)` |
| `plaza_variant_02` | `(2, 4)` | Subtle paving variation | `plaza_fill` plus center pixels from `c2,r3`, `(225,338,96,96)` |
| `plaza_variant_03` | `(3, 4)` | Subtle paving variation | `plaza_fill` plus center pixels from `c3,r3`, `(332,338,96,96)` |
| `plaza_edge_north` | `(4, 4)` | Grass north of plaza | Hard composition of `plaza_fill` and `grass_base` |
| `plaza_edge_south` | `(5, 4)` | Grass south of plaza | Hard composition of `plaza_fill` and `grass_base` |
| `plaza_edge_west` | `(6, 4)` | Grass west of plaza | Hard composition of `plaza_fill` and `grass_base` |
| `plaza_edge_east` | `(7, 4)` | Grass east of plaza | Hard composition of `plaza_fill` and `grass_base` |
| `plaza_outer_corner_nw` | `(0, 5)` | Square plaza exterior corner | Composed from `plaza_fill` and `grass_base` |
| `plaza_outer_corner_ne` | `(1, 5)` | Square plaza exterior corner | Composed from `plaza_fill` and `grass_base` |
| `plaza_outer_corner_sw` | `(2, 5)` | Square plaza exterior corner | Composed from `plaza_fill` and `grass_base` |
| `plaza_outer_corner_se` | `(3, 5)` | Square plaza exterior corner | Composed from `plaza_fill` and `grass_base` |
| `plaza_clipped_corner_nw` | `(4, 5)` | Locked octagonal plaza northwest clip | Hard diagonal composition of `plaza_fill` and `grass_base` |
| `plaza_clipped_corner_ne` | `(5, 5)` | Locked octagonal plaza northeast clip | Hard diagonal composition of `plaza_fill` and `grass_base` |
| `plaza_clipped_corner_sw` | `(6, 5)` | Locked octagonal plaza southwest clip | Hard diagonal composition of `plaza_fill` and `grass_base` |
| `plaza_clipped_corner_se` | `(7, 5)` | Locked octagonal plaza southeast clip | Hard diagonal composition of `plaza_fill` and `grass_base` |

## Considered but Excluded

- Crystal pedestal and blue-crystal paving candidates: excluded because Edenite dressing is outside this terrain pass.
- Diamond and emblem-like paving motifs: excluded because the plaza must remain orderly and non-symbolic.
- Heavily flowered grass: excluded from the runtime ground layer to avoid noise and to keep nature art in its later phase.
- Rock-strewn and heavily damaged paving: excluded to keep the Town Square surface maintained and readable.
- Dark vignette or shadow cells: excluded because they are not terrain materials and could conflict with later lighting.
- Generated diagonal-path fragments near the lower and right edges of the master: excluded because several carry incomplete alpha, colored edge residue, or inconsistent source bounds.
- Crystal plaza centerpiece candidates: excluded because the reserved community space remains undefined.

## Known Limitations and Manual Cleanup Candidates

- The master was generated as a presentation sheet rather than a strict game atlas; its source cells have inconsistent padding and pervasive partial alpha.
- Periodic grass and road texture patches remove hard seams but make repetition more apparent over large uninterrupted areas.
- Direct road corner and junction candidates do not perfectly match the recomposed wide-road fill width.
- The northeastern branch currently uses a four-cell-wide stair-step surface because the available diagonal candidates fail the clean-source gate.
- Road-to-plaza transitions are functional hard pixel compositions and would benefit from a hand-authored stone/earth border.
- Plaza edge tiles use a restrained hard transition rather than the master's more ornate curved borders.
- A future Aseprite pass should inspect grass repetition, road-fill periodicity, transition borders, corner widths, paving variation, and bespoke diagonal-road edges.

These limitations are acceptable for a terrain-only runtime prototype, not evidence of final visual approval.

## Godot Import Expectations

- Resource type: `TileSet` with one `TileSetAtlasSource`.
- Tile size and texture region size: `32 x 32`.
- Atlas source ID: `0`.
- Atlas alternative ID: `0` for every tile.
- Texture filtering: nearest-neighbor through the existing project default.
- Mipmaps: disabled for the runtime PNG import.
- Repeat: disabled.
- Compression: lossless.
- Terrain tiles contain no collision; Town Square collision remains scene-owned and independent.
- TileMapLayer node positions must remain integral.

## Town Square Usage

- `BaseTerrainTiles`: 30 by 22 cells of calm grass with sparse deterministic variation.
- `RoadTiles`: the four established routes plus a four-tile-wide stair-step representation of the northeastern Terrebonne branch.
- `PlazaTiles`: the locked clipped-corner plaza footprint.
- `TerrainTransitions`: four road-to-plaza connection bands.
- Original grass, road, and plaza Polygon2D nodes remain as hidden development fallback visuals.

## Automated Validation Targets

- Source master hash is unchanged.
- Atlas is exactly `256 x 192` and divisible by 32.
- Every documented atlas coordinate resolves through the TileSet.
- All included cells are exactly `32 x 32` and fully opaque.
- The TileSet and Town Square scene load without errors.
- Town Square exposes four positioned TileMapLayer nodes with integral transforms.
- Existing entry markers, exit triggers, collision bodies, NPCs, and camera bounds remain unchanged.

## Manual Review Checklist

- Inspect 3x3 grass repetition at the `640 x 360` internal resolution.
- Check sparse grass variation for checkerboarding or excessive detail.
- Walk horizontal and vertical roads and inspect edge continuity.
- Inspect wide-road fill for visible periodic bands.
- Inspect the northeast branch's stair-step silhouette.
- Check plaza fill, perimeter edges, and all four clipped corners.
- Inspect all four road-to-plaza transitions.
- Compare palette and texture scale with the approved daytime concept.
- Confirm Player and NPC silhouettes remain readable on every surface.
- Check for visible seams, matte color, alpha halos, and atlas bleed.
- Move the camera across the complete Town Square.
- Inspect visual continuity at all four zone entries and exits.
- Decide whether grass, road, or plaza is too detailed or repetitive.
- Record any tiles requiring manual Aseprite cleanup before production approval.
