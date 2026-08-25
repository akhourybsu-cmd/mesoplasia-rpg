#!/usr/bin/env python3
"""Build production 40x56 Caden NPC variant atlases and SpriteFrames.

The prepared v2 masters are immutable inputs. Every character uses the same
four-direction/four-pose normalization contract as the approved NPC base, so
the generated resources can be shared by stationary and patrol NPC scenes.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
from typing import Any

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
TOOL_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL_DIR))

import prepare_caden_npc_base_runtime_v1 as npc_base  # noqa: E402
import prepare_caden_player_runtime_v1 as shared  # noqa: E402


SOURCE_ROOT = ROOT / "assets/source_art/caden/characters/npc/variants"
RUNTIME_ROOT = ROOT / "assets/characters/caden/npc/variants"
MANIFEST_PATH = RUNTIME_ROOT / "caden_npc_variants_runtime_v1_manifest.json"
PREVIEW_PATH = ROOT / "docs/art/previews/caden_npc_variants_runtime_v1_lineup.png"
VARIANT_IDS = (
    "dwarf_elder_man_01",
    "dwarf_middle_woman_01",
    "elf_older_woman_01",
    "elf_younger_man_01",
    "half_elf_young_nonbinary_01",
    "human_elder_woman_01",
    "human_middle_man_01",
    "human_young_woman_01",
)
DIRECTIONS = ("down", "left", "right", "up")
FRAME_SIZE = (40, 56)
SHEET_SIZE = (160, 224)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _repo_path(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def _alpha_audit(image: Image.Image) -> dict[str, Any]:
    if image.mode != "RGBA":
        raise RuntimeError(f"Runtime atlas is {image.mode}, expected RGBA")
    if image.size != SHEET_SIZE:
        raise RuntimeError(f"Runtime atlas is {image.size}, expected {SHEET_SIZE}")
    histogram = image.getchannel("A").histogram()
    if sum(histogram[1:255]) != 0:
        raise RuntimeError("Runtime atlas contains partial alpha")

    frames: list[dict[str, Any]] = []
    for row, direction in enumerate(DIRECTIONS):
        for column in range(4):
            box = (
                column * FRAME_SIZE[0],
                row * FRAME_SIZE[1],
                (column + 1) * FRAME_SIZE[0],
                (row + 1) * FRAME_SIZE[1],
            )
            bbox = image.crop(box).getchannel("A").getbbox()
            if bbox is None:
                raise RuntimeError(f"{direction} frame {column} is empty")
            if bbox[0] < 0 or bbox[1] < 0 or bbox[2] > 40 or bbox[3] > 56:
                raise RuntimeError(f"{direction} frame {column} is outside its runtime cell")
            frames.append({
                "direction": direction,
                "frame": column,
                "visible_bbox": list(bbox),
            })
    return {
        "dimensions": list(image.size),
        "binary_alpha": True,
        "nonempty_frames": len(frames),
        "frames": frames,
    }


def _sprite_frames_text(slug: str) -> str:
    texture_path = f"res://assets/characters/caden/npc/variants/{slug}/caden_npc_{slug}_runtime_v1.png"
    lines = [
        "[gd_resource type=\"SpriteFrames\" load_steps=18 format=3]",
        "",
        f"[ext_resource type=\"Texture2D\" path=\"{texture_path}\" id=\"1_runtime\"]",
        "",
    ]
    for row, direction in enumerate(DIRECTIONS):
        for column in range(4):
            lines.extend([
                f"[sub_resource type=\"AtlasTexture\" id=\"Atlas_{direction}_{column}\"]",
                "atlas = ExtResource(\"1_runtime\")",
                f"region = Rect2({column * 40}, {row * 56}, 40, 56)",
                "",
            ])

    animations: list[str] = []
    for direction in DIRECTIONS:
        animations.append(
            "{\n"
            '"frames": [{\n'
            '"duration": 1.0,\n'
            f'"texture": SubResource("Atlas_{direction}_0")\n'
            "}],\n"
            '"loop": false,\n'
            f'"name": &"idle_{direction}",\n'
            '"speed": 8.0\n'
            "}"
        )
    for direction in DIRECTIONS:
        frames = ", ".join(
            "{\n"
            '"duration": 1.0,\n'
            f'"texture": SubResource("Atlas_{direction}_{column}")\n'
            "}"
            for column in range(4)
        )
        animations.append(
            "{\n"
            f'"frames": [{frames}],\n'
            '"loop": true,\n'
            f'"name": &"walk_{direction}",\n'
            '"speed": 8.0\n'
            "}"
        )
    lines.extend(["[resource]", f"animations = [{', '.join(animations)}]", ""])
    return "\n".join(lines)


def _lineup(entries: list[tuple[str, Image.Image]]) -> Image.Image:
    scale = 4
    card_width = 212
    card_height = 278
    output = Image.new("RGBA", (card_width * 4, card_height * 2), (24, 22, 20, 255))
    draw = ImageDraw.Draw(output)
    for index, (slug, sheet) in enumerate(entries):
        card_x = (index % 4) * card_width
        card_y = (index // 4) * card_height
        draw.rectangle((card_x + 4, card_y + 4, card_x + card_width - 5, card_y + card_height - 5), fill=(43, 39, 35, 255))
        draw.text((card_x + 12, card_y + 10), slug, fill=(238, 226, 207, 255))
        for frame_index in range(4):
            frame = sheet.crop((frame_index * 40, 0, (frame_index + 1) * 40, 56))
            checker = shared._checkerboard((160, 224), 16)
            checker.alpha_composite(frame.resize((160, 224), Image.Resampling.NEAREST))
            output.alpha_composite(checker, (card_x + 26, card_y + 38))
            if frame_index == 0:
                break
        draw.text((card_x + 12, card_y + 264), "down-facing idle · runtime 4x", fill=(176, 165, 150, 255))
    return output


def _process_variant(slug: str) -> tuple[dict[str, Any], Image.Image]:
    source = SOURCE_ROOT / slug / f"caden_npc_{slug}_master_v2.png"
    if not source.is_file():
        raise FileNotFoundError(source)
    source_hash_before = _sha256(source)
    with Image.open(source) as opened:
        source_image = opened.convert("RGBA")
    source_cells, source_cell_size = npc_base._split_cells(source_image)
    if source_cell_size != (265, 371):
        raise RuntimeError(f"{slug} source cells are {source_cell_size}, expected (265, 371)")

    primary_cells: list[Image.Image] = []
    source_frames: list[dict[str, Any]] = []
    for index, cell in enumerate(source_cells):
        frame, primary = npc_base._frame_audit(cell, index // 4, index % 4)
        if frame["boundary_contacts"]:
            raise RuntimeError(f"{slug} {frame['frame']} touches a source-cell boundary")
        source_frames.append(frame)
        primary_cells.append(primary)

    runtime, _runtime_cells, shared_scale = shared._candidate_b(primary_cells)
    runtime_audit = _alpha_audit(runtime)
    output_dir = RUNTIME_ROOT / slug
    runtime_path = output_dir / f"caden_npc_{slug}_runtime_v1.png"
    frames_path = output_dir / f"caden_npc_{slug}_sprite_frames_v1.tres"
    _save_png(runtime, runtime_path)
    output_dir.mkdir(parents=True, exist_ok=True)
    frames_path.write_text(_sprite_frames_text(slug), encoding="utf-8", newline="\n")

    source_hash_after = _sha256(source)
    if source_hash_before != source_hash_after:
        raise RuntimeError(f"Source master changed while processing {slug}")
    return ({
        "variant_id": slug,
        "source": {
            "path": _repo_path(source),
            "sha256": source_hash_after,
            "unchanged": True,
            "dimensions": list(source_image.size),
            "cell_dimensions": list(source_cell_size),
        },
        "runtime": {
            "path": _repo_path(runtime_path),
            "sha256": _sha256(runtime_path),
            "shared_scale": round(shared_scale, 9),
            **runtime_audit,
        },
        "sprite_frames": {
            "path": _repo_path(frames_path),
            "sha256": _sha256(frames_path),
            "animations": [f"idle_{d}" for d in DIRECTIONS] + [f"walk_{d}" for d in DIRECTIONS],
        },
        "source_frame_count": len(source_frames),
    }, runtime)


def main() -> int:
    variants: list[dict[str, Any]] = []
    lineup_entries: list[tuple[str, Image.Image]] = []
    for slug in VARIANT_IDS:
        manifest_entry, runtime = _process_variant(slug)
        variants.append(manifest_entry)
        lineup_entries.append((slug, runtime))

    _save_png(_lineup(lineup_entries), PREVIEW_PATH)
    manifest = {
        "schema": "caden-npc-variants-runtime-v1",
        "contract": {
            "runtime_dimensions": list(SHEET_SIZE),
            "grid": [4, 4],
            "frame_dimensions": list(FRAME_SIZE),
            "row_order": list(DIRECTIONS),
            "column_order": ["neutral", "step_a", "passing", "step_b"],
            "alpha": "binary",
            "normalization": "shared scale per character; nearest-neighbor; horizontally centered; feet aligned",
        },
        "variants": variants,
        "preview": {"path": _repo_path(PREVIEW_PATH), "sha256": _sha256(PREVIEW_PATH)},
    }
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({
        "schema": manifest["schema"],
        "variant_count": len(variants),
        "manifest": _repo_path(MANIFEST_PATH),
        "preview": _repo_path(PREVIEW_PATH),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
