#!/usr/bin/env python3
"""Build the Caden Residential Quarter contract and candidate approval gate."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
BASELINE_MANIFEST = "residential_baseline_screenshot_manifest_v1.json"
RECOMMENDED = {
    "caden_sp_res_01_fenced_flower_yard_master_v1": "One bounded flower yard establishes a maintained domestic garden without multiplying identical yards.",
    "caden_sp_res_04_woodpile_barrel_fence_master_v1": "Functional winter storage supports a quiet household edge.",
    "caden_sp_res_05_laundry_line_master_v1": "Adds unmistakably domestic activity without dialogue or a new interaction.",
    "caden_sp_res_06_small_garden_patch_master_v1": "Provides one productive garden mass beside a home lane.",
    "caden_sp_res_08_doorstep_flower_cluster_master_v1": "Creates a coherent approach treatment for a fixed home footprint.",
    "caden_sp_res_09_rain_barrels_crates_master_v1": "Reads as practical household storage when placed beside, not in front of, a home.",
    "caden_sp_res_11_stepping_stone_flowers_master_v1": "Connects one doorstep to a lane with a walkable-looking domestic threshold.",
}
ALTERNATES = {
    "caden_sp_res_02_fenced_shrub_yard_master_v1": "Scale-compatible alternate to 01 with less floral emphasis.",
    "caden_sp_res_03_porch_planters_master_v1": "Useful only if a selected runtime house has a compatible porch contact.",
    "caden_sp_res_10_side_yard_storage_master_v1": "Scale-compatible alternate to 09; avoid duplicating the same storage role.",
    "caden_sp_res_13_outdoor_table_stools_master_v1": "Optional social yard detail if it remains private and non-interactive.",
    "caden_sp_res_14_hedge_gate_planter_master_v1": "Potential yard threshold where its locked gate geometry fits a fixed lane.",
    "caden_sp_res_15_domestic_fence_garden_master_v1": "Compact alternate garden edge; avoid using beside another fenced garden composite.",
}
DEFERRED = {
    "caden_sp_res_07_bench_planter_lantern_master_v1": "Overlaps the established civic/rest vocabulary used in other zones.",
    "caden_sp_res_12_shed_fence_woodpile_master_v1": "Contains a locked outbuilding composite that may compete with fixed cabin geometry.",
    "caden_sp_res_16_quiet_tree_bench_yard_master_v1": "Combined canopy, bench, fence, and planter complicate collision and depth sorting.",
    "caden_mega_res_01_fenced_yard_master_v1": "Mega composite remains optional until its locked geometry is proven against an exact yard.",
    "caden_mega_res_02_lane_edge_master_v1": "Mega composite remains optional until its locked geometry is proven against an exact lane edge.",
}
HOME_CENTERS = ((160, 128), (384, 160), (608, 128), (800, 176), (1024, 128), (160, 592), (400, 624), (752, 608), (992, 576), (1024, 256))
FENCE_CENTERS = ((160, 240), (784, 272), (240, 512))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    path = Path("C:/Windows/Fonts") / name
    return ImageFont.truetype(str(path), size) if path.is_file() else ImageFont.load_default()


def verify_package(package_root: Path) -> tuple[list[dict[str, str]], dict[str, object]]:
    checksum_rows = (package_root / "metadata/SHA256SUMS.txt").read_text(encoding="utf-8").splitlines()
    if len(checksum_rows) != 297:
        raise RuntimeError(f"Expected 297 package checksums, found {len(checksum_rows)}.")
    for row in checksum_rows:
        expected, relative = row.split("  ", 1)
        path = package_root / relative
        if not path.is_file() or sha256(path) != expected:
            raise RuntimeError(f"Package checksum mismatch: {relative}")
    with (package_root / "metadata/ASSET_MANIFEST.csv").open(newline="", encoding="utf-8") as handle:
        manifest_rows = list(csv.DictReader(handle))
    if len(manifest_rows) != 222:
        raise RuntimeError(f"Expected 222 manifest rows, found {len(manifest_rows)}.")
    catalog = json.loads((package_root / "metadata/ASSET_CATALOG.json").read_text(encoding="utf-8"))
    if catalog.get("schema") != "caden-asset-catalog-v1.1" or len(catalog.get("assets", [])) != 222:
        raise RuntimeError("Unexpected Caden v1.1 asset catalog.")
    return manifest_rows, catalog


def decision(asset_id: str) -> tuple[str, str]:
    if asset_id in RECOMMENDED:
        return "recommended", RECOMMENDED[asset_id]
    if asset_id in ALTERNATES:
        return "alternate", ALTERNATES[asset_id]
    if asset_id in DEFERRED:
        return "deferred", DEFERRED[asset_id]
    raise RuntimeError(f"Residential candidate lacks a decision: {asset_id}")


def normalize_preview(source: Image.Image, record: dict[str, object]) -> Image.Image:
    rgba = source.convert("RGBA")
    alpha = rgba.getchannel("A")
    histogram = alpha.histogram()
    if sum(histogram[1:255]) != 0 or alpha.getbbox() is None:
        raise RuntimeError(f"Candidate is not hard-alpha: {record['asset_id']}")
    bbox = alpha.getbbox()
    if bbox[0] == 0 or bbox[1] == 0 or bbox[2] == rgba.width or bbox[3] == rgba.height:
        raise RuntimeError(f"Candidate touches its source canvas edge: {record['asset_id']}")
    cropped = rgba.crop(bbox)
    factor = float(record["proposed_scale_factor"])
    resized = cropped.resize((round(cropped.width * factor), round(cropped.height * factor)), Image.Resampling.NEAREST)
    target = tuple(int(value) for value in str(record["proposed_target_dimensions"]).split(","))
    output = Image.new("RGBA", target, (0, 0, 0, 0))
    output.alpha_composite(resized, ((target[0] - resized.width) // 2, (target[1] - resized.height) // 2))
    if output.getbbox() is None or output.getbbox()[0] == 0 or output.getbbox()[1] == 0 or output.getbbox()[2] == target[0] or output.getbbox()[3] == target[1]:
        raise RuntimeError(f"Normalized candidate lacks transparent review padding: {record['asset_id']}")
    return output


def candidate_records(package_root: Path, catalog: dict[str, object]) -> list[dict[str, object]]:
    records = [record for record in catalog["assets"] if str(record["asset_id"]).startswith(("caden_sp_res_", "caden_mega_res_"))]
    if len(records) != 18:
        raise RuntimeError(f"Expected 18 Residential candidates, found {len(records)}.")
    for record in records:
        path = package_root / str(record["package_path"])
        if sha256(path) != record["package_sha256"]:
            raise RuntimeError(f"Catalog hash mismatch: {record['asset_id']}")
        state, reason = decision(str(record["asset_id"]))
        record["gate_decision"] = state
        record["gate_reason"] = reason
    return records


def build_candidate_board(package_root: Path, records: list[dict[str, object]], output_root: Path) -> Path:
    width, cell_width, cell_height, header = 1280, 400, 180, 104
    board = Image.new("RGB", (width, header + 6 * cell_height + 32), (21, 28, 23))
    draw = ImageDraw.Draw(board)
    draw.text((32, 18), "Caden Residential native-scale candidate gate", fill=(247, 243, 230), font=font(28, True))
    draw.text((32, 58), "Every asset shown at proposed runtime scale beside the approved 40x56 player. No candidate is imported.", fill=(186, 199, 188), font=font(15))
    player_sheet = Image.open(ROOT / "assets/characters/caden/player/caden_player_runtime_v1.png").convert("RGBA")
    player = player_sheet.crop((0, 0, 40, 56))
    colors = {"recommended": (77, 151, 99), "alternate": (181, 139, 66), "deferred": (138, 103, 116)}
    for index, record in enumerate(records):
        column, row = index % 3, index // 3
        x, y = 32 + column * cell_width, header + row * cell_height
        state = str(record["gate_decision"])
        draw.rectangle((x, y, x + 376, y + 158), fill=(58, 92, 59), outline=colors[state], width=3)
        for grid_x in range(x, x + 377, 32):
            draw.line((grid_x, y + 96, grid_x, y + 158), fill=(65, 101, 65), width=1)
        for grid_y in range(y + 96, y + 159, 32):
            draw.line((x, grid_y, x + 376, grid_y), fill=(65, 101, 65), width=1)
        asset_id = str(record["asset_id"])
        short = asset_id.replace("caden_sp_res_", "RES ").replace("caden_mega_res_", "MEGA ").replace("_master_v1", "").replace("_", " ")
        draw.text((x + 10, y + 8), short, fill=(242, 240, 231), font=font(14, True))
        draw.text((x + 10, y + 34), state.upper(), fill=colors[state], font=font(12, True))
        draw.text((x + 10, y + 55), f"target {record['proposed_target_dimensions']}  pivot {record['proposed_pivot_xy']}", fill=(207, 214, 206), font=font(11))
        preview = normalize_preview(Image.open(package_root / str(record["package_path"])), record)
        ground_y = y + 150
        board.paste(player, (x + 116, ground_y - 56), player)
        board.paste(preview, (x + 235 - preview.width // 2, ground_y - preview.height), preview)
        draw.line((x + 88, ground_y, x + 310, ground_y), fill=(202, 181, 126), width=1)
    path = output_root / "residential_candidate_scale_board_v1.png"
    board.save(path, compress_level=9)
    return path


def build_composition_plan(baseline_root: Path, output_root: Path) -> Path:
    source = Image.open(baseline_root / "raw_captures/residential_full_zone_before_v1_1152x768.png").convert("RGBA")
    overlay = Image.new("RGBA", source.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    rooms = (
        ((48, 48, 528, 304), (61, 122, 88, 72), "NW household gardens"),
        ((528, 48, 1104, 304), (77, 110, 143, 72), "NE household yards"),
        ((48, 464, 496, 720), (153, 105, 65, 72), "SW quiet homes"),
        ((656, 464, 1104, 720), (118, 83, 135, 72), "SE garden homes"),
    )
    for bounds, color, label in rooms:
        draw.rectangle(bounds, fill=color, outline=(*color[:3], 220), width=3)
        draw.text((bounds[0] + 12, bounds[1] + 10), label, fill=(255, 255, 246, 255), font=font(17, True))
    route_color = (224, 195, 101, 90)
    for bounds in ((0, 320, 1152, 448), (512, 448, 640, 768), (224, 96, 288, 320), (864, 96, 928, 320), (256, 448, 320, 672), (896, 448, 960, 672)):
        draw.rectangle(bounds, fill=route_color, outline=(238, 210, 118, 220), width=2)
    for index, (x, y) in enumerate(HOME_CENTERS, start=1):
        draw.rectangle((x - 64, y - 48, x + 64, y + 48), outline=(246, 238, 215, 255), width=3)
        draw.text((x - 12, y - 10), f"H{index}", fill=(246, 238, 215, 255), font=font(14, True))
    for index, (x, y) in enumerate(FENCE_CENTERS, start=1):
        draw.rectangle((x - 96, y - 12, x + 96, y + 12), outline=(232, 154, 82, 255), width=3)
        draw.text((x - 10, y - 9), f"F{index}", fill=(255, 232, 205, 255), font=font(12, True))
    draw.text((22, 338), "Town Square primary route: protected 128 px", fill=(32, 28, 20, 255), font=font(16, True))
    draw.text((520, 686), "Commons route", fill=(32, 28, 20, 255), font=font(15, True))
    plan = Image.alpha_composite(source, overlay).convert("RGB")
    path = output_root / "residential_full_zone_composition_plan_v1.png"
    plan.save(path, compress_level=9)
    return path


def write_readme(output_root: Path) -> Path:
    path = output_root / "RESIDENTIAL_RECONSTRUCTION_GATE_V1.md"
    path.write_text(
        """# Caden Residential Quarter reconstruction gate v1

Review the untouched `1152 x 768` full-zone baseline first, then the contract overlay and native-scale candidate board.

The live scene is an early greybox with ten fixed `128 x 96` cabin bodies, three fixed fence bodies, a protected 128-pixel west-east route, a 128-pixel Commons route, four household lanes, two interactive NPCs, and two transitions. No scene file or library asset is modified by this gate.

All 24 available Residential/townwide house masters remain rejected for unsuitable baked shadows. The recommended set-piece shortlist is `01`, `04`, `05`, `06`, `08`, `09`, and `11`. Each requires exact `0.1875` nearest-neighbor normalization, removal of broad presentation shadows and fringe, structural ground pivots, object-specific collision, and a second visual audit before import.

Approval selects candidates for a limited Residential runtime pass. It does not authorize an alternate, deferred asset, mega composite, rejected house master, Commons work, new dialogue, lore, signs, businesses, or gameplay changes.
""",
        encoding="utf-8",
        newline="\n",
    )
    return path


def write_gate_manifest(package_root: Path, baseline_root: Path, output_root: Path, records: list[dict[str, object]], rejected_buildings: list[dict[str, object]]) -> Path:
    tools = (ROOT / "tools/art/render_caden_residential_baseline_v1.gd", ROOT / "tools/art/build_caden_residential_reconstruction_gate_v1.py")
    manifest = {
        "schema": "caden-residential-reconstruction-gate-v1",
        "gate_state": "residential_candidate_selection_pending_visual_approval",
        "scene": "res://scenes/world/caden/Residential.tscn",
        "scene_sha256": sha256(ROOT / "scenes/world/caden/Residential.tscn"),
        "source_package": str(package_root),
        "source_package_policy": "Complete source library remains outside res://; no candidate imported by this gate.",
        "catalog_rows_verified": 222,
        "package_checksums_verified": 297,
        "contract": {
            "bounds": [0, 0, 1152, 768],
            "home_centers": [list(value) for value in HOME_CENTERS],
            "home_collision": [128, 96],
            "fence_centers": [list(value) for value in FENCE_CENTERS],
            "fence_collision": [192, 24],
            "entries": {"from_town_square": [128, 384], "from_commons": [576, 640]},
            "exits": {"to_town_square": [64, 384], "to_commons": [576, 704]},
            "protected_routes": [[0, 320, 1152, 128], [512, 448, 128, 320]],
            "interactive_npcs": ["HomeResident", "PathResident"],
        },
        "candidates": records,
        "rejected_buildings": [{"asset_id": row["asset_id"], "status": row["status"], "reason": row["rejection_reasons"]} for row in rejected_buildings],
        "tools": {path.relative_to(ROOT).as_posix(): sha256(path) for path in tools},
        "baseline_manifest_sha256": sha256(baseline_root / BASELINE_MANIFEST),
        "rights_status": "project_internal_rights_unverified",
        "distribution_status": "do_not_publish_until_rights_are_verified",
    }
    path = output_root / "residential_reconstruction_gate_manifest_v1.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    return path


def write_checksums(output_root: Path) -> Path:
    path = output_root / "SHA256SUMS.txt"
    files = sorted(item for item in output_root.rglob("*") if item.is_file() and item != path)
    path.write_text("".join(f"{sha256(item)}  {item.relative_to(output_root).as_posix()}\n" for item in files), encoding="utf-8", newline="\n")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package_root", type=Path)
    parser.add_argument("baseline_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    package_root, baseline_root, output_root = (value.resolve() for value in (args.package_root, args.baseline_root, args.output_root))
    if output_root == ROOT or ROOT in output_root.parents:
        raise RuntimeError("Gate materials must remain outside res://.")
    output_root.mkdir(parents=True, exist_ok=True)
    _manifest_rows, catalog = verify_package(package_root)
    records = candidate_records(package_root, catalog)
    rejected_buildings = [row for row in catalog["assets"] if (str(row["asset_id"]).startswith("caden_bld_home_") or str(row["asset_id"]).startswith("caden_bld_res_")) and str(row["status"]).startswith("rejected_")]
    if len(rejected_buildings) != 24:
        raise RuntimeError(f"Expected 24 rejected Residential/townwide building masters, found {len(rejected_buildings)}.")
    baseline_manifest = json.loads((baseline_root / BASELINE_MANIFEST).read_text(encoding="utf-8"))
    if baseline_manifest.get("scene_sha256") != sha256(ROOT / "scenes/world/caden/Residential.tscn"):
        raise RuntimeError("Residential scene changed after baseline capture.")
    for capture in baseline_manifest.get("captures", []):
        capture_path = baseline_root / "raw_captures" / capture["filename"]
        if not capture_path.is_file() or sha256(capture_path) != capture["sha256"]:
            raise RuntimeError(f"Residential baseline capture mismatch: {capture_path}")
    with Image.open(baseline_root / "raw_captures/residential_primary_route_before_v1_640x360.png") as native:
        expected_display = native.convert("RGBA").resize((1280, 720), Image.Resampling.NEAREST)
    with Image.open(baseline_root / "raw_captures/residential_primary_display_before_v1_1280x720.png") as display:
        if expected_display.tobytes() != display.convert("RGBA").tobytes():
            raise RuntimeError("Residential 1280x720 proof is not an exact nearest-neighbor 2x enlargement.")
    shutil.copytree(baseline_root / "raw_captures", output_root / "raw_captures", dirs_exist_ok=True)
    shutil.copy2(baseline_root / BASELINE_MANIFEST, output_root)
    candidate_board = build_candidate_board(package_root, records, output_root)
    composition_plan = build_composition_plan(baseline_root, output_root)
    readme = write_readme(output_root)
    gate_manifest = write_gate_manifest(package_root, baseline_root, output_root, records, rejected_buildings)
    provenance = package_root / "docs/PROVENANCE_AND_LICENSE.md"
    if provenance.is_file():
        shutil.copy2(provenance, output_root / provenance.name)
    checksums = write_checksums(output_root)
    print(f"candidate_board={candidate_board}")
    print(f"composition_plan={composition_plan}")
    print(f"readme={readme}")
    print(f"gate_manifest={gate_manifest}")
    print(f"checksums={checksums}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
