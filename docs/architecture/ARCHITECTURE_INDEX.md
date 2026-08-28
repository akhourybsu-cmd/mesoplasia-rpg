# Mesoplasia Cooperative RPG Architecture Index

## Package status

This package is a **planning blueprint**, not an implementation. All architecture decisions are **proposed** until Alex approves them. The existing single-player Caden build remains the playable baseline.

## Direction labels

| Label | Meaning |
| --- | --- |
| **Locked direction** | Supplied by the master planning brief and safe to plan around. |
| **Provisional recommendation** | Preferred starting point, configurable or reversible. |
| **Open decision** | Requires Alex's approval before implementation depends on it. |
| **Future possibility** | Preserved extension point without current implementation cost. |
| **Explicit non-goal** | Outside the initial architecture. |

## Document map

| Document | Primary concern |
| --- | --- |
| [GAME_VISION_AND_SCOPE.md](GAME_VISION_AND_SCOPE.md) | Locked game direction, capacity assumptions, and non-goals. |
| [CURRENT_REPOSITORY_AUDIT.md](CURRENT_REPOSITORY_AUDIT.md) | Current runtime, files, assumptions, tests, and migration risks. |
| [COOPERATIVE_MULTIPLAYER_ARCHITECTURE.md](COOPERATIVE_MULTIPLAYER_ARCHITECTURE.md) | Runtime topology, application composition, domain boundaries, and state ownership. |
| [SERVER_AUTHORITY_MODEL.md](SERVER_AUTHORITY_MODEL.md) | Command validation, authority, rejection, and audit policy. |
| [NETWORK_PROTOCOL_MODEL.md](NETWORK_PROTOCOL_MODEL.md) | Godot transport, message envelopes, channels, handshake, movement, and snapshots. |
| [PLAYER_AND_SESSION_LIFECYCLE.md](PLAYER_AND_SESSION_LIFECYCLE.md) | Identity mapping, connection, loading, disconnect, and reconnect. |
| [CADEN_SHARED_HUB_ARCHITECTURE.md](CADEN_SHARED_HUB_ARCHITECTURE.md) | Multi-player evolution of the five-zone Caden hub. |
| [PARTY_AND_EXPEDITION_MODEL.md](PARTY_AND_EXPEDITION_MODEL.md) | Party rules, decisions, launch, expedition lifecycle, and return. |
| [DUNGEON_INSTANCE_ARCHITECTURE.md](DUNGEON_INSTANCE_ARCHITECTURE.md) | Authored dungeon definitions, instances, rooms, encounters, and checkpoints. |
| [TURN_BASED_COMBAT_ARCHITECTURE.md](TURN_BASED_COMBAT_ARCHITECTURE.md) | Headless combat simulation, turn order, action pipeline, RNG, AI, and reconnect. |
| [INVENTORY_LOOT_AND_REWARDS.md](INVENTORY_LOOT_AND_REWARDS.md) | Inventory transactions, idempotency, loot policy, and reward settlement. |
| [QUEST_AND_NARRATIVE_SCOPES.md](QUEST_AND_NARRATIVE_SCOPES.md) | Player, party, expedition, and world quest/dialogue scopes. |
| [DATA_CONTENT_AND_IDS.md](DATA_CONTENT_AND_IDS.md) | Stable identities, immutable definitions, runtime state, and content validation. |
| [PERSISTENCE_AND_MIGRATION.md](PERSISTENCE_AND_MIGRATION.md) | Repositories, atomic saves, backups, checkpoints, and schema migration. |
| [SELF_HOSTING_AND_DEPLOYMENT.md](SELF_HOSTING_AND_DEPLOYMENT.md) | Dedicated/listen/solo startup, server configuration, admin, logs, and shutdown. |
| [SECURITY_AND_THREAT_MODEL.md](SECURITY_AND_THREAT_MODEL.md) | Friend-server authentication, trust boundaries, abuse controls, and limitations. |
| [TEST_STRATEGY.md](TEST_STRATEGY.md) | Unit, scene, multiplayer, authority, network-condition, persistence, and server tests. |
| [REPOSITORY_EVOLUTION_PLAN.md](REPOSITORY_EVOLUTION_PLAN.md) | Incremental target layout and current-to-future mapping. |
| [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md) | Reversible phases A-J with gates and rollback checkpoints. |
| [RISK_REGISTER.md](RISK_REGISTER.md) | Migration, networking, persistence, content, operational, and product risks. |
| [DECISION_REGISTER.md](DECISION_REGISTER.md) | Twenty proposed ADRs and all unresolved product decisions. |
| [PROPOSED_AGENTS_ADDITIONS.md](PROPOSED_AGENTS_ADDITIONS.md) | Concise candidate repository rules; `AGENTS.md` is unchanged. |

## Diagram index

The package contains embedded Mermaid source for:

1. system context — `COOPERATIVE_MULTIPLAYER_ARCHITECTURE.md`;
2. client/server responsibility split — `COOPERATIVE_MULTIPLAYER_ARCHITECTURE.md`;
3. dedicated, listen, and solo topology — `COOPERATIVE_MULTIPLAYER_ARCHITECTURE.md`;
4. player connection lifecycle — `PLAYER_AND_SESSION_LIFECYCLE.md`;
5. reconnect flow — `PLAYER_AND_SESSION_LIFECYCLE.md`;
6. Caden-to-expedition flow — `PARTY_AND_EXPEDITION_MODEL.md`;
7. party state machine — `PARTY_AND_EXPEDITION_MODEL.md`;
8. expedition state machine — `PARTY_AND_EXPEDITION_MODEL.md`;
9. dungeon instance structure — `DUNGEON_INSTANCE_ARCHITECTURE.md`;
10. combat state machine — `TURN_BASED_COMBAT_ARCHITECTURE.md`;
11. combat action pipeline — `TURN_BASED_COMBAT_ARCHITECTURE.md`;
12. persistence ownership — `PERSISTENCE_AND_MIGRATION.md`;
13. phased migration roadmap — `IMPLEMENTATION_ROADMAP.md`.

## Shared terminology

| Term | Meaning |
| --- | --- |
| account | Persistent server-issued player identity; never a display name or peer ID. |
| character | Persistent playable identity and progression owned by an account. |
| avatar | Scene/presentation projection of a character in a hub or expedition. |
| peer ID | Transient `MultiplayerAPI` connection identifier. |
| definition | Immutable content identified by a stable content ID. |
| runtime state | Mutable authoritative state for a live server session or instance. |
| command | Requested intent from a client or server policy. |
| event | Ordered authoritative result emitted by the server. |
| snapshot | Complete authoritative state for a defined scope and sequence. |
| transaction ID | Stable idempotency key for persistent mutations and rewards. |
| Caden | Persistent shared hub; Terrebonne is not currently playable. |
| expedition | Party-owned journey from Caden through a dungeon instance and back. |

## Governing invariants

- The server owns persistent gameplay outcomes; clients submit intent.
- Solo, listen-server, and dedicated-server modes use one authoritative ruleset.
- Domain simulation is independent of rendering, UI, audio, and cameras.
- Stable IDs cross save/network boundaries; peer IDs and node paths do not.
- Definitions are immutable; runtime and persistent state are separate records.
- Caden remains the shared hub, exploration remains real-time, and combat remains turn-based.
- Migration is adapter-led and checkpointed; the working Caden build is not rewritten.
- No MMO backend, public matchmaking, relay, platform SDK, or cloud account is required.
