# Phase K Manual Test — Caden Resource Deposit

Phase K is an isolated development proof of the persistent shared-world transaction. It does not modify production Caden visuals, establish final costs, spend stockpiles, unlock gameplay, or define siege/canon behavior.

## Start

1. Open `scenes/development/CadenResourceSandbox.tscn` in Godot 4.7.
2. Run the current scene at the configured 640×360 viewport.
3. Wait until the status says the durable character authenticated.

The screen shows three authoritative projections:

- **Private Edenite** — visible only to the owning client;
- **Shared Stockpile** — persistent Caden world state;
- **Project State** — the development-only fortification probe.

## Test sequence

1. Select **Grant Test**. Private Edenite increases by one; shared state remains unchanged.
2. Select **Fail Deposit**. The status must report `PERSISTENCE_WRITE_FAILED`. Private Edenite, shared stockpile, and project state must remain unchanged.
3. Select **Deposit 1**. Private Edenite decreases by one, the shared stockpile increases by one, and the project changes from `AWAITING_RESOURCES` to `FUNDED`.
4. Select **Replay**. The original result must be returned without another inventory removal or stockpile increase.
5. Select **Reconnect**. After reauthentication, the disposable client projection must reconstruct the same stockpile and funded project state.
6. Stop and run the scene again. The configured `user://mesoplasia_phase_k_sandbox` server data should retain the shared stockpile and funded project state. Grant another test unit if a fresh private balance is needed.

## Acceptance

- Every action and footer remains visible at 640×360.
- Failed persistence never acknowledges or partially applies a deposit.
- Reusing a deposit ID cannot duplicate the transfer.
- The client submits only intent, resource ID, quantity, and expected revisions; it does not submit replacement inventory/world state.
- Restart/reconnect state comes from durable server records.
- No production Caden scene, art, collision, interaction, or narrative content changes.

## Deferred by design

Resource acquisition during expeditions, extraction bundle security, final resource taxonomy, project selection/spending, multiple project stages, world visuals, shortages, unlocks, siege pressure, defense events, balance, and canon remain future approval items.
