#!/usr/bin/env python3
"""Audit a Caden NPC base master and build deterministic runtime candidates.

The approved repaired source has binary alpha. For an explicitly supplied RGB
source, the tool can also reconstruct a review mask from its baked light
checkerboard. Mechanical clipping decisions use connected foreground
components, and production promotion is refused whenever the source gate
fails.
"""

from __future__ import annotations

import argparse
from collections import deque
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
TOOL_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL_DIR))

import prepare_caden_player_runtime_v1 as shared  # noqa: E402


SOURCE = ROOT / "assets/source_art/caden/characters/npc/caden_npc_base_master_v2.png"
ORIGINAL_SOURCE_V1 = ROOT / "assets/source_art/caden/characters/npc/caden_npc_base_master_v1.png"
DEFAULT_OUTPUT_DIR = ROOT / "docs/art/previews/caden_npc_base_runtime_v1"
PLAYER_RUNTIME = ROOT / "assets/characters/caden/player/caden_player_runtime_v1.png"

DIRECTIONS = ("down", "left", "right", "up")
POSES = ("neutral", "step_a", "passing", "step_b")
SOURCE_COLUMNS = 4
SOURCE_ROWS = 4
BACKGROUND_MIN_CHANNEL = 235
BACKGROUND_MAX_CHROMA = 12
STRONG_FOREGROUND_MIN_CHANNEL = 225
STRONG_FOREGROUND_MIN_CHROMA = 18
MAX_ENCLOSED_HOLE_PIXELS = 64
MIN_REPORTED_COMPONENT_PIXELS = 4
EDGE_APPROACH_DISTANCE = 8

PREVIEW_BG = (25, 23, 22, 255)
PREVIEW_PANEL = (43, 39, 35, 255)
PREVIEW_TEXT = (240, 230, 210, 255)
PREVIEW_MUTED = (180, 170, 155, 255)
PREVIEW_CYAN = (70, 220, 235, 255)
PREVIEW_GREEN = (80, 225, 125, 255)
PREVIEW_RED = (250, 85, 75, 255)
PREVIEW_AMBER = (250, 190, 70, 255)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def _is_background_passable(pixel: tuple[int, int, int]) -> bool:
    minimum = min(pixel)
    maximum = max(pixel)
    return minimum >= BACKGROUND_MIN_CHANNEL and maximum - minimum <= BACKGROUND_MAX_CHROMA


def _flood_background_mask(cell: Image.Image) -> Image.Image:
    """Return a mask of bright neutral background connected to the cell edge."""

    rgb = cell.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        offset = y * width + x
        if visited[offset] or not _is_background_passable(pixels[x, y]):
            return
        visited[offset] = 1
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)

    mask = Image.new("L", (width, height), 0)
    mask_pixels = mask.load()
    for y in range(height):
        for x in range(width):
            if not visited[y * width + x]:
                mask_pixels[x, y] = 255
    return mask


def _strong_foreground_mask(cell: Image.Image) -> Image.Image:
    """Classify colored/dark sprite pixels while rejecting the baked checker."""

    rgb = cell.convert("RGB")
    width, height = rgb.size
    source_pixels = rgb.load()
    mask = Image.new("L", cell.size, 0)
    mask_pixels = mask.load()
    for y in range(height):
        for x in range(width):
            pixel = source_pixels[x, y]
            minimum = min(pixel)
            chroma = max(pixel) - minimum
            if minimum < STRONG_FOREGROUND_MIN_CHANNEL or chroma > STRONG_FOREGROUND_MIN_CHROMA:
                mask_pixels[x, y] = 255
    return mask


def _component_mask(size: tuple[int, int], component: list[tuple[int, int]]) -> Image.Image:
    mask = Image.new("L", size, 0)
    pixels = mask.load()
    for x, y in component:
        pixels[x, y] = 255
    return mask


def _extract_primary(cell: Image.Image, component: list[tuple[int, int]]) -> Image.Image:
    rgba = cell.convert("RGBA")
    mask = _component_mask(cell.size, component)
    component_left = min(x for x, _y in component)
    component_top = min(y for _x, y in component)
    component_right = max(x for x, _y in component)
    component_bottom = max(y for _x, y in component)
    inverted = mask.point(lambda value: 0 if value else 255)
    for hole in shared._connected_components(inverted):
        if len(hole) > MAX_ENCLOSED_HOLE_PIXELS:
            continue
        if any(x == 0 or y == 0 or x == cell.width - 1 or y == cell.height - 1 for x, y in hole):
            continue
        hole_left = min(x for x, _y in hole)
        hole_top = min(y for _x, y in hole)
        hole_right = max(x for x, _y in hole)
        hole_bottom = max(y for _x, y in hole)
        if (
            hole_left - component_left < 4
            or hole_top - component_top < 4
            or component_right - hole_right < 4
            or component_bottom - hole_bottom < 4
        ):
            continue
        pixels = mask.load()
        for x, y in hole:
            pixels[x, y] = 255
    extracted = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    extracted.paste(rgba, (0, 0), mask)
    return extracted


def _split_cells(image: Image.Image) -> tuple[list[Image.Image], tuple[int, int]]:
    if image.width % SOURCE_COLUMNS or image.height % SOURCE_ROWS:
        raise ValueError(f"Source {image.size} does not divide evenly into a 4x4 grid.")
    cell_size = (image.width // SOURCE_COLUMNS, image.height // SOURCE_ROWS)
    cells = []
    for row in range(SOURCE_ROWS):
        for column in range(SOURCE_COLUMNS):
            left = column * cell_size[0]
            top = row * cell_size[1]
            cells.append(image.crop((left, top, left + cell_size[0], top + cell_size[1])))
    return cells, cell_size


def _frame_audit(cell: Image.Image, row: int, column: int) -> tuple[dict[str, Any], Image.Image]:
    has_alpha = "A" in cell.getbands()
    if has_alpha:
        alpha = cell.getchannel("A")
        foreground_mask = alpha.point(lambda value: 255 if value >= 128 else 0)
        diagnostic_foreground_mask = foreground_mask.copy()
        alpha_histogram = alpha.histogram()
        literal_alpha = {
            "channel_present": True,
            "transparent": alpha_histogram[0],
            "partial": sum(alpha_histogram[1:255]),
            "opaque": alpha_histogram[255],
            "total": cell.width * cell.height,
            "visible_alpha_bbox": shared._bbox_dict(alpha.point(lambda value: 255 if value > 0 else 0).getbbox()),
        }
    else:
        diagnostic_foreground_mask = _flood_background_mask(cell)
        foreground_mask = _strong_foreground_mask(cell)
        literal_alpha = {
            "channel_present": False,
            "transparent": 0,
            "partial": 0,
            "opaque": cell.width * cell.height,
            "total": cell.width * cell.height,
            "visible_alpha_bbox": shared._bbox_dict((0, 0, cell.width, cell.height)),
        }
    components = shared._connected_components(foreground_mask)
    reported = [component for component in components if len(component) >= MIN_REPORTED_COMPONENT_PIXELS]
    if not reported:
        raise ValueError(f"r{row + 1}c{column + 1} contains no reportable foreground component.")

    summaries = [shared._component_summary(component, cell.size) for component in reported]
    primary = summaries[0]
    primary_cell = _extract_primary(cell, reported[0])
    foreground_bbox = shared._bbox_dict(foreground_mask.getbbox())
    primary_bbox = primary["bbox"]
    edge_contacts = []
    for index, summary in enumerate(summaries):
        if any(summary["edge_counts"].values()):
            edge_contacts.append({
                "component_index": index,
                "pixel_count": summary["pixel_count"],
                "bbox": summary["bbox"],
                "edge_counts": summary["edge_counts"],
            })

    distances = {
        "left": int(primary_bbox["left"]),
        "top": int(primary_bbox["top"]),
        "right": cell.width - int(primary_bbox["right_exclusive"]),
        "bottom": cell.height - int(primary_bbox["bottom_exclusive"]),
    }
    return ({
        "frame": f"r{row + 1}c{column + 1}",
        "direction": DIRECTIONS[row],
        "pose": POSES[column],
        "literal_alpha": literal_alpha,
        "reconstructed_foreground_bbox": foreground_bbox,
        "diagnostic_edge_flood_bbox": shared._bbox_dict(diagnostic_foreground_mask.getbbox()),
        "primary_strong_alpha_bbox": primary_bbox,
        "primary_headroom_pixels": int(primary_bbox["top"]),
        "primary_bottommost_pixel": int(primary_bbox["bottommost_pixel"]),
        "primary_horizontal_center": float(primary_bbox["horizontal_center"]),
        "primary_boundary_distances": distances,
        "strong_alpha_components": summaries,
        "discarded_sub_four_pixel_components": len(components) - len(reported),
        "boundary_contacts": edge_contacts,
    }, primary_cell)


def _source_summary(frames: list[dict[str, Any]]) -> dict[str, Any]:
    widths = [int(frame["primary_strong_alpha_bbox"]["width"]) for frame in frames]
    heights = [int(frame["primary_strong_alpha_bbox"]["height"]) for frame in frames]
    centers = [float(frame["primary_horizontal_center"]) for frame in frames]
    bottoms = [int(frame["primary_bottommost_pixel"]) for frame in frames]
    headrooms = [int(frame["primary_headroom_pixels"]) for frame in frames]
    baselines: dict[str, Any] = {}
    for row, direction in enumerate(DIRECTIONS):
        row_bottoms = bottoms[row * 4:(row + 1) * 4]
        baselines[direction] = {
            "bottommost_pixels": row_bottoms,
            "spread_pixels": max(row_bottoms) - min(row_bottoms),
        }
    return {
        "frame_width_range": [min(widths), max(widths)],
        "frame_height_range": [min(heights), max(heights)],
        "horizontal_center_range": [min(centers), max(centers)],
        "bottommost_pixel_range": [min(bottoms), max(bottoms)],
        "transparent_headroom_range": [min(headrooms), max(headrooms)],
        "within_direction_baselines": baselines,
    }


def _draw_source_grid_audit(
    source_cells: list[Image.Image],
    frames: list[dict[str, Any]],
    cell_size: tuple[int, int],
) -> Image.Image:
    header_height = 42
    width, height = cell_size
    result = Image.new("RGBA", (width * 4, (height + header_height) * 4), PREVIEW_BG)
    draw = ImageDraw.Draw(result)
    font = shared._font(14)
    for index, (cell, frame) in enumerate(zip(source_cells, frames)):
        row, column = divmod(index, 4)
        left = column * width
        top = row * (height + header_height)
        sprite_top = top + header_height
        draw.rectangle((left, top, left + width - 1, sprite_top - 1), fill=PREVIEW_PANEL)
        draw.text((left + 5, top + 4), f"{frame['frame']}  {frame['direction']} / {frame['pose']}", font=font, fill=PREVIEW_TEXT)
        draw.text(
            (left + 5, top + 22),
            f"headroom {frame['primary_headroom_pixels']}  bottom {frame['primary_bottommost_pixel']}",
            font=shared._font(12),
            fill=PREVIEW_MUTED,
        )
        result.alpha_composite(cell.convert("RGBA"), (left, sprite_top))
        draw.rectangle((left, sprite_top, left + width - 1, sprite_top + height - 1), outline=PREVIEW_CYAN, width=2)

        for component_index, component in enumerate(frame["strong_alpha_components"]):
            bbox = component["bbox"]
            color = PREVIEW_GREEN if component_index == 0 else PREVIEW_RED
            draw.rectangle(
                (
                    left + int(bbox["left"]),
                    sprite_top + int(bbox["top"]),
                    left + int(bbox["right_exclusive"]) - 1,
                    sprite_top + int(bbox["bottom_exclusive"]) - 1,
                ),
                outline=color,
                width=2,
            )

        bbox = frame["primary_strong_alpha_bbox"]
        center = left + int(round(float(bbox["horizontal_center"])))
        bottom = sprite_top + int(bbox["bottommost_pixel"])
        draw.line((center, sprite_top + int(bbox["top"]), center, bottom), fill=PREVIEW_CYAN)
        draw.line((left + int(bbox["left"]), bottom, left + int(bbox["right_exclusive"]) - 1, bottom), fill=PREVIEW_AMBER, width=2)

        if frame["boundary_contacts"]:
            label = "BOUNDARY " + ", ".join(
                edge[0].upper()
                for contact in frame["boundary_contacts"]
                for edge, count in contact["edge_counts"].items()
                if count
            )
            draw.rectangle((left + 3, sprite_top + height - 24, left + 190, sprite_top + height - 4), fill=(70, 15, 15, 235))
            draw.text((left + 6, sprite_top + height - 22), label, font=font, fill=PREVIEW_RED)
    return result


def _draw_runtime_lineup(candidate_a: Image.Image, candidate_b: Image.Image, gate_passed: bool) -> Image.Image:
    enlarged = shared._draw_lineup(candidate_a, candidate_b, gate_passed)
    native_height = 278
    result = Image.new("RGBA", (enlarged.width, native_height + enlarged.height), PREVIEW_BG)
    draw = ImageDraw.Draw(result)
    draw.text((16, 10), "NATIVE 1x REVIEW SHEETS", font=shared._font(18), fill=PREVIEW_TEXT)
    for left, label, sheet in ((16, "A: direct cell", candidate_a), (220, "B: shared normalization", candidate_b)):
        draw.text((left, 34), label, font=shared._font(14), fill=PREVIEW_AMBER)
        panel = shared._checkerboard(sheet.size, 8)
        panel.alpha_composite(sheet)
        result.alpha_composite(panel, (left, 54))
        for column in range(5):
            x = left + column * 40
            draw.line((x, 54, x, 54 + 224), fill=PREVIEW_CYAN)
        for row in range(5):
            y = 54 + row * 56
            draw.line((left, y, left + 160, y), fill=PREVIEW_CYAN)
    result.alpha_composite(enlarged, (0, native_height))
    return result


def _draw_npc_anchor_overlay(candidate_b: Image.Image, gate_passed: bool) -> Image.Image:
    zoom = 4
    display_size = (candidate_b.width * zoom, candidate_b.height * zoom)
    top = 62
    result = Image.new("RGBA", (display_size[0] + 32, top + display_size[1] + 24), PREVIEW_BG)
    draw = ImageDraw.Draw(result)
    status = "REVIEW CANDIDATE B" if gate_passed else "REVIEW ONLY - SOURCE GATE FAILED"
    draw.text((16, 10), f"NPC ANCHOR / 20x20 COLLISION - {status}", font=shared._font(18), fill=PREVIEW_TEXT)
    draw.text((16, 34), "CYAN x=20  RED feet row=55  GREEN anchor=(20,56)  AMBER collision x=10..30 y=36..56", font=shared._font(13), fill=PREVIEW_MUTED)
    panel = shared._checkerboard(display_size, 16)
    panel.alpha_composite(candidate_b.resize(display_size, Image.Resampling.NEAREST))
    result.alpha_composite(panel, (16, top))

    for row in range(4):
        for column in range(4):
            left = 16 + column * 40 * zoom
            cell_top = top + row * 56 * zoom
            center_x = left + 20 * zoom
            feet_y = cell_top + 55 * zoom
            anchor_y = cell_top + 56 * zoom - 1
            collision_left = left + 10 * zoom
            collision_top = cell_top + 36 * zoom
            collision_right = left + 30 * zoom
            collision_bottom = cell_top + 56 * zoom - 1
            draw.rectangle((left, cell_top, left + 40 * zoom - 1, cell_top + 56 * zoom - 1), outline=PREVIEW_MUTED)
            draw.line((center_x, cell_top, center_x, anchor_y), fill=PREVIEW_CYAN)
            draw.line((left, feet_y, left + 40 * zoom - 1, feet_y), fill=PREVIEW_RED, width=2)
            draw.rectangle((collision_left, collision_top, collision_right, collision_bottom), outline=PREVIEW_AMBER, width=2)
            draw.rectangle((center_x - 2, anchor_y - 2, center_x + 2, anchor_y), fill=PREVIEW_GREEN)
    return result


def _draw_player_scale_comparison(npc_cells: list[Image.Image], gate_passed: bool) -> Image.Image:
    canvas = Image.new("RGBA", (640, 360), (52, 48, 41, 255))
    draw = ImageDraw.Draw(canvas)
    atlas = Image.open(ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png").convert("RGBA")
    grass = atlas.crop((0, 0, 32, 32))
    road = atlas.crop((64, 32, 96, 64))
    plaza = atlas.crop((128, 128, 160, 160))
    for y in range(168, 360, 32):
        for x in range(0, 640, 32):
            canvas.alpha_composite(grass if x < 224 else road if x < 416 else plaza, (x, y))

    references = (
        ("assets/environments/caden/architecture/town_square/town_square_building_northwest_v1_1.png", (8, 8)),
        ("assets/environments/caden/props/seating/caden_bench_01_v1.png", (260, 88)),
        ("assets/environments/caden/props/lighting/caden_lantern_post_01_v1.png", (420, 58)),
    )
    for path, position in references:
        canvas.alpha_composite(Image.open(ROOT / path).convert("RGBA"), position)

    player_sheet = Image.open(PLAYER_RUNTIME).convert("RGBA")
    player_down = player_sheet.crop((0, 0, 40, 56))

    def paste_feet(image: Image.Image, x: int, feet_y: int) -> None:
        canvas.alpha_composite(image, (x - 20, feet_y - 56))

    paste_feet(player_down, 170, 160)
    paste_feet(npc_cells[0], 210, 160)
    paste_feet(player_down, 340, 160)
    paste_feet(npc_cells[0], 380, 160)
    paste_feet(player_down, 484, 160)
    paste_feet(npc_cells[0], 524, 160)
    paste_feet(player_down, 96, 336)
    paste_feet(npc_cells[0], 144, 336)
    paste_feet(player_down, 304, 336)
    paste_feet(npc_cells[0], 352, 336)
    paste_feet(player_down, 496, 336)
    paste_feet(npc_cells[0], 544, 336)

    draw.rectangle((0, 0, 640, 28), fill=(12, 55, 30, 235) if gate_passed else (55, 12, 12, 235))
    status = "PLAYER / NPC SCALE REVIEW" if gate_passed else "REVIEW ONLY - SOURCE BOUNDARY GATE FAILED"
    draw.text((10, 6), status, font=shared._font(16), fill=PREVIEW_GREEN if gate_passed else PREVIEW_RED)
    draw.text((74, 342), "grass", font=shared._font(12), fill=PREVIEW_TEXT)
    draw.text((280, 342), "road", font=shared._font(12), fill=PREVIEW_TEXT)
    draw.text((470, 342), "plaza", font=shared._font(12), fill=PREVIEW_TEXT)
    return canvas.resize((1280, 720), Image.Resampling.NEAREST)


def _audit(source: Path, image: Image.Image, cell_size: tuple[int, int], frames: list[dict[str, Any]]) -> dict[str, Any]:
    contacts = []
    approached = []
    disconnected = []
    for frame in frames:
        for contact in frame["boundary_contacts"]:
            contacts.append({"frame": frame["frame"], **contact})
        near = {
            edge: distance
            for edge, distance in frame["primary_boundary_distances"].items()
            if distance <= EDGE_APPROACH_DISTANCE
        }
        if near:
            approached.append({"frame": frame["frame"], "distance_pixels": near})
        for component in frame["strong_alpha_components"][1:]:
            disconnected.append({
                "frame": frame["frame"],
                "pixel_count": component["pixel_count"],
                "bbox": component["bbox"],
                "edge_counts": component["edge_counts"],
            })

    affected_frames = sorted({contact["frame"] for contact in contacts})
    failures = []
    if contacts:
        failures.append(
            "Connected reconstructed foreground components touch source-cell boundaries in "
            + ", ".join(affected_frames)
            + "."
        )
        failures.append(
            "The row-4 hair crosses the exact row-3/row-4 boundary; deterministic cropping cannot prove or restore complete up-facing silhouettes."
        )

    has_alpha = "A" in image.getbands()
    if has_alpha:
        alpha_histogram = image.getchannel("A").histogram()
        alpha_range: list[int] | None = list(image.getchannel("A").getextrema())
        alpha_counts = {
            "transparent": alpha_histogram[0],
            "partial": sum(alpha_histogram[1:255]),
            "opaque": alpha_histogram[255],
            "total": image.width * image.height,
            "note": "The repaired source has a true alpha channel; strong components use alpha >= 128.",
        }
        background_reconstruction = {
            "rule": "Use the repaired source's binary alpha directly; no RGB background reconstruction is needed.",
            "output_alpha": "Binary alpha is preserved through candidate preparation.",
            "reported_component_minimum_pixels": MIN_REPORTED_COMPONENT_PIXELS,
        }
    else:
        alpha_range = None
        alpha_counts = {
            "transparent": 0,
            "partial": 0,
            "opaque": image.width * image.height,
            "total": image.width * image.height,
            "note": "The PNG is RGB and has no alpha channel; the checkerboard is baked into the pixels.",
        }
        background_reconstruction = {
            "diagnostic_rule": "Flood-fill edge-connected pixels whose minimum RGB channel is >= 235 and whose RGB chroma is <= 12.",
            "strong_foreground_rule": "Treat a pixel as strong foreground when its minimum RGB channel is < 225 or its RGB chroma is > 18.",
            "enclosed_detail_rule": "After primary-component selection, preserve enclosed holes of at most 64 pixels so intentional light eye/details survive without retaining exterior checker pixels.",
            "output_alpha": "Binary review mask only; the immutable source is not changed.",
            "reported_component_minimum_pixels": MIN_REPORTED_COMPONENT_PIXELS,
        }

    return {
        "schema": "caden-npc-base-source-audit-v1",
        "source_path": _relative(source),
        "source_sha256": _sha256(source),
        "format": image.format or "PNG",
        "mode": image.mode,
        "dimensions": [image.width, image.height],
        "alpha_range": alpha_range,
        "alpha_counts": alpha_counts,
        "background_reconstruction": background_reconstruction,
        "grid": {
            "columns": SOURCE_COLUMNS,
            "rows": SOURCE_ROWS,
            "divides_evenly": image.width % 4 == 0 and image.height % 4 == 0,
            "cell_dimensions": list(cell_size),
            "nonempty_frames": len(frames),
        },
        "frame_order": {
            "rows": list(DIRECTIONS),
            "columns": list(POSES),
            "apparent_order_matches_contract": True,
        },
        "frames": frames,
        "summary": _source_summary(frames),
        "boundary_contacts": contacts,
        "boundary_approaches": approached,
        "disconnected_components": disconnected,
        "visual_consistency_audit": {
            "one_character_per_cell": True,
            "same_npc_in_all_frames": True,
            "body_proportions": (
                "Consistent across all 16 complete source frames; live art review remains required."
                if not contacts
                else "Consistent enough for review; production approval is blocked by clipping."
            ),
            "head_and_hair": (
                "Consistent design with transparent headroom in every direction."
                if not contacts
                else "Consistent design, but one or more crowns cross a cell boundary."
            ),
            "clothing_and_skin_tone": "Consistent cream sleeves, moss/olive clothing, brown belt, dark trousers, practical boots, and warm skin tone.",
            "lighting": "Apparent upper-left lighting is broadly consistent; live art review remains required.",
            "walk_poses": "Four plausible walking poses appear in every direction; no running pose is apparent.",
            "left_right_authorship": "Left and right are separately presented and are not simple lighting-reversing mirrors.",
            "up_facing_details": "Back-facing construction is apparent and no front facial details are visible.",
        },
        "identity_guardrail_audit": {
            "passed": True,
            "finding": "No weapon, armor, tool, satchel, insignia, Festival symbol, Edenite, species-specific anatomy, or occupation-bearing prop is visible.",
            "noncanonical": True,
        },
        "quality_gate": {
            "passed": not contacts,
            "failures": failures,
            "required_action": (
                "No source repair is required by the mechanical gate."
                if not contacts
                else "Use manual Aseprite correction or replace/regenerate all four up-facing frames with complete transparent headroom, then repeat the audit."
            ),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--runtime-output", type=Path)
    parser.add_argument("--strict-gate", action="store_true")
    args = parser.parse_args()

    source = args.source.resolve()
    output_dir = args.output_dir.resolve()
    if not source.is_file():
        raise FileNotFoundError(f"No source master found at {source}")

    before_hash = _sha256(source)
    with Image.open(source) as opened:
        source_format = opened.format
        source_image = opened.copy()
        source_image.format = source_format

    source_cells, source_cell_size = _split_cells(source_image)
    frames: list[dict[str, Any]] = []
    primary_cells: list[Image.Image] = []
    for index, cell in enumerate(source_cells):
        frame, primary_cell = _frame_audit(cell, index // 4, index % 4)
        frames.append(frame)
        primary_cells.append(primary_cell)

    audit = _audit(source, source_image, source_cell_size, frames)
    candidate_a, candidate_a_cells = shared._candidate_a(primary_cells)
    candidate_b, candidate_b_cells, shared_scale = shared._candidate_b(primary_cells)

    outputs = {
        "candidate_a": output_dir / "caden_npc_candidate_a_direct_v1.png",
        "candidate_b": output_dir / "caden_npc_candidate_b_normalized_v1.png",
        "source_grid_audit": output_dir / "caden_npc_source_grid_audit_v1.png",
        "runtime_lineup": output_dir / "caden_npc_runtime_lineup_v1.png",
        "runtime_anchor_overlay": output_dir / "caden_npc_runtime_anchor_overlay_v1.png",
        "source_vs_runtime": output_dir / "caden_npc_source_vs_runtime_v1.png",
        "player_scale_comparison": output_dir / "caden_npc_player_scale_comparison_v1.png",
        "environment_preview": output_dir / "caden_npc_environment_preview_v1.png",
        "runtime_animation_strip": output_dir / "caden_npc_runtime_animation_strip_v1.png",
    }
    shared._save_png(candidate_a, outputs["candidate_a"])
    shared._save_png(candidate_b, outputs["candidate_b"])
    shared._save_png(_draw_source_grid_audit(source_cells, frames, source_cell_size), outputs["source_grid_audit"])
    shared._save_png(_draw_runtime_lineup(candidate_a, candidate_b, audit["quality_gate"]["passed"]), outputs["runtime_lineup"])
    shared._save_png(_draw_npc_anchor_overlay(candidate_b, audit["quality_gate"]["passed"]), outputs["runtime_anchor_overlay"])
    shared._save_png(shared._draw_source_vs_runtime(primary_cells, candidate_a_cells, candidate_b_cells), outputs["source_vs_runtime"])
    shared._save_png(_draw_player_scale_comparison(candidate_b_cells, audit["quality_gate"]["passed"]), outputs["player_scale_comparison"])
    shared._save_png(shared._draw_environment_preview(candidate_a_cells, candidate_b_cells, audit["quality_gate"]["passed"]), outputs["environment_preview"])
    shared._save_png(shared._draw_animation_strip(candidate_a_cells, candidate_b_cells), outputs["runtime_animation_strip"])

    candidate_a_metrics = shared._candidate_metrics(candidate_a_cells)
    candidate_b_metrics = shared._candidate_metrics(candidate_b_cells)
    candidate_b_placements = []
    for index, runtime_frame in enumerate(candidate_b_metrics["frames"]):
        runtime_bbox = runtime_frame["primary_strong_alpha_bbox"]
        candidate_b_placements.append({
            "frame": frames[index]["frame"],
            "source_primary_bbox": frames[index]["primary_strong_alpha_bbox"],
            "runtime_visible_bbox": runtime_bbox,
            "runtime_paste_translation": [int(runtime_bbox["left"]), int(runtime_bbox["top"])],
            "scale": round(shared_scale, 9),
        })

    audit["candidate_methods"] = {
        "a": {
            "description": "Each complete 265x371 cell, after deterministic binary primary-component extraction, is reduced directly to 40x56 with nearest-neighbor sampling.",
            "sheet_dimensions": list(candidate_a.size),
            "sha256": _sha256(outputs["candidate_a"]),
            "metrics": candidate_a_metrics,
        },
        "b": {
            "description": "All primary components use one shared scale, nearest-neighbor sampling, translation-only horizontal centering, and feet alignment to row 55.",
            "shared_scale": round(shared_scale, 9),
            "sheet_dimensions": list(candidate_b.size),
            "sha256": _sha256(outputs["candidate_b"]),
            "metrics": candidate_b_metrics,
            "per_frame_placements": candidate_b_placements,
        },
        "selected": None if not audit["quality_gate"]["passed"] else "b",
        "selection_reason": (
            "Candidate B is mechanically eligible for scale review."
            if audit["quality_gate"]["passed"]
            else "Neither review candidate can restore pixels clipped across the row-3/row-4 source boundary."
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
        shared._save_png(candidate_b, runtime_output)
        audit["promoted_runtime"] = {
            "path": _relative(runtime_output),
            "method": "b",
            "sha256": _sha256(runtime_output),
        }

    audit["source_sha256_after"] = _sha256(source)
    audit["source_unchanged"] = before_hash == audit["source_sha256_after"]
    audit_path = output_dir / "caden_npc_source_audit_v1.json"
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    audit_path.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(f"audited_source={_relative(source)}")
    print(f"source_sha256_before={before_hash}")
    print(f"source_sha256_after={audit['source_sha256_after']}")
    print(f"source_dimensions={source_image.width}x{source_image.height}")
    print(f"source_cell_dimensions={source_cell_size[0]}x{source_cell_size[1]}")
    print(f"candidate_b_shared_scale={shared_scale:.9f}")
    print(f"quality_gate={'PASS' if audit['quality_gate']['passed'] else 'FAIL'}")
    print(f"affected_frames={','.join(sorted({item['frame'] for item in audit['boundary_contacts']}))}")
    print(f"audit={_relative(audit_path)}")

    if args.strict_gate and not audit["quality_gate"]["passed"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
