#!/usr/bin/env python3
"""Compose Commons terrain from exact approved Caden runtime v1.1 cells."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ATLAS_PATH = ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png"
OUTPUT_ROOT = ROOT / "assets/environments/caden/commons/terrain"
OUTPUT_PATH = OUTPUT_ROOT / "commons_terrain_runtime_v1.png"
MANIFEST_PATH = OUTPUT_ROOT / "commons_terrain_runtime_v1.json"
ATLAS_SHA256 = "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a"
TILE = 32
GRID = (32, 22)
SIZE = (1024, 704)
GRASS = ((0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0))
ROAD = ((0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1))


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


def in_road(x: int, y: int) -> bool:
    west_route = 0 <= x <= 15 and 9 <= y <= 12
    north_route = 14 <= x <= 17 and 0 <= y <= 12
    return west_route or north_route


def road_coordinate(x: int, y: int) -> tuple[int, int]:
    if not in_road(x, y - 1):
        return (7, 1)
    if not in_road(x, y + 1):
        return (0, 2)
    if not in_road(x - 1, y):
        return (1, 2)
    if not in_road(x + 1, y):
        return (2, 2)
    if 14 <= x <= 15 and 9 <= y <= 12:
        return (5, 3)
    return ROAD[stable_index(x, y, len(ROAD), 0xCA4D3301)]


def main() -> int:
    if sha256(ATLAS_PATH) != ATLAS_SHA256:
        raise RuntimeError("The protected Caden terrain v1.1 atlas hash changed.")
    with Image.open(ATLAS_PATH) as source:
        atlas = source.convert("RGBA")
    output = Image.new("RGBA", SIZE, (0, 0, 0, 255))
    counts = {"grass": 0, "road": 0}
    for y in range(GRID[1]):
        for x in range(GRID[0]):
            family = "road" if in_road(x, y) else "grass"
            coordinate = road_coordinate(x, y) if family == "road" else GRASS[stable_index(x, y, len(GRASS), 0xCA4D3302)]
            output.alpha_composite(tile(atlas, coordinate), (x * TILE, y * TILE))
            counts[family] += 1
    if output.size != SIZE or any(alpha != 255 for alpha in output.getchannel("A").get_flattened_data()):
        raise RuntimeError("Commons terrain dimensions or opacity are invalid.")
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT_PATH, format="PNG", compress_level=9)
    manifest = {
        "schema": "caden-commons-terrain-runtime-v1",
        "generator": "tools/art/build_caden_commons_terrain_v1.py",
        "generator_sha256": sha256(Path(__file__)),
        "source_atlas": ATLAS_PATH.relative_to(ROOT).as_posix(),
        "source_atlas_sha256": ATLAS_SHA256,
        "output_path": OUTPUT_PATH.relative_to(ROOT).as_posix(),
        "output_sha256": sha256(OUTPUT_PATH),
        "dimensions": list(SIZE),
        "tile_size": [TILE, TILE],
        "grid": list(GRID),
        "tile_counts": counts,
        "route_contract": {"town_square_cells_xyxy": [0, 9, 15, 12], "residential_cells_xyxy": [14, 0, 17, 12]},
        "quiet_green_pixels_xywh": [608, 128, 320, 448],
        "collision": "none; scene collision remains separate",
        "audit": {"fully_opaque": True, "resampling": "none; exact 32x32 atlas cells", "runtime_scale": 1.0},
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"terrain={OUTPUT_PATH.relative_to(ROOT).as_posix()}")
    print(f"manifest={MANIFEST_PATH.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
