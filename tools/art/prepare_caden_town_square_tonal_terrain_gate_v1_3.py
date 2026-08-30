#!/usr/bin/env python3
"""Prepare a topology-identical warm tonal Town Square terrain candidate."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
CURRENT_ATLAS = ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png"
SCENE_PATH = ROOT / "scenes/world/caden/TownSquare.tscn"
CELL = 32


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise RuntimeError(f"Expected JSON object: {path}")
    return value


def verify_checksums(root: Path, count: int) -> None:
    lines = [line for line in (root / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != count:
        raise RuntimeError(f"Checksum count changed for {root.name}: {len(lines)}")
    for line in lines:
        digest, relative = line.split("  ", 1)
        artifact = root / Path(relative)
        if not artifact.is_file() or sha256(artifact) != digest:
            raise RuntimeError(f"Checksum mismatch: {artifact}")


def tile(atlas: Image.Image, coordinate: list[int] | tuple[int, int]) -> Image.Image:
    x, y = coordinate
    return atlas.crop((x * CELL, y * CELL, (x + 1) * CELL, (y + 1) * CELL)).convert("RGBA")


def mean_rgb(images: list[Image.Image]) -> tuple[float, float, float]:
    pixels = [pixel for image in images for pixel in image.get_flattened_data() if pixel[3] != 0]
    return tuple(sum(pixel[channel] for pixel in pixels) / len(pixels) for channel in range(3))


def distance(pixel: tuple[int, int, int, int], mean: tuple[float, float, float]) -> float:
    return sum((pixel[channel] - mean[channel]) ** 2 for channel in range(3))


def remap(pixel: tuple[int, int, int, int], source_mean: tuple[float, float, float], target_mean: tuple[float, float, float], strength: float, contrast: float) -> tuple[int, int, int, int]:
    channels = []
    for channel in range(3):
        shifted_target = source_mean[channel] + (target_mean[channel] - source_mean[channel]) * strength
        value = shifted_target + (pixel[channel] - source_mean[channel]) * contrast
        channels.append(max(0, min(255, round(value))))
    return channels[0], channels[1], channels[2], pixel[3]


def build_candidate(current: Image.Image, harmonized: Image.Image, coordinates: dict[str, list[int]]) -> tuple[Image.Image, dict]:
    output = current.copy().convert("RGBA")
    current_grass_mean = mean_rgb([tile(current, (x, 0)) for x in range(8)])
    current_stone_mean = mean_rgb([tile(current, (x, 4)) for x in range(8)])
    target_grass_mean = mean_rgb([tile(harmonized, coordinates["grass_base"])] + [tile(harmonized, coordinates[f"grass_variant_{index:02d}"]) for index in range(2, 10)])
    target_stone_mean = mean_rgb([tile(harmonized, coordinates["stone_base"])] + [tile(harmonized, coordinates[f"stone_variant_{index:02d}"]) for index in range(2, 10)])
    for y in range(current.height):
        row = y // CELL
        if row in (1, 2, 3):
            continue
        for x in range(current.width):
            pixel = current.getpixel((x, y))
            if pixel[3] == 0:
                continue
            if row == 0:
                changed = remap(pixel, current_grass_mean, target_grass_mean, 0.72, 0.92)
            elif row == 4:
                changed = remap(pixel, current_stone_mean, target_stone_mean, 0.68, 0.86)
            elif distance(pixel, current_grass_mean) <= distance(pixel, current_stone_mean):
                changed = remap(pixel, current_grass_mean, target_grass_mean, 0.72, 0.92)
            else:
                changed = remap(pixel, current_stone_mean, target_stone_mean, 0.68, 0.86)
            output.putpixel((x, y), changed)
    return output, {
        "current_grass_mean_rgb": [round(value, 3) for value in current_grass_mean],
        "target_grass_mean_rgb": [round(value, 3) for value in target_grass_mean],
        "current_stone_mean_rgb": [round(value, 3) for value in current_stone_mean],
        "target_stone_mean_rgb": [round(value, 3) for value in target_stone_mean],
        "grass_shift_strength": 0.72,
        "stone_shift_strength": 0.68,
        "grass_contrast": 0.92,
        "stone_contrast": 0.86,
    }


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    path = Path("C:/Windows/Fonts") / ("segoeuib.ttf" if bold else "segoeui.ttf")
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def make_board(current: Image.Image, candidate: Image.Image, output: Path) -> None:
    board = Image.new("RGB", (960, 520), (18, 23, 20))
    draw = ImageDraw.Draw(board)
    draw.text((24, 18), "Town Square tonal terrain candidate v1.3", font=font(27, True), fill=(244, 241, 230))
    draw.text((24, 56), "Exact v1.1 pattern and masks. Dirt rows byte-identical; grass and formal paving receive source-derived tonal harmonization.", font=font(14), fill=(193, 201, 191))
    draw.text((24, 94), "CURRENT v1.1", font=font(17, True), fill=(231, 229, 217))
    draw.text((496, 94), "TONAL CANDIDATE v1.3", font=font(17, True), fill=(231, 229, 217))
    board.paste(current.convert("RGB").resize((416, 416), Image.Resampling.NEAREST), (24, 122))
    board.paste(candidate.convert("RGB").resize((416, 416), Image.Resampling.NEAREST), (496, 122))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("gate_zero_root", type=Path)
    parser.add_argument("approved_terrain_review_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    gate_root = args.gate_zero_root.resolve()
    review_root = args.approved_terrain_review_root.resolve()
    output_root = args.output_root.resolve()
    for path in (gate_root, review_root, output_root):
        if path == ROOT or ROOT in path.parents:
            raise RuntimeError("Tonal terrain preparation must remain outside res://.")
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)
    verify_checksums(gate_root, 47)
    verify_checksums(review_root, 29)
    gate_manifest = load_json(gate_root / "metadata/preparation_manifest_v1_1.json")
    review_manifest = load_json(review_root / "metadata/residential_terrain_preparation_manifest_v1_2.json")
    harmonized_path = review_root / review_manifest["candidate"]["atlas_path"]
    if sha256(harmonized_path) != review_manifest["candidate"]["atlas_sha256"]:
        raise RuntimeError("Approved harmonized terrain identity mismatch.")
    current = Image.open(CURRENT_ATLAS).convert("RGBA")
    harmonized = Image.open(harmonized_path).convert("RGBA")
    candidate, tonal = build_candidate(current, harmonized, gate_manifest["terrain"]["atlas_coordinates"])
    for row in (1, 2, 3):
        bounds = (0, row * CELL, 256, (row + 1) * CELL)
        if current.crop(bounds).tobytes() != candidate.crop(bounds).tobytes():
            raise RuntimeError("Protected dirt-road rows changed.")
    if current.getchannel("A").tobytes() != candidate.getchannel("A").tobytes():
        raise RuntimeError("Terrain atlas alpha topology changed.")
    candidate_path = output_root / "candidate/town_square_terrain_tonal_candidate_v1_3.png"
    candidate_path.parent.mkdir(parents=True, exist_ok=True)
    candidate.save(candidate_path, format="PNG", compress_level=9)
    board_path = output_root / "boards/town_square_tonal_atlas_audit_v1_3.png"
    make_board(current, candidate, board_path)
    manifest = {
        "schema": "caden-town-square-tonal-terrain-gate-v1.3-preparation",
        "gate_state": "inactive_town_square_tonal_terrain_comparison",
        "scope": "Cross-zone tonal harmonization candidate; no active reference changed.",
        "generator": SCRIPT_PATH.relative_to(ROOT).as_posix(),
        "generator_sha256": sha256(SCRIPT_PATH),
        "scene": SCENE_PATH.relative_to(ROOT).as_posix(),
        "scene_sha256": sha256(SCENE_PATH),
        "current_atlas": CURRENT_ATLAS.relative_to(ROOT).as_posix(),
        "current_atlas_sha256": sha256(CURRENT_ATLAS),
        "candidate_path": candidate_path.relative_to(output_root).as_posix(),
        "candidate_sha256": sha256(candidate_path),
        "dimensions": list(candidate.size),
        "cell_size": [CELL, CELL],
        "topology_contract": "exact current RGB pattern geometry and alpha masks; only rows 0 and 4-7 receive tonal remapping",
        "dirt_rows": [1, 2, 3],
        "dirt_rows_status": "byte_identical",
        "tonal_transfer": tonal,
        "source_harmonized_atlas_sha256": review_manifest["candidate"]["atlas_sha256"],
        "provenance_and_licensing": review_manifest["provenance_and_licensing"],
        "active_reference_changed": False,
    }
    manifest_path = output_root / "metadata/town_square_tonal_terrain_preparation_v1_3.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"candidate={candidate_path}")
    print(f"candidate_sha256={sha256(candidate_path)}")
    print(f"manifest={manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
