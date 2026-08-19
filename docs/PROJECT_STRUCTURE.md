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
│   ├── world/
│   │   └── Caden.tscn
│   ├── Main.tscn
│   └── Player.tscn
├── scripts/
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
- `scenes/` contains Godot `.tscn` scenes. Reusable location scenes live under `scenes/world/` and are composed by the project entry scene rather than becoming entry points themselves.
- `scripts/` contains reusable scene and gameplay scripts.
- `systems/` contains larger game-wide systems and managers.
- `tests/` contains automated or repeatable verification where practical.
- `ui/` contains reusable Godot UI scenes and related game-interface resources.

Gameplay architecture remains intentionally limited to approved milestones. This document should evolve as actual systems are introduced and their responsibilities become established.
