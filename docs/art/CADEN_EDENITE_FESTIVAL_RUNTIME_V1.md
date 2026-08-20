# Caden Edenite, Festival Accents, and Perimeter Fencing Runtime v1

## Scope and failure-gate result

This visual-only pass prepares a restrained Edenite, Festival-fabric, and neutral route-closure vocabulary for Caden Town Square. It also extends the already prepared neutral fence vocabulary into three selective perimeter runs. It adds no Festival lore, building identity, interaction, animation, dynamic lighting, gameplay system, or permanent community feature.

The mandatory failure gate used one freestanding Edenite lantern, one small crystal fixture, one bunting asset, one fence-drape overlay, and one neutral closure gate. All five representatives were isolated deterministically at gameplay scale without destructive scaling, source-background contamination, excessive haloing, perspective conflict, or unreproducible repainting. The failure gate was not triggered.

## Protected inputs

The accent source master and all established runtime layers were read-only inputs. `tools/art/prepare_caden_edenite_festival_runtime_v1.py` verifies these hashes before it writes any output.

| Protected input | SHA-256 before and after preparation |
| --- | --- |
| `assets/source_art/caden/accents/caden_edenite_festival_master_v1.png` | `95a1860a8cc172ae7fbb65a8256450c018f7cef277595c33af80211feff5fc16` |
| Terrain Runtime v1.1 atlas | `bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a` |
| Architecture northwest v1.1 | `55ee5c5c35e2f646e5b8b2295680111eba56e71168d5efed5b246ae9f2c0f770` |
| Architecture southwest v1.1 | `790f375a5549e91af59950e91c648fc6c547fc2d1b092591dc33a56ba59b6780` |
| Architecture northeast v1.1 | `22c8515c03591d869174392fe83ee2a90c909f6c58b70820fb9a6ea60792d1a6` |
| Architecture southeast v1.1 | `68c8686dca3dae8f3173415a094c824f8601021ab51b6904968deef5e84ab487` |
| Architecture south v1.1 | `0693a95af32429919b54c72b0d4e5817298d6bd37d06897d7009579bc5394caa` |
| `project.godot` | `b560718fd3141c70c318a2843b409b95490b876c139bd77104c125ce181c91f0` |

Protected Nature Runtime v1 hashes:

| Nature asset | SHA-256 |
| --- | --- |
| Ground atlas | `9a9cf0889528763c2cdbdbe4b7d5fb755c5df9247529f9dcf2e5e5864190f045` |
| Medium trees 01 / 02 | `4437f65ccff775395b4ac73dd1673ab7da65d7afdbd80256cd9325d09172c828` / `c062eca53c29d4f734716e2708c48acb35bfe86cafbfb71c453a667096f735d9` |
| Small trees 01 / 02 | `099d85522798fa45f68b20e9b23afab2f171936c7279b0f96795d808d78bce78` / `907f22a378b064941e7bf92aba877dd1ac9eb08e31f3b2c29c494d16954d9d1e` |
| Medium bushes 01 / 02 / 03 | `71d4f3883c0cb48ba20b05dea8288fc877b4031aeda2fe4a137141317e6b9c56` / `b7aa6706bd868e828e7c1843535b484eefe2b7416a172cf454c19d85ccb60fe5` / `d488ebf7a5e5a1b0e198e098c977047d7337c285df376ae75966255a5249cc28` |
| Small shrubs 01 / 02 / 03 | `1b6f822eeb9344af4964b798596d8397d3bbb46c0df8b094ca1de4176d4e3d51` / `9f0d898a81bce8dbb726e2d132b50ad0fef987cbce8f4aa46af8184d1ba3ed4c` / `6f18c869d556e9d37128a8cc78a2dfcd6348fe078c9293189ff89d575f6d5113` |
| Small rocks 01 / 02 | `1314c6e6e33e4e32588980a7d74821f7ca0f8d27002801926ed45f1c861f4887` / `db8d584dcb72613b99e58dfa0d3ec7c034bb3d9ac8735bc22c6df06252b8beb6` |
| Rock cluster 01 | `1918ff6469b3684e84aba4c5ea6d7437d87894f280c84b5cf2fab0d629927660` |

Protected Neutral Props Runtime v1 hashes:

| Props assets | SHA-256 |
| --- | --- |
| Benches 01 / 02 | `49c5ec39182644f034d691626af90770084b3a5924c6dc2f4e42410868e35b79` / `b5363f4e1616c517864e717f3f88b5596a8f9bb516d6e8f82d0f77885bd075df` |
| Lantern post / ground lantern | `705640a25a52bfddaf1dd624b2e301d6e01c6eaf88cfee717a7f6b6e0e341c59` / `4fcdf7d84a73a6026cd4cd38e72d5a6e482df9a621693682a3e6abc01df2908c` |
| Fence straight / corner / gate / end | `3f2c330f73edcea4cbf438eff7a9da3cff83a800df304bca3105578ac96065bf` / `1e5594b37e9340155861839c4124215ba13a162dbadd73e1966261a8f548c637` / `876bbd3f59c18e969294248a9ddea6dabffe5466cf85f1119811074ccf77a35c` / `2e4f396a9241f0d86916fb49f8a31493e0166270c35fa4ded91877b7585919ef` |
| Planters 01 / 02 | `27bd2c5c79206ae766d8b36b21431e0d9bf6e67db5a6da22d1e55d681a7d3782` / `c795d44f6d42242f9dbd88df45632e8b0fc8822e2d8da8c5a33dbaef42a6f7c8` |
| Barrels 01 / 02 | `6ba3230d218aa0659c3fe2d22d4f74afb5c6019f461155434b3b0bcfdd8c1e55` / `0cc377a6f04baa9995da2cfd097c000883b1f9146e80ce4fc76291cb95297c3d` |
| Crates 01 / 02 | `927fe189ec720bbf0eb1575fdbcb21dace7e27f27b3329d04e40cf13bd45a9fb` / `be608df14dfd73ed49b4e1e98f683e45567ee640faec5b8a1ea57d0b7307b6a3` |
| Sack / storage clusters | `df6d76760b092a75753f8ea10889416e6a14452948e1184b586283679f8bad95` / `825732a76e08e1bacdd635ad42ba9227e0c205cd90a15521caea5db905d668c0` |
| Luggage bundles 01 / 02 / travel pack | `147b1345512ac5faf2a1754e2e19109a83b460a3b9cee5bb5810fd55994367d1` / `d6973d5921940315aa03dee3e01460b0b3f1a90538eaab091fd5c5d592e507b4` / `8d74fb7dc0f439bfb113b7bd2715f672e311273e90468f0a4cb3f3dd099a9caf` |
| Blank signpost | `c9761623de0099b3b84dd9909298f713d38546f31ab548a175c6ac5b75d64ede` |

## Source inspection

- The accent master decodes as 1448×1086 RGBA.
- Alpha ranges from 0 to 255: 875,652 pixels are fully transparent, 1,278 are fully opaque, and 695,598 are partially transparent. Fully transparent pixels retain no RGB.
- The presentation background is transparent black with pervasive very-low-alpha residue. Copying raw crops would retain a subtle matte; the Edenite glows also contain intentional partial alpha.
- Painted contact darkening is integrated into the objects. Edenite fixtures include integrated cyan/sapphire glows.
- The selected crops do not overlap neighboring objects, although the master is not a production atlas and broad crops could capture adjacent material.
- Individual selected assets can be extracted deterministically with fixed rectangles and alpha reconstruction.
- Perspective is a consistent slight three-quarter view, and highlights and shadows generally follow an upper-left light direction.

## Processing method

`tools/art/prepare_caden_edenite_festival_runtime_v1.py` verifies all protected hashes and then applies the following deterministic operations:

1. Crop each approved candidate using the recorded fixed rectangle.
2. For fabric and closure art, reconstruct binary alpha with an alpha threshold of 64, removing the low-alpha presentation residue.
3. For Edenite art, remove alpha below 16; preserve only low-alpha blue-dominant glow pixels within alpha 48–192; and make body-edge pixels at or above alpha 64 opaque.
4. Trim surviving content, reduce exactly 3:1 with nearest-neighbor sampling, and trim again.
5. Apply category harmonization: Edenite saturation ×0.96, contrast ×0.96, brightness ×0.98; Festival ×0.86/×0.95/×0.96; closure ×0.90/×0.94/×0.95.
6. Place each result on a transparent, versioned runtime canvas with a bottom-center anchor and final-row ground contact.

No bilinear or bicubic scaling, blur, rotation, mirroring, generation, arbitrary resizing, manual repainting, or source modification is used.

## Runtime sprite manifest

Visible bounds use `(x, y, width, height)`. Padding is `(left, top, right, bottom)`. All assets use exact 1:3 nearest-neighbor reduction.

| Category / file | Canvas | Visible bounds | Padding | Source crop `(l,t,r,b)` | SHA-256 | Intended use | Implies / adds collision |
| --- | ---: | --- | --- | --- | --- | --- | --- |
| Edenite — `caden_edenite_lantern_01_v1.png` | 64×96 | `(19,36,26,60)` | `(19,36,19,0)` | `(700,35,825,255)` | `18ce8e4b5066cb228e589e7f9f0cee4dd07fab18e8e9c45f4e12f430a12c36ad` | Modest freestanding fixture | Yes / 14×10 rectangle at `(704,363)` |
| Edenite — `caden_edenite_stone_fixture_01_v1.png` | 64×96 | `(15,36,33,60)` | `(15,36,16,0)` | `(280,35,425,255)` | `a82a235360981dff5760934b54131725e9911ac849500ec2dadb3edf7963fb87` | Compact stone-based fixture | Yes / no duplicate collision; base sits on south boundary |
| Edenite — `caden_edenite_small_fixture_01_v1.png` | 64×64 | `(22,27,19,37)` | `(22,27,23,0)` | `(945,125,1045,275)` | `b91bc8eb4bb6ae7c86fdd266468549eefc7f648a912f72e09e7d5448215c94ae` | Small boundary fixture | Yes / no duplicate collision; base sits within west boundary |
| Festival — `caden_festival_drape_01_v1.png` | 96×64 | `(19,35,57,29)` | `(19,35,20,0)` | `(0,395,205,520)` | `bf5d055d49f0f2502c7dd8d2a99d340a455dc36645416627e69d8a798f317682` | Removable fence drape | No / none |
| Festival — `caden_festival_drape_02_v1.png` | 96×64 | `(20,35,56,29)` | `(20,35,20,0)` | `(200,395,395,520)` | `7b3c5e8be8b4975302d5d6356b4ad2b3018c492c813f609e9b7e04355b09756a` | Removable fence drape variant | No / none |
| Festival — `caden_festival_bunting_01_v1.png` | 96×64 | `(10,37,76,27)` | `(10,37,10,0)` | `(385,395,640,525)` | `6077f2b1a34e68cafd676ebd46a4423b5c2076f0ad2715c997c8081a77e8e702` | Short removable fence bunting | No / none |
| Festival — `caden_festival_bunting_02_v1.png` | 96×64 | `(6,19,83,45)` | `(6,19,7,0)` | `(635,395,915,530)` | `83cea2b28180162151a5421a29de1024cda2063aaa465001a5e0a0f02640e27a` | Longer bunting; prepared, unplaced | No / none |
| Festival — `caden_festival_ribbon_drop_01_v1.png` | 32×64 | `(5,24,22,40)` | `(5,24,5,0)` | `(915,395,1005,535)` | `7b4878ba8d813707dcb8607ad79f7ffc83f5a5deb352c5e78101197ca2f24373` | Removable ordinary-lantern decoration | No / none |
| Closure — `caden_closure_gate_01_v1.png` | 64×64 | `(5,26,53,38)` | `(5,26,6,0)` | `(545,890,735,1045)` | `e678f42152bca02ad27ed8458e19a053092b480382ac86c1ef57ae01d8ad56a1` | Neutral route barrier | Yes / no new collision; aligns with locked closure |
| Closure — `caden_closure_rope_01_v1.png` | 64×64 | `(6,20,52,44)` | `(6,20,6,0)` | `(720,885,885,1050)` | `c370800eb12a20286a550f592c1e10863fdc04ec1b044b4f4932b0836413fc1b` | Neutral rope-and-post closure | Yes / no new collision; aligns with locked closure |
| Closure — `caden_closure_timbers_01_v1.png` | 64×64 | `(10,29,44,35)` | `(10,29,10,0)` | `(875,890,1030,1050)` | `7c2dd8808384527fe94e2ec407f8b5f256282104e8416f5d25595b82dd9e06fb` | Neutral stacked-timber closure | Yes / no new collision; aligns with locked closure |

The bottom-center anchors are `(32,96)`, `(32,64)`, `(48,64)`, or `(16,64)` according to canvas size. Ground-contact rows are 95 for 96-pixel-high canvases and 63 for 64-pixel-high canvases.

## Glow and contact shadows

Edenite glow is fully contained in each sprite. A concentrated cyan core, sapphire midtone, pale-blue edge, and small surviving blue-dominant partial-alpha halo communicate illumination without a light node, shader, bloom, particle, or renderer change. Festival and closure assets use binary transparency with no halo.

Source-integrated crisp contact darkening remains inside the documented bounds. No separate scene shadow was necessary in this pass: the two freely walkable fixtures have compact base collisions, while the stone fixture, fence pieces, and closure art meet existing blocked boundaries.

## Town Square placement

### Perimeter fencing

The perimeter contains 10 visible neutral fence segments arranged into three modest runs. Four originated in Neutral Props Runtime v1 and six are new placements; no earlier fence was moved.

- Northwest top boundary: end at `(256,32)`, straight at `(320,32)`, end at `(368,32)`.
- Southwest south boundary: corner at `(64,672)`, existing straight at `(128,672)`, existing end at `(224,672)`, gate at `(256,672)`.
- Southeast south boundary: existing corner at `(736,672)`, existing straight at `(832,672)`, end at `(896,672)`.

Three of the 10 perimeter segments receive fabric overlays: southwest drape `(128,672)`, northwest bunting `(320,32)`, and southeast drape `(832,672)`. Decorated coverage is therefore 30%; seven segments remain plain. Every run has a corner, gate, or end treatment, no run encircles the plaza, and all bases sit within existing top or south perimeter collision. No fence collision was added.

### Festival accents

Four fabric accents are placed: the three fence overlays above plus one ribbon drop at `(368,144)` on an ordinary amber lantern. The second longer bunting asset remains prepared but unplaced. No building, door, route threshold, NPC, travel pile, reserved-space edge, or plaza center is decorated.

### Edenite fixtures

Three visibly glowing fixtures are placed across the complete 960×704 scene:

- small fixture at `(24,176)` within the west boundary;
- freestanding lantern at `(704,368)` on the east plaza edge;
- stone fixture at `(672,672)` on the south boundary.

Their spatial separation yields an estimated maximum of two visible Edenite elements in any one 640×360 camera view. Three ordinary amber lights remain visible, so the scene does not convert every lantern to Edenite. No fixture enters the reserved area, marks the plaza center, defines a building, or explains the route closure.

### Added collision

Only one scene-local `StaticBody2D` rectangle was required:

| Fixture | Collision center | Size | Clearance relationship |
| --- | ---: | ---: | --- |
| East plaza lantern | `(704,363)` | 14×10 | Outside the east road; at least approximately 54 pixels from the nearest NPC approach and more than 64 pixels from locked structures and other free-standing prop colliders |

No physics layer, navigation obstacle, interaction area, scripted gate, animation, alpha-derived collision, or new collision system was introduced.

### Terrebonne closure

The visible closure uses the existing neutral fence corner at `(624,112)`, a neutral crossed gate at `(688,112)`, rope-and-post barrier at `(752,112)`, and stacked timbers at `(816,112)`. These bases align with the existing locked horizontal branch barrier and the corner meets the existing vertical barrier. The old greybox polygons are retained but hidden; both original collision bodies, positions, sizes, and route geometry remain unchanged. The composition contains no text, warning mark, guard, magical blockage, or explanation for the closure.

## Protected clearances and unchanged placement

- All four entry markers and transition corridors remain clear, with at least 128 pixels through each principal route.
- Door approaches, both NPC interaction approaches, the plaza center, Player visibility, and circulation around the reserved area remain clear.
- The reserved 3×3 community space at `(256,224)` through `(352,320)` contains no Pass 5 asset and is not ceremonially framed.
- The Terrebonne branch remains visible and blocked by its original geometry.
- No Nature Runtime v1 or Neutral Props Runtime v1 node was moved, deleted, or replaced. Known provisional composition issues remain deferred to the Environmental Dressing Polish Pass.

## Excluded source material

The following source categories remain excluded: large or clustered crystals; pedestals or centerpiece candidates; crystal-bearing roofs and architecture; decorated doors or arches; symbol-bearing banners; travel luggage with Festival decoration; flower or planter decorations; extra decorated posts; ceremonial-looking arrangements; and any source item with a readable or lore-bearing mark. Preparation of the small stone fixture does not authorize a monument, shrine, fountain, or reserved-space feature.

## Known limitations and manual cleanup candidates

- The source uses pervasive partial alpha. The deterministic thresholds deliberately favor crisp runtime silhouettes and may simplify the softest painted edges.
- The retained Edenite halo is intentionally small but must still be reviewed against every terrain color and near moving characters.
- The top-boundary fence run approaches the camera/map edge and may require later composition review for clipping; its functional base remains aligned to the existing boundary.
- Festival fabric variants share a similar blue-and-cream treatment; a later polish pass must judge repetition without inventing more variants.
- Closure objects are individually readable but should be reviewed at gameplay scale to ensure the combination does not appear fortified or imply an unapproved cause.

Manual Aseprite cleanup candidates, only for a separately approved polish pass, are isolated one-pixel fringe checks on fabric edges, the small fixture holder silhouette, exact fence-foot contacts, cyan-halo intensity, and closure rope/timber contact pixels. Any cleanup must remain reproducible and must not change source masters.

## Validation previews

- `caden_edenite_festival_runtime_v1_failure_gate.png` — five mandatory extraction representatives at native scale.
- `caden_edenite_festival_runtime_v1_lineup.png` — all prepared assets at native scale.
- `caden_edenite_festival_runtime_v1_anchor_overlay.png` — canvases, contact rows, and bottom-center anchors.
- `caden_edenite_festival_runtime_v1_fence_overlay.png` — new plain fences, decorated segments, and existing perimeter collision.
- `caden_edenite_festival_runtime_v1_clearance_overlay.png` — routes, entries, doors, NPC approaches, reserved space, new bounds, and new collision.
- `caden_edenite_festival_runtime_v1_town_square_preview.png` — all approved runtime layers plus Pass 5.
- `caden_town_square_neutral_vs_festival_comparison.png` — Neutral Props v1 beside the Pass 5 result.
- `caden_terrebonne_closure_runtime_v1_preview.png` — the lore-neutral closure aligned with the locked route.

## Manual 640×360 review checklist

Manual Godot review remains required for fence coverage and continuity; gate/opening readability; rustic rather than fortified character; central-plaza openness; Edenite scale, intensity, density, and amber-lantern balance; fabric saturation and density; the 30% decorated-fence ratio; building and door visibility; route clarity; Player/NPC/prompt contrast; collision feel and snagging; closure readability and neutrality; reserved-space neutrality; alpha halos and background remnants; layering and z-order; boundary clipping; camera movement; and any accidental implication of a business, institution, religion, historical event, or permanent civic identity. Automated checks establish technical integrity, not visual approval.
