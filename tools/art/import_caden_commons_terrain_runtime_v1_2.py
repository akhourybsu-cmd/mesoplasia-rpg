#!/usr/bin/env python3
"""Verify and import the approved Commons terrain v1.2 pilot runtime."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
OUTPUT_PATH = ROOT / "assets/environments/caden/commons/terrain/commons_terrain_runtime_v1_2.png"
MANIFEST_PATH = ROOT / "assets/environments/caden/commons/terrain/commons_terrain_runtime_v1_2.json"
PRIOR_PATH = ROOT / "assets/environments/caden/commons/terrain/commons_terrain_runtime_v1.png"
PRIOR_MANIFEST_PATH = ROOT / "assets/environments/caden/commons/terrain/commons_terrain_runtime_v1.json"
EXPECTED_REVIEW_ZIP_SHA256 = "e05c902b0cd8b940c27638f94f634f4b7f631551d6f433d3e5a36ca0eacfe903"
EXPECTED_ACTIVE_REVIEW_ZIP_SHA256 = "6fc8c71f7217e05e14a26a40daf9746e6da3850359d3ca6fae60757b8cfffe92"
EXPECTED_CANDIDATE_SHA256 = "d3e07ee474f9ebc6f40df4d5074f82768e597ac25da8c79efbc5c0f6ebc27c48"


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
        raise RuntimeError(f"Expected JSON object: {path}")
    return payload


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8", newline="\n")


def verify_review(review_root: Path) -> tuple[dict, str]:
    resolved = review_root.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError("The approved Commons terrain review must remain outside res://.")
    lines = [line for line in (resolved / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != 28:
        raise RuntimeError(f"Expected 28 Commons review checksums, found {len(lines)}.")
    for line in lines:
        digest, relative = line.split("  ", 1)
        path = resolved / Path(relative)
        if not path.is_file() or sha256(path) != digest:
            raise RuntimeError(f"Commons review checksum mismatch: {relative}")
    zip_path = resolved.with_suffix(".zip")
    if not zip_path.is_file() or sha256(zip_path) != EXPECTED_REVIEW_ZIP_SHA256:
        raise RuntimeError("Commons review ZIP identity mismatch.")
    package_manifest_path = resolved / "metadata/package_manifest_v1_2.json"
    package_manifest = load_json(package_manifest_path)
    if package_manifest.get("gate_state") != "inactive_commons_terrain_comparison_pending_visual_approval":
        raise RuntimeError("Unexpected Commons review gate state.")
    if package_manifest.get("candidate_runtime_sha256") != EXPECTED_CANDIDATE_SHA256:
        raise RuntimeError("Commons review candidate identity mismatch.")
    prep_manifest = load_json(resolved / "metadata/commons_terrain_preparation_manifest_v1_2.json")
    return prep_manifest, sha256(package_manifest_path)


def verify_active_review(review_root: Path) -> str:
    resolved = review_root.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError("The active Commons terrain review must remain outside res://.")
    lines = [line for line in (resolved / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != 30:
        raise RuntimeError(f"Expected 30 active Commons review checksums, found {len(lines)}.")
    for line in lines:
        digest, relative = line.split("  ", 1)
        path = resolved / Path(relative)
        if not path.is_file() or sha256(path) != digest:
            raise RuntimeError(f"Active Commons review checksum mismatch: {relative}")
    zip_path = resolved.with_suffix(".zip")
    if not zip_path.is_file() or sha256(zip_path) != EXPECTED_ACTIVE_REVIEW_ZIP_SHA256:
        raise RuntimeError("Active Commons review ZIP identity mismatch.")
    package_manifest_path = resolved / "metadata/package_manifest_v1_2.json"
    package_manifest = load_json(package_manifest_path)
    if package_manifest.get("gate_state") != "commons_terrain_runtime_v1_2_active_pilot_pending_visual_approval":
        raise RuntimeError("Unexpected active Commons review gate state.")
    if package_manifest.get("active_runtime_sha256") != EXPECTED_CANDIDATE_SHA256:
        raise RuntimeError("Active Commons review runtime identity mismatch.")
    return sha256(package_manifest_path)


def audit_runtime(path: Path) -> dict[str, object]:
    with Image.open(path) as source:
        image = source.convert("RGBA")
    pixels = list(image.get_flattened_data())
    alpha_values = sorted({pixel[3] for pixel in pixels})
    partial_alpha = sum(1 for pixel in pixels if pixel[3] not in (0, 255))
    transparent_rgb = sum(1 for red, green, blue, alpha in pixels if alpha == 0 and (red or green or blue))
    if image.size != (1024, 704) or alpha_values != [255] or partial_alpha or transparent_rgb:
        raise RuntimeError("Commons terrain runtime pixel audit failed.")
    return {
        "dimensions": list(image.size), "fully_opaque": True, "alpha_values": alpha_values,
        "partial_alpha_pixels": partial_alpha, "transparent_rgb_pixels": transparent_rgb,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("review_root", type=Path)
    parser.add_argument("active_review_root", type=Path)
    args = parser.parse_args()
    review_root = args.review_root.resolve()
    active_review_root = args.active_review_root.resolve()
    prep_manifest, package_manifest_sha256 = verify_review(review_root)
    active_package_manifest_sha256 = verify_active_review(active_review_root)
    candidate_record = prep_manifest.get("candidate", {})
    source_path = review_root / candidate_record.get("runtime_path", "")
    if not source_path.is_file() or sha256(source_path) != EXPECTED_CANDIDATE_SHA256:
        raise RuntimeError("Approved Commons terrain candidate hash mismatch.")
    prior_manifest = load_json(PRIOR_MANIFEST_PATH)
    if sha256(PRIOR_PATH) != prior_manifest.get("output_sha256"):
        raise RuntimeError("Prior Commons terrain identity mismatch.")
    if candidate_record.get("route_contract") != prior_manifest.get("route_contract"):
        raise RuntimeError("Commons candidate route contract changed.")

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_path, OUTPUT_PATH)
    if sha256(OUTPUT_PATH) != EXPECTED_CANDIDATE_SHA256:
        raise RuntimeError("Imported Commons terrain bytes changed during copy.")
    audit = audit_runtime(OUTPUT_PATH)
    manifest = {
        "schema": "caden-commons-terrain-runtime-v1.2",
        "generator": SCRIPT_PATH.relative_to(ROOT).as_posix(),
        "generator_sha256": sha256(SCRIPT_PATH),
        "gate_state": "commons_terrain_runtime_v1_2_visual_approved",
        "approval": {
            "recorded_date": "2026-08-30",
            "decision": "approved_active_commons_terrain_runtime_v1_2",
            "pilot_authorization_package": review_root.name + ".zip",
            "pilot_authorization_package_sha256": EXPECTED_REVIEW_ZIP_SHA256,
            "pilot_authorization_manifest_sha256": package_manifest_sha256,
            "active_evidence_package": active_review_root.name + ".zip",
            "active_evidence_package_sha256": EXPECTED_ACTIVE_REVIEW_ZIP_SHA256,
            "active_evidence_manifest_sha256": active_package_manifest_sha256,
        },
        "source_policy": "Source master, harmonized atlas, preparation files, and review materials remain outside res://; only the approved composed runtime PNG is imported.",
        "source": {
            "original_master_filename": "caden_grass_stone_terrain_master.png",
            "original_master_sha256": "eaf2dbf53d955e8e92a71c7b04e63b38bcc66710a7e28a06dbfe3956d354508e",
            "approved_harmonized_atlas_sha256": candidate_record["source_atlas_sha256"],
            "external_candidate_sha256": EXPECTED_CANDIDATE_SHA256,
        },
        "output_path": OUTPUT_PATH.relative_to(ROOT).as_posix(),
        "output_sha256": sha256(OUTPUT_PATH),
        "dimensions": audit["dimensions"],
        "cell_size": candidate_record["cell_size"],
        "grid": candidate_record["grid_size"],
        "variant_counts": candidate_record["variant_counts"],
        "composed_cell_counts": candidate_record["composed_cell_counts"],
        "route_footprint_cells": candidate_record["route_footprint_cells"],
        "route_contract": candidate_record["route_contract"],
        "quiet_green_pixels_xywh": candidate_record["quiet_green_pixels_xywh"],
        "import_scale": 1.0,
        "filter": "nearest_neighbor_disabled_filtering",
        "collision": "none; authoritative Commons collision remains separate and unchanged",
        "pixel_audit": audit,
        "preserved_contracts": prep_manifest["protected_contracts"],
        "provenance_and_licensing": prep_manifest["provenance_and_licensing"],
        "rollback": {
            "previous_runtime_path": prior_manifest["output_path"],
            "previous_runtime_sha256": prior_manifest["output_sha256"],
            "instruction": "Restore the single Commons TerrainRuntime ext-resource path to the previous runtime path; do not change route or collision nodes.",
        },
    }
    write_json(MANIFEST_PATH, manifest)
    print(f"runtime={OUTPUT_PATH}")
    print(f"manifest={MANIFEST_PATH}")
    print(f"runtime_sha256={sha256(OUTPUT_PATH)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
