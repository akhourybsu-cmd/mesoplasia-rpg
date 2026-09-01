#!/usr/bin/env python3
"""Build labeled contact sheets and a clean package for all five Caden zones."""

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
RENDER_TOOL = ROOT / "tools/art/render_caden_five_zone_screengrabs_v1.gd"
ZONES = (
    ("WAYFARER'S APPROACH", "01_wayfarers_approach_full_zone_1024x640.png", "02_wayfarers_approach_primary_640x360.png", "03_wayfarers_approach_feature_640x360.png"),
    ("MARKETPLACE", "04_marketplace_full_zone_896x640.png", "05_marketplace_primary_640x360.png", "06_marketplace_feature_640x360.png"),
    ("TOWN SQUARE", "07_town_square_full_zone_960x704.png", "08_town_square_primary_640x360.png", "09_town_square_feature_640x360.png"),
    ("RESIDENTIAL", "10_residential_full_zone_1152x768.png", "11_residential_primary_640x360.png", "12_residential_feature_640x360.png"),
    ("COMMONS", "13_commons_full_zone_1024x704.png", "14_commons_primary_640x360.png", "15_commons_feature_640x360.png"),
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


def fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    result = image.convert("RGB")
    result.thumbnail(size, Image.Resampling.NEAREST)
    return result


def verify(render_root: Path) -> dict:
    manifest_path = render_root / "caden_five_zone_screengrab_manifest_v1.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        raise RuntimeError("Screengrab manifest is invalid.")
    if manifest.get("render_tool_sha256") != sha256(RENDER_TOOL):
        raise RuntimeError("Render tool changed after capture generation.")
    entries = manifest.get("captures", [])
    if len(entries) != 15 or len(list((render_root / "captures").glob("*.png"))) != 15:
        raise RuntimeError("Expected exactly 15 current-zone screenshots.")
    for entry in entries:
        scene = ROOT / str(entry["scene"]).removeprefix("res://")
        capture = render_root / "captures" / entry["filename"]
        if sha256(scene) != entry["scene_sha256"]:
            raise RuntimeError(f"Scene changed after capture: {entry['scene']}")
        if sha256(capture) != entry["sha256"]:
            raise RuntimeError(f"Capture identity mismatch: {entry['filename']}")
    return manifest


def make_overview_sheet(captures: Path, output: Path) -> None:
    board = Image.new("RGB", (1400, 1610), (17, 21, 19))
    draw = ImageDraw.Draw(board)
    draw.text((28, 18), "Caden - all five current zones", font=font(32, True), fill=(244, 241, 230))
    draw.text((28, 62), "Full serialized scene overviews | Godot 4.7 Compatibility renderer", font=font(16), fill=(189, 201, 191))
    for index, (label, full_name, _primary, _feature) in enumerate(ZONES):
        column = index % 2
        row = index // 2
        x = 28 + column * 686
        y = 106 + row * 494
        draw.text((x, y), label, font=font(19, True), fill=(235, 220, 163))
        image = fit(Image.open(captures / full_name), (658, 430))
        board.paste(image, (x, y + 34))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def make_gameplay_sheet(captures: Path, output: Path) -> None:
    board = Image.new("RGB", (1320, 2260), (17, 21, 19))
    draw = ImageDraw.Draw(board)
    draw.text((24, 18), "Caden - gameplay-scale zone views", font=font(32, True), fill=(244, 241, 230))
    draw.text((24, 62), "Primary composition and distinguishing feature | 640x360 native captures", font=font(16), fill=(189, 201, 191))
    for row, (label, _full, primary_name, feature_name) in enumerate(ZONES):
        y = 104 + row * 430
        draw.text((24, y), label, font=font(19, True), fill=(235, 220, 163))
        primary = Image.open(captures / primary_name).convert("RGB")
        feature = Image.open(captures / feature_name).convert("RGB")
        board.paste(primary, (24, y + 34))
        board.paste(feature, (656, y + 34))
        draw.text((24, y + 398), "PRIMARY VIEW", font=font(13, True), fill=(179, 188, 180))
        draw.text((656, y + 398), "FEATURE VIEW", font=font(13, True), fill=(179, 188, 180))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("render_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    render_root = args.render_root.resolve()
    output_root = args.output_root.resolve()
    for path in (render_root, output_root):
        if path == ROOT or ROOT in path.parents:
            raise RuntimeError("Screengrab inputs and output must remain outside res://.")
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    manifest = verify(render_root)
    output_root.mkdir(parents=True, exist_ok=True)
    shutil.copytree(render_root / "captures", output_root / "captures")
    (output_root / "metadata").mkdir(parents=True, exist_ok=True)
    shutil.copyfile(
        render_root / "caden_five_zone_screengrab_manifest_v1.json",
        output_root / "metadata/caden_five_zone_screengrab_manifest_v1.json",
    )
    (output_root / "tooling").mkdir(parents=True, exist_ok=True)
    for tool in (SCRIPT_PATH, RENDER_TOOL):
        shutil.copyfile(tool, output_root / "tooling" / tool.name)
    make_overview_sheet(output_root / "captures", output_root / "boards/caden_all_zones_overview_v1.png")
    make_gameplay_sheet(output_root / "captures", output_root / "boards/caden_all_zones_gameplay_v1.png")
    (output_root / "README.md").write_text(
        "# Caden Five-Zone Screenshots v1\n\n"
        "Fifteen current-state captures: one complete overview and two native 640x360 gameplay views for each of "
        "Wayfarer's Approach, Marketplace, Town Square, Residential, and Commons. The images reflect the serialized "
        "scenes at the recorded hashes in the manifest.\n",
        encoding="utf-8", newline="\n",
    )
    package_manifest = {
        "schema": "caden-five-zone-screengrab-package-v1",
        "source_manifest_sha256": sha256(render_root / "caden_five_zone_screengrab_manifest_v1.json"),
        "capture_count": len(manifest["captures"]),
        "board_count": 2,
        "tooling_sha256": {tool.name: sha256(tool) for tool in (SCRIPT_PATH, RENDER_TOOL)},
    }
    (output_root / "metadata/caden_five_zone_screengrab_package_v1.json").write_text(
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
        for path in sorted(p for p in output_root.rglob("*") if p.is_file()):
            archive.write(path, (Path(output_root.name) / path.relative_to(output_root)).as_posix())
    print(f"package={output_root}")
    print(f"captures={len(manifest['captures'])}")
    print(f"zip={zip_path}")
    print(f"zip_sha256={sha256(zip_path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
