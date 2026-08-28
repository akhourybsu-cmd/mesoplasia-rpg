#!/usr/bin/env python3
"""Normalize and audit the approved Caden Residential runtime shortlist."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path

from PIL import Image

from prepare_caden_marketplace_runtime_v1 import (
    audit,
    clean_bright_halo,
    make_binary_alpha,
    parse_bounds,
    parse_pair,
    remove_presentation_shadow,
    remove_tiny_fragments,
    sanitize_transparency,
    sha256,
)


ROOT = Path(__file__).resolve().parents[2]
RUNTIME_ROOT = ROOT / "assets/environments/caden/residential/props/runtime_v1"
MANIFEST_PATH = ROOT / "assets/environments/caden/residential/residential_runtime_manifest_v1.json"
SCALE = 0.1875
PADDING = 2


@dataclass(frozen=True)
class ResidentialSpec:
    short_id: str
    asset_id: str
    runtime_name: str
    scene_node_path: str
    world_position: tuple[int, int]
    collision: str
    role: str


SPECS = (
    ResidentialSpec("01", "caden_sp_res_01_fenced_flower_yard_master_v1", "fenced_flower_yard_runtime_v1.png", "DomesticSetPieces/FencedFlowerYard", (608, 288), "64x16 garden fence base", "northeast maintained flower yard"),
    ResidentialSpec("04", "caden_sp_res_04_woodpile_barrel_fence_master_v1", "woodpile_barrel_fence_runtime_v1.png", "DomesticSetPieces/WoodpileBarrelFence", (80, 688), "64x16 storage base", "southwest household wood storage"),
    ResidentialSpec("05", "caden_sp_res_05_laundry_line_master_v1", "laundry_line_runtime_v1.png", "DomesticSetPieces/LaundryLine", (400, 536), "two 10x12 post bases; center passable", "southwest private laundry yard"),
    ResidentialSpec("06", "caden_sp_res_06_small_garden_patch_master_v1", "small_garden_patch_runtime_v1.png", "DomesticSetPieces/SmallGardenPatch", (752, 536), "56x16 raised garden base", "southeast productive garden"),
    ResidentialSpec("08", "caden_sp_res_08_doorstep_flower_cluster_master_v1", "doorstep_flower_cluster_runtime_v1.png", "DomesticSetPieces/DoorstepFlowerCluster", (384, 256), "two 12x12 planter bases; central steps passable", "northwest home threshold"),
    ResidentialSpec("09", "caden_sp_res_09_rain_barrels_crates_master_v1", "rain_barrels_crates_runtime_v1.png", "DomesticSetPieces/RainBarrelsCrates", (1080, 688), "56x16 shed and storage base", "southeast side-yard storage"),
    ResidentialSpec("11", "caden_sp_res_11_stepping_stone_flowers_master_v1", "stepping_stone_flowers_runtime_v1.png", "DomesticSetPieces/SteppingStoneFlowers", (800, 288), "none; stepping stones and flowers remain walkable", "northeast doorstep path"),
)


def load_residential_catalog(library_root: Path) -> dict[str, dict[str, str]]:
    import csv

    with (library_root / "metadata/ASSET_MANIFEST.csv").open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 222:
        raise RuntimeError(f"Expected 222 catalog rows, found {len(rows)}.")
    by_id = {row["asset_id"]: row for row in rows}
    for spec in SPECS:
        row = by_id.get(spec.asset_id)
        if row is None or row["status"] != "candidate":
            raise RuntimeError(f"Approved Residential candidate is missing or ineligible: {spec.asset_id}")
        if row["proposed_scale_factor"] != str(SCALE):
            raise RuntimeError(f"Unexpected scale recommendation for {spec.asset_id}.")
    return by_id


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("library_root", type=Path)
    args = parser.parse_args()
    library_root = args.library_root.resolve()
    if ROOT == library_root or ROOT in library_root.parents:
        raise RuntimeError("The Caden Mega Asset Library archive must remain staged outside res://.")
    catalog = load_residential_catalog(library_root)
    RUNTIME_ROOT.mkdir(parents=True, exist_ok=True)
    records: dict[str, object] = {}

    for spec in SPECS:
        row = catalog[spec.asset_id]
        source_path = library_root / row["package_path"]
        if not source_path.is_file() or sha256(source_path) != row["package_sha256"]:
            raise RuntimeError(f"Unexpected source asset: {source_path}")
        source = Image.open(source_path).convert("RGBA")
        cropped = source.crop(parse_bounds(row["alpha_bounds_xyxy"]))
        normalized = cropped.resize((round(cropped.width * SCALE), round(cropped.height * SCALE)), Image.Resampling.NEAREST)
        target_dimensions = parse_pair(row["proposed_target_dimensions"])
        runtime = Image.new("RGBA", target_dimensions, (0, 0, 0, 0))
        runtime.alpha_composite(normalized, (PADDING, PADDING))

        alpha_pixels_binarized = make_binary_alpha(runtime)
        shadow_pixels_removed = remove_presentation_shadow(runtime)
        halo_pixels_cleaned = clean_bright_halo(runtime)
        fragment_count, fragment_pixels = remove_tiny_fragments(runtime)
        transparent_rgb_pixels_zeroed = sanitize_transparency(runtime)
        post_cleanup = audit(runtime)
        for key in ("partial_alpha_pixels", "transparent_rgb_pixels", "canvas_edge_pixels", "bright_boundary_halo_candidates", "detached_components_at_or_below_2_pixels"):
            if post_cleanup[key] != 0:
                raise RuntimeError(f"Post-cleanup audit failed for {spec.asset_id}: {key}={post_cleanup[key]}")

        output_path = RUNTIME_ROOT / spec.runtime_name
        runtime.save(output_path, format="PNG", compress_level=9)
        records[spec.short_id] = {
            "catalog_asset_id": spec.asset_id,
            "catalog_status": row["status"],
            "selection_status": "residential_selected",
            "approval_state": "approved_for_residential_runtime_v1_integration",
            "rights_status": row["rights_status"],
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
            "scene_path": "scenes/world/caden/Residential.tscn",
            "scene_node_path": spec.scene_node_path,
            "world_position_xy": list(spec.world_position),
            "collision": spec.collision,
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
        "schema": "caden-residential-runtime-manifest-v1",
        "generator": "tools/art/prepare_caden_residential_runtime_v1.py",
        "generator_sha256": sha256(Path(__file__)),
        "source_package": "Caden Mega Asset Library v1.1",
        "source_package_location_policy": "staged outside res://; only selected cleaned runtime PNGs are imported",
        "catalog_rows_verified": 222,
        "scope": "Seven explicitly approved Residential candidates only.",
        "gate_state": "residential_runtime_v1_pending_in_engine_visual_approval",
        "provenance_and_licensing": {"rights_status": "project_internal_rights_unverified", "distribution_status": "do_not_publish_until_rights_are_verified"},
        "preserved_rejections": {"residential_and_townwide_building_masters": 24, "mega_set": ["01", "02"]},
        "assets": records,
    }
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"runtime_assets={len(records)}")
    print(f"manifest={MANIFEST_PATH.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
