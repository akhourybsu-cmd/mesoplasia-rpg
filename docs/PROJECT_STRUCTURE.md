# Mesoplasia RPG Project Structure

Mesoplasia RPG is a Godot 4.7 2D top-down fantasy role-playing game. The repository currently provides a minimal project foundation on which game content and systems can be developed deliberately.

## Current Structure

```text
mesoplasia-rpg/
├── .editorconfig
├── .gitattributes
├── .gitignore
├── assets/
│   ├── characters/
│   ├── enemies/
│   ├── environments/
│   ├── items/
│   ├── music/
│   ├── portraits/
│   ├── sfx/
│   ├── tilesets/
│   └── ui/
├── data/
│   ├── combat/
│   └── expeditions/
├── docs/
├── scenes/
│   ├── development/
│   │   ├── LocalMultiAvatarSandbox.tscn
│   │   └── OfflineCombatSandbox.tscn
│   ├── network/
│   │   ├── NetworkConnectionSandbox.tscn
│   │   ├── NetworkExpeditionSandbox.tscn
│   │   ├── NetworkPartySandbox.tscn
│   │   ├── NetworkedCadenPresenter.tscn
│   │   ├── NetworkedCadenSandbox.tscn
│   │   ├── NetworkedExpeditionPresenter.tscn
│   │   └── NetworkRuntime.tscn
│   ├── world/
│   │   ├── caden/
│   │       ├── Caden.tscn
│   │       ├── Commons.tscn
│   │       ├── Marketplace.tscn
│   │       ├── Residential.tscn
│   │       ├── TownSquare.tscn
│   │       └── WayfarersApproach.tscn
│   │   └── expeditions/
│   │       ├── TestDepthsRoom.tscn
│   │       └── TestThresholdRoom.tscn
│   ├── Main.tscn
│   └── Player.tscn
├── scripts/
│   ├── client/
│   │   ├── network/
│   │   ├── players/
│   │   └── world/
│   ├── core/
│   ├── development/
│   ├── domain/
│   │   └── combat/
│   ├── interaction/
│   ├── network/
│   │   ├── protocol/
│   │   ├── runtime/
│   │   └── transport/
│   ├── players/
│   ├── server/
│   │   ├── expedition/
│   │   ├── hub/
│   │   ├── party/
│   │   └── session/
│   └── world/
├── systems/
├── tests/
│   └── combat/
├── ui/
├── AGENTS.md
├── icon.svg
├── icon.svg.import
└── project.godot
```

Godot's local `.godot/` cache is intentionally excluded from this repository structure because it is generated and ignored by Git.

## Directory Responsibilities

- `assets/` contains art, audio, tiles, sprites, portraits, and UI assets. Its subdirectories group assets by purpose.
- `data/` contains structured game-content data. Phase F adds one registry-backed authored development expedition under `data/expeditions/`; it is content data rather than narrative canon or procedural-generation logic. Phase G adds minimal non-canon ability, status, and combatant fixtures under `data/combat/` for deterministic domain verification.
- `docs/` contains project architecture, design decisions, standards, and technical documentation.
- `scenes/` contains Godot `.tscn` scenes. Reusable locations live under `scenes/world/`; a location controller may compose smaller zone scenes while keeping the player persistent across local zone transitions. World locations are composed by the project entry scene rather than becoming entry points themselves.
- `scripts/` contains reusable scene and gameplay scripts. Phase A introduces the multiplayer-neutral boundaries: `core/` owns stable identity contracts, `client/players/` owns local input, presentation, and the avatar registry, `players/` owns input-independent avatar movement, `interaction/` owns local interaction requests, and `world/` retains the Caden transition adapter. Phase B adds only a development controller under `development/` for the local two-avatar sandbox. Phase C adds isolated `network/` protocol, runtime, and ENet transport adapters; `server/session/` owns the in-memory authoritative private-test session mapping, and `client/network/` owns disposable avatar-presence projections. Phase D adds `server/hub/` authority for the five Caden zones, `client/world/` snapshot presentation, compact client hub state under `client/network/`, and an isolated one-click networked Caden sandbox. Phase E adds the pure authoritative party state machine under `server/party/`, a revision-filtered client projection under `client/network/`, party protocol/runtime adapters, and a numbered two-client party sandbox. Phase F adds the pure expedition lifecycle, definition registry, and in-memory checkpoint store under `server/expedition/`, a disposable client expedition projection/presenter, and a two-client authored-dungeon sandbox. Phase G adds a scene-independent offline combat module under `domain/combat/`; its optional development viewer only submits intents and renders snapshots. These systems remain explicitly composed; no autoload was introduced, and production Main/Caden retains its legacy local path for rollback.
- `systems/` contains larger game-wide systems and managers.
- `tests/` contains automated or repeatable verification where practical.
- `ui/` contains reusable Godot UI scenes and related game-interface resources.

Gameplay architecture remains intentionally limited to approved milestones. This document should evolve as actual systems are introduced and their responsibilities become established.
