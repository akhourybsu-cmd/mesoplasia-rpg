# Repository Evolution Plan

## Principle

Do not mass-move or rename the current project. Add new boundaries when their implementation phase begins, adapt current scenes/scripts, and retire legacy paths only after equivalent behavior and tests exist. The structure below is a direction, not an instruction to create empty directories.

## Current-to-future mapping

| Current path | Current responsibility | Incremental target |
| --- | --- | --- |
| `scenes/Main.tscn` | direct Caden entry | eventually `scenes/app/ApplicationRoot.tscn`; Main may remain a compatibility entry during migration |
| `scenes/world/caden/Caden.tscn` | one Player, one zone, one objective/UI | presentation adapter under future `scenes/hub/`; authoritative hub state is not stored in this scene |
| five Caden zone scenes | authored zone presentation/collision/NPC placements | retain in place initially; future `scenes/hub/caden/` only through deliberate low-risk moves, not required |
| `scenes/Player.tscn` | local avatar plus camera/UI/input | retain and parameterize first; later reusable avatar in `scenes/players/` with local presentation attachment |
| `scenes/npcs/*` | stationary/patrol runtime and visuals | presentation adapters; stable definition/placement IDs; server NPC state in domain scripts |
| `scripts/player.gd` | input, movement, camera/UI/dialogue coupling | small input source, avatar presenter, and movement adapter in future `scripts/client/players/`/`scripts/hub/` |
| `scripts/world/caden.gd` | zone content registry, load/unload, teleport/camera | client hub presenter plus server hub/zone services; preserve local adapter until networked Caden passes |
| `scripts/world/world_zone.gd`, `zone_exit.gd` | bounds/entry and direct local transition signal | content/scene adapters for stable zone/entry/exit IDs and transition commands |
| `scripts/interaction/*` | local node candidate and direct call | local target presenter plus server interaction validator/service |
| `scripts/dialogue/*`, `data/dialogue/*` | linear definition Resources | retain definitions; add registry IDs and scoped runtime sessions under quest/narrative domain |
| `scripts/objectives/*`, `data/objectives/*` | definition + one local tracker | retain definitions; add scoped progress service/state; UI subscribes to local projection |
| `scripts/ui/*`, `ui/*` | reusable local CanvasLayers | future `LocalUIRoot`; remain client-only and largely unchanged visually |
| `scripts/visuals/*` | local character presentation | remain client presentation; never imported by pure server rules |
| empty `systems/` | reserved managers | do not fill with global singletons; prefer explicit `scripts/domain`, `server`, `client` modules |
| `tests/*.gd` | headless scene/art/runtime regressions | preserve; add focused subdirectories only when tests grow |
| `data/` | dialogue/objective Resources | expand by approved definition family, with manifest validation |
| art manifests/tools/docs | deterministic visual pipeline | preserve; networking architecture must not destabilize protected asset contracts |

## Incremental target structure

Create only folders needed by the active phase:

```text
docs/
└── architecture/                    # this package

scenes/
├── app/                             # composition root, later
├── network/                         # stable protocol gateways/sandboxes
├── hub/                             # new hub adapters; current zones may remain under world/caden
├── expeditions/
├── dungeons/
├── combat/
├── players/
├── npcs/
└── ui/                              # only if consolidation is later justified

scripts/
├── core/                            # IDs, clocks, results, versions
├── domain/
│   ├── identity/
│   ├── parties/
│   ├── expeditions/
│   ├── dungeons/
│   ├── combat/
│   ├── inventory/
│   └── quests/
├── network/                         # schemas, gateway, transport adapters
├── server/                          # composition and authoritative coordinators
├── client/                          # state stores/presentation adapters/input
├── persistence/
└── content/

data/
├── abilities/
├── items/
├── statuses/
├── enemies/
├── encounters/
├── dungeons/
├── quests/
└── dialogue/                        # existing content stays; namespace incrementally

tests/
├── unit/
├── integration/
├── multiplayer/
├── combat/
├── persistence/
└── migration/

tools/
├── server/
├── content_validation/
└── test_harness/
```

## Dependency direction

```text
presentation/scenes -> client adapters -> protocol/domain interfaces
server adapters -> domain services -> core types/interfaces
persistence/content/network concrete adapters -> domain interfaces
domain services -X-> scenes/UI/Camera/ENet/files
```

Godot Resources used as definitions are converted to immutable domain views at the registry boundary where helpful. Pure domain tests should not require loading production scenes.

## Staging rules

- Add typed stable ID/core result types before a domain needs them; avoid a speculative framework.
- Add a service interface and local adapter before replacing direct behavior.
- Keep `Main.tscn`, Caden, Player, and legacy tests intact through neutral/multi-avatar sandboxes.
- Add network gateway nodes at stable paths; never scatter RPC annotations across content scenes.
- Keep generated/imported art files and `.godot/` outside architecture refactors.
- No autoload, dependency, database, export preset, or renderer change without explicit approval.

## Documentation evolution

When implementation begins, create individual ADR files only after decisions are accepted; update this package/register with acceptance date/supersession links. Update `PROJECT_STRUCTURE.md` when directories actually exist, not when merely proposed. Every implementation phase appends the running changelog as required by repository rules.
