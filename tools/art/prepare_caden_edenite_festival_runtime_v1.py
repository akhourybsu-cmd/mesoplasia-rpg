#!/usr/bin/env python3
"""Prepare deterministic Caden Edenite, Festival, and closure runtime sprites."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source_art/caden/accents/caden_edenite_festival_master_v1.png"
OUT = ROOT / "assets/environments/caden/accents"
PREVIEWS = ROOT / "docs/art/previews"
NEUTRAL_TOWN_PREVIEW = PREVIEWS / "caden_props_runtime_v1_town_square_preview.png"
NEUTRAL_PROPS = ROOT / "assets/environments/caden/props"

EXPECTED = {
    SOURCE: "95a1860a8cc172ae7fbb65a8256450c018f7cef277595c33af80211feff5fc16",
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
    NEUTRAL_PROPS / "seating/caden_bench_01_v1.png": "49c5ec39182644f034d691626af90770084b3a5924c6dc2f4e42410868e35b79",
    NEUTRAL_PROPS / "seating/caden_bench_02_v1.png": "b5363f4e1616c517864e717f3f88b5596a8f9bb516d6e8f82d0f77885bd075df",
    NEUTRAL_PROPS / "lighting/caden_lantern_post_01_v1.png": "705640a25a52bfddaf1dd624b2e301d6e01c6eaf88cfee717a7f6b6e0e341c59",
    NEUTRAL_PROPS / "lighting/caden_ground_lantern_01_v1.png": "4fcdf7d84a73a6026cd4cd38e72d5a6e482df9a621693682a3e6abc01df2908c",
    NEUTRAL_PROPS / "fences/caden_fence_straight_01_v1.png": "3f2c330f73edcea4cbf438eff7a9da3cff83a800df304bca3105578ac96065bf",
    NEUTRAL_PROPS / "fences/caden_fence_corner_01_v1.png": "1e5594b37e9340155861839c4124215ba13a162dbadd73e1966261a8f548c637",
    NEUTRAL_PROPS / "fences/caden_fence_gate_01_v1.png": "876bbd3f59c18e969294248a9ddea6dabffe5466cf85f1119811074ccf77a35c",
    NEUTRAL_PROPS / "fences/caden_fence_end_01_v1.png": "2e4f396a9241f0d86916fb49f8a31493e0166270c35fa4ded91877b7585919ef",
    NEUTRAL_PROPS / "planters/caden_planter_box_01_v1.png": "27bd2c5c79206ae766d8b36b21431e0d9bf6e67db5a6da22d1e55d681a7d3782",
    NEUTRAL_PROPS / "planters/caden_planter_box_02_v1.png": "c795d44f6d42242f9dbd88df45632e8b0fc8822e2d8da8c5a33dbaef42a6f7c8",
    NEUTRAL_PROPS / "storage/caden_barrel_01_v1.png": "6ba3230d218aa0659c3fe2d22d4f74afb5c6019f461155434b3b0bcfdd8c1e55",
    NEUTRAL_PROPS / "storage/caden_barrel_02_v1.png": "0cc377a6f04baa9995da2cfd097c000883b1f9146e80ce4fc76291cb95297c3d",
    NEUTRAL_PROPS / "storage/caden_crate_01_v1.png": "927fe189ec720bbf0eb1575fdbcb21dace7e27f27b3329d04e40cf13bd45a9fb",
    NEUTRAL_PROPS / "storage/caden_crate_02_v1.png": "be608df14dfd73ed49b4e1e98f683e45567ee640faec5b8a1ea57d0b7307b6a3",
    NEUTRAL_PROPS / "storage/caden_sack_cluster_01_v1.png": "df6d76760b092a75753f8ea10889416e6a14452948e1184b586283679f8bad95",
    NEUTRAL_PROPS / "storage/caden_storage_cluster_01_v1.png": "825732a76e08e1bacdd635ad42ba9227e0c205cd90a15521caea5db905d668c0",
    NEUTRAL_PROPS / "travel/caden_luggage_bundle_01_v1.png": "147b1345512ac5faf2a1754e2e19109a83b460a3b9cee5bb5810fd55994367d1",
    NEUTRAL_PROPS / "travel/caden_luggage_bundle_02_v1.png": "d6973d5921940315aa03dee3e01460b0b3f1a90538eaab091fd5c5d592e507b4",
    NEUTRAL_PROPS / "travel/caden_travel_pack_01_v1.png": "8d74fb7dc0f439bfb113b7bd2715f672e311273e90468f0a4cb3f3dd099a9caf",
    NEUTRAL_PROPS / "signage/caden_signpost_blank_01_v1.png": "c9761623de0099b3b84dd9909298f713d38546f31ab548a175c6ac5b75d64ede",
    ROOT / "project.godot": "b560718fd3141c70c318a2843b409b95490b876c139bd77104c125ce181c91f0",
}


@dataclass(frozen=True)
class AccentSpec:
    key: str
    category: str
    crop: tuple[int, int, int, int]
    canvas: tuple[int, int]
    filename: str
    alpha_mode: str
    implies_collision: bool


ACCENTS = (
    AccentSpec("edenite_lantern_01", "edenite", (700, 35, 825, 255), (64, 96), "caden_edenite_lantern_01_v1.png", "glow", True),
    AccentSpec("edenite_stone_fixture_01", "edenite", (280, 35, 425, 255), (64, 96), "caden_edenite_stone_fixture_01_v1.png", "glow", True),
    AccentSpec("edenite_small_fixture_01", "edenite", (945, 125, 1045, 275), (64, 64), "caden_edenite_small_fixture_01_v1.png", "glow", True),
    AccentSpec("festival_drape_01", "festival", (0, 395, 205, 520), (96, 64), "caden_festival_drape_01_v1.png", "binary", False),
    AccentSpec("festival_drape_02", "festival", (200, 395, 395, 520), (96, 64), "caden_festival_drape_02_v1.png", "binary", False),
    AccentSpec("festival_bunting_01", "festival", (385, 395, 640, 525), (96, 64), "caden_festival_bunting_01_v1.png", "binary", False),
    AccentSpec("festival_bunting_02", "festival", (635, 395, 915, 530), (96, 64), "caden_festival_bunting_02_v1.png", "binary", False),
    AccentSpec("festival_ribbon_drop_01", "festival", (915, 395, 1005, 535), (32, 64), "caden_festival_ribbon_drop_01_v1.png", "binary", False),
    AccentSpec("closure_gate_01", "closure", (545, 890, 735, 1045), (64, 64), "caden_closure_gate_01_v1.png", "binary", True),
    AccentSpec("closure_rope_01", "closure", (720, 885, 885, 1050), (64, 64), "caden_closure_rope_01_v1.png", "binary", True),
    AccentSpec("closure_timbers_01", "closure", (875, 890, 1030, 1050), (64, 64), "caden_closure_timbers_01_v1.png", "binary", True),
)

PROTOTYPE_KEYS = {
    "edenite_lantern_01",
    "edenite_small_fixture_01",
    "festival_bunting_01",
    "festival_drape_02",
    "closure_gate_01",
}

ADDITIONAL_FENCES = {
    "fence_corner": [(64, 672)],
    "fence_gate": [(256, 672)],
    "fence_straight": [(320, 32)],
    "fence_end": [(256, 32), (368, 32), (896, 672)],
}

EDENITE_PLACEMENTS = {
    "edenite_small_fixture_01": [(24, 176)],
    "edenite_lantern_01": [(704, 368)],
    "edenite_stone_fixture_01": [(672, 672)],
}

FESTIVAL_PLACEMENTS = {
    "festival_drape_02": [(128, 672)],
    "festival_bunting_01": [(320, 32)],
    "festival_drape_01": [(832, 672)],
    "festival_ribbon_drop_01": [(368, 144)],
}

CLOSURE_PLACEMENTS = {
    "closure_gate_01": [(688, 112)],
    "closure_rope_01": [(752, 112)],
    "closure_timbers_01": [(816, 112)],
}

FENCE_PATHS = {
    "fence_corner": NEUTRAL_PROPS / "fences/caden_fence_corner_01_v1.png",
    "fence_gate": NEUTRAL_PROPS / "fences/caden_fence_gate_01_v1.png",
    "fence_straight": NEUTRAL_PROPS / "fences/caden_fence_straight_01_v1.png",
    "fence_end": NEUTRAL_PROPS / "fences/caden_fence_end_01_v1.png",
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
    if not NEUTRAL_TOWN_PREVIEW.is_file():
        raise SystemExit(f"Missing Pass 4 preview: {NEUTRAL_TOWN_PREVIEW.relative_to(ROOT)}")
    return actual


def reconstruct_alpha(image: Image.Image, mode: str) -> Image.Image:
    rgba = image.convert("RGBA")
    output: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in rgba.get_flattened_data():
        if mode == "binary":
            cleaned_alpha = 255 if alpha >= 64 else 0
        else:
            blue_glow = blue >= 80 and blue > red * 1.15 and blue > green * 1.04
            if alpha < 16:
                cleaned_alpha = 0
            elif blue_glow and alpha < 192:
                cleaned_alpha = max(48, min(192, alpha))
            elif alpha >= 64:
                cleaned_alpha = 255
            else:
                cleaned_alpha = 0
        output.append((red, green, blue, cleaned_alpha))
    result = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    result.putdata(output)
    return result


def harmonize(image: Image.Image, category: str) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    if category == "edenite":
        saturation, contrast, brightness = 0.96, 0.96, 0.98
    elif category == "festival":
        saturation, contrast, brightness = 0.86, 0.95, 0.96
    else:
        saturation, contrast, brightness = 0.90, 0.94, 0.95
    rgb = ImageEnhance.Color(rgb).enhance(saturation)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    rgb = ImageEnhance.Brightness(rgb).enhance(brightness)
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def isolate(source: Image.Image, spec: AccentSpec) -> tuple[Image.Image, tuple[int, int, int, int]]:
    item = reconstruct_alpha(source.crop(spec.crop), spec.alpha_mode)
    bounds = item.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError(f"No foreground survived {spec.key}")
    trimmed = item.crop(bounds)
    reduced = trimmed.resize(
        (max(1, trimmed.width // 3), max(1, trimmed.height // 3)),
        Image.Resampling.NEAREST,
    )
    reduced = harmonize(reduced, spec.category)
    reduced_bounds = reduced.getchannel("A").getbbox()
    if reduced_bounds is None:
        raise RuntimeError(f"No reduced foreground survived {spec.key}")
    reduced = reduced.crop(reduced_bounds)
    if reduced.width > spec.canvas[0] or reduced.height > spec.canvas[1]:
        raise RuntimeError(f"{spec.key} {reduced.size} exceeds canvas {spec.canvas}")
    canvas = Image.new("RGBA", spec.canvas, (0, 0, 0, 0))
    canvas.alpha_composite(
        reduced,
        ((spec.canvas[0] - reduced.width) // 2, spec.canvas[1] - reduced.height),
    )
    visible = canvas.getchannel("A").getbbox()
    assert visible is not None
    return canvas, visible


def write_accent(source: Image.Image, spec: AccentSpec) -> tuple[Image.Image, dict[str, object]]:
    image, visible = isolate(source, spec)
    path = OUT / spec.category / spec.filename
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=False)
    return image, {
        "path": path.relative_to(ROOT).as_posix(),
        "dimensions": list(image.size),
        "visible_bounds": list(visible),
        "source_crop": list(spec.crop),
        "scale": "1/3 nearest",
        "alpha_mode": spec.alpha_mode,
        "anchor": [spec.canvas[0] // 2, spec.canvas[1]],
        "ground_contact_line": spec.canvas[1] - 1,
        "implies_collision": spec.implies_collision,
        "sha256": sha256(path),
    }


def top_left(image: Image.Image, anchor: tuple[int, int]) -> tuple[int, int]:
    return anchor[0] - image.width // 2, anchor[1] - image.height


def write_failure_gate(images: dict[str, Image.Image]) -> None:
    order = (
        ("edenite_lantern_01", "lantern"),
        ("edenite_small_fixture_01", "small fixture"),
        ("festival_bunting_01", "bunting"),
        ("festival_drape_02", "fence overlay"),
        ("closure_gate_01", "closure"),
    )
    preview = Image.new("RGBA", (560, 160), (48, 45, 39, 255))
    draw = ImageDraw.Draw(preview)
    x = 12
    for key, label in order:
        image = images[key]
        preview.alpha_composite(image, (x, 118 - image.height))
        draw.text((x, 126), label, fill=(230, 222, 204, 255))
        x += max(image.width, 96) + 10
    draw.text((12, 148), "native runtime scale / neutral review background", fill=(190, 184, 170, 255))
    preview.save(PREVIEWS / "caden_edenite_festival_runtime_v1_failure_gate.png", optimize=False)


def write_lineup(images: dict[str, Image.Image]) -> None:
    preview = Image.new("RGBA", (1120, 320), (48, 45, 39, 255))
    draw = ImageDraw.Draw(preview)
    y = 10
    for category in ("edenite", "festival", "closure"):
        draw.text((12, y), category.title(), fill=(240, 230, 205, 255))
        x = 120
        baseline = y + 80
        for spec in (item for item in ACCENTS if item.category == category):
            image = images[spec.key]
            preview.alpha_composite(image, (x, baseline - image.height))
            draw.text((x, baseline + 4), spec.key.replace("_01", ""), fill=(205, 198, 180, 255))
            x += max(image.width, 150)
        y += 102
    preview.save(PREVIEWS / "caden_edenite_festival_runtime_v1_lineup.png", optimize=False)


def write_anchor_preview(images: dict[str, Image.Image]) -> None:
    keys = ("edenite_lantern_01", "edenite_small_fixture_01", "festival_drape_02", "festival_bunting_01", "closure_gate_01")
    preview = Image.new("RGBA", (640, 168), (48, 45, 39, 255))
    draw = ImageDraw.Draw(preview)
    x = 18
    for key in keys:
        image = images[key]
        origin = (x, 116 - image.height)
        preview.alpha_composite(image, origin)
        draw.rectangle((origin[0], origin[1], origin[0] + image.width - 1, origin[1] + image.height - 1), outline=(100, 190, 255, 255))
        ground = origin[1] + image.height - 1
        anchor_x = origin[0] + image.width // 2
        draw.line((origin[0] - 2, ground, origin[0] + image.width + 2, ground), fill=(255, 220, 90, 255))
        draw.ellipse((anchor_x - 2, ground - 2, anchor_x + 2, ground + 2), fill=(255, 90, 90, 255))
        draw.text((x, 126), key.split("_01")[0], fill=(225, 216, 196, 255))
        x += image.width + 28
    draw.text((12, 154), "blue canvas / yellow contact line / red bottom-center anchor", fill=(205, 198, 180, 255))
    preview.save(PREVIEWS / "caden_edenite_festival_runtime_v1_anchor_overlay.png", optimize=False)


def load_fences() -> dict[str, Image.Image]:
    return {key: Image.open(path).convert("RGBA") for key, path in FENCE_PATHS.items()}


def composite_pass5(images: dict[str, Image.Image]) -> Image.Image:
    preview = Image.open(NEUTRAL_TOWN_PREVIEW).convert("RGBA")
    fences = load_fences()
    for key, anchors in ADDITIONAL_FENCES.items():
        for anchor in anchors:
            preview.alpha_composite(fences[key], top_left(fences[key], anchor))
    closure_corner = fences["fence_corner"]
    preview.alpha_composite(closure_corner, top_left(closure_corner, (624, 112)))
    for placements in (FESTIVAL_PLACEMENTS, EDENITE_PLACEMENTS, CLOSURE_PLACEMENTS):
        for key, anchors in placements.items():
            for anchor in anchors:
                preview.alpha_composite(images[key], top_left(images[key], anchor))
    return preview


def write_scene_previews(images: dict[str, Image.Image]) -> None:
    neutral = Image.open(NEUTRAL_TOWN_PREVIEW).convert("RGBA")
    final = composite_pass5(images)
    final.save(PREVIEWS / "caden_edenite_festival_runtime_v1_town_square_preview.png", optimize=False)

    comparison = Image.new("RGBA", (1920, 704), (30, 30, 30, 255))
    comparison.alpha_composite(neutral, (0, 0))
    comparison.alpha_composite(final, (960, 0))
    draw = ImageDraw.Draw(comparison, "RGBA")
    draw.rectangle((0, 0, 330, 24), fill=(20, 20, 20, 210))
    draw.text((8, 6), "Neutral Props Runtime v1", fill="white")
    draw.rectangle((960, 0, 1340, 24), fill=(20, 20, 20, 210))
    draw.text((968, 6), "Pass 5 fencing + restrained accents", fill="white")
    comparison.save(PREVIEWS / "caden_town_square_neutral_vs_festival_comparison.png", optimize=False)

    fence_overlay = final.copy()
    draw = ImageDraw.Draw(fence_overlay, "RGBA")
    fences = load_fences()
    for key, anchors in ADDITIONAL_FENCES.items():
        for anchor in anchors:
            image = fences[key]
            left, top = top_left(image, anchor)
            draw.rectangle((left, top, left + image.width - 1, top + image.height - 1), outline=(90, 255, 130, 255), width=2)
    for key in ("festival_drape_02", "festival_bunting_01", "festival_drape_01"):
        for anchor in FESTIVAL_PLACEMENTS[key]:
            image = images[key]
            left, top = top_left(image, anchor)
            draw.rectangle((left, top, left + image.width - 1, top + image.height - 1), outline=(80, 210, 255, 255), width=2)
    draw.rectangle((0, 656, 960, 688), outline=(255, 90, 90, 210), width=2)
    draw.rectangle((0, 0, 960, 32), outline=(255, 90, 90, 210), width=2)
    draw.text((8, 8), "green=new plain fence / cyan=decorated segment / red=existing boundary collision", fill=(255, 255, 255, 255))
    fence_overlay.save(PREVIEWS / "caden_edenite_festival_runtime_v1_fence_overlay.png", optimize=False)

    clearance = final.copy()
    draw = ImageDraw.Draw(clearance, "RGBA")
    for rectangle in ((0, 288, 224, 416), (736, 288, 960, 416), (416, 0, 544, 160), (416, 544, 544, 704)):
        draw.rectangle(rectangle, outline=(90, 210, 255, 255), width=2)
    for rectangle in ((64, 64, 224, 160), (64, 512, 224, 608), (768, 160, 896, 256), (736, 512, 896, 608), (288, 592, 416, 656)):
        draw.rectangle(rectangle, outline=(255, 95, 95, 255), width=2)
    draw.rectangle((256, 224, 352, 320), outline=(255, 225, 70, 255), width=3)
    for position in ((160, 352), (800, 352), (480, 160), (480, 544)):
        draw.rectangle((position[0] - 32, position[1] - 32, position[0] + 32, position[1] + 32), outline=(120, 255, 125, 255), width=2)
    for position in ((288, 448), (672, 256)):
        draw.rectangle((position[0] - 48, position[1] - 48, position[0] + 48, position[1] + 48), outline=(225, 120, 255, 255), width=2)
    draw.polygon(((576, 192), (704, 192), (864, 32), (736, 32)), outline=(255, 145, 35, 255))
    for placements in (EDENITE_PLACEMENTS, FESTIVAL_PLACEMENTS, CLOSURE_PLACEMENTS):
        for key, anchors in placements.items():
            image = images[key]
            for anchor in anchors:
                left, top = top_left(image, anchor)
                draw.rectangle((left, top, left + image.width - 1, top + image.height - 1), outline=(255, 165, 50, 220), width=1)
    draw.rectangle((697, 358, 711, 368), fill=(255, 70, 70, 85), outline=(255, 70, 70, 255), width=2)
    clearance.save(PREVIEWS / "caden_edenite_festival_runtime_v1_clearance_overlay.png", optimize=False)

    closure = final.crop((576, 0, 928, 192)).resize((704, 384), Image.Resampling.NEAREST)
    closure.save(PREVIEWS / "caden_terrebonne_closure_runtime_v1_preview.png", optimize=False)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prototype-only", action="store_true")
    args = parser.parse_args()
    protected = verify_inputs()
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != (1448, 1086):
        raise SystemExit(f"Unexpected accent-master dimensions: {source.size}")
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    selected = [spec for spec in ACCENTS if not args.prototype_only or spec.key in PROTOTYPE_KEYS]
    images: dict[str, Image.Image] = {}
    records: dict[str, dict[str, object]] = {}
    for spec in selected:
        images[spec.key], records[spec.key] = write_accent(source, spec)
    if args.prototype_only:
        write_failure_gate(images)
    else:
        write_failure_gate(images)
        write_lineup(images)
        write_anchor_preview(images)
        write_scene_previews(images)
    print(json.dumps({"prototype_only": args.prototype_only, "protected_hashes": protected, "accents": records}, sort_keys=True))


if __name__ == "__main__":
    main()
