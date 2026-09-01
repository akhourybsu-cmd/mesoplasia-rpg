# Phase F Manual Test

Phase F adds one server-authoritative, registry-backed authored test dungeon to the private-development network stack. The isolated sandbox starts one server and two real loopback ENet clients, prepares a party, transfers it through a content-ready barrier, and safely returns it to Caden. Combat is represented only by explicit outcome stubs; rewards and durable saves are not part of this phase.

## Numbered expedition flow

1. Open `scenes/network/NetworkExpeditionSandbox.tscn` in Godot.
2. Press **F6** to run the current scene.
3. Select **1 Start** and wait for both loopback clients to authenticate.
4. Select **2 Prepare Party**. The sandbox automatically performs invite, accept, expedition selection, and both ready commands. Wait for `READY` and the instruction to launch.
5. Select **3 Launch**. Both clients validate the authored room content; the party should enter `ACTIVE_EXPLORATION` together in `development.room.test_threshold`.
6. Use **WASD** or the arrow keys. The visible local avatar and automated guest mirror should move together. There must still be only one camera and one local interaction UI.
7. Move both avatars into the green exit at the right side and press **E**. The complete party should transfer into `development.room.test_depths`; a lone member at the exit must not transfer the party.
8. Optionally select **Reconnect Guest**. The replacement guest client should retain its stable CharacterId and reconstruct the same ExpeditionId, DungeonInstanceId, room, and avatar state. Movement should continue afterward.
9. Complete one outcome path:
   - Gather both avatars at the gold goal and press **E** for the success stub, or
   - Select **Retreat**, or
   - Select **Stub Failure**.
10. Both clients automatically acknowledge the return. The expedition should become `CLOSED`, the party should return to `FORMING`, and the local avatar should reappear safely in Caden's Wayfarer's Approach.
11. Select **Stop** to close both clients and the in-memory server cleanly.

## Acceptance checks

- A unique stable ExpeditionId, DungeonInstanceId, and deterministic seed are created by the server; clients cannot author them.
- Neither party member enters exploration until both have acknowledged the authored content revision.
- Both avatars share one authoritative current room, and only the leader can request a cohesive room transition or test outcome.
- Movement is server-owned and remains functional after guest reconnect.
- Reloading or reconnecting a presenter reconstructs the current room from the snapshot without allocating a new dungeon instance.
- Room transfer and each outcome checkpoint before authoritative mutation; checkpoint failure rolls back or preserves the previous valid state.
- Success, retreat, failure, and load-timeout paths all return or roll back without stranding the party.
- No combat resolution, enemy AI, rewards, inventory mutation, procedural generation, or durable save data appears in this phase.

## Expected limitations

- The dungeon contains two simple code-native development rooms and one active expedition per server policy. This content is a systems test, not finished art or canon.
- Checkpoints, parties, sessions, and reconnect state are memory-only and disappear when the sandbox server stops.
- The visible second avatar mirrors local movement only to make party cohesion easy to test in one window; it still sends commands through its own ENet client.
- Direct ENet/UDP and the development access code remain suitable only for private testing.
- Production `project.godot`, `scenes/Main.tscn`, and legacy Caden remain the unchanged rollback path.
