#!/usr/bin/env python3
"""Build the full-zone-first Wayfarer structural-recomposition review package."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
AFTER_MANIFEST = "wayfarer_structural_recomposition_screenshot_manifest_v5.json"
PACKAGE_MANIFEST = "wayfarer_structural_recomposition_review_manifest_v5.json"
BOARD_NAME = "wayfarer_structural_recomposition_comparison_board_v5.png"
CHECKSUMS = "SHA256SUMS.txt"
BASELINE_FULL = "wayfarer_full_zone_after_v4_1024x640.png"
AFTER_FULL = "wayfarer_full_zone_after_v5_1024x640.png"
FOCUS_PAIRS = (
    ("primary_gameplay", "wayfarer_primary_gameplay_after_v4_640x360.png", "wayfarer_primary_gameplay_after_v5_640x360.png", "Primary gameplay"),
    ("inn_precinct", "wayfarer_inn_forecourt_after_v4_640x360.png", "wayfarer_inn_precinct_after_v5_640x360.png", "Inn precinct"),
    ("traveler_yard", "wayfarer_traveler_yard_after_v4_640x360.png", "wayfarer_traveler_yard_after_v5_640x360.png", "Traveler working yard"),
    ("rest_grove", "wayfarer_rest_grove_after_v4_640x360.png", "wayfarer_rest_grove_after_v5_640x360.png", "Rest grove"),
    ("open_meadow", "wayfarer_north_lawn_after_v4_640x360.png", "wayfarer_open_meadow_after_v5_640x360.png", "Open meadow"),
    ("road_transitions", "wayfarer_road_transitions_after_v4_640x360.png", "wayfarer_road_transitions_after_v5_640x360.png", "Road and transitions"),
)
SUPPORTING_AFTER = (
    "wayfarer_05_player_front_after_v5_640x360.png",
    "wayfarer_05_player_behind_after_v5_640x360.png",
    "wayfarer_07_player_front_after_v5_640x360.png",
    "wayfarer_07_player_behind_after_v5_640x360.png",
    "wayfarer_grove_tree_player_front_after_v5_640x360.png",
    "wayfarer_grove_tree_player_behind_after_v5_640x360.png",
    "wayfarer_primary_display_after_v5_1280x720.png",
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


def copy_verified(source: Path, destination: Path, expected_size: tuple[int, int]) -> None:
    with Image.open(source) as image:
        image.load()
        if image.size != expected_size:
            raise RuntimeError(f"Unexpected dimensions for {source}: {image.size}")
    shutil.copy2(source, destination)


def verified_capture(root: Path, entries: dict[str, dict[str, object]], filename: str) -> Path:
    path = root / "raw_captures" / filename
    entry = entries.get(filename)
    if entry is None or not path.is_file() or sha256(path) != entry["sha256"]:
        raise RuntimeError(f"Missing or mismatched capture: {path}")
    return path


def build_board(output_root: Path) -> Path:
    captures = output_root / "raw_captures"
    margin = 32
    gap = 24
    header = 104
    full_label = 34
    full_height = full_label + 640
    focus_label = 34
    focus_height = focus_label + 360
    board_width = margin * 2 + 1024 * 2 + gap
    board_height = header + full_height + gap + len(FOCUS_PAIRS) * (focus_height + gap) + margin - gap
    board = Image.new("RGB", (board_width, board_height), (20, 23, 22))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 18), "Wayfarer's Approach structural recomposition", fill=(247, 243, 230), font=font(30, True))
    draw.text(
        (margin, 60),
        "Before: connected terrain pass. After: softened roads, inn precinct, sheltered grove, meadow, and perimeter masses.",
        fill=(180, 190, 182),
        font=font(16),
    )

    for column, (filename, label) in enumerate((
        ("wayfarer_full_zone_before_v5_1024x640.png", "Full zone - before"),
        ("wayfarer_full_zone_after_v5_1024x640.png", "Full zone - after"),
    )):
        x = margin + column * (1024 + gap)
        y = header
        draw.text((x + 8, y + 5), label, fill=(242, 240, 231), font=font(17, True))
        with Image.open(captures / filename) as source:
            board.paste(source.convert("RGB"), (x, y + full_label))
        draw.rectangle((x, y + full_label, x + 1023, y + full_label + 639), outline=(91, 101, 95), width=2)

    y = header + full_height + gap
    for key, _before_source, _after_source, label in FOCUS_PAIRS:
        for column, (filename, state_label) in enumerate((
            (f"wayfarer_{key}_before_v5_640x360.png", f"{label} - before"),
            (f"wayfarer_{key}_after_v5_640x360.png", f"{label} - after"),
        )):
            x = margin + column * (1024 + gap)
            draw.text((x + 8, y + 5), state_label, fill=(242, 240, 231), font=font(17, True))
            with Image.open(captures / filename) as source:
                board.paste(source.convert("RGB"), (x, y + focus_label))
            draw.rectangle((x, y + focus_label, x + 639, y + focus_label + 359), outline=(91, 101, 95), width=2)
        y += focus_height + gap

    output = output_root / BOARD_NAME
    board.save(output, compress_level=9)
    return output


def write_readme(output_root: Path) -> Path:
    path = output_root / "WAYFARER_STRUCTURAL_RECOMPOSITION_REVIEW_V5.md"
    path.write_text(
        """# Wayfarer's Approach structural recomposition review v5

This package is the next visual-approval gate for Wayfarer's Approach. Review the native full-zone comparison first; the focused room views and overlap pairs are supporting evidence.

The revision preserves every gameplay road corridor, transition, camera limit, NPC, dialogue, interaction, and existing collision contract while changing the large-scale composition:

- six irregular grass shoulders soften the visual road cross without narrowing its walkable corridor;
- the inn now sits within one precinct joining its foundation, porch approach, service clusters, and road edge;
- the existing U-shaped traveler enclosure reads over one connected hard-packed working surface with a clear southern entrance;
- the northeast is an intentional open meadow framed by concentrated tree and shrub groups;
- `05` sits inside a three-tree rest grove with layered shrub masses and a connected approach;
- perimeter trees and shrubs are concentrated into overlapping edge groups interrupted only by roads and transitions.

No additional Caden Mega Asset Library candidate or other Caden zone was touched. Approval of this package is required before broader integration resumes.
""",
        encoding="utf-8",
        newline="\n",
    )
    return path


def write_manifest(output_root: Path, baseline_root: Path, after_root: Path, after_manifest: dict[str, object]) -> Path:
    tool_paths = (
        ROOT / "tools/art/build_caden_wayfarer_landscape_surfaces_v1.py",
        ROOT / "tools/art/render_caden_wayfarer_structural_recomposition_v5.gd",
        ROOT / "tools/art/build_caden_wayfarer_structural_recomposition_review_v5.py",
    )
    artifacts = sorted(
        path for path in output_root.rglob("*") if path.is_file() and path.name not in {PACKAGE_MANIFEST, CHECKSUMS}
    )
    manifest = {
        "schema": "caden-wayfarer-structural-recomposition-review-v5",
        "scope": "Wayfarer's Approach large-mass structural recomposition only.",
        "review_priority": "Use the native 1024x640 full-zone comparison as the primary approval view.",
        "baseline": {
            "package": str(baseline_root),
            "package_manifest_sha256": sha256(baseline_root / "wayfarer_production_landscape_review_manifest_v4.json"),
            "state": "v4 production landscape after frames",
        },
        "after": {
            "render_root": str(after_root),
            "screenshot_manifest_sha256": sha256(after_root / AFTER_MANIFEST),
            "render_tool_sha256": after_manifest["render_tool_sha256"],
        },
        "preserved_contracts": [
            "1024x640 zone and camera bounds",
            "640x360 internal and exact 1280x720 2x presentation",
            "all existing road and transition collision corridors",
            "inn, exits, entries, wagons, fences, NPCs, dialogue, and interactions",
            "05 and 07 object-specific collision and player-relative depth sorting",
            "05 and 07 remain the only Caden Mega Asset Library pilot additions",
        ],
        "tools": {path.relative_to(ROOT).as_posix(): sha256(path) for path in tool_paths},
        "artifacts": {path.relative_to(output_root).as_posix(): sha256(path) for path in artifacts},
    }
    path = output_root / PACKAGE_MANIFEST
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    return path


def write_checksums(output_root: Path) -> Path:
    path = output_root / CHECKSUMS
    artifacts = sorted(file for file in output_root.rglob("*") if file.is_file() and file.name != CHECKSUMS)
    path.write_text(
        "".join(f"{sha256(file)}  {file.relative_to(output_root).as_posix()}\n" for file in artifacts),
        encoding="utf-8",
        newline="\n",
    )
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline_root", type=Path)
    parser.add_argument("after_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    baseline_root = args.baseline_root.resolve()
    after_root = args.after_root.resolve()
    output_root = args.output_root.resolve()
    if ROOT == output_root or ROOT in output_root.parents:
        raise RuntimeError("Review material must remain outside the Godot project tree.")
    captures = output_root / "raw_captures"
    metadata = output_root / "metadata"
    captures.mkdir(parents=True, exist_ok=True)
    metadata.mkdir(parents=True, exist_ok=True)

    after_manifest = json.loads((after_root / AFTER_MANIFEST).read_text(encoding="utf-8"))
    entries = {entry["filename"]: entry for entry in after_manifest["captures"]}
    if len(entries) != 14:
        raise RuntimeError("Unexpected structural-recomposition screenshot manifest.")

    baseline_captures = baseline_root / "raw_captures"
    copy_verified(baseline_captures / BASELINE_FULL, captures / "wayfarer_full_zone_before_v5_1024x640.png", (1024, 640))
    copy_verified(verified_capture(after_root, entries, AFTER_FULL), captures / "wayfarer_full_zone_after_v5_1024x640.png", (1024, 640))
    for key, before_name, after_name, _label in FOCUS_PAIRS:
        copy_verified(baseline_captures / before_name, captures / f"wayfarer_{key}_before_v5_640x360.png", (640, 360))
        copy_verified(verified_capture(after_root, entries, after_name), captures / f"wayfarer_{key}_after_v5_640x360.png", (640, 360))
    for filename in SUPPORTING_AFTER:
        size = (1280, 720) if filename.endswith("1280x720.png") else (640, 360)
        copy_verified(verified_capture(after_root, entries, filename), captures / filename, size)

    with Image.open(captures / "wayfarer_primary_gameplay_after_v5_640x360.png") as native_image:
        expected = native_image.convert("RGBA").resize((1280, 720), Image.Resampling.NEAREST)
    with Image.open(captures / "wayfarer_primary_display_after_v5_1280x720.png") as display_image:
        if expected.tobytes() != display_image.convert("RGBA").tobytes():
            raise RuntimeError("The 1280x720 frame is not an exact nearest-neighbor 2x enlargement.")

    shutil.copy2(ROOT / "assets/environments/caden/wayfarers_approach/terrain/composed_v1/wayfarers_landscape_surfaces_v1.json", metadata)
    shutil.copy2(ROOT / "assets/environments/caden/wayfarers_approach/wayfarers_approach_pilot_runtime_v1.json", metadata)
    provenance = baseline_root / "metadata/SOURCE_PROVENANCE_AND_LICENSE.md"
    if provenance.is_file():
        shutil.copy2(provenance, metadata)
    board = build_board(output_root)
    readme = write_readme(output_root)
    manifest = write_manifest(output_root, baseline_root, after_root, after_manifest)
    checksums = write_checksums(output_root)
    print(f"board={board}")
    print(f"readme={readme}")
    print(f"manifest={manifest}")
    print(f"checksums={checksums}")
    print("exact_2x_display=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
