# Caden Residential Quarter Reconstruction Gate v1

## Scope

This gate follows visual approval of Marketplace Runtime v1 and a conformance review of the already validated Town Square. It reconstructed the live Residential Quarter contract, captured its untouched runtime, and presented a composition plan and native-scale candidate shortlist. The user subsequently approved the recommended shortlist and requested a fuller, properly aligned neighborhood with enough NPCs. Commons remains outside this pass.

## Live contract

- Scene: `res://scenes/world/caden/Residential.tscn`
- Bounds and camera: `1152 x 768`
- Ten fixed cabin bodies with `128 x 96` collision at `(160,128)`, `(384,160)`, `(608,128)`, `(800,176)`, `(1024,128)`, `(160,592)`, `(400,624)`, `(752,608)`, `(992,576)`, and `(1024,256)`
- Three fixed yard-fence bodies with `192 x 24` collision at `(160,240)`, `(784,272)`, and `(240,512)`
- Protected west-east route: `128` pixels high from `y=320` through `y=448`
- Protected Commons route: `128` pixels wide from `x=512` through `x=640`
- Four existing household lanes remain authoritative
- Town Square entry marker `(128,384)` and exit `(64,384)`
- Commons entry marker `(576,640)` and exit `(576,704)`
- Existing interactive NPCs: `HomeResident` and `PathResident`, with their dialogue and facing unchanged

## Composition plan

The fixed homes form four quiet household groups: northwest gardens, northeast yards, southwest homes, and southeast garden homes. Public circulation remains a broad west-east lane with one clear southward Commons branch. Domestic density belongs between home foundations and private yard edges; the public route stays open and visually dominant. Fences and hedges should define yards without creating a maze, and every gate or stepping path must align with a fixed lane or implied doorway.

## Candidate disposition

Recommended shortlist: `caden_sp_res_01`, `04`, `05`, `06`, `08`, `09`, and `11`.

Scale-compatible alternates: `02`, `03`, `10`, `13`, `14`, and `15`.

Deferred: `07`, `12`, `16`, and mega composites `01` and `02`. These overlap established civic/rest vocabulary, contain locked shed or tree/bench geometry, complicate collision and sorting, or require an exact-yard fit that is not yet proven.

All 24 available Residential and townwide house masters remain rejected for unsuitable baked shadows. Rejection status is preserved even when a house silhouette appears visually attractive on a contact sheet.

## Required cleanup after selection

Every selected set piece requires exact `0.1875` nearest-neighbor normalization, hard-pixel cleanup, removal of broad presentation shadows and bright fringe, transparent-RGB sanitation, a structural ground-contact pivot, object-specific collision, and a second native-size audit. Runtime PNGs must import at scale `1.0`. No source master enters `res://` before selection.

## Tooling and evidence

`render_caden_residential_baseline_v1.gd` captures the untouched live scene at native full-zone and `640 x 360` gameplay resolutions with exact `1280 x 720` nearest-neighbor proof.

`build_caden_residential_reconstruction_gate_v1.py` verifies all 222 manifest rows and 297 package checksums, rechecks the 18 candidate hashes and binary-alpha/edge contract, builds the full-zone composition plan and native-scale player comparison, records all dispositions and metadata, and checksums the external package.

## Approval boundary

Approval selected `01`, `04`, `05`, `06`, `08`, `09`, and `11` for a limited Residential runtime pass. The follow-up population request authorized five bounded ambient walkers while preserving both existing dialogue NPCs. It did not authorize an alternate, deferred asset, mega composite, rejected building, new dialogue, sign, business, lore, Commons modification, or broader integration. The next gate is the Residential in-engine comparison.
