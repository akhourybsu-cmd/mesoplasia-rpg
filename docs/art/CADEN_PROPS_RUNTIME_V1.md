# Caden Neutral Props Runtime v1

## Scope and failure-gate result

This visual-only pass prepares a restrained neutral prop vocabulary for Caden Town Square. It adds no identity, lore, interaction, pickup behavior, inventory behavior, dynamic lighting, animation, or reusable prop framework. The required bench, ordinary lantern post, fence, barrel, and luggage failure-gate representatives all passed after the travel crop was tightened to exclude the market-stall row.

## Protected inputs

| Input | SHA-256 before preparation |
| --- | --- |
| `assets/source_art/caden/props/caden_props_master_v1.png` | `1bec25a3cb6928014a893cbbd9e04d3b4d4cd9105171df45318037098446ae53` |
| Terrain Runtime v1.1 PNG | `bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a` |
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

## Source inspection

- The Props master decodes as 1536×1024 RGBA. Source alpha ranges from 0 to 254; no pixel is fully opaque.
- It uses a smooth transparent-to-warm-brown gradient presentation background rather than a flat transparent canvas. Retained RGB and partial alpha would produce obvious rectangular haze or colored fringes if copied directly.
- Short painted contact shadows are integrated with many displayed props.
- There are no section labels, divider lines, or borders. Neighboring silhouettes generally do not overlap, but close spacing means broad crops can include unrelated pixels.
- The selected neutral candidates share a slight three-quarter perspective and upper-left light direction closely enough for one runtime set.
- Fixed crop rectangles and deterministic border-flood segmentation isolate the selected assets without repainting. The blue notice board, blue bedroll, carts, stalls, banner fixtures, and crystal-bearing objects were excluded instead of recolored or reconstructed.

## Processing method

`tools/art/prepare_caden_props_runtime_v1.py` verifies every protected hash before writing. For each recorded crop it:

1. Floods the smoothly changing presentation background inward from all four crop borders, accepting only neighboring RGBA steps whose Euclidean distance is at most 12.
2. Reconstructs the result as binary alpha, eliminating partial-alpha haze and matte pixels.
3. Crops to surviving foreground bounds, reduces exactly 3:1 with nearest-neighbor sampling, and crops again after reduction.
4. Applies the common neutral harmonization: saturation ×0.90, contrast ×0.94, brightness ×0.95.
5. Places the sprite on its documented canvas with a bottom-center anchor and final-row ground contact.

No bilinear or bicubic scaling, blur, rotation, mirroring, perspective correction, generative replacement, or untracked repainting is used.

## Runtime sprite manifest

Visible bounds use `(x, y, width, height)`. Every sprite uses a bottom-center anchor; its ground-contact line is the final canvas row. Transparent padding is directly derivable from the canvas and visible bounds.

| Category / file | Canvas | Visible bounds | Source crop `(l,t,r,b)` | SHA-256 | Implies collision |
| --- | ---: | --- | --- | --- | --- |
| Seating — `caden_bench_01_v1.png` | 96×64 | `(21,18,53,46)` | `(5,70,205,240)` | `49c5ec39182644f034d691626af90770084b3a5924c6dc2f4e42410868e35b79` | Yes |
| Seating — `caden_bench_02_v1.png` | 64×64 | `(10,26,43,38)` | `(400,88,540,230)` | `b5363f4e1616c517864e717f3f88b5596a8f9bb516d6e8f82d0f77885bd075df` | Yes |
| Lighting — `caden_lantern_post_01_v1.png` | 32×96 | `(7,24,17,72)` | `(545,10,625,245)` | `705640a25a52bfddaf1dd624b2e301d6e01c6eaf88cfee717a7f6b6e0e341c59` | Yes |
| Lighting — `caden_ground_lantern_01_v1.png` | 32×64 | `(6,28,19,36)` | `(275,450,335,560)` | `4fcdf7d84a73a6026cd4cd38e72d5a6e482df9a621693682a3e6abc01df2908c` | No |
| Fences — `caden_fence_straight_01_v1.png` | 96×64 | `(9,30,78,34)` | `(5,235,265,400)` | `3f2c330f73edcea4cbf438eff7a9da3cff83a800df304bca3105578ac96065bf` | Yes |
| Fences — `caden_fence_corner_01_v1.png` | 64×64 | `(10,21,43,43)` | `(265,235,415,400)` | `1e5594b37e9340155861839c4124215ba13a162dbadd73e1966261a8f548c637` | Yes |
| Fences — `caden_fence_gate_01_v1.png` | 64×64 | `(11,31,42,33)` | `(405,235,550,400)` | `876bbd3f59c18e969294248a9ddea6dabffe5466cf85f1119811074ccf77a35c` | Yes |
| Fences — `caden_fence_end_01_v1.png` | 32×64 | `(5,29,22,35)` | `(545,235,615,400)` | `2e4f396a9241f0d86916fb49f8a31493e0166270c35fa4ded91877b7585919ef` | Yes |
| Planters — `caden_planter_box_01_v1.png` | 96×64 | `(18,19,60,45)` | `(1000,65,1215,235)` | `27bd2c5c79206ae766d8b36b21431e0d9bf6e67db5a6da22d1e55d681a7d3782` | No |
| Planters — `caden_planter_box_02_v1.png` | 64×64 | `(13,25,38,39)` | `(1210,60,1350,235)` | `c795d44f6d42242f9dbd88df45632e8b0fc8822e2d8da8c5a33dbaef42a6f7c8` | No |
| Storage — `caden_barrel_01_v1.png` | 64×64 | `(17,28,30,36)` | `(10,385,110,555)` | `6ba3230d218aa0659c3fe2d22d4f74afb5c6019f461155434b3b0bcfdd8c1e55` | Yes |
| Storage — `caden_barrel_02_v1.png` | 64×64 | `(14,20,36,44)` | `(100,375,215,555)` | `0cc377a6f04baa9995da2cfd097c000883b1f9146e80ce4fc76291cb95297c3d` | Yes |
| Storage — `caden_crate_01_v1.png` | 64×64 | `(16,22,31,42)` | `(325,390,430,555)` | `927fe189ec720bbf0eb1575fdbcb21dace7e27f27b3329d04e40cf13bd45a9fb` | Yes |
| Storage — `caden_crate_02_v1.png` | 64×64 | `(17,30,30,34)` | `(430,380,545,555)` | `be608df14dfd73ed49b4e1e98f683e45567ee640faec5b8a1ea57d0b7307b6a3` | Yes |
| Storage — `caden_sack_cluster_01_v1.png` | 64×64 | `(7,33,49,31)` | `(955,405,1110,550)` | `df6d76760b092a75753f8ea10889416e6a14452948e1184b586283679f8bad95` | Yes |
| Storage — `caden_storage_cluster_01_v1.png` | 64×64 | `(8,18,48,46)` | `(555,380,720,560)` | `825732a76e08e1bacdd635ad42ba9227e0c205cd90a15521caea5db905d668c0` | Yes |
| Travel — `caden_luggage_bundle_01_v1.png` | 64×64 | `(11,29,42,35)` | `(0,535,165,675)` | `147b1345512ac5faf2a1754e2e19109a83b460a3b9cee5bb5810fd55994367d1` | No |
| Travel — `caden_luggage_bundle_02_v1.png` | 64×64 | `(13,31,38,33)` | `(155,535,310,675)` | `d6973d5921940315aa03dee3e01460b0b3f1a90538eaab091fd5c5d592e507b4` | No |
| Travel — `caden_travel_pack_01_v1.png` | 64×64 | `(21,28,22,36)` | `(450,535,545,675)` | `8d74fb7dc0f439bfb113b7bd2715f672e311273e90468f0a4cb3f3dd099a9caf` | No |
| Signage — `caden_signpost_blank_01_v1.png` | 64×64 | `(13,7,37,57)` | `(1025,230,1185,405)` | `c9761623de0099b3b84dd9909298f713d38546f31ab548a175c6ac5b75d64ede` | Yes |

The signpost, gate, second barrels/crates, second luggage bundle, and several other prepared variants remain available but unplaced. Their preparation does not authorize identity, readable text, interaction, or gameplay.

## Per-asset canvas metrics

All entries use exact 1:3 nearest-neighbor reduction. Padding is `(left, top, right, bottom)` in runtime pixels. Anchors use canvas coordinates, and the zero-indexed ground row is the last row of each canvas. “Integrated” means the source contact darkening was not separated into an independent shadow asset and remains contained by the documented visible bounds.

| Runtime file | Padding | Bottom-center anchor | Ground row | Contact-shadow bounds/method |
| --- | --- | --- | ---: | --- |
| `caden_bench_01_v1.png` | `(21,18,22,0)` | `(48,64)` | 63 | Scene shadow when placed: local `(-32,-8)` to `(36,2)` |
| `caden_bench_02_v1.png` | `(10,26,11,0)` | `(32,64)` | 63 | Scene shadow when placed: local `(-26,-8)` to `(30,2)` |
| `caden_lantern_post_01_v1.png` | `(7,24,8,0)` | `(16,96)` | 95 | Scene shadow when placed: local `(-5,-5)` to `(11,2)` |
| `caden_ground_lantern_01_v1.png` | `(6,28,7,0)` | `(16,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_fence_straight_01_v1.png` | `(9,30,9,0)` | `(48,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_fence_corner_01_v1.png` | `(10,21,11,0)` | `(32,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_fence_gate_01_v1.png` | `(11,31,11,0)` | `(32,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_fence_end_01_v1.png` | `(5,29,5,0)` | `(16,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_planter_box_01_v1.png` | `(18,19,18,0)` | `(48,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_planter_box_02_v1.png` | `(13,25,13,0)` | `(32,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_barrel_01_v1.png` | `(17,28,17,0)` | `(32,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_barrel_02_v1.png` | `(14,20,14,0)` | `(32,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_crate_01_v1.png` | `(16,22,17,0)` | `(32,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_crate_02_v1.png` | `(17,30,17,0)` | `(32,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_sack_cluster_01_v1.png` | `(7,33,8,0)` | `(32,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_storage_cluster_01_v1.png` | `(8,18,8,0)` | `(32,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_luggage_bundle_01_v1.png` | `(11,29,11,0)` | `(32,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_luggage_bundle_02_v1.png` | `(13,31,13,0)` | `(32,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_travel_pack_01_v1.png` | `(21,28,21,0)` | `(32,64)` | 63 | Integrated within visible bounds; no separate scene shadow |
| `caden_signpost_blank_01_v1.png` | `(13,7,14,0)` | `(32,64)` | 63 | Integrated within visible bounds; unplaced |

## Contact shadows and collision

The binary extraction retains source-integrated crisp contact-darkening where it survives border segmentation. Low and building-edge props require no additional shadow node. The four freely walkable substantial placements receive short lower-right scene-level `Polygon2D` shadows with no scripts or physics.

| Placed prop | Position | Collision shape | Collision center | Scene shadow bounds |
| --- | ---: | ---: | ---: | --- |
| Plain west bench | `(160,240)` | Rectangle 52×10 | `(160,235)` | local `(-26,-8)` to `(30,2)` |
| Flowered east bench | `(784,440)` | Rectangle 64×10 | `(784,435)` | local `(-32,-8)` to `(36,2)` |
| North lantern post | `(368,144)` | Rectangle 12×10 | `(368,139)` | local `(-5,-5)` to `(11,2)` |
| South lantern post | `(576,496)` | Rectangle 12×10 | `(576,491)` | local `(-5,-5)` to `(11,2)` |

No physics layer, navigation obstacle, movable body, area, interaction component, or script is added. Fence bases and substantial storage clusters are placed on existing perimeter/building collision, so duplicate collision would be unnecessary.

## Town Square placement and clusters

Placed counts: 2 benches, 3 lights, 4 fence pieces, 2 planters, 3 storage props, and 2 travel props—16 placements total.

- West maintained cluster: planter `(208,224)` beside a plain bench `(160,240)` at the edge of the quiet grass pocket north of the west route.
- East maintained cluster: planter `(720,440)` beside the flowered bench `(784,440)`, below the east route and outside the southeastern building collision.
- Route-edge lighting: ordinary posts at `(368,144)` and `(576,496)`, outside the locked north/south corridor rectangles; a small ground lantern at `(248,576)` accompanies the southwest storage cluster.
- Perimeter boundary: straight fences at `(128,672)` and `(832,672)`, an end at `(224,672)`, and a corner at `(736,672)`. Their bases sit on the existing south boundary collision and stay clear of the Commons route.
- Building-edge storage: barrel `(64,144)`, mixed storage `(224,576)`, and sacks `(736,576)` lie on existing blocked building-footprint edges and receive no duplicate collision.
- Travel details: luggage `(256,624)` and a neutral green travel pack `(704,624)` remain flat, noninteractive, and outside the Commons corridor.

The reserved 96×96 community space, plaza center, four 128-pixel principal corridors, entry and exit clearances, five door approaches, both NPC approaches, and the Terrebonne branch remain unoccupied. The blank signpost is intentionally unplaced to avoid implying directions or an institution.

## Excluded categories and likely future use

- Crystal lamps, blue-glowing fixtures, banner-bearing lamps, blue ropes, Festival fabric, road decorations, and the blue-roof notice board: defer to the separately approved Edenite/Festival accent decision, if appropriate.
- Full market stalls and vendor carts: reserve for Marketplace planning.
- Covered wagons and large carts: reserve for Wayfarer’s Approach planning.
- Barricades and road-blocking arrangements: reserve for a dedicated Terrebonne-closure decision; they do not explain the current closure here.
- Treasure-like chests, weapons, readable signs, and pickups: exclude until their gameplay and content purpose is explicitly approved.
- Domestic clutter and laundry: reserve for Residential Quarter planning.
- Topiary and large formal planters: exclude because they would make Town Square too formal or define civic landscaping.

## Known limitations and manual review

- Border-flood extraction deliberately removes the softest source-background-connected shadows; scene shadows replace only what is necessary for placed collidable props.
- A few single-pixel source shadow details remain around low storage silhouettes and should be judged against runtime grass rather than removed automatically.
- The prepared set contains one neutral post-lantern silhouette; variety is supplied by a small ground lantern rather than fabricating a second post.
- Fence perspective is source-consistent but requires manual judgment when seen against the bottom boundary.
- The flowered bench and planters require saturation review beside Nature Runtime v1.

Manual Aseprite cleanup candidates, only if visual review justifies a later approved polish pass, are: isolated one-pixel remnants around the sack, storage, and luggage silhouettes; flower-edge saturation on the flowered bench and planters; fence-foot contacts at the south boundary; and the lantern glass highlight. The blank signpost should remain untouched and unplaced until a content use is approved.

## Validation previews

- `caden_props_runtime_v1_failure_gate.png` — the five-category extraction gate.
- `caden_props_runtime_v1_lineup.png` — every prepared sprite at native scale by category.
- `caden_props_runtime_v1_palette_review.png` — full-color, grayscale, and reduced-saturation lineup review.
- `caden_props_runtime_v1_anchor_overlay.png` — canvas, contact row, and bottom-center anchors.
- `caden_props_runtime_v1_collision_overlay.png` — the four scene-local primitive collision placements.
- `caden_props_runtime_v1_clearance_overlay.png` — locked route, entry, door, NPC, reserved-space, and prop bounds.
- `caden_props_runtime_v1_town_square_preview.png` — Terrain v1.1, Architecture v1.1, Nature v1, and Neutral Props v1 together.
- `caden_town_square_nature_vs_props_comparison.png` — before/after density and readability comparison.

Manual Godot review at 640×360 remains required for all prop scale, density, cluster composition, plaza openness, route and door access, NPC/Player/prompt readability, collision feel and snagging, collision gaps, tall-prop occlusion, shadows, lighting consistency, halos, boundary clipping, camera movement, modest-town character, and accidental business, institution, or Festival implications. Automated tests establish technical integrity, not visual approval.
