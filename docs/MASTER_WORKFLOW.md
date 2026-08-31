# Mesoplasia RPG — Master Workflow

> **Purpose:** This is the single operational dashboard for planning, prompting Codex, reviewing pushed work, tracking completion, and selecting the next task for Mesoplasia RPG.
>
> This file is intended to be updated after every meaningful pushed change. It does not replace the detailed architecture, art, canon, runtime, or test documents elsewhere in the repository.

---

## 0. Workflow Control Block

| Field | Current value |
| --- | --- |
| Repository | `akhourybsu-cmd/mesoplasia-rpg` |
| Canonical remote | `https://github.com/akhourybsu-cmd/mesoplasia-rpg.git` |
| Tracked branch | `main` |
| Workflow version | `1.0` |
| Last synchronized | `2026-08-30` |
| Last verified implementation HEAD | `33c0e696be353f0c6303e97ba79a916eb5a3be8c` |
| Last verified commit message | `Visual Upd` |
| Current repository visual baseline | Caden five-zone rollout v1.3; consolidated rollout remains a visual-review gate |
| Current primary design task | Cooperative extraction-RPG architecture package |
| Current parallel production task | Continue visual refinement of Caden without prematurely expanding gameplay systems |
| Local-change visibility | Local uncommitted or unpushed changes are **not visible** through GitHub and cannot be marked verified here |

### Mandatory synchronization rule

Before a major recommendation or a new Codex prompt is treated as current, inspect:

1. the latest `main` HEAD;
2. every commit since the last verified implementation HEAD;
3. `docs/CHANGELOG.md`;
4. the files changed by those commits;
5. relevant scenes, scripts, resources, manifests, architecture documents, and tests;
6. any explicit creator approval, rejection, correction, or newly locked direction.

After verification, update this control block and the affected task records.

---

## 1. Standard Operating Loop

Use this loop for every tracked Codex task.

- [ ] **Select.** Choose one task marked `READY`.
- [ ] **Refresh.** Verify the current GitHub `main` branch before copying the prompt.
- [ ] **Run.** Open a new Codex thread using this repository and paste the exact prompt.
- [ ] **Hold commit.** Codex normally leaves changes uncommitted for review.
- [ ] **Review report.** Confirm scope, changed files, tests, limitations, and approval gates.
- [ ] **Test manually.** Complete required Godot, visual, multiplayer, or gameplay review.
- [ ] **Approve or revise.** Automated success is not visual or design approval.
- [ ] **Commit and push.** Use a focused commit message only after approval.
- [ ] **Synchronize.** Ask ChatGPT: `Sync the Mesoplasia master workflow.`
- [ ] **Verify delta.** Compare the prior verified HEAD with current `main` and inspect pushed files.
- [ ] **Update this file.** Record the completing SHA, check off the task, preserve open gates, and add the next prompt.

### Completion rule

A task may be marked complete only when all applicable conditions are true:

- expected work is pushed to `main`;
- the pushed diff matches the approved scope;
- required automated checks passed;
- required manual review passed;
- no unresolved approval item blocks acceptance;
- the completing commit SHA is recorded here.

A Codex report alone is not proof of completion. Local files are not proof of completion. Automated tests are not a substitute for creator review when visual, narrative, or design judgment is required.

---

## 2. Status Legend

| Status | Meaning |
| --- | --- |
| `VERIFIED` | Present in pushed `main` and accepted for the stated scope |
| `READY` | Prompt is ready to run against current `main` |
| `ACTIVE` | Work is underway or exists locally but is not pushed and verified |
| `REVIEW` | Pushed or locally completed work still needs approval |
| `BLOCKED` | A dependency or decision must be resolved first |
| `BACKLOG` | Planned, but not the immediate task |
| `TBD` | Intentionally unresolved design or canon decision |
| `SUPERSEDED` | Replaced by a later prompt or direction; retained for history |

---

## 3. Source-of-Truth Hierarchy

When sources disagree, use this order:

1. **Explicit creator approvals, rejections, and corrections.**
2. **Current pushed `main` implementation** for what the game presently does.
3. **Approved repository standards, architecture records, and design documents.**
4. **Approved Mesoplasia canon** for world facts not yet represented in the repository.
5. **Documented recommendations and provisional decisions.**
6. **Inference**, which must be labeled and may not silently establish canon.

The repository is authoritative for implementation. Accidental code, placeholder text, or generated art may not override creator-approved world canon.

---

## 4. Locked Product Vision

### 4.1 World and opening state

- The game takes place during the **Halcyon Age**.
- The Age of Reckoning has already happened.
- The opening occurs in **Caden**, just outside Terrebonne.
- Caden is preparing for the **Festival of the Six**.
- The player initially arrives as an out-of-towner among the influx of travelers and festival-goers.

### 4.2 Inciting crisis

- A new demonic invasion strikes Caden during the Festival build-up.
- The unusually large population of travelers, adventurers, workers, and visitors gives Caden enough people to resist immediate destruction.
- Caden remains under pressure and begins running short on materials, supplies, equipment, and other strategic resources.
- The exact canon explanation for how this invasion occurs during the Halcyon Age is **not yet resolved** and must not be invented by implementation work.

### 4.3 Core game identity

The intended game is a **cooperative PvE extraction RPG**, not an extraction shooter and not an MMO.

- Caden is the persistent shared hub.
- Players form small parties with friends on a server Alex hosts.
- Parties leave Caden for dangerous expedition zones and dungeon-like environments.
- Exploration is top-down and real-time.
- Encounters use turn-based combat.
- Parties fight demons, search locations, collect resources, complete objectives, and choose when to extract.
- Resources become secure only through an approved extraction/return flow.
- Extracted resources are delivered to Caden.
- Caden uses those resources to repair damage, fortify defenses, maintain essential services, unlock capabilities, and survive escalating pressure.
- The strengthened hub enables deeper or more dangerous expeditions.
- The loop repeats as the demonic threat escalates.

### 4.4 Core loop

```text
Prepare in Caden
→ Form party and choose expedition
→ Enter hostile zone
→ Explore in real time
→ Trigger turn-based encounters
→ Collect unsecured resources and complete objectives
→ Decide whether to press deeper or extract
→ Attempt extraction
→ Return surviving party and secured resources to Caden
→ Repair, fortify, unlock, and resupply
→ Advance siege pressure and resolve consequences
→ Launch the next expedition
```

### 4.5 Cooperative direction

- Alex hosts the authoritative server.
- The initial product is for a small friend group.
- Caden persists as the shared home state.
- The server owns persistent world state, expedition state, combat outcomes, rewards, extraction settlement, and saves.
- Solo play should use the same authoritative gameplay rules locally where practical.
- The current single-player Caden build must remain playable during migration.

### 4.6 Visual direction

- Continue the existing bright daytime, top-down pixel-art Caden visual language.
- Caden begins warm, welcoming, and Festival-ready.
- The invasion should later create controlled visual evolution through damage, barricades, repairs, defensive works, shortages, and rebuilding.
- Do not erase Caden’s cozy identity; the contrast between home and danger is a core emotional pillar.

---

## 5. Design Pillars

1. **Home worth defending.** Caden must feel warm, social, useful, and increasingly shaped by player choices.
2. **Meaningful extraction.** Returning safely with resources is a major success condition, not merely walking through an exit.
3. **Shared preparation.** Party formation, supplies, loadout, objectives, and town priorities matter before departure.
4. **Risk versus return.** Deeper exploration should increase potential value and danger.
5. **Readable turn-based tactics.** Combat should reward cooperation and planning without becoming needlessly slow.
6. **Persistent consequence.** Expedition outcomes affect Caden, available options, and future pressure.
7. **Small-group cooperation.** The architecture serves friends playing together, not MMO scale.
8. **One authoritative ruleset.** Solo, listen-host, and dedicated-server play should share the same domain rules.
9. **Incremental migration.** Current Caden systems remain playable at each technical checkpoint.
10. **Canon discipline.** Missing lore is an approval gate, not permission to improvise world history.

---

## 6. Core Game-State Model

### 6.1 Caden campaign states

Recommended state categories, not yet implemented:

```text
FESTIVAL_PREPARATION
FIRST_BREACH
EMERGENCY_DEFENSE
RESOURCE_SHORTAGE
FORTIFICATION
ESCALATING_SIEGE
COUNTEROFFENSIVE
CAMPAIGN_RESOLUTION
```

Do not assume that these are all linear or irreversible. Final campaign-state progression remains TBD.

### 6.2 Resource security states

```text
WORLD_RESOURCE
CARRIED_UNSECURED
PARTY_STAGED
EXTRACTION_PENDING
SECURED_IN_CADEN
SPENT_ON_PROJECT
LOST_OR_ABANDONED
```

The server must own transitions among these states.

### 6.3 Expedition lifecycle

```text
AVAILABLE
SELECTED
READY_CHECK
ALLOCATING
LOADING
ACTIVE_EXPLORATION
ACTIVE_COMBAT
EXTRACTION_AVAILABLE
EXTRACTION_IN_PROGRESS
COMPLETED
FAILED
RETREATING
SETTLEMENT
RETURNING_TO_CADEN
CLOSED
```

### 6.4 Fortification lifecycle

```text
LOCKED
AVAILABLE
PROPOSED
FUNDED
UNDER_CONSTRUCTION
ACTIVE
DAMAGED
DISABLED
REPAIRABLE
REPAIRED
```

These state names are planning vocabulary only until approved in architecture ADRs.

---

## 7. Open Canon and Product Decisions

### 7.1 Canon gates

| ID | Status | Decision |
| --- | --- | --- |
| `CANON-INV-001` | BLOCKED | Explain how demons can invade during the Halcyon Age in relation to the Eden Crystal and prior post-Reckoning protections |
| `CANON-INV-002` | TBD | Determine what is happening in Terrebonne during the attack and why Caden cannot simply evacuate into the capital |
| `CANON-INV-003` | TBD | Determine whether this is a localized breach, coordinated continental return, concealed surviving threat, or another approved mechanism |
| `CANON-FEST-001` | TBD | Define which Festival preparations and traveler groups are present when the invasion begins without inventing Festival rites or iconography |

### 7.2 Game-design gates

| ID | Status | Decision |
| --- | --- | --- |
| `DESIGN-PARTY-001` | TBD | Final party size and maximum connected players |
| `DESIGN-RUN-001` | TBD | Target expedition length and checkpoint structure |
| `DESIGN-EXTRACT-001` | TBD | Extraction points, activation, interruption, emergency retreat, and return rules |
| `DESIGN-LOSS-001` | TBD | What is lost on defeat, abandonment, or failed extraction |
| `DESIGN-RES-001` | TBD | Resource categories, weights, slots, and carrying constraints |
| `DESIGN-FORT-001` | TBD | Fortification categories, upgrade choices, and whether choices are reversible |
| `DESIGN-SIEGE-001` | TBD | How siege pressure advances: real time, expedition count, story chapters, threat meter, or hybrid |
| `DESIGN-DEFENSE-001` | TBD | Whether Caden defense events are playable battles, strategic resolutions, story events, or a hybrid |
| `DESIGN-COMBAT-001` | TBD | Tactical grid, formation/row model, or non-grid target-based combat |
| `DESIGN-TURN-001` | TBD | Initiative, simultaneous planning, action points, and turn timers |
| `DESIGN-CHAR-001` | TBD | Character creation, playable ancestries, classes, roles, and progression |
| `DESIGN-LOOT-001` | TBD | Personal loot, shared pool, direct resource deposit, or hybrid |
| `DESIGN-PERSIST-001` | TBD | Hosted-world ownership, player profile portability, and character ownership |
| `DESIGN-END-001` | TBD | Campaign victory, failure, endless continuation, and replay structure |
| `DESIGN-PROC-001` | TBD | Hand-authored, modular, procedural, or hybrid expedition maps |

Codex may recommend options and tradeoffs. It may not silently mark these decisions accepted.

---

## 8. Verified Repository Baseline

### 8.1 Technical and gameplay foundation

- [x] VERIFIED — Godot 4.7 2D project and repository rules
- [x] VERIFIED — 640×360 internal resolution and 1280×720 desktop baseline
- [x] VERIFIED — Compatibility renderer and nearest-neighbor pixel presentation
- [x] VERIFIED — 32×32 world-grid logic
- [x] VERIFIED — four-direction movement and named Input Map actions
- [x] VERIFIED — five-zone Caden controller and transitions
- [x] VERIFIED — persistent Player across Caden zones
- [x] VERIFIED — interaction foundation
- [x] VERIFIED — linear dialogue foundation
- [x] VERIFIED — stationary and bounded-patrol NPC foundations
- [x] VERIFIED — objective/progress foundation
- [x] VERIFIED — Player character runtime and multiple NPC variants
- [x] VERIFIED — Caden UI runtime for dialogue, interaction prompt, and objective display

### 8.2 Environment state at verified implementation HEAD

The latest verified pushed changelog records **Caden five-zone rollout v1.3**:

- Commons Terrain Runtime v1.2 activated and visually accepted.
- Town Square approved façade candidates activated as Architecture Runtime v3.
- Town Square Terrain Runtime v1.3 activated as a tonal correction.
- Wayfarer’s Approach v5 revalidated and retained.
- Residential and Marketplace approved runtime baselines preserved.
- All six Caden connections captured in both directions.
- Complete Godot regression suite passed `23/23` executable test scripts.

### 8.3 Current visual gate

- [ ] REVIEW — `CAD-VIS-001`: consolidated Caden five-zone rollout v1.3
  - Baseline commit: `33c0e696be353f0c6303e97ba79a916eb5a3be8c`
  - Required decision: approve, request targeted corrections, or retain selected prior visuals.
  - No further broad asset integration should be considered verified until this gate is resolved.

### 8.4 Source-library state

- [x] VERIFIED — Caden Mega Asset Library and modular expansion source material are cataloged as source/reference material.
- [ ] REVIEW — Runtime approval remains asset-specific; source-library presence does not authorize automatic scene integration.
- [ ] TBD — Source rights remain recorded as `project_internal_rights_unverified` in current runtime manifests and must be resolved before public distribution.

---

## 9. Roadmap Overview

### 9.1 Workstream A — Caden visual and opening slice

| Task | Status | Description |
| --- | --- | --- |
| `CAD-VIS-001` | REVIEW | Review consolidated five-zone rollout v1.3 |
| `CAD-VIS-002` | BACKLOG | Targeted Caden-wide edge, seam, density, and grounding corrections after review |
| `CAD-PREINV-001` | BACKLOG | Establish final Festival-ready pre-invasion Caden baseline |
| `CAD-INV-001` | BLOCKED | Create first attacked/damaged Caden visual state after canon and siege-state rules are approved |
| `CAD-INT-001` | BACKLOG | Establish the inn as the first reusable interior |
| `CAD-NAR-001` | BACKLOG | Replace development objective with approved pre-invasion opening sequence |
| `CAD-AUD-001` | BACKLOG | Add first-pass music, ambience, footsteps, UI, and interaction audio |
| `CAD-PLAY-001` | BACKLOG | Produce a polished pre-invasion Caden playtest build |

### 9.2 Workstream B — Architecture and game design

| Task | Status | Description |
| --- | --- | --- |
| `ARCH-001` | READY | Produce cooperative extraction-RPG architecture and game-loop documentation package |
| `ARCH-002` | BACKLOG | Review and approve first ADR and decision set |
| `ARCH-003` | BACKLOG | Update `AGENTS.md` with approved authority, state, and stable-ID rules |
| `CANON-INV-001` | BLOCKED | Approve the Halcyon demonic-invasion mechanism |
| `DESIGN-CORE-001` | BACKLOG | Lock extraction, loss, resource, fortification, and siege MVP rules |

### 9.3 Workstream C — Incremental implementation

| Task | Status | Description |
| --- | --- | --- |
| `CORE-001` | BACKLOG | Introduce offline authoritative session/domain boundary |
| `CORE-002` | BACKLOG | Implement pure resource-bundle, expedition-result, and Caden-defense-state models |
| `CORE-003` | BACKLOG | Implement extraction settlement and secure-resource deposit flow without networking |
| `COMBAT-001` | BACKLOG | Implement headless-testable turn-based combat domain |
| `EXP-001` | BACKLOG | Implement one authored expedition map and run lifecycle |
| `FORT-001` | BACKLOG | Implement first Caden fortification decision and visible state change |
| `SIEGE-001` | BACKLOG | Implement first siege-pressure/defense cycle |
| `COOP-001` | BACKLOG | Create local two-avatar sandbox |
| `NET-001` | BACKLOG | Create server plus two-client networking sandbox |
| `NET-002` | BACKLOG | Migrate Caden to shared authoritative hub |
| `PARTY-001` | BACKLOG | Implement party formation and ready check |
| `NET-EXP-001` | BACKLOG | Network expedition launch, state, extraction, and return |
| `NET-COMBAT-001` | BACKLOG | Network turn-based combat commands, events, snapshots, and reconnect |
| `SAVE-001` | BACKLOG | Add versioned player/world/expedition persistence and recovery |
| `SERVER-001` | BACKLOG | Add self-hosted headless server export, configuration, logs, and admin operations |

---

## 10. Current Prompt Queue

# Prompt `ARCH-001` — Cooperative Extraction-RPG Architecture Package

**Status:** READY  
**Execution:** New Codex thread using the current repository  
**Authorized changes:** Documentation under `docs/architecture/` and a dated `docs/CHANGELOG.md` entry only  
**Forbidden changes:** Production code, scenes, assets, tests, settings, dependencies, autoloads, export presets  
**Commit behavior:** Do not commit

Copy everything inside the block below into Codex.

```text
# ARCH-001 — Mesoplasia Cooperative Extraction-RPG Architecture Package

Read and obey:

- AGENTS.md
- docs/MASTER_WORKFLOW.md
- docs/TECHNICAL_STANDARDS.md
- docs/CADEN_VERTICAL_SLICE.md
- docs/PROJECT_STRUCTURE.md
- docs/CHANGELOG.md
- all current gameplay, Player, NPC, interaction, dialogue, objective, UI, art-runtime, zone, and test documentation relevant to this task

Inspect the current repository first and record the exact main-branch commit SHA audited.

This is an architecture, game-design framework, repository-audit, and documentation task only.

Do not modify production scenes, gameplay scripts, tests, assets, project settings, Input Map, export presets, autoloads, dependencies, or AGENTS.md.
Do not implement networking, combat, resources, fortifications, expeditions, extraction, siege systems, persistence, or server exports.
Do not commit.

You may create documentation under docs/architecture/ and append one dated documentation-only entry to docs/CHANGELOG.md.

## Locked product direction

Treat these statements as creator-approved:

- The game is set during the Halcyon Age.
- Caden is preparing for the Festival of the Six when a new demonic invasion begins.
- Festival travelers, adventurers, workers, and visitors give Caden enough people to resist immediate destruction.
- Caden is under continuing pressure and is running short on strategic resources.
- Caden is the persistent cooperative home hub.
- Players form parties and launch hostile-zone and dungeon-crawling expeditions from Caden.
- Exploration is top-down and real-time.
- Encounters use turn-based combat.
- Players fight demons, collect resources, complete objectives, and choose when to extract.
- Resources become secure through the extraction/return flow and are deposited in Caden.
- Extracted resources repair, fortify, maintain, resupply, and unlock Caden.
- Strengthening Caden enables deeper expeditions while siege pressure escalates.
- Alex hosts the authoritative server for a small friend group.
- Solo play should use the same authoritative rules locally where practical.
- The current single-player Caden build must remain playable throughout migration.
- This is a cooperative PvE extraction RPG, not an extraction shooter and not an MMO.

Do not invent the canon explanation for how demons breach Halcyon-era protections or what is happening in Terrebonne. Record those as explicit canon gates.

## Required current-repository audit

Document the current:

- project entry and application composition;
- five-zone Caden controller and zone lifecycle;
- Player ownership, persistence, movement, camera, interaction, dialogue, objective, and UI ownership;
- StationaryNpc and bounded-patrol foundations;
- current content/data resources;
- current art/runtime and visual-state architecture;
- current tests and change-log process;
- project settings, autoloads, dependencies, export presets, networking code, combat code, and save code;
- assumptions that only one Player exists;
- state currently mixed into scenes or presentation;
- node paths and ownership likely to complicate cooperative migration;
- current architecture that should remain unchanged.

Use the pushed repository as the implementation source of truth. Do not rely on old prompt assumptions when the live project differs.

## Required game architecture

Design concrete boundaries and lifecycles for:

1. solo local host, listen host, dedicated headless server, and remote client modes;
2. persistent player/character identity separate from transient peer identity;
3. authoritative commands, resolved events, snapshots, sequence IDs, duplicate protection, and rejection behavior;
4. Caden as a persistent shared multi-zone hub with local cameras/UI and server-owned shared state;
5. Festival-ready, invaded, damaged, repaired, fortified, and defended Caden state representation without duplicating entire game logic;
6. party formation, invitations, leadership, ready checks, votes, disconnects, and reconnects;
7. expedition definitions versus mutable expedition-run instances;
8. authored zones/dungeons, objectives, encounters, checkpoints, resource nodes, extraction points, and return flow;
9. real-time authoritative exploration movement and an incremental migration path from the current Player;
10. server-authoritative turn-based combat independent of combat presentation;
11. resource bundles, carrying, secure versus unsecured resources, transaction IDs, loss, recovery, and extraction settlement;
12. Caden stockpiles, shortages, repair costs, fortification projects, unlocks, priorities, and visible town-state changes;
13. siege pressure, threat escalation, defense events, consequences, recovery, and campaign progression;
14. player-, party-, expedition-, Caden-, and world-scoped quests/dialogue/decisions;
15. item, equipment, loot, reward, and inventory transactions without deciding final content;
16. versioned persistence, atomic writes, backups, migrations, active-run recovery, and reconnect;
17. stable content IDs and immutable definition versus mutable runtime-state separation;
18. direct-IP/LAN friend hosting, server configuration, secrets, allowlist, logging, admin commands, and graceful shutdown;
19. pure domain tests, scene integration tests, authority-abuse tests, multiplayer harnesses, persistence tests, and headless server tests;
20. incremental migration from the current repository without a rewrite.

For each major component specify:

- responsibility;
- authority;
- lifecycle;
- inputs and outputs;
- state owned;
- state replicated;
- state persisted;
- failure behavior;
- tests;
- dependencies;
- migration path from the current project.

## Required core-loop model

Define the full state flow for:

Prepare in Caden
→ form party
→ select expedition
→ ready/load
→ explore
→ enter turn-based encounters
→ acquire unsecured resources/objectives
→ decide whether to continue or extract
→ extraction attempt
→ authoritative settlement
→ secure resources
→ return to Caden
→ choose repairs/fortifications/unlocks
→ advance siege pressure
→ resolve any defense consequence
→ begin next preparation cycle.

Include success, partial success, retreat, defeat, abandonment, disconnect, server restart, and failed-save paths.

Do not lock final numbers or penalties. Recommend MVP options and tradeoffs.

## Required state and authority matrices

Create:

- client/server responsibility matrix;
- state-scope matrix for client-local, connection, player, party, expedition, combat, Caden, siege, and world state;
- command-validation matrix;
- resource ownership and secure/unsecured transition matrix;
- extraction outcome matrix;
- Caden fortification/project state matrix;
- disconnect/reconnect/recovery matrix;
- persistence/save timing matrix;
- visual-state versus simulation-state matrix.

## Required architecture decisions

Create proposed ADRs for at least:

- server-authoritative persistent state;
- solo using the same ruleset;
- dedicated plus listen hosting;
- identity separate from peer ID;
- commands/events/snapshots;
- Caden as persistent shared hub;
- Caden visual evolution driven by authoritative state;
- instanced expedition model;
- party-size policy;
- one-active-expedition MVP versus multiple instances;
- authoritative real-time movement;
- turn-based combat simulation separate from presentation;
- combat spatial model;
- turn-order model;
- secure versus unsecured resources;
- extraction settlement transaction;
- expedition-loss policy;
- resource-category model;
- fortification project model;
- siege-pressure advancement model;
- defense-event model;
- quest/dialogue scope model;
- loot MVP;
- persistence abstraction;
- stable content IDs;
- protocol/content/save version separation;
- scene-root composition versus autoloads;
- direct-IP hosting before matchmaking/relay.

Mark unresolved ADRs as proposed, not accepted.

## Required documentation package

Create a coherent package under docs/architecture/ containing at minimum:

- ARCHITECTURE_INDEX.md
- GAME_VISION_AND_PILLARS.md
- CURRENT_REPOSITORY_AUDIT.md
- CORE_GAMEPLAY_LOOP.md
- COOPERATIVE_SERVER_ARCHITECTURE.md
- STATE_AUTHORITY_AND_SCOPE.md
- PLAYER_PARTY_AND_SESSION_LIFECYCLE.md
- CADEN_SHARED_HUB_ARCHITECTURE.md
- CADEN_SIEGE_AND_FORTIFICATION_MODEL.md
- EXPEDITION_AND_EXTRACTION_MODEL.md
- DUNGEON_INSTANCE_ARCHITECTURE.md
- TURN_BASED_COMBAT_ARCHITECTURE.md
- RESOURCE_ECONOMY_AND_PROGRESSION.md
- INVENTORY_LOOT_AND_REWARDS.md
- QUEST_DIALOGUE_AND_DECISION_SCOPES.md
- DATA_CONTENT_AND_STABLE_IDS.md
- PERSISTENCE_RECONNECT_AND_RECOVERY.md
- SELF_HOSTING_SECURITY_AND_OPERATIONS.md
- TEST_STRATEGY.md
- REPOSITORY_MIGRATION_PLAN.md
- IMPLEMENTATION_ROADMAP.md
- CANON_DEPENDENCIES.md
- DECISION_REGISTER.md
- RISK_REGISTER.md
- PROPOSED_AGENTS_ADDITIONS.md

Include Mermaid diagrams for:

- system context;
- solo/listen/dedicated/client topologies;
- Caden siege campaign loop;
- player connection lifecycle;
- party state machine;
- expedition/extraction state machine;
- Caden-to-expedition flow;
- combat state machine;
- combat action pipeline;
- secure/unsecured resource flow;
- fortification project lifecycle;
- siege-pressure lifecycle;
- persistence ownership;
- reconnect and active-expedition recovery;
- phased repository migration.

## Explicit open decisions

Preserve and analyze, without silently deciding:

- Halcyon invasion canon mechanism;
- Terrebonne status;
- final player/server/party count;
- expedition duration;
- extraction point rules;
- defeat and loss rules;
- resource categories;
- carrying limits;
- fortification categories;
- siege-pressure cadence;
- playable defense events;
- combat spatial and turn models;
- classes and progression;
- loot distribution;
- crafting, trading, housing, and Caden upgrades;
- procedural generation;
- multiple simultaneous expeditions;
- campaign victory/failure/endless mode;
- public servers, matchmaking, relay, cross-platform, and mod support.

For each, provide 2–4 viable options, tradeoffs, an MVP recommendation, and the exact approval needed from Alex.

## Migration roadmap

Create an incremental roadmap that preserves the current Caden build at every checkpoint.

At minimum evaluate phases for:

1. multiplayer-neutral refactoring and stable IDs;
2. offline authoritative session/command boundary;
3. pure extraction/resource/fortification domain models;
4. local two-avatar sandbox;
5. server and two-client connection sandbox;
6. shared network-aware Caden;
7. party and ready-check system;
8. one authored expedition and extraction loop;
9. pure headless-testable turn-based combat;
10. networked combat;
11. Caden resource deposit and first fortification state change;
12. first siege-pressure and defense consequence;
13. persistence/reconnect/recovery;
14. dedicated server export and friend-host operations.

For every phase define scope, likely files, forbidden scope, automated tests, manual tests, completion gate, and rollback checkpoint.

## First implementation recommendation

Recommend the smallest safe first implementation task after architecture review.

Prefer a narrow offline authoritative boundary that proves one meaningful portion of the future extraction loop without networking the whole game.

Evaluate a first slice involving stable identity plus an authoritative command such as expedition-result/resource-deposit settlement, while preserving current Caden behavior.

Do not implement it during this task.

Identify exact current files likely affected, new files proposed, tests, rollback plan, and forbidden scope.

## Quality and canon rules

- Be concrete rather than using generic “scalable” or “best practices” language.
- Do not invent Mesoplasia lore.
- Do not resolve the invasion/Eden Crystal conflict.
- Do not rewrite the project from scratch.
- Do not recommend mass file moves as the first step.
- Clearly label locked direction, provisional recommendation, open decision, future possibility, explicit non-goal, and canon gate.
- Treat the current pushed repository as implementation truth.

## Validation and final report

- Inspect the complete diff.
- Run git diff --check.
- Confirm only docs/architecture/* and docs/CHANGELOG.md changed.
- Confirm project.godot, AGENTS.md, scenes, scripts, tests, assets, dependencies, autoloads, Input Map, and export settings are unchanged.
- Do not commit.

Report:

1. exact repository SHA audited;
2. every existing file inspected;
3. every document created;
4. major current single-player assumptions;
5. recommended target topology and domains;
6. extraction and Caden-fortification architecture summary;
7. migration phases;
8. proposed ADRs;
9. highest risks;
10. canon gates;
11. unresolved decisions requiring Alex’s approval;
12. recommended first implementation milestone;
13. git diff --check result;
14. confirmation that no production file changed;
15. suggested commit message.

Stop after reporting.
```

### `ARCH-001` completion checklist

- [ ] Codex audited the exact current `main` SHA
- [ ] Architecture report received
- [ ] All required documents created
- [ ] Core loop reviewed
- [ ] Authority/state matrices reviewed
- [ ] Extraction model reviewed
- [ ] Caden siege/fortification model reviewed
- [ ] Combat model reviewed
- [ ] Hosting/persistence model reviewed
- [ ] Canon dependencies reviewed
- [ ] Decision register reviewed
- [ ] Mermaid diagrams reviewed
- [ ] No-code gate confirmed
- [ ] `git diff --check` passed
- [ ] Documentation committed and pushed
- [ ] Completing commit SHA recorded: `TBD`
- [ ] Master workflow synchronized after push

---

## 11. Manual Review Gate `CAD-VIS-001`

**Status:** REVIEW  
**Current implementation baseline:** `33c0e696be353f0c6303e97ba79a916eb5a3be8c`

Review the consolidated Caden five-zone rollout v1.3 and record one outcome:

- [ ] Approve current five-zone alpha baseline
- [ ] Approve with listed deferred visual debt
- [ ] Request targeted correction to specified zone(s)
- [ ] Revert or retain a specified prior runtime element

Review:

- Town Square architecture v3 and terrain v1.3;
- Wayfarer’s Approach v5;
- Marketplace terrain v1.2 and approved content;
- Residential terrain v1.2, buildings v1.1, and approved content;
- Commons terrain v1.2 and selected scenery;
- all six zone transitions in both directions;
- character scale and visual continuity;
- edge concealment, route seams, density, grounding, and collision readability.

A visual approval decision should be added to `docs/CHANGELOG.md` in the implementation task that records it.

---

## 12. Codex Completion Report Template

Every Codex task should end with a report that can be pasted into the review conversation.

```text
Task ID:
Task title:
Repository SHA audited:
Scope completed:
Files created:
Files modified:
Files removed or relocated:
Project settings changed:
Dependencies or autoloads added:
Tests run and exact exit codes:
Manual review still required:
Known limitations:
Canon gates encountered:
Design decisions encountered:
Open approval items:
Suggested commit message:
Commit created: yes/no
```

---

## 13. Workflow Synchronization Request

Use this message after pushing a Codex task:

```text
Sync the Mesoplasia master workflow against the current GitHub main branch. Compare from the workflow’s last verified implementation HEAD, inspect every new commit and changed file, read docs/CHANGELOG.md and the relevant docs/tests/scenes, update docs/MASTER_WORKFLOW.md, mark only fully verified work complete, record completing commit SHAs, preserve unresolved visual/design/canon gates, and add the smallest coherent next copy-pasteable Codex prompt. Do not infer local unpushed changes.
```

During synchronization, the workflow maintainer must:

- refresh the control block;
- summarize commits since the prior baseline;
- inspect actual changed files rather than relying only on commit messages;
- check off tasks only with pushed evidence;
- retain rejected, deferred, and superseded decisions;
- identify divergence between conversation claims and GitHub state;
- avoid issuing parallel prompts that edit the same files without coordination;
- add or revise the next prompt based on the current codebase;
- never claim background monitoring—synchronization occurs when requested.

---

## 14. Prompt and Task History

| Task ID | Title | Status | Completing commit | Notes |
| --- | --- | --- | --- | --- |
| `WORKFLOW-001` | Establish Master Workflow | ACTIVE | pending repository commit | This document |
| `ARCH-001` | Cooperative Extraction-RPG Architecture Package | READY | — | Documentation-only; no production code |
| `CAD-VIS-001` | Consolidated Caden Five-Zone Rollout Review | REVIEW | `33c0e69` baseline | Creator visual decision required |

---

## 15. Workflow Change History

### 2026-08-30 — Workflow v1.0 established

- Created one repository-resident operational dashboard.
- Recorded current pushed implementation baseline `33c0e696be353f0c6303e97ba79a916eb5a3be8c`.
- Incorporated the approved cooperative extraction-RPG direction.
- Recorded the unresolved Halcyon demonic-invasion canon gate.
- Recorded the consolidated Caden rollout visual-review gate.
- Added the first copy-pasteable architecture prompt and completion checklist.
- Established the GitHub verification, checkoff, commit, and resynchronization loop.
