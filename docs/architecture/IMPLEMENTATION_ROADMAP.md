# Implementation Roadmap

## Roadmap diagram

```mermaid
flowchart LR
    A[A Neutral Refactor] --> B[B Multi-Avatar Sandbox]
    B --> C[C Network Sandbox]
    C --> D[D Networked Caden]
    D --> E[E Party]
    E --> F[F Expedition Instance]
    F --> G[G Offline Combat Domain]
    G --> H[H Networked Combat]
    H --> I[I Persistence]
    I --> J[J Dedicated Server]
```

Each arrow is a review/rollback checkpoint. Do not start the next phase automatically.

## Phase A — Multiplayer-neutral refactoring

| Field | Plan |
| --- | --- |
| Scope | Stable local `CharacterId`; explicit local-avatar role; separate input/camera/UI seams; avatar-qualified transition/interaction requests; local service interfaces; preserve exact behavior. |
| Likely files | `Player.tscn`, `player.gd`, `Caden.tscn`, `caden.gd`, interaction/zone adapters, new small core/client scripts, focused tests. |
| Forbidden | Networking/RPC, multiple live players in production Caden, autoload, persistence, combat, content redesign, art/collision/layout changes. |
| Automated tests | Full current suite; identity uniqueness; local adapter parity; no camera/UI duplication seam; transition request includes avatar/exit identity. |
| Manual validation | Existing Caden movement, camera, all transitions, interaction, dialogue, objective and visuals unchanged. |
| Completion gate | Same playable behavior; no direct global-input requirement in authoritative movement adapter; IDs never derive from node path/peer. |
| Rollback | Commit/checkpoint immediately before Phase A; changes are additive adapters and can be removed without data migration. |

## Phase B — Local multi-avatar sandbox

| Field | Plan |
| --- | --- |
| Scope | Development-only scene with two avatar instances; exactly one local input/camera/UI; remote-style presentation; avatar registry; per-avatar interaction/transition intent. |
| Likely files | new development scene, player/avatar configuration, integration tests; production Caden only if a neutral seam is necessary. |
| Forbidden | Sockets, persistence, production multi-player Caden migration, party/combat. |
| Automated tests | two avatars coexist; only local avatar reads input/owns Camera2D/CanvasLayers; no `get_first_node_in_group` ambiguity; stable IDs. |
| Manual validation | camera follows local avatar; both render/depth-sort; local interaction works; remote avatar cannot control UI/world. |
| Completion gate | Multi-avatar scene runs without duplicate input/UI/camera or node-name collisions. |
| Rollback | Remove development scene/adapter flags; Phase A single-player path remains. |

## Phase C — Network connection sandbox

| Field | Plan |
| --- | --- |
| Scope | Stable protocol gateway, ENet host/join, handshake, authentication placeholder suitable for private testing, peer/account mapping, two-client spawn/despawn in isolated scene. |
| Likely files | `scenes/network/`, `scripts/network/`, `scripts/server/session/`, sandbox scenes, multiplayer tests. |
| Forbidden | Migrating Caden, trusted client position, inventory/quest/persistence, public discovery/relay/platform SDK. |
| Automated tests | server + two clients; version rejection; peer replacement; malformed/rate/stale message; spawn/despawn; clean teardown. |
| Manual validation | LAN/loopback host and join, readable connection errors, listen-host local call behavior. |
| Completion gate | Server maps transient peers to stable test identities and clients cannot spawn/control another avatar. |
| Rollback | Network sandbox is isolated; production Main/Caden remains entry path. |

## Phase D — Networked Caden hub

| Field | Plan |
| --- | --- |
| Scope | Authoritative hub/zone/avatar state; one zone first then all five; movement snapshots; local/remote presentation; validated interaction/transfer; reconnect to Caden. |
| Likely files | server hub services, client state store/presenters, Caden/Player adapters, zone ID registry, network/integration tests. |
| Forbidden | Expedition/combat/inventory, full prediction if transitional movement is selected, Caden art/layout redesign. |
| Automated tests | two players same/different zones, transitions, interaction concurrency, server patrol state, join-in-progress, disconnect/reconnect, invalid movement/zone. |
| Manual validation | dedicated-like server and two clients traverse Caden; local UI/camera only; remote motion readable. |
| Completion gate | One player's zone change never unloads another's world; server position/zone wins; safe reconnect works. |
| Rollback | runtime mode can still launch legacy local Caden until networked parity is approved. |

## Phase E — Party system

| Field | Plan |
| --- | --- |
| Scope | Party aggregate, invites, accept/decline, leave/kick, leader, readiness, selected-expedition placeholder, revisions, disconnect grace. |
| Likely files | `scripts/domain/parties/`, server coordinator, protocol schemas, minimal client UI, tests. |
| Forbidden | Dungeon allocation, narrative policy finalization, matchmaking, guilds, permanent social history. |
| Automated tests | capacity/configuration, invite expiry, stale revisions, leadership transfer, readiness reset, disconnect/reconnect, unauthorized commands. |
| Manual validation | two clients form/leave/rejoin and see consistent state. |
| Completion gate | Party snapshot/events reconstruct state and no client directly edits membership/readiness. |
| Rollback | party records are ephemeral; disable feature and clear test parties safely. |

## Phase F — Expedition instance

| Field | Plan |
| --- | --- |
| Scope | One authored test dungeon, one party, unique IDs/seed, load barrier, same-room cohesion, checkpoint, success/retreat/failure, Caden return; no combat beyond a stub outcome trigger. |
| Likely files | expedition/dungeon definitions/services, authored test room scenes/data, client presenter, checkpoint interface stub, tests. |
| Forbidden | procedural generation, split-party multi-room, final rewards/combat, concurrent expedition production support. |
| Automated tests | state machines, eligibility, duplicate launch, load timeout, room links, checkpoint serialization, disconnect, return/cleanup. |
| Manual validation | party launches, explores real-time, completes/retreats, returns to correct Caden points. |
| Completion gate | Instance ID and state survive client scene reload; failure never strands a character or duplicates launch. |
| Rollback | close test instance, return characters to Caden, disable launch content; no durable player rewards yet. |

## Phase G — Offline combat domain

| Field | Plan |
| --- | --- |
| Scope | Pure turn-based records/services, target-based provisional spatial policy, initiative queue, deterministic RNG, minimal abilities/effects/AI fixtures, snapshots/events. |
| Likely files | `scripts/domain/combat/`, minimal test definitions, `tests/combat/`; optional development presenter only after domain passes. |
| Forbidden | Network RPC, production balance/canon, tactical grid unless approved, inventory/loot integration. |
| Automated tests | exhaustive validation/resolution/order/status/RNG/AI/timeout/snapshot fixtures. |
| Manual validation | optional developer combat viewer reflects events without owning state. |
| Completion gate | Same seed/state/intents yield same authoritative result; no scene/UI dependency. |
| Rollback | Pure additive module/data fixtures; expedition continues using stub encounter. |

## Phase H — Networked combat

| Field | Plan |
| --- | --- |
| Scope | Encounter-to-combat transition, reliable combat commands/events, dedicated presentation, reconnect snapshot/event window, timeout/disconnect fallback, dungeon outcome return. |
| Likely files | combat server/client adapters, protocol gateway schemas, combat scene/UI, expedition encounter adapter, multiplayer tests. |
| Forbidden | Client outcomes/RNG, final loot economy, alternate visual presentations, PvP. |
| Automated tests | two-client turns, invalid controller/target/revision, packet duplication, reconnect, timeout, AI, outcome once. |
| Manual validation | party enters combat, resolves/animates, reconnects, resumes exploration. |
| Completion gate | Server state remains correct under hostile/stale clients and presentation reload. |
| Rollback | disable encounter launch and restore expedition stub; no player rewards committed yet. |

## Phase I — Persistence

| Field | Plan |
| --- | --- |
| Scope | Repository interfaces, deterministic versioned files, atomic transactions, profiles/characters/world/inventory/quest, expedition/combat checkpoints, migrations/backups, idempotent rewards. |
| Likely files | `scripts/persistence/`, server data coordinators, save fixtures/tools/tests, config example/ignore proposal after approval. |
| Forbidden | Database dependency, cloud saves, client-selected paths, silent reset/migration, trading/crafting. |
| Automated tests | backend contract, corruption/interruption/migration/backup, duplicate rewards, restart/reconnect, path validation. |
| Manual validation | fresh server, restart, backup/restore, active expedition recovery, failed-save maintenance path. |
| Completion gate | No acknowledged durable mutation is lost/duplicated across forced restart fixtures. |
| Rollback | pre-migration backup plus schema-specific downgrade refusal; return to prior build only with compatible backup. |

## Phase J — Dedicated server export and friend hosting

| Field | Plan |
| --- | --- |
| Scope | explicit server runtime mode, approved Windows/Linux export presets, config/log/save/backup directories, console admin, allowlist/password policy, graceful shutdown, hosting guide. |
| Likely files | application composition, server tools/config examples, export presets only with approval, deployment docs/tests. |
| Forbidden | relay, public matchmaking/browser, web dashboard, cloud accounts, external identity/platform SDK. |
| Automated tests | headless startup/no rendering dependency, config/auth/admin/redaction, client join, backup, drain, shutdown/restart. |
| Manual validation | LAN and direct-IP test with firewall/forwarding; listen and solo parity; ordinary consumer hardware profile. |
| Completion gate | Alex can host, administer, back up, stop, and recover a private server with documented limitations. |
| Rollback | keep listen/solo modes and previous export; restore server-data backup after verified schema compatibility. |

## Proposed first implementation milestone

Phase A only: introduce stable local identity and separate local presentation/input seams while preserving exact single-player behavior. It has the smallest risk and creates the testable boundary every later phase needs. Stop for review before Phase B.
