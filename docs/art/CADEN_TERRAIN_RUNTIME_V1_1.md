# Caden Terrain Runtime v1.1

## Purpose and Review Findings

Terrain Runtime v1.1 is a non-destructive polish derivative of Runtime v1. It addresses the reviewed prototype's bright yellow-green grass, pervasive high-frequency contrast, mechanical plaza rows, dotted road repetition, abrupt road-to-plaza joins, and palette mismatch with the approved daytime concept.

This remains a terrain-only prototype. It does not authorize architecture, nature, props, Edenite, Festival dressing, character art, or changes to another Caden zone.

## Protected Inputs and Outputs

- Immutable source: `assets/source_art/caden/terrain/caden_terrain_master_v1.png`
- Source dimensions: `1448 x 1086`
- Source SHA-256 before and after: `36308c3fe4eb1bda2cca61c7778583440c07b8b859c2f597185f180ebdcb3b4c`
- Protected Runtime v1 atlas: `assets/tilesets/caden/terrain/caden_terrain_runtime_v1.png`
- Runtime v1 SHA-256 before and after: `0e0b6e5bad4c3a64acd427171212ba16ed2a75e10f0006df22d6445100fa0279`
- Runtime v1.1 atlas: `assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png`
- Runtime v1.1 SHA-256: `bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a`
- Runtime v1.1 TileSet: `assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.tres`
- Preparation script: `tools/art/prepare_caden_terrain_runtime_v1_1.py`
- Placement seed: `0xCADA1101`

The script refuses to run if either protected input hash changes. It writes only the v1.1 atlas and documentation previews.

## Atlas Structure

- Dimensions: `256 x 256`
- Grid: `8 x 8`
- Tile size: exact `32 x 32`
- Included tiles: 58
- Unused cells: `(2,7)` through `(7,7)`
- Godot atlas source ID: `0`
- Alternative ID: `0`
- Physics layers: none

## Original Source-Crop Lineage

Runtime v1.1 derives from the protected Runtime v1 cells, whose source-master lineage is retained below. Every direct source region was originally reduced from `96 x 96` to `32 x 32` by exact 3:1 nearest-neighbor resampling during v1 preparation.

| Reference | Original source-master region |
| --- | --- |
| `G0` | Grass base: `c0,r0`, rectangle `(13,11,96,96)` |
| `G1` | Grass variation: `c1,r0`, rectangle `(119,11,96,96)` |
| `G2` | Grass variation: `c3,r0`, rectangle `(332,11,96,96)` |
| `G3` | Grass variation: `c5,r0`, rectangle `(544,11,96,96)` |
| `G4` | Quiet grass detail: `c10,r1`, rectangle `(1079,122,96,96)` |
| `GW1` | Worn grass: `c11,r1`, rectangle `(1186,122,96,96)` |
| `GW2` | Worn grass: `c12,r1`, rectangle `(1293,122,96,96)` |
| `R0` | Road fill lineage: road cross `c9,r2`, rectangle `(973,228,96,96)` |
| `R1` | Road variation lineage: `c3,r2`, rectangle `(332,228,96,96)` |
| `RW` | Worn road lineage: `c2,r2`, rectangle `(225,228,96,96)` |
| `P0` | Plaza base: `c0,r3`, rectangle `(13,338,96,96)` |
| `P1` | Plaza variation: `c1,r3`, rectangle `(119,338,96,96)` |
| `P2` | Plaza variation: `c2,r3`, rectangle `(225,338,96,96)` |
| `P3` | Plaza variation: `c3,r3`, rectangle `(332,338,96,96)` |

Composed edges, corners, thresholds, and macro tiles use only color-corrected pixels from these documented lineages. No new source-master crop or generative replacement was introduced.

## Complete Included-Tile Manifest

| Identifier | Coordinate | Intended use | Derivation |
| --- | ---: | --- | --- |
| `grass_base` | `(0,0)` | Primary calm grass | `G0`; grass-family correction and shared 12-color clustering |
| `grass_variant_01` | `(1,0)` | Subtle grass variation | `G1` interior within shared `G0` border |
| `grass_variant_02` | `(2,0)` | Subtle grass variation | `G2` interior within shared `G0` border |
| `grass_variant_03` | `(3,0)` | Subtle grass variation | `G3` interior within shared `G0` border |
| `grass_variant_04` | `(4,0)` | Quiet detail variation | `G4` interior within shared `G0` border |
| `grass_variant_05` | `(5,0)` | Low-value variation | Reproducible `G0` interior value adjustment |
| `grass_worn_01` | `(6,0)` | Sparse worn grass | `GW1` interior within shared `G0` border |
| `grass_worn_02` | `(7,0)` | Sparse worn grass | `GW2` interior within shared `G0` border |
| `road_fill` | `(0,1)` | Primary earth-road fill | `R0`; road-family correction and shared 16-color clustering |
| `road_fill_variant_01` | `(1,1)` | Quiet road variation | `R1` interior within shared `R0` border |
| `road_fill_variant_02` | `(2,1)` | Quiet darker-center variation | Reproducible `R0` interior value adjustment |
| `road_fill_variant_03` | `(3,1)` | Quiet lighter-center variation | Reproducible `R0` interior value adjustment |
| `road_fill_variant_04` | `(4,1)` | Small road variation | Restrained `R1` interior within shared `R0` border |
| `road_worn_01` | `(5,1)` | Sparse worn-center road | `RW` interior within shared `R0` border |
| `road_worn_02` | `(6,1)` | Sparse compact wear | Restrained `R1` interior within shared `R0` border |
| `road_edge_north` | `(7,1)` | Grass north of road | Irregular hard-pixel composition of `R0` and `G0` |
| `road_edge_south` | `(0,2)` | Grass south of road | Irregular hard-pixel composition of `R0` and `G0` |
| `road_edge_west` | `(1,2)` | Grass west of road | Irregular hard-pixel composition of `R0` and `G0` |
| `road_edge_east` | `(2,2)` | Grass east of road | Irregular hard-pixel composition of `R0` and `G0` |
| `road_straight_horizontal` | `(3,2)` | Horizontal continuity reference | Corrected north-edge material |
| `road_straight_vertical` | `(4,2)` | Vertical continuity reference | Corrected west-edge material |
| `road_outer_corner_nw` | `(5,2)` | Northwest exterior road corner | `R0`/`G0` hard-pixel composition |
| `road_outer_corner_ne` | `(6,2)` | Northeast exterior road corner | `R0`/`G0` hard-pixel composition |
| `road_outer_corner_sw` | `(7,2)` | Southwest exterior road corner | `R0`/`G0` hard-pixel composition |
| `road_outer_corner_se` | `(0,3)` | Southeast exterior road corner | `R0`/`G0` hard-pixel composition |
| `road_inner_corner_nw` | `(1,3)` | Northwest concave road corner | Restrained `R0`/`G0` composition |
| `road_inner_corner_ne` | `(2,3)` | Northeast concave road corner | Restrained `R0`/`G0` composition |
| `road_inner_corner_sw` | `(3,3)` | Southwest concave road corner | Restrained `R0`/`G0` composition |
| `road_inner_corner_se` | `(4,3)` | Southeast concave road corner | Restrained `R0`/`G0` composition |
| `road_cross` | `(5,3)` | Four-way road fill | Corrected `R0` fill |
| `road_junction_n_e_w` | `(6,3)` | North/east/west junction material | `R0` with sparse worn interior |
| `road_junction_n_s_w` | `(7,3)` | North/south/west junction material | `R0` with alternate worn interior |
| `road_to_plaza_north` | `(0,4)` | North approach threshold | `R0` to `P0` with narrow constructed stone band |
| `road_to_plaza_south` | `(1,4)` | South approach threshold | `R0` to `P0` with narrow constructed stone band |
| `road_to_plaza_west` | `(2,4)` | West approach threshold | `R0` to `P0` with narrow constructed stone band |
| `road_to_plaza_east` | `(3,4)` | East approach threshold | `R0` to `P0` with narrow constructed stone band |
| `plaza_fill` | `(4,4)` | Primary calm plaza paving | `P0`; plaza-family correction and shared 18-color clustering |
| `plaza_variant_01` | `(5,4)` | Subtle paving variation | `P1` interior within shared `P0` border |
| `plaza_variant_02` | `(6,4)` | Subtle paving variation | `P2` interior within shared `P0` border |
| `plaza_variant_03` | `(7,4)` | Subtle paving variation | `P3` interior within shared `P0` border |
| `plaza_variant_04` | `(0,5)` | Subtle darker paving variation | Reproducible `P0` interior value adjustment |
| `plaza_variant_05` | `(1,5)` | Subtle lighter paving variation | Reproducible `P0` interior value adjustment |
| `plaza_macro_nw` | `(2,5)` | 2x2 macro group northwest | Related `P1` interior with subtle low-frequency value shift |
| `plaza_macro_ne` | `(3,5)` | 2x2 macro group northeast | Related `P2` interior with subtle low-frequency value shift |
| `plaza_macro_sw` | `(4,5)` | 2x2 macro group southwest | Related `P3` interior with subtle low-frequency value shift |
| `plaza_macro_se` | `(5,5)` | 2x2 macro group southeast | Related `P1` interior with subtle low-frequency value shift |
| `plaza_edge_north` | `(6,5)` | Grass north of plaza | Restrained `P0`/`G0` hard-pixel edge |
| `plaza_edge_south` | `(7,5)` | Grass south of plaza | Restrained `P0`/`G0` hard-pixel edge |
| `plaza_edge_west` | `(0,6)` | Grass west of plaza | Restrained `P0`/`G0` hard-pixel edge |
| `plaza_edge_east` | `(1,6)` | Grass east of plaza | Restrained `P0`/`G0` hard-pixel edge |
| `plaza_outer_corner_nw` | `(2,6)` | Square northwest plaza corner | `P0`/`G0` hard-pixel composition |
| `plaza_outer_corner_ne` | `(3,6)` | Square northeast plaza corner | `P0`/`G0` hard-pixel composition |
| `plaza_outer_corner_sw` | `(4,6)` | Square southwest plaza corner | `P0`/`G0` hard-pixel composition |
| `plaza_outer_corner_se` | `(5,6)` | Square southeast plaza corner | `P0`/`G0` hard-pixel composition |
| `plaza_clipped_corner_nw` | `(6,6)` | Locked northwest plaza clip | Diagonal `P0`/`G0` composition |
| `plaza_clipped_corner_ne` | `(7,6)` | Locked northeast plaza clip | Diagonal `P0`/`G0` composition |
| `plaza_clipped_corner_sw` | `(0,7)` | Locked southwest plaza clip | Diagonal `P0`/`G0` composition |
| `plaza_clipped_corner_se` | `(1,7)` | Locked southeast plaza clip | Diagonal `P0`/`G0` composition |

## Color and Contrast Operations

All operations are per-pixel, deterministic, and applied only to Runtime v1.1 derivatives.

- Grass: hue shifted `+6 degrees` toward middle green, saturation multiplied by `0.84`, luminance/value by `0.92`, and contrast by `0.60`; clustered to a shared 12-color family palette.
- Road: hue shifted `-1 degree`, saturation multiplied by `0.88`, luminance/value by `0.86`, and contrast by `0.64`; clustered to a shared 16-color family palette.
- Plaza: hue shifted `-1.5 degrees`, saturation multiplied by `0.84`, luminance/value by `0.98`, and contrast by `0.62`; clustered to a shared 18-color family palette.
- Variants preserve shared outer borders and change only restrained interiors.
- No blur, interpolation, antialiasing, dithering, procedural high-frequency noise, rotation, mirroring, or runtime randomization is used.

Technical material readings for primary tiles:

| Material | Mean grayscale | Mean saturation | Mean channel standard deviation |
| --- | ---: | ---: | ---: |
| Grass | `118.03` | `0.4507` | `6.61` |
| Road | `154.00` | `0.3239` | `6.05` |
| Plaza | `167.26` | `0.2015` | `10.28` |

These measurements support material separation in grayscale and reduced saturation. They are technical indicators, not visual approval.

## Deterministic Town Square Placement

Placement uses the stable seed `0xCADA1101` and a coordinate-mixing function implemented in the preparation script. No runtime randomization is involved.

### Grass

Across the 660-cell base layer:

- Primary base: 487 cells (`73.79%`).
- Five subtle variants: 142 cells (`21.52%`).
- Two worn variants: 31 cells (`4.70%`).

The stable coordinate hash selects the family and variant without rows, columns, checkerboards, or a fixed visible cycle.

### Road

The road layer retains 116 cells and the existing route widths. Its 68 fill cells use:

- Primary fill: 35.
- Four quiet variants: 29 total (`12`, `5`, `8`, and `4`).
- Two worn variants: 4 total (`2` each).
- Directional edges: 48 total (`14` north, `14` south, `10` west, `10` east).

Worn selection is allowed slightly more often near plaza approaches, but remains sparse.

### Plaza

The plaza layer retains 192 cells:

- Primary fill: 89.
- Five subtle variants: 43 total (`7`, `6`, `10`, `10`, and `10`).
- Two sparse 2x2 macro groups: 8 cells total, two uses of each macro quadrant.
- Directional edges: 48.
- Clipped corners: 4.

The central field uses the primary calm fill. Macro groups remain outside it and carry no emblem or symbolic pattern.

### Transitions

The transition layer retains 16 cells: four each for north, south, west, and east. Each tile replaces the former half-cell paste with a narrow, non-blocking constructed stone threshold between earth and maintained paving.

## Comparison Findings and Failure Gate

The generated side-by-side preview shows a material improvement over Runtime v1:

- Grass is darker, less yellow, less saturated, and less internally contrast-heavy.
- Road dots are less prominent, with more varied center treatment and stronger grayscale separation from plaza paving.
- Plaza repetition is reduced through five variants, calm-center placement, and two sparse non-symbolic macro groups.
- Road-to-plaza joins now contain a constructed threshold rather than a single rectangular material cut.
- The overall palette is softer and more cohesive while preserving grass/road/plaza distinction.

This visual assessment is an inference from the generated previews. The failure gate was not triggered, so Town Square may reference v1.1 for manual review.

## Excluded and Deferred Material

The v1 exclusions remain in force: crystals, pedestals, symbolic or ornate paving, Festival content, heavily flowered grass, nature props, architecture, dark vignette cells, and contaminated diagonal fragments remain excluded. No centerpiece identity was assigned to the reserved community space.

Deferred Aseprite work includes bespoke diagonal edges for the northeastern branch, hand-tuned plaza macro seams, more organic road corners, hand-authored threshold stones, and final palette clustering after architecture and character art can be judged together.

## Preview Outputs

- `docs/art/previews/caden_terrain_runtime_v1_1_validation.png`
- `docs/art/previews/caden_terrain_runtime_v1_1_town_square_preview.png`
- `docs/art/previews/caden_terrain_v1_vs_v1_1_comparison.png`

The previews are documentation artifacts, not runtime assets.

## Automated Technical Validation

Automated checks cover input hashes, output dimensions, tile count, full opacity of used cells, transparent unused cells, TileSet loading, 32x32 regions, absence of terrain collision, Town Square resource references, distribution ranges, preserved entries/exits/bounds, project launch, resource parsing, and regression suites.

Automated checks do not constitute visual approval.

## Manual Review Checklist

- Grass brightness, yellow bias, repetition, and calm at `640 x 360`.
- Plaza repetition, central calm, and 2x2 macro visibility.
- Road repetition, width consistency, and worn-center frequency.
- Road-to-plaza thresholds from every direction.
- Clipped plaza corners and the northeastern Terrebonne branch.
- Full-color, grayscale, and reduced-saturation material separation.
- Palette match against the approved daytime concept.
- Player and NPC contrast on grass, road, and plaza.
- Visible seams, halos, and atlas bleeding.
- Camera movement and entry/exit route continuity.
- Whether any tile requires manual Aseprite cleanup before production approval.

## Known Limitations

- The original master and v1 cells retain presentation-sheet texture structure; clustering reduces but cannot completely remove repetition.
- Plaza masonry still has a recognizable horizontal orientation.
- The northeastern branch remains a four-cell-wide stair-step because clean diagonal source material is unavailable.
- Road corners and thresholds are deterministic pixel composites rather than hand-authored final tiles.
- Final palette approval should wait until Player, NPC, architecture, foliage, and shadow art can be evaluated together.
