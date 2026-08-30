# Caden Modular Environment Expansion Library v1

This package adds a composition-first environment library for all five Caden zones. It contains five source-master sheets with 36 candidates each: 180 candidates total.

## Important status

These are **source candidates, not runtime-ready PNGs**. The designs are useful and cohesive, but the generated masters contain known edge-color contamination, extensive partial alpha, and some occupied outer-edge pixels. Every selected candidate must be extracted, cleaned, normalized, and approved before it enters Godot.

- Runtime-approved assets: `0`
- Source candidates: `180`
- Source sheets: `5`
- Current status for every candidate: `SOURCE_CANDIDATE_CLEANUP_REQUIRED`

The failed cleanup and regeneration drafts are intentionally excluded from this package.

## Contents

| Batch | IDs | Candidates | Purpose |
|---|---:|---:|---|
| Landscaping | `CAD-LAND-01`–`36` | 36 | Trees, shrubs, flowers, rocks, logs, natural masses |
| Fences and boundaries | `CAD-FENCE-01`–`36` | 36 | Fence runs, gates, corners, low walls, boundary compositions |
| Architectural add-ons | `CAD-ARCH-01`–`36` | 36 | Porches, awnings, doors, windows, foundations, lanterns |
| Yard furnishings | `CAD-YARD-01`–`36` | 36 | Benches, planters, utility props, travel storage, furnished pockets |
| Connected compositions | `CAD-COMP-01`–`36` | 36 | Zone-specific structural groupings and transition frames |

See [metadata/ASSET_CATALOG.md](metadata/ASSET_CATALOG.md) for the complete 180-ID catalog.

## Composition standard

Use this library to build connected environmental structure—not evenly scattered decoration.

- Form mature tree masses and clear canopy hierarchy.
- Use U- and L-shaped yards, framed entries, deliberate road shoulders, and connected edge gardens.
- Keep broad roads, market aisles, plaza approaches, domestic lanes, and Commons paths readable.
- Concentrate clutter where an activity explains it: beside a porch, loading edge, stall backstock area, hitching pocket, or rest area.
- Preserve quiet negative space around major buildings and transitions.
- Prefer a few strong environmental compositions over many isolated props.

## Recommended zone emphasis

| Zone | Primary batches | Recommended use |
|---|---|---|
| Wayfarer’s Approach | `LAND`, `FENCE`, `YARD-25–30`, `COMP-01–06` | Road shoulders, arrival framing, traveler staging, hitching edges, inn-side rest areas |
| Marketplace | `ARCH-07–24`, `YARD-19–30`, `COMP-07–12` | Stall edges, backstock, deliveries, aisle framing, restrained perimeter greenery |
| Town Square | `ARCH-01–09`, `YARD-19–24`, `COMP-13–18` | Civic approaches, public seating, plaza-edge gardens; preserve the reserved center |
| Residential Quarter | `LAND`, `FENCE`, `ARCH-01–18`, `YARD-01–18`, `COMP-19–24` | Connected yards, porches, gardens, domestic lane definition |
| Commons | `LAND`, `FENCE-19–36`, `YARD-01–06`, `COMP-25–30` | Mature groves, meadow edges, rest pockets, natural map boundaries |
| Transitions | `LAND-31–36`, `FENCE-31–36`, `COMP-31–36` | Concealed map edges and open, visually matched corridors |

## Extraction and approval workflow

1. Stage this package outside Godot's `res://` tree.
2. Review the catalog and select a small zone-specific candidate set.
3. Extract each candidate into its own working PNG.
4. Remove colored edge contamination, detached fragments, broad baked shadows, and nonstructural ground blobs manually at native pixels.
5. Rebuild true alpha. Do not globally delete red or yellow; legitimate flowers, fabric, foliage, and lamps may use related colors.
6. Normalize exact grid modules offline with nearest-neighbor sampling. Import them at Godot scale `1.0`.
7. Set bottom-center anchors from structural ground contact, ignoring flowers, loose grass, and shadow pixels.
8. Use object-specific collision. Trees collide at trunks; fences at rails/posts; gates preserve their openings; low plants normally remain nonblocking.
9. Split ground detail, structural objects, and foreground occluders whenever player overlap or Y-sorting requires it.
10. Produce 640×360 placement comparisons with player overlap before approving any scene edit.

The existing Caden geometry, roads, buildings, exits, collision, camera limits, and gameplay contracts remain authoritative unless a separate approval explicitly changes them.

