#!/usr/bin/env python3
"""Prepare the Caden Terrain Runtime v1 atlas from the immutable source master.

The script uses only exact source crops, integer-factor nearest-neighbor reduction,
and hard pixel compositing. It never writes to the source-art directory.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image, ImageDraw


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = REPOSITORY_ROOT / "assets/source_art/caden/terrain/caden_terrain_master_v1.png"
ATLAS_PATH = REPOSITORY_ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1.png"
PREVIEW_DIRECTORY = REPOSITORY_ROOT / "docs/art/previews"
VALIDATION_PREVIEW_PATH = PREVIEW_DIRECTORY / "caden_terrain_runtime_v1_validation.png"
TOWN_SQUARE_PREVIEW_PATH = PREVIEW_DIRECTORY / "caden_terrain_runtime_v1_town_square_preview.png"

EXPECTED_SOURCE_SHA256 = "36308c3fe4eb1bda2cca61c7778583440c07b8b859c2f597185f180ebdcb3b4c"
SOURCE_CELL_SIZE = 96
TILE_SIZE = 32
ATLAS_COLUMNS = 8
ATLAS_ROWS = 6

# The generated source sheet has a stable 13-column visual grid and several
# usable rows. Each selected region below is exactly 96x96 before 3:1 reduction.
SOURCE_COLUMN_X = [13, 119, 225, 332, 438, 544, 652, 758, 866, 973, 1079, 1186, 1293]
SOURCE_ROW_Y = [11, 122, 228, 338, 451, 562, 671, 784, 910]


TileCoordinate = tuple[int, int]


TILE_COORDINATES: dict[str, TileCoordinate] = {
    "grass_base": (0, 0),
    "grass_variant_01": (1, 0),
    "grass_variant_02": (2, 0),
    "grass_variant_03": (3, 0),
    "grass_variant_04": (4, 0),
    "grass_worn_01": (5, 0),
    "grass_worn_02": (6, 0),
    "road_fill": (0, 1),
    "road_fill_variant_01": (1, 1),
    "road_edge_north": (2, 1),
    "road_edge_south": (3, 1),
    "road_edge_west": (4, 1),
    "road_edge_east": (5, 1),
    "road_straight_horizontal": (6, 1),
    "road_straight_vertical": (7, 1),
    "road_outer_corner_nw": (0, 2),
    "road_outer_corner_ne": (1, 2),
    "road_outer_corner_sw": (2, 2),
    "road_outer_corner_se": (3, 2),
    "road_inner_corner_nw": (4, 2),
    "road_inner_corner_ne": (5, 2),
    "road_inner_corner_sw": (6, 2),
    "road_inner_corner_se": (7, 2),
    "road_cross": (0, 3),
    "road_junction_n_e_w": (1, 3),
    "road_junction_n_s_w": (2, 3),
    "road_straight_horizontal_worn": (3, 3),
    "road_to_plaza_north": (4, 3),
    "road_to_plaza_south": (5, 3),
    "road_to_plaza_west": (6, 3),
    "road_to_plaza_east": (7, 3),
    "plaza_fill": (0, 4),
    "plaza_variant_01": (1, 4),
    "plaza_variant_02": (2, 4),
    "plaza_variant_03": (3, 4),
    "plaza_edge_north": (4, 4),
    "plaza_edge_south": (5, 4),
    "plaza_edge_west": (6, 4),
    "plaza_edge_east": (7, 4),
    "plaza_outer_corner_nw": (0, 5),
    "plaza_outer_corner_ne": (1, 5),
    "plaza_outer_corner_sw": (2, 5),
    "plaza_outer_corner_se": (3, 5),
    "plaza_clipped_corner_nw": (4, 5),
    "plaza_clipped_corner_ne": (5, 5),
    "plaza_clipped_corner_sw": (6, 5),
    "plaza_clipped_corner_se": (7, 5),
}


def _source_hash() -> str:
    return hashlib.sha256(SOURCE_PATH.read_bytes()).hexdigest()


def _opaque(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    result.putalpha(255)
    return result


def _source_cell(source: Image.Image, column: int, row: int) -> Image.Image:
    x = SOURCE_COLUMN_X[column]
    y = SOURCE_ROW_Y[row]
    crop = source.crop((x, y, x + SOURCE_CELL_SIZE, y + SOURCE_CELL_SIZE))
    return _opaque(crop.resize((TILE_SIZE, TILE_SIZE), Image.Resampling.NEAREST))


def _normalize_fill_edges(image: Image.Image) -> Image.Image:
    """Make opposite fill borders identical using direct pixel copies."""
    result = image.copy()
    for y in range(result.height):
        result.putpixel((result.width - 1, y), result.getpixel((0, y)))
    for x in range(result.width):
        result.putpixel((x, result.height - 1), result.getpixel((x, 0)))
    return result


def _repeat_center_patch(image: Image.Image, inset: int = 8) -> Image.Image:
    patch = _normalize_fill_edges(image.crop((inset, inset, TILE_SIZE - inset, TILE_SIZE - inset)))
    result = Image.new("RGBA", (TILE_SIZE, TILE_SIZE))
    for y in range(0, TILE_SIZE, patch.height):
        for x in range(0, TILE_SIZE, patch.width):
            result.paste(patch, (x, y))
    return _normalize_fill_edges(_opaque(result))


def _center_variant(base: Image.Image, candidate: Image.Image, inset: int = 10) -> Image.Image:
    """Preserve the shared seamless border while introducing a small source variation."""
    result = base.copy()
    result.paste(
        candidate.crop((inset, inset, TILE_SIZE - inset, TILE_SIZE - inset)),
        (inset, inset),
    )
    return _opaque(result)


def _road_edges(horizontal: Image.Image, vertical: Image.Image, road_fill: Image.Image) -> dict[str, Image.Image]:
    north = horizontal.copy()
    north.paste(road_fill.crop((0, 18, 32, 32)), (0, 18))

    south = road_fill.copy()
    south.paste(horizontal.crop((0, 14, 32, 32)), (0, 14))

    west = vertical.copy()
    west.paste(road_fill.crop((18, 0, 32, 32)), (18, 0))

    east = road_fill.copy()
    east.paste(vertical.crop((14, 0, 32, 32)), (14, 0))

    return {
        "road_edge_north": _opaque(north),
        "road_edge_south": _opaque(south),
        "road_edge_west": _opaque(west),
        "road_edge_east": _opaque(east),
    }


def _corner_cut(
    foreground: Image.Image,
    background: Image.Image,
    corner: str,
    *,
    size: int = 12,
) -> Image.Image:
    """Cut a square corner from foreground using source-backed background pixels."""
    result = foreground.copy()
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            in_corner = {
                "nw": x < size and y < size,
                "ne": x >= TILE_SIZE - size and y < size,
                "sw": x < size and y >= TILE_SIZE - size,
                "se": x >= TILE_SIZE - size and y >= TILE_SIZE - size,
            }[corner]
            if in_corner:
                result.putpixel((x, y), background.getpixel((x, y)))
    return _opaque(result)


def _material_edge(
    material: Image.Image,
    grass: Image.Image,
    direction: str,
    *,
    outside_width: int = 5,
) -> Image.Image:
    result = material.copy()
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            outside = {
                "north": y < outside_width,
                "south": y >= TILE_SIZE - outside_width,
                "west": x < outside_width,
                "east": x >= TILE_SIZE - outside_width,
            }[direction]
            if outside:
                result.putpixel((x, y), grass.getpixel((x, y)))
    return _opaque(result)


def _material_transition(
    road: Image.Image,
    plaza: Image.Image,
    road_side: str,
) -> Image.Image:
    result = plaza.copy()
    if road_side == "north":
        result.paste(road.crop((0, 0, 32, 16)), (0, 0))
    elif road_side == "south":
        result.paste(road.crop((0, 16, 32, 32)), (0, 16))
    elif road_side == "west":
        result.paste(road.crop((0, 0, 16, 32)), (0, 0))
    elif road_side == "east":
        result.paste(road.crop((16, 0, 32, 32)), (16, 0))
    else:
        raise ValueError(f"Unsupported road side: {road_side}")
    return _opaque(result)


def _clipped_plaza_corner(
    plaza: Image.Image,
    grass: Image.Image,
    corner: str,
) -> Image.Image:
    result = plaza.copy()
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            use_plaza = {
                "nw": x + y >= TILE_SIZE - 1,
                "ne": y >= x,
                "sw": x >= y,
                "se": x + y <= TILE_SIZE - 1,
            }[corner]
            if not use_plaza:
                result.putpixel((x, y), grass.getpixel((x, y)))
    return _opaque(result)


def _build_tiles(source: Image.Image) -> dict[str, Image.Image]:
    grass = _repeat_center_patch(_source_cell(source, 0, 0))
    road_horizontal = _source_cell(source, 0, 2)
    road_vertical = _source_cell(source, 1, 2)
    road_cross = _source_cell(source, 9, 2)
    road_fill = _repeat_center_patch(road_cross)
    road_fill_variant = _center_variant(road_fill, _repeat_center_patch(_source_cell(source, 3, 2)), 8)
    plaza_fill = _repeat_center_patch(_source_cell(source, 0, 3))

    tiles: dict[str, Image.Image] = {
        "grass_base": grass,
        "grass_variant_01": _center_variant(grass, _source_cell(source, 1, 0)),
        "grass_variant_02": _center_variant(grass, _source_cell(source, 3, 0)),
        "grass_variant_03": _center_variant(grass, _source_cell(source, 5, 0)),
        "grass_variant_04": _center_variant(grass, _source_cell(source, 10, 1)),
        "grass_worn_01": _center_variant(grass, _source_cell(source, 11, 1), 8),
        "grass_worn_02": _center_variant(grass, _source_cell(source, 12, 1), 8),
        "road_fill": road_fill,
        "road_fill_variant_01": road_fill_variant,
        "road_straight_horizontal": road_horizontal,
        "road_straight_vertical": road_vertical,
        "road_outer_corner_nw": _source_cell(source, 6, 2),
        "road_outer_corner_ne": _source_cell(source, 10, 2),
        "road_outer_corner_sw": _source_cell(source, 8, 2),
        "road_outer_corner_se": _source_cell(source, 7, 2),
        "road_inner_corner_nw": _corner_cut(road_fill, grass, "nw"),
        "road_inner_corner_ne": _corner_cut(road_fill, grass, "ne"),
        "road_inner_corner_sw": _corner_cut(road_fill, grass, "sw"),
        "road_inner_corner_se": _corner_cut(road_fill, grass, "se"),
        "road_cross": road_cross,
        "road_junction_n_e_w": _source_cell(source, 3, 2),
        "road_junction_n_s_w": _source_cell(source, 5, 2),
        "road_straight_horizontal_worn": _source_cell(source, 2, 2),
        "plaza_fill": plaza_fill,
        "plaza_variant_01": _center_variant(plaza_fill, _source_cell(source, 1, 3), 7),
        "plaza_variant_02": _center_variant(plaza_fill, _source_cell(source, 2, 3), 7),
        "plaza_variant_03": _center_variant(plaza_fill, _source_cell(source, 3, 3), 7),
    }
    tiles.update(_road_edges(road_horizontal, road_vertical, road_fill))

    for direction in ("north", "south", "west", "east"):
        tiles[f"road_to_plaza_{direction}"] = _material_transition(road_fill, plaza_fill, direction)
        tiles[f"plaza_edge_{direction}"] = _material_edge(plaza_fill, grass, direction)

    for corner in ("nw", "ne", "sw", "se"):
        tiles[f"plaza_outer_corner_{corner}"] = _corner_cut(plaza_fill, grass, corner)
        tiles[f"plaza_clipped_corner_{corner}"] = _clipped_plaza_corner(plaza_fill, grass, corner)

    missing = set(TILE_COORDINATES) - set(tiles)
    if missing:
        raise RuntimeError(f"Missing generated tiles: {sorted(missing)}")
    return tiles


def _write_atlas(tiles: dict[str, Image.Image]) -> Image.Image:
    atlas = Image.new("RGBA", (ATLAS_COLUMNS * TILE_SIZE, ATLAS_ROWS * TILE_SIZE), (0, 0, 0, 0))
    for tile_name, coordinate in TILE_COORDINATES.items():
        atlas.paste(tiles[tile_name], (coordinate[0] * TILE_SIZE, coordinate[1] * TILE_SIZE))
    ATLAS_PATH.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(ATLAS_PATH, optimize=False)
    return atlas


def _draw_tile_grid(
    canvas: Image.Image,
    tiles: dict[str, Image.Image],
    tile_names: list[list[str]],
    origin: tuple[int, int],
) -> None:
    origin_x, origin_y = origin
    for row_index, row in enumerate(tile_names):
        for column_index, tile_name in enumerate(row):
            canvas.paste(
                tiles[tile_name],
                (origin_x + column_index * TILE_SIZE, origin_y + row_index * TILE_SIZE),
            )


def _write_validation_preview(tiles: dict[str, Image.Image]) -> None:
    scale = 2
    preview = Image.new("RGB", (640, 512), (36, 32, 28))
    draw = ImageDraw.Draw(preview)

    draw.text((12, 8), "Grass 3x3 repetition", fill=(245, 235, 210))
    _draw_tile_grid(preview, tiles, [["grass_base"] * 3 for _ in range(3)], (12, 24))

    draw.text((132, 8), "Alternating restrained grass", fill=(245, 235, 210))
    grass_names = ["grass_base", "grass_variant_01", "grass_variant_02", "grass_variant_04"]
    _draw_tile_grid(
        preview,
        tiles,
        [[grass_names[(x + y * 3) % len(grass_names)] for x in range(5)] for y in range(3)],
        (132, 24),
    )

    draw.text((324, 8), "Horizontal road", fill=(245, 235, 210))
    horizontal_road = (
        [["grass_base"] * 8]
        + [["road_edge_north"] * 8]
        + [["road_fill" if x % 3 else "road_fill_variant_01" for x in range(8)] for _ in range(2)]
        + [["road_edge_south"] * 8]
        + [["grass_base"] * 8]
    )
    _draw_tile_grid(preview, tiles, horizontal_road, (324, 24))

    draw.text((12, 144), "Vertical road", fill=(245, 235, 210))
    vertical_road: list[list[str]] = []
    for y in range(7):
        vertical_road.append(
            [
                "grass_base",
                "road_edge_west",
                "road_fill_variant_01" if y % 3 == 1 else "road_fill",
                "road_fill",
                "road_edge_east",
                "grass_base",
            ]
        )
    _draw_tile_grid(preview, tiles, vertical_road, (12, 160))

    draw.text((228, 224), "Road corners and junctions", fill=(245, 235, 210))
    _draw_tile_grid(
        preview,
        tiles,
        [
            ["road_outer_corner_nw", "road_outer_corner_ne", "road_cross", "road_junction_n_e_w"],
            ["road_outer_corner_sw", "road_outer_corner_se", "road_junction_n_s_w", "road_straight_horizontal_worn"],
            ["road_inner_corner_nw", "road_inner_corner_ne", "road_inner_corner_sw", "road_inner_corner_se"],
        ],
        (228, 240),
    )

    draw.text((388, 224), "Plaza block and perimeter", fill=(245, 235, 210))
    plaza_block = [
        ["plaza_outer_corner_nw"] + ["plaza_edge_north"] * 4 + ["plaza_outer_corner_ne"],
        ["plaza_edge_west"] + ["plaza_fill", "plaza_variant_01", "plaza_fill", "plaza_variant_02"] + ["plaza_edge_east"],
        ["plaza_edge_west"] + ["plaza_variant_03", "plaza_fill", "plaza_variant_02", "plaza_fill"] + ["plaza_edge_east"],
        ["plaza_outer_corner_sw"] + ["plaza_edge_south"] * 4 + ["plaza_outer_corner_se"],
    ]
    _draw_tile_grid(preview, tiles, plaza_block, (388, 240))

    draw.text((12, 396), "Clipped plaza corners", fill=(245, 235, 210))
    _draw_tile_grid(
        preview,
        tiles,
        [
            ["plaza_clipped_corner_nw", "plaza_edge_north", "plaza_edge_north", "plaza_clipped_corner_ne"],
            ["plaza_edge_west", "plaza_fill", "plaza_variant_01", "plaza_edge_east"],
            ["plaza_edge_west", "plaza_variant_02", "plaza_fill", "plaza_edge_east"],
            ["plaza_clipped_corner_sw", "plaza_edge_south", "plaza_edge_south", "plaza_clipped_corner_se"],
        ],
        (12, 412),
    )

    draw.text((180, 396), "Road-to-plaza transitions", fill=(245, 235, 210))
    _draw_tile_grid(
        preview,
        tiles,
        [
            ["road_to_plaza_north", "road_to_plaza_south"],
            ["road_to_plaza_west", "road_to_plaza_east"],
        ],
        (180, 412),
    )

    PREVIEW_DIRECTORY.mkdir(parents=True, exist_ok=True)
    preview.resize((preview.width * scale, preview.height * scale), Image.Resampling.NEAREST).save(
        VALIDATION_PREVIEW_PATH,
        optimize=False,
    )


def _town_square_tile_layers() -> tuple[list[list[str]], dict[tuple[int, int], str], dict[tuple[int, int], str], dict[tuple[int, int], str]]:
    base: list[list[str]] = []
    grass_names = ["grass_base", "grass_variant_01", "grass_variant_02", "grass_variant_04"]
    for y in range(22):
        row: list[str] = []
        for x in range(30):
            selector = (x * 17 + y * 31) % 23
            row.append(grass_names[selector % len(grass_names)] if selector < 4 else "grass_base")
        base.append(row)

    roads: dict[tuple[int, int], str] = {}

    def horizontal_road(x_start: int, x_end: int, y_start: int) -> None:
        for x in range(x_start, x_end):
            roads[(x, y_start)] = "road_edge_north"
            roads[(x, y_start + 1)] = "road_fill_variant_01" if x % 4 == 1 else "road_fill"
            roads[(x, y_start + 2)] = "road_fill_variant_01" if x % 5 == 2 else "road_fill"
            roads[(x, y_start + 3)] = "road_edge_south"

    def vertical_road(x_start: int, y_start: int, y_end: int) -> None:
        for y in range(y_start, y_end):
            roads[(x_start, y)] = "road_edge_west"
            roads[(x_start + 1, y)] = "road_fill_variant_01" if y % 4 == 1 else "road_fill"
            roads[(x_start + 2, y)] = "road_fill_variant_01" if y % 5 == 2 else "road_fill"
            roads[(x_start + 3, y)] = "road_edge_east"

    horizontal_road(0, 7, 9)
    horizontal_road(23, 30, 9)
    vertical_road(13, 0, 5)
    vertical_road(13, 17, 22)

    # Four-tile-wide stair-step approximation of the locked northeast branch.
    for row_index, y in enumerate(range(1, 6)):
        x_start = 23 - row_index
        for offset in range(4):
            roads[(x_start + offset, y)] = "road_fill_variant_01" if (row_index + offset) % 4 == 0 else "road_fill"

    plaza: dict[tuple[int, int], str] = {}
    for y in range(5, 17):
        for x in range(7, 23):
            if y == 5 and x in (7, 22):
                continue
            if y == 16 and x in (7, 22):
                continue
            if y == 5:
                tile = "plaza_edge_north"
            elif y == 16:
                tile = "plaza_edge_south"
            elif x == 7:
                tile = "plaza_edge_west"
            elif x == 22:
                tile = "plaza_edge_east"
            else:
                variants = ["plaza_fill", "plaza_variant_01", "plaza_fill", "plaza_variant_02", "plaza_variant_03"]
                tile = variants[(x * 7 + y * 11) % len(variants)]
            plaza[(x, y)] = tile

    plaza[(7, 5)] = "plaza_clipped_corner_nw"
    plaza[(22, 5)] = "plaza_clipped_corner_ne"
    plaza[(7, 16)] = "plaza_clipped_corner_sw"
    plaza[(22, 16)] = "plaza_clipped_corner_se"

    transitions: dict[tuple[int, int], str] = {}
    for y in range(9, 13):
        transitions[(7, y)] = "road_to_plaza_west"
        transitions[(22, y)] = "road_to_plaza_east"
    for x in range(13, 17):
        transitions[(x, 5)] = "road_to_plaza_north"
        transitions[(x, 16)] = "road_to_plaza_south"

    return base, roads, plaza, transitions


def _write_town_square_preview(tiles: dict[str, Image.Image]) -> None:
    base, roads, plaza, transitions = _town_square_tile_layers()
    preview = Image.new("RGBA", (30 * TILE_SIZE, 22 * TILE_SIZE), (0, 0, 0, 255))
    for y, row in enumerate(base):
        for x, tile_name in enumerate(row):
            preview.paste(tiles[tile_name], (x * TILE_SIZE, y * TILE_SIZE))
    for layer in (roads, plaza, transitions):
        for (x, y), tile_name in layer.items():
            preview.paste(tiles[tile_name], (x * TILE_SIZE, y * TILE_SIZE))

    PREVIEW_DIRECTORY.mkdir(parents=True, exist_ok=True)
    preview.save(TOWN_SQUARE_PREVIEW_PATH, optimize=False)


def main() -> None:
    source_hash = _source_hash()
    if source_hash != EXPECTED_SOURCE_SHA256:
        raise SystemExit(
            "Source master hash mismatch; refusing to prepare runtime assets. "
            f"Expected {EXPECTED_SOURCE_SHA256}, got {source_hash}."
        )

    source = Image.open(SOURCE_PATH).convert("RGBA")
    if source.size != (1448, 1086):
        raise SystemExit(f"Unexpected source dimensions: {source.size}")

    tiles = _build_tiles(source)
    atlas = _write_atlas(tiles)
    _write_validation_preview(tiles)
    _write_town_square_preview(tiles)

    print(f"source_sha256={source_hash}")
    print(f"atlas={ATLAS_PATH.relative_to(REPOSITORY_ROOT)}")
    print(f"atlas_size={atlas.width}x{atlas.height}")
    print(f"tile_size={TILE_SIZE}x{TILE_SIZE}")
    print(f"included_tiles={len(TILE_COORDINATES)}")
    print(f"validation_preview={VALIDATION_PREVIEW_PATH.relative_to(REPOSITORY_ROOT)}")
    print(f"town_square_preview={TOWN_SQUARE_PREVIEW_PATH.relative_to(REPOSITORY_ROOT)}")


if __name__ == "__main__":
    main()
