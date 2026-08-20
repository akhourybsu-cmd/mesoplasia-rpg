# Character Visual Prototype Implementation Plan

## Decision boundary

Character Visual Prototype Pass 1 stops at planning artifacts. These approved-source paths were checked and are absent:

- `assets/source_art/caden/characters/player/caden_player_character_master_v1.png`
- `assets/source_art/caden/characters/npc/caden_npc_base_master_v1.png`

The source-art gate is therefore closed. No runtime character image, `SpriteFrames` resource, animation component, production Player/NPC scene edit, Town Square actor edit, movement change, collision change, or project-setting change is authorized in this pass.

The selected planning standard is a `40 x 56` cell, four direction rows, and four walk columns. This plan describes the smallest later implementation only if both approved master sheets pass the documented quality gate.

## Existing seams to preserve

### Player

- `Player` remains a persistent `CharacterBody2D` owned by `Caden`, outside the replaceable zone container.
- `movement_speed` remains `96.0`.
- The centered `24 x 24` collision remains at local `(0,0)`.
- Camera2D, InteractionDetector, InteractionPrompt, DialogueUI, the `player` group, camera-limit updates, four-direction movement, active-axis behavior, `facing_direction`, and reason-keyed control locks remain intact.
- Dialogue lock continues to zero velocity, leave facing unchanged, disable interaction, and block zone transitions.
- The blue `PlaceholderVisual` remains available as a hidden development fallback after gated integration.

### NPC

- `StationaryNpc` remains a `StaticBody2D` with a centered `20 x 20` collision and radius-32 Interactable area.
- `conversation`, `placeholder_color`, and `facing_direction` remain exported instance data.
- Interaction continues to call `start_dialogue()` on the interactor.
- NPCs remain stationary; no schedule, movement, pathfinding, or random animation is introduced.
- The placeholder polygon and FacingMarker remain available as a hidden development fallback after gated integration.

## Proposed smallest reusable component

Create one local script only after the gate passes:

`scripts/visuals/directional_character_visual.gd`

Preferred responsibility boundary:

- Extend `AnimatedSprite2D` or control one exported `AnimatedSprite2D` reference.
- Accept the current movement vector and current cardinal facing from the owning scene.
- Map cardinal vectors to `down`, `left`, `right`, or `up` without diagonal blending.
- Select `walk_<direction>` while movement is nonzero and `idle_<direction>` while stopped.
- Preserve facing while idle by trusting the owner's maintained facing value.
- Avoid calling `play()` when the requested animation is already active.
- Fall back safely when `sprite_frames` or an expected animation is absent: hide the animated sprite and leave the existing placeholder visible.
- Own no input, velocity, collision, movement state, dialogue state, interaction state, zone state, or global registration.

No autoload, animation manager, state-machine framework, AnimationTree, blend space, skeleton, runtime sheet slicer, palette-swap layer, character creator, equipment layer, or paper-doll system is needed.

## Proposed Player scene structure after gate approval

```text
Player (CharacterBody2D; unchanged origin/collision center)
├── VisualRoot (Node2D at local 0,12; feet anchor)
│   ├── AnimatedSprite2D (local 0,-28; 40x56 centered cells)
│   └── DevelopmentFallback (Node2D; hidden when runtime visual is valid)
│       └── PlaceholderVisual (retained blue Polygon2D)
├── CollisionShape2D (unchanged 24x24 at 0,0)
├── Camera2D (unchanged)
├── InteractionDetector (unchanged)
├── InteractionPrompt (unchanged CanvasLayer)
└── DialogueUI (unchanged CanvasLayer)
```

If preserving the existing placeholder's exact global position is simpler, retain it at the Player root and only add `VisualRoot/AnimatedSprite2D`; the fallback must remain hidden rather than deleted. Do not move the Player root or CollisionShape2D to create the feet anchor.

### Player data flow

1. Existing Player input selects a cardinal `movement_direction`.
2. Existing code updates `facing_direction` only for nonzero movement.
3. Existing code assigns `velocity = movement_direction * movement_speed` and calls `move_and_slide()`.
4. A single visual update call passes `velocity` (or `movement_direction`) and `facing_direction` to the component.
5. During a control lock, velocity is zero and facing remains unchanged; the component shows the matching directional idle frame.

The component must not restart the same animation every physics frame. It must not change movement speed or interpolate the sprite position. All transforms remain integer-aligned.

## Proposed NPC scene structure after gate approval

```text
StationaryNpc (StaticBody2D; unchanged origin/collision center)
├── VisualRoot (Node2D at local 0,10; feet anchor)
│   ├── AnimatedSprite2D (local 0,-28; directional idle only at runtime)
│   └── DevelopmentFallback (Node2D; hidden when runtime visual is valid)
│       ├── PlaceholderVisual
│       └── FacingMarker
├── CollisionShape2D (unchanged 20x20 at 0,0)
└── Interactable (unchanged radius 32 and dialogue signal)
```

The reusable base can set `idle_<direction>` once from the existing exported `facing_direction` during `_ready()`. It must not add NPC movement, update loops, or random idle behavior.

## SpriteFrames preparation after gate approval

Only if both master sheets pass the quality gate:

- Verify each is exactly `160 x 224` with 16 cells of `40 x 56`.
- Verify true transparent background, no presentation title or labels, exact grid alignment, bottom-center feet contact, consistent upper-left lighting, consistent proportions, and no unapproved canon.
- Prepare deterministic runtime copies without modifying masters:
  - `assets/characters/caden/player/caden_player_runtime_v1.png`
  - `assets/characters/caden/npc/caden_npc_base_runtime_v1.png`
- Create deterministic `SpriteFrames` resources:
  - `assets/characters/caden/player/caden_player_sprite_frames_v1.tres`
  - `assets/characters/caden/npc/caden_npc_base_sprite_frames_v1.tres`
- Use exact cells only. Do not mirror, rotate, blur, interpolate, or repaint.
- Record source and runtime SHA-256 values in `docs/art/CADEN_CHARACTER_RUNTIME_V1.md`.

Required animations:

| Animation | Frames | Loop | Starting speed |
| --- | ---: | --- | ---: |
| `idle_down`, `idle_left`, `idle_right`, `idle_up` | Direction row, column 1 only | No | Static |
| `walk_down`, `walk_left`, `walk_right`, `walk_up` | Columns 1-4 of direction row | Yes | 8 fps; review within 7-9 fps |

Left and right remain separate rows. No runtime lighting-reversing mirroring is allowed.

## Representative NPC selection

When the source-art gate later passes, select exactly:

`TownSquare/Actors/NPCs/SquareLocal`

Rationale: SquareLocal uses the shared stationary foundation, has an open approximately 48-pixel interaction approach, is not positioned beneath the current Town Square development labels, and provides a useful comparison near plaza/grass circulation without converting the rest of the population. Preserve its role, conversation resource, position `(288,448)`, facing `(1,0)`, collision, interaction area, and instance data. All ten other Caden NPC placeholders, including `PassingVisitor`, remain untouched.

The prototype should override or enable only the representative NPC's approved runtime visual. The shared foundation may gain optional visual support, but its default must continue to display existing placeholders for every instance without approved selection data.

## Fallback behavior

- Runtime visual valid and expected animations present: show AnimatedSprite2D; hide fallback polygons.
- Texture/resource missing, invalid, or animation absent: hide AnimatedSprite2D; show fallback; emit one actionable error rather than failing gameplay.
- A runtime failure involving collision, interaction, dialogue, control lock, persistence, transition, prompt, or anchoring: restore visible fallbacks, retain candidate runtime assets for review, and stop integration.

Fallback choice must never change collision, movement, detector range, dialogue data, or zone state.

## Z order and occlusion

The current project uses static order, not Y-sort:

- Town Square layers are terrain, nature, solid scenery, environmental props, Festival/Edenite, actors, then an empty foreground-overlay group.
- NPCs use default z 0 and scene order.
- The persistent Player has z 10 and currently renders above zone art.
- Prompts and dialogue are CanvasLayers 10 and 20.

The first gated integration should retain this behavior to avoid gameplay-scope drift. Review character feet beside building fronts, benches, lanterns, trees, and canopies at native resolution. If a specific roof/canopy overlap is clearly wrong, document its coordinates and visual expectation. Do not create a new Y-sort, canopy fade, roof fade, shader, or transparency-zone system during the prototype.

## Import conventions

- Lossless PNG import, mipmaps disabled, nearest-neighbor filtering, repeat disabled.
- Exact `40 x 56` cell regions and a `160 x 224` sheet.
- Integer visual positions only.
- Bottom-center mathematical anchor `(20,56)` with feet-contact pixel row 55.
- Player VisualRoot offset `(0,12)`; NPC VisualRoot offset `(0,10)`.
- AnimatedSprite2D center offset `(0,-28)` from VisualRoot.
- No source-master references from production scenes.

## Required gated tests

Create `tests/caden_character_runtime_test.gd` only when runtime integration occurs. It must verify:

- Both runtime textures and both SpriteFrames resources exist and load.
- All eight required animation names exist.
- Each idle animation contains one frame; each walk animation contains four frames.
- Source/runtime dimensions and documented hashes match.
- Player collision remains centered `24 x 24`; NPC collision remains centered `20 x 20`.
- Visual roots and feet anchors use the documented integer offsets.
- Current facing is retained while idle and during dialogue/control locks.
- Walking animation follows current cardinal movement without diagonal blending or repeated restarts.
- Interaction, prompt, dialogue, control locking, and zone transitions still function.
- The Player instance remains persistent through all Caden transitions.
- Exactly one Town Square NPC runtime visual is enabled and every other NPC fallback remains visible.
- No gameplay system, autoload, addon, or external dependency is added.
- Project configuration remains semantically compliant through `project_configuration_test_helper.gd`.

Run the full existing terrain, architecture, nature, props, Edenite/Festival, environmental-dressing, transition, persistence/camera, interaction, dialogue, population, and objective suites after any gated integration.

## Manual gated review

At `640 x 360`, review the integrated Player beside every Town Square door, both benches, ordinary lanterns, all three Edenite fixture types, medium trees, fences, planters, barrels/crates, grass, road, plaza, and the selected NPC. Confirm scale, feet contact, sliding, head bob, facing, idle return, prompt visibility, dialogue lock, silhouette contrast, pixel density, roof/canopy behavior, and whether the prototype implies unintended canon.

Do not resize environment assets automatically. Record environmental visual debt separately.

## Current outcome

- Recommended cell: `40 x 56`.
- Approved Player master: absent.
- Approved NPC master: absent.
- Runtime preparation: not performed.
- Player integration: not performed.
- NPC integration: not performed.
- Production scenes/scripts changed: none.
- Active failure gate: source-art gate only; expected planning-only path.
