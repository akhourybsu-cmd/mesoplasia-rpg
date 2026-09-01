#!/usr/bin/env python3
"""Import the four approved zone-identity comparison assets into res://."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
OUTPUT_ROOT = ROOT / "assets/environments/caden/zone_identity/runtime_v1"
EXPECTED_PREPARATION_MANIFEST_SHA256 = "6d8fb8851036b3a8513f0e5f6f78e2c24f4401ffa2bb4990b1a6a9dab0b80660"
IMPORTS = {
    "CAD-COMP-10": {
        "filename": "caden_zone_identity_market_entry_v1.png",
        "zone": "Marketplace",
        "scene": "scenes/world/caden/Marketplace.tscn",
        "node": "ZoneIdentityV1/MarketEntryFrame",
        "position": [448, 608],
    },
    "CAD-COMP-13": {
        "filename": "caden_zone_identity_civic_garden_v1.png",
        "zone": "TownSquare",
        "scene": "scenes/world/caden/TownSquare.tscn",
        "node": "ZoneIdentityV1/CivicGardenEdge",
        "position": [700, 288],
    },
    "CAD-YARD-35": {
        "filename": "caden_zone_identity_domestic_utility_v1.png",
        "zone": "Residential",
        "scene": "scenes/world/caden/Residential.tscn",
        "node": "ZoneIdentityV1/DomesticUtilityYard",
        "position": [320, 592],
    },
    "CAD-LAND-33": {
        "filename": "caden_zone_identity_natural_boundary_v1.png",
        "zone": "Commons",
        "scene": "scenes/world/caden/Commons.tscn",
        "node": "ZoneIdentityV1/NaturalBoundaryMass",
        "position": [160, 576],
    },
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"Expected a JSON object: {path}")
    return value


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("preparation_root", type=Path)
    args = parser.parse_args()
    preparation_root = args.preparation_root.resolve()
    if preparation_root == ROOT or ROOT in preparation_root.parents:
        raise RuntimeError("Preparation root must remain outside res://.")
    preparation_manifest_path = preparation_root / "metadata/caden_zone_identity_gate_v1.json"
    if sha256(preparation_manifest_path) != EXPECTED_PREPARATION_MANIFEST_SHA256:
        raise RuntimeError("Zone-identity preparation manifest identity mismatch.")
    preparation = read_json(preparation_manifest_path)
    if preparation.get("gate_state") != "inactive_candidates_prepared_for_visual_review":
        raise RuntimeError("Zone-identity preparation state is not importable.")
    candidates = preparation.get("candidates", {})
    if set(candidates) != set(IMPORTS):
        raise RuntimeError("Prepared candidate set does not match the limited import set.")

    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    runtime_records: dict[str, dict[str, object]] = {}
    for source_id, placement in IMPORTS.items():
        source_record = candidates[source_id]
        source_path = preparation_root / source_record["runtime_preview_path"]
        if sha256(source_path) != source_record["runtime_preview_sha256"]:
            raise RuntimeError(f"Prepared runtime identity mismatch: {source_id}")
        image = Image.open(source_path).convert("RGBA")
        audit = source_record["pixel_audit"]
        if list(image.size) != audit["dimensions"]:
            raise RuntimeError(f"Prepared runtime dimensions changed: {source_id}")
        if any(audit[key] != 0 for key in ("partial_alpha_pixels", "transparent_rgb_pixels", "canvas_edge_pixels", "boundary_contamination_pixels")):
            raise RuntimeError(f"Prepared runtime no longer passes cleanup: {source_id}")
        destination = OUTPUT_ROOT / placement["filename"]
        shutil.copyfile(source_path, destination)
        if sha256(destination) != source_record["runtime_preview_sha256"]:
            raise RuntimeError(f"Imported runtime identity mismatch: {source_id}")
        record = dict(source_record)
        record.update(
            {
                "runtime_path": destination.relative_to(ROOT).as_posix(),
                "runtime_sha256": sha256(destination),
                "target_scene": placement["scene"],
                "target_node": placement["node"],
                "placement_position_xy": placement["position"],
                "status": "active_limited_zone_identity_comparison",
                "import_scale": 1.0,
                "filter": "nearest_neighbor_disabled_filtering",
            }
        )
        runtime_records[source_id] = record

    manifest = {
        "schema": "caden-zone-identity-runtime-v1",
        "gate_state": "limited_four_asset_in_engine_comparison",
        "preparation_manifest_sha256": EXPECTED_PREPARATION_MANIFEST_SHA256,
        "generator": SCRIPT_PATH.relative_to(ROOT).as_posix(),
        "generator_sha256": sha256(SCRIPT_PATH),
        "runtime_assets": runtime_records,
        "wayfarer_decision": "retain_v5_unchanged_to_preserve_open_rustic_identity",
        "protected_contracts": [
            "all existing buildings, terrain, roads, routes, entries, exits, collision, camera bounds, NPCs, dialogue, and interactions",
            "Town Square reserved center and all four travel corridors",
            "Marketplace central circulation and perimeter openings",
            "Residential road mask and domestic lanes",
            "Commons maintained paths and Quiet Green",
        ],
        "rollback": "Remove the four ZoneIdentityV1 nodes and their four ext_resource references; no prior node or resource requires restoration.",
        "provenance_and_licensing": preparation["provenance_and_licensing"],
    }
    manifest_path = OUTPUT_ROOT / "caden_zone_identity_runtime_v1.json"
    write_json(manifest_path, manifest)
    print(f"output={OUTPUT_ROOT}")
    print(f"assets={len(runtime_records)}")
    print(f"manifest_sha256={sha256(manifest_path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
