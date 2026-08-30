#!/usr/bin/env python3
"""Build the external review package for the inactive Residential terrain gate."""

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
PREP_TOOL = ROOT / "tools/art/prepare_caden_residential_terrain_gate_v1_2.py"
RENDER_TOOL = ROOT / "tools/art/render_caden_residential_terrain_gate_v1_2.gd"
RESIDENTIAL_TEST = ROOT / "tests/caden_residential_runtime_test.gd"
SCENE_PATH = ROOT / "scenes/world/caden/Residential.tscn"
ACTIVE_TERRAIN = ROOT / "assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.png"
BUILDING_MANIFEST = ROOT / "assets/environments/caden/residential/buildings/residential_building_pilot_manifest_v1_1.json"

PAIRS = (
    ("full", "residential_terrain_full_current_v1_2_1152x768.png", "residential_terrain_full_candidate_v1_2_1152x768.png", "Full zone", 455),
    ("north", "residential_terrain_north_current_v1_2_640x360.png", "residential_terrain_north_candidate_v1_2_640x360.png", "North homes", 405),
    ("south", "residential_terrain_south_current_v1_2_640x360.png", "residential_terrain_south_candidate_v1_2_640x360.png", "South homes", 405),
    ("primary", "residential_terrain_primary_current_v1_2_640x360.png", "residential_terrain_primary_candidate_v1_2_640x360.png", "Primary route and player", 405),
    ("west", "residential_terrain_west_current_v1_2_640x360.png", "residential_terrain_west_candidate_v1_2_640x360.png", "West arrival", 405),
    ("commons", "residential_terrain_commons_current_v1_2_640x360.png", "residential_terrain_commons_candidate_v1_2_640x360.png", "Commons transition", 405),
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


def verify_gate_zero(gate_root: Path) -> str:
    checksum_path = gate_root / "SHA256SUMS.txt"
    lines = [line for line in checksum_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != 47:
        raise RuntimeError("Gate 0 checksum count changed.")
    for line in lines:
        digest, relative = line.split("  ", 1)
        path = gate_root / Path(relative)
        if not path.is_file() or sha256(path) != digest:
            raise RuntimeError(f"Gate 0 checksum mismatch: {relative}")
    return sha256(gate_root / "metadata/package_manifest_v1_1.json")


def verify_prep(prep_root: Path) -> dict:
    manifest_path = prep_root / "metadata/residential_terrain_preparation_manifest_v1_2.json"
    manifest = load_json(manifest_path)
    if manifest.get("gate_state") != "inactive_residential_terrain_comparison_pending_visual_approval":
        raise RuntimeError("Unexpected terrain preparation gate state.")
    if manifest.get("generator_sha256") != sha256(PREP_TOOL):
        raise RuntimeError("Terrain preparation tool hash changed after generation.")
    candidate = manifest.get("candidate", {})
    for key in ("runtime_path", "atlas_path"):
        path = prep_root / candidate[key]
        hash_key = "runtime_sha256" if key == "runtime_path" else "atlas_sha256"
        if not path.is_file() or sha256(path) != candidate[hash_key]:
            raise RuntimeError(f"Terrain candidate artifact mismatch: {path}")
    for relative, digest in manifest.get("boards", {}).items():
        path = prep_root / relative
        if not path.is_file() or sha256(path) != digest:
            raise RuntimeError(f"Terrain preparation board mismatch: {relative}")
    return manifest


def verify_render(render_root: Path) -> dict:
    manifest_path = render_root / "residential_terrain_render_manifest_v1_2.json"
    manifest = load_json(manifest_path)
    if manifest.get("gate_state") != "inactive_residential_terrain_comparison_pending_visual_approval" or manifest.get("active_reference_changed") is not False:
        raise RuntimeError("Unexpected terrain render gate state.")
    if manifest.get("render_tool_sha256") != sha256(RENDER_TOOL):
        raise RuntimeError("Terrain render tool hash changed after capture.")
    captures = manifest.get("captures", [])
    if len(captures) != 13:
        raise RuntimeError("Expected thirteen terrain comparison captures.")
    for record in captures:
        path = render_root / "raw_captures" / record["filename"]
        if not path.is_file() or sha256(path) != record["sha256"]:
            raise RuntimeError(f"Terrain capture mismatch: {path.name}")
    primary = Image.open(render_root / "raw_captures/residential_terrain_primary_candidate_v1_2_640x360.png").convert("RGBA")
    display = Image.open(render_root / "raw_captures/residential_terrain_primary_candidate_display_v1_2_1280x720.png").convert("RGBA")
    if primary.resize((1280, 720), Image.Resampling.NEAREST).tobytes() != display.tobytes():
        raise RuntimeError("Candidate 1280x720 proof is not an exact nearest-neighbor 2x image.")
    return manifest


def verify_active_reference(prep_manifest: dict) -> None:
    scene_text = SCENE_PATH.read_text(encoding="utf-8")
    active_reference = 'res://assets/environments/caden/residential/terrain/residential_terrain_runtime_v1.png'
    if scene_text.count(active_reference) != 1:
        raise RuntimeError("Residential active terrain reference changed.")
    candidate_name = Path(prep_manifest["candidate"]["runtime_path"]).name
    if candidate_name in scene_text:
        raise RuntimeError("Inactive terrain candidate entered Residential.tscn.")
    current_hash = prep_manifest["current_runtime"]["sha256"]
    if sha256(ACTIVE_TERRAIN) != current_hash:
        raise RuntimeError("Active Residential terrain bytes changed.")
    building_manifest = load_json(BUILDING_MANIFEST)
    if building_manifest.get("gate_state") != "residential_building_pilot_v1_1_visual_approved":
        raise RuntimeError("Approved building baseline is not active.")


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
    draw.text((margin, 26), "CADEN RESIDENTIAL TERRAIN GATE v1.2", font=font(32, True), fill=(40, 46, 41))
    draw.text((margin, 70), "Inactive comparison only. Approved buildings and every gameplay contract remain authoritative.", font=font(18), fill=(75, 79, 73))
    y = title_height
    capture_root = render_root / "raw_captures"
    for _, current_name, candidate_name, title, image_height in PAIRS:
        draw.text((margin, y), f"{title} | CURRENT", font=font(19, True), fill=(70, 73, 67))
        draw.text((margin + column_width + gutter, y), f"{title} | CANDIDATE", font=font(19, True), fill=(70, 73, 67))
        y += label_height
        with Image.open(capture_root / current_name) as current, Image.open(capture_root / candidate_name) as candidate:
            board.paste(panel(current.convert("RGBA"), column_width, image_height), (margin, y))
            board.paste(panel(candidate.convert("RGBA"), column_width, image_height), (margin + column_width + gutter, y))
        y += image_height + 34
    draw.text((margin, height - 58), "Approval gate: accept for a limited Residential terrain pilot, request correction, or retain the current terrain.", font=font(18, True), fill=(91, 66, 39))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(output_path)


def copy_artifacts(prep_root: Path, render_root: Path, output_root: Path) -> None:
    shutil.copytree(prep_root / "candidate", output_root / "candidate")
    shutil.copytree(prep_root / "boards", output_root / "boards/source_audits")
    shutil.copytree(render_root / "raw_captures", output_root / "comparison/raw_captures")
    metadata_root = output_root / "metadata"
    metadata_root.mkdir(parents=True, exist_ok=True)
    shutil.copy2(prep_root / "metadata/residential_terrain_preparation_manifest_v1_2.json", metadata_root)
    shutil.copy2(render_root / "residential_terrain_render_manifest_v1_2.json", metadata_root)
    tooling_root = output_root / "tooling"
    tooling_root.mkdir(parents=True, exist_ok=True)
    for path in (PREP_TOOL, RENDER_TOOL, SCRIPT_PATH, RESIDENTIAL_TEST):
        shutil.copy2(path, tooling_root / path.name)


def write_docs(output_root: Path) -> None:
    docs = output_root / "docs"
    docs.mkdir(parents=True, exist_ok=True)
    (docs / "README.md").write_text(
        "# Caden Residential Terrain Gate v1.2\n\n"
        "This package compares the approved Residential scene on its current terrain with a calmer, source-derived grass and warm-stone candidate. "
        "The candidate exists only in this external package and transient render instances. `Residential.tscn` still references the approved v1 terrain.\n\n"
        "The v1.2 derivative keeps the exact `32 x 32` Gate 0 cells, all nine grass and stone variants, and eight transitions, while harmonizing palette and reducing local contrast. "
        "Review the main comparison board and source-audit boards before authorizing any limited terrain pilot.\n",
        encoding="utf-8", newline="\n",
    )
    (docs / "APPROVAL_CHECKLIST.md").write_text(
        "# Visual Approval Checklist\n\n"
        "- [ ] Grass supports the approved buildings without a yellow cast or distracting motif repetition.\n"
        "- [ ] Warm stone reads as a maintained Residential route rather than a Marketplace plaza.\n"
        "- [ ] North and south lanes remain visually wide enough for their authoritative corridors.\n"
        "- [ ] West arrival and Commons transition remain open and unmistakable.\n"
        "- [ ] Stone/grass transitions do not show clipped edges, gaps, halos, or hard rectangular seams.\n"
        "- [ ] Player and NPC silhouettes remain readable on both materials.\n"
        "- [ ] Existing props, trees, fences, and approved houses remain visually grounded.\n\n"
        "Decision: ACCEPT LIMITED RESIDENTIAL PILOT / TARGETED CORRECTIONS / RETAIN CURRENT TERRAIN\n",
        encoding="utf-8", newline="\n",
    )
    (docs / "PROVENANCE_AND_LICENSE.md").write_text(
        "# Provenance and Licensing\n\n"
        "The project owner supplied the terrain master through local Downloads intake. Creator, generation tool, license, and derivative permission remain undocumented. "
        "Status is `project_internal_rights_unverified`; do not publish or ship this derivative until rights are verified. The original master remains outside `res://` and is not included.\n",
        encoding="utf-8", newline="\n",
    )
    (docs / "TOOLING_REQUIREMENTS.md").write_text(
        "# Tooling Requirements\n\n"
        "- Godot 4.7.2, Compatibility renderer\n"
        "- Python 3.12\n"
        "- Pillow 12.3 for offline palette harmonization, audit boards, and package assembly\n\n"
        "No new game runtime dependency or Godot addon was introduced.\n",
        encoding="utf-8", newline="\n",
    )


def build_package(gate_root: Path, prep_root: Path, render_root: Path, output_root: Path) -> Path:
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)
    gate_manifest_hash = verify_gate_zero(gate_root)
    prep_manifest = verify_prep(prep_root)
    render_manifest = verify_render(render_root)
    verify_active_reference(prep_manifest)
    copy_artifacts(prep_root, render_root, output_root)
    comparison_board = output_root / "boards/residential_terrain_comparison_v1_2.png"
    build_comparison_board(render_root, comparison_board)
    write_docs(output_root)

    manifest = {
        "schema": "caden-residential-terrain-review-package-v1.2",
        "gate_state": "inactive_residential_terrain_comparison_pending_visual_approval",
        "scope": "Residential-only terrain comparison; no active reference or other-zone change.",
        "gate_zero_package_manifest_sha256": gate_manifest_hash,
        "preparation_manifest_sha256": sha256(prep_root / "metadata/residential_terrain_preparation_manifest_v1_2.json"),
        "render_manifest_sha256": sha256(render_root / "residential_terrain_render_manifest_v1_2.json"),
        "comparison_board_sha256": sha256(comparison_board),
        "scene_sha256": sha256(SCENE_PATH),
        "active_terrain_sha256": sha256(ACTIVE_TERRAIN),
        "approved_building_manifest_sha256": sha256(BUILDING_MANIFEST),
        "candidate_runtime_sha256": prep_manifest["candidate"]["runtime_sha256"],
        "matched_view_pairs": len(PAIRS),
        "exact_2x_candidate_proof": True,
        "active_reference_changes": [],
        "tooling": {"godot": "4.7.2-stable Compatibility", "python": "3.12", "pillow": "12.3", "runtime_dependencies_added": []},
        "tool_hashes": {f"tooling/{path.name}": sha256(path) for path in (PREP_TOOL, RENDER_TOOL, SCRIPT_PATH, RESIDENTIAL_TEST)},
        "provenance_and_licensing": prep_manifest["provenance_and_licensing"],
        "protected_contracts": prep_manifest["protected_contracts"],
        "visual_decision_required": "accept limited Residential pilot, request targeted correction, or retain current terrain",
    }
    metadata_root = output_root / "metadata"
    package_manifest_path = metadata_root / "package_manifest_v1_2.json"
    write_json(package_manifest_path, manifest)

    files = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name != "SHA256SUMS.txt")
    checksum_path = output_root / "SHA256SUMS.txt"
    checksum_path.write_text("".join(f"{sha256(path)}  {path.relative_to(output_root).as_posix()}\n" for path in files), encoding="utf-8", newline="\n")
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
    parser.add_argument("gate_root", type=Path)
    parser.add_argument("prep_root", type=Path)
    parser.add_argument("render_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    build_package(
        assert_external(args.gate_root, "Gate 0 root"),
        assert_external(args.prep_root, "Preparation root"),
        assert_external(args.render_root, "Render root"),
        assert_external(args.output_root, "Output root"),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
