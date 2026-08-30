#!/usr/bin/env python3
"""Verify and import the approved Residential building pilot assets."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
RUNTIME_ROOT = ROOT / "assets/environments/caden/residential/buildings/runtime_v1_1"
MANIFEST_PATH = ROOT / "assets/environments/caden/residential/buildings/residential_building_pilot_manifest_v1_1.json"
TERRAIN_MANIFEST_PATH = ROOT / "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.json"
TERRAIN_V1_2_MANIFEST_PATH = ROOT / "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1_2.json"

PLACEMENTS = {
    "Cabin01": {"source_id": "cad_bld_v1_r01_c01", "anchor": [160, 128], "sprite_position": [0, -23], "previous": "assets/environments/caden/architecture/town_square/town_square_building_northwest_v2.png"},
    "Cabin02": {"source_id": "cad_bld_v1_r01_c02", "anchor": [384, 160], "sprite_position": [0, -33], "previous": "assets/environments/caden/architecture/town_square/town_square_building_northeast_v2.png"},
    "Cabin03": {"source_id": "cad_bld_v1_r01_c04", "anchor": [608, 128], "sprite_position": [0, -24], "previous": "assets/environments/caden/architecture/town_square/town_square_building_south_v2.png"},
    "Cabin04": {"source_id": "cad_bld_v1_r01_c06", "anchor": [800, 176], "sprite_position": [0, -21], "previous": "assets/environments/caden/architecture/town_square/town_square_building_southwest_v2.png"},
    "Cabin05": {"source_id": "cad_bld_v1_r02_c02", "anchor": [1024, 128], "sprite_position": [0, -14], "previous": "assets/environments/caden/architecture/town_square/town_square_building_southeast_v2.png"},
    "Cabin06": {"source_id": "cad_bld_v2_r01_c01", "anchor": [160, 592], "sprite_position": [0, -37], "previous": "assets/environments/caden/architecture/town_square/town_square_building_southeast_v2.png"},
    "Cabin07": {"source_id": "cad_bld_v2_r01_c02", "anchor": [400, 624], "sprite_position": [0, -21], "previous": "assets/environments/caden/architecture/town_square/town_square_building_south_v2.png"},
    "Cabin08": {"source_id": "cad_bld_v2_r01_c03", "anchor": [752, 608], "sprite_position": [0, -24], "previous": "assets/environments/caden/architecture/town_square/town_square_building_northeast_v2.png"},
    "Cabin09": {"source_id": "cad_bld_v2_r01_c05", "anchor": [992, 576], "sprite_position": [0, -15], "previous": "assets/environments/caden/architecture/town_square/town_square_building_southwest_v2.png"},
    "Cabin10": {"source_id": "cad_bld_v2_r02_c05", "anchor": [1024, 256], "sprite_position": [0, -10], "previous": "assets/environments/caden/architecture/town_square/town_square_building_south_v2.png"},
}
SUPPORTING_ALIGNMENT_ADJUSTMENTS = (
    {"node": "DomesticSetPieces/LaundryLine", "from_xy": [400, 536], "to_xy": [400, 504], "reason": "Keep the retained laundry composite on grass and visually north of Cabin07's taller roof while preserving its two post collisions and depth behavior."},
    {"node": "DomesticSetPieces/SmallGardenPatch", "from_xy": [752, 536], "to_xy": [752, 504], "reason": "Keep the retained garden composite on grass and visually north of Cabin08's taller roof while preserving its object collision and depth behavior."},
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise RuntimeError(f"Expected a JSON object: {path}")
    return payload


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8", newline="\n")


def verify_external_gate(gate_root: Path) -> tuple[dict, str]:
    resolved = gate_root.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError("The source gate must remain outside the Godot project tree.")
    checksum_path = resolved / "SHA256SUMS.txt"
    if not checksum_path.is_file():
        raise RuntimeError(f"Missing source gate checksum file: {checksum_path}")
    verified = 0
    for line in checksum_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        digest, relative = line.split("  ", 1)
        artifact = resolved / Path(relative.replace("/", str(Path('/'))))
        if not artifact.is_file() or sha256(artifact) != digest:
            raise RuntimeError(f"Source gate checksum mismatch: {relative}")
        verified += 1
    if verified != 47:
        raise RuntimeError(f"Expected 47 checksummed gate artifacts, found {verified}.")

    package_manifest_path = resolved / "metadata/package_manifest_v1_1.json"
    preparation_manifest_path = resolved / "metadata/preparation_manifest_v1_1.json"
    package_manifest = load_json(package_manifest_path)
    preparation_manifest = load_json(preparation_manifest_path)
    if package_manifest.get("candidate_count") != 10 or package_manifest.get("catalog_rows") != 88:
        raise RuntimeError("The source package does not match the approved ten-building, 88-row gate.")
    if preparation_manifest.get("candidate_count") != 10 or preparation_manifest.get("catalog_row_count") != 88:
        raise RuntimeError("The preparation manifest does not match the approved gate.")
    if package_manifest.get("gate_state") != "pending_visual_approval_no_live_scene_changes":
        raise RuntimeError("Unexpected source package gate state.")
    return preparation_manifest, sha256(package_manifest_path)


def audit_runtime_png(path: Path) -> dict[str, int]:
    with Image.open(path) as source:
        image = source.convert("RGBA")
    width, height = image.size
    pixels = list(image.get_flattened_data())
    alpha_values = {pixel[3] for pixel in pixels}
    opaque = {(index % width, index // width) for index, pixel in enumerate(pixels) if pixel[3] == 255}
    edge_pixels = sum(
        1 for x, y in opaque if x == 0 or y == 0 or x == width - 1 or y == height - 1
    )
    transparent_rgb = sum(1 for red, green, blue, alpha in pixels if alpha == 0 and (red or green or blue))
    partial_alpha = sum(1 for pixel in pixels if pixel[3] not in (0, 255))
    if alpha_values != {0, 255} or edge_pixels or transparent_rgb or partial_alpha:
        raise RuntimeError(f"Runtime pixel audit failed: {path}")
    return {
        "alpha_value_count": len(alpha_values),
        "partial_alpha_pixels": partial_alpha,
        "canvas_edge_pixels": edge_pixels,
        "transparent_rgb_pixels": transparent_rgb,
    }


def import_assets(gate_root: Path, preparation_manifest: dict, package_manifest_sha256: str) -> None:
    assignments = preparation_manifest.get("residential_assignments", [])
    source_records = {record["source_id"]: record for record in assignments}
    if set(source_records) != {placement["source_id"] for placement in PLACEMENTS.values()}:
        raise RuntimeError("The approved assignment set changed.")

    RUNTIME_ROOT.mkdir(parents=True, exist_ok=True)
    assets: dict[str, dict] = {}
    for cabin_name, placement in PLACEMENTS.items():
        source_id = placement["source_id"]
        source_record = source_records[source_id]
        source_path = gate_root / source_record["runtime_preview_path"]
        if sha256(source_path) != source_record["runtime_preview_sha256"]:
            raise RuntimeError(f"Approved candidate hash mismatch: {source_id}")
        output_name = f"{source_id}_runtime_v1_1.png"
        output_path = RUNTIME_ROOT / output_name
        shutil.copy2(source_path, output_path)
        output_hash = sha256(output_path)
        if output_hash != source_record["runtime_preview_sha256"]:
            raise RuntimeError(f"Imported file changed during copy: {source_id}")
        audit = audit_runtime_png(output_path)
        dimensions = source_record["runtime_preview_dimensions"]
        pivot = source_record["pivot_xy"]
        structural_contact_y = placement["sprite_position"][1] + pivot[1] - dimensions[1] // 2
        if structural_contact_y != 48:
            raise RuntimeError(f"Structural contact is not aligned to local y=48: {cabin_name}")
        assets[cabin_name] = {
            "source_id": source_id,
            "source_master_filename": source_record["filename"],
            "source_master_sha256": source_record["source_sha256"],
            "source_crop_xyxy": source_record["raw_crop_xyxy"],
            "cleaned_alpha_bounds_in_master_xyxy": source_record["cleaned_alpha_bounds_in_master_xyxy"],
            "scale_family": source_record["scale_family"],
            "normalization_factor": source_record["normalization_factor"],
            "runtime_path": output_path.relative_to(ROOT).as_posix(),
            "runtime_sha256": output_hash,
            "runtime_dimensions": dimensions,
            "import_scale": 1.0,
            "filter": "nearest_neighbor_disabled_filtering",
            "pivot_xy": pivot,
            "pivot_basis": source_record["pivot_basis"],
            "target_node": f"Homes/{cabin_name}/ExteriorSprite",
            "anchor_position_xy": placement["anchor"],
            "sprite_position_xy": placement["sprite_position"],
            "structural_ground_contact_local_xy": [0, structural_contact_y],
            "collision_footprint": {"shape": "RectangleShape2D", "size_xy": [128, 96], "status": "retained_unchanged"},
            "intended_placement": source_record["role"],
            "status": "approved_residential_building_runtime_v1_1",
            "approval_basis": "Gate 0 candidate set approved for the limited pilot; active in-engine comparison approved by user continuation on 2026-08-29",
            "post_cleanup_audit": {**source_record["post_cleanup_audit"], **audit},
            "rollback_previous_texture_path": placement["previous"],
            "rollback_previous_sprite_position_xy": [0, -16],
        }

    terrain_manifest = load_json(TERRAIN_MANIFEST_PATH)
    terrain_path = ROOT / terrain_manifest["output_path"]
    if sha256(terrain_path) != terrain_manifest["output_sha256"]:
        raise RuntimeError("The rollback Residential terrain hash changed.")
    terrain_record = {
        "status": "retained_unchanged_and_replacement_deferred",
        "runtime_path": terrain_manifest["output_path"],
        "runtime_sha256": terrain_manifest["output_sha256"],
        "reason": "Gate 0 terrain candidate remains visually deferred for density, contrast, and repetition.",
    }
    if TERRAIN_V1_2_MANIFEST_PATH.is_file():
        active_terrain_manifest = load_json(TERRAIN_V1_2_MANIFEST_PATH)
        active_terrain_path = ROOT / active_terrain_manifest["output_path"]
        if active_terrain_manifest.get("gate_state") != "residential_terrain_runtime_v1_2_visual_approved" or sha256(active_terrain_path) != active_terrain_manifest.get("output_sha256"):
            raise RuntimeError("Residential terrain v1.2 pilot identity mismatch.")
        terrain_record = {
            "status": "residential_runtime_v1_2_visual_approved",
            "runtime_path": active_terrain_manifest["output_path"],
            "runtime_sha256": active_terrain_manifest["output_sha256"],
            "runtime_manifest": TERRAIN_V1_2_MANIFEST_PATH.relative_to(ROOT).as_posix(),
            "rollback_runtime_path": terrain_manifest["output_path"],
            "rollback_runtime_sha256": terrain_manifest["output_sha256"],
        }
    manifest = {
        "schema": "caden-residential-building-pilot-manifest-v1.1",
        "generator": SCRIPT_PATH.relative_to(ROOT).as_posix(),
        "generator_sha256": sha256(SCRIPT_PATH),
        "gate_state": "residential_building_pilot_v1_1_visual_approved",
        "visual_approval": {
            "recorded_date": "2026-08-29",
            "decision": "approved_continue",
            "evidence_package": "caden_residential_building_pilot_review_v1_1.zip",
            "evidence_package_sha256": "9d404ee67929fb5bade7815014c62b9a6ebc8704b08f6a65ba34fe5bf1bc3363",
        },
        "scope": "Selective replacement of the ten existing Residential Cabin exterior sprites plus two one-tile background set-piece alignment corrections.",
        "source_gate": {
            "absolute_path": str(gate_root.resolve()),
            "package_manifest_sha256": package_manifest_sha256,
            "checksummed_artifacts_verified": 47,
            "catalog_rows_verified": 88,
            "candidate_count_verified": 10,
            "staging_policy": "Source masters and the complete approval gate remain outside res://; only ten approved canonical runtime PNGs are imported.",
        },
        "preserved_contracts": [
            "Residential scene geometry and all ten Cabin anchors",
            "128x96 Cabin collision footprints",
            "Residential terrain, roads, exits, entry markers, selected prop assets and collision shapes, landscaping, NPCs, and dialogue",
            "all non-Residential zones and systems",
        ],
        "terrain": terrain_record,
        "provenance_and_licensing": {
            "provided_by": "project owner via local Downloads intake",
            "creator_or_generation_tool": "not documented in supplied prompt or sidecars",
            "rights_status": "project_internal_rights_unverified",
            "license": "unverified",
            "derivative_permission": "unverified",
            "distribution_status": "do_not_publish_or_ship_until rights are verified",
        },
        "runtime_asset_count": len(assets),
        "assets": assets,
        "supporting_alignment_adjustments": list(SUPPORTING_ALIGNMENT_ADJUSTMENTS),
        "rollback": "Restore each recorded prior texture and Vector2(0, -16); remove only this manifest and the ten runtime_v1_1 PNGs after confirming no remaining references.",
    }
    write_json(MANIFEST_PATH, manifest)
    print(f"Imported {len(assets)} verified Residential building pilot assets.")
    print(f"manifest={MANIFEST_PATH}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("gate_root", type=Path, help="External caden_building_terrain_gate_v1_1 directory")
    args = parser.parse_args()
    gate_root = args.gate_root.resolve()
    preparation_manifest, package_manifest_sha256 = verify_external_gate(gate_root)
    import_assets(gate_root, preparation_manifest, package_manifest_sha256)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
