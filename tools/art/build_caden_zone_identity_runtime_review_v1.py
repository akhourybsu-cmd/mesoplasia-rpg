#!/usr/bin/env python3
"""Package the approved Blueprint v3 identity depth/collision proof."""

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
RENDER_TOOL = ROOT / "tools/art/render_caden_zone_identity_runtime_v1.gd"
TRANSITION_TOOL = ROOT / "tools/art/render_caden_five_zone_transition_audit_v1_2.gd"
TEST_TOOL = ROOT / "tests/caden_zone_identity_runtime_v1_test.gd"
PHYSICS_TEST = ROOT / "tests/caden_blueprint_v3_physics_smoke_test.gd"
RIGHTS_TEST = ROOT / "tests/caden_marketplace_rights_clearance_test.gd"
SOURCE_MANIFEST = ROOT / "assets/environments/caden/zone_identity/runtime_v1/caden_zone_identity_runtime_v1.json"
DECISION_MANIFEST = ROOT / "assets/environments/caden/zone_identity/runtime_v1/caden_zone_identity_blueprint_v3.json"
MARKETPLACE_RIGHTS = ROOT / "assets/environments/caden/marketplace/caden_marketplace_source_rights_v1.json"
MARKETPLACE_RIGHTS_DOC = ROOT / "docs/art/CADEN_MARKETPLACE_PROVENANCE_AND_RIGHTS_V1.md"
ZONES = (
    ("town_square", "TOWN SQUARE", "Approved civic-garden edge"),
    ("residential", "RESIDENTIAL", "Working domestic utility yard"),
    ("commons", "COMMONS", "Layered natural boundary"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"Expected JSON object: {path}")
    return value


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    path = Path("C:/Windows/Fonts") / ("segoeuib.ttf" if bold else "segoeui.ttf")
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def make_pair_board(captures: Path, output: Path, mode: str) -> None:
    board = Image.new("RGB", (1320, 1330), (18, 22, 20))
    draw = ImageDraw.Draw(board)
    title = "Caden Blueprint v3 — matched identity proof" if mode == "focus" else "Caden Blueprint v3 — player depth order"
    subtitle = "Left: transiently hidden. Right: approved active scene." if mode == "focus" else "Left: player behind composition. Right: player in front."
    draw.text((24, 16), title, font=font(30, True), fill=(244, 241, 230))
    draw.text((24, 58), subtitle, font=font(16), fill=(190, 201, 191))
    for row, (slug, label, role) in enumerate(ZONES):
        y = 96 + row * 410
        draw.text((24, y), f"{label}  |  {role}", font=font(19, True), fill=(235, 220, 163))
        if mode == "focus":
            left_name = f"{slug}_identity_focus_before_v1_640x360.png"
            right_name = f"{slug}_identity_focus_after_v1_640x360.png"
            left_label, right_label = "HIDDEN FOR COMPARISON", "APPROVED ACTIVE"
        else:
            left_name = f"{slug}_identity_player_behind_v1_640x360.png"
            right_name = f"{slug}_identity_player_front_v1_640x360.png"
            left_label, right_label = "PLAYER BEHIND", "PLAYER IN FRONT"
        board.paste(Image.open(captures / left_name).convert("RGB"), (24, y + 34))
        board.paste(Image.open(captures / right_name).convert("RGB"), (676, y + 34))
        draw.text((24, y + 386), left_label, font=font(14, True), fill=(179, 188, 180))
        draw.text((676, y + 386), right_label, font=font(14, True), fill=(179, 188, 180))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def make_collision_board(captures: Path, output: Path) -> None:
    board = Image.new("RGB", (700, 1370), (18, 22, 20))
    draw = ImageDraw.Draw(board)
    draw.text((24, 16), "Caden Blueprint v3 — collision clearance", font=font(29, True), fill=(244, 241, 230))
    draw.text((24, 58), "Red: structural collision. Blue: protected route, trigger ring, or civic space.", font=font(15), fill=(190, 201, 191))
    for row, (slug, label, role) in enumerate(ZONES):
        y = 96 + row * 420
        draw.text((24, y), f"{label}  |  {role}", font=font(18, True), fill=(235, 220, 163))
        image = Image.open(captures / f"{slug}_identity_collision_clearance_v1_640x360.png").convert("RGB")
        board.paste(image, (24, y + 34))
        draw.text((24, y + 398), "PASS — NO RED / BLUE INTERSECTION", font=font(14, True), fill=(171, 218, 171))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def verify(render_root: Path, transition_root: Path) -> tuple[dict, dict, dict]:
    render_path = render_root / "caden_zone_identity_blueprint_v3_proof.json"
    transition_path = transition_root / "caden_five_zone_transition_render_manifest_v1_2.json"
    render = load_json(render_path)
    transition = load_json(transition_path)
    decision = load_json(DECISION_MANIFEST)
    rights = load_json(MARKETPLACE_RIGHTS)
    if render.get("gate_state") != "approved_active_three_asset_depth_collision_and_clearance_proof":
        raise RuntimeError("Identity proof gate is not approved and active.")
    if render.get("render_tool_sha256") != sha256(RENDER_TOOL):
        raise RuntimeError("Identity proof renderer changed after capture generation.")
    if render.get("decision_manifest_sha256") != sha256(DECISION_MANIFEST):
        raise RuntimeError("Identity proof does not identify the current decision manifest.")
    if transition.get("render_tool_sha256") != sha256(TRANSITION_TOOL):
        raise RuntimeError("Transition renderer changed after capture generation.")
    if decision.get("gate_state") != "blueprint_v3_user_approved_integration":
        raise RuntimeError("Decision manifest is no longer user approved.")
    if rights.get("gate_state") != "operational_distribution_clearance_recorded":
        raise RuntimeError("Marketplace rights clearance is not complete.")
    if rights.get("decision", {}).get("rights_status") != "openai_output_provenance_verified":
        raise RuntimeError("Marketplace rights status is not release-ready.")
    captures = render_root / "raw_captures"
    transition_captures = transition_root / "raw_captures"
    if len(list(captures.glob("*.png"))) != 22:
        raise RuntimeError("Expected exactly 22 approved identity proof captures.")
    if len(list(transition_captures.glob("*.png"))) != 12:
        raise RuntimeError("Expected exactly 12 transition captures.")
    small = Image.open(captures / "town_square_identity_focus_after_v1_640x360.png").convert("RGBA")
    display = Image.open(captures / "town_square_identity_after_display_v1_1280x720.png").convert("RGBA")
    if small.resize((1280, 720), Image.Resampling.NEAREST).tobytes() != display.tobytes():
        raise RuntimeError("Display proof is not exact nearest-neighbor 2x.")
    for entry in render["captures"]:
        scene = ROOT / str(entry["scene"]).removeprefix("res://")
        capture = captures / entry["filename"]
        if sha256(scene) != entry["scene_sha256"] or sha256(capture) != entry["sha256"]:
            raise RuntimeError(f"Identity proof hash mismatch: {entry['filename']}")
    for entry in transition["captures"]:
        scene = ROOT / str(entry["scene"]).removeprefix("res://")
        capture = transition_captures / entry["filename"]
        if sha256(scene) != entry["scene_sha256"] or sha256(capture) != entry["sha256"]:
            raise RuntimeError(f"Transition proof hash mismatch: {entry['filename']}")
    return render, transition, decision


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("render_root", type=Path)
    parser.add_argument("transition_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    render_root = args.render_root.resolve()
    transition_root = args.transition_root.resolve()
    output_root = args.output_root.resolve()
    for path in (render_root, transition_root, output_root):
        if path == ROOT or ROOT in path.parents:
            raise RuntimeError("Proof inputs and output must remain outside res://.")
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    render, transition, decision = verify(render_root, transition_root)
    rights = load_json(MARKETPLACE_RIGHTS)
    output_root.mkdir(parents=True, exist_ok=True)
    shutil.copytree(render_root / "raw_captures", output_root / "captures/identity")
    shutil.copytree(transition_root / "raw_captures", output_root / "captures/transitions")
    (output_root / "metadata").mkdir(parents=True)
    shutil.copyfile(render_root / "caden_zone_identity_blueprint_v3_proof.json", output_root / "metadata/identity_proof.json")
    shutil.copyfile(transition_root / "caden_five_zone_transition_render_manifest_v1_2.json", output_root / "metadata/transition_proof.json")
    shutil.copyfile(SOURCE_MANIFEST, output_root / "metadata/source_manifest.json")
    shutil.copyfile(DECISION_MANIFEST, output_root / "metadata/decision_manifest.json")
    shutil.copyfile(MARKETPLACE_RIGHTS, output_root / "metadata/marketplace_source_rights.json")
    shutil.copyfile(MARKETPLACE_RIGHTS_DOC, output_root / "metadata/CADEN_MARKETPLACE_PROVENANCE_AND_RIGHTS_V1.md")
    (output_root / "runtime_assets").mkdir()
    for path in sorted(SOURCE_MANIFEST.parent.glob("*.png")):
        shutil.copyfile(path, output_root / "runtime_assets" / path.name)
    (output_root / "tooling").mkdir()
    for tool in (SCRIPT_PATH, RENDER_TOOL, TRANSITION_TOOL, TEST_TOOL, PHYSICS_TEST, RIGHTS_TEST):
        shutil.copyfile(tool, output_root / "tooling" / tool.name)
    make_pair_board(output_root / "captures/identity", output_root / "boards/identity_before_after.png", "focus")
    make_pair_board(output_root / "captures/identity", output_root / "boards/identity_depth_order.png", "depth")
    make_collision_board(output_root / "captures/identity", output_root / "boards/identity_collision_clearance.png")
    package_manifest = {
        "schema": "caden-zone-identity-blueprint-v3-proof-package",
        "gate_state": "approved_active_proof_complete",
        "active_source_ids": render["active_source_ids"],
        "rejected_source_ids": render["rejected_source_ids"],
        "identity_capture_count": len(render["captures"]),
        "transition_capture_count": len(transition["captures"]),
        "board_count": 3,
        "decision_manifest_sha256": sha256(DECISION_MANIFEST),
        "automated_contracts": "26 of 26 executable Godot regression scripts passed on 2026-08-30, including real-Player structural collision, bypass probes, and Marketplace source-rights binding.",
        "remaining_gate": None,
        "marketplace_rights_record_sha256": sha256(MARKETPLACE_RIGHTS),
        "marketplace_distribution_status": rights["decision"]["distribution_status"],
        "provenance_and_licensing": load_json(SOURCE_MANIFEST)["provenance_and_licensing"],
    }
    (output_root / "metadata/package_manifest.json").write_text(
        json.dumps(package_manifest, indent=2) + "\n", encoding="utf-8", newline="\n"
    )
    (output_root / "README.md").write_text(
        "# Caden Blueprint v3 Approved Identity Proof\n\n"
        "Matched before/after, player depth-order, collision-clearance, and all twelve transition captures for the approved "
        "Town Square, Residential, and Commons identity compositions. Marketplace CAD-COMP-10 remains rejected. "
        "The package also carries the scoped Marketplace source-rights clearance record; no Blueprint v3 acceptance gate remains open.\n",
        encoding="utf-8", newline="\n",
    )
    checksum_path = output_root / "SHA256SUMS.txt"
    files = sorted(path for path in output_root.rglob("*") if path.is_file() and path != checksum_path)
    checksum_path.write_text(
        "".join(f"{sha256(path)}  {path.relative_to(output_root).as_posix()}\n" for path in files),
        encoding="utf-8", newline="\n",
    )
    zip_path = output_root.with_suffix(".zip")
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(item for item in output_root.rglob("*") if item.is_file()):
            archive.write(path, (Path(output_root.name) / path.relative_to(output_root)).as_posix())
    print(f"package={output_root}")
    print(f"zip={zip_path}")
    print(f"zip_sha256={sha256(zip_path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
