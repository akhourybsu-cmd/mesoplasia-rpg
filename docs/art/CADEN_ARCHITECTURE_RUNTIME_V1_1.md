# Caden Architecture Runtime v1.1

## Purpose and manual-review findings

Runtime v1.1 is a non-destructive architecture polish derivative. Manual review of Runtime v1 at the `640 x 360` internal resolution found visible roof-to-façade separation, background showing through the join, floating roofs, broad unstructured plaster bands, shallow eaves, similar silhouettes, mechanical dark roof divisions, and weak ground contact.

This pass corrects those presentation problems while preserving the five locked building bodies, collision rectangles, scene centers, sprite anchors, routes, terrain, NPCs, interaction, dialogue, objective behavior, camera bounds, and zone transitions. The buildings remain generic, unnamed, visual-only exteriors.

## Protected inputs

| Protected file | Dimensions | SHA-256 before preparation |
| --- | ---: | --- |
| `assets/source_art/caden/architecture/caden_architecture_master_v1.png` | 1448×1086 | `82b60c3b0935e284b602f2a04713d7e4cf84ec4770bc7229ea80aeedc9195bf8` |
| `assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png` | 256×256 | `bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a` |
| `project.godot` | — | `b560718fd3141c70c318a2843b409b95490b876c139bd77104c125ce181c91f0` |

Runtime v1 is also protected for comparison and rollback:

| Runtime v1 file | SHA-256 before preparation |
| --- | --- |
| `town_square_building_northwest_v1.png` | `f493d5ac99bb9c81e04f940244c6e79fdabad1f2303abea8f3557ae58048418f` |
| `town_square_building_southwest_v1.png` | `e8d418c26653085d63f8bb434068908f3368508a33ae467346ce44a13adfb335` |
| `town_square_building_northeast_v1.png` | `023082b67d5924c542c250c5080f35410a3c5c9b69a5ca5cc9e6534b100b1460` |
| `town_square_building_southeast_v1.png` | `cd0e3baaf0ad75ca29b94d2651c0ad7af746bf9db5cbdb3e8c07d71bed63d1dd` |
| `town_square_building_south_v1.png` | `bcd2289ef3685ac2205664fd90ce617657624be48641a9026b69baef64ec7456` |

The v1.1 script verifies every listed hash before writing output. It never writes to the source master, Runtime v1, Terrain Runtime v1/v1.1, or `project.godot`.

## Reproducible preparation

Run:

```powershell
python tools/art/prepare_caden_architecture_runtime_v1_1.py
```

Use `--prototype-only` for the northwest 5×3 failure-gate candidate. The script reuses the reviewed source-extraction helpers from `prepare_caden_architecture_runtime_v1.py`; no library or dependency was added.

## Source crops and composites

Runtime v1.1 uses the same protected source lineage as Runtime v1. Crop rectangles are `(left, top, right, bottom)` source pixels:

| Component | Source crop |
| --- | --- |
| Slate-blue roof A | `(13, 5, 109, 101)` |
| Slate-blue roof B | `(119, 5, 215, 101)` |
| Clay roof | `(225, 5, 321, 101)` |
| Moss-green roof | `(332, 5, 428, 101)` |
| Warm-brown roof | `(438, 5, 534, 101)` |
| Plain timber/plaster wall | `(13, 282, 109, 378)` |
| Braced timber/plaster wall | `(119, 282, 215, 378)` |
| Window wall A | `(225, 282, 321, 378)` |
| Window wall B | `(332, 282, 428, 378)` |
| Natural-stone foundation | `(973, 282, 1069, 378)` |
| Door A | `(13, 400, 109, 544)` |
| Door B | `(119, 400, 215, 544)` |
| Door C | `(225, 400, 321, 544)` |
| Door D | `(332, 400, 428, 544)` |
| Door E | `(438, 400, 534, 544)` |

Every component is reduced exactly 3:1 with nearest-neighbor sampling. Roof fill uses the cleaned interior of its corresponding roof component over a color sampled from that same component. This removes the strongest repeated crop-edge dividers without introducing a replacement texture. Timber/eave pixels use the existing braced-wall palette. Small upper windows are unscaled 16×16 crops from the already reduced window component.

No source piece is rotated, mirrored, blurred, interpolated, or non-integer scaled. Alpha cleanup remains binary at threshold `112`. Palette harmonization remains saturation `0.90`, value `0.95`, and contrast `0.90`, inherited from Runtime v1 source extraction.

## Runtime sprite manifest

All façades remain south-facing and use the existing local sprite anchor `(0, -16)`.

| Identifier | Runtime v1.1 file | Canvas | Locked center | Collision | Roof/façade overlap | Join scan region |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Generic Exterior A | `town_square_building_northwest_v1_1.png` | 192×160 | `(144,112)` | 160×96 | 6 px | `(20,65)` to `(171,70)` |
| Generic Exterior B | `town_square_building_southwest_v1_1.png` | 192×160 | `(144,560)` | 160×96 | 4 px | `(20,65)` to `(171,68)` |
| Generic Exterior C | `town_square_building_northeast_v1_1.png` | 160×160 | `(832,208)` | 128×96 | 6 px | `(20,65)` to `(139,70)` |
| Generic Exterior D | `town_square_building_southeast_v1_1.png` | 192×160 | `(816,560)` | 160×96 | 6 px | `(20,65)` to `(171,70)` |
| Generic Exterior E | `town_square_building_south_v1_1.png` | 160×128 | `(352,624)` | 128×64 | 4 px | `(20,55)` to `(139,58)` |

The join scan regions are fully opaque across the façade width. They provide a stable technical boundary for detecting a reintroduced transparent roof gap without locking decorative pixels or roof colors.

Ground-contact lines remain y=`144` for A–D and y=`112` for E. The runtime canvases, collision centers, collision dimensions, and `(0,-16)` scene offsets are unchanged from v1.

## Eaves and upper façades

Each building receives a five-pixel-deep, source-palette timber eave at the lower roof edge. The eave overlaps the connected upper façade, has a restrained highlight on its upper edge, and remains well above doors and approach space.

The former blank upper plaster band is divided by:

- a dark roof-support beam directly below the eave;
- a secondary horizontal timber beam;
- full-height posts aligned to the 32-pixel façade bays;
- building-specific diagonal brace patterns;
- a small source-derived upper window on A and C.

The framing implies modest roof support or loft space rather than a complete additional story.

## Silhouette and component decisions

| Identifier | Roof and silhouette | Door/windows | Porch/steps | Chimney | Upper-façade distinction |
| --- | --- | --- | --- | --- | --- |
| A | Slate-blue roof, centered modest front gable, 10 px side overhang | Centered door, 2 lower windows, 1 small upper window | 48 px porch | Left | Symmetric braces beneath the centered gable |
| B | Moss roof, slightly left-biased ridge, simple uninterrupted roof, 8 px overhang | Offset door, 2 lower windows | Broad 64 px porch | None | Straight post-and-beam rhythm without a front gable |
| C | Compact clay roof, centered front gable, 12 px overhang | Compact offset door, 2 lower windows, 1 small upper window | 40 px porch | Right | Tighter symmetric framing suited to the 4×3 footprint |
| D | Wide slate-blue roof, right-offset front gable, 10 px overhang | Right-offset door, 2 lower windows | 48 px porch | Left | Asymmetric brace pattern and gable placement |
| E | Smallest warm-brown roof, simple centered ridge, 6 px overhang | Offset door, 1 lower window | Minimal 32 px steps | None | Simple shallow central brace with no upper window or gable |

Roof divisions are spaced at approximately 48 pixels and use a source-derived mid-dark value. This replaces the high-contrast divider at every repeated source segment while retaining readable construction scale. Roof pitch, three-quarter projection, and upper-left lighting stay consistent.

## Grounding and contact shadows

The existing scene-level `ContactShadow` nodes remain visual-only `Polygon2D` shapes, but v1.1 tightens them against each foundation and moves their short tail toward the lower-right. They use crisp edges, a restrained warm-dark alpha, no blur, no physics, and no script. The shadow extends only five pixels past the collision footprint’s south edge and does not occupy an exit, NPC position, prompt, or primary route.

Foundations and porch steps retain their original ground-contact coordinates. Collision continues to come exclusively from the existing rectangle shapes.

## Scene integration and rollback

`TownSquare.tscn` references only the five v1.1 textures for visible architecture. Runtime v1 PNGs remain present and unchanged for comparison or a simple path rollback. The five hidden brown `DevelopmentFallback` polygons and hidden building development labels remain in the scene. No v1 and v1.1 pair is rendered simultaneously.

## Validation previews

- `docs/art/previews/caden_architecture_runtime_v1_1_lineup.png`
- `docs/art/previews/caden_architecture_runtime_v1_1_footprint_overlay.png`
- `docs/art/previews/caden_architecture_v1_vs_v1_1_comparison.png`
- `docs/art/previews/caden_architecture_runtime_v1_1_town_square_preview.png`

These are documentation artifacts only. They intentionally omit nature, props, Edenite, Festival decoration, and character art.

## Excluded source material

Signs, business fixtures, banners, symbols, heraldry, flower boxes, free-standing props, fences, gates, barrels, sacks, smoke, pipes, lamps, vegetation, Edenite, and Festival material remain excluded. No structure receives an identity, function, occupant, ownership, or lore.

## Known limitations and manual cleanup candidates

- The deterministic roof material still retains recognizable horizontal shingle repetition from the source crop.
- Front-gable joins are clean and reproducible but could benefit from hand-tuned ridge pixels.
- Chimney-to-roof contact remains assembled rather than hand-pixelled.
- Timber bays remain deliberately regular because they align with the 32-pixel construction grid.
- The compact E façade has limited room for additional variation without harming door scale.
- Contact shadows require final judgment with actual Player and NPC sprites rather than placeholders.

Potential Aseprite cleanup should be limited to ridge joins, chimney contacts, isolated hard-alpha edge pixels, subtle shingle repetition, and non-symbolic timber variation. It must not change footprint alignment, lighting, door approaches, or collision expectations.

## Manual-review checklist

- [ ] Roof and façade read as one connected structure on all five buildings
- [ ] No grass or background appears at any roof/eave join during camera movement
- [ ] Eave depth reads clearly without hiding windows or doors
- [ ] Upper framing reduces plaster emptiness without suggesting an oversized second story
- [ ] Front-gable placement and roof ridges produce sufficient silhouette variation
- [ ] Repeated roof divisions no longer appear fence-like
- [ ] Player-to-door and NPC-to-window scale at `640 x 360`
- [ ] Porch and step scale against locked collision
- [ ] Chimney size, contact, and upper-left lighting
- [ ] Foundation and contact-shadow grounding on grass, road, and plaza edges
- [ ] Building separation from terrain in full color, grayscale, and reduced saturation
- [ ] All four connections, plaza circulation, and northeastern Terrebonne branch remain clear
- [ ] Reserved 3×3 community space remains open and undefined
- [ ] NPC approach areas and prompts remain unobscured
- [ ] Collision-to-art relationship remains predictable
- [ ] No boundary clipping, haloing, matte, or partial-alpha artifact
- [ ] Overall architectural cohesion at the internal viewport

Automated validation establishes technical integrity, not visual approval.
