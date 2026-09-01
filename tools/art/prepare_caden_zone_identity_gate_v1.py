#!/usr/bin/env python3
"""Prepare four inactive zone-identity candidates from the modular source library."""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
LIBRARY_ROOT = ROOT / "assets/source_art/caden/environment/modular_expansion_library_v1"
SOURCE_ROOT = LIBRARY_ROOT / "source_masters"
PLAYER_PATH = ROOT / "assets/characters/caden/player/caden_player_runtime_v1.png"
PADDING = 4
SOURCE_HASHES = {
    "caden_connected_compositions_source_master_v1.png": "99dce2b61b83be498805acac20c9f2fda720b7c29141a13a54eaa20317602f1b",
    "caden_landscaping_source_master_v1.png": "cf40f2f86fec6bd0d21c980869d644c8ca9e53708f72a587d68201b5142d9602",
    "caden_yard_furnishings_source_master_v1.png": "f574ee25b761b2dc2f16250fb95fb73329139959228902726daa7b7787b8ef51",
}


@dataclass(frozen=True)
class Candidate:
    source_id: str
    filename: str
    row: int
    column: int
    scale: float
    zone: str
    intended_placement: str
    scale_family: str
    collision_guidance: tuple[dict[str, object], ...]


CANDIDATES = (
    Candidate(
        "CAD-COMP-10",
        "caden_connected_compositions_source_master_v1.png",
        2,
        4,
        0.60,
        "marketplace",
        "south market entrance frame on the paved side of the perimeter opening",
        "market_entry",
        (
            {"role": "west_lantern_post", "shape": "rectangle", "size": [12, 18], "offset": [-31, -22]},
            {"role": "east_lantern_post", "shape": "rectangle", "size": [12, 18], "offset": [31, -22]},
        ),
    ),
    Candidate(
        "CAD-COMP-13",
        "caden_connected_compositions_source_master_v1.png",
        3,
        1,
        0.56,
        "town_square",
        "northeast civic lawn edge outside the plaza and travel corridors",
        "civic_garden",
        (
            {"role": "low_wall", "shape": "rectangle", "size": [62, 12], "offset": [-4, -18]},
            {"role": "lantern_post", "shape": "rectangle", "size": [10, 14], "offset": [36, -22]},
        ),
    ),
    Candidate(
        "CAD-YARD-35",
        "caden_yard_furnishings_source_master_v1.png",
        6,
        5,
        0.58,
        "residential",
        "southwest domestic side yard beside the house and away from the lane",
        "domestic_utility",
        (
            {"role": "storage_stack", "shape": "rectangle", "size": [46, 24], "offset": [-18, -12]},
            {"role": "fence_return", "shape": "rectangle", "size": [24, 12], "offset": [34, -8]},
        ),
    ),
    Candidate(
        "CAD-LAND-33",
        "caden_landscaping_source_master_v1.png",
        6,
        3,
        0.62,
        "commons",
        "southwest natural boundary mass outside the maintained path and Quiet Green",
        "natural_boundary",
        (
            {"role": "rock_and_wood_core", "shape": "rectangle", "size": [38, 18], "offset": [2, -9]},
        ),
    ),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    path = Path("C:/Windows/Fonts") / name
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def assert_external(path: Path) -> Path:
    resolved = path.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError("Preparation output must remain outside res://.")
    return resolved


def cell_bounds(size: tuple[int, int], row: int, column: int) -> tuple[int, int, int, int]:
    width, height = size
    x0 = round((column - 1) * width / 6)
    x1 = round(column * width / 6)
    y0 = round((row - 1) * height / 6)
    y1 = round(row * height / 6)
    return x0, y0, x1, y1


def is_boundary_contamination(color: tuple[int, int, int, int]) -> bool:
    red, green, blue, _alpha = color
    red_fringe = red >= 205 and red - green >= 70 and red - blue >= 70
    yellow_fringe = red >= 230 and green >= 190 and blue <= 100 and min(red, green) - blue >= 105
    green_fringe = green >= 220 and red <= 120 and blue <= 105
    return red_fringe or yellow_fringe or green_fringe


def remove_boundary_contamination(image: Image.Image, passes: int = 8) -> int:
    pixels = image.load()
    removed = 0
    for _pass in range(passes):
        targets: list[tuple[int, int]] = []
        for y in range(1, image.height - 1):
            for x in range(1, image.width - 1):
                color = pixels[x, y]
                if color[3] == 0 or not is_boundary_contamination(color):
                    continue
                if any(pixels[x + dx, y + dy][3] == 0 for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                    targets.append((x, y))
        if not targets:
            break
        for x, y in targets:
            pixels[x, y] = (0, 0, 0, 0)
        removed += len(targets)
    return removed


def connected_components(alpha: Image.Image) -> list[list[tuple[int, int]]]:
    pixels = alpha.load()
    seen: set[tuple[int, int]] = set()
    result: list[list[tuple[int, int]]] = []
    for y in range(alpha.height):
        for x in range(alpha.width):
            if not pixels[x, y] or (x, y) in seen:
                continue
            queue = deque([(x, y)])
            seen.add((x, y))
            component: list[tuple[int, int]] = []
            while queue:
                cx, cy = queue.popleft()
                component.append((cx, cy))
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < alpha.width and 0 <= ny < alpha.height and pixels[nx, ny] and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        queue.append((nx, ny))
            result.append(component)
    return sorted(result, key=len, reverse=True)


def remove_tiny_components(image: Image.Image, minimum_pixels: int = 6) -> tuple[int, int]:
    components = connected_components(image.getchannel("A"))
    remove = [component for component in components if len(component) < minimum_pixels]
    pixels = image.load()
    for component in remove:
        for x, y in component:
            pixels[x, y] = (0, 0, 0, 0)
    return len(remove), sum(len(component) for component in remove)


def sanitize(image: Image.Image) -> int:
    pixels = image.load()
    changed = 0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0 and (red or green or blue):
                pixels[x, y] = (0, 0, 0, 0)
                changed += 1
    return changed


def boundary_contamination_count(image: Image.Image) -> int:
    pixels = image.load()
    count = 0
    for y in range(1, image.height - 1):
        for x in range(1, image.width - 1):
            if pixels[x, y][3] and is_boundary_contamination(pixels[x, y]):
                if any(pixels[x + dx, y + dy][3] == 0 for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                    count += 1
    return count


def audit(image: Image.Image) -> dict[str, object]:
    rgba = image.convert("RGBA")
    colors = list(rgba.get_flattened_data())
    edge_alpha = 0
    pixels = rgba.load()
    for x in range(rgba.width):
        edge_alpha += int(pixels[x, 0][3] > 0) + int(pixels[x, rgba.height - 1][3] > 0)
    for y in range(1, rgba.height - 1):
        edge_alpha += int(pixels[0, y][3] > 0) + int(pixels[rgba.width - 1, y][3] > 0)
    components = connected_components(rgba.getchannel("A"))
    return {
        "dimensions": list(rgba.size),
        "alpha_values": sorted({color[3] for color in colors}),
        "partial_alpha_pixels": sum(color[3] not in (0, 255) for color in colors),
        "transparent_rgb_pixels": sum(color[3] == 0 and color[:3] != (0, 0, 0) for color in colors),
        "canvas_edge_pixels": edge_alpha,
        "connected_components": len(components),
        "smallest_component_pixels": min((len(component) for component in components), default=0),
        "boundary_contamination_pixels": boundary_contamination_count(rgba),
    }


def clean_candidate(source: Image.Image, candidate: Candidate) -> tuple[Image.Image, Image.Image, dict[str, object]]:
    crop_xyxy = cell_bounds(source.size, candidate.row, candidate.column)
    crop = source.crop(crop_xyxy).convert("RGBA")
    source_partial_alpha = sum(color[3] not in (0, 255) for color in crop.get_flattened_data())
    pixels = crop.load()
    for y in range(crop.height):
        for x in range(crop.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (red, green, blue, 255) if alpha >= 128 else (0, 0, 0, 0)
    fringe_removed = remove_boundary_contamination(crop)
    components_removed, component_pixels_removed = remove_tiny_components(crop, minimum_pixels=128)
    sanitize(crop)
    bounds = crop.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError(f"No source pixels survived cleanup: {candidate.source_id}")
    trimmed = crop.crop(bounds)
    source_clean = Image.new("RGBA", (trimmed.width + PADDING * 2, trimmed.height + PADDING * 2), (0, 0, 0, 0))
    source_clean.alpha_composite(trimmed, (PADDING, PADDING))
    target = (
        max(1, round(trimmed.width * candidate.scale)),
        max(1, round(trimmed.height * candidate.scale)),
    )
    normalized = trimmed.resize(target, Image.Resampling.NEAREST)
    runtime = Image.new("RGBA", (target[0] + PADDING * 2, target[1] + PADDING * 2), (0, 0, 0, 0))
    runtime.alpha_composite(normalized, (PADDING, PADDING))
    runtime_fringe_removed = remove_boundary_contamination(runtime)
    runtime_components_removed, runtime_component_pixels_removed = remove_tiny_components(runtime)
    sanitize(runtime)
    runtime_audit = audit(runtime)
    for key in ("partial_alpha_pixels", "transparent_rgb_pixels", "canvas_edge_pixels", "boundary_contamination_pixels"):
        if runtime_audit[key] != 0:
            raise RuntimeError(f"{candidate.source_id} failed {key}: {runtime_audit[key]}")
    if runtime_audit["alpha_values"] != [0, 255]:
        raise RuntimeError(f"{candidate.source_id} did not retain binary alpha.")
    metadata = {
        "source_id": candidate.source_id,
        "source_filename": candidate.filename,
        "source_sha256": SOURCE_HASHES[candidate.filename],
        "source_cell": [candidate.column, candidate.row],
        "source_crop_xyxy": list(crop_xyxy),
        "cleaned_bounds_within_cell_xyxy": list(bounds),
        "source_partial_alpha_pixels": source_partial_alpha,
        "normalization_factor": candidate.scale,
        "scale_family": candidate.scale_family,
        "target_zone": candidate.zone,
        "intended_placement": candidate.intended_placement,
        "pivot_xy": [runtime.width // 2, runtime.height - PADDING],
        "pivot_basis": "bottom-center structural ground contact; loose flowers, grass, and removed fringe excluded",
        "footprint_dimensions": [runtime.width, max(12, round(runtime.height * 0.28))],
        "status": "inactive_zone_identity_candidate",
        "collision_guidance": list(candidate.collision_guidance),
        "cleanup": {
            "alpha_threshold": 128,
            "boundary_contamination_pixels_removed": fringe_removed,
            "tiny_components_removed": components_removed,
            "tiny_component_pixels_removed": component_pixels_removed,
            "runtime_boundary_contamination_pixels_removed": runtime_fringe_removed,
            "runtime_tiny_components_removed": runtime_components_removed,
            "runtime_tiny_component_pixels_removed": runtime_component_pixels_removed,
            "alpha_policy": "binary 0/255",
            "safety_padding_pixels": PADDING,
        },
        "pixel_audit": runtime_audit,
    }
    return source_clean, runtime, metadata


def checkerboard(size: tuple[int, int], cell: int = 8) -> Image.Image:
    image = Image.new("RGBA", size, (226, 224, 218, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(204, 202, 196, 255))
    return image


def make_board(records: dict[str, dict[str, object]], output_root: Path) -> None:
    board = Image.new("RGB", (1280, 980), (22, 26, 23))
    draw = ImageDraw.Draw(board)
    draw.text((28, 20), "Caden modular zone-identity candidates", font=font(29, True), fill=(244, 241, 228))
    draw.text((28, 60), "Inactive extraction gate | four distinct roles | Player shown at 40x56", font=font(16), fill=(193, 202, 191))
    player_sheet = Image.open(PLAYER_PATH).convert("RGBA")
    player = player_sheet.crop((0, 0, 40, 56))
    for index, candidate in enumerate(CANDIDATES):
        column = index % 2
        row = index // 2
        x = 28 + column * 620
        y = 104 + row * 424
        draw.rounded_rectangle((x, y, x + 592, y + 392), radius=6, fill=(32, 38, 33), outline=(80, 91, 80))
        record = records[candidate.source_id]
        draw.text((x + 18, y + 14), f"{candidate.source_id} | {candidate.zone.replace('_', ' ').title()}", font=font(19, True), fill=(238, 233, 217))
        draw.text((x + 18, y + 43), candidate.scale_family.replace("_", " "), font=font(14), fill=(190, 199, 188))
        source_clean = Image.open(output_root / record["source_clean_path"]).convert("RGBA")
        runtime = Image.open(output_root / record["runtime_preview_path"]).convert("RGBA")
        source_panel = checkerboard((260, 236))
        source_fit = source_clean.copy()
        source_fit.thumbnail((244, 220), Image.Resampling.NEAREST)
        source_panel.alpha_composite(source_fit, ((260 - source_fit.width) // 2, 228 - source_fit.height))
        board.paste(source_panel.convert("RGB"), (x + 18, y + 78))
        runtime_panel = checkerboard((274, 236))
        baseline = 218
        runtime_panel.alpha_composite(runtime, ((274 - runtime.width) // 2 - 22, baseline - record["pivot_xy"][1]))
        runtime_panel.alpha_composite(player, (218, baseline - 56))
        board.paste(runtime_panel.convert("RGB"), (x + 298, y + 78))
        draw.text((x + 18, y + 324), f"source clean  |  runtime {runtime.width}x{runtime.height} at scale 1.0", font=font(13), fill=(210, 211, 201))
        draw.text((x + 18, y + 348), "PASS: binary alpha, clean canvas edge, no boundary fringe", font=font(13, True), fill=(157, 211, 156))
    path = output_root / "boards/caden_zone_identity_candidate_audit_v1.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    board.save(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    output_root = assert_external(args.output_root)
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)
    staged_root = output_root / "source_staging"
    staged_root.mkdir(parents=True, exist_ok=True)
    sources: dict[str, Image.Image] = {}
    for filename, expected_hash in SOURCE_HASHES.items():
        source = SOURCE_ROOT / filename
        if sha256(source) != expected_hash:
            raise RuntimeError(f"Source identity mismatch: {filename}")
        staged = staged_root / filename
        shutil.copyfile(source, staged)
        if sha256(staged) != expected_hash:
            raise RuntimeError(f"Staged source identity mismatch: {filename}")
        image = Image.open(staged).convert("RGBA")
        if image.size != (1312, 1199):
            raise RuntimeError(f"Unexpected source dimensions: {filename} {image.size}")
        sources[filename] = image

    records: dict[str, dict[str, object]] = {}
    for candidate in CANDIDATES:
        source_clean, runtime, record = clean_candidate(sources[candidate.filename], candidate)
        stem = candidate.source_id.lower().replace("-", "_")
        source_clean_path = Path("candidates/source_clean") / f"{stem}_source_clean.png"
        runtime_path = Path("candidates/runtime_preview") / f"{stem}_runtime_preview.png"
        (output_root / source_clean_path).parent.mkdir(parents=True, exist_ok=True)
        (output_root / runtime_path).parent.mkdir(parents=True, exist_ok=True)
        source_clean.save(output_root / source_clean_path, compress_level=9)
        runtime.save(output_root / runtime_path, compress_level=9)
        record["source_clean_path"] = source_clean_path.as_posix()
        record["source_clean_sha256"] = sha256(output_root / source_clean_path)
        record["runtime_preview_path"] = runtime_path.as_posix()
        record["runtime_preview_sha256"] = sha256(output_root / runtime_path)
        records[candidate.source_id] = record

    make_board(records, output_root)
    manifest = {
        "schema": "caden-zone-identity-gate-v1",
        "gate_state": "inactive_candidates_prepared_for_visual_review",
        "candidate_count": len(records),
        "wayfarer_decision": "retain_v5_without_additional_asset_to_preserve_open_rustic_identity",
        "source_library": "assets/source_art/caden/environment/modular_expansion_library_v1",
        "source_library_status": "source_candidates_cleanup_required",
        "source_staging": "external_verified_copy",
        "generator": SCRIPT_PATH.relative_to(ROOT).as_posix(),
        "generator_sha256": sha256(SCRIPT_PATH),
        "candidates": records,
        "provenance_and_licensing": {
            "created_for": "Mesoplasia RPG / Caden",
            "generation_note": "OpenAI image generation recorded by the supplied library",
            "rights_status": "subject_to_applicable_OpenAI_terms_and_project_policy",
        },
    }
    write_json(output_root / "metadata/caden_zone_identity_gate_v1.json", manifest)
    print(f"output={output_root}")
    print(f"candidates={len(records)}")
    print(f"manifest_sha256={sha256(output_root / 'metadata/caden_zone_identity_gate_v1.json')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
