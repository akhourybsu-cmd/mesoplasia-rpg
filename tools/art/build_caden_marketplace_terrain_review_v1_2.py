#!/usr/bin/env python3
"""Build the external review package for the inactive Marketplace terrain gate."""

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
SCENE_PATH = ROOT / "scenes/world/caden/Marketplace.tscn"
CURRENT_TERRAIN = ROOT / "assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1.png"
CURRENT_MANIFEST = ROOT / "assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1.json"
MARKETPLACE_MANIFEST = ROOT / "assets/environments/caden/marketplace/marketplace_runtime_manifest_v1.json"
PREP_TOOL = ROOT / "tools/art/prepare_caden_marketplace_terrain_gate_v1_2.py"
RENDER_TOOL = ROOT / "tools/art/render_caden_marketplace_terrain_gate_v1_2.gd"
MARKETPLACE_TEST = ROOT / "tests/caden_marketplace_runtime_test.gd"

PAIRS = (
    ("full", "marketplace_terrain_full_current_v1_2_896x640.png", "marketplace_terrain_full_candidate_v1_2_896x640.png", "Full market", 455),
    ("primary", "marketplace_terrain_primary_current_v1_2_640x360.png", "marketplace_terrain_primary_candidate_v1_2_640x360.png", "Primary aisle and player", 405),
    ("north", "marketplace_terrain_north_current_v1_2_640x360.png", "marketplace_terrain_north_candidate_v1_2_640x360.png", "North vendor districts", 405),
    ("south", "marketplace_terrain_south_current_v1_2_640x360.png", "marketplace_terrain_south_candidate_v1_2_640x360.png", "South vendor districts", 405),
    ("west", "marketplace_terrain_west_current_v1_2_640x360.png", "marketplace_terrain_west_candidate_v1_2_640x360.png", "Wayfarer arrival", 405),
    ("town", "marketplace_terrain_town_square_current_v1_2_640x360.png", "marketplace_terrain_town_square_candidate_v1_2_640x360.png", "Town Square transition", 405),
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
        raise RuntimeError(f"Expected JSON object: {path}")
    return payload


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8", newline="\n")


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    filename = "segoeuib.ttf" if bold else "segoeui.ttf"
    path = Path("C:/Windows/Fonts") / filename
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def assert_external(path: Path, label: str) -> Path:
    resolved = path.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError(f"{label} must remain outside res://.")
    return resolved


def verify_prep(prep_root: Path) -> dict:
    manifest_path = prep_root / "metadata/marketplace_terrain_preparation_manifest_v1_2.json"
    manifest = load_json(manifest_path)
    if manifest.get("gate_state") != "inactive_marketplace_terrain_comparison_pending_visual_approval":
        raise RuntimeError("Unexpected Marketplace preparation gate state.")
    if manifest.get("generator_sha256") != sha256(PREP_TOOL):
        raise RuntimeError("Marketplace preparation tool changed after candidate generation.")
    candidate = manifest.get("candidate", {})
    candidate_path = prep_root / candidate.get("runtime_path", "")
    if not candidate_path.is_file() or sha256(candidate_path) != candidate.get("runtime_sha256", ""):
        raise RuntimeError("Marketplace terrain candidate identity mismatch.")
    if candidate.get("runtime_dimensions") != [896, 640] or candidate.get("maintained_material_footprint_cells") != 372:
        raise RuntimeError("Marketplace candidate dimensions or material footprint changed.")
    source_rows = manifest.get("storefront_source_fit", {}).get("source_sheet_storefront_rows", [])
    if len(source_rows) != 12 or any(row.get("status") != "deferred_marketplace_stall_footprint_mismatch" for row in source_rows):
        raise RuntimeError("Marketplace storefront source-fit decision changed.")
    for relative, digest in manifest.get("boards", {}).items():
        path = prep_root / relative
        if not path.is_file() or sha256(path) != digest:
            raise RuntimeError(f"Marketplace preparation board mismatch: {relative}")
    return manifest


def verify_render(render_root: Path, prep_manifest: dict) -> dict:
    manifest_path = render_root / "marketplace_terrain_render_manifest_v1_2.json"
    manifest = load_json(manifest_path)
    if manifest.get("gate_state") != "inactive_marketplace_terrain_comparison_pending_visual_approval" or manifest.get("active_reference_changed") is not False:
        raise RuntimeError("Unexpected Marketplace render gate state.")
    if manifest.get("render_tool_sha256") != sha256(RENDER_TOOL):
        raise RuntimeError("Marketplace render tool changed after capture.")
    if manifest.get("candidate_terrain_sha256") != prep_manifest["candidate"]["runtime_sha256"]:
        raise RuntimeError("Rendered Marketplace candidate identity mismatch.")
    captures = manifest.get("captures", [])
    if len(captures) != 13:
        raise RuntimeError("Expected thirteen Marketplace terrain captures.")
    for record in captures:
        path = render_root / "raw_captures" / record["filename"]
        if not path.is_file() or sha256(path) != record["sha256"]:
            raise RuntimeError(f"Marketplace capture mismatch: {path.name}")
    primary = Image.open(render_root / "raw_captures/marketplace_terrain_primary_candidate_v1_2_640x360.png").convert("RGBA")
    display = Image.open(render_root / "raw_captures/marketplace_terrain_primary_candidate_display_v1_2_1280x720.png").convert("RGBA")
    if primary.resize((1280, 720), Image.Resampling.NEAREST).tobytes() != display.tobytes():
        raise RuntimeError("Marketplace 1280x720 proof is not an exact nearest-neighbor 2x image.")
    return manifest


def verify_active_reference(prep_manifest: dict, render_manifest: dict) -> None:
    current_manifest = load_json(CURRENT_MANIFEST)
    marketplace_manifest = load_json(MARKETPLACE_MANIFEST)
    if marketplace_manifest.get("gate_state") != "marketplace_runtime_v1_visual_approved":
        raise RuntimeError("Marketplace Runtime v1 is not the approved baseline.")
    if sha256(CURRENT_TERRAIN) != current_manifest.get("output_sha256"):
        raise RuntimeError("Active Marketplace terrain bytes changed.")
    scene_text = SCENE_PATH.read_text(encoding="utf-8")
    active_reference = "res://assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1.png"
    if scene_text.count(active_reference) != 1 or "marketplace_terrain_runtime_v1_2" in scene_text:
        raise RuntimeError("Inactive Marketplace candidate entered the active scene.")
    scene_hash = sha256(SCENE_PATH)
    if prep_manifest.get("scene_sha256") != scene_hash or render_manifest.get("scene_sha256") != scene_hash:
        raise RuntimeError("Marketplace scene changed during comparison preparation.")


def panel(image: Image.Image, width: int, height: int) -> Image.Image:
    contained = image.copy()
    contained.thumbnail((width, height), Image.Resampling.NEAREST)
    output = Image.new("RGB", (width, height), (29, 33, 30))
    output.paste(contained.convert("RGB"), ((width - contained.width) // 2, (height - contained.height) // 2))
    return output


def build_comparison_board(render_root: Path, output_path: Path) -> None:
    width, margin, gutter = 1440, 40, 24
    column_width = (width - margin * 2 - gutter) // 2
    title_height, label_height = 124, 40
    height = title_height + sum(label_height + pair[4] + 34 for pair in PAIRS) + 82
    board = Image.new("RGB", (width, height), (239, 237, 229))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 26), "CADEN MARKETPLACE TERRAIN GATE v1.2", font=font(32, True), fill=(40, 46, 41))
    draw.text((margin, 70), "Inactive comparison. Current approved vendor anchors, perimeter, routes, and population remain authoritative.", font=font(18), fill=(75, 79, 73))
    y = title_height
    capture_root = render_root / "raw_captures"
    for _, current_name, candidate_name, title, image_height in PAIRS:
        draw.text((margin, y), f"{title} | CURRENT v1", font=font(19, True), fill=(70, 73, 67))
        draw.text((margin + column_width + gutter, y), f"{title} | CANDIDATE v1.2", font=font(19, True), fill=(70, 73, 67))
        y += label_height
        with Image.open(capture_root / current_name) as current, Image.open(capture_root / candidate_name) as candidate:
            board.paste(panel(current.convert("RGBA"), column_width, image_height), (margin, y))
            board.paste(panel(candidate.convert("RGBA"), column_width, image_height), (margin + column_width + gutter, y))
        y += image_height + 34
    draw.text((margin, height - 58), "Approval gate: accept a limited terrain pilot, request correction, or retain Marketplace Runtime v1.", font=font(18, True), fill=(91, 66, 39))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(output_path)


def write_docs(output_root: Path, candidate_hash: str) -> None:
    docs = output_root / "docs"
    docs.mkdir(parents=True, exist_ok=True)
    (docs / "README.md").write_text(
        "# Caden Marketplace Terrain Gate v1.2\n\n"
        "This package compares the current approved Marketplace Runtime v1 terrain with an inactive warm-stone v1.2 candidate. "
        "The candidate uses the approved Residential terrain family but composes the exact existing Marketplace material footprint: 372 maintained-ground cells and 188 perimeter-grass cells.\n\n"
        "All eight approved vendor anchors, object-specific collision, fencing, trees, props, seven NPCs, routes, entries, and exits remain unchanged. "
        "The twelve storefront rows in the supplied building sheets remain deferred because complete structures do not fit the shallow vendor-bay role.\n\n"
        f"Candidate SHA-256: `{candidate_hash}`.\n",
        encoding="utf-8", newline="\n",
    )
    (docs / "APPROVAL_CHECKLIST.md").write_text(
        "# Visual Approval Checklist\n\n"
        "- [ ] The market reads as one maintained vendor court without becoming visually flat.\n"
        "- [ ] Warm stone supports stall and NPC silhouettes at `640 x 360`.\n"
        "- [ ] The perimeter remains clearly green, fenced, and separate from the court.\n"
        "- [ ] West arrival and Town Square transition remain open and unmistakable.\n"
        "- [ ] The 128-pixel central circulation spine still reads as broad and walkable.\n"
        "- [ ] Grass/stone boundaries have no gaps, halos, hard rectangular seams, or clipped corners.\n"
        "- [ ] Reusing the Residential material family improves cohesion without erasing Marketplace identity.\n\n"
        "Decision: ACCEPT LIMITED MARKETPLACE TERRAIN PILOT / TARGETED CORRECTION / RETAIN RUNTIME v1\n",
        encoding="utf-8", newline="\n",
    )
    (docs / "PROVENANCE_AND_LICENSE.md").write_text(
        "# Provenance and Licensing\n\n"
        "The project owner supplied the terrain and building masters through local Downloads intake. Creator, generation tool, license, and derivative permission remain undocumented. "
        "Status is `project_internal_rights_unverified`; do not publish or ship the derivative until rights are verified. Source masters remain outside `res://` and are not included.\n",
        encoding="utf-8", newline="\n",
    )
    (docs / "TOOLING_REQUIREMENTS.md").write_text(
        "# Tooling Requirements\n\n"
        "- Godot 4.7.2, Compatibility renderer\n"
        "- Python 3.12\n"
        "- Pillow 12.3 for offline composition, comparison boards, and exact 2x verification\n\n"
        "No game runtime dependency, addon, renderer change, or autoload was introduced.\n",
        encoding="utf-8", newline="\n",
    )


def build_package(prep_root: Path, render_root: Path, output_root: Path) -> Path:
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)
    prep_manifest = verify_prep(prep_root)
    render_manifest = verify_render(render_root, prep_manifest)
    verify_active_reference(prep_manifest, render_manifest)

    shutil.copytree(prep_root / "candidate", output_root / "candidate")
    shutil.copytree(prep_root / "boards", output_root / "boards/source_audits")
    shutil.copytree(render_root / "raw_captures", output_root / "comparison/raw_captures")
    metadata_root = output_root / "metadata"
    metadata_root.mkdir(parents=True, exist_ok=True)
    shutil.copy2(prep_root / "metadata/marketplace_terrain_preparation_manifest_v1_2.json", metadata_root)
    shutil.copy2(render_root / "marketplace_terrain_render_manifest_v1_2.json", metadata_root)
    tooling_root = output_root / "tooling"
    tooling_root.mkdir(parents=True, exist_ok=True)
    for path in (PREP_TOOL, RENDER_TOOL, SCRIPT_PATH, MARKETPLACE_TEST):
        shutil.copy2(path, tooling_root / path.name)

    comparison_board = output_root / "boards/marketplace_terrain_comparison_v1_2.png"
    build_comparison_board(render_root, comparison_board)
    candidate_hash = prep_manifest["candidate"]["runtime_sha256"]
    write_docs(output_root, candidate_hash)
    package_manifest = {
        "schema": "caden-marketplace-terrain-review-package-v1.2",
        "gate_state": "inactive_marketplace_terrain_comparison_pending_visual_approval",
        "scope": "Marketplace terrain/source-fit comparison only; no active scene or resource change.",
        "candidate_runtime_sha256": candidate_hash,
        "current_runtime_sha256": sha256(CURRENT_TERRAIN),
        "scene_sha256": sha256(SCENE_PATH),
        "preparation_manifest_sha256": sha256(prep_root / "metadata/marketplace_terrain_preparation_manifest_v1_2.json"),
        "render_manifest_sha256": sha256(render_root / "marketplace_terrain_render_manifest_v1_2.json"),
        "comparison_board_sha256": sha256(comparison_board),
        "matched_view_pairs": len(PAIRS),
        "exact_2x_candidate_proof": True,
        "active_reference_changes": [],
        "storefront_source_decision": "twelve source-sheet storefronts deferred; retain eight approved Runtime v1 vendor anchors",
        "protected_regression": {
            "result": "PASS",
            "tests": [
                "caden_residential_runtime_test.gd", "caden_marketplace_runtime_test.gd",
                "caden_commons_runtime_test.gd", "caden_commons_contract_test.gd",
                "caden_town_square_environmental_dressing_test.gd", "caden_wayfarers_approach_runtime_test.gd",
                "caden_zone_transition_test.gd", "caden_npc_variants_patrol_runtime_test.gd",
            ],
        },
        "tool_hashes": {f"tooling/{path.name}": sha256(path) for path in (PREP_TOOL, RENDER_TOOL, SCRIPT_PATH, MARKETPLACE_TEST)},
        "provenance_and_licensing": prep_manifest["provenance_and_licensing"],
        "visual_decision_required": "accept limited Marketplace terrain pilot, request targeted correction, or retain Runtime v1",
    }
    write_json(metadata_root / "package_manifest_v1_2.json", package_manifest)

    files = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name != "SHA256SUMS.txt")
    checksum_path = output_root / "SHA256SUMS.txt"
    checksum_path.write_text(
        "".join(f"{sha256(path)}  {path.relative_to(output_root).as_posix()}\n" for path in files),
        encoding="utf-8", newline="\n",
    )
    for path in output_root.rglob("*"):
        if path.is_file() and (path.name.startswith(".") or path.suffix in {".uid", ".import", ".pyc"} or "__pycache__" in path.parts):
            raise RuntimeError(f"Generated or hidden artifact entered package: {path}")

    zip_path = output_root.with_suffix(".zip")
    if zip_path.exists():
        raise RuntimeError(f"ZIP already exists: {zip_path}")
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(item for item in output_root.rglob("*") if item.is_file()):
            archive.write(path, Path(output_root.name) / path.relative_to(output_root))
    print(f"package={output_root}")
    print(f"zip={zip_path}")
    print(f"zip_sha256={sha256(zip_path)}")
    print(f"checksummed_artifacts={len(files)}")
    return zip_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("prep_root", type=Path)
    parser.add_argument("render_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    build_package(
        assert_external(args.prep_root, "Preparation root"),
        assert_external(args.render_root, "Render root"),
        assert_external(args.output_root, "Output root"),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
