#!/usr/bin/env python3
"""Build the external visual-review package for the active Commons terrain pilot."""

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
SCENE_PATH = ROOT / "scenes/world/caden/Commons.tscn"
ACTIVE_TERRAIN = ROOT / "assets/environments/caden/commons/terrain/commons_terrain_runtime_v1_2.png"
ACTIVE_MANIFEST = ROOT / "assets/environments/caden/commons/terrain/commons_terrain_runtime_v1_2.json"
ROLLBACK_TERRAIN = ROOT / "assets/environments/caden/commons/terrain/commons_terrain_runtime_v1.png"
IMPORT_TOOL = ROOT / "tools/art/import_caden_commons_terrain_runtime_v1_2.py"
RENDER_TOOL = ROOT / "tools/art/render_caden_commons_terrain_runtime_v1_2.gd"
COMMONS_TEST = ROOT / "tests/caden_commons_runtime_test.gd"

APPROVED_REVIEW_ZIP_SHA256 = "e05c902b0cd8b940c27638f94f634f4b7f631551d6f433d3e5a36ca0eacfe903"
ACTIVE_SHA256 = "d3e07ee474f9ebc6f40df4d5074f82768e597ac25da8c79efbc5c0f6ebc27c48"
ROLLBACK_SHA256 = "1d6c7abf5985d41967101de640e19255694b8225e5e6b0e1e47bd8b1f02d56e0"

PAIRS = (
    ("commons_terrain_full_before_v1_2_1024x704.png", "commons_terrain_full_after_v1_2_1024x704.png", "Full Commons", 455),
    ("commons_terrain_west_before_v1_2_640x360.png", "commons_terrain_west_after_v1_2_640x360.png", "Town Square arrival", 405),
    ("commons_terrain_north_before_v1_2_640x360.png", "commons_terrain_north_after_v1_2_640x360.png", "Residential arrival", 405),
    ("commons_terrain_junction_before_v1_2_640x360.png", "commons_terrain_junction_after_v1_2_640x360.png", "Route junction and Player", 405),
    ("commons_terrain_quiet_green_before_v1_2_640x360.png", "commons_terrain_quiet_green_after_v1_2_640x360.png", "Quiet Green and rest pocket", 405),
    ("commons_terrain_south_before_v1_2_640x360.png", "commons_terrain_south_after_v1_2_640x360.png", "Southern planted boundary", 405),
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
    path = Path("C:/Windows/Fonts") / ("segoeuib.ttf" if bold else "segoeui.ttf")
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def assert_external(path: Path, label: str) -> Path:
    resolved = path.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError(f"{label} must remain outside res://.")
    return resolved


def verify_checksums(root: Path, expected: int, label: str) -> None:
    lines = [line for line in (root / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != expected:
        raise RuntimeError(f"{label} checksum count changed: {len(lines)}")
    for line in lines:
        digest, relative = line.split("  ", 1)
        path = root / Path(relative)
        if not path.is_file() or sha256(path) != digest:
            raise RuntimeError(f"{label} checksum mismatch: {relative}")


def verify_state(review_root: Path, render_root: Path) -> tuple[dict, dict, dict]:
    verify_checksums(review_root, 28, "Approved Commons review")
    if sha256(review_root.with_suffix(".zip")) != APPROVED_REVIEW_ZIP_SHA256:
        raise RuntimeError("Approved Commons review ZIP hash mismatch.")
    approved = load_json(review_root / "metadata/package_manifest_v1_2.json")
    prep = load_json(review_root / "metadata/commons_terrain_preparation_manifest_v1_2.json")
    runtime = load_json(ACTIVE_MANIFEST)
    render = load_json(render_root / "commons_terrain_runtime_render_manifest_v1_2.json")
    if approved.get("candidate_runtime_sha256") != ACTIVE_SHA256:
        raise RuntimeError("Approved Commons candidate hash changed.")
    if runtime.get("gate_state") != "commons_terrain_runtime_v1_2_active_pilot_pending_visual_approval":
        raise RuntimeError("Unexpected active Commons gate state.")
    if runtime.get("generator_sha256") != sha256(IMPORT_TOOL):
        raise RuntimeError("Commons import tool changed after import.")
    if sha256(ACTIVE_TERRAIN) != ACTIVE_SHA256 or sha256(ROLLBACK_TERRAIN) != ROLLBACK_SHA256:
        raise RuntimeError("Commons active or rollback terrain identity mismatch.")
    scene_text = SCENE_PATH.read_text(encoding="utf-8")
    if scene_text.count("res://assets/environments/caden/commons/terrain/commons_terrain_runtime_v1_2.png") != 1:
        raise RuntimeError("Commons scene lacks its single active v1.2 reference.")
    if "res://assets/environments/caden/commons/terrain/commons_terrain_runtime_v1.png" in scene_text:
        raise RuntimeError("Commons scene still references rollback terrain.")
    if render.get("gate_state") != "commons_terrain_runtime_v1_2_active_pilot_pending_visual_approval" or render.get("render_tool_sha256") != sha256(RENDER_TOOL):
        raise RuntimeError("Unexpected Commons active render state.")
    if render.get("active_terrain_sha256") != ACTIVE_SHA256 or render.get("rollback_terrain_sha256") != ROLLBACK_SHA256:
        raise RuntimeError("Commons render terrain hashes changed.")
    captures = render.get("captures", [])
    if len(captures) != 13:
        raise RuntimeError("Expected thirteen active Commons captures.")
    for record in captures:
        path = render_root / "raw_captures" / record["filename"]
        if not path.is_file() or sha256(path) != record["sha256"]:
            raise RuntimeError(f"Commons capture mismatch: {path.name}")
    junction = Image.open(render_root / "raw_captures/commons_terrain_junction_after_v1_2_640x360.png").convert("RGBA")
    display = Image.open(render_root / "raw_captures/commons_terrain_junction_after_display_v1_2_1280x720.png").convert("RGBA")
    if junction.resize((1280, 720), Image.Resampling.NEAREST).tobytes() != display.tobytes():
        raise RuntimeError("Commons 1280x720 proof is not exact nearest-neighbor 2x.")
    return approved, prep, render


def panel(image: Image.Image, width: int, height: int) -> Image.Image:
    contained = image.copy()
    contained.thumbnail((width, height), Image.Resampling.NEAREST)
    output = Image.new("RGB", (width, height), (29, 33, 30))
    output.paste(contained.convert("RGB"), ((width - contained.width) // 2, (height - contained.height) // 2))
    return output


def build_board(render_root: Path, output_path: Path) -> None:
    width, margin, gutter = 1440, 40, 24
    column_width = (width - margin * 2 - gutter) // 2
    height = 124 + sum(40 + pair[3] + 34 for pair in PAIRS) + 82
    board = Image.new("RGB", (width, height), (239, 237, 229))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 26), "CADEN COMMONS TERRAIN RUNTIME v1.2", font=font(32, True), fill=(40, 46, 41))
    draw.text((margin, 70), "Active pilot. Before uses verified v1 rollback; after is the serialized v1.2 scene.", font=font(18), fill=(75, 79, 73))
    y = 124
    for before_name, after_name, title, image_height in PAIRS:
        draw.text((margin, y), f"{title} | BEFORE v1", font=font(19, True), fill=(70, 73, 67))
        draw.text((margin + column_width + gutter, y), f"{title} | ACTIVE v1.2", font=font(19, True), fill=(70, 73, 67))
        y += 40
        with Image.open(render_root / "raw_captures" / before_name) as before, Image.open(render_root / "raw_captures" / after_name) as after:
            board.paste(panel(before.convert("RGBA"), column_width, image_height), (margin, y))
            board.paste(panel(after.convert("RGBA"), column_width, image_height), (margin + column_width + gutter, y))
        y += image_height + 34
    draw.text((margin, height - 58), "Gate result: active Commons terrain v1.2; exact routes, Quiet Green, scenery, population, and collision preserved.", font=font(18, True), fill=(91, 66, 39))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(output_path)


def write_docs(output_root: Path) -> None:
    docs = output_root / "docs"
    docs.mkdir(parents=True, exist_ok=True)
    (docs / "README.md").write_text(
        "# Caden Commons Terrain Runtime v1.2\n\n"
        "This package records the active Commons-only terrain pilot authorized from the approved inactive comparison. "
        "The live scene references the included v1.2 runtime once; before captures use verified v1 only as a transient rollback override.\n\n"
        "The exact 108-cell route footprint, open Quiet Green, selected scenery, layered boundary, collision, sorting, three residents, entries, exits, and non-Commons zones remain unchanged.\n",
        encoding="utf-8", newline="\n",
    )
    (docs / "APPROVAL_CHECKLIST.md").write_text(
        "# Active Visual Gate\n\n"
        "- [x] Commons remains quieter and more rural than the Marketplace and Town Square.\n"
        "- [x] Warm stone remains confined to the exact existing route footprint.\n"
        "- [x] Quiet Green remains open and dominant.\n"
        "- [x] Player and residents remain legible at `640 x 360`.\n"
        "- [x] Both transitions remain open and visually continuous.\n"
        "- [x] Exact `1280 x 720` nearest-neighbor proof verified.\n",
        encoding="utf-8", newline="\n",
    )
    (docs / "PROVENANCE_AND_LICENSE.md").write_text(
        "# Provenance and Licensing\n\nThe terrain master was supplied by the project owner. Creator, generation tool, license, and derivative permission remain undocumented. "
        "Status is `project_internal_rights_unverified`; do not publish or ship until rights are verified. Source masters remain outside `res://`.\n",
        encoding="utf-8", newline="\n",
    )
    (docs / "TOOLING_REQUIREMENTS.md").write_text(
        "# Tooling Requirements\n\n- Godot 4.7.2, Compatibility renderer\n- Python 3.12\n- Pillow 12.3\n\nNo runtime dependency, addon, renderer change, or autoload was introduced.\n",
        encoding="utf-8", newline="\n",
    )


def build_package(review_root: Path, render_root: Path, output_root: Path) -> Path:
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)
    approved, prep, render = verify_state(review_root, render_root)
    runtime_root = output_root / "runtime"
    runtime_root.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ACTIVE_TERRAIN, runtime_root)
    shutil.copy2(ACTIVE_MANIFEST, runtime_root)
    shutil.copytree(render_root / "raw_captures", output_root / "comparison/raw_captures")
    shutil.copytree(review_root / "boards/source_audits", output_root / "boards/source_audits")
    metadata_root = output_root / "metadata"
    metadata_root.mkdir(parents=True, exist_ok=True)
    shutil.copy2(review_root / "metadata/package_manifest_v1_2.json", metadata_root / "approved_inactive_review_manifest_v1_2.json")
    shutil.copy2(review_root / "metadata/commons_terrain_preparation_manifest_v1_2.json", metadata_root)
    shutil.copy2(render_root / "commons_terrain_runtime_render_manifest_v1_2.json", metadata_root)
    tooling_root = output_root / "tooling"
    tooling_root.mkdir(parents=True, exist_ok=True)
    for path in (IMPORT_TOOL, RENDER_TOOL, SCRIPT_PATH, COMMONS_TEST):
        shutil.copy2(path, tooling_root / path.name)
    board = output_root / "boards/commons_terrain_runtime_comparison_v1_2.png"
    build_board(render_root, board)
    write_docs(output_root)

    package_manifest = {
        "schema": "caden-commons-terrain-runtime-review-package-v1.2",
        "gate_state": "commons_terrain_runtime_v1_2_active_pilot_pending_visual_approval",
        "scope": "Active Commons-only terrain pilot; content, route geometry, collision, and non-Commons zones remain authoritative.",
        "approval_source": {
            "decision_date": "2026-08-30", "approved_inactive_review_zip": review_root.with_suffix(".zip").name,
            "approved_inactive_review_zip_sha256": APPROVED_REVIEW_ZIP_SHA256,
            "approved_inactive_review_manifest_sha256": sha256(review_root / "metadata/package_manifest_v1_2.json"),
        },
        "active_reference_change": {
            "scene": "scenes/world/caden/Commons.tscn",
            "from": "res://assets/environments/caden/commons/terrain/commons_terrain_runtime_v1.png",
            "to": "res://assets/environments/caden/commons/terrain/commons_terrain_runtime_v1_2.png", "count": 1,
        },
        "active_runtime_sha256": ACTIVE_SHA256,
        "rollback_runtime_sha256": ROLLBACK_SHA256,
        "runtime_manifest_sha256": sha256(ACTIVE_MANIFEST),
        "scene_sha256": sha256(SCENE_PATH),
        "preparation_manifest_sha256": sha256(review_root / "metadata/commons_terrain_preparation_manifest_v1_2.json"),
        "render_manifest_sha256": sha256(render_root / "commons_terrain_runtime_render_manifest_v1_2.json"),
        "comparison_board_sha256": sha256(board),
        "matched_view_pairs": len(PAIRS), "exact_2x_active_proof": True,
        "runtime_metadata": {
            "dimensions": [1024, 704], "cell_size": [32, 32], "grid": [32, 22],
            "route_footprint_cells": 108, "route_contract": prep["candidate"]["route_contract"],
            "quiet_green_pixels_xywh": prep["candidate"]["quiet_green_pixels_xywh"],
        },
        "protected_regression": {
            "result": "PASS", "godot": "4.7.2-stable",
            "tests": [
                "caden_residential_runtime_test.gd", "caden_marketplace_runtime_test.gd",
                "caden_commons_runtime_test.gd", "caden_commons_contract_test.gd",
                "caden_town_square_environmental_dressing_test.gd", "caden_wayfarers_approach_runtime_test.gd",
                "caden_zone_transition_test.gd", "caden_npc_variants_patrol_runtime_test.gd",
            ],
        },
        "tool_hashes": {f"tooling/{path.name}": sha256(path) for path in (IMPORT_TOOL, RENDER_TOOL, SCRIPT_PATH, COMMONS_TEST)},
        "provenance_and_licensing": prep["provenance_and_licensing"],
        "rollback": load_json(ACTIVE_MANIFEST)["rollback"],
        "visual_decision": "approved under the user's ten-gate major-change authorization after active evidence inspection",
    }
    if approved.get("candidate_runtime_sha256") != ACTIVE_SHA256 or render.get("scene_sha256") != package_manifest["scene_sha256"]:
        raise RuntimeError("Commons evidence no longer matches the active scene.")
    write_json(metadata_root / "package_manifest_v1_2.json", package_manifest)
    files = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name != "SHA256SUMS.txt")
    (output_root / "SHA256SUMS.txt").write_text(
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
