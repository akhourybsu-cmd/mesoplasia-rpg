#!/usr/bin/env python3
"""Build the review-only Marketplace reconstruction and candidate gate package."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
BASELINE_MANIFEST = "marketplace_baseline_screenshot_manifest_v1.json"
FULL_ZONE = "marketplace_full_zone_before_v1_896x640.png"
CANDIDATE_STAGE = "marketplace_candidate_stage_before_v1_640x360.png"
BOARD_NAME = "marketplace_native_scale_candidate_board_v1.png"
PLAN_NAME = "marketplace_full_zone_composition_plan_v1.png"
PACKAGE_MANIFEST = "marketplace_reconstruction_gate_manifest_v1.json"
CHECKSUMS = "SHA256SUMS.txt"

CANDIDATES = {
    "caden_sp_mkt_01_produce_crate_display_master_v1": ("recommended", "Distinct produce frontage; fits one fixed stall bay."),
    "caden_sp_mkt_02_bread_basket_display_master_v1": ("alternate", "Scale-compatible food display; redundant with the produce frontage."),
    "caden_sp_mkt_03_folded_cloth_display_master_v1": ("recommended", "Adds controlled canopy-free color and a compact customer face."),
    "caden_sp_mkt_04_pottery_jars_display_master_v1": ("recommended", "Clear merchandise silhouette within one fixed stall bay."),
    "caden_sp_mkt_05_travel_supply_display_master_v1": ("deferred", "Traveler identity overlaps Wayfarer and still needs partial-alpha review."),
    "caden_sp_mkt_06_barrel_sack_storage_master_v1": ("recommended", "Useful rear-of-stall backstock cluster; partial alpha must be cleaned if selected."),
    "caden_sp_mkt_07_vendor_counter_mixed_goods_master_v1": ("recommended", "Best candidate for a primary canopied vendor anchor; partial alpha must be cleaned."),
    "caden_sp_mkt_08_market_corner_canopy_master_v1": ("alternate", "Strong secondary anchor, but its visual span exceeds one greybox bay."),
    "caden_sp_mkt_11_market_aisle_edge_master_v1": ("alternate", "Useful only as a restrained perimeter edge; too linear for a primary stall."),
    "caden_sp_mkt_13_empty_crates_barrels_master_v1": ("recommended", "Neutral rear service storage that does not invent a vendor identity."),
    "caden_sp_mkt_14_shopfront_supply_cluster_master_v1": ("recommended", "Compact mixed-goods backstock for a perimeter service edge."),
    "caden_sp_mkt_16_neutral_notice_cluster_master_v1": ("deferred", "Notice-board silhouette risks implying unapproved signage or lore."),
    "caden_mega_mkt_02_market_corner_master_v1": ("deferred", "Locked composite geometry does not fit the eight authoritative stall footprints."),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    filename = "segoeuib.ttf" if bold else "segoeui.ttf"
    path = Path("C:/Windows/Fonts") / filename
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def parse_pair(value: str) -> tuple[int, int]:
    left, right = value.split(",")
    return int(left), int(right)


def parse_bounds(value: str) -> tuple[int, int, int, int]:
    return tuple(int(part) for part in value.split(","))  # type: ignore[return-value]


def load_manifest_rows(library_root: Path) -> tuple[list[dict[str, str]], dict[str, dict[str, str]]]:
    path = library_root / "metadata/ASSET_MANIFEST.csv"
    with path.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 222:
        raise RuntimeError(f"Expected 222 catalog rows, found {len(rows)}.")
    by_id = {row["asset_id"]: row for row in rows}
    missing = sorted(set(CANDIDATES) - set(by_id))
    if missing:
        raise RuntimeError(f"Missing Marketplace candidates: {missing}")
    return rows, by_id


def verify_candidate_source(library_root: Path, row: dict[str, str]) -> Path:
    path = library_root / row["package_path"]
    if not path.is_file() or sha256(path) != row["package_sha256"]:
        raise RuntimeError(f"Missing or mismatched candidate source: {path}")
    return path


def load_capture(render_root: Path, entries: dict[str, dict[str, object]], filename: str) -> Path:
    path = render_root / "raw_captures" / filename
    entry = entries.get(filename)
    if entry is None or not path.is_file() or sha256(path) != entry["sha256"]:
        raise RuntimeError(f"Missing or mismatched baseline capture: {path}")
    return path


def draw_arrow(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], color: tuple[int, int, int, int]) -> None:
    draw.line(points, fill=color, width=8, joint="curve")
    x, y = points[-1]
    previous_x, previous_y = points[-2]
    if abs(x - previous_x) > abs(y - previous_y):
        direction = 1 if x > previous_x else -1
        head = [(x, y), (x - 18 * direction, y - 12), (x - 18 * direction, y + 12)]
    else:
        direction = 1 if y > previous_y else -1
        head = [(x, y), (x - 12, y - 18 * direction), (x + 12, y - 18 * direction)]
    draw.polygon(head, fill=color)


def build_composition_plan(full_zone_path: Path, output_root: Path) -> Path:
    with Image.open(full_zone_path) as source:
        base = source.convert("RGBA")
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Protected circulation remains exactly aligned to the live scene contract.
    draw.rectangle((384, 64, 512, 639), fill=(36, 150, 205, 72), outline=(90, 210, 250, 230), width=3)
    draw.rectangle((0, 256, 800, 384), fill=(36, 150, 205, 54), outline=(90, 210, 250, 210), width=3)
    draw.rectangle((96, 288, 800, 352), fill=(36, 150, 205, 62), outline=(90, 210, 250, 210), width=3)
    draw.rectangle((400, 500, 496, 639), fill=(80, 225, 165, 70), outline=(100, 245, 185, 220), width=3)
    draw.rectangle((0, 272, 144, 368), fill=(80, 225, 165, 70), outline=(100, 245, 185, 220), width=3)

    districts = (
        ((144, 104, 384, 232), "NW food / daily goods", (226, 166, 68, 72)),
        ((512, 104, 752, 232), "NE cloth / household", (198, 92, 102, 72)),
        ((144, 408, 384, 528), "SW local goods", (119, 159, 83, 76)),
        ((512, 408, 752, 528), "SE supply / backstock", (111, 117, 181, 76)),
    )
    for bounds, label, color in districts:
        draw.rounded_rectangle(bounds, radius=10, fill=color, outline=color[:3] + (225,), width=3)
        draw.text((bounds[0] + 10, bounds[1] + 8), label, fill=(248, 246, 235, 255), font=font(16, True))

    for x, y in ((208, 160), (336, 160), (560, 160), (688, 160), (208, 464), (336, 464), (560, 464), (688, 464)):
        draw.rectangle((x - 48, y - 24, x + 48, y + 24), outline=(255, 244, 188, 255), width=4)
        draw.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(255, 244, 188, 255))

    draw.rectangle((96, 64, 800, 108), fill=(30, 48, 36, 118), outline=(123, 164, 116, 225), width=3)
    draw.text((108, 76), "North service edge: deliveries, storage, planting, no customer-lane obstruction", fill=(235, 243, 226, 255), font=font(15, True))
    draw.rectangle((96, 536, 800, 576), fill=(30, 48, 36, 118), outline=(123, 164, 116, 225), width=3)
    draw.text((108, 546), "South transition forecourt: open and visually continuous to Town Square", fill=(235, 243, 226, 255), font=font(15, True))
    draw_arrow(draw, [(72, 320), (416, 320), (448, 320), (448, 600)], (111, 225, 246, 240))

    composed = Image.alpha_composite(base, overlay).convert("RGB")
    canvas = Image.new("RGB", (896, 748), (19, 23, 21))
    canvas.paste(composed, (0, 84))
    header = ImageDraw.Draw(canvas)
    header.text((24, 14), "Marketplace reconstruction composition plan", fill=(247, 243, 230), font=font(28, True))
    header.text((24, 51), "Blue = protected circulation; white = authoritative stall footprints; tinted masses = vendor districts.", fill=(184, 195, 186), font=font(16))
    output = output_root / PLAN_NAME
    canvas.save(output, compress_level=9)
    return output


def normalized_preview(source_path: Path, row: dict[str, str]) -> Image.Image:
    with Image.open(source_path) as source:
        image = source.convert("RGBA")
    bounds = parse_bounds(row["alpha_bounds_xyxy"])
    crop = image.crop(bounds)
    target = parse_pair(row["proposed_target_dimensions"])
    return crop.resize(target, Image.Resampling.NEAREST)


def build_candidate_board(
    stage_path: Path,
    library_root: Path,
    rows: dict[str, dict[str, str]],
    output_root: Path,
) -> tuple[Path, list[dict[str, object]]]:
    with Image.open(stage_path) as source:
        stage = source.convert("RGBA")
    margin = 24
    gap = 20
    header_height = 112
    card_width = 640
    card_height = 438
    columns = 2
    row_count = (len(CANDIDATES) + columns - 1) // columns
    board = Image.new("RGB", (margin * 2 + card_width * columns + gap, header_height + row_count * (card_height + gap) + margin - gap), (18, 22, 20))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 16), "Marketplace native-scale candidate review", fill=(247, 243, 230), font=font(30, True))
    draw.text((margin, 57), "Review-only nearest-neighbor previews on live terrain with the approved 40x56 player reference.", fill=(184, 195, 186), font=font(16))
    draw.text((margin, 81), "No candidate has been normalized, imported, selected, or placed in the Godot scene.", fill=(240, 182, 112), font=font(16, True))

    catalog: list[dict[str, object]] = []
    disposition_colors = {"recommended": (96, 176, 119), "alternate": (215, 166, 73), "deferred": (157, 131, 165)}
    for index, (asset_id, (disposition, reason)) in enumerate(CANDIDATES.items()):
        row = rows[asset_id]
        source_path = verify_candidate_source(library_root, row)
        preview = normalized_preview(source_path, row)
        column = index % columns
        card_row = index // columns
        x = margin + column * (card_width + gap)
        y = header_height + card_row * (card_height + gap)
        card = stage.copy()
        pivot_x = 205
        ground_y = 268
        card.alpha_composite(preview, (pivot_x - preview.width // 2, ground_y - preview.height))
        board.paste(card.convert("RGB"), (x, y + 78))
        color = disposition_colors[disposition]
        draw.rectangle((x, y, x + card_width - 1, y + card_height - 1), outline=color, width=3)
        short_id = asset_id.removeprefix("caden_").removesuffix("_master_v1")
        draw.text((x + 14, y + 9), short_id, fill=(245, 242, 231), font=font(18, True))
        draw.text((x + 14, y + 36), f"{disposition.upper()}  |  target {row['proposed_target_dimensions']} px  |  footprint {row['proposed_collision_footprint']} px", fill=color, font=font(14, True))
        draw.text((x + 14, y + 58), reason, fill=(201, 207, 200), font=font(13))
        catalog.append({
            "asset_id": asset_id,
            "review_disposition": disposition,
            "review_reason": reason,
            "source_package_path": row["package_path"],
            "source_sha256": row["package_sha256"],
            "scale_family": row["scale_family"],
            "proposed_scale_factor": float(row["proposed_scale_factor"]),
            "proposed_target_dimensions": list(parse_pair(row["proposed_target_dimensions"])),
            "proposed_pivot_xy": list(parse_pair(row["proposed_pivot_xy"])),
            "proposed_collision_footprint": row["proposed_collision_footprint"],
            "catalog_status": row["status"],
            "metadata_status": row["metadata_status"],
            "audit_flags": row["audit_flags"],
            "correction": row["correction"],
            "intended_placement": row["intended_placement"],
            "rights_status": row["rights_status"],
            "integration_authorized": False,
        })
    output = output_root / BOARD_NAME
    board.save(output, compress_level=9)
    return output, catalog


def write_review_document(output_root: Path) -> Path:
    path = output_root / "MARKETPLACE_RECONSTRUCTION_GATE_V1.md"
    path.write_text(
        """# Caden Marketplace reconstruction gate v1

This is the required pre-integration visual gate for Marketplace. The live `896 x 640` scene remains untouched.

## Contract

- Preserve the eight `96 x 48` stall footprints and their collision locations.
- Preserve the `128`-pixel central aisle, west arrival, south transition, camera bounds, three NPCs, dialogue, and all entry/exit nodes.
- Treat the west-to-center-to-south route as the primary circulation spine.
- Keep customer-facing goods inside four vendor districts and backstock on the north or outer service edges.
- Keep the south transition forecourt open and visually continuous with Town Square.

## Candidate recommendation

Recommended for a limited Marketplace reconstruction shortlist: `01`, `03`, `04`, `06`, `07`, `13`, and `14`.

Alternates: `02`, `08`, and `11`.

Deferred: `05`, `16`, and mega-set `02`.

All fourteen Marketplace structure masters, set pieces `09`, `10`, `12`, `15`, and mega-set `01` remain rejected under the v1.1 visual audit. The rejected structures are not silently reintroduced to solve the greybox stalls.

Approval of this gate authorizes normalization and manual cleanup only for the assets the user explicitly selects. It does not authorize the alternates, deferred candidates, rejected art, signs, lore, NPCs, or changes to another zone.
""",
        encoding="utf-8",
        newline="\n",
    )
    return path


def write_package_manifest(
    output_root: Path,
    render_root: Path,
    library_root: Path,
    baseline_manifest: dict[str, object],
    catalog: list[dict[str, object]],
) -> Path:
    tool_paths = (
        ROOT / "tools/art/render_caden_marketplace_baseline_v1.gd",
        ROOT / "tools/art/build_caden_marketplace_reconstruction_gate_v1.py",
    )
    artifacts = sorted(path for path in output_root.rglob("*") if path.is_file() and path.name not in {PACKAGE_MANIFEST, CHECKSUMS})
    manifest = {
        "schema": "caden-marketplace-reconstruction-gate-v1",
        "gate_state": "marketplace_composition_and_candidate_shortlist_pending_visual_approval",
        "scene_modified": False,
        "assets_imported": False,
        "library_root": str(library_root),
        "library_manifest_rows_verified": 222,
        "library_manifest_sha256": sha256(library_root / "metadata/ASSET_MANIFEST.csv"),
        "library_checksums_sha256": sha256(library_root / "metadata/SHA256SUMS.txt"),
        "rights_status": "project_internal_rights_unverified",
        "distribution_status": "do_not_publish_until_rights_are_verified",
        "live_contract": {
            "zone_dimensions": [896, 640],
            "stall_footprints": 8,
            "stall_collision_dimensions": [96, 48],
            "primary_aisle_width": 128,
            "west_destination": "wayfarers_approach",
            "south_destination": "town_square",
            "existing_npcs": 3,
        },
        "review_catalog": catalog,
        "rejected_categories_preserved": [
            "all fourteen Marketplace structure masters",
            "Marketplace set pieces 09, 10, 12, and 15",
            "Marketplace mega-set 01",
        ],
        "baseline": {
            "render_root": str(render_root),
            "manifest_sha256": sha256(render_root / BASELINE_MANIFEST),
            "render_tool_sha256": baseline_manifest["render_tool_sha256"],
        },
        "tools": {path.relative_to(ROOT).as_posix(): sha256(path) for path in tool_paths},
        "artifacts": {path.relative_to(output_root).as_posix(): sha256(path) for path in artifacts},
    }
    path = output_root / PACKAGE_MANIFEST
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    return path


def write_checksums(output_root: Path) -> Path:
    path = output_root / CHECKSUMS
    artifacts = sorted(file for file in output_root.rglob("*") if file.is_file() and file.name != CHECKSUMS)
    path.write_text(
        "".join(f"{sha256(file)}  {file.relative_to(output_root).as_posix()}\n" for file in artifacts),
        encoding="utf-8",
        newline="\n",
    )
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("render_root", type=Path)
    parser.add_argument("library_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    render_root = args.render_root.resolve()
    library_root = args.library_root.resolve()
    output_root = args.output_root.resolve()
    if ROOT == output_root or ROOT in output_root.parents:
        raise RuntimeError("Review material must remain outside the Godot project tree.")
    output_root.mkdir(parents=True, exist_ok=True)
    (output_root / "raw_captures").mkdir(exist_ok=True)
    (output_root / "metadata").mkdir(exist_ok=True)

    _all_rows, rows = load_manifest_rows(library_root)
    baseline_manifest = json.loads((render_root / BASELINE_MANIFEST).read_text(encoding="utf-8"))
    capture_entries = {entry["filename"]: entry for entry in baseline_manifest["captures"]}
    full_zone = load_capture(render_root, capture_entries, FULL_ZONE)
    candidate_stage = load_capture(render_root, capture_entries, CANDIDATE_STAGE)
    for filename in capture_entries:
        source = load_capture(render_root, capture_entries, filename)
        shutil.copy2(source, output_root / "raw_captures" / filename)

    shutil.copy2(render_root / BASELINE_MANIFEST, output_root / "metadata")
    shutil.copy2(library_root / "metadata/ASSET_MANIFEST.csv", output_root / "metadata")
    shutil.copy2(library_root / "docs/PROVENANCE_AND_LICENSE.md", output_root / "metadata")
    plan = build_composition_plan(full_zone, output_root)
    board, catalog = build_candidate_board(candidate_stage, library_root, rows, output_root)
    (output_root / "metadata/marketplace_candidate_shortlist_v1.json").write_text(
        json.dumps({"schema": "caden-marketplace-candidate-shortlist-v1", "candidates": catalog}, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    review_document = write_review_document(output_root)
    package_manifest = write_package_manifest(output_root, render_root, library_root, baseline_manifest, catalog)
    checksums = write_checksums(output_root)

    with Image.open(output_root / "raw_captures/marketplace_primary_aisle_before_v1_640x360.png") as native:
        expected = native.convert("RGBA").resize((1280, 720), Image.Resampling.NEAREST)
    with Image.open(output_root / "raw_captures/marketplace_primary_display_before_v1_1280x720.png") as display:
        if expected.tobytes() != display.convert("RGBA").tobytes():
            raise RuntimeError("The 1280x720 baseline is not an exact nearest-neighbor 2x enlargement.")

    print(f"composition_plan={plan}")
    print(f"candidate_board={board}")
    print(f"review_document={review_document}")
    print(f"package_manifest={package_manifest}")
    print(f"checksums={checksums}")
    print("scene_modified=false")
    print("assets_imported=false")
    print("exact_2x_display=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
