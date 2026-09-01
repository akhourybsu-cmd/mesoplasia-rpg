#!/usr/bin/env python3
"""Build Marketplace Terrain Runtime v1.3 from the approved v1.2 runtime.

The v1.3 footprint preserves every authoritative route cell while replacing the
oversized rectangular court with perimeter grass cut-ins. Tiles are sampled
without rotation, mirroring, scaling, or interpolation from the approved v1.2
runtime, so the material family and native 32-pixel grid stay unchanged.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
SOURCE_PATH = ROOT / "assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1_2.png"
SOURCE_MANIFEST_PATH = ROOT / "assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1_2.json"
OUTPUT_PATH = ROOT / "assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1_3.png"
MANIFEST_PATH = ROOT / "assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1_3.json"

CELL = 32
GRID = (28, 20)
SIZE = (896, 640)

GRASS_SAMPLES = (
    (0, 0), (1, 0), (2, 0), (25, 0), (26, 0), (27, 0),
    (0, 5), (27, 5), (0, 15),
)
STONE_SAMPLES = (
    (6, 5), (7, 5), (11, 5), (16, 5), (20, 5), (21, 5),
    (6, 14), (11, 14), (20, 14),
)
TRANSITION_SAMPLES = {
    "grass_north": (4, 2),
    "grass_south": (4, 17),
    "grass_west": (3, 3),
    "grass_east": (24, 3),
    "grass_northwest": (3, 2),
    "grass_northeast": (24, 2),
    "grass_southwest": (3, 17),
    "grass_southeast": (24, 17),
}


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
    return (value ^ (value >> 16)) % count


def rect_cells(x0: int, y0: int, x1: int, y1: int) -> set[tuple[int, int]]:
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def authoritative_route_cells() -> set[tuple[int, int]]:
    west = rect_cells(0, 8, 8, 11)
    cross = rect_cells(3, 9, 24, 10)
    spine = rect_cells(12, 2, 15, 19)
    return west | cross | spine


def grass_cut_ins() -> set[tuple[int, int]]:
    # Deliberately asymmetrical one- and two-cell cut-ins avoid both a perfect
    # rectangle and a repeated scalloped outline. None touch the west route,
    # cross route, or protected 128-pixel central spine.
    return {
        (3, 2), (4, 2), (3, 3),
        (9, 2), (10, 2),
        (18, 2),
        (23, 2), (24, 2),
        (3, 5), (3, 6),
        (24, 6),
        (3, 13),
        (24, 12), (24, 13),
        (3, 16), (3, 17), (4, 17), (5, 17),
        (9, 17), (10, 17),
        (18, 17),
        (24, 16), (23, 17), (24, 17),
    }


def maintained_cells() -> set[tuple[int, int]]:
    precinct = rect_cells(3, 2, 24, 17)
    return (precinct - grass_cut_ins()) | authoritative_route_cells()


def transition_name(x: int, y: int, stone: set[tuple[int, int]]) -> str | None:
    def grass(nx: int, ny: int) -> bool:
        return 0 <= nx < GRID[0] and 0 <= ny < GRID[1] and (nx, ny) not in stone

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


def sample(image: Image.Image, coordinate: tuple[int, int]) -> Image.Image:
    x, y = coordinate
    return image.crop((x * CELL, y * CELL, (x + 1) * CELL, (y + 1) * CELL))


def main() -> int:
    source_manifest = json.loads(SOURCE_MANIFEST_PATH.read_text(encoding="utf-8"))
    if source_manifest.get("gate_state") != "marketplace_terrain_runtime_v1_2_visual_approved":
        raise RuntimeError("Marketplace Terrain Runtime v1.2 is not the approved source.")
    if sha256(SOURCE_PATH) != source_manifest.get("output_sha256"):
        raise RuntimeError("Marketplace Terrain Runtime v1.2 identity changed.")
    with Image.open(SOURCE_PATH) as handle:
        source = handle.convert("RGBA")
    if source.size != SIZE:
        raise RuntimeError(f"Unexpected source dimensions: {source.size}")

    routes = authoritative_route_cells()
    cuts = grass_cut_ins()
    if routes & cuts:
        raise RuntimeError("A grass cut-in overlaps an authoritative route cell.")
    stone = maintained_cells()
    if not routes <= stone:
        raise RuntimeError("The authoritative route mask is not fully maintained.")

    output = Image.new("RGBA", SIZE, (0, 0, 0, 255))
    counts = {"grass": 0, "warm_stone": 0, "transition": 0}
    for y in range(GRID[1]):
        for x in range(GRID[0]):
            if (x, y) not in stone:
                coordinate = GRASS_SAMPLES[stable_index(x, y, len(GRASS_SAMPLES), 0xCA4D3301)]
                counts["grass"] += 1
            else:
                transition = transition_name(x, y, stone)
                if transition is None:
                    coordinate = STONE_SAMPLES[stable_index(x, y, len(STONE_SAMPLES), 0xCA4D3302)]
                    counts["warm_stone"] += 1
                else:
                    coordinate = TRANSITION_SAMPLES[transition]
                    counts["transition"] += 1
            output.alpha_composite(sample(source, coordinate), (x * CELL, y * CELL))

    pixels = list(output.get_flattened_data())
    if output.size != SIZE or any(pixel[3] != 255 for pixel in pixels):
        raise RuntimeError("Marketplace v1.3 pixel audit failed.")
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT_PATH, format="PNG", compress_level=9)
    manifest = {
        "schema": "caden-marketplace-terrain-runtime-v1.3",
        "gate_state": "blueprint_v3_active_runtime",
        "generator": SCRIPT_PATH.relative_to(ROOT).as_posix(),
        "generator_sha256": sha256(SCRIPT_PATH),
        "source_runtime": SOURCE_PATH.relative_to(ROOT).as_posix(),
        "source_runtime_sha256": sha256(SOURCE_PATH),
        "output_path": OUTPUT_PATH.relative_to(ROOT).as_posix(),
        "output_sha256": sha256(OUTPUT_PATH),
        "dimensions": list(SIZE),
        "cell_size": [CELL, CELL],
        "grid": list(GRID),
        "composed_cell_counts": counts,
        "maintained_cell_count": len(stone),
        "grass_cut_in_cell_count": len(cuts),
        "grass_cut_in_cells_xy": [list(cell) for cell in sorted(cuts, key=lambda cell: (cell[1], cell[0]))],
        "route_contract": source_manifest["route_contract"],
        "route_cells_preserved": len(routes),
        "method": "native 32x32 cells sampled from approved v1.2 without rotation, mirroring, scaling, or interpolation",
        "collision": "none; scene collision and transition nodes remain authoritative",
        "import_scale": 1.0,
        "filter": "nearest_neighbor_disabled_filtering",
        "pixel_audit": {
            "fully_opaque": True,
            "partial_alpha_pixels": 0,
            "transparent_rgb_pixels": 0,
        },
        "provenance_and_licensing": source_manifest["provenance_and_licensing"],
        "rollback": {
            "previous_runtime_path": SOURCE_PATH.relative_to(ROOT).as_posix(),
            "previous_runtime_sha256": sha256(SOURCE_PATH),
            "instruction": "Restore Marketplace TerrainRuntime to v1.2; do not change routes, stalls, transitions, or collision.",
        },
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"runtime={OUTPUT_PATH.relative_to(ROOT).as_posix()}")
    print(f"manifest={MANIFEST_PATH.relative_to(ROOT).as_posix()}")
    print(f"runtime_sha256={sha256(OUTPUT_PATH)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
