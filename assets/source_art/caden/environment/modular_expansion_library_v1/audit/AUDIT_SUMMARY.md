# Source-Master Audit Summary

Audit date: 2026-08-29

## Result

All five selected source masters decode and retain RGBA channels, but **none is runtime-approved**.

| Source master | Size | RGBA | Occupied outer-edge alpha pixels | High-saturation red pixels | High-saturation yellow pixels | Status |
|---|---:|---:|---:|---:|---:|---|
| Architectural add-ons | 1312×1199 | Yes | 32 | 6,755 | 3,566 | Cleanup required |
| Connected compositions | 1312×1199 | Yes | 304 | 9,813 | 18,128 | Cleanup required |
| Fences and boundaries | 1312×1199 | Yes | 338 | 10,177 | 4,663 | Cleanup required |
| Landscaping | 1312×1199 | Yes | 493 | 3,225 | 4,082 | Cleanup required |
| Yard furnishings | 1312×1199 | Yes | 309 | 6,131 | 3,260 | Cleanup required |

The color counts are screening metrics, not automatic deletion masks. Some legitimate asset colors fall near these ranges; cleanup must distinguish intentional art from saturated boundary contamination.

## Known defects

- Saturated red and yellow fringe/remnant pixels appear around multiple silhouettes and ground-contact regions.
- Every sheet has at least some visible alpha on the outer canvas edge.
- The generated foregrounds contain extensive partial-alpha pixels and require native-pixel inspection before alpha quantization.
- Some connected compositions include baked terrain pockets; retain them only when they join the selected runtime ground cleanly.
- Exact fence lengths and seam joins are design references until rebuilt or normalized against the 32×32 runtime grid.
- Composite pieces may require separation for player overlap, collision, and Y-sorting.

## Rejected attempts

- One cleanup pass removed much of the fringe but flattened transparency into a visible checkerboard.
- One restricted-palette regeneration still produced colored boundary contamination; its architectural sheet also introduced a nontransparent presentation background.
- Those drafts are excluded from the deliverable.

## Acceptance gate for extracted assets

An extracted runtime asset must fail if it has a visible sheet remnant, checker pattern, guide line, detached fragment, colored halo, edge-touching pixel, broad baked shadow, clipped silhouette, blurred edge, or incorrect scale. Passing candidates must use clean alpha, nearest-neighbor normalization, a documented pivot, explicit collision guidance, intended zone/placement, and a 640×360 in-engine comparison.

