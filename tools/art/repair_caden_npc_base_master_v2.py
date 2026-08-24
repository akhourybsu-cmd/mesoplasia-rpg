#!/usr/bin/env python3
"""Create a transparent, boundary-safe Caden NPC base master v2.

The immutable v1 PNG stores its checkerboard as RGB pixels and places the top
14-15 rows of each up-facing crown in the preceding grid cell. This repair
does not repaint, generate, resize, mirror, or warp art. It extracts the
complete connected character silhouettes from v1, gives them binary alpha,
keeps rows 1-3 at their original positions, and translates each complete
up-facing silhouette down to 16 pixels of source-cell headroom.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
import sys

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
TOOL_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL_DIR))

import prepare_caden_player_runtime_v1 as shared  # noqa: E402


SOURCE_V1 = ROOT / "assets/source_art/caden/characters/npc/caden_npc_base_master_v1.png"
OUTPUT_V2 = ROOT / "assets/source_art/caden/characters/npc/caden_npc_base_master_v2.png"
SOURCE_V1_SHA256 = "8b284d0864199b1329ac7e448bd2712e2e414aec97e446de35da8cc70c7387cd"

SHEET_SIZE = (1060, 1484)
CELL_SIZE = (265, 371)
STRONG_MIN_CHANNEL = 205
STRONG_MIN_CHROMA = 26
MAX_ENCLOSED_DETAIL_PIXELS = 2048
ENCLOSED_DETAIL_MARGIN = 3
NEUTRAL_EDGE_MIN_CHANNEL = 165
NEUTRAL_EDGE_MAX_CHROMA = 22
NEUTRAL_EDGE_PASSES = 3
UP_SEARCH_ROWS_ABOVE_BOUNDARY = 24
UP_HEADROOM = 16


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _strong_mask(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    mask = Image.new("L", image.size, 0)
    source_pixels = rgb.load()
    mask_pixels = mask.load()
    for y in range(image.height):
        for x in range(image.width):
            pixel = source_pixels[x, y]
            minimum = min(pixel)
            chroma = max(pixel) - minimum
            if minimum < STRONG_MIN_CHANNEL or chroma > STRONG_MIN_CHROMA:
                mask_pixels[x, y] = 255
    return mask


def _component_mask(size: tuple[int, int], component: list[tuple[int, int]]) -> Image.Image:
    mask = Image.new("L", size, 0)
    pixels = mask.load()
    for x, y in component:
        pixels[x, y] = 255
    return mask


def _preserve_small_enclosed_details(mask: Image.Image, component: list[tuple[int, int]]) -> Image.Image:
    left = min(x for x, _y in component)
    top = min(y for _x, y in component)
    right = max(x for x, _y in component)
    bottom = max(y for _x, y in component)
    inverted = mask.point(lambda value: 0 if value else 255)
    output = mask.copy()
    output_pixels = output.load()
    for hole in shared._connected_components(inverted):
        if len(hole) > MAX_ENCLOSED_DETAIL_PIXELS:
            continue
        hole_left = min(x for x, _y in hole)
        hole_top = min(y for _x, y in hole)
        hole_right = max(x for x, _y in hole)
        hole_bottom = max(y for _x, y in hole)
        if (
            hole_left - left < ENCLOSED_DETAIL_MARGIN
            or hole_top - top < ENCLOSED_DETAIL_MARGIN
            or right - hole_right < ENCLOSED_DETAIL_MARGIN
            or bottom - hole_bottom < ENCLOSED_DETAIL_MARGIN
        ):
            continue
        for x, y in hole:
            output_pixels[x, y] = 255
    return output


def _remove_neutral_edge_residue(image: Image.Image, mask: Image.Image) -> Image.Image:
    """Remove baked-checker gray pixels only where they remain on the edge."""

    rgb = image.convert("RGB")
    source_pixels = rgb.load()
    output = mask.copy()
    for _pass in range(NEUTRAL_EDGE_PASSES):
        pixels = output.load()
        to_remove: list[tuple[int, int]] = []
        for y in range(output.height):
            for x in range(output.width):
                if pixels[x, y] == 0:
                    continue
                pixel = source_pixels[x, y]
                minimum = min(pixel)
                chroma = max(pixel) - minimum
                if minimum < NEUTRAL_EDGE_MIN_CHANNEL or chroma > NEUTRAL_EDGE_MAX_CHROMA:
                    continue
                if any(
                    neighbor_x < 0
                    or neighbor_y < 0
                    or neighbor_x >= output.width
                    or neighbor_y >= output.height
                    or pixels[neighbor_x, neighbor_y] == 0
                    for neighbor_x, neighbor_y in (
                        (x - 1, y),
                        (x + 1, y),
                        (x, y - 1),
                        (x, y + 1),
                    )
                ):
                    to_remove.append((x, y))
        if not to_remove:
            break
        for x, y in to_remove:
            pixels[x, y] = 0
    return output


def _extract_primary(image: Image.Image) -> tuple[Image.Image, tuple[int, int, int, int]]:
    strong = _strong_mask(image)
    components = shared._connected_components(strong)
    if not components:
        raise RuntimeError("A source region contains no connected foreground component.")
    primary = components[0]
    mask = _component_mask(image.size, primary)
    mask = _preserve_small_enclosed_details(mask, primary)
    mask = _remove_neutral_edge_residue(image, mask)
    bbox = mask.getbbox()
    if bbox is None:
        raise RuntimeError("Primary component extraction produced an empty mask.")
    rgba = image.convert("RGBA")
    extracted = Image.new("RGBA", image.size, (0, 0, 0, 0))
    extracted.paste(rgba, (0, 0), mask)
    return extracted, bbox


def _alpha_edge_counts(cell: Image.Image) -> dict[str, int]:
    alpha = cell.getchannel("A")
    return {
        "top": sum(alpha.getpixel((x, 0)) > 0 for x in range(cell.width)),
        "bottom": sum(alpha.getpixel((x, cell.height - 1)) > 0 for x in range(cell.width)),
        "left": sum(alpha.getpixel((0, y)) > 0 for y in range(cell.height)),
        "right": sum(alpha.getpixel((cell.width - 1, y)) > 0 for y in range(cell.height)),
    }


def main() -> int:
    if not SOURCE_V1.is_file():
        raise FileNotFoundError(SOURCE_V1)
    before_hash = _sha256(SOURCE_V1)
    if before_hash != SOURCE_V1_SHA256:
        raise RuntimeError("Protected NPC source v1 hash does not match the approved repair input.")

    with Image.open(SOURCE_V1) as opened:
        source = opened.convert("RGB")
    if source.size != SHEET_SIZE:
        raise RuntimeError(f"Expected v1 dimensions {SHEET_SIZE}, found {source.size}.")

    output = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
    repair_log: list[str] = []

    for row in range(3):
        for column in range(4):
            left = column * CELL_SIZE[0]
            top = row * CELL_SIZE[1]
            source_cell = source.crop((left, top, left + CELL_SIZE[0], top + CELL_SIZE[1]))
            extracted, bbox = _extract_primary(source_cell)
            output.alpha_composite(extracted, (left, top))
            repair_log.append(
                f"r{row + 1}c{column + 1}: retained original position; bbox={bbox}"
            )

    row4_top = CELL_SIZE[1] * 3
    search_top = row4_top - UP_SEARCH_ROWS_ABOVE_BOUNDARY
    for column in range(4):
        left = column * CELL_SIZE[0]
        region = source.crop((left, search_top, left + CELL_SIZE[0], SHEET_SIZE[1]))
        extracted, bbox = _extract_primary(region)
        crop = extracted.crop(bbox)
        original_top_in_row4 = search_top + bbox[1] - row4_top
        paste_x = left + bbox[0]
        paste_y = row4_top + UP_HEADROOM
        output.alpha_composite(crop, (paste_x, paste_y))
        translation_y = UP_HEADROOM - original_top_in_row4
        repair_log.append(
            f"r4c{column + 1}: complete sprite translated (0,{translation_y}); "
            f"original_row4_top={original_top_in_row4}; source_region_bbox={bbox}; "
            f"new_bbox=({bbox[0]},{UP_HEADROOM},{bbox[0] + crop.width},{UP_HEADROOM + crop.height})"
        )

    for row in range(4):
        for column in range(4):
            left = column * CELL_SIZE[0]
            top = row * CELL_SIZE[1]
            cell = output.crop((left, top, left + CELL_SIZE[0], top + CELL_SIZE[1]))
            if cell.getchannel("A").getbbox() is None:
                raise RuntimeError(f"Repaired frame r{row + 1}c{column + 1} is empty.")
            edges = _alpha_edge_counts(cell)
            if any(edges.values()):
                raise RuntimeError(
                    f"Repaired frame r{row + 1}c{column + 1} touches a boundary: {edges}."
                )

    OUTPUT_V2.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT_V2, format="PNG", optimize=False, compress_level=9)

    after_hash = _sha256(SOURCE_V1)
    if after_hash != before_hash:
        raise RuntimeError("Protected NPC source v1 changed during repair.")

    print(f"source_v1_sha256_before={before_hash}")
    print(f"source_v1_sha256_after={after_hash}")
    print(f"output_v2={OUTPUT_V2.relative_to(ROOT).as_posix()}")
    print(f"output_v2_sha256={_sha256(OUTPUT_V2)}")
    print(f"output_v2_mode={output.mode}")
    print(f"output_v2_dimensions={output.width}x{output.height}")
    for entry in repair_log:
        print(entry)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
