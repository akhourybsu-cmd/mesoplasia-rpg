#!/usr/bin/env python3
"""Create deterministic Caden character-production templates and review previews.

The outputs are intentionally noncanonical. The source templates are transparent
grids only; neutral development silhouettes appear exclusively in documentation
previews and in the CharacterScaleLab Godot scene.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
TEMPLATE_DIRECTORY = ROOT / "assets/source_art/caden/characters/templates"
PREVIEW_DIRECTORY = ROOT / "docs/art/previews"

CELL_WIDTH = 40
CELL_HEIGHT = 56
COLUMNS = 4
ROWS = 4
SHEET_SIZE = (CELL_WIDTH * COLUMNS, CELL_HEIGHT * ROWS)

PLAYER_TEMPLATE = TEMPLATE_DIRECTORY / "caden_player_directional_template_v1.png"
NPC_TEMPLATE = TEMPLATE_DIRECTORY / "caden_npc_directional_template_v1.png"
ANCHOR_REFERENCE = TEMPLATE_DIRECTORY / "caden_character_anchor_reference_v1.png"
COLLISION_REFERENCE = TEMPLATE_DIRECTORY / "caden_character_collision_reference_v1.png"

SCALE_COMPARISON = PREVIEW_DIRECTORY / "caden_character_scale_comparison_v1.png"
COLLISION_OVERLAY = PREVIEW_DIRECTORY / "caden_character_scale_collision_overlay_v1.png"
ENVIRONMENT_SCALE = PREVIEW_DIRECTORY / "caden_character_environment_scale_v1.png"
TEMPLATE_PREVIEW = PREVIEW_DIRECTORY / "caden_character_sheet_template_v1.png"

ENVIRONMENT_ASSETS = {
    "terrain": ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png",
    "building": ROOT / "assets/environments/caden/architecture/town_square/town_square_building_northwest_v1_1.png",
    "tree": ROOT / "assets/environments/caden/nature/trees/caden_tree_medium_01_v1.png",
    "bench": ROOT / "assets/environments/caden/props/seating/caden_bench_01_v1.png",
    "lantern": ROOT / "assets/environments/caden/props/lighting/caden_lantern_post_01_v1.png",
    "edenite": ROOT / "assets/environments/caden/accents/edenite/caden_edenite_lantern_01_v1.png",
    "planter": ROOT / "assets/environments/caden/props/planters/caden_planter_box_02_v1.png",
}

EXPECTED_ENVIRONMENT_HASHES = {
    "terrain": "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a",
    "building": "55ee5c5c35e2f646e5b8b2295680111eba56e71168d5efed5b246ae9f2c0f770",
    "tree": "4437f65ccff775395b4ac73dd1673ab7da65d7afdbd80256cd9325d09172c828",
    "bench": "49c5ec39182644f034d691626af90770084b3a5924c6dc2f4e42410868e35b79",
    "lantern": "705640a25a52bfddaf1dd624b2e301d6e01c6eaf88cfee717a7f6b6e0e341c59",
    "edenite": "18ce8e4b5066cb228e589e7f9f0cee4dd07fab18e8e9c45f4e12f430a12c36ad",
    "planter": "c795d44f6d42242f9dbd88df45632e8b0fc8822e2d8da8c5a33dbaef42a6f7c8",
}

CANDIDATES = (
    ("Candidate A", 32, 48),
    ("Candidate B - recommended", 40, 56),
    ("Candidate C", 48, 64),
)

INK = (38, 47, 50, 255)
BODY = (77, 104, 106, 255)
LIGHT = (166, 157, 137, 255)
GUIDE = (77, 184, 204, 255)
ANCHOR = (94, 214, 143, 255)
COLLISION = (247, 183, 73, 255)
ORIGIN = (232, 92, 92, 255)
PANEL = (39, 35, 31, 255)
TEXT = (241, 232, 211, 255)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_environment_assets() -> None:
    for key, path in ENVIRONMENT_ASSETS.items():
        if not path.is_file():
            raise SystemExit(f"Missing representative environment asset: {path.relative_to(ROOT)}")
        if sha256(path) != EXPECTED_ENVIRONMENT_HASHES[key]:
            raise SystemExit(f"Protected environment asset changed: {path.relative_to(ROOT)}")


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def create_templates() -> dict[Path, Image.Image]:
    blank = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
    anchor_reference = blank.copy()
    anchor_draw = ImageDraw.Draw(anchor_reference)
    collision_reference = blank.copy()
    collision_draw = ImageDraw.Draw(collision_reference)

    for row in range(ROWS):
        for column in range(COLUMNS):
            left = column * CELL_WIDTH
            top = row * CELL_HEIGHT
            right = left + CELL_WIDTH - 1
            bottom = top + CELL_HEIGHT - 1

            anchor_draw.rectangle((left, top, right, bottom), outline=GUIDE, width=1)
            anchor_draw.line((left + 1, bottom, right - 1, bottom), fill=ANCHOR, width=1)
            anchor_x = left + CELL_WIDTH // 2
            anchor_draw.point((anchor_x, bottom), fill=(255, 255, 255, 255))
            anchor_draw.point((anchor_x - 1, bottom), fill=ANCHOR)
            anchor_draw.point((anchor_x + 1, bottom), fill=ANCHOR)
            anchor_draw.point((anchor_x, bottom - 1), fill=ANCHOR)

            collision_draw.rectangle((left, top, right, bottom), outline=GUIDE, width=1)
            collision_left = left + (CELL_WIDTH - 24) // 2
            collision_top = top + CELL_HEIGHT - 24
            collision_right = collision_left + 23
            collision_bottom = bottom
            collision_draw.rectangle(
                (collision_left, collision_top, collision_right, collision_bottom),
                outline=COLLISION,
                width=1,
            )
            collision_draw.point((left + CELL_WIDTH // 2, bottom), fill=ANCHOR)
            collision_draw.point((left + CELL_WIDTH // 2, collision_top + 12), fill=ORIGIN)

    return {
        PLAYER_TEMPLATE: blank,
        NPC_TEMPLATE: blank.copy(),
        ANCHOR_REFERENCE: anchor_reference,
        COLLISION_REFERENCE: collision_reference,
    }


def candidate_geometry(width: int, height: int) -> dict[str, list[tuple[int, int]]]:
    half_head = max(6, round(width * 0.19))
    head_top = -height + max(3, round(height * 0.06))
    head_bottom = head_top + max(13, round(height * 0.27))
    shoulder = max(9, round(width * 0.27))
    hand = shoulder + max(2, round(width * 0.06))
    torso_bottom = -max(11, round(height * 0.23))
    foot_width = max(7, round(width * 0.20))
    center_gap = 1

    return {
        "head": [
            (-half_head + 2, head_top),
            (half_head - 2, head_top),
            (half_head, head_top + 3),
            (half_head, head_bottom - 3),
            (half_head - 3, head_bottom),
            (-half_head + 3, head_bottom),
            (-half_head, head_bottom - 3),
            (-half_head, head_top + 3),
        ],
        "body": [
            (-shoulder, head_bottom - 1),
            (shoulder, head_bottom - 1),
            (shoulder + 1, torso_bottom - 5),
            (shoulder - 3, torso_bottom),
            (-shoulder + 3, torso_bottom),
            (-shoulder - 1, torso_bottom - 5),
        ],
        "left_arm": [
            (-shoulder, head_bottom + 2),
            (-shoulder + 3, head_bottom + 1),
            (-shoulder + 2, torso_bottom + 2),
            (-hand, torso_bottom + 1),
        ],
        "right_arm": [
            (shoulder - 3, head_bottom + 1),
            (shoulder, head_bottom + 2),
            (hand, torso_bottom + 1),
            (shoulder - 2, torso_bottom + 2),
        ],
        "left_leg": [
            (-foot_width, torso_bottom - 1),
            (-center_gap, torso_bottom - 1),
            (-center_gap, -3),
            (-foot_width - 1, -3),
        ],
        "right_leg": [
            (center_gap, torso_bottom - 1),
            (foot_width, torso_bottom - 1),
            (foot_width + 1, -3),
            (center_gap, -3),
        ],
        "left_foot": [(-foot_width - 2, -4), (-center_gap, -4), (-center_gap, 0), (-foot_width - 3, 0)],
        "right_foot": [(center_gap, -4), (foot_width + 2, -4), (foot_width + 3, 0), (center_gap, 0)],
    }


def draw_silhouette(draw: ImageDraw.ImageDraw, feet: tuple[int, int], width: int, height: int) -> None:
    feet_x, feet_y = feet
    geometry = candidate_geometry(width, height)

    def translated(points: list[tuple[int, int]]) -> list[tuple[int, int]]:
        return [(feet_x + x, feet_y + y) for x, y in points]

    draw.polygon(translated(geometry["left_leg"]), fill=INK)
    draw.polygon(translated(geometry["right_leg"]), fill=INK)
    draw.polygon(translated(geometry["left_foot"]), fill=INK)
    draw.polygon(translated(geometry["right_foot"]), fill=INK)
    draw.polygon(translated(geometry["left_arm"]), fill=BODY)
    draw.polygon(translated(geometry["right_arm"]), fill=BODY)
    draw.polygon(translated(geometry["body"]), fill=BODY)
    draw.polygon(translated(geometry["head"]), fill=LIGHT)


def tile(atlas: Image.Image, column: int, row: int) -> Image.Image:
    return atlas.crop((column * 32, row * 32, (column + 1) * 32, (row + 1) * 32))


def tile_rect(canvas: Image.Image, source: Image.Image, rectangle: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = rectangle
    for y in range(top, bottom, source.height):
        for x in range(left, right, source.width):
            canvas.alpha_composite(source, (x, y))


def load_environment() -> dict[str, Image.Image]:
    return {key: Image.open(path).convert("RGBA") for key, path in ENVIRONMENT_ASSETS.items()}


def draw_surface_bands(canvas: Image.Image, environment: dict[str, Image.Image], top: int, bottom: int) -> None:
    atlas = environment["terrain"]
    grass = tile(atlas, 0, 0)
    road = tile(atlas, 0, 1)
    plaza = tile(atlas, 4, 4)
    tile_rect(canvas, grass, (0, top, canvas.width // 3, bottom))
    tile_rect(canvas, road, (canvas.width // 3, top, canvas.width * 2 // 3, bottom))
    tile_rect(canvas, plaza, (canvas.width * 2 // 3, top, canvas.width, bottom))


def create_scale_comparison(environment: dict[str, Image.Image]) -> Image.Image:
    panel_width = 480
    height = 360
    comparison = Image.new("RGBA", (panel_width * len(CANDIDATES), height), PANEL)

    for index, (name, width, sprite_height) in enumerate(CANDIDATES):
        panel = Image.new("RGBA", (panel_width, height), PANEL)
        draw_surface_bands(panel, environment, 24, height)
        draw = ImageDraw.Draw(panel)
        draw.rectangle((0, 0, panel_width - 1, 23), fill=PANEL)
        draw.text((8, 7), f"{name} | {width}x{sprite_height} canvas | native pixels", fill=TEXT)

        panel.alpha_composite(environment["building"], (8, 28))
        draw_silhouette(draw, (220, 175), width, sprite_height)
        panel.alpha_composite(environment["bench"], (238, 111))
        panel.alpha_composite(environment["lantern"], (328, 79))
        panel.alpha_composite(environment["tree"], (382, 79))

        surface_y = 350
        for surface_x, surface_name in ((80, "GRASS"), (240, "ROAD"), (400, "PLAZA")):
            draw_silhouette(draw, (surface_x, surface_y), width, sprite_height)
            text_left = surface_x - 18 if surface_name != "PLAZA" else surface_x - 20
            draw.text((text_left, 220), surface_name, fill=(34, 31, 28, 255))

        comparison.alpha_composite(panel, (index * panel_width, 0))

    return comparison


def create_collision_overlay() -> Image.Image:
    panel_width = 340
    height = 300
    scale = 3
    overlay = Image.new("RGBA", (panel_width * len(CANDIDATES), height), PANEL)

    for index, (name, width, sprite_height) in enumerate(CANDIDATES):
        left = index * panel_width
        draw = ImageDraw.Draw(overlay, "RGBA")
        center_x = left + panel_width // 2
        feet_y = 250
        canvas_left = center_x - width * scale // 2
        canvas_top = feet_y - sprite_height * scale
        canvas_right = canvas_left + width * scale - 1
        canvas_bottom = feet_y - 1

        collision_left = center_x - 12 * scale
        collision_top = feet_y - 24 * scale
        collision_right = collision_left + 24 * scale - 1
        collision_bottom = feet_y - 1
        draw.rectangle(
            (collision_left, collision_top, collision_right, collision_bottom),
            fill=(247, 183, 73, 38),
        )

        small = Image.new("RGBA", (width, sprite_height), (0, 0, 0, 0))
        draw_silhouette(ImageDraw.Draw(small), (width // 2, sprite_height - 1), width, sprite_height)
        enlarged = small.resize((width * scale, sprite_height * scale), Image.Resampling.NEAREST)
        overlay.alpha_composite(enlarged, (canvas_left, canvas_top))

        draw.rectangle((canvas_left, canvas_top, canvas_right, canvas_bottom), outline=GUIDE, width=2)
        draw.rectangle(
            (collision_left, collision_top, collision_right, collision_bottom),
            outline=COLLISION,
            width=2,
        )
        draw.line((canvas_left, feet_y - 1, canvas_right, feet_y - 1), fill=ANCHOR, width=2)
        origin_y = feet_y - 12 * scale
        draw.line((center_x - 5, origin_y, center_x + 5, origin_y), fill=ORIGIN, width=2)
        draw.line((center_x, origin_y - 5, center_x, origin_y + 5), fill=ORIGIN, width=2)
        draw.ellipse((center_x - 3, feet_y - 4, center_x + 3, feet_y + 2), fill=ANCHOR)

        draw.text((left + 12, 10), name, fill=TEXT)
        draw.text((left + 12, 27), f"canvas {width}x{sprite_height}", fill=GUIDE)
        draw.text((left + 12, 44), "collision 24x24", fill=COLLISION)
        draw.text((left + 12, 61), f"overhang {int((width - 24) / 2)} px/side", fill=TEXT)
        draw.text((left + 12, 78), f"visual above collision {sprite_height - 24} px", fill=TEXT)
        draw.text((left + 12, 272), "green feet anchor | red Player origin", fill=TEXT)

    return overlay


def create_environment_scale(environment: dict[str, Image.Image]) -> Image.Image:
    canvas = Image.new("RGBA", (640, 360), PANEL)
    atlas = environment["terrain"]
    grass = tile(atlas, 0, 0)
    road = tile(atlas, 0, 1)
    plaza = tile(atlas, 4, 4)
    threshold = tile(atlas, 3, 4)

    tile_rect(canvas, grass, (0, 0, 256, 360))
    tile_rect(canvas, road, (256, 0, 384, 360))
    tile_rect(canvas, threshold, (384, 0, 416, 360))
    tile_rect(canvas, plaza, (416, 0, 640, 360))
    canvas.alpha_composite(environment["building"], (16, 40))
    canvas.alpha_composite(environment["bench"], (252, 116))
    canvas.alpha_composite(environment["lantern"], (364, 84))
    canvas.alpha_composite(environment["edenite"], (416, 84))
    canvas.alpha_composite(environment["planter"], (488, 116))
    canvas.alpha_composite(environment["tree"], (544, 84))

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.rectangle((0, 0, 640, 23), fill=PANEL)
    draw.text((8, 7), "640x360 CHARACTER SCALE LAB | Candidate B 40x56 | noncanonical", fill=TEXT)
    draw.rectangle((316, 316, 339, 339), fill=(247, 183, 73, 38), outline=COLLISION, width=1)
    draw_silhouette(draw, (328, 340), 40, 56)
    draw.rectangle((316, 316, 339, 339), outline=COLLISION, width=1)
    draw.line((308, 339, 347, 339), fill=ANCHOR, width=1)
    draw.text((268, 255), "recommended development silhouette", fill=(31, 29, 26, 255))
    return canvas


def create_template_preview(anchor_reference: Image.Image) -> Image.Image:
    width, height = 1040, 520
    preview = Image.new("RGBA", (width, height), PANEL)
    draw = ImageDraw.Draw(preview)
    draw.text((12, 10), "CADEN CHARACTER SHEET TEMPLATE V1 | 160x224 | cells 40x56", fill=TEXT)
    origin_x, origin_y = 190, 58
    scale = 2

    checkerboard = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
    for y in range(SHEET_SIZE[1]):
        for x in range(SHEET_SIZE[0]):
            color = (64, 60, 54, 255) if (x // 8 + y // 8) % 2 == 0 else (82, 76, 68, 255)
            checkerboard.putpixel((x, y), color)
    checkerboard = checkerboard.resize(
        (SHEET_SIZE[0] * scale, SHEET_SIZE[1] * scale),
        Image.Resampling.NEAREST,
    )
    enlarged_reference = anchor_reference.resize(
        (SHEET_SIZE[0] * scale, SHEET_SIZE[1] * scale),
        Image.Resampling.NEAREST,
    )
    preview.alpha_composite(checkerboard, (origin_x, origin_y))
    preview.alpha_composite(enlarged_reference, (origin_x, origin_y))

    row_names = ("DOWN", "LEFT", "RIGHT", "UP")
    for row, row_name in enumerate(row_names):
        draw.text((origin_x - 54, origin_y + row * CELL_HEIGHT * scale + 50), row_name, fill=TEXT)
    column_names = ("1 NEUTRAL", "2 STEP A", "3 PASSING", "4 STEP B")
    for column, column_name in enumerate(column_names):
        draw.text((origin_x + column * CELL_WIDTH * scale + 5, origin_y - 17), column_name, fill=TEXT)

    note_x = 550
    draw.text((note_x, 82), "Cell: 40x56", fill=TEXT)
    draw.text((note_x, 108), "Rows: down, left, right, up", fill=TEXT)
    draw.text((note_x, 134), "Columns:", fill=TEXT)
    draw.text((note_x + 18, 156), "neutral", fill=TEXT)
    draw.text((note_x + 18, 178), "step A", fill=TEXT)
    draw.text((note_x + 18, 200), "passing/contact", fill=TEXT)
    draw.text((note_x + 18, 222), "step B", fill=TEXT)
    draw.text((note_x, 270), "Green: bottom-center feet-contact line", fill=ANCHOR)
    draw.text((note_x, 296), "Cyan: production cell boundary", fill=GUIDE)
    draw.text((note_x, 344), "Production PNGs are completely transparent.", fill=TEXT)
    draw.text((note_x, 370), "Guides exist only in separate reference files.", fill=TEXT)
    return preview


def expected_outputs(environment: dict[str, Image.Image]) -> dict[Path, Image.Image]:
    outputs = create_templates()
    anchor_reference = outputs[ANCHOR_REFERENCE]
    outputs.update(
        {
            SCALE_COMPARISON: create_scale_comparison(environment),
            COLLISION_OVERLAY: create_collision_overlay(),
            ENVIRONMENT_SCALE: create_environment_scale(environment),
            TEMPLATE_PREVIEW: create_template_preview(anchor_reference),
        }
    )
    return outputs


def verify_existing(outputs: dict[Path, Image.Image]) -> None:
    for path, expected in outputs.items():
        if not path.is_file():
            raise SystemExit(f"Missing generated output: {path.relative_to(ROOT)}")
        actual = Image.open(path).convert("RGBA")
        if actual.size != expected.size or actual.tobytes() != expected.tobytes():
            raise SystemExit(f"Generated output is stale: {path.relative_to(ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="Verify protected inputs and compare existing output pixels without writing.",
    )
    args = parser.parse_args()

    verify_environment_assets()
    environment = load_environment()
    outputs = expected_outputs(environment)
    if args.verify_only:
        verify_existing(outputs)
    else:
        for path, image in outputs.items():
            save_png(image, path)

    verify_environment_assets()
    for path in outputs:
        print(f"{path.relative_to(ROOT).as_posix()} {sha256(path)}")


if __name__ == "__main__":
    main()
