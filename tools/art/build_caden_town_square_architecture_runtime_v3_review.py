#!/usr/bin/env python3
"""Build active Town Square Runtime v3 verification evidence."""

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
SCENE_PATH = ROOT / "scenes/world/caden/TownSquare.tscn"
RUNTIME_MANIFEST = ROOT / "assets/environments/caden/architecture/town_square/caden_architecture_runtime_v3_manifest.json"
RENDER_TOOL = ROOT / "tools/art/render_caden_town_square_architecture_runtime_v3.gd"
IMPORT_TOOL = ROOT / "tools/art/import_caden_town_square_architecture_runtime_v3.py"
EXPECTED_AUTHORIZATION_ZIP_SHA256 = "7ce5860927274ec7bfb8b3beb7247a5d32e81f737f5015742a1dc45234f675cd"
MATCHES = {
    "town_square_full_architecture_v1_2_960x704.png": "town_square_runtime_v3_full_960x704.png",
    "town_square_northwest_architecture_v1_2_640x360.png": "town_square_runtime_v3_northwest_640x360.png",
    "town_square_south_architecture_v1_2_640x360.png": "town_square_runtime_v3_south_640x360.png",
    "town_square_doorway_architecture_v1_2_640x360.png": "town_square_runtime_v3_doorway_640x360.png",
}


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


def copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def make_board(before: Path, after: Path, output: Path) -> None:
    board = Image.new("RGB", (1280, 570), (18, 23, 20))
    draw = ImageDraw.Draw(board)
    draw.text((24, 16), "Town Square architecture Runtime v3", font=font(29, True), fill=(244, 241, 230))
    draw.text((24, 56), "Active scene pixel-matches the approved architecture-only pass; Terrain Runtime v1.1 is retained.", font=font(16), fill=(193, 201, 191))
    for index, (label, path) in enumerate((("BEFORE: Runtime v2", before), ("AFTER: Runtime v3", after))):
        draw.text((24 + index * 628, 92), label, font=font(18, True), fill=(231, 229, 217))
        image = Image.open(path).convert("RGB").resize((600, 440), Image.Resampling.NEAREST)
        board.paste(image, (24 + index * 628, 120))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("authorization_root", type=Path)
    parser.add_argument("render_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    authorization_root = args.authorization_root.resolve()
    render_root = args.render_root.resolve()
    output_root = args.output_root.resolve()
    for path in (authorization_root, render_root, output_root):
        if path == ROOT or ROOT in path.parents:
            raise RuntimeError("Review material must remain outside res://.")
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)
    if sha256(authorization_root.with_suffix(".zip")) != EXPECTED_AUTHORIZATION_ZIP_SHA256:
        raise RuntimeError("Town Square authorization package identity mismatch.")
    runtime_manifest = load_json(RUNTIME_MANIFEST)
    render_manifest_path = render_root / "town_square_architecture_runtime_v3_render_manifest.json"
    render_manifest = load_json(render_manifest_path)
    if runtime_manifest.get("gate_state") != "town_square_architecture_runtime_v3_visual_approved":
        raise RuntimeError("Runtime v3 manifest is not approved.")
    if render_manifest.get("render_tool_sha256") != sha256(RENDER_TOOL):
        raise RuntimeError("Runtime v3 render tool changed.")
    authorization_captures = authorization_root / "captures"
    active_captures = render_root / "raw_captures"
    for approved_name, active_name in MATCHES.items():
        approved = Image.open(authorization_captures / approved_name).convert("RGBA")
        active = Image.open(active_captures / active_name).convert("RGBA")
        if approved.size != active.size or approved.tobytes() != active.tobytes():
            raise RuntimeError(f"Active scene differs from approved comparison: {active_name}")
    doorway = Image.open(active_captures / "town_square_runtime_v3_doorway_640x360.png").convert("RGBA")
    display = Image.open(active_captures / "town_square_runtime_v3_doorway_display_1280x720.png").convert("RGBA")
    if doorway.resize((1280, 720), Image.Resampling.NEAREST).tobytes() != display.tobytes():
        raise RuntimeError("Active Runtime v3 display proof is not exact nearest-neighbor 2x.")

    shutil.copytree(active_captures, output_root / "captures")
    copy(render_manifest_path, output_root / "metadata" / render_manifest_path.name)
    copy(RUNTIME_MANIFEST, output_root / "metadata" / RUNTIME_MANIFEST.name)
    copy(authorization_root / "metadata/town_square_protected_decision_v1_2.json", output_root / "metadata/town_square_protected_decision_v1_2.json")
    copy(authorization_root / "boards/town_square_full_decision_board_v1_2.png", output_root / "authorization/town_square_full_decision_board_v1_2.png")
    for tool in (SCRIPT_PATH, RENDER_TOOL, IMPORT_TOOL):
        copy(tool, output_root / "tooling" / tool.name)
    for record in runtime_manifest["generated_buildings"].values():
        path = ROOT / record["path"]
        if sha256(path) != record["sha256"]:
            raise RuntimeError(f"Runtime v3 asset identity mismatch: {path.name}")
        copy(path, output_root / "runtime" / path.name)
    board_path = output_root / "boards/town_square_runtime_v3_before_after.png"
    make_board(
        authorization_captures / "town_square_full_current_v1_2_960x704.png",
        active_captures / "town_square_runtime_v3_full_960x704.png",
        board_path,
    )
    approval = {
        "schema": "caden-town-square-architecture-runtime-v3-approval",
        "gate_state": "town_square_architecture_runtime_v3_active_verified",
        "scene": SCENE_PATH.relative_to(ROOT).as_posix(),
        "scene_sha256": sha256(SCENE_PATH),
        "authorization_package_sha256": EXPECTED_AUTHORIZATION_ZIP_SHA256,
        "runtime_manifest_sha256": sha256(RUNTIME_MANIFEST),
        "matched_approved_captures": MATCHES,
        "exact_pixel_match": True,
        "terrain_runtime_v1_1_retained": True,
        "tooling_sha256": {tool.name: sha256(tool) for tool in (SCRIPT_PATH, RENDER_TOOL, IMPORT_TOOL)},
    }
    approval_path = output_root / "metadata/town_square_architecture_runtime_v3_approval.json"
    approval_path.write_text(json.dumps(approval, indent=2) + "\n", encoding="utf-8", newline="\n")
    (output_root / "README.md").write_text(
        "# Town Square Architecture Runtime v3\n\n"
        "The active serialized scene pixel-matches the approved architecture-only comparison. "
        "Terrain Runtime v1.1, geometry, collisions, routes, exits, interactions, and population remain unchanged.\n",
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
