#!/usr/bin/env python3
"""Build the external Caden building/terrain source-fidelity approval gate."""

from __future__ import annotations

import argparse
from collections import deque
import csv
from dataclasses import asdict, dataclass
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
RENDER_TOOL = ROOT / "tools/art/render_caden_building_terrain_gate_v1_1.gd"
PLAYER_PATH = ROOT / "assets/characters/caden/player/caden_player_runtime_v1.png"
CURRENT_BUILDING_PATH = ROOT / "assets/environments/caden/architecture/town_square/town_square_building_northwest_v2.png"
CURRENT_TERRAIN_PATH = ROOT / "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.png"
SOURCE_SPECS = {
    "caden_buildings_volume_1_master.png": {
        "sha256": "1f9bc86b2e91aecd9ad455e6ca768fccb2c8c9699cc653ec695202dd3bbcc8a4",
        "dimensions": (1535, 1024),
        "rows": 4,
        "columns": 6,
    },
    "caden_buildings_volume_2_master.png": {
        "sha256": "d4df1a8fd892cc16153e32aa8b97d7760df4a3d718b01f0c804853a4ad34895f",
        "dimensions": (1535, 1024),
        "rows": 4,
        "columns": 6,
    },
    "caden_grass_stone_terrain_master.png": {
        "sha256": "eaf2dbf53d955e8e92a71c7b04e63b38bcc66710a7e28a06dbfe3956d354508e",
        "dimensions": (1535, 1024),
        "rows": 5,
        "columns": 8,
    },
}
PADDING = 4
CELL = 32


@dataclass(frozen=True)
class CandidateSpec:
    source_id: str
    filename: str
    row: int
    column: int
    crop: tuple[int, int, int, int]
    scale_family: str
    factor: float
    target_node: str
    role: str


CANDIDATES = (
    CandidateSpec("cad_bld_v1_r01_c01", "caden_buildings_volume_1_master.png", 1, 1, (24, 68, 235, 292), "residential_standard", 0.875, "Cabin01", "compact chimney cottage"),
    CandidateSpec("cad_bld_v1_r01_c02", "caden_buildings_volume_1_master.png", 1, 2, (260, 62, 510, 292), "residential_standard", 0.875, "Cabin02", "porch cottage"),
    CandidateSpec("cad_bld_v1_r01_c04", "caden_buildings_volume_1_master.png", 1, 4, (775, 65, 1018, 292), "residential_standard", 0.875, "Cabin03", "blue-roof maintained home"),
    CandidateSpec("cad_bld_v1_r01_c06", "caden_buildings_volume_1_master.png", 1, 6, (1278, 68, 1518, 292), "residential_standard", 0.875, "Cabin04", "moss-roof garden home"),
    CandidateSpec("cad_bld_v1_r02_c02", "caden_buildings_volume_1_master.png", 2, 2, (255, 316, 522, 548), "residential_broad", 0.75, "Cabin05", "broad two-dormer home"),
    CandidateSpec("cad_bld_v2_r01_c01", "caden_buildings_volume_2_master.png", 1, 1, (62, 62, 260, 298), "residential_small", 1.0, "Cabin06", "narrow red-roof cottage"),
    CandidateSpec("cad_bld_v2_r01_c02", "caden_buildings_volume_2_master.png", 1, 2, (270, 60, 505, 298), "residential_standard", 0.875, "Cabin07", "gabled entry cottage"),
    CandidateSpec("cad_bld_v2_r01_c03", "caden_buildings_volume_2_master.png", 1, 3, (515, 60, 750, 298), "residential_standard", 0.875, "Cabin08", "blue-roof flower-box home"),
    CandidateSpec("cad_bld_v2_r01_c05", "caden_buildings_volume_2_master.png", 1, 5, (995, 72, 1240, 298), "residential_standard", 0.875, "Cabin09", "long-window red-roof home"),
    CandidateSpec("cad_bld_v2_r02_c05", "caden_buildings_volume_2_master.png", 2, 5, (995, 310, 1218, 550), "residential_broad", 0.75, "Cabin10", "green-roof dormer home"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    filename = "segoeuib.ttf" if bold else "segoeui.ttf"
    path = Path("C:/Windows/Fonts") / filename
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def checkerboard(size: tuple[int, int], cell: int = 8) -> Image.Image:
    output = Image.new("RGBA", size, (242, 239, 230, 255))
    draw = ImageDraw.Draw(output)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(214, 211, 203, 255))
    return output


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8", newline="\n")


def assert_external(path: Path) -> None:
    resolved = path.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError("Gate output must remain outside the Godot project tree.")


def verify_sources(source_root: Path) -> dict[str, dict[str, object]]:
    result: dict[str, dict[str, object]] = {}
    for filename, expected in SOURCE_SPECS.items():
        path = source_root / filename
        if not path.is_file():
            raise RuntimeError(f"Missing source master: {path}")
        digest = sha256(path)
        with Image.open(path) as image:
            image.load()
            dimensions = image.size
            mode = image.mode
            unique_colors = len(image.getcolors(maxcolors=3_000_000) or [])
        if digest != expected["sha256"] or dimensions != expected["dimensions"] or mode != "RGB":
            raise RuntimeError(f"Source identity mismatch: {path}")
        result[filename] = {
            "absolute_path": str(path.resolve()),
            "sha256": digest,
            "dimensions": list(dimensions),
            "mode": mode,
            "unique_rgb_colors": unique_colors,
            "checkerboard_status": "baked RGB image data; not transparency",
        }
    return result


def background_mask(image: Image.Image) -> tuple[bytearray, int]:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def passable(pixel: tuple[int, int, int]) -> bool:
        minimum = min(pixel)
        chroma = max(pixel) - minimum
        return (minimum >= 214 and chroma <= 26) or (minimum >= 158 and chroma <= 15)

    def enqueue(x: int, y: int) -> None:
        offset = y * width + x
        if visited[offset] or not passable(pixels[x, y]):
            return
        visited[offset] = 1
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(1, height - 1):
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
    shadow_pixels = 0
    for y in range(height):
        for x in range(width):
            if visited[y * width + x] and min(pixels[x, y]) < 214:
                shadow_pixels += 1
    return visited, shadow_pixels


def component_list(mask: Image.Image) -> list[list[tuple[int, int]]]:
    width, height = mask.size
    pixels = mask.load()
    seen = bytearray(width * height)
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            offset = y * width + x
            if seen[offset] or pixels[x, y] == 0:
                continue
            seen[offset] = 1
            queue = deque([(x, y)])
            component: list[tuple[int, int]] = []
            while queue:
                cx, cy = queue.popleft()
                component.append((cx, cy))
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    neighbor = ny * width + nx
                    if seen[neighbor] or pixels[nx, ny] == 0:
                        continue
                    seen[neighbor] = 1
                    queue.append((nx, ny))
            components.append(component)
    return sorted(components, key=len, reverse=True)


def remove_bright_boundary(image: Image.Image, passes: int = 3) -> int:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    removed = 0
    for _pass in range(passes):
        targets: list[tuple[int, int]] = []
        for y in range(1, rgba.height - 1):
            for x in range(1, rgba.width - 1):
                pixel = pixels[x, y]
                if pixel[3] == 0:
                    continue
                if all(pixels[nx, ny][3] for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                    continue
                minimum = min(pixel[:3])
                chroma = max(pixel[:3]) - minimum
                if minimum >= 204 and chroma <= 20:
                    targets.append((x, y))
        if not targets:
            break
        for x, y in targets:
            pixels[x, y] = (0, 0, 0, 0)
        removed += len(targets)
    image.paste(rgba)
    return removed


def retain_primary_component(image: Image.Image) -> tuple[int, int]:
    components = component_list(image.getchannel("A"))
    if not components:
        raise RuntimeError("No foreground survived source cleanup.")
    keep = set(components[0])
    pixels = image.load()
    removed_components = max(0, len(components) - 1)
    removed_pixels = sum(len(component) for component in components[1:])
    for y in range(image.height):
        for x in range(image.width):
            if pixels[x, y][3] and (x, y) not in keep:
                pixels[x, y] = (0, 0, 0, 0)
    return removed_components, removed_pixels


def sanitize_transparency(image: Image.Image) -> int:
    pixels = image.load()
    changed = 0
    for y in range(image.height):
        for x in range(image.width):
            pixel = pixels[x, y]
            if pixel[3] == 0 and pixel[:3] != (0, 0, 0):
                pixels[x, y] = (0, 0, 0, 0)
                changed += 1
            elif pixel[3] not in (0, 255):
                pixels[x, y] = (*pixel[:3], 255)
                changed += 1
    return changed


def audit_rgba(image: Image.Image) -> dict[str, int]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    alpha_values: set[int] = set()
    edge_pixels = 0
    transparent_rgb = 0
    bright_boundary = 0
    colors: set[tuple[int, int, int, int]] = set()
    for y in range(rgba.height):
        for x in range(rgba.width):
            pixel = pixels[x, y]
            colors.add(pixel)
            alpha_values.add(pixel[3])
            if pixel[3] == 0 and pixel[:3] != (0, 0, 0):
                transparent_rgb += 1
            if pixel[3] and (x in (0, rgba.width - 1) or y in (0, rgba.height - 1)):
                edge_pixels += 1
            if pixel[3] and 0 < x < rgba.width - 1 and 0 < y < rgba.height - 1:
                if any(pixels[nx, ny][3] == 0 for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                    minimum = min(pixel[:3])
                    if minimum >= 214 and max(pixel[:3]) - minimum <= 20:
                        bright_boundary += 1
    return {
        "alpha_value_count": len(alpha_values),
        "partial_alpha_pixels": sum(1 for pixel in colors if pixel[3] not in (0, 255)),
        "canvas_edge_pixels": edge_pixels,
        "transparent_rgb_pixels": transparent_rgb,
        "bright_neutral_boundary_pixels": bright_boundary,
        "connected_components": len(component_list(rgba.getchannel("A"))),
        "unique_rgba_colors": len(colors),
    }


def clean_candidate(source: Image.Image, spec: CandidateSpec) -> tuple[Image.Image, Image.Image, dict[str, object]]:
    crop = source.crop(spec.crop).convert("RGBA")
    background, neutral_shadow_pixels = background_mask(crop)
    pixels = list(crop.get_flattened_data())
    cleaned_pixels = [
        (0, 0, 0, 0) if background[index] else (pixel[0], pixel[1], pixel[2], 255)
        for index, pixel in enumerate(pixels)
    ]
    clean = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    clean.putdata(cleaned_pixels)
    fringe_removed = remove_bright_boundary(clean)
    removed_components, removed_pixels = retain_primary_component(clean)
    sanitize_transparency(clean)
    alpha_bounds = clean.getchannel("A").getbbox()
    if alpha_bounds is None:
        raise RuntimeError(f"No candidate survived cleanup: {spec.source_id}")
    if alpha_bounds[0] == 0 or alpha_bounds[1] == 0 or alpha_bounds[2] == crop.width or alpha_bounds[3] == crop.height:
        raise RuntimeError(f"Candidate crop lacks transparent safety margin: {spec.source_id} {alpha_bounds}")
    trimmed = clean.crop(alpha_bounds)
    source_clean = Image.new("RGBA", (trimmed.width + PADDING * 2, trimmed.height + PADDING * 2), (0, 0, 0, 0))
    source_clean.alpha_composite(trimmed, (PADDING, PADDING))
    target = (max(1, round(trimmed.width * spec.factor)), max(1, round(trimmed.height * spec.factor)))
    normalized = trimmed.resize(target, Image.Resampling.NEAREST)
    runtime_size = (
        normalized.width + PADDING * 2 + normalized.width % 2,
        normalized.height + PADDING * 2 + normalized.height % 2,
    )
    runtime = Image.new("RGBA", runtime_size, (0, 0, 0, 0))
    runtime.alpha_composite(normalized, ((runtime.width - normalized.width) // 2, (runtime.height - normalized.height) // 2))
    sanitize_transparency(runtime)
    alpha = runtime.getchannel("A")
    alpha_pixels = alpha.load()
    central_left = runtime.width // 4
    central_right = runtime.width - central_left
    contact_rows = [y for y in range(runtime.height) if any(alpha_pixels[x, y] for x in range(central_left, central_right))]
    if not contact_rows:
        raise RuntimeError(f"Unable to determine structural contact: {spec.source_id}")
    pivot = (runtime.width // 2, max(contact_rows))
    audit = audit_rgba(runtime)
    for key in ("partial_alpha_pixels", "canvas_edge_pixels", "transparent_rgb_pixels", "bright_neutral_boundary_pixels"):
        if audit[key] != 0:
            raise RuntimeError(f"Candidate audit failed for {spec.source_id}: {key}={audit[key]}")
    if audit["connected_components"] != 1 or audit["alpha_value_count"] != 2:
        raise RuntimeError(f"Candidate topology audit failed for {spec.source_id}: {audit}")
    metadata = {
        "raw_crop_xyxy": list(spec.crop),
        "cleaned_alpha_bounds_within_crop_xyxy": list(alpha_bounds),
        "cleaned_alpha_bounds_in_master_xyxy": [
            spec.crop[0] + alpha_bounds[0], spec.crop[1] + alpha_bounds[1],
            spec.crop[0] + alpha_bounds[2], spec.crop[1] + alpha_bounds[3],
        ],
        "source_clean_dimensions": list(source_clean.size),
        "normalization_factor": spec.factor,
        "runtime_preview_dimensions": list(runtime.size),
        "pivot_xy": list(pivot),
        "pivot_basis": "bottom-center structural contact inside the central half; detached decoration and removed shadow excluded",
        "intended_collision_footprint": "retain authoritative 128x96 Cabin StaticBody2D collision",
        "cleanup": {
            "border_connected_checker_removed": True,
            "neutral_shadow_pixels_removed": neutral_shadow_pixels,
            "bright_boundary_pixels_removed": fringe_removed,
            "detached_components_removed": removed_components,
            "detached_component_pixels_removed": removed_pixels,
            "alpha_policy": "binary 0/255",
            "safety_padding_pixels": PADDING,
        },
        "post_cleanup_audit": audit,
    }
    return source_clean, runtime, metadata


def best_periodic_patch(
    sample: Image.Image,
    size: int = CELL,
    search_box: tuple[int, int, int, int] | None = None,
) -> tuple[Image.Image, tuple[int, int], int]:
    rgb = sample.convert("RGB")
    left, top, right, bottom = search_box or (4, 4, rgb.width - size - 4, rgb.height - size - 4)
    best_score: int | None = None
    best_xy = (0, 0)
    for y in range(top, bottom):
        for x in range(left, right):
            patch = rgb.crop((x, y, x + size, y + size))
            pixels = patch.load()
            score = 0
            for index in range(size):
                score += sum(abs(pixels[0, index][channel] - pixels[size - 1, index][channel]) for channel in range(3))
                score += sum(abs(pixels[index, 0][channel] - pixels[index, size - 1][channel]) for channel in range(3))
            if best_score is None or score < best_score:
                best_score = score
                best_xy = (x, y)
    patch = rgb.crop((best_xy[0], best_xy[1], best_xy[0] + size, best_xy[1] + size)).convert("RGBA")
    pixels = patch.load()
    for index in range(size):
        left = pixels[0, index]
        top = pixels[index, 0]
        pixels[size - 1, index] = left
        pixels[index, size - 1] = top
    pixels[size - 1, size - 1] = pixels[0, 0]
    return patch, best_xy, int(best_score or 0)


def material_variants(sample: Image.Image) -> tuple[list[Image.Image], list[dict[str, object]]]:
    x_min, x_max = 4, sample.width - CELL - 4
    y_min, y_max = 4, sample.height - CELL - 4
    x_breaks = (x_min, x_min + (x_max - x_min) // 3, x_min + 2 * (x_max - x_min) // 3, x_max)
    y_breaks = (y_min, y_min + (y_max - y_min) // 3, y_min + 2 * (y_max - y_min) // 3, y_max)
    regions = tuple(
        (x_breaks[column], y_breaks[row], x_breaks[column + 1], y_breaks[row + 1])
        for row in range(3)
        for column in range(3)
    )
    variants: list[Image.Image] = []
    records: list[dict[str, object]] = []
    for region in regions:
        patch, origin, score = best_periodic_patch(sample, search_box=region)
        variants.append(patch)
        records.append({"native_patch_xy": list(origin), "pre_repair_edge_score": score})
    reference = variants[0]
    reference_pixels = reference.load()
    for variant in variants[1:]:
        pixels = variant.load()
        for index in range(CELL):
            pixels[0, index] = reference_pixels[0, index]
            pixels[CELL - 1, index] = reference_pixels[CELL - 1, index]
            pixels[index, 0] = reference_pixels[index, 0]
            pixels[index, CELL - 1] = reference_pixels[index, CELL - 1]
    return variants, records


def terrain_transition(grass: Image.Image, stone: Image.Image, kind: str) -> Image.Image:
    output = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 255))
    gp = grass.load()
    sp = stone.load()
    op = output.load()
    noise = (-2, -1, 0, 1, 2, 1, 0, -1)
    for y in range(CELL):
        for x in range(CELL):
            nx = noise[x % len(noise)]
            ny = noise[y % len(noise)]
            if kind == "grass_north":
                use_grass = y < 15 + nx
            elif kind == "grass_south":
                use_grass = y >= 17 + nx
            elif kind == "grass_west":
                use_grass = x < 15 + ny
            elif kind == "grass_east":
                use_grass = x >= 17 + ny
            elif kind == "grass_northwest":
                radius = 16 + noise[(x + y) % len(noise)]
                use_grass = (x - (CELL - 1)) ** 2 + (y - (CELL - 1)) ** 2 > radius ** 2
            elif kind == "grass_northeast":
                radius = 16 + noise[(x + y) % len(noise)]
                use_grass = x ** 2 + (y - (CELL - 1)) ** 2 > radius ** 2
            elif kind == "grass_southwest":
                radius = 16 + noise[(x + y) % len(noise)]
                use_grass = (x - (CELL - 1)) ** 2 + y ** 2 > radius ** 2
            elif kind == "grass_southeast":
                radius = 16 + noise[(x + y) % len(noise)]
                use_grass = x ** 2 + y ** 2 > radius ** 2
            else:
                raise ValueError(kind)
            op[x, y] = gp[x, y] if use_grass else sp[x, y]
    return output


def build_terrain(source: Image.Image, output_root: Path) -> dict[str, object]:
    grass_rect = (240, 59, 386, 205)
    stone_rect = (53, 248, 199, 390)
    grass_sample = source.crop(grass_rect)
    stone_sample = source.crop(stone_rect)
    grass_variants, grass_records = material_variants(grass_sample)
    stone_variants, stone_records = material_variants(stone_sample)
    grass = grass_variants[0]
    stone = stone_variants[0]
    cells: dict[str, Image.Image] = {"grass_base": grass_variants[0]}
    cells.update({f"grass_variant_{index:02d}": image for index, image in enumerate(grass_variants[1:], start=2)})
    cells["stone_base"] = stone_variants[0]
    cells.update({f"stone_variant_{index:02d}": image for index, image in enumerate(stone_variants[1:], start=2)})
    for name in (
        "grass_north", "grass_south", "grass_west", "grass_east",
        "grass_northwest", "grass_northeast", "grass_southwest", "grass_southeast",
    ):
        cells[name] = terrain_transition(grass, stone, name)
    order = list(cells)
    atlas_rows = (len(order) + 4) // 5
    atlas = Image.new("RGBA", (CELL * 5, CELL * atlas_rows), (0, 0, 0, 0))
    coordinates: dict[str, list[int]] = {}
    for index, name in enumerate(order):
        x, y = index % 5, index // 5
        atlas.alpha_composite(cells[name], (x * CELL, y * CELL))
        coordinates[name] = [x, y]
    terrain_root = output_root / "terrain"
    terrain_root.mkdir(parents=True, exist_ok=True)
    atlas_path = terrain_root / "terrain_candidate_atlas_v1_1.png"
    atlas.save(atlas_path, compress_level=9)
    build_terrain_boards(output_root, cells)
    return {
        "source_id": "cad_ter_minimal_family_gate_v1_1",
        "source_filename": "caden_grass_stone_terrain_master.png",
        "source_sha256": SOURCE_SPECS["caden_grass_stone_terrain_master.png"]["sha256"],
        "grass_source_id": "cad_ter_r01_c02",
        "grass_sample_rect_xyxy": list(grass_rect),
        "grass_variants": grass_records,
        "stone_source_id": "cad_ter_r02_c01",
        "stone_sample_rect_xyxy": list(stone_rect),
        "stone_variants": stone_records,
        "cell_size": [CELL, CELL],
        "resampling": "none; nine native 32x32 patches per material with deterministic common-edge parity repair",
        "atlas_path": atlas_path.relative_to(output_root).as_posix(),
        "atlas_sha256": sha256(atlas_path),
        "atlas_coordinates": coordinates,
        "collision": "none",
        "status": "inactive_terrain_comparison_candidate",
        "approval_state": "pending_visual_review",
    }


def build_terrain_boards(output_root: Path, cells: dict[str, Image.Image]) -> None:
    boards = output_root / "boards"
    boards.mkdir(parents=True, exist_ok=True)
    scale = 3
    panel = CELL * 5 * scale
    board = Image.new("RGB", (panel * 2 + 72, panel + 88), (26, 31, 27))
    draw = ImageDraw.Draw(board)
    draw.text((24, 16), "Native 5x5 repetition audit", fill=(245, 241, 228), font=font(24, True))
    pattern = (
        (0, 4, 8, 2, 6),
        (7, 1, 5, 0, 3),
        (2, 6, 3, 7, 1),
        (5, 8, 0, 4, 2),
        (3, 7, 6, 1, 5),
    )
    for column, material in enumerate(("grass", "stone")):
        variants = [f"{material}_base"] + [f"{material}_variant_{index:02d}" for index in range(2, 10)]
        tiled = Image.new("RGBA", (CELL * 5, CELL * 5), (0, 0, 0, 0))
        for y in range(5):
            for x in range(5):
                name = variants[pattern[y][x]]
                tiled.alpha_composite(cells[name], (x * CELL, y * CELL))
        x = 24 + column * (panel + 24)
        draw.text((x, 52), f"{material} mixed variants", fill=(198, 207, 196), font=font(15, True))
        board.paste(tiled.convert("RGB").resize((panel, panel), Image.Resampling.NEAREST), (x, 82))
    board.save(boards / "terrain_repetition_board_v1_1.png", compress_level=9)

    grass_names = ["grass_base"] + [f"grass_variant_{index:02d}" for index in range(2, 10)]
    layout = [[grass_names[pattern[y][x]] for x in range(5)] for y in range(5)]
    layout[1][1:4] = ["grass_northwest", "grass_north", "grass_northeast"]
    layout[2][1:4] = ["grass_west", "stone_variant_05", "grass_east"]
    layout[3][1:4] = ["grass_southwest", "grass_south", "grass_southeast"]
    assembled = Image.new("RGBA", (CELL * 5, CELL * 5), (0, 0, 0, 0))
    for y, row in enumerate(layout):
        for x, name in enumerate(row):
            assembled.alpha_composite(cells[name], (x * CELL, y * CELL))
    transition = Image.new("RGB", (panel + 48, panel + 92), (26, 31, 27))
    td = ImageDraw.Draw(transition)
    td.text((24, 16), "Assembled grass / warm-stone transition", fill=(245, 241, 228), font=font(23, True))
    td.text((24, 50), "Inactive candidate; exact 32x32 cells", fill=(190, 200, 190), font=font(14))
    transition.paste(assembled.convert("RGB").resize((panel, panel), Image.Resampling.NEAREST), (24, 78))
    transition.save(boards / "terrain_transition_board_v1_1.png", compress_level=9)

    current = Image.open(CURRENT_TERRAIN_PATH).convert("RGB").crop((480, 304, 672, 464))
    comparison = Image.new("RGB", (900, 420), (26, 31, 27))
    cd = ImageDraw.Draw(comparison)
    cd.text((24, 16), "Residential terrain material comparison", fill=(245, 241, 228), font=font(24, True))
    cd.text((24, 55), "Current runtime", fill=(190, 200, 190), font=font(16, True))
    comparison.paste(current.resize((384, 320), Image.Resampling.NEAREST), (24, 82))
    cd.text((468, 55), "Source-fidelity candidate", fill=(190, 200, 190), font=font(16, True))
    candidate = assembled.crop((CELL, CELL, CELL * 4, CELL * 4)).resize((288, 288), Image.Resampling.NEAREST)
    comparison.paste(candidate.convert("RGB"), (468, 82))
    cd.text((468, 382), "Comparison only; no scene reference changed", fill=(221, 184, 118), font=font(14, True))
    comparison.save(boards / "terrain_material_comparison_v1_1.png", compress_level=9)


def build_source_catalog(selected: dict[str, dict[str, object]], sources: dict[str, dict[str, object]], output_root: Path) -> None:
    rows: list[dict[str, object]] = []
    selected_by_id = {item["source_id"]: item for item in selected.values()}
    for volume in (1, 2):
        filename = f"caden_buildings_volume_{volume}_master.png"
        for row in range(1, 5):
            for column in range(1, 7):
                source_id = f"cad_bld_v{volume}_r{row:02d}_c{column:02d}"
                chosen = selected_by_id.get(source_id)
                if chosen:
                    status = "selected_for_inactive_residential_comparison"
                elif row == 3:
                    status = "deferred_marketplace_stall_footprint_mismatch"
                else:
                    status = "deferred_not_audited_in_gate_0"
                rows.append({
                    "source_id": source_id,
                    "source_filename": filename,
                    "source_sha256": sources[filename]["sha256"],
                    "row": row,
                    "column": column,
                    "visual_role": "home" if row <= 2 else "storefront" if row == 3 else "service_civic_or_outbuilding",
                    "raw_crop_xyxy": "" if not chosen else ",".join(str(value) for value in chosen["raw_crop_xyxy"]),
                    "scale_family": "" if not chosen else chosen["scale_family"],
                    "target_dimensions": "" if not chosen else "x".join(str(value) for value in chosen["runtime_preview_dimensions"]),
                    "pivot_xy": "" if not chosen else ",".join(str(value) for value in chosen["pivot_xy"]),
                    "footprint": "128x96 retained Cabin collision" if chosen else "",
                    "intended_placement": "" if not chosen else chosen["target_node"],
                    "status": status,
                    "approval_state": "pending_visual_review" if chosen else "not_approved",
                    "rights_status": "project_internal_rights_unverified",
                })
    terrain_roles = {1: "grass", 2: "stone", 3: "straight_transition", 4: "corner_transition", 5: "path_or_junction"}
    for row in range(1, 6):
        for column in range(1, 9):
            source_id = f"cad_ter_r{row:02d}_c{column:02d}"
            selected_material = source_id in {"cad_ter_r01_c02", "cad_ter_r02_c01"}
            rows.append({
                "source_id": source_id,
                "source_filename": "caden_grass_stone_terrain_master.png",
                "source_sha256": sources["caden_grass_stone_terrain_master.png"]["sha256"],
                "row": row,
                "column": column,
                "visual_role": terrain_roles[row],
                "raw_crop_xyxy": "240,59,386,205" if source_id == "cad_ter_r01_c02" else "53,248,199,390" if source_id == "cad_ter_r02_c01" else "",
                "scale_family": "native_32_patch_reconstruction" if selected_material else "",
                "target_dimensions": "32x32" if selected_material else "",
                "pivot_xy": "not_applicable",
                "footprint": "decorative floor; no collision" if selected_material else "",
                "intended_placement": "inactive terrain material comparison" if selected_material else "",
                "status": "selected_material_reference" if selected_material else "deferred_not_audited_in_gate_0",
                "approval_state": "pending_visual_review" if selected_material else "not_approved",
                "rights_status": "project_internal_rights_unverified",
            })
    if len(rows) != 88:
        raise RuntimeError(f"Expected 88 source catalog rows, found {len(rows)}")
    metadata = output_root / "metadata"
    metadata.mkdir(parents=True, exist_ok=True)
    write_json(metadata / "source_catalog_v1_1.json", {"schema": "caden-building-terrain-source-catalog-v1.1", "row_count": len(rows), "rows": rows})
    with (metadata / "source_catalog_v1_1.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def build_building_boards(output_root: Path, records: dict[str, dict[str, object]], source_root: Path) -> None:
    boards = output_root / "boards"
    boards.mkdir(parents=True, exist_ok=True)
    player = Image.open(PLAYER_PATH).convert("RGBA").crop((0, 0, 40, 56))
    current = Image.open(CURRENT_BUILDING_PATH).convert("RGBA")
    cards: list[tuple[str, Image.Image, dict[str, object] | None]] = [("current approved reference", current, None)]
    for spec in CANDIDATES:
        record = records[spec.source_id]
        image = Image.open(output_root / record["runtime_preview_path"]).convert("RGBA")
        cards.append((spec.source_id, image, record))
    columns, card_w, card_h = 3, 380, 310
    rows = (len(cards) + columns - 1) // columns
    board = Image.new("RGB", (columns * card_w + 32, rows * card_h + 82), (24, 29, 26))
    draw = ImageDraw.Draw(board)
    draw.text((20, 14), "Caden house candidates at proposed runtime scale", fill=(247, 242, 228), font=font(25, True))
    draw.text((20, 49), "Player is 40x56; red line is the structural ground-contact baseline", fill=(188, 199, 188), font=font(14))
    for index, (label, image, record) in enumerate(cards):
        x = 16 + (index % columns) * card_w
        y = 78 + (index // columns) * card_h
        panel = Image.new("RGBA", (card_w - 12, card_h - 12), (92, 118, 65, 255))
        pd = ImageDraw.Draw(panel)
        baseline = 246
        pivot = (image.width // 2, image.height - 5) if record is None else tuple(record["pivot_xy"])
        origin_x = 18
        origin_y = baseline - pivot[1]
        panel.alpha_composite(image, (origin_x, origin_y))
        player_x = min(panel.width - player.width - 16, origin_x + pivot[0] + 30)
        panel.alpha_composite(player, (player_x, baseline - 52))
        pd.line((12, baseline, panel.width - 12, baseline), fill=(194, 76, 62, 255), width=1)
        pd.rectangle((0, 0, panel.width - 1, panel.height - 1), outline=(76, 87, 78, 255), width=2)
        pd.rectangle((0, 0, panel.width - 1, 50), fill=(35, 43, 35, 230))
        pd.text((12, 8), label, fill=(250, 246, 234, 255), font=font(15, True))
        if record is None:
            detail = f"{image.width}x{image.height} active reference"
        else:
            detail = f"{image.width}x{image.height} factor {record['normalization_factor']} -> {record['target_node']}"
        pd.text((12, 30), detail, fill=(222, 225, 213, 255), font=font(12))
        board.paste(panel.convert("RGB"), (x, y))
    board.save(boards / "building_player_scale_board_v1_1.png", compress_level=9)

    edge = Image.new("RGB", (1200, 10 * 260 + 66), (24, 29, 26))
    ed = ImageDraw.Draw(edge)
    ed.text((20, 14), "Source matte vs cleaned binary-alpha edge audit", fill=(247, 242, 228), font=font(24, True))
    for index, spec in enumerate(CANDIDATES):
        record = records[spec.source_id]
        source = Image.open(source_root / spec.filename).convert("RGB").crop(spec.crop)
        clean = Image.open(output_root / record["source_clean_path"]).convert("RGBA")
        y = 60 + index * 260
        ed.text((18, y + 4), f"{spec.source_id} | source RGB crop", fill=(228, 223, 207), font=font(14, True))
        source_fit = source.copy()
        source_fit.thumbnail((520, 220), Image.Resampling.NEAREST)
        edge.paste(source_fit, (18, y + 30))
        ed.text((610, y + 4), "cleaned candidate on generated checker", fill=(228, 223, 207), font=font(14, True))
        checker = checkerboard((560, 220), 10)
        clean_fit = clean.copy()
        clean_fit.thumbnail((540, 210), Image.Resampling.NEAREST)
        checker.alpha_composite(clean_fit, ((checker.width - clean_fit.width) // 2, checker.height - clean_fit.height - 4))
        edge.paste(checker.convert("RGB"), (610, y + 30))
    edge.save(boards / "building_edge_audit_board_v1_1.png", compress_level=9)

    contact = checkerboard((1180, 800), 12)
    cd = ImageDraw.Draw(contact)
    cd.rectangle((0, 0, 1179, 58), fill=(24, 29, 26, 255))
    cd.text((20, 14), "Cleaned alpha contact sheet - inactive candidates", fill=(247, 242, 228, 255), font=font(24, True))
    for index, spec in enumerate(CANDIDATES):
        record = records[spec.source_id]
        image = Image.open(output_root / record["runtime_preview_path"]).convert("RGBA")
        column, row = index % 5, index // 5
        x, y = 18 + column * 232, 74 + row * 350
        cd.text((x, y), spec.source_id, fill=(34, 38, 34, 255), font=font(13, True))
        contact.alpha_composite(image, (x + (210 - image.width) // 2, y + 28 + (260 - image.height)))
    contact.convert("RGB").save(boards / "building_alpha_contact_sheet_v1_1.png", compress_level=9)


def current_commit() -> str:
    result = subprocess.run(
        ["git", "-c", f"safe.directory={ROOT.as_posix()}", "rev-parse", "HEAD"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else "unavailable"


def prepare(source_root: Path, output_root: Path) -> None:
    assert_external(output_root)
    output_root.mkdir(parents=True, exist_ok=True)
    sources = verify_sources(source_root)
    records: dict[str, dict[str, object]] = {}
    images = {filename: Image.open(source_root / filename).convert("RGB") for filename in SOURCE_SPECS}
    source_clean_root = output_root / "candidates/source_clean"
    runtime_root = output_root / "candidates/runtime_preview"
    source_clean_root.mkdir(parents=True, exist_ok=True)
    runtime_root.mkdir(parents=True, exist_ok=True)
    for spec in CANDIDATES:
        source_clean, runtime, metadata = clean_candidate(images[spec.filename], spec)
        source_clean_path = source_clean_root / f"{spec.source_id}_clean.png"
        runtime_path = runtime_root / f"{spec.source_id}_runtime_preview.png"
        source_clean.save(source_clean_path, compress_level=9)
        runtime.save(runtime_path, compress_level=9)
        records[spec.source_id] = {
            **asdict(spec),
            **metadata,
            "source_sha256": sources[spec.filename]["sha256"],
            "source_clean_path": source_clean_path.relative_to(output_root).as_posix(),
            "source_clean_sha256": sha256(source_clean_path),
            "runtime_preview_path": runtime_path.relative_to(output_root).as_posix(),
            "runtime_preview_sha256": sha256(runtime_path),
            "status": "selected_for_inactive_residential_comparison",
            "approval_state": "pending_visual_review",
            "rights_status": "project_internal_rights_unverified",
        }
    terrain = build_terrain(images["caden_grass_stone_terrain_master.png"], output_root)
    build_source_catalog(records, sources, output_root)
    build_building_boards(output_root, records, source_root)
    manifest = {
        "schema": "caden-building-terrain-gate-v1.1-preparation",
        "gate_state": "inactive_comparison_pending_visual_approval",
        "repository_commit": current_commit(),
        "source_policy": "Masters remain outside res://; only external preview derivatives were written.",
        "sources": sources,
        "candidate_count": len(records),
        "catalog_row_count": 88,
        "residential_assignments": list(records.values()),
        "terrain": terrain,
        "protected_live_scenes_modified": [],
        "provenance_and_licensing": {
            "provided_by": "project owner via local Downloads intake",
            "creator_or_generation_tool": "not documented in supplied prompt or sidecars",
            "license": "unverified",
            "derivative_permission": "unverified",
            "distribution_status": "do_not_publish_or_ship_until rights are verified",
        },
    }
    write_json(output_root / "metadata/preparation_manifest_v1_1.json", manifest)
    print(f"prepared={output_root}")
    print(f"candidates={len(records)}")
    print("catalog_rows=88")


def revised_prompt(commit: str) -> str:
    return f"""# Caden Building and Terrain Source-Fidelity Master Prompt v1.1

## Request boundary

Treat this document as a specification, not as permission to edit active game scenes. The current task is selective source-art preparation and inactive comparison. Stop for explicit visual approval before changing any scene, TileSet, active texture reference, collision, route, NPC, or gameplay contract.

## Current repository state

- Repository commit observed by the Gate 0 package: `{commit}`.
- Marketplace, Residential, Commons, Town Square, and Wayfarer's Approach already use authored runtime art.
- Residential currently has ten fixed `128x96` cabin collision bodies and five reused Town Square Runtime v2 exterior textures.
- Marketplace has eight fixed stall bodies, a protected central aisle, perimeter fencing/planting, and ambient population. Full shopfronts are not authorized stall replacements.
- Commons Runtime v1 remains a protected visual-review baseline and receives no building.
- Town Square Runtime v2 / Terrain v1.1 and Wayfarer v5 remain protected.

Current scenes, scripts, collisions, routes, transitions, camera bounds, NPCs, dialogue, tests, and approved runtime art outrank every supplied source master.

## Inputs

Use only the three canonical `1535x1024` RGB masters and verify these SHA-256 values:

- `caden_buildings_volume_1_master.png`: `1f9bc86b2e91aecd9ad455e6ca768fccb2c8c9699cc653ec695202dd3bbcc8a4`
- `caden_buildings_volume_2_master.png`: `d4df1a8fd892cc16153e32aa8b97d7760df4a3d718b01f0c804853a4ad34895f`
- `caden_grass_stone_terrain_master.png`: `eaf2dbf53d955e8e92a71c7b04e63b38bcc66710a7e28a06dbfe3956d354508e`

Ignore byte-identical `(1)` download copies. The checkerboard is baked RGB data, not alpha. Stage masters and all large review boards outside `res://`.

## Gate 0: source reconstruction only

1. Catalog all 88 spatial entries using stable `cad_bld_*` and `cad_ter_*` IDs. Non-selected entries may remain deferred, but may not be silently treated as approved.
2. Restrict the first building comparison to ten Residential candidates from building rows 1-2.
3. Use border-connected spatial matte reconstruction. Never globally delete white, gray, or checker colors.
4. Require binary alpha, transparent safety padding, zero opaque canvas-edge pixels, zero transparent RGB residue, one structural connected component, and zero bright neutral boundary candidates.
5. Remove broad baked presentation shadows. Retain the scene's controlled grounding layer instead.
6. Determine bottom-center pivots from structural ground contact, excluding flowers, loose merchandise, and shadow pixels.
7. Keep runtime preview scale `1.0`; perform any approved nearest-neighbor normalization offline.
8. Reconstruct terrain as exact `32x32` cells. Use one calm grass family and one pale warm-stone family. Do not shrink a complete 145-pixel sample into a tile.
9. Prove base repetition and assembled transition behavior on native 5x5 or larger boards.
10. Render inactive Residential comparisons by transiently replacing textures in the review renderer. Do not serialize those replacements into `Residential.tscn`.

## Approval gates

### Gate A - source and scale

Deliver the 88-row catalog, cleaned-alpha sheet, edge audit, player-scale board, terrain repetition/transition boards, metadata, tooling requirements, provenance/licensing note, script hashes, and package checksums. Stop if extraction damages pale architecture or leaves matte, fringe, fragments, clipping, or unsuitable shadows.

### Gate B - inactive Residential comparison

Deliver matched current/proposed full-zone and `640x360` views. Preserve every cabin center and collision, road, fence, yard piece, tree, NPC, entry, exit, and route. Stop for explicit visual approval.

Approval of Gate A or Gate B authorizes only the specifically named next step. It never authorizes Town Square, Wayfarer, Commons, Marketplace, or broad terrain replacement by implication.

## Later implementation order after approval

1. Residential building-only pilot, using only approved candidates.
2. Separate zone-specific terrain comparison; never replace all zone terrain at once.
3. Marketplace retains its open-air stall contract unless a future comparison proves a candidate fits at correct player/door scale without narrowing circulation.
4. Commons receives terrain comparison only after its current runtime review is approved.
5. Town Square and Wayfarer remain comparison-only until separately authorized.

## Provenance and tooling

Record source path, hash, dimensions, creator/source, generation tool, license, derivative permission, and distribution status. Until rights are verified, mark outputs `project_internal_rights_unverified` and do not publish or ship them.

Document exact Python, Pillow, and Godot versions. Checksum every preparation, render, packaging, and verification script. Exclude `.godot`, `.import`, `.uid`, `__pycache__`, hidden OS files, and temporary build products from the external package.

## Stop conditions

Retain the active visual when extraction is ambiguous, a candidate is clipped, player/door scale is wrong, a foundation cannot fit the fixed footprint, a terrain cell cannot repeat cleanly, source art weakens zone cohesion, or any change would require moving authoritative gameplay geometry.
"""


def build_comparison_board(output_root: Path) -> Path:
    capture_root = output_root / "residential_comparison/raw_captures"
    pairs = (
        ("residential_full_zone_current_v1_1_1152x768.png", "residential_full_zone_candidate_v1_1_1152x768.png", "Full Residential"),
        ("residential_north_current_v1_1_640x360.png", "residential_north_candidate_v1_1_640x360.png", "North homes"),
        ("residential_south_current_v1_1_640x360.png", "residential_south_candidate_v1_1_640x360.png", "South homes"),
        ("residential_entrance_current_v1_1_640x360.png", "residential_entrance_candidate_v1_1_640x360.png", "Player / entrance scale"),
    )
    for left, right, _label in pairs:
        if not (capture_root / left).is_file() or not (capture_root / right).is_file():
            raise RuntimeError("Godot comparison captures are incomplete.")
    margin, gap = 24, 20
    width = 1152 * 2 + gap + margin * 2
    height = 78 + 768 + gap + 3 * (36 + 360 + gap) + margin
    board = Image.new("RGB", (width, height), (21, 25, 23))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 14), "Caden Residential inactive building comparison", fill=(247, 242, 228), font=font(28, True))
    draw.text((margin, 50), "Current approved runtime", fill=(190, 201, 190), font=font(15, True))
    draw.text((margin + 1152 + gap, 50), "Source-fidelity candidates - not integrated", fill=(221, 184, 118), font=font(15, True))
    y = 78
    for index, (left_name, right_name, label) in enumerate(pairs):
        left = Image.open(capture_root / left_name).convert("RGB")
        right = Image.open(capture_root / right_name).convert("RGB")
        if index == 0:
            board.paste(left, (margin, y))
            board.paste(right, (margin + 1152 + gap, y))
            y += 768 + gap
        else:
            draw.text((margin, y + 5), label, fill=(235, 231, 218), font=font(16, True))
            focus_offset = (1152 - left.width) // 2
            board.paste(left, (margin + focus_offset, y + 36))
            board.paste(right, (margin + 1152 + gap + focus_offset, y + 36))
            y += 36 + 360 + gap
    path = output_root / "boards/residential_inactive_comparison_board_v1_1.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    board.save(path, compress_level=9)
    return path


def tooling_versions() -> dict[str, str]:
    return {
        "python": subprocess.run([shutil.which("python") or "python", "--version"], capture_output=True, text=True, check=False).stdout.strip() or "Python 3.12.13 bundled runtime",
        "pillow": Image.__version__,
        "godot": "4.7.2-stable Compatibility renderer",
        "runtime_dependency_policy": "No new game runtime dependency; Python/Pillow and Godot are offline preparation tools only.",
    }


def finalize(output_root: Path) -> Path:
    assert_external(output_root)
    preparation_path = output_root / "metadata/preparation_manifest_v1_1.json"
    render_manifest_path = output_root / "residential_comparison/residential_comparison_manifest_v1_1.json"
    if not preparation_path.is_file() or not render_manifest_path.is_file():
        raise RuntimeError("Prepare assets and run the Godot renderer before finalizing the gate.")
    preparation = json.loads(preparation_path.read_text(encoding="utf-8"))
    render_manifest = json.loads(render_manifest_path.read_text(encoding="utf-8"))
    comparison_board = build_comparison_board(output_root)
    docs = output_root / "docs"
    tools_dir = output_root / "tooling"
    docs.mkdir(parents=True, exist_ok=True)
    tools_dir.mkdir(parents=True, exist_ok=True)
    prompt_path = docs / "caden_building_terrain_replacement_master_prompt_v1_1.md"
    prompt_path.write_text(revised_prompt(preparation["repository_commit"]), encoding="utf-8", newline="\n")
    provenance_path = docs / "PROVENANCE_AND_LICENSE.md"
    provenance_path.write_text(
        """# Provenance and license status\n\nThe three canonical masters were supplied by the project owner from the local Downloads intake and verified by SHA-256. No creator identity, generation tool, original license, derivative-use grant, or distribution permission accompanied the files.\n\nStatus: `project_internal_rights_unverified`. The cleaned candidates, terrain derivatives, and comparison boards may be used for internal visual review only. Do not publish, redistribute, commit as production art, or ship them until the rights record is completed.\n""",
        encoding="utf-8",
        newline="\n",
    )
    versions = tooling_versions()
    tooling_path = docs / "TOOLING_REQUIREMENTS.md"
    tooling_path.write_text(
        f"""# Tooling requirements\n\n- Python: {versions['python']}\n- Pillow: {versions['pillow']}\n- Godot: {versions['godot']}\n- Renderer: Compatibility\n- Runtime effect: none; these tools are offline and introduce no game dependency.\n\nRun preparation first, then the Godot comparison renderer, then finalize. All output paths must be absolute and outside `res://`.\n""",
        encoding="utf-8",
        newline="\n",
    )
    readme = docs / "README.md"
    readme.write_text(
        """# Caden building and terrain Gate 0 v1.1\n\nThis package is an inactive visual-approval gate. It does not authorize or contain serialized scene changes.\n\nReview in this order:\n\n1. `boards/building_edge_audit_board_v1_1.png`\n2. `boards/building_player_scale_board_v1_1.png`\n3. `boards/residential_inactive_comparison_board_v1_1.png`\n4. `boards/terrain_repetition_board_v1_1.png`\n5. `boards/terrain_transition_board_v1_1.png`\n6. `boards/terrain_material_comparison_v1_1.png`\n\nThe proposed buildings are restricted to Residential. Marketplace storefronts, Commons buildings, Town Square swaps, Wayfarer swaps, and active terrain replacement remain unapproved.\n""",
        encoding="utf-8",
        newline="\n",
    )
    shutil.copy2(SCRIPT_PATH, tools_dir / SCRIPT_PATH.name)
    shutil.copy2(RENDER_TOOL, tools_dir / RENDER_TOOL.name)
    forbidden = {".godot", ".import", ".uid", "__pycache__", ".DS_Store", "Thumbs.db"}
    hidden_or_build = [path for path in output_root.rglob("*") if path.name in forbidden or path.name.startswith("~$")]
    if hidden_or_build:
        raise RuntimeError(f"Hidden/build artifacts found in gate package: {hidden_or_build}")
    artifact_paths = sorted(
        path for path in output_root.rglob("*")
        if path.is_file() and path.name not in {"package_manifest_v1_1.json", "SHA256SUMS.txt"}
    )
    manifest = {
        "schema": "caden-building-terrain-gate-package-v1.1",
        "gate_state": "pending_visual_approval_no_live_scene_changes",
        "repository_commit": preparation["repository_commit"],
        "source_manifest_sha256": sha256(preparation_path),
        "render_manifest_sha256": sha256(render_manifest_path),
        "comparison_board_sha256": sha256(comparison_board),
        "catalog_rows": preparation["catalog_row_count"],
        "candidate_count": preparation["candidate_count"],
        "tooling": versions,
        "tool_hashes": {
            f"tooling/{SCRIPT_PATH.name}": sha256(tools_dir / SCRIPT_PATH.name),
            f"tooling/{RENDER_TOOL.name}": sha256(tools_dir / RENDER_TOOL.name),
        },
        "provenance_and_licensing": preparation["provenance_and_licensing"],
        "live_scene_files_modified_by_gate": [],
        "artifacts": {path.relative_to(output_root).as_posix(): sha256(path) for path in artifact_paths},
    }
    manifest_path = output_root / "metadata/package_manifest_v1_1.json"
    write_json(manifest_path, manifest)
    checksum_paths = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name != "SHA256SUMS.txt")
    checksum_path = output_root / "SHA256SUMS.txt"
    checksum_path.write_text(
        "".join(f"{sha256(path)}  {path.relative_to(output_root).as_posix()}\n" for path in checksum_paths),
        encoding="utf-8",
        newline="\n",
    )
    archive = output_root.parent / f"{output_root.name}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as handle:
        for path in sorted(item for item in output_root.rglob("*") if item.is_file()):
            handle.write(path, Path(output_root.name) / path.relative_to(output_root))
    print(f"finalized={output_root}")
    print(f"archive={archive}")
    print(f"archive_sha256={sha256(archive)}")
    return archive


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--finalize", action="store_true")
    args = parser.parse_args()
    output_root = args.output_root.resolve()
    if args.finalize:
        finalize(output_root)
    else:
        if args.source_root is None:
            parser.error("--source-root is required unless --finalize is used")
        prepare(args.source_root.resolve(), output_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
