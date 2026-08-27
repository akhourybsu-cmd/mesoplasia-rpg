#!/usr/bin/env python3
"""Validate and assemble the external Wayfarer Gate 1 visual-review package."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_NAME = "wayfarer_gate1_screenshot_manifest_v2.json"
BOARD_NAME = "wayfarer_gate1_comparison_board_v2.png"
CHECKSUM_JSON_NAME = "wayfarer_gate1_tool_and_artifact_checksums_v2.json"
CHECKSUM_TEXT_NAME = "SHA256SUMS.txt"
CAPTURE_SPECS = (
    (1, "caden_wayfarer_rest_area_before_640x360.png", "01  Rest area - baseline"),
    (2, "caden_wayfarer_rest_area_after_640x360.png", "02  Rest area - 05 placed"),
    (3, "caden_wayfarer_05_player_front_640x360.png", "03  05 - player in front"),
    (4, "caden_wayfarer_05_player_behind_640x360.png", "04  05 - player behind"),
    (5, "caden_wayfarer_hitching_area_before_640x360.png", "05  Hitching area - baseline"),
    (6, "caden_wayfarer_hitching_area_after_640x360.png", "06  Hitching area - 07 placed"),
    (7, "caden_wayfarer_07_player_front_640x360.png", "07  07 - player in front"),
    (8, "caden_wayfarer_07_player_behind_640x360.png", "08  07 - player behind"),
    (9, "caden_wayfarer_road_readability_after_640x360.png", "09  Road readability - both pilot assets"),
)
DISPLAY_CAPTURE = "caden_wayfarer_pilot_display_after_1280x720.png"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    filename = "segoeuib.ttf" if bold else "segoeui.ttf"
    path = Path("C:/Windows/Fonts") / filename
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def load_and_validate(review_root: Path) -> dict[str, object]:
    manifest_path = review_root / MANIFEST_NAME
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema") != "caden-wayfarer-gate-1-screenshot-manifest-v2":
        raise RuntimeError("Unexpected screenshot manifest schema.")
    entries = manifest.get("captures")
    if not isinstance(entries, list) or len(entries) != 10:
        raise RuntimeError("Gate 1 requires exactly ten screenshot manifest entries.")
    by_id = {entry["evidence_id"]: entry for entry in entries}
    if sorted(by_id) != list(range(1, 11)):
        raise RuntimeError("Gate 1 evidence IDs must be the contiguous range 1-10.")

    capture_root = review_root / "raw_captures"
    for evidence_id, entry in by_id.items():
        path = capture_root / entry["filename"]
        if not path.is_file():
            raise RuntimeError(f"Missing Gate 1 capture: {path}")
        expected_size = (640, 360) if evidence_id < 10 else (1280, 720)
        with Image.open(path) as image:
            image.load()
            if image.size != expected_size:
                raise RuntimeError(f"Unexpected dimensions for {path.name}: {image.size}")
        if sha256(path) != entry["sha256"]:
            raise RuntimeError(f"Manifest hash mismatch for {path.name}.")

    for evidence_id, filename, _label in CAPTURE_SPECS:
        if by_id[evidence_id]["filename"] != filename:
            raise RuntimeError(f"Evidence {evidence_id} does not use the expected stable filename.")
    if by_id[10]["filename"] != DISPLAY_CAPTURE:
        raise RuntimeError("Evidence 10 does not use the expected stable filename.")

    with Image.open(capture_root / CAPTURE_SPECS[-1][1]) as reference_image:
        reference = reference_image.convert("RGBA")
    with Image.open(capture_root / DISPLAY_CAPTURE) as display_image:
        display = display_image.convert("RGBA")
    expected_display = reference.resize((1280, 720), Image.Resampling.NEAREST)
    if display.tobytes() != expected_display.tobytes():
        raise RuntimeError("The 1280x720 display capture is not an exact nearest-neighbor 2x enlargement.")
    return manifest


def build_board(review_root: Path) -> Path:
    capture_root = review_root / "raw_captures"
    margin = 32
    column_gap = 24
    row_gap = 28
    header_height = 104
    label_height = 34
    capture_width = 640
    capture_height = 360
    panel_height = label_height + capture_height
    board_width = margin * 2 + capture_width * 3 + column_gap * 2
    board_height = header_height + panel_height * 3 + row_gap * 2 + margin
    board = Image.new("RGB", (board_width, board_height), (20, 23, 22))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 22), "Wayfarer Gate 1 - two-asset in-engine comparison", fill=(247, 243, 230), font=font(30, True))
    draw.text(
        (margin, 62),
        "All nine 640x360 frames are shown at native size. 05: rest lawn. 07: wagon and hitching area.",
        fill=(180, 190, 182),
        font=font(17),
    )

    for index, (_evidence_id, filename, label) in enumerate(CAPTURE_SPECS):
        column = index % 3
        row = index // 3
        x = margin + column * (capture_width + column_gap)
        y = header_height + row * (panel_height + row_gap)
        draw.text((x + 8, y + 5), label, fill=(242, 240, 231), font=font(17, True))
        with Image.open(capture_root / filename) as source:
            capture = source.convert("RGB")
        board.paste(capture, (x, y + label_height))
        draw.rectangle(
            (x, y + label_height, x + capture_width - 1, y + label_height + capture_height - 1),
            outline=(91, 101, 95),
            width=2,
        )

    output = review_root / BOARD_NAME
    board.save(output, compress_level=9)
    return output


def write_checksums(review_root: Path) -> tuple[Path, Path]:
    tool_paths = (
        ROOT / "tools/art/prepare_caden_wayfarer_pilot_runtime_v1.py",
        ROOT / "tools/art/render_caden_wayfarer_gate1_review_v2.gd",
        ROOT / "tools/art/build_caden_wayfarer_gate1_review_v2.py",
    )
    artifact_paths = sorted(
        path
        for path in review_root.rglob("*")
        if path.is_file() and path.name not in {CHECKSUM_JSON_NAME, CHECKSUM_TEXT_NAME}
    )
    checksum_json = review_root / CHECKSUM_JSON_NAME
    checksum_json.write_text(
        json.dumps(
            {
                "schema": "caden-wayfarer-gate-1-checksums-v2",
                "tools": {
                    path.relative_to(ROOT).as_posix(): sha256(path)
                    for path in tool_paths
                },
                "review_artifacts": {
                    path.relative_to(review_root).as_posix(): sha256(path)
                    for path in artifact_paths
                },
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
        newline="\n",
    )
    checksum_text = review_root / CHECKSUM_TEXT_NAME
    covered_paths = sorted(
        path for path in review_root.rglob("*") if path.is_file() and path.name != CHECKSUM_TEXT_NAME
    )
    checksum_text.write_text(
        "".join(f"{sha256(path)}  {path.relative_to(review_root).as_posix()}\n" for path in covered_paths),
        encoding="utf-8",
        newline="\n",
    )
    return checksum_json, checksum_text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("review_root", type=Path, help="External Gate 1 review directory created by the Godot renderer.")
    args = parser.parse_args()
    review_root = args.review_root.resolve()
    if ROOT == review_root or ROOT in review_root.parents:
        raise RuntimeError("Gate 1 review material must remain outside the Godot project tree.")
    load_and_validate(review_root)
    board = build_board(review_root)
    checksum_json, checksum_text = write_checksums(review_root)
    print(f"comparison={board}")
    print("captures=10")
    print("native_640x360_board=true")
    print("exact_2x_display=true")
    print(f"checksums={checksum_json}")
    print(f"sha256sums={checksum_text}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
