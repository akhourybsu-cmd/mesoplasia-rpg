# Server Authority Model

## Authority rule

The server is authoritative for identity, zone, movement outcome, hub/world state, party/expedition/combat state, RNG, AI, inventory/equipment/currency, loot/rewards, quest/dialogue persistence, unlocks, and saves. A client may predict visuals and request an action but cannot commit a persistent outcome.

Every client command envelope carries at least `protocol_version`, `session_id`, `command_id`, `command_type`, `client_sequence`, `expected_revision` where relevant, and payload. The server derives the sender peer from the RPC context immediately, maps it to an authenticated account/character, and never accepts an account or peer claim in the payload as authority.

## Common validation pipeline

1. Decode against the protocol schema and size limit.
2. Capture `get_remote_sender_id()` synchronously at the transport boundary.
3. Require a live session and authenticated identity where applicable.
4. Apply per-connection and per-command rate limits.
5. Resolve stable IDs through registries; reject unknown content or runtime IDs.
6. Check zone, party, expedition, combat, ownership, revision, and turn preconditions.
7. Check idempotency/duplicate command or transaction ID.
8. Validate domain rules without mutating.
9. Apply one authoritative mutation/transaction.
10. Persist when the command crosses a durability boundary.
11. Emit an ordered event/result; update snapshot sequence.

Rejected commands never mutate state. Responses use stable reason codes plus safe user-readable text. Security logs avoid raw secrets and excessive payload data.

## Command validation table

Rates are provisional token-bucket defaults per authenticated connection and must be configuration/policy values.

| Command | Sender and required state | Zone/party requirements | Rate | Validation and accepted result | Rejection, event, audit |
| --- | --- | --- | ---: | --- | --- |
| `join` | New transport peer, no session | none | 3/min/IP | capacity, protocol preamble; allocate pending session | reject capacity/version/rate; `SessionPending`; connection log |
| `authenticate` | Pending session | none | 5/min/IP, 3/session | password/invite/allowlist proof, sanitized profile hint; bind server-issued account | reject generically, delay; `PlayerAuthenticated`; security audit without secret |
| `movement_input` | Authenticated, active avatar, not hard-locked | avatar in hub/exploration; sender owns avatar input | 30/s | sequence newer, cardinal/allowed vector, timing plausible; enqueue intent and simulate | silently drop stale/excess, correct invalid; snapshot/correction; sampled security log |
| `interact` | Authenticated active avatar | same zone/room as stable target | 5/s | distance, facing/visibility if required, target enabled, no conflicting lock | `INVALID_TARGET/STATE/RANGE`; `InteractionStarted` or domain event; suspicious rejects logged |
| `party_invite` | Authenticated, available character | inviter allowed; target eligible; party revision current | 5/min | target exists/online, capacity, no duplicate, policy allows; create expiring invite | `PartyInviteCreated`; party audit |
| `party_accept` | Authenticated invite recipient | invite valid; capacity/revisions still valid | 5/min | token/ID belongs to sender, not expired; add member atomically | `PartyMemberJoined` or stale/capacity reject; party audit |
| `party_leave` | Authenticated member | not in non-leavable settlement phase | 3/min | revision, settlement safety, leadership transfer/disband rule | `PartyMemberLeft/LeaderChanged/Disbanded`; always audit |
| `ready` | Authenticated party member | forming/ready-check; no blocking load/state | 10/min | only own ready flag; expected party revision | `PartyReadyChanged`; stale rejects; normal party log |
| `select_expedition` | Leader or policy-authorized member | party forming; not reserved | 5/min | definition exists, unlocked, capacity/eligibility, revision | `ExpeditionSelected`; party/expedition audit |
| `launch_expedition` | Leader/policy winner | ready check complete; all eligible; Caden prep context | 2/min | content/version, one-active policy, no duplicate reservation, saves healthy | reserve/create instance; `ExpeditionAllocated`; all failures logged |
| `dialogue_choice` | Eligible session participant | correct dialogue scope/zone and decision open | 10/min | choice exists, voter eligible, no duplicate vote, revision/deadline | `DialogueVoteRecorded/DecisionResolved`; narrative audit for persistent/world choices |
| `combat_action` | Controller of active combatant | member of combat; actor's turn | 10/turn plus 3/s | ability/item exists, costs, cooldown, target/spatial rule, action nonce/revision | lock/resolve atomically; ordered `CombatActionResolved`; all invalid-turn/target attempts logged |
| `use_item` | Item owner/controller | allowed hub/exploration/combat phase | 5/s | instance/stack ownership, definition, target, cooldown, transaction ID | inventory/effect transaction; `ItemUsed`; persistent transaction audit |
| `equip_item` | Character controller | safe policy state; normally hub/out of combat | 5/s | ownership, compatible slot, constraints, expected inventory revision | atomic swap; `EquipmentChanged`; transaction audit |
| `loot_claim` | Eligible participant | correct unresolved loot transaction/instance | 10/min | policy eligibility, entitlement, unclaimed ID, inventory capacity/overflow policy | atomic grant/watermark; `LootGranted`; always audit duplicates/rewards |
| `retreat` | Member or party decision authority | active expedition, not already settling | 2/min | configured decision policy, safe transition/penalty rules | `RetreatApproved`, outcome/checkpoint/settlement; always audit |
| `reconnect` | New authenticated connection | account has disconnected session/character | 5/min/IP | reconnect token proof if used, grace period, no conflicting active control, versions compatible | rebind new peer, snapshots; `PlayerReconnected`; security/session audit |
| `admin_*` | Local server console or separately authenticated server-only channel | server policy | low/manual | explicit role, command-specific confirmation and target validation | admin event plus immutable audit; never callable as ordinary gameplay client |

## Mandatory rejection cases

The server rejects attempts to act for another player; act in the wrong zone/instance; act outside the controlled combat turn; target invalid or nonexistent IDs; reference unknown definitions; replay a transaction; use a stale party/instance revision; create impossible inventory deltas; or exceed rate/size limits.

## Revisions, ordering, and idempotency

- Mutable aggregates (`Party`, `Expedition`, `Combat`, `Inventory`) carry monotonically increasing revisions.
- Commands whose meaning depends on observed state include `expected_revision`; stale commands are rejected with the current revision/snapshot hint.
- Persistent mutations use globally unique transaction IDs and retain an idempotency result watermark long enough to survive reconnect/restart.
- Server events carry aggregate ID, aggregate revision, and event sequence. Events are results, not an invitation for clients to author state.

## Movement authority

Movement input is exceptional only in frequency, not authority. The owning client may predict its avatar. The server consumes sequenced intent, simulates collision/locks/transfers, and periodically sends authoritative position/velocity/facing plus last processed input sequence. The client replays unacknowledged input after correction. Remote clients interpolate; they never simulate ownership.

For the first network sandbox, prediction may be deferred: client sends input, server simulates, owner interpolates low-latency snapshots. This transitional model is acceptable only if transport and simulation are already separated and no client position becomes durable truth.

## Audit policy

Always audit authentication decisions, party membership/leadership, expedition lifecycle, combat actions, inventory/reward transactions, persistence/migration, admin actions, and security rejections. Sample routine movement success; log only anomalies/corrections to avoid noise. Include session, account, character, party, expedition, combat, transaction, and event IDs when applicable.
