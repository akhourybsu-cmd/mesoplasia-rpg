#!/usr/bin/env python3
"""Build the Caden Commons contract and candidate approval gate."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
BASELINE_MANIFEST = "commons_baseline_screenshot_manifest_v1.json"
RECOMMENDED = {
    "caden_sp_com_01_large_tree_shrubs_master_v1": "Strong single-tree boundary anchor with a readable structural contact.",
    "caden_sp_com_04_three_tree_grove_master_v1": "One restrained grove can establish the northwest natural anchor without filling the Quiet Green.",
    "caden_sp_com_09_wildflower_meadow_master_v1": "Walkable low meadow texture supports the open green without adding a solid obstacle.",
    "caden_sp_com_11_rock_shrub_cluster_master_v1": "Natural replacement candidate for the fixed southwest rock footprint.",
    "caden_sp_com_14_dense_undergrowth_edge_master_v1": "Useful as a limited boundary mass where it cannot obscure a transition.",
    "caden_sp_com_20_quiet_bench_rocks_wildflowers_master_v1": "One quiet rest pocket beside a path fits the zone without creating civic density.",
}
ALTERNATES = {
    "caden_sp_com_02_large_tree_flowers_rocks_master_v1": "Scale-compatible alternate to 01 with a more decorative base.",
    "caden_sp_com_03_medium_tree_pair_master_v1": "Lighter alternate grove for an existing tree footprint.",
    "caden_sp_com_05_tree_stump_wildflowers_master_v1": "Natural alternate where a slightly wilder edge is desirable.",
    "caden_sp_com_08_hedge_tree_boundary_master_v1": "Compatible boundary alternate, but its hedge geometry is less flexible.",
    "caden_sp_com_10_tall_grass_flowers_master_v1": "Alternate low planting with more occlusion than the meadow candidate.",
    "caden_sp_com_12_stump_log_cluster_master_v1": "Compact alternate for the southwest natural obstacle role.",
    "caden_sp_com_13_low_hedge_corner_master_v1": "Corrected candidate suitable only where its corner geometry matches the boundary.",
    "caden_sp_com_15_bench_tree_flowers_master_v1": "Alternate rest pocket if its combined canopy sorts cleanly in-engine.",
    "caden_sp_com_18_path_edge_rest_pocket_master_v1": "Alternate to 20 with a more structured path-edge composition.",
}
DEFERRED = {
    "caden_sp_com_06_tree_fallen_log_master_v1": "Combined trunk and long log require more collision and passage proof than this shortlist needs.",
    "caden_sp_com_07_tree_wall_boundary_master_v1": "Rigid wall geometry risks making the open Commons read fortified or boxed in.",
    "caden_sp_com_16_two_benches_lantern_master_v1": "Paired seating and lantern read too civic and duplicate the single rest-pocket role.",
    "caden_sp_com_17_fence_shrubs_blank_sign_master_v1": "Even a blank sign introduces unnecessary sign authority and a rigid fence cluster.",
    "caden_sp_com_19_rustic_shade_shelter_master_v1": "A shelter is specifically outside the Commons brief and competes with open green space.",
    "caden_seam_tsq_com_a_master_v1": "A paired seam would modify the already validated Town Square and is unnecessary for terrain continuity.",
    "caden_seam_tsq_com_b_master_v1": "A paired seam would modify the already validated Town Square and is unnecessary for terrain continuity.",
    "caden_mega_com_01_maintained_grove_master_v1": "Locked mega geometry is unnecessary when the fixed tree footprints can be dressed individually.",
    "caden_mega_com_02_rest_area_master_v1": "Locked mega rest-area geometry would over-author the quiet green and complicate collision.",
}
OBSTACLES = {
    "TreeCluster01": {"center": (192, 160), "collision": (96, 96)},
    "TreeCluster02": {"center": (800, 224), "collision": (96, 96)},
    "TreeCluster03": {"center": (768, 512), "collision": (96, 96)},
    "RockCluster": {"center": (288, 544), "collision": (64, 48)},
}


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
    raise RuntimeError(f"Commons candidate lacks a decision: {asset_id}")


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
    bounds = output.getbbox()
    if bounds is None or bounds[0] == 0 or bounds[1] == 0 or bounds[2] == target[0] or bounds[3] == target[1]:
        raise RuntimeError(f"Normalized candidate lacks transparent review padding: {record['asset_id']}")
    return output


def candidate_records(package_root: Path, catalog: dict[str, object]) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    records = [record for record in catalog["assets"] if str(record["asset_id"]).startswith(("caden_sp_com_", "caden_mega_com_", "caden_seam_tsq_com_"))]
    rejected = [record for record in catalog["assets"] if str(record["asset_id"]).startswith("caden_seam_res_com_")]
    if len(records) != 24 or len(rejected) != 2:
        raise RuntimeError(f"Expected 24 viable and 2 rejected Commons candidates, found {len(records)} and {len(rejected)}.")
    for record in records:
        path = package_root / str(record["package_path"])
        if sha256(path) != record["package_sha256"]:
            raise RuntimeError(f"Catalog hash mismatch: {record['asset_id']}")
        state, reason = decision(str(record["asset_id"]))
        record["gate_decision"] = state
        record["gate_reason"] = reason
    return records, rejected


def build_candidate_board(package_root: Path, records: list[dict[str, object]], output_root: Path) -> Path:
    width, cell_width, cell_height, header = 1420, 340, 184, 108
    board = Image.new("RGB", (width, header + 6 * cell_height + 32), (21, 28, 23))
    draw = ImageDraw.Draw(board)
    draw.text((32, 18), "Caden Commons native-scale candidate gate", fill=(247, 243, 230), font=font(28, True))
    draw.text((32, 60), "All 24 viable sources at proposed runtime scale beside the approved 40x56 player. No source is imported.", fill=(186, 199, 188), font=font(15))
    player_sheet = Image.open(ROOT / "assets/characters/caden/player/caden_player_runtime_v1.png").convert("RGBA")
    player = player_sheet.crop((0, 0, 40, 56))
    colors = {"recommended": (77, 151, 99), "alternate": (181, 139, 66), "deferred": (138, 103, 116)}
    for index, record in enumerate(records):
        column, row = index % 4, index // 4
        x, y = 32 + column * cell_width, header + row * cell_height
        state = str(record["gate_decision"])
        draw.rectangle((x, y, x + 318, y + 162), fill=(58, 92, 59), outline=colors[state], width=3)
        for grid_x in range(x, x + 319, 32):
            draw.line((grid_x, y + 100, grid_x, y + 162), fill=(65, 101, 65), width=1)
        for grid_y in range(y + 100, y + 163, 32):
            draw.line((x, grid_y, x + 318, grid_y), fill=(65, 101, 65), width=1)
        asset_id = str(record["asset_id"])
        short = asset_id.replace("caden_sp_com_", "COM ").replace("caden_mega_com_", "MEGA ").replace("caden_seam_tsq_com_", "SEAM ").replace("_master_v1", "").replace("_", " ")
        draw.text((x + 9, y + 7), short[:38], fill=(242, 240, 231), font=font(12, True))
        draw.text((x + 9, y + 29), state.upper(), fill=colors[state], font=font(11, True))
        draw.text((x + 9, y + 48), f"target {record['proposed_target_dimensions']}  pivot {record['proposed_pivot_xy']}", fill=(207, 214, 206), font=font(10))
        preview = normalize_preview(Image.open(package_root / str(record["package_path"])), record)
        ground_y = y + 154
        board.paste(player, (x + 90, ground_y - 56), player)
        board.paste(preview, (x + 220 - preview.width // 2, ground_y - preview.height), preview)
        draw.line((x + 70, ground_y, x + 278, ground_y), fill=(202, 181, 126), width=1)
    path = output_root / "commons_candidate_scale_board_v1.png"
    board.save(path, compress_level=9)
    return path


def build_composition_plan(baseline_root: Path, output_root: Path) -> Path:
    source = Image.open(baseline_root / "raw_captures/commons_full_zone_before_v1_1024x704.png").convert("RGBA")
    overlay = Image.new("RGBA", source.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.rectangle((608, 96, 960, 608), fill=(79, 139, 86, 65), outline=(151, 210, 151, 235), width=4)
    draw.text((628, 116), "Dominant anchor: open Quiet Green", fill=(248, 248, 230, 255), font=font(18, True))
    draw.text((628, 143), "Keep mostly walkable and undecorated", fill=(236, 241, 222, 255), font=font(14))
    for bounds, label, label_xy in (
        ((48, 48, 400, 256), "NW maintained grove", (58, 57)),
        ((48, 448, 416, 656), "SW natural edge", (58, 457)),
        ((640, 448, 960, 656), "SE planted boundary", (650, 626)),
    ):
        draw.rectangle(bounds, fill=(49, 105, 70, 55), outline=(114, 178, 124, 220), width=3)
        draw.text(label_xy, label, fill=(247, 246, 227, 255), font=font(15, True))
    for bounds in ((0, 288, 576, 416), (448, 0, 576, 416)):
        draw.rectangle(bounds, fill=(224, 195, 101, 80), outline=(238, 210, 118, 230), width=3)
    draw.text((20, 310), "Town Square route: protected 128 px", fill=(34, 29, 20, 255), font=font(16, True))
    draw.text((458, 44), "Residential route", fill=(34, 29, 20, 255), font=font(14, True))
    for name, record in OBSTACLES.items():
        x, y = record["center"]
        width, height = record["collision"]
        draw.rectangle((x - width // 2, y - height // 2, x + width // 2, y + height // 2), outline=(247, 236, 211, 255), width=3)
        draw.text((x - 44, y - 10), name.replace("Cluster", ""), fill=(247, 236, 211, 255), font=font(12, True))
    for x, y, label, label_xy in (
        (384, 240, "possible rest pocket", (404, 231)),
        (608, 432, "path-edge rest pocket", (628, 414)),
    ):
        draw.ellipse((x - 12, y - 12, x + 12, y + 12), fill=(219, 153, 92, 220))
        draw.text(label_xy, label, fill=(255, 230, 204, 255), font=font(12, True))
    plan = Image.alpha_composite(source, overlay).convert("RGB")
    path = output_root / "commons_full_zone_composition_plan_v1.png"
    plan.save(path, compress_level=9)
    return path


def write_readme(output_root: Path) -> Path:
    path = output_root / "COMMONS_RECONSTRUCTION_GATE_V1.md"
    path.write_text(
        """# Caden Commons reconstruction gate v1

Review the untouched `1024 x 704` full-zone baseline first, then the contract overlay and native-scale candidate board.

The live scene is an early greybox with a protected `128`-pixel west approach from Town Square, a protected `128`-pixel north approach from Residential, three fixed `96 x 96` tree-cluster bodies, one fixed `64 x 48` rock body, one interactive resident, two transitions, and a large eastern Quiet Green. No scene file or Commons library source is modified by this gate.

The recommended shortlist is `01`, `04`, `09`, `11`, `14`, and `20`. It supplies one strong tree anchor, one restrained grove, walkable meadow color, a natural rock cluster, limited boundary undergrowth, and one quiet rest pocket. The open Quiet Green remains the dominant anchor and must stay mostly walkable.

The paired Town Square seams, both mega composites, shade shelter, sign cluster, civic seating cluster, and rigid tree-wall options remain deferred. Both Residential/Commons seam sources remain rejected for boundary fringe. Approval selects only the recommended shortlist for a limited Commons runtime pass; it does not authorize an alternate, deferred, rejected, seam, mega, pond, bridge, gazebo, stage, shrine, monument, new dialogue, lore, or gameplay change.
""",
        encoding="utf-8",
        newline="\n",
    )
    return path


def write_gate_manifest(package_root: Path, baseline_root: Path, output_root: Path, records: list[dict[str, object]], rejected: list[dict[str, object]]) -> Path:
    tools = (
        ROOT / "tools/art/render_caden_commons_baseline_v1.gd",
        ROOT / "tools/art/build_caden_commons_reconstruction_gate_v1.py",
        ROOT / "tests/caden_commons_contract_test.gd",
    )
    manifest = {
        "schema": "caden-commons-reconstruction-gate-v1",
        "gate_state": "commons_candidate_selection_pending_visual_approval",
        "scene": "res://scenes/world/caden/Commons.tscn",
        "scene_sha256": sha256(ROOT / "scenes/world/caden/Commons.tscn"),
        "source_package": str(package_root),
        "source_package_policy": "Complete source library remains outside res://; no Commons candidate imported by this gate.",
        "catalog_rows_verified": 222,
        "package_checksums_verified": 297,
        "contract": {
            "bounds": [0, 0, 1024, 704],
            "entries": {"from_town_square": [128, 352], "from_residential": [512, 128]},
            "exits": {"to_town_square": [64, 352], "to_residential": [512, 64]},
            "protected_routes": [[0, 288, 576, 128], [448, 0, 128, 416]],
            "quiet_green": [608, 128, 320, 448],
            "fixed_obstacles": OBSTACLES,
            "interactive_npcs": ["CommonsLocal"],
        },
        "candidates": records,
        "rejected_residential_commons_seams": [{"asset_id": row["asset_id"], "status": row["status"], "reason": row.get("rejection_reasons", "boundary fringe")} for row in rejected],
        "tools": {path.relative_to(ROOT).as_posix(): sha256(path) for path in tools},
        "baseline_manifest_sha256": sha256(baseline_root / BASELINE_MANIFEST),
        "rights_status": "project_internal_rights_unverified",
        "distribution_status": "do_not_publish_until_rights_are_verified",
    }
    path = output_root / "commons_reconstruction_gate_manifest_v1.json"
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
    records, rejected = candidate_records(package_root, catalog)
    baseline_manifest = json.loads((baseline_root / BASELINE_MANIFEST).read_text(encoding="utf-8"))
    if baseline_manifest.get("scene_sha256") != sha256(ROOT / "scenes/world/caden/Commons.tscn"):
        raise RuntimeError("Commons scene changed after baseline capture.")
    for capture in baseline_manifest.get("captures", []):
        capture_path = baseline_root / "raw_captures" / capture["filename"]
        if not capture_path.is_file() or sha256(capture_path) != capture["sha256"]:
            raise RuntimeError(f"Commons baseline capture mismatch: {capture_path}")
    with Image.open(baseline_root / "raw_captures/commons_route_junction_before_v1_640x360.png") as native:
        expected_display = native.convert("RGBA").resize((1280, 720), Image.Resampling.NEAREST)
    with Image.open(baseline_root / "raw_captures/commons_route_display_before_v1_1280x720.png") as display:
        if expected_display.tobytes() != display.convert("RGBA").tobytes():
            raise RuntimeError("Commons 1280x720 proof is not an exact nearest-neighbor 2x enlargement.")
    shutil.copytree(baseline_root / "raw_captures", output_root / "raw_captures", dirs_exist_ok=True)
    shutil.copy2(baseline_root / BASELINE_MANIFEST, output_root)
    candidate_board = build_candidate_board(package_root, records, output_root)
    composition_plan = build_composition_plan(baseline_root, output_root)
    readme = write_readme(output_root)
    gate_manifest = write_gate_manifest(package_root, baseline_root, output_root, records, rejected)
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
