#!/usr/bin/env python3
"""Compose the Caden Marketplace terrain from the approved runtime v1.1 atlas."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ATLAS_PATH = ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png"
OUTPUT_ROOT = ROOT / "assets/environments/caden/marketplace/terrain"
OUTPUT_PATH = OUTPUT_ROOT / "marketplace_terrain_runtime_v1.png"
MANIFEST_PATH = OUTPUT_ROOT / "marketplace_terrain_runtime_v1.json"
ATLAS_SHA256 = "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a"
TILE = 32
GRID = (28, 20)
SIZE = (896, 640)

GRASS = ((0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0))
ROAD = ((0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1))
PLAZA = ((4, 4), (5, 4), (6, 4), (7, 4), (0, 5), (1, 5))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def stable_index(x: int, y: int, count: int, seed: int) -> int:
    value = (x * 0x45D9F3B + y * 0x119DE1F3 + seed) & 0xFFFFFFFF
    value ^= value >> 16
    value = (value * 0x45D9F3B) & 0xFFFFFFFF
    value ^= value >> 16
    return value % count


def tile(atlas: Image.Image, coordinate: tuple[int, int]) -> Image.Image:
    x, y = coordinate
    return atlas.crop((x * TILE, y * TILE, (x + 1) * TILE, (y + 1) * TILE))


def in_market_precinct(x: int, y: int) -> bool:
    return 3 <= x <= 24 and 2 <= y <= 17


def in_road(x: int, y: int) -> bool:
    west_lane = 0 <= x <= 8 and 8 <= y <= 11
    cross_lane = 3 <= x <= 24 and 9 <= y <= 10
    central_lane = 12 <= x <= 15 and 2 <= y <= 19
    return west_lane or cross_lane or central_lane


def plaza_edge_coordinate(x: int, y: int) -> tuple[int, int] | None:
    if (x, y) == (3, 2):
        return (2, 6)
    if (x, y) == (24, 2):
        return (3, 6)
    if (x, y) == (3, 17):
        return (4, 6)
    if (x, y) == (24, 17):
        return (5, 6)
    if y == 2:
        return (6, 5)
    if y == 17:
        return (7, 5)
    if x == 3:
        return (0, 6)
    if x == 24:
        return (1, 6)
    return None


def road_coordinate(x: int, y: int) -> tuple[int, int]:
    # Transition tiles keep the maintained court visually joined to the authoritative lanes.
    if y == 8 and 0 <= x <= 8:
        return (7, 1)
    if y == 11 and 0 <= x <= 8:
        return (0, 2)
    if x == 12 and 2 <= y <= 19:
        return (1, 2)
    if x == 15 and 2 <= y <= 19:
        return (2, 2)
    if 12 <= x <= 15 and 9 <= y <= 10:
        return (5, 3)
    return ROAD[stable_index(x, y, len(ROAD), 0xCA4D1201)]


def main() -> int:
    if sha256(ATLAS_PATH) != ATLAS_SHA256:
        raise RuntimeError("The protected Caden terrain v1.1 atlas hash changed.")
    with Image.open(ATLAS_PATH) as source:
        atlas = source.convert("RGBA")
    output = Image.new("RGBA", SIZE, (0, 0, 0, 255))
    tile_counts: dict[str, int] = {"grass": 0, "plaza": 0, "road": 0, "plaza_edge": 0}
    for y in range(GRID[1]):
        for x in range(GRID[0]):
            if in_road(x, y):
                coordinate = road_coordinate(x, y)
                family = "road"
            elif in_market_precinct(x, y):
                edge = plaza_edge_coordinate(x, y)
                if edge is not None:
                    coordinate = edge
                    family = "plaza_edge"
                else:
                    coordinate = PLAZA[stable_index(x, y, len(PLAZA), 0xCA4D1202)]
                    family = "plaza"
            else:
                coordinate = GRASS[stable_index(x, y, len(GRASS), 0xCA4D1203)]
                family = "grass"
            output.alpha_composite(tile(atlas, coordinate), (x * TILE, y * TILE))
            tile_counts[family] += 1

    if output.size != SIZE:
        raise RuntimeError(f"Unexpected terrain size: {output.size}")
    alpha_values = list(output.getchannel("A").get_flattened_data())
    if any(alpha != 255 for alpha in alpha_values):
        raise RuntimeError("Marketplace terrain must be fully opaque.")
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT_PATH, format="PNG", compress_level=9)
    manifest = {
        "schema": "caden-marketplace-terrain-runtime-v1",
        "generator": "tools/art/build_caden_marketplace_terrain_v1.py",
        "generator_sha256": sha256(Path(__file__)),
        "source_atlas": ATLAS_PATH.relative_to(ROOT).as_posix(),
        "source_atlas_sha256": ATLAS_SHA256,
        "output_path": OUTPUT_PATH.relative_to(ROOT).as_posix(),
        "output_sha256": sha256(OUTPUT_PATH),
        "dimensions": list(SIZE),
        "tile_size": [TILE, TILE],
        "grid": list(GRID),
        "tile_counts": tile_counts,
        "collision": "none; authoritative scene collision remains separate",
        "route_contract": {
            "west_lane_cells_xyxy": [0, 8, 8, 11],
            "cross_lane_cells_xyxy": [3, 9, 24, 10],
            "central_lane_cells_xyxy": [12, 2, 15, 19],
            "market_precinct_cells_xyxy": [3, 2, 24, 17],
        },
        "audit": {
            "fully_opaque": True,
            "canvas_edge_pixels_expected": True,
            "resampling": "none; exact 32x32 atlas cells",
            "runtime_scale": 1.0,
        },
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"terrain={OUTPUT_PATH.relative_to(ROOT).as_posix()}")
    print(f"manifest={MANIFEST_PATH.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
