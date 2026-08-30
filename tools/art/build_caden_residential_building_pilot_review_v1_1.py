#!/usr/bin/env python3
"""Build the external in-engine review package for the Residential building pilot."""

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
BUILDING_MANIFEST_PATH = ROOT / "assets/environments/caden/residential/buildings/residential_building_pilot_manifest_v1_1.json"
IMPORT_TOOL_PATH = ROOT / "tools/art/import_caden_residential_building_pilot_v1_1.py"
RENDER_TOOL_PATH = ROOT / "tools/art/render_caden_residential_building_pilot_v1_1.gd"
TEST_PATH = ROOT / "tests/caden_residential_runtime_test.gd"

PAIRS = (
    ("full_zone", "residential_full_zone_current_v1_1_1152x768.png", "residential_full_zone_pilot_v1_1_1152x768.png", "Full zone"),
    ("north", "residential_north_current_v1_1_640x360.png", "residential_north_pilot_v1_1_640x360.png", "North homes"),
    ("south", "residential_south_current_v1_1_640x360.png", "residential_south_pilot_v1_1_640x360.png", "South homes"),
    ("entrance", "residential_entrance_current_v1_1_640x360.png", "residential_entrance_pilot_v1_1_640x360.png", "Northwest threshold with player"),
)
ACTIVE_ONLY = (
    ("residential_west_arrival_pilot_v1_1_640x360.png", "West arrival"),
    ("residential_primary_route_pilot_v1_1_640x360.png", "Primary route"),
    ("residential_commons_transition_pilot_v1_1_640x360.png", "Commons transition"),
    ("residential_cabin02_player_front_pilot_v1_1_640x360.png", "Cabin02 overlap"),
    ("residential_cabin07_player_front_pilot_v1_1_640x360.png", "Cabin07 overlap"),
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
    filename = "segoeuib.ttf" if bold else "segoeui.ttf"
    path = Path("C:/Windows/Fonts") / filename
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def assert_external(path: Path, label: str) -> Path:
    resolved = path.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise RuntimeError(f"{label} must remain outside the Godot project tree.")
    return resolved


def verify_gate(gate_root: Path) -> None:
    checksum_path = gate_root / "SHA256SUMS.txt"
    lines = [line for line in checksum_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != 47:
        raise RuntimeError("Gate 0 no longer has 47 checksummed artifacts.")
    for line in lines:
        digest, relative = line.split("  ", 1)
        artifact = gate_root / Path(relative)
        if not artifact.is_file() or sha256(artifact) != digest:
            raise RuntimeError(f"Gate 0 checksum mismatch: {relative}")


def verify_render(render_root: Path) -> dict:
    manifest_path = render_root / "residential_building_pilot_screenshot_manifest_v1_1.json"
    manifest = load_json(manifest_path)
    if manifest.get("gate_state") != "active_pilot_pending_in_engine_visual_approval":
        raise RuntimeError("Unexpected active render gate state.")
    captures = manifest.get("captures", [])
    if len(captures) != 10:
        raise RuntimeError("Expected ten active pilot captures.")
    for record in captures:
        path = render_root / "raw_captures" / record["filename"]
        if not path.is_file() or sha256(path) != record["sha256"]:
            raise RuntimeError(f"Active capture hash mismatch: {path.name}")
    primary = Image.open(render_root / "raw_captures/residential_primary_route_pilot_v1_1_640x360.png").convert("RGBA")
    display = Image.open(render_root / "raw_captures/residential_primary_display_pilot_v1_1_1280x720.png").convert("RGBA")
    proof = primary.resize((1280, 720), Image.Resampling.NEAREST)
    if proof.tobytes() != display.tobytes():
        raise RuntimeError("The 1280x720 presentation proof is not an exact nearest-neighbor 2x image.")
    return manifest


def panel(image: Image.Image, width: int, height: int) -> Image.Image:
    contained = image.copy()
    contained.thumbnail((width, height), Image.Resampling.NEAREST)
    output = Image.new("RGB", (width, height), (30, 34, 31))
    x = (width - contained.width) // 2
    y = (height - contained.height) // 2
    output.paste(contained.convert("RGB"), (x, y))
    return output


def build_board(before_root: Path, after_root: Path, output_path: Path) -> None:
    width = 1440
    margin = 40
    gutter = 24
    column_width = (width - margin * 2 - gutter) // 2
    title_height = 122
    label_height = 40
    pair_heights = [455, 405, 405, 405]
    active_height = 395
    active_rows = 3
    height = title_height + sum(label_height + value + 34 for value in pair_heights) + active_rows * (label_height + active_height + 34) + 80
    board = Image.new("RGB", (width, height), (239, 237, 229))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 26), "CADEN RESIDENTIAL BUILDING PILOT v1.1", font=font(32, True), fill=(40, 46, 41))
    draw.text((margin, 70), "Existing composition vs active ten-house pilot. Terrain, routes, Cabin anchors, and collision remain unchanged.", font=font(18), fill=(75, 79, 73))
    y = title_height
    for index, (_, before_name, after_name, title) in enumerate(PAIRS):
        draw.text((margin, y), f"{title} | BEFORE", font=font(19, True), fill=(70, 73, 67))
        draw.text((margin + column_width + gutter, y), f"{title} | PILOT", font=font(19, True), fill=(70, 73, 67))
        y += label_height
        with Image.open(before_root / before_name) as before_image, Image.open(after_root / after_name) as after_image:
            board.paste(panel(before_image.convert("RGBA"), column_width, pair_heights[index]), (margin, y))
            board.paste(panel(after_image.convert("RGBA"), column_width, pair_heights[index]), (margin + column_width + gutter, y))
        y += pair_heights[index] + 34

    for row in range(active_rows):
        left_index = row * 2
        right_index = left_index + 1
        for column, item_index in enumerate((left_index, right_index)):
            if item_index >= len(ACTIVE_ONLY):
                continue
            filename, title = ACTIVE_ONLY[item_index]
            x = margin + column * (column_width + gutter)
            draw.text((x, y), f"PILOT CHECK | {title}", font=font(19, True), fill=(70, 73, 67))
            with Image.open(after_root / filename) as active_image:
                board.paste(panel(active_image.convert("RGBA"), column_width, active_height), (x, y + label_height))
        y += label_height + active_height + 34
    draw.text((margin, height - 56), "Approval gate: accept, request targeted alignment changes, or reject the ten-house pilot. Terrain remains deferred.", font=font(18, True), fill=(91, 66, 39))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(output_path)


def copy_review_inputs(gate_root: Path, render_root: Path, output_root: Path) -> dict[str, str]:
    before_root = output_root / "comparison/before"
    after_root = output_root / "comparison/pilot"
    before_root.mkdir(parents=True, exist_ok=True)
    after_root.mkdir(parents=True, exist_ok=True)
    hashes: dict[str, str] = {}
    gate_capture_root = gate_root / "residential_comparison/raw_captures"
    render_capture_root = render_root / "raw_captures"
    for _, before_name, after_name, _ in PAIRS:
        before_output = before_root / before_name
        after_output = after_root / after_name
        shutil.copy2(gate_capture_root / before_name, before_output)
        shutil.copy2(render_capture_root / after_name, after_output)
        hashes[before_output.relative_to(output_root).as_posix()] = sha256(before_output)
        hashes[after_output.relative_to(output_root).as_posix()] = sha256(after_output)
    for filename, _ in ACTIVE_ONLY:
        output = after_root / filename
        shutil.copy2(render_capture_root / filename, output)
        hashes[output.relative_to(output_root).as_posix()] = sha256(output)
    display_name = "residential_primary_display_pilot_v1_1_1280x720.png"
    display_output = after_root / display_name
    shutil.copy2(render_capture_root / display_name, display_output)
    hashes[display_output.relative_to(output_root).as_posix()] = sha256(display_output)
    return hashes


def write_docs(output_root: Path) -> None:
    docs = output_root / "docs"
    docs.mkdir(parents=True, exist_ok=True)
    (docs / "README.md").write_text(
        "# Caden Residential Building Pilot v1.1\n\n"
        "This is the active in-engine approval gate for the ten Residential house replacements approved from Gate 0. "
        "The comparison uses matched live-scene cameras. Residential terrain, roads, Cabin anchors and collision, landscaping, NPCs, entries, exits, and all other zones remain unchanged. "
        "The retained laundry and small garden assets moved one tile north on grass to clear the taller south roofs; their object-specific collision shapes and depth behavior remain intact.\n\n"
        "Review `boards/residential_building_pilot_comparison_v1_1.png`, then record accept, targeted correction, or rejection. "
        "No terrain replacement or additional building integration is authorized by this package.\n",
        encoding="utf-8",
        newline="\n",
    )
    (docs / "APPROVAL_CHECKLIST.md").write_text(
        "# Visual Approval Checklist\n\n"
        "- [ ] Ten houses read as one coherent Residential family without repetitive reuse.\n"
        "- [ ] Structural ground contacts align with the retained Cabin collision and threshold line.\n"
        "- [ ] No clipped edges, checker matte, guide remnants, detached fragments, bright fringe, or broad baked shadow are visible.\n"
        "- [ ] North and south rows remain readable around existing yards, trees, props, and roads.\n"
        "- [ ] Player overlap at Cabin02 and Cabin07 reads cleanly.\n"
        "- [ ] West arrival and Commons transition remain visually open.\n"
        "- [ ] Terrain remains the approved existing Residential terrain.\n\n"
        "Decision: ACCEPT / TARGETED CORRECTIONS / REJECT\n",
        encoding="utf-8",
        newline="\n",
    )
    (docs / "PROVENANCE_AND_LICENSE.md").write_text(
        "# Provenance and Licensing\n\n"
        "The project owner supplied the source masters through local Downloads intake. The creator, generation tool, license, and derivative permission were not documented in the supplied materials. "
        "Rights remain `project_internal_rights_unverified`; do not publish or ship these derivatives until rights are verified. The complete masters remain outside `res://`.\n",
        encoding="utf-8",
        newline="\n",
    )
    (docs / "TOOLING_REQUIREMENTS.md").write_text(
        "# Tooling Requirements\n\n"
        "- Godot 4.7.2, Compatibility renderer\n"
        "- Python 3.12\n"
        "- Pillow 12.3 for offline pixel audit and comparison-board assembly\n\n"
        "These are preparation and evidence tools only. No new game runtime dependency was introduced.\n",
        encoding="utf-8",
        newline="\n",
    )


def build_package(gate_root: Path, render_root: Path, output_root: Path) -> Path:
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError(f"Review output must not already contain files: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)
    capture_hashes = copy_review_inputs(gate_root, render_root, output_root)
    board_path = output_root / "boards/residential_building_pilot_comparison_v1_1.png"
    build_board(output_root / "comparison/before", output_root / "comparison/pilot", board_path)
    write_docs(output_root)

    metadata_root = output_root / "metadata"
    tooling_root = output_root / "tooling"
    metadata_root.mkdir(parents=True, exist_ok=True)
    tooling_root.mkdir(parents=True, exist_ok=True)
    shutil.copy2(BUILDING_MANIFEST_PATH, metadata_root / BUILDING_MANIFEST_PATH.name)
    shutil.copy2(render_root / "residential_building_pilot_screenshot_manifest_v1_1.json", metadata_root / "residential_building_pilot_screenshot_manifest_v1_1.json")
    for source in (IMPORT_TOOL_PATH, RENDER_TOOL_PATH, SCRIPT_PATH, TEST_PATH):
        shutil.copy2(source, tooling_root / source.name)

    manifest = {
        "schema": "caden-residential-building-pilot-review-package-v1.1",
        "gate_state": "active_ten_house_pilot_pending_visual_approval",
        "scope": "Residential building exteriors plus two one-tile background set-piece alignment corrections; no terrain or broad five-zone integration.",
        "source_gate_root": str(gate_root),
        "source_gate_package_manifest_sha256": sha256(gate_root / "metadata/package_manifest_v1_1.json"),
        "active_render_manifest_sha256": sha256(render_root / "residential_building_pilot_screenshot_manifest_v1_1.json"),
        "scene_sha256": sha256(SCENE_PATH),
        "building_manifest_sha256": sha256(BUILDING_MANIFEST_PATH),
        "comparison_board_sha256": sha256(board_path),
        "before_after_pairs": 4,
        "active_runtime_checks": len(ACTIVE_ONLY),
        "runtime_asset_count": 10,
        "population": {"dialogue_npcs": 2, "ambient_walkers": 5, "total_visible_npcs": 7},
        "terrain_status": "existing Residential terrain retained; replacement deferred",
        "exact_2x_primary_proof": True,
        "tooling": {"godot": "4.7.2-stable Compatibility", "python": "3.12", "pillow": "12.3", "runtime_dependencies_added": []},
        "tool_hashes": {f"tooling/{path.name}": sha256(path) for path in (IMPORT_TOOL_PATH, RENDER_TOOL_PATH, SCRIPT_PATH, TEST_PATH)},
        "provenance_and_licensing": {
            "provided_by": "project owner via local Downloads intake",
            "creator_or_generation_tool": "not documented",
            "rights_status": "project_internal_rights_unverified",
            "distribution_status": "do_not_publish_or_ship_until rights are verified",
        },
        "supporting_alignment_adjustments": load_json(BUILDING_MANIFEST_PATH).get("supporting_alignment_adjustments", []),
        "protected_live_contracts": ["Cabin anchors and collision", "terrain and roads", "selected prop assets and collision shapes", "landscaping", "NPCs and dialogue", "entries and exits", "all non-Residential zones"],
        "artifacts": capture_hashes,
    }
    manifest_path = metadata_root / "package_manifest_v1_1.json"
    write_json(manifest_path, manifest)

    files = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name != "SHA256SUMS.txt")
    checksum_path = output_root / "SHA256SUMS.txt"
    checksum_path.write_text("".join(f"{sha256(path)}  {path.relative_to(output_root).as_posix()}\n" for path in files), encoding="utf-8", newline="\n")
    for path in output_root.rglob("*"):
        if path.is_file() and (path.name.startswith(".") or path.suffix in {".uid", ".import", ".pyc"} or "__pycache__" in path.parts):
            raise RuntimeError(f"Hidden or generated build artifact entered review package: {path}")

    zip_path = output_root.with_suffix(".zip")
    if zip_path.exists():
        raise RuntimeError(f"Review ZIP already exists: {zip_path}")
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
    parser.add_argument("render_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    gate_root = assert_external(args.gate_root, "Gate root")
    render_root = assert_external(args.render_root, "Render root")
    output_root = assert_external(args.output_root, "Review output")
    verify_gate(gate_root)
    verify_render(render_root)
    build_package(gate_root, render_root, output_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
