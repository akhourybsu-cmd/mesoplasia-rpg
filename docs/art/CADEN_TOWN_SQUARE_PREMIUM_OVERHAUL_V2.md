# Caden Town Square Premium Overhaul v2

## Outcome

Town Square now uses five Architecture Runtime v2 exteriors, eight production-ready NPC variant atlases, two fully illustrated interactive NPCs, and three bounded ambient patrols. The overhaul keeps the existing `960×704` zone, four exits, entry markers, building centers, building collisions, reserved community space, Terrebonne closure, dialogue data, objectives, and Compatibility renderer unchanged.

The final in-engine composition is captured at:

`docs/art/previews/caden_town_square_runtime_v2_gameplay_preview.png`

## Architecture Runtime v2

The v1.1 façades, foundations, doors, porches, shadows, canvas sizes, `(0,-16)` sprite anchors, scene centers, and collision rectangles remain the protected structural base. Runtime v2 replaces only the roof/eave presentation with one continuous source-palette shingle field per building.

- Staggered short shingle joints replace the repeated full-height roof divisions.
- Ridge, gable, chimney, eave, and façade join are drawn as integrated pieces.
- Every roof/façade scan region is fully opaque.
- Output retains binary alpha and exact existing canvases.
- No building gains a name, use, occupant, sign, door interaction, script, or new collision.

Runtime assets and hashes are recorded in:

`assets/environments/caden/architecture/town_square/caden_architecture_runtime_v2_manifest.json`

Rebuild with:

```powershell
python tools/art/prepare_caden_architecture_runtime_v2.py
```

The tool refuses to run if the immutable architecture source or any Runtime v1.1 input hash changes. It writes five `_v2.png` assets plus lineup, v1.1/v2 comparison, and Town Square placement previews.

The image-generated concept at `docs/art/previews/caden_town_square_premium_overhaul_concept_v2.png` was used only for visual direction: coherent massing, connected construction, clean entrances, and an open plaza. It is not imported by the game and introduced no lore or runtime dependency.

## Scene presentation cleanup

`DevelopmentLabels` remains in its established scene path for technical rollback and review, but its root is hidden in the finished presentation. This removes the zone, plaza, reserved-space, and closure copy from the game view without deleting technical nodes.

The visually merged frontage clusters were redistributed while retaining support and clearance rules:

| Prop | Final base |
| --- | ---: |
| Southwest barrel | `(80,592)` |
| Southwest storage cluster | `(192,592)` |
| Southwest ground lantern | `(256,592)` |
| Southeast travel pack | `(704,528)` |
| Southeast sacks | `(752,592)` |

Full sprite canvases within each cluster no longer intersect. Principal 128-pixel routes, entry clearances, NPC approaches, building collisions, and the reserved space remain clear.

## NPC variant runtime contract

The eight audited transparent v2 masters under `assets/source_art/caden/characters/npc/variants/` are immutable inputs. The runtime preparation tool generates one `160×224` RGBA atlas and one `SpriteFrames` resource per variant under `assets/characters/caden/npc/variants/<variant_id>/`.

- Grid: four columns by four rows.
- Frame: `40×56`.
- Rows: down, left, right, up.
- Columns: neutral, step A, passing, step B.
- Alpha: binary.
- Normalization: one shared scale per character, nearest-neighbor only, horizontal centering, feet aligned to row 55.
- Animations: `idle_down`, `idle_left`, `idle_right`, `idle_up`, `walk_down`, `walk_left`, `walk_right`, `walk_up`.
- Idle animations: one frame, non-looping.
- Walk animations: four frames, looping, 8 FPS.

The descriptive variant IDs remain asset identifiers only; this pass assigns no canon names, occupations, relationships, ownership, or narrative facts.

Manifest and visual audit:

- `assets/characters/caden/npc/variants/caden_npc_variants_runtime_v1_manifest.json`
- `docs/art/previews/caden_npc_variants_runtime_v1_lineup.png`

Rebuild with:

```powershell
python tools/art/prepare_caden_npc_variants_runtime_v1.py
```

## Patrol behavior and population

`PatrolNpc.tscn` is a reusable `CharacterBody2D` component in the `ambient_npcs` group. It is intentionally not in the interactive `npcs` group, so population/dialogue systems still see exactly the original two Town Square conversation NPCs.

Each patrol is configured by data: horizontal or vertical axis, total lane distance, movement speed, pause duration, and initial direction. Patrols use collision-aware `move_and_slide()`, reverse at lane ends or collisions, play authored directional walk cycles while moving, and show `idle_down` while paused when `face_forward_while_idle` is enabled. No navigation agent, schedule manager, registry, random movement, autoload, or narrative data was added.

| Instance | Center | Axis | Lane distance | Speed | Runtime variant |
| --- | ---: | --- | ---: | ---: | --- |
| `NorthPlazaWalker` | `(160,272)` | left/right | 64 px | 20 px/s | half-elf young nonbinary 01 |
| `WestPlazaWalker` | `(752,352)` | up/down | 96 px | 22 px/s | dwarf middle woman 01 |
| `SouthPlazaWalker` | `(656,496)` | left/right | 64 px | 24 px/s | elf younger man 01 |

`PassingVisitor` uses the prepared human young woman variant and retains its left-facing idle, dialogue resource, collision, interaction prompt, and scene path. The later full-map composition pass moves it to `(352,448)` opposite `SquareLocal`; `SquareLocal` remains at `(288,448)` with the approved base runtime and all existing behavior. The same pass moves the three ambient lanes to the activity anchors listed above without changing their reusable patrol component.

`Actors/NPCs` enables Y-sort, and all five NPC instances share the existing world z-index 10. Stationary NPC movement remains prohibited; ambient movement is isolated in `patrol_npc.gd`.

## Validation

The following checks pass in Godot 4.7.2:

- Architecture v1 compatibility and Runtime v2 integration.
- Continuous binary-alpha roofs and opaque façade joins.
- Locked building centers, sprite anchors, collisions, routes, entries, and exits.
- Environmental counts, clearances, support, collision gaps, festival restraint, and non-overlapping frontage clusters.
- All eight variant manifests, atlases, frames, hashes, animations, and binary-alpha sheets.
- Forward-idle and horizontal movement behavior for the reusable patrol component.
- Three Town Square patrol axes, prepared visuals, and ambient-only grouping.
- Interactive population remains exactly two; dialogue uniqueness and zone-unload behavior remain intact.
- SquareLocal and PassingVisitor visuals, interactions, dialogue, facing, and reload behavior.
- Zone transitions, persistent Player, camera limits, nature, props, and Festival/Edenite integration.

Automated checks establish technical integrity. The retained gameplay preview records the final actual-engine composition for visual review.
