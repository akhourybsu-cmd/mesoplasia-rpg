#!/usr/bin/env python3
"""Normalize and audit the approved Caden Commons runtime shortlist."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import csv
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
RUNTIME_ROOT = ROOT / "assets/environments/caden/commons/props/runtime_v1"
MANIFEST_PATH = ROOT / "assets/environments/caden/commons/commons_runtime_manifest_v1.json"
SCALE = 0.1875
PADDING = 2


@dataclass(frozen=True)
class CommonsSpec:
    short_id: str
    asset_id: str
    runtime_name: str
    scene_node_path: str
    world_position: tuple[int, int]
    collision: str
    role: str


SPECS = (
    CommonsSpec("01", "caden_sp_com_01_large_tree_shrubs_master_v1", "large_tree_shrubs_runtime_v1.png", "Greenery/TreeCluster02", (800, 224), "24x18 trunk base", "Quiet Green shade tree anchor"),
    CommonsSpec("04", "caden_sp_com_04_three_tree_grove_master_v1", "three_tree_grove_runtime_v1.png", "Greenery/TreeCluster01", (192, 160), "three 14x12 trunk bases", "northwest maintained grove"),
    CommonsSpec("09", "caden_sp_com_09_wildflower_meadow_master_v1", "wildflower_meadow_runtime_v1.png", "CommonsComposition/WildflowerMeadow", (704, 352), "none; meadow remains walkable", "restrained Quiet Green meadow"),
    CommonsSpec("11", "caden_sp_com_11_rock_shrub_cluster_master_v1", "rock_shrub_cluster_runtime_v1.png", "Greenery/RockCluster", (288, 544), "40x20 central rock base", "southwest natural rock anchor"),
    CommonsSpec("14", "caden_sp_com_14_dense_undergrowth_edge_master_v1", "dense_undergrowth_edge_runtime_v1.png", "CommonsComposition/BoundaryUndergrowth", (896, 624), "56x16 fence and rock base", "southeast planted boundary mass"),
    CommonsSpec("20", "caden_sp_com_20_quiet_bench_rocks_wildflowers_master_v1", "quiet_bench_rocks_wildflowers_runtime_v1.png", "CommonsComposition/QuietRestPocket", (640, 480), "52x14 bench plus 20x18 rock base", "single quiet path-edge rest pocket"),
)


def load_catalog(library_root: Path) -> dict[str, dict[str, str]]:
    with (library_root / "metadata/ASSET_MANIFEST.csv").open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 222:
        raise RuntimeError(f"Expected 222 catalog rows, found {len(rows)}.")
    by_id = {row["asset_id"]: row for row in rows}
    for spec in SPECS:
        row = by_id.get(spec.asset_id)
        if row is None or row["status"] != "candidate":
            raise RuntimeError(f"Approved Commons candidate is missing or ineligible: {spec.asset_id}")
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
    catalog = load_catalog(library_root)
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
            "selection_status": "commons_selected",
            "approval_state": "approved_for_commons_runtime_v1_integration",
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
            "scene_path": "scenes/world/caden/Commons.tscn",
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
        "schema": "caden-commons-runtime-manifest-v1",
        "generator": "tools/art/prepare_caden_commons_runtime_v1.py",
        "generator_sha256": sha256(Path(__file__)),
        "source_package": "Caden Mega Asset Library v1.1",
        "source_package_location_policy": "staged outside res://; only selected cleaned runtime PNGs are imported",
        "catalog_rows_verified": 222,
        "scope": "Six explicitly approved Commons candidates only.",
        "gate_state": "commons_runtime_v1_pending_in_engine_visual_approval",
        "provenance_and_licensing": {"rights_status": "project_internal_rights_unverified", "distribution_status": "do_not_publish_until_rights_are_verified"},
        "preserved_rejections": {"residential_commons_seams": ["a", "b"], "deferred_mega_set": ["01", "02"], "deferred_town_square_commons_seams": ["a", "b"]},
        "assets": records,
    }
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"runtime_assets={len(records)}")
    print(f"manifest={MANIFEST_PATH.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
