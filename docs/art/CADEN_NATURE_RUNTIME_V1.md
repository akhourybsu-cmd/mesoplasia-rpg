# Caden Nature Runtime v1

## Scope and status

Caden Nature Runtime v1 is the first visual-only environmental dressing pass for Town Square. It is a deterministic derivative of the Nature source master and introduces no collision, navigation, interaction, gameplay logic, canon, props, Edenite, or Festival material. The central plaza and reserved 3×3 community space remain open and undefined.

The failure-gate prototype—one medium tree, one medium bush, one 32×32 flower overlay, and one small rock—passed internal extraction review. Each representative asset remained readable after exact 3:1 nearest-neighbor reduction and contained no presentation label, matte, neighboring fragment, or partial-alpha halo.

## Protected inputs

| Input | Dimensions | SHA-256 before preparation |
| --- | ---: | --- |
| `assets/source_art/caden/nature/caden_nature_master_v1.png` | 1536×1024 RGBA | `611eb43cc137a63b477d982371e88d6d6d07997878a12bde8202ef26cfe93650` |
| `assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png` | 256×224 | `bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a` |
| `town_square_building_northwest_v1_1.png` | 192×160 | `55ee5c5c35e2f646e5b8b2295680111eba56e71168d5efed5b246ae9f2c0f770` |
| `town_square_building_southwest_v1_1.png` | 192×160 | `790f375a5549e91af59950e91c648fc6c547fc2d1b092591dc33a56ba59b6780` |
| `town_square_building_northeast_v1_1.png` | 160×160 | `22c8515c03591d869174392fe83ee2a90c909f6c58b70820fb9a6ea60792d1a6` |
| `town_square_building_southeast_v1_1.png` | 192×160 | `68c8686dca3dae8f3173415a094c824f8601021ab51b6904968deef5e84ab487` |
| `town_square_building_south_v1_1.png` | 160×128 | `0693a95af32429919b54c72b0d4e5817298d6bd37d06897d7009579bc5394caa` |

`project.godot` is also guarded by the preparation script at SHA-256 `b560718fd3141c70c318a2843b409b95490b876c139bd77104c125ce181c91f0`.

## Source inspection

- The source decodes as a 1536×1024 RGBA image.
- Its presentation background is technically transparent rather than opaque: colored presentation pixels use pervasive very-low alpha, while displayed asset pixels use higher alpha.
- Painted lower-right grounding and shadow information is integrated into the displayed assets.
- Headings, divider lines, and the palette occupy separate presentation regions but sit close enough to some asset rows that crop rectangles must be explicit.
- The selected trees, shrubs, flowers, tufts, and rocks can be isolated deterministically with fixed rectangles and hard alpha reconstruction.
- Edge cleanup does not require destructive repainting for this selected vocabulary. Thresholding and exact reduction are sufficient; more complex deferred categories may still need Aseprite cleanup.

## Deterministic processing

`tools/art/prepare_caden_nature_runtime_v1.py` performs the complete preparation pass.

1. Verify every protected SHA-256 before writing outputs.
2. Crop only the recorded source rectangles.
3. Reconstruct alpha as binary: source alpha below 64 becomes 0 and alpha at least 64 becomes 255.
4. Trim to the surviving visible bounds.
5. Reduce exactly 3:1 with nearest-neighbor sampling.
6. Apply one shared restrained harmonization: saturation ×0.88, contrast ×0.94, brightness ×0.94.
7. Reapply binary alpha and bottom-center the result on the documented canvas.
8. Save PNGs without runtime rescaling, smoothing, mirroring, rotation, blur, or generative replacement.

The source-integrated lower-right grounding pixels are retained where they survive the alpha threshold. No new shadow, lighting, shader, particle, or physics system is added.

## Individual sprite manifest

All anchors are bottom-center. The ground-contact line is the final canvas row. Transparent padding is the difference between each canvas and its visible bounds.

| Asset | Runtime size | Visible bounds `(x,y,w,h)` | Source crop `(l,t,r,b)` | SHA-256 | Intended use | Implies solidity |
| --- | ---: | --- | --- | --- | --- | --- |
| `trees/caden_tree_medium_01_v1.png` | 64×96 | `(16,39,32,57)` | `(25,397,142,584)` | `4437f65ccff775395b4ac73dd1673ab7da65d7afdbd80256cd9325d09172c828` | Perimeter tree | Yes |
| `trees/caden_tree_medium_02_v1.png` | 64×96 | `(11,38,41,58)` | `(146,397,276,586)` | `c062eca53c29d4f734716e2708c48acb35bfe86cafbfb71c453a667096f735d9` | Perimeter tree | Yes |
| `trees/caden_tree_small_01_v1.png` | 32×64 | `(5,27,22,37)` | `(25,634,116,768)` | `099d85522798fa45f68b20e9b23afab2f171936c7279b0f96795d808d78bce78` | Boundary sapling | Yes |
| `trees/caden_tree_small_02_v1.png` | 64×64 | `(21,26,21,38)` | `(117,634,207,769)` | `907f22a378b064941e7bf92aba877dd1ac9eb08e31f3b2c29c494d16954d9d1e` | Boundary sapling | Yes |
| `shrubs/caden_bush_medium_01_v1.png` | 64×32 | `(20,8,24,24)` | `(583,350,700,430)` | `71d4f3883c0cb48ba20b05dea8288fc877b4031aeda2fe4a137141317e6b9c56` | Blocked building edge | Yes |
| `shrubs/caden_bush_medium_02_v1.png` | 64×32 | `(16,7,32,25)` | `(699,350,807,430)` | `b7aa6706bd868e828e7c1843535b484eefe2b7416a172cf454c19d85ccb60fe5` | Blocked building edge | Yes |
| `shrubs/caden_bush_medium_03_v1.png` | 64×32 | `(13,6,37,26)` | `(812,350,924,432)` | `d488ebf7a5e5a1b0e198e098c977047d7337c285df376ae75966255a5249cc28` | Blocked building edge | Yes |
| `shrubs/caden_shrub_small_01_v1.png` | 32×32 | `(7,11,17,21)` | `(590,520,665,586)` | `1b6f822eeb9344af4964b798596d8397d3bbb46c0df8b094ca1de4176d4e3d51` | Low edge shrub | No |
| `shrubs/caden_shrub_small_02_v1.png` | 32×32 | `(8,11,16,21)` | `(665,520,738,586)` | `9f0d898a81bce8dbb726e2d132b50ad0fef987cbce8f4aa46af8184d1ba3ed4c` | Low edge shrub | No |
| `shrubs/caden_shrub_small_03_v1.png` | 32×32 | `(8,11,16,21)` | `(800,520,860,586)` | `6f18c869d556e9d37128a8cc78a2dfcd6348fe078c9293189ff89d575f6d5113` | Restrained flowering edge shrub | No |
| `rocks/caden_rock_small_01_v1.png` | 32×32 | `(6,13,20,19)` | `(407,918,469,980)` | `1314c6e6e33e4e32588980a7d74821f7ca0f8d27002801926ed45f1c861f4887` | Low ground detail | No |
| `rocks/caden_rock_small_02_v1.png` | 32×32 | `(7,10,17,22)` | `(466,908,518,976)` | `db8d584dcb72613b99e58dfa0d3ec7c034bb3d9ac8735bc22c6df06252b8beb6` | Low ground detail | No |
| `rocks/caden_rock_cluster_01_v1.png` | 32×32 | `(5,15,22,17)` | `(487,814,557,905)` | `1918ff6469b3684e84aba4c5ea6d7437d87894f280c84b5cf2fab0d629927660` | Boundary rock cluster | Yes |

## Ground atlas manifest

`ground/caden_nature_ground_runtime_v1.png` is a 96×96 transparent atlas with nine exact 32×32 cells. Its SHA-256 is `9a9cf0889528763c2cdbdbe4b7d5fb755c5df9247529f9dcf2e5e5864190f045`. `ground/caden_nature_ground_runtime_v1.tres` exposes those cells through one 32×32 `TileSetAtlasSource` for later reuse. Town Square currently uses deterministic `Sprite2D` frames from the atlas because this sparse fourteen-placement pass does not justify serialized TileMap data.

| Cell | Identifier | Source crop |
| --- | --- | --- |
| `(0,0)` | `flower_01` | `(1002,112,1092,180)` |
| `(1,0)` | `flower_02` | `(1090,112,1180,180)` |
| `(2,0)` | `flower_03` | `(1178,112,1265,180)` |
| `(0,1)` | `flower_04` | `(1263,112,1354,180)` |
| `(1,1)` | `flower_05` | `(1354,112,1445,180)` |
| `(2,1)` | `tuft_01` | `(1008,835,1093,895)` |
| `(0,2)` | `tuft_02` | `(1092,835,1178,895)` |
| `(1,2)` | `tuft_03` | `(1180,835,1267,895)` |
| `(2,2)` | `tuft_04` | `(1268,835,1355,895)` |

## Town Square placement

- Medium trees: `(32,240)`, `(928,528)`, `(32,512)`, `(928,208)`.
- Small trees/saplings: `(32,656)`, `(928,96)`.
- Medium bushes: `(80,160)`, `(768,256)`, `(208,160)`, `(880,608)`, `(80,608)`, `(896,255)`.
- Small shrubs: `(208,608)`, `(752,608)`, `(240,128)`.
- Small rocks and cluster: `(272,80)`, `(688,640)`, `(928,640)`.
- Ground overlays: `(272,176)`, `(336,176)`, `(240,192)`, `(736,224)`, `(112,240)`, `(192,224)`, `(80,464)`, `(208,464)`, `(752,464)`, `(880,464)`, `(272,640)`, `(624,640)`, `(576,80)`, `(336,80)`.

Tree bases and the dense rock-cluster base are on the existing perimeter boundary. Medium-bush bases sit at existing building-footprint edges, outside door approach widths. The small rocks, small shrubs, flowers, and tufts are low nonblocking details. No canopy intentionally overlaps an entry marker, transition threshold, NPC, door, reserved-space circulation area, or the Terrebonne route.

The scene hierarchy is `Nature/GroundOverlays`, `Nature/LowVegetation`, `Nature/Trees`, and `Nature/Rocks`. It is ordered after terrain and before solid scenery and actors, with no scripts or physics descendants.

## Protected clearance relationship

- All four principal routes retain their locked four-tile width.
- A full 32×32 tile remains clear around each entry marker and beyond each transition corridor edge.
- Door approaches retain approximately 48–64 pixels of clear frontal space.
- Both NPC interaction approaches retain approximately 48 pixels.
- The central plaza interior and reserved 3×3 community space contain no Nature nodes.
- The northeastern Terrebonne branch remains visible; nature neither obstructs nor explains the closure.

## Deferred categories

- Large forest-scale trees, fallen logs, and large stumps: reserve for the Commons or wilderness-oriented exteriors.
- Vines and building-wall climbers: defer until architecture overlays and occlusion are planned.
- Potted plants, barrel planters, and formal planters: defer to the props pass.
- Hedge systems: defer until a later layout can support their implied solidity without new collision.
- Fruit trees, unusual fantasy plants, glowing plants, and Edenite-bearing vegetation: excluded because they could imply unapproved identity or lore.

## Known limitations and manual cleanup candidates

- The 3:1 reduction intentionally favors crisp gameplay readability over preservation of all source micro-detail.
- Source-integrated shadow edges are hard-alpha reconstructed; inspect for any single-pixel roughness against the runtime grass.
- The two small-tree canvases contain generous upper padding relative to their reduced silhouettes; retain for stable anchors unless manual Aseprite review proves a tighter shared standard preferable.
- Medium bushes should be checked beside final building-edge props before their density is treated as final.
- Any later desire for softer but still pixel-clean shadow dithering, more exact silhouette surgery, or isolated hedge end/corner pieces should be handled as tracked Aseprite cleanup—not ad hoc runtime repainting.

## Manual review checklist

Review in Godot at the 640×360 internal viewport for tree scale and canopy size; trunk visibility; shrub density; flower saturation; terrain repetition; route, door, window, porch, step, NPC, prompt, entry, exit, Terrebonne-branch, and reserved-space readability; upper-left lighting consistency; contact shadows; alpha halos and presentation-background remnants; edge clipping; camera movement near tall assets; and whether Town Square remains an open maintained town rather than woodland. Automated tests do not constitute visual approval.
