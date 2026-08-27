#!/usr/bin/env python3
"""Build the external Wayfarer landscape-revision comparison package."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SOURCE_MANIFEST = "wayfarer_gate1_screenshot_manifest_v2.json"
BOARD_NAME = "wayfarer_landscape_revision_comparison_board_v3.png"
MANIFEST_NAME = "wayfarer_landscape_revision_manifest_v3.json"
CHECKSUM_NAME = "SHA256SUMS.txt"
COMPARISON_PAIRS = (
    (
        "caden_wayfarer_rest_area_after_640x360.png",
        "wayfarer_rest_area_before_landscape_640x360.png",
        "wayfarer_rest_area_after_landscape_640x360.png",
        "Rest area",
    ),
    (
        "caden_wayfarer_hitching_area_after_640x360.png",
        "wayfarer_hitching_area_before_landscape_640x360.png",
        "wayfarer_hitching_area_after_landscape_640x360.png",
        "Traveler yard and hitching area",
    ),
    (
        "caden_wayfarer_road_readability_after_640x360.png",
        "wayfarer_road_before_landscape_640x360.png",
        "wayfarer_road_after_landscape_640x360.png",
        "Road readability",
    ),
)
AFTER_SUPPORTING = (
    ("caden_wayfarer_05_player_front_640x360.png", "wayfarer_05_player_front_after_landscape_640x360.png"),
    ("caden_wayfarer_05_player_behind_640x360.png", "wayfarer_05_player_behind_after_landscape_640x360.png"),
    ("caden_wayfarer_07_player_front_640x360.png", "wayfarer_07_player_front_after_landscape_640x360.png"),
    ("caden_wayfarer_07_player_behind_640x360.png", "wayfarer_07_player_behind_after_landscape_640x360.png"),
    ("caden_wayfarer_pilot_display_after_1280x720.png", "wayfarer_after_landscape_1280x720.png"),
)


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


def load_source_manifest(review_root: Path) -> tuple[dict[str, object], dict[str, dict[str, object]]]:
    path = review_root / SOURCE_MANIFEST
    manifest = json.loads(path.read_text(encoding="utf-8"))
    entries = manifest.get("captures")
    if not isinstance(entries, list) or len(entries) != 10:
        raise RuntimeError(f"Unexpected source capture manifest: {path}")
    return manifest, {entry["filename"]: entry for entry in entries}


def verified_capture(review_root: Path, entries: dict[str, dict[str, object]], filename: str) -> Path:
    path = review_root / "raw_captures" / filename
    entry = entries.get(filename)
    if entry is None or not path.is_file() or sha256(path) != entry["sha256"]:
        raise RuntimeError(f"Missing or mismatched source capture: {path}")
    return path


def copy_capture(source: Path, destination: Path, expected_size: tuple[int, int]) -> None:
    with Image.open(source) as image:
        image.load()
        if image.size != expected_size:
            raise RuntimeError(f"Unexpected dimensions for {source}: {image.size}")
    shutil.copy2(source, destination)


def build_board(output_root: Path) -> Path:
    capture_root = output_root / "raw_captures"
    margin = 32
    column_gap = 24
    row_gap = 28
    header_height = 104
    label_height = 34
    capture_width = 640
    capture_height = 360
    panel_height = label_height + capture_height
    board_width = margin * 2 + capture_width * 2 + column_gap
    board_height = header_height + panel_height * 3 + row_gap * 2 + margin
    board = Image.new("RGB", (board_width, board_height), (20, 23, 22))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 20), "Wayfarer landscape revision", fill=(247, 243, 230), font=font(30, True))
    draw.text(
        (margin, 60),
        "Before: approved two-asset pilot. After: grouped planting, grounded rest grove, and yard-edge 07 placement.",
        fill=(180, 190, 182),
        font=font(16),
    )

    for row, (_source_name, before_name, after_name, label) in enumerate(COMPARISON_PAIRS):
        y = header_height + row * (panel_height + row_gap)
        for column, (filename, state_label) in enumerate(((before_name, "Before landscaping"), (after_name, "After landscaping"))):
            x = margin + column * (capture_width + column_gap)
            draw.text((x + 8, y + 5), f"{label} - {state_label}", fill=(242, 240, 231), font=font(17, True))
            with Image.open(capture_root / filename) as source:
                capture = source.convert("RGB")
            board.paste(capture, (x, y + label_height))
            draw.rectangle(
                (x, y + label_height, x + capture_width - 1, y + label_height + capture_height - 1),
                outline=(91, 101, 95),
                width=2,
            )

    output = output_root / BOARD_NAME
    board.save(output, compress_level=9)
    return output


def write_manifest(
    output_root: Path,
    before_root: Path,
    after_root: Path,
    before_manifest: dict[str, object],
    after_manifest: dict[str, object],
) -> Path:
    artifact_paths = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name not in {MANIFEST_NAME, CHECKSUM_NAME})
    tool_paths = (
        ROOT / "tools/art/prepare_caden_wayfarer_pilot_runtime_v1.py",
        ROOT / "tools/art/render_caden_wayfarer_gate1_review_v2.gd",
        ROOT / "tools/art/build_caden_wayfarer_landscape_revision_v3.py",
    )
    manifest = {
        "schema": "caden-wayfarer-landscape-revision-v3",
        "scope": "Wayfarer pilot landscape revision using existing approved repository art only.",
        "before_source": {
            "review_root": str(before_root),
            "manifest_sha256": sha256(before_root / SOURCE_MANIFEST),
            "render_tool_sha256": before_manifest["render_tool_sha256"],
        },
        "after_source": {
            "review_root": str(after_root),
            "manifest_sha256": sha256(after_root / SOURCE_MANIFEST),
            "render_tool_sha256": after_manifest["render_tool_sha256"],
        },
        "design_changes": [
            "Consolidated loose north-lawn accents into one meadow island around the existing tree.",
            "Moved 07 to the traveler-yard edge and grounded it with restrained trampled terrain.",
            "Moved the existing worn patch beneath 05 to establish a coherent rest grove.",
            "Grouped repeated flowers and low greenery at the rest-grove edges instead of scattering them across the lawn.",
            "Kept the main road, exits, approach corridors, and central lawn negative space open.",
        ],
        "tools": {path.relative_to(ROOT).as_posix(): sha256(path) for path in tool_paths},
        "artifacts": {path.relative_to(output_root).as_posix(): sha256(path) for path in artifact_paths},
    }
    path = output_root / MANIFEST_NAME
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    return path


def write_checksums(output_root: Path) -> Path:
    checksum_path = output_root / CHECKSUM_NAME
    paths = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name != CHECKSUM_NAME)
    checksum_path.write_text(
        "".join(f"{sha256(path)}  {path.relative_to(output_root).as_posix()}\n" for path in paths),
        encoding="utf-8",
        newline="\n",
    )
    return checksum_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before_root", type=Path)
    parser.add_argument("after_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    before_root = args.before_root.resolve()
    after_root = args.after_root.resolve()
    output_root = args.output_root.resolve()
    if ROOT == output_root or ROOT in output_root.parents:
        raise RuntimeError("Landscape review material must remain outside the Godot project tree.")
    capture_root = output_root / "raw_captures"
    metadata_root = output_root / "metadata"
    capture_root.mkdir(parents=True, exist_ok=True)
    metadata_root.mkdir(parents=True, exist_ok=True)

    before_manifest, before_entries = load_source_manifest(before_root)
    after_manifest, after_entries = load_source_manifest(after_root)
    for source_name, before_name, after_name, _label in COMPARISON_PAIRS:
        copy_capture(verified_capture(before_root, before_entries, source_name), capture_root / before_name, (640, 360))
        copy_capture(verified_capture(after_root, after_entries, source_name), capture_root / after_name, (640, 360))
    for source_name, output_name in AFTER_SUPPORTING:
        expected_size = (1280, 720) if output_name.endswith("1280x720.png") else (640, 360)
        copy_capture(verified_capture(after_root, after_entries, source_name), capture_root / output_name, expected_size)

    full_zone = ROOT / "docs/art/previews/wayfarers_approach/caden_wayfarers_approach_runtime_v1_full_zone.png"
    copy_capture(full_zone, capture_root / "wayfarer_full_zone_after_landscape_1024x640.png", (1024, 640))
    shutil.copy2(
        ROOT / "assets/environments/caden/wayfarers_approach/wayfarers_approach_pilot_runtime_v1.json",
        metadata_root / "wayfarers_approach_pilot_runtime_v1.json",
    )
    provenance = before_root / "metadata/SOURCE_PROVENANCE_AND_LICENSE.md"
    if provenance.is_file():
        shutil.copy2(provenance, metadata_root / provenance.name)

    with Image.open(capture_root / "wayfarer_road_after_landscape_640x360.png") as reference_image:
        reference = reference_image.convert("RGBA")
    with Image.open(capture_root / "wayfarer_after_landscape_1280x720.png") as display_image:
        display = display_image.convert("RGBA")
    if display.tobytes() != reference.resize((1280, 720), Image.Resampling.NEAREST).tobytes():
        raise RuntimeError("The revised 1280x720 display frame is not an exact nearest-neighbor 2x enlargement.")

    board = build_board(output_root)
    manifest = write_manifest(output_root, before_root, after_root, before_manifest, after_manifest)
    checksums = write_checksums(output_root)
    print(f"comparison={board}")
    print(f"manifest={manifest}")
    print(f"checksums={checksums}")
    print("native_comparison_frames=6")
    print("exact_2x_display=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
