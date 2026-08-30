#!/usr/bin/env python3
"""Prepare an external, inactive Marketplace terrain v1.2 comparison."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import statistics

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
SCENE_PATH = ROOT / "scenes/world/caden/Marketplace.tscn"
CURRENT_TERRAIN = ROOT / "assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1.png"
CURRENT_MANIFEST = ROOT / "assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1.json"
MARKETPLACE_MANIFEST = ROOT / "assets/environments/caden/marketplace/marketplace_runtime_manifest_v1.json"
RESIDENTIAL_TERRAIN_MANIFEST = ROOT / "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1_2.json"
CELL_SIZE = 32
GRID_SIZE = (28, 20)
OUTPUT_SIZE = (896, 640)

GRASS_NAMES = ["grass_base"] + [f"grass_variant_{index:02d}" for index in range(2, 10)]
STONE_NAMES = ["stone_base"] + [f"stone_variant_{index:02d}" for index in range(2, 10)]
TRANSITION_NAMES = (
    "grass_north", "grass_south", "grass_west", "grass_east",
    "grass_northwest", "grass_northeast", "grass_southwest", "grass_southeast",
)


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


def assert_external(path: Path, label: str) -> Path:
    resolved = path.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError(f"{label} must remain outside res://.")
    return resolved


def verify_checksums(root: Path, expected_count: int, label: str) -> None:
    lines = [line for line in (root / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != expected_count:
        raise RuntimeError(f"{label} checksum count changed: {len(lines)}.")
    for line in lines:
        digest, relative = line.split("  ", 1)
        path = root / Path(relative)
        if not path.is_file() or sha256(path) != digest:
            raise RuntimeError(f"{label} checksum mismatch: {relative}")


def tile(atlas: Image.Image, coordinate: list[int]) -> Image.Image:
    x, y = coordinate
    return atlas.crop((x * CELL_SIZE, y * CELL_SIZE, (x + 1) * CELL_SIZE, (y + 1) * CELL_SIZE))


def stable_index(x: int, y: int, count: int, seed: int) -> int:
    value = (x * 0x45D9F3B + y * 0x119DE1F3 + seed) & 0xFFFFFFFF
    value ^= value >> 16
    value = (value * 0x45D9F3B) & 0xFFFFFFFF
    return (value ^ (value >> 16)) % count


def in_market_precinct(x: int, y: int) -> bool:
    return 3 <= x <= 24 and 2 <= y <= 17


def in_authoritative_lane(x: int, y: int) -> bool:
    west_lane = 0 <= x <= 8 and 8 <= y <= 11
    cross_lane = 3 <= x <= 24 and 9 <= y <= 10
    central_lane = 12 <= x <= 15 and 2 <= y <= 19
    return west_lane or cross_lane or central_lane


def maintained_cells() -> set[tuple[int, int]]:
    return {
        (x, y)
        for y in range(GRID_SIZE[1])
        for x in range(GRID_SIZE[0])
        if in_market_precinct(x, y) or in_authoritative_lane(x, y)
    }


def transition_name(x: int, y: int, stone: set[tuple[int, int]]) -> str | None:
    def grass(nx: int, ny: int) -> bool:
        return 0 <= nx < GRID_SIZE[0] and 0 <= ny < GRID_SIZE[1] and (nx, ny) not in stone

    north = grass(x, y - 1)
    south = grass(x, y + 1)
    west = grass(x - 1, y)
    east = grass(x + 1, y)
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


def compose(atlas: Image.Image, coordinates: dict[str, list[int]]) -> tuple[Image.Image, dict[str, int]]:
    stone = maintained_cells()
    output = Image.new("RGBA", OUTPUT_SIZE, (0, 0, 0, 255))
    counts = {"grass": 0, "warm_stone": 0, "transition": 0}
    for y in range(GRID_SIZE[1]):
        for x in range(GRID_SIZE[0]):
            if (x, y) not in stone:
                name = GRASS_NAMES[stable_index(x, y, len(GRASS_NAMES), 0xCA4D2201)]
                counts["grass"] += 1
            else:
                name = transition_name(x, y, stone)
                if name is None:
                    name = STONE_NAMES[stable_index(x, y, len(STONE_NAMES), 0xCA4D2202)]
                    counts["warm_stone"] += 1
                else:
                    counts["transition"] += 1
            output.alpha_composite(tile(atlas, coordinates[name]), (x * CELL_SIZE, y * CELL_SIZE))
    return output, counts


def material_stats(image: Image.Image, stone: set[tuple[int, int]]) -> dict[str, dict[str, list[float]]]:
    result: dict[str, dict[str, list[float]]] = {}
    for label, use_stone in (("grass", False), ("maintained_ground", True)):
        channels: list[list[int]] = [[], [], []]
        for y in range(GRID_SIZE[1]):
            for x in range(GRID_SIZE[0]):
                if (((x, y) in stone) != use_stone):
                    continue
                crop = image.crop((x * CELL_SIZE, y * CELL_SIZE, (x + 1) * CELL_SIZE, (y + 1) * CELL_SIZE)).convert("RGB")
                for pixel in crop.get_flattened_data():
                    for channel in range(3):
                        channels[channel].append(pixel[channel])
        result[label] = {
            "mean_rgb": [round(statistics.fmean(channel), 3) for channel in channels],
            "population_stddev_rgb": [round(statistics.pstdev(channel), 3) for channel in channels],
        }
    return result


def make_material_board(current: Image.Image, candidate: Image.Image, output_path: Path) -> None:
    board = Image.new("RGB", (1280, 720), (239, 237, 229))
    draw = ImageDraw.Draw(board)
    draw.text((32, 24), "CADEN MARKETPLACE TERRAIN GATE v1.2", font=font(30, True), fill=(40, 46, 41))
    draw.text((32, 66), "Inactive material comparison. Live stalls, perimeter, routes, NPCs, and collision remain authoritative.", font=font(17), fill=(74, 79, 72))
    draw.text((32, 108), "CURRENT RUNTIME v1", font=font(18, True), fill=(70, 73, 67))
    draw.text((656, 108), "CANDIDATE v1.2", font=font(18, True), fill=(70, 73, 67))
    for x, image in ((32, current), (656, candidate)):
        preview = image.convert("RGB").resize((592, 423), Image.Resampling.NEAREST)
        board.paste(preview, (x, 140))
    crop_box = (288, 224, 608, 416)
    draw.text((32, 586), "Central vendor ground", font=font(16, True), fill=(70, 73, 67))
    draw.text((656, 586), "Central vendor ground", font=font(16, True), fill=(70, 73, 67))
    board.paste(current.crop(crop_box).convert("RGB").resize((288, 96), Image.Resampling.NEAREST), (32, 612))
    board.paste(candidate.crop(crop_box).convert("RGB").resize((288, 96), Image.Resampling.NEAREST), (656, 612))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(output_path)


def make_repetition_board(atlas: Image.Image, coordinates: dict[str, list[int]], output_path: Path) -> None:
    board = Image.new("RGB", (960, 416), (239, 237, 229))
    draw = ImageDraw.Draw(board)
    draw.text((24, 22), "Marketplace v1.2 Material Repetition Audit", font=font(26, True), fill=(40, 46, 41))
    for column, (title, names) in enumerate((("calm grass", GRASS_NAMES), ("warm stone", STONE_NAMES))):
        x0 = 24 + column * 468
        draw.text((x0, 66), title.upper(), font=font(17, True), fill=(70, 73, 67))
        mosaic = Image.new("RGBA", (9 * CELL_SIZE, 9 * CELL_SIZE), (0, 0, 0, 255))
        for y in range(9):
            for x in range(9):
                name = names[stable_index(x, y, len(names), 0xCA4D2300 + column)]
                mosaic.alpha_composite(tile(atlas, coordinates[name]), (x * CELL_SIZE, y * CELL_SIZE))
        board.paste(mosaic.convert("RGB"), (x0, 100))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(output_path)


def storefront_decisions(gate_root: Path) -> list[dict[str, object]]:
    catalog = load_json(gate_root / "metadata/source_catalog_v1_1.json")
    rows = catalog.get("rows", [])
    selected = [row for row in rows if row.get("visual_role") == "storefront"]
    if len(selected) != 12:
        raise RuntimeError(f"Expected twelve storefront source rows, found {len(selected)}.")
    decisions = []
    for row in selected:
        if row.get("status") != "deferred_marketplace_stall_footprint_mismatch":
            raise RuntimeError(f"Storefront disposition changed: {row.get('source_id')}")
        decisions.append({
            "source_id": row["source_id"],
            "source_filename": row["source_filename"],
            "visual_role": row["visual_role"],
            "status": "deferred_marketplace_stall_footprint_mismatch",
            "rationale": "A complete storefront would exceed the established shallow vendor-bay role or compete with the protected central circulation spine; retain the approved market set piece.",
        })
    return decisions


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("gate_zero_root", type=Path)
    parser.add_argument("approved_terrain_review_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    gate_root = assert_external(args.gate_zero_root, "Gate 0 root")
    review_root = assert_external(args.approved_terrain_review_root, "Approved terrain review root")
    output_root = assert_external(args.output_root, "Output root")
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)

    verify_checksums(gate_root, 47, "Gate 0")
    verify_checksums(review_root, 29, "Approved terrain review")
    residential_manifest = load_json(RESIDENTIAL_TERRAIN_MANIFEST)
    if residential_manifest.get("gate_state") != "residential_terrain_runtime_v1_2_visual_approved":
        raise RuntimeError("Residential terrain v1.2 is not the approved baseline.")
    marketplace_manifest = load_json(MARKETPLACE_MANIFEST)
    if marketplace_manifest.get("gate_state") != "marketplace_runtime_v1_visual_approved":
        raise RuntimeError("Marketplace Runtime v1 is not the approved baseline.")
    current_manifest = load_json(CURRENT_MANIFEST)
    if sha256(CURRENT_TERRAIN) != current_manifest.get("output_sha256"):
        raise RuntimeError("Marketplace terrain v1 identity mismatch.")
    scene_text = SCENE_PATH.read_text(encoding="utf-8")
    active_reference = "res://assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1.png"
    if scene_text.count(active_reference) != 1 or "marketplace_terrain_runtime_v1_2" in scene_text:
        raise RuntimeError("Marketplace active terrain reference changed before the comparison gate.")

    gate_manifest = load_json(gate_root / "metadata/preparation_manifest_v1_1.json")
    coordinates = gate_manifest["terrain"]["atlas_coordinates"]
    review_manifest = load_json(review_root / "metadata/residential_terrain_preparation_manifest_v1_2.json")
    atlas_path = review_root / review_manifest["candidate"]["atlas_path"]
    if sha256(atlas_path) != review_manifest["candidate"]["atlas_sha256"]:
        raise RuntimeError("Approved harmonized terrain atlas identity mismatch.")
    with Image.open(atlas_path) as source:
        atlas = source.convert("RGBA")
    with Image.open(CURRENT_TERRAIN) as source:
        current = source.convert("RGBA")
    candidate, counts = compose(atlas, coordinates)
    if candidate.size != OUTPUT_SIZE or set(candidate.getchannel("A").get_flattened_data()) != {255}:
        raise RuntimeError("Marketplace candidate pixel audit failed.")

    candidate_root = output_root / "candidate"
    candidate_root.mkdir(parents=True, exist_ok=True)
    candidate_path = candidate_root / "marketplace_terrain_candidate_v1_2.png"
    candidate.save(candidate_path, format="PNG", compress_level=9)
    material_board = output_root / "boards/marketplace_terrain_material_comparison_v1_2.png"
    repetition_board = output_root / "boards/marketplace_terrain_repetition_v1_2.png"
    make_material_board(current, candidate, material_board)
    make_repetition_board(atlas, coordinates, repetition_board)

    stone = maintained_cells()
    expected_material_cells = sum(current_manifest["tile_counts"].get(key, 0) for key in ("plaza", "road", "plaza_edge"))
    if len(stone) != expected_material_cells or counts["grass"] != current_manifest["tile_counts"]["grass"]:
        raise RuntimeError("Candidate material footprint does not match Marketplace v1.")
    manifest = {
        "schema": "caden-marketplace-terrain-gate-v1.2-preparation",
        "gate_state": "inactive_marketplace_terrain_comparison_pending_visual_approval",
        "scope": "Marketplace terrain and source-fit comparison only; no active scene or resource reference changed.",
        "generator": SCRIPT_PATH.relative_to(ROOT).as_posix(),
        "generator_sha256": sha256(SCRIPT_PATH),
        "scene": SCENE_PATH.relative_to(ROOT).as_posix(),
        "scene_sha256": sha256(SCENE_PATH),
        "current_runtime": {
            "path": CURRENT_TERRAIN.relative_to(ROOT).as_posix(),
            "sha256": sha256(CURRENT_TERRAIN),
            "dimensions": list(current.size),
            "gate_state": marketplace_manifest["gate_state"],
            "active_reference_status": "retained_unchanged",
        },
        "candidate": {
            "runtime_path": candidate_path.relative_to(output_root).as_posix(),
            "runtime_sha256": sha256(candidate_path),
            "runtime_dimensions": list(candidate.size),
            "source_atlas_sha256": sha256(atlas_path),
            "cell_size": [CELL_SIZE, CELL_SIZE],
            "grid_size": list(GRID_SIZE),
            "variant_counts": {"grass": len(GRASS_NAMES), "warm_stone": len(STONE_NAMES), "transitions": len(TRANSITION_NAMES)},
            "composed_cell_counts": counts,
            "maintained_material_footprint_cells": len(stone),
            "route_contract": current_manifest["route_contract"],
            "collision": "none; authoritative Marketplace collision remains separate and unchanged",
            "status": "inactive_candidate_pending_visual_approval",
        },
        "material_statistics": {
            "current": material_stats(current, stone),
            "candidate": material_stats(candidate, stone),
        },
        "storefront_source_fit": {
            "decision": "retain_all_eight_approved_runtime_v1_vendor_anchors",
            "source_sheet_storefront_rows": storefront_decisions(gate_root),
        },
        "boards": {
            material_board.relative_to(output_root).as_posix(): sha256(material_board),
            repetition_board.relative_to(output_root).as_posix(): sha256(repetition_board),
        },
        "protected_contracts": [
            "eight approved vendor anchors and their object-specific collision",
            "minimum 128-pixel central circulation spine and authoritative west/cross/central lanes",
            "fenced planted perimeter, trees, props, seven NPCs, dialogue, entries, exits, and bounds",
            "Marketplace.tscn and all active resource references",
            "all non-Marketplace zones",
        ],
        "provenance_and_licensing": review_manifest["provenance_and_licensing"],
    }
    metadata_root = output_root / "metadata"
    write_json(metadata_root / "marketplace_terrain_preparation_manifest_v1_2.json", manifest)
    print(f"candidate={candidate_path}")
    print(f"candidate_sha256={sha256(candidate_path)}")
    print(f"manifest={metadata_root / 'marketplace_terrain_preparation_manifest_v1_2.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
