# Current Repository Audit

## Audit basis

Read-only audit performed 2026-08-27 against the working tree, including unrelated in-progress Marketplace reconstruction. That work was present before this package and is not part of this architecture change.

## Existing runtime structure

| Concern | Current implementation | Migration consequence |
| --- | --- | --- |
| Startup | `project.godot` points to `scenes/Main.tscn`; `Main` directly instances `Caden.tscn`. | A future application composition root can replace the startup composition in a gated phase; do not change it during neutral refactors. |
| Caden controller | `scripts/world/caden.gd`; preloads five zone scenes, owns `$CurrentZone` and one fixed `$Player`. | Extract a zone/session interface before networking. Current controller is a good single-player adapter, not a server world model. |
| Zones | Wayfarer's Approach, Marketplace, Town Square, Residential, Commons. Only one zone scene is instantiated at a time. | Server must eventually track multiple zone memberships and may keep active zones loaded independently of one client camera. |
| Player | `CharacterBody2D`; input, movement, collision, facing, animation, camera, interaction detector, prompt, dialogue, and control locks are composed in one scene. | Split avatar simulation/input intent from local camera/UI presentation without discarding the reusable visual/collision work. |
| NPC foundation | `StationaryNpc` is a reusable `StaticBody2D` with optional frames, exported facing/conversation, and an `Interactable`; `PatrolNpc` owns local path motion. | Add stable NPC/instance IDs where persistent; server owns patrol and persistent interaction rules. Visual components remain client-side. |
| Interaction | Per-Player detector collects nearby `Area2D` candidates and directly emits interaction to the selected world node. | Retain client target selection as presentation; send an interact command containing stable target/zone IDs for server distance/state validation. |
| Dialogue | `DialogueConversation` Resource contains `speaker_id`, display name, and lines. NPC calls `Player.start_dialogue`; `DialogueUI` owns the active line/index. | Preserve resources as presentation content initially; move authoritative dialogue session/choice state into scoped server records. |
| Objectives | `ObjectiveDefinition` and steps are Resources. `ObjectiveTracker` holds one mutable step index under Caden and updates one `ObjectiveUI`. | Definition/state separation already begins well; add stable IDs, scoped progress records, server events, and per-local-player UI binding. |
| UI ownership | Prompt and dialogue are children of Player; objective UI is a child of Caden. All are `CanvasLayer`s. | Move all local UI under `LocalUIRoot`; bind it to the locally controlled character, never replicate it. |
| Scene transitions | `ZoneExit` emits destination names after any body in `player` group enters; Caden unloads the old zone, loads the next, teleports the one Player, and updates its camera. | Replace direct transition mutation with a request/authorization/transfer flow. Stable zone and entry IDs can retain current `StringName` values. |
| Camera | One enabled `Camera2D` child on Player; Caden pushes current zone bounds. | Client-only and locally enabled. Remote avatars and dedicated servers have no camera. |
| Player persistence | The Player node persists only while Caden replaces zones; there is no disk persistence or identity record. | Do not confuse scene persistence with account/character persistence. |
| Content data | Dialogue `.tres` files and one objective `.tres`; art/runtime manifests are JSON. | Add registry validation and namespaced stable IDs; do not mutate shared Resource definitions as runtime state. |
| Tests | Script-driven headless tests cover project settings, zones, Player persistence/camera, interaction, dialogue, objective, population, and extensive art/runtime contracts. | Preserve these as regression tests; add pure domain and multi-avatar/network harnesses rather than replacing them. |
| Autoloads | No `[autoload]` section in `project.godot`. | Keep it that way initially; use a scene-root composition. |
| Input | `move_up/down/left/right`, `interact`, `attack`, `secondary_action`, and `pause`. | Input actions remain local; future input commands carry intent, sequence, and client tick. |
| Save code | None found. `FileAccess` usage is test/tool asset validation, not gameplay persistence. | Introduce repository interfaces before any backend. |
| Network code | No RPC, `MultiplayerAPI`, `ENetMultiplayerPeer`, peer mapping, or replication code found. | First network milestone should be an isolated sandbox. |

## Zone graph

| Zone | Bounds | Entries | Connections |
| --- | ---: | --- | --- |
| Wayfarer's Approach | 1024x640 | arrival, from Town Square, from Marketplace | Town Square, Marketplace |
| Marketplace | 896x640 | from Wayfarer's Approach, from Town Square | Wayfarer's Approach, Town Square |
| Town Square | 960x704 | from all four neighbors | all four neighbors; Terrebonne route remains blocked |
| Residential | 1152x768 | from Town Square, from Commons | Town Square, Commons |
| Commons | 1024x704 | from Town Square, from Residential | Town Square, Residential |

`ZONE_SCENES`, starting zone, and starting entry are hard-coded in `caden.gd`, but they are content composition rather than persistent IDs.

## Meaningful one-Player assumptions

| Location | Assumption | Risk | Migration seam |
| --- | --- | --- | --- |
| `Caden.tscn` / `caden.gd` | Exactly one named child `$Player`; one `_player`; one position and camera update. | Cannot represent several players or clients in different zones. | Introduce avatar registry keyed by `CharacterId`; preserve current Player through a local-session adapter. |
| `caden.gd` | Exactly one `_current_zone`; loading a destination unloads it for everyone. | One player moving would replace the world for all players. | Server zone-instance registry plus client presentation loader. |
| `ZoneExit` | Any body in group `player` triggers one unqualified transition. | No sender, character, source-zone, rate, or authority validation. | Emit local intent with avatar/exit ID; server validates and returns transfer snapshot. |
| `Player.tscn` | Camera, InteractionPrompt, and DialogueUI exist on every avatar and camera is enabled. | Remote avatars would create cameras and duplicate local UI. | Avatar scene with optional local presentation attachment; one `LocalUIRoot`. |
| `player.gd` | Reads global Input directly and immediately mutates authoritative position. | Client and server responsibilities are inseparable. | Input source -> movement intent -> simulation adapter -> presentation correction. |
| `InteractionDetector` | Candidate node reference is trusted and `interact()` is called locally. | Node identity/path cannot cross network or be trusted. | Stable `InteractableId`, server range/zone/state validation. |
| `DialogueUI` | UI owns conversation, line index, and active state. | Reconnect and scoped choices cannot be reconstructed authoritatively. | Server `DialogueSessionState`; UI displays a snapshot/event stream. |
| `ObjectiveTracker` | One step index for the Caden scene; UI connected directly. | No player/party/world scope and no persistence. | Definition + scoped `QuestProgress`, server event to local UI projection. |
| `DepthSortedStaticProp` | Uses `get_first_node_in_group("player")`. | Sort result is arbitrary with multiple avatars. | Client-local depth policy using relevant rendered actors/Y-sort; never server domain logic. |
| Stationary NPC | Calls a method on the interactor and allows concurrency implicitly. | No NPC/dialogue scope, lock, or world-state validation. | Scope-aware dialogue policy; ordinary NPCs remain concurrently presentable. |
| Patrol NPC | Simulates movement in every scene process. | Diverges across clients and has no stable runtime identity. | Server AI/movement state; clients render snapshots. |
| Tests | Many fetch `caden.get_node("Player")`, assert the instance stays unique, or preload a single Player. | Regression suite encodes current behavior as the only behavior. | Keep tests for legacy adapter; add multi-avatar tests before changing assertions. |

## State/presentation mixing

- Player input, movement state, facing, control locks, camera, visual animation, interaction targeting, and dialogue launch share one script/scene boundary.
- `DialogueUI` owns mutable dialogue progression.
- `ObjectiveTracker` is separated from its UI but remains scene-local and unscoped.
- Patrol simulation and visuals share `PatrolNpc`.
- Zone controller owns content lookup, scene lifecycle, Player teleport, camera bounds, and transition locking.

These are migration targets, not reasons for a rewrite. Directional visuals, data Resources, signals, zone entry markers, collision geometry, and existing tests are valuable seams to preserve.

## Client-only, server-owned, and shared targets

| Remain client-only | Become server-owned | Shared deterministic/data boundary |
| --- | --- | --- |
| Camera2D, CanvasLayer UI, input device mapping, prompts, animation, audio, effects, interpolation | identity mapping, authoritative movement/zone, NPC state, party, expedition, combat, inventory, rewards, quest progress, RNG, saves | immutable definitions, validation rules, command/event schemas, pure domain calculations, stable IDs |

## Stable-ID and Resource risks

- Dialogue has `speaker_id` and objectives have `objective_id`/`step_id`, but no repository-wide uniqueness or manifest validation exists.
- Zones and entries use string names; these can become explicit stable content IDs if registered and validated.
- Player, avatar, party, expedition, combat, inventory item instance, reward, and save identities do not exist.
- Scene node names, paths, group-first lookup, and instance IDs are currently usable only inside one process.
- Current `.tres` definitions appear immutable at runtime; future code must avoid storing mutable progress back into shared Resource instances.

## Existing architecture to preserve

- Godot 4.7, GDScript, Compatibility renderer, 640x360 internal viewport, 32x32 world grid, and named inputs.
- Caden's five authored zones, connections, entry points, collision, art, NPC presentation, and Terrebonne closure.
- Player visual/collision contract and four-direction movement feel during neutral refactoring.
- Resource-based dialogue/objective definitions and signal-driven UI updates as adaptation points.
- No-autoload baseline, data/content separation, local components, and headless script tests.

## Inspected repository material

The audit inspected:

- `AGENTS.md`, `project.godot`, `docs/TECHNICAL_STANDARDS.md`, `docs/CADEN_VERTICAL_SLICE.md`, `docs/PROJECT_STRUCTURE.md`, and existing changelog headings;
- all current Markdown documentation under `docs/art/` covering architecture, terrain, nature, props, Wayfarer's Approach, Town Square, Marketplace gate, Edenite/Festival, character, NPC, Player, and UI runtime contracts;
- all scripts under `scripts/`, all production scenes under `scenes/`, all UI scenes, dialogue/objective data Resources, and all tests under `tests/`;
- the current repository tree and pre-existing working-tree changes.

Large art binaries, generated previews, `.import` files, and `.godot/` cache were not visually or semantically audited because they do not own gameplay architecture. Existing art documentation and runtime manifests were used for their contracts.

## Unknown or unverified facts

- No final maximum connected-player count, party size, simultaneous-party rule, combat spatial model, loot rule, or narrative vote rule is approved.
- No gameplay persistence format exists to inspect.
- No export presets exist in the audited file list; dedicated-server export configuration remains future work.
- Direct-IP reachability, router behavior, firewall rules, and host hardware have not been tested.
- The in-progress Marketplace reconstruction was not validated or modified by this task.
