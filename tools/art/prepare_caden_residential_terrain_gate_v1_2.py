#!/usr/bin/env python3
"""Prepare an external, inactive Residential terrain comparison candidate."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import statistics

from PIL import Image, ImageDraw, ImageFont, ImageStat


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
CURRENT_TERRAIN = ROOT / "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.png"
CURRENT_MANIFEST = ROOT / "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.json"
CELL_SIZE = 32
GRID_SIZE = (36, 24)

GRASS_NAMES = ["grass_base"] + [f"grass_variant_{index:02d}" for index in range(2, 10)]
STONE_NAMES = ["stone_base"] + [f"stone_variant_{index:02d}" for index in range(2, 10)]
TRANSITION_NAMES = [
    "grass_north", "grass_south", "grass_west", "grass_east",
    "grass_northwest", "grass_northeast", "grass_southwest", "grass_southeast",
]


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
    filename = "segoeuib.ttf" if bold else "segoeui.ttf"
    path = Path("C:/Windows/Fonts") / filename
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def assert_external(path: Path) -> Path:
    resolved = path.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError("Terrain gate output and Gate 0 input must remain outside res://.")
    return resolved


def verify_gate(gate_root: Path) -> dict:
    checksum_path = gate_root / "SHA256SUMS.txt"
    lines = [line for line in checksum_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != 47:
        raise RuntimeError("Expected 47 Gate 0 checksummed artifacts.")
    for line in lines:
        digest, relative = line.split("  ", 1)
        path = gate_root / Path(relative)
        if not path.is_file() or sha256(path) != digest:
            raise RuntimeError(f"Gate 0 checksum mismatch: {relative}")
    manifest = load_json(gate_root / "metadata/preparation_manifest_v1_1.json")
    terrain = manifest.get("terrain", {})
    atlas_path = gate_root / terrain.get("atlas_path", "")
    if not atlas_path.is_file() or sha256(atlas_path) != terrain.get("atlas_sha256", ""):
        raise RuntimeError("Gate 0 terrain atlas identity mismatch.")
    return terrain


def tile(atlas: Image.Image, position: list[int]) -> Image.Image:
    x, y = position
    return atlas.crop((x * CELL_SIZE, y * CELL_SIZE, (x + 1) * CELL_SIZE, (y + 1) * CELL_SIZE))


def material_mean(atlas: Image.Image, coordinates: dict, names: list[str]) -> tuple[float, float, float]:
    values: list[tuple[int, int, int]] = []
    for name in names:
        for red, green, blue, alpha in tile(atlas, coordinates[name]).get_flattened_data():
            if alpha:
                values.append((red, green, blue))
    return tuple(sum(pixel[channel] for pixel in values) / len(values) for channel in range(3))


def route_cells(route_contract: dict) -> set[tuple[int, int]]:
    result: set[tuple[int, int]] = set()
    for bounds in route_contract.values():
        x1, y1, x2, y2 = bounds
        for y in range(y1, y2 + 1):
            for x in range(x1, x2 + 1):
                result.add((x, y))
    return result


def current_material_mean(image: Image.Image, roads: set[tuple[int, int]], road: bool) -> tuple[float, float, float]:
    values: list[tuple[int, int, int]] = []
    for y in range(GRID_SIZE[1]):
        for x in range(GRID_SIZE[0]):
            if ((x, y) in roads) != road:
                continue
            values.extend(image.crop((x * CELL_SIZE, y * CELL_SIZE, (x + 1) * CELL_SIZE, (y + 1) * CELL_SIZE)).get_flattened_data())
    return tuple(sum(pixel[channel] for pixel in values) / len(values) for channel in range(3))


def grade_pixel(
    pixel: tuple[int, int, int, int],
    source_mean: tuple[float, float, float],
    target_mean: tuple[float, float, float],
    contrast: float,
    deviation_limit: float,
) -> tuple[int, int, int, int]:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return (0, 0, 0, 0)
    output = []
    for value, source, target in zip((red, green, blue), source_mean, target_mean):
        deviation = max(-deviation_limit, min(deviation_limit, value - source))
        output.append(round(max(0.0, min(255.0, target + deviation * contrast))))
    return (output[0], output[1], output[2], alpha)


def color_distance(pixel: tuple[int, int, int, int], mean: tuple[float, float, float]) -> float:
    return sum((pixel[channel] - mean[channel]) ** 2 for channel in range(3))


def grade_atlas(
    source: Image.Image,
    coordinates: dict,
    grass_source_mean: tuple[float, float, float],
    stone_source_mean: tuple[float, float, float],
    grass_target_mean: tuple[float, float, float],
    stone_target_mean: tuple[float, float, float],
) -> Image.Image:
    output = Image.new("RGBA", source.size, (0, 0, 0, 0))
    forced_grass = set(GRASS_NAMES)
    forced_stone = set(STONE_NAMES)
    for name, position in coordinates.items():
        source_tile = tile(source, position).convert("RGBA")
        graded = Image.new("RGBA", source_tile.size, (0, 0, 0, 0))
        pixels = []
        for pixel in source_tile.get_flattened_data():
            use_grass = name in forced_grass or (
                name not in forced_stone and color_distance(pixel, grass_source_mean) <= color_distance(pixel, stone_source_mean)
            )
            if use_grass:
                pixels.append(grade_pixel(pixel, grass_source_mean, grass_target_mean, 0.32, 46.0))
            else:
                pixels.append(grade_pixel(pixel, stone_source_mean, stone_target_mean, 0.58, 62.0))
        graded.putdata(pixels)
        output.alpha_composite(graded, (position[0] * CELL_SIZE, position[1] * CELL_SIZE))
    return output


def transition_name(x: int, y: int, roads: set[tuple[int, int]]) -> str | None:
    def grass_neighbor(nx: int, ny: int) -> bool:
        return 0 <= nx < GRID_SIZE[0] and 0 <= ny < GRID_SIZE[1] and (nx, ny) not in roads

    north = grass_neighbor(x, y - 1)
    south = grass_neighbor(x, y + 1)
    west = grass_neighbor(x - 1, y)
    east = grass_neighbor(x + 1, y)
    if north and west:
        return "grass_northwest"
    if north and east:
        return "grass_northeast"
    if south and west:
        return "grass_southwest"
    if south and east:
        return "grass_southeast"
    if north:
        return "grass_north"
    if south:
        return "grass_south"
    if west:
        return "grass_west"
    if east:
        return "grass_east"
    return None


def variant_index(x: int, y: int, count: int) -> int:
    value = (x * 73856093) ^ (y * 19349663) ^ ((x + y) * 83492791)
    value ^= value >> 13
    value *= 1274126177
    return (value ^ (value >> 16)) % count


def compose_runtime(atlas: Image.Image, coordinates: dict, roads: set[tuple[int, int]]) -> tuple[Image.Image, dict[str, int]]:
    output = Image.new("RGBA", (GRID_SIZE[0] * CELL_SIZE, GRID_SIZE[1] * CELL_SIZE), (0, 0, 0, 255))
    counts: dict[str, int] = {"grass": 0, "stone": 0, "transition": 0}
    for y in range(GRID_SIZE[1]):
        for x in range(GRID_SIZE[0]):
            if (x, y) not in roads:
                name = GRASS_NAMES[variant_index(x, y, len(GRASS_NAMES))]
                counts["grass"] += 1
            else:
                name = transition_name(x, y, roads)
                if name is None:
                    name = STONE_NAMES[variant_index(x, y, len(STONE_NAMES))]
                    counts["stone"] += 1
                else:
                    counts["transition"] += 1
            output.alpha_composite(tile(atlas, coordinates[name]), (x * CELL_SIZE, y * CELL_SIZE))
    return output, counts


def material_stats(image: Image.Image, roads: set[tuple[int, int]]) -> dict[str, dict[str, list[float]]]:
    result = {}
    for label, road in (("grass", False), ("road", True)):
        values = [[], [], []]
        for y in range(GRID_SIZE[1]):
            for x in range(GRID_SIZE[0]):
                if ((x, y) in roads) != road:
                    continue
                for pixel in image.crop((x * CELL_SIZE, y * CELL_SIZE, (x + 1) * CELL_SIZE, (y + 1) * CELL_SIZE)).convert("RGB").get_flattened_data():
                    for channel in range(3):
                        values[channel].append(pixel[channel])
        result[label] = {
            "mean_rgb": [round(statistics.fmean(channel), 3) for channel in values],
            "population_stddev_rgb": [round(statistics.pstdev(channel), 3) for channel in values],
        }
    return result


def make_repetition_board(atlas: Image.Image, coordinates: dict, output_path: Path) -> None:
    width, height = 760, 410
    board = Image.new("RGB", (width, height), (28, 33, 29))
    draw = ImageDraw.Draw(board)
    draw.text((24, 18), "Residential terrain v1.2 repetition audit", font=font(24, True), fill=(242, 239, 228))
    draw.text((24, 56), "Nine exact 32x32 variants per material; palette and contrast harmonized", font=font(15), fill=(194, 201, 190))
    for column, (title, names) in enumerate((("calm grass", GRASS_NAMES), ("warm stone", STONE_NAMES))):
        x0 = 24 + column * 372
        draw.text((x0, 88), title, font=font(17, True), fill=(222, 220, 208))
        mosaic = Image.new("RGBA", (288, 288), (0, 0, 0, 255))
        for y in range(9):
            for x in range(9):
                name = names[variant_index(x, y, len(names))]
                mosaic.alpha_composite(tile(atlas, coordinates[name]), (x * CELL_SIZE, y * CELL_SIZE))
        board.paste(mosaic.convert("RGB"), (x0, 116))
    board.save(output_path)


def make_material_board(current: Image.Image, candidate: Image.Image, output_path: Path) -> None:
    board = Image.new("RGB", (760, 430), (28, 33, 29))
    draw = ImageDraw.Draw(board)
    draw.text((24, 18), "Residential terrain v1.2 inactive material comparison", font=font(23, True), fill=(242, 239, 228))
    draw.text((24, 54), "Current dirt route", font=font(16, True), fill=(214, 215, 204))
    draw.text((396, 54), "Calm source-derived stone", font=font(16, True), fill=(214, 215, 204))
    crop_box = (448, 288, 704, 544)
    board.paste(current.crop(crop_box).convert("RGB").resize((320, 320), Image.Resampling.NEAREST), (24, 84))
    board.paste(candidate.crop(crop_box).convert("RGB").resize((320, 320), Image.Resampling.NEAREST), (396, 84))
    draw.text((24, 408), "Comparison only; the active Residential terrain reference is unchanged", font=font(14, True), fill=(222, 184, 100))
    board.save(output_path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("gate_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    gate_root = assert_external(args.gate_root)
    output_root = assert_external(args.output_root)
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)

    gate_terrain = verify_gate(gate_root)
    current_manifest = load_json(CURRENT_MANIFEST)
    if sha256(CURRENT_TERRAIN) != current_manifest.get("output_sha256"):
        raise RuntimeError("Current Residential terrain identity mismatch.")
    route_contract = current_manifest.get("route_contract", {})
    roads = route_cells(route_contract)

    coordinates = gate_terrain.get("atlas_coordinates", {})
    source_atlas_path = gate_root / gate_terrain["atlas_path"]
    source_atlas = Image.open(source_atlas_path).convert("RGBA")
    current = Image.open(CURRENT_TERRAIN).convert("RGBA")
    grass_source_mean = material_mean(source_atlas, coordinates, GRASS_NAMES)
    stone_source_mean = material_mean(source_atlas, coordinates, STONE_NAMES)
    grass_target_mean = current_material_mean(current.convert("RGB"), roads, False)
    current_road_mean = current_material_mean(current.convert("RGB"), roads, True)
    stone_target_mean = tuple(current_road_mean[index] * 0.75 + stone_source_mean[index] * 0.25 for index in range(3))

    candidate_atlas = grade_atlas(
        source_atlas, coordinates, grass_source_mean, stone_source_mean, grass_target_mean, stone_target_mean
    )
    candidate_runtime, counts = compose_runtime(candidate_atlas, coordinates, roads)
    atlas_path = output_root / "candidate/residential_terrain_atlas_v1_2.png"
    runtime_path = output_root / "candidate/residential_terrain_candidate_v1_2.png"
    atlas_path.parent.mkdir(parents=True, exist_ok=True)
    candidate_atlas.save(atlas_path)
    candidate_runtime.save(runtime_path)

    boards_root = output_root / "boards"
    boards_root.mkdir(parents=True, exist_ok=True)
    repetition_path = boards_root / "residential_terrain_repetition_v1_2.png"
    material_path = boards_root / "residential_terrain_material_v1_2.png"
    make_repetition_board(candidate_atlas, coordinates, repetition_path)
    make_material_board(current, candidate_runtime, material_path)

    manifest = {
        "schema": "caden-residential-terrain-gate-v1.2-preparation",
        "gate_state": "inactive_residential_terrain_comparison_pending_visual_approval",
        "scope": "Residential terrain only; no active scene or texture reference change.",
        "generator": SCRIPT_PATH.relative_to(ROOT).as_posix(),
        "generator_sha256": sha256(SCRIPT_PATH),
        "source_gate": {
            "absolute_path": str(gate_root),
            "checksummed_artifacts_verified": 47,
            "catalog_rows_verified": 88,
            "atlas_path": gate_terrain["atlas_path"],
            "atlas_sha256": gate_terrain["atlas_sha256"],
            "original_master_filename": gate_terrain["source_filename"],
            "original_master_sha256": gate_terrain["source_sha256"],
        },
        "current_runtime": {
            "path": CURRENT_TERRAIN.relative_to(ROOT).as_posix(),
            "sha256": sha256(CURRENT_TERRAIN),
            "dimensions": list(current.size),
            "active_reference_status": "retained_unchanged",
        },
        "candidate": {
            "runtime_path": runtime_path.relative_to(output_root).as_posix(),
            "runtime_sha256": sha256(runtime_path),
            "runtime_dimensions": list(candidate_runtime.size),
            "atlas_path": atlas_path.relative_to(output_root).as_posix(),
            "atlas_sha256": sha256(atlas_path),
            "atlas_dimensions": list(candidate_atlas.size),
            "cell_size": [CELL_SIZE, CELL_SIZE],
            "grid_size": list(GRID_SIZE),
            "resampling": "none; exact Gate 0 source-derived 32x32 cells",
            "palette_harmonization": {
                "grass_source_mean_rgb": [round(value, 3) for value in grass_source_mean],
                "grass_target_mean_rgb": [round(value, 3) for value in grass_target_mean],
                "grass_contrast": 0.32,
                "stone_source_mean_rgb": [round(value, 3) for value in stone_source_mean],
                "stone_target_mean_rgb": [round(value, 3) for value in stone_target_mean],
                "stone_contrast": 0.58,
                "purpose": "reduce Gate 0 yellow cast, local contrast, and visual competition with approved architecture",
            },
            "variant_counts": {"grass": 9, "stone": 9, "transitions": 8},
            "composed_cell_counts": counts,
            "route_contract": route_contract,
            "collision": "none; authoritative scene collision remains separate and unchanged",
            "status": "inactive_candidate_pending_visual_approval",
        },
        "material_statistics": {
            "current": material_stats(current, roads),
            "candidate": material_stats(candidate_runtime, roads),
        },
        "boards": {
            repetition_path.relative_to(output_root).as_posix(): sha256(repetition_path),
            material_path.relative_to(output_root).as_posix(): sha256(material_path),
        },
        "protected_contracts": [
            "Residential.tscn remains byte-unchanged by this preparation tool",
            "current terrain texture and manifest remain active",
            "road mask, exits, entry markers, collision, buildings, props, landscaping, NPCs, and dialogue remain authoritative",
            "all non-Residential zones remain out of scope",
        ],
        "provenance_and_licensing": {
            "provided_by": "project owner via local Downloads intake",
            "creator_or_generation_tool": "not documented in supplied prompt or sidecars",
            "rights_status": "project_internal_rights_unverified",
            "distribution_status": "do_not_publish_or_ship_until rights are verified",
        },
    }
    manifest_path = output_root / "metadata/residential_terrain_preparation_manifest_v1_2.json"
    write_json(manifest_path, manifest)
    print(f"candidate={runtime_path}")
    print(f"manifest={manifest_path}")
    print(f"candidate_sha256={sha256(runtime_path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
