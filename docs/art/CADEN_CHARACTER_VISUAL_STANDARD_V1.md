# Caden Character Visual Standard v1

## Status and scope

This document defines a visual-production standard for a noncanonical Caden character prototype. It does not define Player or NPC race, gender, species, class, profession, equipment, wealth, history, faction, religion, magical ability, or permanent clothing. Final character art is not included in this pass.

The recommended production cell is **40 x 56 pixels**. The source-art gate is closed because neither approved master sheet exists. Production Player, NPC, Town Square, movement, collision, interaction, dialogue, objective, transition, camera, and project-configuration files therefore remain unchanged.

## Verified technical baseline

- Godot 4.7-compatible 2D project using GDScript and the Compatibility renderer.
- Internal viewport: `640 x 360`; initial window: `1280 x 720`.
- Viewport stretch, effective `keep` aspect behavior, integer scaling, and nearest-neighbor default filtering.
- World grid: `32 x 32` pixels.
- Named four-direction Input Map actions.
- Persistent Player instance across Caden zones.
- Player movement speed: `96.0` pixels per second.
- No character-visual autoload or external dependency is required.

## Current implementation audit

### Player

| Finding | Current implementation |
| --- | --- |
| Scene | `res://scenes/Player.tscn` |
| Root | `CharacterBody2D`, in the `player` group |
| Visual | `Polygon2D` named `PlaceholderVisual` |
| Placeholder bounds | `24 x 28`, from `(-12,-14)` to `(12,14)` |
| Root origin | Center of the gameplay collision at `(0,0)` |
| Collision | Centered `RectangleShape2D`, `24 x 24` |
| Camera | Enabled `Camera2D` child at the Player origin; limits are supplied by the active zone |
| Interaction | `InteractionDetector` child at the Player origin; circular radius `40`; facing preference follows Player facing |
| Prompt | `CanvasLayer` at layer 10; a `160 x 32` panel at the bottom of the viewport, not an overhead world prompt |
| Dialogue | `DialogueUI` child `CanvasLayer` at layer 20; dialogue starts through `Player.start_dialogue()` |
| Movement | `Input.get_vector()` followed by active-axis selection; output is always one of four cardinal vectors |
| Facing | Public `facing_direction`, initially down; updated only on nonzero cardinal movement |
| Control locks | Reason-keyed dictionary; dialogue lock zeros velocity, calls `move_and_slide()`, disables interaction, and leaves facing unchanged |
| Persistence | Player is a child of `Caden`, separate from the replaceable `CurrentZone` child |
| Layering | Caden's Player instance has `z_index = 10`; the Player therefore renders above default-z zone art |

`player.gd` contains no reference to `PlaceholderVisual`, texture size, sprite offset, or animation. Its visual assumptions are limited to the stable child paths for Camera2D, InteractionDetector, and DialogueUI. This is a favorable seam for a later visual component.

### NPC

| Finding | Current implementation |
| --- | --- |
| Reusable scene | `res://scenes/npcs/StationaryNpc.tscn` |
| Root | `StaticBody2D`, in the `npcs` group |
| Visual | `Polygon2D` named `PlaceholderVisual` plus a `FacingMarker` polygon |
| Placeholder bounds | `20 x 24`, from `(-10,-12)` to `(10,12)` |
| Collision | Centered `RectangleShape2D`, `20 x 20` |
| Interaction area | Centered `CircleShape2D`, radius `32`, on collision layer 2 |
| Facing | Exported cardinal `Vector2`; the marker is placed 9 pixels in that direction and rotated |
| Dialogue | External conversation `Resource` exported on the reusable scene and assigned by each zone instance |
| Layering | Default `z_index = 0`; no Y-sort. Town Square NPCs occur after environment groups in scene order and before the empty `ForegroundOverlays` group |
| Reuse | Eleven current Caden NPC instances share this one foundation: 3 Approach, 3 Marketplace, 2 Town Square, 2 Residential, 1 Commons |

Visual variation (`placeholder_color`), facing, and content (`conversation`) are already assigned separately per instance. The foundation is reusable, though it does not yet have a separate character-visual resource or component.

### Current origin and collision relationship

Both placeholders are centered around their root/collision center and extend two pixels below the collision bottom. They do not use a feet-contact anchor. A production visual must not move either root or collision. Instead, a visual-only child anchor should be placed at the collision bottom:

- Player visual anchor: local `(0,12)` relative to the existing root.
- NPC visual anchor: local `(0,10)` relative to the existing root.
- A 40 x 56 centered sprite is then offset `(0,-28)` from that visual anchor.

For the Player, this places the cell from local `x=-20..20` and `y=-44..12` in continuous coordinates while the collision remains `x=-12..12`, `y=-12..12`. The visual cell overhang is 8 pixels per side and 32 pixels above the collision top.

## Environment measurements

The representative runtime assets used by the scale lab are protected inputs.

| Reference | Canvas / visible measurement | Scale relationship |
| --- | --- | --- |
| Terrain Runtime v1.1 | 32 x 32 cells | Character footprint remains centered on one tile |
| Northwest building | 192 x 160 canvas; visible bounds 175 x 136 | Door and frame occupy roughly one 32-pixel facade bay and approximately 1.5-1.75 tiles vertically above the porch contact |
| Flowered bench | 96 x 64 canvas; visible bounds 53 x 46 | Substantial seated prop; much wider than one collision footprint |
| Ordinary lantern post | 32 x 96 canvas; visible bounds 17 x 72 | Intentionally taller and narrower than the recommended character |
| Edenite lantern | 64 x 96 canvas; visible bounds 26 x 60 | Near character height, but remains narrower and visually fixture-like |
| Medium tree 01 | 64 x 96 canvas; visible bounds 32 x 57 | Canopy width helps it read larger; its short visible height is existing scale debt exposed by large character candidates |
| Planter 02 | 64 x 64 canvas; visible bounds 38 x 39 | Below the recommended head line |
| Road | Locked principal routes are 128 pixels wide | Recommended canvas is 31.25% of road width; collision is 18.75% |
| Plaza paving | 32 x 32 cell logic | Recommended canvas is 1.25 tiles wide and 1.75 tiles high |

The current Player placeholder is only `24 x 28`: the same width as its collision and four pixels taller. The current NPC placeholder is `20 x 24`. The Player therefore appears only four pixels wider and four pixels taller than an NPC, and both read primarily as collision markers rather than environment-scaled characters.

The interaction prompt is viewport UI rather than an overhead bubble. Increasing visible character height does not change detector range or world-space prompt clearance. Near the lower camera edge, any character can appear beneath the layer-10 prompt panel; the CanvasLayer keeps the prompt readable.

## Candidate comparison

All candidates use the same neutral posture, three-tone treatment, bottom-center feet alignment, and unchanged `24 x 24` Player collision.

| Criterion | A: 32 x 48 | B: 40 x 56 | C: 48 x 64 |
| --- | --- | --- | --- |
| Horizontal overhang beyond collision | 4 px per side | 8 px per side | 12 px per side |
| Canvas above collision | 24 px | 32 px | 40 px |
| Grass/plaza/road readability | Readable but body parts compress quickly | Clear head/body/limb masses on all three | Very clear, but begins to dominate paving and props |
| Door relationship | Conservative and slightly undersized beside the framed door | Matches the full framed door mass without filling the facade bay | Presses against door and facade scale; risks making modest buildings feel small |
| Bench relationship | Visible height is approximately bench height | Clearly taller than bench seating while keeping the bench substantial | Bench begins to look undersized |
| Lantern relationship | Strong size separation; character can feel small | Character remains clearly shorter than ordinary lantern | Character approaches the ordinary lantern's visual height |
| Edenite fixture relationship | Fixture dominates | Balanced, with the fixture still slightly taller | Character can dominate the fixture |
| Medium-tree relationship | Safest of the three | Close visible-height relationship exposes existing tree-scale debt but canopy width still separates it | Character can exceed the current tree silhouette height; failure risk near canopies |
| Head/body readability | Minimum viable; little room for neutral clothing and four-direction feet | Best balance of head, hands, feet, clothing, and negative space | Most readable but encourages excess detail and larger head/body mass |
| Roof/canopy pressure | Lowest | Moderate and reviewable | Highest; 40 pixels extend above collision and static layering debt becomes obvious |
| 96 px/s implication at 8 fps | 12 px per frame; small feet make sliding easier to notice | 12 px per frame with enough foot mass to sell contact | Same displacement, but larger stride expectation raises sliding risk |
| Four-direction production cost | Lowest: 24,576 cell-pixels across 16 frames | Moderate: 35,840 cell-pixels, 46% above A | Highest: 49,152 cell-pixels, 37% above B and 100% above A |

### Candidate A finding

Candidate A is technically compatible and economical, but it remains close to a one-tile-width legacy character. At native scale it is near the bench's total visible height, leaves little room for readable hands and directional feet, and is the most likely to make door frames and lanterns feel oversized. It is acceptable as a fallback if later motion review proves 40 x 56 too large.

### Candidate B finding

Candidate B provides enough height for a non-chibi head/body split, readable three-to-five-pixel hands and feet, and restrained clothing shapes without becoming a two-tile-wide presence. It remains shorter than the ordinary lantern, near but below the Edenite fixture, and visually compatible with the full framed-door mass. Its 8-pixel side overhang is meaningful but still practical around 32-pixel routes and the unchanged collision.

### Candidate C finding

Candidate C is attractive in isolation but materially changes environmental proportion. It can exceed the current medium-tree visible height, makes benches and compact buildings feel smaller, increases canopy/roof overlap, and raises the expected stride size without changing movement speed. Its extra area also invites detail inconsistent with the controlled Caden pixel density.

## Recommendation

Use a **40 x 56 visible production cell** for both the development Player and the reusable town-adult NPC base. Candidate B best satisfies the priority order of gameplay readability, environmental proportion, animation clarity, production practicality, and visual appeal. The scale failure gate is not triggered.

This recommendation remains subject to manual approval at `640 x 360`. It does not authorize final art or runtime integration.

## Cell, sheet, anchor, and padding standard

- Cell: `40 x 56` pixels.
- Sheet: `160 x 224` pixels.
- Grid: four columns by four rows.
- Mathematical bottom-center anchor: `(20,56)` within a cell, on the lower cell boundary.
- Feet-contact pixel line: zero-indexed row `55`, the final pixel row.
- No painted pixel may cross a cell boundary.
- Keep at least two transparent pixels at the top and sides in the neutral frame where practical; animation extrema may use that space deliberately.
- Keep the feet on row 55 for contact frames. A raised step foot may move upward, but the supporting foot must retain a believable ground contact.
- Do not add labels, row names, guides, or presentation backgrounds inside production Player or NPC sheets.
- Guide marks belong only in the two separate reference PNGs.

### Collision relationship

The production cell does not replace gameplay collision.

- Player collision remains `24 x 24`, bottom-aligned to the feet anchor in the visual reference.
- In cell coordinates, the collision occupies continuous bounds `x=8..32`, `y=32..56`; the Player root/collision center is `(20,44)`, twelve pixels above the anchor.
- NPC collision remains `20 x 20`; its root/collision center is ten pixels above its visual anchor.
- Transparent visual overhang must never be treated as collision.
- Hair, cloak, hands, and step extrema may extend beyond collision while remaining within the cell.

## Proportion and silhouette guidance

- Use a slight three-quarter top-down posture consistent with Caden architecture and props.
- Target a painted standing height of approximately 49-53 pixels inside the 56-pixel cell.
- Keep the complete head/hair mass approximately 14-16 pixels high. The head should read clearly but not become a chibi half-body mass.
- Keep shoulders and ordinary clothing comfortably inside 28-30 painted pixels in the neutral frame; reserve the remaining cell width for motion and modest silhouettes.
- Use hands as practical 3-5-pixel clusters, not one-pixel needles.
- Use feet as stable 4-7-pixel shapes with a visible contact edge. Avoid tiny single-pixel shoes.
- Preserve a clear gap or value break between legs in down/up frames where perspective permits.
- Use compact, readable limb shapes rather than realistic thin anatomy.
- Preserve recognizable directional head, shoulder, and foot masses even in silhouette.

## Noncanonical development-art guardrails

### DevelopmentTravelerPlayer

Permitted: simple tunic, trousers, boots, short cloak or travel mantle, plain belt, small neutral satchel, and restrained hair silhouette.

Not permitted: race/species definition, gender definition, class/profession markers, armor, weapons, magic, heraldry, faction colors, royal clothing, Festival symbols, Edenite jewelry, visible wealth, religious marks, or biographical cues. `DevelopmentTravelerPlayer` is an internal identifier only and must not appear in normal gameplay.

### DevelopmentTownNpcBase

Permitted: modest everyday clothing, simple footwear, and a restrained hair/head silhouette.

Not permitted: occupation tools, permanent accessories, species-specific anatomy, faction colors, Festival insignia, weapons, magic, or individualized canon. The base tests visual reuse and must not imply that every Caden citizen shares one identity or body.

## Lighting, palette, and outline

- Use the environment's upper-left light direction in every direction and frame.
- Author separate left and right rows. Do not mirror if doing so reverses lighting, satchel placement, clothing asymmetry, hair asymmetry, or highlights.
- Use a warm, cohesive palette with deliberate hue/value separation from grass, earth road, pale plaza, timber, and stone.
- Reserve enough contrast for the head, torso, hands, and feet to remain readable without portrait-level facial detail.
- Prefer selective warm-dark exterior contours and clustered shadow shapes. Do not use pure black around every interior detail.
- Avoid antialiasing, semitransparent edge pixels, painterly blending, subpixel noise, and isolated highlight specks.

## Directional animation structure

Row order:

1. Down
2. Left
3. Right
4. Up

Column order:

1. Neutral/contact
2. Step A
3. Passing/contact
4. Step B

The idle animation reuses column 1 for its direction. Separate one-frame idle sheets are unnecessary. Required future animation names should be `idle_down`, `idle_left`, `idle_right`, `idle_up`, `walk_down`, `walk_left`, `walk_right`, and `walk_up`.

No diagonal, run, blink, breathing, emote, talking, attack, dodge, item-use, casting, death, or combat animation is part of v1.

## Timing and movement implications

- Start walking at `8 fps`; the acceptable provisional review range is `7-9 fps`.
- Idle is static at one frame.
- Change animation immediately when facing or movement state changes.
- Return to directional idle when movement stops and retain the last facing direction.
- Use no diagonal blending, frame interpolation, animation tree, or blend space.
- Do not restart an animation already playing.
- At the unchanged `96 px/s`, movement advances about `12 px` per frame at `8 fps` (`10.7-13.7 px` across the allowed range). Contact frames and stride spacing must be reviewed in motion for sliding.
- Keep movement speed unchanged until approved art is integrated and manually reviewed. Prefer animation-timing correction before any later gameplay-speed proposal.

## Import and runtime conventions

- PNG with true transparency and no presentation background.
- Lossless import; mipmaps disabled; repeat disabled unless a specific reviewed resource requires otherwise.
- Use the project's nearest-neighbor default filtering. Do not add smoothing or interpolation.
- Place sprites and visual anchors on integer pixels.
- Build `SpriteFrames` deterministically from exact `40 x 56` cells after the source-art gate passes.
- Do not use runtime sprite-sheet slicing, arbitrary scaling, rotation, or lighting-reversing mirroring.
- Keep source sheets under `assets/source_art/caden/characters/`; place approved runtime derivatives under `assets/characters/caden/` only after the gate passes.

## Occlusion and layering implications

The current Town Square does not use Y-sort. The persistent Player has `z_index = 10`, so it renders above default-z buildings, trees, props, NPCs, and the currently empty `ForegroundOverlays`. NPCs use scene order at z 0. A 40 x 56 sprite will therefore expose static layering limitations near roofs and canopies, but this pass does not create a new sorting, fade, shader, or transparency system.

Use the existing static hierarchy during the first gated prototype. If live review shows clearly incorrect roof/canopy occlusion, document exact locations before proposing a narrowly scoped layer adjustment. Prompts and dialogue remain CanvasLayers above world visuals.

## Protected representative hashes

| Runtime asset | SHA-256 |
| --- | --- |
| Terrain Runtime v1.1 atlas | `bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a` |
| Northwest Architecture Runtime v1.1 building | `55ee5c5c35e2f646e5b8b2295680111eba56e71168d5efed5b246ae9f2c0f770` |
| Medium tree 01 | `4437f65ccff775395b4ac73dd1673ab7da65d7afdbd80256cd9325d09172c828` |
| Flowered bench 01 | `49c5ec39182644f034d691626af90770084b3a5924c6dc2f4e42410868e35b79` |
| Ordinary lantern post 01 | `705640a25a52bfddaf1dd624b2e301d6e01c6eaf88cfee717a7f6b6e0e341c59` |
| Edenite lantern 01 | `18ce8e4b5066cb228e589e7f9f0cee4dd07fab18e8e9c45f4e12f430a12c36ad` |

## Known limitations

- Neutral polygons test scale and mass, not final anatomy, clothing, palette, facial readability, or animation quality.
- The deterministic previews approximate Godot compositing and do not replace live camera, collision, movement, prompt, dialogue, or import review.
- Candidate B exposes an existing medium-tree scale concern; environment assets must not be resized automatically in response.
- Static Player z 10 prevents genuine roof/canopy occlusion evaluation until approved art is tested live.
- Foot sliding cannot be approved without an actual four-frame cycle.
- Player/NPC relative scale is standardized, but individual future age/body variation remains undefined.

## Manual review checklist

- [ ] Confirm 40 x 56 as the selected visible canvas at `640 x 360`.
- [ ] Review Player/door, Player/bench, Player/ordinary-lantern, Player/Edenite-fixture, and Player/tree proportions.
- [ ] Review Player/NPC relative scale and ensure the NPC base does not imply population uniformity.
- [ ] Review silhouette, head/face mass, hand, and foot readability on grass, road, and plaza.
- [ ] Review cell padding, frame consistency, bottom-center anchoring, and feet-contact row.
- [ ] Review all four facings, directional idle transitions, walk timing, head bob, and foot sliding.
- [ ] Review whether `96 px/s` visually matches the approved walk cycle.
- [ ] Review roof and canopy occlusion, static z ordering, and absence of z-order popping.
- [ ] Review prompt visibility, dialogue-lock behavior, and lower-screen UI overlap.
- [ ] Review environment contrast, upper-left lighting, palette cohesion, outline density, and pixel density.
- [ ] Decide whether any environment asset needs a later separately approved manual rescale.
- [ ] Confirm the prototype does not imply Player or NPC canon.

Automated tests establish dimensions, paths, transparency, hashes, and configuration only. They do not constitute visual approval.
