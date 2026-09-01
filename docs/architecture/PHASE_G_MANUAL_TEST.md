# Phase G Manual Test

Phase G is an offline, scene-independent combat domain. The optional development viewer submits action intent and renders authoritative snapshots/events; it does not own health, resources, initiative, RNG, effects, AI, timeout behavior, or outcomes. It is not connected to the Phase F expedition or any network RPC.

The spatial policy is the roadmap's provisional non-grid, target-based model behind a replaceable rule object. It is a test policy, not final combat canon.

## Viewer flow

1. Open `scenes/development/OfflineCombatSandbox.tscn` in Godot.
2. Press **F6** to run the current scene.
3. Confirm the viewer shows Vanguard, Warden, and Venom Slime, an explicit initiative-driven current actor, round/revision state, and bounded authoritative events.
4. On Vanguard or Warden turns, use **Strike**. The domain automatically chooses the lowest-health valid enemy target.
5. Use **Guard** and confirm the status appears, reduces the next incoming damage, and expires at its declared turn-start hook.
6. After a hero has taken damage, use **Mend** on Warden's turn. Confirm health is clamped, Focus is spent, and the cooldown prevents immediate reuse.
7. Let a player turn sit for ten seconds. The domain should apply deterministic Guard fallback and advance instead of freezing.
8. Continue until one team is defeated. Confirm the lifecycle becomes `COMBAT_END`, the outcome is explicit, and action buttons disable.
9. Select **Restart Fixture**. The initial state and deterministic seed-driven behavior should reset without retaining the prior outcome.

## Acceptance checks

- The same definitions, starting state, seed, action sequence, and timing inputs produce the same initiative queue, RNG draws, effects, events, and outcome.
- Only the controller of the current player combatant can submit an action; stale revisions, forged actors, invalid targets, unequipped abilities, insufficient resources, cooldowns, malformed nonces, and replayed nonces are rejected without mutation.
- Enemy AI chooses intent from a constrained snapshot and passes through the same ability, cost, target, spatial, and resolution pipeline as player intent.
- Damage, healing, Guard, Poison, defeat, turn advancement, and terminal checks occur in ordered authoritative events.
- The event window remains bounded and an aged-out consumer is instructed to request a full snapshot.
- Checkpoints preserve the explicit queue, current turn, combatants, cooldowns, statuses, RNG stream states/draw counts, nonce set, and bounded events; checksum tampering is rejected.
- The viewer contains no network runtime and no expedition, inventory, loot, reward, or persistence integration.

## Expected limitations

- Abilities, values, combatant names, and the target-based policy are non-canon development fixtures, not production balance or character design.
- There is no tactical grid, formation model, action-point system, player-selected target UI, combat animation, audio, reward settlement, inventory use, or death penalty.
- Phase G is offline domain work. Network commands, reconnect presentation, encounter transitions, and expedition outcomes belong to Phase H.
- Checkpoints are serialized dictionaries for tests only; no durable storage backend is introduced.
- Production `project.godot`, `scenes/Main.tscn`, and legacy Caden remain the unchanged rollback path.
