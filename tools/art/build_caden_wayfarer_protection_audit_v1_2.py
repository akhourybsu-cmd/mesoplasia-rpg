#!/usr/bin/env python3
"""Package the Wayfarer v5 protected-baseline retention audit."""

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
SCENE_PATH = ROOT / "scenes/world/caden/WayfarersApproach.tscn"
RENDER_TOOL = ROOT / "tools/art/render_caden_wayfarer_structural_recomposition_v5.gd"
WAYFARER_TEST = ROOT / "tests/caden_wayfarers_approach_runtime_test.gd"
SURFACE_MANIFEST = ROOT / "assets/environments/caden/wayfarers_approach/terrain/composed_v1/wayfarers_landscape_surfaces_v1.json"
PILOT_MANIFEST = ROOT / "assets/environments/caden/wayfarers_approach/wayfarers_approach_pilot_runtime_v1.json"


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


def verify_checksums(root: Path) -> int:
    lines = [line for line in (root / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != 27:
        raise RuntimeError(f"Approved Wayfarer v5 checksum count changed: {len(lines)}")
    for line in lines:
        digest, relative = line.split("  ", 1)
        artifact = root / Path(relative)
        if not artifact.is_file() or sha256(artifact) != digest:
            raise RuntimeError(f"Approved Wayfarer v5 checksum mismatch: {relative}")
    return len(lines)


def make_board(captures: Path, output: Path) -> None:
    board = Image.new("RGB", (1280, 980), (18, 23, 20))
    draw = ImageDraw.Draw(board)
    draw.text((24, 16), "Wayfarer's Approach v5 protection audit", font=font(29, True), fill=(244, 241, 230))
    draw.text((24, 56), "Retain approved v5. All 14 active captures byte-match; no narrowly justified terrain experiment exists.", font=font(16), fill=(193, 201, 191))
    full = Image.open(captures / "wayfarer_full_zone_after_v5_1024x640.png").convert("RGB").resize((768, 480), Image.Resampling.NEAREST)
    board.paste(full, (24, 96))
    draw.text((820, 106), "PROTECTED CONTRACTS", font=font(18, True), fill=(231, 229, 217))
    notes = (
        "1024 x 640 zone and camera bounds\n"
        "Dirt carriage-road hierarchy\n"
        "Inn precinct and authored surfaces\n"
        "Traveler yard and rest grove\n"
        "Pilot 05 / 07 collision and sorting\n"
        "Entries, exits, NPCs, dialogue\n\n"
        "MATERIAL DECISION\n"
        "A grass-only swap would conflict with\n"
        "grass embedded in eight composed surfaces.\n"
        "No visible threshold seam warrants a rebuild."
    )
    draw.multiline_text((820, 146), notes, font=font(16), fill=(206, 211, 202), spacing=9)
    entries = (
        ("PRIMARY ROUTE", "wayfarer_primary_gameplay_after_v5_640x360.png"),
        ("INN PRECINCT", "wayfarer_inn_precinct_after_v5_640x360.png"),
        ("REST GROVE", "wayfarer_rest_grove_after_v5_640x360.png"),
    )
    for index, (label, filename) in enumerate(entries):
        x = 24 + index * 414
        draw.text((x, 604), label, font=font(17, True), fill=(231, 229, 217))
        image = Image.open(captures / filename).convert("RGB").resize((400, 225), Image.Resampling.NEAREST)
        board.paste(image, (x, 636))
    draw.text((24, 898), "Decision: no active-reference change. Current v5 remains the stronger coherent landscape.", font=font(20, True), fill=(235, 226, 183))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline_root", type=Path)
    parser.add_argument("render_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    baseline_root = args.baseline_root.resolve()
    render_root = args.render_root.resolve()
    output_root = args.output_root.resolve()
    for path in (baseline_root, render_root, output_root):
        if path == ROOT or ROOT in path.parents:
            raise RuntimeError("Wayfarer audit material must remain outside res://.")
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Output root is not empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)
    verify_checksums(baseline_root)
    baseline_captures = baseline_root / "raw_captures"
    active_captures = render_root / "raw_captures"
    active_files = sorted(active_captures.glob("*.png"))
    if len(active_files) != 14:
        raise RuntimeError(f"Expected 14 active Wayfarer captures, found {len(active_files)}")
    for current in active_files:
        prior = baseline_captures / current.name
        if not prior.is_file() or sha256(prior) != sha256(current):
            raise RuntimeError(f"Active Wayfarer no longer matches approved v5: {current.name}")
    render_manifest_path = render_root / "wayfarer_structural_recomposition_screenshot_manifest_v5.json"
    render_manifest = load_json(render_manifest_path)
    if render_manifest.get("render_tool_sha256") != sha256(RENDER_TOOL):
        raise RuntimeError("Wayfarer render-tool checksum is stale.")
    small = Image.open(active_captures / "wayfarer_primary_gameplay_after_v5_640x360.png").convert("RGBA")
    display = Image.open(active_captures / "wayfarer_primary_display_after_v5_1280x720.png").convert("RGBA")
    if small.resize((1280, 720), Image.Resampling.NEAREST).tobytes() != display.tobytes():
        raise RuntimeError("Wayfarer display proof is not exact nearest-neighbor 2x.")

    shutil.copytree(active_captures, output_root / "captures")
    copy(render_manifest_path, output_root / "metadata" / render_manifest_path.name)
    copy(baseline_root / "wayfarer_structural_recomposition_review_manifest_v5.json", output_root / "metadata/wayfarer_structural_recomposition_review_manifest_v5.json")
    copy(SURFACE_MANIFEST, output_root / "metadata" / SURFACE_MANIFEST.name)
    copy(PILOT_MANIFEST, output_root / "metadata" / PILOT_MANIFEST.name)
    copy(baseline_root / "metadata/SOURCE_PROVENANCE_AND_LICENSE.md", output_root / "metadata/SOURCE_PROVENANCE_AND_LICENSE.md")
    copy(baseline_root / "wayfarer_structural_recomposition_comparison_board_v5.png", output_root / "baseline/wayfarer_structural_recomposition_comparison_board_v5.png")
    for tool in (SCRIPT_PATH, RENDER_TOOL, WAYFARER_TEST):
        copy(tool, output_root / "tooling" / tool.name)
    board_path = output_root / "boards/wayfarer_v5_protection_audit_v1_2.png"
    make_board(output_root / "captures", board_path)
    decision = {
        "schema": "caden-wayfarer-protection-audit-v1.2",
        "gate_state": "wayfarer_v5_retained_no_candidate_justified",
        "decision": "retain_active_wayfarer_v5_unchanged",
        "scene": SCENE_PATH.relative_to(ROOT).as_posix(),
        "scene_sha256": sha256(SCENE_PATH),
        "capture_count": 14,
        "all_active_captures_byte_match_v5": True,
        "terrain_experiment": "not_created",
        "terrain_reason": "A grass-only replacement would mismatch grass embedded in eight approved authored surfaces; no documented building-threshold seam warrants rebuilding them.",
        "architecture_decision": "retain_current_inn_per_explicit_protection_contract",
        "pilot_decision": "retain_only_05_and_07",
        "active_reference_changed": False,
        "surface_manifest_sha256": sha256(SURFACE_MANIFEST),
        "pilot_manifest_sha256": sha256(PILOT_MANIFEST),
        "tooling_sha256": {tool.name: sha256(tool) for tool in (SCRIPT_PATH, RENDER_TOOL, WAYFARER_TEST)},
    }
    decision_path = output_root / "metadata/wayfarer_protection_decision_v1_2.json"
    decision_path.write_text(json.dumps(decision, indent=2) + "\n", encoding="utf-8", newline="\n")
    (output_root / "README.md").write_text(
        "# Wayfarer's Approach Protection Audit v1.2\n\n"
        "The active scene remains an exact visual match for the approved v5 baseline. No candidate was created because "
        "the available grass-only substitution would introduce seams across the authored surface system.\n",
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
