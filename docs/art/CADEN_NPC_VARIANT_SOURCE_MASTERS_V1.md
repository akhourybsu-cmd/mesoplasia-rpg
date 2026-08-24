# Caden NPC Variant Source Masters V1

## Scope

Eight supplied Caden NPC variant sheets were ingested as source art only. The filenames remain descriptive asset identifiers; this work does not assign a name, occupation, story role, location, or canonical demographic to an in-game NPC.

No runtime atlas or scene placement was created. Runtime normalization should be handled separately so stature and silhouette differences can be reviewed in-world without accidentally normalizing dwarven, elven, half-elven, or human proportions to one height.

## Storage contract

The source assets live at:

`assets/source_art/caden/characters/npc/variants/<variant_id>/`

Each folder contains:

- an immutable `*_master_v1.png` copied byte-for-byte from the supplied file;
- a deterministic `*_master_v2.png` prepared for production use.

All sheets retain the established 1060×1484 source layout: four columns by four rows, with 265×371 source cells. Rows are down, left, right, and up. Columns are neutral, step A, passing/contact, and step B.

## Audit findings and repairs

All eight supplied v1 files were RGB images with the visible checkerboard baked into the pixels. They therefore required conversion to true transparency.

The following four sheets also had up-facing hair or head pixels split across the row-3/row-4 boundary:

- `half_elf_young_nonbinary_01`
- `elf_older_woman_01`
- `elf_younger_man_01`
- `human_middle_man_01`

For those sheets, the four complete up-facing silhouettes were recovered from the original pixels and translated down to safe source-cell headroom. The other four sheets retained every frame at its original position.

The repair was deterministic: primary-silhouette extraction, binary alpha, and translation-only boundary recovery. It did not repaint, generate, resize, mirror, interpolate, or warp the art.

## Result

Every v2 master passed the focused source gate:

- PNG, RGBA, and binary alpha;
- 1060×1484 dimensions;
- sixteen nonempty frames;
- no visible pixel on a source-cell boundary;
- original direction and pose order retained;
- supplied v1 SHA-256 unchanged before and after preparation.

The machine-readable per-frame bboxes, edge counts, translations, and SHA-256 values are in `docs/art/audits/caden_npc_variant_masters_v1.json`.
