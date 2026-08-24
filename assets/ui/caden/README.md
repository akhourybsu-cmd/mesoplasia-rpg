# Caden UI Runtime Assets

This directory contains deterministic runtime derivatives of the immutable Caden UI source masters.

- `panels/` — binary-alpha panel, nameplate, and divider textures.
- `icons/` — 24×24 navigation and objective-state atlases.
- `keycaps/` — 24×24 blank keycap-state atlas; letters remain dynamic UI text.
- `caden_ui_runtime_manifest_v1.json` — authoritative crop, cell, and source-hash mapping.

Regenerate with `tools/art/prepare_caden_ui_runtime_v1.py --prepare-runtime`. Do not hand-edit generated PNGs or resource mappings; update the reviewed source mapping in the tool and repeat the documented review instead.
