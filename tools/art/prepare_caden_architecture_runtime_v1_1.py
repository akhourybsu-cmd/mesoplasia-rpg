#!/usr/bin/env python3
"""Prepare the connected Caden Town Square architecture polish set.

Runtime v1.1 is a non-destructive derivative of the same protected source
components used by Runtime v1. Roofs overlap framed upper facades, receive a
crisp eave band, and use less mechanical repetition. Runtime v1, the source
master, and Terrain Runtime v1.1 are verified before any output is written.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageStat

import prepare_caden_architecture_runtime_v1 as v1


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIRECTORY = REPOSITORY_ROOT / "assets/environments/caden/architecture/town_square"
PREVIEW_DIRECTORY = REPOSITORY_ROOT / "docs/art/previews"
TERRAIN_PREVIEW_PATH = PREVIEW_DIRECTORY / "caden_terrain_runtime_v1_1_town_square_preview.png"
LINEUP_PREVIEW_PATH = PREVIEW_DIRECTORY / "caden_architecture_runtime_v1_1_lineup.png"
FOOTPRINT_PREVIEW_PATH = PREVIEW_DIRECTORY / "caden_architecture_runtime_v1_1_footprint_overlay.png"
COMPARISON_PREVIEW_PATH = PREVIEW_DIRECTORY / "caden_architecture_v1_vs_v1_1_comparison.png"
TOWN_SQUARE_PREVIEW_PATH = PREVIEW_DIRECTORY / "caden_architecture_runtime_v1_1_town_square_preview.png"

EXPECTED_PROJECT_SHA256 = "b560718fd3141c70c318a2843b409b95490b876c139bd77104c125ce181c91f0"
EXPECTED_V1_HASHES = {
    "northwest": "f493d5ac99bb9c81e04f940244c6e79fdabad1f2303abea8f3557ae58048418f",
    "southwest": "e8d418c26653085d63f8bb434068908f3368508a33ae467346ce44a13adfb335",
    "northeast": "023082b67d5924c542c250c5080f35410a3c5c9b69a5ca5cc9e6534b100b1460",
    "southeast": "cd0e3baaf0ad75ca29b94d2651c0ad7af746bf9db5cbdb3e8c07d71bed63d1dd",
    "south": "bcd2289ef3685ac2205664fd90ce617657624be48641a9026b69baef64ec7456",
}


@dataclass(frozen=True)
class PolishSpec:
    base: v1.BuildingSpec
    output_name: str
    roof_y: int
    roof_height: int
    wall_top: int
    overlap: int
    overhang: int
    peak_bias: float
    front_gable: str | None
    frame_pattern: str
    upper_window: bool


POLISH_SPECS: tuple[PolishSpec, ...] = (
    PolishSpec(v1.BUILDINGS[0], "town_square_building_northwest_v1_1.png", 10, 64, 65, 6, 10, 0.50, "center", "symmetric", True),
    PolishSpec(v1.BUILDINGS[1], "town_square_building_southwest_v1_1.png", 12, 60, 65, 4, 8, 0.44, None, "posts", False),
    PolishSpec(v1.BUILDINGS[2], "town_square_building_northeast_v1_1.png", 10, 64, 65, 6, 12, 0.50, "center", "compact", True),
    PolishSpec(v1.BUILDINGS[3], "town_square_building_southeast_v1_1.png", 8, 66, 65, 6, 10, 0.54, "right", "asymmetric", False),
    PolishSpec(v1.BUILDINGS[4], "town_square_building_south_v1_1.png", 8, 54, 55, 4, 6, 0.50, None, "simple", False),
)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _v1_path(spec: PolishSpec) -> Path:
    return OUTPUT_DIRECTORY / spec.base.output_name


def _verify_protected_inputs() -> dict[str, str]:
    hashes = {
        "source": _sha256(v1.SOURCE_PATH),
        "terrain_v1_1": _sha256(v1.TERRAIN_PATH),
        "project": _sha256(REPOSITORY_ROOT / "project.godot"),
    }
    if hashes["source"] != v1.EXPECTED_SOURCE_SHA256:
        raise SystemExit("Architecture source master hash changed.")
    if hashes["terrain_v1_1"] != v1.EXPECTED_TERRAIN_SHA256:
        raise SystemExit("Terrain Runtime v1.1 hash changed.")
    if hashes["project"] != EXPECTED_PROJECT_SHA256:
        raise SystemExit("project.godot changed from the v1.1 preparation baseline.")
    for spec in POLISH_SPECS:
        current_hash = _sha256(_v1_path(spec))
        hashes[f"v1_{spec.base.key}"] = current_hash
        if current_hash != EXPECTED_V1_HASHES[spec.base.key]:
            raise SystemExit(f"Protected Runtime v1 asset changed: {_v1_path(spec)}")
    return hashes


def _opaque_material(component: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Tile a cropped roof interior over a source-sampled opaque base."""
    interior = component.crop((4, 1, component.width - 4, component.height - 1))
    result = Image.new("RGBA", size, v1._palette_color(component, 0.42))
    for y in range(0, size[1], interior.height):
        for x in range(0, size[0], interior.width):
            result.alpha_composite(interior, (x, y))
    return result


def _roof_layer(component: Image.Image, width: int, height: int, peak_bias: float) -> Image.Image:
    material = _opaque_material(component, (width, height))
    mask = Image.new("L", (width, height), 0)
    draw_mask = ImageDraw.Draw(mask)
    peak_x = round(width * peak_bias)
    shoulder_y = max(18, height // 3)
    bottom_y = height - 4
    silhouette = ((peak_x, 2), (width - 4, shoulder_y), (width - 4, bottom_y), (4, bottom_y), (4, shoulder_y))
    draw_mask.polygon(silhouette, fill=255)
    material.putalpha(mask)

    draw = ImageDraw.Draw(material)
    dark = v1._palette_color(component, 0.06)
    mid_dark = v1._palette_color(component, 0.22)
    light = v1._palette_color(component, 0.78)
    draw.line((*silhouette, silhouette[0]), fill=dark, width=2)
    draw.line((peak_x, 3, peak_x, shoulder_y + 3), fill=light, width=1)
    draw.line((5, bottom_y - 1, width - 5, bottom_y - 1), fill=mid_dark, width=2)

    # Sparse low-contrast roof divisions retain scale without the v1 fence rhythm.
    divider_spacing = 48
    divider_offset = 26
    for x in range(divider_offset, width - 16, divider_spacing):
        roof_top = round(2 + abs(x - peak_x) * (shoulder_y - 2) / max(1, max(peak_x - 4, width - 4 - peak_x)))
        draw.line((x, roof_top + 8, x, bottom_y - 4), fill=mid_dark, width=1)
    return v1._alpha_cleanup(material)


def _facade_layer(components: dict[str, Image.Image], spec: PolishSpec, foundation_y: int) -> Image.Image:
    base = spec.base
    width = base.footprint[0]
    height = foundation_y - spec.wall_top
    plaster = v1._palette_color(components["wall_plain"], 0.70)
    wall = Image.new("RGBA", (width, height), plaster)

    # Source wall panels establish the lower facade; the upper zone receives
    # a distinct timber support rhythm rather than an uninterrupted plaster band.
    panel_y = max(12, height - 34)
    for slot, source_name in enumerate(base.wall_sources):
        wall.alpha_composite(components[source_name], (slot * 32, panel_y))

    draw = ImageDraw.Draw(wall)
    timber_dark = v1._palette_color(components["wall_braced"], 0.08)
    timber_mid = v1._palette_color(components["wall_braced"], 0.32)
    draw.rectangle((0, 0, width - 1, 3), fill=timber_dark)
    draw.rectangle((0, min(height - 1, 18), width - 1, min(height - 1, 21)), fill=timber_mid)
    draw.rectangle((0, height - 4, width - 1, height - 1), fill=timber_dark)
    for x in range(0, width + 1, 32):
        draw.rectangle((max(0, x - 1), 0, min(width - 1, x + 1), height - 1), fill=timber_dark)

    center = width // 2
    upper_bottom = min(height - 1, 21)
    if spec.frame_pattern in {"symmetric", "compact"}:
        span = 32 if spec.frame_pattern == "symmetric" else 24
        draw.line((center - span, upper_bottom, center, 1), fill=timber_dark, width=2)
        draw.line((center, 1, center + span, upper_bottom), fill=timber_dark, width=2)
    elif spec.frame_pattern == "asymmetric":
        draw.line((width // 2 - 40, upper_bottom, width // 2 - 12, 1), fill=timber_dark, width=2)
        draw.line((width // 2 + 8, 1, width // 2 + 42, upper_bottom), fill=timber_dark, width=2)
    elif spec.frame_pattern == "simple":
        draw.line((center - 20, upper_bottom, center, 3), fill=timber_dark, width=2)
        draw.line((center, 3, center + 20, upper_bottom), fill=timber_dark, width=2)

    if spec.upper_window:
        source_window = components["wall_window_a"]
        small_window = source_window.crop((8, 7, 24, 23))
        window_x = center - small_window.width // 2
        window_y = 3
        wall.alpha_composite(small_window, (window_x, window_y))
        draw = ImageDraw.Draw(wall)
        draw.rectangle((window_x - 1, window_y - 1, window_x + small_window.width, window_y + small_window.height), outline=timber_dark, width=1)
    return v1._alpha_cleanup(wall)


def _front_gable_layer(component: Image.Image, width: int, height: int) -> Image.Image:
    material = _opaque_material(component, (width, height))
    mask = Image.new("L", (width, height), 0)
    draw_mask = ImageDraw.Draw(mask)
    points = ((width // 2, 1), (width - 3, height // 2), (width - 3, height - 3), (3, height - 3), (3, height // 2))
    draw_mask.polygon(points, fill=255)
    material.putalpha(mask)
    draw = ImageDraw.Draw(material)
    dark = v1._palette_color(component, 0.07)
    light = v1._palette_color(component, 0.76)
    draw.line((*points, points[0]), fill=dark, width=2)
    draw.line((width // 2, 2, width // 2, height // 2 + 3), fill=light, width=1)
    return v1._alpha_cleanup(material)


def _compose_building(source: Image.Image, spec: PolishSpec) -> Image.Image:
    base = spec.base
    components = {name: v1._source_component(source, name) for name in v1.SOURCE_CROPS}
    canvas = Image.new("RGBA", base.canvas, (0, 0, 0, 0))
    footprint_x = (base.canvas[0] - base.footprint[0]) // 2
    foundation_height = 12
    foundation_y = base.ground_line - foundation_height

    facade = _facade_layer(components, spec, foundation_y)
    canvas.alpha_composite(facade, (footprint_x, spec.wall_top))

    stone_strip = v1._tile_texture(components["stone_foundation"], (base.footprint[0], foundation_height))
    canvas.alpha_composite(stone_strip, (footprint_x, foundation_y))

    door = components[base.door_source]
    door_x = footprint_x + base.door_slot * 32 + (32 - door.width) // 2
    door_y = base.ground_line - door.height - 4
    canvas.alpha_composite(door, (door_x, door_y))

    roof_width = base.footprint[0] + spec.overhang * 2
    roof = _roof_layer(components[base.roof_source], roof_width, spec.roof_height, spec.peak_bias)
    roof_x = (base.canvas[0] - roof_width) // 2
    canvas.alpha_composite(roof, (roof_x, spec.roof_y))
    roof_bottom = spec.roof_y + spec.roof_height - 4

    if spec.front_gable:
        gable_width = 58 if base.footprint[0] == 160 else 50
        gable_height = 46 if base.canvas[1] == 160 else 38
        gable_x = base.canvas[0] // 2 - gable_width // 2
        if spec.front_gable == "right":
            gable_x += 30
        gable_y = roof_bottom - gable_height + 8
        gable = _front_gable_layer(components[base.roof_source], gable_width, gable_height)
        canvas.alpha_composite(gable, (gable_x, gable_y))

    # The eave bridges roof and facade and stays above all doors and windows.
    draw = ImageDraw.Draw(canvas)
    timber_dark = v1._palette_color(components["wall_braced"], 0.06)
    timber_mid = v1._palette_color(components["wall_braced"], 0.28)
    eave_x = footprint_x - 3
    eave_width = base.footprint[0] + 6
    eave_y = roof_bottom - 2
    draw.rectangle((eave_x, eave_y, eave_x + eave_width - 1, eave_y + 4), fill=timber_dark)
    draw.line((eave_x + 2, eave_y, eave_x + eave_width - 3, eave_y), fill=timber_mid, width=1)

    if base.chimney_side:
        chimney = v1._chimney_layer(components["stone_foundation"], 30)
        chimney_x = roof_x + 28 if base.chimney_side == "left" else roof_x + roof_width - 42
        canvas.alpha_composite(chimney, (chimney_x, spec.roof_y + 7))

    porch_y = base.ground_line - 6
    porch_x = base.canvas[0] // 2 - base.porch_width // 2
    draw = ImageDraw.Draw(canvas)
    wood_dark = v1._palette_color(components["wall_braced"], 0.08)
    wood_mid = v1._palette_color(components["wall_braced"], 0.42)
    draw.rectangle((porch_x, porch_y, porch_x + base.porch_width - 1, base.ground_line - 1), fill=wood_mid, outline=wood_dark, width=1)
    step_width = max(20, base.porch_width - 12)
    step_x = base.canvas[0] // 2 - step_width // 2
    draw.rectangle((step_x, base.ground_line, step_x + step_width - 1, base.ground_line + 3), fill=wood_dark)
    return v1._alpha_cleanup(canvas)


def _join_bounds(spec: PolishSpec) -> tuple[int, int, int, int]:
    base = spec.base
    footprint_x = (base.canvas[0] - base.footprint[0]) // 2
    roof_bottom = spec.roof_y + spec.roof_height - 4
    return footprint_x + 4, spec.wall_top, footprint_x + base.footprint[0] - 4, roof_bottom + 1


def _validate_building(image: Image.Image, spec: PolishSpec) -> dict[str, object]:
    base = spec.base
    if image.size != base.canvas:
        raise RuntimeError(f"{base.label} canvas changed: {image.size} != {base.canvas}")
    alpha = image.getchannel("A")
    if not set(alpha.get_flattened_data()).issubset({0, 255}):
        raise RuntimeError(f"{base.label} contains partial alpha")
    join = _join_bounds(spec)
    for y in range(join[1], join[3]):
        for x in range(join[0], join[2]):
            if alpha.getpixel((x, y)) == 0:
                raise RuntimeError(f"{base.label} has a transparent roof/facade gap at {(x, y)}")
    bounds = alpha.getbbox()
    if bounds is None or bounds[3] > base.ground_line + 4:
        raise RuntimeError(f"{base.label} has invalid visible bounds: {bounds}")
    actual_overlap = spec.roof_y + spec.roof_height - 4 - spec.wall_top + 1
    if actual_overlap != spec.overlap:
        raise RuntimeError(f"{base.label} overlap mismatch: {actual_overlap} != {spec.overlap}")
    return {
        "canvas": list(image.size),
        "visible_bounds": list(bounds),
        "ground_line": base.ground_line,
        "roof_facade_overlap": actual_overlap,
        "join_bounds": list(join),
    }


def _write_building(source: Image.Image, spec: PolishSpec) -> tuple[Image.Image, dict[str, object]]:
    image = _compose_building(source, spec)
    validation = _validate_building(image, spec)
    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIRECTORY / spec.output_name
    image.save(output_path, optimize=False)
    validation["sha256"] = _sha256(output_path)
    return image, validation


def _draw_contact_shadow(draw: ImageDraw.ImageDraw, center: tuple[int, int], footprint: tuple[int, int]) -> None:
    half_width = footprint[0] // 2 - 10
    south_edge = center[1] + footprint[1] // 2
    draw.polygon(
        ((center[0] - half_width + 3, south_edge - 10), (center[0] + half_width, south_edge - 10),
         (center[0] + half_width + 5, south_edge + 5), (center[0] - half_width + 9, south_edge + 5)),
        fill=(37, 31, 25, 96),
    )


def _scene_sprite_top_left(spec: PolishSpec) -> tuple[int, int]:
    base = spec.base
    sprite_position_y = base.footprint[1] // 2 - base.ground_line + base.canvas[1] // 2
    return base.scene_center[0] - base.canvas[0] // 2, base.scene_center[1] + sprite_position_y - base.canvas[1] // 2


def _write_lineup(buildings: dict[str, Image.Image]) -> None:
    background = (43, 39, 34, 255)
    spacing = 24
    width = sum(buildings[spec.base.key].width for spec in POLISH_SPECS) + spacing * (len(POLISH_SPECS) + 1)
    preview = Image.new("RGBA", (width, 208), background)
    draw = ImageDraw.Draw(preview)
    x = spacing
    baseline = 174
    for spec in POLISH_SPECS:
        image = buildings[spec.base.key]
        preview.alpha_composite(image, (x, baseline - spec.base.ground_line))
        draw.text((x + image.width // 2 - 4, 188), spec.base.label, fill=(245, 235, 210, 255))
        x += image.width + spacing
    preview.save(LINEUP_PREVIEW_PATH, optimize=False)


def _write_footprint_preview(buildings: dict[str, Image.Image]) -> None:
    panel_width = 256
    panel_height = 224
    preview = Image.new("RGBA", (panel_width * len(POLISH_SPECS), panel_height), (43, 39, 34, 255))
    draw = ImageDraw.Draw(preview)
    for index, spec in enumerate(POLISH_SPECS):
        base = spec.base
        origin_x = index * panel_width
        center = (origin_x + panel_width // 2, 130)
        _draw_contact_shadow(draw, center, base.footprint)
        image = buildings[base.key]
        top_left = (center[0] - image.width // 2, center[1] + base.footprint[1] // 2 - base.ground_line)
        preview.alpha_composite(image, top_left)
        collision = (center[0] - base.footprint[0] // 2, center[1] - base.footprint[1] // 2,
                     center[0] + base.footprint[0] // 2 - 1, center[1] + base.footprint[1] // 2 - 1)
        draw.rectangle(collision, outline=(255, 94, 94, 255), width=1)
        ground_y = center[1] + base.footprint[1] // 2
        draw.line((origin_x + 8, ground_y, origin_x + panel_width - 8, ground_y), fill=(255, 221, 98, 255), width=1)
        draw.line((center[0], ground_y + 4, center[0], ground_y + 20), fill=(114, 210, 255, 255), width=2)
        draw.text((origin_x + 8, 8), f"{base.label}: {base.footprint[0]}x{base.footprint[1]} / overlap {spec.overlap}px", fill=(245, 235, 210, 255))
        draw.text((origin_x + 8, 204), "red collision / yellow ground / blue approach", fill=(210, 200, 180, 255))
    preview.save(FOOTPRINT_PREVIEW_PATH, optimize=False)


def _write_comparison(buildings: dict[str, Image.Image]) -> None:
    panel_width = 256
    preview = Image.new("RGBA", (panel_width * len(POLISH_SPECS), 392), (43, 39, 34, 255))
    draw = ImageDraw.Draw(preview)
    draw.text((10, 8), "Runtime v1: detached roof / open plaster band", fill=(230, 202, 170, 255))
    draw.text((10, 198), "Runtime v1.1: connected eave / framed upper facade", fill=(230, 235, 210, 255))
    for index, spec in enumerate(POLISH_SPECS):
        base = spec.base
        x_center = index * panel_width + panel_width // 2
        v1_image = Image.open(_v1_path(spec)).convert("RGBA")
        preview.alpha_composite(v1_image, (x_center - v1_image.width // 2, 174 - base.ground_line))
        current = buildings[base.key]
        preview.alpha_composite(current, (x_center - current.width // 2, 368 - base.ground_line))
        draw.text((x_center - 4, 180), base.label, fill=(245, 235, 210, 255))
        draw.text((x_center - 4, 374), base.label, fill=(245, 235, 210, 255))
    preview.save(COMPARISON_PREVIEW_PATH, optimize=False)


def _write_town_square_preview(buildings: dict[str, Image.Image]) -> None:
    preview = Image.open(TERRAIN_PREVIEW_PATH).convert("RGBA")
    shadow_layer = Image.new("RGBA", preview.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_layer)
    for spec in POLISH_SPECS:
        _draw_contact_shadow(shadow_draw, spec.base.scene_center, spec.base.footprint)
    preview.alpha_composite(shadow_layer)
    for spec in sorted(POLISH_SPECS, key=lambda item: item.base.scene_center[1]):
        preview.alpha_composite(buildings[spec.base.key], _scene_sprite_top_left(spec))
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

    protected_hashes = _verify_protected_inputs()
    source = Image.open(v1.SOURCE_PATH).convert("RGBA")
    if source.size != v1.SOURCE_SIZE:
        raise SystemExit(f"Architecture source dimensions changed: {source.size}")

    selected = POLISH_SPECS[:1] if args.prototype_only else POLISH_SPECS
    buildings: dict[str, Image.Image] = {}
    validations: dict[str, dict[str, object]] = {}
    for spec in selected:
        buildings[spec.base.key], validations[spec.base.key] = _write_building(source, spec)

    if not args.prototype_only:
        _write_lineup(buildings)
        _write_footprint_preview(buildings)
        _write_comparison(buildings)
        _write_town_square_preview(buildings)

    print(json.dumps({
        "protected_hashes": protected_hashes,
        "prototype_only": args.prototype_only,
        "scale_method": "3:1 nearest-neighbor source reduction; no runtime rescaling",
        "buildings": validations,
        "metrics": {key: _material_metrics(image) for key, image in buildings.items()},
    }, sort_keys=True))


if __name__ == "__main__":
    main()
