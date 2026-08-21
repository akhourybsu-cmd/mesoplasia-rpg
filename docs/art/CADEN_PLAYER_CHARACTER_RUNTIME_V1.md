# Caden Player Character Runtime v1

## Outcome

**Source-art gate: passed on master v3. Runtime, scale-lab, animation, and gameplay gates: passed. Player-only integration: complete.**

The approved production runtime is a `160 x 224` RGBA sheet with sixteen `40 x 56` cells. It is derived from the repaired v3 master with one shared normalization scale, nearest-neighbor sampling, binary alpha, translation-only centering, and every foot baseline on runtime row 55.

The v1 and v2 masters and their prior audits remain preserved. Master v3 supersedes them only as the current Player integration source.

## Tooling note

Aseprite was not installed or callable in the working environment, so no `caden_player_character_master_v3.aseprite` file is claimed or included. The requested pixel operations were instead performed deterministically by `tools/art/repair_caden_player_master_v3.py`; the script protects the v1 input hash and can reproduce the audited v3 PNG exactly. The PNG is the immutable source consumed by the runtime pipeline. An editable `.aseprite` copy may be created later by opening that PNG in Aseprite and saving it without changing the pixels.

No generative repair was used.

## Preserved source history

| Master | SHA-256 | Status |
| --- | --- | --- |
| `caden_player_character_master_v1.png.png` | `865bfbe417db5eaf04aad05d511c6c8a5809289025ead4f213afdad2a948c0b1` | Original repair base; unchanged |
| `caden_player_character_master_v2.png` | `9b3226a1c2821f7e7bd0c082626e30198a38fa90dc373e64ceab7012939bb71d` | Preserved failed candidate |
| `caden_player_character_master_v3.png` | `02cf142c088af1852cd08b90db231cbfbc72c2b71c3246d45d1d4cdaa84b9ab8` | Approved integration source |

The v2 failure record remains in `CADEN_PLAYER_CHARACTER_MASTER_V2_AUDIT.md`. The earlier v1 review artifacts remain under `docs/art/previews/`, the v2 artifacts remain under `docs/art/previews/caden_player_master_v2/`, and the approved v3 audit set is isolated under `docs/art/previews/caden_player_master_v3/`.

## Deterministic v3 repair

The repair tool performs only these explicit edits against v1:

1. Verifies the exact protected v1 SHA-256 before doing any work.
2. Uses the exact `265 x 371`, origin `(0,0)` source grid.
3. Moves the complete contents of each row-4 cell down exactly 16 source pixels, without resizing or pose changes.
4. Copies only the four-row crown cap from `r4c3` source rows `5..8` into `r4c2` and `r4c4` target rows `12..15`, with an 8-pixel horizontal alignment offset.
5. Clears the isolated `r3c2` artifact at local `x=119..125`, `y=370`.
6. Exports an RGBA `1060 x 1484` PNG without trimming, scaling, indexing, guides, or grid pixels.
7. Re-verifies that the v1 input hash did not change.

## V3 source audit

| Property | Result |
| --- | --- |
| Format / dimensions | PNG, RGBA, `1060 x 1484` |
| Exact grid | `4 x 4`, `265 x 371` per cell |
| Nonempty frames | 16 of 16 |
| Primary strong-alpha components | Exactly one in every cell |
| Strong component touching a cell boundary | None |
| Up-frame crown top clearances | 17, 12, 21, and 12 source pixels |
| Former `r3c2` artifact | Absent at all seven specified pixels |
| Row / column order | Down, left, right, up / neutral, step A, passing, step B |
| Partial alpha | 539,651 pixels (`34.306248%`) |
| Gate result | Pass |

The source retains a broad low-opacity edge field inherited from v1. Mechanical clipping decisions use the fixed alpha threshold of 128 and four-connected primary-character components. No strong component approaches or touches a cell boundary. Runtime construction applies the same fixed threshold and therefore contains binary alpha only.

### Strong-alpha frame geometry

Bboxes are local to each source cell and use right/bottom-exclusive coordinates.

| Frame | Direction / pose | Bbox | Size | Center x | Bottom | Components |
| --- | --- | --- | --- | ---: | ---: | ---: |
| `r1c1` | down / neutral | `(58,49)-(206,339)` | `148 x 290` | 131.5 | 338 | 1 |
| `r1c2` | down / step A | `(59,45)-(207,349)` | `148 x 304` | 132.5 | 348 | 1 |
| `r1c3` | down / passing | `(58,56)-(201,343)` | `143 x 287` | 129.0 | 342 | 1 |
| `r1c4` | down / step B | `(64,45)-(209,349)` | `145 x 304` | 136.0 | 348 | 1 |
| `r2c1` | left / neutral | `(73,32)-(193,332)` | `120 x 300` | 132.5 | 331 | 1 |
| `r2c2` | left / step A | `(71,30)-(198,332)` | `127 x 302` | 134.0 | 331 | 1 |
| `r2c3` | left / passing | `(71,28)-(197,332)` | `126 x 304` | 133.5 | 331 | 1 |
| `r2c4` | left / step B | `(69,33)-(197,332)` | `128 x 299` | 132.5 | 331 | 1 |
| `r3c1` | right / neutral | `(64,18)-(192,321)` | `128 x 303` | 127.5 | 320 | 1 |
| `r3c2` | right / step A | `(52,18)-(198,321)` | `146 x 303` | 124.5 | 320 | 1 |
| `r3c3` | right / passing | `(61,18)-(194,322)` | `133 x 304` | 127.0 | 321 | 1 |
| `r3c4` | right / step B | `(57,23)-(196,321)` | `139 x 298` | 126.0 | 320 | 1 |
| `r4c1` | up / neutral | `(58,17)-(206,323)` | `148 x 306` | 131.5 | 322 | 1 |
| `r4c2` | up / step A | `(62,12)-(206,320)` | `144 x 308` | 133.5 | 319 | 1 |
| `r4c3` | up / passing | `(54,21)-(198,323)` | `144 x 302` | 125.5 | 322 | 1 |
| `r4c4` | up / step B | `(62,12)-(205,323)` | `143 x 311` | 133.0 | 322 | 1 |

Source baseline spreads are 10 pixels down, 0 left, 1 right, and 3 up. These are normalized through whole-frame translation in the selected runtime method.

## Candidate comparison and selection

Both candidates use exact cell extraction, nearest-neighbor sampling, and a fixed alpha threshold of 128.

| Metric | Candidate A: direct cell reduction | Candidate B: shared normalization |
| --- | --- | --- |
| SHA-256 | `b3b8ad916d9593201cfd7451a45c901fc14b10cd5272ecf76465c628f1ddb52d` | `9f692386e678528708de983463473db1fae63f72160244d52295b1af3e1be282` |
| Shared scale | Full-cell reduction | `0.170418006` for all frames |
| Painted widths | 18..22 px | 20..25 px |
| Painted heights | 43..47 px | 49..53 px |
| Horizontal centers | 18.5..20.5 | 19.0..20.0 |
| Bottommost pixels | 47..52 | 55 in all frames |
| Binary alpha | Yes | Yes |

Candidate B is selected. It is materially stronger because it preserves a larger readable silhouette, uses one shared scale across all 16 frames, and meets the common center and foot-anchor contract through translation only. Candidate A remains a review artifact and is not referenced by production resources.

## Runtime contract

| Property | Approved value |
| --- | --- |
| Runtime sheet | `assets/characters/caden/player/caden_player_runtime_v1.png` |
| SHA-256 | `9f692386e678528708de983463473db1fae63f72160244d52295b1af3e1be282` |
| Format / dimensions | RGBA `160 x 224` |
| Cell size | `40 x 56` |
| Alpha | Binary only |
| Scale | One shared factor: `0.170418006` |
| Horizontal anchor | Centers at `x=19..20`, target near `x=20` |
| Foot anchor | Bottommost pixel at row 55 in every frame |
| Project filtering | Nearest (`default_texture_filter=0`) |

`caden_player_sprite_frames_v1.tres` defines exactly eight animations:

- `idle_down`, `idle_left`, `idle_right`, `idle_up`: column 0, one frame, non-looping, 8 FPS metadata.
- `walk_down`, `walk_left`, `walk_right`, `walk_up`: columns 0 through 3, four frames, looping at 8 FPS.

## Scale-lab and Player integration

`CharacterScaleLab.tscn` now includes `Candidates/RuntimeCandidateV1` against the existing protected terrain and environment references. It displays the `40 x 56` canvas, the unchanged `24 x 24` collision overlay, and the live `walk_down` SpriteFrames cycle with integer positioning and feet aligned to the comparison baseline.

`Player.tscn` retains the original `PlaceholderVisual` as a hidden fallback and adds:

```text
Player
|- PlaceholderVisual (preserved, hidden fallback)
|- VisualRoot (0, 12)
|  `- AnimatedSprite2D (0, -28)
|- CollisionShape2D (unchanged 24 x 24)
|- Camera2D (unchanged)
|- InteractionDetector (unchanged)
|- InteractionPrompt (unchanged)
`- DialogueUI (unchanged)
```

`directional_character_visual.gd` validates the exact animation contract at runtime, switches between `idle_*` and `walk_*` without restarting an already-playing walk unnecessarily, and restores the fallback if the resource contract is invalid. `player.gd` passes its existing movement and retained facing direction into this visual-only component.

The integration preserves:

- `movement_speed = 96.0`.
- The centered `24 x 24` Player collision shape.
- Four-direction movement and facing behavior.
- Dialogue/control locking, interaction facing, camera ownership, and zone-transition behavior.
- The persistent Player architecture.

## Scope protection

No NPC source, runtime, scene, or script was added or changed. `TownSquare.tscn`, all representative environment assets, and `project.godot` retain their protected hashes. No autoload, addon, plugin, external dependency, renderer change, input-map change, environment composition change, collision change, or movement-speed change was introduced.

## V3 previews and machine-readable audit

All current review artifacts are under `docs/art/previews/caden_player_master_v3/`:

| Artifact | Purpose |
| --- | --- |
| `caden_player_source_audit_v1.json` | Full source/runtime metrics, hashes, components, gate result, and promotion record |
| `caden_player_source_grid_audit_v1.png` | Exact 4 x 4 source grid, bounds, centers, baselines, and edge flags |
| `caden_player_candidate_a_direct_v1.png` | Direct-cell candidate |
| `caden_player_candidate_b_normalized_v1.png` | Selected shared-normalization candidate |
| `caden_player_runtime_lineup_v1.png` | All frames for both methods |
| `caden_player_runtime_anchor_overlay_v1.png` | Center and row-55 anchor inspection |
| `caden_player_source_vs_runtime_v1.png` | Representative source/runtime comparison |
| `caden_player_runtime_environment_preview_v1.png` | Candidate B against protected Caden references |
| `caden_player_runtime_animation_strip_v1.png` | Four directional runtime cycles |

## Verification contract

`tests/caden_player_character_runtime_test.gd` verifies the immutable v3 and runtime hashes, source dimensions and cell boundaries, crown headroom, removed artifact, runtime binary alpha and per-frame geometry, exact SpriteFrames mappings, scale-lab anchors, Player hierarchy, collision, speed, movement animations, retained idle facing, and control-lock behavior.

`tests/caden_character_visual_spec_test.gd` now treats the Player gate as open while continuing to enforce the NPC exclusion, protected NPC/world/environment hashes, templates, scale candidates, collision overlays, and project configuration.

The complete validation record and exact command exit codes are reported in the implementation handoff for this pass.
