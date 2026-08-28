# Caden Shared Hub Architecture

## Locked role

Caden is the persistent cooperative hub for social presence, NPC interaction, character/party preparation, expedition selection, and return. Its five current zones remain authored content:

- Wayfarer's Approach;
- Town Square;
- Marketplace;
- Residential Quarter (`residential` runtime ID today);
- Commons.

Terrebonne remains blocked and non-playable.

## Server hub model

```text
CadenHubState
  hub_instance_id
  world_revision
  active_zone_states: ZoneId -> HubZoneRuntimeState
  avatar_locations: CharacterId -> ZoneLocation
  party_presence: PartyId -> summary
  persistent_unlocks / world flags

HubZoneRuntimeState
  zone_id
  connected_avatar_ids
  npc_runtime_states
  interactable_runtime_states
  zone_event_sequence
```

The server may keep all five lightweight domain zone states available while clients load only their current zone presentation. Scene loading/unloading does not create or destroy authoritative hub state.

## Multi-player zone behavior

| Concern | Target behavior |
| --- | --- |
| Several avatars in one zone | Server simulates each by `CharacterId`; clients receive relevant snapshots and instantiate remote avatar views. |
| Clients in different zones | Each client subscribes to its current zone plus private/party scopes; one player's transfer does not unload another's state. |
| Zone activation | Domain state activates on server startup/load; expensive presentation loads per client. Later server optimization may idle empty non-persistent simulation, preserving its record. |
| NPCs | Persistent or moving NPC state is server-owned; cosmetic animation is client-only. Static dialogue definitions remain shared content. |
| Movement | Sequenced intent to server; authoritative collision/position; owner prediction optional; remote interpolation. |
| Visibility | MVP: all avatars in the same Caden zone are relevant. Do not add fine-grained interest management until measured. |
| Join in progress | Load private/party state, destination zone content, then apply a reliable full hub-zone snapshot. |
| Return from expedition | Server selects registered return point, transfers party/players, commits settlement, then sends Caden snapshots. |

## Local presentation ownership

One `LocalUIRoot` owns dialogue, interaction prompt, objective display, menus, and notifications. One enabled local Camera2D follows the controlled avatar. Remote avatar scenes contain visual/collision-proxy presentation only: no global input, enabled camera, local CanvasLayers, or authoritative control locks.

The existing `Player.tscn` should first gain an adapter/configuration seam that can disable or detach local-only children. Do not duplicate the entire Player ruleset into `RemotePlayer.tscn`.

## Hub transitions

Replace direct `ZoneExit -> Caden._load_zone()` behavior incrementally:

1. local detector identifies a stable `ZoneExitId` and submits a transition request;
2. server verifies sender, source zone, exit availability, control state, and destination;
3. server reserves the target entry and freezes movement under a transfer revision;
4. client loads target presentation;
5. server updates zone membership and authoritative position;
6. old/new zone subscribers receive leave/join events and the transferring client receives a snapshot.

Entry IDs can begin with current marker names, registered under namespaced zone IDs. Node paths are adapters only.

## Interaction and NPC concurrency

- Ordinary Caden NPC conversation defaults to concurrent, player-scoped presentation; it does not pause the zone.
- An interaction command identifies character, zone instance, and stable interactable ID; server validates range and availability.
- Only interactions that mutate shared state require a server lock or revision check.
- A shared lock has owner/session, purpose, acquisition revision, and timeout; disconnect releases it safely.
- NPC display name and dialogue text do not serve as identity.

## Dialogue scopes

| Scope | Ownership | Replication/persistence | Default use |
| --- | --- | --- | --- |
| `LOCAL_PRESENTATION` | local client view | none | advancing non-authoritative line presentation after server permits conversation |
| `PLAYER_SCOPED` | server for choices/flags; client displays | owner only; player save if consequential | ordinary personal dialogue and personal quest decisions |
| `PARTY_SCOPED` | server decision session | eligible party members; party/quest record | expedition/story choice explicitly marked shared |
| `WORLD_SCOPED` | server world state | all affected clients; world save | rare persistent hub decisions; never default |

Do not convert every current conversation into a party vote. Existing linear conversations can be adapted as player-scoped sessions whose text advancement remains local unless advancement itself has game effects.

## Objective evolution

The current `ObjectiveDefinition`/`ObjectiveStepDefinition` Resources are useful immutable definitions. Replace scene-local `_current_step_index` as the source of truth with scoped server `QuestProgress`. `ObjectiveUI` observes the local character's projected progress. The current development objective remains player-scoped and noncanonical during migration.

## Current-to-target migration

1. Add stable local `CharacterId` and avatar registry while still spawning exactly one Player.
2. Move camera/prompt/dialogue beneath a local presentation root or make their local ownership explicit.
3. Replace group-first depth/interaction assumptions and qualify transition requests by avatar.
4. Build a two-avatar no-network sandbox across one zone.
5. Add server-side hub state and transport adapters in a network sandbox.
6. Network one Caden zone, then all five, retaining existing scene content/collision.
7. Make NPC patrol and persistent interaction state server-owned.
8. Add reconnect to a Caden safe point before expeditions.

At every step, legacy single-player tests continue through the local adapter until equivalent authoritative tests replace only the assumptions that have intentionally changed.

## Failure and tests

Test two avatars entering different exits simultaneously, one avatar in dialogue while another moves, two clients speaking to one ordinary NPC, zone unload without stale interaction targets, join-in-progress, transfer timeout, disconnect during transfer, remote camera/UI absence, server-owned patrol convergence, and return-from-expedition placement.
