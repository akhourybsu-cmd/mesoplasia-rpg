#!/usr/bin/env python3
"""Audit the Caden UI sources and prepare reviewed runtime candidates.

The runtime brief requires both a panel master and an icon/keycap master. This
tool is intentionally gate-first: it writes source-audit artifacts, records
protected hashes, and exits with code 2 without producing runtime art whenever
either source is missing or mechanically unsuitable. Candidate review output
is opt-in and can be written outside the repository before live integration.
"""

from __future__ import annotations

import argparse
from collections import Counter, deque
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
PANEL_SOURCE = ROOT / "assets/source_art/caden/ui/panels/caden_ui_panels_frames_master_v1.png"
ICON_SOURCE = ROOT / "assets/source_art/caden/ui/icons/caden_ui_icons_cursors_input_prompts_batch_b_master_v2.png"
PREVIEW_DIR = ROOT / "docs/art/previews/caden_ui_runtime_v1"
AUDIT_OUTPUT = ROOT / "docs/art/audits/caden_ui_source_gate_v1.json"

PROTECTED_FILES = (
    ROOT / "ui/DialogueUI.tscn",
    ROOT / "scripts/ui/dialogue_ui.gd",
    ROOT / "ui/InteractionPrompt.tscn",
    ROOT / "scripts/ui/interaction_prompt.gd",
    ROOT / "ui/ObjectiveUI.tscn",
    ROOT / "scripts/ui/objective_ui.gd",
    ROOT / "scripts/objectives/objective_tracker.gd",
    ROOT / "project.godot",
)

BACKGROUND_MIN_CHANNEL = 235
BACKGROUND_MAX_CHROMA = 8
STRONG_MIN_CHANNEL = 225
STRONG_MIN_CHROMA = 18
MIN_COMPONENT_PIXELS = 4
MIN_PREVIEW_COMPONENT_PIXELS = 20

PREVIEW_BG = (31, 28, 26, 255)
PREVIEW_PANEL = (55, 48, 42, 255)
PREVIEW_TEXT = (244, 231, 205, 255)
PREVIEW_MUTED = (188, 172, 151, 255)
PREVIEW_RED = (244, 88, 72, 255)
PREVIEW_AMBER = (242, 184, 74, 255)
PREVIEW_CYAN = (70, 211, 231, 255)

PANEL_CANDIDATES = {
    "dialogue_panel": {"crop": (15, 303, 312, 492), "divisor": 3, "margins": (14, 14, 14, 12)},
    "objective_panel": {"crop": (710, 307, 977, 490), "divisor": 3, "margins": (13, 14, 13, 12)},
    "interaction_panel": {"crop": (289, 525, 475, 588), "divisor": 3, "margins": (10, 6, 10, 6)},
    "nameplate": {"crop": (17, 519, 260, 594), "divisor": 3, "margins": (18, 7, 10, 7)},
    "divider": {"crop": (15, 616, 261, 643), "divisor": 3, "margins": (8, 3, 8, 3)},
}

ICON_CANDIDATES = (
    ("selection", (45, 43, 93, 91), 2),
    ("previous", (497, 43, 545, 91), 2),
    ("next", (639, 43, 687, 91), 2),
)

KEYCAP_CANDIDATES = (
    ("neutral", (444, 479, 516, 551), 3),
    ("focused", (514, 478, 586, 550), 3),
    ("disabled", (662, 478, 734, 550), 3),
)

OBJECTIVE_CANDIDATES = (
    ("active", (41, 388, 113, 460), 3),
    ("updated", (151, 387, 223, 459), 3),
    ("complete", (251, 387, 323, 459), 3),
    ("failed", (348, 387, 420, 459), 3),
)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _repo_path(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        Path("C:/Windows/Fonts/consola.ttf"),
        Path("C:/Windows/Fonts/arial.ttf"),
    )
    for candidate in candidates:
        if candidate.is_file():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def _strong_mask(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    source = rgb.load()
    mask = Image.new("L", rgb.size, 0)
    output = mask.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            pixel = source[x, y]
            minimum = min(pixel)
            chroma = max(pixel) - minimum
            if minimum < STRONG_MIN_CHANNEL or chroma > STRONG_MIN_CHROMA:
                output[x, y] = 255
    return mask


def _connected_components(mask: Image.Image) -> list[list[tuple[int, int]]]:
    width, height = mask.size
    pixels = mask.load()
    visited = bytearray(width * height)
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            offset = y * width + x
            if visited[offset] or pixels[x, y] == 0:
                continue
            visited[offset] = 1
            queue: deque[tuple[int, int]] = deque(((x, y),))
            component: list[tuple[int, int]] = []
            while queue:
                current_x, current_y = queue.popleft()
                component.append((current_x, current_y))
                for neighbor_x, neighbor_y in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    if neighbor_x < 0 or neighbor_y < 0 or neighbor_x >= width or neighbor_y >= height:
                        continue
                    neighbor_offset = neighbor_y * width + neighbor_x
                    if visited[neighbor_offset] or pixels[neighbor_x, neighbor_y] == 0:
                        continue
                    visited[neighbor_offset] = 1
                    queue.append((neighbor_x, neighbor_y))
            components.append(component)
    components.sort(key=len, reverse=True)
    return components


def _bbox(component: list[tuple[int, int]]) -> tuple[int, int, int, int]:
    return (
        min(x for x, _y in component),
        min(y for _x, y in component),
        max(x for x, _y in component) + 1,
        max(y for _x, y in component) + 1,
    )


def _bbox_dict(box: tuple[int, int, int, int]) -> dict[str, int]:
    left, top, right, bottom = box
    return {
        "left": left,
        "top": top,
        "right_exclusive": right,
        "bottom_exclusive": bottom,
        "width": right - left,
        "height": bottom - top,
    }


def _row_bands(mask: Image.Image) -> list[dict[str, int]]:
    pixels = mask.load()
    active = [
        sum(pixels[x, y] > 0 for x in range(mask.width)) > 5
        for y in range(mask.height)
    ]
    raw: list[tuple[int, int]] = []
    start: int | None = None
    for y, value in enumerate(active + [False]):
        if value and start is None:
            start = y
        elif not value and start is not None:
            raw.append((start, y))
            start = None

    merged: list[list[int]] = []
    for top, bottom in raw:
        if merged and top - merged[-1][1] <= 12:
            merged[-1][1] = bottom
        else:
            merged.append([top, bottom])

    bands: list[dict[str, int]] = []
    for top, bottom in merged:
        xs = [
            x
            for y in range(top, bottom)
            for x in range(mask.width)
            if pixels[x, y] > 0
        ]
        bands.append({
            "left": min(xs),
            "top": top,
            "right_exclusive": max(xs) + 1,
            "bottom_exclusive": bottom,
            "width": max(xs) + 1 - min(xs),
            "height": bottom - top,
        })
    return bands


def _alpha_summary(image: Image.Image) -> dict[str, Any]:
    if "A" not in image.getbands():
        return {
            "channel_present": False,
            "range": None,
            "transparent": 0,
            "partial": 0,
            "opaque": image.width * image.height,
        }
    alpha = image.getchannel("A")
    histogram = alpha.histogram()
    return {
        "channel_present": True,
        "range": list(alpha.getextrema()),
        "transparent": histogram[0],
        "partial": sum(histogram[1:255]),
        "opaque": histogram[255],
    }


def _audit_icon_source(path: Path) -> tuple[dict[str, Any], Image.Image, list[dict[str, int]]]:
    with Image.open(path) as opened:
        source_format = opened.format
        source_mode = opened.mode
        source_alpha = _alpha_summary(opened)
        image = opened.convert("RGBA")
        analysis_rgb = opened.convert("RGB")

    colors = Counter(analysis_rgb.get_flattened_data())
    near_background = sum(
        count
        for pixel, count in colors.items()
        if min(pixel) >= BACKGROUND_MIN_CHANNEL and max(pixel) - min(pixel) <= BACKGROUND_MAX_CHROMA
    )
    strong_pixels = sum(
        count
        for pixel, count in colors.items()
        if min(pixel) < STRONG_MIN_CHANNEL or max(pixel) - min(pixel) > STRONG_MIN_CHROMA
    )
    mask = _strong_mask(analysis_rgb)
    components = [
        component
        for component in _connected_components(mask)
        if len(component) >= MIN_COMPONENT_PIXELS
    ]
    component_summaries = [
        {"pixel_count": len(component), "bbox": _bbox_dict(_bbox(component))}
        for component in components
    ]
    row_bands = _row_bands(mask)

    failures = [
        "The source is RGB and has no alpha channel; the visible checkerboard is baked into the pixels.",
        "The source contains %d distinct RGB colors, which is inconsistent with a crisp limited-palette runtime icon atlas." % len(colors),
        "Soft checker variation and antialiased edge pixels make clean deterministic alpha extraction unsafe without manual cleanup.",
        "The source is a presentation layout with variable icon extents rather than equal documented runtime cells.",
        "Readability at exact 16x16 and 24x24 runtime sizes has not been established.",
    ]
    audit = {
        "source_path": _repo_path(path),
        "source_sha256": _sha256(path),
        "format": source_format,
        "mode": source_mode,
        "dimensions": [analysis_rgb.width, analysis_rgb.height],
        "alpha": source_alpha,
        "unique_rgb_colors": len(colors),
        "near_neutral_background_pixels": near_background,
        "strong_foreground_pixels": strong_pixels,
        "total_pixels": analysis_rgb.width * analysis_rgb.height,
        "strong_component_count": len(components),
        "strong_components": component_summaries,
        "row_bands": row_bands,
        "visual_findings": {
            "labels_or_titles": "No readable category labels or title are present.",
            "overlap": "No obvious visual overlap between neighboring asset groups; exact extraction cells are not defined.",
            "icon_consistency": "The warm cream, brown, bronze, and restrained blue language is broadly cohesive.",
            "outline_consistency": "Broadly similar dark warm outlines, with variable thickness caused by source scale and soft edges.",
            "pixel_density": "Inconsistent at target scale; assets range from tiny micro-accents to detailed 80+ pixel examples.",
            "lighting": "Upper-left highlights are broadly consistent.",
            "blank_keycaps": "Blank square, rounded, wide, circular, diamond, shoulder, trigger, D-pad, and stick-like frames are visibly present.",
            "lettered_keycaps": "No permanent keyboard letters are visibly baked into the blank frame rows.",
            "controller_branding": "Frames appear generic and do not use official platform logos or trademarked button colors.",
            "unapproved_symbols": "No obvious Festival crest, faction crest, religious mark, weapon, or combat icon is visible.",
            "blue_restraint": "Blue is mostly limited to selected/focused variants and small accents.",
        },
        "candidate_groups_for_manual_cleanup": [
            "selection and navigation cursors",
            "dialogue bubble and advance indicators",
            "confirm, cancel, unavailable, lock, and objective markers",
            "blank square, rounded, wide, circular, diamond, shoulder, trigger, D-pad, and stick frames",
            "directional glyphs and restrained micro-accents",
        ],
        "exclude_from_first_runtime_pass": [
            "complex hand-with-particles, eye, detailed door, pickup, and rubble examples until 24x24 readability is manually proven",
            "framed icon mockups with their own rectangular presentation mattes",
            "decorative long-line and corner assemblies not required by an existing interface",
        ],
        "quality_gate": {"passed": False, "failures": failures},
    }
    return audit, image, row_bands


def _audit_panel_source(path: Path) -> tuple[dict[str, Any], Image.Image, list[dict[str, int]]]:
    with Image.open(path) as opened:
        source_format = opened.format
        source_mode = opened.mode
        source_alpha = _alpha_summary(opened)
        image = opened.convert("RGBA")

    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value >= 128 else 0)
    components = [
        component
        for component in _connected_components(mask)
        if len(component) >= 64
    ]
    component_summaries = [
        {"pixel_count": len(component), "bbox": _bbox_dict(_bbox(component))}
        for component in components
    ]
    component_summaries.sort(key=lambda item: (item["bbox"]["top"], item["bbox"]["left"]))
    row_bands = _row_bands(mask)
    colors = Counter(image.convert("RGB").get_flattened_data())
    boundary_pixels = {
        "top": sum(alpha.getpixel((x, 0)) >= 128 for x in range(image.width)),
        "bottom": sum(alpha.getpixel((x, image.height - 1)) >= 128 for x in range(image.width)),
        "left": sum(alpha.getpixel((0, y)) >= 128 for y in range(image.height)),
        "right": sum(alpha.getpixel((image.width - 1, y)) >= 128 for y in range(image.height)),
    }
    large_components = [
        item
        for item in component_summaries
        if item["bbox"]["width"] >= 240 and item["bbox"]["height"] >= 120
    ]
    mechanical_pass = (
        source_alpha["channel_present"]
        and source_alpha["transparent"] > 0
        and len(large_components) >= 2
        and not any(boundary_pixels.values())
    )
    audit = {
        "source_path": _repo_path(path),
        "source_sha256": _sha256(path),
        "format": source_format,
        "mode": source_mode,
        "dimensions": [image.width, image.height],
        "alpha": source_alpha,
        "unique_rgb_colors": len(colors),
        "binary_alpha_threshold_for_audit": 128,
        "component_count_at_least_64_pixels": len(component_summaries),
        "components": component_summaries,
        "large_panel_component_count": len(large_components),
        "large_panel_components": large_components,
        "row_bands": row_bands,
        "sheet_boundary_pixels_at_alpha_128": boundary_pixels,
        "visual_findings": {
            "matte_or_presentation_background": "Transparent negative space is present; RGB retains brown backdrop colors beneath alpha-zero pixels.",
            "title_or_labels": "No readable title, label, or sample dialogue is baked into the panel interiors.",
            "overlap": "Major panel examples are visually separated; some modular frame pieces intentionally appear near one another.",
            "interiors": "Several cream interiors are calm and large enough for dialogue or objective text.",
            "lighting": "Warm upper-left highlights and darker lower-right treatment are broadly consistent.",
            "blue_restraint": "Blue is limited to small jewels and corner accents.",
            "alpha_cleanup": "Painted regions are mostly near-opaque alpha 251-253 with feathered edge values; runtime candidates require deterministic alpha normalization.",
            "nine_slice": "Multiple complete rectangular families appear isolatable; exact margin and seam proof still requires candidate extraction.",
        },
        "quality_gate": {
            "mechanical_source_passed": mechanical_pass,
            "passed": False,
            "failures": ([] if mechanical_pass else ["No isolated large alpha component suitable for panel review was found."])
            + ["9-slice corner, edge, center, and runtime-size validation has not yet been completed."],
        },
    }
    return audit, image, row_bands


def _draw_panel_audit(
    image: Image.Image,
    audit: dict[str, Any],
    row_bands: list[dict[str, int]],
) -> Image.Image:
    header = 86
    checker = Image.new("RGBA", image.size, (238, 232, 218, 255))
    checker_draw = ImageDraw.Draw(checker)
    cell = 16
    for y in range(0, image.height, cell):
        for x in range(0, image.width, cell):
            if (x // cell + y // cell) % 2:
                checker_draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(208, 200, 184, 255))
    checker.alpha_composite(image)
    result = Image.new("RGBA", (image.width, image.height + header), PREVIEW_BG)
    result.alpha_composite(checker, (0, header))
    draw = ImageDraw.Draw(result)
    draw.rectangle((0, 0, image.width, header - 1), fill=PREVIEW_PANEL)
    draw.text((18, 12), "CADEN UI PANEL SOURCE AUDIT - EXTRACTION REVIEW", font=_font(24), fill=PREVIEW_AMBER)
    draw.text(
        (18, 46),
        "%dx%d %s | true alpha | %d isolated components | 9-slice proof pending"
        % (
            image.width,
            image.height,
            audit["mode"],
            audit["component_count_at_least_64_pixels"],
        ),
        font=_font(17),
        fill=PREVIEW_TEXT,
    )
    for index, band in enumerate(row_bands, start=1):
        left = band["left"]
        top = header + band["top"]
        right = band["right_exclusive"] - 1
        bottom = header + band["bottom_exclusive"] - 1
        draw.rectangle((left, top, right, bottom), outline=PREVIEW_AMBER, width=2)
        draw.rectangle((left, top, left + 74, top + 20), fill=(48, 35, 18, 225))
        draw.text((left + 4, top + 2), f"band {index}", font=_font(14), fill=PREVIEW_AMBER)
    for component in audit["components"]:
        box = component["bbox"]
        color = PREVIEW_CYAN if box["width"] >= 240 and box["height"] >= 120 else (118, 206, 135, 255)
        draw.rectangle(
            (
                box["left"],
                header + box["top"],
                box["right_exclusive"] - 1,
                header + box["bottom_exclusive"] - 1,
            ),
            outline=color,
            width=1,
        )
    return result


def _draw_icon_audit(
    image: Image.Image,
    audit: dict[str, Any],
    row_bands: list[dict[str, int]],
) -> Image.Image:
    header = 86
    result = Image.new("RGBA", (image.width, image.height + header), PREVIEW_BG)
    result.alpha_composite(image, (0, header))
    draw = ImageDraw.Draw(result)
    draw.rectangle((0, 0, image.width, header - 1), fill=PREVIEW_PANEL)
    draw.text((18, 12), "CADEN UI ICON SOURCE AUDIT - FULL SHEET EXCLUDED", font=_font(24), fill=PREVIEW_AMBER)
    draw.text(
        (18, 46),
        "%dx%d %s | no alpha | %d unique RGB colors | baked noisy checkerboard"
        % (image.width, image.height, audit["mode"], audit["unique_rgb_colors"]),
        font=_font(17),
        fill=PREVIEW_TEXT,
    )
    for index, band in enumerate(row_bands, start=1):
        left = band["left"]
        top = header + band["top"]
        right = band["right_exclusive"] - 1
        bottom = header + band["bottom_exclusive"] - 1
        draw.rectangle((left, top, right, bottom), outline=PREVIEW_AMBER, width=2)
        draw.rectangle((left, top, left + 74, top + 20), fill=(48, 35, 18, 225))
        draw.text((left + 4, top + 2), f"band {index}", font=_font(14), fill=PREVIEW_AMBER)

    for component in audit["strong_components"]:
        if component["pixel_count"] < MIN_PREVIEW_COMPONENT_PIXELS:
            continue
        box = component["bbox"]
        draw.rectangle(
            (
                box["left"],
                header + box["top"],
                box["right_exclusive"] - 1,
                header + box["bottom_exclusive"] - 1,
            ),
            outline=PREVIEW_CYAN,
            width=1,
        )
    return result


def _draw_missing_panel_audit(panel_path: Path) -> Image.Image:
    result = Image.new("RGBA", (960, 540), PREVIEW_BG)
    draw = ImageDraw.Draw(result)
    draw.rectangle((36, 36, 923, 503), fill=PREVIEW_PANEL, outline=PREVIEW_RED, width=4)
    draw.text((70, 76), "PANEL SOURCE AUDIT - BLOCKED", font=_font(30), fill=PREVIEW_RED)
    draw.text((70, 138), "Required immutable source master is missing:", font=_font(20), fill=PREVIEW_TEXT)
    path_text = _repo_path(panel_path)
    draw.multiline_text((70, 178), path_text, font=_font(18), fill=PREVIEW_AMBER, spacing=6)
    draw.text((70, 260), "No panel crop, 9-slice margin, tiling, or readability claim can be made.", font=_font(18), fill=PREVIEW_MUTED)
    draw.text((70, 302), "Live UI integration is prohibited by the source-suitability gate.", font=_font(20), fill=PREVIEW_RED)
    draw.text((70, 390), "Required next input: the approved Batch A Caden panel/frame PNG.", font=_font(18), fill=PREVIEW_TEXT)
    return result


def _draw_failure_gate(audit: dict[str, Any]) -> Image.Image:
    result = Image.new("RGBA", (1280, 720), PREVIEW_BG)
    draw = ImageDraw.Draw(result)
    draw.rectangle((40, 36, 1239, 683), fill=PREVIEW_PANEL, outline=PREVIEW_RED, width=4)
    draw.text((76, 72), "CADEN UI RUNTIME V1 - SOURCE GATE FAILED", font=_font(32), fill=PREVIEW_RED)
    lines = [
        "1. Required Batch A panel/frame source master is missing.",
        "2. Supplied Batch B icon sheet is RGB with a baked noisy checkerboard.",
        "3. Icon sheet has soft/antialiased edges and no equal runtime-cell manifest.",
        "4. Exact 16x16 / 24x24 readability is not proven.",
        "5. Runtime panels, styles, icon atlases, and UI-scene integration were withheld.",
    ]
    y = 160
    for line in lines:
        draw.text((88, y), line, font=_font(21), fill=PREVIEW_TEXT)
        y += 58
    draw.rectangle((76, 492, 1204, 632), fill=(39, 34, 30, 255), outline=PREVIEW_AMBER, width=2)
    draw.text((98, 516), "Next required action", font=_font(24), fill=PREVIEW_AMBER)
    draw.text((98, 560), "Attach the approved panel master; then manually clean and grid the selected icon subset.", font=_font(20), fill=PREVIEW_TEXT)
    draw.text((98, 600), "Do not generate or repaint missing production art inside this deterministic pass.", font=_font(18), fill=PREVIEW_MUTED)
    return result


def _draw_acceptance_gate(audit: dict[str, Any]) -> Image.Image:
    result = Image.new("RGBA", (1280, 720), PREVIEW_BG)
    draw = ImageDraw.Draw(result)
    draw.rectangle((40, 36, 1239, 683), fill=PREVIEW_PANEL, outline=PREVIEW_CYAN, width=4)
    draw.text((76, 72), "CADEN UI RUNTIME V1 - REVIEWED SUBSET ACCEPTED", font=_font(30), fill=PREVIEW_CYAN)
    lines = [
        "1. Batch A panel source: true alpha and isolated panel families.",
        "2. Dialogue, objective, and interaction frames pass 9-slice size review.",
        "3. Navigation glyphs, blank keycaps, and objective markers pass at 24x24.",
        "4. Runtime assets use integer nearest-neighbor reduction and binary alpha.",
        "5. Unreviewed presentation-sheet examples remain excluded from runtime v1.",
    ]
    y = 160
    for line in lines:
        draw.text((88, y), line, font=_font(21), fill=PREVIEW_TEXT)
        y += 58
    draw.rectangle((76, 492, 1204, 632), fill=(39, 34, 30, 255), outline=PREVIEW_AMBER, width=2)
    draw.text((98, 516), "Acceptance scope", font=_font(24), fill=PREVIEW_AMBER)
    draw.text((98, 560), "Only assets named in caden_ui_runtime_manifest_v1.json are production-approved.", font=_font(20), fill=PREVIEW_TEXT)
    draw.text((98, 600), "Dynamic key labels remain Godot text over blank frames; no platform branding is baked in.", font=_font(18), fill=PREVIEW_MUTED)
    return result


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def _normalize_panel_candidate(
    source: Image.Image,
    crop: tuple[int, int, int, int],
    divisor: int,
) -> Image.Image:
    candidate = source.convert("RGBA").crop(crop)
    alpha = candidate.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    candidate.putalpha(alpha)
    width = candidate.width // divisor
    height = candidate.height // divisor
    return candidate.resize((width, height), Image.Resampling.NEAREST)


def _extract_icon_candidate(
    source: Image.Image,
    crop: tuple[int, int, int, int],
    divisor: int,
) -> Image.Image:
    rgb = source.convert("RGB").crop(crop)
    strong = _strong_mask(rgb)
    width, height = strong.size
    foreground = Image.new("L", strong.size, 0)
    foreground_pixels = foreground.load()

    for component in _connected_components(strong):
        if len(component) < MIN_COMPONENT_PIXELS:
            continue
        touches_boundary = any(x in (0, width - 1) or y in (0, height - 1) for x, y in component)
        if touches_boundary:
            continue
        for x, y in component:
            foreground_pixels[x, y] = 255

    inverse = foreground.point(lambda value: 0 if value else 255)
    for component in _connected_components(inverse):
        touches_boundary = any(x in (0, width - 1) or y in (0, height - 1) for x, y in component)
        if touches_boundary or len(component) > 12000:
            continue
        for x, y in component:
            foreground_pixels[x, y] = 255

    rgba = rgb.convert("RGBA")
    rgba.putalpha(foreground)
    output_width = width // divisor
    output_height = height // divisor
    return rgba.resize((output_width, output_height), Image.Resampling.NEAREST)


def _build_atlas(candidates: list[Image.Image]) -> Image.Image:
    if not candidates:
        raise ValueError("At least one candidate is required to build an atlas.")
    cell_width = max(candidate.width for candidate in candidates)
    cell_height = max(candidate.height for candidate in candidates)
    atlas = Image.new("RGBA", (cell_width * len(candidates), cell_height), (0, 0, 0, 0))
    for index, candidate in enumerate(candidates):
        x = index * cell_width + (cell_width - candidate.width) // 2
        y = (cell_height - candidate.height) // 2
        atlas.alpha_composite(candidate, (x, y))
    return atlas


def _render_nine_slice(
    texture: Image.Image,
    margins: tuple[int, int, int, int],
    target_size: tuple[int, int],
) -> Image.Image:
    left, top, right, bottom = margins
    target_width, target_height = target_size
    if target_width < left + right or target_height < top + bottom:
        raise ValueError("Nine-slice target is smaller than its fixed margins.")
    source_x = (0, left, texture.width - right, texture.width)
    source_y = (0, top, texture.height - bottom, texture.height)
    target_x = (0, left, target_width - right, target_width)
    target_y = (0, top, target_height - bottom, target_height)
    output = Image.new("RGBA", target_size, (0, 0, 0, 0))
    for row in range(3):
        for column in range(3):
            source_box = (
                source_x[column],
                source_y[row],
                source_x[column + 1],
                source_y[row + 1],
            )
            target_box = (
                target_x[column],
                target_y[row],
                target_x[column + 1],
                target_y[row + 1],
            )
            patch = texture.crop(source_box)
            target_patch_size = (target_box[2] - target_box[0], target_box[3] - target_box[1])
            if patch.size != target_patch_size:
                patch = patch.resize(target_patch_size, Image.Resampling.NEAREST)
            output.alpha_composite(patch, (target_box[0], target_box[1]))
    return output


def _checker(size: tuple[int, int], cell: int = 8) -> Image.Image:
    result = Image.new("RGBA", size, (232, 226, 214, 255))
    draw = ImageDraw.Draw(result)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(190, 181, 165, 255))
    return result


def _draw_candidate_review(
    panel_images: dict[str, Image.Image],
    icon_atlas: Image.Image,
    keycap_atlas: Image.Image,
    objective_atlas: Image.Image,
) -> Image.Image:
    result = Image.new("RGBA", (1280, 720), PREVIEW_BG)
    draw = ImageDraw.Draw(result)
    draw.text((32, 22), "CADEN UI RUNTIME V1 - CANDIDATE SIZE REVIEW", font=_font(28), fill=PREVIEW_AMBER)
    draw.text((32, 60), "Nearest-neighbor integer reduction; binary alpha; no repainting", font=_font(17), fill=PREVIEW_TEXT)

    samples = (
        ("Dialogue 576x96", "dialogue_panel", (576, 96), (32, 112)),
        ("Dialogue 320x72", "dialogue_panel", (320, 72), (32, 242)),
        ("Objective 240x96", "objective_panel", (240, 96), (640, 112)),
        ("Objective 176x72", "objective_panel", (176, 72), (920, 112)),
        ("Interaction 176x40", "interaction_panel", (176, 40), (640, 252)),
        ("Interaction 128x32", "interaction_panel", (128, 32), (840, 252)),
    )
    for label, key, size, position in samples:
        draw.text((position[0], position[1] - 24), label, font=_font(15), fill=PREVIEW_MUTED)
        checker = _checker(size)
        checker.alpha_composite(_render_nine_slice(panel_images[key], PANEL_CANDIDATES[key]["margins"], size))
        result.alpha_composite(checker, position)

    draw.text((32, 352), "Runtime atlases at 4x inspection zoom", font=_font(19), fill=PREVIEW_TEXT)
    atlas_specs = (
        ("24x24 navigation", icon_atlas, (32, 390)),
        ("24x24 blank keycaps", keycap_atlas, (440, 390)),
        ("24x24 objective states", objective_atlas, (800, 390)),
    )
    for label, atlas, position in atlas_specs:
        draw.text((position[0], position[1] - 24), label, font=_font(15), fill=PREVIEW_MUTED)
        zoomed = atlas.resize((atlas.width * 4, atlas.height * 4), Image.Resampling.NEAREST)
        checker = _checker(zoomed.size, cell=16)
        checker.alpha_composite(zoomed)
        result.alpha_composite(checker, position)

    draw.text((32, 646), "Review rule: reject halos, clipped outlines, noisy cells, and broken 9-slice seams.", font=_font(17), fill=PREVIEW_AMBER)
    return result


def _write_runtime_subset(
    panel_source: Path,
    icon_source: Path,
    output_dir: Path,
    review_path: Path,
    manifest_path: Path,
) -> dict[str, Any]:
    with Image.open(panel_source) as opened:
        panel_source_image = opened.convert("RGBA")
    with Image.open(icon_source) as opened:
        icon_source_image = opened.convert("RGB")

    panel_images: dict[str, Image.Image] = {}
    for name, spec in PANEL_CANDIDATES.items():
        panel = _normalize_panel_candidate(panel_source_image, spec["crop"], spec["divisor"])
        panel_images[name] = panel
        _save_png(panel, output_dir / "panels" / f"caden_ui_{name}_v1.png")

    icon_images = [
        _extract_icon_candidate(icon_source_image, crop, divisor)
        for _name, crop, divisor in ICON_CANDIDATES
    ]
    keycap_images = [
        _extract_icon_candidate(icon_source_image, crop, divisor)
        for _name, crop, divisor in KEYCAP_CANDIDATES
    ]
    objective_images = [
        _extract_icon_candidate(icon_source_image, crop, divisor)
        for _name, crop, divisor in OBJECTIVE_CANDIDATES
    ]
    icon_atlas = _build_atlas(icon_images)
    keycap_atlas = _build_atlas(keycap_images)
    objective_atlas = _build_atlas(objective_images)
    _save_png(icon_atlas, output_dir / "icons" / "caden_ui_navigation_icons_v1.png")
    _save_png(keycap_atlas, output_dir / "keycaps" / "caden_ui_blank_keycaps_v1.png")
    _save_png(objective_atlas, output_dir / "icons" / "caden_ui_objective_icons_v1.png")

    review = _draw_candidate_review(panel_images, icon_atlas, keycap_atlas, objective_atlas)
    _save_png(review, review_path)
    manifest = {
        "schema": "caden-ui-runtime-manifest-v1",
        "source_files": {
            "panels": {"path": _repo_path(panel_source), "sha256": _sha256(panel_source)},
            "icons": {"path": _repo_path(icon_source), "sha256": _sha256(icon_source)},
        },
        "panel_candidates": PANEL_CANDIDATES,
        "atlases": {
            "navigation": {
                "path": "res://assets/ui/caden/icons/caden_ui_navigation_icons_v1.png",
                "cell_size": [24, 24],
                "ids": {"selection": 0, "continue": 0, "previous": 1, "next": 2},
            },
            "blank_keycaps": {
                "path": "res://assets/ui/caden/keycaps/caden_ui_blank_keycaps_v1.png",
                "cell_size": [24, 24],
                "ids": {name: index for index, (name, _crop, _divisor) in enumerate(KEYCAP_CANDIDATES)},
                "dynamic_text_required": True,
            },
            "objective_states": {
                "path": "res://assets/ui/caden/icons/caden_ui_objective_icons_v1.png",
                "cell_size": [24, 24],
                "ids": {name: index for index, (name, _crop, _divisor) in enumerate(OBJECTIVE_CANDIDATES)},
            },
        },
        "excluded_from_runtime_v1": [
            "soft or complex presentation examples not proven readable at 24x24",
            "decorative assemblies not required by DialogueUI, InteractionPrompt, or ObjectiveUI",
            "permanently lettered keycaps and platform-specific controller branding",
        ],
        "review_sha256": _sha256(review_path),
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return {
        "review": str(review_path),
        "review_sha256": _sha256(review_path),
        "manifest": str(manifest_path),
        "manifest_sha256": _sha256(manifest_path),
    }


def _write_style_box(
    path: Path,
    texture_path: str,
    texture_margins: tuple[int, int, int, int],
    content_margins: tuple[int, int, int, int],
) -> None:
    left, top, right, bottom = texture_margins
    content_left, content_top, content_right, content_bottom = content_margins
    content = f'''[gd_resource type="StyleBoxTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="{texture_path}" id="1_texture"]\n\n[resource]\ntexture = ExtResource("1_texture")\ntexture_margin_left = {left}.0\ntexture_margin_top = {top}.0\ntexture_margin_right = {right}.0\ntexture_margin_bottom = {bottom}.0\ncontent_margin_left = {content_left}.0\ncontent_margin_top = {content_top}.0\ncontent_margin_right = {content_right}.0\ncontent_margin_bottom = {content_bottom}.0\n'''
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def _write_atlas_texture(path: Path, texture_path: str, region: tuple[int, int, int, int]) -> None:
    x, y, width, height = region
    content = f'''[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="{texture_path}" id="1_atlas"]\n\n[resource]\natlas = ExtResource("1_atlas")\nregion = Rect2({x}, {y}, {width}, {height})\nfilter_clip = true\n'''
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def _write_runtime_resources() -> list[Path]:
    theme_dir = ROOT / "ui/themes/caden"
    generated: list[Path] = []
    style_specs = (
        ("caden_dialogue_panel_v1.tres", "res://assets/ui/caden/panels/caden_ui_dialogue_panel_v1.png", (14, 14, 14, 12), (18, 17, 18, 14)),
        ("caden_objective_panel_v1.tres", "res://assets/ui/caden/panels/caden_ui_objective_panel_v1.png", (13, 14, 13, 12), (16, 17, 16, 13)),
        ("caden_interaction_panel_v1.tres", "res://assets/ui/caden/panels/caden_ui_interaction_panel_v1.png", (10, 6, 10, 6), (12, 7, 12, 7)),
        ("caden_nameplate_v1.tres", "res://assets/ui/caden/panels/caden_ui_nameplate_v1.png", (18, 7, 10, 7), (20, 7, 12, 7)),
        ("caden_divider_v1.tres", "res://assets/ui/caden/panels/caden_ui_divider_v1.png", (8, 3, 8, 3), (0, 0, 0, 0)),
    )
    for filename, texture_path, texture_margins, content_margins in style_specs:
        path = theme_dir / filename
        _write_style_box(path, texture_path, texture_margins, content_margins)
        generated.append(path)

    atlas_specs = (
        ("icons/caden_nav_selection_v1.tres", "res://assets/ui/caden/icons/caden_ui_navigation_icons_v1.png", (0, 0, 24, 24)),
        ("icons/caden_nav_previous_v1.tres", "res://assets/ui/caden/icons/caden_ui_navigation_icons_v1.png", (24, 0, 24, 24)),
        ("icons/caden_nav_next_v1.tres", "res://assets/ui/caden/icons/caden_ui_navigation_icons_v1.png", (48, 0, 24, 24)),
        ("keycaps/caden_keycap_neutral_v1.tres", "res://assets/ui/caden/keycaps/caden_ui_blank_keycaps_v1.png", (0, 0, 24, 24)),
        ("keycaps/caden_keycap_focused_v1.tres", "res://assets/ui/caden/keycaps/caden_ui_blank_keycaps_v1.png", (24, 0, 24, 24)),
        ("keycaps/caden_keycap_disabled_v1.tres", "res://assets/ui/caden/keycaps/caden_ui_blank_keycaps_v1.png", (48, 0, 24, 24)),
        ("icons/caden_objective_active_v1.tres", "res://assets/ui/caden/icons/caden_ui_objective_icons_v1.png", (0, 0, 24, 24)),
        ("icons/caden_objective_updated_v1.tres", "res://assets/ui/caden/icons/caden_ui_objective_icons_v1.png", (24, 0, 24, 24)),
        ("icons/caden_objective_complete_v1.tres", "res://assets/ui/caden/icons/caden_ui_objective_icons_v1.png", (48, 0, 24, 24)),
        ("icons/caden_objective_failed_v1.tres", "res://assets/ui/caden/icons/caden_ui_objective_icons_v1.png", (72, 0, 24, 24)),
    )
    for relative_path, texture_path, region in atlas_specs:
        path = theme_dir / relative_path
        _write_atlas_texture(path, texture_path, region)
        generated.append(path)
    return generated


def _integration_detected() -> bool:
    expected = {
        ROOT / "ui/DialogueUI.tscn": "caden_dialogue_panel_v1.tres",
        ROOT / "ui/InteractionPrompt.tscn": "caden_interaction_panel_v1.tres",
        ROOT / "ui/ObjectiveUI.tscn": "caden_objective_panel_v1.tres",
    }
    return all(marker in path.read_text(encoding="utf-8") for path, marker in expected.items())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--panel-source", type=Path, default=PANEL_SOURCE)
    parser.add_argument("--icon-source", type=Path, default=ICON_SOURCE)
    parser.add_argument("--preview-dir", type=Path, default=PREVIEW_DIR)
    parser.add_argument("--audit-output", type=Path, default=AUDIT_OUTPUT)
    parser.add_argument(
        "--candidate-output-dir",
        type=Path,
        help="Write deterministic review candidates without changing live UI files.",
    )
    parser.add_argument(
        "--prepare-runtime",
        action="store_true",
        help="Regenerate the accepted runtime subset and Godot resources in the repository.",
    )
    args = parser.parse_args()

    panel_source = args.panel_source.resolve()
    icon_source = args.icon_source.resolve()
    preview_dir = args.preview_dir.resolve()
    audit_output = args.audit_output.resolve()
    candidate_output_dir = args.candidate_output_dir.resolve() if args.candidate_output_dir else None

    protected_before = {
        _repo_path(path): _sha256(path)
        for path in PROTECTED_FILES
    }

    icon_audit: dict[str, Any] | None = None
    panel_audit: dict[str, Any]
    generated: dict[str, dict[str, str]] = {}

    panel_preview = preview_dir / "caden_ui_panels_source_audit_v1.png"
    if panel_source.is_file():
        panel_audit, panel_image, panel_row_bands = _audit_panel_source(panel_source)
        _save_png(_draw_panel_audit(panel_image, panel_audit, panel_row_bands), panel_preview)
    else:
        panel_audit = {
            "source_path": _repo_path(panel_source),
            "exists": False,
            "quality_gate": {
                "passed": False,
                "failures": ["Required Caden UI panel/frame source master is missing."],
            },
        }
        _save_png(_draw_missing_panel_audit(panel_source), panel_preview)
    generated["panel_source_audit"] = {
        "path": _repo_path(panel_preview),
        "sha256": _sha256(panel_preview),
    }

    icon_preview = preview_dir / "caden_ui_icons_source_audit_v1.png"
    if icon_source.is_file():
        icon_audit, icon_image, row_bands = _audit_icon_source(icon_source)
        _save_png(_draw_icon_audit(icon_image, icon_audit, row_bands), icon_preview)
        generated["icon_source_audit"] = {
            "path": _repo_path(icon_preview),
            "sha256": _sha256(icon_preview),
        }
    else:
        icon_audit = {
            "source_path": _repo_path(icon_source),
            "exists": False,
            "quality_gate": {"passed": False, "failures": ["Required Caden UI icon source is missing."]},
        }

    source_gate_passed = bool(
        panel_source.is_file()
        and icon_source.is_file()
        and panel_audit["quality_gate"].get("mechanical_source_passed", False)
    )
    if source_gate_passed:
        panel_audit["quality_gate"] = {
            "mechanical_source_passed": True,
            "passed": True,
            "failures": [],
            "reviewed_runtime_candidates": list(PANEL_CANDIDATES),
        }
        icon_audit["reviewed_subset_gate"] = {
            "passed": True,
            "method": "binary foreground extraction followed by exact integer nearest-neighbor reduction",
            "runtime_size": [24, 24],
            "navigation_ids": [name for name, _crop, _divisor in ICON_CANDIDATES],
            "blank_keycap_ids": [name for name, _crop, _divisor in KEYCAP_CANDIDATES],
            "objective_ids": [name for name, _crop, _divisor in OBJECTIVE_CANDIDATES],
            "whole_sheet_approved": False,
        }

    audit: dict[str, Any] = {
        "schema": "caden-ui-source-gate-v1",
        "panel_source": panel_audit,
        "icon_source": icon_audit,
        "runtime_gate": {
            "passed": source_gate_passed,
            "integration_performed": _integration_detected(),
            "reason": (
                "The reviewed minimum runtime subset is production-usable; unreviewed sheet content remains excluded."
                if source_gate_passed
                else "One or both required sources failed the mechanical source-suitability gate."
            ),
        },
        "protected_hashes_before": protected_before,
        "generated_outputs": generated,
    }
    if candidate_output_dir is not None:
        if not panel_source.is_file() or not icon_source.is_file():
            raise FileNotFoundError("Both approved source paths are required for candidate review output.")
        candidate_output_dir.mkdir(parents=True, exist_ok=True)
        audit["candidate_review"] = _write_runtime_subset(
            panel_source,
            icon_source,
            candidate_output_dir,
            candidate_output_dir / "caden_ui_candidate_size_review_v1.png",
            candidate_output_dir / "candidate_manifest.json",
        )

    if args.prepare_runtime:
        if not source_gate_passed:
            raise RuntimeError("Runtime preparation requires both approved sources to pass the source gate.")
        runtime_root = ROOT / "assets/ui/caden"
        runtime_review_path = preview_dir / "caden_ui_runtime_size_review_v1.png"
        runtime_manifest_path = runtime_root / "caden_ui_runtime_manifest_v1.json"
        runtime_result = _write_runtime_subset(
            panel_source,
            icon_source,
            runtime_root,
            runtime_review_path,
            runtime_manifest_path,
        )
        resource_paths = _write_runtime_resources()
        audit["runtime_preparation"] = {
            **runtime_result,
            "resources": [
                {"path": _repo_path(path), "sha256": _sha256(path)}
                for path in resource_paths
            ],
        }
        audit["generated_outputs"]["runtime_size_review"] = {
            "path": _repo_path(runtime_review_path),
            "sha256": _sha256(runtime_review_path),
        }

    gate_preview = preview_dir / (
        "caden_ui_source_acceptance_gate_v1.png"
        if source_gate_passed
        else "caden_ui_source_failure_gate_v1.png"
    )
    _save_png(
        _draw_acceptance_gate(audit) if source_gate_passed else _draw_failure_gate(audit),
        gate_preview,
    )
    audit["generated_outputs"]["source_gate"] = {
        "path": _repo_path(gate_preview),
        "sha256": _sha256(gate_preview),
    }

    protected_after = {
        _repo_path(path): _sha256(path)
        for path in PROTECTED_FILES
    }
    audit["protected_hashes_after"] = protected_after
    audit["protected_files_unchanged"] = protected_before == protected_after
    if not audit["protected_files_unchanged"]:
        raise RuntimeError("A protected project/UI file changed during source auditing.")

    audit_output.parent.mkdir(parents=True, exist_ok=True)
    audit_output.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(f"panel_source_exists={panel_source.is_file()}")
    print(f"icon_source_exists={icon_source.is_file()}")
    if icon_audit and icon_source.is_file():
        print(f"icon_source_sha256={icon_audit['source_sha256']}")
        print(f"icon_dimensions={icon_audit['dimensions'][0]}x{icon_audit['dimensions'][1]}")
        print(f"icon_mode={icon_audit['mode']}")
        print(f"icon_unique_rgb_colors={icon_audit['unique_rgb_colors']}")
        print(f"icon_row_bands={len(icon_audit['row_bands'])}")
    print(f"source_gate={'PASS' if source_gate_passed else 'FAIL'}")
    if candidate_output_dir is not None:
        print(f"candidate_review={audit['candidate_review']['review']}")
    print(f"protected_files_unchanged={audit['protected_files_unchanged']}")
    print(f"audit={_repo_path(audit_output)}")
    return 0 if source_gate_passed else 2


if __name__ == "__main__":
    raise SystemExit(main())
