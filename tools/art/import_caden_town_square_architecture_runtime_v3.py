#!/usr/bin/env python3
"""Import the visually approved Town Square architecture Runtime v3 assets."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
OUTPUT_ROOT = ROOT / "assets/environments/caden/architecture/town_square"
MANIFEST_PATH = OUTPUT_ROOT / "caden_architecture_runtime_v3_manifest.json"
BASELINE_MANIFEST_PATH = OUTPUT_ROOT / "caden_architecture_runtime_v2_manifest.json"
SCENE_PATH = ROOT / "scenes/world/caden/TownSquare.tscn"
EXPECTED_REVIEW_ZIP_SHA256 = "7ce5860927274ec7bfb8b3beb7247a5d32e81f737f5015742a1dc45234f675cd"
EXPECTED_REVIEW_CHECKSUMS = 40
SLOT_FILENAMES = {
    "northwest": "town_square_building_northwest_v3.png",
    "southwest": "town_square_building_southwest_v3.png",
    "northeast": "town_square_building_northeast_v3.png",
    "southeast": "town_square_building_southeast_v3.png",
    "south": "town_square_building_south_v3.png",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise RuntimeError(f"Expected JSON object: {path}")
    return value


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def verify_external_package(review_root: Path) -> dict:
    resolved = review_root.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError("Town Square review package must remain outside res://.")
    sums_path = resolved / "SHA256SUMS.txt"
    lines = [line for line in sums_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != EXPECTED_REVIEW_CHECKSUMS:
        raise RuntimeError(f"Expected {EXPECTED_REVIEW_CHECKSUMS} review checksums, found {len(lines)}.")
    for line in lines:
        digest, relative = line.split("  ", 1)
        artifact = resolved / Path(relative)
        if not artifact.is_file() or sha256(artifact) != digest:
            raise RuntimeError(f"Town Square review checksum mismatch: {relative}")
    zip_path = resolved.with_suffix(".zip")
    if not zip_path.is_file() or sha256(zip_path) != EXPECTED_REVIEW_ZIP_SHA256:
        raise RuntimeError("Town Square review ZIP identity mismatch.")
    decision = load_json(resolved / "metadata/town_square_protected_decision_v1_2.json")
    if decision.get("gate_state") != "approved_architecture_runtime_v3_terrain_retained_v1_1":
        raise RuntimeError("Town Square review does not authorize Runtime v3 architecture.")
    if decision.get("terrain_decision") != "retain_active_runtime_v1_1":
        raise RuntimeError("Town Square terrain decision changed.")
    return decision


def audit_png(path: Path) -> dict[str, object]:
    with Image.open(path) as source:
        image = source.convert("RGBA")
    pixels = list(image.get_flattened_data())
    alpha_values = sorted({pixel[3] for pixel in pixels})
    if alpha_values != [0, 255]:
        raise RuntimeError(f"Runtime PNG alpha policy failed: {path.name}")
    transparent_rgb = sum(1 for red, green, blue, alpha in pixels if alpha == 0 and (red or green or blue))
    edge_pixels = 0
    for x in range(image.width):
        edge_pixels += int(image.getpixel((x, 0))[3] != 0) + int(image.getpixel((x, image.height - 1))[3] != 0)
    for y in range(1, image.height - 1):
        edge_pixels += int(image.getpixel((0, y))[3] != 0) + int(image.getpixel((image.width - 1, y))[3] != 0)
    if transparent_rgb or edge_pixels:
        raise RuntimeError(f"Runtime PNG fringe or edge audit failed: {path.name}")
    return {
        "dimensions": list(image.size),
        "alpha_values": alpha_values,
        "partial_alpha_pixels": 0,
        "transparent_rgb_pixels": transparent_rgb,
        "canvas_edge_pixels": edge_pixels,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("review_root", type=Path)
    args = parser.parse_args()
    review_root = args.review_root.resolve()
    decision = verify_external_package(review_root)
    prep = load_json(review_root / "metadata/town_square_protected_preparation_manifest_v1_2.json")
    baseline = load_json(BASELINE_MANIFEST_PATH)
    baseline_buildings = baseline.get("generated_buildings", {})
    if len(baseline_buildings) != 5:
        raise RuntimeError("Town Square Runtime v2 rollback baseline changed.")
    if sha256(SCENE_PATH) != prep.get("scene_sha256"):
        raise RuntimeError("Town Square scene changed since the protected comparison.")

    generated: dict[str, dict] = {}
    for record in prep.get("building_candidates", []):
        slot = record["slot"]
        if slot not in SLOT_FILENAMES or slot not in baseline_buildings:
            raise RuntimeError(f"Unexpected Town Square slot: {slot}")
        if decision["building_runtime_sha256"].get(slot) != record["runtime_sha256"]:
            raise RuntimeError(f"Approved candidate identity changed: {slot}")
        source = review_root / record["runtime_path"]
        if sha256(source) != record["runtime_sha256"]:
            raise RuntimeError(f"Approved candidate bytes changed: {slot}")
        destination = OUTPUT_ROOT / SLOT_FILENAMES[slot]
        shutil.copyfile(source, destination)
        if sha256(destination) != record["runtime_sha256"]:
            raise RuntimeError(f"Imported bytes changed: {slot}")
        audit = audit_png(destination)
        collision = record["collision_footprint"]
        runtime_dimensions = record["runtime_dimensions"]
        pivot = record["pivot_xy"]
        sprite_offset_y = collision[1] / 2 - pivot[1] + runtime_dimensions[1] / 2
        generated[slot] = {
            "path": destination.relative_to(ROOT).as_posix(),
            "sha256": sha256(destination),
            "status": "approved_active_runtime_v3",
            "source_id": record["source_id"],
            "source_filename": record["source_filename"],
            "source_sha256": record["source_sha256"],
            "scale_family": record["scale_family"],
            "normalization_factor": record["normalization_factor"],
            "dimensions": runtime_dimensions,
            "pivot_xy": pivot,
            "pivot_basis": record["pivot_basis"],
            "sprite_offset_xy": [0, sprite_offset_y],
            "collision_footprint": collision,
            "scene_center": baseline_buildings[slot]["scene_center"],
            "target_node": record["target_node"],
            "intended_placement": record["visual_role"],
            "cleanup": record["cleanup"],
            "pixel_audit": audit,
        }

    manifest = {
        "schema": "caden-architecture-runtime-v3",
        "gate_state": "town_square_architecture_runtime_v3_visual_approved",
        "approval": {
            "recorded_date": "2026-08-30",
            "decision": "activate_all_five_fixed_footprint_architecture_candidates",
            "review_package": review_root.name + ".zip",
            "review_package_sha256": EXPECTED_REVIEW_ZIP_SHA256,
            "decision_manifest_sha256": sha256(review_root / "metadata/town_square_protected_decision_v1_2.json"),
        },
        "generator": SCRIPT_PATH.relative_to(ROOT).as_posix(),
        "generator_sha256": sha256(SCRIPT_PATH),
        "source_policy": "Source masters, intermediate cleanup, and review material remain outside res://; only five approved runtime PNGs are imported.",
        "concept_authority": "Palette, materials, lighting, architectural language, and density only; signs, emblems, central monument, and exact geometry are non-authoritative.",
        "generated_buildings": generated,
        "protected_contracts": prep["protected_contracts"],
        "provenance_and_licensing": prep["provenance_and_licensing"],
        "terrain_decision": {
            "active_path": "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.tres",
            "status": "retained_unchanged",
            "candidate_sha256": prep["terrain_candidate"]["sha256"],
            "reason": decision["terrain_reason"],
        },
        "rollback": {
            "manifest": BASELINE_MANIFEST_PATH.relative_to(ROOT).as_posix(),
            "manifest_sha256": sha256(BASELINE_MANIFEST_PATH),
            "building_sha256": {slot: value["sha256"] for slot, value in baseline_buildings.items()},
            "instruction": "Restore the five TownSquare ExteriorSprite paths and offsets to Runtime v2; do not change building centers or collisions.",
        },
    }
    write_json(MANIFEST_PATH, manifest)
    print(f"manifest={MANIFEST_PATH}")
    for slot, value in generated.items():
        print(f"{slot}={value['path']} sha256={value['sha256']} offset={value['sprite_offset_xy']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
