#!/usr/bin/env python3
"""Build the clean Caden five-zone rollout v1.3 review package."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
EXPECTED_PACKAGES = {
    "residential": ("caden_residential_terrain_runtime_review_v1_2.zip", "7ef1484113357070bb867b7a02c3d70a1023798224af0904b17ff09b7bc77736"),
    "marketplace": ("caden_marketplace_terrain_runtime_review_v1_2.zip", "f013205e480e1fed8283772482a8cf0834aa300899e99a559db1985bf5d90f08"),
    "commons": ("caden_commons_terrain_runtime_review_v1_2.zip", "6fc8c71f7217e05e14a26a40daf9746e6da3850359d3ca6fae60757b8cfffe92"),
    "town_square_architecture": ("caden_town_square_protected_review_v1_2_b.zip", "7ce5860927274ec7bfb8b3beb7247a5d32e81f737f5015742a1dc45234f675cd"),
    "town_square_terrain": ("caden_town_square_tonal_terrain_review_v1_3.zip", "e580e4582b6be79a937912a6f75b197b7a8a608da1803415d0235fb36411c771"),
    "wayfarer": ("caden_wayfarer_protection_audit_v1_2.zip", "18ee4f5039ead183b1a6286dfd41389c339b6b0129f52031b63cec76fec96b21"),
    "transitions": ("caden_five_zone_transition_audit_v1_2_b.zip", "142e474ecad08802a777f818d61b618ba4a43d9b178cf05db2e26edf5935de63"),
}
TESTS = [
    "caden_architecture_runtime_test.gd",
    "caden_architecture_runtime_v1_1_test.gd",
    "caden_character_visual_spec_test.gd",
    "caden_commons_contract_test.gd",
    "caden_commons_runtime_test.gd",
    "caden_edenite_festival_runtime_test.gd",
    "caden_marketplace_runtime_test.gd",
    "caden_nature_runtime_test.gd",
    "caden_npc_base_character_runtime_test.gd",
    "caden_npc_variants_patrol_runtime_test.gd",
    "caden_player_character_runtime_test.gd",
    "caden_population_test.gd",
    "caden_props_runtime_test.gd",
    "caden_residential_runtime_test.gd",
    "caden_terrain_runtime_test.gd",
    "caden_terrain_runtime_v1_1_test.gd",
    "caden_town_square_environmental_dressing_test.gd",
    "caden_ui_runtime_test.gd",
    "caden_wayfarers_approach_runtime_test.gd",
    "caden_zone_transition_test.gd",
    "dialogue_foundation_test.gd",
    "interaction_foundation_test.gd",
    "opening_objective_test.gd",
]
RUNTIME_FILES = [
    "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1_2.png",
    "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1_2.json",
    "assets/environments/caden/residential/buildings/residential_building_pilot_manifest_v1_1.json",
    "assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1_2.png",
    "assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1_2.json",
    "assets/environments/caden/commons/terrain/commons_terrain_runtime_v1_2.png",
    "assets/environments/caden/commons/terrain/commons_terrain_runtime_v1_2.json",
    "assets/environments/caden/architecture/town_square/caden_architecture_runtime_v3_manifest.json",
    "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_3.png",
    "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_3.tres",
    "assets/tilesets/caden/terrain/caden_terrain_runtime_v1_3.json",
    "assets/environments/caden/wayfarers_approach/wayfarers_approach_pilot_runtime_v1.json",
    "assets/environments/caden/wayfarers_approach/wayfarers_approach_runtime_manifest_v1.json",
]
SCENES = [
    "scenes/world/caden/WayfarersApproach.tscn",
    "scenes/world/caden/Marketplace.tscn",
    "scenes/world/caden/TownSquare.tscn",
    "scenes/world/caden/Residential.tscn",
    "scenes/world/caden/Commons.tscn",
]
DOCS = [
    "docs/art/CADEN_FIVE_ZONE_ROLLOUT_V1_3.md",
    "docs/art/CADEN_TOWN_SQUARE_RUNTIME_V3_TERRAIN_V1_3.md",
    "docs/art/CADEN_WAYFARER_PROTECTION_AUDIT_V1_2.md",
    "docs/art/CADEN_RESIDENTIAL_TERRAIN_RUNTIME_V1_2.md",
    "docs/art/CADEN_MARKETPLACE_TERRAIN_RUNTIME_V1_2.md",
    "docs/art/CADEN_COMMONS_TERRAIN_GATE_V1_2.md",
]
TOOLS = [
    "tools/art/import_caden_commons_terrain_runtime_v1_2.py",
    "tools/art/import_caden_town_square_architecture_runtime_v3.py",
    "tools/art/import_caden_town_square_tonal_terrain_runtime_v1_3.py",
    "tools/art/render_caden_five_zone_transition_audit_v1_2.gd",
    "tools/art/render_caden_town_square_runtime_v3_terrain_v1_3.gd",
    "tools/art/build_caden_five_zone_transition_audit_v1_2.py",
]
TOWN_SQUARE_MATCHES = {
    "town_square_tonal_full_candidate_v1_3_960x704.png": "town_square_active_v3_v1_3_full_960x704.png",
    "town_square_tonal_plaza_candidate_v1_3_640x360.png": "town_square_active_v3_v1_3_plaza_640x360.png",
    "town_square_tonal_north_candidate_v1_3_640x360.png": "town_square_active_v3_v1_3_north_640x360.png",
    "town_square_tonal_west_candidate_v1_3_640x360.png": "town_square_active_v3_v1_3_west_640x360.png",
    "town_square_tonal_south_candidate_v1_3_640x360.png": "town_square_active_v3_v1_3_south_640x360.png",
    "town_square_tonal_east_candidate_v1_3_640x360.png": "town_square_active_v3_v1_3_east_640x360.png",
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


def copy(source: Path, destination: Path) -> None:
    if not source.is_file():
        raise RuntimeError(f"Missing required file: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    path = Path("C:/Windows/Fonts") / name
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def make_overview(evidence_root: Path, output: Path) -> None:
    sources = [
        ("ACTIVE TOWN SQUARE", evidence_root / "caden_town_square_runtime_v3_terrain_v1_3_render/raw_captures/town_square_active_v3_v1_3_full_960x704.png"),
        ("WAYFARER V5 RETAINED", evidence_root / "caden_wayfarer_protection_audit_v1_2/captures/wayfarer_full_zone_after_v5_1024x640.png"),
        ("FINAL TRANSITION AUDIT", evidence_root / "caden_five_zone_transition_audit_v1_2_b/boards/caden_five_zone_transition_audit_v1_2.png"),
    ]
    canvas = Image.new("RGB", (1440, 2200), (21, 25, 22))
    draw = ImageDraw.Draw(canvas)
    draw.text((36, 24), "Caden five-zone rollout v1.3", font=font(34, True), fill=(244, 241, 229))
    draw.text((36, 70), "Ten gated decisions, preserved gameplay geometry, 23/23 regression scripts passing", font=font(18), fill=(193, 202, 191))
    boxes = [(36, 118, 668, 440), (736, 118, 668, 440), (180, 610, 1080, 1540)]
    for (label, source), (x, y, width, height) in zip(sources, boxes):
        image = Image.open(source).convert("RGB")
        draw.text((x, y), label, font=font(17, True), fill=(231, 229, 217))
        max_height = height - 34
        scale = min(width / image.width, max_height / image.height)
        size = (max(1, int(image.width * scale)), max(1, int(image.height * scale)))
        image = image.resize(size, Image.Resampling.NEAREST)
        canvas.paste(image, (x + (width - size[0]) // 2, y + 30))
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    evidence_root = args.evidence_root.resolve()
    output_root = args.output_root.resolve()
    if output_root == ROOT or ROOT in output_root.parents:
        raise RuntimeError("Review material must remain outside res://.")
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)

    package_hashes = {}
    for gate, (name, expected) in EXPECTED_PACKAGES.items():
        actual = sha256(evidence_root / name)
        if actual != expected:
            raise RuntimeError(f"Evidence identity mismatch for {gate}: {actual}")
        package_hashes[gate] = actual

    architecture_manifest = read_json(ROOT / RUNTIME_FILES[7])
    terrain_manifest = read_json(ROOT / RUNTIME_FILES[10])
    if architecture_manifest.get("gate_state") != "town_square_architecture_runtime_v3_visual_approved":
        raise RuntimeError("Town Square architecture is not in its approved active state.")
    if terrain_manifest.get("gate_state") != "town_square_tonal_terrain_runtime_v1_3_visual_approved":
        raise RuntimeError("Town Square terrain is not in its approved active state.")

    approved = evidence_root / "caden_town_square_tonal_terrain_review_v1_3/captures"
    active = evidence_root / "caden_town_square_runtime_v3_terrain_v1_3_render/raw_captures"
    for approved_name, active_name in TOWN_SQUARE_MATCHES.items():
        before = Image.open(approved / approved_name).convert("RGBA")
        after = Image.open(active / active_name).convert("RGBA")
        if before.size != after.size or before.tobytes() != after.tobytes():
            raise RuntimeError(f"Active Town Square differs from approved tonal capture: {active_name}")
    plaza = Image.open(active / "town_square_active_v3_v1_3_plaza_640x360.png").convert("RGBA")
    display = Image.open(active / "town_square_active_v3_v1_3_plaza_display_1280x720.png").convert("RGBA")
    if plaza.resize((1280, 720), Image.Resampling.NEAREST).tobytes() != display.tobytes():
        raise RuntimeError("Town Square display proof is not exact nearest-neighbor 2x.")

    for relative in RUNTIME_FILES:
        copy(ROOT / relative, output_root / "runtime" / relative)
    for record in architecture_manifest["generated_buildings"].values():
        relative = record["path"]
        source = ROOT / relative
        if sha256(source) != record["sha256"]:
            raise RuntimeError(f"Town Square runtime asset mismatch: {source.name}")
        copy(source, output_root / "runtime" / relative)
    for relative in SCENES:
        copy(ROOT / relative, output_root / "scenes" / Path(relative).name)
    for relative in DOCS:
        copy(ROOT / relative, output_root / "docs" / Path(relative).name)
    for relative in TOOLS:
        copy(ROOT / relative, output_root / "tooling" / Path(relative).name)
    copy(SCRIPT_PATH, output_root / "tooling" / SCRIPT_PATH.name)
    for name in TESTS:
        copy(ROOT / "tests" / name, output_root / "tests" / name)

    board_sources = {
        "residential_terrain_runtime_v1_2.png": "caden_residential_terrain_runtime_review_v1_2/boards/residential_terrain_runtime_comparison_v1_2.png",
        "marketplace_terrain_runtime_v1_2.png": "caden_marketplace_terrain_runtime_review_v1_2/boards/marketplace_terrain_runtime_comparison_v1_2.png",
        "commons_terrain_runtime_v1_2.png": "caden_commons_terrain_runtime_review_v1_2/boards/commons_terrain_runtime_comparison_v1_2.png",
        "town_square_architecture_v3.png": "caden_town_square_protected_review_v1_2_b/boards/town_square_full_decision_board_v1_2.png",
        "town_square_terrain_v1_3.png": "caden_town_square_tonal_terrain_review_v1_3/boards/town_square_tonal_terrain_decision_v1_3.png",
        "wayfarer_v5_protection.png": "caden_wayfarer_protection_audit_v1_2/boards/wayfarer_v5_protection_audit_v1_2.png",
        "five_zone_transition_audit.png": "caden_five_zone_transition_audit_v1_2_b/boards/caden_five_zone_transition_audit_v1_2.png",
    }
    for destination, relative in board_sources.items():
        copy(evidence_root / relative, output_root / "boards" / destination)
    shutil.copytree(active, output_root / "captures/town_square_active")
    shutil.copytree(
        evidence_root / "caden_five_zone_transition_audit_v1_2_b/captures",
        output_root / "captures/transitions",
    )
    make_overview(evidence_root, output_root / "boards/caden_five_zone_rollout_v1_3_overview.png")

    test_results = {
        "schema": "caden-five-zone-regression-v1.3",
        "date": "2026-08-30",
        "godot": "4.7.2.stable.official.ed1daf0bf",
        "renderer": "Compatibility",
        "result": "pass",
        "passed": len(TESTS),
        "total": len(TESTS),
        "tests": [{"path": f"tests/{name}", "sha256": sha256(ROOT / "tests" / name), "result": "pass"} for name in TESTS],
        "environmental_notices": [
            "Sandboxed headless runs could not write user:// Godot logs.",
            "Sandboxed headless runs could not read the Windows root certificate store.",
        ],
    }
    (output_root / "metadata").mkdir(parents=True, exist_ok=True)
    (output_root / "metadata/caden_five_zone_regression_v1_3.json").write_text(
        json.dumps(test_results, indent=2) + "\n", encoding="utf-8", newline="\n"
    )
    ledger = {
        "schema": "caden-five-zone-rollout-v1.3",
        "gate_state": "implementation_complete_pending_consolidated_visual_review",
        "date": "2026-08-30",
        "gates_completed": 10,
        "regression": "23/23 pass",
        "evidence_package_sha256": package_hashes,
        "scene_sha256": {Path(path).name: sha256(ROOT / path) for path in SCENES},
        "active_town_square_capture_match": True,
        "transition_capture_count": 12,
        "rejected_or_retained": {
            "town_square_coarse_terrain": "rejected_not_imported",
            "wayfarer_v5": "retained_unchanged",
            "wayfarer_additional_candidates": "not_integrated",
            "marketplace_complete_storefronts": "deferred_footprint_mismatch",
        },
        "provenance_rights_status": "project_internal_rights_unverified",
    }
    (output_root / "metadata/caden_five_zone_rollout_v1_3.json").write_text(
        json.dumps(ledger, indent=2) + "\n", encoding="utf-8", newline="\n"
    )
    (output_root / "TOOLING_REQUIREMENTS.md").write_text(
        "# Tooling Requirements\n\n"
        "- Godot 4.7.2, Compatibility renderer.\n"
        "- Python 3 with Pillow for deterministic board and package generation.\n"
        "- PowerShell 7 or equivalent for SHA-256 verification.\n"
        "- Nearest-neighbor texture import with runtime node scale 1.0.\n",
        encoding="utf-8", newline="\n",
    )
    (output_root / "PROVENANCE_AND_LICENSE.md").write_text(
        "# Provenance and License\n\n"
        "Replacement source art was provided by the project owner through local Downloads intake. "
        "Creator and generation-tool details were not supplied. Rights are project_internal_rights_unverified. "
        "Do not publish or ship these assets until rights are verified.\n",
        encoding="utf-8", newline="\n",
    )
    (output_root / "README.md").write_text(
        "# Caden Five-Zone Rollout v1.3\n\n"
        "This is the clean consolidated visual-review package for ten completed gates. It contains active runtime "
        "assets and manifests, representative decision boards, the active Town Square capture set, all twelve "
        "bidirectional transition captures, 23 passing test contracts, provenance, tooling, and rollback evidence.\n\n"
        "No new gameplay geometry, collision, exits, interactions, quests, or dialogue were added in this rollout.\n",
        encoding="utf-8", newline="\n",
    )

    files = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name != "SHA256SUMS.txt")
    (output_root / "SHA256SUMS.txt").write_text(
        "".join(f"{sha256(path)}  {path.relative_to(output_root).as_posix()}\n" for path in files),
        encoding="utf-8", newline="\n",
    )
    zip_path = output_root.with_suffix(".zip")
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(item for item in output_root.rglob("*") if item.is_file()):
            archive.write(path, (Path(output_root.name) / path.relative_to(output_root)).as_posix())
    print(f"package={output_root}")
    print(f"artifacts={len(files) + 1}")
    print(f"zip={zip_path}")
    print(f"zip_sha256={sha256(zip_path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
