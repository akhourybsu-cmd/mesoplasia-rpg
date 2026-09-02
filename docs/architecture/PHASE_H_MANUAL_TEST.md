# Phase H Manual Test

Phase H connects one authored expedition encounter to the Phase G combat domain over two real loopback ENet clients. The server owns encounter eligibility, combat identity, turns, RNG, AI, timeouts, reconnect state, outcome settlement, and expedition resume. The dedicated combat presenter submits intent and renders reliable snapshots/events; it does not calculate results.

## Network combat flow

1. Open `scenes/network/NetworkCombatSandbox.tscn` in Godot.
2. Press **F6** to run the current scene.
3. Select **1 Start**, wait briefly for both loopback clients to authenticate, then select **2 Prepare Party**. Wait for the two-member party to show `READY`.
4. Select **3 Launch**. Both clients should cross the content-ready barrier into `ACTIVE_EXPLORATION` in `development.room.test_threshold`.
5. Use **WASD** or the arrow keys to move both mirrored party members into the green exit on the right, then press **E**. Both should enter `development.room.test_depths` together.
6. Gather both avatars inside the gold encounter area and select **Enter Combat**. The expedition should enter `ACTIVE_COMBAT`, then the dedicated combat screen should replace the room after both clients acknowledge the ready barrier.
7. On the local Vanguard's turn, use **Strike** or **Guard**. The guest Warden submits its own turns automatically and the Venom Slime uses server AI. Confirm the current actor, health, Focus, statuses, revision, round, result, and reliable event list update together.
8. Leave a local turn untouched for ten seconds. The server should apply the deterministic timeout fallback and continue instead of freezing.
9. During another active local turn, select **Reconnect Guest**. The replacement guest should retain its CharacterId, reconstruct the same CombatId and bounded event window, acknowledge its current connection state, and continue taking its own turns.
10. Continue using **Strike** until victory. The combat snapshot should close exactly once, the dedicated combat screen should disappear, and both clients should resume `ACTIVE_EXPLORATION` in the same depths room with the encounter marked completed.
11. Select **Enter Combat** again. The server should reject the already-resolved encounter without creating a second combat or changing the completed result.
12. Select **Stop** to close both clients and the in-memory server cleanly.

## Acceptance checks

- Only the authenticated party leader can start the authored encounter, and all connected members must be inside its activation area at the expected expedition revision.
- The server allocates CombatId, combatants, deterministic seed, initiative, deadlines, RNG, AI decisions, effects, events, and outcome. Clients cannot author any of them.
- Both player controllers must acknowledge the reliable ready barrier before turns begin.
- A combat action is accepted only from the current combatant's authenticated controller at the exact combat revision with a unique nonce and legal ability/target combination.
- Stale revisions, forged controllers/actors, invalid targets, replayed nonces, and duplicate outcome processing do not mutate authoritative state.
- Reliable combat snapshots reconstruct the same CombatId, combatant state, current turn, event window, and outcome after guest reconnect or presenter reload.
- Disconnects and expired deadlines cannot freeze combat; deterministic fallback/AI advances through the same domain validator.
- Victory settles the encounter once and resumes the existing ExpeditionId/DungeonInstanceId. Defeat uses the existing safe Caden-return boundary.
- The full combat title, state, both panels, Strike/Mend/Guard controls, result feedback, and boundary text fit the 640×360 gameplay viewport.

## Expected limitations

- The encounter, Venom Slime, Vanguard, Warden, abilities, values, target-based spatial policy, and ten-second sandbox deadline are non-canon development fixtures.
- The visible guest is automated for one-window testing. It is still a separate authenticated ENet client and does not bypass the server command path.
- The sandbox auto-selects legal targets; production target selection, animation, audio, accessibility polish, final balance, and alternate combat presentations are not part of Phase H.
- Loot, rewards, inventory mutation, durable combat recovery, public hosting, relay, matchmaking, and PvP remain outside this phase.
- The combat and expedition checkpoint stores are memory-only and disappear when the sandbox server stops.
- Production `project.godot`, `scenes/Main.tscn`, and legacy Caden remain the unchanged rollback path. Disabling encounter launch leaves the Phase F outcome-stub sandbox available.
