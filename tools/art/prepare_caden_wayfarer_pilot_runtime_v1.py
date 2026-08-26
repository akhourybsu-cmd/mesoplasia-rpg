#!/usr/bin/env python3
"""Normalize the two approved Caden Wayfarer pilot props."""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = ROOT / "assets/source_art/caden/environment/wayfarers_approach/pilot_v1"
RUNTIME_ROOT = ROOT / "assets/environments/caden/wayfarers_approach/props/pilot_v1"
MANIFEST_PATH = ROOT / "assets/environments/caden/wayfarers_approach/wayfarers_approach_pilot_runtime_v1.json"
SCALE = 0.1875
PADDING = 2


@dataclass(frozen=True)
class PilotSpec:
    key: str
    source_name: str
    source_sha256: str
    source_bounds: tuple[int, int, int, int]
    runtime_name: str
    pivot: tuple[int, int]
    shadow_regions: tuple[tuple[int, int, int, int], ...]
    collisions: tuple[dict[str, object], ...]


SPECS = (
    PilotSpec(
        key="sp_way_05_bench_luggage_lantern",
        source_name="caden_sp_way_05_bench_luggage_lantern_source_v1.png",
        source_sha256="da43948a523945de20f696a862f2db62bd66c5f219d785a468d241d122197894",
        source_bounds=(32, 32, 608, 384),
        runtime_name="bench_luggage_lantern_pilot_v1.png",
        pivot=(56, 63),
        shadow_regions=((96, 48, 112, 64),),
        collisions=(
            {"name": "lantern_post", "shape": "rectangle", "offset": [-33, -8], "size": [10, 10]},
            {"name": "bench", "shape": "rectangle", "offset": [-7, -6], "size": [48, 10]},
            {"name": "luggage", "shape": "rectangle", "offset": [31, -6], "size": [38, 14]},
        ),
    ),
    PilotSpec(
        key="sp_way_07_hitching_rail_barrels",
        source_name="caden_sp_way_07_hitching_rail_barrels_source_v1.png",
        source_sha256="9e2a243a381c735c730af3a899d9d82b503f94b0340478b530357d7734804d87",
        source_bounds=(32, 32, 624, 346),
        runtime_name="hitching_rail_barrels_pilot_v1.png",
        pivot=(57, 55),
        shadow_regions=((50, 45, 91, 58),),
        collisions=(
            {"name": "barrels", "shape": "rectangle", "offset": [-29, -7], "size": [42, 16]},
            {"name": "hitching_rail", "shape": "rectangle", "offset": [13, -5], "size": [70, 10]},
        ),
    ),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _visible_boundary(image: Image.Image) -> set[tuple[int, int]]:
    alpha = image.getchannel("A")
    pixels = alpha.load()
    boundary: set[tuple[int, int]] = set()
    for y in range(image.height):
        for x in range(image.width):
            if pixels[x, y] == 0:
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if nx < 0 or ny < 0 or nx >= image.width or ny >= image.height or pixels[nx, ny] == 0:
                    boundary.add((x, y))
                    break
    return boundary


def _clean_bright_halo(image: Image.Image) -> int:
    rgba = image.load()
    replacements: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    for x, y in _visible_boundary(image):
        red, green, blue, alpha = rgba[x, y]
        if max(red, green, blue) - min(red, green, blue) > 28 or (red + green + blue) / 3 < 218:
            continue
        candidates: list[tuple[int, int, int]] = []
        for ny in range(max(0, y - 2), min(image.height, y + 3)):
            for nx in range(max(0, x - 2), min(image.width, x + 3)):
                nr, ng, nb, na = rgba[nx, ny]
                if na == 0 or (nr + ng + nb) / 3 >= 210:
                    continue
                if max(nr, ng, nb) - min(nr, ng, nb) < 18:
                    continue
                candidates.append((nr, ng, nb))
        if candidates:
            candidates.sort(key=lambda color: sum(color))
            replacement = candidates[len(candidates) // 2]
            replacements[(x, y)] = (*replacement, alpha)
        else:
            replacements[(x, y)] = (0, 0, 0, 0)
    for position, color in replacements.items():
        rgba[position] = color
    return len(replacements)


def _remove_baked_shadow(image: Image.Image, regions: tuple[tuple[int, int, int, int], ...]) -> int:
    rgba = image.load()
    removed = 0
    for left, top, right, bottom in regions:
        for y in range(max(0, top), min(image.height, bottom)):
            for x in range(max(0, left), min(image.width, right)):
                red, green, blue, alpha = rgba[x, y]
                if alpha == 0:
                    continue
                saturation = max(red, green, blue) - min(red, green, blue)
                brightness = (red + green + blue) / 3
                if saturation <= 24 and 18 <= brightness <= 185:
                    rgba[x, y] = (0, 0, 0, 0)
                    removed += 1
    return removed


def _remove_tiny_fragments(image: Image.Image, maximum_area: int = 2) -> tuple[int, int]:
    alpha = image.getchannel("A")
    pixels = alpha.load()
    visited: set[tuple[int, int]] = set()
    fragments: list[list[tuple[int, int]]] = []
    for y in range(image.height):
        for x in range(image.width):
            if pixels[x, y] == 0 or (x, y) in visited:
                continue
            stack = [(x, y)]
            visited.add((x, y))
            component: list[tuple[int, int]] = []
            while stack:
                px, py = stack.pop()
                component.append((px, py))
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if nx < 0 or ny < 0 or nx >= image.width or ny >= image.height:
                        continue
                    if pixels[nx, ny] == 0 or (nx, ny) in visited:
                        continue
                    visited.add((nx, ny))
                    stack.append((nx, ny))
            if len(component) <= maximum_area:
                fragments.append(component)
    rgba = image.load()
    for component in fragments:
        for position in component:
            rgba[position] = (0, 0, 0, 0)
    return len(fragments), sum(len(component) for component in fragments)


def _sanitize_transparency(image: Image.Image) -> int:
    rgba = image.load()
    changed = 0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = rgba[x, y]
            if alpha == 0 and (red or green or blue):
                rgba[x, y] = (0, 0, 0, 0)
                changed += 1
    return changed


def _edge_pixel_count(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    pixels = alpha.load()
    positions = {(x, 0) for x in range(image.width)} | {(x, image.height - 1) for x in range(image.width)}
    positions |= {(0, y) for y in range(image.height)} | {(image.width - 1, y) for y in range(image.height)}
    return sum(pixels[position] > 0 for position in positions)


def main() -> int:
    RUNTIME_ROOT.mkdir(parents=True, exist_ok=True)
    records: dict[str, object] = {}
    for spec in SPECS:
        source_path = SOURCE_ROOT / spec.source_name
        if sha256(source_path) != spec.source_sha256:
            raise RuntimeError(f"Unexpected source hash: {source_path}")
        source = Image.open(source_path).convert("RGBA")
        cropped = source.crop(spec.source_bounds)
        normalized_size = (
            round(cropped.width * SCALE),
            round(cropped.height * SCALE),
        )
        normalized = cropped.resize(normalized_size, Image.Resampling.NEAREST)
        runtime = Image.new("RGBA", (normalized.width + PADDING * 2, normalized.height + PADDING * 2), (0, 0, 0, 0))
        runtime.alpha_composite(normalized, (PADDING, PADDING))
        shadow_pixels = _remove_baked_shadow(runtime, spec.shadow_regions)
        halo_pixels = _clean_bright_halo(runtime)
        fragment_count, fragment_pixels = _remove_tiny_fragments(runtime)
        transparent_rgb_pixels = _sanitize_transparency(runtime)
        edge_pixels = _edge_pixel_count(runtime)
        if edge_pixels:
            raise RuntimeError(f"Runtime edge pixels remain for {spec.key}: {edge_pixels}")
        output_path = RUNTIME_ROOT / spec.runtime_name
        runtime.save(output_path, format="PNG", compress_level=9)
        records[spec.key] = {
            "selection_status": "pilot_selected",
            "source_path": source_path.relative_to(ROOT).as_posix(),
            "source_sha256": spec.source_sha256,
            "source_dimensions": list(source.size),
            "source_bounds_xyxy": list(spec.source_bounds),
            "scale": SCALE,
            "resampling": "nearest-neighbor",
            "manual_cleanup": {
                "bright_halo_pixels_recolored_or_removed": halo_pixels,
                "baked_shadow_pixels_removed": shadow_pixels,
                "detached_fragments_removed": fragment_count,
                "detached_fragment_pixels_removed": fragment_pixels,
                "transparent_rgb_pixels_zeroed": transparent_rgb_pixels,
                "remaining_edge_pixels": edge_pixels,
            },
            "runtime_path": output_path.relative_to(ROOT).as_posix(),
            "runtime_dimensions": list(runtime.size),
            "pivot_xy": list(spec.pivot),
            "pivot_basis": "bottom-center structural ground contact; excludes flowers, stones, and shadow pixels",
            "import_scale": 1.0,
            "collision_shapes": list(spec.collisions),
            "runtime_sha256": sha256(output_path),
        }
    manifest = {
        "version": 1,
        "generator": "tools/art/prepare_caden_wayfarer_pilot_runtime_v1.py",
        "generator_sha256": sha256(Path(__file__)),
        "source_package": "Caden Mega Asset Library v1.1",
        "source_package_sha256": "7859e29f917e1a3bca18334d831bac361d543a9be40f8b8e8cc03649ee3a98a1",
        "scope": "Limited two-asset Wayfarer pilot; no additional library assets authorized.",
        "assets": records,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"pilot_assets={len(records)}")
    print(f"manifest={MANIFEST_PATH.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
