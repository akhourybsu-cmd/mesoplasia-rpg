# Caden Architecture Runtime v1

## Scope

This pass prepares five generic, visual-only building exteriors for the locked Town Square footprints. It proves the shared Caden architecture language at gameplay scale; it does not define occupants, functions, ownership, interiors, door interactions, or world canon.

## Protected inputs

| Input | Dimensions | SHA-256 before preparation |
| --- | ---: | --- |
| `assets/source_art/caden/architecture/caden_architecture_master_v1.png` | 1448×1086 | `82b60c3b0935e284b602f2a04713d7e4cf84ec4770bc7229ea80aeedc9195bf8` |
| `assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png` | 256×256 | `bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a` |

The preparation script verifies both hashes before writing output. These inputs and all other source-art and terrain runtime files are read-only for this pass.

## Reproducible preparation

Run:

```powershell
python tools/art/prepare_caden_architecture_runtime_v1.py
```

The failure-gate prototype can be generated independently with `--prototype-only`. The script uses Pillow already available in the workspace runtime and installs no dependencies.

### Source-component crops

Crop rectangles use `(left, top, right, bottom)` source pixels. Every selected crop has dimensions divisible by three and is reduced exactly 3:1 with nearest-neighbor sampling.

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

The script assembles these reduced pieces into a deterministic shared construction vocabulary. Roof courses, timber/plaster bays, door bays, window bays, foundations, ridges, restrained steps/porches, and optional chimneys are composed without rotating, mirroring, or non-integer scaling any selected source crop. Small seam and grounding pixels use colors sampled from the selected source material, not invented iconography.

### Image processing

- Scaling: exact 3:1 nearest-neighbor reduction.
- Palette harmonization: saturation multiplier `0.90`, value multiplier `0.95`, and contrast multiplier `0.90` on extracted components.
- Edge and alpha cleanup: alpha values below `112` become transparent and all remaining pixels become fully opaque. Runtime silhouettes therefore contain only alpha `0` or `255`, avoiding partial-alpha halos and presentation mattes.
- Lighting and perspective: all source pieces retain their original orientation, slight three-quarter projection, and upper-left lighting.
- Runtime canvases: transparent and divisible by 32.

## Runtime buildings

All façades face south. This preserves one shared perspective and lighting direction; doors remain visually approachable from open ground even where a building does not directly face the plaza.

| Identifier | Runtime file | Canvas | Locked center | Collision / tiles | Ground line | Roof | Door | Windows | Porch/steps | Chimney |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- | ---: | --- | --- |
| Generic Exterior A | `assets/environments/caden/architecture/town_square/town_square_building_northwest_v1.png` | 192×160 | `(144, 112)` | 160×96 / 5×3 | y=144 | slate blue A | centered | 2 | 48 px, modest | small, left |
| Generic Exterior B | `assets/environments/caden/architecture/town_square/town_square_building_southwest_v1.png` | 192×160 | `(144, 560)` | 160×96 / 5×3 | y=144 | moss green | slightly left of center | 2 | 64 px, broad | none |
| Generic Exterior C | `assets/environments/caden/architecture/town_square/town_square_building_northeast_v1.png` | 160×160 | `(832, 208)` | 128×96 / 4×3 | y=144 | muted clay | slightly right of center | 2 | 40 px, compact | small, right |
| Generic Exterior D | `assets/environments/caden/architecture/town_square/town_square_building_southeast_v1.png` | 192×160 | `(816, 560)` | 160×96 / 5×3 | y=144 | slate blue B | right of center | 2 | 48 px, modest | small, left |
| Generic Exterior E | `assets/environments/caden/architecture/town_square/town_square_building_south_v1.png` | 160×128 | `(352, 624)` | 128×64 / 4×2 | y=112 | warm brown | slightly right of center | 1 | 32 px, minimal | none |

The five files combine the roof, wall, door, window, and foundation crops listed above according to their row. A uses slate-blue A/plain/window A/door A; B uses moss/braced/window B/door B; C uses clay/plain/window A/door C; D uses slate-blue B/braced/window B/door D; E uses warm-brown/plain/window A/door E. Each building uses the shared stone-foundation crop.

## Placement and anchoring

- The existing `StaticBody2D` remains centered on its locked collision footprint.
- Each `ExteriorSprite` is centered horizontally and placed at local `(0, -16)`.
- The runtime ground-contact line therefore aligns with the collision footprint’s south edge: local y=`48` for the 5×3 and 4×3 footprints, and local y=`32` for the 4×2 footprint.
- Transparent canvas padding accommodates the pitched roof, restrained chimney, and baseline without fractional placement.
- The visible roof width is 176 px on a 160 px footprint and 144 px on a 128 px footprint: a predictable 8 px overhang per side. The overhang is visual only and does not conceal a primary route.
- Door approaches remain centered within open, south-side walkable space. No porch or step changes collision.

## Contact shadows

Town Square uses a shared crisp `Polygon2D` contact-shadow treatment beneath each exterior. It is offset four pixels toward the lower-right, uses a restrained translucent warm-dark color, has no blur, and carries no physics. Keeping the shadow in the scene makes its relationship to the unchanged collision footprint explicit without introducing a lighting or shadow system.

## Scene fallback structure

Each existing building `StaticBody2D` retains its original collision and brown `Polygon2D`. The polygon now lives below a hidden `DevelopmentFallback` node. The five corresponding development label nodes are also retained but hidden so they do not cover the runtime façades. The runtime `ExteriorSprite` and visual-only `ContactShadow` are siblings of the existing `CollisionShape2D`. Collision remains the gameplay source of truth; no collision is derived from a sprite silhouette.

## Validation previews

- `docs/art/previews/caden_architecture_runtime_v1_lineup.png` — A–E at native scale on a neutral background and common baseline.
- `docs/art/previews/caden_architecture_runtime_v1_footprint_overlay.png` — locked collision bounds, ground line, visible bounds, and door approach.
- `docs/art/previews/caden_architecture_runtime_v1_town_square_preview.png` — architecture over the approved Terrain Runtime v1.1 layout, without nature, props, Festival decoration, or Edenite accents.

The previews are documentation outputs and are not runtime textures.

## Exclusions and known limitations

Excluded source elements include signs, banners, business fixtures, barrels, sacks, fences, gates, flowers, shrubs, pipes, decorative lamps, smoke, and all potentially identifying or lore-bearing ornaments. No Edenite or Festival material is used.

This is a deterministic assembly prototype, not final hand-pixelled architecture. Repeated roof courses and regular timber bays are intentionally visible consequences of the shared kit. Manual Aseprite cleanup candidates are:

- soften repeated roof-course seams without changing pitch or lighting;
- refine ridge joins and chimney-to-roof contact pixels;
- add restrained, non-symbolic façade variation where repetition is too apparent;
- review door and window highlights at actual 640×360 play scale;
- inspect the hard-alpha silhouette for isolated edge pixels;
- adjust individual porch pixels only if they imply walkable space outside the locked collision.

## Manual-review checklist

- [ ] Scale relative to the Player and both NPC placeholders
- [ ] Door size and readability
- [ ] Window readability and non-neon warmth
- [ ] Porch and step scale
- [ ] Roof height, pitch consistency, and overhang
- [ ] Chimney scale and upper-left lighting
- [ ] Contact-shadow direction, density, and route clearance
- [ ] Separation from grass, road, and plaza paving in color and grayscale
- [ ] Four zone connections and northeastern Terrebonne road remain visually clear
- [ ] Reserved 3×3 community space remains open and undefined
- [ ] Both NPC approach areas and prompts remain visible
- [ ] Collision-to-art relationship remains predictable
- [ ] No clipping near Town Square boundaries or camera limits
- [ ] No haloing, colored matte, or transparency artifact
- [ ] Overall cohesion and density at 640×360

Automated tests establish technical integrity only. They do not constitute visual approval.
