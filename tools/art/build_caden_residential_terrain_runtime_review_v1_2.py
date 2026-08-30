#!/usr/bin/env python3
"""Build the external visual-review package for the active Residential terrain pilot."""

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
SCENE_PATH = ROOT / "scenes/world/caden/Residential.tscn"
ACTIVE_TERRAIN = ROOT / "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1_2.png"
ACTIVE_MANIFEST = ROOT / "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1_2.json"
ROLLBACK_TERRAIN = ROOT / "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.png"
BUILDING_MANIFEST = ROOT / "assets/environments/caden/residential/buildings/residential_building_pilot_manifest_v1_1.json"
IMPORT_TOOL = ROOT / "tools/art/import_caden_residential_terrain_runtime_v1_2.py"
RENDER_TOOL = ROOT / "tools/art/render_caden_residential_terrain_runtime_v1_2.gd"
RESIDENTIAL_TEST = ROOT / "tests/caden_residential_runtime_test.gd"

APPROVED_REVIEW_ZIP_SHA256 = "d6479402e753b782aaf299a3b7db823af11b13bd673e85d989f6190aac4571e8"
ACTIVE_SHA256 = "828cfd64940b9bdd37fca40bac4d5a091432955d16f8e47b9701bef2028a98a0"
ROLLBACK_SHA256 = "d3d09685eac8f3343bba1c476266def1f7fc99bc13c56863b8445ce21ca03daf"

PAIRS = (
    ("full", "residential_terrain_full_before_v1_2_1152x768.png", "residential_terrain_full_after_v1_2_1152x768.png", "Full zone", 455),
    ("north", "residential_terrain_north_before_v1_2_640x360.png", "residential_terrain_north_after_v1_2_640x360.png", "North homes", 405),
    ("south", "residential_terrain_south_before_v1_2_640x360.png", "residential_terrain_south_after_v1_2_640x360.png", "South homes", 405),
    ("primary", "residential_terrain_primary_before_v1_2_640x360.png", "residential_terrain_primary_after_v1_2_640x360.png", "Primary route and player", 405),
    ("west", "residential_terrain_west_before_v1_2_640x360.png", "residential_terrain_west_after_v1_2_640x360.png", "West arrival", 405),
    ("commons", "residential_terrain_commons_before_v1_2_640x360.png", "residential_terrain_commons_after_v1_2_640x360.png", "Commons transition", 405),
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


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    path = Path("C:/Windows/Fonts") / name
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def assert_external(path: Path, label: str) -> Path:
    resolved = path.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError(f"{label} must remain outside res://.")
    return resolved


def verify_approved_review(review_root: Path) -> tuple[dict, dict]:
    checksum_path = review_root / "SHA256SUMS.txt"
    lines = [line for line in checksum_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != 29:
        raise RuntimeError("Approved inactive review checksum count changed.")
    for line in lines:
        digest, relative = line.split("  ", 1)
        path = review_root / Path(relative)
        if not path.is_file() or sha256(path) != digest:
            raise RuntimeError(f"Approved inactive review checksum mismatch: {relative}")
    review_zip = review_root.with_suffix(".zip")
    if not review_zip.is_file() or sha256(review_zip) != APPROVED_REVIEW_ZIP_SHA256:
        raise RuntimeError("Approved inactive review ZIP hash mismatch.")
    package_manifest = load_json(review_root / "metadata/package_manifest_v1_2.json")
    prep_manifest = load_json(review_root / "metadata/residential_terrain_preparation_manifest_v1_2.json")
    if package_manifest.get("gate_state") != "inactive_residential_terrain_comparison_pending_visual_approval":
        raise RuntimeError("Unexpected approved review gate state.")
    if prep_manifest.get("candidate", {}).get("runtime_sha256") != ACTIVE_SHA256:
        raise RuntimeError("Approved candidate hash changed.")
    return package_manifest, prep_manifest


def verify_active_runtime() -> tuple[dict, dict]:
    manifest = load_json(ACTIVE_MANIFEST)
    if manifest.get("gate_state") != "residential_terrain_runtime_v1_2_active_pilot_pending_visual_approval":
        raise RuntimeError("Unexpected active terrain gate state.")
    if manifest.get("generator_sha256") != sha256(IMPORT_TOOL):
        raise RuntimeError("Terrain import tool changed after import.")
    if sha256(ACTIVE_TERRAIN) != ACTIVE_SHA256 or manifest.get("output_sha256") != ACTIVE_SHA256:
        raise RuntimeError("Active terrain hash mismatch.")
    if sha256(ROLLBACK_TERRAIN) != ROLLBACK_SHA256:
        raise RuntimeError("Rollback terrain hash mismatch.")
    if manifest.get("approval", {}).get("review_package_sha256") != APPROVED_REVIEW_ZIP_SHA256:
        raise RuntimeError("Active manifest is not bound to the approved review package.")
    scene_text = SCENE_PATH.read_text(encoding="utf-8")
    active_reference = "res://assets/environments/caden/residential/terrain/residential_terrain_runtime_v1_2.png"
    rollback_reference = "res://assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.png"
    if scene_text.count(active_reference) != 1 or scene_text.count(rollback_reference) != 0:
        raise RuntimeError("Residential scene does not contain exactly one active v1.2 terrain reference.")
    building_manifest = load_json(BUILDING_MANIFEST)
    if building_manifest.get("gate_state") != "residential_building_pilot_v1_1_visual_approved":
        raise RuntimeError("Approved Residential building baseline is not active.")
    terrain_state = building_manifest.get("terrain", {}).get("status")
    if terrain_state != "residential_runtime_v1_2_active_pilot_pending_visual_approval":
        raise RuntimeError("Building manifest does not record the active terrain pilot.")
    return manifest, building_manifest


def verify_render(render_root: Path) -> dict:
    manifest_path = render_root / "residential_terrain_runtime_render_manifest_v1_2.json"
    manifest = load_json(manifest_path)
    if manifest.get("gate_state") != "residential_terrain_runtime_v1_2_active_pilot_pending_visual_approval":
        raise RuntimeError("Unexpected active render gate state.")
    if manifest.get("render_tool_sha256") != sha256(RENDER_TOOL):
        raise RuntimeError("Active render tool changed after capture.")
    if manifest.get("active_terrain_sha256") != ACTIVE_SHA256 or manifest.get("rollback_terrain_sha256") != ROLLBACK_SHA256:
        raise RuntimeError("Active render terrain hashes do not match the approved contract.")
    captures = manifest.get("captures", [])
    if len(captures) != 13:
        raise RuntimeError("Expected thirteen active terrain captures.")
    for record in captures:
        path = render_root / "raw_captures" / record["filename"]
        if not path.is_file() or sha256(path) != record["sha256"]:
            raise RuntimeError(f"Active terrain capture mismatch: {path.name}")
    primary = Image.open(render_root / "raw_captures/residential_terrain_primary_after_v1_2_640x360.png").convert("RGBA")
    display = Image.open(render_root / "raw_captures/residential_terrain_primary_after_display_v1_2_1280x720.png").convert("RGBA")
    if primary.resize((1280, 720), Image.Resampling.NEAREST).tobytes() != display.tobytes():
        raise RuntimeError("Active 1280x720 proof is not an exact nearest-neighbor 2x image.")
    return manifest


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
    draw.text((margin, 26), "CADEN RESIDENTIAL TERRAIN RUNTIME v1.2", font=font(32, True), fill=(40, 46, 41))
    draw.text((margin, 70), "Active limited pilot. Before uses the verified v1 rollback; after is the serialized v1.2 scene.", font=font(18), fill=(75, 79, 73))
    y = title_height
    capture_root = render_root / "raw_captures"
    for _, before_name, after_name, title, image_height in PAIRS:
        draw.text((margin, y), f"{title} | BEFORE v1", font=font(19, True), fill=(70, 73, 67))
        draw.text((margin + column_width + gutter, y), f"{title} | ACTIVE v1.2", font=font(19, True), fill=(70, 73, 67))
        y += label_height
        with Image.open(capture_root / before_name) as before, Image.open(capture_root / after_name) as after:
            board.paste(panel(before.convert("RGBA"), column_width, image_height), (margin, y))
            board.paste(panel(after.convert("RGBA"), column_width, image_height), (margin + column_width + gutter, y))
        y += image_height + 34
    draw.text((margin, height - 58), "Approval gate: approve v1.2, request a targeted correction, or restore the single v1 texture reference.", font=font(18, True), fill=(91, 66, 39))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(output_path)


def copy_artifacts(review_root: Path, render_root: Path, output_root: Path) -> None:
    runtime_root = output_root / "runtime"
    runtime_root.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ACTIVE_TERRAIN, runtime_root)
    shutil.copy2(ACTIVE_MANIFEST, runtime_root)
    shutil.copytree(render_root / "raw_captures", output_root / "comparison/raw_captures")
    shutil.copytree(review_root / "boards/source_audits", output_root / "boards/source_audits")
    metadata_root = output_root / "metadata"
    metadata_root.mkdir(parents=True, exist_ok=True)
    shutil.copy2(review_root / "metadata/package_manifest_v1_2.json", metadata_root / "approved_inactive_review_manifest_v1_2.json")
    shutil.copy2(review_root / "metadata/residential_terrain_preparation_manifest_v1_2.json", metadata_root)
    shutil.copy2(render_root / "residential_terrain_runtime_render_manifest_v1_2.json", metadata_root)
    tooling_root = output_root / "tooling"
    tooling_root.mkdir(parents=True, exist_ok=True)
    for path in (IMPORT_TOOL, RENDER_TOOL, SCRIPT_PATH, RESIDENTIAL_TEST):
        shutil.copy2(path, tooling_root / path.name)


def write_docs(output_root: Path) -> None:
    docs = output_root / "docs"
    docs.mkdir(parents=True, exist_ok=True)
    (docs / "README.md").write_text(
        "# Caden Residential Terrain Runtime v1.2\n\n"
        "This package records the active, Residential-only terrain pilot authorized after approval of the inactive v1.2 comparison. "
        "The live scene references the included v1.2 runtime once. Every before capture is a transient override using the verified v1 rollback; every after capture is the serialized scene.\n\n"
        "The road mask, collision, buildings, props, landscaping, seven residents, entries, exits, and every non-Residential zone remain unchanged. "
        "No additional terrain or building integration is authorized by this package.\n",
        encoding="utf-8", newline="\n",
    )
    (docs / "APPROVAL_CHECKLIST.md").write_text(
        "# Active Visual Approval Checklist\n\n"
        "- [ ] Warm stone reads as a maintained Residential route at gameplay scale.\n"
        "- [ ] Grass supports the approved houses without a yellow cast or distracting repetition.\n"
        "- [ ] All intersections, branch ends, and grass/stone transitions align without gaps or hard seams.\n"
        "- [ ] West arrival and Commons transition remain open and unmistakable.\n"
        "- [ ] Player and all seven NPC silhouettes remain readable on both materials.\n"
        "- [ ] Buildings, fences, trees, gardens, and set pieces remain visually grounded.\n"
        "- [ ] No route, collision, entry, exit, or non-Residential change is visible.\n\n"
        "Decision: APPROVE v1.2 / TARGETED CORRECTION / RESTORE v1\n",
        encoding="utf-8", newline="\n",
    )
    (docs / "PROVENANCE_AND_LICENSE.md").write_text(
        "# Provenance and Licensing\n\n"
        "The project owner supplied the terrain master through local Downloads intake. Creator, generation tool, license, and derivative permission remain undocumented. "
        "Status is `project_internal_rights_unverified`; do not publish or ship this derivative until rights are verified. The master, Gate 0 atlas, and preparation workspace remain outside `res://` and are not included.\n",
        encoding="utf-8", newline="\n",
    )
    (docs / "TOOLING_REQUIREMENTS.md").write_text(
        "# Tooling Requirements\n\n"
        "- Godot 4.7.2, Compatibility renderer\n"
        "- Python 3.12\n"
        "- Pillow 12.3 for package board assembly and exact nearest-neighbor verification\n\n"
        "No game runtime dependency, Godot addon, renderer change, or autoload was introduced.\n",
        encoding="utf-8", newline="\n",
    )


def build_package(review_root: Path, render_root: Path, output_root: Path) -> Path:
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)
    approved_manifest, prep_manifest = verify_approved_review(review_root)
    runtime_manifest, building_manifest = verify_active_runtime()
    render_manifest = verify_render(render_root)
    copy_artifacts(review_root, render_root, output_root)
    comparison_board = output_root / "boards/residential_terrain_runtime_comparison_v1_2.png"
    build_comparison_board(render_root, comparison_board)
    write_docs(output_root)

    package_manifest = {
        "schema": "caden-residential-terrain-runtime-review-package-v1.2",
        "gate_state": "residential_terrain_runtime_v1_2_active_pilot_pending_visual_approval",
        "scope": "Active Residential-only terrain pilot; all route geometry, collision, content, and non-Residential zones remain authoritative.",
        "approval_source": {
            "decision_date": "2026-08-29",
            "approved_inactive_review_zip": review_root.with_suffix(".zip").name,
            "approved_inactive_review_zip_sha256": APPROVED_REVIEW_ZIP_SHA256,
            "approved_inactive_review_manifest_sha256": sha256(review_root / "metadata/package_manifest_v1_2.json"),
        },
        "active_reference_change": {
            "scene": "scenes/world/caden/Residential.tscn",
            "from": "res://assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.png",
            "to": "res://assets/environments/caden/residential/terrain/residential_terrain_runtime_v1_2.png",
            "count": 1,
        },
        "active_runtime_sha256": ACTIVE_SHA256,
        "rollback_runtime_sha256": ROLLBACK_SHA256,
        "runtime_manifest_sha256": sha256(ACTIVE_MANIFEST),
        "building_manifest_sha256": sha256(BUILDING_MANIFEST),
        "scene_sha256": sha256(SCENE_PATH),
        "preparation_manifest_sha256": sha256(review_root / "metadata/residential_terrain_preparation_manifest_v1_2.json"),
        "render_manifest_sha256": sha256(render_root / "residential_terrain_runtime_render_manifest_v1_2.json"),
        "comparison_board_sha256": sha256(comparison_board),
        "matched_view_pairs": len(PAIRS),
        "exact_2x_active_proof": True,
        "runtime_metadata": {
            "dimensions": runtime_manifest["dimensions"],
            "cell_size": runtime_manifest["cell_size"],
            "grid": runtime_manifest["grid"],
            "variant_counts": runtime_manifest["variant_counts"],
            "route_contract": runtime_manifest["route_contract"],
            "pixel_audit": runtime_manifest["pixel_audit"],
        },
        "protected_regression": {
            "result": "PASS",
            "godot": "4.7.2-stable",
            "tests": [
                "caden_residential_runtime_test.gd",
                "caden_marketplace_runtime_test.gd",
                "caden_commons_runtime_test.gd",
                "caden_commons_contract_test.gd",
                "caden_town_square_environmental_dressing_test.gd",
                "caden_wayfarers_approach_runtime_test.gd",
                "caden_zone_transition_test.gd",
                "caden_npc_variants_patrol_runtime_test.gd",
            ],
        },
        "tool_hashes": {f"tooling/{path.name}": sha256(path) for path in (IMPORT_TOOL, RENDER_TOOL, SCRIPT_PATH, RESIDENTIAL_TEST)},
        "provenance_and_licensing": prep_manifest["provenance_and_licensing"],
        "rollback": runtime_manifest["rollback"],
        "visual_decision_required": "approve active v1.2, request targeted correction, or restore v1",
    }
    if approved_manifest.get("candidate_runtime_sha256") != ACTIVE_SHA256:
        raise RuntimeError("Approved package manifest does not match the active runtime.")
    if render_manifest.get("scene_sha256") != package_manifest["scene_sha256"]:
        raise RuntimeError("Scene changed after active Compatibility capture.")
    if building_manifest.get("terrain", {}).get("runtime_sha256") != ACTIVE_SHA256:
        raise RuntimeError("Building manifest terrain record does not match the active runtime.")
    metadata_root = output_root / "metadata"
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
    parser.add_argument("approved_review_root", type=Path)
    parser.add_argument("render_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    build_package(
        assert_external(args.approved_review_root, "Approved review root"),
        assert_external(args.render_root, "Render root"),
        assert_external(args.output_root, "Output root"),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
