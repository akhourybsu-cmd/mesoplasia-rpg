# Caden Residential Building Pilot v1.1

## Decision state

The ten-house Residential pilot was visually approved by user continuation on 2026-08-29 and is the approved Residential building runtime. The approval evidence is `caden_residential_building_pilot_review_v1_1.zip` with SHA-256 `9d404ee67929fb5bade7815014c62b9a6ebc8704b08f6a65ba34fe5bf1bc3363`.

This approval does not authorize terrain replacement, additional building integration, or changes to another Caden zone. The next documented phase is an inactive Residential-only terrain comparison.

## Implemented scope

- Imported only the ten approved Gate 0 runtime PNGs from the external, checksummed package.
- Assigned one distinct source-faithful exterior to each existing `Homes/Cabin01` through `Homes/Cabin10` anchor.
- Kept every Cabin `StaticBody2D` center and `128 x 96` collision footprint unchanged.
- Used recorded bottom-center structural contacts and integer sprite offsets so every foundation lands on local `y = 48` at import scale `1.0`.
- Retained the approved Residential terrain, roads, exits, entry markers, landscaping, NPC population, dialogue, and all other zone contracts.
- Moved the existing LaundryLine and SmallGardenPatch one `32 px` tile north on grass to clear the taller south roofs. Their selected assets, object-specific collision shapes, and player-relative depth behavior remain intact.

## Source and runtime integrity

The importer verifies all 47 Gate 0 package checksums, the 88-row catalog state, the exact ten-candidate assignment set, and every candidate SHA-256 before copying. Each imported PNG is re-audited for binary alpha, transparent RGB residue, and canvas-edge pixels. The runtime manifest records source crop, source and runtime hashes, scale family, normalization factor, dimensions, pivot, footprint, target node, status, intended placement, and the prior texture and offset needed for rollback.

The source masters and complete Gate 0 package remain outside `res://`. Rights remain `project_internal_rights_unverified`; do not publish or ship these derivatives until the creator, license, and derivative permission are documented.

## Visual gate

The external review package contains four matched before/pilot views, five active route and overlap checks, an exact nearest-neighbor `1280 x 720` presentation proof, tooling copies and hashes, manifests, provenance, approval checklist, and package checksums.

The comparison was approved. Retain the package as the decision evidence for the active Residential building runtime.

## Rollback

Restore the prior Town Square texture recorded for each Cabin and return each `ExteriorSprite` to `Vector2(0, -16)`. Return LaundryLine to `Vector2(400, 536)` and SmallGardenPatch to `Vector2(752, 536)`. Remove only the v1.1 building manifest and ten runtime PNGs after confirming that no active reference remains.
