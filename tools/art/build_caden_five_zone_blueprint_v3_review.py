#!/usr/bin/env python3
"""Package blueprint v3 before/after and approval-boundary review evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
RENDER_TOOL = ROOT / "tools/art/render_caden_five_zone_blueprint_v3.gd"
ZONES = (
    ("WAYFARER'S APPROACH", "01_wayfarers_approach_full_zone_1024x640.png", "02_wayfarers_approach_primary_640x360.png", "03_wayfarers_approach_feature_640x360.png", "PROTECTED / UNCHANGED"),
    ("MARKETPLACE", "04_marketplace_full_zone_896x640.png", "05_marketplace_primary_640x360.png", "06_marketplace_feature_640x360.png", "ACTIVE BLUEPRINT V3"),
    ("TOWN SQUARE", "07_town_square_full_zone_960x704.png", "08_town_square_primary_640x360.png", "09_town_square_feature_640x360.png", "ACTIVE — USER APPROVED"),
    ("RESIDENTIAL", "10_residential_full_zone_1152x768.png", "11_residential_primary_640x360.png", "12_residential_feature_640x360.png", "ACTIVE BLUEPRINT V3"),
    ("COMMONS", "13_commons_full_zone_1024x704.png", "14_commons_primary_640x360.png", "15_commons_feature_640x360.png", "ACTIVE BLUEPRINT V3"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    path = Path("C:/Windows/Fonts") / ("segoeuib.ttf" if bold else "segoeui.ttf")
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def contain(path: Path, size: tuple[int, int]) -> Image.Image:
    image = Image.open(path).convert("RGB")
    image.thumbnail(size, Image.Resampling.NEAREST)
    return image


def load_manifest(root: Path, names: tuple[str, ...], expected_counts: tuple[int, ...]) -> tuple[dict, Path]:
    manifest_path = next((root / name for name in names if (root / name).is_file()), None)
    if manifest_path is None:
        raise RuntimeError(f"No supported capture manifest found in {root}.")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    captures = manifest.get("captures", [])
    if len(captures) not in expected_counts:
        raise RuntimeError(f"Expected capture count {expected_counts} in {manifest_path}.")
    for entry in captures:
        capture = root / "captures" / entry["filename"]
        if not capture.is_file() or sha256(capture) != entry["sha256"]:
            raise RuntimeError(f"Capture hash mismatch: {capture}")
    return manifest, manifest_path


def before_after_board(baseline: Path, current: Path, output: Path) -> None:
    board = Image.new("RGB", (1840, 3440), (17, 21, 19))
    draw = ImageDraw.Draw(board)
    draw.text((32, 22), "Caden five-zone blueprint v3 — before / after", font=font(36, True), fill=(244, 241, 230))
    draw.text((32, 72), "Serialized scene overviews | native Godot 4.7 Compatibility captures", font=font(18), fill=(189, 201, 191))
    draw.text((34, 108), "BEFORE", font=font(18, True), fill=(191, 181, 154))
    draw.text((936, 108), "AFTER", font=font(18, True), fill=(171, 218, 171))
    for row, (label, full_name, _primary, _feature, state) in enumerate(ZONES):
        y = 150 + row * 650
        draw.text((32, y), label, font=font(24, True), fill=(235, 220, 163))
        draw.text((930, y), state, font=font(16, True), fill=(171, 218, 171))
        left = contain(baseline / full_name, (870, 590))
        right = contain(current / full_name, (870, 590))
        board.paste(left, (32, y + 38))
        board.paste(right, (930, y + 38))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def gameplay_board(current: Path, output: Path) -> None:
    board = Image.new("RGB", (1320, 2260), (17, 21, 19))
    draw = ImageDraw.Draw(board)
    draw.text((24, 18), "Caden blueprint v3 — gameplay views", font=font(34, True), fill=(244, 241, 230))
    draw.text((24, 66), "Primary circulation and distinguishing feature | native 640x360", font=font(17), fill=(189, 201, 191))
    for row, (label, _full, primary_name, feature_name, state) in enumerate(ZONES):
        y = 106 + row * 430
        draw.text((24, y), label, font=font(20, True), fill=(235, 220, 163))
        draw.text((656, y), state, font=font(14, True), fill=(171, 218, 171))
        board.paste(Image.open(current / primary_name).convert("RGB"), (24, y + 34))
        board.paste(Image.open(current / feature_name).convert("RGB"), (656, y + 34))
        draw.text((24, y + 398), "PRIMARY", font=font(13, True), fill=(179, 188, 180))
        draw.text((656, y + 398), "FEATURE", font=font(13, True), fill=(179, 188, 180))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def town_square_board(before: Path, current: Path, output: Path) -> None:
    board = Image.new("RGB", (1960, 820), (17, 21, 19))
    draw = ImageDraw.Draw(board)
    draw.text((28, 18), "Town Square approved activation", font=font(34, True), fill=(244, 241, 230))
    draw.text((28, 66), "Left: pre-approval active base. Right: approved civic-garden assembly active once.", font=font(18), fill=(189, 201, 191))
    draw.text((28, 104), "PRE-APPROVAL ACTIVE BASE", font=font(18, True), fill=(191, 181, 154))
    draw.text((1000, 104), "APPROVED / ACTIVE", font=font(18, True), fill=(171, 218, 171))
    base = contain(before / "07_town_square_full_zone_960x704.png", (930, 670))
    approved = contain(current / "07_town_square_full_zone_960x704.png", (930, 670))
    board.paste(base, (28, 140))
    board.paste(approved, (1000, 140))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline_root", type=Path)
    parser.add_argument("current_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    baseline_root = args.baseline_root.resolve()
    current_root = args.current_root.resolve()
    output_root = args.output_root.resolve()
    if output_root == ROOT or ROOT in output_root.parents:
        raise RuntimeError("Review output must remain outside res://.")
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    baseline_manifest, baseline_manifest_path = load_manifest(
        baseline_root,
        ("caden_five_zone_blueprint_v3_review.json", "caden_five_zone_screengrab_manifest_v1.json"),
        (15, 17),
    )
    current_manifest, current_manifest_path = load_manifest(
        current_root,
        ("caden_five_zone_blueprint_v3_review.json",),
        (17,),
    )
    if current_manifest.get("render_tool_sha256") != sha256(RENDER_TOOL):
        raise RuntimeError("Blueprint renderer changed after capture generation.")

    output_root.mkdir(parents=True, exist_ok=True)
    shutil.copytree(baseline_root / "captures", output_root / "captures/before")
    shutil.copytree(current_root / "captures", output_root / "captures/after")
    (output_root / "metadata").mkdir(parents=True)
    shutil.copyfile(baseline_manifest_path, output_root / "metadata/before_manifest.json")
    shutil.copyfile(current_manifest_path, output_root / "metadata/after_manifest.json")
    (output_root / "tooling").mkdir(parents=True)
    for tool in (SCRIPT_PATH, RENDER_TOOL):
        shutil.copyfile(tool, output_root / "tooling" / tool.name)
    before_after_board(output_root / "captures/before", output_root / "captures/after", output_root / "boards/caden_blueprint_v3_before_after.png")
    gameplay_board(output_root / "captures/after", output_root / "boards/caden_blueprint_v3_gameplay.png")
    town_square_board(output_root / "captures/before", output_root / "captures/after", output_root / "boards/caden_blueprint_v3_town_square_approval.png")
    (output_root / "README.md").write_text(
        "# Caden Five-Zone Blueprint v3 Review\n\n"
        "Pre-approval and approved captures for all five zones, current gameplay views, and a separately labeled Town Square activation comparison. "
        "Town Square, Marketplace, Residential, and Commons are active. Wayfarer's Approach remains protected.\n",
        encoding="utf-8", newline="\n",
    )
    package_manifest = {
        "schema": "caden-five-zone-blueprint-v3-review-package",
        "before_manifest_sha256": sha256(baseline_manifest_path),
        "after_manifest_sha256": sha256(current_manifest_path),
        "before_capture_count": len(baseline_manifest["captures"]),
        "after_capture_count": len(current_manifest["captures"]),
        "board_count": 3,
    }
    (output_root / "metadata/package_manifest.json").write_text(
        json.dumps(package_manifest, indent=2) + "\n", encoding="utf-8", newline="\n"
    )
    checksum_path = output_root / "SHA256SUMS.txt"
    files = sorted(path for path in output_root.rglob("*") if path.is_file() and path != checksum_path)
    checksum_path.write_text(
        "".join(f"{sha256(path)}  {path.relative_to(output_root).as_posix()}\n" for path in files),
        encoding="utf-8", newline="\n",
    )
    zip_path = output_root.with_suffix(".zip")
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(item for item in output_root.rglob("*") if item.is_file()):
            archive.write(path, (Path(output_root.name) / path.relative_to(output_root)).as_posix())
    print(f"package={output_root}")
    print(f"zip={zip_path}")
    print(f"zip_sha256={sha256(zip_path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
