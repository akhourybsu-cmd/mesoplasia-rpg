# Mesoplasia RPG Project Rules

These rules apply throughout this repository.

## Technology

- Use Godot 4.7 for this 2D project.
- Use GDScript unless explicitly instructed otherwise.
- Do not introduce C#, external libraries, addons, plugins, or other dependencies without approval.
- Keep the current Compatibility renderer unchanged unless a change is explicitly approved.

## Architecture

- Favor modular, reusable components over large monolithic scripts.
- Keep gameplay systems separated from content and data.
- Design systems so future quests, dialogue, items, enemies, maps, and characters can be added primarily through data rather than by rewriting core code.
- Avoid unnecessary coupling between systems.
- Do not hard-code narrative content into general-purpose gameplay scripts.
- Do not prematurely build systems that have not been requested.

## Repository Structure

- `assets/` — Art, audio, tiles, sprites, portraits, UI assets.
- `data/` — Structured game-content data such as items, dialogue, quests, characters, enemies, and world definitions.
- `docs/` — Project architecture, design decisions, standards, and technical documentation.
- `scenes/` — Godot `.tscn` scenes.
- `scripts/` — Reusable scene and gameplay scripts.
- `systems/` — Larger game-wide systems and managers.
- `tests/` — Automated or repeatable verification where practical.
- `ui/` — Reusable Godot UI scenes and related game-interface resources.

## Safety and Scope

- Never edit files inside `.godot/`.
- Do not intentionally commit Godot-generated cache or import data.
- Do not modify imported or generated files when the source asset should be changed instead.
- Do not delete or rename existing assets, scenes, systems, or data without explaining why.
- Do not redesign established systems outside the scope of the current task.
- Do not make world-lore or canon decisions independently.
- When requirements are ambiguous and the decision would materially affect architecture, ask before implementing.
- Preserve backward compatibility with existing saved data once a save system exists unless a migration is explicitly approved.

## Coding Standards

- Use clear, descriptive names.
- Prefer typed GDScript where practical.
- Keep functions reasonably focused and small.
- Comment architectural intent or non-obvious behavior rather than narrating obvious code.
- Treat warnings and errors as things to investigate rather than ignore.
- Prefer composition and signals where they fit Godot naturally.
- Avoid unnecessary global singletons and autoloads.
- Do not create an autoload without approval.

## Verification

For every implementation task:

- Inspect relevant existing files before editing.
- Make the smallest coherent change needed.
- Check for obvious parse errors, broken resource paths, missing dependencies, and invalid scene references.
- Run available tests or Godot validation when the local environment allows it.
- Clearly report anything that could not be tested.
- Summarize files changed and why.
- Do not claim something was tested if it was not.
