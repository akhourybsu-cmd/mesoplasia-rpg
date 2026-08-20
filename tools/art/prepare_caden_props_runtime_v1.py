#!/usr/bin/env python3
"""Prepare deterministic neutral Caden prop sprites from the Props master."""

from __future__ import annotations

import argparse
from collections import deque
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source_art/caden/props/caden_props_master_v1.png"
OUT = ROOT / "assets/environments/caden/props"
PREVIEWS = ROOT / "docs/art/previews"
NATURE_PREVIEW = PREVIEWS / "caden_nature_runtime_v1_town_square_preview.png"

EXPECTED = {
    SOURCE: "1bec25a3cb6928014a893cbbd9e04d3b4d4cd9105171df45318037098446ae53",
    ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png": "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a",
    ROOT / "assets/environments/caden/architecture/town_square/town_square_building_northwest_v1_1.png": "55ee5c5c35e2f646e5b8b2295680111eba56e71168d5efed5b246ae9f2c0f770",
    ROOT / "assets/environments/caden/architecture/town_square/town_square_building_southwest_v1_1.png": "790f375a5549e91af59950e91c648fc6c547fc2d1b092591dc33a56ba59b6780",
    ROOT / "assets/environments/caden/architecture/town_square/town_square_building_northeast_v1_1.png": "22c8515c03591d869174392fe83ee2a90c909f6c58b70820fb9a6ea60792d1a6",
    ROOT / "assets/environments/caden/architecture/town_square/town_square_building_southeast_v1_1.png": "68c8686dca3dae8f3173415a094c824f8601021ab51b6904968deef5e84ab487",
    ROOT / "assets/environments/caden/architecture/town_square/town_square_building_south_v1_1.png": "0693a95af32429919b54c72b0d4e5817298d6bd37d06897d7009579bc5394caa",
    ROOT / "assets/environments/caden/nature/ground/caden_nature_ground_runtime_v1.png": "9a9cf0889528763c2cdbdbe4b7d5fb755c5df9247529f9dcf2e5e5864190f045",
    ROOT / "assets/environments/caden/nature/trees/caden_tree_medium_01_v1.png": "4437f65ccff775395b4ac73dd1673ab7da65d7afdbd80256cd9325d09172c828",
    ROOT / "assets/environments/caden/nature/trees/caden_tree_medium_02_v1.png": "c062eca53c29d4f734716e2708c48acb35bfe86cafbfb71c453a667096f735d9",
    ROOT / "assets/environments/caden/nature/trees/caden_tree_small_01_v1.png": "099d85522798fa45f68b20e9b23afab2f171936c7279b0f96795d808d78bce78",
    ROOT / "assets/environments/caden/nature/trees/caden_tree_small_02_v1.png": "907f22a378b064941e7bf92aba877dd1ac9eb08e31f3b2c29c494d16954d9d1e",
    ROOT / "assets/environments/caden/nature/shrubs/caden_bush_medium_01_v1.png": "71d4f3883c0cb48ba20b05dea8288fc877b4031aeda2fe4a137141317e6b9c56",
    ROOT / "assets/environments/caden/nature/shrubs/caden_bush_medium_02_v1.png": "b7aa6706bd868e828e7c1843535b484eefe2b7416a172cf454c19d85ccb60fe5",
    ROOT / "assets/environments/caden/nature/shrubs/caden_bush_medium_03_v1.png": "d488ebf7a5e5a1b0e198e098c977047d7337c285df376ae75966255a5249cc28",
    ROOT / "assets/environments/caden/nature/shrubs/caden_shrub_small_01_v1.png": "1b6f822eeb9344af4964b798596d8397d3bbb46c0df8b094ca1de4176d4e3d51",
    ROOT / "assets/environments/caden/nature/shrubs/caden_shrub_small_02_v1.png": "9f0d898a81bce8dbb726e2d132b50ad0fef987cbce8f4aa46af8184d1ba3ed4c",
    ROOT / "assets/environments/caden/nature/shrubs/caden_shrub_small_03_v1.png": "6f18c869d556e9d37128a8cc78a2dfcd6348fe078c9293189ff89d575f6d5113",
    ROOT / "assets/environments/caden/nature/rocks/caden_rock_small_01_v1.png": "1314c6e6e33e4e32588980a7d74821f7ca0f8d27002801926ed45f1c861f4887",
    ROOT / "assets/environments/caden/nature/rocks/caden_rock_small_02_v1.png": "db8d584dcb72613b99e58dfa0d3ec7c034bb3d9ac8735bc22c6df06252b8beb6",
    ROOT / "assets/environments/caden/nature/rocks/caden_rock_cluster_01_v1.png": "1918ff6469b3684e84aba4c5ea6d7437d87894f280c84b5cf2fab0d629927660",
    ROOT / "project.godot": "b560718fd3141c70c318a2843b409b95490b876c139bd77104c125ce181c91f0",
}


@dataclass(frozen=True)
class PropSpec:
    key: str
    category: str
    crop: tuple[int, int, int, int]
    canvas: tuple[int, int]
    filename: str
    implies_collision: bool


PROPS = (
    PropSpec("bench_flower_01", "seating", (5, 70, 205, 240), (96, 64), "caden_bench_01_v1.png", True),
    PropSpec("bench_plain_02", "seating", (400, 88, 540, 230), (64, 64), "caden_bench_02_v1.png", True),
    PropSpec("lantern_post_01", "lighting", (545, 10, 625, 245), (32, 96), "caden_lantern_post_01_v1.png", True),
    PropSpec("lantern_ground_01", "lighting", (275, 450, 335, 560), (32, 64), "caden_ground_lantern_01_v1.png", False),
    PropSpec("fence_straight_01", "fences", (5, 235, 265, 400), (96, 64), "caden_fence_straight_01_v1.png", True),
    PropSpec("fence_corner_01", "fences", (265, 235, 415, 400), (64, 64), "caden_fence_corner_01_v1.png", True),
    PropSpec("fence_gate_01", "fences", (405, 235, 550, 400), (64, 64), "caden_fence_gate_01_v1.png", True),
    PropSpec("fence_end_01", "fences", (545, 235, 615, 400), (32, 64), "caden_fence_end_01_v1.png", True),
    PropSpec("planter_box_01", "planters", (1000, 65, 1215, 235), (96, 64), "caden_planter_box_01_v1.png", False),
    PropSpec("planter_box_02", "planters", (1210, 60, 1350, 235), (64, 64), "caden_planter_box_02_v1.png", False),
    PropSpec("barrel_01", "storage", (10, 385, 110, 555), (64, 64), "caden_barrel_01_v1.png", True),
    PropSpec("barrel_02", "storage", (100, 375, 215, 555), (64, 64), "caden_barrel_02_v1.png", True),
    PropSpec("crate_01", "storage", (325, 390, 430, 555), (64, 64), "caden_crate_01_v1.png", True),
    PropSpec("crate_02", "storage", (430, 380, 545, 555), (64, 64), "caden_crate_02_v1.png", True),
    PropSpec("sack_cluster_01", "storage", (955, 405, 1110, 550), (64, 64), "caden_sack_cluster_01_v1.png", True),
    PropSpec("storage_cluster_01", "storage", (555, 380, 720, 560), (64, 64), "caden_storage_cluster_01_v1.png", True),
    PropSpec("luggage_01", "travel", (0, 535, 165, 675), (64, 64), "caden_luggage_bundle_01_v1.png", False),
    PropSpec("luggage_02", "travel", (155, 535, 310, 675), (64, 64), "caden_luggage_bundle_02_v1.png", False),
    PropSpec("travel_pack_01", "travel", (450, 535, 545, 675), (64, 64), "caden_travel_pack_01_v1.png", False),
    PropSpec("signpost_blank_01", "signage", (1025, 230, 1185, 405), (64, 64), "caden_signpost_blank_01_v1.png", True),
)

PLACEMENTS = {
    "bench_plain_02": [(160, 240)],
    "bench_flower_01": [(784, 440)],
    "lantern_post_01": [(368, 144), (576, 496)],
    "lantern_ground_01": [(248, 576)],
    "fence_straight_01": [(128, 672), (832, 672)],
    "fence_end_01": [(224, 672)],
    "fence_corner_01": [(736, 672)],
    "planter_box_01": [(208, 224)],
    "planter_box_02": [(720, 440)],
    "barrel_01": [(64, 144)],
    "storage_cluster_01": [(224, 576)],
    "sack_cluster_01": [(736, 576)],
    "luggage_01": [(256, 624)],
    "travel_pack_01": [(704, 624)],
}

COLLISIONS = {
    "bench_plain_02": ((52, 10), (0, -5)),
    "bench_flower_01": ((64, 10), (0, -5)),
    "lantern_post_01": ((12, 10), (0, -5)),
}


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


def reconstruct_alpha(image: Image.Image, step_threshold: int = 12) -> Image.Image:
    """Flood the smoothly changing presentation background from crop borders."""
    rgba = image.convert("RGBA")
    w, h = rgba.size
    pixels = list(rgba.get_flattened_data())
    background = bytearray(w * h)
    queue: deque[tuple[int, int]] = deque()
    for x in range(w):
        queue.append((x, 0)); queue.append((x, h - 1))
    for y in range(1, h - 1):
        queue.append((0, y)); queue.append((w - 1, y))
    threshold_squared = step_threshold * step_threshold
    while queue:
        x, y = queue.popleft()
        index = y * w + x
        if background[index]:
            continue
        background[index] = 1
        current = pixels[index]
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if nx < 0 or ny < 0 or nx >= w or ny >= h:
                continue
            neighbor_index = ny * w + nx
            if background[neighbor_index]:
                continue
            neighbor = pixels[neighbor_index]
            distance_squared = sum((current[channel] - neighbor[channel]) ** 2 for channel in range(4))
            if distance_squared <= threshold_squared:
                queue.append((nx, ny))
    output: list[tuple[int, int, int, int]] = []
    for index, pixel in enumerate(pixels):
        output.append((pixel[0], pixel[1], pixel[2], 0 if background[index] else 255))
    result = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    result.putdata(output)
    return result


def harmonize(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    rgb = ImageEnhance.Color(rgb).enhance(0.90)
    rgb = ImageEnhance.Contrast(rgb).enhance(0.94)
    rgb = ImageEnhance.Brightness(rgb).enhance(0.95)
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def isolate(source: Image.Image, spec: PropSpec) -> tuple[Image.Image, tuple[int, int, int, int]]:
    item = reconstruct_alpha(source.crop(spec.crop))
    bbox = item.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"No foreground survived {spec.key}")
    trimmed = item.crop(bbox)
    reduced = trimmed.resize((max(1, trimmed.width // 3), max(1, trimmed.height // 3)), Image.Resampling.NEAREST)
    reduced = harmonize(reduced)
    reduced_bounds = reduced.getchannel("A").getbbox()
    if reduced_bounds is None:
        raise RuntimeError(f"No reduced foreground survived {spec.key}")
    reduced = reduced.crop(reduced_bounds)
    if reduced.width > spec.canvas[0] or reduced.height > spec.canvas[1]:
        raise RuntimeError(f"{spec.key} {reduced.size} exceeds canvas {spec.canvas}")
    canvas = Image.new("RGBA", spec.canvas, (0, 0, 0, 0))
    canvas.alpha_composite(reduced, ((spec.canvas[0] - reduced.width) // 2, spec.canvas[1] - reduced.height))
    visible = canvas.getchannel("A").getbbox()
    assert visible is not None
    return canvas, visible


def write_prop(source: Image.Image, spec: PropSpec) -> tuple[Image.Image, dict[str, object]]:
    image, visible = isolate(source, spec)
    path = OUT / spec.category / spec.filename
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=False)
    return image, {
        "path": path.relative_to(ROOT).as_posix(), "dimensions": list(image.size),
        "visible_bounds": list(visible), "source_crop": list(spec.crop), "scale": "1/3 nearest",
        "anchor": [spec.canvas[0] // 2, spec.canvas[1]], "ground_contact_line": spec.canvas[1] - 1,
        "implies_collision": spec.implies_collision, "sha256": sha256(path),
    }


def top_left(image: Image.Image, anchor: tuple[int, int]) -> tuple[int, int]:
    return anchor[0] - image.width // 2, anchor[1] - image.height


def write_failure_gate(images: dict[str, Image.Image]) -> None:
    keys = ("bench_plain_02", "lantern_post_01", "fence_straight_01", "barrel_01", "luggage_01")
    preview = Image.new("RGBA", (400, 144), (48, 45, 39, 255))
    draw = ImageDraw.Draw(preview)
    x = 8
    for key in keys:
        image = images[key]
        preview.alpha_composite(image, (x, 112 - image.height))
        draw.text((x, 120), key.split("_")[0], fill=(225, 216, 196, 255))
        x += image.width + 12
    preview.save(PREVIEWS / "caden_props_runtime_v1_failure_gate.png", optimize=False)


def write_lineup(images: dict[str, Image.Image]) -> None:
    preview = Image.new("RGBA", (1280, 480), (48, 45, 39, 255))
    draw = ImageDraw.Draw(preview)
    order = ("seating", "lighting", "fences", "planters", "storage", "travel", "signage")
    y = 8
    for category in order:
        keys = [spec.key for spec in PROPS if spec.category == category]
        draw.text((12, y), category.title(), fill=(240, 230, 205, 255))
        x = 120
        baseline = y + 78
        for key in keys:
            image = images[key]
            preview.alpha_composite(image, (x, baseline - image.height))
            draw.text((x, baseline + 4), key.replace("_01", "").replace("_02", ""), fill=(205, 198, 180, 255))
            x += max(image.width, 142) + 8
        y += 66
    preview.save(PREVIEWS / "caden_props_runtime_v1_lineup.png", optimize=False)


def write_palette_preview() -> None:
    full_color = Image.open(PREVIEWS / "caden_props_runtime_v1_lineup.png").convert("RGBA")
    grayscale = ImageOps.grayscale(full_color.convert("RGB")).convert("RGBA")
    reduced = ImageEnhance.Color(full_color.convert("RGB")).enhance(0.35).convert("RGBA")
    preview = Image.new("RGBA", (full_color.width, full_color.height * 3), (48, 45, 39, 255))
    preview.alpha_composite(full_color, (0, 0))
    preview.alpha_composite(grayscale, (0, full_color.height))
    preview.alpha_composite(reduced, (0, full_color.height * 2))
    draw = ImageDraw.Draw(preview, "RGBA")
    for label, y in (("Full color", 0), ("Grayscale", full_color.height), ("Reduced saturation", full_color.height * 2)):
        draw.rectangle((0, y, 112, y + 20), fill=(20, 20, 20, 220))
        draw.text((6, y + 5), label, fill=(255, 255, 255, 255))
    preview.save(PREVIEWS / "caden_props_runtime_v1_palette_review.png", optimize=False)


def write_anchor_preview(images: dict[str, Image.Image]) -> None:
    keys = ("bench_plain_02", "lantern_post_01", "fence_straight_01", "barrel_01", "luggage_01")
    preview = Image.new("RGBA", (640, 160), (48, 45, 39, 255))
    draw = ImageDraw.Draw(preview)
    x = 20
    for key in keys:
        image = images[key]
        origin = (x, 112 - image.height)
        preview.alpha_composite(image, origin)
        draw.rectangle((origin[0], origin[1], origin[0] + image.width - 1, origin[1] + image.height - 1), outline=(100, 190, 255, 255))
        ground = origin[1] + image.height - 1
        anchor_x = origin[0] + image.width // 2
        draw.line((origin[0] - 2, ground, origin[0] + image.width + 2, ground), fill=(255, 220, 90, 255))
        draw.ellipse((anchor_x - 2, ground - 2, anchor_x + 2, ground + 2), fill=(255, 90, 90, 255))
        draw.text((x, 122), key.split("_")[0], fill=(225, 216, 196, 255))
        x += image.width + 24
    draw.text((12, 146), "blue canvas / yellow contact line / red bottom-center anchor", fill=(205, 198, 180, 255))
    preview.save(PREVIEWS / "caden_props_runtime_v1_anchor_overlay.png", optimize=False)


def composite_scene(images: dict[str, Image.Image]) -> Image.Image:
    preview = Image.open(NATURE_PREVIEW).convert("RGBA")
    for key, anchors in PLACEMENTS.items():
        image = images[key]
        for anchor in anchors:
            preview.alpha_composite(image, top_left(image, anchor))
    return preview


def write_scene_previews(images: dict[str, Image.Image]) -> None:
    props = composite_scene(images)
    props.save(PREVIEWS / "caden_props_runtime_v1_town_square_preview.png", optimize=False)
    nature = Image.open(NATURE_PREVIEW).convert("RGBA")
    comparison = Image.new("RGBA", (1920, 704), (30, 30, 30, 255))
    comparison.alpha_composite(nature, (0, 0)); comparison.alpha_composite(props, (960, 0))
    draw = ImageDraw.Draw(comparison, "RGBA")
    draw.rectangle((0, 0, 300, 24), fill=(20, 20, 20, 210)); draw.text((8, 6), "Nature Runtime v1", fill="white")
    draw.rectangle((960, 0, 1300, 24), fill=(20, 20, 20, 210)); draw.text((968, 6), "Nature + Neutral Props Runtime v1", fill="white")
    comparison.save(PREVIEWS / "caden_town_square_nature_vs_props_comparison.png", optimize=False)

    clearance = props.copy()
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
            left, top = top_left(image, anchor)
            draw.rectangle((left, top, left + image.width - 1, top + image.height - 1), outline=(255, 165, 50, 220), width=1)
    clearance.save(PREVIEWS / "caden_props_runtime_v1_clearance_overlay.png", optimize=False)

    collision = props.copy()
    draw = ImageDraw.Draw(collision, "RGBA")
    for key, (size, offset) in COLLISIONS.items():
        for anchor in PLACEMENTS[key]:
            cx, cy = anchor[0] + offset[0], anchor[1] + offset[1]
            draw.rectangle((cx - size[0] // 2, cy - size[1] // 2, cx + size[0] // 2, cy + size[1] // 2), fill=(255, 70, 70, 85), outline=(255, 70, 70, 255), width=2)
            draw.ellipse((anchor[0] - 3, anchor[1] - 3, anchor[0] + 3, anchor[1] + 3), fill=(255, 230, 80, 255))
    collision.save(PREVIEWS / "caden_props_runtime_v1_collision_overlay.png", optimize=False)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prototype-only", action="store_true")
    args = parser.parse_args()
    protected = verify_inputs()
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != (1536, 1024):
        raise SystemExit(f"Unexpected Props master dimensions: {source.size}")
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    gate_keys = {"bench_plain_02", "lantern_post_01", "fence_straight_01", "barrel_01", "luggage_01"}
    selected = [spec for spec in PROPS if not args.prototype_only or spec.key in gate_keys]
    images: dict[str, Image.Image] = {}
    records: dict[str, dict[str, object]] = {}
    for spec in selected:
        images[spec.key], records[spec.key] = write_prop(source, spec)
    if args.prototype_only:
        write_failure_gate(images)
    else:
        write_failure_gate(images)
        write_lineup(images)
        write_palette_preview()
        write_anchor_preview(images)
        write_scene_previews(images)
    print(json.dumps({"prototype_only": args.prototype_only, "protected_hashes": protected, "props": records}, sort_keys=True))


if __name__ == "__main__":
    main()
