# Caden NPC Variant Source Masters

Each child directory is an asset identifier, not a story-character assignment.

- `*_master_v1.png` is the immutable supplied source. It remains RGB with its baked checkerboard so the original bytes and provenance are preserved.
- `*_master_v2.png` is the reviewed production source master. It uses binary transparency and keeps all sixteen sprites inside their 265×371 source cells.
- Runtime 40×56 atlases, character records, names, occupations, and scene placement are intentionally outside this source-art folder and are not implied by these descriptive variant identifiers.

The repeatable preparation tool is `tools/art/prepare_caden_npc_variant_masters_v1.py`. Detailed mechanical results are stored in `docs/art/audits/caden_npc_variant_masters_v1.json`.
