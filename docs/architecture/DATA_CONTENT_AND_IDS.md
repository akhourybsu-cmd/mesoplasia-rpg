# Data, Content, and Stable IDs

## Identity rules

Persistent or network identity never uses node path, array index, scene order, peer ID, display name, or filename alone. IDs are opaque, stable, case-normalized strings or serialized UUID-like values with explicit type wrappers in domain code.

| ID family | Suggested representation/example | Creation/ownership |
| --- | --- | --- |
| Account/character | opaque server-issued UUID string | server identity repository |
| Party/expedition/dungeon/combat/session | time-independent UUID string | server ID generator |
| Combatant/item instance/transaction/entitlement | scoped or UUID opaque ID | owning server domain |
| Content definitions | namespaced lowercase ID, e.g. `caden.zone.town_square` | authored registry, immutable after release |
| NPC/interactable placement | namespaced definition + placement ID | authored content; runtime instance qualifies with hub/dungeon ID |
| Save record | typed owner ID plus schema/version | persistence repository |

IDs may be displayed in logs/admin tools but should not expose secrets. Renaming a file or node does not rename a released stable ID; use aliases/migrations when required.

## Connection identity mapping

`ConnectionPeerId` is captured at the network gateway and maps to `SessionId`. Authentication binds `SessionId` to `PlayerAccountId`; character selection binds it to `CharacterId`; spawning creates/reclaims `AvatarRuntimeState`. Disconnect destroys/replaces peer mapping without changing persistent IDs.

## Definition families

Godot-native custom `Resource` definitions are appropriate for editor-authored immutable content:

- `ItemDefinition`;
- `AbilityDefinition`;
- `StatusEffectDefinition`;
- `EnemyDefinition`;
- `LootTableDefinition`;
- `DungeonDefinition` and room/connection/placement definitions;
- `EncounterDefinition`;
- `QuestDefinition`;
- `DialogueDefinition`;
- `NPCDefinition`;
- `CharacterProgressionDefinition` if/when progression is approved.

Each definition has stable ID, display/localization key (or provisional display text), definition schema version where useful, declared dependencies by ID, and validation method/data contract. Definitions do not contain live health, current steps, inventory quantities, cooldowns, opened doors, or votes.

## Runtime-state pairing

| Definition | Runtime/persistent counterpart |
| --- | --- |
| `AbilityDefinition` | cooldown/loadout plus action state on `CombatantState` |
| `ItemDefinition` | stack entry or `ItemInstanceState` |
| `EnemyDefinition` | `CombatantState` and optional world NPC runtime state |
| `DungeonDefinition` | `DungeonInstanceState` |
| `EncounterDefinition` | encounter placement state and `CombatInstance` |
| `QuestDefinition` | scoped `QuestProgress` |
| `DialogueDefinition` | `DialogueSessionState` / decision state |
| `NPCDefinition` | hub/dungeon-qualified NPC runtime state |

Never edit a shared Resource to store runtime progress; Resources may be cached/shared across instances.

## Content registry

At startup, `ContentRegistry` loads approved roots, validates each definition, builds typed ID maps, resolves dependencies, calculates a deterministic manifest, and freezes mutation. The server fails startup for authority-critical errors. A client with a different required `CONTENT_VERSION`/manifest hash is rejected before authentication/world load.

The registry API is narrow: `has_id`, typed `get_definition`, dependency query, manifest/version query, and validation report. Gameplay does not call `load()` on client-provided paths.

## Content manifest

Use deterministic records sorted by stable ID containing ID, definition family, definition schema, authority-relevant canonical hash, and dependency IDs. Cosmetic-only compatibility can later be separated only through an approved policy; initially require an exact authority-relevant manifest.

`CONTENT_VERSION` changes when packaged definitions/scenes required for shared play change. It is separate from `PROTOCOL_VERSION` and `SAVE_SCHEMA_VERSION`.

## Validation plan

| Validation | Failure level |
| --- | --- |
| duplicate ID across a family/global namespace | fatal |
| missing dependency/reference/ability/item/enemy/quest/dialogue | fatal |
| circular dependency where the family forbids it | fatal with cycle path |
| invalid loot table entry/weight/quantity | fatal for authoritative content |
| broken dungeon connection/room link or invalid entry/checkpoint | fatal |
| unreachable required dungeon objective | error/fatal by definition policy |
| invalid quest transition, missing state, unreachable terminal | fatal |
| duplicate NPC/interactable/placement ID in an instance definition | fatal |
| missing localization key | warning during prototype; release gate later |
| unused definition | warning |

Validation runs in focused tools/tests, server startup, and build/release checks. Reports include source path for authors, but paths never become persistent identity.

## Current content migration

- Preserve existing dialogue `speaker_id` and objective/step IDs as candidate IDs; namespace them and check uniqueness before release.
- Register current Caden zone/entry/exit names without renaming scenes.
- Add adapters that expose IDs from current scene nodes; do not mass-edit art/runtime scenes.
- Introduce definition base contracts only when a phase needs them; do not prematurely convert every `.tres`.

## Version compatibility and tests

Golden manifest tests detect nondeterministic ordering and unintended content changes. Tests cover duplicate/missing/circular/broken references, Resource mutation attempts, stable ID alias/migration, server/client hash mismatch, and persisted unknown IDs. Unknown persisted data is preserved for recovery or causes an explicit migration failure; it is never silently discarded.
