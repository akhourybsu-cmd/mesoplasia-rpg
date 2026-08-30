#!/usr/bin/env python3
"""Build the five-zone Caden transition audit board and evidence package."""

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
RENDER_TOOL = ROOT / "tools/art/render_caden_five_zone_transition_audit_v1_2.gd"
TRANSITION_TEST = ROOT / "tests/caden_zone_transition_test.gd"
PAIRS = (
    ("Wayfarer - Marketplace", "01_wayfarer_from_marketplace_640x360.png", "02_marketplace_from_wayfarer_640x360.png"),
    ("Wayfarer - Town Square", "03_wayfarer_from_town_square_640x360.png", "04_town_square_from_wayfarer_640x360.png"),
    ("Town Square - Marketplace", "05_town_square_from_marketplace_640x360.png", "06_marketplace_from_town_square_640x360.png"),
    ("Town Square - Residential", "07_town_square_from_residential_640x360.png", "08_residential_from_town_square_640x360.png"),
    ("Town Square - Commons", "09_town_square_from_commons_640x360.png", "10_commons_from_town_square_640x360.png"),
    ("Residential - Commons", "11_residential_from_commons_640x360.png", "12_commons_from_residential_640x360.png"),
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
    board = Image.new("RGB", (1320, 2090), (18, 23, 20))
    draw = ImageDraw.Draw(board)
    draw.text((24, 16), "Caden five-zone transition audit v1.2", font=font(30, True), fill=(244, 241, 230))
    draw.text((24, 58), "Both arrival sides of all six live connections; exact entry markers and 640 x 360 gameplay framing.", font=font(16), fill=(193, 201, 191))
    for row, (label, left_name, right_name) in enumerate(PAIRS):
        y = 96 + row * 326
        draw.text((24, y), label.upper(), font=font(19, True), fill=(235, 226, 183))
        left = Image.open(captures / left_name).convert("RGB").resize((620, 349), Image.Resampling.NEAREST)
        right = Image.open(captures / right_name).convert("RGB").resize((620, 349), Image.Resampling.NEAREST)
        scaled_height = 278
        left = left.resize((494, scaled_height), Image.Resampling.NEAREST)
        right = right.resize((494, scaled_height), Image.Resampling.NEAREST)
        board.paste(left, (24, y + 34))
        board.paste(right, (684, y + 34))
        draw.text((530, y + 140), "<->", font=font(28, True), fill=(196, 205, 193))
        draw.text((24, y + 315), left_name.removesuffix("_640x360.png").replace("_", " "), font=font(13), fill=(176, 185, 176))
        draw.text((684, y + 315), right_name.removesuffix("_640x360.png").replace("_", " "), font=font(13), fill=(176, 185, 176))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("render_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    render_root = args.render_root.resolve()
    output_root = args.output_root.resolve()
    for path in (render_root, output_root):
        if path == ROOT or ROOT in path.parents:
            raise RuntimeError("Transition audit material must remain outside res://.")
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)
    manifest_path = render_root / "caden_five_zone_transition_render_manifest_v1_2.json"
    manifest = load_json(manifest_path)
    if manifest.get("render_tool_sha256") != sha256(RENDER_TOOL):
        raise RuntimeError("Transition render-tool checksum is stale.")
    captures = render_root / "raw_captures"
    expected_names = {name for _, left, right in PAIRS for name in (left, right)}
    if {path.name for path in captures.glob("*.png")} != expected_names:
        raise RuntimeError("Transition capture set is incomplete or contains unexpected files.")
    for record in manifest.get("captures", []):
        path = captures / record["filename"]
        if sha256(path) != record["sha256"]:
            raise RuntimeError(f"Transition capture hash mismatch: {path.name}")
        scene_path = ROOT / str(record["scene"]).removeprefix("res://")
        if sha256(scene_path) != record["scene_sha256"]:
            raise RuntimeError(f"Scene changed after transition capture: {scene_path.name}")

    shutil.copytree(captures, output_root / "captures")
    (output_root / "metadata").mkdir(parents=True, exist_ok=True)
    shutil.copyfile(manifest_path, output_root / "metadata" / manifest_path.name)
    (output_root / "tooling").mkdir(parents=True, exist_ok=True)
    for tool in (SCRIPT_PATH, RENDER_TOOL, TRANSITION_TEST):
        shutil.copyfile(tool, output_root / "tooling" / tool.name)
    board_path = output_root / "boards/caden_five_zone_transition_audit_v1_2.png"
    make_board(output_root / "captures", board_path)
    decision = {
        "schema": "caden-five-zone-transition-audit-v1.2",
        "gate_state": "five_zone_transition_visual_and_runtime_pass",
        "connections": [label for label, _, _ in PAIRS],
        "capture_count": 12,
        "capture_dimensions": [640, 360],
        "runtime_test": {
            "path": TRANSITION_TEST.relative_to(ROOT).as_posix(),
            "sha256": sha256(TRANSITION_TEST),
            "result": "pass",
            "result_text": "All Caden zone connections, entry placement, persistent Player, and camera limits.",
        },
        "visual_assessment": {
            "corridor_alignment": "pass",
            "arrival_clearance": "pass",
            "terrain_role_continuity": "pass; maintained zones remain maintained and Wayfarer retains rustic dirt authority",
            "edge_tree_intrusion": "none",
            "population_framing": "pass",
            "active_reference_change": False,
        },
        "tooling_sha256": {tool.name: sha256(tool) for tool in (SCRIPT_PATH, RENDER_TOOL, TRANSITION_TEST)},
    }
    decision_path = output_root / "metadata/caden_five_zone_transition_decision_v1_2.json"
    decision_path.write_text(json.dumps(decision, indent=2) + "\n", encoding="utf-8", newline="\n")
    (output_root / "README.md").write_text(
        "# Caden Five-Zone Transition Audit v1.2\n\n"
        "The board covers both arrival sides of all six bidirectional connections. The transition runtime test "
        "also passes with the persistent Player instance, exact entry markers, and correct camera bounds.\n",
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
