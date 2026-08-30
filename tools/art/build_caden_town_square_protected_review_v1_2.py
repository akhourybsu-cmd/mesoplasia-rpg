#!/usr/bin/env python3
"""Build the checksummed Town Square protected comparison decision package."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import zipfile

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = Path(__file__).resolve()
PREP_TOOL = ROOT / "tools/art/prepare_caden_town_square_protected_gate_v1_2.py"
RENDER_TOOL = ROOT / "tools/art/render_caden_town_square_protected_gate_v1_2.gd"
SCENE_PATH = ROOT / "scenes/world/caden/TownSquare.tscn"
ARCHITECTURE_MANIFEST = ROOT / "assets/environments/caden/architecture/town_square/caden_architecture_runtime_v2_manifest.json"
REQUIRED_CAPTURES = (
    "town_square_full_current_v1_2_960x704.png",
    "town_square_full_terrain_v1_2_960x704.png",
    "town_square_full_architecture_v1_2_960x704.png",
    "town_square_full_combined_v1_2_960x704.png",
    "town_square_plaza_current_v1_2_640x360.png",
    "town_square_plaza_terrain_v1_2_640x360.png",
    "town_square_northwest_current_v1_2_640x360.png",
    "town_square_northwest_architecture_v1_2_640x360.png",
    "town_square_south_current_v1_2_640x360.png",
    "town_square_south_architecture_v1_2_640x360.png",
    "town_square_doorway_current_v1_2_640x360.png",
    "town_square_doorway_architecture_v1_2_640x360.png",
    "town_square_doorway_combined_v1_2_640x360.png",
    "town_square_east_current_v1_2_640x360.png",
    "town_square_east_combined_v1_2_640x360.png",
    "town_square_doorway_architecture_display_v1_2_1280x720.png",
)


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
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    path = Path("C:/Windows/Fonts") / ("segoeuib.ttf" if bold else "segoeui.ttf")
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def assert_external(path: Path, label: str) -> Path:
    resolved = path.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError(f"{label} must remain outside res://.")
    return resolved


def copy_file(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def labeled_panel(image: Image.Image, label: str, size: tuple[int, int]) -> Image.Image:
    panel = Image.new("RGB", size, (25, 30, 27))
    draw = ImageDraw.Draw(panel)
    draw.text((14, 10), label, font=font(18, True), fill=(239, 237, 226))
    available = (size[0] - 28, size[1] - 54)
    scale = min(available[0] / image.width, available[1] / image.height)
    resized = image.convert("RGB").resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.NEAREST)
    panel.paste(resized, ((size[0] - resized.width) // 2, 44 + (available[1] - resized.height) // 2))
    return panel


def build_full_board(captures: Path, output: Path) -> None:
    entries = (
        ("CURRENT: Runtime v2 + terrain v1.1", "town_square_full_current_v1_2_960x704.png"),
        ("TERRAIN ONLY: retain current", "town_square_full_terrain_v1_2_960x704.png"),
        ("ARCHITECTURE ONLY: approved", "town_square_full_architecture_v1_2_960x704.png"),
        ("COMBINED: terrain candidate not approved", "town_square_full_combined_v1_2_960x704.png"),
    )
    board = Image.new("RGB", (1280, 1030), (18, 23, 20))
    draw = ImageDraw.Draw(board)
    draw.text((24, 16), "Town Square protected decision gate v1.2", font=font(28, True), fill=(244, 241, 230))
    draw.text((24, 54), "Architecture approved for Runtime v3. Terrain v1.1 retained; scene geometry and contracts remain authoritative.", font=font(16), fill=(193, 201, 191))
    for index, (label, filename) in enumerate(entries):
        panel = labeled_panel(Image.open(captures / filename), label, (620, 458))
        board.paste(panel, (20 + (index % 2) * 630, 92 + (index // 2) * 468))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def build_detail_board(captures: Path, output: Path) -> None:
    entries = (
        ("NORTHWEST CURRENT", "town_square_northwest_current_v1_2_640x360.png"),
        ("NORTHWEST APPROVED", "town_square_northwest_architecture_v1_2_640x360.png"),
        ("SOUTH CURRENT", "town_square_south_current_v1_2_640x360.png"),
        ("SOUTH APPROVED", "town_square_south_architecture_v1_2_640x360.png"),
        ("DOORWAY CURRENT", "town_square_doorway_current_v1_2_640x360.png"),
        ("DOORWAY APPROVED", "town_square_doorway_architecture_v1_2_640x360.png"),
    )
    board = Image.new("RGB", (1320, 1290), (18, 23, 20))
    draw = ImageDraw.Draw(board)
    draw.text((24, 16), "Town Square scale, pivot, and overlap details", font=font(28, True), fill=(244, 241, 230))
    draw.text((24, 54), "Fixed centers and collisions. Bottom-center structural contact excludes flowers, shadow pixels, and fragments.", font=font(16), fill=(193, 201, 191))
    for index, (label, filename) in enumerate(entries):
        panel = labeled_panel(Image.open(captures / filename), label, (640, 390))
        board.paste(panel, (20 + (index % 2) * 650, 92 + (index // 2) * 400))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("prep_root", type=Path)
    parser.add_argument("render_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    prep_root = assert_external(args.prep_root, "Preparation root")
    render_root = assert_external(args.render_root, "Render root")
    output_root = assert_external(args.output_root, "Output root")
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)

    prep_manifest_path = prep_root / "metadata/town_square_protected_preparation_manifest_v1_2.json"
    render_manifest_path = render_root / "town_square_protected_render_manifest_v1_2.json"
    prep = load_json(prep_manifest_path)
    render = load_json(render_manifest_path)
    if prep.get("scene_sha256") != sha256(SCENE_PATH) or render.get("scene_sha256") != sha256(SCENE_PATH):
        raise RuntimeError("Town Square changed during the protected comparison.")
    if prep.get("generator_sha256") != sha256(PREP_TOOL):
        raise RuntimeError("Preparation tool hash changed.")
    if render.get("render_tool_sha256") != sha256(RENDER_TOOL):
        raise RuntimeError("Render tool hash changed.")
    captures = render_root / "raw_captures"
    for filename in REQUIRED_CAPTURES:
        if not (captures / filename).is_file():
            raise RuntimeError(f"Missing required capture: {filename}")
    small = Image.open(captures / "town_square_doorway_architecture_v1_2_640x360.png").convert("RGBA")
    display = Image.open(captures / "town_square_doorway_architecture_display_v1_2_1280x720.png").convert("RGBA")
    if small.resize((1280, 720), Image.Resampling.NEAREST).tobytes() != display.tobytes():
        raise RuntimeError("Town Square display proof is not exact nearest-neighbor 2x.")
    for record in prep.get("building_candidates", []):
        audit = record.get("post_cleanup_audit", {})
        if any(audit.get(key) != 0 for key in ("partial_alpha_pixels", "canvas_edge_pixels", "transparent_rgb_pixels", "bright_neutral_boundary_pixels")):
            raise RuntimeError(f"Candidate audit regressed: {record.get('source_id')}")
        if audit.get("connected_components") != 1:
            raise RuntimeError(f"Candidate topology regressed: {record.get('source_id')}")

    for relative in ("candidate", "boards"):
        shutil.copytree(prep_root / relative, output_root / relative)
    shutil.copytree(captures, output_root / "captures")
    copy_file(prep_manifest_path, output_root / "metadata/town_square_protected_preparation_manifest_v1_2.json")
    copy_file(render_manifest_path, output_root / "metadata/town_square_protected_render_manifest_v1_2.json")
    copy_file(SCRIPT_PATH, output_root / "tooling" / SCRIPT_PATH.name)
    copy_file(PREP_TOOL, output_root / "tooling" / PREP_TOOL.name)
    copy_file(RENDER_TOOL, output_root / "tooling" / RENDER_TOOL.name)
    copy_file(ARCHITECTURE_MANIFEST, output_root / "baseline" / ARCHITECTURE_MANIFEST.name)
    full_board = output_root / "boards/town_square_full_decision_board_v1_2.png"
    detail_board = output_root / "boards/town_square_detail_decision_board_v1_2.png"
    build_full_board(output_root / "captures", full_board)
    build_detail_board(output_root / "captures", detail_board)

    decision = {
        "schema": "caden-town-square-protected-decision-v1.2",
        "gate_state": "approved_architecture_runtime_v3_terrain_retained_v1_1",
        "terrain_decision": "retain_active_runtime_v1_1",
        "terrain_reason": "Candidate stone is too coarse for the formal civic plaza and weakens the established paving hierarchy.",
        "architecture_decision": "approved_for_versioned_runtime_v3_import",
        "architecture_reason": "All five candidates improve depth, material specificity, and silhouette while preserving existing centers, collisions, corridors, and pivots.",
        "protected_contracts": prep.get("protected_contracts", []),
        "active_reference_changed_during_comparison": False,
        "building_runtime_sha256": {record["slot"]: record["runtime_sha256"] for record in prep["building_candidates"]},
        "tooling_sha256": {
            SCRIPT_PATH.name: sha256(SCRIPT_PATH),
            PREP_TOOL.name: sha256(PREP_TOOL),
            RENDER_TOOL.name: sha256(RENDER_TOOL),
        },
        "provenance_and_licensing": prep.get("provenance_and_licensing", {}),
    }
    write_json(output_root / "metadata/town_square_protected_decision_v1_2.json", decision)
    (output_root / "APPROVAL_DECISION.md").write_text(
        "# Town Square Protected Decision v1.2\n\n"
        "- Architecture: approved for versioned Runtime v3 import.\n"
        "- Terrain: retain active Runtime v1.1.\n"
        "- Geometry, collisions, routes, exits, NPCs, and interactions: unchanged and authoritative.\n"
        "- Town Square concept authority remains limited to palette, materials, lighting, architectural language, and density.\n"
        "- Signs, emblems, central monument, and exact concept geometry remain non-authoritative.\n",
        encoding="utf-8", newline="\n",
    )
    (output_root / "README.md").write_text(
        "# Caden Town Square Protected Review v1.2\n\n"
        "This external package records the terrain-only, architecture-only, and combined comparison. "
        "Open `boards/town_square_full_decision_board_v1_2.png` first, then the detail board for pivot and overlap evidence.\n",
        encoding="utf-8", newline="\n",
    )

    files = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name != "SHA256SUMS.txt")
    sums = "".join(f"{sha256(path)}  {path.relative_to(output_root).as_posix()}\n" for path in files)
    (output_root / "SHA256SUMS.txt").write_text(sums, encoding="utf-8", newline="\n")
    zip_path = output_root.with_suffix(".zip")
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(p for p in output_root.rglob("*") if p.is_file()):
            archive.write(path, (Path(output_root.name) / path.relative_to(output_root)).as_posix())
    print(f"package={output_root}")
    print(f"artifacts={len(files) + 1}")
    print(f"zip={zip_path}")
    print(f"zip_sha256={sha256(zip_path)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise
