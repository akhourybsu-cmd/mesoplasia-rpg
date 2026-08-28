#!/usr/bin/env python3
"""Build the external Caden Residential runtime v1 visual-review package."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
BASELINE_MANIFEST = "residential_baseline_screenshot_manifest_v1.json"
AFTER_MANIFEST = "residential_runtime_screenshot_manifest_v1.json"
PACKAGE_MANIFEST = "residential_runtime_review_manifest_v1.json"
BOARD_NAME = "residential_runtime_comparison_board_v1.png"
CHECKSUMS = "SHA256SUMS.txt"
FOCUS_PAIRS = (
    ("west_arrival", "Town Square arrival"),
    ("primary_route", "Primary road and Commons junction"),
    ("north_homes", "North homes and household yards"),
    ("south_homes", "South homes and work yards"),
    ("commons_transition", "Commons transition"),
)
SUPPORTING_AFTER = (
    "residential_doorstep_player_front_after_v1_640x360.png",
    "residential_doorstep_player_behind_after_v1_640x360.png",
    "residential_laundry_player_front_after_v1_640x360.png",
    "residential_laundry_player_behind_after_v1_640x360.png",
    "residential_primary_display_after_v1_1280x720.png",
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


def build_board(output_root: Path) -> Path:
    captures = output_root / "raw_captures"
    margin, gap, column_width, header, label_height = 32, 24, 1152, 112, 34
    width = margin * 2 + column_width * 2 + gap
    height = header + label_height + 768 + gap + len(FOCUS_PAIRS) * (label_height + 360 + gap) + margin - gap
    board = Image.new("RGB", (width, height), (19, 23, 21))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 18), "Caden Residential selective integration", fill=(247, 243, 230), font=font(30, True))
    draw.text((margin, 61), "Before: fixed greybox contract. After: aligned homes, coherent household yards, planted edges, and seven visible residents.", fill=(184, 195, 186), font=font(16))

    for column, (filename, label) in enumerate((
        ("residential_full_zone_before_v1_1152x768.png", "Full zone - before"),
        ("residential_full_zone_after_v1_1152x768.png", "Full zone - after"),
    )):
        x, y = margin + column * (column_width + gap), header
        draw.text((x + 8, y + 5), label, fill=(242, 240, 231), font=font(17, True))
        with Image.open(captures / filename) as source:
            board.paste(source.convert("RGB"), (x, y + label_height))
        draw.rectangle((x, y + label_height, x + 1151, y + label_height + 767), outline=(91, 101, 95), width=2)

    y = header + label_height + 768 + gap
    for key, label in FOCUS_PAIRS:
        for column, (state, suffix) in enumerate((("before", "Before"), ("after", "After"))):
            filename = f"residential_{key}_{state}_v1_640x360.png"
            x = margin + column * (column_width + gap)
            draw.text((x + 8, y + 5), f"{label} - {suffix.lower()}", fill=(242, 240, 231), font=font(17, True))
            with Image.open(captures / filename) as source:
                board.paste(source.convert("RGB"), (x, y + label_height))
            draw.rectangle((x, y + label_height, x + 639, y + label_height + 359), outline=(91, 101, 95), width=2)
        y += label_height + 360 + gap

    output = output_root / BOARD_NAME
    board.save(output, compress_level=9)
    return output


def write_readme(output_root: Path) -> Path:
    path = output_root / "RESIDENTIAL_RUNTIME_REVIEW_V1.md"
    path.write_text(
        """# Caden Residential runtime review v1

Review the native `1152 x 768` full-zone pair first, then the matched route and household views. The after pass preserves every fixed home, fence, road, entry, exit, collision, and dialogue contract while replacing the greybox presentation with a coherent residential composition.

The implementation imports only approved candidates `01`, `04`, `05`, `06`, `08`, `09`, and `11`. Each uses exact `0.1875` nearest-neighbor normalization, hard alpha, structural ground-contact pivots, scale `1.0`, cleanup audits, and object-specific collision. Existing approved Caden building art supplies the ten home exteriors; none of the 24 rejected baked-shadow building masters is imported.

Five non-interactive walkers join the two existing dialogue residents, for seven visible NPCs. Their patrols are short, bounded, and kept away from exits. Trees and low planting frame the outer grass while the west-east road, Commons branch, and four household lanes remain clear.

Source rights remain project-internal and unverified. Do not publish this package until rights are independently confirmed. Approval of this package authorizes completion of the Residential visual gate only; Commons and all alternate, deferred, rejected, and mega assets remain outside scope.
""",
        encoding="utf-8",
        newline="\n",
    )
    return path


def write_manifest(output_root: Path, baseline_root: Path, after_root: Path, after_manifest: dict[str, object]) -> Path:
    tool_paths = (
        ROOT / "tools/art/prepare_caden_residential_runtime_v1.py",
        ROOT / "tools/art/build_caden_residential_terrain_v1.py",
        ROOT / "tools/art/render_caden_residential_runtime_v1.gd",
        ROOT / "tools/art/build_caden_residential_runtime_review_v1.py",
        ROOT / "tests/caden_residential_runtime_test.gd",
    )
    artifacts = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name not in {PACKAGE_MANIFEST, CHECKSUMS})
    manifest = {
        "schema": "caden-residential-runtime-review-v1",
        "gate_state": "residential_runtime_v1_pending_in_engine_visual_approval",
        "review_priority": "Use the native 1152x768 full-zone comparison as the primary approval view.",
        "baseline": {"render_root": str(baseline_root), "manifest_sha256": sha256(baseline_root / BASELINE_MANIFEST), "scene_state": "untouched Residential greybox"},
        "after": {"render_root": str(after_root), "manifest_sha256": sha256(after_root / AFTER_MANIFEST), "render_tool_sha256": after_manifest["render_tool_sha256"], "scene_sha256": sha256(ROOT / "scenes/world/caden/Residential.tscn")},
        "selected_library_assets": ["01", "04", "05", "06", "08", "09", "11"],
        "additional_library_assets_imported": [],
        "population": {"dialogue_npcs": 2, "ambient_walkers": 5, "total_visible_npcs": 7},
        "preserved_contracts": ["1152x768 zone and camera bounds", "ten home centers and 128x96 collision bodies", "three fence centers and 192x24 collision bodies", "west Town Square and south Commons transitions", "primary road, Commons branch, and four household lanes", "two existing NPC identities and dialogue resources"],
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
    path.write_text("".join(f"{sha256(file)}  {file.relative_to(output_root).as_posix()}\n" for file in artifacts), encoding="utf-8", newline="\n")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline_root", type=Path)
    parser.add_argument("after_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    baseline_root, after_root, output_root = args.baseline_root.resolve(), args.after_root.resolve(), args.output_root.resolve()
    if ROOT == output_root or ROOT in output_root.parents:
        raise RuntimeError("Review material must remain outside the Godot project tree.")
    captures, metadata = output_root / "raw_captures", output_root / "metadata"
    captures.mkdir(parents=True, exist_ok=True)
    metadata.mkdir(parents=True, exist_ok=True)

    baseline_manifest = json.loads((baseline_root / BASELINE_MANIFEST).read_text(encoding="utf-8"))
    after_manifest = json.loads((after_root / AFTER_MANIFEST).read_text(encoding="utf-8"))
    baseline_entries = {entry["filename"]: entry for entry in baseline_manifest["captures"]}
    after_entries = {entry["filename"]: entry for entry in after_manifest["captures"]}
    if len(baseline_entries) != 7 or len(after_entries) != 11:
        raise RuntimeError("Unexpected Residential capture manifest.")

    for state, root, entries in (("before", baseline_root, baseline_entries), ("after", after_root, after_entries)):
        full_name = f"residential_full_zone_{state}_v1_1152x768.png"
        copy_verified(verified_capture(root, entries, full_name), captures / full_name, (1152, 768))
        for key, _label in FOCUS_PAIRS:
            filename = f"residential_{key}_{state}_v1_640x360.png"
            copy_verified(verified_capture(root, entries, filename), captures / filename, (640, 360))
    for filename in SUPPORTING_AFTER:
        dimensions = (1280, 720) if filename.endswith("1280x720.png") else (640, 360)
        copy_verified(verified_capture(after_root, after_entries, filename), captures / filename, dimensions)

    shutil.copy2(after_root / AFTER_MANIFEST, metadata)
    shutil.copy2(ROOT / "assets/environments/caden/residential/residential_runtime_manifest_v1.json", metadata)
    shutil.copy2(ROOT / "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.json", metadata)
    provenance = baseline_root.parent / "caden_mega_asset_library_v1_1/docs/PROVENANCE_AND_LICENSE.md"
    if provenance.is_file():
        shutil.copy2(provenance, metadata)

    with Image.open(captures / "residential_primary_route_after_v1_640x360.png") as native:
        expected = native.convert("RGBA").resize((1280, 720), Image.Resampling.NEAREST)
    with Image.open(captures / "residential_primary_display_after_v1_1280x720.png") as display:
        if expected.tobytes() != display.convert("RGBA").tobytes():
            raise RuntimeError("The 1280x720 frame is not an exact nearest-neighbor 2x enlargement.")

    print(f"board={build_board(output_root)}")
    print(f"readme={write_readme(output_root)}")
    print(f"package_manifest={write_manifest(output_root, baseline_root, after_root, after_manifest)}")
    print(f"checksums={write_checksums(output_root)}")
    print("exact_2x_display=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
