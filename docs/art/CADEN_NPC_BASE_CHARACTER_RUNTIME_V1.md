# Caden NPC Base Character Runtime v1

> Current integration note: the base runtime contract is unchanged, but Town Square now also uses prepared variant art for `PassingVisitor` and three ambient patrols. See `CADEN_TOWN_SQUARE_PREMIUM_OVERHAUL_V2.md`. The remainder of this document records the original base-runtime preparation and SquareLocal integration pass.

## Outcome

All mechanical gates pass, and the runtime is integrated into exactly one production NPC: `Actors/NPCs/SquareLocal` in Town Square. The character remains a noncanonical reusable development base.

The immutable v1 source initially failed the boundary gate because every up-facing crown crossed the row-3/row-4 boundary. After review authorization, a deterministic repair created a separate transparent v2 source without repainting, generating, resizing, mirroring, warping, or inventing pixels. The complete up-facing sprites were recovered from their connected pixels above and below the boundary and translated down as whole silhouettes. The v1 source remains byte-for-byte unchanged, and its failed-audit artifacts are retained under `docs/art/previews/caden_npc_base_master_v1/`.

## Protected files and hashes

| File | Before SHA-256 | Final SHA-256 | Result |
| --- | --- | --- | --- |
| `assets/source_art/caden/characters/npc/caden_npc_base_master_v1.png` | `8b284d0864199b1329ac7e448bd2712e2e414aec97e446de35da8cc70c7387cd` | `8b284d0864199b1329ac7e448bd2712e2e414aec97e446de35da8cc70c7387cd` | Unchanged |
| `assets/characters/caden/player/caden_player_runtime_v1.png` | `9f692386e678528708de983463473db1fae63f72160244d52295b1af3e1be282` | `9f692386e678528708de983463473db1fae63f72160244d52295b1af3e1be282` | Unchanged |
| `assets/characters/caden/player/caden_player_sprite_frames_v1.tres` | `60a9e29a77271b1c9c5285700e8ca3cf9d796b443d6465e3b95ee598309c1dd3` | `60a9e29a77271b1c9c5285700e8ca3cf9d796b443d6465e3b95ee598309c1dd3` | Unchanged |
| `scenes/npcs/StationaryNpc.tscn` | `c2ba9b8358c3e0ed27227d3bb93052afc463164fb5aafc64a0b5dfb62fcbe854` | `8ac15151d7844821f02d677489a4a18816362d9731d205962de0c0095037b03f` | Intended optional visual boundary |
| `scripts/npcs/stationary_npc.gd` | `8b2a0032376495184e4638b5bc86849d13b712716eabf416487b4b3f78c84e4b` | `5537245cb7568f9bf2083498b471a25f85501ff03e83de01832223f16dbccc76` | Intended optional visual behavior |
| `scenes/world/caden/TownSquare.tscn` | `af98a1d13ac14c0675968621400f21bbc9b1568be815a99b8844959b70af9781` | `e7e8016e423ee94b54f207aec38f0f6159ae94573ed55b5ce1f61a00c17b88c4` | Intended SquareLocal-only assignment |
| `project.godot` | `d7d8343041bef8aa48c4f540a5ccbb8163832d148134662a5f39252b68044990` | `d7d8343041bef8aa48c4f540a5ccbb8163832d148134662a5f39252b68044990` | Unchanged |

Player scene, Player script, Player source/runtime art, environment assets, dialogue data, other Caden zone scenes, renderer, resolution, and Input Map were not modified.

## Source audit and repair

### Immutable v1 finding

The v1 input is a `1060 x 1484` RGB PNG with a baked checkerboard and no alpha channel. It divides evenly into a `4 x 4` grid of `265 x 371` cells and contains 16 apparent frames in down, left, right, up row order and neutral/contact, step A, passing/contact, step B column order.

The initial connected-component audit found complete character art but a cross-cell placement defect. In `r3c1` through `r3c4`, disconnected crown portions touched the bottom boundary; the corresponding primary silhouettes in `r4c1` through `r4c4` touched the top boundary. The original failure and exact spill geometry remain documented in `docs/art/previews/caden_npc_base_master_v1/caden_npc_source_audit_v1.json` and its companion previews.

### Deterministic v2 repair

`tools/art/repair_caden_npc_base_master_v2.py` creates `assets/source_art/caden/characters/npc/caden_npc_base_master_v2.png`.

- v2 dimensions and mode: `1060 x 1484`, RGBA.
- v2 SHA-256: `ab7e2f000f4f26ccb1a127e588da8e633259cf14f02416f396312d07cb5b9938`.
- Alpha range: `0..255`; `1,223,261` transparent, `0` partial, `349,779` opaque pixels.
- Foreground extraction: strong when minimum RGB is below `205` or chroma exceeds `26`; four-connected primary component.
- Enclosed-detail policy: retain enclosed components up to `2,048` pixels with a three-pixel interior margin.
- Edge cleanup: three boundary-only passes remove neutral baked-checker residue with minimum RGB at least `165` and chroma at most `22`.
- Output alpha: binary; no blur, interpolation, halo, matte, or translucent clothing.
- Rows 1-3 retain their extracted whole-sprite positions.
- Up translations: `r4c1 (0,+30)`, `r4c2 (0,+30)`, `r4c3 (0,+31)`, `r4c4 (0,+31)`.
- Every up frame has 16 source pixels of transparent headroom after repair.
- All 16 cells contain one connected character; there are no boundary contacts and no reportable disconnected artifacts.

The passing v2 audit reports source widths `97..142`, heights `258..274`, horizontal centers `91.5..163.5`, bottommost pixels `281..366`, and headroom `16..97`. Within-direction source baseline spreads are one pixel down, six left, three right, and six up. The only close boundary approach is the down row, whose boots retain four to five source pixels below them.

### Per-frame repaired source geometry

Bounds are cell-local and right/bottom exclusive.

| Frame | Direction / pose | Source strong bbox | Size | Center x | Bottom | Headroom |
| --- | --- | --- | --- | ---: | ---: | ---: |
| `r1c1` | down / neutral | `(93,97)-(235,367)` | `142x270` | 163.5 | 366 | 97 |
| `r1c2` | down / step A | `(72,93)-(210,367)` | `138x274` | 140.5 | 366 | 93 |
| `r1c3` | down / passing | `(57,94)-(196,366)` | `139x272` | 126.0 | 365 | 94 |
| `r1c4` | down / step B | `(31,95)-(166,367)` | `135x272` | 98.0 | 366 | 95 |
| `r2c1` | left / neutral | `(104,67)-(204,332)` | `100x265` | 153.5 | 331 | 67 |
| `r2c2` | left / step A | `(84,65)-(199,326)` | `115x261` | 141.0 | 325 | 65 |
| `r2c3` | left / passing | `(69,67)-(166,331)` | `97x264` | 117.0 | 330 | 67 |
| `r2c4` | left / step B | `(41,65)-(151,326)` | `110x261` | 95.5 | 325 | 65 |
| `r3c1` | right / neutral | `(110,30)-(207,293)` | `97x263` | 158.0 | 292 | 30 |
| `r3c2` | right / step A | `(81,32)-(196,290)` | `115x258` | 138.0 | 289 | 32 |
| `r3c3` | right / passing | `(67,30)-(167,293)` | `100x263` | 116.5 | 292 | 30 |
| `r3c4` | right / step B | `(40,32)-(147,293)` | `107x261` | 93.0 | 292 | 32 |
| `r4c1` | up / neutral | `(93,16)-(221,282)` | `128x266` | 156.5 | 281 | 16 |
| `r4c2` | up / step A | `(74,16)-(201,287)` | `127x271` | 137.0 | 286 | 16 |
| `r4c3` | up / passing | `(52,16)-(181,283)` | `129x267` | 116.0 | 282 | 16 |
| `r4c4` | up / step B | `(27,16)-(157,288)` | `130x272` | 91.5 | 287 | 16 |

## Identity and animation audit

All frames depict the same ordinary adult development character. Hair, head construction, body build, cream sleeves, muted moss/olive clothing, brown belt, dark trousers, practical boots, skin tone, and upper-left lighting remain consistent. No Player mantle or satchel is present. No weapon, armor, occupational tool or uniform, merchant goods, heraldry, religious mark, Festival symbol, Edenite, faction insignia, or species-defining anatomy is visible.

All four directions are present. Left and right are separately authored rather than lighting-reversing mirrors. The up row is back-facing with no front facial detail. Each direction contains a neutral/contact pose, step A, passing/contact, and step B. Alternating limbs are apparent, and no pose reads as a run. Static previews show no severe scale pulse, head jump, or palette change; live cycle review remains required for final artistic approval.

## Candidate preparation and selected runtime

Candidate A reduces each complete `265 x 371` cell directly to `40 x 56` with nearest-neighbor sampling. Its source placement drift produces a smaller, inconsistent gameplay figure, so it was rejected. Candidate A SHA-256 is `ed905d62e4f45ca657d20cc6773b889d0d897605042ec10a48fac4e948c15ea4`.

Candidate B crops each complete primary silhouette, uses one shared scale of `0.193430657`, resizes with nearest-neighbor only, then applies translation-only horizontal centering and row-55 feet alignment. It was selected because it preserves anatomy and animation amplitude while matching Player height, pixel density, frame occupancy, and bottom-center anchoring. It remains less saturated and visually distinct from the rust-mantled, satchel-bearing Player.

Production runtime:

- Path: `assets/characters/caden/npc/caden_npc_base_runtime_v1.png`.
- SHA-256: `3cba56af2257f09f6c6e7f8ba0789e93a90d0e69f18ac271421ccb1f8354840c`.
- Sheet: `160 x 224` RGBA, four columns by four rows.
- Frame: `40 x 56`; mathematical anchor `(20,56)`; feet row 55.
- Alpha: binary; every frame has transparent top and side padding.
- Runtime painted width range: `19..27`; height range: `50..53`.
- All 16 frames end on row 55; no cell contains neighboring-frame contamination.

### Runtime placement table

The paste translation is the integer placement of the complete shared-scale silhouette inside its `40 x 56` cell.

| Frame | Runtime visible bbox | Paste translation |
| --- | --- | --- |
| `r1c1` | `(6,4)-(33,56)` | `(6,4)` |
| `r1c2` | `(6,3)-(33,56)` | `(6,3)` |
| `r1c3` | `(6,3)-(33,56)` | `(6,3)` |
| `r1c4` | `(7,3)-(33,56)` | `(7,3)` |
| `r2c1` | `(10,5)-(29,56)` | `(10,5)` |
| `r2c2` | `(9,6)-(31,56)` | `(9,6)` |
| `r2c3` | `(10,5)-(29,56)` | `(10,5)` |
| `r2c4` | `(10,6)-(31,56)` | `(10,6)` |
| `r3c1` | `(10,5)-(29,56)` | `(10,5)` |
| `r3c2` | `(9,6)-(31,56)` | `(9,6)` |
| `r3c3` | `(10,5)-(29,56)` | `(10,5)` |
| `r3c4` | `(10,6)-(31,56)` | `(10,6)` |
| `r4c1` | `(8,5)-(33,56)` | `(8,5)` |
| `r4c2` | `(8,4)-(33,56)` | `(8,4)` |
| `r4c3` | `(8,4)-(33,56)` | `(8,4)` |
| `r4c4` | `(8,3)-(33,56)` | `(8,3)` |

## SpriteFrames contract

`assets/characters/caden/npc/caden_npc_base_sprite_frames_v1.tres` uses the one runtime sheet as its only texture source. It defines exactly `idle_down`, `idle_left`, `idle_right`, `idle_up`, `walk_down`, `walk_left`, `walk_right`, and `walk_up`. Idle animations use column 1, contain one frame, and do not loop. Walk animations use columns 1-4, contain four frames, loop, and run at 8 FPS. No additional states were added.

## CharacterScaleLab and Player comparison

`CharacterScaleLab.tscn` now shows the approved Player runtime at `(80,340)` and NPC runtime at `(144,340)`, both on `40 x 56` canvases with integer positioning. The Player retains its existing `24 x 24` collision overlay; the NPC shows its preserved `20 x 20` stationary collision. Existing door, bench, lantern, Edenite fixture, medium tree, grass, road, and plaza references remain.

The static 640x360 comparisons show compatible adult apparent height, head/body proportion, hands, feet, pixel density, feet anchor, and Caden-environment readability. The green-tunic NPC is clearly different from the Player and has no accidental identity-bearing detail. Godot import and a headless ScaleLab launch pass, but these checks are not live visual approval.

## Reusable StationaryNpc architecture

The `StaticBody2D` root, `PlaceholderVisual`, `FacingMarker`, `CollisionShape2D`, `Interactable`, dialogue API, and signal connection are preserved. The base scene adds:

```text
StationaryNpc
|- PlaceholderVisual          (existing fallback)
|- FacingMarker               (existing fallback)
|- VisualRoot                 position (0,10)
|  `- AnimatedSprite2D        position (0,-28)
|- CollisionShape2D           existing 20x20 rectangle
`- Interactable               existing radius-32 area
```

The root exports optional `character_sprite_frames` and `character_visual_enabled` fields. Both default to unconfigured/false, so existing NPC instances retain their rectangles and markers. When enabled with a valid eight-animation resource, the script hides the fallback, selects the one-frame directional idle from the existing facing value, and stops playback. The facing setter normalizes runtime/editor assignments to a cardinal direction and updates the idle without a `_process()` loop. No movement, pathfinding, schedule, manager, registry, autoload, or AnimationTree was added.

## Historical v1 SquareLocal-only integration

SquareLocal remains at `Actors/NPCs/SquareLocal`, position `(288,448)`, facing right `(1,0)`, with the same `square_local_resident.tres` dialogue, speaker name `Local`, prompt text `Talk`, `20 x 20` collision, and radius-32 interaction area.

It alone sets `character_visual_enabled = true` and assigns the NPC SpriteFrames. The resulting animation is static `idle_right`; the orange rectangle and marker remain present as hidden fallbacks. `VisualRoot (0,10)` plus sprite position `(0,-28)` places the bottom of the `40 x 56` frame at local y=10, exactly the bottom of the centered 20x20 collision. No scale or fractional offset is used.

Town Square terrain uses z-indices 1-3. An actual renderer capture showed that the default z-index placed the NPC beneath those terrain layers, so SquareLocal alone now uses z-index 10, matching the existing Player layer. This is the smallest local layering correction and leaves every other NPC instance unchanged. The prompt and dialogue UI remain CanvasLayer-based and render above the world.

Focused tests instantiate all five Caden zones and confirm that exactly one of 11 NPCs has runtime art; the other ten placeholders and markers remain visible. They also unload Town Square, verify SquareLocal and its interaction area are freed, return, and verify the visual, prompt connection, dialogue assignment, and idle direction are restored.

## Validation artifacts

Current artifacts are under `docs/art/previews/caden_npc_base_runtime_v1/`:

- `caden_npc_source_audit_v1.json`: complete machine-readable v2 source, component, candidate, placement, and hash data.
- `caden_npc_source_grid_audit_v1.png`: 4x4 boundaries, strong bounds, headroom, centers, bottoms, and flags.
- `caden_npc_candidate_a_direct_v1.png` and `caden_npc_candidate_b_normalized_v1.png`: deterministic method comparison.
- `caden_npc_runtime_lineup_v1.png`: all 16 frames at native and nearest-neighbor enlarged scales.
- `caden_npc_runtime_anchor_overlay_v1.png`: canvas, anchor, feet line, collision, and overhang.
- `caden_npc_source_vs_runtime_v1.png`: representative repaired-source and runtime comparison.
- `caden_npc_player_scale_comparison_v1.png`: Player/NPC and environmental scale comparison.
- `caden_npc_environment_preview_v1.png`: CharacterScaleLab-style environment review.
- `caden_npc_runtime_animation_strip_v1.png`: all four directional cycles.
- `caden_npc_square_local_preview_v1.png`: actual Godot Compatibility-renderer capture of integrated SquareLocal in the unmodified Town Square composition.

The original failed v1 audit and preview set are preserved separately under `docs/art/previews/caden_npc_base_master_v1/`.

## Gates, known defects, and manual review

Mechanical source, runtime, ScaleLab, and integration gates pass. No failure gate remains active. Known limitations are visual-review items rather than detected contract failures:

- The immutable v1 source still has its baked checker and cross-row crowns by design; v2 is the repair source of truth.
- Deterministic threshold extraction can only preserve pixels distinguishable from the baked checker. Inspect fine pale sleeve, skin, and hair-edge details at high zoom.
- Side views are naturally narrower than down/up views; confirm that this reads as perspective rather than scale pulsing.
- Automated stills cannot approve stride timing, foot sliding, clothing/hair flicker, upper-left lighting, overlap readability, prompt visibility during play, or collision feel.

Recommended Aseprite follow-up is optional polish, not a gate repair: inspect v2 at native pixels for neutral edge loss or checker fringe; if hand-edited, preserve the exact 4x4 grid, shared scale intent, binary alpha, row-55 runtime baseline, and immutable v1 history, then rerun both preparation and focused tests.

Live Godot review at 640x360 remains required for NPC/Player/door scale, adult proportions, head size, grass/plaza/wall contrast, foot anchor, four idles, four walk cycles, left/right lighting, clothing and hair flicker, Player approach and overlap, collision feel, prompt and dialogue behavior, roofs/canopies, alpha halos, source-frame clipping, accidental canon detail, and whether the base remains generic enough for reuse.

## Verification record

| Validation | Exit code | Result |
| --- | ---: | --- |
| Python syntax validation for both NPC tools | 0 | Pass |
| Deterministic v2 repair, first and second runs | 0 / 0 | Pass; identical v2 SHA-256 |
| Runtime preparation, first and second runs | 0 / 0 | Pass; every runtime/audit/preview hash identical |
| Preparation with `--strict-gate` and runtime promotion | 0 | Pass; source gate open, no affected frames |
| Godot 4.7.2 editor/import | 0 | Pass |
| Actual Town Square 640x360 Compatibility-renderer capture | 0 | Pass |
| `caden_architecture_runtime_test.gd` | 0 | Pass |
| `caden_architecture_runtime_v1_1_test.gd` | 0 | Pass |
| `caden_character_visual_spec_test.gd` | 0 | Pass |
| `caden_edenite_festival_runtime_test.gd` | 0 | Pass |
| `caden_nature_runtime_test.gd` | 0 | Pass |
| `caden_npc_base_character_runtime_test.gd` | 0 | Pass, including runtime facing change and zone reload |
| `caden_player_character_runtime_test.gd` | 0 | Pass |
| `caden_population_test.gd` | 0 | Pass |
| `caden_props_runtime_test.gd` | 0 | Pass |
| `caden_terrain_runtime_test.gd` | 0 | Pass |
| `caden_terrain_runtime_v1_1_test.gd` | 0 | Pass |
| `caden_town_square_environmental_dressing_test.gd` | 0 | Pass |
| `caden_zone_transition_test.gd` | 0 | Pass; transitions, Player persistence, camera limits |
| `dialogue_foundation_test.gd` | 0 | Pass |
| `interaction_foundation_test.gd` | 0 | Pass |
| `opening_objective_test.gd` | 0 | Pass |
| CharacterScaleLab headless launch | 0 | Pass |
| Main-project headless launch | 0 | Pass |
| Scene/resource parsing | 0 | Pass through import, launches, and preload-heavy tests |
| `git diff --check` | 0 | Pass |

Automated results do not replace the live review above. No commit was created.
