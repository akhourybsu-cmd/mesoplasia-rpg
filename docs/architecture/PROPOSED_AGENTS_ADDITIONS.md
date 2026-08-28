# Proposed AGENTS.md Additions

- The server owns all persistent gameplay state and outcomes; clients submit commands, never outcomes.
- Solo, listen-server, and dedicated-server modes must use one authoritative gameplay ruleset.
- Multiplayer peer IDs, node paths, display names, filenames, and array positions are never persistent identities.
- UI, cameras, animation, audio, and effects never own authoritative domain state.
- Domain simulation must be headless-testable and independent of rendered scenes.
- Immutable content definitions and mutable runtime/persistent state must remain separate.
- Persisted and networked content references must use validated stable IDs.
- Network commands, events, and snapshots must be explicitly versioned and schema-validated.
- Persistent mutations and rewards must be idempotent and transactionally recoverable.
- Every network feature requires authority, reconnect, stale-command, and hostile-client tests.
- Do not add an autoload, production dependency, database, transport, or external service without approval.
- Preserve the playable Caden build through staged, reversible migration checkpoints.
