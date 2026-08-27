#!/usr/bin/env python3
"""Build the external Wayfarer production-landscape approval package."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
AFTER_MANIFEST = "wayfarer_production_landscape_screenshot_manifest_v4.json"
BASELINE_FULL = "raw_captures/wayfarer_full_zone_after_landscape_1024x640.png"
BOARD_NAME = "wayfarer_production_landscape_comparison_board_v4.png"
PACKAGE_MANIFEST = "wayfarer_production_landscape_review_manifest_v4.json"
CHECKSUMS = "SHA256SUMS.txt"
FOCUS_SPECS = (
    ("primary_gameplay", (704, 400), "wayfarer_primary_gameplay_after_v4_640x360.png", "Primary gameplay"),
    ("inn_forecourt", (320, 260), "wayfarer_inn_forecourt_after_v4_640x360.png", "Inn forecourt"),
    ("traveler_yard", (416, 460), "wayfarer_traveler_yard_after_v4_640x360.png", "Traveler working yard"),
    ("rest_grove", (704, 460), "wayfarer_rest_grove_after_v4_640x360.png", "Rest grove"),
    ("north_lawn", (704, 180), "wayfarer_north_lawn_after_v4_640x360.png", "North lawn"),
    ("road_transitions", (704, 320), "wayfarer_road_transitions_after_v4_640x360.png", "Road and transitions"),
)
SUPPORTING_AFTER = (
    "wayfarer_05_player_front_after_v4_640x360.png",
    "wayfarer_05_player_behind_after_v4_640x360.png",
    "wayfarer_07_player_front_after_v4_640x360.png",
    "wayfarer_07_player_behind_after_v4_640x360.png",
    "wayfarer_primary_display_after_v4_1280x720.png",
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


def verified_after(after_root: Path, entries: dict[str, dict[str, object]], filename: str) -> Path:
    path = after_root / "raw_captures" / filename
    entry = entries.get(filename)
    if entry is None or not path.is_file() or sha256(path) != entry["sha256"]:
        raise RuntimeError(f"Missing or mismatched after capture: {path}")
    return path


def copy_verified(source: Path, destination: Path, expected_size: tuple[int, int]) -> None:
    with Image.open(source) as image:
        image.load()
        if image.size != expected_size:
            raise RuntimeError(f"Unexpected dimensions for {source}: {image.size}")
    shutil.copy2(source, destination)


def crop_baseline(full_zone: Image.Image, center: tuple[int, int], destination: Path) -> None:
    left = center[0] - 320
    top = center[1] - 180
    if left < 0 or top < 0 or left + 640 > full_zone.width or top + 360 > full_zone.height:
        raise RuntimeError(f"Baseline crop exceeds the source frame at camera center {center}.")
    full_zone.crop((left, top, left + 640, top + 360)).save(destination, compress_level=9)


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
    board_height = header + full_height + gap + len(FOCUS_SPECS) * (focus_height + gap) + margin - gap
    board = Image.new("RGB", (board_width, board_height), (20, 23, 22))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 18), "Wayfarer's Approach production landscape pass", fill=(247, 243, 230), font=font(30, True))
    draw.text(
        (margin, 60),
        "Before: v3 landscaped pilot. After: connected authored terrain and four-room composition.",
        fill=(180, 190, 182),
        font=font(16),
    )

    full_pairs = (
        ("wayfarer_full_zone_before_v4_1024x640.png", "Full zone - before"),
        ("wayfarer_full_zone_after_v4_1024x640.png", "Full zone - after"),
    )
    for column, (filename, label) in enumerate(full_pairs):
        x = margin + column * (1024 + gap)
        y = header
        draw.text((x + 8, y + 5), label, fill=(242, 240, 231), font=font(17, True))
        with Image.open(captures / filename) as source:
            board.paste(source.convert("RGB"), (x, y + full_label))
        draw.rectangle((x, y + full_label, x + 1023, y + full_label + 639), outline=(91, 101, 95), width=2)

    y = header + full_height + gap
    for key, _center, _after_name, label in FOCUS_SPECS:
        pairs = (
            (f"wayfarer_{key}_before_v4_640x360.png", f"{label} - before"),
            (f"wayfarer_{key}_after_v4_640x360.png", f"{label} - after"),
        )
        for column, (filename, state_label) in enumerate(pairs):
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
    path = output_root / "WAYFARER_PRODUCTION_LANDSCAPE_REVIEW_V4.md"
    path.write_text(
        """# Wayfarer's Approach production landscape review v4

This package is the visual-approval gate for the Wayfarer's Approach production landscape pass.

The before state is the checksummed v3 landscaped pilot. The after state replaces five separate wear discs and three translucent grounding stamps with three deterministic, binary-alpha surfaces derived only from approved repository grass and wear textures: an inn apron, one connected traveler-yard field, and a subordinate rest-grove pocket.

The existing zone geometry, roads, exits, collision corridors, inn, wagons, NPCs, dialogue, interactions, camera bounds, and two-asset pilot remain authoritative. No additional Caden Mega Asset Library candidate was imported.

Review the native-size board first, then the raw depth pairs. Approval of this package is required before another Caden zone or asset-library candidate is touched.
""",
        encoding="utf-8",
        newline="\n",
    )
    return path


def write_manifest(output_root: Path, baseline_root: Path, after_root: Path, after_manifest: dict[str, object]) -> Path:
    tool_paths = (
        ROOT / "tools/art/build_caden_wayfarer_landscape_surfaces_v1.py",
        ROOT / "tools/art/render_caden_wayfarer_production_landscape_v4.gd",
        ROOT / "tools/art/build_caden_wayfarer_production_landscape_review_v4.py",
    )
    artifact_paths = sorted(
        path for path in output_root.rglob("*") if path.is_file() and path.name not in {PACKAGE_MANIFEST, CHECKSUMS}
    )
    manifest = {
        "schema": "caden-wayfarer-production-landscape-review-v4",
        "scope": "Selective Wayfarer's Approach landscape recomposition only.",
        "baseline": {
            "package": str(baseline_root),
            "package_manifest_sha256": sha256(baseline_root / "wayfarer_landscape_revision_manifest_v3.json"),
            "full_zone_source": BASELINE_FULL,
            "derived_focus_frames": "Native 640x360 crops from the checksummed 1024x640 v3 full-zone frame; no resampling.",
        },
        "after": {
            "render_root": str(after_root),
            "screenshot_manifest_sha256": sha256(after_root / AFTER_MANIFEST),
            "render_tool_sha256": after_manifest["render_tool_sha256"],
        },
        "protected_contracts": [
            "1024x640 zone and camera bounds",
            "640x360 internal and exact 1280x720 2x presentation",
            "existing road, exits, entries, transitions, collisions, inn, wagons, NPCs, dialogue, and interactions",
            "object-specific collision and player-relative depth sorting for 05 and 07",
            "05 and 07 remain the only Caden Mega Asset Library pilot additions",
        ],
        "tools": {path.relative_to(ROOT).as_posix(): sha256(path) for path in tool_paths},
        "artifacts": {path.relative_to(output_root).as_posix(): sha256(path) for path in artifact_paths},
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
    if len(entries) != 12:
        raise RuntimeError("Unexpected production-landscape screenshot manifest.")

    baseline_full_path = baseline_root / BASELINE_FULL
    copy_verified(baseline_full_path, captures / "wayfarer_full_zone_before_v4_1024x640.png", (1024, 640))
    copy_verified(
        verified_after(after_root, entries, "wayfarer_full_zone_after_v4_1024x640.png"),
        captures / "wayfarer_full_zone_after_v4_1024x640.png",
        (1024, 640),
    )
    with Image.open(baseline_full_path) as source:
        baseline_full = source.convert("RGBA")
        for key, center, after_name, _label in FOCUS_SPECS:
            crop_baseline(baseline_full, center, captures / f"wayfarer_{key}_before_v4_640x360.png")
            copy_verified(verified_after(after_root, entries, after_name), captures / f"wayfarer_{key}_after_v4_640x360.png", (640, 360))
    for filename in SUPPORTING_AFTER:
        size = (1280, 720) if filename.endswith("1280x720.png") else (640, 360)
        copy_verified(verified_after(after_root, entries, filename), captures / filename, size)

    native = captures / "wayfarer_primary_gameplay_after_v4_640x360.png"
    display = captures / "wayfarer_primary_display_after_v4_1280x720.png"
    with Image.open(native) as native_image, Image.open(display) as display_image:
        expected = native_image.convert("RGBA").resize((1280, 720), Image.Resampling.NEAREST)
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
