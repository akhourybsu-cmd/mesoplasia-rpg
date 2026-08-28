# Caden Commons Runtime v1

## Scope

Commons Runtime v1 is the limited in-engine implementation authorized after the Commons reconstruction gate. It modifies only `res://scenes/world/caden/Commons.tscn` and Commons-owned runtime art. Every other Caden zone remains unchanged.

## Selected source art

The source archive remains staged outside `res://`. Only approved candidates `01`, `04`, `09`, `11`, `14`, and `20` are imported as cleaned runtime PNGs. Each source is verified against the complete 222-row Caden Mega Asset Library v1.1 manifest, normalized at exact `0.1875` nearest-neighbor scale, cleaned to hard alpha, and imported at scale `1.0`.

The selected set supplies one shade-tree anchor, one maintained grove, one walkable wildflower meadow, one rock-and-shrub mass, one dense boundary edge, and one quiet bench pocket. Both Residential/Commons seams remain rejected, and all alternate, deferred, Town Square seam, shelter, and mega sources remain outside the repository.

## Composition

The eastern Quiet Green remains the dominant anchor through open, walkable negative space rather than a structure. The selected grove occupies the fixed northwest tree center. The selected shade tree occupies the fixed northeast center. An approved existing Caden tree retains the fixed southeast tree center. The selected rock mass replaces the southwest rock placeholder. One meadow and one bench pocket connect the Quiet Green to the route edge without entering either protected approach.

Sixteen approved repository trees and seventeen low shrubs layer the north, west, east, and south boundaries while preserving the Town Square and Residential openings. Density is concentrated at scene limits and natural anchors, leaving the central grass and both routes legible.

## Population

`CommonsLocal` retains position, facing, identity, dialogue, and interaction behavior while receiving an approved character visual. Two non-interactive residents use the established `PatrolNpc` component on short bounded routes, producing three visible NPCs without new dialogue, lore, persistence, or gameplay systems.

## Collision and sorting

The three authored tree centers and rock center remain unchanged. Placeholder `96 x 96` canopy collisions are replaced with precise trunk shapes: three small trunk shapes for the grove and one `24 x 18` trunk shape for each individual tree. The rock cluster uses a `40 x 20` central rock base. The meadow remains non-colliding. The rest pocket uses separate bench and rock shapes; boundary undergrowth collides only at its structural fence-and-rock base.

Selected solids and trees use player-relative depth sorting. The player renders in front below their structural contact and behind their canopy or upper mass when standing above it.

## Visual gate

`render_caden_commons_runtime_v1.gd` captures native full-zone and `640 x 360` route and landscape views, bench and tree front/behind pairs, and exact `1280 x 720` nearest-neighbor proof. `build_caden_commons_runtime_review_v1.py` combines these with the untouched baseline in a checksum-verified external package. Commons Runtime v1 remains pending in-engine visual approval.

## Provenance

Source rights remain `project_internal_rights_unverified`. Runtime assets and review materials must not be published until rights are independently confirmed.
