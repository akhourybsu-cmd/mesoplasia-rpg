# Decision Register

All ADRs are **Proposed**. None is accepted by this planning task. Approval questions are directed to Alex.

## ADR-001 — Server-authoritative game state

- **Status:** Proposed.
- **Context:** Cooperative outcomes, persistence, and reconnect require one source of truth.
- **Decision:** Server owns gameplay state/outcomes; clients submit intent and display results.
- **Alternatives:** client authority; peer lockstep; domain-by-domain mixed authority.
- **Advantages:** consistent saves/reconnect, simpler anti-duplication, one arbitration point.
- **Disadvantages:** latency/prediction work, higher host responsibility, server outage stops play.
- **Migration effect:** extract current local simulation behind commands; local host acts as server.
- **Alex approval:** Confirm server authority even for host client and solo mode.

## ADR-002 — Solo uses the cooperative ruleset

- **Status:** Proposed.
- **Context:** Separate offline rules would double combat/inventory/quest/dungeon behavior.
- **Decision:** Solo starts one local authoritative server and one client boundary.
- **Alternatives:** offline-only rules; directly invoke domain services without command boundary.
- **Advantages:** parity, shared tests, fewer save/network edge differences.
- **Disadvantages:** more startup/composition complexity for solo; local latency boundary.
- **Migration effect:** current single-player remains through an adapter until local authoritative composition passes.
- **Alex approval:** Approve no separate offline gameplay implementation.

## ADR-003 — Dedicated server plus optional listen server

- **Status:** Proposed.
- **Context:** Alex may host headlessly or play while hosting.
- **Decision:** One project supports dedicated, listen, solo, and remote-client compositions.
- **Alternatives:** listen-only; separate server project/codebase.
- **Advantages:** flexible hosting and shared rules/content.
- **Disadvantages:** conditional composition/export/testing matrix.
- **Migration effect:** add explicit runtime mode/ApplicationRoot in later phase; preserve Main until ready.
- **Alex approval:** Confirm Windows/Linux dedicated target and listen-server importance.

## ADR-004 — Persistent identity is separate from peer ID

- **Status:** Proposed.
- **Context:** Godot peer IDs change per connection and cannot survive reconnect.
- **Decision:** server-issued AccountId/CharacterId; peer maps only within SessionId.
- **Alternatives:** display name, IP, peer ID, client-generated identity alone.
- **Advantages:** safe ownership/reconnect/audit/persistence.
- **Disadvantages:** identity repository and first-join/account recovery policy required.
- **Migration effect:** add local stable CharacterId before networking; no current save migration exists.
- **Alex approval:** Choose first-join/host-approval and recovery expectations before Phase C/I.

## ADR-005 — Commands, events, and snapshots

- **Status:** Proposed.
- **Context:** Arbitrary remote scene mutation couples protocol to NodePaths and loses replay/resync semantics.
- **Decision:** versioned command intent, authoritative result events, complete scoped snapshots.
- **Alternatives:** RPC directly on gameplay nodes; replicate entire scene tree; full event sourcing.
- **Advantages:** validation, audit, reconnect, testability, protocol clarity.
- **Disadvantages:** schema/revision boilerplate and client state store.
- **Migration effect:** stable gateway adapters wrap current signals/methods; no mass rewrite.
- **Alex approval:** Approve this explicit protocol boundary and bounded—not complete—event logs.

## ADR-006 — Caden is the shared persistent hub

- **Status:** Proposed.
- **Context:** Locked game direction makes Caden the social/preparation/return space.
- **Decision:** server owns hub state across five zones; clients load zone presentation independently.
- **Alternatives:** private per-player Caden; single giant always-rendered scene; session-only lobby menu.
- **Advantages:** preserves current world, social presence, future upgrades.
- **Disadvantages:** multi-zone subscriptions, NPC concurrency, persistent world scope.
- **Migration effect:** evolve current one-zone controller via hub state/presentation adapter.
- **Alex approval:** Confirm players may occupy different Caden zones simultaneously.

## ADR-007 — Instanced expeditions

- **Status:** Proposed.
- **Context:** Parties leave shared Caden for isolated dungeon progress/combat/checkpoints.
- **Decision:** unique ExpeditionId/DungeonInstanceId with party membership and lifecycle.
- **Alternatives:** one global dungeon state; client-owned dungeon scenes; duplicate server process per party.
- **Advantages:** clear authority, cleanup, checkpoint, future concurrency.
- **Disadvantages:** instance lifecycle and transfer complexity.
- **Migration effect:** first authored test dungeon uses an instance even with one-active policy.
- **Alex approval:** Confirm expeditions are party instances rather than shared global dungeons.

## ADR-008 — Initial party-size policy

- **Status:** Proposed.
- **Context:** Brief gives provisional 1-4 but requires configurability.
- **Decision:** target 1-4 for expedition MVP; server config owns max; logic uses capacity policy.
- **Alternatives:** fixed 4; 1-6/8; no party cap beyond connections.
- **Advantages:** modest UI/network/combat scope; supports solo through four friends.
- **Disadvantages:** exact encounter balance/UI still open; larger group later requires testing.
- **Migration effect:** collections/revisions avoid four fixed slots.
- **Alex approval:** Final expedition cap and separate maximum connected users.

## ADR-009 — One active expedition MVP, registry-ready future

- **Status:** Proposed.
- **Context:** Concurrent instances add scheduling, persistence, operations, and testing cost.
- **Decision:** policy allows one active expedition initially; all APIs/records still use IDs/registry.
- **Alternatives:** multiple instances from day one; global singleton without IDs.
- **Advantages:** smaller MVP while avoiding data-model trap.
- **Disadvantages:** friends outside the expedition may wait; concurrency unproven.
- **Migration effect:** instance registry exists; capacity policy changes later.
- **Alex approval:** Is one active expedition acceptable for MVP, and may non-party players remain in Caden?

## ADR-010 — Real-time movement authority

- **Status:** Proposed.
- **Context:** Caden/dungeon exploration is real-time; saved position and collisions matter.
- **Decision:** clients send sequenced input; server simulates final position; prediction/interpolation are presentation.
- **Alternatives:** client-authoritative position with sanity checks; deterministic lockstep.
- **Advantages:** coherent world/zone authority and correction.
- **Disadvantages:** perceived latency, reconciliation and server collision data.
- **Migration effect:** Phase A separates input from movement; Phase D may start without prediction.
- **Alex approval:** Approve transitional server-driven movement before prediction if playability is acceptable.

## ADR-011 — Combat simulation separate from presentation

- **Status:** Proposed.
- **Context:** Dedicated server, tests, alternate presentations, and reconnect require scene-independent rules.
- **Decision:** pure server combat state/services; dedicated combat scene is provisional MVP view.
- **Alternatives:** rules in combat scene/UI; in-place scene-only combat.
- **Advantages:** headless tests, authority, reproducibility, presentation flexibility.
- **Disadvantages:** adapter/event layer and explicit state models.
- **Migration effect:** build offline domain before networked combat; current project has no combat to migrate.
- **Alex approval:** Confirm dedicated combat scene as MVP presentation, not permanent canon.

## ADR-012 — Combat spatial model

- **Status:** Proposed, product choice remains open.
- **Context:** Grid/formation choice strongly affects abilities, AI, content, UI, and state.
- **Decision:** recommend non-grid target-based MVP behind `CombatSpatialRules`.
- **Alternatives:** formation/rows; tactical tile grid.
- **Advantages:** smallest implementation/reconnect burden; preserves later abstraction.
- **Disadvantages:** less positional tactics; later grid adoption changes content and UI substantially.
- **Migration effect:** abstract position/target rules from first combat record.
- **Alex approval:** Choose non-grid, formation, or tactical grid before Phase G production design.

## ADR-013 — Initiative-based turn order

- **Status:** Proposed.
- **Context:** A deterministic server queue needs tie, round, summon, status, timeout rules.
- **Decision:** initiative queue with explicit entries, deterministic tie fallback, configurable 60-second provisional timeout.
- **Alternatives:** alternating teams; speed gauge/continuous turns; simultaneous planning.
- **Advantages:** familiar, testable, extensible.
- **Disadvantages:** balance and waiting-time concerns; exact initiative/AP model open.
- **Migration effect:** queue is saved/snapshotted, never recomputed on reconnect.
- **Alex approval:** Approve baseline model, final timer, action points, delay/extra-turn expectations.

## ADR-014 — Dialogue and quest scopes

- **Status:** Proposed.
- **Context:** Personal Caden talk must not pause everyone; some decisions are shared/persistent.
- **Decision:** explicit player, party, expedition, server-world quest scopes and local/player/party/world dialogue scopes.
- **Alternatives:** all personal; all party leader; all shared global.
- **Advantages:** correct concurrency, privacy, persistence, authored policy.
- **Disadvantages:** content authors must declare scope and vote policy.
- **Migration effect:** current linear dialogue becomes player-scoped; objective becomes player-scoped development progress.
- **Alex approval:** Decide default party-vote/story-leader rules before shared narrative content.

## ADR-015 — Loot-distribution MVP

- **Status:** Proposed, product choice remains open.
- **Context:** Shared loot introduces eligibility/votes/timeouts/duplication risk.
- **Decision:** recommend personal loot entitlements for MVP plus explicit shared quest rewards.
- **Alternatives:** party pool, need/greed, leader distribution, hybrid.
- **Advantages:** simplest atomic/reconnect behavior and low conflict.
- **Disadvantages:** less shared loot drama; trading implications remain open.
- **Migration effect:** entitlement/transaction model supports later policy without changing inventory ownership.
- **Alex approval:** Select final MVP loot policy, overflow behavior, and whether trading is in scope.

## ADR-016 — Persistence backend abstraction

- **Status:** Proposed.
- **Context:** Prototype needs saves without an unapproved dependency; durable transactions may later justify a DB.
- **Decision:** repositories/SaveTransaction; deterministic versioned files first; SQLite-like backend only after approval.
- **Alternatives:** direct FileAccess throughout domains; database immediately; no active expedition recovery.
- **Advantages:** small prototype, testability, backend replacement.
- **Disadvantages:** file transaction journal complexity; interface discipline.
- **Migration effect:** no current saves; introduce with schema fixtures and backups.
- **Alex approval:** Approve file-first progression and later dependency decision trigger.

## ADR-017 — Stable content-ID strategy

- **Status:** Proposed.
- **Context:** Filenames/node paths cannot be persistent identities; current IDs are unvalidated.
- **Decision:** namespaced immutable IDs in a typed content registry and deterministic manifest.
- **Alternatives:** resource paths; numeric array indexes; generated UUIDs for every authored definition.
- **Advantages:** readable authoring, stable references, validation/version hash.
- **Disadvantages:** naming governance and aliases/migrations after release.
- **Migration effect:** namespace existing zone/dialogue/objective IDs incrementally; scenes remain in place.
- **Alex approval:** Approve namespaced ID convention before new production content families.

## ADR-018 — Separate protocol/content/save versions

- **Status:** Proposed.
- **Context:** Wire, packaged content, and persisted schema change independently.
- **Decision:** `PROTOCOL_VERSION`, `CONTENT_VERSION`, and `SAVE_SCHEMA_VERSION` with separate compatibility gates.
- **Alternatives:** one game version; build number only.
- **Advantages:** precise rejection/migration and safer operations.
- **Disadvantages:** release discipline and compatibility matrix.
- **Migration effect:** establish version constants/manifests before first network/save format.
- **Alex approval:** Approve explicit version ownership and no unsafe downgrade.

## ADR-019 — Scene-root services before autoloads

- **Status:** Proposed.
- **Context:** Current project has no autoload; listen/solo require separable server/client lifecycles.
- **Decision:** `ApplicationRoot` composes explicit dependencies; no initial autoload.
- **Alternatives:** multiple global singletons; one service-locator autoload.
- **Advantages:** test injection, teardown, dual runtime branches, controlled state.
- **Disadvantages:** references must be passed/wired; root composition is more explicit.
- **Migration effect:** current Main remains until composition phase; no `project.godot` change during neutral work.
- **Alex approval:** Confirm new autoloads continue to require case-by-case approval.

## ADR-020 — Direct-IP friend hosting before relay/matchmaking

- **Status:** Proposed.
- **Context:** Initial audience is Alex and friends; cloud/platform systems add cost and dependency.
- **Decision:** ENet LAN/direct IP, configurable UDP port, password/invite/allowlist, documented port-forward/firewall limits.
- **Alternatives:** relay/public matchmaking/platform lobby/cloud accounts immediately.
- **Advantages:** self-hosted, modest, no external dependency.
- **Disadvantages:** NAT setup, no guaranteed confidentiality, host availability/security burden.
- **Migration effect:** transport interface preserves future alternatives without implementing them.
- **Alex approval:** Confirm direct-IP setup and security limitations are acceptable for first Internet hosting.

## Open decision register

| Decision | Provisional recommendation/tradeoff | Needed by |
| --- | --- | --- |
| Maximum connected players | configure 4-8 initially; larger cap increases hub snapshots/ops tests | Phase C/D |
| Expedition party size | 1-4 | Phase E/G content |
| Simultaneous parties/expeditions | one active expedition MVP, IDs/registry ready for more | Phase F |
| Character creation | no architecture content beyond account/character separation | before character-content implementation |
| Playable ancestries/classes/progression | remain undefined; data-driven definitions later | before progression/combat content |
| Combat spatial model | non-grid target-based recommended; grid has much higher cost | before Phase G |
| Action-point model | no AP baseline required until combat design; keep costs generic | before Phase G |
| Turn timer | provisional 60 seconds; accessibility/pace tradeoff | Phase H |
| Death/defeat consequences | safe return/outcome hooks only; no penalty invented | Phase F/H |
| Procedural dungeon generation | handcrafted first; optional seeded variation later | after Phase F |
| Loot distribution | personal loot recommended | Phase I/rewards |
| Trading | defer; adds transfer fraud/economy rules | after inventory MVP |
| Crafting | defer; definition/transaction extension only | future approval |
| Housing | explicit non-goal initially | future approval |
| Caden upgrades | retain world-state extension point, no content/system now | future approval |
| Party-vote policy | per decision; ready unanimous, narrative majority provisional | Phase E/shared narrative |
| Story-leader policy | do not equate party leader automatically; definition policy | shared narrative content |
| PvP | non-goal; combat team/controller model does not authorize it | future approval only |
| Public servers | non-goal; changes auth/moderation/security/ops substantially | future approval only |
| Relay service | defer; direct IP first | future hosting review |
| Cross-platform scope | Windows/Linux server and desktop clients assumed; exact clients open | export planning |
| Mod support | non-goal; manifests currently require controlled compatible content | future approval only |

No implementation phase may silently resolve an open decision when it materially changes architecture, player agency, persistence, security, or canon.
