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
├── docs/
├── scenes/
│   ├── development/
│   │   └── LocalMultiAvatarSandbox.tscn
│   ├── network/
│   │   ├── NetworkConnectionSandbox.tscn
│   │   └── NetworkRuntime.tscn
│   ├── world/
│   │   └── caden/
│   │       ├── Caden.tscn
│   │       ├── Commons.tscn
│   │       ├── Marketplace.tscn
│   │       ├── Residential.tscn
│   │       ├── TownSquare.tscn
│   │       └── WayfarersApproach.tscn
│   ├── Main.tscn
│   └── Player.tscn
├── scripts/
│   ├── client/
│   │   ├── network/
│   │   └── players/
│   ├── core/
│   ├── development/
│   ├── interaction/
│   ├── network/
│   │   ├── protocol/
│   │   ├── runtime/
│   │   └── transport/
│   ├── players/
│   ├── server/
│   │   └── session/
│   └── world/
├── systems/
├── tests/
├── ui/
├── AGENTS.md
├── icon.svg
├── icon.svg.import
└── project.godot
```

Godot's local `.godot/` cache is intentionally excluded from this repository structure because it is generated and ignored by Git.

## Directory Responsibilities

- `assets/` contains art, audio, tiles, sprites, portraits, and UI assets. Its subdirectories group assets by purpose.
- `data/` contains structured game-content data, including future item, dialogue, quest, character, enemy, and world definitions.
- `docs/` contains project architecture, design decisions, standards, and technical documentation.
- `scenes/` contains Godot `.tscn` scenes. Reusable locations live under `scenes/world/`; a location controller may compose smaller zone scenes while keeping the player persistent across local zone transitions. World locations are composed by the project entry scene rather than becoming entry points themselves.
- `scripts/` contains reusable scene and gameplay scripts. Phase A introduces the multiplayer-neutral boundaries: `core/` owns stable identity contracts, `client/players/` owns local input, presentation, and the avatar registry, `players/` owns input-independent avatar movement, `interaction/` owns local interaction requests, and `world/` retains the Caden transition adapter. Phase B adds only a development controller under `development/` for the local two-avatar sandbox. Phase C adds isolated `network/` protocol, runtime, and ENet transport adapters; `server/session/` owns the in-memory authoritative private-test session mapping, and `client/network/` owns disposable avatar-presence projections. These systems are composed by scenes under `scenes/network/` and are not autoloads or dependencies of production Main/Caden.
- `systems/` contains larger game-wide systems and managers.
- `tests/` contains automated or repeatable verification where practical.
- `ui/` contains reusable Godot UI scenes and related game-interface resources.

Gameplay architecture remains intentionally limited to approved milestones. This document should evolve as actual systems are introduced and their responsibilities become established.
