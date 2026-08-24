# Caden UI Runtime V1

## Status

**Source gate passed for the reviewed minimum subset. Runtime preparation and existing-interface integration are complete.**

The full icon presentation sheet is not approved as a wholesale runtime atlas. Only the crops and IDs recorded in `assets/ui/caden/caden_ui_runtime_manifest_v1.json` are approved for runtime v1.

No image-generation model or generative repainting was used. All derivatives were created deterministically from the immutable supplied masters by binary alpha normalization, foreground isolation, and exact integer nearest-neighbor reduction.

## Immutable source masters

| Role | Repository path | Dimensions/mode | SHA-256 before and after |
| --- | --- | --- | --- |
| Batch A panels and frames | `assets/source_art/caden/ui/panels/caden_ui_panels_frames_master_v1.png` | 1536×1024 RGBA | `28ba4e9631c32fc9f4145d598751b0abb818dca34338da72a8b9e214b5ee3aaa` |
| Batch B icons, cursors, and input prompts | `assets/source_art/caden/ui/icons/caden_ui_icons_cursors_input_prompts_batch_b_master_v2.png` | 1536×1024 RGB | `92c4b1253bc1ea3a11239278dd44d362ba8de1b587b2cba61ee7c48f8c154694` |

The source filenames and bytes are preserved. Runtime assets live under `assets/ui/caden/`; Godot resources live under `ui/themes/caden/`.

## Source audit

### Panel source

- True transparent negative space is present.
- Alpha range is 0–254: 468,327 fully transparent pixels and 1,104,537 partially transparent pixels.
- The source contains 39 isolated painted components at the audit threshold, including seven large panel candidates.
- No title, label, sample dialogue, or presentation text is baked into panel interiors.
- Warm upper-left highlights, dark lower-right edges, and restrained blue jewel accents are consistent.
- Runtime candidates use binary alpha at threshold 128 to remove soft presentation feathering without repainting RGB pixels.
- Selected complete frames passed 9-slice review from 128 to 576 pixels wide.

### Icon source

The full sheet is RGB with a baked checkerboard, 169,944 distinct RGB colors, soft fringe pixels, and variable presentation extents. It therefore remains unsuitable for blind or bulk atlas extraction.

A small subset passed because each selected example has an isolated dark/colored silhouette, an enclosed cream interior where applicable, transparent padding after extraction, and an exact integer reduction to 24×24. The preparation tool excludes boundary-connected checker material, restores only enclosed icon interiors, writes binary alpha, and never repaints source colors.

## Panel mapping and 9-slice margins

Coordinates use `(left, top, right-exclusive, bottom-exclusive)` in the Batch A source. Margins use `(left, top, right, bottom)` in runtime pixels.

| Runtime ID | Source crop | Reduction | Runtime size | 9-slice margins | Practical reviewed sizes |
| --- | --- | --- | --- | --- | --- |
| `dialogue_panel` | `(15, 303, 312, 492)` | ÷3 | 99×63 | `(14, 14, 14, 12)` | 320×72, 576×96 |
| `objective_panel` | `(710, 307, 977, 490)` | ÷3 | 89×61 | `(13, 14, 13, 12)` | 176×72, 240×96 |
| `interaction_panel` | `(289, 525, 475, 588)` | ÷3 | 62×21 | `(10, 6, 10, 6)` | 128×32, 176×40 |
| `nameplate` | `(17, 519, 260, 594)` | ÷3 | 81×25 | `(18, 7, 10, 7)` | Dynamic dialogue width |
| `divider` | `(15, 616, 261, 643)` | ÷3 | 82×9 | `(8, 3, 8, 3)` | Dynamic horizontal width |

Godot `StyleBoxTexture` resources:

- `ui/themes/caden/caden_dialogue_panel_v1.tres`
- `ui/themes/caden/caden_objective_panel_v1.tres`
- `ui/themes/caden/caden_interaction_panel_v1.tres`
- `ui/themes/caden/caden_nameplate_v1.tres`
- `ui/themes/caden/caden_divider_v1.tres`

## Runtime atlas manifest

### Navigation atlas

Path: `assets/ui/caden/icons/caden_ui_navigation_icons_v1.png`  
Cell size: 24×24; atlas size: 72×24.

| ID | Cell | Source crop | Reduction |
| --- | --- | --- | --- |
| `selection` / `continue` | 0 | `(45, 43, 93, 91)` | ÷2 |
| `previous` | 1 | `(497, 43, 545, 91)` | ÷2 |
| `next` | 2 | `(639, 43, 687, 91)` | ÷2 |

### Blank keycap atlas

Path: `assets/ui/caden/keycaps/caden_ui_blank_keycaps_v1.png`  
Cell size: 24×24; atlas size: 72×24.

| ID | Cell | Source crop | Reduction |
| --- | --- | --- | --- |
| `neutral` | 0 | `(444, 479, 516, 551)` | ÷3 |
| `focused` | 1 | `(514, 478, 586, 550)` | ÷3 |
| `disabled` | 2 | `(662, 478, 734, 550)` | ÷3 |

Input letters are never baked into these cells. `InteractionPrompt` renders the current key as a dynamic Godot `Label` over the neutral frame.

### Objective-state atlas

Path: `assets/ui/caden/icons/caden_ui_objective_icons_v1.png`  
Cell size: 24×24; atlas size: 96×24.

| ID | Cell | Source crop | Reduction |
| --- | --- | --- | --- |
| `active` | 0 | `(41, 388, 113, 460)` | ÷3 |
| `updated` | 1 | `(151, 387, 223, 459)` | ÷3 |
| `complete` | 2 | `(251, 387, 323, 459)` | ÷3 |
| `failed` | 3 | `(348, 387, 420, 459)` | ÷3 |

Individual `AtlasTexture` resources are stored in `ui/themes/caden/icons/` and `ui/themes/caden/keycaps/`.

## Existing-interface integration

### DialogueUI

- `ui/DialogueUI.tscn` now uses the dialogue panel, speaker nameplate, divider, and 24×24 continue indicator.
- `SpeakerName`, `DialogueText`, and `[E] Continue` remain live labels.
- An explicit bottom anchor fixes the intended 640×360 bottom-panel geometry.
- `scripts/ui/dialogue_ui.gd` was not changed: ordered lines, interact-release protection, input consumption, control locking integration, closing behavior, and `dialogue_closed` remain intact.

### InteractionPrompt

- `ui/InteractionPrompt.tscn` now uses the compact interaction frame and a blank 24×24 keycap.
- `scripts/ui/interaction_prompt.gd` keeps the key and action description as separate dynamic labels. Legacy bracketed values such as `[E]` are normalized for display without changing the public `input_hint_text` seam.
- No controller auto-detection, input manager, remapping system, or platform branding was added.

### ObjectiveUI

- `ui/ObjectiveUI.tscn` now uses the objective frame and an objective-state marker.
- `scripts/ui/objective_ui.gd` switches only the marker texture between active and complete while preserving title, step text, completion text, timer, and visibility behavior.
- `scripts/objectives/objective_tracker.gd` was not changed.

`project.godot`, the Compatibility renderer, 640×360 viewport, integer stretch mode, input map, gameplay systems, world composition, NPC work, and narrative data were not modified.

## Intentionally excluded from runtime v1

- Complex hand-with-particles, eye, detailed door, pickup, rubble, and other soft presentation examples not proven at 24×24.
- Framed icon mockups that include their own rectangular presentation matte.
- Decorative long-line and corner assemblies not required by the three existing interfaces.
- Permanently lettered keycaps, platform-specific controller branding, and controller auto-detection.
- Any source example requiring non-integer reduction, manual repainting, invented pixels, or boundary-clipped silhouettes.

## Reproduction

Python and Pillow are required by the deterministic preparation tool:

```powershell
python tools/art/prepare_caden_ui_runtime_v1.py --prepare-runtime
```

The tool rewrites runtime PNGs, manifest data, `StyleBoxTexture` resources, `AtlasTexture` resources, source audit images, and size-review previews. It verifies immutable source hashes and that protected project/UI files are unchanged during asset generation.

Live preview rendering uses the existing Godot scenes and the Compatibility renderer:

```powershell
Godot --path . --script res://tools/art/render_caden_ui_runtime_preview.gd --audio-driver Dummy
```

The focused runtime test is:

```powershell
Godot --headless --path . --script res://tests/caden_ui_runtime_test.gd
```

## Preview and audit artifacts

- `docs/art/audits/caden_ui_source_gate_v1.json`
- `docs/art/previews/caden_ui_runtime_v1/caden_ui_panels_source_audit_v1.png`
- `docs/art/previews/caden_ui_runtime_v1/caden_ui_icons_source_audit_v1.png`
- `docs/art/previews/caden_ui_runtime_v1/caden_ui_source_acceptance_gate_v1.png`
- `docs/art/previews/caden_ui_runtime_v1/caden_ui_runtime_size_review_v1.png`
- `docs/art/previews/caden_ui_runtime_v1/caden_ui_live_interfaces_v1.png`
- `docs/art/previews/caden_ui_runtime_v1/caden_ui_before_after_v1.png` — reconstructed baseline on the left, live integrated scenes on the right.
- `docs/art/previews/caden_ui_runtime_v1/caden_ui_live_interfaces_grayscale_v1.png`
- `docs/art/previews/caden_ui_runtime_v1/caden_ui_live_interfaces_reduced_saturation_v1.png`

The preview backdrop is a deterministic high-/low-value contrast field, not a new world-art asset or lore decision.

## Manual review outcome

- Panel scale and padding: pass at the tested 640×360 layouts.
- Text hierarchy and clipping: pass for current English strings and representative dialogue length.
- 9-slice seams: pass across compact, small, medium, large, and 576-pixel-wide samples.
- Keycap readability: pass at 24×24 with dynamic `E` label.
- Icon readability: pass for the manifest-approved navigation and objective cells only.
- Blue restraint: pass; blue remains a small focal accent.
- Bright/dark background contrast: pass in live Compatibility-rendered previews.
- UI overlap: objective remains clear with dialogue or interaction prompt visible.
- Grayscale/reduced saturation: hierarchy remains legible.
- Current font: adequate for runtime v1; localization and longer strings should receive a future clipping review.

The architecture remains intentionally small: three independent scenes, reusable style/atlas resources, and one deterministic preparation tool. No new UI manager, autoload, dependency, or future system was introduced.
