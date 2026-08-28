# Risk Register

Scores are provisional: likelihood (`L`) and impact (`I`) range 1-5; priority is `L x I`. Reassess at every phase gate.

| ID | Risk | L | I | Priority | Mitigation/early evidence | Owner/trigger |
| --- | --- | ---: | ---: | ---: | --- | --- |
| R-01 | Fixed `$Player`/one-zone assumptions cause a Caden rewrite or regressions | 5 | 5 | 25 | Phase A adapters, multi-avatar sandbox, preserve legacy tests | architecture; before networked Caden |
| R-02 | Local camera/UI/input is instantiated on remote avatars or server | 5 | 4 | 20 | explicit local presentation attachment; dedicated no-render test | client architecture; Phase B/D |
| R-03 | Client-trusted movement creates cheating/desync and unsafe saved positions | 4 | 5 | 20 | server simulation, sequences, correction, safe-position saves | networking; Phase C/D |
| R-04 | RPCs coupled to dynamic node paths break with scene/content changes | 4 | 4 | 16 | stable gateway node, schema envelopes, stable IDs | protocol; Phase C |
| R-05 | Peer ID/display name becomes persistent identity | 3 | 5 | 15 | typed identity mapping and reconnect tests | identity; Phase A/C |
| R-06 | Mutable shared Resources leak state across instances | 3 | 5 | 15 | immutable registry + separate runtime records, mutation tests | content/domain; all phases |
| R-07 | Listen/solo in-process branch topology is brittle in Godot | 3 | 4 | 12 | prove in sandbox; retain loopback ENet fallback | runtime composition; Phase C |
| R-08 | Headless server accidentally loads cameras/UI/art-heavy scenes | 4 | 4 | 16 | server composition contains pure state/adapters; dedicated tests | server; Phase D/J |
| R-09 | Party/load/disconnect states strand players or freeze instances | 4 | 5 | explicit state machines, timeouts, safe Caden recovery/admin command | party/expedition; Phase E/F |
| R-10 | Combat presentation owns rules or events apply twice | 3 | 5 | pure domain, revisions/action nonce, snapshot/event tests | combat; Phase G/H |
| R-11 | RNG changes across reconnect/restart duplicate or alter outcomes | 3 | 5 | server RNG state/streams/checkpoints/golden fixtures | combat/loot; Phase G-I |
| R-12 | Reward/save failure duplicates or loses inventory/quest state | 4 | 5 | transaction IDs, atomic write sets, persisted watermarks, crash tests | persistence; Phase I |
| R-13 | File backend cannot safely commit multi-record outcomes | 3 | 5 | transaction manifest/journal; repository abstraction; DB approval trigger | persistence; Phase I |
| R-14 | Save migration silently discards unknown content/state | 3 | 5 | pre-backup, unknown preservation/refusal, migration fixtures | persistence; Phase I |
| R-15 | Content ID collisions/broken references ship | 4 | 4 | deterministic registry/manifest and startup validation | content; before F/G |
| R-16 | ENet/direct IP expectations imply confidentiality or easy NAT | 4 | 4 | explicit documentation, strong private-server policy, manual network test | security/ops; Phase J |
| R-17 | Authentication secrets leak to config/log/git | 3 | 5 | separated secrets, ignore patterns, redaction tests, no raw logs | security/ops; Phase J |
| R-18 | Command floods or malformed packets destabilize friend server | 3 | 4 | schema/size/rate limits, fuzz/adversarial tests, kick policy | protocol/security; Phase C onward |
| R-19 | One-active-expedition shortcuts become singleton coupling | 4 | 4 | IDs/registry from first implementation; capacity policy enforces MVP | expedition; Phase F |
| R-20 | Scope/vote rules apply personal dialogue globally | 3 | 4 | explicit quest/dialogue scope and definition policy | narrative; Phase D/E |
| R-21 | Tactical-grid assumptions create premature combat/content cost | 3 | 5 | spatial interface; target-based provisional ADR remains open | combat/product; before G |
| R-22 | Existing art/runtime tests are destabilized by architecture moves | 4 | 3 | no mass moves; protected regression suite every phase | repository; all phases |
| R-23 | Pre-existing Marketplace work is overwritten or misattributed | 3 | 4 | preserve dirty worktree; scoped patches/diff review | repository; immediate |
| R-24 | Server tick/snapshot/save rates exceed consumer hardware/network | 3 | 4 | configurable provisional rates and capacity profiling | performance; D/H/I/J |
| R-25 | Open product decisions are accidentally treated as canon | 4 | 4 | decision register, proposed status, approval gates | Alex/architecture; every phase |

## Highest-priority treatment order

1. R-01/R-02: Phase A/B ownership separation before any transport.
2. R-03/R-04/R-05: authority, protocol gateway, and identity in Phase C/D.
3. R-09/R-19: explicit party/expedition state and IDs before authored dungeon work.
4. R-10/R-11/R-21: pure combat and spatial approval before network presentation.
5. R-12/R-13/R-14: transaction/recovery prototypes before persistent progression ships.

## Approval/stop triggers

Stop and request direction if profiling invalidates modest-host targets; in-process topology cannot isolate authority; the file backend cannot meet atomic reward/checkpoint needs; transport confidentiality becomes a requirement; concurrent expeditions or split parties become MVP requirements; or an open combat/loot/narrative choice becomes necessary to implement the next phase.
