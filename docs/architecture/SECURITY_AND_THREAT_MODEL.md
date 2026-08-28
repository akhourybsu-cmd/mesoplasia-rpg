# Security and Threat Model

## Security posture

This is a private friend server, not an enterprise identity platform or cheat-proof competitive service. The goal is to prevent accidental corruption, casual command forgery, privilege misuse, replay/duplication, and unsafe operations while documenting the limitations of direct-IP hosting.

## Trust boundaries

- Clients, including the host's local client branch, are untrusted for gameplay outcomes.
- Network payloads and display text are untrusted input.
- Server configuration/secrets and local admin console are trusted only after filesystem/operator controls.
- Packaged content is trusted only after manifest/definition validation.
- Save files are trusted only after schema/checksum/reference validation.
- UI/presentation nodes are never authority even when running in the server process.

## Initial authentication recommendation

Use a server password or invite secret plus optional allowlist. On first approved admission, the server issues a persistent opaque `PlayerAccountId` and associates it with a local client profile/key or reconnect proof according to the implementation selected. Display name is sanitized metadata, never identity.

For a very small group, allowlist plus password/invite is simplest. Host approval can be an explicit first-join workflow later. Store secrets separately from public config; compare derived/hashed representations where practical; rate-limit attempts; never reveal whether a particular account is allowlisted in unauthenticated error details.

## Direct-IP limitations

- ENet/direct UDP does not automatically provide confidentiality of gameplay/auth traffic.
- A password sent without an approved secure challenge/encryption design may be observable on the network.
- IP addresses are not stable player identities and can be spoofed/changed at broader network layers.
- Port forwarding exposes the service to Internet scans and denial-of-service attempts.
- The architecture cannot prevent a malicious player from modifying their client or reading data legitimately sent to it.
- Server authority reduces outcome cheating but is not a substitute for transport security, OS patching, firewalling, backups, or operator judgment.

Do not claim encryption, confidentiality, strong account recovery, or identity proof until implemented and independently verified.

## Threat/control matrix

| Threat | Control | Residual risk |
| --- | --- | --- |
| Client grants damage/items/currency | server computes all outcomes; command schemas; ownership/revision checks | compromised server remains trusted |
| Act as another player | derive sender peer, server session mapping, no payload identity trust | session/reconnect secret theft |
| Replay/duplicate reward | unique transaction/entitlement ID and persisted watermark | bugs in migration/retention policy |
| Stale party/combat action | aggregate revision, action nonce, turn/controller checks | user sees rejection under latency |
| Command flood | packet/field limits, token buckets, timeout/kick/temporary ban | volumetric UDP denial of service remains |
| Auth guessing | IP/session rate limit, generic errors, strong invite/password, allowlist | distributed guessing/secret sharing |
| Malformed serialization | strict primitive schema, bounded nesting/arrays/strings, reject unknown required fields | engine/protocol vulnerabilities |
| Name/text abuse | Unicode/control-character policy, length limits, UI escaping/render-safe use | social moderation remains host responsibility |
| Client file/path selection | stable content IDs only; server-owned canonical roots | malicious local admin/OS compromise |
| Admin misuse | server-local boundary, explicit role, confirmation for destructive recovery, audit | trusted operator power is intentionally broad |
| Save corruption/crash | atomic transaction, checksum, backups, migration gates | disk/OS failure can exceed local backups |
| Content mismatch | content manifest/version handshake | compromised packaged client sees only sent data |
| Secret leakage in logs | redaction-by-construction tests, safe reason fields | external crash tooling must also be reviewed |

## Command security requirements

- Validate sender, state, zone/instance, stable IDs, expected revision, ownership, rate, and content existence for every command.
- Never accept client damage, loot roll, inventory delta, quest completion, RNG result, or save record.
- Reject excessive request rates, impossible movement, invalid targets, wrong turns/zones, stale commands, and duplicate transactions.
- Keep security rejection details in server logs while returning stable minimally revealing reason codes.
- Disconnect or ban only through server policy and audit; a single malformed packet should not corrupt state.

## Secrets and storage

Do not commit secrets. Do not include raw secrets in snapshots, events, logs, backups exported for support, or admin output. Resolve config/save paths under approved roots, prevent traversal, and use least-privilege OS accounts/filesystem permissions for dedicated hosting.

## Security validation

Automate hostile-client tests for impersonation, another avatar's movement/turn, invalid content/targets, oversized payloads, nested data, replay, stale revisions, rate flooding, path strings, control characters, unauthorized admin calls, auth enumeration, and log-secret scanning. Re-run after protocol or persistence migrations.

## Future options requiring approval

Transport encryption/authenticated key exchange, certificate distribution, platform identity, relay/DDoS protection, remote admin, account recovery, public servers, and formal ban evasion controls are separate security projects with operational cost.
