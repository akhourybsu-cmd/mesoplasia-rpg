#!/usr/bin/env python3
"""Build the deterministic Caden Terrain Runtime v1.1 derivative.

The immutable source master and Runtime v1 atlas are read-only inputs. Output is
limited to the separate v1.1 atlas and documentation previews.
"""

from __future__ import annotations

import argparse
import base64
import colorsys
from collections import Counter
import hashlib
import json
from pathlib import Path
import struct

from PIL import Image, ImageDraw, ImageEnhance, ImageStat


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = REPOSITORY_ROOT / "assets/source_art/caden/terrain/caden_terrain_master_v1.png"
V1_ATLAS_PATH = REPOSITORY_ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1.png"
V1_TOWN_SQUARE_PREVIEW_PATH = (
    REPOSITORY_ROOT / "docs/art/previews/caden_terrain_runtime_v1_town_square_preview.png"
)
OUTPUT_ATLAS_PATH = (
    REPOSITORY_ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png"
)
PREVIEW_DIRECTORY = REPOSITORY_ROOT / "docs/art/previews"
VALIDATION_PREVIEW_PATH = PREVIEW_DIRECTORY / "caden_terrain_runtime_v1_1_validation.png"
TOWN_SQUARE_PREVIEW_PATH = (
    PREVIEW_DIRECTORY / "caden_terrain_runtime_v1_1_town_square_preview.png"
)
COMPARISON_PREVIEW_PATH = PREVIEW_DIRECTORY / "caden_terrain_v1_vs_v1_1_comparison.png"

EXPECTED_SOURCE_SHA256 = "36308c3fe4eb1bda2cca61c7778583440c07b8b859c2f597185f180ebdcb3b4c"
EXPECTED_V1_SHA256 = "0e0b6e5bad4c3a64acd427171212ba16ed2a75e10f0006df22d6445100fa0279"
TILE_SIZE = 32
ATLAS_COLUMNS = 8
ATLAS_ROWS = 8
PLACEMENT_SEED = 0xCADA1101


TileCoordinate = tuple[int, int]
CellMap = dict[tuple[int, int], str]


TILE_COORDINATES: dict[str, TileCoordinate] = {
    "grass_base": (0, 0),
    "grass_variant_01": (1, 0),
    "grass_variant_02": (2, 0),
    "grass_variant_03": (3, 0),
    "grass_variant_04": (4, 0),
    "grass_variant_05": (5, 0),
    "grass_worn_01": (6, 0),
    "grass_worn_02": (7, 0),
    "road_fill": (0, 1),
    "road_fill_variant_01": (1, 1),
    "road_fill_variant_02": (2, 1),
    "road_fill_variant_03": (3, 1),
    "road_fill_variant_04": (4, 1),
    "road_worn_01": (5, 1),
    "road_worn_02": (6, 1),
    "road_edge_north": (7, 1),
    "road_edge_south": (0, 2),
    "road_edge_west": (1, 2),
    "road_edge_east": (2, 2),
    "road_straight_horizontal": (3, 2),
    "road_straight_vertical": (4, 2),
    "road_outer_corner_nw": (5, 2),
    "road_outer_corner_ne": (6, 2),
    "road_outer_corner_sw": (7, 2),
    "road_outer_corner_se": (0, 3),
    "road_inner_corner_nw": (1, 3),
    "road_inner_corner_ne": (2, 3),
    "road_inner_corner_sw": (3, 3),
    "road_inner_corner_se": (4, 3),
    "road_cross": (5, 3),
    "road_junction_n_e_w": (6, 3),
    "road_junction_n_s_w": (7, 3),
    "road_to_plaza_north": (0, 4),
    "road_to_plaza_south": (1, 4),
    "road_to_plaza_west": (2, 4),
    "road_to_plaza_east": (3, 4),
    "plaza_fill": (4, 4),
    "plaza_variant_01": (5, 4),
    "plaza_variant_02": (6, 4),
    "plaza_variant_03": (7, 4),
    "plaza_variant_04": (0, 5),
    "plaza_variant_05": (1, 5),
    "plaza_macro_nw": (2, 5),
    "plaza_macro_ne": (3, 5),
    "plaza_macro_sw": (4, 5),
    "plaza_macro_se": (5, 5),
    "plaza_edge_north": (6, 5),
    "plaza_edge_south": (7, 5),
    "plaza_edge_west": (0, 6),
    "plaza_edge_east": (1, 6),
    "plaza_outer_corner_nw": (2, 6),
    "plaza_outer_corner_ne": (3, 6),
    "plaza_outer_corner_sw": (4, 6),
    "plaza_outer_corner_se": (5, 6),
    "plaza_clipped_corner_nw": (6, 6),
    "plaza_clipped_corner_ne": (7, 6),
    "plaza_clipped_corner_sw": (0, 7),
    "plaza_clipped_corner_se": (1, 7),
}


V1_COORDINATES: dict[str, TileCoordinate] = {
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
    "plaza_fill": (0, 4),
    "plaza_variant_01": (1, 4),
    "plaza_variant_02": (2, 4),
    "plaza_variant_03": (3, 4),
}


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _tile(atlas: Image.Image, coordinate: TileCoordinate) -> Image.Image:
    x, y = coordinate
    return atlas.crop((x * TILE_SIZE, y * TILE_SIZE, (x + 1) * TILE_SIZE, (y + 1) * TILE_SIZE)).convert("RGBA")


def _force_opaque(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    result.putalpha(255)
    return result


def _color_adjust(
    image: Image.Image,
    *,
    hue_shift_degrees: float,
    saturation_scale: float,
    luminance_scale: float,
    contrast_scale: float,
) -> Image.Image:
    pixels: list[tuple[int, int, int, int]] = []
    for red, green, blue, _alpha in image.convert("RGBA").get_flattened_data():
        hue, saturation, value = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
        hue = (hue + hue_shift_degrees / 360.0) % 1.0
        saturation = max(0.0, min(1.0, saturation * saturation_scale))
        value = max(0.0, min(1.0, value * luminance_scale))
        adjusted = colorsys.hsv_to_rgb(hue, saturation, value)
        pixels.append(tuple(round(channel * 255.0) for channel in adjusted) + (255,))
    result = Image.new("RGBA", image.size)
    result.putdata(pixels)
    result = ImageEnhance.Contrast(result).enhance(contrast_scale)
    return _force_opaque(result)


def _cluster_family(images: list[Image.Image], color_count: int) -> list[Image.Image]:
    strip = Image.new("RGB", (TILE_SIZE * len(images), TILE_SIZE))
    for index, image in enumerate(images):
        strip.paste(image.convert("RGB"), (index * TILE_SIZE, 0))
    palette = strip.quantize(colors=color_count, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return [
        _force_opaque(image.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA"))
        for image in images
    ]


def _center_variant(base: Image.Image, candidate: Image.Image, inset: int = 6) -> Image.Image:
    result = base.copy()
    result.paste(candidate.crop((inset, inset, TILE_SIZE - inset, TILE_SIZE - inset)), (inset, inset))
    return _force_opaque(result)


def _interior_value_variant(base: Image.Image, scale: float, inset: int = 7) -> Image.Image:
    result = base.copy()
    patch = ImageEnhance.Brightness(base.crop((inset, inset, TILE_SIZE - inset, TILE_SIZE - inset))).enhance(scale)
    result.paste(patch, (inset, inset))
    return _force_opaque(result)


def _material_edge(foreground: Image.Image, background: Image.Image, direction: str, width: int = 5) -> Image.Image:
    result = foreground.copy()
    edge_offsets = (0, 1, 0, -1, 0, 0, 1, 0)
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            offset = edge_offsets[(x if direction in ("north", "south") else y) % len(edge_offsets)]
            outside = {
                "north": y < width + offset,
                "south": y >= TILE_SIZE - width - offset,
                "west": x < width + offset,
                "east": x >= TILE_SIZE - width - offset,
            }[direction]
            if outside:
                result.putpixel((x, y), background.getpixel((x, y)))
    return _force_opaque(result)


def _corner_cut(foreground: Image.Image, background: Image.Image, corner: str, size: int = 12) -> Image.Image:
    result = foreground.copy()
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            outside = {
                "nw": x < size and y < size,
                "ne": x >= TILE_SIZE - size and y < size,
                "sw": x < size and y >= TILE_SIZE - size,
                "se": x >= TILE_SIZE - size and y >= TILE_SIZE - size,
            }[corner]
            if outside:
                result.putpixel((x, y), background.getpixel((x, y)))
    return _force_opaque(result)


def _clipped_corner(plaza: Image.Image, grass: Image.Image, corner: str) -> Image.Image:
    result = plaza.copy()
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            inside = {
                "nw": x + y >= TILE_SIZE - 1,
                "ne": y >= x,
                "sw": x >= y,
                "se": x + y <= TILE_SIZE - 1,
            }[corner]
            if not inside:
                result.putpixel((x, y), grass.getpixel((x, y)))
    return _force_opaque(result)


def _constructed_transition(road: Image.Image, plaza: Image.Image, road_side: str) -> Image.Image:
    result = plaza.copy()
    threshold_dark = tuple(max(0, round(channel * 0.78)) for channel in ImageStat.Stat(plaza.convert("RGB")).mean)
    if road_side in ("north", "south"):
        if road_side == "north":
            result.paste(road.crop((0, 0, 32, 13)), (0, 0))
            band_rows = range(13, 17)
        else:
            result.paste(road.crop((0, 19, 32, 32)), (0, 19))
            band_rows = range(15, 19)
        for y in band_rows:
            for x in range(TILE_SIZE):
                source_y = (y + 7) % TILE_SIZE
                result.putpixel((x, y), plaza.getpixel((x, source_y)))
        border_y = 13 if road_side == "north" else 18
        for x in range(TILE_SIZE):
            if x % 8 != 7:
                result.putpixel((x, border_y), threshold_dark + (255,))
    else:
        if road_side == "west":
            result.paste(road.crop((0, 0, 13, 32)), (0, 0))
            band_columns = range(13, 17)
        else:
            result.paste(road.crop((19, 0, 32, 32)), (19, 0))
            band_columns = range(15, 19)
        for x in band_columns:
            for y in range(TILE_SIZE):
                source_x = (x + 7) % TILE_SIZE
                result.putpixel((x, y), plaza.getpixel((source_x, y)))
        border_x = 13 if road_side == "west" else 18
        for y in range(TILE_SIZE):
            if y % 8 != 7:
                result.putpixel((border_x, y), threshold_dark + (255,))
    return _force_opaque(result)


def _build_tiles(v1_atlas: Image.Image) -> dict[str, Image.Image]:
    grass_inputs = [
        _color_adjust(
            _tile(v1_atlas, V1_COORDINATES[name]),
            hue_shift_degrees=6.0,
            saturation_scale=0.84,
            luminance_scale=0.92,
            contrast_scale=0.60,
        )
        for name in (
            "grass_base",
            "grass_variant_01",
            "grass_variant_02",
            "grass_variant_03",
            "grass_variant_04",
            "grass_worn_01",
            "grass_worn_02",
        )
    ]
    grass_clustered = _cluster_family(grass_inputs, 12)
    grass_base = grass_clustered[0]
    grass_tiles = {
        "grass_base": grass_base,
        "grass_variant_01": _center_variant(grass_base, grass_clustered[1], 8),
        "grass_variant_02": _center_variant(grass_base, grass_clustered[2], 8),
        "grass_variant_03": _center_variant(grass_base, grass_clustered[3], 8),
        "grass_variant_04": _center_variant(grass_base, grass_clustered[4], 9),
        "grass_variant_05": _interior_value_variant(grass_base, 0.96, 9),
        "grass_worn_01": _center_variant(grass_base, grass_clustered[5], 9),
        "grass_worn_02": _center_variant(grass_base, grass_clustered[6], 9),
    }

    road_inputs = [
        _color_adjust(
            _tile(v1_atlas, V1_COORDINATES[name]),
            hue_shift_degrees=-1.0,
            saturation_scale=0.88,
            luminance_scale=0.86,
            contrast_scale=0.64,
        )
        for name in ("road_fill", "road_fill_variant_01", "road_straight_horizontal_worn")
    ]
    road_clustered = _cluster_family(road_inputs, 16)
    road_fill = road_clustered[0]
    road_tiles = {
        "road_fill": road_fill,
        "road_fill_variant_01": _center_variant(road_fill, road_clustered[1], 7),
        "road_fill_variant_02": _interior_value_variant(road_fill, 0.96, 7),
        "road_fill_variant_03": _interior_value_variant(road_fill, 1.025, 8),
        "road_fill_variant_04": _center_variant(road_fill, road_clustered[1], 10),
        "road_worn_01": _center_variant(road_fill, road_clustered[2], 10),
        "road_worn_02": _center_variant(road_fill, road_clustered[1], 11),
    }

    road_tiles.update(
        {
            f"road_edge_{direction}": _material_edge(road_fill, grass_base, direction)
            for direction in ("north", "south", "west", "east")
        }
    )
    road_tiles["road_straight_horizontal"] = road_tiles["road_edge_north"].copy()
    road_tiles["road_straight_vertical"] = road_tiles["road_edge_west"].copy()

    for corner in ("nw", "ne", "sw", "se"):
        road_tiles[f"road_outer_corner_{corner}"] = _corner_cut(road_fill, grass_base, corner, 12)
        road_tiles[f"road_inner_corner_{corner}"] = _corner_cut(road_fill, grass_base, corner, 7)
    road_tiles["road_cross"] = road_fill.copy()
    road_tiles["road_junction_n_e_w"] = _center_variant(road_fill, road_tiles["road_worn_01"], 8)
    road_tiles["road_junction_n_s_w"] = _center_variant(road_fill, road_tiles["road_worn_02"], 8)

    plaza_inputs = [
        _color_adjust(
            _tile(v1_atlas, V1_COORDINATES[name]),
            hue_shift_degrees=-1.5,
            saturation_scale=0.84,
            luminance_scale=0.98,
            contrast_scale=0.62,
        )
        for name in ("plaza_fill", "plaza_variant_01", "plaza_variant_02", "plaza_variant_03")
    ]
    plaza_clustered = _cluster_family(plaza_inputs, 18)
    plaza_base = plaza_clustered[0]
    plaza_tiles = {
        "plaza_fill": plaza_base,
        "plaza_variant_01": _center_variant(plaza_base, plaza_clustered[1], 6),
        "plaza_variant_02": _center_variant(plaza_base, plaza_clustered[2], 6),
        "plaza_variant_03": _center_variant(plaza_base, plaza_clustered[3], 7),
        "plaza_variant_04": _interior_value_variant(plaza_base, 0.97, 7),
        "plaza_variant_05": _interior_value_variant(plaza_base, 1.02, 8),
        "plaza_macro_nw": _center_variant(plaza_base, _interior_value_variant(plaza_clustered[1], 0.98), 5),
        "plaza_macro_ne": _center_variant(plaza_base, _interior_value_variant(plaza_clustered[2], 1.01), 5),
        "plaza_macro_sw": _center_variant(plaza_base, _interior_value_variant(plaza_clustered[3], 1.00), 5),
        "plaza_macro_se": _center_variant(plaza_base, _interior_value_variant(plaza_clustered[1], 0.97), 5),
    }
    plaza_tiles.update(
        {
            f"plaza_edge_{direction}": _material_edge(plaza_base, grass_base, direction, 4)
            for direction in ("north", "south", "west", "east")
        }
    )
    for corner in ("nw", "ne", "sw", "se"):
        plaza_tiles[f"plaza_outer_corner_{corner}"] = _corner_cut(plaza_base, grass_base, corner, 10)
        plaza_tiles[f"plaza_clipped_corner_{corner}"] = _clipped_corner(plaza_base, grass_base, corner)

    transitions = {
        f"road_to_plaza_{direction}": _constructed_transition(road_fill, plaza_base, direction)
        for direction in ("north", "south", "west", "east")
    }

    tiles = grass_tiles | road_tiles | plaza_tiles | transitions
    missing = set(TILE_COORDINATES) - set(tiles)
    if missing:
        raise RuntimeError(f"Missing v1.1 tiles: {sorted(missing)}")
    return tiles


def _stable_hash(x: int, y: int, salt: int = 0) -> int:
    value = (x * 0x1F123BB5 + y * 0x5F356495 + PLACEMENT_SEED + salt) & 0xFFFFFFFF
    value ^= value >> 16
    value = (value * 0x7FEB352D) & 0xFFFFFFFF
    value ^= value >> 15
    value = (value * 0x846CA68B) & 0xFFFFFFFF
    return value ^ (value >> 16)


def _grass_name(x: int, y: int) -> str:
    roll = _stable_hash(x, y, 11) % 100
    if roll < 76:
        return "grass_base"
    if roll < 95:
        return f"grass_variant_{1 + _stable_hash(x, y, 17) % 5:02d}"
    return f"grass_worn_{1 + _stable_hash(x, y, 23) % 2:02d}"


def _road_fill_name(x: int, y: int, near_plaza: bool) -> str:
    roll = _stable_hash(x, y, 31) % 100
    worn_cutoff = 12 if near_plaza else 6
    if roll < worn_cutoff:
        return f"road_worn_{1 + _stable_hash(x, y, 37) % 2:02d}"
    if roll < 45:
        return f"road_fill_variant_{1 + _stable_hash(x, y, 41) % 4:02d}"
    return "road_fill"


def _plaza_fill_name(x: int, y: int) -> str:
    calm_center = 11 <= x <= 18 and 8 <= y <= 13
    roll = _stable_hash(x, y, 53) % 100
    if calm_center or roll < 46:
        return "plaza_fill"
    return f"plaza_variant_{1 + _stable_hash(x, y, 59) % 5:02d}"


def town_square_layers() -> dict[str, CellMap]:
    base: CellMap = {(x, y): _grass_name(x, y) for y in range(22) for x in range(30)}
    roads: CellMap = {}

    def horizontal_road(x_start: int, x_end: int, y_start: int) -> None:
        for x in range(x_start, x_end):
            roads[(x, y_start)] = "road_edge_north"
            roads[(x, y_start + 1)] = _road_fill_name(x, y_start + 1, x in (5, 6, 23, 24))
            roads[(x, y_start + 2)] = _road_fill_name(x, y_start + 2, x in (5, 6, 23, 24))
            roads[(x, y_start + 3)] = "road_edge_south"

    def vertical_road(x_start: int, y_start: int, y_end: int) -> None:
        for y in range(y_start, y_end):
            roads[(x_start, y)] = "road_edge_west"
            roads[(x_start + 1, y)] = _road_fill_name(x_start + 1, y, y in (3, 4, 17, 18))
            roads[(x_start + 2, y)] = _road_fill_name(x_start + 2, y, y in (3, 4, 17, 18))
            roads[(x_start + 3, y)] = "road_edge_east"

    horizontal_road(0, 7, 9)
    horizontal_road(23, 30, 9)
    vertical_road(13, 0, 5)
    vertical_road(13, 17, 22)

    for row_index, y in enumerate(range(1, 6)):
        x_start = 23 - row_index
        for offset in range(4):
            x = x_start + offset
            roads[(x, y)] = _road_fill_name(x, y, y == 5)

    plaza: CellMap = {}
    for y in range(5, 17):
        for x in range(7, 23):
            if y == 5:
                tile = "plaza_edge_north"
            elif y == 16:
                tile = "plaza_edge_south"
            elif x == 7:
                tile = "plaza_edge_west"
            elif x == 22:
                tile = "plaza_edge_east"
            else:
                tile = _plaza_fill_name(x, y)
            plaza[(x, y)] = tile

    plaza[(7, 5)] = "plaza_clipped_corner_nw"
    plaza[(22, 5)] = "plaza_clipped_corner_ne"
    plaza[(7, 16)] = "plaza_clipped_corner_sw"
    plaza[(22, 16)] = "plaza_clipped_corner_se"

    # Two sparse, non-symbolic 2x2 macro groups outside the calm central field.
    for anchor_x, anchor_y in ((9, 7), (19, 13)):
        plaza[(anchor_x, anchor_y)] = "plaza_macro_nw"
        plaza[(anchor_x + 1, anchor_y)] = "plaza_macro_ne"
        plaza[(anchor_x, anchor_y + 1)] = "plaza_macro_sw"
        plaza[(anchor_x + 1, anchor_y + 1)] = "plaza_macro_se"

    transitions: CellMap = {}
    for y in range(9, 13):
        transitions[(7, y)] = "road_to_plaza_west"
        transitions[(22, y)] = "road_to_plaza_east"
    for x in range(13, 17):
        transitions[(x, 5)] = "road_to_plaza_north"
        transitions[(x, 16)] = "road_to_plaza_south"

    return {
        "BaseTerrainTiles": base,
        "RoadTiles": roads,
        "PlazaTiles": plaza,
        "TerrainTransitions": transitions,
    }


def _write_atlas(tiles: dict[str, Image.Image]) -> None:
    atlas = Image.new("RGBA", (ATLAS_COLUMNS * TILE_SIZE, ATLAS_ROWS * TILE_SIZE), (0, 0, 0, 0))
    for name, (x, y) in TILE_COORDINATES.items():
        atlas.paste(tiles[name], (x * TILE_SIZE, y * TILE_SIZE))
    OUTPUT_ATLAS_PATH.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT_ATLAS_PATH, optimize=False)


def _validate_atlas() -> None:
    atlas = Image.open(OUTPUT_ATLAS_PATH).convert("RGBA")
    if atlas.size != (ATLAS_COLUMNS * TILE_SIZE, ATLAS_ROWS * TILE_SIZE):
        raise RuntimeError(f"Unexpected v1.1 atlas size: {atlas.size}")
    used_coordinates = set(TILE_COORDINATES.values())
    for y in range(ATLAS_ROWS):
        for x in range(ATLAS_COLUMNS):
            alpha = atlas.crop(
                (x * TILE_SIZE, y * TILE_SIZE, (x + 1) * TILE_SIZE, (y + 1) * TILE_SIZE)
            ).getchannel("A")
            extrema = alpha.getextrema()
            if (x, y) in used_coordinates and extrema != (255, 255):
                raise RuntimeError(f"Used atlas cell {(x, y)} contains partial or missing alpha: {extrema}")
            if (x, y) not in used_coordinates and extrema != (0, 0):
                raise RuntimeError(f"Unused atlas cell {(x, y)} is not transparent: {extrema}")


def _draw_grid(canvas: Image.Image, tiles: dict[str, Image.Image], rows: list[list[str]], origin: tuple[int, int]) -> None:
    for y, row in enumerate(rows):
        for x, name in enumerate(row):
            canvas.paste(tiles[name], (origin[0] + x * TILE_SIZE, origin[1] + y * TILE_SIZE))


def _write_validation_preview(tiles: dict[str, Image.Image]) -> None:
    preview = Image.new("RGB", (800, 576), (36, 32, 28))
    draw = ImageDraw.Draw(preview)
    ink = (245, 235, 210)
    draw.text((12, 8), "Grass 3x3 repetition", fill=ink)
    _draw_grid(preview, tiles, [["grass_base"] * 3 for _ in range(3)], (12, 24))
    draw.text((132, 8), "Mixed calm grass", fill=ink)
    grass = ["grass_base", "grass_variant_01", "grass_base", "grass_variant_03", "grass_worn_01"]
    _draw_grid(preview, tiles, [[grass[(x * 3 + y * 2) % len(grass)] for x in range(6)] for y in range(3)], (132, 24))
    draw.text((356, 8), "Horizontal road", fill=ink)
    road_row = ["road_fill", "road_fill_variant_01", "road_fill", "road_worn_01"] * 2
    _draw_grid(preview, tiles, [["grass_base"] * 8, ["road_edge_north"] * 8, road_row, road_row[2:] + road_row[:2], ["road_edge_south"] * 8], (356, 24))
    draw.text((12, 144), "Vertical road", fill=ink)
    vertical = [["grass_base", "road_edge_west", road_row[y % len(road_row)], "road_fill", "road_edge_east", "grass_base"] for y in range(7)]
    _draw_grid(preview, tiles, vertical, (12, 160))
    draw.text((228, 144), "Road corners and junctions", fill=ink)
    _draw_grid(preview, tiles, [["road_outer_corner_nw", "road_outer_corner_ne", "road_cross", "road_junction_n_e_w"], ["road_outer_corner_sw", "road_outer_corner_se", "road_junction_n_s_w", "road_worn_02"], ["road_inner_corner_nw", "road_inner_corner_ne", "road_inner_corner_sw", "road_inner_corner_se"]], (228, 160))
    draw.text((388, 144), "Plaza variation and 2x2 macro", fill=ink)
    plaza_rows = [["plaza_edge_west", "plaza_fill", "plaza_variant_01", "plaza_variant_02", "plaza_variant_03", "plaza_edge_east"], ["plaza_edge_west", "plaza_variant_04", "plaza_macro_nw", "plaza_macro_ne", "plaza_variant_05", "plaza_edge_east"], ["plaza_edge_west", "plaza_fill", "plaza_macro_sw", "plaza_macro_se", "plaza_fill", "plaza_edge_east"]]
    _draw_grid(preview, tiles, plaza_rows, (388, 160))
    draw.text((12, 408), "Clipped plaza corners", fill=ink)
    _draw_grid(preview, tiles, [["plaza_clipped_corner_nw", "plaza_edge_north", "plaza_edge_north", "plaza_clipped_corner_ne"], ["plaza_edge_west", "plaza_fill", "plaza_variant_01", "plaza_edge_east"], ["plaza_edge_west", "plaza_variant_02", "plaza_fill", "plaza_edge_east"], ["plaza_clipped_corner_sw", "plaza_edge_south", "plaza_edge_south", "plaza_clipped_corner_se"]], (12, 424))
    draw.text((180, 408), "Constructed road-to-plaza thresholds", fill=ink)
    _draw_grid(preview, tiles, [["road_to_plaza_north", "road_to_plaza_south"], ["road_to_plaza_west", "road_to_plaza_east"]], (180, 424))
    PREVIEW_DIRECTORY.mkdir(parents=True, exist_ok=True)
    preview.resize((preview.width * 2, preview.height * 2), Image.Resampling.NEAREST).save(VALIDATION_PREVIEW_PATH, optimize=False)


def _render_town_square(tiles: dict[str, Image.Image], layers: dict[str, CellMap]) -> Image.Image:
    preview = Image.new("RGBA", (30 * TILE_SIZE, 22 * TILE_SIZE), (0, 0, 0, 255))
    for layer_name in ("BaseTerrainTiles", "RoadTiles", "PlazaTiles", "TerrainTransitions"):
        for (x, y), name in layers[layer_name].items():
            preview.paste(tiles[name], (x * TILE_SIZE, y * TILE_SIZE))
    return preview


def _write_comparison(v1_1_preview: Image.Image) -> None:
    v1_preview = Image.open(V1_TOWN_SQUARE_PREVIEW_PATH).convert("RGBA")
    header_height = 24
    comparison = Image.new("RGBA", (v1_preview.width + v1_1_preview.width, v1_preview.height + header_height), (36, 32, 28, 255))
    comparison.paste(v1_preview, (0, header_height))
    comparison.paste(v1_1_preview, (v1_preview.width, header_height))
    draw = ImageDraw.Draw(comparison)
    draw.text((8, 7), "Runtime v1", fill=(245, 235, 210, 255))
    draw.text((v1_preview.width + 8, 7), "Runtime v1.1", fill=(245, 235, 210, 255))
    comparison.save(COMPARISON_PREVIEW_PATH, optimize=False)


def _encode_tile_map_data(cells: CellMap) -> str:
    payload = bytearray((0, 0))
    for (x, y), tile_name in sorted(cells.items(), key=lambda item: (item[0][1], item[0][0])):
        atlas_x, atlas_y = TILE_COORDINATES[tile_name]
        payload.extend(struct.pack("<hhhhhh", x, y, 0, atlas_x, atlas_y, 0))
    return base64.b64encode(payload).decode("ascii")


def _usage_summary(layers: dict[str, CellMap]) -> dict[str, dict[str, int]]:
    return {name: dict(sorted(Counter(cells.values()).items())) for name, cells in layers.items()}


def _material_metrics(tiles: dict[str, Image.Image]) -> dict[str, dict[str, float]]:
    metrics: dict[str, dict[str, float]] = {}
    for name in ("grass_base", "road_fill", "plaza_fill"):
        image = tiles[name].convert("RGB")
        stat = ImageStat.Stat(image)
        luminance = sum(stat.mean) / 3.0
        contrast = sum(stat.stddev) / 3.0
        saturation_values = [
            colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)[1]
            for r, g, b in image.get_flattened_data()
        ]
        metrics[name] = {
            "mean_luminance": round(luminance, 2),
            "grayscale_mean": round(ImageStat.Stat(image.convert("L")).mean[0], 2),
            "mean_saturation": round(sum(saturation_values) / len(saturation_values), 4),
            "mean_channel_stddev": round(contrast, 2),
        }
    return metrics


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--emit-scene-data", action="store_true")
    args = parser.parse_args()

    source_hash = _sha256(SOURCE_PATH)
    v1_hash = _sha256(V1_ATLAS_PATH)
    if source_hash != EXPECTED_SOURCE_SHA256:
        raise SystemExit(f"Source hash mismatch: expected {EXPECTED_SOURCE_SHA256}, got {source_hash}")
    if v1_hash != EXPECTED_V1_SHA256:
        raise SystemExit(f"Runtime v1 hash mismatch: expected {EXPECTED_V1_SHA256}, got {v1_hash}")

    v1_atlas = Image.open(V1_ATLAS_PATH).convert("RGBA")
    if v1_atlas.size != (256, 192):
        raise SystemExit(f"Unexpected Runtime v1 dimensions: {v1_atlas.size}")

    tiles = _build_tiles(v1_atlas)
    layers = town_square_layers()
    _write_atlas(tiles)
    _validate_atlas()
    _write_validation_preview(tiles)
    town_square_preview = _render_town_square(tiles, layers)
    town_square_preview.save(TOWN_SQUARE_PREVIEW_PATH, optimize=False)
    _write_comparison(town_square_preview)

    summary = {
        "source_sha256": source_hash,
        "runtime_v1_sha256": v1_hash,
        "runtime_v1_1_sha256": _sha256(OUTPUT_ATLAS_PATH),
        "atlas_size": [ATLAS_COLUMNS * TILE_SIZE, ATLAS_ROWS * TILE_SIZE],
        "tile_count": len(TILE_COORDINATES),
        "placement_seed": f"0x{PLACEMENT_SEED:08X}",
        "usage": _usage_summary(layers),
        "metrics": _material_metrics(tiles),
    }
    if args.emit_scene_data:
        summary["scene_data"] = {name: _encode_tile_map_data(cells) for name, cells in layers.items()}
    print(json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main()
