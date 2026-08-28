# Self-Hosting and Deployment

## Initial hosting model

Support Windows and Linux dedicated headless servers, listen servers, and local solo hosts from the same project/ruleset. Initial connectivity is LAN or direct IP/domain using a configurable UDP port. Internet hosts may need router port forwarding and firewall configuration.

Godot supports `--headless` and dedicated-server exports; the dedicated export mode adds the `dedicated_server` feature tag and can strip visuals while preserving references. Plan a server export preset only in the later dedicated-server phase—this task does not modify export presets. Reference: [Godot dedicated server exports](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html).

## Runtime starts

| Mode | Startup selector | Composition |
| --- | --- | --- |
| Dedicated | dedicated-server export feature and/or explicit `--server` user argument | ServerRuntime only; headless display, dummy/no audio, config + saves + console |
| Listen | host menu/argument | ServerRuntime plus local ClientRuntime in separated branches |
| Solo | solo menu | local ServerRuntime plus one ClientRuntime; no Internet required |
| Remote client | join menu with address/port | ClientRuntime only |

Do not automatically start production server behavior merely because a test uses `--headless`; use an explicit runtime mode so current headless tests remain tests.

## Versioned server configuration

```text
config_schema_version
server_name
listen_address
port
max_connections
max_party_size
server_password_or_invite_mode
allowlist_enabled
save_path
backup_path
log_path
log_level
auto_save_interval
turn_timeout
reconnect_grace_period
one_active_expedition_mvp
```

Validate types, ranges, resolved paths, permissions, and conflicts before opening transport. `max_connections` and `max_party_size` are separate. Defaults are safe/private and all provisional capacity values remain configurable.

## Private configuration and `.gitignore` strategy

Commit only an example/template with placeholders and no secrets. Ignore instance-specific config, secret/invite files, allowlists if private, save directories, backups, and logs. Prefer an operator-selected directory outside `res://`/the install directory for production data. Future implementation should propose exact patterns for approval; this planning task does not edit `.gitignore`.

Never log or commit raw passwords/invite tokens. On shared hosts, restrict filesystem permissions. The server—not clients—resolves allowed save/log/backup roots.

## Directory separation

```text
server-data/
├── config/       # public instance config and separately protected secrets
├── saves/        # repositories/transaction manifests
├── backups/      # rotating and manual backups
└── logs/         # structured runtime/audit logs
```

Paths are canonicalized and verified under approved roots before write/delete/rotation operations.

## Minimal administration

Start with local console commands and structured logs, not a web dashboard.

| Command | Safety behavior |
| --- | --- |
| `status`, `list players` | read-only summary; avoid secrets/private inventory |
| `inspect party/expedition/combat` | read-only stable IDs/revisions/status |
| `announce` | sanitize/limit text; audit sender/local console |
| `kick`, `ban`, `unban` | explicit account/session target; reason; audit |
| `save`, `backup` | quiesce/transactional snapshot; report exact result |
| `return player to Caden` | safe registered point, checkpoint first, audit recovery |
| `close abandoned instance` | inspect references/settlement first; explicit confirmation/audit |
| `shutdown` | graceful sequence; force mode only as separate explicit emergency action |

Admin commands exist only inside ServerRuntime/local protected admin input. Ordinary clients cannot call them through gameplay RPCs.

## Structured logging

Categories: server lifecycle, connection, authentication, player session, party, expedition, combat, persistence, content validation, admin, security rejection, and migration.

Include timestamp, level, category, event name, build/protocol/content/save versions, session/account/character IDs, party/expedition/combat/transaction/event IDs as applicable, and safe reason code. Do not log raw passwords, invite/reconnect tokens, full auth payloads, private text, or unnecessary personal information.

Recommended levels:

- `ERROR`: data loss risk, failed commit/migration/startup, invariant violation;
- `WARN`: recoverable correction, timeout, suspicious/rejected behavior, backup issue;
- `INFO`: lifecycle, auth outcome, party/expedition/outcome, admin, save/backup summary;
- `DEBUG`: command/state transitions with IDs in development;
- `TRACE`: movement/packet diagnostics only temporarily with sampling.

Rotate logs by size/time and retain audit-relevant logs according to an operator policy.

## Graceful shutdown

1. Mark server draining and stop accepting new connections.
2. Notify clients with deadline/reason.
3. Reject new party launches and persistent mutations; let in-flight transactions finish.
4. Pause/checkpoint active expeditions/combat according to recovery support.
5. Flush all dirty saves and verify transaction results.
6. Create optional shutdown backup and record status.
7. Close network peers.
8. Exit with a logged success/failure code.

If a required save fails, keep the process alive in maintenance mode where possible and require explicit admin action rather than claiming a clean shutdown.

## Operations tests

Test headless startup without render/audio dependencies, config validation, occupied/invalid port, save/load, client join, log redaction, console authorization, backup, drain, shutdown with active expedition/combat, failed save, and restart recovery on both target operating systems when available.

## Deferred hosting improvements

Relay/NAT traversal, public discovery/matchmaking, external identity, cloud backups, containers/system services, automatic updates, platform lobbies, and remote web admin are optional future projects, not initial dependencies.
