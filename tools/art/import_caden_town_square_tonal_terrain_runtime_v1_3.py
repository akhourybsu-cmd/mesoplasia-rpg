#!/usr/bin/env python3
"""Import the approved Town Square tonal Terrain Runtime v1.3."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
OUTPUT_ATLAS = ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_3.png"
OUTPUT_TILESET = ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_3.tres"
OUTPUT_MANIFEST = ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_3.json"
ROLLBACK_ATLAS = ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png"
ROLLBACK_TILESET = ROOT / "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.tres"
ARCHITECTURE_MANIFEST = ROOT / "assets/environments/caden/architecture/town_square/caden_architecture_runtime_v3_manifest.json"
EXPECTED_REVIEW_ZIP_SHA256 = "e580e4582b6be79a937912a6f75b197b7a8a608da1803415d0235fb36411c771"
EXPECTED_REVIEW_CHECKSUMS = 23
EXPECTED_CANDIDATE_SHA256 = "aa290ab82c5f79b90b491d9f67c88d181f320a2078ca97c161d8925cec46b86d"


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


def verify_review(review_root: Path) -> tuple[dict, dict]:
    if review_root == ROOT or ROOT in review_root.parents:
        raise RuntimeError("Town Square tonal review must remain outside res://.")
    lines = [line for line in (review_root / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != EXPECTED_REVIEW_CHECKSUMS:
        raise RuntimeError(f"Expected {EXPECTED_REVIEW_CHECKSUMS} tonal review checksums, found {len(lines)}.")
    for line in lines:
        digest, relative = line.split("  ", 1)
        artifact = review_root / Path(relative)
        if not artifact.is_file() or sha256(artifact) != digest:
            raise RuntimeError(f"Tonal review checksum mismatch: {relative}")
    zip_path = review_root.with_suffix(".zip")
    if not zip_path.is_file() or sha256(zip_path) != EXPECTED_REVIEW_ZIP_SHA256:
        raise RuntimeError("Tonal review ZIP identity mismatch.")
    decision = load_json(review_root / "metadata/town_square_tonal_terrain_decision_v1_3.json")
    prep = load_json(review_root / "metadata/town_square_tonal_terrain_preparation_v1_3.json")
    if decision.get("gate_state") != "approved_town_square_tonal_terrain_runtime_v1_3":
        raise RuntimeError("Tonal terrain review does not authorize Runtime v1.3.")
    if prep.get("candidate_sha256") != EXPECTED_CANDIDATE_SHA256:
        raise RuntimeError("Approved tonal candidate identity changed.")
    return decision, prep


def create_tileset() -> None:
    source = ROLLBACK_TILESET.read_text(encoding="utf-8")
    source = source.replace('[gd_resource type="TileSet" format=3 uid="uid://ffmi8arynxey"]', '[gd_resource type="TileSet" format=3]')
    source = source.replace('[ext_resource type="Texture2D" uid="uid://dg6ee27f7rsju" path="res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png" id="1_atlas"]', '[ext_resource type="Texture2D" path="res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_3.png" id="1_atlas"]')
    source = source.replace("TileSetAtlasSource_caden_terrain_v1_1", "TileSetAtlasSource_caden_terrain_v1_3")
    if "caden_terrain_runtime_v1_1.png" in source or "uid://" in source:
        raise RuntimeError("Unable to create independent Runtime v1.3 TileSet text.")
    OUTPUT_TILESET.write_text(source, encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("review_root", type=Path)
    args = parser.parse_args()
    review_root = args.review_root.resolve()
    decision, prep = verify_review(review_root)
    candidate = review_root / prep["candidate_path"]
    if sha256(candidate) != EXPECTED_CANDIDATE_SHA256:
        raise RuntimeError("Approved tonal candidate bytes changed.")
    with Image.open(candidate) as source:
        image = source.convert("RGBA")
    if image.size != (256, 256):
        raise RuntimeError("Tonal terrain atlas dimensions changed.")
    with Image.open(ROLLBACK_ATLAS) as source:
        rollback = source.convert("RGBA")
    for row in (1, 2, 3):
        bounds = (0, row * 32, 256, (row + 1) * 32)
        if image.crop(bounds).tobytes() != rollback.crop(bounds).tobytes():
            raise RuntimeError("Protected dirt-road rows are not byte-identical.")
    if image.getchannel("A").tobytes() != rollback.getchannel("A").tobytes():
        raise RuntimeError("Runtime v1.3 alpha topology differs from v1.1.")
    shutil.copyfile(candidate, OUTPUT_ATLAS)
    if sha256(OUTPUT_ATLAS) != EXPECTED_CANDIDATE_SHA256:
        raise RuntimeError("Imported tonal atlas bytes changed.")
    create_tileset()
    architecture = load_json(ARCHITECTURE_MANIFEST)
    architecture["terrain_decision"] = {
        "active_path": OUTPUT_TILESET.relative_to(ROOT).as_posix(),
        "active_atlas_sha256": EXPECTED_CANDIDATE_SHA256,
        "status": "approved_active_tonal_runtime_v1_3",
        "authorization_package_sha256": EXPECTED_REVIEW_ZIP_SHA256,
        "coarse_candidate_status": "rejected_not_imported",
        "rollback_path": ROLLBACK_TILESET.relative_to(ROOT).as_posix(),
        "rollback_atlas_sha256": sha256(ROLLBACK_ATLAS),
    }
    write_json(ARCHITECTURE_MANIFEST, architecture)
    manifest = {
        "schema": "caden-terrain-runtime-v1.3",
        "gate_state": "town_square_tonal_terrain_runtime_v1_3_visual_approved",
        "approval": {
            "recorded_date": "2026-08-30",
            "decision": decision["decision"],
            "review_package": review_root.name + ".zip",
            "review_package_sha256": EXPECTED_REVIEW_ZIP_SHA256,
            "decision_manifest_sha256": sha256(review_root / "metadata/town_square_tonal_terrain_decision_v1_3.json"),
        },
        "generator": SCRIPT_PATH.relative_to(ROOT).as_posix(),
        "generator_sha256": sha256(SCRIPT_PATH),
        "atlas_path": OUTPUT_ATLAS.relative_to(ROOT).as_posix(),
        "atlas_sha256": sha256(OUTPUT_ATLAS),
        "tileset_path": OUTPUT_TILESET.relative_to(ROOT).as_posix(),
        "tileset_sha256": sha256(OUTPUT_TILESET),
        "dimensions": [256, 256],
        "cell_size": [32, 32],
        "documented_tile_count": 58,
        "dirt_rows": [1, 2, 3],
        "dirt_rows_status": "byte_identical_to_runtime_v1_1",
        "alpha_topology": "byte_identical_to_runtime_v1_1",
        "tonal_transfer": prep["tonal_transfer"],
        "source_harmonized_atlas_sha256": prep["source_harmonized_atlas_sha256"],
        "collision": "none",
        "import_scale": 1.0,
        "filter": "nearest_neighbor_disabled_filtering",
        "provenance_and_licensing": prep["provenance_and_licensing"],
        "rollback": {
            "atlas_path": ROLLBACK_ATLAS.relative_to(ROOT).as_posix(),
            "atlas_sha256": sha256(ROLLBACK_ATLAS),
            "tileset_path": ROLLBACK_TILESET.relative_to(ROOT).as_posix(),
            "tileset_sha256": sha256(ROLLBACK_TILESET),
            "instruction": "Restore the single TownSquare TileSet ext-resource path to Runtime v1.1; do not change TileMap data or collision.",
        },
    }
    write_json(OUTPUT_MANIFEST, manifest)
    print(f"atlas={OUTPUT_ATLAS}")
    print(f"atlas_sha256={sha256(OUTPUT_ATLAS)}")
    print(f"tileset={OUTPUT_TILESET}")
    print(f"tileset_sha256={sha256(OUTPUT_TILESET)}")
    print(f"manifest={OUTPUT_MANIFEST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
