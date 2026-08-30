#!/usr/bin/env python3
"""Prepare inactive Town Square terrain and architecture comparisons."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
DEPENDENCY_PATH = ROOT / "tools/art/prepare_caden_building_terrain_gate_v1_1.py"
SCENE_PATH = ROOT / "scenes/world/caden/TownSquare.tscn"
CURRENT_ATLAS = ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png"
CURRENT_TILESET = ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.tres"
ARCHITECTURE_MANIFEST = ROOT / "assets/environments/caden/architecture/town_square/caden_architecture_runtime_v2_manifest.json"
PLAYER_PATH = ROOT / "assets/characters/caden/player/caden_player_runtime_v1.png"
CELL = 32
ATLAS_SIZE = (256, 256)

CANDIDATES = (
    ("northwest", "cad_bld_v2_r04_c03", "caden_buildings_volume_2_master.png", 4, 3, (500, 750, 770, 1000), "town_square_broad", 0.72, "GenericBuildingNorthwest", "maintained public-house frontage", (160, 96)),
    ("southwest", "cad_bld_v2_r04_c04", "caden_buildings_volume_2_master.png", 4, 4, (745, 750, 1020, 1000), "town_square_broad", 0.74, "GenericBuildingSouthwest", "workshop and service frontage", (160, 96)),
    ("northeast", "cad_bld_v2_r02_c05", "caden_buildings_volume_2_master.png", 2, 5, (995, 310, 1218, 550), "town_square_standard", 0.75, "GenericBuildingNortheast", "compact civic-side cottage", (128, 96)),
    ("southeast", "cad_bld_v2_r04_c01", "caden_buildings_volume_2_master.png", 4, 1, (10, 745, 280, 1005), "town_square_broad", 0.68, "GenericBuildingSoutheast", "two-story community frontage", (160, 96)),
    ("south", "cad_bld_v1_r04_c05", "caden_buildings_volume_1_master.png", 4, 5, (1160, 765, 1385, 1010), "town_square_small", 0.80, "GenericBuildingSouth", "small service outbuilding", (128, 64)),
)
SOURCE_HASHES = {
    "caden_buildings_volume_1_master.png": "1f9bc86b2e91aecd9ad455e6ca768fccb2c8c9699cc653ec695202dd3bbcc8a4",
    "caden_buildings_volume_2_master.png": "d4df1a8fd892cc16153e32aa8b97d7760df4a3d718b01f0c804853a4ad34895f",
}
GRASS_NAMES = ["grass_base"] + [f"grass_variant_{index:02d}" for index in range(2, 10)]
STONE_NAMES = ["stone_base"] + [f"stone_variant_{index:02d}" for index in range(2, 10)]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise RuntimeError(f"Expected JSON object: {path}")
    return payload


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8", newline="\n")


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    path = Path("C:/Windows/Fonts") / ("segoeuib.ttf" if bold else "segoeui.ttf")
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def assert_external(path: Path, label: str) -> Path:
    resolved = path.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError(f"{label} must remain outside res://.")
    return resolved


def verify_checksums(root: Path, expected_count: int, label: str) -> None:
    lines = [line for line in (root / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != expected_count:
        raise RuntimeError(f"{label} checksum count changed: {len(lines)}")
    for line in lines:
        digest, relative = line.split("  ", 1)
        path = root / Path(relative)
        if not path.is_file() or sha256(path) != digest:
            raise RuntimeError(f"{label} checksum mismatch: {relative}")


def load_cleanup_module():
    spec = importlib.util.spec_from_file_location("caden_gate0_cleanup", DEPENDENCY_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load Gate 0 cleanup dependency.")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def atlas_tile(atlas: Image.Image, coordinate: list[int] | tuple[int, int]) -> Image.Image:
    x, y = coordinate
    return atlas.crop((x * CELL, y * CELL, (x + 1) * CELL, (y + 1) * CELL)).convert("RGBA")


def mean_rgb(tiles: list[Image.Image]) -> tuple[float, float, float]:
    pixels = [pixel for tile in tiles for pixel in tile.convert("RGB").get_flattened_data()]
    return tuple(sum(pixel[channel] for pixel in pixels) / len(pixels) for channel in range(3))


def distance(pixel: tuple[int, int, int, int], mean: tuple[float, float, float]) -> float:
    return sum((pixel[channel] - mean[channel]) ** 2 for channel in range(3))


def build_compatible_atlas(current: Image.Image, harmonized: Image.Image, coordinates: dict[str, list[int]]) -> Image.Image:
    output = current.copy().convert("RGBA")
    old_grass_tiles = [atlas_tile(current, (x, 0)) for x in range(8)]
    old_stone_tiles = [atlas_tile(current, (x, 4)) for x in range(8)]
    old_grass_mean = mean_rgb(old_grass_tiles)
    old_stone_mean = mean_rgb(old_stone_tiles)
    new_grass = [atlas_tile(harmonized, coordinates[name]) for name in GRASS_NAMES]
    new_stone = [atlas_tile(harmonized, coordinates[name]) for name in STONE_NAMES]

    for x in range(8):
        output.paste(new_grass[x], (x * CELL, 0))
        output.paste(new_stone[x], (x * CELL, 4 * CELL))
    for row in (5, 6, 7):
        for column in range(8):
            source = atlas_tile(current, (column, row))
            grass_tile = new_grass[(column + row) % len(new_grass)]
            stone_tile = new_stone[(column * 3 + row) % len(new_stone)]
            pixels = []
            source_pixels = list(source.get_flattened_data())
            grass_pixels = list(grass_tile.get_flattened_data())
            stone_pixels = list(stone_tile.get_flattened_data())
            for index, pixel in enumerate(source_pixels):
                if pixel[3] == 0:
                    pixels.append((0, 0, 0, 0))
                elif distance(pixel, old_grass_mean) <= distance(pixel, old_stone_mean):
                    pixels.append((*grass_pixels[index][:3], 255))
                else:
                    pixels.append((*stone_pixels[index][:3], 255))
            tile = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            tile.putdata(pixels)
            output.paste(tile, (column * CELL, row * CELL))
    return output


def make_building_board(records: list[dict], output_root: Path, output_path: Path) -> None:
    board = Image.new("RGB", (1280, 720), (28, 33, 29))
    draw = ImageDraw.Draw(board)
    draw.text((28, 20), "Town Square protected architecture gate v1.2", font=font(28, True), fill=(242, 239, 228))
    draw.text((28, 60), "Five cleaned candidates at exact proposed runtime scale; Player shown as 40 x 56 authority", font=font(16), fill=(194, 201, 190))
    player_sheet = Image.open(PLAYER_PATH).convert("RGBA")
    player = player_sheet.crop((0, 0, 40, 56))
    for index, record in enumerate(records):
        column, row = index % 3, index // 3
        x0, y0 = 28 + column * 412, 102 + row * 294
        draw.text((x0, y0), f"{record['slot'].upper()} | {record['source_id']}", font=font(16, True), fill=(222, 220, 208))
        runtime = Image.open(output_root / record["runtime_path"]).convert("RGBA")
        stage = Image.new("RGBA", (380, 240), (239, 237, 229, 255))
        baseline = 204
        stage.alpha_composite(runtime, ((stage.width - runtime.width) // 2 - 24, baseline - record["pivot_xy"][1]))
        stage.alpha_composite(player, (stage.width // 2 + 70, baseline - 55))
        board.paste(stage.convert("RGB"), (x0, y0 + 28))
        draw.text((x0, y0 + 272), f"{record['runtime_dimensions'][0]}x{record['runtime_dimensions'][1]}  factor {record['normalization_factor']}", font=font(14), fill=(194, 201, 190))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(output_path)


def make_terrain_board(current: Image.Image, candidate: Image.Image, output_path: Path) -> None:
    board = Image.new("RGB", (960, 520), (28, 33, 29))
    draw = ImageDraw.Draw(board)
    draw.text((24, 20), "Town Square compatible terrain atlas v1.2", font=font(27, True), fill=(242, 239, 228))
    draw.text((24, 60), "Same 8 x 8 coordinates. Dirt rows retained byte-for-byte; grass and plaza material replaced.", font=font(15), fill=(194, 201, 190))
    draw.text((24, 96), "CURRENT v1.1", font=font(16, True), fill=(214, 215, 204))
    draw.text((496, 96), "CANDIDATE v1.2", font=font(16, True), fill=(214, 215, 204))
    board.paste(current.convert("RGB").resize((416, 416), Image.Resampling.NEAREST), (24, 124))
    board.paste(candidate.convert("RGB").resize((416, 416), Image.Resampling.NEAREST), (496, 124))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(output_path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument("gate_zero_root", type=Path)
    parser.add_argument("approved_terrain_review_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    source_root = args.source_root.resolve()
    gate_root = assert_external(args.gate_zero_root, "Gate 0 root")
    review_root = assert_external(args.approved_terrain_review_root, "Approved terrain review root")
    output_root = assert_external(args.output_root, "Output root")
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)
    verify_checksums(gate_root, 47, "Gate 0")
    verify_checksums(review_root, 29, "Approved terrain review")
    for filename, digest in SOURCE_HASHES.items():
        if sha256(source_root / filename) != digest:
            raise RuntimeError(f"Town Square source identity mismatch: {filename}")
    scene_hash = sha256(SCENE_PATH)
    architecture_manifest = load_json(ARCHITECTURE_MANIFEST)
    if len(architecture_manifest.get("generated_buildings", {})) != 5:
        raise RuntimeError("Town Square Runtime v2 architecture baseline changed.")

    cleanup = load_cleanup_module()
    masters = {filename: Image.open(source_root / filename).convert("RGB") for filename in SOURCE_HASHES}
    records: list[dict] = []
    for slot, source_id, filename, row, column, crop, family, factor, node, role, collision in CANDIDATES:
        spec = cleanup.CandidateSpec(source_id, filename, row, column, crop, family, factor, node, role)
        source_clean, runtime, metadata = cleanup.clean_candidate(masters[filename], spec)
        source_clean_path = output_root / f"candidate/source_clean/{source_id}_clean.png"
        runtime_path = output_root / f"candidate/buildings/{source_id}_runtime_preview.png"
        source_clean_path.parent.mkdir(parents=True, exist_ok=True)
        runtime_path.parent.mkdir(parents=True, exist_ok=True)
        source_clean.save(source_clean_path, format="PNG", compress_level=9)
        runtime.save(runtime_path, format="PNG", compress_level=9)
        metadata["intended_collision_footprint"] = list(collision)
        record = {
            "slot": slot, "source_id": source_id, "source_filename": filename,
            "source_sha256": SOURCE_HASHES[filename], "row": row, "column": column,
            "visual_role": role, "scale_family": family, "normalization_factor": factor,
            "target_node": f"SolidScenery/Buildings/{node}", "collision_footprint": list(collision),
            "runtime_path": runtime_path.relative_to(output_root).as_posix(),
            "runtime_sha256": sha256(runtime_path), "runtime_dimensions": list(runtime.size),
            "source_clean_path": source_clean_path.relative_to(output_root).as_posix(),
            "source_clean_sha256": sha256(source_clean_path), "status": "inactive_town_square_candidate",
            "approval_state": "protected_comparison_only", **metadata,
        }
        records.append(record)

    gate_manifest = load_json(gate_root / "metadata/preparation_manifest_v1_1.json")
    coordinates = gate_manifest["terrain"]["atlas_coordinates"]
    review_manifest = load_json(review_root / "metadata/residential_terrain_preparation_manifest_v1_2.json")
    harmonized_path = review_root / review_manifest["candidate"]["atlas_path"]
    if sha256(harmonized_path) != review_manifest["candidate"]["atlas_sha256"]:
        raise RuntimeError("Approved harmonized atlas identity mismatch.")
    current_atlas = Image.open(CURRENT_ATLAS).convert("RGBA")
    harmonized_atlas = Image.open(harmonized_path).convert("RGBA")
    candidate_atlas = build_compatible_atlas(current_atlas, harmonized_atlas, coordinates)
    if candidate_atlas.size != ATLAS_SIZE:
        raise RuntimeError("Town Square compatible atlas dimensions changed.")
    for row in (1, 2, 3):
        if candidate_atlas.crop((0, row * CELL, 256, (row + 1) * CELL)).tobytes() != current_atlas.crop((0, row * CELL, 256, (row + 1) * CELL)).tobytes():
            raise RuntimeError("Protected dirt-road atlas rows changed.")
    atlas_path = output_root / "candidate/terrain/town_square_terrain_atlas_candidate_v1_2.png"
    atlas_path.parent.mkdir(parents=True, exist_ok=True)
    candidate_atlas.save(atlas_path, format="PNG", compress_level=9)
    building_board = output_root / "boards/town_square_building_scale_audit_v1_2.png"
    terrain_board = output_root / "boards/town_square_terrain_atlas_audit_v1_2.png"
    make_building_board(records, output_root, building_board)
    make_terrain_board(current_atlas, candidate_atlas, terrain_board)

    manifest = {
        "schema": "caden-town-square-protected-gate-v1.2-preparation",
        "gate_state": "inactive_town_square_terrain_architecture_comparison",
        "scope": "Protected Town Square terrain and architecture comparison only; no active scene or resource reference changed.",
        "generator": SCRIPT_PATH.relative_to(ROOT).as_posix(), "generator_sha256": sha256(SCRIPT_PATH),
        "cleanup_dependency": DEPENDENCY_PATH.relative_to(ROOT).as_posix(), "cleanup_dependency_sha256": sha256(DEPENDENCY_PATH),
        "scene": SCENE_PATH.relative_to(ROOT).as_posix(), "scene_sha256": scene_hash,
        "active_baseline": {
            "tileset": CURRENT_TILESET.relative_to(ROOT).as_posix(), "terrain_atlas_sha256": sha256(CURRENT_ATLAS),
            "architecture_manifest_sha256": sha256(ARCHITECTURE_MANIFEST), "status": "retained_unchanged",
        },
        "terrain_candidate": {
            "path": atlas_path.relative_to(output_root).as_posix(), "sha256": sha256(atlas_path),
            "dimensions": list(candidate_atlas.size), "cell_size": [CELL, CELL],
            "coordinate_contract": "exact active 8x8 atlas coordinates",
            "dirt_rows": [1, 2, 3], "dirt_rows_status": "byte_identical_to_runtime_v1_1",
            "grass_row": 0, "plaza_rows": [4, 5, 6, 7], "collision": "none",
            "status": "inactive_candidate",
        },
        "building_candidates": records,
        "boards": {
            building_board.relative_to(output_root).as_posix(): sha256(building_board),
            terrain_board.relative_to(output_root).as_posix(): sha256(terrain_board),
        },
        "protected_contracts": [
            "five StaticBody2D centers and authoritative collision rectangles",
            "octagonal plaza, all TileMap cell coordinates, four travel corridors, and distinct dirt roads",
            "blocked Terrebonne branch, reserved community space, entries, exits, NPCs, interactions, and bounds",
            "TownSquare.tscn, Runtime v2 architecture, Runtime v1.1 TileSet, and all active references",
        ],
        "provenance_and_licensing": review_manifest["provenance_and_licensing"],
    }
    manifest_path = output_root / "metadata/town_square_protected_preparation_manifest_v1_2.json"
    write_json(manifest_path, manifest)
    print(f"terrain_candidate={atlas_path}")
    print(f"terrain_sha256={sha256(atlas_path)}")
    print(f"building_candidates={len(records)}")
    print(f"manifest={manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
