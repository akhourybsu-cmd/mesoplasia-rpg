#!/usr/bin/env python3
"""Build a checksummed Marketplace runtime-v1 versus lively-perimeter-v2 review."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
CAPTURE_MANIFEST = "marketplace_runtime_screenshot_manifest_v1.json"
VIEWS = (
    ("full_zone", "marketplace_full_zone_after_v1_896x640.png", (896, 640), "Full zone"),
    ("west_arrival", "marketplace_west_arrival_after_v1_640x360.png", (640, 360), "Wayfarer arrival"),
    ("primary_aisle", "marketplace_primary_aisle_after_v1_640x360.png", (640, 360), "Primary aisle"),
    ("north_districts", "marketplace_north_districts_after_v1_640x360.png", (640, 360), "North districts"),
    ("south_districts", "marketplace_south_districts_after_v1_640x360.png", (640, 360), "South districts"),
    ("south_transition", "marketplace_south_transition_after_v1_640x360.png", (640, 360), "Town Square opening"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    path = Path("C:/Windows/Fonts") / name
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def load_entries(root: Path) -> tuple[dict[str, object], dict[str, dict[str, object]]]:
    manifest_path = root / CAPTURE_MANIFEST
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    entries = {entry["filename"]: entry for entry in manifest["captures"]}
    return manifest, entries


def verified_capture(root: Path, entries: dict[str, dict[str, object]], filename: str, size: tuple[int, int]) -> Path:
    path = root / "raw_captures" / filename
    entry = entries.get(filename)
    if entry is None or not path.is_file() or sha256(path) != entry["sha256"]:
        raise RuntimeError(f"Missing or mismatched capture: {path}")
    with Image.open(path) as image:
        if image.size != size:
            raise RuntimeError(f"Unexpected capture dimensions for {path}: {image.size}")
    return path


def copy_views(source_root: Path, entries: dict[str, dict[str, object]], output_root: Path, state: str) -> None:
    captures = output_root / "raw_captures"
    for key, filename, size, _label in VIEWS:
        source = verified_capture(source_root, entries, filename, size)
        shutil.copy2(source, captures / f"marketplace_{key}_{state}_v2.png")


def build_board(output_root: Path) -> Path:
    captures = output_root / "raw_captures"
    margin = 32
    gap = 24
    column = 896
    header = 112
    full_row = 34 + 640
    focus_row = 34 + 360
    focus_views = VIEWS[1:]
    width = margin * 2 + column * 2 + gap
    height = header + full_row + gap + len(focus_views) * (focus_row + gap) + margin - gap
    board = Image.new("RGB", (width, height), (20, 24, 21))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 18), "Caden Marketplace lively perimeter v2", fill=(247, 243, 230), font=font(30, True))
    draw.text(
        (margin, 62),
        "Before: selective runtime v1. After: four ambient shoppers, grass-grounded tree layers, shrub understory, and fenced green edge.",
        fill=(185, 198, 188),
        font=font(16),
    )

    y = header
    for column_index, state in enumerate(("before", "after")):
        x = margin + column_index * (column + gap)
        draw.text((x + 8, y + 5), f"Full zone - {state}", fill=(242, 240, 231), font=font(17, True))
        with Image.open(captures / f"marketplace_full_zone_{state}_v2.png") as source:
            board.paste(source.convert("RGB"), (x, y + 34))
        draw.rectangle((x, y + 34, x + 895, y + 673), outline=(91, 103, 95), width=2)

    y += full_row + gap
    for key, _filename, _size, label in focus_views:
        for column_index, state in enumerate(("before", "after")):
            x = margin + column_index * (column + gap)
            draw.text((x + 8, y + 5), f"{label} - {state}", fill=(242, 240, 231), font=font(17, True))
            with Image.open(captures / f"marketplace_{key}_{state}_v2.png") as source:
                board.paste(source.convert("RGB"), (x, y + 34))
            draw.rectangle((x, y + 34, x + 639, y + 393), outline=(91, 103, 95), width=2)
        y += focus_row + gap

    path = output_root / "marketplace_lively_perimeter_comparison_board_v2.png"
    board.save(path, compress_level=9)
    return path


def write_readme(output_root: Path) -> Path:
    path = output_root / "MARKETPLACE_LIVELY_PERIMETER_REVIEW_V2.md"
    path.write_text(
        """# Caden Marketplace lively perimeter review v2

Review the native full-zone comparison first. This iteration adds four bounded, non-interactive Caden shoppers; moves every tree ground contact to the outer grass; increases the tree mass from ten to sixteen; layers shrub understory; and adds 22 narrow collidable fence segments between the market and green frame.

The west Wayfarer's Approach opening and south Town Square opening remain clear. The eight vendor bays, three interactive NPCs and dialogue, selected library assets, terrain, central circulation, transitions, and camera contract are unchanged.

This is a visual gate only. It does not authorize another library asset or work in Town Square, Residential Quarter, or Commons.
""",
        encoding="utf-8",
        newline="\n",
    )
    return path


def write_manifest(output_root: Path, before_root: Path, after_root: Path) -> Path:
    tool_paths = (
        ROOT / "tools/art/render_caden_marketplace_runtime_v1.gd",
        ROOT / "tools/art/build_caden_marketplace_lively_perimeter_review_v2.py",
        ROOT / "tests/caden_marketplace_runtime_test.gd",
    )
    manifest = {
        "schema": "caden-marketplace-lively-perimeter-review-v2",
        "gate_state": "marketplace_lively_perimeter_v2_pending_visual_approval",
        "before_render_root": str(before_root),
        "after_render_root": str(after_root),
        "scene_sha256": sha256(ROOT / "scenes/world/caden/Marketplace.tscn"),
        "changes": {
            "ambient_walkers": 4,
            "perimeter_trees": 16,
            "fence_segments": 22,
            "additional_library_assets": [],
        },
        "preserved_openings": ["west_wayfarers_approach", "south_town_square"],
        "tools": {path.relative_to(ROOT).as_posix(): sha256(path) for path in tool_paths},
    }
    path = output_root / "marketplace_lively_perimeter_review_manifest_v2.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    return path


def write_checksums(output_root: Path) -> Path:
    path = output_root / "SHA256SUMS.txt"
    files = sorted(item for item in output_root.rglob("*") if item.is_file() and item != path)
    path.write_text(
        "".join(f"{sha256(item)}  {item.relative_to(output_root).as_posix()}\n" for item in files),
        encoding="utf-8",
        newline="\n",
    )
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before_root", type=Path)
    parser.add_argument("after_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    before_root = args.before_root.resolve()
    after_root = args.after_root.resolve()
    output_root = args.output_root.resolve()
    if output_root == ROOT or ROOT in output_root.parents:
        raise RuntimeError("Review materials must remain outside res://.")
    (output_root / "raw_captures").mkdir(parents=True, exist_ok=True)
    before_manifest, before_entries = load_entries(before_root)
    after_manifest, after_entries = load_entries(after_root)
    copy_views(before_root, before_entries, output_root, "before")
    copy_views(after_root, after_entries, output_root, "after")
    metadata = output_root / "metadata"
    metadata.mkdir(exist_ok=True)
    (metadata / "before_capture_manifest.json").write_text(json.dumps(before_manifest, indent=2) + "\n", encoding="utf-8")
    (metadata / "after_capture_manifest.json").write_text(json.dumps(after_manifest, indent=2) + "\n", encoding="utf-8")
    board = build_board(output_root)
    readme = write_readme(output_root)
    manifest = write_manifest(output_root, before_root, after_root)
    checksums = write_checksums(output_root)
    print(f"board={board}")
    print(f"readme={readme}")
    print(f"manifest={manifest}")
    print(f"checksums={checksums}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
