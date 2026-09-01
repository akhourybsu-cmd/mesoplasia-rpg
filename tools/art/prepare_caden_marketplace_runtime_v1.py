#!/usr/bin/env python3
"""Normalize and audit the approved Caden Marketplace v1 runtime shortlist."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RUNTIME_ROOT = ROOT / "assets/environments/caden/marketplace/props/runtime_v1"
MANIFEST_PATH = ROOT / "assets/environments/caden/marketplace/marketplace_runtime_manifest_v1.json"
RIGHTS_RECORD_PATH = ROOT / "assets/environments/caden/marketplace/caden_marketplace_source_rights_v1.json"
SCALE = 0.1875
PADDING = 2


@dataclass(frozen=True)
class MarketplaceSpec:
    short_id: str
    asset_id: str
    runtime_name: str
    scene_node_path: str
    world_position: tuple[int, int]
    collision_size: tuple[int, int]
    role: str


SPECS = (
    MarketplaceSpec("01", "caden_sp_mkt_01_produce_crate_display_master_v1", "produce_crate_display_runtime_v1.png", "Stalls/Stall01", (208, 184), (56, 16), "northwest produce frontage"),
    MarketplaceSpec("03", "caden_sp_mkt_03_folded_cloth_display_master_v1", "folded_cloth_display_runtime_v1.png", "Stalls/Stall03", (560, 184), (48, 16), "northeast cloth frontage"),
    MarketplaceSpec("04", "caden_sp_mkt_04_pottery_jars_display_master_v1", "pottery_jars_display_runtime_v1.png", "Stalls/Stall04", (688, 184), (56, 16), "northeast household frontage"),
    MarketplaceSpec("06", "caden_sp_mkt_06_barrel_sack_storage_master_v1", "barrel_sack_storage_runtime_v1.png", "Stalls/Stall06", (336, 488), (56, 16), "southwest rear-of-stall backstock"),
    MarketplaceSpec("07", "caden_sp_mkt_07_vendor_counter_mixed_goods_master_v1", "vendor_counter_mixed_goods_runtime_v1.png", "Stalls/Stall02|Stalls/Stall05", (336, 184), (64, 24), "paired primary vendor anchors"),
    MarketplaceSpec("13", "caden_sp_mkt_13_empty_crates_barrels_master_v1", "empty_crates_barrels_runtime_v1.png", "Stalls/Stall07", (560, 488), (56, 16), "southeast neutral service storage"),
    MarketplaceSpec("14", "caden_sp_mkt_14_shopfront_supply_cluster_master_v1", "shopfront_supply_cluster_runtime_v1.png", "Stalls/Stall08", (688, 488), (56, 16), "southeast mixed-goods backstock"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def parse_pair(value: str) -> tuple[int, int]:
    left, right = value.split(",")
    return int(left), int(right)


def parse_bounds(value: str) -> tuple[int, int, int, int]:
    parts = tuple(int(part) for part in value.split(","))
    if len(parts) != 4:
        raise ValueError(value)
    return parts  # type: ignore[return-value]


def load_catalog(library_root: Path) -> dict[str, dict[str, str]]:
    manifest_path = library_root / "metadata/ASSET_MANIFEST.csv"
    with manifest_path.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 222:
        raise RuntimeError(f"Expected 222 catalog rows, found {len(rows)}.")
    by_id = {row["asset_id"]: row for row in rows}
    for spec in SPECS:
        row = by_id.get(spec.asset_id)
        if row is None or row["status"] not in {"candidate", "candidate_review_required"}:
            raise RuntimeError(f"Approved candidate is missing or ineligible: {spec.asset_id}")
    return by_id


def load_rights_decision() -> dict[str, str]:
    payload = json.loads(RIGHTS_RECORD_PATH.read_text(encoding="utf-8"))
    decision = payload.get("decision", {})
    if payload.get("gate_state") != "operational_distribution_clearance_recorded":
        raise RuntimeError("Marketplace rights clearance is not active.")
    if decision.get("rights_status") != "openai_output_provenance_verified":
        raise RuntimeError("Marketplace rights clearance has an unexpected status.")
    return decision


def visible_boundary(image: Image.Image) -> set[tuple[int, int]]:
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


def bright_halo_positions(image: Image.Image) -> set[tuple[int, int]]:
    rgba = image.load()
    positions: set[tuple[int, int]] = set()
    for x, y in visible_boundary(image):
        red, green, blue, _alpha = rgba[x, y]
        if max(red, green, blue) - min(red, green, blue) <= 28 and (red + green + blue) / 3 >= 218:
            positions.add((x, y))
    return positions


def clean_bright_halo(image: Image.Image) -> int:
    rgba = image.load()
    replacements: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    for x, y in bright_halo_positions(image):
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
            candidates.sort(key=sum)
            replacements[(x, y)] = (*candidates[len(candidates) // 2], alpha)
        else:
            replacements[(x, y)] = (0, 0, 0, 0)
    for position, color in replacements.items():
        rgba[position] = color
    return len(replacements)


def remove_presentation_shadow(image: Image.Image) -> int:
    rgba = image.load()
    candidates: set[tuple[int, int]] = set()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = rgba[x, y]
            if alpha == 0:
                continue
            saturation = max(red, green, blue) - min(red, green, blue)
            brightness = (red + green + blue) / 3
            if saturation <= 24 and 95 <= brightness <= 238:
                candidates.add((x, y))

    seed_region_x = int(image.width * 0.76)
    seed_region_y = int(image.height * 0.52)
    seeds = [
        position
        for position in visible_boundary(image)
        if position in candidates and (position[0] >= seed_region_x or position[1] >= seed_region_y)
    ]
    removable: set[tuple[int, int]] = set(seeds)
    stack = list(seeds)
    while stack:
        x, y = stack.pop()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            position = (nx, ny)
            if position in candidates and position not in removable:
                removable.add(position)
                stack.append(position)
    for position in removable:
        rgba[position] = (0, 0, 0, 0)
    return len(removable)


def make_binary_alpha(image: Image.Image) -> int:
    rgba = image.load()
    changed = 0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = rgba[x, y]
            target = 255 if alpha >= 128 else 0
            if alpha != target:
                changed += 1
            rgba[x, y] = (red, green, blue, target) if target else (0, 0, 0, 0)
    return changed


def remove_tiny_fragments(image: Image.Image, maximum_area: int = 2) -> tuple[int, int]:
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


def sanitize_transparency(image: Image.Image) -> int:
    rgba = image.load()
    changed = 0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = rgba[x, y]
            if alpha == 0 and (red or green or blue):
                rgba[x, y] = (0, 0, 0, 0)
                changed += 1
    return changed


def component_sizes(image: Image.Image) -> list[int]:
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


def edge_pixel_count(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    pixels = alpha.load()
    positions = {(x, 0) for x in range(image.width)} | {(x, image.height - 1) for x in range(image.width)}
    positions |= {(0, y) for y in range(image.height)} | {(image.width - 1, y) for y in range(image.height)}
    return sum(pixels[position] > 0 for position in positions)


def audit(image: Image.Image) -> dict[str, object]:
    alpha_values = list(image.getchannel("A").get_flattened_data())
    sizes = component_sizes(image)
    transparent_rgb = sum(
        1 for red, green, blue, alpha in image.get_flattened_data() if alpha == 0 and (red or green or blue)
    )
    return {
        "visible_bounds_xyxy": list(image.getchannel("A").getbbox() or ()),
        "visible_pixels": sum(alpha > 0 for alpha in alpha_values),
        "partial_alpha_pixels": sum(0 < alpha < 255 for alpha in alpha_values),
        "transparent_rgb_pixels": transparent_rgb,
        "canvas_edge_pixels": edge_pixel_count(image),
        "bright_boundary_halo_candidates": len(bright_halo_positions(image)),
        "connected_components": len(sizes),
        "detached_components_at_or_below_2_pixels": sum(size <= 2 for size in sizes),
        "largest_component_pixels": sizes[0] if sizes else 0,
        "smallest_component_pixels": sizes[-1] if sizes else 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("library_root", type=Path)
    args = parser.parse_args()
    library_root = args.library_root.resolve()
    if ROOT == library_root or ROOT in library_root.parents:
        raise RuntimeError("The Caden Mega Asset Library archive must remain staged outside res://.")
    catalog = load_catalog(library_root)
    rights = load_rights_decision()
    RUNTIME_ROOT.mkdir(parents=True, exist_ok=True)
    records: dict[str, object] = {}

    for spec in SPECS:
        row = catalog[spec.asset_id]
        source_path = library_root / row["package_path"]
        if not source_path.is_file() or sha256(source_path) != row["package_sha256"]:
            raise RuntimeError(f"Unexpected source asset: {source_path}")
        source = Image.open(source_path).convert("RGBA")
        cropped = source.crop(parse_bounds(row["alpha_bounds_xyxy"]))
        normalized_size = (round(cropped.width * SCALE), round(cropped.height * SCALE))
        normalized = cropped.resize(normalized_size, Image.Resampling.NEAREST)
        target_dimensions = parse_pair(row["proposed_target_dimensions"])
        runtime = Image.new("RGBA", target_dimensions, (0, 0, 0, 0))
        runtime.alpha_composite(normalized, (PADDING, PADDING))
        if runtime.size != target_dimensions:
            raise RuntimeError(f"Unexpected target dimensions for {spec.asset_id}: {runtime.size}")

        alpha_pixels_binarized = make_binary_alpha(runtime)
        shadow_pixels_removed = remove_presentation_shadow(runtime)
        halo_pixels_cleaned = clean_bright_halo(runtime)
        fragment_count, fragment_pixels = remove_tiny_fragments(runtime)
        transparent_rgb_pixels_zeroed = sanitize_transparency(runtime)
        post_cleanup = audit(runtime)
        for key in (
            "partial_alpha_pixels",
            "transparent_rgb_pixels",
            "canvas_edge_pixels",
            "bright_boundary_halo_candidates",
            "detached_components_at_or_below_2_pixels",
        ):
            if post_cleanup[key] != 0:
                raise RuntimeError(f"Post-cleanup audit failed for {spec.asset_id}: {key}={post_cleanup[key]}")

        output_path = RUNTIME_ROOT / spec.runtime_name
        runtime.save(output_path, format="PNG", compress_level=9)
        records[spec.short_id] = {
            "catalog_asset_id": spec.asset_id,
            "catalog_status": row["status"],
            "selection_status": "marketplace_selected",
            "approval_state": "approved_for_marketplace_runtime_v1_integration",
            "rights_status": rights["rights_status"],
            "source_package": "Caden Mega Asset Library v1.1 staged outside res://",
            "source_package_path": row["package_path"],
            "source_sha256": row["package_sha256"],
            "source_dimensions": list(parse_pair(row["package_dimensions"])),
            "source_bounds_xyxy": list(parse_bounds(row["alpha_bounds_xyxy"])),
            "scale_family": row["scale_family"],
            "normalization_factor": SCALE,
            "resampling": "nearest-neighbor",
            "runtime_path": output_path.relative_to(ROOT).as_posix(),
            "runtime_sha256": sha256(output_path),
            "runtime_dimensions": list(runtime.size),
            "pivot_xy": list(parse_pair(row["proposed_pivot_xy"])),
            "pivot_basis": "bottom-center structural ground contact; excludes removed presentation shadow",
            "import_scale": 1.0,
            "intended_placement": spec.role,
            "scene_path": "scenes/world/caden/Marketplace.tscn",
            "scene_node_path": spec.scene_node_path,
            "primary_world_position_xy": list(spec.world_position),
            "collision": {
                "shape": "rectangle",
                "size": list(spec.collision_size),
                "offset_from_ground_contact_xy": [0, -spec.collision_size[1] // 2],
                "strategy": "solid counter, crates, barrels, or storage base only; canvas bounds do not collide",
            },
            "manual_cleanup": {
                "partial_alpha_pixels_binarized": alpha_pixels_binarized,
                "presentation_shadow_pixels_removed": shadow_pixels_removed,
                "bright_halo_pixels_recolored_or_removed": halo_pixels_cleaned,
                "detached_fragments_removed": fragment_count,
                "detached_fragment_pixels_removed": fragment_pixels,
                "transparent_rgb_pixels_zeroed": transparent_rgb_pixels_zeroed,
            },
            "post_cleanup_audit": post_cleanup,
        }

    manifest = {
        "schema": "caden-marketplace-runtime-manifest-v1",
        "generator": "tools/art/prepare_caden_marketplace_runtime_v1.py",
        "generator_sha256": sha256(Path(__file__)),
        "source_package": "Caden Mega Asset Library v1.1",
        "source_package_location_policy": "staged outside res://; only selected cleaned runtime PNGs are imported",
        "catalog_rows_verified": 222,
        "scope": "Seven explicitly approved Marketplace candidates only.",
        "gate_state": "marketplace_runtime_v1_visual_approved",
        "provenance_and_licensing": {
            "rights_record": RIGHTS_RECORD_PATH.relative_to(ROOT).as_posix(),
            "notes": "Operational project clearance records ChatGPT delivery provenance, OpenAI output-ownership terms, third-party-mark review, and two disclosed corrected-source archival exceptions.",
            "rights_status": rights["rights_status"],
            "distribution_status": rights["distribution_status"],
        },
        "preserved_rejections": {
            "all_marketplace_structure_masters": "rejected",
            "setpieces": ["09", "10", "12", "15"],
            "mega_set": ["01"],
        },
        "assets": records,
    }
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"runtime_assets={len(records)}")
    print(f"manifest={MANIFEST_PATH.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
