# Caden Player Character Master v2 Audit

## Outcome

**Source-art quality gate: failed. Runtime integration gate: not entered.**

The v2 sheet does not correct the source-boundary problem. All four up-facing frames have their primary connected hair silhouettes cut by the top edge of their `265 x 371` cells. The boundary contains 40 to 48 strong-opacity hair pixels per frame, so this is not removable low-alpha noise. Missing hair pixels cannot be reconstructed with the allowed deterministic operations.

The right-facing row also contains six separate strong-alpha components at the bottom edge. These are spatially separated from the character silhouettes and can be removed deterministically, but cleaning them does not repair the up row.

No production runtime PNG, `SpriteFrames` resource, scale-lab edit, Player scene edit, Player script edit, or visual-controller script was created.

## Source protection

The supplied Downloads file remains unchanged:

`C:/Users/AKHOURY/Downloads/caden_player_character_master_v2.png.png`

A byte-identical canonical repository copy was created without changing the supplied file:

`assets/source_art/caden/characters/player/caden_player_character_master_v2.png`

| Check | Result |
| --- | --- |
| Source size | 1,046,548 bytes |
| Downloads SHA-256 before copy | `9b3226a1c2821f7e7bd0c082626e30198a38fa90dc373e64ceab7012939bb71d` |
| Repository copy SHA-256 | `9b3226a1c2821f7e7bd0c082626e30198a38fa90dc373e64ceab7012939bb71d` |
| Supplied-file transformation | None |

## Source audit

| Property | Finding |
| --- | --- |
| Format / mode | PNG / RGBA |
| Dimensions | `1060 x 1484` |
| Alpha range | `0..255` |
| Fully transparent | 1,024,875 pixels (`65.152507%`) |
| Partially transparent | 547,604 pixels (`34.811829%`) |
| Fully opaque | 561 pixels (`0.035663%`) |
| Grid | Exact `4 x 4` |
| Source cell | `265 x 371` |
| Nonempty frames | 16 of 16 at alpha >= 128 |
| Apparent row order | Down, left, right, up |
| Apparent column order | Neutral/contact, step A, passing/contact, step B |
| Identity continuity | Same development-traveler silhouette, clothing, hair, boots, and satchel |
| Canon guardrail | No weapon, magic, heraldry, Festival symbol, species trait, or profession marker identified |

The sheet's direction and pose order are usable. The blocking issue is missing image content at the up-row boundary, not missing frames or uncertain mapping.

## Boundary and contamination findings

| Frame | Direction / pose | Primary strong bbox | Strong pixels on boundary | Finding |
| --- | --- | --- | ---: | --- |
| `r4c1` | up / neutral | `(56,0)-(202,281)` | 40 top | Connected hair is clipped |
| `r4c2` | up / step A | `(55,0)-(198,280)` | 48 top | Connected hair is clipped |
| `r4c3` | up / passing | `(44,0)-(188,281)` | 40 top | Connected hair is clipped |
| `r4c4` | up / step B | `(45,0)-(191,281)` | 41 top | Connected hair is clipped |

All four right-facing primary silhouettes also approach the top boundary: `r3c1`, `r3c2`, and `r3c3` have 4 pixels of top clearance; `r3c4` has 6.

Separate bottom-edge components, excluded from primary-character bounds:

| Frame | Component pixels | Source bbox | Bottom-edge pixels |
| --- | ---: | --- | ---: |
| `r3c1` | 366 | `(110,360)-(152,371)` | 39 |
| `r3c2` | 322 | `(99,360)-(140,371)` | 39 |
| `r3c3` | 125 | `(109,365)-(135,371)` | 26 |
| `r3c3` | 97 | `(93,362)-(106,371)` | 13 |
| `r3c4` | 188 | `(109,362)-(136,371)` | 25 |
| `r3c4` | 93 | `(94,362)-(108,371)` | 14 |

The audit preview draws greater-than-zero alpha bounds in amber, primary strong-alpha bounds in green, centers in cyan, bottommost primary pixels in red, and clipped-cell notices at the affected edges.

## Frame consistency and feet baselines

Primary strong-alpha widths range from `121..149` pixels. Heights range from `280..300` pixels. The up row is systematically shorter (`280..281`) because its hair is truncated at the cell boundary.

| Direction | Primary bottommost pixels | Spread |
| --- | --- | ---: |
| Down | 332, 342, 336, 342 | 10 px |
| Left | 320, 317, 319, 318 | 3 px |
| Right | 300, 299, 302, 300 | 3 px |
| Up | 280, 279, 280, 280 | 1 px |

Translation can normalize these baselines. It cannot recover the missing hair.

## Candidate methods

Both candidates use nearest-neighbor sampling only. Neither uses bilinear, bicubic, Lanczos, mirroring, generative fill, repainting, or per-frame scale factors.

### Candidate A: exact-cell reduction

- Exact `265 x 371` cells reduced to `40 x 56`.
- Fixed binary alpha threshold at 128.
- No content translation.
- Review sheet: RGBA `160 x 224`; 25,941 transparent, 0 partial-alpha, and 9,899 opaque pixels.
- SHA-256: `b7feda390a1e8991993111a565e6e2bab7e92edca5974b551458a9b48b159ad1`.
- Painted heights are `42..45` pixels and direction-dependent feet remain on rows 41 through 51, so the runtime row-55 anchor is not met.

### Candidate B: shared-content normalization

- Largest connected strong-alpha component retained per frame.
- One shared scale: `0.176666667`.
- Translation-only center and feet alignment.
- Fixed binary alpha threshold at 128.
- Review sheet: RGBA `160 x 224`; 22,295 transparent, 0 partial-alpha, and 13,545 opaque pixels.
- SHA-256: `7fca3bfaca116a1b62785c8f4dc91e22390cfdc6fac553e72b64bb9767cf9f96`.
- Painted widths are `21..26` pixels and heights are `49..53` pixels.
- All bottommost pixels land on row 55; horizontal centers are `19.0..20.0`.

Candidate B is mechanically superior, but the up-facing hair remains visibly flat because the source pixels do not exist. No production method is selected.

## Review artifacts

The v2 rerun is isolated under `docs/art/previews/caden_player_master_v2/`:

- `caden_player_source_grid_audit_v1.png`
- `caden_player_runtime_lineup_v1.png`
- `caden_player_runtime_anchor_overlay_v1.png`
- `caden_player_source_vs_runtime_v1.png`
- `caden_player_runtime_environment_preview_v1.png`
- `caden_player_runtime_animation_strip_v1.png`
- `caden_player_candidate_a_direct_v1.png`
- `caden_player_candidate_b_normalized_v1.png`
- `caden_player_source_audit_v1.json`

The JSON audit contains every frame bbox, component, center, baseline, alpha count, generated hash, and gate finding.

## Integration status

- `assets/characters/caden/player/caden_player_runtime_v1.png`: not created.
- `assets/characters/caden/player/caden_player_sprite_frames_v1.tres`: not created.
- `tests/caden_player_character_runtime_test.gd`: not created because no approved runtime exists.
- `scenes/development/CharacterScaleLab.tscn`: unchanged.
- `scenes/Player.tscn`: unchanged.
- `scripts/player.gd`: unchanged.
- Player collision: unchanged, centered `24 x 24`.
- Player movement speed: unchanged at `96.0`.
- NPC scenes/scripts and Town Square composition: unchanged.
- Environment assets and `project.godot`: unchanged.

## Required correction

1. Move the entire up row downward within its cells using uncropped source frames, leaving clear transparent space above the complete hair silhouette.
2. If the current image is already clipped before placement, recover or regenerate all four up-facing frames; padding alone cannot restore the missing hair.
3. Remove the six separated bottom-edge components from `r3c1` through `r3c4`.
4. Preserve the same scale, four-direction order, four-pose order, traveler identity, lighting, and palette.
5. Re-export an exact RGBA `1060 x 1484` master and repeat the gate before runtime preparation.

Manual Aseprite correction is sufficient only if uncropped up-facing originals exist. Otherwise, all four up-facing frames require targeted replacement. A full-sheet regeneration is unnecessary unless matching replacements cannot be produced consistently.

## Validation record

Final validation used Godot `4.7.2-stable` in an isolated project copy.

| Validation | Exit / result |
| --- | --- |
| Preparation tool, normal audit mode | Exit 0; gate recorded as failed |
| Preparation tool, strict gate mode | Exit 2; expected gate-failure signal |
| Deterministic regeneration | Exit 0; 0 mismatches across both candidates, six previews, and JSON audit |
| Python source compilation | Exit 0 |
| v2 artifact contract | Exit 0 |
| Downloads/repository source hash comparison | Exit 0; identical |
| Protected production/environment hash check | Exit 0; 0 mismatches |
| Godot editor/import validation | Exit 0 |
| Headless project launch | Exit 0 |
| `git diff --check` | Exit 0 |

All 14 existing executable Godot test scripts passed independently with exit 0: character visual specification, both terrain generations, both architecture generations, nature, props, Edenite/Festival, Town Square environmental dressing, zone transition/persistence/camera, interaction, dialogue, population, and opening objective. The final suite reported 14 passed, 0 failed, and 0 Godot errors.

The focused Player runtime test was not created or run because v2 failed the prerequisite source-art gate and no production runtime resource exists.
