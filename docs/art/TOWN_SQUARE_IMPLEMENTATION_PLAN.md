# Town Square Environment-Art Implementation Plan

## Purpose and Scope

This document prepares the available Caden source-art sheets for a later Town Square visual implementation. It does not authorize final artwork integration, change the approved layout, or establish new Mesoplasia canon.

The first implementation pass must be limited to Town Square. Other Caden zones should continue using their current visuals until separately approved. Existing collision, entry markers, exit triggers, NPC behavior, dialogue, interaction, objective progress, and zone transitions must remain functionally unchanged.

## Approved Layout Baseline

Town Square currently uses a `960 x 704`-pixel scene footprint on the `32 x 32` world grid. Its established elements include:

- Four functional connections: Wayfarer's Approach, Residential Quarter, Marketplace, and Commons.
- A visible but blocked branch toward Terrebonne.
- An open, clipped-corner plaza with clear crossing routes.
- Five generic, grid-aligned building footprints.
- A reserved `96 x 96`-pixel community space whose identity remains undefined.
- Existing NPC positions, interaction access, collision, and transition geometry.

Source art must be adapted to this layout. The concept image must not be used to replace or redraw the approved scene geometry.

## Source-Art Inventory and Assessment

All available sheets are master/reference images rather than production-ready runtime atlases.

| Source | Dimensions | Apparent contents | Candidate use | Current status |
| --- | ---: | --- | --- | --- |
| `concept/caden_town_square_daytime_concept.png` | 1418 x 1109 | A fully composed daytime Town Square reference with grass, paved plaza, roads, rustic buildings, fences, foliage, lamps, signs, props, characters, decorative accents, and a central feature | Palette, mood, material, density, and architectural reference | Reference-only; its layout, text, iconography, central feature, and specific decorations are not approved implementation instructions |
| `terrain/caden_terrain_master_v1.png` | 1448 x 1086 | Grass variants, flowered grass, dirt-road pieces, paved/cobblestone pieces, grass-to-path and grass-to-paving edges, corners, junctions, worn paving, shadow-like pieces, decorative paving motifs, and crystal-accented pieces | Candidate tile-based grass, road, plaza, and edge material | Requires extraction, cleanup, scale decision, grid normalization, and tile-neighbor testing |
| `architecture/caden_architecture_master_v1.png` | 1448 x 1086 | Roof planes and ridges, gables, timber-and-plaster walls, masonry, doors, windows, flower boxes, porches, stairs, chimneys, pipes, hanging signs, fences, gates, barrels, crates, shrubs, and small roof/building details | Candidate building modules, collision-backed structure sprites, foreground roof overlays, and selected neutral props | Requires separation by asset class, transparent-edge cleanup, scale normalization, anchors, and assembly tests |
| `props/caden_props_master_v1.png` | 1536 x 1024 | Benches, lamps, planters, fences, gates, posts, ropes, signs, notice board, barrels, crates, sacks, chests, luggage, bedrolls, logs, market stalls, carts, wagons, vegetation pots, and a blocked-road arrangement | Candidate placeable props, boundary dressing, sparse plaza decoration, and decorative overlays | Requires individual cropping, background/alpha cleanup, scale normalization, anchors, and collision classification |
| `accents/caden_edenite_festival_master_v1.png` | 1448 x 1086 | Crystal-bearing lamps and structures, crystal outcrops, crystal architectural details, blue-and-cream drapery, banners, bunting, decorated posts, decorated fences, luggage, gates, and other event-like accents | Candidate source for a later restrained Edenite accent pass and sparse generic blue-and-cream Festival-period decoration | Available source master requiring preparation; restrained non-symbolic use is approved, while symbolic or lore-bearing art remains unapproved |
| `nature/caden_nature_master_v1.png` | 1536 x 1024 | Trees, bushes, hedges, ground flowers, tall plants, vines, potted plants, rocks, logs, stumps, and small ground-detail overlays | Candidate nature sprites, perimeter dressing, planters, rocks, wood details, and non-blocking ground overlays | Available source master requiring separation, background/edge cleanup, scale normalization, consistent anchors, transparent runtime exports, and partitioning by asset type |

### Transparency and Canvas Findings

- The concept image is a fully opaque composite and cannot supply clean standalone sprites without reconstructive editing.
- The terrain, architecture, nature, props, and accents sheets contain alpha, but inspection found extensive partially transparent pixels rather than cleanly separated, predominantly opaque sprites.
- Some transparent or near-transparent pixels retain strong RGB color. These can produce fringes or halos after cropping, scaling, filtering, or texture-atlas sampling.
- Canvas dimensions and visible element spacing are not regular multiples of the project's `32 x 32` tile size.
- Assets vary substantially in size and padding, so using raw image regions would produce inconsistent pivots and apparent scale.

## Practical Use Classification

### Tile-Based Material Candidates

The terrain sheet provides the strongest candidates for tile-based material:

- Quiet grass bases and restrained grass variants.
- Dirt-road centers, edges, corners, and junctions.
- Plaza paving centers and edge transitions.
- Grass-to-road and grass-to-paving transitions.
- Limited worn or damaged surface variations.

These are conceptual tile candidates, not immediately valid Godot tiles. Each selected tile must first be cropped, normalized to a consistent source grid, and adapted to the approved `32 x 32` runtime tile logic. Decorative crystal tiles and unapproved motifs should remain unused.

### Placeable Prop Candidates

The props and architecture sheets contain recognizable discrete objects that could become individual `Sprite2D` resources after preparation:

- Neutral benches and planters.
- Wood fences, posts, gates, and simple boundary pieces.
- Barrels, crates, sacks, logs, and restrained travel supplies.
- Neutral lamps, notice-board forms, and sign supports without unapproved symbols or text.
- Doors, windows, porches, stairs, chimneys, and selected building modules.
- Market structures only where their use matches the approved zone and does not redefine Town Square.

Every collision-bearing prop must receive deliberate collision in the scene or a reusable prop scene. Collision should never be inferred automatically from the master-sheet rectangle.

### Overlay and Decorative Candidates

Potential overlays include:

- Grass tufts, flower clusters, and paving wear.
- Flower boxes and restrained building greenery.
- Roof overhangs, gables, eaves, and chimney smoke where approved and technically appropriate.
- Foreground fence rails or vegetation that overlap characters without hiding routes.

Restrained Edenite fixtures and accents, plus sparse generic blue-and-cream Festival-period fabric decoration, are approved for a later environmental-dressing pass. Symbolic or lore-bearing Festival art remains unapproved. Every selected accent still requires preparation before runtime use, and the pass must wait until terrain, architecture, nature, and basic neutral dressing are stable.

## Required Asset Preparation

Preparation should produce derived runtime files while leaving every master sheet unchanged.

### Terrain Preparation

1. Select only the minimum grass, dirt-road, plaza, and transition pieces required by the locked layout.
2. Crop each candidate to exact source bounds and remove colored or low-alpha fringe pixels.
3. Determine a consistent resampling or redraw approach that preserves intentional pixel clusters at `32 x 32`; do not blindly shrink the full sheet.
4. Normalize tile boundaries to a strict `32 x 32` runtime grid.
5. Check opposite edges for seamless repetition and correct edge matching.
6. Group variants by purpose: base, transition, corner, junction, and sparse detail.
7. Exclude decorative motifs that imply unapproved lore.

### Architecture Preparation

1. Separate roofs, walls, foundations, doors, windows, porches, chimneys, and foreground pieces into coherent modules or assembled building sprites.
2. Establish one Town Square scale by comparing doors and porches with the Player's `32 x 32` gameplay footprint.
3. Match assembled art to the five approved building footprints without changing their collision geometry.
4. Normalize origins around a documented ground-contact point, preferably the center of the collision footprint's bottom edge for assembled façades.
5. Remove transparent padding, semi-transparent residue, color spill, and overlaps from neighboring sheet elements.
6. Separate portions that must render behind actors from roof/eave portions that may render in front.
7. Keep doors and signs visually neutral unless their identity is approved.

### Props and Overlays Preparation

1. Crop selected objects to individual transparent PNGs or a deliberately packed atlas with safe padding.
2. Remove background haze and partial-alpha fringe pixels while preserving intentional soft effects only when explicitly desired.
3. Normalize scale against the `32 x 32` grid, Player silhouette, doors, and fences.
4. Use consistent anchor categories: bottom-center for upright props, ground-center for freestanding objects, and grid-origin anchors for modular fences.
5. Identify each prop as decorative-only, foreground overlay, or collision-bearing before scene placement.
6. Keep the initial prop set sparse and neutral.

### Nature Preparation

The Nature master is available as source/reference material for trees, bushes, hedges, ground flowers, tall plants, vines, potted plants, rocks, logs, stumps, and small ground-detail overlays. It remains a master sheet rather than a production-ready atlas.

Later preparation must:

1. Separate individual sprites and modular hedge sections.
2. Remove the sheet background and clean residual edge color or partial-alpha contamination.
3. Normalize scale against the `32 x 32` grid, Player, buildings, fences, and other prepared Caden assets.
4. Assign consistent ground-contact anchors for trees, shrubs, pots, rocks, logs, and overlays.
5. Export clean transparent runtime PNGs rather than referencing master-sheet regions directly.
6. Partition the prepared results by asset type, such as trees, bushes, hedges, flowers, tall plants, vines, potted plants, rocks, wood details, and ground overlays.

## Assets to Use First

The first approved art-integration pass should use only a narrow, cleaned subset:

1. One quiet grass base plus a very small number of low-density variants.
2. A complete dirt-road set for the four zone routes and the Terrebonne branch.
3. A coherent plaza-paving center and edge set that fits the clipped-corner plaza.
4. Necessary grass, road, and paving transitions.
5. One consistent neutral timber-and-stone building treatment adapted across the approved footprints.
6. A minimal neutral boundary set for perimeter readability and the blocked Terrebonne route.
7. A few cleaned benches, planters, barrels, crates, or fence segments placed outside primary circulation lanes.

This subset is enough to evaluate scale, palette, route readability, and visual cohesion without committing to the full contents of any master sheet.

## Assets to Keep Reference-Only

- The full Town Square concept composition, including its exact layout and written signs.
- Any central crystal, fountain, monument, patterned emblem, or other proposed identity for the reserved community space.
- Festival symbols, crests, religious imagery, relic imagery, historical iconography, and any decoration that would establish unapproved meaning.
- Edenite pedestals, large crystals, and other centerpiece-like components unless a later task approves a specific non-central use.
- Decorative paving motifs that imply unapproved meaning.
- Merchant or business signs whose identity is not established.
- Complex market stalls in Town Square unless their placement and purpose are approved.
- The more elaborate carts, wagons, chests, and dense prop groupings until base scale and navigation are validated.
- Any asset whose silhouette, alpha, or scale cannot be cleaned without substantial reconstruction.

## Proposed Godot Import Strategy

### Source Masters

- Keep the original master sheets under `assets/source_art/caden/` unchanged as traceable references.
- Do not reference master sheets directly from Town Square scenes or resources.
- Godot may still discover and import images stored under `res://`; if source-sheet import overhead becomes undesirable, consider an approved `.gdignore` decision separately rather than introducing an asset-pipeline framework during implementation.

### Derived Runtime Assets

- Place approved terrain atlases under `assets/tilesets/caden/` and prepared environment sprites under a dedicated Caden subdirectory of `assets/environments/`.
- Export PNGs with true transparent backgrounds, intentional alpha, and sufficient atlas padding to prevent neighboring-pixel bleed.
- Use lossless texture import, mipmaps disabled, repeat disabled unless a specific prepared texture requires it, and the project's nearest-neighbor filtering standard.
- Use `TileSetAtlasSource` resources with `32 x 32` texture regions for normalized terrain tiles.
- Use individual textures or deliberately packed atlases for props and building modules; do not use arbitrary master-sheet regions as production sprites.
- Keep all runtime node positions and sprite offsets on integer pixels.
- Set pivots consistently during preparation instead of compensating with unrelated per-instance offsets.
- Preserve collision in Town Square as the behavioral authority until visual assets and collision are deliberately reconciled and regression-tested.

## Proposed Town Square Layering Strategy

The current scene hierarchy already provides an appropriate boundary for visual integration:

1. `TerrainLayers/BaseTerrain`: grass TileMapLayer or equivalent visual ground layer.
2. `TerrainLayers/Routes`: dirt-road tiles for the four connections and Terrebonne branch.
3. `TerrainLayers/Plaza`: plaza centers, edges, and clipped corners.
4. `TerrainLayers/GroundDetails`: non-blocking grass tufts, flowers, paving wear, and small transition overlays.
5. `SolidScenery/PerimeterVisuals`: trees, dense foliage, fences, or other clear edge visuals aligned with existing boundary collision.
6. `SolidScenery/Buildings`: building foundations and assembled structures tied to the existing footprint collision.
7. `SolidScenery/ReservedCommunitySpace`: retain a neutral placeholder or visually quiet reserved patch; do not assign an identity.
8. `SolidScenery/TerrebonneClosure`: neutral closure art aligned with both existing barrier shapes so the route remains visibly and physically blocked.
9. `EnvironmentalProps`: sparse props, each classified as decorative or collision-bearing.
10. `Actors/NPCs`: preserve current actors, positions, and interaction behavior.
11. `ForegroundOverlays`: roof edges, tree canopies, or tall foliage that may pass in front of actors without obscuring routes or prompts.
12. `DevelopmentLabels`: keep available during implementation and disable visually only when their technical information is no longer needed for a review pass.

Y-sorting should be introduced only where overlapping sprites require it and only after testing that it does not disturb the current hierarchy. It is not necessary for the first terrain-material pass.

## Proposed Implementation Order

1. **Terrain preparation and test:** prepare the minimal grass, roads, paving, and transition set; validate it against the locked layout before continuing.
2. **Architecture preparation and building adaptation:** prepare one coherent building subset and fit it to the existing footprints without changing collision.
3. **Nature preparation and perimeter dressing:** separate and normalize the required nature sprites, then establish controlled perimeter massing and restrained ground detail.
4. **Neutral props and travel-related dressing:** add a sparse selection outside primary routes, transitions, and interaction approach spaces.
5. **Restrained Edenite/Festival accent pass:** introduce only a small number of Edenite-blue accents and sparse generic blue-and-cream fabric decorations after the base environment is stable; keep symbolic or lore-bearing art excluded and the reserved community space open and undefined.
6. **Final readability and density review at `640 x 360`:** inspect integer-scaled output, verify collision and transitions remain visually truthful, rerun all Caden regression tests, and review Town Square before changing another zone.

## Readability and Regression Gates

Before approving a Town Square visual pass:

- The plaza and all four primary routes must remain visually obvious and unobstructed.
- The blocked Terrebonne route must remain impossible to bypass and must not gain an invented narrative explanation.
- Building art must not obscure collision expectations or imply usable doors where none exist.
- NPCs and the Player must remain legible against every nearby ground material.
- Interaction prompts and approach spaces must remain clear.
- No decorative object may cover an exit trigger, entry marker, objective-critical route, or dialogue approach.
- The reserved community space must remain undefined.
- No other Caden zone may receive the new art during this phase.

## Primary Risks

1. **Scale mismatch:** the master sheets are not authored as `32 x 32` runtime atlases, and inconsistent resizing could break the shared pixel scale.
2. **Alpha contamination:** widespread partial-alpha pixels and retained RGB color can create halos, muddy composites, and atlas bleed.
3. **Layout drift:** the concept composition differs from the approved playable layout and could unintentionally move routes, buildings, or reserved space.
4. **Canon leakage:** centerpiece-like crystal use, symbolic banners, written signs, or lore-bearing Festival decorations could establish unapproved visual meaning.
5. **Collision mismatch:** assembled buildings and props may visually disagree with the existing blocking geometry.
6. **Readability loss:** the source references are richly detailed; copying their density directly could obscure characters, interactions, and routes at `640 x 360`.
7. **Nature-sheet complexity:** the available sheet combines large silhouettes, small overlays, rocks, wood, and potted plants, so inconsistent extraction could create mismatched scale and anchors.
8. **Master-sheet coupling:** referencing whole sheets directly would make pivots, padding, atlas regions, and later revisions brittle.

## Current Decision Boundary

No final Town Square visuals should be implemented from these sheets until the cleanup scope and runtime subset are reviewed. Restrained Edenite accents and sparse generic blue-and-cream Festival-period fabric decoration are approved for a later environmental-dressing pass, but symbolic or lore-bearing Festival art remains unapproved. The reserved central community space must stay visually open and undefined. The safest next production step is a small terrain-preparation pass using only neutral grass, road, plaza, and transition material while preserving every established gameplay boundary.
