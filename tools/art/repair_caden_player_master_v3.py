#!/usr/bin/env python3
"""Create the Caden Player v3 master through explicit, non-generative edits.

The repair preserves the audited v1 bytes, moves all four up-facing cells down
16 source pixels, copies a four-row crown cap from r4c3 into the two clipped
up-facing frames, and clears the documented seven-pixel r3c2 artifact.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source_art/caden/characters/player/caden_player_character_master_v1.png.png"
DESTINATION = ROOT / "assets/source_art/caden/characters/player/caden_player_character_master_v3.png"

EXPECTED_SOURCE_SHA256 = "865bfbe417db5eaf04aad05d511c6c8a5809289025ead4f213afdad2a948c0b1"
SHEET_SIZE = (1060, 1484)
CELL_SIZE = (265, 371)
UP_ROW = 3
UP_SHIFT_Y = 16

# r4c3 has a complete narrow crown cap on rows 5..8. Aligning the donor
# head center to r4c2/r4c4 requires an 8-pixel horizontal translation. The
# cap is placed on rows 12..15, immediately above the shifted target crowns.
CROWN_DONOR_COLUMN = 2
CROWN_SOURCE_ROWS = (5, 9)
CROWN_TARGET_COLUMNS = (1, 3)
CROWN_OFFSET_X = 8
CROWN_TARGET_Y = 12

# Inclusive local coordinates from the audited v1 r3c2 artifact.
ARTIFACT_COLUMN = 1
ARTIFACT_ROW = 2
ARTIFACT_X_RANGE = (119, 125)
ARTIFACT_Y = 370


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _cell_box(column: int, row: int) -> tuple[int, int, int, int]:
    width, height = CELL_SIZE
    return (
        column * width,
        row * height,
        (column + 1) * width,
        (row + 1) * height,
    )


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def main() -> int:
    if not SOURCE.is_file():
        raise FileNotFoundError(SOURCE)
    source_hash_before = _sha256(SOURCE)
    if source_hash_before != EXPECTED_SOURCE_SHA256:
        raise ValueError(
            f"Protected v1 hash mismatch: expected {EXPECTED_SOURCE_SHA256}, got {source_hash_before}"
        )

    with Image.open(SOURCE) as opened:
        if opened.size != SHEET_SIZE or opened.mode != "RGBA":
            raise ValueError(f"Expected RGBA {SHEET_SIZE}, got {opened.mode} {opened.size}")
        source = opened.copy()

    repaired = source.copy()
    width, height = CELL_SIZE

    for column in range(4):
        cell = source.crop(_cell_box(column, UP_ROW))
        shifted = Image.new("RGBA", CELL_SIZE, (0, 0, 0, 0))
        shifted.alpha_composite(cell, (0, UP_SHIFT_Y))
        repaired.paste(shifted, (column * width, UP_ROW * height))

    donor = source.crop(_cell_box(CROWN_DONOR_COLUMN, UP_ROW))
    crown = donor.crop((0, CROWN_SOURCE_ROWS[0], width, CROWN_SOURCE_ROWS[1]))
    for target_column in CROWN_TARGET_COLUMNS:
        repaired.alpha_composite(
            crown,
            (
                target_column * width + CROWN_OFFSET_X,
                UP_ROW * height + CROWN_TARGET_Y,
            ),
        )

    artifact_global_y = ARTIFACT_ROW * height + ARTIFACT_Y
    for local_x in range(ARTIFACT_X_RANGE[0], ARTIFACT_X_RANGE[1] + 1):
        repaired.putpixel(
            (ARTIFACT_COLUMN * width + local_x, artifact_global_y),
            (0, 0, 0, 0),
        )

    _save_png(repaired, DESTINATION)
    source_hash_after = _sha256(SOURCE)
    if source_hash_after != source_hash_before:
        raise RuntimeError("Protected v1 source changed during repair.")

    print(f"source={SOURCE.relative_to(ROOT).as_posix()}")
    print(f"source_sha256_before={source_hash_before}")
    print(f"source_sha256_after={source_hash_after}")
    print(f"destination={DESTINATION.relative_to(ROOT).as_posix()}")
    print(f"destination_sha256={_sha256(DESTINATION)}")
    print("up_row_translation=16")
    print("crown_patch=r4c3 rows 5..8 -> r4c2/r4c4 rows 12..15, x offset +8")
    print("artifact_clear=r3c2 x119..125 y370")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
