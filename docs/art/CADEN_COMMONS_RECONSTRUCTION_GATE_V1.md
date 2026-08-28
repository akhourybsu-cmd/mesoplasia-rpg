# Caden Commons Reconstruction Gate v1

## Scope

This gate follows visual approval of Residential Runtime v1. It reconstructed the untouched Commons gameplay contract, captured its baseline runtime, and presented a full-zone composition plan and native-scale candidate shortlist. The user subsequently approved continuation with the recommended six candidates.

## Live contract

- Scene and camera bounds: `1024 x 704`
- Protected Town Square route: `128` pixels high from `x=0` through `x=576`, centered on `y=352`
- Protected Residential route: `128` pixels wide from `y=0` through `y=416`, centered on `x=512`
- Town Square entry marker `(128,352)` and exit `(64,352)`
- Residential entry marker `(512,128)` and exit `(512,64)`
- Quiet Green reserved area: `(608,128)` through `(928,576)`
- Fixed tree bodies: `96 x 96` at `(192,160)`, `(800,224)`, and `(768,512)`
- Fixed rock body: `64 x 48` at `(288,544)`
- Existing interactive NPC: `CommonsLocal` at `(704,400)`, with dialogue and facing authoritative

## Composition plan

The open eastern Quiet Green is the dominant anchor, not a building or monument. A maintained northwest grove frames the northern Residential approach. A restrained southwest natural edge supports the fixed rock footprint. Trees and undergrowth soften the eastern and southern boundaries without narrowing either transition. One rest pocket may sit beside, never within, a path. The center of the Quiet Green remains generous, walkable negative space.

## Candidate disposition

Recommended shortlist: `caden_sp_com_01`, `04`, `09`, `11`, `14`, and `20`.

Scale-compatible alternates: `02`, `03`, `05`, `08`, `10`, `12`, `13`, `15`, and `18`.

Deferred: `06`, `07`, `16`, `17`, `19`, both Town Square/Commons seam candidates, and Commons mega composites `01` and `02`. These introduce excessive collision complexity, rigid or civic geometry, sign authority, prohibited shelter architecture, paired changes to the validated Town Square, or unnecessary locked compositions.

Both Residential/Commons seam sources remain rejected for boundary fringe. No seam source is needed to preserve the current transition contracts.

## Required cleanup after selection

Every selected source requires exact nearest-neighbor normalization at its catalog factor, hard-pixel cleanup, removal of broad presentation shadows and bright fringe, transparent-RGB sanitation, a structural ground-contact pivot, object-specific collision, and a second native-size audit. Runtime PNGs must import at scale `1.0`. Meadow and flowers remain walkable; tree collision covers trunks rather than canopies.

## Approval boundary

Approval selected only `01`, `04`, `09`, `11`, `14`, and `20` for a limited Commons runtime pass. It did not authorize an alternate, deferred, rejected, seam, mega, shelter, pond, bridge, gazebo, stage, shrine, monument, new dialogue, lore, Festival structure, or gameplay change. The active gate is now the Commons in-engine comparison.
