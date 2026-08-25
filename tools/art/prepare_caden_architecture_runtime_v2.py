#!/usr/bin/env python3
"""Prepare cohesive Town Square architecture Runtime v2.

Runtime v2 preserves the approved source lineage, canvases, ground contacts,
scene centers, and collision footprints. It replaces the v1.1 tiled roof fill
with a continuous staggered shingle field, integrated ridges, connected eaves,
and source-palette details so no building reads as stitched roof modules.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
TOOL_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL_DIR))

import prepare_caden_architecture_runtime_v1 as v1  # noqa: E402
import prepare_caden_architecture_runtime_v1_1 as v1_1  # noqa: E402


OUTPUT_DIR = ROOT / "assets/environments/caden/architecture/town_square"
PREVIEW_DIR = ROOT / "docs/art/previews"
TERRAIN_PREVIEW = PREVIEW_DIR / "caden_terrain_runtime_v1_1_town_square_preview.png"
LINEUP_PREVIEW = PREVIEW_DIR / "caden_architecture_runtime_v2_lineup.png"
COMPARISON_PREVIEW = PREVIEW_DIR / "caden_architecture_v1_1_vs_v2_comparison.png"
TOWN_PREVIEW = PREVIEW_DIR / "caden_architecture_runtime_v2_town_square_preview.png"
MANIFEST_PATH = OUTPUT_DIR / "caden_architecture_runtime_v2_manifest.json"

EXPECTED_SOURCE_HASH = "82b60c3b0935e284b602f2a04713d7e4cf84ec4770bc7229ea80aeedc9195bf8"
EXPECTED_V1_1_HASHES = {
    "northwest": "55ee5c5c35e2f646e5b8b2295680111eba56e71168d5efed5b246ae9f2c0f770",
    "southwest": "790f375a5549e91af59950e91c648fc6c547fc2d1b092591dc33a56ba59b6780",
    "northeast": "22c8515c03591d869174392fe83ee2a90c909f6c58b70820fb9a6ea60792d1a6",
    "southeast": "68c8686dca3dae8f3173415a094c824f8601021ab51b6904968deef5e84ab487",
    "south": "0693a95af32429919b54c72b0d4e5817298d6bd37d06897d7009579bc5394caa",
}


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _runtime_v1_1_path(spec: v1_1.PolishSpec) -> Path:
    return OUTPUT_DIR / spec.output_name


def _runtime_v2_path(spec: v1_1.PolishSpec) -> Path:
    return OUTPUT_DIR / spec.output_name.replace("_v1_1.png", "_v2.png")


def _verify_inputs() -> dict[str, str]:
    hashes = {"source": _sha256(v1.SOURCE_PATH)}
    if hashes["source"] != EXPECTED_SOURCE_HASH:
        raise RuntimeError("The immutable architecture source master changed.")
    for spec in v1_1.POLISH_SPECS:
        current = _sha256(_runtime_v1_1_path(spec))
        hashes[f"v1_1_{spec.base.key}"] = current
        if current != EXPECTED_V1_1_HASHES[spec.base.key]:
            raise RuntimeError(f"Protected Runtime v1.1 changed: {_runtime_v1_1_path(spec)}")
    return hashes


def _roof_palette(component: Image.Image) -> dict[str, tuple[int, int, int, int]]:
    return {
        "outline": v1._palette_color(component, 0.04),
        "deep": v1._palette_color(component, 0.14),
        "shadow": v1._palette_color(component, 0.28),
        "base": v1._palette_color(component, 0.46),
        "light": v1._palette_color(component, 0.70),
        "glint": v1._palette_color(component, 0.84),
    }


def _continuous_roof(
    component: Image.Image,
    width: int,
    height: int,
    peak_bias: float,
    phase: int,
) -> Image.Image:
    palette = _roof_palette(component)
    roof = Image.new("RGBA", (width, height), palette["base"])
    draw = ImageDraw.Draw(roof)
    peak_x = round(width * peak_bias)
    shoulder_y = max(17, height // 3)
    bottom_y = height - 4

    # One continuous staggered shingle field. Short vertical joints never form
    # the long repeated module dividers present in Runtime v1.1.
    for row_index, y in enumerate(range(shoulder_y - 4, bottom_y, 4)):
        row_color = palette["shadow"] if row_index % 2 == 0 else palette["deep"]
        draw.line((2, y, width - 3, y), fill=row_color, width=1)
        offset = (phase + (row_index % 2) * 5) % 10
        for x in range(offset, width, 10):
            draw.line((x, y + 1, x, min(bottom_y - 1, y + 3)), fill=palette["shadow"], width=1)
            if x + 1 < width:
                draw.point((x + 1, y + 1), fill=palette["light"])

    # Upper slopes use diagonal shingle courses that converge on the ridge.
    for y in range(6, shoulder_y, 4):
        half_span = round((y - 2) * max(peak_x - 4, width - peak_x - 4) / max(1, shoulder_y - 2))
        left = max(3, peak_x - half_span)
        right = min(width - 4, peak_x + half_span)
        draw.line((left, y, right, y), fill=palette["shadow"], width=1)
        for x in range(left + ((phase + y) % 9), right, 9):
            draw.point((x, min(shoulder_y - 1, y + 1)), fill=palette["light"])

    mask = Image.new("L", (width, height), 0)
    mask_draw = ImageDraw.Draw(mask)
    silhouette = (
        (peak_x, 2),
        (width - 4, shoulder_y),
        (width - 4, bottom_y),
        (4, bottom_y),
        (4, shoulder_y),
    )
    mask_draw.polygon(silhouette, fill=255)
    roof.putalpha(mask)
    draw = ImageDraw.Draw(roof)
    draw.line((*silhouette, silhouette[0]), fill=palette["outline"], width=2)
    draw.line((peak_x - 1, 3, peak_x - 1, shoulder_y + 2), fill=palette["glint"], width=1)
    draw.line((peak_x, 3, peak_x, shoulder_y + 3), fill=palette["deep"], width=2)
    draw.line((5, bottom_y - 2, width - 5, bottom_y - 2), fill=palette["outline"], width=2)
    return v1._alpha_cleanup(roof)


def _continuous_front_gable(component: Image.Image, width: int, height: int, phase: int) -> Image.Image:
    palette = _roof_palette(component)
    gable = Image.new("RGBA", (width, height), palette["base"])
    draw = ImageDraw.Draw(gable)
    center = width // 2
    shoulder = height // 2
    bottom = height - 3
    for row_index, y in enumerate(range(shoulder - 3, bottom, 4)):
        draw.line((2, y, width - 3, y), fill=palette["shadow"], width=1)
        offset = (phase + row_index * 5) % 10
        for x in range(offset, width, 10):
            draw.line((x, y + 1, x, min(bottom - 1, y + 3)), fill=palette["deep"], width=1)
    mask = Image.new("L", (width, height), 0)
    mask_draw = ImageDraw.Draw(mask)
    points = ((center, 1), (width - 3, shoulder), (width - 3, bottom), (3, bottom), (3, shoulder))
    mask_draw.polygon(points, fill=255)
    gable.putalpha(mask)
    draw = ImageDraw.Draw(gable)
    draw.line((*points, points[0]), fill=palette["outline"], width=2)
    draw.line((center - 1, 2, center - 1, shoulder + 2), fill=palette["glint"], width=1)
    draw.line((center, 2, center, shoulder + 2), fill=palette["deep"], width=2)
    return v1._alpha_cleanup(gable)


def _compose(source: Image.Image, spec: v1_1.PolishSpec, phase: int) -> Image.Image:
    base = spec.base
    prior = Image.open(_runtime_v1_1_path(spec)).convert("RGBA")
    canvas = Image.new("RGBA", base.canvas, (0, 0, 0, 0))

    # Preserve the approved, collision-aligned façade, foundation, door, and
    # porch from Runtime v1.1 while replacing the entire roof/eave assembly.
    facade_top = spec.wall_top
    canvas.alpha_composite(prior.crop((0, facade_top, prior.width, prior.height)), (0, facade_top))

    components = {name: v1._source_component(source, name) for name in v1.SOURCE_CROPS}
    roof_width = base.footprint[0] + spec.overhang * 2
    roof = _continuous_roof(components[base.roof_source], roof_width, spec.roof_height, spec.peak_bias, phase)
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
        gable = _continuous_front_gable(components[base.roof_source], gable_width, gable_height, phase + 3)
        canvas.alpha_composite(gable, (gable_x, gable_y))

    draw = ImageDraw.Draw(canvas)
    timber_dark = v1._palette_color(components["wall_braced"], 0.06)
    timber_mid = v1._palette_color(components["wall_braced"], 0.30)
    eave_x = (base.canvas[0] - base.footprint[0]) // 2 - 4
    eave_width = base.footprint[0] + 8
    eave_y = roof_bottom - 2
    draw.rectangle((eave_x, eave_y, eave_x + eave_width - 1, eave_y + 5), fill=timber_dark)
    draw.line((eave_x + 2, eave_y, eave_x + eave_width - 3, eave_y), fill=timber_mid, width=1)
    draw.line((eave_x + 5, eave_y + 5, eave_x + eave_width - 6, eave_y + 5), fill=timber_mid, width=1)

    if base.chimney_side:
        chimney = v1._chimney_layer(components["stone_foundation"], 30)
        chimney_x = roof_x + 28 if base.chimney_side == "left" else roof_x + roof_width - 42
        canvas.alpha_composite(chimney, (chimney_x, spec.roof_y + 7))

    return v1._alpha_cleanup(canvas)


def _validate(image: Image.Image, spec: v1_1.PolishSpec) -> dict[str, object]:
    base = spec.base
    if image.size != base.canvas:
        raise RuntimeError(f"{base.key}: canvas changed")
    alpha = image.getchannel("A")
    if not set(alpha.get_flattened_data()).issubset({0, 255}):
        raise RuntimeError(f"{base.key}: non-binary alpha")
    join = v1_1._join_bounds(spec)
    for y in range(join[1], join[3]):
        for x in range(join[0], join[2]):
            if alpha.getpixel((x, y)) == 0:
                raise RuntimeError(f"{base.key}: transparent roof/façade join at {(x, y)}")
    bounds = alpha.getbbox()
    if bounds is None or bounds[3] > base.ground_line + 4:
        raise RuntimeError(f"{base.key}: invalid ground contact {bounds}")
    return {
        "canvas": list(image.size),
        "visible_bounds": list(bounds),
        "ground_line": base.ground_line,
        "collision_footprint": list(base.footprint),
        "scene_center": list(base.scene_center),
        "join_bounds": list(join),
        "binary_alpha": True,
        "continuous_roof_field": True,
    }


def _scene_top_left(spec: v1_1.PolishSpec) -> tuple[int, int]:
    base = spec.base
    sprite_position_y = base.footprint[1] // 2 - base.ground_line + base.canvas[1] // 2
    return base.scene_center[0] - base.canvas[0] // 2, base.scene_center[1] + sprite_position_y - base.canvas[1] // 2


def _write_lineup(buildings: dict[str, Image.Image]) -> None:
    spacing = 24
    width = sum(buildings[spec.base.key].width for spec in v1_1.POLISH_SPECS) + spacing * 6
    preview = Image.new("RGBA", (width, 208), (35, 31, 28, 255))
    draw = ImageDraw.Draw(preview)
    x = spacing
    baseline = 174
    for spec in v1_1.POLISH_SPECS:
        image = buildings[spec.base.key]
        preview.alpha_composite(image, (x, baseline - spec.base.ground_line))
        draw.text((x + 4, 188), spec.base.label, fill=(242, 230, 205, 255))
        x += image.width + spacing
    preview.save(LINEUP_PREVIEW, optimize=False)


def _write_comparison(buildings: dict[str, Image.Image]) -> None:
    panel_width = 224
    preview = Image.new("RGBA", (panel_width * 5, 384), (35, 31, 28, 255))
    draw = ImageDraw.Draw(preview)
    draw.text((12, 8), "Runtime v1.1: repeated roof sections", fill=(226, 192, 154, 255))
    draw.text((12, 198), "Runtime v2: continuous staggered shingles / integrated ridge", fill=(210, 236, 218, 255))
    for index, spec in enumerate(v1_1.POLISH_SPECS):
        center_x = index * panel_width + panel_width // 2
        before = Image.open(_runtime_v1_1_path(spec)).convert("RGBA")
        preview.alpha_composite(before, (center_x - before.width // 2, 180 - spec.base.ground_line))
        after = buildings[spec.base.key]
        preview.alpha_composite(after, (center_x - after.width // 2, 372 - spec.base.ground_line))
    preview.save(COMPARISON_PREVIEW, optimize=False)


def _write_town_preview(buildings: dict[str, Image.Image]) -> None:
    preview = Image.open(TERRAIN_PREVIEW).convert("RGBA")
    shadow_layer = Image.new("RGBA", preview.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_layer)
    for spec in v1_1.POLISH_SPECS:
        v1_1._draw_contact_shadow(shadow_draw, spec.base.scene_center, spec.base.footprint)
    preview.alpha_composite(shadow_layer)
    for spec in sorted(v1_1.POLISH_SPECS, key=lambda item: item.base.scene_center[1]):
        preview.alpha_composite(buildings[spec.base.key], _scene_top_left(spec))
    preview.save(TOWN_PREVIEW, optimize=False)


def main() -> int:
    protected = _verify_inputs()
    source = Image.open(v1.SOURCE_PATH).convert("RGBA")
    buildings: dict[str, Image.Image] = {}
    validations: dict[str, dict[str, object]] = {}
    for index, spec in enumerate(v1_1.POLISH_SPECS):
        image = _compose(source, spec, phase=index * 2)
        validation = _validate(image, spec)
        output_path = _runtime_v2_path(spec)
        image.save(output_path, optimize=False)
        validation["path"] = output_path.relative_to(ROOT).as_posix()
        validation["sha256"] = _sha256(output_path)
        validations[spec.base.key] = validation
        buildings[spec.base.key] = image

    _write_lineup(buildings)
    _write_comparison(buildings)
    _write_town_preview(buildings)
    manifest = {
        "schema": "caden-architecture-runtime-v2",
        "protected_inputs": protected,
        "method": "source-palette continuous staggered shingle field over protected Runtime v1.1 façades",
        "generated_buildings": validations,
        "previews": {
            "lineup": LINEUP_PREVIEW.relative_to(ROOT).as_posix(),
            "comparison": COMPARISON_PREVIEW.relative_to(ROOT).as_posix(),
            "town_square": TOWN_PREVIEW.relative_to(ROOT).as_posix(),
        },
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
