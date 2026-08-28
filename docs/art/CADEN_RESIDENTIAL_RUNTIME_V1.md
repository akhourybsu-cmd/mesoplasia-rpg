# Caden Residential Runtime v1

## Scope

Residential Runtime v1 is the limited in-engine implementation authorized after the Residential reconstruction gate. It modifies only `res://scenes/world/caden/Residential.tscn` and Residential-owned runtime art. Commons and all other Caden zones remain outside this pass.

## Selected source art

The source archive remains staged outside `res://`. Only approved candidates `01`, `04`, `05`, `06`, `08`, `09`, and `11` are imported as cleaned runtime PNGs. Each source is verified against the complete 222-row Caden Mega Asset Library v1.1 manifest, normalized at exact `0.1875` nearest-neighbor scale, cleaned to hard alpha, and imported at scale `1.0`.

The imported pieces provide a fenced flower yard, wood storage, laundry line, small garden, doorstep flowers, rain-barrel storage, and stepping-stone garden path. The 24 rejected Residential and townwide building masters remain rejected for unsuitable baked shadows. The ten home exteriors reuse already approved Caden Town Square runtime v2 building art.

## Composition and alignment

All ten authoritative home centers and `128 x 96` collision bodies remain unchanged. Their exterior sprites use the same local ground alignment. The three authoritative yard-fence centers and `192 x 24` collision bodies also remain unchanged, with approved fence art aligned symmetrically across each body.

Domestic set pieces are grouped at thresholds, fence lines, and private work yards rather than scattered through circulation space. Twelve perimeter trees and sixteen low plantings frame the outer grass. Four lanterns mark household lanes. The west-east road, south Commons branch, four household lanes, both entries, and both exits remain clear.

## Population

The two existing interactive residents retain their identity, position, facing, dialogue, and interaction behavior. Their placeholders are replaced with existing approved Caden character visuals. Five additional non-interactive neighbors use the established `PatrolNpc` component on short bounded horizontal routes, producing seven visible NPCs without adding dialogue, lore, persistence, or new gameplay systems.

## Collision and sorting

Selected set pieces use structural bottom-center pivots and object-specific collision. Laundry posts and doorstep planters collide independently while their centers remain passable. Stepping stones have no collision. Gardens and storage pieces collide only at their structural bases. Trees collide only at the trunk and set pieces use player-relative depth sorting.

## Visual gate

`render_caden_residential_runtime_v1.gd` captures native full-zone and `640 x 360` route and household views, two front/behind overlap pairs, and exact `1280 x 720` nearest-neighbor proof. `build_caden_residential_runtime_review_v1.py` combines these with the untouched baseline in a checksum-verified external package. Residential Runtime v1 received visual approval on 2026-08-27, authorizing progression to the Commons reconstruction gate. That approval does not authorize a Commons asset shortlist or runtime integration.

## Provenance

Source rights remain `project_internal_rights_unverified`. Runtime assets and review materials must not be published until rights are independently confirmed.
