#!/usr/bin/env python3
"""Build the approved Town Square tonal terrain v1.3 comparison package."""

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
PREP_TOOL = ROOT / "tools/art/prepare_caden_town_square_tonal_terrain_gate_v1_3.py"
RENDER_TOOL = ROOT / "tools/art/render_caden_town_square_tonal_terrain_gate_v1_3.gd"
SCENE_PATH = ROOT / "scenes/world/caden/TownSquare.tscn"
PAIRS = (
    ("FULL ZONE", "town_square_tonal_full_current_v1_3_960x704.png", "town_square_tonal_full_candidate_v1_3_960x704.png"),
    ("CENTRAL PLAZA", "town_square_tonal_plaza_current_v1_3_640x360.png", "town_square_tonal_plaza_candidate_v1_3_640x360.png"),
    ("MARKETPLACE ARRIVAL", "town_square_tonal_north_current_v1_3_640x360.png", "town_square_tonal_north_candidate_v1_3_640x360.png"),
    ("COMMONS ARRIVAL", "town_square_tonal_south_current_v1_3_640x360.png", "town_square_tonal_south_candidate_v1_3_640x360.png"),
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


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    path = Path("C:/Windows/Fonts") / ("segoeuib.ttf" if bold else "segoeui.ttf")
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def make_board(captures: Path, output: Path) -> None:
    board = Image.new("RGB", (1320, 1800), (18, 23, 20))
    draw = ImageDraw.Draw(board)
    draw.text((24, 16), "Town Square tonal terrain decision v1.3", font=font(30, True), fill=(244, 241, 230))
    draw.text((24, 58), "Approved: source-derived warm palette on the exact v1.1 formal paving pattern and masks.", font=font(16), fill=(193, 201, 191))
    for row, (label, current_name, candidate_name) in enumerate(PAIRS):
        y = 96 + row * 410
        draw.text((24, y), label, font=font(19, True), fill=(235, 226, 183))
        current = Image.open(captures / current_name).convert("RGB")
        candidate = Image.open(captures / candidate_name).convert("RGB")
        current.thumbnail((620, 340), Image.Resampling.NEAREST)
        candidate.thumbnail((620, 340), Image.Resampling.NEAREST)
        board.paste(current, (24, y + 34))
        board.paste(candidate, (676, y + 34))
        draw.text((24, y + 378), "CURRENT v1.1", font=font(14, True), fill=(180, 188, 180))
        draw.text((676, y + 378), "APPROVED TONAL v1.3", font=font(14, True), fill=(180, 188, 180))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("prep_root", type=Path)
    parser.add_argument("render_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    prep_root = args.prep_root.resolve()
    render_root = args.render_root.resolve()
    output_root = args.output_root.resolve()
    for path in (prep_root, render_root, output_root):
        if path == ROOT or ROOT in path.parents:
            raise RuntimeError("Town Square terrain review must remain outside res://.")
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)
    prep_manifest_path = prep_root / "metadata/town_square_tonal_terrain_preparation_v1_3.json"
    render_manifest_path = render_root / "town_square_tonal_terrain_render_manifest_v1_3.json"
    prep = load_json(prep_manifest_path)
    render = load_json(render_manifest_path)
    if prep.get("generator_sha256") != sha256(PREP_TOOL) or render.get("render_tool_sha256") != sha256(RENDER_TOOL):
        raise RuntimeError("Town Square tonal tooling changed after evidence generation.")
    if prep.get("scene_sha256") != sha256(SCENE_PATH) or render.get("scene_sha256") != sha256(SCENE_PATH):
        raise RuntimeError("Town Square changed during the tonal comparison.")
    candidate = prep_root / prep["candidate_path"]
    if sha256(candidate) != prep["candidate_sha256"]:
        raise RuntimeError("Tonal terrain candidate identity mismatch.")
    captures = render_root / "raw_captures"
    if len(list(captures.glob("*.png"))) != 13:
        raise RuntimeError("Expected 13 tonal terrain captures.")
    small = Image.open(captures / "town_square_tonal_plaza_candidate_v1_3_640x360.png").convert("RGBA")
    display = Image.open(captures / "town_square_tonal_plaza_candidate_display_v1_3_1280x720.png").convert("RGBA")
    if small.resize((1280, 720), Image.Resampling.NEAREST).tobytes() != display.tobytes():
        raise RuntimeError("Tonal terrain display proof is not exact nearest-neighbor 2x.")

    shutil.copytree(captures, output_root / "captures")
    shutil.copytree(prep_root / "candidate", output_root / "candidate")
    shutil.copytree(prep_root / "boards", output_root / "boards")
    (output_root / "metadata").mkdir(parents=True, exist_ok=True)
    shutil.copyfile(prep_manifest_path, output_root / "metadata" / prep_manifest_path.name)
    shutil.copyfile(render_manifest_path, output_root / "metadata" / render_manifest_path.name)
    (output_root / "tooling").mkdir(parents=True, exist_ok=True)
    for tool in (SCRIPT_PATH, PREP_TOOL, RENDER_TOOL):
        shutil.copyfile(tool, output_root / "tooling" / tool.name)
    decision_board = output_root / "boards/town_square_tonal_terrain_decision_v1_3.png"
    make_board(output_root / "captures", decision_board)
    decision = {
        "schema": "caden-town-square-tonal-terrain-decision-v1.3",
        "gate_state": "approved_town_square_tonal_terrain_runtime_v1_3",
        "decision": "activate_versioned_tonal_atlas_and_tileset",
        "candidate_sha256": prep["candidate_sha256"],
        "current_v1_1_sha256": prep["current_atlas_sha256"],
        "coarse_v1_2_candidate_status": "rejected_and_not_imported",
        "coarse_v1_2_reason": "Stone units were too large and weakened formal civic paving hierarchy.",
        "v1_3_reason": "The candidate preserves the existing fine formal paving geometry while bringing the palette into pale warm-stone continuity with the other maintained zones.",
        "dirt_rows_byte_identical": True,
        "alpha_topology_identical": True,
        "active_reference_changed_during_comparison": False,
        "tooling_sha256": {tool.name: sha256(tool) for tool in (SCRIPT_PATH, PREP_TOOL, RENDER_TOOL)},
        "provenance_and_licensing": prep["provenance_and_licensing"],
    }
    decision_path = output_root / "metadata/town_square_tonal_terrain_decision_v1_3.json"
    decision_path.write_text(json.dumps(decision, indent=2) + "\n", encoding="utf-8", newline="\n")
    (output_root / "README.md").write_text(
        "# Town Square Tonal Terrain Review v1.3\n\n"
        "The v1.3 candidate is approved. It preserves the exact active pattern, masks, coordinates, and dirt rows while "
        "harmonizing grass and formal paving colors with the source-derived Caden terrain family.\n",
        encoding="utf-8", newline="\n",
    )
    files = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name != "SHA256SUMS.txt")
    (output_root / "SHA256SUMS.txt").write_text(
        "".join(f"{sha256(path)}  {path.relative_to(output_root).as_posix()}\n" for path in files),
        encoding="utf-8", newline="\n",
    )
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
    raise SystemExit(main())
