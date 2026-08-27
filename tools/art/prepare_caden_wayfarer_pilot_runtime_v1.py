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
    catalog_asset_id: str
    source_name: str
    source_sha256: str
    source_bounds: tuple[int, int, int, int]
    runtime_name: str
    target_dimensions: tuple[int, int]
    pivot: tuple[int, int]
    intended_placement: str
    scene_node_path: str
    world_position: tuple[int, int]
    solid_bounds: tuple[int, int, int, int]
    passable_details: tuple[str, ...]
    shadow_regions: tuple[tuple[int, int, int, int], ...]
    collisions: tuple[dict[str, object], ...]


SPECS = (
    PilotSpec(
        key="sp_way_05_bench_luggage_lantern",
        catalog_asset_id="caden_sp_way_05_bench_luggage_lantern_master_v1",
        source_name="caden_sp_way_05_bench_luggage_lantern_source_v1.png",
        source_sha256="da43948a523945de20f696a862f2db62bd66c5f219d785a468d241d122197894",
        source_bounds=(32, 32, 608, 384),
        runtime_name="bench_luggage_lantern_pilot_v1.png",
        target_dimensions=(112, 70),
        pivot=(56, 63),
        intended_placement="open right-side rest lawn, clear of the road and eastern transition corridor",
        scene_node_path="SolidScenery/PilotProps/BenchLuggageLantern",
        world_position=(860, 556),
        solid_bounds=(-38, -13, 50, 1),
        passable_details=("flowers", "stones", "ground decoration", "removed shadow pixels"),
        shadow_regions=((96, 48, 112, 64),),
        collisions=(
            {"name": "lantern_post", "shape": "rectangle", "offset": [-33, -8], "size": [10, 10]},
            {"name": "bench", "shape": "rectangle", "offset": [-7, -6], "size": [48, 10]},
            {"name": "luggage", "shape": "rectangle", "offset": [31, -6], "size": [38, 14]},
        ),
    ),
    PilotSpec(
        key="sp_way_07_hitching_rail_barrels",
        catalog_asset_id="caden_sp_way_07_hitching_rail_barrels_master_v1",
        source_name="caden_sp_way_07_hitching_rail_barrels_source_v1.png",
        source_sha256="9e2a243a381c735c730af3a899d9d82b503f94b0340478b530357d7734804d87",
        source_bounds=(32, 32, 624, 346),
        runtime_name="hitching_rail_barrels_pilot_v1.png",
        target_dimensions=(115, 63),
        pivot=(57, 55),
        intended_placement="traveler wagon and hitching area, south of the preserved east-west road corridor",
        scene_node_path="SolidScenery/PilotProps/HitchingRailBarrels",
        world_position=(650, 500),
        solid_bounds=(-50, -15, 48, 1),
        passable_details=("flowers", "rope gaps", "ground decoration", "removed shadow pixels"),
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


def _bright_halo_positions(image: Image.Image) -> set[tuple[int, int]]:
    rgba = image.load()
    positions: set[tuple[int, int]] = set()
    for x, y in _visible_boundary(image):
        red, green, blue, _alpha = rgba[x, y]
        if max(red, green, blue) - min(red, green, blue) <= 28 and (red + green + blue) / 3 >= 218:
            positions.add((x, y))
    return positions


def _clean_bright_halo(image: Image.Image) -> int:
    rgba = image.load()
    replacements: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    for x, y in _bright_halo_positions(image):
        _red, _green, _blue, alpha = rgba[x, y]
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


def _component_sizes(image: Image.Image) -> list[int]:
    alpha = image.getchannel("A")
    pixels = alpha.load()
    visited: set[tuple[int, int]] = set()
    sizes: list[int] = []
    for y in range(image.height):
        for x in range(image.width):
            if pixels[x, y] == 0 or (x, y) in visited:
                continue
            stack = [(x, y)]
            visited.add((x, y))
            size = 0
            while stack:
                px, py = stack.pop()
                size += 1
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if nx < 0 or ny < 0 or nx >= image.width or ny >= image.height:
                        continue
                    if pixels[nx, ny] == 0 or (nx, ny) in visited:
                        continue
                    visited.add((nx, ny))
                    stack.append((nx, ny))
            sizes.append(size)
    return sorted(sizes, reverse=True)


def _post_cleanup_audit(image: Image.Image) -> dict[str, object]:
    alpha = image.getchannel("A")
    alpha_values = list(alpha.get_flattened_data())
    component_sizes = _component_sizes(image)
    visible_bounds = alpha.getbbox()
    transparent_rgb_pixels = sum(
        1
        for red, green, blue, value in image.get_flattened_data()
        if value == 0 and (red != 0 or green != 0 or blue != 0)
    )
    return {
        "visible_bounds_xyxy": list(visible_bounds) if visible_bounds is not None else None,
        "visible_pixels": sum(value > 0 for value in alpha_values),
        "partial_alpha_pixels": sum(0 < value < 255 for value in alpha_values),
        "transparent_rgb_pixels": transparent_rgb_pixels,
        "canvas_edge_pixels": _edge_pixel_count(image),
        "bright_boundary_halo_candidates": len(_bright_halo_positions(image)),
        "connected_components": len(component_sizes),
        "detached_components_at_or_below_2_pixels": sum(size <= 2 for size in component_sizes),
        "smallest_component_pixels": component_sizes[-1] if component_sizes else 0,
        "largest_component_pixels": component_sizes[0] if component_sizes else 0,
    }


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
        if runtime.size != spec.target_dimensions:
            raise RuntimeError(f"Unexpected target dimensions for {spec.key}: {runtime.size}")
        shadow_pixels = _remove_baked_shadow(runtime, spec.shadow_regions)
        halo_pixels = _clean_bright_halo(runtime)
        fragment_count, fragment_pixels = _remove_tiny_fragments(runtime)
        transparent_rgb_pixels = _sanitize_transparency(runtime)
        edge_pixels = _edge_pixel_count(runtime)
        if edge_pixels:
            raise RuntimeError(f"Runtime edge pixels remain for {spec.key}: {edge_pixels}")
        post_cleanup_audit = _post_cleanup_audit(runtime)
        for audit_key in (
            "partial_alpha_pixels",
            "transparent_rgb_pixels",
            "canvas_edge_pixels",
            "bright_boundary_halo_candidates",
            "detached_components_at_or_below_2_pixels",
        ):
            if post_cleanup_audit[audit_key] != 0:
                raise RuntimeError(f"Post-cleanup audit failed for {spec.key}: {audit_key}")
        output_path = RUNTIME_ROOT / spec.runtime_name
        runtime.save(output_path, format="PNG", compress_level=9)
        records[spec.key] = {
            "catalog_asset_id": spec.catalog_asset_id,
            "catalog_source": "metadata/ASSET_CATALOG.json in Caden Mega Asset Library v1.1",
            "catalog_status": "candidate",
            "catalog_metadata_status": "proposed_pending_visual_approval",
            "selection_status": "pilot_selected",
            "approval_state": "pilot_selected_wayfarer_structural_recomposition_v5_approved",
            "rights_status": "project_internal_rights_unverified",
            "zone": "wayfarers_approach",
            "intended_placement": spec.intended_placement,
            "scene_path": "scenes/world/caden/WayfarersApproach.tscn",
            "scene_node_path": spec.scene_node_path,
            "world_position_xy": list(spec.world_position),
            "scale_family": "medium_setpiece",
            "source_path": source_path.relative_to(ROOT).as_posix(),
            "source_sha256": spec.source_sha256,
            "source_dimensions": list(source.size),
            "source_bounds_xyxy": list(spec.source_bounds),
            "scale": SCALE,
            "resampling": "nearest-neighbor",
            "target_runtime_dimensions": list(spec.target_dimensions),
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
            "intended_footprint": {
                "solid_bounds_relative_to_pivot_xyxy": list(spec.solid_bounds),
                "solid_bounds_size": [spec.solid_bounds[2] - spec.solid_bounds[0], spec.solid_bounds[3] - spec.solid_bounds[1]],
                "passable_details": list(spec.passable_details),
            },
            "collision_shapes": list(spec.collisions),
            "sorting_strategy": "player-relative z-index from structural ground-contact Y; behind=9, neutral=10, front=11",
            "post_cleanup_audit": post_cleanup_audit,
            "runtime_sha256": sha256(output_path),
        }
    manifest = {
        "version": 2,
        "generator": "tools/art/prepare_caden_wayfarer_pilot_runtime_v1.py",
        "generator_sha256": sha256(Path(__file__)),
        "source_package": "Caden Mega Asset Library v1.1",
        "source_package_sha256": "7859e29f917e1a3bca18334d831bac361d543a9be40f8b8e8cc03649ee3a98a1",
        "scope": "Limited two-asset Wayfarer pilot; no additional library assets authorized.",
        "provenance_and_licensing": {
            "source": "Caden Mega Asset Library v1.1",
            "notes": "See docs/PROVENANCE_AND_LICENSE.md in the verified source package.",
            "rights_status": "project_internal_rights_unverified",
            "distribution_status": "do_not_publish_until_rights_are_verified",
        },
        "concept_authority": {
            "allowed": ["palette", "materials", "lighting", "architectural language", "greenery", "relative density"],
            "excluded": ["signs", "emblems", "central monument", "exact geometry", "lore-bearing details"],
        },
        "approval_decisions": {
            "pilot_selected": ["sp_way_05_bench_luggage_lantern", "sp_way_07_hitching_rail_barrels"],
            "scale_approved_alternates_not_selected": ["sp_way_06_bench_packs_planter", "sp_way_08_hitching_posts_supplies"],
            "deferred": {
                "sp_way_11": "corrected but absent from the approved scale-calibration board",
                "sp_way_12": "corrected but absent from the approved scale-calibration board; may read as a Marketplace stall",
                "sp_way_13": "corrected but absent from the approved scale-calibration board",
                "sp_way_14": "reserved for an optional Festival-state pass",
                "sp_way_15": "tree reads as a sapling; combined sprite creates collision and depth-sorting problems",
            },
            "rejected_as_is": ["all seven Wayfarer buildings", "sp_way_01-04", "sp_way_09-10", "sp_way_16"],
        },
        "gate": "Wayfarer's Approach structural recomposition v5 visually approved; Marketplace composition and candidate shortlist review is the next gate.",
        "assets": records,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"pilot_assets={len(records)}")
    print(f"manifest={MANIFEST_PATH.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
