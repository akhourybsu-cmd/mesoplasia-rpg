# Caden Town Square Composition Pass v1

## Scope

This scene-only pass unifies Town Square at the full-map scale without creating runtime art or changing its gameplay footprint. It reuses the prepared Caden terrain, architecture, nature, prop, Festival, Edenite, closure, and NPC resources already referenced by `TownSquare.tscn`.

## Preserved contracts

- Camera bounds remain `960 x 704`.
- All four exits and entry markers remain at their established positions.
- The five building centers, collision shapes, and exterior textures remain unchanged.
- Base terrain, road, plaza, and transition layers retain `660`, `116`, `192`, and `16` cells respectively.
- The reserved community collision remains the existing `96 x 96` area at `(304,272)`.
- The two-part Terrebonne collision remains at `(768,112)` and `(624,80)` with its existing sizes.
- Collision-bearing benches, ordinary lanterns, and the east plaza Edenite lantern remain in place.
- Development labels remain present for technical use but hidden in presentation.

## Composition changes

### Plaza hierarchy

`TerrainLayers/PlazaComposition` adds 33 visual cells from the existing Terrain Runtime v1.1 atlas across independently toned `TravelCorridors` and `ReservedInlay` layers. Eight narrow, visual-only seam polygons establish a broken inner border around a quiet `192 x 192` center. The lighter two-tile-wide paving corridors stop at its four openings, while cells `(8..10, 7..9)` form the neutral reserved 3x3 inlay. No monument, symbol, fixture, prop, or narrative identity enters the reserved area.

### Building transitions

`TerrainLayers/BuildingApproaches` contains five visual-only doorstep treatments aimed toward the nearest plaza or road surface. Each building also has a low-opacity `GroundDarkening` polygon beneath its existing strengthened contact shadow. Existing foundation vegetation and functional prop groups remain scene dressing rather than building logic.

### Environmental clusters

- Northwest: northwest building, west bench, west planter, ordinary north lantern, foundation vegetation, and the nearby ambient resident lane.
- Northeast: northeast building, framed Terrebonne approach, connected closure treatment, edge vegetation, and the existing restrained Edenite presence.
- Southwest: southwest building, barrel and storage grouping, ground lantern, shrubs, tree mass, and plain/Festival fence treatment.
- Southeast: southeast building, east bench and planter, luggage, travel pack, sacks, foliage, and restrained Festival fabric.
- South: the smaller building now has a directional doorstep treatment toward the Commons route and additional foundation grounding.

These labels describe composition only and do not establish permanent district names or canon.

### Perimeter and Terrebonne approach

The four dark perimeter polygons now use irregular, partially transparent silhouettes instead of uniform 32-pixel bars. Four additional side-boundary trees, nine additional low-vegetation placements, and a second northern fence run layer the scene edge while leaving all principal routes clear. Lower boundary trees render as foreground foliage.

The Terrebonne closure retains its original collision and gate, rope, and timber placements. A neutral fence end and hedge complete the visible obstruction while road-edge tufts and the northern fence run frame the continuation. The scene supplies no explanation for the closure.

### NPC activity anchors

- `NorthPlazaWalker` patrols near the northwest rest composition from `(160,272)`.
- `WestPlazaWalker` crosses the east road/plaza threshold from `(752,352)`.
- `SquareLocal` and `PassingVisitor` stand at `(288,448)` and `(352,448)`, facing one another near the southwest plaza edge.
- `SouthPlazaWalker` patrols beside the traveler composition from `(656,496)`.

The population remains two interactive NPCs and three bounded ambient patrols using the same reusable scenes, dialogue resources, and prepared character art.

## Verification contract

The composition regression checks assert the five doorstep visuals, building ground-darkening nodes, complete reserved inlay, new environmental counts, four coherent fence runs, restrained Festival ratio, six-part closure art, and NPC activity anchors. Existing geometry, resource-reference, collision, route-clearance, and source-master gates remain in force.
