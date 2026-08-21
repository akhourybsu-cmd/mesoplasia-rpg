#!/usr/bin/env python3
"""Audit the supplied Caden Player master and build review-only candidates.

This tool audits a master and writes review candidates beneath the selected
output directory. Candidate A is an exact-cell nearest-neighbor reduction.
Candidate B uses one shared scale with translation-only centering and feet
alignment. Both use deterministic binary-alpha cleanup. Production promotion
is opt-in and is refused unless the source quality gate passes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
REQUESTED_SOURCE = ROOT / "assets/source_art/caden/characters/player/caden_player_character_master_v1.png"
SUPPLIED_SOURCE = ROOT / "assets/source_art/caden/characters/player/caden_player_character_master_v1.png.png"
DEFAULT_OUTPUT_DIR = ROOT / "docs/art/previews"

DIRECTIONS = ("down", "left", "right", "up")
POSES = ("neutral", "step_a", "passing", "step_b")
SOURCE_COLUMNS = 4
SOURCE_ROWS = 4
TARGET_CELL = (40, 56)
TARGET_SHEET = (160, 224)
ALPHA_THRESHOLD = 128
EDGE_APPROACH_DISTANCE = 8

PREVIEW_BG = (25, 23, 22, 255)
PREVIEW_PANEL = (43, 39, 35, 255)
PREVIEW_TEXT = (240, 230, 210, 255)
PREVIEW_MUTED = (180, 170, 155, 255)
PREVIEW_CYAN = (70, 220, 235, 255)
PREVIEW_GREEN = (80, 225, 125, 255)
PREVIEW_RED = (250, 85, 75, 255)
PREVIEW_AMBER = (250, 190, 70, 255)


def _font(size: int = 14) -> ImageFont.ImageFont:
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _relative(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def _checkerboard(size: tuple[int, int], cell: int = 8) -> Image.Image:
    image = Image.new("RGBA", size, (31, 29, 28, 255))
    draw = ImageDraw.Draw(image)
    alternate = (49, 46, 43, 255)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, min(x + cell - 1, size[0] - 1), min(y + cell - 1, size[1] - 1)), fill=alternate)
    return image


def _binary_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    mask = rgba.getchannel("A").point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)
    cleaned = rgba.copy()
    cleaned.putalpha(mask)
    result = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    result.paste(cleaned, (0, 0), mask)
    return result


def _edge_counts(mask: Image.Image) -> dict[str, int]:
    width, height = mask.size
    return {
        "left": sum(1 for y in range(height) if mask.getpixel((0, y)) > 0),
        "right": sum(1 for y in range(height) if mask.getpixel((width - 1, y)) > 0),
        "top": sum(1 for x in range(width) if mask.getpixel((x, 0)) > 0),
        "bottom": sum(1 for x in range(width) if mask.getpixel((x, height - 1)) > 0),
    }


def _connected_components(mask: Image.Image) -> list[list[tuple[int, int]]]:
    width, height = mask.size
    remaining = {
        (x, y)
        for y in range(height)
        for x in range(width)
        if mask.getpixel((x, y)) > 0
    }
    components: list[list[tuple[int, int]]] = []
    while remaining:
        stack = [remaining.pop()]
        component: list[tuple[int, int]] = []
        while stack:
            x, y = stack.pop()
            component.append((x, y))
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    stack.append(neighbor)
        components.append(component)
    components.sort(key=len, reverse=True)
    return components


def _component_summary(component: list[tuple[int, int]], size: tuple[int, int]) -> dict[str, Any]:
    width, height = size
    xs = [point[0] for point in component]
    ys = [point[1] for point in component]
    bbox = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
    return {
        "pixel_count": len(component),
        "bbox": _bbox_dict(bbox),
        "edge_counts": {
            "left": sum(1 for x, _y in component if x == 0),
            "right": sum(1 for x, _y in component if x == width - 1),
            "top": sum(1 for _x, y in component if y == 0),
            "bottom": sum(1 for _x, y in component if y == height - 1),
        },
    }


def _largest_component_binary(image: Image.Image) -> Image.Image:
    cleaned = _binary_alpha(image)
    mask = cleaned.getchannel("A")
    components = _connected_components(mask)
    if not components:
        return cleaned
    largest_mask = Image.new("L", image.size, 0)
    pixels = largest_mask.load()
    for x, y in components[0]:
        pixels[x, y] = 255
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    result.paste(cleaned, (0, 0), largest_mask)
    return result


def _bbox_dict(bbox: tuple[int, int, int, int] | None) -> dict[str, float | int] | None:
    if bbox is None:
        return None
    left, top, right, bottom = bbox
    return {
        "left": left,
        "top": top,
        "right_exclusive": right,
        "bottom_exclusive": bottom,
        "width": right - left,
        "height": bottom - top,
        "horizontal_center": round((left + right - 1) / 2.0, 3),
        "bottommost_pixel": bottom - 1,
    }


def _frame_metrics(cell: Image.Image, row: int, column: int) -> dict[str, Any]:
    alpha = cell.getchannel("A")
    histogram = alpha.histogram()
    visible_mask = alpha.point(lambda value: 255 if value > 0 else 0)
    strong_mask = alpha.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)
    components = _connected_components(strong_mask)
    component_summaries = [_component_summary(component, cell.size) for component in components]
    primary = component_summaries[0] if component_summaries else None
    total = cell.width * cell.height
    return {
        "frame": f"r{row + 1}c{column + 1}",
        "direction": DIRECTIONS[row],
        "pose": POSES[column],
        "alpha_counts": {
            "transparent": histogram[0],
            "partial": sum(histogram[1:255]),
            "opaque": histogram[255],
            "total": total,
        },
        "visible_alpha_bbox": _bbox_dict(visible_mask.getbbox()),
        "strong_alpha_bbox": _bbox_dict(strong_mask.getbbox()),
        "primary_strong_alpha_bbox": primary["bbox"] if primary else None,
        "visible_alpha_edge_counts": _edge_counts(visible_mask),
        "strong_alpha_edge_counts": _edge_counts(strong_mask),
        "primary_strong_alpha_edge_counts": primary["edge_counts"] if primary else None,
        "strong_alpha_components": component_summaries,
    }


def _split_cells(image: Image.Image) -> tuple[list[Image.Image], tuple[int, int]]:
    if image.width % SOURCE_COLUMNS != 0 or image.height % SOURCE_ROWS != 0:
        raise ValueError(f"Source {image.size} does not divide evenly into a 4x4 grid.")
    cell_width = image.width // SOURCE_COLUMNS
    cell_height = image.height // SOURCE_ROWS
    cells = []
    for row in range(SOURCE_ROWS):
        for column in range(SOURCE_COLUMNS):
            cells.append(
                image.crop(
                    (
                        column * cell_width,
                        row * cell_height,
                        (column + 1) * cell_width,
                        (row + 1) * cell_height,
                    )
                )
            )
    return cells, (cell_width, cell_height)


def _candidate_a(cells: list[Image.Image]) -> tuple[Image.Image, list[Image.Image]]:
    target_cells = [
        _binary_alpha(cell.resize(TARGET_CELL, Image.Resampling.NEAREST))
        for cell in cells
    ]
    return _assemble_sheet(target_cells), target_cells


def _candidate_b(cells: list[Image.Image]) -> tuple[Image.Image, list[Image.Image], float]:
    cleaned = [_largest_component_binary(cell) for cell in cells]
    bboxes = [cell.getchannel("A").getbbox() for cell in cleaned]
    if any(bbox is None for bbox in bboxes):
        raise ValueError("Candidate B cannot normalize an empty frame.")

    concrete_bboxes = [bbox for bbox in bboxes if bbox is not None]
    maximum_width = max(bbox[2] - bbox[0] for bbox in concrete_bboxes)
    maximum_height = max(bbox[3] - bbox[1] for bbox in concrete_bboxes)
    # A shared 53-pixel maximum painted height preserves the documented 2-pixel
    # top allowance and puts contact feet on row 55 without per-frame scaling.
    shared_scale = min(38.0 / maximum_width, 53.0 / maximum_height)

    target_cells: list[Image.Image] = []
    for cell, bbox in zip(cleaned, concrete_bboxes):
        crop = cell.crop(bbox)
        scaled_size = (
            max(1, round(crop.width * shared_scale)),
            max(1, round(crop.height * shared_scale)),
        )
        scaled = crop.resize(scaled_size, Image.Resampling.NEAREST)
        scaled_bbox = scaled.getchannel("A").getbbox()
        if scaled_bbox is None:
            raise ValueError("Candidate B lost a frame during nearest-neighbor reduction.")
        scaled = scaled.crop(scaled_bbox)
        target = Image.new("RGBA", TARGET_CELL, (0, 0, 0, 0))
        paste_x = round(TARGET_CELL[0] / 2 - scaled.width / 2)
        paste_y = TARGET_CELL[1] - scaled.height
        target.alpha_composite(scaled, (paste_x, paste_y))
        target_cells.append(target)

    return _assemble_sheet(target_cells), target_cells, shared_scale


def _assemble_sheet(cells: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", TARGET_SHEET, (0, 0, 0, 0))
    for index, cell in enumerate(cells):
        row, column = divmod(index, SOURCE_COLUMNS)
        sheet.alpha_composite(cell, (column * TARGET_CELL[0], row * TARGET_CELL[1]))
    return sheet


def _candidate_metrics(cells: list[Image.Image]) -> dict[str, Any]:
    metrics = [_frame_metrics(cell, index // 4, index % 4) for index, cell in enumerate(cells)]
    baseline_spreads: dict[str, int] = {}
    for row, direction in enumerate(DIRECTIONS):
        bottoms = [
            metrics[row * 4 + column]["primary_strong_alpha_bbox"]["bottommost_pixel"]
            for column in range(4)
        ]
        baseline_spreads[direction] = max(bottoms) - min(bottoms)
    return {"frames": metrics, "baseline_spread_pixels": baseline_spreads}


def _draw_source_grid_audit(
    cells: list[Image.Image],
    metrics: list[dict[str, Any]],
    cell_size: tuple[int, int],
) -> Image.Image:
    header_height = 24
    cell_width, cell_height = cell_size
    audit = Image.new("RGBA", (cell_width * 4, (cell_height + header_height) * 4), PREVIEW_BG)
    draw = ImageDraw.Draw(audit)
    font = _font(15)
    for index, (cell, frame) in enumerate(zip(cells, metrics)):
        row, column = divmod(index, 4)
        origin_x = column * cell_width
        origin_y = row * (cell_height + header_height)
        label = f"{frame['frame']}  {frame['direction']} / {frame['pose']}"
        draw.rectangle((origin_x, origin_y, origin_x + cell_width - 1, origin_y + header_height - 1), fill=PREVIEW_PANEL)
        draw.text((origin_x + 5, origin_y + 4), label, font=font, fill=PREVIEW_TEXT)
        checker = _checkerboard(cell_size, 16)
        checker.alpha_composite(cell)
        audit.alpha_composite(checker, (origin_x, origin_y + header_height))
        sprite_y = origin_y + header_height
        draw.rectangle(
            (origin_x, sprite_y, origin_x + cell_width - 1, sprite_y + cell_height - 1),
            outline=PREVIEW_CYAN,
            width=2,
        )
        visible_bbox = frame["visible_alpha_bbox"]
        if visible_bbox is not None:
            draw.rectangle(
                (
                    origin_x + int(visible_bbox["left"]),
                    sprite_y + int(visible_bbox["top"]),
                    origin_x + int(visible_bbox["right_exclusive"]) - 1,
                    sprite_y + int(visible_bbox["bottom_exclusive"]) - 1,
                ),
                outline=PREVIEW_AMBER,
                width=1,
            )
        bbox = frame["primary_strong_alpha_bbox"]
        if bbox is not None:
            left = origin_x + int(bbox["left"])
            top = sprite_y + int(bbox["top"])
            right = origin_x + int(bbox["right_exclusive"]) - 1
            bottom = sprite_y + int(bbox["bottom_exclusive"]) - 1
            center = origin_x + int(round(float(bbox["horizontal_center"])))
            draw.rectangle((left, top, right, bottom), outline=PREVIEW_GREEN, width=2)
            draw.line((center, top, center, bottom), fill=PREVIEW_CYAN, width=1)
            draw.line((left, bottom, right, bottom), fill=PREVIEW_RED, width=2)
        for artifact in frame["strong_alpha_components"][1:]:
            artifact_bbox = artifact["bbox"]
            draw.rectangle(
                (
                    origin_x + int(artifact_bbox["left"]),
                    sprite_y + int(artifact_bbox["top"]),
                    origin_x + int(artifact_bbox["right_exclusive"]) - 1,
                    sprite_y + int(artifact_bbox["bottom_exclusive"]) - 1,
                ),
                outline=PREVIEW_RED,
                width=2,
            )
        edges = frame["primary_strong_alpha_edge_counts"]
        if any(edges.values()):
            edge_label = "CLIP " + ", ".join(f"{key[0].upper()}={value}" for key, value in edges.items() if value)
            draw.rectangle((origin_x + 3, sprite_y + cell_height - 24, origin_x + 150, sprite_y + cell_height - 4), fill=(70, 15, 15, 230))
            draw.text((origin_x + 6, sprite_y + cell_height - 22), edge_label, font=font, fill=PREVIEW_RED)
    return audit


def _draw_lineup(candidate_a: Image.Image, candidate_b: Image.Image, gate_passed: bool) -> Image.Image:
    zoom = 4
    scaled_size = (TARGET_SHEET[0] * zoom, TARGET_SHEET[1] * zoom)
    gap = 44
    top = 58
    lineup = Image.new("RGBA", (scaled_size[0] * 2 + gap + 32, scaled_size[1] + top + 24), PREVIEW_BG)
    draw = ImageDraw.Draw(lineup)
    font = _font(18)
    status = (
        "REVIEW CANDIDATES - SOURCE QUALITY GATE PASSED"
        if gate_passed
        else "REVIEW-ONLY CANDIDATES - SOURCE QUALITY GATE FAILED"
    )
    draw.text((16, 12), status, font=font, fill=PREVIEW_GREEN if gate_passed else PREVIEW_RED)
    draw.text((16, 36), "A: exact 265x371 cell -> 40x56 nearest-neighbor + binary alpha", font=_font(14), fill=PREVIEW_TEXT)
    second_x = 16 + scaled_size[0] + gap
    draw.text((second_x, 36), "B: one shared scale + translation-only feet/center alignment", font=_font(14), fill=PREVIEW_TEXT)
    for x, sheet in ((16, candidate_a), (second_x, candidate_b)):
        panel = _checkerboard(scaled_size, 16)
        panel.alpha_composite(sheet.resize(scaled_size, Image.Resampling.NEAREST))
        lineup.alpha_composite(panel, (x, top))
        panel_draw = ImageDraw.Draw(lineup)
        for column in range(5):
            line_x = x + column * TARGET_CELL[0] * zoom
            panel_draw.line((line_x, top, line_x, top + scaled_size[1]), fill=PREVIEW_CYAN, width=1)
        for row in range(5):
            line_y = top + row * TARGET_CELL[1] * zoom
            panel_draw.line((x, line_y, x + scaled_size[0], line_y), fill=PREVIEW_CYAN, width=1)
    return lineup


def _draw_anchor_overlay(candidate_a: Image.Image, candidate_b: Image.Image) -> Image.Image:
    zoom = 4
    sheet_size = (TARGET_SHEET[0] * zoom, TARGET_SHEET[1] * zoom)
    top = 62
    gap = 38
    image = Image.new("RGBA", (sheet_size[0] + 32, top + sheet_size[1] * 2 + gap + 24), PREVIEW_BG)
    draw = ImageDraw.Draw(image)
    draw.text((16, 12), "ANCHOR / FEET REVIEW — RED=row 55, CYAN=x 20", font=_font(18), fill=PREVIEW_TEXT)
    for block, (label, sheet) in enumerate((("Candidate A", candidate_a), ("Candidate B", candidate_b))):
        y = top + block * (sheet_size[1] + gap)
        draw.text((16, y - 20), label, font=_font(14), fill=PREVIEW_AMBER)
        panel = _checkerboard(sheet_size, 16)
        panel.alpha_composite(sheet.resize(sheet_size, Image.Resampling.NEAREST))
        image.alpha_composite(panel, (16, y))
        for row in range(4):
            for column in range(4):
                left = 16 + column * TARGET_CELL[0] * zoom
                cell_top = y + row * TARGET_CELL[1] * zoom
                center_x = left + 20 * zoom
                feet_y = cell_top + 55 * zoom
                draw.line((center_x, cell_top, center_x, cell_top + 56 * zoom - 1), fill=PREVIEW_CYAN, width=1)
                draw.line((left, feet_y, left + 40 * zoom - 1, feet_y), fill=PREVIEW_RED, width=2)
                draw.rectangle((left, cell_top, left + 40 * zoom - 1, cell_top + 56 * zoom - 1), outline=PREVIEW_MUTED)
    return image


def _draw_source_vs_runtime(
    source_cells: list[Image.Image],
    candidate_a_cells: list[Image.Image],
    candidate_b_cells: list[Image.Image],
) -> Image.Image:
    source_display = (132, 185)
    runtime_display = (160, 224)
    row_height = 244
    image = Image.new("RGBA", (620, 42 + row_height * 4), PREVIEW_BG)
    draw = ImageDraw.Draw(image)
    draw.text((16, 10), "REPRESENTATIVE SOURCE vs REVIEW CANDIDATES", font=_font(18), fill=PREVIEW_TEXT)
    for row, direction in enumerate(DIRECTIONS):
        index = row * 4
        top = 42 + row * row_height
        draw.text((16, top + 6), direction.upper(), font=_font(16), fill=PREVIEW_AMBER)
        source_panel = _checkerboard(source_display, 10)
        source_panel.alpha_composite(source_cells[index].resize(source_display, Image.Resampling.NEAREST))
        image.alpha_composite(source_panel, (98, top + 26))
        a_panel = _checkerboard(runtime_display, 12)
        a_panel.alpha_composite(candidate_a_cells[index].resize(runtime_display, Image.Resampling.NEAREST))
        image.alpha_composite(a_panel, (256, top + 8))
        b_panel = _checkerboard(runtime_display, 12)
        b_panel.alpha_composite(candidate_b_cells[index].resize(runtime_display, Image.Resampling.NEAREST))
        image.alpha_composite(b_panel, (438, top + 8))
        draw.text((125, top + 212), "source", font=_font(13), fill=PREVIEW_MUTED)
        draw.text((314, top + 232), "A", font=_font(13), fill=PREVIEW_MUTED)
        draw.text((496, top + 232), "B", font=_font(13), fill=PREVIEW_MUTED)
    return image


def _load_rgba(relative_path: str) -> Image.Image:
    return Image.open(ROOT / relative_path).convert("RGBA")


def _draw_environment_preview(
    candidate_a_cells: list[Image.Image],
    candidate_b_cells: list[Image.Image],
    gate_passed: bool,
) -> Image.Image:
    image = Image.new("RGBA", (640, 360), (52, 48, 41, 255))
    draw = ImageDraw.Draw(image)
    atlas = _load_rgba("assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png")
    grass = atlas.crop((0, 0, 32, 32))
    road = atlas.crop((64, 32, 96, 64))
    plaza = atlas.crop((128, 128, 160, 160))
    for y in range(168, 360, 32):
        for x in range(0, 640, 32):
            tile = grass if x < 224 else road if x < 416 else plaza
            image.alpha_composite(tile, (x, y))

    building = _load_rgba("assets/environments/caden/architecture/town_square/town_square_building_northwest_v1_1.png")
    bench = _load_rgba("assets/environments/caden/props/seating/caden_bench_01_v1.png")
    lantern = _load_rgba("assets/environments/caden/props/lighting/caden_lantern_post_01_v1.png")
    edenite = _load_rgba("assets/environments/caden/accents/edenite/caden_edenite_lantern_01_v1.png")
    tree = _load_rgba("assets/environments/caden/nature/trees/caden_tree_medium_01_v1.png")
    image.alpha_composite(building, (10, 8))
    image.alpha_composite(bench, (250, 88))
    image.alpha_composite(lantern, (370, 58))
    image.alpha_composite(edenite, (432, 58))
    image.alpha_composite(tree, (542, 58))

    def paste_feet(cell: Image.Image, x: int, feet_y: int) -> None:
        image.alpha_composite(cell, (x - 20, feet_y - 56))

    paste_feet(candidate_a_cells[0], 180, 160)
    paste_feet(candidate_b_cells[0], 214, 160)
    paste_feet(candidate_b_cells[0], 112, 336)
    paste_feet(candidate_b_cells[4], 304, 336)
    paste_feet(candidate_b_cells[8], 496, 336)
    draw.rectangle((0, 0, 640, 28), fill=(12, 55, 30, 235) if gate_passed else (55, 12, 12, 235))
    status = (
        "RUNTIME CANDIDATE - SOURCE GATE PASSED; SCALE REVIEW"
        if gate_passed
        else "REVIEW ONLY - SOURCE QUALITY GATE FAILED; NOT INTEGRATED"
    )
    draw.text((10, 6), status, font=_font(16), fill=PREVIEW_GREEN if gate_passed else PREVIEW_RED)
    draw.text((8, 342), "grass", font=_font(12), fill=PREVIEW_TEXT)
    draw.text((228, 342), "road", font=_font(12), fill=PREVIEW_TEXT)
    draw.text((420, 342), "plaza", font=_font(12), fill=PREVIEW_TEXT)
    return image.resize((1280, 720), Image.Resampling.NEAREST)


def _draw_animation_strip(candidate_a_cells: list[Image.Image], candidate_b_cells: list[Image.Image]) -> Image.Image:
    zoom = 4
    cell_display = (TARGET_CELL[0] * zoom, TARGET_CELL[1] * zoom)
    left = 120
    row_height = cell_display[1] + 32
    image = Image.new("RGBA", (left + cell_display[0] * 4 + 24, 42 + row_height * 8), PREVIEW_BG)
    draw = ImageDraw.Draw(image)
    draw.text((12, 10), "DIRECTIONAL CYCLES - A then B (REVIEW ONLY)", font=_font(18), fill=PREVIEW_TEXT)
    for method_index, (method, cells) in enumerate((("A", candidate_a_cells), ("B", candidate_b_cells))):
        for direction_index, direction in enumerate(DIRECTIONS):
            row_index = method_index * 4 + direction_index
            top = 42 + row_index * row_height
            draw.text((12, top + 94), f"{method}  {direction}", font=_font(16), fill=PREVIEW_AMBER)
            for column in range(4):
                panel = _checkerboard(cell_display, 16)
                source_cell = cells[direction_index * 4 + column]
                panel.alpha_composite(source_cell.resize(cell_display, Image.Resampling.NEAREST))
                x = left + column * cell_display[0]
                image.alpha_composite(panel, (x, top))
                draw.rectangle((x, top, x + cell_display[0] - 1, top + cell_display[1] - 1), outline=PREVIEW_CYAN)
                draw.text((x + 4, top + 4), POSES[column], font=_font(12), fill=PREVIEW_TEXT)
    return image


def _audit_source(
    source: Path,
    requested_source: Path,
    image: Image.Image,
    cell_size: tuple[int, int],
    cells: list[Image.Image],
) -> dict[str, Any]:
    alpha_histogram = image.getchannel("A").histogram()
    total = image.width * image.height
    frames = [_frame_metrics(cell, index // 4, index % 4) for index, cell in enumerate(cells)]

    clipped_frames = []
    approached_frames = []
    for frame in frames:
        strong_edges = frame["primary_strong_alpha_edge_counts"]
        for edge, count in strong_edges.items():
            if count:
                clipped_frames.append({"frame": frame["frame"], "edge": edge, "strong_pixels": count})
        bbox = frame["primary_strong_alpha_bbox"]
        if bbox is None:
            continue
        distances = {
            "left": int(bbox["left"]),
            "top": int(bbox["top"]),
            "right": cell_size[0] - int(bbox["right_exclusive"]),
            "bottom": cell_size[1] - int(bbox["bottom_exclusive"]),
        }
        near = {edge: distance for edge, distance in distances.items() if distance <= EDGE_APPROACH_DISTANCE}
        if near:
            approached_frames.append({"frame": frame["frame"], "distance_pixels": near})

    source_baselines: dict[str, dict[str, Any]] = {}
    for row, direction in enumerate(DIRECTIONS):
        bottoms = [
            frames[row * 4 + column]["primary_strong_alpha_bbox"]["bottommost_pixel"]
            for column in range(4)
        ]
        source_baselines[direction] = {
            "bottommost_pixels": bottoms,
            "spread_pixels": max(bottoms) - min(bottoms),
        }

    clipped_summary = ", ".join(
        f"{item['frame']} {item['edge']} ({item['strong_pixels']} strong pixels)"
        for item in clipped_frames
    )
    failures = []
    if clipped_frames:
        failures = [
            f"Primary connected character silhouettes reach source-cell boundaries: {clipped_summary}.",
            "Pixels missing beyond a connected source-cell edge cannot be reconstructed by deterministic scaling, translation, padding, connected-component cleanup, or alpha thresholding.",
        ]
    warnings = []
    if source != requested_source:
        warnings.append(
            f"The requested immutable path {_relative(requested_source)} is absent; {_relative(source)} was audited in place without renaming it."
        )
    partial = sum(alpha_histogram[1:255])
    warnings.append(
        f"The source contains {partial} partial-alpha pixels ({partial / total:.6%}); review candidates use a fixed alpha >= {ALPHA_THRESHOLD} binary threshold."
    )
    artifact_components = []
    for frame in frames:
        for component in frame["strong_alpha_components"][1:]:
            artifact_components.append(
                {
                    "frame": frame["frame"],
                    "pixel_count": component["pixel_count"],
                    "bbox": component["bbox"],
                    "edge_counts": component["edge_counts"],
                }
            )
    if artifact_components:
        artifact_summary = ", ".join(
            f"{item['frame']} ({item['pixel_count']} pixels)"
            for item in artifact_components
        )
        warnings.append(
            f"Separate strong-alpha components were classified as deterministic edge contamination: {artifact_summary}. Candidate B keeps only each frame's largest connected component."
        )

    gate_passed = not clipped_frames
    clipped_frame_names = sorted({item["frame"] for item in clipped_frames})
    artifact_frame_names = sorted({item["frame"] for item in artifact_components})
    required_actions = []
    if clipped_frame_names:
        required_actions.append(
            "Recover or replace the clipped primary silhouettes in " + ", ".join(clipped_frame_names) + "."
        )
    if artifact_frame_names:
        required_actions.append(
            "Remove separated edge contamination from " + ", ".join(artifact_frame_names) + "."
        )
    if required_actions:
        required_actions.append("Re-export the complete sheet and repeat this audit.")

    return {
        "schema": "caden-player-source-audit-v1",
        "requested_source_path": _relative(requested_source),
        "requested_source_exists": requested_source.exists(),
        "audited_source_path": _relative(source),
        "source_sha256": _sha256(source),
        "format": image.format or "PNG",
        "mode": image.mode,
        "dimensions": [image.width, image.height],
        "alpha_range": list(image.getchannel("A").getextrema()),
        "alpha_counts": {
            "transparent": alpha_histogram[0],
            "partial": partial,
            "opaque": alpha_histogram[255],
            "total": total,
            "transparent_percent": round(alpha_histogram[0] * 100.0 / total, 6),
            "partial_percent": round(partial * 100.0 / total, 6),
            "opaque_percent": round(alpha_histogram[255] * 100.0 / total, 6),
        },
        "grid": {
            "columns": SOURCE_COLUMNS,
            "rows": SOURCE_ROWS,
            "divides_evenly": image.width % 4 == 0 and image.height % 4 == 0,
            "cell_dimensions": list(cell_size),
            "nonempty_strong_alpha_frames": sum(1 for frame in frames if frame["strong_alpha_bbox"] is not None),
        },
        "frame_order": {
            "rows": list(DIRECTIONS),
            "columns": list(POSES),
            "visual_review": (
                "The apparent row and pose order matches the requested mapping."
                if gate_passed
                else "The apparent row and pose order matches the requested mapping, but source defects block runtime approval."
            ),
        },
        "frames": frames,
        "strong_alpha_clipped_frames": clipped_frames,
        "strong_alpha_approached_frames": approached_frames,
        "separate_strong_alpha_components": artifact_components,
        "source_baselines": source_baselines,
        "quality_gate": {
            "passed": gate_passed,
            "failures": failures,
            "warnings": warnings,
            "required_action": " ".join(required_actions) if required_actions else "Source passes the mechanical integration gate.",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, help="Explicit source master path. The file is read-only.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument(
        "--runtime-output",
        type=Path,
        help="Write approved Candidate B to this production path only when the source gate passes.",
    )
    parser.add_argument(
        "--strict-gate",
        action="store_true",
        help="Return exit code 2 after writing audits when the source quality gate fails.",
    )
    args = parser.parse_args()

    requested_source = args.source.resolve() if args.source else REQUESTED_SOURCE
    source = requested_source if requested_source.exists() else SUPPLIED_SOURCE
    output_dir = args.output_dir.resolve()
    if not source.is_file():
        raise FileNotFoundError(f"No source master found at {source}")

    before_hash = _sha256(source)
    with Image.open(source) as opened:
        source_format = opened.format
        source_image = opened.convert("RGBA")
        source_image.format = source_format

    source_cells, source_cell_size = _split_cells(source_image)
    source_metrics = [_frame_metrics(cell, index // 4, index % 4) for index, cell in enumerate(source_cells)]
    audit = _audit_source(source, requested_source, source_image, source_cell_size, source_cells)

    candidate_a, candidate_a_cells = _candidate_a(source_cells)
    candidate_b, candidate_b_cells, shared_scale = _candidate_b(source_cells)

    outputs = {
        "candidate_a": output_dir / "caden_player_candidate_a_direct_v1.png",
        "candidate_b": output_dir / "caden_player_candidate_b_normalized_v1.png",
        "source_grid_audit": output_dir / "caden_player_source_grid_audit_v1.png",
        "runtime_lineup": output_dir / "caden_player_runtime_lineup_v1.png",
        "runtime_anchor_overlay": output_dir / "caden_player_runtime_anchor_overlay_v1.png",
        "source_vs_runtime": output_dir / "caden_player_source_vs_runtime_v1.png",
        "runtime_environment_preview": output_dir / "caden_player_runtime_environment_preview_v1.png",
        "runtime_animation_strip": output_dir / "caden_player_runtime_animation_strip_v1.png",
    }
    _save_png(candidate_a, outputs["candidate_a"])
    _save_png(candidate_b, outputs["candidate_b"])
    _save_png(_draw_source_grid_audit(source_cells, source_metrics, source_cell_size), outputs["source_grid_audit"])
    _save_png(
        _draw_lineup(candidate_a, candidate_b, audit["quality_gate"]["passed"]),
        outputs["runtime_lineup"],
    )
    _save_png(_draw_anchor_overlay(candidate_a, candidate_b), outputs["runtime_anchor_overlay"])
    _save_png(
        _draw_source_vs_runtime(source_cells, candidate_a_cells, candidate_b_cells),
        outputs["source_vs_runtime"],
    )
    _save_png(
        _draw_environment_preview(
            candidate_a_cells,
            candidate_b_cells,
            audit["quality_gate"]["passed"],
        ),
        outputs["runtime_environment_preview"],
    )
    _save_png(_draw_animation_strip(candidate_a_cells, candidate_b_cells), outputs["runtime_animation_strip"])

    audit["candidate_methods"] = {
        "a": {
            "description": "Exact 265x371 cell reduction to 40x56 with nearest-neighbor sampling, then alpha >= 128 binary cleanup.",
            "sheet_dimensions": list(candidate_a.size),
            "metrics": _candidate_metrics(candidate_a_cells),
        },
        "b": {
            "description": "Largest connected strong-alpha component per cell, scaled by one shared factor, then translation-only horizontal centering and feet alignment.",
            "shared_scale": round(shared_scale, 9),
            "sheet_dimensions": list(candidate_b.size),
            "metrics": _candidate_metrics(candidate_b_cells),
        },
        "selected": "b" if audit["quality_gate"]["passed"] else None,
        "selection_reason": (
            "Candidate B meets the mechanical source gate with one shared scale and aligned feet; visual approval remains required."
            if audit["quality_gate"]["passed"]
            else "Neither candidate can restore source pixels already clipped at cell boundaries, so no production method is selected."
        ),
    }
    audit["generated_outputs"] = {
        name: {"path": _relative(path), "sha256": _sha256(path)}
        for name, path in outputs.items()
    }
    if args.runtime_output:
        if not audit["quality_gate"]["passed"]:
            raise RuntimeError("Refusing to write production runtime art because the source gate failed.")
        runtime_output = args.runtime_output.resolve()
        _save_png(candidate_b, runtime_output)
        audit["promoted_runtime"] = {
            "path": _relative(runtime_output),
            "method": "b",
            "dimensions": list(candidate_b.size),
            "sha256": _sha256(runtime_output),
        }
    audit["source_sha256_after"] = _sha256(source)
    audit["source_unchanged"] = before_hash == audit["source_sha256_after"]

    audit_path = output_dir / "caden_player_source_audit_v1.json"
    audit_path.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(f"audited_source={_relative(source)}")
    print(f"source_sha256_before={before_hash}")
    print(f"source_sha256_after={audit['source_sha256_after']}")
    print(f"source_dimensions={source_image.width}x{source_image.height}")
    print(f"source_cell_dimensions={source_cell_size[0]}x{source_cell_size[1]}")
    print(f"candidate_b_shared_scale={shared_scale:.9f}")
    print(f"quality_gate={'PASS' if audit['quality_gate']['passed'] else 'FAIL'}")
    print(f"audit={_relative(audit_path)}")
    if args.strict_gate and not audit["quality_gate"]["passed"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
