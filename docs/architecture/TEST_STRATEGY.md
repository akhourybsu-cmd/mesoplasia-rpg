# Test Strategy

## Test pyramid and gates

Prioritize fast headless domain tests, then scene adapters, then multi-process networking, with a small manual play matrix. Every migration phase keeps the prior Caden regression suite green or records an explicitly approved assertion change.

## Pure domain unit tests

No rendered scenes, camera, UI, audio, network socket, or production files:

- identity/session mapping and peer replacement;
- party invitations, capacity, leadership, ready checks, votes, disconnect grace;
- expedition/dungeon state transitions, cohesion, checkpoints, cleanup;
- combat action validation/resolution, turn order, ties, statuses, costs, targeting, timeout, AI;
- deterministic RNG streams and snapshot serialization;
- inventory/equipment/reward transactions and duplicate prevention;
- quest scope/decision resolution and reward triggers;
- content IDs/references/cycles/manifests;
- persistence contract, transactions, migrations, backups, recovery.

Inject deterministic clock, ID generator, RNG, content registry, and in-memory repositories.

## Scene integration tests

- current Caden startup and all five zone transitions;
- two or more avatar scene instances without duplicate cameras/UI/input;
- local versus remote presentation configuration;
- server-state-to-avatar binding and correction;
- per-avatar interaction targeting and stable interactable adapters;
- dialogue and objective UI bound only to local character state;
- NPC server-state presentation/patrol convergence;
- expedition room and dedicated combat presentation loading;
- unload/reload without stale node references.

Existing art/runtime tests remain valuable protected contracts. They should not be overloaded as domain tests.

## Multiplayer harness

Build a headless orchestrator after the network sandbox exists. It starts one server process and two scripted clients, later configurable up to the approved cap/four expedition players. Allocate loopback ports safely, capture structured logs separately, impose timeouts, and always clean up child processes.

Scenario path:

1. server startup/config/content validation;
2. two clients handshake/authenticate/spawn;
3. real-time movement and remote interpolation state;
4. party invite/accept/ready;
5. expedition selection/launch/load barrier;
6. authored room and encounter;
7. turn-based action and outcome;
8. disconnect/reconnect in hub, exploration, and combat;
9. reward settlement and Caden return;
10. graceful shutdown/restart and persistence verification.

Use unique temporary server-data roots. Never point tests at a real save directory.

## Authority/adversarial tests

Script clients attempt to:

- move another character or send claimed account/peer IDs;
- interact/transition from the wrong zone or beyond range;
- invite/ready/launch against stale party revision or without authority;
- take another combatant's turn, act outside turn, or target invalid IDs;
- submit damage/RNG/item grants or replace inventory;
- replay transaction/reward/action IDs across reconnect/restart;
- claim loot twice, equip unowned items, or create negative quantities;
- flood commands and send oversized/malformed payloads;
- invoke admin functions or choose server file paths.

Assert safe rejection, no state mutation, stable reason code, appropriate audit entry, and continued service for other clients.

## Network-condition tests

Add controllable latency, jitter, loss, duplication, and reordering at the test transport/proxy boundary. Cover stale movement input/snapshots, correction/reconciliation, reliable command completion, event gaps/resync, disconnect during zone load/turn/save/settlement, server restart, and content/version mismatch.

Provisional test points: 50/100/200 ms latency, 0/2/5/10% unreliable loss, 0/20/50 ms jitter. These are test profiles, not supported-service guarantees.

## Persistence and migration tests

- atomic temporary write/promote and interrupted phases;
- missing/corrupt/current/future-schema records;
- backup rotation, last-known-good restore, and maintenance refusal;
- every migration fixture plus unknown-field preservation and downgrade refusal;
- transaction replay and duplicate rewards after restart;
- active expedition/combat checkpoint recovery;
- shutdown flush failure and retry;
- repository backend contract parity if a database is approved later.

## Dedicated-server tests

Verify explicit server mode starts headlessly, requires no local Player/UI/camera/audio/decorative rendering, validates config/content/saves, accepts clients, logs/redacts correctly, saves/backups, drains, checkpoints, and exits with meaningful status. Test on Windows and Linux export templates when those builds exist.

## Performance/capacity tests

Measure server tick duration, snapshot bytes/rate, command queues, memory per hub/expedition/combat, save latency, and reconnect snapshot size at the provisional supported cap. Gates should protect a modest consumer host, not optimize for thousands. Exact budgets require profiling before approval.

## Manual matrix

At minimum: solo, listen host plus one remote client, and dedicated server plus two clients; each exercises Caden movement/interaction/dialogue, party/launch, exploration/combat, disconnect/reconnect, return, save/restart, and graceful shutdown. Visual checks cover local camera/UI ownership and remote interpolation; automated domain tests remain authority for rules.

## Phase completion evidence

Each phase records commands/tests run, versions/config, passed/failed counts, log locations, manual checks, limitations, and rollback checkpoint. A test not run is reported as not run; no result is inferred from documentation.
