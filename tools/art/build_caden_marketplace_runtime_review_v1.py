#!/usr/bin/env python3
"""Build the full-zone-first Caden Marketplace runtime v1 review package."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
BASELINE_MANIFEST = "marketplace_baseline_screenshot_manifest_v1.json"
AFTER_MANIFEST = "marketplace_runtime_screenshot_manifest_v1.json"
PACKAGE_MANIFEST = "marketplace_runtime_review_manifest_v1.json"
BOARD_NAME = "marketplace_runtime_comparison_board_v1.png"
CHECKSUMS = "SHA256SUMS.txt"

FOCUS_PAIRS = (
    ("west_arrival", "marketplace_west_arrival_before_v1_640x360.png", "marketplace_west_arrival_after_v1_640x360.png", "Wayfarer arrival"),
    ("primary_aisle", "marketplace_primary_aisle_before_v1_640x360.png", "marketplace_primary_aisle_after_v1_640x360.png", "Primary aisle"),
    ("north_districts", "marketplace_north_districts_before_v1_640x360.png", "marketplace_north_districts_after_v1_640x360.png", "North vendor districts"),
    ("south_districts", "marketplace_south_districts_before_v1_640x360.png", "marketplace_south_districts_after_v1_640x360.png", "South vendor and service districts"),
    ("south_transition", "marketplace_south_transition_before_v1_640x360.png", "marketplace_south_transition_after_v1_640x360.png", "Town Square forecourt"),
)
SUPPORTING_AFTER = (
    "marketplace_vendor_player_front_after_v1_640x360.png",
    "marketplace_vendor_player_behind_after_v1_640x360.png",
    "marketplace_tree_player_front_after_v1_640x360.png",
    "marketplace_tree_player_behind_after_v1_640x360.png",
    "marketplace_primary_display_after_v1_1280x720.png",
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


def verified_capture(root: Path, entries: dict[str, dict[str, object]], filename: str) -> Path:
    path = root / "raw_captures" / filename
    entry = entries.get(filename)
    if entry is None or not path.is_file() or sha256(path) != entry["sha256"]:
        raise RuntimeError(f"Missing or mismatched capture: {path}")
    return path


def copy_verified(source: Path, destination: Path, expected_size: tuple[int, int]) -> None:
    with Image.open(source) as image:
        image.load()
        if image.size != expected_size:
            raise RuntimeError(f"Unexpected dimensions for {source}: {image.size}")
    shutil.copy2(source, destination)


def build_baseline_district_crops(baseline_full: Path, captures: Path) -> None:
    with Image.open(baseline_full) as source:
        full = source.convert("RGBA")
    crops = {
        "marketplace_north_districts_before_v1_640x360.png": (128, 28, 768, 388),
        "marketplace_south_districts_before_v1_640x360.png": (128, 268, 768, 628),
    }
    for filename, bounds in crops.items():
        image = full.crop(bounds)
        if image.size != (640, 360):
            raise RuntimeError(f"Unexpected baseline crop dimensions for {filename}.")
        image.save(captures / filename, compress_level=9)


def build_board(output_root: Path) -> Path:
    captures = output_root / "raw_captures"
    margin = 32
    gap = 24
    column_width = 896
    header = 106
    label_height = 34
    full_height = label_height + 640
    focus_height = label_height + 360
    width = margin * 2 + column_width * 2 + gap
    height = header + full_height + gap + len(FOCUS_PAIRS) * (focus_height + gap) + margin - gap
    board = Image.new("RGB", (width, height), (19, 23, 21))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 18), "Caden Marketplace selective integration", fill=(247, 243, 230), font=font(30, True))
    draw.text((margin, 60), "Before: geometric greybox. After: one paved market court, paired vendor districts, framed routes, and selected source art.", fill=(184, 195, 186), font=font(16))

    for column, (filename, label) in enumerate((
        ("marketplace_full_zone_before_v1_896x640.png", "Full zone - before"),
        ("marketplace_full_zone_after_v1_896x640.png", "Full zone - after"),
    )):
        x = margin + column * (column_width + gap)
        y = header
        draw.text((x + 8, y + 5), label, fill=(242, 240, 231), font=font(17, True))
        with Image.open(captures / filename) as source:
            board.paste(source.convert("RGB"), (x, y + label_height))
        draw.rectangle((x, y + label_height, x + 895, y + label_height + 639), outline=(91, 101, 95), width=2)

    y = header + full_height + gap
    for key, _before_source, _after_source, label in FOCUS_PAIRS:
        for column, (filename, state) in enumerate((
            (f"marketplace_{key}_before_v1_640x360.png", f"{label} - before"),
            (f"marketplace_{key}_after_v1_640x360.png", f"{label} - after"),
        )):
            x = margin + column * (column_width + gap)
            draw.text((x + 8, y + 5), state, fill=(242, 240, 231), font=font(17, True))
            with Image.open(captures / filename) as source:
                board.paste(source.convert("RGB"), (x, y + label_height))
            draw.rectangle((x, y + label_height, x + 639, y + label_height + 359), outline=(91, 101, 95), width=2)
        y += focus_height + gap

    output = output_root / BOARD_NAME
    board.save(output, compress_level=9)
    return output


def write_readme(output_root: Path) -> Path:
    path = output_root / "MARKETPLACE_RUNTIME_REVIEW_V1.md"
    path.write_text(
        """# Caden Marketplace runtime review v1

This is the in-engine visual-approval gate for the limited Marketplace integration. Review the native `896 x 640` full-zone comparison first, then the matched route and district views and player-overlap evidence.

The pass:

- preserves the live `896 x 640` bounds, eight vendor-bay centers, west and south transitions, entry markers, camera, NPC identities, dialogue, and route corridors;
- replaces placeholder surfaces with a deterministic terrain composition derived from the approved Caden terrain v1.1 atlas;
- integrates only approved candidates `01`, `03`, `04`, `06`, `07`, `13`, and `14`, with `07` reused once as the paired south anchor;
- imports cleaned runtime PNGs at scale `1.0` after exact `0.1875` nearest-neighbor normalization;
- removes presentation shadows, bright fringes, partial alpha, detached fragments, and transparent RGB;
- uses structural bottom-center pivots, object-specific collision, and player-relative depth sorting;
- frames the court with already approved Caden trees, shrubs, planters, and lanterns while keeping all lanes open;
- replaces the three colored NPC placeholders with their existing approved Caden character visuals without changing dialogue or behavior.

No alternate, deferred, rejected, seam, mega-set, sign, Festival, or later-zone asset was imported. Source rights remain project-internal and unverified; do not publish this package until rights are confirmed.

Approval of this package completes the Marketplace visual gate. It does not authorize Town Square, Residential, Commons, or any additional library asset.
""",
        encoding="utf-8",
        newline="\n",
    )
    return path


def write_manifest(output_root: Path, baseline_root: Path, after_root: Path, after_manifest: dict[str, object]) -> Path:
    tool_paths = (
        ROOT / "tools/art/prepare_caden_marketplace_runtime_v1.py",
        ROOT / "tools/art/build_caden_marketplace_terrain_v1.py",
        ROOT / "tools/art/render_caden_marketplace_runtime_v1.gd",
        ROOT / "tools/art/build_caden_marketplace_runtime_review_v1.py",
        ROOT / "tests/caden_marketplace_runtime_test.gd",
    )
    artifacts = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name not in {PACKAGE_MANIFEST, CHECKSUMS})
    manifest = {
        "schema": "caden-marketplace-runtime-review-v1",
        "gate_state": "marketplace_runtime_v1_visual_approved",
        "review_priority": "Use the native 896x640 full-zone comparison as the primary approval view.",
        "baseline": {
            "render_root": str(baseline_root),
            "manifest_sha256": sha256(baseline_root / BASELINE_MANIFEST),
            "scene_state": "untouched Marketplace greybox",
        },
        "after": {
            "render_root": str(after_root),
            "manifest_sha256": sha256(after_root / AFTER_MANIFEST),
            "render_tool_sha256": after_manifest["render_tool_sha256"],
            "scene_sha256": sha256(ROOT / "scenes/world/caden/Marketplace.tscn"),
        },
        "selected_library_assets": ["01", "03", "04", "06", "07", "13", "14"],
        "additional_library_assets_imported": [],
        "preserved_contracts": [
            "896x640 zone and camera bounds",
            "west Wayfarer and south Town Square transition nodes and entry markers",
            "primary west, cross, and central route corridors",
            "eight authoritative vendor-bay centers",
            "three existing NPC identities, dialogue resources, and interaction behavior",
            "640x360 internal and exact 1280x720 nearest-neighbor presentation",
        ],
        "rights_status": "project_internal_rights_unverified",
        "distribution_status": "do_not_publish_until_rights_are_verified",
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

    baseline_manifest = json.loads((baseline_root / BASELINE_MANIFEST).read_text(encoding="utf-8"))
    baseline_entries = {entry["filename"]: entry for entry in baseline_manifest["captures"]}
    after_manifest = json.loads((after_root / AFTER_MANIFEST).read_text(encoding="utf-8"))
    after_entries = {entry["filename"]: entry for entry in after_manifest["captures"]}
    if len(after_entries) != 11:
        raise RuntimeError("Unexpected Marketplace after-capture manifest.")

    baseline_full = verified_capture(baseline_root, baseline_entries, "marketplace_full_zone_before_v1_896x640.png")
    copy_verified(baseline_full, captures / "marketplace_full_zone_before_v1_896x640.png", (896, 640))
    copy_verified(verified_capture(after_root, after_entries, "marketplace_full_zone_after_v1_896x640.png"), captures / "marketplace_full_zone_after_v1_896x640.png", (896, 640))
    build_baseline_district_crops(baseline_full, captures)

    for key, before_name, after_name, _label in FOCUS_PAIRS:
        if key not in {"north_districts", "south_districts"}:
            copy_verified(verified_capture(baseline_root, baseline_entries, before_name), captures / before_name, (640, 360))
        copy_verified(verified_capture(after_root, after_entries, after_name), captures / after_name, (640, 360))
    for filename in SUPPORTING_AFTER:
        dimensions = (1280, 720) if filename.endswith("1280x720.png") else (640, 360)
        copy_verified(verified_capture(after_root, after_entries, filename), captures / filename, dimensions)

    shutil.copy2(after_root / AFTER_MANIFEST, metadata)
    shutil.copy2(ROOT / "assets/environments/caden/marketplace/marketplace_runtime_manifest_v1.json", metadata)
    shutil.copy2(ROOT / "assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1.json", metadata)
    provenance = baseline_root.parent / "caden_mega_asset_library_v1_1/docs/PROVENANCE_AND_LICENSE.md"
    if provenance.is_file():
        shutil.copy2(provenance, metadata)

    with Image.open(captures / "marketplace_primary_aisle_after_v1_640x360.png") as native:
        expected = native.convert("RGBA").resize((1280, 720), Image.Resampling.NEAREST)
    with Image.open(captures / "marketplace_primary_display_after_v1_1280x720.png") as display:
        if expected.tobytes() != display.convert("RGBA").tobytes():
            raise RuntimeError("The 1280x720 frame is not an exact nearest-neighbor 2x enlargement.")

    board = build_board(output_root)
    readme = write_readme(output_root)
    package_manifest = write_manifest(output_root, baseline_root, after_root, after_manifest)
    checksums = write_checksums(output_root)
    print(f"board={board}")
    print(f"readme={readme}")
    print(f"package_manifest={package_manifest}")
    print(f"checksums={checksums}")
    print("exact_2x_display=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
