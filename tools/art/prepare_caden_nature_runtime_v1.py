#!/usr/bin/env python3
"""Prepare the deterministic Caden Nature Runtime v1 derivative set.

The source master is presentation art whose background is encoded as very-low
alpha color. Runtime assets are exact crops, hard-alpha reconstructed, reduced
3:1 with nearest-neighbor sampling, and placed on predictable canvases.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source_art/caden/nature/caden_nature_master_v1.png"
OUT = ROOT / "assets/environments/caden/nature"
PREVIEWS = ROOT / "docs/art/previews"
ARCH_PREVIEW = PREVIEWS / "caden_architecture_runtime_v1_1_town_square_preview.png"

EXPECTED = {
    SOURCE: "611eb43cc137a63b477d982371e88d6d6d07997878a12bde8202ef26cfe93650",
    ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png": "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a",
    ROOT / "assets/environments/caden/architecture/town_square/town_square_building_northwest_v1_1.png": "55ee5c5c35e2f646e5b8b2295680111eba56e71168d5efed5b246ae9f2c0f770",
    ROOT / "assets/environments/caden/architecture/town_square/town_square_building_southwest_v1_1.png": "790f375a5549e91af59950e91c648fc6c547fc2d1b092591dc33a56ba59b6780",
    ROOT / "assets/environments/caden/architecture/town_square/town_square_building_northeast_v1_1.png": "22c8515c03591d869174392fe83ee2a90c909f6c58b70820fb9a6ea60792d1a6",
    ROOT / "assets/environments/caden/architecture/town_square/town_square_building_southeast_v1_1.png": "68c8686dca3dae8f3173415a094c824f8601021ab51b6904968deef5e84ab487",
    ROOT / "assets/environments/caden/architecture/town_square/town_square_building_south_v1_1.png": "0693a95af32429919b54c72b0d4e5817298d6bd37d06897d7009579bc5394caa",
    ROOT / "project.godot": "b560718fd3141c70c318a2843b409b95490b876c139bd77104c125ce181c91f0",
}


@dataclass(frozen=True)
class SpriteSpec:
    key: str
    category: str
    crop: tuple[int, int, int, int]
    canvas: tuple[int, int]
    output_name: str
    implies_collision: bool


SPRITES = (
    SpriteSpec("tree_medium_01", "trees", (25, 397, 142, 584), (64, 96), "caden_tree_medium_01_v1.png", True),
    SpriteSpec("tree_medium_02", "trees", (146, 397, 276, 586), (64, 96), "caden_tree_medium_02_v1.png", True),
    SpriteSpec("tree_small_01", "trees", (25, 634, 116, 768), (32, 64), "caden_tree_small_01_v1.png", True),
    SpriteSpec("tree_small_02", "trees", (117, 634, 207, 769), (64, 64), "caden_tree_small_02_v1.png", True),
    SpriteSpec("bush_medium_01", "shrubs", (583, 350, 700, 430), (64, 32), "caden_bush_medium_01_v1.png", True),
    SpriteSpec("bush_medium_02", "shrubs", (699, 350, 807, 430), (64, 32), "caden_bush_medium_02_v1.png", True),
    SpriteSpec("bush_medium_03", "shrubs", (812, 350, 924, 432), (64, 32), "caden_bush_medium_03_v1.png", True),
    SpriteSpec("shrub_small_01", "shrubs", (590, 520, 665, 586), (32, 32), "caden_shrub_small_01_v1.png", False),
    SpriteSpec("shrub_small_02", "shrubs", (665, 520, 738, 586), (32, 32), "caden_shrub_small_02_v1.png", False),
    SpriteSpec("shrub_small_03", "shrubs", (800, 520, 860, 586), (32, 32), "caden_shrub_small_03_v1.png", False),
    SpriteSpec("rock_small_01", "rocks", (407, 918, 469, 980), (32, 32), "caden_rock_small_01_v1.png", False),
    SpriteSpec("rock_small_02", "rocks", (466, 908, 518, 976), (32, 32), "caden_rock_small_02_v1.png", False),
    SpriteSpec("rock_cluster_01", "rocks", (487, 814, 557, 905), (32, 32), "caden_rock_cluster_01_v1.png", True),
)

GROUND_CROPS = (
    ("flower_01", (1002, 112, 1092, 180)),
    ("flower_02", (1090, 112, 1180, 180)),
    ("flower_03", (1178, 112, 1265, 180)),
    ("flower_04", (1263, 112, 1354, 180)),
    ("flower_05", (1354, 112, 1445, 180)),
    ("tuft_01", (1008, 835, 1093, 895)),
    ("tuft_02", (1092, 835, 1178, 895)),
    ("tuft_03", (1180, 835, 1267, 895)),
    ("tuft_04", (1268, 835, 1355, 895)),
)

PLACEMENTS = {
    "tree_medium_01": [(32, 240), (928, 528)],
    "tree_medium_02": [(32, 512), (928, 208)],
    "tree_small_01": [(32, 656)],
    "tree_small_02": [(928, 96)],
    "bush_medium_01": [(80, 160), (768, 256)],
    "bush_medium_02": [(208, 160), (880, 608)],
    "bush_medium_03": [(80, 608), (896, 255)],
    "shrub_small_01": [(208, 608)],
    "shrub_small_02": [(752, 608)],
    "shrub_small_03": [(240, 128)],
    "rock_small_01": [(272, 80)],
    "rock_small_02": [(688, 640)],
    "rock_cluster_01": [(928, 640)],
}

GROUND_PLACEMENTS = [
    (0, (272, 176)), (1, (336, 176)), (2, (240, 192)), (3, (736, 224)),
    (4, (112, 240)), (5, (192, 224)), (6, (80, 464)), (7, (208, 464)),
    (8, (752, 464)), (0, (880, 464)), (2, (272, 640)), (4, (624, 640)),
    (6, (576, 80)), (8, (336, 80)),
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_inputs() -> dict[str, str]:
    actual: dict[str, str] = {}
    for path, expected in EXPECTED.items():
        if not path.is_file():
            raise SystemExit(f"Missing protected input: {path.relative_to(ROOT)}")
        digest = sha256(path)
        actual[path.relative_to(ROOT).as_posix()] = digest
        if digest != expected:
            raise SystemExit(f"Protected input changed: {path.relative_to(ROOT)}")
    return actual


def hard_alpha(image: Image.Image, threshold: int = 64) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for red, green, blue, alpha in rgba.get_flattened_data():
        pixels.append((red, green, blue, 255 if alpha >= threshold else 0))
    rgba.putdata(pixels)
    return rgba


def harmonize(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    rgb = ImageEnhance.Color(rgb).enhance(0.88)
    rgb = ImageEnhance.Contrast(rgb).enhance(0.94)
    rgb = ImageEnhance.Brightness(rgb).enhance(0.94)
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def isolate(source: Image.Image, crop: tuple[int, int, int, int], canvas: tuple[int, int]) -> tuple[Image.Image, tuple[int, int, int, int]]:
    item = hard_alpha(source.crop(crop))
    bbox = item.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"No art survived crop {crop}")
    item = item.crop(bbox).resize((max(1, (bbox[2] - bbox[0]) // 3), max(1, (bbox[3] - bbox[1]) // 3)), Image.Resampling.NEAREST)
    item = harmonize(hard_alpha(item))
    if item.width > canvas[0] or item.height > canvas[1]:
        raise RuntimeError(f"Reduced crop {crop} does not fit canvas {canvas}: {item.size}")
    result = Image.new("RGBA", canvas, (0, 0, 0, 0))
    x = (canvas[0] - item.width) // 2
    y = canvas[1] - item.height
    result.alpha_composite(item, (x, y))
    visible = result.getchannel("A").getbbox()
    assert visible is not None
    return result, visible


def prepare_sprite(source: Image.Image, spec: SpriteSpec) -> tuple[Image.Image, dict[str, object]]:
    image, visible = isolate(source, spec.crop, spec.canvas)
    path = OUT / spec.category / spec.output_name
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=False)
    return image, {
        "path": path.relative_to(ROOT).as_posix(), "dimensions": list(image.size),
        "visible_bounds": list(visible), "source_crop": list(spec.crop), "scale": "1/3 nearest",
        "anchor": [spec.canvas[0] // 2, spec.canvas[1]], "ground_contact_line": spec.canvas[1] - 1,
        "implies_collision": spec.implies_collision, "sha256": sha256(path),
    }


def prepare_ground(source: Image.Image, limit: int | None = None) -> tuple[Image.Image, list[dict[str, object]]]:
    atlas = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    records: list[dict[str, object]] = []
    selected = GROUND_CROPS if limit is None else GROUND_CROPS[:limit]
    for index, (name, crop) in enumerate(selected):
        cell, visible = isolate(source, crop, (32, 32))
        x = (index % 3) * 32
        y = (index // 3) * 32
        atlas.alpha_composite(cell, (x, y))
        records.append({"name": name, "cell": [index % 3, index // 3], "source_crop": list(crop), "visible_bounds_in_cell": list(visible)})
    path = OUT / "ground/caden_nature_ground_runtime_v1.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(path, optimize=False)
    return atlas, records


def sprite_top_left(image: Image.Image, anchor: tuple[int, int]) -> tuple[int, int]:
    return anchor[0] - image.width // 2, anchor[1] - image.height


def write_lineup(images: dict[str, Image.Image], atlas: Image.Image) -> None:
    preview = Image.new("RGBA", (960, 320), (48, 45, 39, 255))
    draw = ImageDraw.Draw(preview)
    groups = (
        ("Trees", [k for k in images if k.startswith("tree")], 16, 8, 124),
        ("Shrubs", [k for k in images if "bush" in k or "shrub" in k], 420, 8, 124),
        ("Rocks", [k for k in images if k.startswith("rock")], 16, 174, 244),
    )
    for label, keys, start_x, label_y, baseline in groups:
        draw.text((start_x, label_y), label, fill=(240, 230, 205, 255))
        x = start_x
        for key in keys:
            image = images[key]
            preview.alpha_composite(image, (x, baseline - image.height))
            short = key.replace("tree_", "t ").replace("bush_", "b ").replace("shrub_", "s ").replace("rock_", "r ")
            draw.text((x, baseline + 6), short, fill=(205, 198, 180, 255))
            x += max(image.width, 82) + 8
    draw.text((320, 174), "Ground overlay atlas - native scale", fill=(240, 230, 205, 255))
    preview.alpha_composite(atlas, (320, 194))
    preview.save(PREVIEWS / "caden_nature_runtime_v1_lineup.png", optimize=False)


def write_anchor_preview(images: dict[str, Image.Image]) -> None:
    keys = ("tree_medium_01", "bush_medium_01", "rock_small_01")
    preview = Image.new("RGBA", (480, 160), (48, 45, 39, 255))
    draw = ImageDraw.Draw(preview)
    for index, key in enumerate(keys):
        image = images[key]
        origin = (32 + index * 150, 16)
        preview.alpha_composite(image, origin)
        draw.rectangle((origin[0], origin[1], origin[0] + image.width - 1, origin[1] + image.height - 1), outline=(100, 190, 255, 255))
        ground = origin[1] + image.height - 1
        anchor = origin[0] + image.width // 2
        draw.line((origin[0] - 4, ground, origin[0] + image.width + 4, ground), fill=(255, 220, 90, 255))
        draw.ellipse((anchor - 2, ground - 2, anchor + 2, ground + 2), fill=(255, 90, 90, 255))
        draw.text((origin[0], 126), key, fill=(235, 228, 210, 255))
    draw.text((16, 144), "blue canvas / yellow contact line / red bottom-center anchor", fill=(205, 198, 180, 255))
    preview.save(PREVIEWS / "caden_nature_runtime_v1_anchor_overlay.png", optimize=False)


def composite_town_square(images: dict[str, Image.Image], atlas: Image.Image) -> Image.Image:
    base = Image.open(ARCH_PREVIEW).convert("RGBA")
    for cell_index, center in GROUND_PLACEMENTS:
        cell = atlas.crop(((cell_index % 3) * 32, (cell_index // 3) * 32, (cell_index % 3 + 1) * 32, (cell_index // 3 + 1) * 32))
        base.alpha_composite(cell, (center[0] - 16, center[1] - 16))
    for key, anchors in PLACEMENTS.items():
        for anchor in anchors:
            base.alpha_composite(images[key], sprite_top_left(images[key], anchor))
    return base


def write_scene_previews(images: dict[str, Image.Image], atlas: Image.Image) -> None:
    nature = composite_town_square(images, atlas)
    nature.save(PREVIEWS / "caden_nature_runtime_v1_town_square_preview.png", optimize=False)
    architecture = Image.open(ARCH_PREVIEW).convert("RGBA")
    comparison = Image.new("RGBA", (1920, 704), (30, 30, 30, 255))
    comparison.alpha_composite(architecture, (0, 0))
    comparison.alpha_composite(nature, (960, 0))
    draw = ImageDraw.Draw(comparison)
    draw.rectangle((0, 0, 300, 24), fill=(20, 20, 20, 210)); draw.text((8, 6), "Architecture Runtime v1.1", fill="white")
    draw.rectangle((960, 0, 1280, 24), fill=(20, 20, 20, 210)); draw.text((968, 6), "Architecture + Nature Runtime v1", fill="white")
    comparison.save(PREVIEWS / "caden_town_square_architecture_vs_nature_comparison.png", optimize=False)

    clearance = nature.copy()
    draw = ImageDraw.Draw(clearance, "RGBA")
    for rect in ((0, 288, 224, 416), (736, 288, 960, 416), (416, 0, 544, 160), (416, 544, 544, 704)):
        draw.rectangle(rect, outline=(90, 210, 255, 255), width=2)
    for rect in ((64, 64, 224, 160), (64, 512, 224, 608), (768, 160, 896, 256), (736, 512, 896, 608), (288, 592, 416, 656)):
        draw.rectangle(rect, outline=(255, 95, 95, 255), width=2)
    draw.rectangle((256, 224, 352, 320), outline=(255, 225, 70, 255), width=3)
    for pos in ((160, 352), (800, 352), (480, 160), (480, 544)):
        draw.rectangle((pos[0] - 32, pos[1] - 32, pos[0] + 32, pos[1] + 32), outline=(120, 255, 125, 255), width=2)
    for pos in ((288, 448), (672, 256)):
        draw.rectangle((pos[0] - 48, pos[1] - 48, pos[0] + 48, pos[1] + 48), outline=(225, 120, 255, 255), width=2)
    for key, anchors in PLACEMENTS.items():
        image = images[key]
        for anchor in anchors:
            left, top = sprite_top_left(image, anchor)
            draw.rectangle((left, top, left + image.width - 1, top + image.height - 1), outline=(255, 165, 50, 220), width=1)
            if next(s for s in SPRITES if s.key == key).implies_collision:
                draw.ellipse((anchor[0] - 5, anchor[1] - 3, anchor[0] + 5, anchor[1] + 3), fill=(255, 80, 40, 230))
    clearance.save(PREVIEWS / "caden_nature_runtime_v1_clearance_overlay.png", optimize=False)


def write_tileset() -> None:
    path = OUT / "ground/caden_nature_ground_runtime_v1.tres"
    lines = [
        '[gd_resource type="TileSet" load_steps=3 format=3]', '',
        '[ext_resource type="Texture2D" path="res://assets/environments/caden/nature/ground/caden_nature_ground_runtime_v1.png" id="1_ground"]', '',
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_ground"]',
        'texture = ExtResource("1_ground")', 'texture_region_size = Vector2i(32, 32)',
    ]
    for index in range(9):
        lines += [f'{index % 3}:{index // 3}/0 = 0']
    lines += ['', '[resource]', 'tile_size = Vector2i(32, 32)', 'sources/0 = SubResource("TileSetAtlasSource_ground")', '']
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prototype-only", action="store_true", help="Prepare only the required failure-gate set.")
    args = parser.parse_args()
    protected = verify_inputs()
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != (1536, 1024):
        raise SystemExit(f"Unexpected source dimensions: {source.size}")
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    selected = (SPRITES[0], SPRITES[4], SPRITES[10]) if args.prototype_only else SPRITES
    images: dict[str, Image.Image] = {}
    records: dict[str, dict[str, object]] = {}
    for spec in selected:
        images[spec.key], records[spec.key] = prepare_sprite(source, spec)
    atlas, ground = prepare_ground(source, 1 if args.prototype_only else None)
    if args.prototype_only:
        prototype = Image.new("RGBA", (256, 128), (48, 45, 39, 255))
        prototype.alpha_composite(images["tree_medium_01"], (8, 16))
        prototype.alpha_composite(images["bush_medium_01"], (88, 80))
        prototype.alpha_composite(atlas.crop((0, 0, 32, 32)), (168, 80))
        prototype.alpha_composite(images["rock_small_01"], (208, 80))
        prototype.save(PREVIEWS / "caden_nature_runtime_v1_failure_gate.png", optimize=False)
    else:
        write_tileset()
        write_lineup(images, atlas)
        write_anchor_preview(images)
        write_scene_previews(images, atlas)
    print(json.dumps({"prototype_only": args.prototype_only, "protected_hashes": protected, "sprites": records, "ground_cells": ground}, sort_keys=True))


if __name__ == "__main__":
    main()
