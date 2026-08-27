#!/usr/bin/env python3
"""Build connected Wayfarer's Approach landscape surfaces from approved art."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_ROOT = ROOT / "assets/environments/caden/wayfarers_approach/terrain/composed_v1"
METADATA_PATH = OUTPUT_ROOT / "wayfarers_landscape_surfaces_v1.json"
GRASS_ATLAS = ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png"
TERRAIN_ROOT = ROOT / "assets/environments/caden/wayfarers_approach/terrain"
SOURCE_NAMES = (
    "rest_field_trampled_a_v1.png",
    "rest_field_trampled_b_v1.png",
    "rest_field_trampled_c_v1.png",
    "rest_field_dirt_a_v1.png",
    "rest_field_straw_v1.png",
    "rest_field_mud_v1.png",
    "road_wear_patch_v1.png",
)


@dataclass(frozen=True)
class SurfaceSpec:
    filename: str
    room: str
    world_origin: tuple[int, int]
    size: tuple[int, int]
    perimeter: tuple[tuple[int, int], ...]
    cutouts: tuple[tuple[tuple[int, int], ...], ...]
    strong_wear: tuple[tuple[tuple[int, int], ...], ...]
    intent: str
    grass_only: bool = False


SPECS = (
    SurfaceSpec(
        filename="inn_forecourt_surface_v1.png",
        room="inn_forecourt",
        world_origin=(112, 188),
        size=(356, 104),
        perimeter=((3, 24), (22, 14), (55, 10), (91, 14), (126, 9), (164, 13),
                   (202, 8), (238, 12), (272, 9), (307, 15), (340, 22), (352, 42),
                   (349, 67), (336, 91), (306, 98), (274, 94), (242, 100),
                   (208, 95), (174, 101), (140, 96), (106, 99), (72, 94),
                   (39, 98), (12, 88), (3, 67)),
        cutouts=(
            ((3, 30), (19, 24), (33, 31), (27, 48), (10, 52), (3, 45)),
        ),
        strong_wear=(
            ((62, 49), (143, 40), (227, 44), (286, 55), (303, 77), (274, 94),
             (202, 97), (128, 92), (72, 81), (48, 63)),
            ((258, 28), (320, 31), (347, 49), (338, 77), (294, 83), (248, 66)),
        ),
        intent="Continuous inn precinct linking the unchanged foundation and porch approach into the road shoulder.",
    ),
    SurfaceSpec(
        filename="traveler_yard_surface_v1.png",
        room="traveler_working_yard",
        world_origin=(124, 376),
        size=(588, 232),
        perimeter=((4, 36), (28, 27), (72, 30), (110, 24), (152, 29), (194, 24),
                   (238, 30), (280, 25), (326, 29), (370, 24), (414, 30), (452, 27),
                   (478, 32), (489, 30), (489, 6), (511, 3), (516, 14), (516, 38), (548, 48),
                   (574, 61), (584, 89), (578, 119), (584, 145), (571, 171),
                   (548, 185), (520, 189), (500, 207), (468, 215), (435, 211),
                   (400, 219), (360, 214), (322, 221), (280, 216), (240, 221),
                   (198, 214), (158, 219), (118, 212), (80, 218), (42, 207),
                   (15, 190), (4, 162), (10, 133), (3, 105), (9, 76)),
        cutouts=(
            ((4, 61), (24, 54), (42, 61), (37, 78), (16, 84), (4, 77)),
            ((553, 118), (584, 110), (584, 140), (564, 147)),
        ),
        strong_wear=(
            ((56, 74), (176, 65), (278, 76), (282, 119), (182, 135), (70, 126), (38, 103)),
            ((264, 74), (393, 69), (459, 90), (454, 132), (357, 144), (270, 127)),
            ((405, 118), (520, 109), (567, 133), (558, 171), (470, 181), (404, 160)),
            ((284, 169), (418, 166), (448, 194), (420, 215), (294, 216), (264, 196)),
            ((479, 25), (521, 13), (533, 56), (516, 90), (486, 80)),
        ),
        intent="One connected compacted working surface with road and wagon-gate thresholds.",
    ),
    SurfaceSpec(
        filename="rest_grove_surface_v1.png",
        room="rest_grove",
        world_origin=(774, 380),
        size=(204, 236),
        perimeter=((54, 3), (77, 5), (84, 26), (80, 50), (94, 69), (126, 77),
                   (159, 91), (190, 116), (199, 146), (193, 180), (174, 208),
                   (145, 228), (111, 233), (77, 226), (47, 231), (20, 213),
                   (4, 185), (8, 151), (3, 122), (17, 96), (43, 79), (57, 58),
                   (51, 34)),
        cutouts=(
            ((3, 131), (20, 119), (33, 126), (28, 147), (10, 154), (3, 147)),
            ((168, 101), (203, 108), (203, 141), (179, 151), (160, 134)),
            ((159, 194), (203, 178), (203, 215), (176, 230), (148, 214)),
        ),
        strong_wear=(
            ((52, 80), (121, 72), (165, 94), (177, 133), (155, 169), (96, 181),
             (42, 166), (25, 130)),
            ((70, 157), (149, 151), (177, 178), (162, 208), (94, 218), (51, 195)),
        ),
        intent="Subordinate rest-pocket surface with one narrow road approach and a planted outer crescent.",
    ),
    SurfaceSpec(
        filename="road_northwest_shoulder_surface_v1.png",
        room="road_northwest_shoulder",
        world_origin=(-2, 242),
        size=(454, 44),
        perimeter=((2, 2), (451, 2), (451, 19), (420, 26), (389, 20), (358, 29),
                   (326, 23), (294, 31), (262, 24), (230, 28), (198, 21),
                   (166, 27), (134, 22), (102, 30), (70, 23), (38, 29), (15, 23), (2, 25)),
        cutouts=(),
        strong_wear=(),
        intent="Irregular grass encroachment softening the northwest edge of the preserved main road.",
        grass_only=True,
    ),
    SurfaceSpec(
        filename="road_northeast_shoulder_surface_v1.png",
        room="road_northeast_shoulder",
        world_origin=(574, 242),
        size=(452, 44),
        perimeter=((2, 2), (449, 2), (449, 24), (425, 29), (394, 22), (362, 30),
                   (330, 24), (298, 28), (266, 21), (234, 29), (202, 23),
                   (170, 31), (138, 24), (106, 28), (74, 20), (42, 27), (16, 21), (2, 18)),
        cutouts=(),
        strong_wear=(),
        intent="Irregular grass encroachment softening the northeast edge of the preserved main road.",
        grass_only=True,
    ),
    SurfaceSpec(
        filename="road_southwest_shoulder_surface_v1.png",
        room="road_southwest_shoulder",
        world_origin=(-2, 358),
        size=(454, 44),
        perimeter=((2, 23), (30, 17), (62, 24), (94, 15), (126, 22), (158, 13),
                   (190, 20), (222, 15), (254, 23), (286, 14), (318, 21),
                   (350, 12), (382, 19), (414, 14), (451, 20), (451, 41), (2, 41)),
        cutouts=(),
        strong_wear=(),
        intent="Irregular grass encroachment softening the southwest edge of the preserved main road.",
        grass_only=True,
    ),
    SurfaceSpec(
        filename="road_southeast_shoulder_surface_v1.png",
        room="road_southeast_shoulder",
        world_origin=(574, 358),
        size=(452, 44),
        perimeter=((2, 18), (34, 12), (66, 20), (98, 14), (130, 23), (162, 16),
                   (194, 21), (226, 13), (258, 19), (290, 15), (322, 24),
                   (354, 17), (386, 22), (418, 14), (449, 21), (449, 41), (2, 41)),
        cutouts=(),
        strong_wear=(),
        intent="Irregular grass encroachment softening the southeast edge of the preserved main road.",
        grass_only=True,
    ),
    SurfaceSpec(
        filename="road_vertical_west_shoulder_surface_v1.png",
        room="road_vertical_west_shoulder",
        world_origin=(438, -2),
        size=(34, 260),
        perimeter=((2, 2), (20, 2), (26, 28), (20, 56), (29, 84), (22, 112),
                   (30, 140), (23, 168), (28, 196), (21, 224), (26, 257), (2, 257)),
        cutouts=(),
        strong_wear=(),
        intent="Irregular grass encroachment softening the west edge of the preserved north road.",
        grass_only=True,
    ),
    SurfaceSpec(
        filename="road_vertical_east_shoulder_surface_v1.png",
        room="road_vertical_east_shoulder",
        world_origin=(554, -2),
        size=(34, 260),
        perimeter=((12, 2), (31, 2), (31, 257), (10, 257), (5, 228), (12, 200),
                   (4, 172), (11, 144), (3, 116), (10, 88), (5, 60), (13, 32)),
        cutouts=(),
        strong_wear=(),
        intent="Irregular grass encroachment softening the east edge of the preserved north road.",
        grass_only=True,
    ),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def grass_pixel(atlas: Image.Image, world_x: int, world_y: int) -> tuple[int, int, int]:
    cell_x = world_x // 32
    cell_y = world_y // 32
    variant = (cell_x * 7 + cell_y * 11 + (cell_x * cell_y) % 5) % 8
    pixel = atlas.getpixel((variant * 32 + world_x % 32, world_y % 32))
    return pixel[:3]


def terrain_pixel(
    source_colors: list[tuple[int, int, int]],
    seed: int,
    strong: bool,
) -> tuple[int, int, int]:
    source_index = (5 if seed == 3 else 3) if strong else (seed - 1) % 2
    return source_colors[source_index]


def approved_interior_average(source: Image.Image) -> tuple[int, int, int]:
    interior = source.getchannel("A").filter(ImageFilter.MinFilter(5))
    totals = [0, 0, 0]
    count = 0
    for y in range(source.height):
        for x in range(source.width):
            if interior.getpixel((x, y)) != 255:
                continue
            pixel = source.getpixel((x, y))
            for channel in range(3):
                totals[channel] += pixel[channel]
            count += 1
    if count == 0:
        raise RuntimeError("Approved terrain texture has no opaque interior.")
    return tuple(total // count for total in totals)


def blend(base: tuple[int, int, int], wear: tuple[int, int, int], weight: int) -> tuple[int, int, int, int]:
    inverse = 255 - weight
    return tuple((base[index] * inverse + wear[index] * weight + 127) // 255 for index in range(3)) + (255,)


def build_mask(spec: SurfaceSpec) -> Image.Image:
    mask = Image.new("L", spec.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(spec.perimeter, fill=255)
    for cutout in spec.cutouts:
        draw.polygon(cutout, fill=0)
    return mask


def connected_component_count(mask: Image.Image) -> int:
    width, height = mask.size
    visited: set[tuple[int, int]] = set()
    components = 0
    for y in range(height):
        for x in range(width):
            if mask.getpixel((x, y)) == 0 or (x, y) in visited:
                continue
            components += 1
            stack = [(x, y)]
            visited.add((x, y))
            while stack:
                current_x, current_y = stack.pop()
                for next_x, next_y in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    point = (next_x, next_y)
                    if not (0 <= next_x < width and 0 <= next_y < height):
                        continue
                    if point in visited or mask.getpixel(point) == 0:
                        continue
                    visited.add(point)
                    stack.append(point)
    return components


def build_surface(
    spec: SurfaceSpec,
    atlas: Image.Image,
    source_colors: list[tuple[int, int, int]],
    seed: int,
) -> dict[str, object]:
    mask = build_mask(spec)
    inner = mask.filter(ImageFilter.MinFilter(9))
    deep = mask.filter(ImageFilter.MinFilter(19))
    strong_mask = Image.new("L", spec.size, 0)
    strong_draw = ImageDraw.Draw(strong_mask)
    for polygon in spec.strong_wear:
        strong_draw.polygon(polygon, fill=255)
    strong_mask = ImageChops.multiply(mask, strong_mask)

    output = Image.new("RGBA", spec.size, (0, 0, 0, 0))
    pixels = output.load()
    mask_pixels = mask.load()
    inner_pixels = inner.load()
    deep_pixels = deep.load()
    strong_pixels = strong_mask.load()
    visible = 0
    for y in range(spec.size[1]):
        for x in range(spec.size[0]):
            if mask_pixels[x, y] == 0:
                continue
            world_x = spec.world_origin[0] + x
            world_y = spec.world_origin[1] + y
            is_strong = strong_pixels[x, y] != 0
            base = grass_pixel(atlas, world_x, world_y)
            if spec.grass_only:
                pixels[x, y] = base + (255,)
            else:
                wear = terrain_pixel(source_colors, seed, is_strong)
                if is_strong:
                    weight = 120 if seed in (1, 2) else 100
                elif deep_pixels[x, y] != 0:
                    weight = 78
                elif inner_pixels[x, y] != 0:
                    weight = 58
                else:
                    weight = 28
                block_x = world_x // 4
                block_y = world_y // 4
                weight += ((block_x * 13 + block_y * 7 + seed * 17 + block_x * block_y * 3) % 11) - 5
                pixels[x, y] = blend(base, wear, max(18, min(112, weight)))
            visible += 1

    output_path = OUTPUT_ROOT / spec.filename
    output.save(output_path, compress_level=9)
    alpha = output.getchannel("A")
    partial_alpha = sum(
        1
        for y in range(spec.size[1])
        for x in range(spec.size[0])
        if alpha.getpixel((x, y)) not in (0, 255)
    )
    edge_coordinates = [(x, 0) for x in range(spec.size[0])]
    edge_coordinates += [(x, spec.size[1] - 1) for x in range(spec.size[0])]
    edge_coordinates += [(0, y) for y in range(1, spec.size[1] - 1)]
    edge_coordinates += [(spec.size[0] - 1, y) for y in range(1, spec.size[1] - 1)]
    edge_pixels = sum(1 for point in edge_coordinates if alpha.getpixel(point) != 0)
    transparent_rgb = sum(
        1
        for y in range(spec.size[1])
        for x in range(spec.size[0])
        if pixels[x, y][3] == 0 and pixels[x, y][:3] != (0, 0, 0)
    )
    connected_components = connected_component_count(mask)
    if partial_alpha != 0 or edge_pixels != 0 or transparent_rgb != 0 or connected_components != 1:
        raise RuntimeError(f"Surface audit failed for {spec.filename}.")
    return {
        "runtime_path": output_path.relative_to(ROOT).as_posix(),
        "runtime_sha256": sha256(output_path),
        "world_origin_xy": list(spec.world_origin),
        "runtime_dimensions": list(spec.size),
        "pivot": "top_left",
        "import_scale": 1.0,
        "visible_pixels": visible,
        "partial_alpha_pixels": partial_alpha,
        "transparent_rgb_pixels": transparent_rgb,
        "canvas_edge_pixels": edge_pixels,
        "connected_components": connected_components,
        "collision": "none_walkable_surface",
        "surface_role": "grass_road_shoulder" if spec.grass_only else "compacted_room_surface",
        "intent": spec.intent,
    }


def main() -> int:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    atlas = Image.open(GRASS_ATLAS).convert("RGBA")
    sources = [Image.open(TERRAIN_ROOT / name).convert("RGBA") for name in SOURCE_NAMES]
    source_colors = [approved_interior_average(source) for source in sources]
    records = {
        spec.room: build_surface(spec, atlas, source_colors, index + 1)
        for index, spec in enumerate(SPECS)
    }
    manifest = {
        "schema": "caden-wayfarer-landscape-surfaces-v1",
        "generator": Path(__file__).relative_to(ROOT).as_posix(),
        "generator_sha256": sha256(Path(__file__)),
        "scope": "Wayfarer's Approach production landscape pass; no additional library candidate.",
        "method": "Deterministic binary-alpha composites using exact live grass tiles and interior-derived color averages from approved wear textures; no rotation, scaling, blur, or antialiasing.",
        "source_files": {
            GRASS_ATLAS.relative_to(ROOT).as_posix(): sha256(GRASS_ATLAS),
            **{(TERRAIN_ROOT / name).relative_to(ROOT).as_posix(): sha256(TERRAIN_ROOT / name) for name in SOURCE_NAMES},
        },
        "surfaces": records,
    }
    METADATA_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"metadata={METADATA_PATH}")
    for room, record in records.items():
        print(f"surface={room}:{record['runtime_path']}:{record['runtime_sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
