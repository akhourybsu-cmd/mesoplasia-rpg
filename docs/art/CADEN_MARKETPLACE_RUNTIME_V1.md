# Caden Marketplace Runtime v1

## Scope

Marketplace Runtime v1 is the limited in-engine implementation authorized by the Marketplace reconstruction gate. It modifies only `res://scenes/world/caden/Marketplace.tscn` and Marketplace-owned runtime art. No later Caden zone and no unselected library candidate is integrated.

## Selected assets

The approved source archive remains staged outside `res://`. Only seven cleaned runtime PNGs are imported:

- `01` produce crate display
- `03` folded cloth display
- `04` pottery and jars display
- `06` barrel and sack backstock
- `07` mixed-goods vendor counter, instantiated twice as the paired district anchors
- `13` neutral crate and barrel storage
- `14` shopfront supply cluster

Each source hash is verified against the 222-row Caden Mega Asset Library v1.1 manifest. `prepare_caden_marketplace_runtime_v1.py` crops to the catalog alpha bounds, applies exact `0.1875` nearest-neighbor normalization, pads the image, removes the broad right/bottom presentation shadow, converts alpha to a hard pixel mask, cleans bright boundary fringe, removes tiny fragments, sanitizes transparent RGB, and writes the final PNG at scale `1.0`.

The runtime manifest records source and runtime hashes, source bounds, scale family, target dimensions, structural pivot, collision footprint, scene placement, cleanup counts, post-clean audit, approval state, and provenance status.

## Terrain and composition

`build_caden_marketplace_terrain_v1.py` composes the complete `896 x 640` ground from exact `32 x 32` cells in the protected Caden Terrain Runtime v1.1 atlas. It creates one continuous maintained-stone vendor court inside the preserved grass frame and retains the authoritative west, cross, and central earth lanes. It introduces no collision and no resampling.

The eight original vendor-bay centers remain in their northwest, northeast, southwest, and southeast pairs. Merchandise fronts and primary counters occupy the north districts; the south districts combine a second vendor anchor with backstock and service clusters. Sixteen approved repository trees now overlap as full perimeter masses with every structural ground contact in the outer grass. Shrub understory layers soften their bases. A continuous structural fence follows the grass side of the market edge, closes the north service and east cross-lane ends, and leaves deliberate openings only for the west Wayfarer's Approach and south Town Square routes.

## Pivots, collision, and sorting

All selected assets use bottom-center pivots from catalog structural ground contact. Collision represents only the solid counter, crates, barrels, or storage base, using `48 x 16`, `56 x 16`, or `64 x 24` rectangles rather than composite canvas bounds.

Vendor props, trees, planters, and lanterns use `depth_sorted_static_prop.gd`. They render behind a player below their ground contact and in front of a player above it. Tree collision covers the trunk only; planter and lantern collision covers the physical base only. Fence collision follows its narrow rail line instead of blocking the planting bed. Shrubs remain decorative and non-colliding.

## Preserved gameplay contract

- `896 x 640` camera and zone bounds
- West Wayfarer's Approach transition and `(128,320)` arrival marker
- South Town Square transition and `(448,512)` arrival marker
- West, cross, and central circulation corridors
- Eight authoritative vendor-bay centers
- Stall attendant, market shopper, and supply traveler identities, positions, dialogue resources, interactions, and facing
- Existing collision layers, boundary bodies, input, player, UI, save assumptions, and world transition behavior

The three interactive NPC placeholder polygons are replaced by existing approved Caden character visuals without changing their behavior. Four non-interactive Caden ambient shoppers use the established bounded `PatrolNpc` component in the northwest, northeast, southwest, and southeast customer aisles. They add no dialogue, vendor identity, sign, lore, mechanic, or persistence contract.

## Visual gate

`render_caden_marketplace_runtime_v1.gd` captures the live scene at native full-zone and `640 x 360` gameplay resolutions, including matched routes, district views, vendor and tree overlap pairs, and exact `1280 x 720` nearest-neighbor proof. The current landscaped-perimeter iteration is rendered outside `res://` under `caden_marketplace_lively_perimeter_review_v2`; it retains the original selective-asset baseline and adds no library candidate.

Marketplace Runtime v1, including the lively perimeter refinement, received visual approval on 2026-08-27. That approval authorizes continuation of the ordered five-zone workflow; it does not authorize another Marketplace alternate, deferred, rejected, seam, Festival, or mega-set asset.

## Provenance

The prior `project_internal_rights_unverified` status is superseded by `assets/environments/caden/marketplace/caden_marketplace_source_rights_v1.json`. The selected runtime derivatives are `openai_output_provenance_verified` and may be distributed with the Mesoplasia RPG project subject to applicable law and third-party rights. See `CADEN_MARKETPLACE_PROVENANCE_AND_RIGHTS_V1.md` for the evidence chain and disclosed archival limitations.
