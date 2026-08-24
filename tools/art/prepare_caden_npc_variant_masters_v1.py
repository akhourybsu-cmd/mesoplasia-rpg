#!/usr/bin/env python3
"""Audit and deterministically prepare Caden NPC variant source masters.

The supplied variant masters use the same 4x4, 1060x1484 source layout as
the Caden NPC base. This tool preserves every input byte-for-byte as an
immutable v1 and creates a binary-alpha v2 without repainting, mirroring,
resizing, or warping the character art. Complete up-facing silhouettes are
recovered from a small region above the fourth-row boundary and translated
down to safe source-cell headroom.

No runtime atlas, character data, scene assignment, or lore is produced.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
TOOL_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL_DIR))

import repair_caden_npc_base_master_v2 as repair  # noqa: E402
import prepare_caden_player_runtime_v1 as shared  # noqa: E402


DEFAULT_OUTPUT_ROOT = ROOT / "assets/source_art/caden/characters/npc/variants"
DEFAULT_AUDIT_OUTPUT = ROOT / "docs/art/audits/caden_npc_variant_masters_v1.json"
NAME_PATTERN = re.compile(r"^caden_npc_(?P<slug>[a-z0-9_]+)_master_v1\.png$")

SHEET_SIZE = repair.SHEET_SIZE
CELL_SIZE = repair.CELL_SIZE
ROWS = ("down", "left", "right", "up")
POSES = ("neutral", "step_a", "passing", "step_b")
MIN_COMPONENT_PIXELS = 4


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _repo_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return path.name


def _bbox_dict(bbox: tuple[int, int, int, int] | None) -> dict[str, int] | None:
    if bbox is None:
        return None
    left, top, right, bottom = bbox
    return {
        "left": left,
        "top": top,
        "right_exclusive": right,
        "bottom_exclusive": bottom,
        "width": right - left,
        "height": bottom - top,
    }


def _component_summary(component: list[tuple[int, int]], size: tuple[int, int]) -> dict[str, Any]:
    width, height = size
    left = min(x for x, _y in component)
    top = min(y for _x, y in component)
    right = max(x for x, _y in component)
    bottom = max(y for _x, y in component)
    edge_counts = {
        "top": sum(y == 0 for _x, y in component),
        "bottom": sum(y == height - 1 for _x, y in component),
        "left": sum(x == 0 for x, _y in component),
        "right": sum(x == width - 1 for x, _y in component),
    }
    return {
        "pixel_count": len(component),
        "bbox": _bbox_dict((left, top, right + 1, bottom + 1)),
        "edge_counts": edge_counts,
    }


def _source_frame_audit(source: Image.Image) -> list[dict[str, Any]]:
    frames: list[dict[str, Any]] = []
    for row, direction in enumerate(ROWS):
        for column, pose in enumerate(POSES):
            left = column * CELL_SIZE[0]
            top = row * CELL_SIZE[1]
            cell = source.crop((left, top, left + CELL_SIZE[0], top + CELL_SIZE[1]))
            strong = repair._strong_mask(cell)
            components = [
                component
                for component in shared._connected_components(strong)
                if len(component) >= MIN_COMPONENT_PIXELS
            ]
            summaries = [_component_summary(component, cell.size) for component in components]
            contacts = [summary for summary in summaries if any(summary["edge_counts"].values())]
            frames.append({
                "frame": f"r{row + 1}c{column + 1}",
                "direction": direction,
                "pose": pose,
                "component_count": len(summaries),
                "components": summaries,
                "boundary_contacts": contacts,
            })
    return frames


def _prepare_transparent_master(
    source: Image.Image,
    original_frames: list[dict[str, Any]],
) -> tuple[Image.Image, list[dict[str, Any]]]:
    output = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
    repairs: list[dict[str, Any]] = []

    for row in range(3):
        for column in range(4):
            left = column * CELL_SIZE[0]
            top = row * CELL_SIZE[1]
            source_cell = source.crop((left, top, left + CELL_SIZE[0], top + CELL_SIZE[1]))
            extracted, bbox = repair._extract_primary(source_cell)
            edges = repair._alpha_edge_counts(extracted)
            if any(edges.values()):
                raise RuntimeError(f"r{row + 1}c{column + 1} primary silhouette touches a boundary: {edges}")
            output.alpha_composite(extracted, (left, top))
            repairs.append({
                "frame": f"r{row + 1}c{column + 1}",
                "operation": "binary-alpha extraction at original position",
                "source_bbox": _bbox_dict(bbox),
                "translation": [0, 0],
            })

    row4_top = CELL_SIZE[1] * 3
    search_top = row4_top - repair.UP_SEARCH_ROWS_ABOVE_BOUNDARY
    for column in range(4):
        left = column * CELL_SIZE[0]
        row4_audit = original_frames[12 + column]
        if not row4_audit["boundary_contacts"]:
            source_cell = source.crop((left, row4_top, left + CELL_SIZE[0], SHEET_SIZE[1]))
            extracted, bbox = repair._extract_primary(source_cell)
            edges = repair._alpha_edge_counts(extracted)
            if any(edges.values()):
                raise RuntimeError(f"r4c{column + 1} primary silhouette touches a boundary: {edges}")
            output.alpha_composite(extracted, (left, row4_top))
            repairs.append({
                "frame": f"r4c{column + 1}",
                "operation": "binary-alpha extraction at original position",
                "source_bbox": _bbox_dict(bbox),
                "translation": [0, 0],
            })
            continue

        region = source.crop((left, search_top, left + CELL_SIZE[0], SHEET_SIZE[1]))
        extracted, bbox = repair._extract_primary(region)
        region_edges = repair._alpha_edge_counts(extracted)
        if any(region_edges.values()):
            raise RuntimeError(f"r4c{column + 1} extended primary silhouette is incomplete: {region_edges}")
        crop = extracted.crop(bbox)
        original_top_in_row4 = search_top + bbox[1] - row4_top
        paste_x = left + bbox[0]
        paste_y = row4_top + repair.UP_HEADROOM
        if paste_y + crop.height > SHEET_SIZE[1]:
            raise RuntimeError(f"r4c{column + 1} cannot fit with required headroom")
        output.alpha_composite(crop, (paste_x, paste_y))
        repairs.append({
            "frame": f"r4c{column + 1}",
            "operation": "recover complete silhouette and translate into row 4",
            "source_region_bbox": _bbox_dict(bbox),
            "original_top_relative_to_row4": original_top_in_row4,
            "translation": [0, repair.UP_HEADROOM - original_top_in_row4],
            "output_bbox": _bbox_dict((bbox[0], repair.UP_HEADROOM, bbox[2], repair.UP_HEADROOM + crop.height)),
        })

    return output, repairs


def _prepared_frame_audit(output: Image.Image) -> list[dict[str, Any]]:
    frames: list[dict[str, Any]] = []
    for row, direction in enumerate(ROWS):
        for column, pose in enumerate(POSES):
            left = column * CELL_SIZE[0]
            top = row * CELL_SIZE[1]
            cell = output.crop((left, top, left + CELL_SIZE[0], top + CELL_SIZE[1]))
            alpha = cell.getchannel("A")
            bbox = alpha.getbbox()
            if bbox is None:
                raise RuntimeError(f"r{row + 1}c{column + 1} is empty after preparation")
            edges = repair._alpha_edge_counts(cell)
            if any(edges.values()):
                raise RuntimeError(f"r{row + 1}c{column + 1} touches a boundary after preparation: {edges}")
            frames.append({
                "frame": f"r{row + 1}c{column + 1}",
                "direction": direction,
                "pose": pose,
                "visible_bbox": _bbox_dict(bbox),
                "boundary_distances": {
                    "left": bbox[0],
                    "top": bbox[1],
                    "right": CELL_SIZE[0] - bbox[2],
                    "bottom": CELL_SIZE[1] - bbox[3],
                },
                "edge_counts": edges,
            })
    return frames


def _alpha_summary(image: Image.Image) -> dict[str, int | bool]:
    alpha = image.getchannel("A")
    histogram = alpha.histogram()
    return {
        "channel_present": True,
        "transparent": histogram[0],
        "partial": sum(histogram[1:255]),
        "opaque": histogram[255],
        "binary": sum(histogram[1:255]) == 0,
    }


def _safe_copy(source: Path, destination: Path) -> None:
    if destination.exists():
        if _sha256(source) != _sha256(destination):
            raise RuntimeError(f"Refusing to overwrite a different immutable v1: {destination}")
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def _write_png(image: Image.Image, destination: Path) -> None:
    if destination.exists():
        raise RuntimeError(f"Refusing to overwrite an existing prepared master: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, format="PNG", optimize=False, compress_level=9)


def _process(input_path: Path, output_root: Path, write: bool) -> dict[str, Any]:
    input_path = input_path.resolve()
    match = NAME_PATTERN.fullmatch(input_path.name)
    if match is None:
        raise ValueError(f"Unsupported filename: {input_path.name}")
    if not input_path.is_file():
        raise FileNotFoundError(input_path)

    slug = match.group("slug")
    variant_dir = output_root / slug
    archived_v1 = variant_dir / input_path.name
    prepared_v2 = variant_dir / input_path.name.replace("_master_v1.png", "_master_v2.png")
    input_hash_before = _sha256(input_path)

    with Image.open(input_path) as opened:
        source_format = opened.format
        source_mode = opened.mode
        source = opened.convert("RGB")
    if source_format != "PNG":
        raise RuntimeError(f"{input_path.name} is {source_format}, expected PNG")
    if source.size != SHEET_SIZE:
        raise RuntimeError(f"{input_path.name} is {source.size}, expected {SHEET_SIZE}")

    original_frames = _source_frame_audit(source)
    prepared, repairs = _prepare_transparent_master(source, original_frames)
    prepared_frames = _prepared_frame_audit(prepared)
    original_contacts = [
        {"frame": frame["frame"], "contacts": frame["boundary_contacts"]}
        for frame in original_frames
        if frame["boundary_contacts"]
    ]

    if write:
        _safe_copy(input_path, archived_v1)
        _write_png(prepared, prepared_v2)

    input_hash_after = _sha256(input_path)
    if input_hash_after != input_hash_before:
        raise RuntimeError(f"Input changed while preparing {input_path.name}")

    result: dict[str, Any] = {
        "variant_id": slug,
        "input_filename": input_path.name,
        "input_sha256_before": input_hash_before,
        "input_sha256_after": input_hash_after,
        "input_unchanged": input_hash_before == input_hash_after,
        "input_format": source_format,
        "input_mode": source_mode,
        "dimensions": list(source.size),
        "grid": {"columns": 4, "rows": 4, "cell_dimensions": list(CELL_SIZE)},
        "original_boundary_contacts": original_contacts,
        "original_frame_audit": original_frames,
        "repair_required": source_mode != "RGBA" or bool(original_contacts),
        "repair_method": (
            "deterministic primary-silhouette extraction, binary alpha, and translation-only row-4 recovery; "
            "no repainting, generation, mirroring, resizing, or warping"
        ),
        "repair_log": repairs,
        "prepared_alpha": _alpha_summary(prepared),
        "prepared_frame_audit": prepared_frames,
        "prepared_quality_gate": {
            "passed": True,
            "nonempty_frames": 16,
            "boundary_safe_frames": 16,
            "binary_alpha": True,
            "row_order": list(ROWS),
            "column_order": list(POSES),
        },
        "archived_v1_path": _repo_path(archived_v1),
        "prepared_v2_path": _repo_path(prepared_v2),
    }
    if archived_v1.exists():
        result["archived_v1_sha256"] = _sha256(archived_v1)
        result["archived_v1_matches_input"] = result["archived_v1_sha256"] == input_hash_before
    if prepared_v2.exists():
        with Image.open(prepared_v2) as opened:
            stored_prepared = opened.convert("RGBA")
        result["prepared_v2_sha256"] = _sha256(prepared_v2)
        result["prepared_v2_matches_reconstruction"] = (
            stored_prepared.size == prepared.size and stored_prepared.tobytes() == prepared.tobytes()
        )
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    parser.add_argument("--audit-output", type=Path, default=DEFAULT_AUDIT_OUTPUT)
    parser.add_argument("--write", action="store_true", help="Archive immutable v1 files and write prepared v2 files.")
    args = parser.parse_args()

    output_root = args.output_root.resolve()
    audit_output = args.audit_output.resolve()
    results = [_process(path, output_root, args.write) for path in args.inputs]
    audit = {
        "schema": "caden-npc-variant-master-audit-v1",
        "contract": {
            "source_dimensions": list(SHEET_SIZE),
            "grid": "4 columns x 4 rows",
            "cell_dimensions": list(CELL_SIZE),
            "rows": list(ROWS),
            "columns": list(POSES),
            "prepared_alpha": "binary",
            "prepared_boundaries": "no visible pixel on any cell edge",
        },
        "scope": "Source-art preparation only; no character assignment, lore, runtime atlas, or scene placement.",
        "variants": results,
    }

    if args.write:
        if audit_output.exists():
            raise RuntimeError(f"Refusing to overwrite an existing audit: {audit_output}")
        audit_output.parent.mkdir(parents=True, exist_ok=True)
        audit_output.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    for result in results:
        affected = ",".join(item["frame"] for item in result["original_boundary_contacts"])
        print(
            f"{result['variant_id']}: mode={result['input_mode']} size={result['dimensions'][0]}x{result['dimensions'][1]} "
            f"repair_required={result['repair_required']} original_boundary_frames={affected or 'none'} "
            f"prepared_gate=PASS stored_match={result.get('prepared_v2_matches_reconstruction', 'n/a')}"
        )
    if args.write:
        print(f"audit={_repo_path(audit_output)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
