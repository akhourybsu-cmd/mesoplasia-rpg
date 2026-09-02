# Phase I Manual Test — Durable Persistence

## Purpose

This isolated sandbox verifies Phase I without changing the production `Main.tscn` path. It demonstrates server-owned versioned records, atomic reward settlement, restart recovery, backups, and rejection of a simulated failed write.

## Run

1. Open `scenes/development/PersistenceSandbox.tscn` in Godot 4.7.
2. Run the current scene with **F6**.
3. Keep the **Durable Record View** visible while using the numbered buttons.

## Expected sequence

1. Select **Initialize Atomic Fixture**.
   - The result says five records committed atomically.
   - Save schema is `1`, inventory revision is `1`, and Edenite quantity is `0`.
   - If the fixture already exists, the sandbox reports that it was left intact; continue with the remaining checks.
2. Select **Grant / Replay Reward**.
   - The first selection commits inventory and the reward outcome together.
   - Edenite quantity becomes `1` and the entitlement reads `COMMITTED`.
3. Select **Grant / Replay Reward** again.
   - The result says the reward was replayed without duplication.
   - Edenite quantity remains `1`.
4. Select **Simulate Process Restart**.
   - The result says the process was reconstructed from disk.
   - Inventory revision, Edenite quantity, and entitlement remain intact.
5. Select **Inject Failed Save**.
   - The mutation is rejected before acknowledgement.
   - Edenite quantity remains `1`.
6. Select **Create Backup**, then **Restore Last Backup**.
   - Both operations report success.
   - The durable record view remains valid and maintenance mode stays `NO`.

## Pass criteria

- Replaying the same entitlement never grants a second item.
- Simulated process reconstruction preserves acknowledged data.
- The injected persistence failure changes no durable state.
- Backup creation and validated restore succeed.
- Maintenance mode remains off throughout the healthy path.

The sandbox stores its development fixture under `user://mesoplasia_phase_i_sandbox`. It is intentionally isolated from game content and production composition.
