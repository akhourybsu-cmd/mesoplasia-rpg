#!/usr/bin/env python3
"""Prepare five visual-only Caden Town Square architecture sprites.

The architecture master and Terrain Runtime v1.1 are protected read-only inputs.
All source reductions use exact 3:1 nearest-neighbor scaling, hard alpha cleanup,
and deterministic compositing.
"""

from __future__ import annotations

import argparse
import colorsys
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageStat


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = REPOSITORY_ROOT / "assets/source_art/caden/architecture/caden_architecture_master_v1.png"
TERRAIN_PATH = REPOSITORY_ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png"
TERRAIN_PREVIEW_PATH = REPOSITORY_ROOT / "docs/art/previews/caden_terrain_runtime_v1_1_town_square_preview.png"
OUTPUT_DIRECTORY = REPOSITORY_ROOT / "assets/environments/caden/architecture/town_square"
PREVIEW_DIRECTORY = REPOSITORY_ROOT / "docs/art/previews"
LINEUP_PREVIEW_PATH = PREVIEW_DIRECTORY / "caden_architecture_runtime_v1_lineup.png"
FOOTPRINT_PREVIEW_PATH = PREVIEW_DIRECTORY / "caden_architecture_runtime_v1_footprint_overlay.png"
TOWN_SQUARE_PREVIEW_PATH = PREVIEW_DIRECTORY / "caden_architecture_runtime_v1_town_square_preview.png"

EXPECTED_SOURCE_SHA256 = "82b60c3b0935e284b602f2a04713d7e4cf84ec4770bc7229ea80aeedc9195bf8"
EXPECTED_TERRAIN_SHA256 = "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a"
SOURCE_SIZE = (1448, 1086)
SCALE_FACTOR = 3


SOURCE_CROPS: dict[str, tuple[int, int, int, int]] = {
    "roof_slate_blue": (13, 5, 96, 96),
    "roof_slate_blue_02": (119, 5, 96, 96),
    "roof_clay": (225, 5, 96, 96),
    "roof_moss": (332, 5, 96, 96),
    "roof_warm_brown": (438, 5, 96, 96),
    "wall_plain": (13, 282, 96, 96),
    "wall_braced": (119, 282, 96, 96),
    "wall_window_a": (225, 282, 96, 96),
    "wall_window_b": (332, 282, 96, 96),
    "stone_foundation": (973, 282, 96, 96),
    "door_a": (13, 400, 96, 144),
    "door_b": (119, 400, 96, 144),
    "door_c": (225, 400, 96, 144),
    "door_d": (332, 400, 96, 144),
    "door_e": (438, 400, 96, 144),
}


@dataclass(frozen=True)
class BuildingSpec:
    key: str
    label: str
    output_name: str
    scene_center: tuple[int, int]
    footprint: tuple[int, int]
    canvas: tuple[int, int]
    ground_line: int
    roof_source: str
    door_source: str
    door_slot: int
    wall_sources: tuple[str, ...]
    chimney_side: str | None
    porch_width: int
    window_count: int


BUILDINGS: tuple[BuildingSpec, ...] = (
    BuildingSpec(
        "northwest", "A", "town_square_building_northwest_v1.png", (144, 112), (160, 96),
        (192, 160), 144, "roof_slate_blue", "door_a", 2,
        ("wall_plain", "wall_window_a", "wall_plain", "wall_window_b", "wall_braced"),
        "left", 48, 2,
    ),
    BuildingSpec(
        "southwest", "B", "town_square_building_southwest_v1.png", (144, 560), (160, 96),
        (192, 160), 144, "roof_moss", "door_b", 1,
        ("wall_window_b", "wall_plain", "wall_braced", "wall_window_a", "wall_plain"),
        None, 64, 2,
    ),
    BuildingSpec(
        "northeast", "C", "town_square_building_northeast_v1.png", (832, 208), (128, 96),
        (160, 160), 144, "roof_clay", "door_c", 2,
        ("wall_window_a", "wall_plain", "wall_plain", "wall_window_b"),
        "right", 40, 2,
    ),
    BuildingSpec(
        "southeast", "D", "town_square_building_southeast_v1.png", (816, 560), (160, 96),
        (192, 160), 144, "roof_slate_blue_02", "door_d", 3,
        ("wall_braced", "wall_window_b", "wall_plain", "wall_plain", "wall_window_a"),
        "left", 48, 2,
    ),
    BuildingSpec(
        "south", "E", "town_square_building_south_v1.png", (352, 624), (128, 64),
        (160, 128), 112, "roof_warm_brown", "door_e", 2,
        ("wall_plain", "wall_window_a", "wall_plain", "wall_braced"),
        None, 32, 1,
    ),
)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _crop_box(reference: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    x, y, width, height = reference
    return x, y, x + width, y + height


def _alpha_cleanup(image: Image.Image, threshold: int = 112) -> Image.Image:
    result = image.convert("RGBA")
    cleaned: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in result.get_flattened_data():
        if alpha < threshold:
            cleaned.append((0, 0, 0, 0))
        else:
            cleaned.append((red, green, blue, 255))
    result.putdata(cleaned)
    return result


def _harmonize(image: Image.Image, saturation_scale: float = 0.90, value_scale: float = 0.95) -> Image.Image:
    result = image.convert("RGBA")
    adjusted: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in result.get_flattened_data():
        if alpha == 0:
            adjusted.append((0, 0, 0, 0))
            continue
        hue, saturation, value = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
        saturation = min(1.0, saturation * saturation_scale)
        value = min(1.0, value * value_scale)
        new_red, new_green, new_blue = colorsys.hsv_to_rgb(hue, saturation, value)
        adjusted.append((round(new_red * 255), round(new_green * 255), round(new_blue * 255), 255))
    result.putdata(adjusted)
    return _alpha_cleanup(ImageEnhance.Contrast(result).enhance(0.90))


def _source_component(source: Image.Image, name: str) -> Image.Image:
    x, y, width, height = SOURCE_CROPS[name]
    if width % SCALE_FACTOR or height % SCALE_FACTOR:
        raise RuntimeError(f"Source crop {name} is not divisible by {SCALE_FACTOR}: {(width, height)}")
    crop = source.crop(_crop_box(SOURCE_CROPS[name]))
    reduced = crop.resize((width // SCALE_FACTOR, height // SCALE_FACTOR), Image.Resampling.NEAREST)
    return _harmonize(_alpha_cleanup(reduced))


def _opaque_colors(image: Image.Image) -> list[tuple[int, int, int]]:
    return [(r, g, b) for r, g, b, a in image.get_flattened_data() if a == 255]


def _palette_color(image: Image.Image, percentile: float) -> tuple[int, int, int, int]:
    colors = _opaque_colors(image)
    if not colors:
        return (64, 48, 32, 255)
    colors.sort(key=lambda color: sum(color))
    return colors[min(len(colors) - 1, round((len(colors) - 1) * percentile))] + (255,)


def _tile_texture(texture: Image.Image, size: tuple[int, int]) -> Image.Image:
    result = Image.new("RGBA", size, (0, 0, 0, 0))
    for y in range(0, size[1], texture.height):
        for x in range(0, size[0], texture.width):
            result.alpha_composite(texture, (x, y))
    return result


def _roof_layer(component: Image.Image, width: int, compact: bool) -> Image.Image:
    height = 62 if not compact else 52
    texture = _tile_texture(component, (width, height))
    mask = Image.new("L", (width, height), 0)
    mask_draw = ImageDraw.Draw(mask)
    shoulder_y = 24 if not compact else 20
    bottom_y = height - 4
    mask_draw.polygon(((width // 2, 2), (width - 4, shoulder_y), (width - 4, bottom_y), (4, bottom_y), (4, shoulder_y)), fill=255)
    texture.putalpha(mask)
    draw = ImageDraw.Draw(texture)
    outline = _palette_color(component, 0.05)
    highlight = _palette_color(component, 0.78)
    points = [(width // 2, 2), (width - 4, shoulder_y), (width - 4, bottom_y), (4, bottom_y), (4, shoulder_y), (width // 2, 2)]
    draw.line(points, fill=outline, width=2)
    draw.line((width // 2, 3, width // 2, shoulder_y + 5), fill=highlight, width=1)
    draw.line((5, bottom_y - 1, width - 5, bottom_y - 1), fill=outline, width=2)
    return _alpha_cleanup(texture)


def _wall_layer(components: dict[str, Image.Image], spec: BuildingSpec, wall_top: int) -> Image.Image:
    footprint_width = spec.footprint[0]
    wall_height = spec.ground_line - wall_top - 12
    wall = Image.new("RGBA", (footprint_width, wall_height), (0, 0, 0, 0))
    plaster = _palette_color(components["wall_plain"], 0.72)
    ImageDraw.Draw(wall).rectangle((0, 0, footprint_width - 1, wall_height - 1), fill=plaster)
    for slot, source_name in enumerate(spec.wall_sources):
        panel = components[source_name]
        wall.alpha_composite(panel, (slot * 32, max(0, wall_height - panel.height)))
    timber = _palette_color(components["wall_braced"], 0.10)
    draw = ImageDraw.Draw(wall)
    for x in range(0, footprint_width + 1, 32):
        draw.rectangle((max(0, x - 1), 0, min(footprint_width - 1, x + 1), wall_height - 1), fill=timber)
    draw.rectangle((0, 0, footprint_width - 1, 2), fill=timber)
    return _alpha_cleanup(wall)


def _chimney_layer(stone: Image.Image, height: int = 30) -> Image.Image:
    chimney = Image.new("RGBA", (14, height), (0, 0, 0, 0))
    texture = _tile_texture(stone, (10, height - 3))
    chimney.alpha_composite(texture, (2, 3))
    draw = ImageDraw.Draw(chimney)
    dark = _palette_color(stone, 0.08)
    light = _palette_color(stone, 0.70)
    draw.rectangle((1, 2, 12, height - 1), outline=dark, width=2)
    draw.rectangle((0, 0, 13, 4), fill=dark)
    draw.line((3, 3, 10, 3), fill=light, width=1)
    return _alpha_cleanup(chimney)


def _compose_building(source: Image.Image, spec: BuildingSpec) -> Image.Image:
    components = {name: _source_component(source, name) for name in SOURCE_CROPS}
    canvas = Image.new("RGBA", spec.canvas, (0, 0, 0, 0))
    compact = spec.canvas[1] == 128
    wall_top = 58 if compact else 78
    footprint_x = (spec.canvas[0] - spec.footprint[0]) // 2

    wall = _wall_layer(components, spec, wall_top)
    canvas.alpha_composite(wall, (footprint_x, wall_top))

    foundation_height = 12
    foundation_y = spec.ground_line - foundation_height
    stone_strip = _tile_texture(components["stone_foundation"], (spec.footprint[0], foundation_height))
    canvas.alpha_composite(stone_strip, (footprint_x, foundation_y))

    door = components[spec.door_source]
    door_x = footprint_x + spec.door_slot * 32 + (32 - door.width) // 2
    door_y = spec.ground_line - door.height - 4
    canvas.alpha_composite(door, (door_x, door_y))

    roof_width = spec.footprint[0] + 16
    roof = _roof_layer(components[spec.roof_source], roof_width, compact)
    roof_x = (spec.canvas[0] - roof_width) // 2
    roof_y = 10 if compact else 12
    canvas.alpha_composite(roof, (roof_x, roof_y))

    if spec.chimney_side:
        chimney = _chimney_layer(components["stone_foundation"], 27 if compact else 32)
        if spec.chimney_side == "left":
            chimney_x = roof_x + 28
        else:
            chimney_x = roof_x + roof_width - 42
        canvas.alpha_composite(chimney, (chimney_x, roof_y + 8))

    porch_y = spec.ground_line - 6
    porch_x = spec.canvas[0] // 2 - spec.porch_width // 2
    draw = ImageDraw.Draw(canvas)
    wood_dark = _palette_color(components["wall_braced"], 0.10)
    wood_mid = _palette_color(components["wall_braced"], 0.46)
    draw.rectangle((porch_x, porch_y, porch_x + spec.porch_width - 1, spec.ground_line - 1), fill=wood_mid, outline=wood_dark, width=1)
    step_width = max(20, spec.porch_width - 12)
    step_x = spec.canvas[0] // 2 - step_width // 2
    draw.rectangle((step_x, spec.ground_line, step_x + step_width - 1, spec.ground_line + 3), fill=wood_dark)

    return _alpha_cleanup(canvas)


def _validate_building(image: Image.Image, spec: BuildingSpec) -> dict[str, object]:
    if image.size != spec.canvas:
        raise RuntimeError(f"{spec.label} canvas mismatch: {image.size} != {spec.canvas}")
    alpha = image.getchannel("A")
    values = set(alpha.get_flattened_data())
    if not values.issubset({0, 255}):
        raise RuntimeError(f"{spec.label} contains partial-alpha edge pixels: {sorted(values)[:8]}")
    if alpha.getpixel((0, 0)) != 0 or alpha.getpixel((image.width - 1, 0)) != 0:
        raise RuntimeError(f"{spec.label} does not retain transparent upper corners")
    bounds = alpha.getbbox()
    if bounds is None:
        raise RuntimeError(f"{spec.label} has no visible pixels")
    if bounds[3] > spec.ground_line + 4:
        raise RuntimeError(f"{spec.label} extends below its documented approach step allowance")
    return {"canvas": list(image.size), "visible_bounds": list(bounds), "ground_line": spec.ground_line}


def _write_building(source: Image.Image, spec: BuildingSpec) -> tuple[Image.Image, dict[str, object]]:
    image = _compose_building(source, spec)
    validation = _validate_building(image, spec)
    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT_DIRECTORY / spec.output_name, optimize=False)
    validation["sha256"] = _sha256(OUTPUT_DIRECTORY / spec.output_name)
    return image, validation


def _shadow_polygon(draw: ImageDraw.ImageDraw, center: tuple[int, int], footprint: tuple[int, int]) -> None:
    half_width = footprint[0] // 2 - 8
    y = center[1] + footprint[1] // 2 - 12
    draw.polygon(((center[0] - half_width + 4, y), (center[0] + half_width, y), (center[0] + half_width + 6, y + 16), (center[0] - half_width + 10, y + 16)), fill=(37, 31, 25, 84))


def _scene_sprite_top_left(spec: BuildingSpec) -> tuple[int, int]:
    sprite_position_y = spec.footprint[1] // 2 - spec.ground_line + spec.canvas[1] // 2
    return spec.scene_center[0] - spec.canvas[0] // 2, spec.scene_center[1] + sprite_position_y - spec.canvas[1] // 2


def _write_lineup(buildings: dict[str, Image.Image]) -> None:
    background = (43, 39, 34, 255)
    spacing = 24
    width = sum(buildings[spec.key].width for spec in BUILDINGS) + spacing * (len(BUILDINGS) + 1)
    height = 208
    preview = Image.new("RGBA", (width, height), background)
    draw = ImageDraw.Draw(preview)
    x = spacing
    baseline = 174
    for spec in BUILDINGS:
        image = buildings[spec.key]
        y = baseline - spec.ground_line
        preview.alpha_composite(image, (x, y))
        draw.text((x + image.width // 2 - 4, 188), spec.label, fill=(245, 235, 210, 255))
        x += image.width + spacing
    PREVIEW_DIRECTORY.mkdir(parents=True, exist_ok=True)
    preview.save(LINEUP_PREVIEW_PATH, optimize=False)


def _write_footprint_preview(buildings: dict[str, Image.Image]) -> None:
    panel_width = 256
    panel_height = 224
    preview = Image.new("RGBA", (panel_width * len(BUILDINGS), panel_height), (43, 39, 34, 255))
    draw = ImageDraw.Draw(preview)
    for index, spec in enumerate(BUILDINGS):
        origin_x = index * panel_width
        center = (origin_x + panel_width // 2, 130)
        image = buildings[spec.key]
        top_left = (center[0] - image.width // 2, center[1] + spec.footprint[1] // 2 - spec.ground_line)
        preview.alpha_composite(image, top_left)
        footprint_box = (
            center[0] - spec.footprint[0] // 2,
            center[1] - spec.footprint[1] // 2,
            center[0] + spec.footprint[0] // 2 - 1,
            center[1] + spec.footprint[1] // 2 - 1,
        )
        draw.rectangle(footprint_box, outline=(255, 94, 94, 255), width=1)
        draw.line((origin_x + 8, center[1] + spec.footprint[1] // 2, origin_x + panel_width - 8, center[1] + spec.footprint[1] // 2), fill=(255, 221, 98, 255), width=1)
        draw.line((center[0], center[1] + spec.footprint[1] // 2 + 4, center[0], center[1] + spec.footprint[1] // 2 + 20), fill=(114, 210, 255, 255), width=2)
        draw.text((origin_x + 8, 8), f"{spec.label}: {spec.footprint[0]}x{spec.footprint[1]}", fill=(245, 235, 210, 255))
        draw.text((origin_x + 8, 204), "red collision / yellow ground / blue approach", fill=(210, 200, 180, 255))
    preview.save(FOOTPRINT_PREVIEW_PATH, optimize=False)


def _write_town_square_preview(buildings: dict[str, Image.Image]) -> None:
    preview = Image.open(TERRAIN_PREVIEW_PATH).convert("RGBA")
    shadow_layer = Image.new("RGBA", preview.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_layer)
    for spec in BUILDINGS:
        _shadow_polygon(shadow_draw, spec.scene_center, spec.footprint)
    preview.alpha_composite(shadow_layer)
    for spec in sorted(BUILDINGS, key=lambda item: item.scene_center[1]):
        preview.alpha_composite(buildings[spec.key], _scene_sprite_top_left(spec))
    preview.save(TOWN_SQUARE_PREVIEW_PATH, optimize=False)


def _material_metrics(image: Image.Image) -> dict[str, float]:
    opaque = Image.new("RGB", image.size, (255, 255, 255))
    opaque.paste(image.convert("RGB"), mask=image.getchannel("A"))
    stat = ImageStat.Stat(opaque.convert("L"))
    return {"grayscale_mean_on_white": round(stat.mean[0], 2), "grayscale_stddev_on_white": round(stat.stddev[0], 2)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prototype-only", action="store_true")
    args = parser.parse_args()

    source_hash = _sha256(SOURCE_PATH)
    terrain_hash = _sha256(TERRAIN_PATH)
    if source_hash != EXPECTED_SOURCE_SHA256:
        raise SystemExit(f"Architecture source hash mismatch: expected {EXPECTED_SOURCE_SHA256}, got {source_hash}")
    if terrain_hash != EXPECTED_TERRAIN_SHA256:
        raise SystemExit(f"Terrain Runtime v1.1 hash mismatch: expected {EXPECTED_TERRAIN_SHA256}, got {terrain_hash}")

    source = Image.open(SOURCE_PATH).convert("RGBA")
    if source.size != SOURCE_SIZE:
        raise SystemExit(f"Architecture source dimensions changed: expected {SOURCE_SIZE}, got {source.size}")

    selected = BUILDINGS[:1] if args.prototype_only else BUILDINGS
    buildings: dict[str, Image.Image] = {}
    validations: dict[str, dict[str, object]] = {}
    for spec in selected:
        buildings[spec.key], validations[spec.key] = _write_building(source, spec)

    if not args.prototype_only:
        _write_lineup(buildings)
        _write_footprint_preview(buildings)
        _write_town_square_preview(buildings)

    summary = {
        "source_sha256": source_hash,
        "terrain_v1_1_sha256": terrain_hash,
        "scale_method": "3:1 nearest-neighbor",
        "prototype_only": args.prototype_only,
        "buildings": validations,
        "metrics": {key: _material_metrics(image) for key, image in buildings.items()},
    }
    print(json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main()
