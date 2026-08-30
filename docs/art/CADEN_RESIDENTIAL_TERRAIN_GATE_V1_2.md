# Caden Residential Terrain Gate v1.2

## Decision state

This inactive Residential-only comparison was approved on 2026-08-29 for a limited active pilot. Its decision evidence remains immutable in the external review package. The active implementation and current visual gate are documented in `CADEN_RESIDENTIAL_TERRAIN_RUNTIME_V1_2.md`.

The approval authorized only the limited Residential terrain pilot. It did not authorize Marketplace, Commons, Town Square, Wayfarer's Approach, collision, route, or broad five-zone terrain changes.

## Candidate construction

- Verified all 47 Gate 0 package checksums and the 88-row source catalog state.
- Reused the Gate 0 atlas's exact source-derived `32 x 32` cells without spatial resampling.
- Retained nine grass variants, nine warm-stone variants, and eight grass/stone transition cells.
- Rejected the initial Gate 0 presentation for its yellow cast, high local contrast, and visible repetition.
- Harmonized grass to the current Residential grass mean at `0.32` local contrast and warm stone toward the current route palette at `0.58` local contrast.
- Distributed variants with a deterministic coordinate hash and composed the exact existing `36 x 24` road mask from the approved terrain manifest.
- Kept collision separate; the candidate adds no collision data.

The final inactive candidate is `1152 x 768` with SHA-256 `828cfd64940b9bdd37fca40bac4d5a091432955d16f8e47b9701bef2028a98a0`.

## Visual evidence

The Compatibility renderer instantiates the live approved Residential scene and swaps only the transient `TerrainRuntime` texture in candidate instances. Six matched current/candidate pairs cover the full zone, north homes, south homes, primary route and Player, west arrival, and Commons transition. A separate `1280 x 720` candidate frame is an exact nearest-neighbor enlargement of its `640 x 360` source.

The comparison makes the design tradeoff explicit: warm stone creates a maintained, cohesive Residential route language that better matches the approved architecture, but reads more formal than the current dirt. That visual decision remains with the user.

## Integrity and provenance

The package includes preparation and render manifests, the candidate atlas and composed preview, repetition and material audits, all raw captures, an approval checklist, copied/checksummed tools, provenance/licensing notes, and `SHA256SUMS.txt`. It contains no master source, `.godot`, `.import`, `.uid`, `__pycache__`, hidden OS artifact, or serialized scene derivative.

Rights remain `project_internal_rights_unverified`; do not publish or ship the derivative until creator, license, and derivative-use permission are documented.

The review ZIP SHA-256 is `d6479402e753b782aaf299a3b7db823af11b13bd673e85d989f6190aac4571e8`.

## Approval options

1. Accept for a limited Residential terrain pilot.
2. Request targeted palette, contrast, repetition, or route-edge corrections.
3. Retain the current Residential terrain.

Decision recorded: `ACCEPT LIMITED RESIDENTIAL PILOT`. Continue only through the separate active in-engine visual gate.
